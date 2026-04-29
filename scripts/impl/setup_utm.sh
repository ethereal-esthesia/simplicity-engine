#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_DOWNLOAD_DIR="${REPO_ROOT}/local/utm/media"

WINDOWS_DOWNLOAD_PAGE="https://www.microsoft.com/en-us/software-download/windows11arm64"
LINUX_DEFAULT_URL="https://cdimage.ubuntu.com/releases/24.04.4/release/ubuntu-24.04.4-desktop-arm64.iso"
MACOS_UTM_DOCS_URL="https://docs.getutm.app/guest-support/macos/"

INSTALL_UTM=true
OPEN_URLS=true
FORCE_DOWNLOAD=false
DOWNLOAD_DIR="${DEFAULT_DOWNLOAD_DIR}"
SELECTED_PLATFORMS=()
MEDIA_OVERRIDE=""
SAW_PLATFORM_FLAG=false
COMMON_HOST_SETUP_DONE=false
DOWNLOAD_ROOT_READY=false
WINDOWS_PIPELINE_DONE=false
LINUX_PIPELINE_DONE=false
MACOS_PIPELINE_DONE=false

usage() {
  cat <<EOF
Usage: ./scripts/setup_utm.sh [options]

Install UTM on this Mac, prepare ignored local media folders, and stage guest media
for Windows, Linux, and macOS UTM setups.

Platform selection:
  --all                 Prepare Windows, Linux, and macOS guest setup paths.
  --windows             Prepare the Windows guest setup path.
  --linux               Prepare the Linux guest setup path.
  --macos               Prepare the macOS guest setup path.

Media options:
  --iso <path>          Use a local ISO or IPSW for the selected platform.
                        This requires selecting exactly one platform.
  --download-dir <dir>  Store guest media under this directory.
                        Default: ${DEFAULT_DOWNLOAD_DIR}
  --force               Re-download or replace staged media even if it already exists.

Host setup:
  --skip-install-utm    Do not install or upgrade UTM with Homebrew.
  --no-open             Do not open browser pages for manual download steps.
  --help                Show this help.

Notes:
  - With no platform flags, the script only checks host prerequisites and prepares
    the local media cache root. It does not start guest media flows.
  - Windows uses Microsoft's interactive download page when no ISO is provided.
  - Linux defaults to the official Ubuntu 24.04.4 ARM64 desktop ISO.
  - macOS tries to fetch the latest supported restore image from Apple's
    virtualization service. If that fails, UTM can still download the latest
    compatible IPSW automatically from its VM wizard.
EOF
}

friendly_next_step_note() {
  cat <<EOF

Next step:
  Choose which guest setup path you want to prepare.

Examples:
  ./scripts/setup_utm.sh --windows
  ./scripts/setup_utm.sh --linux
  ./scripts/setup_utm.sh --macos
  ./scripts/setup_utm.sh --all

If you already downloaded your own media, pass it explicitly:
  ./scripts/setup_utm.sh --windows --iso /path/to/windows.iso
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

add_platform() {
  local platform="$1"
  local existing

  for existing in "${SELECTED_PLATFORMS[@]:-}"; do
    if [[ "${existing}" == "${platform}" ]]; then
      return 0
    fi
  done

  SELECTED_PLATFORMS+=("${platform}")
}

mark_step_done() {
  local flag_name="$1"
  printf -v "${flag_name}" '%s' true
}

step_done() {
  local flag_name="$1"
  [[ "${!flag_name}" == true ]]
}

note_already_installed() {
  local label="$1"
  echo "(already installed: ${label})"
}

platform_media_dir() {
  local platform="$1"
  printf '%s/%s\n' "${DOWNLOAD_DIR}" "${platform}"
}

stage_local_media() {
  local platform="$1"
  local source_path="$2"
  local destination_dir
  local destination_path

  destination_dir="$(platform_media_dir "${platform}")"
  mkdir -p "${destination_dir}"

  if [[ ! -e "${source_path}" ]]; then
    echo "Local media path does not exist: ${source_path}" >&2
    exit 1
  fi

  destination_path="${destination_dir}/$(basename "${source_path}")"
  if [[ -L "${destination_path}" || -f "${destination_path}" ]]; then
    rm -f "${destination_path}"
  fi

  ln -s "$(cd "$(dirname "${source_path}")" && pwd)/$(basename "${source_path}")" "${destination_path}"
  echo "Staged ${platform} media at ${destination_path}"
}

download_file() {
  local url="$1"
  local destination_path="$2"
  local label="$3"
  local destination_dir
  local temp_path

  destination_dir="$(dirname "${destination_path}")"
  mkdir -p "${destination_dir}"

  if [[ -f "${destination_path}" && "${FORCE_DOWNLOAD}" != true ]]; then
    echo "${label} already present at ${destination_path}"
    return 0
  fi

  temp_path="${destination_path}.part"
  rm -f "${temp_path}"

  echo "Downloading ${label}"
  echo "  from: ${url}"
  echo "  to:   ${destination_path}"
  curl -L --fail --progress-bar "${url}" -o "${temp_path}"
  mv "${temp_path}" "${destination_path}"
}

install_utm() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "UTM setup is only supported from macOS hosts." >&2
    exit 1
  fi

  if [[ "${INSTALL_UTM}" != true ]]; then
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew was not found." >&2
    echo "Install Homebrew first from https://brew.sh/, then rerun ./scripts/setup_utm.sh." >&2
    exit 1
  fi

  echo "Installing or upgrading UTM with Homebrew..."
  brew install --cask utm
}

