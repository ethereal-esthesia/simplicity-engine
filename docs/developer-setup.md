# Developer setup

Use `scripts/dev-setup.sh --target TARGET` on macOS/Linux. Windows has a native
PowerShell entrypoint, `scripts/dev-setup.ps1`. There are no legacy setup aliases.
This replaces setup_target, setup-target, setup_utm, the separate mobile setup
commands, the menu setup command, and all Parallels helpers.

```sh
./scripts/dev-setup.sh --target macos --check
./scripts/dev-setup.sh --target macos
./scripts/dev-setup.sh --target linux --vm --storage "/Volumes/Storage/VM Images/Simplicity"
./scripts/dev-setup.sh --target windows --vm --storage "/Volumes/Storage/VM Images/Simplicity"
./scripts/dev-setup.sh --target macos --vm --storage "/Volumes/Storage/VM Images/Simplicity"
./scripts/dev-setup.sh --target android --device all
./scripts/dev-setup.sh --target ios --device all
```

## What setup does

- Native macOS: checks Xcode command-line tools; installs missing CMake/Ninja with
  an existing Homebrew installation.
- Native Linux: installs C++/CMake/Ninja, GTK3, SDL graphics dependencies and Xvfb
  through apt or dnf. Package managers reuse installed packages.
- Native Windows: uses winget to install CMake/Ninja and Visual Studio C++ tools.
  Installer/license prompts remain interactive. Open a developer shell afterwards.
- Android: reuses the SDK selected by ANDROID_SDK_ROOT/ANDROID_HOME or the usual
  host SDK location, installs the pinned SDK/NDK/CMake/image packages, and creates
  missing Simplicity phone/tablet AVDs. SDK Command-line Tools and Java must already
  be installed. Android Studio's SDK Manager provides these tools. SDK license
  prompts are not automatically accepted.
- iOS: requires full Xcode and an installed iOS runtime, reuses available phone/
  tablet simulators, and creates missing devices. Missing runtimes are reported
  with the download command. Xcode installation and its license are user steps.

`--check` reports readiness without installing, creating directories, writing logs,
opening apps, or connecting to a guest. It does not prove that a VM boots or that
an app works. Each real setup run writes a log under STORAGE/logs.
Exit status: 0 = PASSED, 3 = SETUP INCOMPLETE, 1 = FAILED, 2 = invalid arguments.

## VM workflow and its current boundary

The VM backend runs on macOS and installs UTM with Homebrew if missing. UTM uses
Apple virtualization for macOS and its QEMU backend for Windows/Linux. macOS guests
require Apple Silicon. UTM is free; guest OS licensing remains separate.

**VM creation and OS installation currently use the UTM wizard.** Setup opens UTM,
prints exact next steps, saves those instructions, and returns SETUP INCOMPLETE.
It never labels installed UTM or a staged image as a working guest. Use official
installation media matching your Mac architecture; `--media /path/to/image.iso`
(or IPSW) records an existing image in the instructions without duplicating it.
UTM can download a compatible macOS IPSW in its wizard.

Save the bundle to STORAGE/vms/Simplicity-TARGET.utm, or select an existing bundle
with `--vm-path /path/to/existing.utm`. Reruns reuse that bundle. No disk conversion,
Parallels migration, deletion, automatic snapshots or unattended OS installation
is performed. Existing Parallels VMs on disk remain yours to use independently.

After installing the OS and completing its account/license steps, clone or share
this repository into the guest and run the native setup command there. Unix guests
can also be provisioned from the host once SSH is enabled:

```sh
./scripts/dev-setup.sh --target linux --vm \
  --vm-path "/Volumes/Storage/VM Images/Simplicity/Fedora.utm" \
  --guest developer@192.168.64.5 --guest-repo /home/developer/simplicity-engine
```

SSH retains normal host-key/authentication prompts. Wait for the guest to boot and
rerun if the connection is not ready. Setup does not enable remote access or copy
credentials. Windows provisioning runs locally in the guest with PowerShell.

## Storage and repeat runs

`--storage PATH` (or SIMPLICITY_STORAGE) defaults to ignored `local/dev`. It holds
logs, VM instructions and new Android AVD disks. VM storage is chosen in the UTM
wizard using the printed path. An unmounted /Volumes destination is rejected.
Existing SDKs/AVDs are reused in place, not moved. Set ANDROID_SDK_ROOT to put the
SDK itself on another drive. Apple manages Xcode/simulator storage separately.
No completion marker skips real prerequisite checks, so interrupted setup can be
rerun. Package managers reuse their caches; there is no custom large-image download.

## Test separately

```sh
./scripts/menu_demo.sh test host
./scripts/menu_demo.sh test ios-phone
./scripts/menu_demo.sh test ios-tablet
./scripts/menu_demo.sh test android-phone
./scripts/menu_demo.sh test android-tablet
# Inside Windows, from a Visual Studio developer shell:
# .\scripts\menu\demo.ps1 -Action test
```

These commands build the demo and run tests. CMake/Gradle may fetch build dependencies;
they do not install SDKs or operating systems. Use `run` instead of `test` to inspect
the menu interactively. In a VM run the same test command inside the guest.

References: [UTM macOS](https://docs.getutm.app/guest-support/macos/),
[UTM Windows guest tools](https://docs.getutm.app/guest-support/windows/).
