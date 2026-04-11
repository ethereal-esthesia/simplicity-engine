# Parallels Windows Testing

These scripts let macOS drive a Windows build/run loop through Parallels.

Default assumptions:
- VM name: `Windows 11`
- Windows repo path: `C:\Users\shane\Project\simplicity-engine`
- CMake preset: `debug`
- Target: `hello_pixel`

## First-Time Setup
Clone this repo inside the Windows VM at the default path, or pass another path with `--guest-repo`.

Install build tools inside Windows:
- CMake
- Ninja
- Git
- A C++ compiler toolchain, such as Visual Studio Build Tools

Create a local, gitignored script profile after the VM is registered:

```bash
./scripts/parallels/setup.sh --target windows
```

## Build and Run from macOS
From the macOS repo root:

```bash
./scripts/parallels/run-windows.sh
```

Common options:

```bash
./scripts/parallels/run-windows.sh --sync pull
./scripts/parallels/run-windows.sh --preset release
./scripts/parallels/run-windows.sh --target smoke_sdl_init --no-launch
./scripts/parallels/run-windows.sh --test
./scripts/parallels/run-windows.sh --native
./scripts/parallels/run-windows.sh --guest-repo 'C:\Users\shane\src\simplicity-engine'
```

`--sync pull` runs `git pull --ff-only` inside the Windows checkout before building.
`--launch` runs the built executable through Windows after a successful build.
`--native` enables guest-to-host app sharing before launch so Windows app windows can integrate more naturally with macOS.

## Sync Notes
The Windows checkout is a separate working copy. Commit and push from macOS before using `--sync pull`, or manually copy changes into the Windows checkout.

If you need to test uncommitted macOS changes, use a Parallels shared folder or add a dedicated copy/sync step later.
