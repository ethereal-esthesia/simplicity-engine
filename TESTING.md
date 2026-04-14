# Testing

This project uses an automated smoke-first approach for every change, with optional manual visual verification.

## Local Smoke Test

Primary path (recommended):

```bash
cmake --preset debug
cmake --build --preset debug
./tools/smoke.sh debug
```

```bash
cmake --preset release
cmake --build --preset release
./tools/smoke.sh release
```

Full test suite (broader than smoke):

```bash
cmake --preset release
cmake --build --preset release
./tools/test.sh release
```

Optional manual visual check:

Debug:

```bash
./scripts/run.sh
```

Release:

```bash
./scripts/run.sh --preset release
```

Expected behavior:
- A window titled `Simplicity Engine - Hello Pixel` opens.
- Background is dark.
- A small mint mark appears at the center.
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

Additional non-smoke tests:
- `test_fast_rng_vectors` (`rng`, `full` labels): broader deterministic vector parity and behavioral checks for RNG.

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
