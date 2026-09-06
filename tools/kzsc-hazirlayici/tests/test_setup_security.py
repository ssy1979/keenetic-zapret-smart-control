from __future__ import annotations

import hashlib
import io
import sys
import tarfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import InstallationIncomplete, KzscApp
from core import KzscRelease, DeviceInfo, SetupPlan, sanitize_diagnostic
from release import REQUIRED_PAYLOAD, validate_release_payload
from transport import EntwareShell, KeeneticCli


TAG = "v0.11.2.55-generic"
ROOT = f"keenetic-zapret-smart-control-{TAG}"
RELEASE = KzscRelease(TAG, TAG[1:], ROOT + ".tar.gz", ROOT + ".tar.gz.sha256", ROOT,
                      "https://github.com/archive", "https://github.com/checksum", "https://github.com/release", 1)


def payload(*, change=None, manifest_change=None, extra=None):
    files = {path: b"#!/bin/sh\nexit 0\n" for path in REQUIRED_PAYLOAD}
    files["opt/kzsc/bin/kzsc-maintenance.sh"] = b'#!/bin/sh\nVERSION="0.11.2.55-generic"\n'
    if change:
        change(files)
    manifest = "".join(hashlib.sha256(data).hexdigest() + "  ./" + path + "\n" for path, data in sorted(files.items()))
    if manifest_change:
        manifest = manifest_change(manifest)
    files["SHA256SUMS"] = manifest.encode()
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        for path, data in files.items():
            member = tarfile.TarInfo(ROOT + "/" + path)
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
        if extra:
            extra(archive)
    archive = output.getvalue()
    checksum = f"{hashlib.sha256(archive).hexdigest()}  {RELEASE.archive_name}\n".encode()
    return replace(RELEASE, archive_size=len(archive)), archive, checksum


class PackageSecurityTests(unittest.TestCase):
    def test_complete_payload_is_accepted_without_extracting(self):
        release, archive, checksum = payload()
        self.assertEqual(validate_release_payload(release, archive, checksum), hashlib.sha256(archive).hexdigest())

    def test_missing_purity_reproduces_broken_v54_and_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Missing required.*purity"):
            validate_release_payload(*payload(change=lambda files: files.pop("opt/kzsc/bin/kzsc-purity.sh")))

    def test_unlisted_files_and_manifest_outside_root_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "cover every"):
            validate_release_payload(*payload(manifest_change=lambda text: "\n".join(text.splitlines()[1:]) + "\n"))
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            validate_release_payload(*payload(manifest_change=lambda text: text.replace("./install.sh", "../../install.sh")))

    def test_duplicate_manifest_entry_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            validate_release_payload(*payload(manifest_change=lambda text: text + text.splitlines()[0] + "\n"))

    def test_manifest_hash_tampering_rejected(self):
        with self.assertRaisesRegex(ValueError, "Internal SHA-256"):
            validate_release_payload(*payload(manifest_change=lambda text: "0" * 64 + text[64:]))

    def test_links_devices_and_fifos_rejected(self):
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.CHRTYPE, tarfile.FIFOTYPE):
            def add(archive):
                member = tarfile.TarInfo(ROOT + "/opt/kzsc/extra")
                member.type = kind
                member.linkname = "/etc/passwd"
                archive.addfile(member)
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "entry type"):
                validate_release_payload(*payload(extra=add))

    def test_duplicate_tar_and_traversal_rejected(self):
        for path in (ROOT + "/install.sh", ROOT + "/../outside", "/outside"):
            def add(archive):
                archive.addfile(tarfile.TarInfo(path), io.BytesIO())
            with self.subTest(path=path), self.assertRaises(ValueError):
                validate_release_payload(*payload(extra=add))

    def test_missing_literal_runtime_dependency_rejected(self):
        def modify(files):
            files["install.sh"] = b"#!/bin/sh\n/opt/kzsc/bin/kzsc-missing.sh check\n"
        with self.assertRaisesRegex(ValueError, "Missing runtime dependency"):
            validate_release_payload(*payload(change=modify))

    def test_stale_declared_version_rejected(self):
        def modify(files):
            files["opt/kzsc/bin/kzsc-maintenance.sh"] = b'VERSION="0.11.2.54-generic"\n'
        with self.assertRaisesRegex(ValueError, "version does not match"):
            validate_release_payload(*payload(change=modify))

    def test_decompression_limit_includes_tar_headers(self):
        with patch("release.MAX_TAR_BYTES", 100), self.assertRaisesRegex(ValueError, "Decompressed tar"):
            validate_release_payload(*payload())

    def test_external_checksum_and_metadata_size_enforced(self):
        release, archive, checksum = payload()
        with self.assertRaisesRegex(ValueError, "External SHA-256"):
            validate_release_payload(release, archive, b"0" * 64 + checksum[64:])
        with self.assertRaisesRegex(ValueError, "size"):
            validate_release_payload(replace(release, archive_size=1), archive, checksum)


