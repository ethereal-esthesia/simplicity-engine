#!/usr/bin/env bash
set -euo pipefail

cmake --preset linux-debug
cmake --build --preset linux-debug

cmake --preset linux-release
cmake --build --preset linux-release

cmake --preset windows-debug
cmake --build --preset windows-debug

cmake --preset windows-release
cmake --build --preset windows-release

echo "Linux debug:    build/linux-debug/hello_pixel"
echo "Linux release:  build/linux-release/hello_pixel"
echo "Windows debug:  build/windows-debug/hello_pixel.exe"
echo "Windows release: build/windows-release/hello_pixel.exe"
