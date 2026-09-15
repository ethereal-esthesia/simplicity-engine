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
./scripts/dev-setup.sh --target android --device phone
./scripts/dev-setup.sh --target ios --device phone
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
  missing Simplicity phone AVDs. SDK Command-line Tools and Java must already
  be installed. Android Studio's SDK Manager provides these tools. SDK license
  prompts are not automatically accepted.
- iOS: requires full Xcode and an installed iOS runtime, reuses available phone simulators, and creates missing devices. Missing runtimes are reported
  with the download command. Xcode installation and its license are user steps.

`--check` reports readiness without installing, creating directories, writing logs,
opening apps, or connecting to a guest. It does not prove that a VM boots or that
an app works. Each real setup run writes a log under STORAGE/logs.
Exit status: 0 = PASSED, 3 = SETUP INCOMPLETE, 1 = FAILED, 2 = invalid arguments.

## VM workflow and its current boundary

The VM backend runs on macOS and installs UTM with Homebrew if missing. UTM uses
Apple virtualization for macOS and its QEMU backend for Windows/Linux. macOS guests
require Apple Silicon. UTM is free; guest OS licensing remains separate.

Linux and Windows VM creation is automated. Supply `--media /path/to/installer.iso`;
setup creates a UTM VM, exports its system disk to
`STORAGE/vms/Simplicity-TARGET.utm`, removes only the verified temporary staging
VM, opens the external bundle and attaches the ISO through UTM's scripting API.
Media is referenced in place, not copied. The graphical display and shared network
are configured. Windows also enables UTM's TPM device and ensures a second CD drive exists.
Setup does not download or mount guest tools. In UTM use **Drives → Install Windows
Guest Tools** so UTM manages the download and attachment. If a previous tools ISO
occupies that drive, eject it first; do not eject the Windows installer during setup.
Existing VMs must be shut down before a missing CD drive can be added. Existing
media and system disks are retained. If Windows asks for a network driver, browse
the UTM tools CD (including subfolders), not the Windows Sources folder.
Installer completion is
not yet verified.

```sh
./scripts/dev-setup.sh --target linux --vm --storage "/Volumes/Storage/VM Images/Simplicity" \
  --media "/Volumes/Storage/VM Images/ISOs/Fedora-Workstation-Live-44-1.7.aarch64.iso" \
  --ram 4096 --cpus 4 --disk 64
```

RAM is in MiB and disk capacity in GiB. These settings apply only to new VMs.
Use `--vm-path /path/to/existing.utm` to reuse another bundle. Existing disks and
resource settings are preserved. Explicit `--media` updates the first CD drive of a
stopped QEMU VM; omit it after installation to leave removable media unchanged.
No existing VM is overwritten. If creation is interrupted, the adjacent `.setup.json`
journal identifies the staging/export state; setup stops for inspection instead of
creating duplicates. UTM may require a macOS Automation permission prompt.

The guest OS installer, license and account steps remain interactive. VM creation
alone returns SETUP INCOMPLETE, never a claim that guest provisioning/tests passed.
The Linux configuration has been verified to reach the Fedora boot menu. Windows
creation/export/media attachment have been checked, but its installation remains to test.

**macOS restore installation is still manual.** UTM's scripting API exposes Apple
Linux creation but not the macOS IPSW restore operation. Create macOS in UTM and
supply its existing `--vm-path`; `--media` is rejected for this target rather than
silently ignored. No automatic snapshots or unattended OS installation are performed.

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
logs, exported VM bundles and new Android AVD disks. macOS VM storage is chosen
in UTM during its manual restore setup. An unmounted /Volumes destination is rejected.
Existing SDKs/AVDs are reused in place, not moved. Set ANDROID_SDK_ROOT to put the
SDK itself on another drive. Apple manages Xcode/simulator storage separately.
No completion marker skips real prerequisite checks, so interrupted setup can be
rerun. Package managers reuse their caches; there is no custom large-image download.

## Test separately

```sh
./scripts/menu_demo.sh test host
./scripts/menu_demo.sh test ios-phone
./scripts/menu_demo.sh test android-phone
# Inside Windows, from a Visual Studio developer shell:
# .\scripts\menu\demo.ps1 -Action test
```

These commands build the demo and run tests. CMake/Gradle may fetch build dependencies;
they do not install SDKs or operating systems. Use `run` instead of `test` to inspect
the menu interactively. In a VM run the same test command inside the guest.

References: [UTM macOS](https://docs.getutm.app/guest-support/macos/),
[UTM Windows guest tools](https://docs.getutm.app/guest-support/windows/).
