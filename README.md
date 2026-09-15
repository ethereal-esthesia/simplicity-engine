# Simplicity Engine

Simplicity Engine aims to reduce the complexity of getting high quality, fluid motion graphics working with a low learning curve.

## macOS Matte Overlay

A click-through menu-bar utility adds translucent grey tint and paper-like grain across all connected displays, without taking keyboard focus. Grain remains visible at 0% tint.

Build and launch with Apple's command-line developer tools installed:

```sh
bash tools/matte-overlay/build.sh
open "build/Matte Overlay.app"
```

Open **◐** in the menu bar:

- **Turn Overlay Off / On** controls visibility; the action has no checkmark.
- **Full-resolution grain** switches between display backing resolution (including Retina scaling) and the original 960 × 540 texture.
- **Random (animated grain)** refreshes at 30 fps using a shift/XOR-only RNG that consumes every output bit.
- **Grey tint** adjusts from 0–65%. Tint labels and the slider are greyed out only while the overlay is off.
- **Quit Matte Overlay** removes the overlay and exits.

The compact menu has no redundant heading. Settings persist between launches. Grain uses brightness values 192–255 at 12% opacity, independently of tint. See [Matte Overlay documentation](tools/matte-overlay/README.md) for implementation details and verification commands.

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

Developer setup uses one public command:

```bash
./scripts/dev-setup.sh --target macos --check
./scripts/dev-setup.sh --target macos
./scripts/dev-setup.sh --target macos --vm --storage "/Volumes/Storage/VM Images/Simplicity"
./scripts/dev-setup.sh --target linux --vm
./scripts/dev-setup.sh --target windows --vm
./scripts/dev-setup.sh --target android
./scripts/dev-setup.sh --target ios
```

On Windows, use `./scripts/dev-setup.ps1`. Setup and testing are separate:
`./scripts/menu_demo.sh test host` builds and tests Menu Studio.
See [developer setup](docs/developer-setup.md) for storage, reuse, installation
boundaries, and exit codes, and [common menus](docs/menu.md) for the API and test matrix.
UTM is the supported desktop VM frontend. Parallels integration and the old setup
aliases have been removed; existing VM files are not modified or removed.

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



```bash
```

For iPhone Simulator instead:

```bash
./scripts/run_ios_iphone.sh
```

### Android Emulators

To build, install, and launch the sample app on a running Android emulator, or automatically start the first matching AVD it finds:

```bash
./scripts/run_android_phone.sh
```

Useful variants:

```bash
./scripts/run_android_phone.sh --build-only
```


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
