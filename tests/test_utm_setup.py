import importlib.util
import plistlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('utm_setup', Path(__file__).resolve().parents[1] / 'scripts/impl/dev_setup/utm.py')
utm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(utm)

class UTMTests(unittest.TestCase):
    def fixture(self, vm):
        (vm / 'Data').mkdir(parents=True)
        (vm / 'Data/system.qcow2').write_bytes(b'disk sentinel')
        config = {'Backend': 'QEMU', 'Information': {'UUID': 'test-id'}, 'System': {'MemorySize': 4096, 'CPUCount': 4},
                  'Drive': [{'ImageType': 'CD'}, {'ImageName': 'system.qcow2'}]}
        (vm / 'config.plist').write_bytes(plistlib.dumps(config))

    def test_existing_disk_preserved_when_attaching_media(self):
        with tempfile.TemporaryDirectory() as folder:
            vm = Path(folder) / 'VM with spaces.utm'; self.fixture(vm)
            iso = Path(folder) / 'image with spaces.iso'; iso.write_bytes(b'iso')
            with patch.object(utm, 'script', return_value='0') as script, patch.object(utm.subprocess, 'run'):
                utm.prepare(vm, iso, 'linux', 8192, 8, 128, lambda _: None)
            self.assertEqual((vm / 'Data/system.qcow2').read_bytes(), b'disk sentinel')
            self.assertEqual(utm.read_config(vm)['System']['MemorySize'], 4096)
            self.assertNotIn('create_utm.applescript', [c.args[0] for c in script.call_args_list])
            self.assertEqual(script.call_args_list[-1].args[-1], iso.resolve())

    def test_guest_tools_download_is_cached(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder)
            def download(command, **kwargs):
                output = Path(command[command.index('--output') + 1])
                output.write_bytes(bytes(32769) + b'CD001' + bytes(100))
            with patch.object(utm.subprocess, 'run', side_effect=download) as run:
                first = utm.tools_iso(cache, lambda _: None)
                second = utm.tools_iso(cache, lambda _: None)
            self.assertEqual(first, second)
            self.assertEqual(run.call_count, 1)

    def test_tools_addition_preserves_installer_and_system_disk(self):
        with tempfile.TemporaryDirectory() as folder:
            vm = Path(folder) / 'VM.utm'; self.fixture(vm)
            iso = Path(folder) / 'tools.iso'; iso.write_bytes(b'iso')
            original = utm.read_config(vm)['Drive']
            def attach(*args):
                config = utm.read_config(vm)
                config['Drive'].append({'ImageType': 'CD', 'Identifier': 'tools'})
                (vm / 'config.plist').write_bytes(plistlib.dumps(config))
                return '0'
            with patch.object(utm, 'script', side_effect=attach):
                utm.attach_tools(vm, 'test-id', iso, lambda _: None)
            self.assertEqual(utm.read_config(vm)['Drive'][:2], original)

    def test_export_without_disk_cannot_delete_staging(self):
        with tempfile.TemporaryDirectory() as folder:
            vm = Path(folder) / 'VM.utm'; self.fixture(vm)
            (vm / 'Data/system.qcow2').unlink()
            with self.assertRaisesRegex(RuntimeError, 'missing its system disk'):
                utm.verify_created(vm, 4096, 4)

    def test_partial_destination_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            vm = Path(folder) / 'VM.utm'; vm.mkdir()
            with self.assertRaisesRegex(RuntimeError, 'Nothing overwritten'):
                utm.prepare(vm, None, 'linux', 4096, 4, 64, print)

    def test_missing_media_does_not_create_vm(self):
        with tempfile.TemporaryDirectory() as folder:
            vm = Path(folder) / 'VM.utm'
            with self.assertRaisesRegex(RuntimeError, 'require --media'):
                utm.prepare(vm, None, 'linux', 4096, 4, 64, print)
            self.assertFalse(vm.exists())

if __name__ == '__main__': unittest.main()
