#!/usr/bin/env bash
set -euo pipefail

# Hosted runners can already have a working gem-installed CocoaPods. Installing
# the Homebrew formula over it fails on the existing /usr/local/bin/pod link.
for pair in xcodegen:xcodegen pod:cocoapods idevice_id:libimobiledevice; do
  command_name=${pair%%:*}
  formula=${pair#*:}
  if command -v "$command_name" >/dev/null 2>&1; then
    "$command_name" --version
  else
    brew install "$formula"
    "$command_name" --version
  fi
done
