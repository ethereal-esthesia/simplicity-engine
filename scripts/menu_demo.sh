#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="${1:-help}"; TARGET="${2:-host}"
if [[ "$ACTION" == help || "$ACTION" == --help ]]; then
  echo 'Usage: scripts/menu_demo.sh <build|test|run> <host|ios-phone|ios-tablet|android-phone|android-tablet>'
  echo 'Windows: use scripts/menu/demo.ps1 from a Visual Studio developer shell.'
  exit 0
fi
case "$ACTION" in build|test|run) ;; *) echo "Unknown action: $ACTION" >&2; exit 2;; esac
mkdir -p "$ROOT/build/menu-logs"
case "$TARGET" in
  host|macos|linux)
    BUILD="${SIMPLICITY_MENU_BUILD_DIR:-$ROOT/build/menu-host}"
    cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Debug
    cmake --build "$BUILD" -j "${SIMPLICITY_JOBS:-4}"
    BIN="$BUILD/menu_demo"; if [[ -d "$BUILD/menu_demo.app" ]]; then BIN="$BUILD/menu_demo.app/Contents/MacOS/menu_demo"; fi
    if [[ "$ACTION" == test ]]; then
      ctest --test-dir "$BUILD" --output-on-failure
      if [[ $(uname -s) == Linux && -z "${DISPLAY:-}" ]]; then
        command -v xvfb-run >/dev/null || { echo 'Native GTK test requires DISPLAY or xvfb-run.' >&2; exit 1; }
        xvfb-run -a "$BUILD/test_menu" --native
      else "$BUILD/test_menu" --native; fi
    elif [[ "$ACTION" == run ]]; then exec "$BIN"; fi
    ;;
  ios-phone|ios-tablet)
    if [[ "$TARGET" == ios-phone ]]; then FAMILY=iPhone; FLAG=--phone; else FAMILY=iPad; FLAG=--tablet; fi
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
  android-phone|android-tablet)
    FLAG=--phone; NAME=Simplicity_phone; PORT=5554
    if [[ "$TARGET" == android-tablet ]]; then FLAG=--tablet; NAME=Simplicity_tablet; PORT=5556; fi
    DEFAULT_SDK="$HOME/Android/Sdk"
    [[ $(uname -s) == Darwin ]] && DEFAULT_SDK="$HOME/Library/Android/sdk"
    SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$DEFAULT_SDK}}"
    "$ROOT/scripts/menu/run-android.sh" --build-only
    [[ "$ACTION" == build ]] && exit 0
    SERIAL="${ANDROID_SERIAL:-emulator-$PORT}"
    if ! "$SDK/platform-tools/adb" -s "$SERIAL" get-state >/dev/null 2>&1; then
      if [[ -n "${ANDROID_SERIAL:-}" ]]; then echo "Device not connected: $SERIAL" >&2; exit 1; fi
      nohup "$SDK/emulator/emulator" -avd "$NAME" -port "$PORT" -no-snapshot > "$ROOT/build/menu-logs/$TARGET-emulator.log" 2>&1 < /dev/null &
    fi
    READY=0
    for attempt in {1..180}; do
      if [[ $("$SDK/platform-tools/adb" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; then READY=1; break; fi
      sleep 1
    done
    [[ $READY == 1 ]] || { echo "Emulator boot timed out: $SERIAL" >&2; exit 1; }
    "$SDK/platform-tools/adb" -s "$SERIAL" install -r "$ROOT/android/app/build/outputs/apk/debug/app-debug.apk"
    ID=dev.simplicityengine.hellopixel
    "$SDK/platform-tools/adb" -s "$SERIAL" shell am force-stop "$ID"
    if [[ "$ACTION" == test ]]; then
      SINCE=$("$SDK/platform-tools/adb" -s "$SERIAL" shell "date '+%m-%d %H:%M:%S.000'" | tr -d '\r')
      "$SDK/platform-tools/adb" -s "$SERIAL" shell am start -n "$ID/.HelloPixelActivity" --ez menu_self_test true
      LOG="$ROOT/build/menu-logs/$TARGET-test.log"
      for attempt in {1..60}; do
        "$SDK/platform-tools/adb" -s "$SERIAL" logcat -d -T "$SINCE" -s 'SDL/APP:I' > "$LOG"
        if grep -q 'MENU_SELF_TEST=PASS' "$LOG"; then cat "$LOG"; exit 0; fi
        if grep -q 'MENU_SELF_TEST=FAIL' "$LOG"; then cat "$LOG"; exit 1; fi
        sleep 1
      done
      echo 'Menu self-test timed out.' >&2; exit 1
    else "$SDK/platform-tools/adb" -s "$SERIAL" shell am start -n "$ID/.HelloPixelActivity" --ez menu_self_test false; fi
    ;;
  *) echo "Unknown target: $TARGET" >&2; exit 2;;
esac
