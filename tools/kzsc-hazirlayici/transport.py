from __future__ import annotations

import base64
import concurrent.futures
import hashlib
import ipaddress
import os
import re
import socket
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

import paramiko

from core import strip_ansi, validate_hostname


@dataclass(frozen=True)
class DiscoveredHost:
    host: str
    label: str
    ssh22: bool
    web_hint: bool

    @property
    def display(self) -> str:
        flags = []
        if self.ssh22:
            flags.append("SSH 22")
        if self.web_hint:
            flags.append("Keenetic web")
        detail = ", ".join(flags) if flags else "aday"
        return f"{self.host} — {self.label} ({detail})"


class HostKeyMismatch(RuntimeError):
    pass


class UnknownHostKey(RuntimeError):
    def __init__(self, host: str, key_type: str, fingerprint: str):
        super().__init__(f"{host} için yeni SSH anahtarı: {fingerprint}")
        self.host = host
        self.key_type = key_type
        self.fingerprint = fingerprint


def app_data_dir() -> Path:
    base = os.getenv("LOCALAPPDATA") or str(Path.home())
    path = Path(base) / "KZSC-Hazirlayici"
    path.mkdir(parents=True, exist_ok=True)
    return path


def fingerprint_sha256(key: paramiko.PKey) -> str:
    digest = hashlib.sha256(key.asbytes()).digest()
    return "SHA256:" + base64.b64encode(digest).decode("ascii").rstrip("=")


def _host_key_name(host: str, port: int) -> str:
    return host if port == 22 else f"[{host}]:{port}"


def probe_host_key(host: str, port: int = 22, timeout: float = 5.0) -> paramiko.PKey:
    validate_hostname(host)
    sock = socket.create_connection((host, port), timeout=timeout)
    transport = paramiko.Transport(sock)
    try:
        transport.start_client(timeout=timeout)
        return transport.get_remote_server_key()
    finally:
        transport.close()
        sock.close()


def verify_host_key(host: str, key: paramiko.PKey, port: int = 22) -> None:
    path = app_data_dir() / "known_hosts"
    keys = paramiko.HostKeys()
    if path.exists():
        keys.load(str(path))
    name = _host_key_name(host, port)
    known = keys.lookup(name)
    if not known:
        raise UnknownHostKey(name, key.get_name(), fingerprint_sha256(key))
    if key.get_name() not in known or known[key.get_name()].asbytes() != key.asbytes():
        expected = ", ".join(fingerprint_sha256(item) for item in known.values())
        raise HostKeyMismatch(
            f"SSH sunucu anahtarı değişti. Beklenen: {expected}; gelen: {fingerprint_sha256(key)}"
        )


def trust_host_key(host: str, key: paramiko.PKey, port: int = 22) -> None:
    path = app_data_dir() / "known_hosts"
    keys = paramiko.HostKeys()
    if path.exists():
        keys.load(str(path))
    keys.add(_host_key_name(host, port), key.get_name(), key)
    keys.save(str(path))


def forget_host_key(host: str, port: int = 22) -> bool:
    path = app_data_dir() / "known_hosts"
    if not path.exists():
        return False
    keys = paramiko.HostKeys(str(path))
    name = _host_key_name(host, port)
    if name not in keys:
        return False
    del keys[name]
    keys.save(str(path))
    return True


