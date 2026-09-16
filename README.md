# Simplicity Engine

Fluid motion graphics with a low learning curve, built around **Rust → WebAssembly
and Tauri**.

## Direction and current status

- Write new shared engine logic and straightforward conversions in **Rust**, and
  compile it to **WebAssembly (Wasm)**. Keep one implementation across hosts.
- Use **Tauri 2** for application windows and native services. Its native Rust
  host and the Rust code compiled to Wasm are separate build targets.
- Keep JavaScript thin: load Wasm, forward input, and connect drawing to web APIs.
  Keep OS integration in Tauri instead of putting it in the portable core.
- Hello Pixel now has a small Tauri host and dependency-free Rust/Wasm core.
  Rust provides its centered mark geometry and palette; a Canvas adapter draws it.
- The existing C++/SDL macOS and iPhone demos, menu API, bookmark probe, and Swift
  Matte Overlay remain available while features migrate. They are not yet ported.

Tauri is the sole planned app host. There is no Electron dependency or build path.
Tauri supports macOS, Windows, Linux, iOS/iPadOS, and Android, but this repository's
new host is currently validated on macOS only. Mobile projects, signing, and other
platform packages still need setup and testing; framework coverage is not a claim
that this app already ships on every platform.

See the [roadmap](docs/platform-targets-todo.md) and
[engine definition](docs/engine-definition.md). Earlier platform code is preserved
on [the archive branch](https://github.com/ethereal-esthesia/simplicity-engine/tree/codex/archive-multiplatform-2026-09-15).

## Build and run Tauri

On macOS, install Apple's command-line developer tools, Rust through rustup, and
Node.js 22 or later. See [developer setup](docs/developer-setup.md).

```sh
make setup       # install locked npm dependencies and the Rust Wasm target
make             # build Wasm and the release Tauri executable
make test        # native Rust tests and execution of the compiled Wasm
make run         # launch Tauri in development mode
make bundle      # build the macOS .app
```

The release executable is `target/release/simplicity-app`; the macOS app is
`target/release/bundle/macos/Simplicity Engine.app`. The demo opens a dark window
with a centered mint mark. Generated Wasm lives in `web/generated/` and is rebuilt
automatically before Tauri runs or builds. Node is build/test tooling, not an app
runtime dependency. Equivalent npm commands are available in `package.json`.

## Repository layout

| Path | Purpose |
|---|---|
| `crates/engine-core/` | Portable Rust logic compiled natively for tests and to Wasm |
| `src-tauri/` | Native Tauri application host |
| `web/` | HTML, CSS, and a small Wasm/Canvas adapter |
| `src/`, `include/`, `demos/` | Retained C++/SDL Apple implementation |
| `tools/matte-overlay/` | Standalone Swift macOS utility |
| `scripts/`, `tests/`, `docs/` | Build entrypoints, checks, and project references |

## Retained Apple builds

Install CMake 3.25+ and Ninja (`brew install cmake ninja`). Configuration downloads
SDL 3.2.8; these builds are independent of the Tauri app.

```sh
make apple-test
./scripts/run.sh
./scripts/menu_demo.sh test host
```

For the iPhone simulator, install full Xcode and an iOS runtime. The existing
simulator presets target Apple silicon Macs:

```sh
./scripts/dev-setup.sh --target ios
make ios-build
./scripts/menu_demo.sh test ios-phone
```

These commands build the retained SDL iPhone app, not a Tauri mobile package.
See [testing](TESTING.md) and the [menu API](docs/menu.md).

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

CI tests the Rust core natively and as Wasm, builds a macOS Tauri app, and retains
the Apple native checks. Tag-driven releases still publish the existing macOS SDL
archives; Tauri release distribution and signing are not configured yet.
