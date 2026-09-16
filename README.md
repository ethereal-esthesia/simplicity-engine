# Simplicity Engine

Fluid motion graphics with a low learning curve. Current development focuses on
a shared C++ core compiled to WebAssembly, with WebKit on macOS and Electron
for compatibility on other desktops.

## Direction

- **Common language:** C++ for engine logic, compiled to WebAssembly (Wasm) so the
  same core can run in both desktop hosts.
- **macOS host:** WebKit via WKWebView. WebKit is the Mac-only host choice.
- **Other desktop hosts:** Electron for compatibility, consuming the same Wasm core.
- **Current code:** native macOS and iPhone/iOS SDL demos, AppKit and touch menus,
  a macOS bookmark probe, and Matte Overlay remain as the Apple foundation.
- **Implementation status:** the Wasm build, WebKit host, and Electron host are
  planned. None is implemented or packaged yet; the commands below run the existing
  native Apple demos.
- Native Windows, Linux, Android, container builds, and VM provisioning have been
  removed from `main`. Broader platform work is preserved on
  [`codex/archive-multiplatform-2026-09-15`](https://github.com/ethereal-esthesia/simplicity-engine/tree/codex/archive-multiplatform-2026-09-15).

See the [platform roadmap](docs/platform-targets-todo.md) for priorities and the
[engine definition](docs/engine-definition.md) for the longer-term runtime goals.

## Build on macOS

Install Apple's command-line developer tools, CMake 3.21+, and Ninja. The checked-in
presets require CMake 3.25+ (preset schema version 6). Configure downloads SDL 3.2.8.

```sh
xcode-select --install
brew install cmake ninja
./scripts/dev-setup.sh --target macos --check
cmake --preset debug
cmake --build --preset debug
ctest --test-dir build/debug --output-on-failure
./scripts/run.sh
```

Use the `release` preset for optimized builds. Menu Studio:

```sh
./scripts/menu_demo.sh run host
./scripts/menu_demo.sh test host
```

## iPhone simulator

Install full Xcode and an iOS simulator runtime, then select Xcode as the active
developer directory. The simulator presets target Apple silicon Macs.

```sh
./scripts/dev-setup.sh --target ios
./scripts/run_ios_iphone.sh
./scripts/menu_demo.sh test ios-phone
```

See [developer setup](docs/developer-setup.md), [testing](TESTING.md), and the
[menu API](docs/menu.md). iOS device signing and App Store distribution are not
configured by these simulator commands.

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

## macOS bookmark probe

```sh
cmake --preset debug
cmake --build --preset debug --target macos_bookmark_probe
./build/debug/macos_bookmark_probe choose
./build/debug/macos_bookmark_probe resolve
./build/debug/macos_bookmark_probe load index.html
```

The probe saves a security-scoped folder bookmark under `data/probe/`.
See [probe documentation](probes/README.md).

## GitHub builds and releases

CI builds and tests macOS and builds the iPhone simulator demos. Nightly checks
cover macOS arm64 and x86_64. Tags matching `v*` package macOS Hello Pixel archives
and publish a GitHub release. Wasm host packaging will be added with its implementation;
no other platform binaries are currently published.

```sh
./scripts/package_target.sh macos-arm64
./scripts/release.sh                # show latest release tag
./scripts/release.sh v0.1.0         # create and push a release tag
```
