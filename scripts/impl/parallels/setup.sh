#!/usr/bin/env bash
set -euo pipefail

TARGET="windows"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# shellcheck source=scripts/impl/parallels/install-hints.sh
source "${SCRIPT_DIR}/install-hints.sh"
# shellcheck source=scripts/impl/parallels/guest-exec.sh
source "${SCRIPT_DIR}/guest-exec.sh"

usage() {
  cat <<'EOF'
Usage: scripts/parallels/setup.sh [options]

Options:
  --target <windows|linux>   Which local profile to write. Default: windows
  -h, --help                Show this help.
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
    *)
      usage_error "Unknown option: $1"
      ;;
  esac
done

if [[ "$TARGET" != "windows" && "$TARGET" != "linux" ]]; then
  usage_error "--target must be 'windows' or 'linux'."
fi

if ! command -v prlctl >/dev/null 2>&1; then
  echo "Parallels command-line tools were not found (`prlctl`)." >&2
  echo "Install the Parallels Desktop CLI tools, then rerun setup." >&2
  exit 1
fi

prompt() {
  local var_name="$1"
  local prompt_text="$2"

  if [[ -r /dev/tty ]]; then
    read -r -p "$prompt_text" "$var_name" </dev/tty
  else
    read -r -p "$prompt_text" "$var_name"
  fi
}

host_repo_relative_path() {
  local host_home
  local relative_path

  host_home="${HOME%/}"
  if [[ -n "$host_home" && "$REPO_ROOT" == "$host_home/"* ]]; then
    relative_path="${REPO_ROOT#"$host_home"/}"
  else
    relative_path="$(basename "$REPO_ROOT")"
  fi

  printf '%s\n' "$relative_path"
}

join_windows_path() {
  local base="$1"
  local relative_path="$2"
  local windows_relative

  windows_relative="${relative_path//\//\\}"
  printf '%s\\%s\n' "${base%\\}" "$windows_relative"
}

join_posix_path() {
  local base="$1"
  local relative_path="$2"

  printf '%s/%s\n' "${base%/}" "$relative_path"
}

default_shared_host_repo() {
  local relative_path
  local windows_relative

  relative_path="$(host_repo_relative_path)"
  if [[ "$TARGET" == "windows" ]]; then
    windows_relative="${relative_path//\//\\}"
    printf '\\\\Mac\\Home\\%s\n' "$windows_relative"
  else
    printf '/media/psf/Home/%s\n' "$relative_path"
  fi
}

ensure_vm_running() {
  local vm_name="$1"
  local status

  status="$(prlctl status "$vm_name" 2>/dev/null || true)"
  if [[ -z "$status" ]]; then
    echo "Parallels VM not found: $vm_name" >&2
    echo "Available VMs:" >&2
    prlctl list --all >&2
    exit 1
  elif [[ "$status" == *"suspended"* ]]; then
    prlctl resume "$vm_name"
  elif [[ "$status" != *"running"* ]]; then
    prlctl start "$vm_name"
  fi
}

wait_for_guest_exec() {
  local vm_name="$1"

  parallels_wait_for_guest_exec "$TARGET" "$vm_name" "rerun setup"
}

guest_repo_exists() {
  local vm_name="$1"
  local guest_repo="$2"

  if [[ "$TARGET" == "windows" ]]; then
    prlctl exec "$vm_name" --current-user powershell.exe \
      -NoProfile \
      -ExecutionPolicy Bypass \
      -Command '& { param($repo) if ((Test-Path -LiteralPath $repo -PathType Container) -and (Test-Path -LiteralPath (Join-Path $repo "scripts\parallels\setup.sh") -PathType Leaf)) { exit 0 } else { exit 1 } }' \
      "$guest_repo" >/dev/null 2>&1 </dev/null
  else
    prlctl exec "$vm_name" --current-user test -f "${guest_repo}/scripts/parallels/setup.sh" >/dev/null 2>&1 </dev/null
  fi
}

