#!/usr/bin/env bash
set -euo pipefail
case "${1:---phone}" in
  --phone) ;;
  *) echo 'Usage: internal ios.sh --phone' >&2; exit 2;;
esac
xcrun --find simctl >/dev/null
xcrun --sdk iphonesimulator --show-sdk-path
python3 - <<'PY'
import json, subprocess, sys
get=lambda kind: json.loads(subprocess.check_output(['xcrun','simctl','list',kind,'-j']))
runtimes=[r for r in get('runtimes')['runtimes'] if r.get('isAvailable') and '.iOS-' in r['identifier']]
if not runtimes: sys.exit('No iOS runtime. Install one with: xcodebuild -downloadPlatform iOS')
selected=max(runtimes, key=lambda r: tuple(int(n) for n in r['version'].split('.')))
runtime=selected['identifier']
devices=get('devices')['devices'].get(runtime, [])
types=selected.get('supportedDeviceTypes', [])
if not types: sys.exit('Runtime does not report supported device types. Update Xcode before creating simulators.')
for family in ['iPhone']:
    found=next((d for d in devices if d.get('isAvailable') and d['name'].startswith(family)), None)
    if found: print(f"Ready: {found['name']} ({found['udid']})"); continue
    dtype=next((t for t in types if t['name'].startswith(family)), None)
    if not dtype: sys.exit(f'No {family} device type installed')
    result=subprocess.run(['xcrun','simctl','create',f'{family} Simplicity',dtype['identifier'],runtime], text=True, capture_output=True)
    if result.returncode: sys.exit(f"Could not create {dtype['name']} on {selected['name']}: {result.stderr.strip()}")
    uid=result.stdout.strip()
    print(f'Ready: {family} Simplicity ({uid})')
PY
