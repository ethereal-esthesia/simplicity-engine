#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET=""
PASS_THROUGH=()

usage() {
  cat <<'EOF'
Usage: ./scripts/package_target.sh <target> [options]
   or: ./scripts/package_target.sh --target <target> [options]

Package a supported target through one public entrypoint.

Targets wired now:
  linux-x64, linux-arm64, macos-arm64, macos-x64, windows-x64

Targets planned next:
  ios, android, fireos, chromeos
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
  linux-x64)
    exec env ARCH_LABEL=x64 "${SCRIPT_DIR}/package_linux.sh" "${PASS_THROUGH[@]}"
    ;;
  linux-arm64)
    exec env ARCH_LABEL=arm64 "${SCRIPT_DIR}/package_linux.sh" "${PASS_THROUGH[@]}"
    ;;
  macos-arm64)
    exec env ARCH_LABEL=arm64 "${SCRIPT_DIR}/package_macos.sh" "${PASS_THROUGH[@]}"
    ;;
  macos-x64)
    exec env ARCH_LABEL=x64 "${SCRIPT_DIR}/package_macos.sh" "${PASS_THROUGH[@]}"
    ;;
  windows-x64)
    if command -v pwsh >/dev/null 2>&1; then
      exec pwsh -NoProfile -File "${SCRIPT_DIR}/package_windows_zip.ps1" "${PASS_THROUGH[@]}"
    fi
    echo "Packaging windows-x64 needs PowerShell (`pwsh`) on this host." >&2
    exit 1
    ;;
  ios|android|fireos|chromeos)
    echo "Packaging for ${TARGET} is still a stub." >&2
    exit 1
    ;;
  *)
    echo "Unknown package target: ${TARGET}" >&2
    exit 1
    ;;
esac
