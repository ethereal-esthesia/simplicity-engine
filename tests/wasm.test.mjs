import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('compiled Wasm preserves Hello Pixel geometry and palette without host imports', async () => {
  const module = await WebAssembly.compile(await readFile(
    new URL('../web/generated/simplicity_core.wasm', import.meta.url)));
  assert.deepEqual(WebAssembly.Module.imports(module), []);
  const { exports: core } = await WebAssembly.instantiate(module);
  assert.equal(core.abi_version(), 1);
  assert.equal(core.background_rgb(), 0x080c12);
  assert.equal(core.mark_rgb(), 0x40ffd0);
  assert.equal(core.mark_size(), 8);
  for (const extent of [1, 8, 800, 1600]) {
    assert.equal(core.mark_origin(extent) + core.mark_size() / 2, extent / 2);
  }
  for (const extent of [NaN, Infinity, -1, 0]) assert.equal(core.mark_origin(extent), 0);
});
