# Platform Targets TODO

## Goal

For a simple app or game built on `simplicity-engine`, building for another mainstream platform should be a one-liner.

This TODO separates:

- compile targets, which need their own build/package pipeline
- compatibility targets, which mostly reuse another compile target but still need explicit validation
- tablet validation targets, which represent the device families we should test against

## Why These Targets

Current platform popularity is concentrated enough that we can be opinionated:

- tablets are still led by Apple and Samsung, with Lenovo, Xiaomi, and Huawei in the next tier
- desktop operating systems are still led by Windows, followed by Apple and Linux
- mobile operating systems are still dominated by Android and iOS
- Fire OS and ChromeOS matter because they are distinct compatibility lanes built on top of Android app distribution

This is enough to justify a practical target list instead of treating every hardware brand as a separate platform.

## Engine Promise

The engine should eventually make these flows normal:

```bash
./tools/build-target.sh macos
./tools/build-target.sh windows-x64
./tools/build-target.sh windows-arm64
./tools/build-target.sh linux-x64
./tools/build-target.sh ios
./tools/build-target.sh android
./tools/build-target.sh fireos
./tools/build-target.sh chromeos
```

The exact target names can change, but the user experience goal should not.

## Compile Targets

These are the operating-system targets the engine should treat as first-class build outputs.

### Tier 1

- [ ] `macos`
- [ ] `windows-x64`
- [ ] `linux-x64`
- [ ] `ios`
- [ ] `android`

### Tier 2

- [ ] `windows-arm64`
- [ ] `linux-arm64`

## Compatibility Targets

These are important enough to document and test explicitly, even when they mostly reuse another compile target.

- [ ] `ipados`
  - Same Apple family as `ios`, but should have tablet-specific validation, layout, and input coverage.
- [ ] `fireos`
  - Usually derived from the Android build, but store packaging, API level support, and Google-service assumptions must be checked.
- [ ] `chromeos`
  - Usually derived from the Android build, but touch-not-required manifests, keyboard/mouse input, resizable windows, and Chromebook behavior must be checked.

## Tablet Validation Targets

These are the tablet families we should be able to point to when we say the engine supports popular tablet workflows.

### Required

- [ ] `ipad`
  - iPadOS validation target for Apple tablets.
- [ ] `galaxy-tab`
  - Mainstream Android tablet validation target.
- [ ] `fire-tablet`
  - Fire OS validation target. Use a custom Fire-style AVD for smoke tests, then a physical Fire tablet plus Live App Testing for Appstore-facing checks.
- [ ] `windows-tablet`
  - Windows tablet validation target. Surface is the first obvious hardware lane here, but the engine target should stay Windows-first instead of becoming Surface-specific. Use open VM tooling such as QEMU/libvirt or UTM for build and smoke checks; keep Parallels as an optional paid alternative, and require real hardware for touch signoff.
- [ ] `chromebook-tablet-or-2-in-1`
  - ChromeOS validation target.

### Nice to Have

- [ ] `lenovo-android-tablet`
  - Good extra signal for broader global Android tablet coverage.
- [ ] `xiaomi-android-tablet`
  - Useful if the engine starts caring more about broader non-US Android tablet behavior.

## Phone Validation Targets

These are the phone families we should be able to point to when we say the engine supports popular phone workflows.

### Required

- [ ] `iphone`
  - iPhone validation target for Apple phones.
- [ ] `android-phone`
  - Mainstream Android phone validation target.

## One-Liner Build UX

- [ ] Add a single entrypoint for target builds:
  - [ ] `./tools/build-target.sh <target>`
- [ ] Add a single entrypoint for running local validation where that makes sense:
  - [ ] `./tools/run-target.sh <target>`
- [ ] Add a single entrypoint for packaging/export:
  - [ ] `./tools/package-target.sh <target>`
- [ ] Make target names stable and documented.
- [ ] Make unsupported host/target combinations fail with a short, direct explanation.

## Platform Shell Polish

- [ ] Replace stock template branding in platform shells before calling a target "supported".
- [ ] Android:
  - [ ] Replace the default SDL launcher icons in `android/app/src/main/res/mipmap-*`.
  - [ ] Decide whether the first-launch experience should show a custom splash, a plain background, or no splash at all.
