from __future__ import annotations

import ipaddress
import re
from dataclasses import dataclass, field
from typing import Iterable


APP_NAME = "KZSC Hazırlayıcı"
APP_VERSION = "1.2.4"

KZSC_REPOSITORY = "ssy1979/keenetic-zapret-smart-control"
KZSC_ASSET_PREFIX = "keenetic-zapret-smart-control"
KZSC_RELEASE_API = f"https://api.github.com/repos/{KZSC_REPOSITORY}/releases/latest"
KZSC_MAX_ARCHIVE_BYTES = 10_485_760
KZSC_MAX_CHECKSUM_BYTES = 65_536


@dataclass(frozen=True)
class DnsPreset:
    title: str
    dot: tuple[tuple[str, str], ...]
    doh: tuple[str, ...]


DNS_PRESETS: dict[str, DnsPreset] = {
    "Cloudflare": DnsPreset(
        "Cloudflare",
        (("1.1.1.1", "cloudflare-dns.com"), ("1.0.0.1", "cloudflare-dns.com")),
        ("https://cloudflare-dns.com/dns-query",),
    ),
    "Google": DnsPreset(
        "Google",
        (("8.8.8.8", "dns.google"), ("8.8.4.4", "dns.google")),
        ("https://dns.google/dns-query",),
    ),
    "Quad9": DnsPreset(
        "Quad9",
        (("9.9.9.9", "dns.quad9.net"), ("149.112.112.112", "dns.quad9.net")),
        ("https://dns.quad9.net/dns-query",),
    ),
    "AdGuard": DnsPreset(
        "AdGuard",
        (("94.140.14.14", "dns.adguard-dns.com"), ("94.140.15.15", "dns.adguard-dns.com")),
        ("https://dns.adguard-dns.com/dns-query",),
    ),
}


DEFAULT_ENTWARE_PACKAGES = (
    "ca-certificates",
    "wget-ssl",
    "curl",
    "coreutils-sha256sum",
    "lighttpd",
    "lighttpd-mod-cgi",
    "iptables",
    "ip-full",
    "findutils",
    "gawk",
    "sed",
    "grep",
    "tar",
    "gzip",
    "procps-ng-ps",
)


DEFAULT_KZSC_COMPONENTS = (
    "ssh",
    "opkg",
    "dns-tls",
    "dns-https",
    "opkg-kmod-netfilter",
    "opkg-kmod-netfilter-addons",
)


ENTWARE_ARCH = {
    "aarch64": ("aarch64-k3.10", "aarch64-installer.tar.gz"),
    "arm64": ("aarch64-k3.10", "aarch64-installer.tar.gz"),
    "mipsel": ("mipselsf-k3.4", "mipsel-installer.tar.gz"),
    "mips": ("mipssf-k3.4", "mips-installer.tar.gz"),
}


@dataclass
class Component:
    name: str
    version: str = ""
    installed: str = ""
    queued: str = ""

    @property
    def is_installed(self) -> bool:
        return bool(self.installed and self.installed.lower() not in {"no", "false", "none"})


@dataclass
class StoragePartition:
    uuid: str = ""
    label: str = ""
    fstype: str = ""
    state: str = ""
    total: int = 0
    free: int = 0
    media_name: str = ""

    @property
    def target(self) -> str:
        ident = self.uuid or self.label
        return f"{ident}:/" if ident else ""

    @property
    def usable_for_entware(self) -> bool:
        return self.state.upper() == "MOUNTED" and self.fstype.lower() in {"ext2", "ext3", "ext4"}

    @property
    def display(self) -> str:
        name = self.label or self.uuid or "Adsız bölüm"
        free = format_bytes(self.free) if self.free else "bilinmiyor"
        return f"USB · {name} · {self.fstype.upper()} · boş {free}"


@dataclass
class DeviceInfo:
    host: str
    model: str = "Bilinmiyor"
    hw_id: str = ""
    release: str = ""
    arch: str = ""
    hostname: str = ""
    components: dict[str, Component] = field(default_factory=dict)
    component_catalog_complete: bool = True
    partitions: list[StoragePartition] = field(default_factory=list)
    interfaces: list[str] = field(default_factory=list)
    interface_choices: dict[str, str] = field(default_factory=dict)
    internal_storage: bool = False
    entware_ready: bool = False
    opkg_disk: str = ""


