# Parallels Windows Testing

These scripts let macOS drive a Windows build/run loop through Parallels.

Default assumptions:
- VM name: `Windows 11`
- Windows repo path: `%USERPROFILE%\Project\simplicity-engine`
- CMake preset: `debug`
- Target: `hello_pixel`

## First-Time Setup
Clone this repo inside the Windows VM at the setup script's default path, or enter another path when prompted.

Install build tools inside Windows:
- CMake
- Ninja
- Git
- A C++ compiler toolchain, such as Visual Studio Build Tools

Create a local, gitignored script profile after the VM is registered:

```bash
./scripts/parallels/setup.sh --target windows
```

The setup script verifies the Windows repo path inside the VM. If the folder is
missing, it can clone this repo's `origin` remote into the selected path before
writing `local/parallels/windows.env`.
It uses the current Windows user's profile directory plus the host repo path
relative to the host home directory. For example, `/Users/shane/Project/simplicity-engine`
defaults to `%USERPROFILE%\Project\simplicity-engine` in Windows.
It also writes the Windows-visible Parallels shared-folder path for the Mac repo,
defaulting to `\\Mac\Home\<host repo path relative to $HOME>`.

## Build and Run from macOS
From the macOS repo root:

```bash
./scripts/parallels/run-windows.sh
```

Common options:

```bash
./scripts/parallels/run-windows.sh --no-launch
./scripts/parallels/run-windows.sh --sync pull
./scripts/parallels/run-windows.sh --sync none
./scripts/parallels/run-windows.sh --host-repo '\\Mac\Home\Project\simplicity-engine'
./scripts/parallels/run-windows.sh --preset release
./scripts/parallels/run-windows.sh --target smoke_sdl_init --no-launch
./scripts/parallels/run-windows.sh --test
./scripts/parallels/run-windows.sh --native
./scripts/parallels/run-windows.sh --guest-repo 'C:\Users\shane\src\simplicity-engine'
```

By default, the runner fetches and fast-forwards from the Mac checkout through the configured Parallels shared folder before building.
`--sync pull` runs `git pull --ff-only` inside the Windows checkout before building.
`--sync none` skips the sync step.
`--host-repo` overrides the Windows-visible path to the Mac checkout if your VM sees the shared folder somewhere else.
`--launch` runs the built executable through Windows after a successful build.
`--native` enables guest-to-host app sharing before launch so Windows app windows can integrate more naturally with macOS.

## Sync Notes
The Windows checkout is a separate working copy. The default sync pulls committed changes from the Mac checkout without pushing.

The default host sync still uses Git, so it syncs committed local changes. It does not copy uncommitted edits.
