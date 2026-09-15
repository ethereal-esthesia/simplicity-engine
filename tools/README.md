# Tools

Utility scripts for local development, packaging, and release.

## Build

- `build-in-container.sh`: Build Linux and Windows targets inside the Docker build image.
- `run.sh`: Configure, build, optionally test, and launch the sample desktop app on the current host.
- `run_android_phone.sh`: Stable Android phone emulator entrypoint.
- `run_ios_iphone.sh`: Stable iPhone Simulator entrypoint.
- `smoke.sh`: Run all CTest smoke tests (`LABELS smoke`) for a build flavor (`release` by default).
- `test.sh`: Run the full CTest suite for a build flavor (`release` by default).

## Remote And VM Helpers


## Packaging

- `package_linux.sh`: Build release binary and package Linux artifacts (`.tar.gz` and `.AppImage`).
- `package_macos.sh`: Build release binary and package macOS artifact (`.tar.gz`).
- `package_windows_zip.ps1`: Build release binary and package Windows artifact (`.zip`).

## Release

- `release.sh`: Print latest release tag, or create and push a version tag (`vX.Y.Z`).
