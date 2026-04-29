#!/usr/bin/env bash
set -euo pipefail

REPO="/home/shane/Project/simplicity-engine"
PRESET="linux-debug"
TARGET="hello_pixel"
SYNC="none"
RUN_TESTS=0
LAUNCH=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tools/parallels/install-hints.sh
source "${SCRIPT_DIR}/../install-hints.sh"

usage() {
  cat <<'EOF'
Usage: guest-build-run.sh [options]

Options:
  --repo <path>           Linux repo path. Default: /home/shane/Project/simplicity-engine
  --preset <name>         CMake preset to build. Default: linux-debug
  --target <name>         CMake target to build. Default: hello_pixel
  --sync <none|pull>      Sync step before build. Default: none
  --test                  Run ctest after build.
  --launch                Launch the built executable after build.
  -h, --help              Show this help.
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
    --repo)
      REPO="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --preset)
      PRESET="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --target)
      TARGET="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --sync)
      SYNC="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --test)
      RUN_TESTS=1
      shift
      ;;
    --launch)
      LAUNCH=1
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

if [[ "$SYNC" != "none" && "$SYNC" != "pull" ]]; then
  usage_error "--sync must be 'none' or 'pull'."
fi

for required_command in cmake git ninja; do
  command -v "$required_command" >/dev/null 2>&1 || {
    parallels_install_hint linux "$required_command" "rerun the Linux build" >&2
    exit 1
  }
done

if [[ ! -d "$REPO" ]]; then
  echo "Linux repo path does not exist: ${REPO}" >&2
  echo "Make sure the repo is present in the VM, or rerun the Parallels setup helper first." >&2
  exit 1
fi

cd "$REPO"

if [[ "$SYNC" == "pull" ]]; then
  git pull --ff-only
fi

cmake --preset "$PRESET"
cmake --build --preset "$PRESET" --target "$TARGET"

if [[ "$RUN_TESTS" -eq 1 ]]; then
  ctest --test-dir "build/$PRESET" --output-on-failure
fi

if [[ "$LAUNCH" -eq 1 ]]; then
  executable=""
  for candidate in \
    "build/$PRESET/$TARGET" \
    "build/$PRESET/Debug/$TARGET" \
    "build/$PRESET/Release/$TARGET" \
    "build/$PRESET/RelWithDebInfo/$TARGET"; do
    if [[ -x "$candidate" ]]; then
      executable="$candidate"
      break
    fi
  done

  if [[ -z "$executable" ]]; then
    echo "Built target '${TARGET}' was not found under build/${PRESET}." >&2
    echo "Check the build output above and confirm the selected preset produces a runnable executable." >&2
    exit 1
  fi

  (cd "$(dirname "$executable")" && "./$(basename "$executable")") &
fi