class KeeneticCli:
    def __init__(self, host: str, username: str, password: str, port: int = 22, timeout: float = 10.0):
        self.host = validate_hostname(host)
        self.port = port
        self._username = username
        self._password = password
        self._timeout = timeout
        self.client: paramiko.SSHClient | None = None
        self.channel: paramiko.Channel | None = None
        self._connect()

    def _connect(self) -> None:
        self.close()
        client = paramiko.SSHClient()
        client.load_host_keys(str(app_data_dir() / "known_hosts"))
        client.set_missing_host_key_policy(paramiko.RejectPolicy())
        try:
            client.connect(
                hostname=self.host,
                port=self.port,
                username=self._username,
                password=self._password,
                look_for_keys=False,
                allow_agent=False,
                timeout=self._timeout,
                auth_timeout=self._timeout,
                banner_timeout=self._timeout,
            )
            channel = client.invoke_shell(width=220, height=1000)
            channel.settimeout(0.25)
        except Exception:
            client.close()
            raise
        self.client = client
        self.channel = channel
        self._read_until_idle(1.0, 6.0)

    def close(self) -> None:
        try:
            if self.channel is not None:
                self.channel.close()
        finally:
            if self.client is not None:
                self.client.close()
            self.channel = None
            self.client = None

    def _is_connected(self) -> bool:
        if self.client is None or self.channel is None or self.channel.closed:
            return False
        transport = self.client.get_transport()
        return bool(transport and transport.is_active())

    def command(self, command: str, timeout: float = 30.0, idle: float = 0.7) -> str:
        if not self._is_connected():
            self._connect()
        assert self.channel is not None
        try:
            self.channel.send(command + "\n")
        except (OSError, EOFError, paramiko.SSHException):
            # Keenetic can close an idle CLI channel while Entware/SSH 222 is
            # being awaited.  Reconnect once before sending the next command;
            # a failed send means the command was not accepted by the channel.
            self._connect()
            assert self.channel is not None
            self.channel.send(command + "\n")
        # Some commands (notably ``components list``) contact Keenetic's update
        # service and may stay silent for several seconds after echoing the
        # command.  An idle timeout therefore truncates a perfectly valid
        # response.  The CLI prompt is the authoritative completion marker.
        # ``idle`` remains in the public signature for compatibility with
        # callers built against earlier versions.
        output = self._read_until_prompt(timeout)
        return _clean_command_output(output, command)

    def commands(
        self,
        commands: Iterable[str],
        timeout: float = 30.0,
        callback: Callable[[str, str], None] | None = None,
    ) -> list[tuple[str, str]]:
        results: list[tuple[str, str]] = []
        for command in commands:
            output = self.command(command, timeout=timeout)
            results.append((command, output))
            if callback:
                callback(command, output)
        return results

    def _read_until_idle(self, idle: float, timeout: float) -> str:
        if self.channel is None:
            return ""
        chunks: list[bytes] = []
        started = time.monotonic()
        last = started
        while time.monotonic() - started < timeout:
            if self.channel.recv_ready():
                data = self.channel.recv(65535)
                if not data:
                    break
                chunks.append(data)
                last = time.monotonic()
                continue
            if self.channel.closed:
                break
            if chunks and time.monotonic() - last >= idle:
                break
            time.sleep(0.05)
        return b"".join(chunks).decode("utf-8", errors="replace")

    def _read_until_prompt(self, timeout: float) -> str:
        if self.channel is None:
            return ""
        chunks: list[bytes] = []
        started = time.monotonic()
        while time.monotonic() - started < timeout:
            if self.channel.recv_ready():
                data = self.channel.recv(65535)
                if not data:
                    break
                chunks.append(data)
                if _ends_with_cli_prompt(b"".join(chunks).decode("utf-8", errors="replace")):
                    break
                continue
            if self.channel.closed:
                break
            time.sleep(0.05)
        return b"".join(chunks).decode("utf-8", errors="replace")


class EntwareShell:
    def __init__(self, host: str, username: str, password: str, port: int = 222, timeout: float = 10.0):
        self.host = validate_hostname(host)
        key = probe_host_key(host, port, timeout)
        try:
            verify_host_key(host, key, port)
        except UnknownHostKey:
            trust_host_key(host, key, port)
        self.client = paramiko.SSHClient()
        self.client.load_host_keys(str(app_data_dir() / "known_hosts"))
        self.client.set_missing_host_key_policy(paramiko.RejectPolicy())
        self.client.connect(
            hostname=host,
            port=port,
            username=username,
            password=password,
            look_for_keys=False,
            allow_agent=False,
            timeout=timeout,
            auth_timeout=timeout,
            banner_timeout=timeout,
        )

    def close(self) -> None:
        self.client.close()

    def command(self, command: str, timeout: float = 120.0) -> tuple[int, str, str]:
        stdin, stdout, stderr = self.client.exec_command(command, timeout=timeout)
        stdin.close()
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        code = stdout.channel.recv_exit_status()
        return code, out, err

