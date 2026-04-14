#!/usr/bin/env bash
set -euo pipefail

VM_NAME="Linux"
GUEST_REPO="/home/shane/Project/simplicity-engine"
PRESET="linux-debug"
TARGET="hello_pixel"
SYNC="none"
RUN_TESTS=0
LAUNCH=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=scripts/parallels/install-hints.sh
source "${SCRIPT_DIR}/../install-hints.sh"

LOCAL_CONFIG="${REPO_ROOT}/local/parallels/linux.env"
if [[ -f "$LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_CONFIG"
fi

usage() {
  cat <<'EOF'
Usage: scripts/parallels/linux/run-linux.sh [options]

Options:
  --vm <name>             Parallels VM name. Default: Linux
  --guest-repo <path>     Linux repo path. Default: /home/shane/Project/simplicity-engine
  --preset <name>         CMake preset to build. Default: linux-debug
  --target <name>         CMake target to build. Default: hello_pixel
  --sync <none|pull>      Sync step inside Linux before build. Default: none
  --test                  Run ctest after build.
  --no-test               Do not run ctest after build. Default.
  --launch                Launch the built executable. Default.
  --no-launch             Build only.
  -h, --help              Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm)
      VM_NAME="${2:?Missing value for --vm}"
      shift 2
      ;;
    --guest-repo)
      GUEST_REPO="${2:?Missing value for --guest-repo}"
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

if ! command -v prlctl >/dev/null 2>&1; then
  echo "prlctl was not found. Install Parallels Desktop command-line tools." >&2
  exit 1
fi

status="$(prlctl status "$VM_NAME" 2>/dev/null || true)"
if [[ -z "$status" ]]; then
  echo "Parallels VM not found: $VM_NAME" >&2
  echo "Available VMs:" >&2
  prlctl list --all >&2
  exit 1
fi

if [[ "$status" == *"suspended"* ]]; then
  prlctl resume "$VM_NAME"
elif [[ "$status" != *"running"* ]]; then
  prlctl start "$VM_NAME"
fi

echo "Running Linux build in VM '${VM_NAME}' at '${GUEST_REPO}'"
echo "Mac repo: ${REPO_ROOT}"

cmd=(prlctl exec "$VM_NAME" --current-user bash \
  "${GUEST_REPO}/scripts/parallels/linux/guest-build-run.sh" \
  --repo "$GUEST_REPO" \
  --preset "$PRESET" \
  --target "$TARGET" \
  --sync "$SYNC")

if [[ "$RUN_TESTS" -eq 1 ]]; then
  cmd+=(--test)
fi

if [[ "$LAUNCH" -eq 1 ]]; then
  cmd+=(--launch)
fi

if output="$("${cmd[@]}" 2>&1)"; then
  printf '%s\n' "$output"
else
  case "$output" in
    *"Required command not found in Linux PATH: cmake"*|*"cmake was not found in the Linux VM"*)
      parallels_install_hint linux cmake "rerun the Linux build" >&2
      ;;
    *"Required command not found in Linux PATH: git"*|*"git was not found in the Linux VM"*)
      parallels_install_hint linux git "rerun the Linux build" >&2
      ;;
    *"Required command not found in Linux PATH: ninja"*|*"ninja was not found in the Linux VM"*)
      parallels_install_hint linux ninja "rerun the Linux build" >&2
      ;;
    *)
      printf '%s\n' "$output" >&2
      ;;
  esac
  exit 1
fi
