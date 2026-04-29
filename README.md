# Simplicity Engine

Simplicity Engine aims to reduce the complexity of getting high quality, fluid motion graphics working with a low learning curve.

## Hello Pixel (SDL)

This repo currently includes a minimal SDL app that opens a window and renders a small visible mark at the center.

Project reference docs live in `docs/`.
- Palette mapping reference: `docs/palette-mapping.md`
- Movable file handle TODO: `docs/movable-file-handle-todo.md`
- Platform targets TODO: `docs/platform-targets-todo.md`
- SSH remote runner TODO: `docs/ssh-remote-runner-todo.md`
- Mobile testing notes: `docs/mobile-testing/README.md`

Top-level setup guides:
- Mobile testing setup: `MOBILE-TESTING-SETUP.md`

VM direction:
- Prefer open VM tooling such as QEMU/libvirt or UTM for cross-platform automation.
- Keep Parallels as an optional paid alternative, not the default plan.

Script surface:

```bash
./scripts/setup_target.sh <target>
./scripts/build_target.sh <target>
./scripts/run_target.sh <target>
./scripts/package_target.sh <target>
```

Those are the stable top-level entrypoints we want people to grow into. Underneath them, target-specific wrappers such as `scripts/run_ios_ipad.sh` and `scripts/setup_utm.sh` still exist and stay usable while the unified backends fill in.

UTM bootstrap:

```bash
./scripts/setup_utm.sh
```

That no-flag path is the safe starting point. It:

- installs or upgrades UTM on macOS through Homebrew
- prepares the ignored guest-media cache under `local/utm/media`
- stops before starting any guest OS media flow
- prints the next-step commands for each platform pipeline

Platform pipelines:

```bash
./scripts/setup_utm.sh --windows
./scripts/setup_utm.sh --linux
./scripts/setup_utm.sh --macos
./scripts/setup_utm.sh --all
```

What each one does:

- `--windows`
  - prepares `local/utm/media/windows`
  - opens Microsoft's official Windows 11 Arm64 download page by default
  - writes a reminder file in that folder because Microsoft's download flow is interactive
- `--linux`
  - downloads the official Ubuntu ARM64 desktop ISO into `local/utm/media/linux`
- `--macos`
  - tries to fetch the latest supported macOS restore image from Apple's virtualization service
  - if that fetch fails, it leaves a reminder file and points you at UTM's built-in macOS guest flow
- `--all`
  - runs the Windows, Linux, and macOS guest-media setup paths in sequence

If you already have local guest media, pass it explicitly:

```bash
./scripts/setup_utm.sh --windows --iso /path/to/windows.iso
./scripts/setup_utm.sh --linux --iso /path/to/linux.iso
./scripts/setup_utm.sh --macos --iso /path/to/restore.ipsw
```

Useful options:

- `--download-dir <dir>` stores media somewhere other than `local/utm/media`
- `--force` re-downloads or replaces staged media
- `--skip-install-utm` skips the Homebrew UTM install/upgrade step
- `--no-open` avoids opening browser pages for the interactive Windows or fallback macOS paths

The script is idempotent within a run: shared host setup only happens once, and later pipeline steps will report when that setup was already handled.

## Build Types

To match Serenity's workflow, this project uses two primary build types:
- `Debug` (default development mode)
- `Release` (optimized runtime mode)

## Build and Run (local)

Requirements:
- CMake 3.21+
- Ninja
- C/C++ compiler
- Internet access during configure (CMake fetches SDL automatically)

**macOS (using Homebrew):** Install Apple's compiler tools and build tools:

```bash
xcode-select --install
brew install cmake ninja
```

**macOS (using MacPorts):** Install Apple's compiler tools and build tools:

```bash
xcode-select --install
sudo port install cmake ninja
```

