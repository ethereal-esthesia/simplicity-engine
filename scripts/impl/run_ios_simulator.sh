#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PRESET="ios-ipad-simulator-debug"
DEVICE_NAME=""
BUILD_ONLY=0
DEVICE_CLASS="ipad"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/install-hints.sh
source "${SCRIPT_DIR}/../lib/install-hints.sh"

usage() {
  cat <<'EOF'
Usage: scripts/run_ios_simulator.sh [options]

Options:
  --preset <name>    CMake preset to configure/build. Default: ios-ipad-simulator-debug
  --device <name>    Exact simulator device name. Default: first available device in the chosen class
  --device-class <name>
                     Simulator family to use: ipad or iphone. Default: ipad
  --build-only       Configure and build, but do not boot/install/launch
  -h, --help         Show this help
EOF
}

usage_error() {
  local message="$1"

  echo "$message" >&2
  echo >&2
  usage >&2
  exit 2
}

require_option_value() {
  local option="$1"
  local value="${2-}"

  if [[ -z "$value" || "$value" == --* ]]; then
    usage_error "Missing value for ${option}."
  fi

  printf '%s\n' "$value"
}

require_command() {
  local command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    simplicity_install_hint macos "$command_name" "rerun the iOS simulator launcher" >&2
    exit 1
  }
}

resolve_device() {
  local requested_name="$1"
  local requested_class="$2"

  local simctl_json
  simctl_json="$(xcrun simctl list devices available -j)"

  SIMCTL_JSON="$simctl_json" python3 - "$requested_name" "$requested_class" <<'PY'
import json
import os
import sys

requested = sys.argv[1]
requested_class = sys.argv[2]
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
    raise SystemExit(
        f"Could not find an available simulator named '{requested}'. "
        "Open Simulator or Xcode and confirm that device exists."
    )

prefix = {
    "ipad": "iPad",
    "iphone": "iPhone",
}.get(requested_class)

if prefix is None:
    raise SystemExit(
        f"Unsupported simulator device class '{requested_class}'. "
        "Use 'ipad' or 'iphone'."
    )

for entry in devices:
    if entry.get("name", "").startswith(prefix):
        print(f"{entry['name']}|{entry['udid']}")
        raise SystemExit(0)

raise SystemExit(
    f"No available {requested_class} simulator device was found. "
    "Install a matching simulator runtime in Xcode first."
)
PY
}

find_app_bundle() {
  local build_dir="$1"
  find "$build_dir" -type d -name 'hello_pixel.app' | head -n 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      PRESET="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --device)
      DEVICE_NAME="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --device-class)
      DEVICE_CLASS="$(require_option_value "$1" "${2-}")"
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
      usage_error "Unknown option: $1"
      ;;
  esac
done

if [[ "$DEVICE_CLASS" != "ipad" && "$DEVICE_CLASS" != "iphone" ]]; then
  usage_error "--device-class must be 'ipad' or 'iphone'."
fi

if [[ "$PRESET" == "ios-ipad-"* ]]; then
  DEVICE_CLASS="ipad"
elif [[ "$PRESET" == "ios-iphone-"* ]]; then
  DEVICE_CLASS="iphone"
fi

cd "$ROOT_DIR"

require_command cmake
require_command xcrun

echo "Configuring preset ${PRESET}"
cmake --preset "$PRESET"

echo "Building preset ${PRESET}"
cmake --build --preset "$PRESET"

BUILD_DIR="${ROOT_DIR}/build/${PRESET}"
APP_PATH="$(find_app_bundle "$BUILD_DIR")"
if [[ -z "$APP_PATH" ]]; then
  echo "Build completed, but hello_pixel.app was not found under ${BUILD_DIR}." >&2
  echo "Check the CMake preset output above and confirm the app bundle target built successfully." >&2
  exit 1
fi

echo "Built app bundle: ${APP_PATH}"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  exit 0
fi

DEVICE_RECORD="$(resolve_device "$DEVICE_NAME" "$DEVICE_CLASS")"
SIM_NAME="${DEVICE_RECORD%%|*}"
SIM_UDID="${DEVICE_RECORD##*|}"

echo "Booting simulator: ${SIM_NAME}"
xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Info.plist")"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "Could not determine the CFBundleIdentifier for ${APP_PATH}." >&2
  echo "Make sure the generated app bundle has a valid Info.plist." >&2
  exit 1
fi

echo "Installing ${BUNDLE_ID}"
xcrun simctl install "$SIM_UDID" "$APP_PATH"

echo "Launching ${BUNDLE_ID}"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
