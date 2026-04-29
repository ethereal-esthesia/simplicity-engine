#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/run_ios_simulator.sh" \
  --preset ios-ipad-simulator-debug \
  --device-class ipad \
  "$@"
