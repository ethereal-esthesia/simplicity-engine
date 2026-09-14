"""Setup regression checks: isolated mocks never install packages or boot VMs."""
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/impl/dev_setup/main.py'
spec = importlib.util.spec_from_file_location('dev_setup', SCRIPT)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)

class SetupTests(unittest.TestCase):
    def invoke(self, arguments, system='Darwin'):
        output = io.StringIO()
        with patch('sys.argv', [str(SCRIPT), *arguments]), patch.object(setup.platform, 'system', return_value=system), redirect_stdout(output):
            result = setup.main()
        return result, output.getvalue()

    def test_check_does_not_create_storage(self):
        with tempfile.TemporaryDirectory() as directory:
            storage = Path(directory) / 'absent'
            with patch.object(setup.shutil, 'which', return_value=None):
                result, output = self.invoke(['--target', 'ios', '--check', '--storage', str(storage)])
            self.assertEqual(result, 3)
            self.assertFalse(storage.exists())
            self.assertIn('xcrun is missing', output)

    def test_wrong_host_has_no_installer_side_effect(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(setup.subprocess, 'Popen') as run:
            result, _ = self.invoke(['--target', 'linux', '--check', '--storage', directory])
            self.assertEqual(result, 3)
            run.assert_not_called()

    def test_vm_bundle_is_not_proof_of_guest_readiness(self):
        with tempfile.TemporaryDirectory() as directory:
            vm = Path(directory) / 'Example.utm'
            vm.mkdir(); (vm / 'config.plist').write_text('fixture')
            real_is_dir = Path.is_dir
            def is_dir(path):
                return True if str(path) == '/Applications/UTM.app' else real_is_dir(path)
            with patch.object(Path, 'is_dir', is_dir), patch.object(setup.subprocess, 'Popen') as run:
                result, output = self.invoke(['--target', 'linux', '--vm', '--vm-path', str(vm), '--check', '--storage', directory])
            self.assertEqual(result, 3)
            self.assertIn('VM found', output)
            run.assert_not_called()

    def test_unmounted_external_storage_is_rejected(self):
        with patch.object(Path, 'is_mount', return_value=False):
            result, output = self.invoke(['--target', 'macos', '--storage', '/Volumes/Absent/Simplicity'])
        self.assertEqual(result, 3)
        self.assertIn('not mounted', output)

    def test_partial_setup_writes_log_and_can_resume(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(setup.shutil, 'which', return_value=None):
            args = ['--target', 'ios', '--storage', directory]
            self.assertEqual(self.invoke(args)[0], 3)
            self.assertEqual(self.invoke(args)[0], 3)
            self.assertEqual(len(list((Path(directory) / 'logs').glob('*.log'))), 2)

    def test_guest_options_cannot_run_without_vm(self):
        with self.assertRaises(SystemExit) as error:
            self.invoke(['--target', 'linux', '--guest', 'user@host', '--guest-repo', '/repo'])
        self.assertEqual(error.exception.code, 2)

if __name__ == '__main__':
    unittest.main()
