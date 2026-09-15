"""Developer setup orchestration; standard library only. --check never writes files."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
from datetime import datetime

ROOT = Path(__file__).resolve().parents[3]
BACKENDS = Path(__file__).resolve().parent

class Incomplete(Exception):
    pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True, choices=['macos', 'linux', 'windows', 'android', 'ios'])
    parser.add_argument('--vm', action='store_true', help='Prepare/reuse a UTM desktop VM on macOS')
    parser.add_argument('--check', action='store_true', help='Read-only prerequisite and environment check')
    parser.add_argument('--storage', type=Path, default=Path(os.environ.get('SIMPLICITY_STORAGE', ROOT / 'local/dev')))
    parser.add_argument('--vm-path', type=Path, help='Existing .utm bundle; never imports or modifies other VM formats')
    parser.add_argument('--media', type=Path, help='Linux/Windows installation ISO; attached without copying')
    parser.add_argument('--device', choices=['phone'], default='phone')
    parser.add_argument('--guest', help='For an existing Unix guest: SSH user@hostname with this checkout already available')
    parser.add_argument('--guest-repo', help='Absolute path to this checkout inside the SSH guest')
    parser.add_argument('--ram', type=int, default=4096, help='New VM RAM in MiB')
    parser.add_argument('--cpus', type=int, default=4, help='New VM CPU cores')
    parser.add_argument('--disk', type=int, default=64, help='New VM disk capacity in GiB')
    args = parser.parse_args()
    if (args.vm_path or args.media or args.guest or args.guest_repo) and not args.vm:
        parser.error('--vm-path, --media and --guest options require --vm')
    if args.vm and args.target not in ('macos', 'linux', 'windows'):
        parser.error('--vm applies only to desktop targets')
    if bool(args.guest) != bool(args.guest_repo):
        parser.error('--guest and --guest-repo must be supplied together')
    if args.guest and (args.target == 'windows' or args.guest.startswith('-') or not args.guest_repo.startswith('/')):
        parser.error('--guest requires a Unix target, SSH destination, and absolute --guest-repo')
    if args.ram < 1024 or args.cpus < 1 or args.disk < 16:
        parser.error('Use at least 1024 MiB RAM, one CPU core, and 16 GiB disk.')
    host = {'Darwin': 'macos', 'Linux': 'linux', 'Windows': 'windows'}.get(platform.system())
    storage = args.storage.expanduser().absolute()
    if str(storage).startswith('/Volumes/'):
        volume = Path(*storage.parts[:3])
        if not volume.is_mount():
            print(f'SETUP INCOMPLETE: external volume is not mounted: {volume}')
            return 3
    log = None
    def say(message):
        print(message, flush=True)
        if log:
            log.write(message + '\n'); log.flush()
    def run(command, env=None):
        say('+ ' + ' '.join(map(str, command)))
        # Keep stdin for sudo/license prompts; mirror output into the setup log.
        proc = subprocess.Popen(list(map(str, command)), stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, env=env)
        for line in proc.stdout:
            say(line.rstrip())
        if proc.wait():
            raise RuntimeError(f'Command exited {proc.returncode}: {command[0]}')
    def require(tool):
        if not shutil.which(tool):
            raise Incomplete(f'{tool} is missing. Install it, then rerun this command.')
    def read_json(command):
        return json.loads(subprocess.check_output(command, text=True))
    try:
        if not args.check:
            storage.mkdir(parents=True, exist_ok=True)
            (storage / 'logs').mkdir(exist_ok=True)
            logpath = storage / 'logs' / (datetime.now().strftime('%Y%m%d-%H%M%S-%f') + f'-{args.target}.log')
            log = logpath.open('w')
            say(f'Log: {logpath}')
        say(f'Target: {args.target}{" VM" if args.vm else ""}; storage: {storage}')
        if args.vm:
            if host != 'macos':
                raise Incomplete('This VM backend requires a Mac host. Native Linux/Windows setup can run inside an existing VM.')
            if args.target == 'macos' and platform.machine() != 'arm64':
                raise Incomplete('The macOS VM backend requires Apple Silicon.')
            utm = next((p for p in (Path('/Applications/UTM.app'), Path.home() / 'Applications/UTM.app') if p.is_dir()), None)
            if not utm:
                if args.check:
                    raise Incomplete('UTM is missing. Run setup without --check to install it through Homebrew.')
                require('brew')
                run(['brew', 'install', '--cask', 'utm'])
                utm = Path('/Applications/UTM.app')
                if not utm.exists():
                    raise Incomplete('UTM installation was not found in /Applications; locate the application before continuing.')
            vm = args.vm_path.expanduser().absolute() if args.vm_path else storage / 'vms' / f'Simplicity-{args.target}.utm'
            if args.media and not args.media.expanduser().is_file():
                raise Incomplete(f'Media does not exist: {args.media}')
            if args.check:
                if not (vm / 'config.plist').is_file():
                    raise Incomplete(f'VM missing: {vm}. Run without --check and supply --media for Linux/Windows.')
            elif args.target != 'macos':
                from utm import prepare
                prepare(vm, args.media, args.target, args.ram, args.cpus, args.disk, say, storage=storage)
            elif args.media or not (vm / 'config.plist').is_file():
                raise Incomplete('UTM scripting does not expose macOS IPSW installation. Create macOS in UTM and rerun with --vm-path pointing to it, without --media.')
            say(f'Existing VM: {vm}')
            if args.guest:
                import shlex
                command = f'cd {shlex.quote(args.guest_repo)} && ./scripts/dev-setup.sh --target {args.target}'
                if args.check:
                    # No SSH connections/known_hosts changes in read-only mode.
                    say('Guest provisioning configured; readiness has not been checked remotely.')
                    raise Incomplete('Run without --check to provision the guest over SSH.')
                require('ssh')
                run(['open', str(vm)])
                # SSH retains its normal authentication and host-key confirmation.
                result = subprocess.call(['ssh', '-t', args.guest, command])
                if result:
                    raise Incomplete('Guest not reachable or provisioning incomplete. Wait for boot and rerun; no VM is recreated.')
            else:
                if not args.check:
                    run(['open', str(vm)])
                raise Incomplete('VM found. Run setup inside the guest, or supply --guest and --guest-repo for Unix provisioning.')
        elif args.target in ('macos', 'linux', 'windows'):
            if host != args.target:
                raise Incomplete(f'Run this target inside {args.target}, or use --vm on a Mac.')
            if host == 'windows':
                raise Incomplete('Use scripts/dev-setup.ps1 in PowerShell on Windows.')
            run(['bash', BACKENDS / 'host.sh', '--check' if args.check else '--install'])
        elif args.target == 'ios':
            if host != 'macos':
                raise Incomplete('iOS simulators require macOS and full Xcode.')
            require('xcrun')
            run(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
            runtimes = read_json(['xcrun', 'simctl', 'list', 'runtimes', '-j'])['runtimes']
            if not any(r.get('isAvailable') and '.iOS-' in r['identifier'] for r in runtimes):
                raise Incomplete('Install an iOS runtime with xcodebuild -downloadPlatform iOS, then rerun.')
            if args.check:
                devices = read_json(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'])['devices']
                for family in ['iPhone']:
                    if not any(d['name'].startswith(family) for k, group in devices.items() if 'iOS' in k for d in group):
                        raise Incomplete(f'No {family} simulator; run setup without --check.')
            else:
                run(['bash', BACKENDS / 'ios.sh', '--' + args.device])
        else:
            default_sdk = Path.home() / ('Library/Android/sdk' if host == 'macos' else 'Android/Sdk')
            sdk = Path(os.environ.get('ANDROID_SDK_ROOT', os.environ.get('ANDROID_HOME', default_sdk)))
            if not (sdk / 'cmdline-tools/latest/bin/sdkmanager').is_file():
                raise Incomplete(f'Install Android SDK Command-line Tools (latest) in Android Studio at {sdk}, or set ANDROID_SDK_ROOT.')
            env = dict(os.environ, ANDROID_SDK_ROOT=str(sdk), SIMPLICITY_STORAGE=str(storage))
            if args.check:
                abi = 'arm64-v8a' if platform.machine() in ('arm64', 'aarch64') else 'x86_64'
                for relative in ['platform-tools/adb', 'emulator/emulator', 'platforms/android-36/android.jar', 'build-tools/36.0.0', 'ndk/27.2.12479018', 'cmake/3.22.1', f'system-images/android-36.1/google_apis/{abi}/system.img']:
                    if not (sdk / relative).exists():
                        raise Incomplete(f'Missing Android dependency: {relative}. Run setup without --check.')
                for lane in ['phone']:
                    if not (Path(os.environ.get('ANDROID_AVD_HOME', str(Path.home() / '.android/avd'))) / f'Simplicity_{lane}.ini').is_file():
                        raise Incomplete(f'Simplicity_{lane} AVD missing. Run setup without --check.')
                require('java')
            else:
                (storage / 'avd').mkdir(exist_ok=True)
                run(['bash', BACKENDS / 'android.sh', '--' + args.device], env)
            say(f'Android SDK reused at {sdk}; new AVD disks use {storage / "avd"}. Existing AVDs are retained.')
        say('PASSED: setup prerequisites ready. No build or runtime test was run.')
        say('Next: scripts/menu_demo.sh test host (or ios-phone / android-phone).')
        return 0
    except Incomplete as error:
        say(f'SETUP INCOMPLETE: {error}')
        return 3
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError) as error:
        say(f'FAILED: {error}')
        return 1
    finally:
        if log:
            log.close()

if __name__ == '__main__':
    sys.exit(main())
