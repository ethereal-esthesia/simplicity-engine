# Platform testing

Current targets: macOS, Linux, Windows, iPhone and Android phone.

Use `scripts/dev-setup.sh --target ios` or `--target android` to prepare mobile environments.
Run `scripts/menu_demo.sh test ios-phone` or `test android-phone`, then use `run` for a visual check.
Desktop setup uses `--target macos`, `linux`, or `windows`; add `--vm` on a Mac to use UTM.
