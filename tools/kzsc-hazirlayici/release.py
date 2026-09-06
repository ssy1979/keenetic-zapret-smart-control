"""Bounded, non-extracting validation of owner-published KZSC release payloads."""
from __future__ import annotations

import hashlib
import gzip
import io
import re
import tarfile
import time
import urllib.parse
import urllib.request

from core import APP_VERSION, KZSC_MAX_ARCHIVE_BYTES, KZSC_MAX_CHECKSUM_BYTES, KzscRelease


MAX_EXPANDED_BYTES = 32 * 1024 * 1024
MAX_TAR_BYTES = 40 * 1024 * 1024
MAX_MEMBERS = 500
REQUIRED_PAYLOAD = frozenset({
    "install.sh", "opt/etc/init.d/S99kzsc", "opt/kzsc/bin/kzsc",
    "opt/kzsc/www/index.html",
} | {
    "opt/kzsc/bin/kzsc-" + name + ".sh" for name in (
        "lib", "bootstrap", "daemon", "discover", "reconcile", "clients",
        "isolation", "wan-registry", "native-dpi", "maintenance", "updater",
        "audit", "preflight", "purity", "ui-selftest",
    )
})


def _relative_path(name: str, *, manifest: bool = False) -> str:
    # GNU sha256sum emits ./paths; allow that prefix once, not traversal.
    if manifest and name.startswith("./"):
        name = name[2:]
    if not re.fullmatch(r"[A-Za-z0-9_.+/-]+", name):
        raise ValueError(f"Unsafe package path: {name!r}")
    if any(part in {"", ".", ".."} for part in name.split("/")):
        raise ValueError(f"Unsafe package path: {name!r}")
    return name


