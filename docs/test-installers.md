# Testing installers from GitHub Actions

The [Test installers workflow](https://github.com/ethereal-esthesia/simplicity-engine/actions/workflows/test-installers.yml)
builds downloadable development packages on relevant pushes to `main` and on
**Run workflow**. Downloads are attached to the workflow run under **Artifacts**
and retained for 14 days. Each includes the source commit and SHA-256 checksums.
These are Tauri packages; the retained SDL release workflow is separate.

## Build matrix

| Target | Runner/toolchain | Output |
|---|---|---|
| macOS Apple silicon | macOS, native arm64 | DMG and zipped .app |
| macOS Intel | macOS, cross-compiled x86_64 | DMG and zipped .app |
| Windows x64 | Windows MSVC | NSIS .exe and MSI |
| Windows ARM64 | Windows MSVC cross-compilation | NSIS .exe |
| Linux x64 | Ubuntu 22.04 | DEB, RPM, AppImage |
| Linux ARM64 | Ubuntu 24.04 ARM | DEB, RPM, AppImage |
| Android | Ubuntu + JDK 17 + NDK 27 | Debug APKs for arm64, armv7, x86, x86_64 |
| iOS Simulator | macOS + Xcode | Zipped simulator .app for ARM64 and Intel Macs |

These are GitHub-hosted virtual machines, with native packaging tools on each OS.
A single Linux container cannot produce all supported installers reliably. The
portable Rust/Wasm core is built and tested in every job, while native host code
is compiled using the appropriate target toolchain. Dependencies use the checked-in
npm and Cargo locks; generated mobile projects come from the pinned Tauri CLI.

The workflow intentionally does not publish a GitHub Release or upload to stores.
Successful compilation is not proof of successful installation or rendering on
all target devices. Test each artifact before treating that platform as supported.
Linux ARM64 packages inherit Ubuntu 24.04's library baseline; x64 uses 22.04.
AppImages still depend on a compatible host OS and graphics stack.

## Installing for testing

Download and extract the artifact matching the machine's OS and CPU. Desktop
packages have no production signing or notarization; normal platform trust checks
may flag them. They are for development testing, not general distribution.

Android debug APKs are signed with the build machine's development key and can be
installed with `adb install path/to/app.apk`. A later workflow run can use a different
key; reinstalling may require removing the previous test app, which erases its data.
The workflow does not need an Android release keystore.

iOS artifacts are **simulator applications, not iPhone installers**. Extract the
inner app ZIP, boot a matching simulator, then run:

```sh
xcrun simctl install booted '/path/to/Simplicity Engine.app'
xcrun simctl launch booted dev.simplicityengine.desktop
```

A physical iPhone build requires an Apple development team, signing certificate,
and provisioning profile (or a TestFlight distribution setup). Those are not
configured, so the workflow does not pretend an unsigned IPA is installable.

## Local commands

```sh
npm ci
rustup target add wasm32-unknown-unknown
npm test
npm run tauri -- build --bundles app,dmg -- --locked   # macOS
npm run tauri -- build --bundles nsis,msi -- --locked  # Windows x64
npm run tauri -- build --bundles deb,rpm,appimage -- --locked # Linux
```

Install platform dependencies first; see
[Tauri prerequisites](https://v2.tauri.app/start/prerequisites/).
For the exact mobile initialization and build commands, see
[the workflow](../.github/workflows/test-installers.yml).