ensure_media_root() {
  if step_done DOWNLOAD_ROOT_READY; then
    note_already_installed "UTM media cache root"
    return 0
  fi

  mkdir -p "${DOWNLOAD_DIR}"
  echo "Prepared UTM media cache root: ${DOWNLOAD_DIR}"
  mark_step_done DOWNLOAD_ROOT_READY
}

ensure_common_host_setup() {
  if step_done COMMON_HOST_SETUP_DONE; then
    note_already_installed "UTM host prerequisites"
    return 0
  fi

  ensure_media_root
  install_utm
  echo "UTM host setup looks ready."
  mark_step_done COMMON_HOST_SETUP_DONE
}

fetch_latest_macos_restore_url() {
  local swift_script
  swift_script="$(mktemp)"

  cat > "${swift_script}" <<'SWIFT'
import Foundation
import Virtualization

let semaphore = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0
var output = ""

VZMacOSRestoreImage.fetchLatestSupported { result in
    defer { semaphore.signal() }
    switch result {
    case .success(let image):
        output = image.url.absoluteString
    case .failure(let error):
        fputs("ERROR: \(error)\n", stderr)
        exitCode = 1
    }
}

if semaphore.wait(timeout: .now() + 120) == .timedOut {
    fputs("ERROR: timed out fetching macOS restore image URL\n", stderr)
    exit(Int32(1))
}

if !output.isEmpty {
    print(output)
}
exit(exitCode)
SWIFT

  swift "${swift_script}"
  rm -f "${swift_script}"
}

open_url_if_allowed() {
  local url="$1"

  if [[ "${OPEN_URLS}" == true ]]; then
    open "${url}" >/dev/null 2>&1 || true
  fi
}

write_instruction_file() {
  local path="$1"
  local body="$2"

  mkdir -p "$(dirname "${path}")"
  printf '%s\n' "${body}" > "${path}"
}

prepare_windows() {
  if step_done WINDOWS_PIPELINE_DONE; then
    note_already_installed "windows pipeline setup"
    return 0
  fi

  ensure_common_host_setup

  local destination_dir
  local instruction_path

  destination_dir="$(platform_media_dir windows)"
  mkdir -p "${destination_dir}"

  if [[ -n "${MEDIA_OVERRIDE}" ]]; then
    stage_local_media windows "${MEDIA_OVERRIDE}"
    mark_step_done WINDOWS_PIPELINE_DONE
    return 0
  fi

  instruction_path="${destination_dir}/README.txt"
  write_instruction_file "${instruction_path}" "Windows guest media is staged manually here.

Microsoft's official Windows 11 Arm64 download flow is interactive:
${WINDOWS_DOWNLOAD_PAGE}

Download the ISO from that page, then place it in:
${destination_dir}

After that, rerun:
./scripts/setup_utm.sh --windows --iso <path-to-your-downloaded-iso>
"

  echo "Windows setup folder prepared at ${destination_dir}"
  echo "Microsoft uses an interactive download page for Windows 11 Arm64."
  echo "Open ${WINDOWS_DOWNLOAD_PAGE}, download the ISO, and place it in ${destination_dir}."
  echo "A reminder file was written to ${instruction_path}"
  open_url_if_allowed "${WINDOWS_DOWNLOAD_PAGE}"
  mark_step_done WINDOWS_PIPELINE_DONE
}

