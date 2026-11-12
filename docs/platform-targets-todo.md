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

A fullscreen transparent overlay with mouse passthrough and a custom cursor is
a separate, SDL3-based direction outside this Tauri/Wasm host; see
[overlay passthrough direction](overlay-passthrough-direction.md).

## Installer and iOS follow-up checklist — 2026-09-17

Checked items were implemented or verified during the local setup session; they
are not a claim that the changes have been committed, published, or tested on all
platforms. Installation instructions live in [test-installers.md](test-installers.md).

### Documentation and local setup

- [x] Explain free Apple Account / Personal Team testing on an owned iPhone/iPad:
  no paid membership or jailbreak required; signing is required and provisioning
  expires after seven days.
- [x] Distinguish simulator `.app` packages from physical-device builds and `.ipa`
  distribution. A simulator app cannot run on an iPhone, or vice versa.
- [x] Document packaged-build requests: OS, CPU, testing versus distribution,
  revision, checksums, installation steps, signing limits, and actual test status.
- [x] Add `scripts/ios-device.sh` to save and reuse the team ID in Git-ignored
  `local/apple-development-team` with mode 600. Keep passwords and signing keys
  managed by Xcode/macOS Keychain.
- [x] Label the setup prompt **Team ID (Organizational Unit)** and include the
  certificate lookup path in Keychain Access.
- [x] Exercise account/team setup locally through the user's Xcode walkthrough.
- [ ] Validate the complete free-account installation instructions on a physical
  iPhone/iPad. The user does not own one; simulator testing cannot complete this.
- [x] Document simulator-only setup without Apple credentials.
- [x] Explain runtime removal through Xcode Settings > Components, including older
  installed runtimes. Keep an installed iOS simulator runtime for simulator tests;
  retain device support if physical-device development is needed.

### Build and launch fixes

- [x] Fix Intel iOS CI's CocoaPods installation conflict by reusing existing tools
  in `scripts/ci/prepare-ios-tools.sh`; local mocked checks passed.
- The Intel iOS simulator CI job was removed because its GitHub-hosted runner is
  no longer supported; the previous failure occurred before compilation.
- [x] Fix Xcode's `npm: command not found` with
  `scripts/configure-ios-xcode.mjs`, configuring Node/npm and Rust tool paths.
- [x] Apply that helper automatically through the device wrapper and document
  reapplication after `ios init` or a Node installation change.
- [x] Diagnose and document Tauri's stale CLI connection error: restart
  `ios dev --open`, leave it running, and avoid competing iOS CLI sessions.
- [x] Fix the simulator's unsigned `.debug.dylib` launch crash by setting
  `ENABLE_DEBUG_DYLIB=NO` on the app target in the setup helper. This opts the app
  target out of SwiftUI Previews; it does not disable library validation.
- [x] Verify the corrected Xcode project builds and launches through Run/⌘R on
  the Apple silicon iPhone Simplicity simulator (iOS 26.5).
- [x] Visually verify the dark background and mint pixel; user confirmed a pass.
- [ ] Commit the reviewed setup/documentation changes and publish them to the
  intended branch, then verify CI against that exact revision.

### Downloadable package validation

- [ ] Test the GitHub Actions ARM64 iOS simulator artifact independently: extract
  the outer download and inner app ZIP, stop Xcode/Tauri development, drag the
  `.app` into the booted simulator, launch from Home Screen, and verify rendering.
- [ ] Test macOS Apple silicon DMG and zipped `.app` installation/launch.
- [ ] Test macOS Intel DMG and zipped `.app` installation/launch.
- [ ] Test Windows x64 NSIS EXE and MSI installation/launch.
- [ ] Test Windows ARM64 NSIS EXE installation/launch.
- [ ] Test Linux x64 DEB, RPM, and AppImage on compatible systems.
- [ ] Test Linux ARM64 DEB, RPM, and AppImage on compatible systems; note its
  Ubuntu 24.04 build baseline versus Ubuntu 22.04 for x64.
- [ ] Test Android debug APKs for arm64, armv7, x86, and x86_64 on matching devices
  or emulators. Document that changing debug signing keys can require uninstalling
  the previous app and losing its data.
- [ ] Record artifact commit, checksums, OS/runtime, CPU, package format, install
  result, launch/rendering result, and warnings for every tested target.
- [ ] Keep successful compilation separate from installation and device validation.

### UIScene compatibility migration

- [x] Confirm the current generated app lacks a scene manifest and the pinned
  Tao 0.35.3 gates scene handling on multi-window support.
- [x] Identify the upstream single-window scene issue and relevant Tao 0.37.0
  lifecycle fixes. The pinned Tauri runtime currently requires Tao 0.35.x.
- [ ] Find and adopt a compatible Tauri/runtime dependency upgrade containing
  the required Tao scene fixes; review lockfile and cross-platform impact.
- [ ] Retain a single-window design (`UIApplicationSupportsMultipleScenes=false`)
  unless multi-window behavior is deliberately introduced and tested.
- [ ] Add a persistent `src-tauri/Info.ios.plist` scene manifest through Tauri's
  supported configuration. Verify the final generated and packaged Info.plist.
- [ ] Verify Tauri/Tao registers the scene configuration and delegate, connects
  the UIWindow to its UIWindowScene, and assigns the root view controller.
  Reuse framework-owned delegates rather than adding a competing Swift delegate.
- [ ] Add scene configuration names/delegate entries or dynamic configuration only
  as required by the upgraded framework. Add `UISceneStoryboardFile` only if the
  root UI is storyboard-driven; the launch storyboard alone does not require it.
- [ ] Audit active/inactive and background/foreground callbacks. Verify framework
  scene callbacks deliver the expected app behavior; migrate any app-owned logic
  and replace inappropriate global state checks with suitable notifications.
- [ ] Audit external-display handling; only if applicable, replace deprecated
  noninteractive external-display scene handling with the supported accessory API.
- [ ] Verify both debug and release launches without the UIScene lifecycle warning
  or assertions, including the newer SDK/runtime combination that requires scenes.
- [ ] Test background/foreground transitions, rotation, relaunch, and scene restoration.
- [ ] Test iPad Full Screen, Windowed, and Stage Manager behavior on supported
  devices/runtimes; document unavailable test environments explicitly.
- [ ] Recheck desktop and Android builds after the dependency upgrade.

References: [Tao single-window issue](https://github.com/tauri-apps/tao/issues/1308),
[Tao 0.37.0 release](https://github.com/tauri-apps/tao/releases/tag/tao-v0.37.0),
[Apple scene migration](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle).
Apple requires scenes for apps built with the latest SDK starting with iOS 27;
this remains outstanding compatibility work, not a completed migration.

### Console warnings and distribution

- [x] Separate the resolved unsigned-library crash from the outstanding UIScene
  warning and observed Apple WebKit/networking/accessibility diagnostics.
- [ ] Record whether WebKit networking/configuration, query-parameter, server
  registration, accessibility-cache, and duplicate-class messages recur during
  standalone package tests or accompany functional problems.
- [x] Identify both duplicate `UIAccessibilityLoaderWebShared` copies as Apple
  simulator runtime components. Do not delete or rename those system libraries.
- [ ] Configure production desktop signing/notarization and release distribution
  when preparing public releases; current test packages are development builds.
- [ ] Configure Android release signing and distribution separately from debug APKs.
- [ ] Configure Apple device/CI signing and provisioning or TestFlight distribution
  when physical-device distribution is requested; free local testing is separate.
- [ ] Replace or extend the retained tag-driven SDL macOS release workflow with
  the intended Tauri release pipeline before claiming production installer coverage.
