# SSH Remote Runner TODO

## Goal
Use SSH as the stable local remote-execution layer for emulator and machine targets, instead of relying on emulator-specific guest command APIs.

Working idea: keep Parallels, QEMU, UTM, and physical machines responsible for lifecycle/display, while SSH handles build, test, sync, run, and logs.

## Core Model
- [ ] Treat every remote target as `user@host` plus platform metadata.
- [ ] Support Windows and APT-based Linux first.
- [ ] Keep local macOS builds on `scripts/run.sh`.
- [ ] Keep `scripts/parallels/run-windows.sh` as a fallback/bootstrap path, not the long-term remote abstraction.
- [ ] Make the remote runner emulator-agnostic: no required `prlctl`, QEMU, or UTM command for normal build/run.
- [ ] Store local per-machine settings under `local/remote/`, ignored by git.
- [ ] Make output quiet by default and write full logs under `logs/`.
- [ ] Preserve `--console` as the opt-in full-output mode.

## Local Bootstrap
- [ ] Add a bootstrap note for enabling OpenSSH Server on Windows.
- [ ] Add a bootstrap note for ensuring `sshd` is running on Linux.
- [ ] Document host discovery options: `.local` hostname, static IP, emulator NAT port forward, or manually configured host alias.
- [ ] Document key-based login from macOS.
- [ ] Add a smoke command: `ssh <target> whoami`.
- [ ] Add a path smoke command for each platform:
  - [ ] Windows: verify `git`, `cmake`, and `ninja` are on PATH.
  - [ ] Linux: verify `git`, `cmake`, `ninja`, and a compiler are on PATH.
- [ ] Document that SSH does not provide display by itself.

## Config Sketch
- [ ] Support a config file such as `local/remote/windows.env`.
- [ ] Support a config file such as `local/remote/linux.env`.
- [ ] Include `REMOTE_HOST`, for example `ether@windows-vm.local`.
- [ ] Include `REMOTE_PLATFORM`, for example `windows` or `linux`.
- [ ] Include `REMOTE_REPO`, using the remote platform path style.
- [ ] Include `REMOTE_PRESET`, defaulting to `debug` for Windows and `linux-debug` for Linux if needed.
- [ ] Include `REMOTE_TARGET`, defaulting to `hello_pixel`.
- [ ] Include optional `REMOTE_DISPLAY_MODE`, for notes only at first: `parallels`, `rdp`, `vnc`, `spice`, or `manual`.

## Runner Shape
- [ ] Add `scripts/remote/run.sh`.
- [ ] Options:
  - [ ] `--config <path>`
  - [ ] `--host <user@host>`
  - [ ] `--platform <windows|linux>`
  - [ ] `--repo <remote path>`
  - [ ] `--preset <name>`
  - [ ] `--target <name>`
  - [ ] `--test`
  - [ ] `--no-test`
  - [ ] `--launch`
  - [ ] `--no-launch`
  - [ ] `--console`
- [ ] Validate that required config is present before connecting.
- [ ] Run a short SSH preflight before doing build work.
- [ ] Write a timestamped host-side log in `logs/`.
- [ ] Print only high-signal status lines by default.
- [ ] Surface missing dependency messages using the shared install hint wording.

## Sync Strategy
- [ ] Start with committed-only Git sync, matching the current VM runner behavior.
- [ ] Add a `mac` remote on the guest when the local repo is reachable as a network path.
- [ ] Also support `git fetch origin <branch>` for machines that cannot see the Mac checkout.
- [ ] Avoid copying uncommitted changes by default.
- [ ] Add an explicit future escape hatch for uncommitted changes, likely `rsync`, but do not make it default.
- [ ] Never park rejected, replaced, or "bad" files in an unbounded backup directory by default.
- [ ] If an uncommitted-file sync mode is added, require excludes for build outputs, logs, dependency caches, and generated artifacts.
- [ ] If an uncommitted-file sync mode is added, estimate transfer size before copying and fail before writing when it exceeds a configured budget.
- [ ] Prefer atomic temp paths that are cleaned up on failure over accumulating timestamped abandoned copies.

## Disk Safety
- [ ] Add a remote free-space preflight before sync/build.
- [ ] Make the required free-space threshold configurable per target.
- [ ] Fail early with a clear message when the remote repo volume is low on space.
- [ ] Keep host-side and remote-side logs bounded by count or age.
- [ ] Avoid remote artifact retention unless explicitly requested.
- [ ] Put temporary files under a known runner temp directory.
- [ ] Clean the runner temp directory at the start of each run unless a debug flag asks to preserve it.
- [ ] Do not delete user-owned files outside runner-managed temp/build/log paths.
- [ ] Make any destructive cleanup visible in `--console` output and the run log.
- [ ] Add a `--dry-run-sync` or equivalent before supporting any non-Git file sync.

## Windows Remote Build
- [ ] Keep the Windows build logic in PowerShell on the guest, but invoke it over SSH.
- [ ] Reuse or adapt `scripts/parallels/guest-build-run.ps1`.
- [ ] Keep `VsDevCmd.bat` probing and MSVC target detection.
- [ ] Keep stale MSVC CMake cache detection.
- [ ] Launch GUI apps through a detached Windows process when `--launch` is used.
- [ ] Confirm SSH-launched GUI apps can attach to the logged-in Windows desktop session.
- [ ] If SSH cannot launch visible GUI apps directly, document the display launch path separately.

## Linux Remote Build
- [ ] Reuse or adapt `scripts/parallels/linux/guest-build-run.sh`.
- [ ] Verify display behavior under common local VM setups.
- [ ] Support `DISPLAY` forwarding only as an explicit opt-in, not the default.
- [ ] Prefer launching on the guest's existing display when available.

## Display Model
- [ ] Keep display separate from execution.
- [ ] For Parallels Windows, use Coherence/shared app windows for the visible app.
- [ ] For QEMU/UTM/Linux, document VNC/SPICE/RDP-style display options.
- [ ] Do not promise that SSH alone shows a remote GUI on the Mac desktop.
- [ ] Add clear troubleshooting notes for "build succeeded but no window appeared."

## Security and Reliability
- [ ] Prefer SSH keys over passwords.
- [ ] Avoid storing passwords in repo-local config.
- [ ] Avoid disabling host key checking by default.
- [ ] Support `~/.ssh/config` aliases.
- [ ] Ensure logs do not print private keys or credentials.
- [ ] Handle hosts being offline with a concise error.
- [ ] Handle stale host keys with a concise pointer to SSH's own warning.

## Tests and Probes
- [ ] Add `scripts/remote/run.sh --preflight`.
- [ ] Test Windows `ssh whoami`.
- [ ] Test Linux `ssh whoami`.
- [ ] Test remote `git status --short --branch`.
- [ ] Test remote build without launch.
- [ ] Test remote build with tests.
- [ ] Test remote launch behavior separately from build success.
- [ ] Confirm the runner works with a Parallels VM.
- [ ] Confirm the runner works with at least one non-Parallels target before making it the primary documented remote path.

## Open Questions
- [ ] Should the remote runner live under `scripts/remote/` or replace the Parallels runner entry point later?
- [ ] Should Windows SSH setup be part of `scripts/parallels/setup.sh` or a separate remote setup script?
- [ ] Should remote configs be shell `.env` files, JSON, or TOML?
- [ ] Should the guest build scripts move out of `scripts/parallels/` once SSH is the primary remote abstraction?
- [ ] How much VM lifecycle should the remote runner attempt, if any?
- [ ] Do we want a named target registry so commands can use `--target-machine windows-arm` instead of a config path?