clone_repo_to_guest() {
  local vm_name="$1"
  local guest_repo="$2"
  local repo_url="$3"
  local clone_output

  if [[ "$TARGET" == "windows" ]]; then
    if clone_output="$(prlctl exec "$vm_name" --current-user powershell.exe \
      -NoProfile \
      -ExecutionPolicy Bypass \
      -Command '& { param($repo, $url) if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Output git-not-found; exit 1 }; if (Test-Path -LiteralPath $repo) { Write-Output path-exists-but-not-repo; exit 1 }; $parent = Split-Path -Parent $repo; New-Item -ItemType Directory -Force -Path $parent | Out-Null; & git clone $url $repo }' \
      "$guest_repo" \
      "$repo_url" </dev/null 2>&1)"; then
      printf '%s\n' "$clone_output"
    else
      case "$clone_output" in
        *git-not-found*)
          parallels_install_hint windows git "rerun setup" >&2
          ;;
        *path-exists-but-not-repo*)
          echo "Path exists but does not look like this repo: ${guest_repo}" >&2
          ;;
        *)
          printf '%s\n' "$clone_output" >&2
          ;;
      esac
      exit 1
    fi
  else
    if clone_output="$(prlctl exec "$vm_name" --current-user bash -lc \
      'repo="$1"; url="$2"; if ! command -v git >/dev/null 2>&1; then echo git-not-found; exit 1; fi; if [ -e "$repo" ]; then echo path-exists-but-not-repo; exit 1; fi; mkdir -p "$(dirname "$repo")"; git clone "$url" "$repo"' \
      bash \
      "$guest_repo" \
      "$repo_url" </dev/null 2>&1)"; then
      printf '%s\n' "$clone_output"
    else
      case "$clone_output" in
        *git-not-found*)
          parallels_install_hint linux git "rerun setup" >&2
          ;;
        *path-exists-but-not-repo*)
          echo "Path exists but does not look like this repo: ${guest_repo}" >&2
          ;;
        *)
          printf '%s\n' "$clone_output" >&2
          ;;
      esac
      exit 1
    fi
  fi
}

guest_default_repo() {
  local vm_name="$1"
  local guest_home
  local relative_path

  relative_path="$(host_repo_relative_path)"

  if [[ "$TARGET" == "windows" ]]; then
    guest_home="$(prlctl exec "$vm_name" --current-user powershell.exe \
      -NoProfile \
      -ExecutionPolicy Bypass \
      -Command '$env:USERPROFILE' </dev/null 2>/dev/null | tr -d '\r' || true)"
    guest_home="${guest_home%%$'\n'*}"
    if [[ -z "$guest_home" ]]; then
      guest_home="$(prlctl exec "$vm_name" --current-user cmd.exe /c echo %USERPROFILE% </dev/null 2>/dev/null | tr -d '\r' || true)"
    fi
    guest_home="${guest_home%%$'\n'*}"
    if [[ -n "$guest_home" ]]; then
      join_windows_path "$guest_home" "$relative_path"
      return
    fi

    join_windows_path 'C:\Users\shane' "$relative_path"
  else
    guest_home="$(prlctl exec "$vm_name" --current-user sh -lc 'printf %s "$HOME"' </dev/null 2>/dev/null || true)"
    guest_home="${guest_home%%$'\n'*}"
    if [[ -n "$guest_home" ]]; then
      join_posix_path "$guest_home" "$relative_path"
      return
    fi

    join_posix_path '/home/shane' "$relative_path"
  fi
}

