# Parallels Linux Testing

These scripts let macOS drive a Linux build/test/run loop through Parallels.

Default assumptions:
- VM name: `Linux`
- Linux repo path: `$HOME/Project/simplicity-engine`
- CMake preset: `linux-debug`
- Target: `hello_pixel`

## First-Time Setup
Create or register a Linux VM in Parallels, then clone this repo inside the VM at the setup script's default path, or enter another path when prompted.

The commands below assume an APT-based, Debian-compatible Linux guest. For Fedora, Arch, Alpine, or another package family, install the equivalent packages with that distro's package manager.

Install build tools inside the guest:

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build git
```

Create a local, gitignored script profile after the VM is registered:

```bash
./tools/parallels/setup.sh --target linux
```

The setup script verifies the Linux repo path inside the VM. If the folder is
missing, it can clone this repo's `origin` remote into the selected path before
writing `local/parallels/linux.env`.
It uses the current Linux user's home directory plus the host repo path relative
to the host home directory. For example, `/Users/shane/Project/simplicity-engine`
defaults to `$HOME/Project/simplicity-engine` in Linux.
It also enables Parallels host Home sharing so the VM can fetch committed local
changes from the Mac checkout.
It also writes the Linux-visible Parallels shared-folder path for the Mac repo,
defaulting to `/media/psf/Home/<host repo path relative to $HOME>`.

Install runtime/build dependencies needed by SDL on Linux if CMake reports missing packages. Common APT packages include:

```bash
sudo apt install -y pkg-config libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxinerama-dev libxkbcommon-dev libgl1-mesa-dev
```

## Build and Run from macOS
From the macOS repo root:

```bash
./tools/parallels/linux/run-linux.sh
```

Common options:

```bash
./tools/parallels/linux/run-linux.sh --no-launch
./tools/parallels/linux/run-linux.sh --vm "Debian 12"
./tools/parallels/linux/run-linux.sh --sync pull
./tools/parallels/linux/run-linux.sh --sync none
./tools/parallels/linux/run-linux.sh --host-repo /media/psf/Home/Project/simplicity-engine
./tools/parallels/linux/run-linux.sh --preset linux-release
./tools/parallels/linux/run-linux.sh --target smoke_sdl_init --no-launch
./tools/parallels/linux/run-linux.sh --test
./tools/parallels/linux/run-linux.sh --guest-repo /home/shane/src/simplicity-engine
```

By default, the runner fetches and fast-forwards from the Mac checkout through the configured Parallels shared folder before building.
`--sync pull` runs `git pull --ff-only` inside the Linux checkout before building.
`--sync none` skips the sync step.
`--host-repo` overrides the Linux-visible path to the Mac checkout if your VM sees the shared folder somewhere else.
`--launch` runs the built executable inside the Linux desktop session after a successful build.

## Sync Notes
The Linux checkout is a separate working copy. The default sync pulls committed changes from the Mac checkout without pushing.

The default host sync still uses Git, so it syncs committed local changes. It does not copy uncommitted edits.
