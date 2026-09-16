#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET=macos
CHECK=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 && "$2" != --* ]] || { echo "Missing target." >&2; exit 2; }
      TARGET="$2"; shift 2 ;;
    --check) CHECK=1; shift ;;
    -h|--help) echo 'Usage: scripts/dev-setup.sh [--target macos|ios] [--check]'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$TARGET" in macos|ios) ;; *) echo "Unsupported native target: $TARGET" >&2; exit 2;; esac
[[ $(uname -s) == Darwin ]] || { echo 'Apple development requires macOS.' >&2; exit 1; }
for tool in cmake ninja python3 xcrun; do
  command -v "$tool" >/dev/null || { echo "Install $tool; see docs/developer-setup.md." >&2; exit 1; }
done
xcrun --find clang++ >/dev/null
if [[ "$TARGET" == ios ]]; then
  xcrun --find simctl >/dev/null
  xcrun --sdk iphonesimulator --show-sdk-path >/dev/null
  if [[ "$CHECK" == 0 ]]; then exec bash "$ROOT/scripts/impl/dev_setup/ios.sh" --phone; fi
fi
echo "Ready: $TARGET developer tools"
