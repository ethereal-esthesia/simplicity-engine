#!/usr/bin/env bash
set -euo pipefail
# Run inside the OS being prepared. --install may install missing packages.
INSTALL=0
case "${1:-}" in --install) INSTALL=1;; ""|--check) ;; *) echo 'Usage: setup.sh [--check|--install]' >&2; exit 2;; esac
case "$(uname -s)" in
  Darwin)
    xcrun --find clang++ >/dev/null
    if [[ "$INSTALL" == 1 ]] && { ! command -v cmake >/dev/null || ! command -v ninja >/dev/null; }; then
      brew install cmake ninja
    fi
    command -v cmake; command -v ninja
    echo 'macOS menu setup: ready (AppKit + C++17 + SDL fetched by CMake)'
    ;;
  Linux)
    if [[ "$INSTALL" == 1 ]]; then
      ELEVATE=(); if [[ $EUID != 0 ]]; then ELEVATE=(sudo); fi
      if command -v dnf >/dev/null; then
        "${ELEVATE[@]}" dnf install -y gcc-c++ cmake ninja-build pkgconf-pkg-config gtk3-devel libXcursor-devel libXi-devel libXrandr-devel mesa-libEGL-devel wayland-devel libxkbcommon-devel xorg-x11-server-Xvfb xorg-x11-xauth
      elif command -v apt-get >/dev/null; then
        "${ELEVATE[@]}" apt-get update
        "${ELEVATE[@]}" apt-get install -y g++ cmake ninja-build pkg-config libgtk-3-dev libxcursor-dev libxi-dev libxrandr-dev libegl1-mesa-dev libwayland-dev libxkbcommon-dev xvfb xauth
      else echo 'Install a C++17 compiler, CMake, Ninja, pkg-config and GTK3 development files.' >&2; exit 1; fi
    fi
    command -v c++; command -v cmake; command -v ninja
    pkg-config --modversion gtk+-3.0
    echo 'Linux menu setup: ready (GTK3)'
    ;;
  *) echo 'For Windows use scripts/dev-setup.ps1.' >&2; exit 1;;
esac
