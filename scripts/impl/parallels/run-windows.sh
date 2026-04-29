#!/usr/bin/env bash
set -euo pipefail

VM_NAME="Windows 11"
GUEST_REPO='C:\Users\shane\Project\simplicity-engine'
PRESET="debug"
TARGET="hello_pixel"
SYNC="host"
HOST_REPO=""
RUN_TESTS=0
LAUNCH=1
NATIVE_MODE=0
CONSOLE_OUTPUT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=scripts/impl/parallels/install-hints.sh
source "${SCRIPT_DIR}/install-hints.sh"
# shellcheck source=scripts/impl/parallels/guest-exec.sh
source "${SCRIPT_DIR}/guest-exec.sh"

LOCAL_CONFIG="${REPO_ROOT}/local/parallels/windows.env"
if [[ -f "$LOCAL_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_CONFIG"
fi

usage() {
  cat <<'EOF'
Usage: scripts/parallels/run-windows.sh [options]

Options:
  --vm <name>             Parallels VM name. Default: Windows 11
  --guest-repo <path>     Windows repo path. Default: C:\Users\shane\Project\simplicity-engine
  --preset <name>         CMake preset to build. Default: debug
  --target <name>         CMake target to build. Default: hello_pixel
  --sync <host|pull|none> Sync step before build. Default: host
                           host checks out this Mac repo branch through a Parallels shared folder.
  --host-repo <path>      Windows path to this Mac repo through Parallels sharing.
                           Default: \\Mac\Home\<host repo path relative to $HOME>
  --test                  Run ctest after build.
  --no-test               Do not run ctest after build. Default.
  --launch                Launch the built executable. Default.
  --no-launch             Build only.
  --native                Enable guest-to-host app sharing before launch.
  --console               Print full Windows build output. Default: write it to logs/.
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
  local relative_path
  local windows_relative

  relative_path="$(host_repo_relative_path)"
  windows_relative="${relative_path//\//\\}"
  printf '\\\\Mac\\Home\\%s\n' "$windows_relative"
}

host_branch() {
  git -C "$REPO_ROOT" branch --show-current
}

create_run_log() {
  local logs_dir="${REPO_ROOT}/logs"
  local timestamp
  local log_path

  mkdir -p "$logs_dir"
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  log_path="${logs_dir}/run_windows_${timestamp}.log"
  if [[ -e "$log_path" ]]; then
    log_path="${logs_dir}/run_windows_${timestamp}_$$.log"
  fi
  printf '%s\n' "$log_path"
}

append_log() {
  local message="$1"

  printf '%s\n' "$message" >> "$LOG_PATH"
}

append_file_to_log() {
  local file="$1"

  cat "$file" >> "$LOG_PATH"
  printf '\n' >> "$LOG_PATH"
}

print_file_safely() {
  local file="$1"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s\n' "$line" || return 0
  done < "$file"
}

file_contains() {
  local file="$1"
  local pattern="$2"

  grep -Fq -- "$pattern" "$file"
}

run_prlctl_set_logged() {
  local description="$1"
  local required="$2"
  local output

  shift 2

  if output="$(prlctl set "$VM_NAME" "$@" 2>&1)"; then
    append_log "${description}:"
    append_log "$output"
    append_log ""
  else
    append_log "${description} failed:"
    append_log "$output"
    append_log ""
    if [[ "$required" -eq 1 ]]; then
      echo "${description} failed. See log: ${LOG_PATH}" >&2
      exit 1
    fi
    echo "Warning: ${description} failed. See log: ${LOG_PATH}" >&2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm)
      VM_NAME="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --guest-repo)
      GUEST_REPO="$(require_option_value "$1" "${2-}")"
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
    --host-repo)
      HOST_REPO="$(require_option_value "$1" "${2-}")"
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
    --native)
      NATIVE_MODE=1
      shift
      ;;
    --console)
      CONSOLE_OUTPUT=1
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

if [[ "$SYNC" != "host" && "$SYNC" != "pull" && "$SYNC" != "none" ]]; then
  usage_error "--sync must be 'host', 'pull', or 'none'."
fi

if ! command -v prlctl >/dev/null 2>&1; then
  echo "Parallels command-line tools were not found (`prlctl`)." >&2
  echo "Install the Parallels Desktop CLI tools, then rerun the Windows build." >&2
  exit 1
fi

LOG_PATH="$(create_run_log)"
append_log "run-windows started: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
append_log "vm: ${VM_NAME}"
append_log "mac repo: ${REPO_ROOT}"
append_log "guest repo: ${GUEST_REPO}"
append_log "preset: ${PRESET}"
append_log "target: ${TARGET}"
append_log "sync: ${SYNC}"
append_log "launch: ${LAUNCH}"
append_log "run tests: ${RUN_TESTS}"
append_log ""

status="$(prlctl status "$VM_NAME" 2>/dev/null || true)"
if [[ -z "$status" ]]; then
  echo "Parallels VM not found: ${VM_NAME}" >&2
  echo "Available VMs:" >&2
  prlctl list --all >&2
  exit 1
fi

