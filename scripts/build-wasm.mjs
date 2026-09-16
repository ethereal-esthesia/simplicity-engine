import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
// Override the output directory so a user's Cargo config cannot move the artifact
// away from the path copied below. Never build the native host for the Wasm target.
const result = spawnSync('cargo', [
  'build', '--locked', '-p', 'simplicity-core', '--release',
  '--target', 'wasm32-unknown-unknown', '--target-dir', 'target',
], { cwd: root, stdio: 'inherit' });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
mkdirSync(new URL('../web/generated/', import.meta.url), { recursive: true });
copyFileSync(
  new URL('../target/wasm32-unknown-unknown/release/simplicity_core.wasm', import.meta.url),
  new URL('../web/generated/simplicity_core.wasm', import.meta.url),
);
