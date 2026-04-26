#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PRESET="ios-ipad-simulator-debug"
DEVICE_NAME=""
BUILD_ONLY=0

usage() {
  cat <<'EOF'
Usage: tools/run_ios_simulator.sh [options]

Options:
  --preset <name>    CMake preset to configure/build. Default: ios-ipad-simulator-debug
  --device <name>    Exact simulator device name. Default: first available iPad simulator
  --build-only       Configure and build, but do not boot/install/launch
  -h, --help         Show this help
EOF
}

resolve_device() {
  local requested_name="$1"

  local simctl_json
  simctl_json="$(xcrun simctl list devices available -j)"

  SIMCTL_JSON="$simctl_json" python3 - "$requested_name" <<'PY'
import json
import os
import sys

requested = sys.argv[1]
data = json.loads(os.environ["SIMCTL_JSON"])

devices = []
for runtime, entries in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for entry in entries:
        if entry.get("isAvailable"):
            devices.append(entry)

if requested:
    for entry in devices:
        if entry.get("name") == requested:
            print(f"{entry['name']}|{entry['udid']}")
            raise SystemExit(0)
    raise SystemExit(f"Simulator device not found: {requested}")

for entry in devices:
    if entry.get("name", "").startswith("iPad"):
        print(f"{entry['name']}|{entry['udid']}")
        raise SystemExit(0)

raise SystemExit("No available iPad simulator device found")
PY
}

find_app_bundle() {
  local build_dir="$1"
  find "$build_dir" -type d -name 'hello_pixel.app' | head -n 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      PRESET="${2:?Missing value for --preset}"
      shift 2
      ;;
    --device)
      DEVICE_NAME="${2:?Missing value for --device}"
      shift 2
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

echo "Configuring preset ${PRESET}"
cmake --preset "$PRESET"

echo "Building preset ${PRESET}"
cmake --build --preset "$PRESET"

BUILD_DIR="${ROOT_DIR}/build/${PRESET}"
APP_PATH="$(find_app_bundle "$BUILD_DIR")"
if [[ -z "$APP_PATH" ]]; then
  echo "Unable to find hello_pixel.app under ${BUILD_DIR}" >&2
  exit 1
fi

echo "Built app bundle: ${APP_PATH}"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  exit 0
fi

DEVICE_RECORD="$(resolve_device "$DEVICE_NAME")"
SIM_NAME="${DEVICE_RECORD%%|*}"
SIM_UDID="${DEVICE_RECORD##*|}"

echo "Booting simulator: ${SIM_NAME}"
xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Info.plist")"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "Unable to determine CFBundleIdentifier for ${APP_PATH}" >&2
  exit 1
fi

echo "Installing ${BUNDLE_ID}"
xcrun simctl install "$SIM_UDID" "$APP_PATH"

echo "Launching ${BUNDLE_ID}"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
