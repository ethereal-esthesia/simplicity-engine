# Testing

On macOS, configure and build each preset before running its tests:

```sh
cmake --preset debug
cmake --build --preset debug
ctest --test-dir build/debug --output-on-failure
cmake --preset release
cmake --build --preset release
ctest --test-dir build/release --output-on-failure
python3 tests/test_ios_setup.py
```

CTest covers shared menu behavior, a headless Menu Studio run, SDL initialization,
and RNG smoke/vector checks. `./scripts/menu_demo.sh test host` also verifies
native AppKit menu construction, state, and dispatch.

For iPhone simulator builds and runtime self-tests:

```sh
./scripts/run_ios_iphone.sh --build-only
./scripts/menu_demo.sh test ios-phone
```

A simulator self-test must print `MENU_SELF_TEST=PASS`. iOS binaries are tested
inside the simulator, not through host CTest.

For visual checks, run `./scripts/run.sh` (dark background and centered mint mark),
`./scripts/menu_demo.sh run host`, and `./scripts/menu_demo.sh run ios-phone`.
Verify menu interaction and clean exit. See the
[Matte Overlay guide](tools/matte-overlay/README.md) for its checks.

GitHub CI covers macOS tests and iPhone simulator compilation; nightly jobs cover
macOS arm64 and x86_64. Electron validation is pending its implementation.
