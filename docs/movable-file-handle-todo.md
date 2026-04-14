# Movable File Handle Normalization TODO

## Goal
Create a cross-platform class that can keep referring to a user-selected file or folder after normal renames and moves, while making each platform's guarantees explicit.

Working name: `MovableFileHandle`.

## Core Model
- [ ] Represent the target kind: file, folder, or unknown.
- [ ] Store the original display path for UI/debugging, but never treat it as identity.
- [ ] Store a stable locator when the platform provides one.
- [ ] Store a persisted permission grant when sandboxed/platform policy requires one.
- [ ] Support live open handles separately from persisted locators.
- [ ] Expose stale/unresolved states instead of silently falling back to an old path.
- [ ] Version the serialized token format so platform payloads can evolve.

## Public API Sketch
- [ ] `MovableFileHandle::fromPickerSelection(path_or_platform_object)`
- [ ] `MovableFileHandle::fromPathBestEffort(path)`
- [ ] `resolve() -> ResolvedFileTarget`
- [ ] `openRead()`, `openWrite()`, and `openDirectory()`
- [ ] `refresh()` to update stale bookmark/link metadata after a successful resolve.
- [ ] `serialize()` / `deserialize()`
- [ ] `debugDescription()` that reports platform strategy and state without exposing sensitive token contents.

## Platform Backends
- [ ] macOS: prefer security-scoped `NSURL` bookmark data for user-selected files/folders.
- [ ] macOS: use non-security-scoped bookmark data where sandbox permissions are not needed.
- [ ] macOS: treat file reference URLs as runtime-only helpers, not durable serialized identity.
- [ ] macOS: optionally test Finder alias behavior as a compatibility fallback, not the primary engine format.
- [ ] Windows: use picker/FutureAccessList tokens for packaged app permission grants.
- [ ] Windows: store file ID plus volume identity for same-volume rename/move tracking when available.
- [ ] Windows: optionally resolve `.lnk`/Shell Link targets when importing user-provided shortcuts.
- [ ] Linux: store `st_dev` and `st_ino` for best-effort identity checks.
- [ ] Linux: investigate `name_to_handle_at` / `open_by_handle_at` as an advanced backend, gated by filesystem support and privileges.
- [ ] Linux sandbox: support XDG document portal URIs/FUSE paths as persisted grants for Flatpak-style environments.

## Semantics to Normalize
- [ ] `canResolveAfterRename`
- [ ] `canResolveAfterMoveWithinVolume`
- [ ] `canResolveAfterMoveAcrossVolume`
- [ ] `requiresUserGrant`
- [ ] `requiresProcessLifetimeOnly`
- [ ] `requiresPrivilege`
- [ ] `mayBecomeStale`
- [ ] `canRefreshToken`
- [ ] `supportsFolderTargets`

## Resolution Policy
- [ ] Try the strongest persisted platform locator first.
- [ ] If the locator resolves, verify target kind and refresh stale metadata if needed.
- [ ] If only identity metadata is available, verify by platform identity rather than name.
- [ ] Use the original path only as a last-resort hint and return a degraded/confidence state.
- [ ] Never claim a match after deletion/recreation unless platform identity confirms it.
- [ ] Surface "permission needed" separately from "target not found".

## Tests and Probes
- [ ] Add fixture tests for serialization compatibility and unknown future fields.
- [ ] Add integration tests for rename in place.
- [ ] Add integration tests for move within the same folder tree.
- [ ] Add integration tests for move to another folder on the same volume.
- [ ] Add negative tests for delete and recreate at the same path.
- [ ] Add folder-target tests, including opening a child by relative path.
- [ ] Extend the existing `probes/macos/bookmark_probe.mm` into a reusable backend probe or migrate it into tests.
- [ ] Add Windows and Linux probes before locking the public API.

## Open Questions
- [ ] Should this class live in the engine platform layer or the asset/resource layer?
- [ ] Should the serialized token be JSON for inspectability or a compact binary blob with platform subrecords?
- [ ] Do we need separate types for `MovableFileHandle` and `MovableFolderHandle`, or is target kind enough?
- [ ] How much sandbox behavior should be compiled in by default versus enabled by platform feature flags?
- [ ] What is the minimum acceptable Linux fallback when no portal and no privileged file-handle API are available?
