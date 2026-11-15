import assert from 'node:assert/strict';
import { mkdtemp, readFile, rmdir, unlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { prepareDiagramFile } from '../scripts/diagram-prepare.mjs';

test('asks before creating a missing file and leaves existing files alone', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'simplicity-prepare-'));
  const path = join(directory, 'diagram.mmd');
  t.after(async () => {
    await unlink(path);
    await rmdir(directory);
  });
  await assert.rejects(prepareDiagramFile(path, async () => false), /cancelled/);
  await assert.rejects(readFile(path), { code: 'ENOENT' });
  await prepareDiagramFile(path, async requested => requested === path);
  const content = await readFile(path, 'utf8');
  assert.match(content, /^%% Enter a Mermaid diagram/);
  await prepareDiagramFile(path, async () => { throw new Error('unexpected prompt'); });
  assert.equal(await readFile(path, 'utf8'), content);
});