@dataclass(frozen=True)
class SetupOptions:
    protocol: str
    preset: str
    dot_entries: tuple[tuple[str, str], ...]
    doh_entries: tuple[str, ...]
    ignore_isp_dns: bool
    ignore_ipv6_dns: bool
    wan_interfaces: tuple[str, ...]
    storage_target: str
    storage_kind: str
    keenetic_components: tuple[str, ...]
    entware_packages: tuple[str, ...]


@dataclass
class SetupPlan:
    components_to_install: list[str]
    unavailable_components: list[str]
    dns_commands: list[str]
    storage_command: str
    entware_url: str
    packages: list[str]
    warnings: list[str]

    @property
    def requires_component_commit(self) -> bool:
        return bool(self.components_to_install)


@dataclass(frozen=True)
class KzscRelease:
    tag: str
    version: str
    archive_name: str
    checksum_name: str
    root_name: str
    archive_url: str
    checksum_url: str
    html_url: str
    archive_size: int


def parse_kzsc_release(payload: object) -> KzscRelease:
    """Validate GitHub's latest-release response against the owner-controlled KZSC contract."""
    if not isinstance(payload, dict):
        raise ValueError("GitHub KZSC sürüm yanıtı geçerli bir nesne değil.")
    if payload.get("draft") is not False or payload.get("prerelease") is not False:
        raise ValueError("KZSC kurulumu için yalnızca yayımlanmış kararlı Release kabul edilir.")

    tag = str(payload.get("tag_name", ""))
    if not re.fullmatch(r"v[0-9]+(?:\.[0-9]+){2,3}-generic", tag):
        raise ValueError("KZSC Release etiketi beklenen v…-generic biçiminde değil.")

    archive_name = f"{KZSC_ASSET_PREFIX}-{tag}.tar.gz"
    checksum_name = f"{archive_name}.sha256"
    root_name = f"{KZSC_ASSET_PREFIX}-{tag}"
    expected_base = f"https://github.com/{KZSC_REPOSITORY}/releases/download/{tag}/"
    html_url = str(payload.get("html_url", ""))
    expected_page = f"https://github.com/{KZSC_REPOSITORY}/releases/tag/{tag}"
    if html_url != expected_page:
        raise ValueError("KZSC Release sayfası güvenilir depo ile eşleşmiyor.")

    assets = payload.get("assets")
    if not isinstance(assets, list):
        raise ValueError("KZSC Release varlık listesi bulunamadı.")
    by_name: dict[str, dict] = {}
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = str(asset.get("name", ""))
        if name in {archive_name, checksum_name}:
            if name in by_name:
                raise ValueError(f"KZSC Release içinde yinelenen varlık var: {name}")
            by_name[name] = asset
    if archive_name not in by_name or checksum_name not in by_name:
        raise ValueError("KZSC Release arşivi veya ona ait .sha256 varlığı eksik.")

    archive = by_name[archive_name]
    checksum = by_name[checksum_name]
    archive_url = str(archive.get("browser_download_url", ""))
    checksum_url = str(checksum.get("browser_download_url", ""))
    if archive_url != expected_base + archive_name or checksum_url != expected_base + checksum_name:
        raise ValueError("KZSC Release indirme adresi güvenilir depo/etiket ile eşleşmiyor.")
    try:
        archive_size = int(archive.get("size", 0))
        checksum_size = int(checksum.get("size", 0))
    except (TypeError, ValueError) as exc:
        raise ValueError("KZSC Release varlık boyutu geçersiz.") from exc
    if not 0 < archive_size <= KZSC_MAX_ARCHIVE_BYTES:
        raise ValueError("KZSC Release arşivi 10 MiB güvenlik sınırının dışında.")
    if not 0 < checksum_size <= KZSC_MAX_CHECKSUM_BYTES:
        raise ValueError("KZSC .sha256 varlığı güvenlik boyutu sınırının dışında.")

    return KzscRelease(
        tag=tag,
        version=tag[1:],
        archive_name=archive_name,
        checksum_name=checksum_name,
        root_name=root_name,
        archive_url=archive_url,
        checksum_url=checksum_url,
        html_url=html_url,
        archive_size=archive_size,
    )


def strip_ansi(value: str) -> str:
    value = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", value)
    value = value.replace("\r", "")
    value = value.replace("►\n", "")
    return value


