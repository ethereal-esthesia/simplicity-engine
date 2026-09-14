#!/usr/bin/env bash
set -euo pipefail
PHONE=0; TABLET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phone) PHONE=1;; --tablet) TABLET=1;; --all) PHONE=1; TABLET=1;;
    -h|--help) echo 'Usage: internal ios.sh [--phone|--tablet|--all]'; exit 0;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
  shift
done
if [[ $PHONE == 0 && $TABLET == 0 ]]; then PHONE=1; TABLET=1; fi
xcrun --find simctl >/dev/null
xcrun --sdk iphonesimulator --show-sdk-path
python3 - "$PHONE" "$TABLET" <<'PY'
import json, subprocess, sys
get=lambda kind: json.loads(subprocess.check_output(['xcrun','simctl','list',kind,'-j']))
runtimes=[r for r in get('runtimes')['runtimes'] if r.get('isAvailable') and '.iOS-' in r['identifier']]
if not runtimes: sys.exit('No iOS runtime. Install one with: xcodebuild -downloadPlatform iOS')
runtime=runtimes[-1]['identifier']
devices=get('devices')['devices'].get(runtime, [])
types=get('devicetypes')['devicetypes']
for enabled, family in zip(sys.argv[1:], ['iPhone','iPad']):
    if enabled!='1': continue
    found=next((d for d in devices if d.get('isAvailable') and d['name'].startswith(family)), None)
    if found: print(f"Ready: {found['name']} ({found['udid']})"); continue
    dtype=next((t for t in reversed(types) if t['name'].startswith(family)), None)
    if not dtype: sys.exit(f'No {family} device type installed')
    uid=subprocess.check_output(['xcrun','simctl','create',f'{family} Simplicity',dtype['identifier'],runtime], text=True).strip()
    print(f'Ready: {family} Simplicity ({uid})')
PY