def validate_release_payload(release: KzscRelease, archive: bytes, checksum: bytes) -> str:
    """Return the verified digest; never extract or execute downloaded code.

    A valid checksum alone does not prove that a release is complete. Every
    regular file must be covered exactly once by the manifest, and the runtime
    entry points and their literal KZSC backend references must be present.
    """
    if not 0 < len(archive) <= KZSC_MAX_ARCHIVE_BYTES or len(archive) != release.archive_size:
        raise ValueError("Archive size does not match the validated release metadata.")
    if not 0 < len(checksum) <= KZSC_MAX_CHECKSUM_BYTES:
        raise ValueError("Checksum file exceeds its size limit.")
    try:
        checksum_lines = checksum.decode("ascii").splitlines()
    except UnicodeDecodeError as exc:
        raise ValueError("Checksum file is not ASCII.") from exc
    if len(checksum_lines) != 1:
        raise ValueError("Expected exactly one external checksum entry.")
    match = re.fullmatch(r"([0-9a-fA-F]{64}) [ *](.+)", checksum_lines[0])
    if not match or match[2] != release.archive_name:
        raise ValueError("External checksum does not name the expected archive.")
    digest = hashlib.sha256(archive).hexdigest()
    if digest != match[1].lower():
        raise ValueError("External SHA-256 mismatch.")

    files: dict[str, bytes] = {}
    paths: set[str] = set()
    expanded = 0
    try:
        # Bound the complete decompressed tar, including PAX/GNU metadata,
        # before tarfile parses headers with attacker-controlled size fields.
        with gzip.GzipFile(fileobj=io.BytesIO(archive)) as compressed:
            tar_bytes = compressed.read(MAX_TAR_BYTES + 1)
        if len(tar_bytes) > MAX_TAR_BYTES:
            raise ValueError("Decompressed tar exceeds its size limit.")
        with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as package:
            for index, member in enumerate(package):
                if index >= MAX_MEMBERS:
                    raise ValueError("Too many archive entries.")
                name = _relative_path(member.name.rstrip("/") if member.isdir() else member.name)
                if name in paths:
                    raise ValueError(f"Duplicate archive path: {name}")
                paths.add(name)
                if name == release.root_name:
                    if not member.isdir():
                        raise ValueError("Archive root is not a directory.")
                    continue
                if not name.startswith(release.root_name + "/"):
                    raise ValueError("Archive entry is outside the expected release root.")
                if member.mode & 0o7000 or member.issparse() or not (member.isfile() or member.isdir()):
                    raise ValueError(f"Unsupported archive entry type/mode: {name}")
                if member.isdir():
                    continue
                expanded += member.size
                if member.size < 0 or expanded > MAX_EXPANDED_BYTES:
                    raise ValueError("Expanded archive exceeds its size limit.")
                stream = package.extractfile(member)
                if stream is None:
                    raise ValueError(f"Unreadable archive member: {name}")
                data = stream.read(member.size + 1)
                if len(data) != member.size:
                    raise ValueError(f"Truncated archive member: {name}")
                files[name[len(release.root_name) + 1:]] = data
    except (tarfile.TarError, OSError, EOFError) as exc:
        raise ValueError(f"Invalid gzip/tar package: {exc}") from exc
    if "SHA256SUMS" not in files:
        raise ValueError("Missing internal SHA256SUMS manifest.")
    missing = sorted(REQUIRED_PAYLOAD - files.keys())
    if missing:
        raise ValueError("Missing required KZSC payload: " + ", ".join(missing))
    for path in files:
        parts = path.split("/")
        if any("/".join(parts[:end]) in files for end in range(1, len(parts))):
            raise ValueError(f"Archive file is also used as a directory: {path}")
    if any(not files[path] for path in REQUIRED_PAYLOAD):
        raise ValueError("A required KZSC payload file is empty.")
    try:
        manifest_lines = files["SHA256SUMS"].decode("ascii").splitlines()
    except UnicodeDecodeError as exc:
        raise ValueError("Internal manifest is not ASCII.") from exc
    entries: dict[str, str] = {}
    for line in manifest_lines:
        entry = re.fullmatch(r"([0-9a-fA-F]{64}) [ *](.+)", line)
        if not entry:
            raise ValueError("Malformed internal checksum entry.")
        path = _relative_path(entry[2], manifest=True)
        if path in entries or path == "SHA256SUMS":
            raise ValueError(f"Duplicate/self-referencing manifest entry: {path}")
        entries[path] = entry[1].lower()
    if set(entries) != files.keys() - {"SHA256SUMS"}:
        raise ValueError("Internal manifest must cover every packaged file exactly once.")
    for path, expected in entries.items():
        if hashlib.sha256(files[path]).hexdigest() != expected:
            raise ValueError(f"Internal SHA-256 mismatch: {path}")

    version_source = files["opt/kzsc/bin/kzsc-maintenance.sh"].decode("utf-8")
    if not re.search(r'^VERSION=[\"\']?' + re.escape(release.version) + r'[\"\']?\s*$', version_source, re.M):
        raise ValueError("Package version does not match the release tag.")
    reference = re.compile(r'(?:/opt/kzsc|\$(?:KZSC_HOME|\{KZSC_HOME\}))/bin/(kzsc(?:-[A-Za-z0-9_-]+\.sh)?)\b')
    for path, data in files.items():
        if path != "install.sh" and not path.startswith(("opt/kzsc/bin/", "opt/kzsc/www/cgi-bin/", "opt/etc/init.d/")):
            continue
        source = data.decode("utf-8")
        # Comments may document removed files. Only actual source lines define
        # the literal dependency contract; dynamic references remain core-audited.
        source = "\n".join(line for line in source.splitlines() if not line.lstrip().startswith("#"))
        for target in reference.findall(source):
            if "opt/kzsc/bin/" + target not in files:
                raise ValueError(f"Missing runtime dependency {target}, referenced by {path}.")
    return digest


class _HttpsOnlyRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urllib.parse.urlsplit(newurl).scheme != "https":
            raise ValueError("Release download attempted a non-HTTPS redirect.")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def download_bounded(url: str, maximum: int, timeout: float = 180) -> bytes:
    if urllib.parse.urlsplit(url).scheme != "https":
        raise ValueError("Release download requires HTTPS.")
    request = urllib.request.Request(url, headers={"User-Agent": f"KZSC-Hazirlayici/{APP_VERSION}"})
    started = time.monotonic()
    with urllib.request.build_opener(_HttpsOnlyRedirect()).open(request, timeout=25) as response:
        declared = response.headers.get("Content-Length")
        if declared and (int(declared) < 1 or int(declared) > maximum):
            raise ValueError("Release download exceeds its size limit.")
        data = bytearray()
        while True:
            if time.monotonic() - started > timeout:
                raise TimeoutError("Release download deadline exceeded.")
            block = response.read(min(65536, maximum + 1 - len(data)))
            if not block:
                break
            data.extend(block)
            if len(data) > maximum:
                raise ValueError("Release download exceeds its size limit.")
        return bytes(data)