def parse_key_values(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in strip_ansi(text).splitlines():
        match = re.match(r"^\s*([\w-]+):\s*(.*?)\s*$", line)
        if match and match.group(1) not in result:
            result[match.group(1)] = match.group(2)
    return result


def parse_components(text: str) -> dict[str, Component]:
    components: dict[str, Component] = {}
    current: dict[str, str] | None = None
    for line in strip_ansi(text).splitlines():
        if re.match(r"^\s*component:\s*$", line):
            if current and current.get("name"):
                comp = Component(**{k: current.get(k, "") for k in ("name", "version", "installed", "queued")})
                components[comp.name] = comp
            current = {}
            continue
        if current is None:
            continue
        match = re.match(r"^\s*([\w-]+):\s*(.*?)\s*$", line)
        if match:
            current[match.group(1)] = match.group(2)
    if current and current.get("name"):
        comp = Component(**{k: current.get(k, "") for k in ("name", "version", "installed", "queued")})
        components[comp.name] = comp
    return components


def parse_installed_components(text: str) -> dict[str, Component]:
    """Read the locally installed component set embedded in ``show version``.

    KeeneticOS exposes this comma-separated field without contacting the update
    service, so it is a reliable fallback when the online component catalogue
    is temporarily unavailable.
    """

    clean = strip_ansi(text)
    match = re.search(r'^\s*["\']?components["\']?\s*:\s*["\']?([^"\'\r\n}]*)', clean, re.M)
    if not match:
        return {}
    result: dict[str, Component] = {}
    for raw_name in match.group(1).split(","):
        name = raw_name.strip()
        if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", name):
            result[name] = Component(name=name, installed="yes")
    return result


def parse_opkg_disk(text: str) -> str:
    """Return the configured OPKG storage target from running-config."""

    match = re.search(r"^\s*opkg\s+disk\s+([^\s]+)\s*$", strip_ansi(text), re.M | re.I)
    if not match:
        return ""
    target = match.group(1).strip()
    return target if re.fullmatch(r"[A-Za-z0-9_.:+/-]+", target) else ""


def _flush_partition(current: dict[str, str] | None, media_name: str, output: list[StoragePartition]) -> None:
    if not current:
        return
    output.append(
        StoragePartition(
            uuid=current.get("uuid", ""),
            label=current.get("label", ""),
            fstype=current.get("fstype", ""),
            state=current.get("state", ""),
            total=_as_int(current.get("total", "0")),
            free=_as_int(current.get("free", "0")),
            media_name=media_name,
        )
    )


def parse_media(text: str) -> list[StoragePartition]:
    output: list[StoragePartition] = []
    media_name = ""
    current: dict[str, str] | None = None
    for line in strip_ansi(text).splitlines():
        if re.match(r"^\s*media:\s*$", line):
            _flush_partition(current, media_name, output)
            current = None
            media_name = ""
            continue
        if re.match(r"^\s*partition:\s*$", line):
            _flush_partition(current, media_name, output)
            current = {}
            continue
        match = re.match(r"^\s*([\w-]+):\s*(.*?)\s*$", line)
        if not match:
            continue
        key, value = match.groups()
        if current is None and key == "name":
            media_name = value
        elif current is not None:
            current[key] = value
    _flush_partition(current, media_name, output)
    return output


def parse_interfaces(text: str) -> list[str]:
    return list(parse_interface_choices(text).values())


def parse_interface_choices(text: str) -> dict[str, str]:
    """Map user-facing Keenetic connection names to their CLI interface IDs."""

    wan_prefixes = (
        "ISP", "PPPoE", "PPTP", "L2TP", "UsbModem", "UsbQmi", "UsbLte", "UsbCdma",
        "Wisp", "WifiStation", "GigabitEthernet", "FastEthernet", "Vlan", "Dsl",
    )
    records: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in strip_ansi(text).splitlines():
        boundary = re.match(r"^\s*interface(?:\s*,\s*id\s*=\s*([A-Za-z][A-Za-z0-9_.-]*))?\s*:\s*$", line)
        if boundary:
            if current:
                records.append(current)
            current = {}
            if boundary.group(1):
                current["id"] = boundary.group(1)
            continue
        match = re.match(r"^\s*([\w-]+):\s*(.*?)\s*$", line)
        if match:
            current.setdefault(match.group(1).lower(), match.group(2).strip().strip('"'))
    if current:
        records.append(current)

    found: list[tuple[str, str]] = []
    for record in records:
        candidates = (record.get("id", ""), record.get("interface", ""), record.get("name", ""))
        interface_id = next((value for value in candidates if re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,63}", value)), "")
        if not interface_id or interface_id.startswith(("Home", "Guest", "Bridge", "AccessPoint", "WifiMaster", "Switch", "Loopback")):
            continue
        public = record.get("security-level", "").lower() == "public"
        global_interface = record.get("global", "").lower() in {"yes", "true", "1"}
        known_wan = interface_id == "ISP" or interface_id.startswith(
            ("PPPoE", "PPTP", "L2TP", "UsbModem", "UsbQmi", "UsbLte", "UsbCdma", "Wisp", "WifiStation", "Dsl")
        )
        if not (known_wan or public or global_interface):
            continue
        label_candidates = (
            record.get("description", ""), record.get("title", ""), record.get("label", ""),
            record.get("alias", ""), record.get("provider", ""), record.get("service-name", ""),
            record.get("name", ""),
        )
        label = next(
            (
                value.strip().strip('"')
                for value in label_candidates
                if value.strip().strip('"')
                and value.strip().strip('"') != interface_id
                and not value.strip().strip('"').isdigit()
            ),
            interface_id,
        )
        found.append((label, interface_id))

    # Older outputs may not be record-shaped. Preserve support while preferring
    # descriptive connection names whenever the device supplies them.
    if not found:
        for line in strip_ansi(text).splitlines():
            match = re.match(r"^\s*(?:interface|id|name):\s*([A-Za-z][A-Za-z0-9_.-]*)\s*$", line)
            if match:
                interface_id = match.group(1)
                if interface_id.startswith(wan_prefixes):
                    found.append((interface_id, interface_id))

    choices: dict[str, str] = {}
    for label, interface_id in found:
        if interface_id in choices.values():
            continue
        display = label
        suffix = 2
        while display in choices:
            display = f"{label} ({suffix})"
            suffix += 1
        choices[display] = interface_id
    return choices


def parse_configured_wan_choices(text: str) -> dict[str, str]:
    """Read configured WAN descriptions, including inactive backup links."""

    provider_profiles = (
        "ISP", "PPPoE", "PPTP", "L2TP", "UsbModem", "UsbQmi", "UsbLte", "UsbCdma",
        "Wisp", "WifiStation",
    )
    layered_provider_profiles = ("PPPoE", "PPTP", "L2TP")
    vpn_prefixes = ("Wireguard", "OpenVPN", "SSTP", "IPsec", "Gre", "EoIP", "Tunnel", "ZeroTier")
    records: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    for raw_line in strip_ansi(text).splitlines():
        line = raw_line.strip()
        start = re.match(r"^interface\s+([A-Za-z][A-Za-z0-9_.-]{0,63})(?:\s+description\s+(.+))?$", line)
        if start:
            if current:
                records.append(current)
            current = {"id": start.group(1), "signals": []}
            if start.group(2):
                current["description"] = start.group(2).strip().strip('"')
            continue
        if current is None:
            continue
        if line == "exit" or line.startswith("interface "):
            records.append(current)
            current = None
            continue
        description = re.match(r"^description\s+(.+)$", line)
        if description:
            current["description"] = description.group(1).strip().strip('"')
        rename = re.match(r"^rename\s+([A-Za-z][A-Za-z0-9_.-]{0,63})$", line, re.I)
        if rename:
            current["rename"] = rename.group(1)
        via = re.match(r"^connect\s+via\s+([A-Za-z][A-Za-z0-9_.-]{0,63})$", line, re.I)
        if via:
            current["via"] = via.group(1)
        signals = current["signals"]
        assert isinstance(signals, list)
        signals.append(line.lower())
    if current:
        records.append(current)

    interface_aliases = {
        str(record.get("rename", "")): str(record.get("id", ""))
        for record in records
        if record.get("rename") and record.get("id")
    }
    layered_parents = {
        interface_aliases.get(str(record.get("via", "")), str(record.get("via", "")))
        for record in records
        if str(record.get("id", "")).startswith(layered_provider_profiles) and record.get("via")
    }
    choices: dict[str, str] = {}
    for record in records:
        interface_id = str(record.get("id", ""))
        signals = tuple(str(item) for item in record.get("signals", []))
        if interface_id.startswith(vpn_prefixes):
            continue
        if interface_id in layered_parents and not interface_id.startswith(layered_provider_profiles):
            continue
        public = any(item.startswith("security-level public") for item in signals)
        direct_ipoe = public and any(
            item.startswith(("ip dhcp client", "ip address")) for item in signals
        )
        configured_as_wan = interface_id.startswith(provider_profiles) or direct_ipoe
        if not configured_as_wan:
            continue
        label = str(record.get("description", "")).strip()
        if not label or label.isdigit():
            label = interface_id
        display = label
        suffix = 2
        while display in choices:
            display = f"{label} ({suffix})"
            suffix += 1
        choices[display] = interface_id
    return choices


def merge_wan_choices(primary: dict[str, str], configured: dict[str, str]) -> dict[str, str]:
    """Prefer configured descriptions while retaining live WAN ordering/state."""

    configured_labels = {interface_id: label for label, interface_id in configured.items()}
    ordered: list[tuple[str, str]] = []
    seen: set[str] = set()
    for label, interface_id in primary.items():
        ordered.append((configured_labels.get(interface_id, label), interface_id))
        seen.add(interface_id)
    for label, interface_id in configured.items():
        if interface_id not in seen:
            ordered.append((label, interface_id))
            seen.add(interface_id)

    result: dict[str, str] = {}
    for label, interface_id in ordered:
        display = label
        suffix = 2
        while display in result:
            display = f"{label} ({suffix})"
            suffix += 1
        result[display] = interface_id
    return result


def summarize_wan_sources(interface_text: str, running_text: str) -> str:
    """Return a credential-free WAN diagnostic excerpt for support logs."""

    safe_show_keys = {
        "id", "name", "alias", "description", "title", "label", "provider", "service-name",
        "type", "global", "defaultgw", "security-level", "connected", "link", "state", "priority",
    }
    show_lines: list[str] = []
    for raw_line in strip_ansi(interface_text).splitlines():
        if re.match(r"^\s*interface(?:\s*,.*)?\s*:\s*$", raw_line):
            show_lines.append(raw_line.strip())
            continue
        match = re.match(r"^\s*([\w-]+):\s*(.*?)\s*$", raw_line)
        if match and match.group(1).lower() in safe_show_keys:
            show_lines.append(f"{match.group(1).lower()}: {match.group(2).strip()}")

    config_lines: list[str] = []
    for raw_line in strip_ansi(running_text).splitlines():
        line = raw_line.strip()
        start = re.match(r"^interface\s+([A-Za-z][A-Za-z0-9_.-]{0,63})(?:\s+description\s+(.+))?$", line)
        if start:
            value = f"interface {start.group(1)}"
            if start.group(2):
                value += " description " + start.group(2).strip()
            config_lines.append(value)
            continue
        if re.match(r"^connect\s+via\s+[A-Za-z][A-Za-z0-9_.-]{0,63}$", line, re.I):
            config_lines.append(line)
        elif re.match(
            r"^(?:description|rename|security-level|global|defaultgw|priority)\b", line, re.I
        ) or re.match(
            r"^(?:ip\s+dhcp\s+client(?:\s+no)?\s+name-servers|ipcp(?:\s+no)?\s+name-servers|mobile(?:\s+no)?\s+name-servers)\s*$",
            line,
            re.I,
        ):
            config_lines.append(line)

    show_excerpt = "\n".join(show_lines[:240]) or "(uygun güvenli alan bulunamadı)"
    config_excerpt = "\n".join(config_lines[:240]) or "(uygun güvenli alan bulunamadı)"
    return f"SHOW INTERFACE (güvenli alanlar)\n{show_excerpt}\nRUNNING CONFIG (güvenli WAN satırları)\n{config_excerpt}"


def build_wan_selection_targets(choices: dict[str, str], all_label: str) -> dict[str, tuple[str, ...]]:
    """Build single-WAN choices and append a localized all-WAN choice."""

    targets = {label: (interface_id,) for label, interface_id in choices.items()}
    unique_interfaces = tuple(dict.fromkeys(choices.values()))
    if len(unique_interfaces) > 1:
        targets[all_label] = unique_interfaces
    return targets


def parse_version(text: str) -> dict[str, str]:
    wanted = {"release", "arch", "model", "hw_id", "device", "manufacturer"}
    result: dict[str, str] = {}
    for line in strip_ansi(text).splitlines():
        match = re.match(r'^\s*["\']?([\w-]+)["\']?\s*:\s*["\']?(.*?)["\']?,?\s*$', line)
        if match and match.group(1) in wanted:
            result[match.group(1)] = match.group(2)
    return result


def parse_custom_dot(value: str, sni: str) -> tuple[tuple[str, str], ...]:
    entries: list[tuple[str, str]] = []
    clean_sni = validate_hostname(sni, "DoT SNI")
    for raw in value.split(","):
        address = raw.strip()
        if not address:
            continue
        try:
            ipaddress.ip_address(address)
        except ValueError as exc:
            raise ValueError(f"Geçersiz DoT IP adresi: {address}") from exc
        entries.append((address, clean_sni))
    return tuple(entries)


def parse_custom_doh(value: str) -> tuple[str, ...]:
    entries: list[str] = []
    for raw in value.split(","):
        url = raw.strip()
        if not url:
            continue
        if not re.fullmatch(r"https://[A-Za-z0-9.-]+(?::\d+)?/[A-Za-z0-9_./?=&%-]+", url):
            raise ValueError(f"Geçersiz DoH adresi: {url}")
        entries.append(url)
    return tuple(entries)


def validate_hostname(value: str, label: str = "Ana bilgisayar") -> str:
    value = value.strip()
    if not value or len(value) > 253 or not re.fullmatch(r"[A-Za-z0-9.-]+", value):
        raise ValueError(f"{label} geçerli değil.")
    return value


def validate_interface(value: str) -> str:
    value = value.strip()
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,63}", value):
        raise ValueError("WAN arayüz adı geçerli değil.")
    return value


def validate_storage_target(value: str) -> str:
    value = value.strip()
    if value == "storage:/":
        return value
    if not re.fullmatch(r"[A-Za-z0-9_.-]+:/", value):
        raise ValueError("OPKG depolama hedefi geçerli değil.")
    return value


def validate_packages(packages: Iterable[str]) -> tuple[str, ...]:
    output: list[str] = []
    for package in packages:
        package = package.strip()
        if not package:
            continue
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9+_.-]{0,79}", package):
            raise ValueError(f"Geçersiz OPKG paket adı: {package}")
        if package not in output:
            output.append(package)
    return tuple(output)


