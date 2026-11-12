# Fullscreen overlay direction: SDL3 mouse passthrough + custom cursor

## Goal

Support a fullscreen, transparent, click-through overlay that hides the OS
cursor and renders a custom cursor sprite tracked to the real pointer
position, on macOS, Windows, and Linux.

## Decision

Build this on **SDL3**, not Tauri/webview, winit+wgpu, or a pure per-OS native
implementation. Rationale:

- SDL3 best matches the project's priorities: runtime speed, cross-platform
  reach (macOS/Windows/Linux, plus iOS/Android if ever needed), small static
  footprint, and modern GPU access through `SDL_gpu` (Vulkan/Metal/D3D12).
- SDL3 is already a project dependency (see `CMakeLists.txt`), with ~25 years
  of production hardening across the broader SDL lineage.
- Tauri/webview has no supported click-through/passthrough mode and abstracts
  away the native window APIs this feature needs.
- winit+wgpu already exposes `Window::set_cursor_hittest(bool)` today (no
  patch required), and winit is a transitive Tauri dependency, so it is a
  credible fallback if the SDL3 path stalls. It was not chosen as the primary
  path because it would mean standardizing the native host on Rust/winit
  instead of the existing C++/SDL3 direction, and it carries a heavier
  runtime than SDL3's thin C core.
- A permanent SDL3 fork was rejected: it would require re-merging patched
  per-platform window backends on every SDL version bump. Instead, patch a
  short-lived fork, use it locally, and upstream the change.

## Known gap

SDL3 has no built-in mouse-passthrough/click-through window flag as of this
writing. The native OS window handle is reachable today through
`SDL_GetWindowProperties` (for example
`SDL_PROP_WINDOW_COCOA_WINDOW_POINTER` on macOS) without any SDL patch, so a
first working version does not require the fork below. Upstreaming a proper
`SDL_SetWindowMouseClickthrough`-style API is the longer-term goal so other
SDL3 users gain it and the project does not carry an ad hoc workaround
indefinitely.

## Plan

### Short term: ship the feature using existing SDL3 APIs

- [ ] Use `SDL_SetWindowOpacity` / per-pixel alpha rendering for the
      transparent fullscreen window.
- [ ] Hide the OS cursor with `SDL_HideCursor()`.
- [ ] Track pointer position and draw a custom cursor sprite each frame.
- [ ] Reach the native window handle via `SDL_GetWindowProperties` and call
      the platform passthrough API directly from application code:
      - macOS: `[NSWindow setIgnoresMouseEvents:YES]`.
      - Windows: add `WS_EX_TRANSPARENT | WS_EX_LAYERED` to the window style.
      - Linux/X11: set an empty input shape region (`XShapeCombineRegion`).
      - Linux/Wayland: no standard protocol exists; document as unsupported
        for now.
- [ ] Compare this approach against the existing `tools/matte-overlay`
      Cocoa/`NSWindow` implementation, which already solves transparency,
      click-through, and no-keyboard-focus on macOS without SDL.

### Longer term: upstream passthrough into SDL3

Tracked in detail in
[SDL3 mouse passthrough TODO](sdl3-passthrough-upstream-todo.md), covering the
RFC issue, the short-lived fork, per-backend implementation, testing, and the
upstream PR process.

## Open questions

- [ ] Does the custom-cursor overlay belong in `crates/engine-core`, in a
      dedicated overlay module, or as a standalone tool like
      `tools/matte-overlay`?
- [ ] Should the overlay be a separate process coordinated with the Tauri
      host (for settings/toggling), or a fully standalone SDL3 application?
- [ ] Revisit winit+wgpu if the SDL3 upstream patch stalls in review or if
      Wasm/web parity for this feature becomes a requirement.
