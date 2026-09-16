# Platform direction: Rust → WebAssembly + Tauri

Tauri is the application host. Write shared engine logic and simple conversions in
Rust, compile it to Wasm, and keep the web adapter small. Native host services live
in Tauri's separate Rust crate. Do not duplicate core logic in JavaScript or Swift.

## Current implementation

- [x] Rust Hello Pixel geometry and palette with native tests.
- [x] Locked Rust → Wasm build and tests that execute the generated module.
- [x] Tauri 2 host loading that module through a small Canvas adapter.
- [x] `make` setup, build, run, test, and macOS bundle entrypoints.
- [x] Preserve working native Apple demos and utilities during migration.
- [ ] Migrate menus, input, timing, and file access incrementally with parity checks.
- [ ] Add an animation workload and measure frame pacing and resizing in each webview.

## Platform scope

| Target | Tauri webview | Repository status |
|---|---|---|
| macOS | WKWebView | Initial Hello Pixel host |
| Windows | WebView2 | CI test installers; device validation pending |
| Linux | WebKitGTK | CI test installers; device validation pending |
| iPhone/iPad | WKWebView | CI simulator apps; device signing pending; SDL demo retained |
| Android | Android System WebView | CI debug APKs; device validation pending |

Validate each platform before promising support. Rust/Wasm portability does not
replace tests for graphics, permissions, native menus, or device lifecycle.
Tauri uses platform webviews; see [upstream details](https://v2.tauri.app/reference/webview-versions/).

Prior native Windows/Linux/Android and VM tooling remains on
[the archive branch](https://github.com/ethereal-esthesia/simplicity-engine/tree/codex/archive-multiplatform-2026-09-15).

See [test installer downloads and limitations](test-installers.md).
