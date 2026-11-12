#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_dir"
config_file="$repo_dir/local/apple-development-team"
action=${1:-help}
if [[ $# -gt 0 ]]; then shift; fi

case "$action" in
  setup)
    if [[ $(uname -s) != Darwin ]]; then
      echo 'iOS device builds require macOS and full Xcode.' >&2; exit 1
    fi
    echo 'Sign in using Xcode > Settings > Apple Accounts first.'
    echo 'Enter the 10-character Team ID (Organizational Unit), not your Apple login or password.'
    echo 'Find it in Keychain Access > Apple Development certificate > Details > Subject Name > Organizational Unit.'
    read -r -p 'Apple development Team ID (Organizational Unit): ' team
    if [[ ! "$team" =~ ^[A-Z0-9]{10}$ ]]; then
      echo 'Expected a 10-character uppercase alphanumeric Team ID.' >&2; exit 1
    fi
    umask 077
    mkdir -p "$repo_dir/local"
    printf '%s\n' "$team" > "$config_file"
    chmod 600 "$config_file"
    echo 'Saved local team selection. Credentials remain managed by Xcode/Keychain.'
    ;;
  init|dev|build)
    if [[ ! -f "$config_file" ]]; then
      echo 'Run bash scripts/ios-device.sh setup first; see docs/test-installers.md.' >&2; exit 1
    fi
    IFS= read -r APPLE_DEVELOPMENT_TEAM < "$config_file"
    if [[ ! "$APPLE_DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
      echo 'Invalid saved Team ID; rerun setup.' >&2; exit 1
    fi
    export APPLE_DEVELOPMENT_TEAM
    if [[ "$action" == init ]]; then
      npm run tauri -- ios init "$@"
      exec node scripts/configure-ios-xcode.mjs
    fi
    node scripts/configure-ios-xcode.mjs
    exec npm run tauri -- ios "$action" "$@"
    ;;
  *)
    echo 'Usage: bash scripts/ios-device.sh setup|init|dev|build [Tauri options]'
    echo 'For personal device testing: init, then dev --open.'
    [[ "$action" == help || "$action" == --help ]]
    ;;
esac
