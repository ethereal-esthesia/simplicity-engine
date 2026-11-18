# Probes

Small platform experiments live here before they become engine backends or tests.

## macOS Bookmark Probe

`macos_bookmark_probe` explores security-scoped `NSURL` bookmark behavior for user-selected folders. It stores its generated token under `data/probe/`, which is intentionally gitignored.

## macOS Fullscreen Overlay Probe

Build and run the standalone probe from the repository root:

```sh
xcrun swiftc probes/macos/fullscreen_overlay_probe.swift -o build/fullscreen-overlay-probe
./build/fullscreen-overlay-probe
```

It shows a red, click-through block near the top-right corner of each display
using a non-activating panel at screen-saver level. Switch to Minecraft
fullscreen to check whether the block remains visible. The probe has no Dock
icon; stop it with Ctrl-C in the terminal. It does not change the main app.
