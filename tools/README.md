# Tools

Utility scripts for local development, packaging, and release.

## Build

- `build-in-container.sh`: Build Linux and Windows targets inside the Docker build image.
- `smoke.sh`: Run all CTest smoke tests (`LABELS smoke`) for a build flavor (`release` by default).
- `test.sh`: Run the full CTest suite for a build flavor (`release` by default).

## Packaging

- `package_linux.sh`: Build release binary and package Linux artifacts (`.tar.gz` and `.AppImage`).
- `package_macos.sh`: Build release binary and package macOS artifact (`.tar.gz`).
- `package_windows_zip.ps1`: Build release binary and package Windows artifact (`.zip`).

## Release

- `release.sh`: Print latest release tag, or create and push a version tag (`vX.Y.Z`).