- [ ] Apple:
  - [ ] Make sure iPhone/iPad app icons and launch presentation match engine branding once we move past the placeholder sample phase.

## Input And Gesture Normalization

- [ ] Normalize pointer input across mouse, trackpad, and touchscreen so simple apps do not need per-platform gesture branches.
- [ ] Normalize single-pointer tap / click semantics across desktop and mobile targets.
- [ ] Normalize drag / pan semantics across mouse drag, trackpad gesture, and touchscreen drag.
- [ ] Normalize scroll semantics across mouse wheel, two-finger trackpad scroll, and touch-driven content movement.
- [ ] Normalize pinch / zoom gestures across trackpad pinch and touchscreen pinch where the platform supports both.
- [ ] Normalize swipe gestures across trackpad and touchscreen input where the platform exposes both.
- [ ] Decide which gestures belong in the engine core versus a higher-level UI layer.
- [ ] Log which native gesture or pointer backend produced each normalized input event when debug input logging is enabled.
- [ ] Document the minimum normalized gesture set that every supported target must expose.
- [ ] Treat pen input as a later extension unless a target forces earlier support for pressure, tilt, or hover semantics.

## Target Rules

- [ ] `ios` and `ipados` should share as much engine code as possible.
- [ ] `android`, `fireos`, and `chromeos` should share as much engine code as possible.
- [ ] `windows-tablet` should stay a validation profile on top of `windows-x64` and `windows-arm64`, not become its own build target.
- [ ] Surface should be the first Windows-tablet hardware lane we validate, but not the only hardware assumption baked into the docs.
- [ ] Open VM tooling should be the default Windows-tablet smoke path; Parallels should stay optional and never become the only documented route.
- [ ] `fireos` should not become a forked engine target unless real API divergence forces it.
- [ ] `chromeos` should not become a forked engine target unless Android-on-ChromeOS constraints force it.

## Minimum Acceptance Bar

Before claiming the engine has cross-platform target support for a target family:

- [ ] The sample app builds from a one-line command.
- [ ] The sample app launches or packages successfully on that target.
- [ ] Input, timing, and rendering backends are identified in logs.
- [ ] Platform-specific fallback behavior is documented.
- [ ] There is at least one smoke test or validation note for that target family.

## Near-Term Implementation Order

### Phase 1

- [ ] `macos`
- [ ] `windows-x64`
- [ ] `linux-x64`

### Phase 2

- [ ] `ios`
- [ ] `android`

### Phase 3

- [ ] `ipados`
- [ ] `fireos`
- [ ] `chromeos`
- [ ] `windows-tablet`

### Phase 4

- [ ] `windows-arm64`
- [ ] `linux-arm64`
- [ ] broader Android tablet validation on Lenovo/Xiaomi hardware

## Open Questions

- [ ] Should `ipados` be a visible target name in tooling, or should it stay a validation profile under `ios`?
- [ ] Should `fireos` and `chromeos` have their own package commands, even if they share the Android binary?
- [ ] Do we want host-side remote runners for Apple, Android, and Windows targets before we add more target names?
- [ ] At what point do we add Web as a first-class target, even though it is not an operating system target?

## Sources

- Apple multiplatform targets: <https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target>
- Android on ChromeOS: <https://developer.android.com/develop/devices/chromeos/learn?hl=en>
- Amazon Fire OS overview: <https://developer.amazon.com/docs/fire-tv/fire-os-overview.html>
- Worldwide tablet market, Q1 2025: <https://www.canalys.com/newsroom/worldwide-tablet-market-q1-2025>
- Worldwide tablet market, 2025: <https://www.idc.com/resource-center/blog/global-tablet-shipments-rise-1-9-in-4q25-as-seasonal-demand-offsets-cooling-replacement-cycle/>
- Desktop OS market share reference: <https://gs.statcounter.com/os-market-share/desktop/worldwide/2025>
- Mobile OS market share reference: <https://gs.statcounter.com/os-market-share/mobile/worldwide-/2025>
- Windows touch guidance: <https://learn.microsoft.com/en-us/windows/apps/develop/input/touch-interactions>