**APT-based Linux:** Install build tools:

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build git
```

**Windows:** Install build tools for x64/x86 and ARM64 targets:

```powershell
winget install --id Kitware.CMake -e
winget install --id Ninja-build.Ninja -e
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --includeRecommended"
```

- For manual Windows builds, use an MSVC developer shell, such as the "Developer PowerShell for VS", so the compiler tools are on PATH.
- For native Windows ARM64 builds, use an MSVC developer shell that targets ARM64. An ARM64-hosted x64 compiler still builds x64 binaries.
- Rerunning `winget install` only checks for an upgrade after Visual Studio Build Tools is installed. If Build Tools is already installed without the needed compiler target, uninstall it with `winget uninstall --id Microsoft.VisualStudio.2022.BuildTools -e`, then rerun the Windows block above.

Demo run (default debug `hello_pixel` build):

```bash
./scripts/run.sh
```

Useful variants:

```bash
./scripts/run.sh --no-launch
./scripts/run.sh --test
./scripts/run.sh --preset release
./scripts/run.sh --console
```

By default, build and app output is written to `logs/`. Use `--console` when you want the full output attached to the current shell.

### iPad Simulator

To build the sample app as an iPad-form iOS app and launch it in Simulator:

```bash
./scripts/run_ios_ipad.sh
```

For iPhone Simulator instead:

```bash
./scripts/run_ios_iphone.sh
```

### Android Emulators

To build, install, and launch the sample app on a running Android emulator, or automatically start the first matching AVD it finds:

```bash
./scripts/run_android_phone.sh
./scripts/run_android_tablet.sh
```

Useful variants:

```bash
./scripts/run_android_phone.sh --build-only
./scripts/run_android_tablet.sh --build-only
./scripts/run_android_emulator.sh --avd Half_Screen_Tablet_API_36.1
```

For Fire-tablet compatibility smoke tests, create a custom AVD that matches a Fire tablet and launch it with `--avd <name>`. For Amazon Appstore retail-page and final Fire OS checks, use a physical Fire tablet and Amazon Live App Testing.

Requirements for the Android path:
- Android SDK with platform-tools, emulator, and at least one system image
- Android NDK `27.2.12479018`
- Android CMake `3.22.1`
- Android Studio's bundled JBR or another compatible JDK

Manual debug equivalent:

```bash
cmake --preset debug
cmake --build --preset debug
./build/debug/hello_pixel
```

Manual release equivalent:

```bash
cmake --preset release
cmake --build --preset release
./build/release/hello_pixel
```

## Probes

Probe sources live in `probes/`.

### macOS Bookmark Probe

On macOS, the repo builds a small probe for security-scoped folder bookmarks:

```bash
cmake --preset debug
cmake --build --preset debug --target macos_bookmark_probe
./build/debug/macos_bookmark_probe choose
./build/debug/macos_bookmark_probe resolve
./build/debug/macos_bookmark_probe load index.html
```

`choose` opens a folder picker and saves the base64 bookmark token to `data/probe/macos-bookmark-token.json`.
`load` resolves that token, starts scoped access, opens the requested relative file with `NSFileHandle`, and prints a short preview.

## Containerized Build

Build the container:

```bash
docker build -t simplicity-engine-build .
```

Run Linux + Windows builds inside the container:

```bash
docker run --rm -it -v "$PWD:/workspace" simplicity-engine-build ./scripts/build-in-container.sh
```

Expected artifacts:
- `build/linux-debug/hello_pixel`
- `build/linux-release/hello_pixel`
- `build/windows-debug/hello_pixel.exe`
- `build/windows-release/hello_pixel.exe`

## Platform Notes

- Linux: supported in container and native.
- Windows: cross-compiled from Linux container using `mingw-w64`.
- macOS: build natively on macOS using the local CMake flow (Apple SDK cannot be fully redistributed in a generic Linux container).

## Releases

Release automation matches the tag-driven pattern used in Serenity Engine:
- Push a tag like `v0.1.0` to trigger `.github/workflows/release.yml`.
- The workflow builds and packages Linux, Windows, and macOS artifacts, then publishes a GitHub release.

Use the local release helper script:

```bash
./scripts/release.sh          # show latest release tag
./scripts/release.sh v0.1.0   # create + push a new release tag
```