run_prlctl_set_logged "Set VM startup view to headless" 0 --startup-view headless
if [[ "$SYNC" == "host" ]]; then
  run_prlctl_set_logged "Configure host Home sharing" 1 \
    --shf-host on \
    --shf-host-defined home \
    --shf-host-automount on
fi

if [[ "$status" == *"suspended"* ]]; then
  prlctl resume "$VM_NAME"
elif [[ "$status" != *"running"* ]]; then
  prlctl start "$VM_NAME"
fi

parallels_wait_for_guest_exec windows "$VM_NAME" "rerun the Windows build"

guest_script="${GUEST_REPO}\\scripts\\parallels\\guest-build-run.ps1"
HOST_BRANCH=""

if [[ "$NATIVE_MODE" -eq 1 ]]; then
  run_prlctl_set_logged "Configure guest app sharing" 1 \
    --sh-app-guest-to-host on \
    --sh-app-host-to-guest off \
    --show-guest-app-folder-in-dock off \
    --winsystray-in-macmenu off
fi

echo "Running Windows build in VM '${VM_NAME}' at '${GUEST_REPO}'"
echo "Mac repo: ${REPO_ROOT}"
echo "Log: ${LOG_PATH}"

GUEST_SYNC="$SYNC"
if [[ "$SYNC" == "host" ]]; then
  HOST_REPO="${HOST_REPO:-$(default_host_repo)}"
  HOST_BRANCH="$(host_branch)"
  if [[ -z "$HOST_BRANCH" ]]; then
    echo "--sync host requires the Mac checkout to be on a named git branch." >&2
    echo "Switch to a named branch first, then rerun the Windows build." >&2
    exit 1
  fi

  guest_script="${HOST_REPO}\\scripts\\parallels\\guest-build-run.ps1"
  append_log "host repo: ${HOST_REPO}"
  append_log "host branch: ${HOST_BRANCH}"
  echo "Syncing Windows checkout from Mac shared repo '${HOST_REPO}' branch '${HOST_BRANCH}'"
fi

cmd=(prlctl exec "$VM_NAME" --current-user powershell.exe \
  -WindowStyle Minimized \
  -NoProfile \
  -ExecutionPolicy Bypass \
  -File "$guest_script" \
  -Repo "$GUEST_REPO" \
  -Preset "$PRESET" \
  -Target "$TARGET" \
  -Sync "$GUEST_SYNC")

if [[ "$SYNC" == "host" ]]; then
  cmd+=(-HostRepo "$HOST_REPO" -HostBranch "$HOST_BRANCH")
fi

if [[ "$RUN_TESTS" -eq 1 ]]; then
  cmd+=(-RunTests)
fi

if [[ "$LAUNCH" -eq 1 ]]; then
  cmd+=(-Launch)
fi

build_output="$(mktemp "${TMPDIR:-/tmp}/simplicity-windows-build.XXXXXX")"
trap 'rm -f "$build_output"' EXIT

if "${cmd[@]}" >"$build_output" 2>&1; then
  append_log "build output:"
  append_file_to_log "$build_output"
  if file_contains "$build_output" "No CMAKE_C_COMPILER could be found." || file_contains "$build_output" "No CMAKE_CXX_COMPILER could be found."; then
    parallels_install_hint windows compiler "rerun the Windows build" >&2
    echo "Full log: ${LOG_PATH}" >&2
    exit 1
  fi

  if [[ "$CONSOLE_OUTPUT" -eq 1 ]]; then
    print_file_safely "$build_output"
  else
    echo "Windows build succeeded. Full log: ${LOG_PATH}"
  fi
else
  append_log "build failed:"
  append_file_to_log "$build_output"
  if file_contains "$build_output" "Required command not found in Windows PATH: cmake" || file_contains "$build_output" "cmake was not found in the Windows VM"; then
    parallels_install_hint windows cmake "rerun the Windows build" >&2
  elif file_contains "$build_output" "host-repo-not-found" || file_contains "$build_output" "Mac shared repo was not found from the Windows VM"; then
    echo "Mac shared repo was not found from the Windows VM: ${HOST_REPO}" >&2
    echo "Check Parallels shared folders, or pass --host-repo with the Windows-visible path." >&2
  elif file_contains "$build_output" "Required command not found in Windows PATH: git" || file_contains "$build_output" "git was not found in the Windows VM"; then
    parallels_install_hint windows git "rerun the Windows build" >&2
  elif file_contains "$build_output" "Required command not found in Windows PATH: ninja" || file_contains "$build_output" "ninja was not found in the Windows VM"; then
    parallels_install_hint windows ninja "rerun the Windows build" >&2
  elif file_contains "$build_output" "No CMAKE_C_COMPILER could be found." || file_contains "$build_output" "No CMAKE_CXX_COMPILER could be found."; then
    parallels_install_hint windows compiler "rerun the Windows build" >&2
  else
    if [[ "$CONSOLE_OUTPUT" -eq 1 ]]; then
      print_file_safely "$build_output" >&2
    else
      echo "Windows build failed. See log: ${LOG_PATH}" >&2
    fi
  fi
  echo "Full log: ${LOG_PATH}" >&2
  exit 1
fi
