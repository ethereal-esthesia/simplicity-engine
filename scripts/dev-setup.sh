#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v python3 >/dev/null; then
  echo 'SETUP INCOMPLETE: Python 3 is required to run setup.' >&2
  exit 3
fi
exec python3 "$ROOT/scripts/impl/dev_setup/main.py" "$@"
