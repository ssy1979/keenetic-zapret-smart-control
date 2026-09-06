"""Regressions for incomplete, inconsistent and over-broad release packaging."""
import importlib.util
from pathlib import Path
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("release_contract", Path(__file__).resolve().parents[1] / "tools/release_contract.py")
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)


class ReleaseContractTests(unittest.TestCase):
    def payload(self):
        result = {p: b"#!/bin/sh\n# 0.11.2.55-generic\n" for p in contract.REQUIRED}
        result.update({p: b"# 0.11.2.55-generic\n" for p in contract.VERSION_FILES})
        result[contract.VERSION_FILE] = b'VERSION="0.11.2.55-generic"\n'
        return result

    def test_missing_backend_is_rejected_even_with_matching_manifest(self):
        files = self.payload()
        del files["opt/kzsc/bin/kzsc-purity.sh"]
        contract.verify_manifest(files, contract.manifest_for(files))
        with self.assertRaisesRegex(ValueError, "kzsc-purity"):
            contract.validate_payload(files, "0.11.2.55-generic")

    def test_stale_telegram_version_is_rejected(self):
        files = self.payload()
        files["opt/kzsc/bin/kzsc-telegram.sh"] = b"# 0.11.2.54-generic\n"
        with self.assertRaisesRegex(ValueError, "Version mismatch"):
            contract.validate_payload(files, "0.11.2.55-generic")

    def test_unlisted_file_and_duplicate_hash_line_are_rejected(self):
        files = self.payload()
        manifest = contract.manifest_for(files)
        files["opt/kzsc/bin/injected.sh"] = b"unexpected"
        with self.assertRaisesRegex(ValueError, "coverage"):
            contract.verify_manifest(files, manifest)
        del files["opt/kzsc/bin/injected.sh"]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            contract.verify_manifest(files, manifest + manifest.splitlines(keepends=True)[0])

    def test_unshipped_literal_dependency_is_rejected(self):
        files = self.payload()
        files["opt/kzsc/bin/kzsc"] += b"/opt/kzsc/bin/kzsc-missing.sh check\n"
        with self.assertRaisesRegex(ValueError, "Missing dependency"):
            contract.validate_payload(files, "0.11.2.55-generic")

    def test_archive_excludes_tools_builds_and_docs_and_covers_every_file(self):
        files = self.payload()
        files.update({"local-build/nested.tar.gz": b"large", "tools/app.py": b"python", "docs/test.md": b"doc"})
        with tempfile.TemporaryDirectory() as temp:
            archive = contract.build_router(files, "0.11.2.55-generic", Path(temp))
            with tarfile.open(archive) as tar:
                names = [m.name for m in tar.getmembers()]
                self.assertFalse(any("local-build" in n or "/tools/" in n or "/docs/" in n for n in names))
                self.assertTrue(any(n.endswith("/kzsc-purity.sh") for n in names))
            self.assertTrue(archive.with_name(archive.name + ".sha256").exists())


if __name__ == "__main__":
    unittest.main()
