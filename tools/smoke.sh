#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_FLAVOR="${1:-release}"
BUILD_DIR="build/${BUILD_FLAVOR}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build directory not found: ${BUILD_DIR}"
  echo "Run: cmake --preset ${BUILD_FLAVOR} && cmake --build --preset ${BUILD_FLAVOR}"
  exit 1
fi

ctest --test-dir "${BUILD_DIR}" --output-on-failure -L smoke