class SetupCompletionTests(unittest.TestCase):
    def app(self):
        app = KzscApp.__new__(KzscApp)
        app.language_code = "en"
        app.run_config = {"host": "192.168.1.1", "pass22": "admin-secret", "pass222": "root-secret", "install_kzsc_requested": True}
        app._post = MagicMock()
        app._write_report = MagicMock()
        return app

    def test_bad_release_is_rejected_before_any_router_write(self):
        app = self.app()
        app.info = DeviceInfo(host="192.168.1.1")
        app.plan = SetupPlan(["opkg"], [], [], "", "", [], [])
        app._resolve_latest_kzsc_release = MagicMock(return_value=RELEASE)
        app._new_cli = MagicMock()
        with patch("app.download_bounded", return_value=b"bad"), patch("app.validate_release_payload", side_effect=ValueError("broken package")):
            app._setup_worker()
        app._new_cli.assert_not_called()
        self.assertIn("broken package", str(app._post.call_args_list))

    def test_failed_final_audit_is_partial_install_not_success(self):
        app = self.app()
        app._wait_kzsc_ready = MagicMock()
        shell = MagicMock()
        shell.command.side_effect = [(0, "KZSC_INSTALL_STARTED=1\n", ""), (1, "FAIL audit", "")]
        with self.assertRaises(InstallationIncomplete) as error:
            app._install_kzsc(shell, [], RELEASE, "a" * 64)
        self.assertIn("KZSC files were installed", str(error.exception))
        self.assertIn("kuruldu", error.exception.title)
        self.assertIn("[ \"$actual\" = '" + "a" * 64 + "' ]", shell.command.call_args_list[0].args[0])

    def test_success_requires_status_preflight_full_audit(self):
        app = self.app()
        app._wait_kzsc_ready = MagicMock()
        shell = MagicMock()
        shell.command.side_effect = [(0, "KZSC_INSTALL_STARTED=1\n", ""), (0, "PASS", "")]
        report = []
        self.assertIs(app._install_kzsc(shell, report, RELEASE, "a" * 64), shell)
        verify = shell.command.call_args_list[-1].args[0]
        self.assertIn("kzsc status; /opt/bin/kzsc preflight; /opt/bin/kzsc audit full", verify)
        self.assertTrue(report)

    def test_reboot_pending_must_reconnect_and_validate_before_success(self):
        app = self.app()
        app._wait_kzsc_ready = MagicMock()
        first, resumed = MagicMock(), MagicMock()
        first.command.side_effect = [(0, "KZSC_REBOOT_PENDING=1\n", ""), (0, "reboot scheduled", "")]
        resumed.command.return_value = (0, "PASS", "")
        app._new_entware_shell = MagicMock(return_value=resumed)
        with patch("app.wait_for_port", return_value=True):
            self.assertIs(app._install_kzsc(first, [], RELEASE, "a" * 64), resumed)
        app._wait_kzsc_ready.assert_called_once_with(resumed, RELEASE, timeout=600)
        self.assertIn("audit full", resumed.command.call_args.args[0])

    def test_reboot_failure_never_reports_success(self):
        app = self.app()
        first = MagicMock()
        first.command.side_effect = [(0, "KZSC_REBOOT_PENDING=1\n", ""), (1, "reboot rejected", "")]
        with self.assertRaisesRegex(InstallationIncomplete, "could not restart"):
            app._install_kzsc(first, [], RELEASE, "a" * 64)

    def test_translated_diagnostics_remove_passwords_and_tokens(self):
        app = self.app()
        text = app._diagnostic('admin-secret root-secret password=other-secret\nBearer ABCDEF\nhttps://u:pass@router/test\n123456789:abcdefghijklmnopqrstuvwxyzABCDE')
        for secret in ("admin-secret", "root-secret", "other-secret", "ABCDEF", "u:pass", "abcdefghijklmnopqrstuvwxyz"):
            self.assertNotIn(secret, text)
        self.assertEqual(app._t("KZSC kurulumunun tamamlandığı doğrulanamadı"), "KZSC installation completion could not be confirmed")
        self.assertNotIn("\x1b", sanitize_diagnostic("\x1b[31mFAIL\x1b[0m\x1b]0;hidden\x07"))


class TransportCompletionTests(unittest.TestCase):
    def test_cli_partial_output_does_not_become_a_successful_reply(self):
        cli = KeeneticCli.__new__(KeeneticCli)
        cli.channel = MagicMock(closed=True)
        cli.channel.recv_ready.return_value = False
        cli.close = MagicMock()
        with self.assertRaises(TimeoutError):
            cli._read_until_prompt(1)
        cli.close.assert_called_once()

    def test_cli_complete_prompt_is_returned(self):
        cli = KeeneticCli.__new__(KeeneticCli)
        cli.channel = MagicMock(closed=False)
        cli.channel.recv_ready.return_value = True
        cli.channel.recv.return_value = b"done\n(config)> "
        self.assertIn("done", cli._read_until_prompt(1))

    def test_entware_drains_both_streams_before_exit(self):
        shell = EntwareShell.__new__(EntwareShell)
        shell.client = MagicMock()
        stdin, stdout, stderr = MagicMock(), MagicMock(), MagicMock()
        channel = stdout.channel
        channel.recv_ready.side_effect = [True, False]
        channel.recv_stderr_ready.side_effect = [True, False]
        channel.recv.return_value = b"stdout"
        channel.recv_stderr.return_value = b"stderr"
        channel.exit_status_ready.return_value = True
        channel.recv_exit_status.return_value = 7
        shell.client.exec_command.return_value = stdin, stdout, stderr
        self.assertEqual(shell.command("test", 1), (7, "stdout", "stderr"))
        stdout.read.assert_not_called()
        stderr.read.assert_not_called()
        channel.close.assert_called_once()

    def test_entware_total_deadline_closes_session(self):
        shell = EntwareShell.__new__(EntwareShell)
        shell.client = MagicMock()
        stdin, stdout, stderr = MagicMock(), MagicMock(), MagicMock()
        stdout.channel.recv_ready.return_value = False
        stdout.channel.recv_stderr_ready.return_value = False
        stdout.channel.exit_status_ready.return_value = False
        shell.client.exec_command.return_value = stdin, stdout, stderr
        with patch("transport.time.monotonic", side_effect=[0, 2]), self.assertRaises(TimeoutError):
            shell.command("test", 1)
        stdout.channel.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