def entware_url_for_arch(arch: str) -> str:
    normalized = arch.strip().lower()
    if normalized not in ENTWARE_ARCH:
        raise ValueError(f"Bu işlemci mimarisi için güvenli Entware eşlemesi yok: {arch or 'bilinmiyor'}")
    directory, filename = ENTWARE_ARCH[normalized]
    return f"https://bin.entware.net/{directory}/installer/{filename}"


def build_dns_commands(options: SetupOptions) -> list[str]:
    protocol = options.protocol.lower()
    if protocol not in {"dot", "doh", "both"}:
        raise ValueError("DNS protokolü DoT, DoH veya İkisi olmalıdır.")
    commands: list[str] = []
    if protocol in {"dot", "both"}:
        if not options.dot_entries:
            raise ValueError("En az bir DoT sunucusu gerekli.")
        for address, sni in options.dot_entries:
            validate_hostname(sni, "DoT SNI")
            try:
                ipaddress.ip_address(address)
            except ValueError as exc:
                raise ValueError(f"Geçersiz DoT IP adresi: {address}") from exc
            commands.append(f"dns-proxy tls upstream {address} 853 sni {sni}")
    if protocol in {"doh", "both"}:
        if not options.doh_entries:
            raise ValueError("En az bir DoH sunucusu gerekli.")
        for url in options.doh_entries:
            if not re.fullmatch(r"https://[A-Za-z0-9.-]+(?::\d+)?/[A-Za-z0-9_./?=&%-]+", url):
                raise ValueError(f"Geçersiz DoH adresi: {url}")
            commands.append(f"dns-proxy https upstream {url} dnsm")
    if options.ignore_isp_dns:
        interfaces = tuple(dict.fromkeys(validate_interface(item) for item in options.wan_interfaces))
        if not interfaces:
            raise ValueError("İSS DNS'ini yoksaymak için en az bir WAN bağlantısı seçilmelidir.")
        for interface in interfaces:
            if interface.startswith(("PPPoE", "PPTP", "L2TP")):
                commands.extend((f"interface {interface}", "ipcp no name-servers", "exit"))
            elif interface.startswith(("UsbQmi", "UsbLte")):
                commands.extend((f"interface {interface}", "mobile no name-servers", "exit"))
            else:
                commands.extend((f"interface {interface}", "ip dhcp client no name-servers", "exit"))
            if options.ignore_ipv6_dns:
                commands.append(f"no interface {interface} ipv6 name-servers auto")
    commands.append("system configuration save")
    return commands


