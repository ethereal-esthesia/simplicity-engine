#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANDROID_PROJECT_DIR="${REPO_ROOT}/android"
SDK_ROOT_DEFAULT="${HOME}/Library/Android/sdk"
APP_ID="dev.simplicityengine.hellopixel"
APP_ACTIVITY="dev.simplicityengine.hellopixel.HelloPixelActivity"

BUILD_MODE="install"
LAUNCH_APP=true
START_EMULATOR=true
AVD_NAME=""

usage() {
  cat <<'EOF'
Usage: ./tools/run_android_emulator.sh [options]

Build and install the Android sample app to a running or auto-started emulator.

Options:
  --avd <name>          Launch or target a specific AVD name.
  --build-only          Build the APK without installing it.
  --no-launch           Install but do not launch the app activity.
  --no-start-emulator   Require an already running emulator/device.
  --help                Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --avd)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --avd" >&2; exit 1; }
      AVD_NAME="$1"
      ;;
    --build-only)
      BUILD_MODE="build"
      ;;
    --no-launch)
      LAUNCH_APP=false
      ;;
    --no-start-emulator)
      START_EMULATOR=false
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${SDK_ROOT_DEFAULT}}}"
ANDROID_SDK_ROOT="${ANDROID_HOME}"
ADB="${ANDROID_HOME}/platform-tools/adb"
EMULATOR="${ANDROID_HOME}/emulator/emulator"

if [[ ! -x "${ADB}" ]]; then
  echo "Android platform-tools not found at ${ADB}" >&2
  exit 1
fi

if [[ ! -x "${EMULATOR}" && "${BUILD_MODE}" != "build" ]]; then
  echo "Android emulator not found at ${EMULATOR}" >&2
  exit 1
fi

find_latest_ndk() {
  local ndk_dir="${ANDROID_HOME}/ndk"
  if [[ ! -d "${ndk_dir}" ]]; then
    return 1
  fi
  find "${ndk_dir}" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1
}

escape_gradle_path() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/:/\\:/g; s/ /\\ /g'
}

write_local_properties() {
  local local_properties="${ANDROID_PROJECT_DIR}/local.properties"
  local sdk_escaped
  sdk_escaped="$(escape_gradle_path "${ANDROID_HOME}")"
  {
    printf 'sdk.dir=%s\n' "${sdk_escaped}"
  } > "${local_properties}"
}

pick_default_avd() {
  local avds
  avds="$("${EMULATOR}" -list-avds)"
  if [[ -z "${avds}" ]]; then
    return 1
  fi
  local tablet_match
  tablet_match="$(printf '%s\n' "${avds}" | awk 'BEGIN{IGNORECASE=1} /tablet|tab/ {print; exit}')"
  if [[ -n "${tablet_match}" ]]; then
    printf '%s\n' "${tablet_match}"
    return 0
  fi
  printf '%s\n' "${avds}" | head -n 1
}

wait_for_boot() {
  local device="$1"
  "${ADB}" -s "${device}" wait-for-device >/dev/null
  for _ in $(seq 1 180); do
    local boot_completed
    boot_completed="$("${ADB}" -s "${device}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "${boot_completed}" == "1" ]]; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for emulator boot completion on ${device}" >&2
  return 1
}

first_running_device() {
  "${ADB}" devices | awk 'NR > 1 && $2 == "device" {print $1; exit}'
}

start_emulator_if_needed() {
  local running_device
  running_device="$(first_running_device)"
  if [[ -n "${running_device}" ]]; then
    printf '%s\n' "${running_device}"
    return 0
  fi

  if [[ "${START_EMULATOR}" != true ]]; then
    echo "No running emulator/device found and --no-start-emulator was set." >&2
    return 1
  fi

  if [[ -z "${AVD_NAME}" ]]; then
    AVD_NAME="$(pick_default_avd)"
  fi
  if [[ -z "${AVD_NAME}" ]]; then
    echo "No Android Virtual Device found." >&2
    return 1
  fi

  local emulator_log="${REPO_ROOT}/logs/android-emulator.log"
  mkdir -p "${REPO_ROOT}/logs"
  nohup "${EMULATOR}" -avd "${AVD_NAME}" > "${emulator_log}" 2>&1 &

  for _ in $(seq 1 60); do
    running_device="$(first_running_device)"
    if [[ -n "${running_device}" ]]; then
      printf '%s\n' "${running_device}"
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for emulator ${AVD_NAME} to appear." >&2
  return 1
}

ensure_java_home() {
  if [[ -n "${JAVA_HOME:-}" ]]; then
    return 0
  fi
  if [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
    JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  else
    JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
  fi
  export JAVA_HOME
}

write_local_properties
ensure_java_home
export ANDROID_HOME ANDROID_SDK_ROOT
export PATH="${JAVA_HOME}/bin:${PATH}"

if [[ "${BUILD_MODE}" == "build" ]]; then
  (
    cd "${ANDROID_PROJECT_DIR}"
    ./gradlew assembleDebug --no-daemon
  )
  echo "Built Android debug APK."
  exit 0
fi

"${ADB}" start-server >/dev/null
TARGET_DEVICE="$(start_emulator_if_needed)"
wait_for_boot "${TARGET_DEVICE}"

(
  cd "${ANDROID_PROJECT_DIR}"
  ./gradlew installDebug --no-daemon
)

if [[ "${LAUNCH_APP}" == true ]]; then
  "${ADB}" -s "${TARGET_DEVICE}" shell am start -n "${APP_ID}/${APP_ACTIVITY}" >/dev/null
  echo "Installed and launched on ${TARGET_DEVICE}."
else
  echo "Installed on ${TARGET_DEVICE}."
fi
