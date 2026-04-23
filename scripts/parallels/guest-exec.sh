#!/usr/bin/env bash

parallels_wait_for_guest_exec() {
  local target="${1:?Missing guest target}"
  local vm_name="${2:?Missing VM name}"
  local retry_action="${3:-rerun the command}"
  local attempts="${4:-${PARALLELS_GUEST_EXEC_ATTEMPTS:-30}}"
  local delay_seconds="${5:-${PARALLELS_GUEST_EXEC_DELAY_SECONDS:-2}}"
  local attempt
  local last_output=""

  echo "Waiting for ${target} guest commands to become available..."
  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    case "$target" in
      windows)
        if last_output="$(prlctl exec "$vm_name" --current-user powershell.exe \
          -NoProfile \
          -ExecutionPolicy Bypass \
          -Command 'exit 0' </dev/null 2>&1)"; then
          return 0
        fi
        ;;
      linux)
        if last_output="$(prlctl exec "$vm_name" --current-user true </dev/null 2>&1)"; then
          return 0
        fi
        ;;
      *)
        echo "Unknown Parallels guest target: $target" >&2
        return 2
        ;;
    esac

    if [[ "$attempt" -lt "$attempts" ]]; then
      sleep "$delay_seconds"
    fi
  done

  echo "Timed out waiting for guest commands in VM: $vm_name" >&2
  echo "Log in to the VM desktop and make sure Parallels Tools are running, then ${retry_action}." >&2
  if [[ -n "$last_output" ]]; then
    echo "Last Parallels error:" >&2
    printf '%s\n' "$last_output" >&2
  fi
  return 1
}
