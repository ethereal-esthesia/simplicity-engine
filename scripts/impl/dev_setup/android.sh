#!/usr/bin/env bash
set -euo pipefail
case "${1:---phone}" in
  --phone) ;;
  *) echo 'Usage: internal android.sh --phone' >&2; exit 2;;
esac
SDK_ROOT="${ANDROID_SDK_ROOT:?Set by dev-setup.sh}"
if [[ -z "${JAVA_HOME:-}" && -d '/Applications/Android Studio.app/Contents/jbr/Contents/Home' ]]; then
  export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
  export PATH="$JAVA_HOME/bin:$PATH"
fi
SDKMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/avdmanager"
[[ -x "$SDKMANAGER" ]] || { echo 'Install Android SDK Command-line Tools (latest) in Android Studio first.' >&2; exit 1; }
"$SDKMANAGER" --sdk_root="$SDK_ROOT" 'platform-tools' 'emulator' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;27.2.12479018' 'cmake;3.22.1'
ABI=arm64-v8a; if [[ $(uname -m) == x86_64 ]]; then ABI=x86_64; fi
IMAGE="system-images;android-36.1;google_apis;$ABI"
"$SDKMANAGER" --sdk_root="$SDK_ROOT" "$IMAGE"
for lane in phone; do
  NAME="Simplicity_${lane}"; DEVICE=pixel_7
  if ! "$SDK_ROOT/emulator/emulator" -list-avds | grep -Fxq "$NAME"; then
    printf 'no\n' | "$AVDMANAGER" create avd --name "$NAME" --package "$IMAGE" --device "$DEVICE" --path "$SIMPLICITY_STORAGE/avd/$NAME.avd"
  fi
  echo "Ready: $NAME"
done
