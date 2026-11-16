# Testing

## Rust/Wasm/Tauri

Run `make test` for native Rust tests, actual Wasm execution under Node, and the
video player adapter tests. Run `cargo test --locked -p video-player` for its
command-line path validation. On macOS, run `cargo test --locked -p
simplicity-app` to exercise the AppKit frame-coordinate mapping.
Run `make` to compile the native Tauri host. Run
`make run DIAGRAM=/path/to/diagram.mmd` to verify the app
opens as a small transparent, borderless, rounded, always-on-top window at the
monitor's top-right corner. Drag it to verify native window dragging without
expansion, including a long drag; a click released less than five pixels from
the press should expand it. On macOS, focus another application first and
verify that a single click expands the window; repeat with a single click-drag
to verify it moves without an initial focus click. Confirm the normal cursor is
used by default and the optional drag-cursor setting shows grab/grabbing cursors. Click
the SVG and confirm the window itself resizes smoothly at a 60 Hz target to a
uniform inset equal to 5% of the smaller monitor dimension, with the small icon
staying at the nearest display corner until the resize finishes; then the full
diagram fades in over white. Click a flowchart node twice to disable and
re-enable it, verifying each change is saved in the Mermaid file. Check an
existing `disabled` class definition and a shared `class A,B disabled` assignment.
Click the diagram background to edit its Mermaid source.
Verify that dragging or double-clicking diagram labels does not select them,
that the icon cannot be dragged as an image, and that source text remains
selectable in the editor.
Verify long lines wrap and a vertical scrollbar appears when needed; Escape
must save valid edits and fade back to the updated diagram. Invalid source
must keep the editor open with an error and leave the file unchanged. Test a
missing path with both answers to the terminal creation prompt, and an empty
file for commented usage hints. Test all four corners after dragging the compact
window. On macOS, watch the top-left rounded corner during both
directions for vibration or a rectangular frame, and verify that the diagram
does not fade in before the native animation finishes. Click outside the window
and press Escape to verify both shrink it back to its original dragged position
with all four corners rounded throughout. Tauri command failures must be visible.
On macOS, the native white backing matches the web surface and keeps the
rounded corner stationary when the webview redraw lags.
On macOS, switch between desktop Spaces and a fullscreen application such as
Minecraft and verify the compact window remains visible and can be expanded,
edited, and collapsed without changing the application's display mode.
Set the `WindowOptions` constructor's `always_on_top` to false and rebuild to
verify that other windows can cover it; restore it to true to verify it floats.
Right-click the compact window and verify that the native menu contains only
Close, that dismissing the menu leaves the app open, and that Close exits it.
Verify that right-clicking the expanded editor retains its normal context menu.
`make bundle` builds the macOS app; test its launch separately from development.
The [installer workflow](docs/test-installers.md) compiles other desktop targets,
Android APKs, and iOS Simulator apps. Runtime and installation checks on those
targets remain separate from compile checks.

Run `npm run video-player:build`, then
`target/release/video-player /path/to/video.mp4` to check that the standalone
video plays and loops in its bordered window, including after resizing. Missing
or unplayable files must show an error.

## Shared engine test boundary

`crates/engine-core` is the source of truth for portable engine behavior. Keep
its unit tests in Rust, and use the compiled Wasm tests to verify that the same
implementation works through the Wasm boundary. JavaScript tests should cover
the Wasm/Canvas and Tauri webview adapters, not reimplement engine behavior.
Rust tests in Tauri host crates cover host-specific integration.

The retained C++/SDL tests cover menu presentation and native driver
integration. Portable menu validation, mutation, and activation behavior lives
in `simplicity-core` and is shared with the native menu drivers through its C
ABI. Rust unit tests own those rules; CTest remains focused on SDL/AppKit
integration.

## Retained Apple demos

On macOS, configure and build each preset before running its tests:

```sh
cmake --preset debug
cmake --build --preset debug
ctest --test-dir build/debug --output-on-failure
cmake --preset release
cmake --build --preset release
ctest --test-dir build/release --output-on-failure
python3 tests/test_ios_setup.py
```

CTest covers touch-menu interaction, a headless Menu Studio run, and SDL
initialization. Portable RNG and menu behavior are tested in `simplicity-core`.
`./scripts/menu_demo.sh test host` also verifies native AppKit menu construction,
state, and dispatch.

For iPhone simulator builds and runtime self-tests:

```sh
./scripts/run_ios_iphone.sh --build-only
./scripts/menu_demo.sh test ios-phone
```

A simulator self-test must print `MENU_SELF_TEST=PASS`. iOS binaries are tested
inside the simulator, not through host CTest.

For visual checks, run `./scripts/run.sh` (dark background and centered mint mark),
`./scripts/menu_demo.sh run host`, and `./scripts/menu_demo.sh run ios-phone`.
Verify menu interaction and clean exit. See the
[Matte Overlay guide](tools/matte-overlay/README.md) for its checks.

GitHub CI covers macOS tests and iPhone simulator compilation; nightly jobs cover
macOS arm64 and x86_64. Tauri/Wasm checks run separately from the retained SDL builds.
