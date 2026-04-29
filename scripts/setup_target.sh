#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGETS=()
PASS_THROUGH=()

usage() {
  cat <<'EOF'
Usage: ./scripts/setup_target.sh [options]

Set up one or more platform pipelines through a single public entrypoint.

Options:
  --target <name>        Target to prepare. Repeat for more than one.
                         Supported now: windows, linux, macos
                         Planned next: ios-phone, ios-tablet, android-phone, android-tablet
  --all                  Prepare every currently wired target.
  --iso <path>           Forward a guest media override to the active backend.
  --download-dir <dir>   Forward a custom media cache root to the active backend.
  --force                Force re-download or restaging where supported.
  --skip-install-utm     Skip Homebrew UTM install checks.
  --no-open              Do not open upstream download pages.
  -h, --help             Show this help.
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
      TARGETS+=("$(require_option_value "$1" "${2-}")")
      shift 2
      ;;
    --all|--iso|--download-dir|--force|--skip-install-utm|--no-open)
      PASS_THROUGH+=("$1")
      if [[ "$1" == "--iso" || "$1" == "--download-dir" ]]; then
        PASS_THROUGH+=("$(require_option_value "$1" "${2-}")")
        shift 2
      else
        shift
      fi
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

if [[ " ${PASS_THROUGH[*]} " == *" --all "* && "${#TARGETS[@]}" -gt 0 ]]; then
  usage_error "Use either --all or one or more --target values, not both."
fi

if [[ "${#TARGETS[@]}" -eq 0 && " ${PASS_THROUGH[*]} " != *" --all "* ]]; then
  "${SCRIPT_DIR}/setup_utm.sh" "${PASS_THROUGH[@]}"
  echo
  echo "Unified mobile setup is still a stub."
  echo "Planned backend entrypoints:"
  echo "  ./scripts/setup_target.sh --target ios-phone"
  echo "  ./scripts/setup_target.sh --target ios-tablet"
  echo "  ./scripts/setup_target.sh --target android-phone"
  echo "  ./scripts/setup_target.sh --target android-tablet"
  exit 0
fi

if [[ "${#TARGETS[@]}" -eq 0 && " ${PASS_THROUGH[*]} " == *" --all "* ]]; then
  "${SCRIPT_DIR}/setup_utm.sh" "${PASS_THROUGH[@]}"
  echo
  echo "Unified mobile setup is still a stub."
  echo "Desktop VM lanes are ready; mobile bootstrap backends are the next piece."
  exit 0
fi

for target in "${TARGETS[@]}"; do
  case "$target" in
    windows|linux|macos)
      "${SCRIPT_DIR}/setup_utm.sh" "--${target}" "${PASS_THROUGH[@]}"
      ;;
    ios-phone|ios-tablet)
      echo "Setup for ${target} is not wired yet." >&2
      echo "Try ./scripts/setup_ios_simulators.sh --help for the planned flag shape." >&2
      exit 1
      ;;
    android-phone|android-tablet)
      echo "Setup for ${target} is not wired yet." >&2
      echo "Try ./scripts/setup_android_emulators.sh --help for the planned flag shape." >&2
      exit 1
      ;;
    *)
      echo "Unknown setup target: ${target}" >&2
      echo "Supported right now: windows, linux, macos." >&2
      exit 1
      ;;
  esac
done
