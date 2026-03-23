# Testing

This project currently uses a lightweight smoke-test approach: build both primary build types and run the app manually.

## Local Smoke Test

Debug:

```bash
cmake --preset debug
cmake --build --preset debug
./build/debug/hello_pixel
```

Release:

```bash
cmake --preset release
cmake --build --preset release
./build/release/hello_pixel
```

Expected behavior:
- A window titled `Simplicity Engine - Hello Pixel` opens.
- Background is dark.
- A single white pixel appears at the center.
- Closing the window exits cleanly.

## Headless SDL Init Smoke Test

Smoke tests are label-based (`smoke`) and can be run in one command:

```bash
cmake --preset release
cmake --build --preset release
./tools/smoke.sh release
```

Current smoke tests:
- `smoke_sdl_init`: verifies SDL video subsystem initialization in no-display mode (`dummy` video driver).
- `smoke_fast_rng`: verifies deterministic RNG output parity with Serenity vectors.

## Container Cross-Platform Build Smoke Test

Build image:

```bash
docker build -t simplicity-engine-build .
```

Run cross-platform build script:

```bash
docker run --rm -it -v "$PWD:/workspace" simplicity-engine-build ./tools/build-in-container.sh
```

Expected artifacts:
- `build/linux-debug/hello_pixel`
- `build/linux-release/hello_pixel`
- `build/windows-debug/hello_pixel.exe`
- `build/windows-release/hello_pixel.exe`
