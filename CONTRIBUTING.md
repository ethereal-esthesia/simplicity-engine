# Contributing

The common engine language is C++, compiled to WebAssembly. The desktop direction
is WebKit/WKWebView on macOS only and Electron for other desktops. Keep engine
logic shared and host adapters thin. The Wasm pipeline and both hosts are planned;
the existing macOS and iPhone/iOS native demos remain the buildable foundation.
See the [roadmap](docs/platform-targets-todo.md).

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
