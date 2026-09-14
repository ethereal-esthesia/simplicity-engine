# Scripts

Public scripts live here. The top level is meant to stay lightweight and stable, while heavier implementation details live under `scripts/impl/`.

Unified entrypoints:

- `build_target.sh`: Shared build front door for host, iOS, and Android paths that are already wired.
- `run_target.sh`: Shared run front door for host, iOS, and Android paths that are already wired.
- `package_target.sh`: Shared packaging front door for current desktop package targets.

Target-specific wrappers are still first-class and are the clearest path when you know exactly what you want to run.

## Build

- `build-in-container.sh`: Build Linux and Windows targets inside the Docker build image.
- `run.sh`: Configure, build, optionally test, and launch the sample desktop app on the current host.
- `run_android_emulator.sh`: Build and install the Android sample app on a running or auto-started emulator, with target profiles such as `android-phone` and `android-tablet`. You can also point it at a custom AVD with `--avd <name>`.
- `run_android_phone.sh`: Stable Android phone emulator entrypoint.
- `run_android_tablet.sh`: Stable Android tablet emulator entrypoint.
- `run_ios_ipad.sh`: Stable iPad Simulator entrypoint.
- `run_ios_iphone.sh`: Stable iPhone Simulator entrypoint.
- `run_ios_simulator.sh`: Configure, build, and launch the iOS app on an iPad simulator by default, or an iPhone simulator when requested.
- `smoke.sh`: Run all CTest smoke tests (`LABELS smoke`) for a build flavor (`release` by default).
- `test.sh`: Run the full CTest suite for a build flavor (`release` by default).

## Remote And VM Helpers


## Packaging

- `package_linux.sh`: Build release binary and package Linux artifacts (`.tar.gz` and `.AppImage`).
- `package_macos.sh`: Build release binary and package macOS artifact (`.tar.gz`).
- `package_windows_zip.ps1`: Build release binary and package Windows artifact (`.zip`).

## Release

- `release.sh`: Print latest release tag, or create and push a version tag (`vX.Y.Z`).

## Developer setup and Menu Studio

`dev-setup.sh` is the sole Unix setup entrypoint; `dev-setup.ps1` is its native
Windows equivalent. Implementation files in `impl/dev_setup/` are internal.
See [the setup guide](../docs/developer-setup.md).

`menu_demo.sh <build|test|run> <target>` runs the common-menu demo.
Windows uses `menu/demo.ps1 -Action build|test|run`.
Build and test commands never install SDKs, OS images, or packages.