prepare_linux() {
  if step_done LINUX_PIPELINE_DONE; then
    note_already_installed "linux pipeline setup"
    return 0
  fi

  ensure_common_host_setup

  local destination_dir
  local destination_path

  destination_dir="$(platform_media_dir linux)"
  mkdir -p "${destination_dir}"

  if [[ -n "${MEDIA_OVERRIDE}" ]]; then
    stage_local_media linux "${MEDIA_OVERRIDE}"
    mark_step_done LINUX_PIPELINE_DONE
    return 0
  fi

  destination_path="${destination_dir}/ubuntu-24.04.4-desktop-arm64.iso"
  download_file "${LINUX_DEFAULT_URL}" "${destination_path}" "Ubuntu ARM64 desktop ISO"
  mark_step_done LINUX_PIPELINE_DONE
}

prepare_macos() {
  if step_done MACOS_PIPELINE_DONE; then
    note_already_installed "macos pipeline setup"
    return 0
  fi

  ensure_common_host_setup

  local destination_dir
  local destination_path
  local restore_url
  local file_name
  local instruction_path

  destination_dir="$(platform_media_dir macos)"
  mkdir -p "${destination_dir}"

  if [[ -n "${MEDIA_OVERRIDE}" ]]; then
    stage_local_media macos "${MEDIA_OVERRIDE}"
    mark_step_done MACOS_PIPELINE_DONE
    return 0
  fi

  if restore_url="$(fetch_latest_macos_restore_url 2>/tmp/simplicity-engine-macos-restore.err)"; then
    file_name="$(basename "${restore_url%%\?*}")"
    if [[ -z "${file_name}" ]]; then
      file_name="latest-supported-macos.ipsw"
    fi
    destination_path="${destination_dir}/${file_name}"
    download_file "${restore_url}" "${destination_path}" "latest supported macOS restore image"
    rm -f /tmp/simplicity-engine-macos-restore.err
    mark_step_done MACOS_PIPELINE_DONE
    return 0
  fi

  instruction_path="${destination_dir}/README.txt"
  write_instruction_file "${instruction_path}" "macOS guest media could not be fetched automatically from Apple's virtualization service.

UTM can still download the latest compatible IPSW automatically:
${MACOS_UTM_DOCS_URL}

Or you can supply a local IPSW manually with:
./scripts/setup_utm.sh --macos --iso <path-to-ipsw>

The underlying fetch error was:
$(cat /tmp/simplicity-engine-macos-restore.err 2>/dev/null || echo 'Unknown error')
"

  echo "macOS setup folder prepared at ${destination_dir}"
  echo "Automatic macOS restore image download was not available on this host."
  echo "UTM can still download the latest compatible IPSW automatically from its VM wizard."
  echo "A reminder file was written to ${instruction_path}"
  open_url_if_allowed "${MACOS_UTM_DOCS_URL}"
  mark_step_done MACOS_PIPELINE_DONE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      add_platform windows
      add_platform linux
      add_platform macos
      SAW_PLATFORM_FLAG=true
      shift
      ;;
    --windows)
      add_platform windows
      SAW_PLATFORM_FLAG=true
      shift
      ;;
    --linux)
      add_platform linux
      SAW_PLATFORM_FLAG=true
      shift
      ;;
    --macos)
      add_platform macos
      SAW_PLATFORM_FLAG=true
      shift
      ;;
    --iso)
      MEDIA_OVERRIDE="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --download-dir)
      DOWNLOAD_DIR="$(require_option_value "$1" "${2-}")"
      shift 2
      ;;
    --skip-install-utm)
      INSTALL_UTM=false
      shift
      ;;
    --no-open)
      OPEN_URLS=false
      shift
      ;;
    --force)
      FORCE_DOWNLOAD=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage_error "Unknown option: $1"
      ;;
  esac
done

if [[ -n "${MEDIA_OVERRIDE}" && "${#SELECTED_PLATFORMS[@]}" -ne 1 ]]; then
  usage_error "--iso requires exactly one selected platform."
fi

if [[ "${SAW_PLATFORM_FLAG}" != true ]]; then
  ensure_common_host_setup
  echo "Media cache root: ${DOWNLOAD_DIR}"
  friendly_next_step_note
  exit 0
fi

for platform in "${SELECTED_PLATFORMS[@]}"; do
  case "${platform}" in
    windows)
      prepare_windows
      ;;
    linux)
      prepare_linux
      ;;
    macos)
      prepare_macos
      ;;
    *)
      echo "Internal error: unsupported platform ${platform}" >&2
      exit 1
      ;;
  esac
done

echo
echo "UTM host setup complete."
echo "Guest media root: ${DOWNLOAD_DIR}"
