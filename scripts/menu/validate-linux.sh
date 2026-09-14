#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${SIMPLICITY_MENU_BUILD_DIR:-/tmp/simplicity-menu-build}"
ARGS=()
if [[ -d "$ROOT/build/debug/_deps/sdl3-src" ]]; then
  ARGS+=("-DFETCHCONTENT_SOURCE_DIR_SDL3=$ROOT/build/debug/_deps/sdl3-src")
fi
cmake -S "$ROOT" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Debug "${ARGS[@]}"
cmake --build "$BUILD" -j 4
ctest --test-dir "$BUILD" --output-on-failure
