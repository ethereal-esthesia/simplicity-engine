"""Exercise the iOS backend with simctl responses and no simulator side effects."""
import io
import json
from pathlib import Path
import subprocess
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

SOURCE = (Path(__file__).resolve().parents[1] / 'scripts/impl/dev_setup/ios.sh').read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]

class IOSSetupTests(unittest.TestCase):
    def test_creation_uses_runtime_supported_models_and_reuses_devices(self):
        current = {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-5', 'name': 'iOS 26.5', 'version': '26.5', 'isAvailable': True,
                   'supportedDeviceTypes': [{'name': 'iPhone 17 Pro', 'identifier': 'phone-new'}]}
        old = dict(current, version='9.0', identifier='com.apple.CoreSimulator.SimRuntime.iOS-9-0')
        devices = []
        def check(command, **kwargs):
            kind = command[3]
            return json.dumps({'runtimes': [current, old]} if kind == 'runtimes' else {'devices': {current['identifier']: devices}})
        with patch('sys.argv', ['-', '1', '1']), patch('subprocess.check_output', side_effect=check), patch('subprocess.run', return_value=subprocess.CompletedProcess([], 0, 'uuid\n', '')) as create, redirect_stdout(io.StringIO()):
            exec(SOURCE, {})
            self.assertEqual([c.args[0][4] for c in create.call_args_list], ['phone-new'])
            self.assertTrue(all(c.args[0][5] == current['identifier'] for c in create.call_args_list))
            devices.extend([{'name': f'{family} Simplicity', 'isAvailable': True, 'udid': family} for family in ['iPhone']])
            create.reset_mock()
            exec(SOURCE, {})
            create.assert_not_called()

if __name__ == '__main__': unittest.main()
