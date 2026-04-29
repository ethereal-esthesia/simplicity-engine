#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ARCH_LABEL="${ARCH_LABEL:-arm64}"
MACOS_CMAKE_ARCH="${MACOS_CMAKE_ARCH:-}"
if [[ -z "${MACOS_CMAKE_ARCH}" ]]; then
  case "${ARCH_LABEL}" in
    arm64) MACOS_CMAKE_ARCH="arm64" ;;
    x64) MACOS_CMAKE_ARCH="x86_64" ;;
    *) echo "Unsupported ARCH_LABEL: ${ARCH_LABEL}" >&2; exit 1 ;;
  esac
fi
mkdir -p dist

cmake --preset release -DCMAKE_OSX_ARCHITECTURES="${MACOS_CMAKE_ARCH}"
cmake --build --preset release
ctest --test-dir build/release --output-on-failure

STAGE_DIR="dist/simplicity-engine-macos-${ARCH_LABEL}"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp "build/release/hello_pixel" "$STAGE_DIR/"

tar -C dist -czf "dist/simplicity-engine-macos-${ARCH_LABEL}.tar.gz" "simplicity-engine-macos-${ARCH_LABEL}"
echo "Created dist/simplicity-engine-macos-${ARCH_LABEL}.tar.gz"
