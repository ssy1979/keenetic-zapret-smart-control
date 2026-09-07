#!/usr/bin/env python3
"""Verify the complete source manifest and build a router-only release payload."""
from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
import re
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = "opt/kzsc/bin/kzsc-maintenance.sh"
VERSION_FILES = (
    "install.sh", "opt/kzsc/bin/kzsc", "opt/kzsc/bin/kzsc-backup.sh",
    "opt/kzsc/bin/kzsc-maintenance.sh", "opt/kzsc/bin/kzsc-preflight.sh",
    "opt/kzsc/bin/kzsc-telegram.sh", "opt/kzsc/bin/kzsc-updater.sh",
    "opt/kzsc/etc/kzsc.conf.example",
)
REQUIRED = (
    "install.sh", "opt/etc/init.d/S99kzsc", "opt/kzsc/www/index.html",
    "opt/kzsc/etc/kzsc.conf.example",
    *(f"opt/kzsc/bin/{name}" for name in (
        "kzsc", "kzsc-audit.sh", "kzsc-ui-selftest.sh", "kzsc-purity.sh",
        "kzsc-lib.sh", "kzsc-preflight.sh", "kzsc-bootstrap.sh",
        "kzsc-maintenance.sh", "kzsc-updater.sh", "kzsc-daemon.sh",
    )),
)


def source_files(root: Path = ROOT) -> list[str]:
    result = subprocess.run(
        ["git", "-c", f"safe.directory={root.as_posix()}", "-C", str(root),
         "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        check=True, stdout=subprocess.PIPE,
    )
    paths = sorted(set(result.stdout.decode("utf-8").strip("\0").split("\0")))
    return [p for p in paths if p and p != "SHA256SUMS"]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def manifest_for(files: dict[str, bytes]) -> bytes:
    return "".join(f"{digest(data)}  ./{path}\n" for path, data in sorted(files.items())).encode()


def validate_payload(files: dict[str, bytes], version: str) -> None:
    missing = [path for path in REQUIRED if not files.get(path)]
    if missing:
        raise ValueError("Required payload files missing: " + ", ".join(missing))
    for path in VERSION_FILES:
        data = files[path].decode("utf-8")
        versions = set(re.findall(r"(?<![0-9.])v?([0-9]+\.\d+\.\d+(?:\.\d+)?-generic)", data))
        if versions != {version}:
            raise ValueError(f"Version mismatch in {path}: {sorted(versions)} != {version}")
    # Static shell paths are dependencies, even when older manifest generators
    # accidentally omitted the dependency from both the archive and its hashes.
    pattern = re.compile(r"(?:/opt/kzsc|\$KZSC_HOME|\$ROOT)/bin/(kzsc(?:-[a-z0-9-]+\.sh)?)\b")
    for path, data in files.items():
        if not (path.startswith("opt/kzsc/bin/") or path == "install.sh"):
            continue
        if b"\r" in data:
            raise ValueError(f"Non-POSIX line endings: {path}")
        for match in pattern.finditer(data.decode("utf-8")):
            dependency = f"opt/kzsc/bin/{match[1]}"
            if dependency not in files:
                raise ValueError(f"Missing dependency {dependency} referenced by {path}")
    for path in ("opt/kzsc/var/", "opt/kzsc/zapret2/", "opt/kzsc/etc/kzsc.conf"):
        if any(name == path or (path.endswith("/") and name.startswith(path)) for name in files):
            raise ValueError(f"Router runtime data must not be published: {path}")


def read_source(root: Path = ROOT) -> dict[str, bytes]:
    files = {}
    for name in source_files(root):
        path = root / name
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Source must be an ordinary file: {name}")
        files[name] = path.read_bytes()
    return files


def canonical_version(files: dict[str, bytes]) -> str:
    matches = re.findall(rb'^VERSION="([0-9.]+-generic)"$', files[VERSION_FILE], re.M)
    if len(matches) != 1:
        raise ValueError("Canonical VERSION is missing or ambiguous")
    return matches[0].decode()


def verify_manifest(files: dict[str, bytes], manifest: bytes) -> None:
    expected = {}
    for line in manifest.decode("utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (?:\./)?([^\s]+)", line)
        if not match or match[2] in expected:
            raise ValueError("Invalid or duplicate manifest entry")
        expected[match[2]] = match[1]
    if set(expected) != set(files):
        raise ValueError(f"Manifest coverage differs: missing={sorted(set(files)-set(expected))}, extra={sorted(set(expected)-set(files))}")
    for path, data in files.items():
        if digest(data) != expected[path]:
            raise ValueError(f"Manifest hash mismatch: {path}")


def build_router(files: dict[str, bytes], version: str, destination: Path) -> Path:
    # Explicit roots prevent recursive local-build/dist packages, docs, and the
    # Windows Python tree from being copied into router storage.
    roots = {"install.sh", "LICENSE", "THIRD_PARTY_NOTICES.md", "README.txt"}
    payload = {p: b for p, b in files.items() if p in roots or p.startswith("opt/")}
    validate_payload(payload, version)
    payload["SHA256SUMS"] = manifest_for(payload)
    directory = f"keenetic-zapret-smart-control-v{version}"
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / f"{directory}.tar.gz"
    with tarfile.open(archive, "w:gz", format=tarfile.USTAR_FORMAT) as tar:
        info = tarfile.TarInfo(directory)
        info.type = tarfile.DIRTYPE
        info.mode = 0o755
        tar.addfile(info)
        for name, data in sorted(payload.items()):
            info = tarfile.TarInfo(f"{directory}/{name}")
            info.size = len(data)
            info.mode = 0o755 if data.startswith(b"#!") else 0o644
            tar.addfile(info, io.BytesIO(data))
    # Read back bytes from the actual archive, not only the input directory.
    with tarfile.open(archive, "r:gz") as tar:
        unpacked = {m.name[len(directory)+1:]: tar.extractfile(m).read()
                    for m in tar.getmembers() if m.isfile()}
    inner_manifest = unpacked.pop("SHA256SUMS")
    verify_manifest(unpacked, inner_manifest)
    validate_payload(unpacked, version)
    archive.with_name(archive.name + ".sha256").write_text(
        f"{digest(archive.read_bytes())}  {archive.name}\n", encoding="ascii")
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("verify", "manifest", "build"))
    parser.add_argument("--tag")
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    files = read_source()
    version = canonical_version(files)
    validate_payload(files, version)
    if args.tag and args.tag != f"v{version}":
        raise ValueError("Tag does not match canonical version")
    if args.action == "manifest":
        (ROOT / "SHA256SUMS").write_bytes(manifest_for(files))
    else:
        verify_manifest(files, (ROOT / "SHA256SUMS").read_bytes())
    if args.action == "build":
        print(build_router(files, version, args.output))
    print(f"Release contract OK: {version}, {len(files)} source files")


if __name__ == "__main__":
    main()
