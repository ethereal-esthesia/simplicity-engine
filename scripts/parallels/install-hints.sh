#!/usr/bin/env bash

parallels_install_hint() {
  local platform="$1"
  local command_name="$2"
  local rerun_hint="${3:-rerun the previous command}"
  local package_hint=""
  local platform_name="$platform"

  case "${platform}:${command_name}" in
    windows:git)
      package_hint="Git for Windows"
      ;;
    windows:cmake)
      package_hint="CMake"
      ;;
    windows:ninja)
      package_hint="Ninja"
      ;;
    windows:compiler)
      package_hint="Visual Studio Build Tools with the C++ workload"
      ;;
    linux:compiler)
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
      platform_name="Windows"
      ;;
    linux)
      platform_name="Linux"
      ;;
  esac

  echo "${command_name} was not found in the ${platform_name} VM. Please install ${package_hint}, then ${rerun_hint}. See README.md for installation details."
}
