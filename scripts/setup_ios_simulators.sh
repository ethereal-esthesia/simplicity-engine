#!/usr/bin/env bash
set -euo pipefail

PHONE=0
TABLET=0

usage() {
  cat <<'EOF'
Usage: ./scripts/setup_ios_simulators.sh [options]

Prepare iOS Simulator prerequisites and device-class lanes.

Options:
  --phone               Prepare the iPhone simulator lane.
  --tablet              Prepare the iPad simulator lane.
  --all                 Prepare both simulator lanes.
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

echo "iOS simulator bootstrap is not wired yet." >&2
echo "Planned scope: Xcode/runtime checks plus stable iPhone and iPad simulator setup." >&2
exit 1
