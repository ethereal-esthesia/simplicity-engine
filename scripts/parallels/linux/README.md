# Parallels Linux Testing

These scripts let macOS drive a Linux build/test/run loop through Parallels.

Default assumptions:
- VM name: `Linux`
- Linux repo path: `/home/shane/Project/simplicity-engine`
- CMake preset: `linux-debug`
- Target: `hello_pixel`

## First-Time Setup
Create or register a Linux VM in Parallels, then clone this repo inside the VM at the default path, or pass another path with `--guest-repo`.

The commands below assume an APT-based, Debian-compatible Linux guest. For Fedora, Arch, Alpine, or another package family, install the equivalent packages with that distro's package manager.

Install build tools inside the guest:

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build git
```

Create a local, gitignored script profile after the VM is registered:

```bash
./scripts/parallels/setup.sh --target linux
```

Install runtime/build dependencies needed by SDL on Linux if CMake reports missing packages. Common APT packages include:

```bash
sudo apt install -y pkg-config libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxinerama-dev libxkbcommon-dev libgl1-mesa-dev
```

## Build and Run from macOS
From the macOS repo root:

```bash
./scripts/parallels/linux/run-linux.sh
```

Common options:

```bash
./scripts/parallels/linux/run-linux.sh --vm "Debian 12"
./scripts/parallels/linux/run-linux.sh --sync pull
./scripts/parallels/linux/run-linux.sh --preset linux-release
./scripts/parallels/linux/run-linux.sh --target smoke_sdl_init --no-launch
./scripts/parallels/linux/run-linux.sh --test
./scripts/parallels/linux/run-linux.sh --guest-repo /home/shane/src/simplicity-engine
```

`--sync pull` runs `git pull --ff-only` inside the Linux checkout before building.
`--launch` runs the built executable inside the Linux desktop session after a successful build.

## Sync Notes
The Linux checkout is a separate working copy. Commit and push from macOS before using `--sync pull`, or manually copy changes into the Linux checkout.

If you need to test uncommitted macOS changes, use a Parallels shared folder or add a dedicated copy/sync step later.
