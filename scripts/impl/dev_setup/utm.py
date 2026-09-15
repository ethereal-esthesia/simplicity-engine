"""UTM VM creation using the installed AppleScript API, with explicit export verification."""
from pathlib import Path
import json
import plistlib
import subprocess
import platform

HERE = Path(__file__).resolve().parent


def read_config(vm):
    with (vm / 'config.plist').open('rb') as stream:
        return plistlib.load(stream)


def verify_created(vm, ram, cores):
    config = read_config(vm)
    disks = [d for d in config['Drive'] if d.get('ImageName')]
    if config['System']['MemorySize'] != ram or config['System']['CPUCount'] != cores or len(disks) != 1:
        raise RuntimeError('Exported VM configuration did not match requested resources.')
    if not (vm / 'Data' / disks[0]['ImageName']).is_file():
        raise RuntimeError('Exported VM is missing its system disk. Staging VM retained.')
    return config


def script(name, *args):
    result = subprocess.run(['osascript', str(HERE / name), *map(str, args)], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


TOOLS_URL = 'https://getutm.app/downloads/utm-guest-tools-latest.iso'


def tools_iso(cache, say):
    cache.mkdir(parents=True, exist_ok=True)
    destination = cache / 'utm-guest-tools.iso'
    def valid(path):
        if not path.is_file() or path.stat().st_size < 32774:
            return False
        with path.open('rb') as stream:
            stream.seek(32769)
            return stream.read(5) == b'CD001'
    if valid(destination):
        say(f'Reusing Windows guest tools: {destination}')
        return destination
    partial = destination.with_suffix('.iso.part')
    say(f'Downloading official UTM Windows guest tools to {destination}')
    subprocess.run(['curl', '--fail', '--location', '--retry', '3', '--connect-timeout', '30',
                    '--output', str(partial), TOOLS_URL], check=True)
    if not valid(partial):
        raise RuntimeError('Downloaded guest tools are not a valid ISO; incomplete file retained for inspection.')
    partial.replace(destination)
    return destination


def attach_tools(vm, vm_id, media, say):
    before = read_config(vm)['Drive']
    size = int(script('attach_tools_utm.applescript', vm_id, media))
    after = read_config(vm)['Drive']
    disks = lambda drives: [d for d in drives if d.get('ImageName')]
    if disks(before) != disks(after) or before[0] != after[0]:
        raise RuntimeError('Drive verification failed after attaching guest tools.')
    if sum(d.get('ImageType') == 'CD' for d in after) != 2:
        raise RuntimeError('Expected exactly two CD drives after attaching guest tools.')
    if size != media.stat().st_blocks * 512 // (1024 * 1024):
        raise RuntimeError('UTM reports an unexpected guest-tools ISO size.')
    say(f'Windows guest tools attached on the second CD drive: {media}')


def prepare(vm, media, target, ram, cores, disk_gib, say, storage=None):
    vm = vm.resolve()
    if vm.suffix != '.utm':
        raise RuntimeError('--vm-path must end in .utm')
    # AppleScript exposes Apple Linux creation, but not IPSW restore installation.
    if target == 'macos':
        raise RuntimeError('Automated macOS IPSW installation is not exposed by this UTM API. Create macOS in UTM, then supply its existing --vm-path. --media cannot be applied as a macOS restore image.')
    if media is not None:
        media = media.expanduser().resolve(strict=True)
        if media.suffix.lower() != '.iso':
            raise RuntimeError('Linux/Windows --media must be an ISO installation image.')
    journal = vm.with_suffix('.setup.json')
    new = not (vm / 'config.plist').is_file()
    if new:
        if vm.exists():
            raise RuntimeError(f'Destination already exists without a config: {vm}. Nothing overwritten.')
        if media is None:
            raise RuntimeError('New Linux/Windows VMs require --media /path/to/installer.iso.')
        vm.parent.mkdir(parents=True, exist_ok=True)
        if journal.exists():
            raise RuntimeError(f'An interrupted creation is recorded in {journal}. Inspect its staging VM before retrying; nothing overwritten.')
        arch = {'arm64': 'aarch64', 'x86_64': 'x86_64'}.get(platform.machine())
        if not arch:
            raise RuntimeError('Unsupported host architecture.')
        name = vm.stem
        # Refuse an ambiguous registered name before creating any data.
        script('check_utm_name.applescript', name)
        journal.write_text(json.dumps({'state': 'creating', 'vm': str(vm), 'media': str(media), 'name': name}, indent=2))
        say(f'Creating {name}: {ram} MiB RAM, {cores} cores, {disk_gib} GiB disk.')
        vm_id = script('create_utm.applescript', name, arch, media, vm, ram, disk_gib * 1024, cores)
        config = verify_created(vm, ram, cores)
        if config['Information']['UUID'] != vm_id:
            raise RuntimeError('Export UUID mismatch; staging VM retained.')
        journal.write_text(json.dumps({'state': 'exported', 'vm': str(vm), 'id': vm_id, 'media': str(media)}, indent=2))
        # Only this newly created, stopped staging VM is deleted, after disk verification.
        script('delete_staging_utm.applescript', vm_id)
        if target == 'windows':
            config['QEMU']['TPMDevice'] = True
            with (vm / 'config.plist').open('wb') as stream:
                plistlib.dump(config, stream)
    else:
        config = read_config(vm)
        vm_id = config['Information']['UUID']
        if journal.exists() and json.loads(journal.read_text()).get('state') in ('creating', 'exported'):
            raise RuntimeError(f'Interrupted setup: inspect {journal} before opening the exported VM. Staging registration may still exist.')
        say(f'Reusing {vm}; existing disks and resource settings retained.')
    subprocess.run(['open', '-a', 'UTM', str(vm)], check=True)
    # open returns before AppleScript necessarily sees a newly registered bundle.
    script('wait_utm.applescript', vm_id)
    if media:
        if config.get('Backend') != 'QEMU' or not config.get('Drive') or config['Drive'][0].get('ImageType') != 'CD':
            raise RuntimeError('Existing VM does not have the expected first CD drive; no media changed.')
        before = read_config(vm)['Drive']
        size = int(script('attach_utm.applescript', vm_id, media))
        after = read_config(vm)['Drive']
        if len(before) != len(after) or [d.get('ImageName') for d in before] != [d.get('ImageName') for d in after]:
            raise RuntimeError('Drive verification failed after media attachment.')
        if size != media.stat().st_blocks * 512 // (1024 * 1024):
            raise RuntimeError('UTM reports an unexpected installation-media size.')
        say(f'ISO attached and size verified: {media}')
    if target == 'windows':
        cache = (Path(storage) if storage else vm.parent.parent) / 'media'
        attach_tools(vm, vm_id, tools_iso(cache, say), say)
    journal.write_text(json.dumps({'state': 'ready', 'vm': str(vm), 'id': vm_id, 'media': str(media) if media else None}, indent=2))
    say(f'VM configured at {vm}. Start it in UTM to complete OS installation.')
    return vm_id
