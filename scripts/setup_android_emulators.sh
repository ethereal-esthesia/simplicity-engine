#!/usr/bin/env bash
set -euo pipefail

PHONE=0
TABLET=0

usage() {
  cat <<'EOF'
Usage: ./scripts/setup_android_emulators.sh [options]

Prepare Android emulator prerequisites and AVD lanes.

Options:
  --phone               Prepare the Android phone lane.
  --tablet              Prepare the Android tablet lane.
  --all                 Prepare both Android emulator lanes.
  --sdk-only            Only verify or install shared Android SDK prerequisites.
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phone)
      PHONE=1
      shift
      ;;
    --tablet)
      TABLET=1
      shift
      ;;
    --all)
      PHONE=1
      TABLET=1
      shift
      ;;
    --sdk-only)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo "Android emulator bootstrap is not wired yet." >&2
echo "Planned scope: shared SDK checks plus stable phone and tablet AVD creation." >&2
exit 1
