# Contributing

Use **Rust → WebAssembly** for new shared engine logic and simple conversions.
Tauri is the sole app host. Keep core logic independent of OS and Tauri APIs; use
thin web adapters and native Rust host services. Keep existing Apple code buildable
until each replacement passes behavioral checks. See the [roadmap](docs/platform-targets-todo.md).

For Rust/Tauri changes, run `make test`, `cargo fmt --all -- --check`, and `make`.
Commit Cargo.lock and package-lock.json; do not commit generated Wasm or build output.
Test in the target Tauri webview before claiming platform compatibility.

Use [Apple developer setup](docs/developer-setup.md). Before a pull request, build
Debug and Release and run CTest for both:

```sh
cmake --preset debug
cmake --build --preset debug
ctest --test-dir build/debug --output-on-failure
cmake --preset release
cmake --build --preset release
ctest --test-dir build/release --output-on-failure
```

For menu changes, run `./scripts/menu_demo.sh test host` and, for iOS changes,
`./scripts/menu_demo.sh test ios-phone`. For setup changes, run
`python3 tests/test_ios_setup.py`. See [testing](TESTING.md) for visual checks.

Keep changes focused, prefer clarity, and update documentation when behavior or
commands change. Do not reintroduce additional native platform backends or VM
provisioning without revisiting the project direction.
