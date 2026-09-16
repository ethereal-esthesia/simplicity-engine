# Scripts

- `dev-setup.sh --target macos|ios [--check]`: verify Apple tools; prepare an iPhone simulator.
- `run.sh`: build and launch the macOS demo.
- `build_target.sh` / `run_target.sh`: route `macos` or `ios-phone`.
- `run_ios_iphone.sh`: build and launch the iPhone simulator demo.
- `menu_demo.sh <build|test|run> <host|ios-phone>`: Menu Studio.
- `package_target.sh <macos-arm64|macos-x64>`: macOS archive.
- `smoke.sh` / `test.sh [debug|release]`: test an existing build.
- `release.sh [version]`: inspect or create/push a release tag.

Hyphenated target commands are aliases. Internal implementations live in `impl/`.
See [developer setup](../docs/developer-setup.md) and the [roadmap](../docs/platform-targets-todo.md).
