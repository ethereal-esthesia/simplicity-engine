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

test('compiled Wasm exposes the shared menu model through its C ABI', async () => {
  const module = await WebAssembly.compile(await readFile(
    new URL('../web/generated/simplicity_core.wasm', import.meta.url)));
  const { exports: core } = await WebAssembly.instantiate(module);
  const encoder = new TextEncoder();
  const start = core.memory.buffer.byteLength - 4096;
  let cursor = start;
  const writeString = (value) => {
    const bytes = encoder.encode(value);
    const offset = cursor;
    new Uint8Array(core.memory.buffer, offset, bytes.length).set(bytes);
    cursor += bytes.length;
    return { offset, length: bytes.length };
  };
  const id = writeString('flag\0item');
  const label = writeString('Flag');
  const group = writeString('');
  cursor = (cursor + 3) & ~3;
  const item = cursor;
  cursor += 36;
  const error = cursor;
  const enabled = cursor + 4;
  const checked = cursor + 5;
  const view = new DataView(core.memory.buffer);
  view.setUint32(item, id.offset, true);
  view.setUint32(item + 4, id.length, true);
  view.setUint32(item + 8, label.offset, true);
  view.setUint32(item + 12, label.length, true);
  view.setUint32(item + 16, 1, true);
  view.setUint8(item + 20, 1);
  view.setUint8(item + 21, 0);
  view.setUint32(item + 24, group.offset, true);
  view.setUint32(item + 28, group.length, true);
  view.setInt32(item + 32, -1, true);

  const menu = core.simplicity_menu_create(item, 1, error);
  assert.notEqual(menu, 0);
  assert.equal(new DataView(core.memory.buffer).getInt32(error, true), 0);
  assert.equal(core.simplicity_menu_activate(menu, id.offset, id.length), 1);
  assert.equal(core.simplicity_menu_get_state(
    menu, id.offset, id.length, enabled, checked), 1);
  let state = new Uint8Array(core.memory.buffer);
  assert.equal(state[enabled], 1);
  assert.equal(state[checked], 1);
  assert.equal(core.simplicity_menu_set_enabled(
    menu, id.offset, id.length, 0), 1);
  assert.equal(core.simplicity_menu_activate(menu, id.offset, id.length), 0);
  assert.equal(core.simplicity_menu_get_state(
    menu, id.offset, id.length, enabled, checked), 1);
  state = new Uint8Array(core.memory.buffer);
  assert.equal(state[enabled], 0);
  assert.equal(state[checked], 1);
  core.simplicity_menu_destroy(menu);
});
