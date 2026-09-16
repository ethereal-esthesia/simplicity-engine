# Apple developer setup

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

Electron setup will be documented when its implementation lands. See the
[platform roadmap](platform-targets-todo.md). Existing local VM images and SDK
installations are outside the repository and are not managed by these scripts.
