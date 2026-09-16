# Platform direction: C++ → WebAssembly

Use C++ as the common engine language and compile the shared core to WebAssembly
(Wasm). Desktop hosts consume that same core:

| Target | Host | Status |
|---|---|---|
| macOS | WebKit / WKWebView | Planned |
| Other desktops | Electron | Planned |
| iPhone/iOS | Existing native Apple demo | Retained; host migration undecided |

WebKit is the Mac-only host choice. Keep host code thin: application lifecycle,
windows, menus, and platform services belong in host adapters; reusable engine
behavior belongs in C++. Avoid duplicating engine logic in JavaScript or Swift.

The repository currently builds native Apple demos. It has no Wasm build or web
host yet. These are the next implementation milestones, not current capabilities.

## Shared core and host milestones

- [ ] Isolate C++ runtime logic from SDL and platform UI dependencies.
- [ ] Add a reproducible C++ → Wasm build and a small versioned host interface.
- [ ] Run the same demo/core in WKWebView on macOS and Electron on other desktops.
- [ ] Map rendering, input, timing, menus, and file access through host adapters.
- [ ] Verify shared behavior across both hosts and add packaging to CI.

## Retained Apple foundation

- [x] Keep macOS Hello Pixel, AppKit menus, bookmark probe, and Matte Overlay.
- [x] Keep iPhone simulator builds and touch menus.
- [x] Limit current native CI and release packaging to Apple.
- [ ] Decide the iOS host direction separately; desktop Electron is not an iOS plan.
- [ ] Add iOS device signing and distribution when needed.

Native Windows/Linux backends, Android, container builds, and desktop VM setup are
out of current scope. Their previous implementation and plans remain on
[`codex/archive-multiplatform-2026-09-15`](https://github.com/ethereal-esthesia/simplicity-engine/tree/codex/archive-multiplatform-2026-09-15).
