#!/usr/bin/env bash
set -euo pipefail

VM_NAME="Linux"
GUEST_REPO="/home/shane/Project/simplicity-engine"
PRESET="linux-debug"
TARGET="hello_pixel"
SYNC="host"
HOST_REPO=""
RUN_TESTS=0
LAUNCH=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=tools/parallels/install-hints.sh
source "${SCRIPT_DIR}/../install-hints.sh"
# shellcheck source=tools/parallels/guest-exec.sh
source "${SCRIPT_DIR}/../guest-exec.sh"

LOCAL_CONFIG="${REPO_ROOT}/local/parallels/linux.env"
if [[ -f "$LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_CONFIG"
fi

usage() {
  cat <<'EOF'
Usage: tools/parallels/linux/run-linux.sh [options]

Options:
  --vm <name>             Parallels VM name. Default: Linux
  --guest-repo <path>     Linux repo path. Default: /home/shane/Project/simplicity-engine
  --preset <name>         CMake preset to build. Default: linux-debug
  --target <name>         CMake target to build. Default: hello_pixel
  --sync <host|pull|none> Sync step before build. Default: host
                           host pulls from this Mac repo through a Parallels shared folder.
  --host-repo <path>      Linux path to this Mac repo through Parallels sharing.
                           Default: /media/psf/Home/<host repo path relative to $HOME>
  --test                  Run ctest after build.
  --no-test               Do not run ctest after build. Default.
  --launch                Launch the built executable. Default.
  --no-launch             Build only.
  -h, --help              Show this help.
EOF
}

host_repo_relative_path() {
  local host_home

  host_home="${HOME%/}"
  if [[ -n "$host_home" && "$REPO_ROOT" == "$host_home/"* ]]; then
    printf '%s\n' "${REPO_ROOT#"$host_home"/}"
  else
    basename "$REPO_ROOT"
  fi
}

default_host_repo() {
  printf '/media/psf/Home/%s\n' "$(host_repo_relative_path)"
}

host_branch() {
  git -C "$REPO_ROOT" branch --show-current
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
    --host-repo)
      HOST_REPO="${2:?Missing value for --host-repo}"
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

if [[ "$SYNC" != "host" && "$SYNC" != "pull" && "$SYNC" != "none" ]]; then
  echo "--sync must be 'host', 'pull', or 'none'." >&2
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

if [[ "$SYNC" == "host" ]]; then
  parallels_enable_host_home_sharing "$VM_NAME" "rerun the Linux build"
fi

if [[ "$status" == *"suspended"* ]]; then
  prlctl resume "$VM_NAME"
elif [[ "$status" != *"running"* ]]; then
  prlctl start "$VM_NAME"
fi

parallels_wait_for_guest_exec linux "$VM_NAME" "rerun the Linux build"

echo "Running Linux build in VM '${VM_NAME}' at '${GUEST_REPO}'"
echo "Mac repo: ${REPO_ROOT}"

GUEST_SYNC="$SYNC"
if [[ "$SYNC" == "host" ]]; then
  HOST_REPO="${HOST_REPO:-$(default_host_repo)}"
  HOST_BRANCH="$(host_branch)"
  if [[ -z "$HOST_BRANCH" ]]; then
    echo "--sync host requires the Mac checkout to be on a named branch." >&2
    exit 1
  fi

  echo "Syncing Linux checkout from Mac shared repo '${HOST_REPO}' branch '${HOST_BRANCH}'"
  if sync_output="$(prlctl exec "$VM_NAME" --current-user bash -lc \
    'repo="$1"; host_repo="$2"; branch="$3"; if [ ! -d "$host_repo/.git" ]; then echo host-repo-not-found; exit 1; fi; cd "$repo"; if git remote get-url mac >/dev/null 2>&1; then git remote set-url mac "$host_repo"; else git remote add mac "$host_repo"; fi; git fetch mac "$branch"; git pull --ff-only mac "$branch"' \
    bash \
    "$GUEST_REPO" \
    "$HOST_REPO" \
    "$HOST_BRANCH" </dev/null 2>&1)"; then
    printf '%s\n' "$sync_output"
  else
    case "$sync_output" in
      *host-repo-not-found*)
        echo "Mac shared repo was not found from the Linux VM: ${HOST_REPO}" >&2
        echo "Check Parallels shared folders, or pass --host-repo with the Linux-visible path." >&2
        ;;
      *)
        printf '%s\n' "$sync_output" >&2
        ;;
    esac
    exit 1
  fi
  GUEST_SYNC="none"
fi

cmd=(prlctl exec "$VM_NAME" --current-user bash \
  "${GUEST_REPO}/tools/parallels/linux/guest-build-run.sh" \
  --repo "$GUEST_REPO" \
  --preset "$PRESET" \
  --target "$TARGET" \
  --sync "$GUEST_SYNC")

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
    *"No CMAKE_C_COMPILER could be found."*|*"No CMAKE_CXX_COMPILER could be found."*)
      parallels_install_hint linux compiler "rerun the Linux build" >&2
      ;;
    *)
      printf '%s\n' "$output" >&2
      ;;
  esac
  exit 1
fi
