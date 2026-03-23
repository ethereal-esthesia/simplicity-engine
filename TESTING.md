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
