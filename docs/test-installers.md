# Testing installers from GitHub Actions

The [Test installers workflow](https://github.com/ethereal-esthesia/simplicity-engine/actions/workflows/test-installers.yml)
builds downloadable development packages on relevant pushes to `main` and on
**Run workflow**. Downloads are attached to the workflow run under **Artifacts**
and retained for 14 days. Each includes the source commit and SHA-256 checksums.
App archives are checked for the expected CPU architecture; iOS downloads must
also identify themselves as simulator apps.
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
| iOS Simulator | Apple silicon macOS + Xcode | Zipped simulator .app for Apple silicon Macs |

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

## Physical iPhone/iPad testing (free Apple Account)

You do not need a jailbreak or paid Apple Developer Program membership to test
on your own device. You do need a free Apple Account signed into Xcode so Apple
can provision and sign the native app. Personal Team profiles expire after seven
days; rebuild and reinstall afterward. This is local device testing, not a
shareable unsigned IPA or TestFlight distribution. See
[Apple membership comparison](https://developer.apple.com/support/compare-memberships/).

1. Install full Xcode, launch it to finish component installation, and select it
   as the active developer directory if necessary:
   `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
2. In **Xcode > Settings > Apple Accounts** (Accounts in some versions), sign in
   with your Apple Account. Select your Personal Team. Use **Manage Certificates**
   to create an **Apple Development** certificate if none exists. Xcode and macOS
   Keychain retain the account and private key; do not paste passwords into chat.
3. Connect and unlock your iPhone/iPad, accept **Trust This Computer**, and enable
   **Settings > Privacy & Security > Developer Mode**, restarting when prompted.
   If the option is missing, pair the device with Xcode first. See
   [Apple device setup](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
4. Find the 10-character **Team ID (Organizational Unit)**. If Xcode does not show it in account details,
   open **Keychain Access**, select your Apple Development certificate, and read
   its **Details > Subject Name > Organizational Unit** value. Do not export the
   private key. Run these commands from the repository root:

   ```sh
   npm ci
   bash scripts/ci/prepare-ios-tools.sh
   rustup target add wasm32-unknown-unknown aarch64-apple-ios
   bash scripts/ios-device.sh setup
   bash scripts/ios-device.sh init
   bash scripts/ios-device.sh dev --open
   ```

5. Keep the terminal command running. In the generated Xcode project select the
   iOS app target, then **Signing & Capabilities**, enable **Automatically manage
   signing**, and select your Personal Team. Select the connected device as the
   run destination and press **Run**. If the bundle identifier is unavailable,
   choose a unique identifier in a local Tauri config and pass it with `--config`
   to both `init` and `dev`; do not change the shared identifier just for your account.
6. If prompted on the device, trust your developer under **Settings > General >
   VPN & Device Management**. Confirm the app launches and displays the mint
   Hello Pixel graphic. Report the step and error if anything fails, without
   sharing account passwords or private keys.

The setup script saves only the team ID to `local/apple-development-team`
(ignored by Git, file mode 600). Its `init`, `dev`, and `build` commands load that
value as `APPLE_DEVELOPMENT_TEAM`; it never stores or reads your Apple password.
Delete that file to forget the selection. Xcode may still request account renewal
or Keychain access. CI signing and TestFlight distribution need separate setup.
These instructions still need end-to-end validation on a physical device.

## Packaged-build requests

When preparing a requested package:

- Determine OS, CPU, and personal testing versus distribution from the request;
  ask only for missing details that change the package.
- Build or select an artifact for the requested revision, verify the job succeeded,
  and include its commit, checksum, install instructions, and signing limitations.
- For iOS, explicitly distinguish simulator versus physical device. For a personal
  device, reuse the saved team through `scripts/ios-device.sh`; if setup is missing,
  point the user to the steps above. Never label a simulator ZIP or unsigned IPA
  as an installable physical-device package. Use Xcode Run for free-account testing.
- For distribution, identify the required signing/provisioning setup rather than
  implying that free Personal Team testing provides a distributable release.
- Report build success separately from actual installation and launch verification.

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

## Local simulator testing and Xcode build errors

Simulator testing does not require an Apple Account or the device setup script.
Install an iOS Simulator runtime in Xcode Settings > Components, then run:

```sh
npm run tauri -- ios init
node scripts/configure-ios-xcode.mjs
npm run tauri -- ios dev --open
```

Keep the terminal running and select a specific iPhone simulator in Xcode before
pressing Run. If Xcode reports `npm: command not found`, rerun
`node scripts/configure-ios-xcode.mjs` from the repository root. This configures
the generated build phase to find this Mac's Node installation and Rust tooling.
Rerun it after regenerating the project or changing Node installations. The
`ios-device.sh` wrapper applies it automatically.

If Run/⌘R fails with `failed to read CLI options` and `Connection refused`,
Xcode is pointing at an ended Tauri CLI session. Stop the old `ios dev --open`
command with Ctrl-C, rerun `npm run tauri -- ios dev --open`, and leave that
terminal running while using Xcode. Avoid running a second Tauri iOS build/dev
command concurrently: it can replace the connection settings used by Xcode.
After a command-line build, restart the `--open` session before using ⌘R.

If Xcode stops in `dyld` with `Library not loaded: ...debug.dylib` and
`Trying to load an unsigned library`, rerun `node scripts/configure-ios-xcode.mjs`
and rebuild. The helper sets `ENABLE_DEBUG_DYLIB=NO` on the app target so debug
code is linked into the executable. This follows Apple's supported
[debug layout opt-out](https://developer.apple.com/documentation/xcode/understanding-build-product-layout-changes);
SwiftUI Previews for this app target are unavailable with this setting.
