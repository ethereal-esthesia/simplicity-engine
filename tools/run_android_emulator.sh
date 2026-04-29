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
TARGET_PROFILE=""

default_target_help() {
  cat <<'EOF'
Default Android emulator target profiles:
  android-phone   first AVD matching "phone" or "pixel"
  android-tablet  first AVD matching "tablet" or "tab"
EOF
}

usage() {
  cat <<'EOF'
Usage: ./tools/run_android_emulator.sh --target <profile> [options]

Build and install the Android sample app to a running or auto-started emulator.

Options:
  --target <profile>    One of: android-phone, android-tablet.
  --avd <name>          Launch or target a specific AVD name.
  --build-only          Build the APK without installing it.
  --no-launch           Install but do not launch the app activity.
  --no-start-emulator   Require an already running emulator/device.
  --help                Show this help message.
EOF
  echo
  default_target_help
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      shift
      TARGET_PROFILE="$(require_option_value "--target" "${1-}")"
      ;;
    --avd)
      shift
      AVD_NAME="$(require_option_value "--avd" "${1-}")"
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
      usage_error "Unknown option: $1"
      ;;
  esac
  shift
done

if [[ -z "${TARGET_PROFILE}" && -z "${AVD_NAME}" ]]; then
  usage
  exit 0
fi

validate_target_profile() {
  case "${TARGET_PROFILE}" in
    ""|android-phone|android-tablet)
      return 0
      ;;
    fire-tablet)
      cat >&2 <<'EOF'
The fire-tablet target was removed because this setup does not have a real built-in Fire tablet emulator profile.

Use one of these instead:
  - create a custom Fire-style AVD in Android Studio and pass it with --avd <name>
  - use a physical Fire tablet for real Fire OS and Amazon Appstore validation

See MOBILE-TESTING-SETUP.md for the current Fire testing workflow.
EOF
      return 1
      ;;
    *)
      echo "Unknown Android target profile: ${TARGET_PROFILE}" >&2
      echo "Supported target profiles: android-phone, android-tablet." >&2
      return 1
      ;;
  esac
}

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${SDK_ROOT_DEFAULT}}}"
ANDROID_SDK_ROOT="${ANDROID_HOME}"
ADB="${ANDROID_HOME}/platform-tools/adb"
EMULATOR="${ANDROID_HOME}/emulator/emulator"

if [[ ! -x "${ADB}" ]]; then
  echo "Android platform-tools were not found at ${ADB}." >&2
  echo "Install the Android SDK platform-tools, or point ANDROID_HOME / ANDROID_SDK_ROOT at the correct SDK." >&2
  exit 1
fi

if [[ ! -x "${EMULATOR}" && "${BUILD_MODE}" != "build" ]]; then
  echo "The Android emulator binary was not found at ${EMULATOR}." >&2
  echo "Install the Android Emulator component, or use --build-only if you only want the APK." >&2
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

pick_default_avd_for_pattern() {
  local pattern="$1"
  local avds
  avds="$("${EMULATOR}" -list-avds)"
  if [[ -z "${avds}" ]]; then
    return 1
  fi
  local match
  match="$(
    printf '%s\n' "${avds}" |
      awk -v pattern="${pattern}" '
        BEGIN {
          lowered_pattern = tolower(pattern)
        }
        tolower($0) ~ lowered_pattern {
          print
          exit
        }
      '
  )"
  if [[ -n "${match}" ]]; then
    printf '%s\n' "${match}"
    return 0
  fi
  return 1
}

pick_default_avd() {
  case "${TARGET_PROFILE}" in
    android-phone)
      pick_default_avd_for_pattern "phone|pixel"
      ;;
    android-tablet)
      pick_default_avd_for_pattern "tablet|tab"
      ;;
    "")
      pick_default_avd_for_pattern "tablet|tab"
      ;;
    *)
      echo "Unknown target profile: ${TARGET_PROFILE}" >&2
      return 1
      ;;
  esac
}

wait_for_boot() {
  local device="$1"
  "${ADB}" -s "${device}" wait-for-device >/dev/null
  for _ in $(seq 1 180); do
    local boot_completed
    local dev_bootcomplete
    local bootanim_state
    local ce_available
    boot_completed="$("${ADB}" -s "${device}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    dev_bootcomplete="$("${ADB}" -s "${device}" shell getprop dev.bootcomplete 2>/dev/null | tr -d '\r')"
    bootanim_state="$("${ADB}" -s "${device}" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r')"
    ce_available="$("${ADB}" -s "${device}" shell getprop sys.user.0.ce_available 2>/dev/null | tr -d '\r')"
    if [[ "${boot_completed}" == "1" &&
          "${dev_bootcomplete}" == "1" &&
          "${bootanim_state}" == "stopped" &&
          "${ce_available}" == "true" ]]; then
      sleep 5
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for emulator system readiness on ${device}" >&2
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
    echo "No running Android emulator or device was found, and --no-start-emulator was set." >&2
    echo "Start an emulator manually, connect a device over adb, or rerun without --no-start-emulator." >&2
    return 1
  fi

  if [[ -z "${AVD_NAME}" ]]; then
    AVD_NAME="$(pick_default_avd || true)"
  fi
  if [[ -z "${AVD_NAME}" ]]; then
    if [[ -n "${TARGET_PROFILE}" ]]; then
      echo "No Android Virtual Device found for target profile ${TARGET_PROFILE}." >&2
      echo "Create a matching AVD in Android Studio Device Manager, or pass a specific one with --avd <name>." >&2
    else
      echo "No Android Virtual Device was found." >&2
      echo "Create one in Android Studio Device Manager, or pass an existing one with --avd <name>." >&2
    fi
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

  echo "Timed out waiting for emulator ${AVD_NAME} to appear in adb." >&2
  echo "Check the emulator window or logs/android-emulator.log for startup errors, then try again." >&2
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
validate_target_profile
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
