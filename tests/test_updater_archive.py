import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
UPDATER = ROOT / 'opt/kzsc/bin/kzsc-updater.sh'
SHELL = shutil.which('sh') or (r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else None)


def shell_path(path):
    value = Path(path).resolve().as_posix()
    return f'/{value[0].lower()}{value[2:]}' if os.name == 'nt' else value


@unittest.skipUnless(SHELL, 'POSIX shell required')
class UpdaterArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = UPDATER.read_text(encoding='utf-8')
        self.functions = source[source.index('archive_safe(){'):source.index('apply_update(){')]
        self.prefix = 'keenetic-zapret-smart-control-v0.11.2.55-generic'

    def run_guard(self, name, *args):
        command = self.functions + '\n' + name + ' "$1" "$2" "$3"\n'
        result = subprocess.run([SHELL, '-c', command, 'guard', *args], capture_output=True, timeout=20)
        return result.returncode

    def archive(self, members):
        archive = self.root / 'test.tar.gz'
        with tarfile.open(archive, 'w:gz', format=tarfile.USTAR_FORMAT) as tar:
            for name, kind in members:
                info = tarfile.TarInfo(name)
                info.type = kind
                info.size = 1 if kind == tarfile.REGTYPE else 0
                if kind == tarfile.SYMTYPE:
                    info.linkname = '/tmp/elsewhere'
                tar.addfile(info, io.BytesIO(b'x') if info.size else None)
        return self.run_guard('archive_safe', shell_path(archive), self.prefix, shell_path(self.root / 'list'))

    def test_regular_archive_is_accepted(self):
        self.assertEqual(0, self.archive([(f'{self.prefix}/install.sh', tarfile.REGTYPE)]))

    def test_fifo_symlink_and_duplicate_entries_are_rejected(self):
        for kind in (tarfile.FIFOTYPE, tarfile.SYMTYPE, tarfile.CHRTYPE):
            with self.subTest(kind=kind):
                self.assertNotEqual(0, self.archive([(f'{self.prefix}/special', kind)]))
        self.assertNotEqual(0, self.archive([(f'{self.prefix}/install.sh', tarfile.REGTYPE)] * 2))

    def test_traversal_is_rejected(self):
        self.assertNotEqual(0, self.archive([(f'{self.prefix}/../outside', tarfile.REGTYPE)]))

    def test_complete_manifest_passes_extra_files_and_escape_fail(self):
        payload = self.root / 'payload'
        payload.mkdir()
        (payload / 'install.sh').write_bytes(b'#!/bin/sh\n')
        digest = hashlib.sha256((payload / 'install.sh').read_bytes()).hexdigest()
        manifest = payload / 'SHA256SUMS'
        manifest.write_bytes(f'{digest}  ./install.sh\n'.encode('ascii'))
        self.assertEqual(0, self.run_guard('manifest_safe', shell_path(payload)))
        extra = payload / 'unlisted.sh'
        extra.write_bytes(b'code')
        self.assertNotEqual(0, self.run_guard('manifest_safe', shell_path(payload)))
        extra.unlink()
        manifest.write_bytes(f'{digest}  ../install.sh\n'.encode('ascii'))
        self.assertNotEqual(0, self.run_guard('manifest_safe', shell_path(payload)))


if __name__ == '__main__':
    unittest.main()
