# Native Tauri Window Animation

Keep native window control in Tauri commands and shared, monitor-independent geometry in the Rust core.

## What Happened
The Simplicity Engine SVG expansion moved from an in-page overlay to a borderless native Tauri window. The host now animates physical monitor coordinates using geometry tested in `simplicity-core`; mobile targets show the artwork without requesting desktop window operations.

## Takeaway
For Tauri desktop window effects, use Rust commands for monitor/window APIs and keep interpolation math in a portable crate. On macOS, transparent windows also require `app.macOSPrivateApi` and Tauri's `macos-private-api` feature.

## History
- 2026-11-15 (simplicity-engine/native-window): initial