def build_plan(info: DeviceInfo, options: SetupOptions) -> SetupPlan:
    requested = list(options.keenetic_components)
    if options.storage_kind == "usb":
        requested.extend(("storage", "ext"))
    elif options.storage_kind == "internal":
        requested.append("storage")
    if options.protocol.lower() in {"dot", "both"}:
        requested.append("dns-tls")
    if options.protocol.lower() in {"doh", "both"}:
        requested.append("dns-https")

    components_to_install: list[str] = []
    unavailable: list[str] = []
    seen: set[str] = set()
    for name in requested:
        if name in seen:
            continue
        seen.add(name)
        component = info.components.get(name)
        if component is None:
            if info.component_catalog_complete:
                unavailable.append(name)
            else:
                # Only trusted, profile-defined official component names reach
                # this branch.  Availability will be confirmed by Keenetic's
                # own preview step before a commit is allowed.
                components_to_install.append(name)
        elif not component.is_installed:
            components_to_install.append(name)

    if options.storage_kind in {"existing", "configured"}:
        storage_target = ""
        url = ""
        storage_command = ""
    else:
        storage_target = validate_storage_target(options.storage_target)
        url = entware_url_for_arch(info.arch)
        storage_command = f"opkg disk {storage_target} {url}"
    warnings: list[str] = []
    if options.storage_kind == "internal":
        if not info.internal_storage:
            warnings.append("Dahili depolama komutla doğrulanamadı; kurulum cihaz tarafından reddedilebilir.")
        warnings.append("Dahili NAND alanı sınırlıdır; KZSC paketleri için yeterli boş alan bulunduğunu doğrulayın.")
    if options.ignore_isp_dns and any(item.startswith(("PPTP", "L2TP")) for item in options.wan_interfaces):
        warnings.append("Tünel sunucusu alan adıyla tanımlıysa İSS DNS'ini kapatmak bağlantıyı kesebilir.")
    if options.ignore_isp_dns and any(item.startswith("UsbModem") for item in options.wan_interfaces):
        warnings.append("UsbModem bağlantısında DNS yöntemi modem türüne göre DHCP veya IPCP olabilir; planı doğrulayın.")
    if unavailable:
        warnings.append("Cihaz bileşen kataloğunda bulunmayan öğeler otomatik kurulamayacak.")
    if not info.component_catalog_complete:
        warnings.append(
            "Çevrimiçi bileşen kataloğu alınamadı; kurulu bileşenler cihazın yerel sürüm bilgisinden okundu. "
            "Eksik bileşenler Keenetic önizleme adımında yeniden doğrulanacak."
        )

    return SetupPlan(
        components_to_install=components_to_install,
        unavailable_components=unavailable,
        dns_commands=build_dns_commands(options),
        storage_command=storage_command,
        entware_url=url,
        packages=list(validate_packages(options.entware_packages)),
        warnings=warnings,
    )


def has_cli_error(text: str) -> bool:
    lowered = strip_ansi(text).lower()
    markers = (
        "error[",
        "not found:",
        "unknown command",
        "invalid argument",
        "request failed",
        "permission denied",
        "erişim reddedildi",
        "hata[",
    )
    return any(marker in lowered for marker in markers)


def extract_installed_packages(text: str) -> set[str]:
    packages: set[str] = set()
    for line in strip_ansi(text).splitlines():
        match = re.match(r"^([A-Za-z0-9][A-Za-z0-9+_.-]*)\s+-\s+\S+", line.strip())
        if match:
            packages.add(match.group(1))
    return packages


def format_bytes(value: int) -> str:
    number = float(value)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if number < 1024 or unit == "TB":
            return f"{number:.1f} {unit}"
        number /= 1024
    return f"{number:.1f} TB"


def _as_int(value: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0
