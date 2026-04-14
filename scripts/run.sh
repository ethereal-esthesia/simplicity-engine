#!/usr/bin/env bash
set -euo pipefail

PRESET="debug"
TARGET="hello_pixel"
RUN_TESTS=0
LAUNCH=1
CONSOLE_OUTPUT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/install-hints.sh
source "${SCRIPT_DIR}/install-hints.sh"

usage() {
  cat <<'EOF'
Usage: scripts/run.sh [options]

Options:
  --preset <name>         CMake preset to build. Default: debug
  --target <name>         CMake target to build. Default: hello_pixel
  --test                  Run ctest after build.
  --no-test               Do not run ctest after build. Default.
  --launch                Launch the built executable. Default.
  --no-launch             Build only.
  --console               Run the executable attached to this shell.
  --foreground            Alias for --console.
  -h, --help              Show this help.
EOF
}

host_platform() {
  case "$(uname -s)" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      printf 'linux-host\n'
      ;;
    *)
      printf 'host\n'
      ;;
  esac
}

require_command() {
  local command_name="$1"
  local platform="$2"

  command -v "$command_name" >/dev/null 2>&1 || {
    simplicity_install_hint "$platform" "$command_name" "rerun the demo" >&2
    exit 1
  }
}

compiler_available() {
  local platform="$1"

  if [[ "$platform" == "macos" ]] && xcrun --find clang++ >/dev/null 2>&1; then
    return 0
  fi

  command -v c++ >/dev/null 2>&1 ||
    command -v clang++ >/dev/null 2>&1 ||
    command -v g++ >/dev/null 2>&1
}

find_executable() {
  local preset="$1"
  local target="$2"
  local candidate

  for candidate in \
    "build/${preset}/${target}" \
    "build/${preset}/${target}.app" \
    "build/${preset}/${target}.exe" \
    "build/${preset}/Debug/${target}" \
    "build/${preset}/Debug/${target}.exe" \
    "build/${preset}/Release/${target}" \
    "build/${preset}/Release/${target}.exe" \
    "build/${preset}/RelWithDebInfo/${target}" \
    "build/${preset}/RelWithDebInfo/${target}.exe"; do
    if [[ -x "$candidate" || -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

create_run_log() {
  local logs_dir="${REPO_ROOT}/logs"
  local timestamp
  local log_path

  mkdir -p "$logs_dir"
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  log_path="${logs_dir}/run_${timestamp}.log"
  if [[ -e "$log_path" ]]; then
    log_path="${logs_dir}/run_${timestamp}_$$.log"
  fi
  printf '%s\n' "$log_path"
}

launch_executable() {
  local executable="$1"
  local executable_dir
  local executable_name
  local log_path
  local pid

  if [[ "$CONSOLE_OUTPUT" -eq 1 ]]; then
    echo "Running ${executable} with console output"
    cd "$(dirname "$executable")"
    exec "./$(basename "$executable")"
  fi

  if [[ -d "$executable" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      open -n "$executable"
      echo "Launched ${executable}"
      return
    fi

    echo "Built target is a directory, not an executable: ${executable}" >&2
    exit 1
  fi

  executable_dir="$(cd "$(dirname "$executable")" && pwd)"
  executable_name="$(basename "$executable")"
  log_path="$(create_run_log)"

  (
    cd "$executable_dir"
    exec nohup "./$executable_name" >"$log_path" 2>&1 < /dev/null
  ) &
  pid="$!"

  echo "Launched ${executable} as pid ${pid}"
  echo "App log: ${log_path}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      PRESET="${2:?Missing value for --preset}"
      shift 2
      ;;
    --target)
      TARGET="${2:?Missing value for --target}"
      shift 2
      ;;
    --test)
      RUN_TESTS=1
      shift
      ;;
    --no-test)
      RUN_TESTS=0
      shift
      ;;
    --launch)
      LAUNCH=1
      shift
      ;;
    --no-launch)
      LAUNCH=0
      shift
      ;;
    --console|--foreground)
      CONSOLE_OUTPUT=1
      LAUNCH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

PLATFORM="$(host_platform)"

require_command cmake "$PLATFORM"
require_command ninja "$PLATFORM"

if ! compiler_available "$PLATFORM"; then
  simplicity_install_hint "$PLATFORM" compiler "rerun the demo" >&2
  exit 1
fi

cd "$REPO_ROOT"

echo "Running build at '${REPO_ROOT}'"
echo "Preset: ${PRESET}"
echo "Target: ${TARGET}"

cmake --preset "$PRESET"
cmake --build --preset "$PRESET" --target "$TARGET"

if [[ "$RUN_TESTS" -eq 1 ]]; then
  ctest --test-dir "build/$PRESET" --output-on-failure
fi

if [[ "$LAUNCH" -eq 1 ]]; then
  executable="$(find_executable "$PRESET" "$TARGET")" || {
    echo "Built executable not found for target '$TARGET' under build/$PRESET" >&2
    exit 1
  }

  launch_executable "$executable"
fi
