#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULT_SDK="$HOME/Android/Sdk"
[[ $(uname -s) == Darwin ]] && DEFAULT_SDK="$HOME/Library/Android/sdk"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$DEFAULT_SDK}}"
if [[ $(uname -s) == Darwin ]] && { [[ -z "${JAVA_HOME:-}" ]] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -Eq 'version "(17|21|22|23)\.'; }; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 23 2>/dev/null || /usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home -v 17)"
fi
if [[ -n "${JAVA_HOME:-}" ]]; then export PATH="$JAVA_HOME/bin:$PATH"; fi
java -version 2>&1 | grep -Eq 'version "(17|21|22|23)\.' || { echo 'Use JDK 17, 21, 22 or 23 for the pinned Gradle version.' >&2; exit 1; }
export ANDROID_HOME="$SDK_ROOT"

cd "$ROOT/android"
./gradlew -PmenuDemo assembleDebug
if [[ "${1:-}" == --build-only ]]; then exit 0; fi
SERIAL="${ANDROID_SERIAL:-}"
if [[ -z "$SERIAL" ]]; then echo 'Set ANDROID_SERIAL to the test emulator; APK build succeeded.'; exit 0; fi
"$SDK_ROOT/platform-tools/adb" -s "$SERIAL" install -r app/build/outputs/apk/debug/app-debug.apk
"$SDK_ROOT/platform-tools/adb" -s "$SERIAL" shell am start -n dev.simplicityengine.hellopixel/.HelloPixelActivity
