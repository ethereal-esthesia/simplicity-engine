#!/usr/bin/env bash

simplicity_install_hint() {
  local platform="$1"
  local command_name="$2"
  local rerun_hint="${3:-rerun the previous command}"
  local package_hint=""
  local location=""

  case "${platform}:${command_name}" in
    windows:git)
      package_hint="Git for Windows"
      ;;
    windows:cmake|macos:cmake|linux-host:cmake)
      package_hint="CMake"
      ;;
    windows:ninja|macos:ninja|linux-host:ninja)
      package_hint="Ninja"
      ;;
    windows:compiler|windows:cl)
      package_hint="Visual Studio Build Tools with the C++ workload"
      ;;
    macos:compiler)
      package_hint="Apple's compiler tools"
      ;;
    linux:compiler|linux-host:compiler)
      package_hint="a C/C++ compiler toolchain such as build-essential"
      ;;
    linux:*)
      package_hint="${command_name}"
      ;;
    *)
      package_hint="${command_name}"
      ;;
  esac

  case "$platform" in
    windows)
      location="in the Windows VM"
      ;;
    linux)
      location="in the Linux VM"
      ;;
    macos)
      location="on macOS"
      ;;
    linux-host)
      location="on Linux"
      ;;
    *)
      location="on this host"
      ;;
  esac

  echo "${command_name} was not found ${location}. Please install ${package_hint}, then ${rerun_hint}. See README.md for installation details."
}
