#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET=""
PASS_THROUGH=()

usage() {
  cat <<'EOF'
Usage: ./scripts/build_target.sh <target> [options]
   or: ./scripts/build_target.sh --target <target> [options]

Build a supported target through one public entrypoint.

Targets wired now:
  macos, host, ios-phone, ios-tablet, android-phone, android-tablet

Targets planned next:
  windows-x64, windows-arm64, linux-x64, linux-arm64, fireos, chromeos
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      PASS_THROUGH+=("$1")
      if [[ $# -gt 1 && "${2-}" != --* ]]; then
        PASS_THROUGH+=("$2")
        shift 2
      else
        shift
      fi
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$1"
      else
        PASS_THROUGH+=("$1")
      fi
      shift
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  usage_error "Missing target."
fi

case "$TARGET" in
  host|macos)
    exec "${SCRIPT_DIR}/run.sh" --no-launch "${PASS_THROUGH[@]}"
    ;;
  ios-phone|ios-iphone)
    exec "${SCRIPT_DIR}/run_ios_iphone.sh" --build-only "${PASS_THROUGH[@]}"
    ;;
  ios-tablet|ios-ipad|ios)
    exec "${SCRIPT_DIR}/run_ios_ipad.sh" --build-only "${PASS_THROUGH[@]}"
    ;;
  android-phone)
    exec "${SCRIPT_DIR}/run_android_phone.sh" --build-only "${PASS_THROUGH[@]}"
    ;;
  android-tablet|android)
    exec "${SCRIPT_DIR}/run_android_tablet.sh" --build-only "${PASS_THROUGH[@]}"
    ;;
  windows-x64|windows-arm64|linux-x64|linux-arm64|fireos|chromeos)
    echo "Build routing for ${TARGET} is still a stub." >&2
    echo "We need to finish the remote or platform-specific backend before this becomes a one-liner." >&2
    exit 1
    ;;
  *)
    echo "Unknown build target: ${TARGET}" >&2
    exit 1
    ;;
esac
