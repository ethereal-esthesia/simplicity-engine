# Native Tauri Window Animation

Keep native window control in Tauri commands and shared, monitor-independent geometry in the Rust core.

## What Happened
The Simplicity Engine SVG expansion moved from an in-page overlay to a borderless native Tauri window. The host animates physical monitor coordinates using geometry tested in `simplicity-core`; mobile targets show the artwork without requesting desktop window operations. The native window can reverse the same edge interpolation on focus loss or Escape.

## Takeaway
For Tauri desktop window effects, use Rust commands for monitor/window APIs and keep interpolation math in a portable crate. Reuse the same eased edge animation for expansion and collapse; detect outside clicks through window focus loss rather than global mouse hooks. On macOS, animate the entire `NSWindow` frame with AppKit rather than driving frame updates with an unsynchronized timer; wait for its completion before changing the artwork. Clip the content view's layer to the same corner radius as the web surface so corners follow the native bounds during shrinking. Set `alwaysOnTop` on the native window. Transparent windows also require `app.macOSPrivateApi` and Tauri's `macos-private-api` feature.

## History
- 2026-11-15 (simplicity-engine/native-window): initial
- 2026-11-15 (simplicity-engine/native-window): added focus-loss and Escape collapse
- 2026-11-15 (simplicity-engine/native-window): tuned 60 Hz logical-coordinate resize and always-on-top
- 2026-11-15 (simplicity-engine/native-window): switched macOS to atomic AppKit frame updates
- 2026-11-15 (simplicity-engine/native-window): use AppKit animation instead of timer-driven frame updates
- 2026-11-15 (simplicity-engine/native-window): clip native content view during resize
