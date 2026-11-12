# SDL3 mouse passthrough TODO

## Goal

Add a cross-platform mouse-passthrough (click-through) window API to SDL3 and
submit it upstream, so the fullscreen overlay described in
[overlay passthrough direction](overlay-passthrough-direction.md) no longer
needs an ad hoc per-project workaround. See that document for why SDL3 was
chosen over Tauri/webview, winit+wgpu, and a permanently maintained fork.

Working name: `SDL_SetWindowMouseClickthrough`.

## Before writing code

- [ ] Search existing SDL GitHub issues/PRs for prior passthrough proposals
      and read why any were rejected or stalled, so the new proposal
      addresses known objections up front.
- [ ] Open an SDL GitHub issue describing the use case (fullscreen overlay
      that must not block input to windows beneath it) before implementing,
      following the pattern of prior accepted window-property additions
      (for example `SDL_SetWindowOpacity`, the `SDL_PROP_WINDOW_*` system).
- [ ] Confirm naming/shape with a maintainer if possible: a boolean setter
      plus getter (`SDL_SetWindowMouseClickthrough` /
      `SDL_GetWindowMouseClickthrough`) versus a window-creation flag
      (`SDL_WINDOW_MOUSE_CLICKTHROUGH`), consistent with SDL3's existing
      `SDL_PROP_WINDOW_*` properties conventions.
- [ ] Decide how the API should report platforms where passthrough cannot be
      supported (for example return `false` / set an error, rather than a
      silent no-op).

## Fork setup

- [ ] Fork `libsdl-org/SDL` and create a working branch for this change only;
      do not carry unrelated changes on it.
- [ ] Point the project's local `CMakeLists.txt` `FetchContent` declaration at
      this fork/branch temporarily while developing and testing, with a
      comment noting it is a staging patch pending upstream review and the
      exact SDL3 version it is based on.
- [ ] Track the upstream SDL3 release the fork is based on so rebasing stays
      tractable; avoid letting the fork drift far from upstream `main`.

## Implementation

- [ ] Add the new public API declaration and documentation comment to
      `include/SDL3/SDL_video.h`, matching existing style/doc conventions.
- [ ] Implement a no-op/default fallback in `src/video/SDL_video.c` for
      backends that do not support it.
- [ ] macOS (`src/video/cocoa`): implement via
      `[NSWindow setIgnoresMouseEvents:YES/NO]`.
- [ ] Windows (`src/video/windows`): implement via toggling
      `WS_EX_TRANSPARENT | WS_EX_LAYERED` on the window's extended style.
- [ ] Linux/X11 (`src/video/x11`): implement via `XShapeCombineRegion` with
      an empty region to pass through input, and restore normal hit-testing
      when disabled.
- [ ] Linux/Wayland (`src/video/wayland`): document as unsupported for now;
      return `false`/unsupported rather than silently failing. Note any
      compositor-specific protocol (for example `wlr-layer-shell`) as a
      possible future follow-up, out of scope for the initial patch.
- [ ] Add/update the relevant `SDL_PROP_WINDOW_*` capability reporting if
      SDL's convention expects callers to query support before calling.

## Tests and validation

- [ ] Add or extend an SDL test/example demonstrating a transparent
      click-through window, consistent with SDL's existing test suite style
      (see `test/` in the SDL3 repo).
- [ ] Manually verify on macOS: overlay window does not receive mouse events
      and clicks reach the window beneath it.
- [ ] Manually verify on Windows: same behavior via a VM or physical machine.
- [ ] Manually verify on Linux/X11: same behavior under at least one window
      manager.
- [ ] Confirm toggling passthrough on/off at runtime works without requiring
      window recreation.
- [ ] Confirm the feature does not regress existing SDL3 test suite results
      (`ctest`) on all three desktop platforms.

## Upstream submission

- [ ] Rebase the branch on current upstream `main` before opening the PR.
- [ ] Write a PR description covering: motivation, API shape, platforms
      implemented, platforms intentionally left unsupported (Wayland), and
      test evidence.
- [ ] Link the earlier RFC/issue discussion from the PR.
- [ ] Respond to maintainer review feedback; expect requests to adjust the
      API shape or scope (for example dropping or deferring a platform).
- [ ] If the PR stalls or is rejected, fall back to the native-handle
      workaround documented in
      [overlay passthrough direction](overlay-passthrough-direction.md)
      (`SDL_GetWindowProperties` plus direct platform calls) as the
      long-term approach, and revisit winit+wgpu's existing
      `set_cursor_hittest` as an alternative.

## After merge

- [ ] Remove the project's local fork/patch and `FetchContent` override once
      the change ships in an official SDL3 release.
- [ ] Update `CMakeLists.txt` to pin the SDL3 release containing the merged
      feature.
- [ ] Update [overlay passthrough direction](overlay-passthrough-direction.md)
      to remove the "known gap" section and reference the shipped API
      directly.