verify_or_clone_guest_repo() {
  local vm_name="$1"
  local guest_repo="$2"
  local repo_url clone_answer

  if guest_repo_exists "$vm_name" "$guest_repo"; then
    echo "Verified ${TARGET} repo path: ${guest_repo}"
    return
  fi

  echo "The ${TARGET} repo path was not found, was not accessible, or did not look like this repo in the VM: ${guest_repo}" >&2
  repo_url="$(git -C "$REPO_ROOT" config --get remote.origin.url || true)"
  if [[ -z "$repo_url" ]]; then
    echo "No git origin remote is configured for ${REPO_ROOT}, so setup cannot clone it automatically." >&2
    echo "Create the folder inside the VM or add an origin remote, then rerun setup." >&2
    exit 1
  fi

  prompt clone_answer "Clone ${repo_url} into the ${TARGET} VM at ${guest_repo}? [y/N]: "
  case "$clone_answer" in
    [Yy]|[Yy][Ee][Ss])
      clone_repo_to_guest "$vm_name" "$guest_repo" "$repo_url"
      echo "Cloned repo into ${TARGET} VM: ${guest_repo}"
      ;;
    *)
      echo "Setup cannot continue until the repo path exists inside the VM." >&2
      exit 1
      ;;
  esac
}

vm_lines=()
while IFS= read -r line; do
  vm_lines+=("$line")
done < <(prlctl list --all --no-header)
if [[ "${#vm_lines[@]}" -eq 0 ]]; then
  echo "No registered Parallels VMs found. Create or register a VM first, then rerun this setup." >&2
  exit 1
fi

echo "Registered Parallels VMs:"
for index in "${!vm_lines[@]}"; do
  printf '  %d) %s\n' "$((index + 1))" "${vm_lines[$index]}"
done

prompt selection "Select VM number for ${TARGET}: "
if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#vm_lines[@]} )); then
  echo "Invalid selection: $selection" >&2
  exit 2
fi

selected_line="${vm_lines[$((selection - 1))]}"
vm_name="$(awk '{for (i=4; i<=NF; ++i) {printf "%s%s", (i == 4 ? "" : " "), $i}}' <<<"$selected_line")"
if [[ -z "$vm_name" ]]; then
  echo "Could not parse VM name from: $selected_line" >&2
  exit 1
fi

ensure_vm_running "$vm_name"
parallels_enable_host_home_sharing "$vm_name" "rerun setup"
wait_for_guest_exec "$vm_name"

if [[ "$TARGET" == "windows" ]]; then
  default_repo="$(guest_default_repo "$vm_name")"
  default_host_repo="$(default_shared_host_repo)"
  default_preset="debug"
  prompt guest_repo "Windows repo path [${default_repo}]: "
  prompt host_repo "Windows path to Mac shared repo [${default_host_repo}]: "
  prompt preset "CMake preset [${default_preset}]: "
  guest_repo="${guest_repo:-$default_repo}"
  host_repo="${host_repo:-$default_host_repo}"
  preset="${preset:-$default_preset}"
  output="${REPO_ROOT}/local/parallels/windows.env"
else
  default_repo="$(guest_default_repo "$vm_name")"
  default_host_repo="$(default_shared_host_repo)"
  default_preset="linux-debug"
  echo "Linux target selected. The documented package install commands assume an APT-based, Debian-compatible guest."
  prompt guest_repo "Linux repo path [${default_repo}]: "
  prompt host_repo "Linux path to Mac shared repo [${default_host_repo}]: "
  prompt preset "CMake preset [${default_preset}]: "
  guest_repo="${guest_repo:-$default_repo}"
  host_repo="${host_repo:-$default_host_repo}"
  preset="${preset:-$default_preset}"
  output="${REPO_ROOT}/local/parallels/linux.env"
fi

verify_or_clone_guest_repo "$vm_name" "$guest_repo"

mkdir -p "$(dirname "$output")"
{
  printf '# Generated by scripts/parallels/setup.sh. This file is gitignored.\n'
  printf 'VM_NAME=%q\n' "$vm_name"
  printf 'GUEST_REPO=%q\n' "$guest_repo"
  printf 'HOST_REPO=%q\n' "$host_repo"
  printf 'PRESET=%q\n' "$preset"
  printf 'SYNC=%q\n' host
} > "$output"

echo "Wrote ${output#"$REPO_ROOT"/}"