def is_port_open(host: str, port: int, timeout: float = 0.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def wait_for_port(
    host: str,
    port: int,
    timeout: float,
    want_open: bool = True,
    callback: Callable[[int], None] | None = None,
) -> bool:
    started = time.monotonic()
    last_report = -1
    while time.monotonic() - started < timeout:
        state = is_port_open(host, port, timeout=0.8)
        if state == want_open:
            return True
        elapsed = int(time.monotonic() - started)
        if callback and elapsed // 10 != last_report:
            last_report = elapsed // 10
            callback(elapsed)
        time.sleep(2.0)
    return False


def discover_keenetic() -> list[DiscoveredHost]:
    candidates: dict[str, str] = {}
    for name, label in (("my.keenetic.net", "my.keenetic.net"), ("keenetic.local", "keenetic.local")):
        try:
            address = socket.gethostbyname(name)
            if _is_private_ipv4(address):
                candidates[address] = label
        except OSError:
            pass
    for gateway in _default_gateways():
        candidates.setdefault(gateway, "Varsayılan ağ geçidi")

    local_ips = _local_ipv4_addresses()
    scan_ips: set[str] = set(candidates)
    for local_ip in local_ips:
        network = ipaddress.ip_network(f"{local_ip}/24", strict=False)
        scan_ips.update(str(item) for item in network.hosts())

    results: list[DiscoveredHost] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=64) as pool:
        future_map = {pool.submit(_probe_candidate, ip): ip for ip in scan_ips}
        for future in concurrent.futures.as_completed(future_map):
            host = future_map[future]
            try:
                ssh22, web_hint = future.result()
            except OSError:
                continue
            if ssh22 and (web_hint or host in candidates):
                results.append(
                    DiscoveredHost(host, candidates.get(host, "Yerel ağdaki olası Keenetic"), ssh22, web_hint)
                )
    results.sort(key=lambda item: (0 if item.host in candidates else 1, tuple(int(x) for x in item.host.split("."))))
    return results


def _probe_candidate(host: str) -> tuple[bool, bool]:
    ssh22 = is_port_open(host, 22, 0.22)
    if not ssh22:
        return False, False
    return True, _keenetic_web_hint(host)


def _keenetic_web_hint(host: str) -> bool:
    for port, tls in ((80, False), (443, True)):
        try:
            raw = socket.create_connection((host, port), timeout=0.3)
            if tls:
                import ssl

                context = ssl.create_default_context()
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
                sock = context.wrap_socket(raw, server_hostname=host)
            else:
                sock = raw
            with sock:
                sock.settimeout(0.5)
                sock.sendall(b"GET / HTTP/1.0\r\nHost: my.keenetic.net\r\n\r\n")
                data = sock.recv(4096).lower()
                if b"keenetic" in data or b"ndm" in data or b"x-ndm" in data:
                    return True
        except OSError:
            continue
    return False


def _default_gateways() -> list[str]:
    output = ""
    try:
        output = subprocess.run(
            ["route", "print", "-4"], capture_output=True, text=True, timeout=4, creationflags=0x08000000
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    gateways: list[str] = []
    for line in output.splitlines():
        match = re.match(r"^\s*0\.0\.0\.0\s+0\.0\.0\.0\s+(\d+\.\d+\.\d+\.\d+)\s+", line)
        if match and _is_private_ipv4(match.group(1)) and match.group(1) not in gateways:
            gateways.append(match.group(1))
    return gateways


def _local_ipv4_addresses() -> list[str]:
    addresses: set[str] = set()
    try:
        for item in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            address = item[4][0]
            if _is_private_ipv4(address):
                addresses.add(address)
    except OSError:
        pass
    return sorted(addresses)


def _is_private_ipv4(value: str) -> bool:
    try:
        address = ipaddress.ip_address(value)
        return address.version == 4 and address.is_private and not address.is_loopback
    except ValueError:
        return False


def _clean_command_output(output: str, command: str) -> str:
    output = strip_ansi(output)
    lines = output.splitlines()
    cleaned: list[str] = []
    skipped_echo = False
    for line in lines:
        compact = line.strip()
        if not skipped_echo and compact == command:
            skipped_echo = True
            continue
        if re.fullmatch(r"\([^)]*\)>\s*", compact):
            continue
        cleaned.append(line.rstrip())
    return "\n".join(cleaned).strip()


def _ends_with_cli_prompt(output: str) -> bool:
    """Return true only when a complete Keenetic CLI prompt is at the end."""

    clean = strip_ansi(output).replace("\r", "")
    return re.search(r"(?:^|\n)\s*\([^\n)]{1,80}\)>\s*$", clean) is not None
