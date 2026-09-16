# Developer setup

## Rust/Wasm and Tauri

Install Rust with rustup, Node.js 22+, and Apple command-line tools on macOS.
Run `make setup`, then `make test` and `make`. Use `make run` to launch the app and
`make bundle` for a macOS app bundle. Cargo.lock and package-lock.json pin dependencies.
The Wasm target is `wasm32-unknown-unknown`; the Tauri host builds for the native OS.

Other Tauri platforms require their own [prerequisites](https://v2.tauri.app/start/prerequisites/)
and have [CI testing packages](test-installers.md); runtime testing is still required. `make ios-build` below still builds the retained
SDL simulator app.

## Retained Apple demos

Use macOS with Apple command-line developer tools, CMake 3.25+ for the presets,
Ninja, and Python 3. Install CMake and Ninja with `brew install cmake ninja` or
`sudo port install cmake ninja`.

```sh
./scripts/dev-setup.sh --target macos --check
./scripts/dev-setup.sh --target ios --check
./scripts/dev-setup.sh --target ios
```

`--check` verifies tools without creating simulators. The iOS setup command reuses
an available iPhone simulator or creates one supported by the newest installed
available iOS runtime. It does not install tools or download runtimes.
Unsupported targets/options exit with code 2; missing tools exit with code 1.

For iOS, install full Xcode and select it with
`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
Install an iOS runtime in Xcode or use `xcodebuild -downloadPlatform iOS`.
The checked-in simulator presets use arm64 and an iOS 17.0 deployment target.

Build and testing are separate from setup:

```sh
./scripts/build_target.sh macos
./scripts/run_target.sh ios-phone --build-only
./scripts/menu_demo.sh test host
./scripts/menu_demo.sh test ios-phone
```

See the
[platform roadmap](platform-targets-todo.md). Existing local VM images and SDK
installations are outside the repository and are not managed by these scripts.
