#!/usr/bin/env bash
simplicity_install_hint() {
  local command_name="$2"
  local rerun_hint="${3:-rerun the previous command}"
  echo "${command_name} was not found on macOS. Install it, then ${rerun_hint}. See docs/developer-setup.md."
}
