#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARCH_LABEL="${ARCH_LABEL:-arm64}"
mkdir -p dist

cmake --preset release
cmake --build --preset release
./tools/smoke.sh release

STAGE_DIR="dist/simplicity-engine-macos-${ARCH_LABEL}"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp "build/release/hello_pixel" "$STAGE_DIR/"

tar -C dist -czf "dist/simplicity-engine-macos-${ARCH_LABEL}.tar.gz" "simplicity-engine-macos-${ARCH_LABEL}"
echo "Created dist/simplicity-engine-macos-${ARCH_LABEL}.tar.gz"
