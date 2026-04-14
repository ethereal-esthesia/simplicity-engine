# Simplicity Engine

Simplicity Engine aims to reduce the complexity of getting high quality, fluid motion graphics working with a low learning curve.

## Hello Pixel (SDL)

This repo currently includes a minimal SDL app that opens a window and renders a single white pixel at the center.

Project reference docs live in `docs/`.
- Palette mapping reference: `docs/palette-mapping.md`
- Movable file handle TODO: `docs/movable-file-handle-todo.md`

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

**Windows x64/x86:** Install build tools for Intel/AMD Windows:

```powershell
winget install --id Kitware.CMake -e
winget install --id Ninja-build.Ninja -e
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

For manual Windows builds, use an MSVC developer shell, such as the "Developer PowerShell for VS", so the compiler tools are on PATH.

**Windows ARM64:** Install build tools for native Windows ARM64:

```powershell
winget install --id Kitware.CMake -e
winget install --id Ninja-build.Ninja -e
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --includeRecommended"
```

For manual Windows ARM64 builds, use an MSVC developer shell that targets ARM64. An ARM64-hosted x64 compiler still builds x64 binaries; native ARM64 builds need the ARM64 target tools.

**Windows uninstall:** Remove Visual Studio Build Tools before switching variants:

```cmd
winget uninstall --id Microsoft.VisualStudio.2022.BuildTools -e
```

Rerunning `winget install` only checks for an upgrade after Visual Studio Build Tools is installed; it does not change the installed C++ component set. If the wrong Visual Studio Build Tools variant is installed, uninstall it first, then rerun the matching Windows section above.

Debug (default):

```bash
cmake --preset debug
cmake --build --preset debug
./build/debug/hello_pixel
```

Release:

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
docker run --rm -it -v "$PWD:/workspace" simplicity-engine-build ./tools/build-in-container.sh
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
./tools/release.sh          # show latest release tag
./tools/release.sh v0.1.0   # create + push a new release tag
```
