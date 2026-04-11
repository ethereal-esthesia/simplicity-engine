#!/usr/bin/env bash
set -euo pipefail

REPO="/home/shane/Project/simplicity-engine"
PRESET="linux-debug"
TARGET="hello_pixel"
SYNC="none"
RUN_TESTS=0
LAUNCH=0

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:?Missing value for --repo}"
      shift 2
      ;;
    --preset)
      PRESET="${2:?Missing value for --preset}"
      shift 2
      ;;
    --target)
      TARGET="${2:?Missing value for --target}"
      shift 2
      ;;
    --sync)
      SYNC="${2:?Missing value for --sync}"
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
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$SYNC" != "none" && "$SYNC" != "pull" ]]; then
  echo "--sync must be 'none' or 'pull'." >&2
  exit 2
fi

command -v cmake >/dev/null 2>&1 || {
  echo "Required command not found in Linux PATH: cmake" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || {
  echo "Required command not found in Linux PATH: git" >&2
  exit 1
}

if [[ ! -d "$REPO" ]]; then
  echo "Linux repo path does not exist: $REPO" >&2
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
    echo "Built executable not found for target '$TARGET' under build/$PRESET" >&2
    exit 1
  fi

  (cd "$(dirname "$executable")" && "./$(basename "$executable")") &
fi
