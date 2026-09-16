#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="${1:-help}"; TARGET="${2:-host}"
if [[ "$ACTION" == help || "$ACTION" == --help ]]; then
  echo 'Usage: scripts/menu_demo.sh <build|test|run> <host|ios-phone>'
  exit 0
fi
case "$ACTION" in build|test|run) ;; *) echo "Unknown action: $ACTION" >&2; exit 2;; esac
mkdir -p "$ROOT/build/menu-logs"
case "$TARGET" in
  host|macos)
    BUILD="${SIMPLICITY_MENU_BUILD_DIR:-$ROOT/build/menu-host}"
    cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Debug
    cmake --build "$BUILD" -j "${SIMPLICITY_JOBS:-4}"
    BIN="$BUILD/menu_demo"; if [[ -d "$BUILD/menu_demo.app" ]]; then BIN="$BUILD/menu_demo.app/Contents/MacOS/menu_demo"; fi
    if [[ "$ACTION" == test ]]; then
      ctest --test-dir "$BUILD" --output-on-failure
      "$BUILD/test_menu" --native
    elif [[ "$ACTION" == run ]]; then exec "$BIN"; fi
    ;;
  ios-phone)
    FAMILY=iPhone
    BUILD="${SIMPLICITY_MENU_BUILD_DIR:-$ROOT/build/menu-ios}"
    cmake -S "$ROOT" -B "$BUILD" -G Xcode -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DSIMPLICITY_MENU_DEMO=ON
    cmake --build "$BUILD" --target hello_pixel --config Debug -j "${SIMPLICITY_JOBS:-4}"
    [[ "$ACTION" == build ]] && exit 0
    DEVICE="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if x["name"].startswith(sys.argv[1])))' "$FAMILY")"
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    xcrun simctl bootstatus "$DEVICE" -b
    APP="$BUILD/Debug-iphonesimulator/hello_pixel.app"
    ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
    xcrun simctl install "$DEVICE" "$APP"
    xcrun simctl terminate "$DEVICE" "$ID" 2>/dev/null || true
    if [[ "$ACTION" == test ]]; then
      LOG="$ROOT/build/menu-logs/$TARGET-test.log"
      xcrun simctl launch --console "$DEVICE" "$ID" --self-test 2>&1 | tee "$LOG"
      grep -q 'MENU_SELF_TEST=PASS' "$LOG"
    else
      open -a Simulator --args -CurrentDeviceUDID "$DEVICE"
      xcrun simctl launch "$DEVICE" "$ID"
    fi
    ;;
  *) echo "Unknown target: $TARGET" >&2; exit 2;;
esac
