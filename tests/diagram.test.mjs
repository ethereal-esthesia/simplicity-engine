import assert from 'node:assert/strict';
import test from 'node:test';
import { createDiagramViewer } from '../web/diagram-viewer.mjs';

function fixture(render = async source => `<svg>${source}</svg>`, save = async () => {}) {
  const classes = new Set();
  const root = { setAttribute() {}, classList: {
    toggle(name, enabled) { if (enabled) classes.add(name); else classes.delete(name); },
    contains: name => classes.has(name),
    add: name => classes.add(name),
    remove: name => classes.delete(name),
  } };
  const listeners = {};
  const diagram = {
    setAttribute() {},
    focus() {},
    addEventListener(name, callback) { listeners[name] = callback; },
  };
  const editor = { setAttribute() {}, focus() {} };
  const error = {};
  const viewer = createDiagramViewer({ root, diagram, editor, error, render, save });
  return { viewer, diagram, editor, error, listeners };
}

test('opens a blank source editor and saves before displaying a valid diagram', async () => {
  const saved = [];
  const app = fixture(undefined, async source => { saved.push(source); });
  await app.viewer.load('%% Enter a diagram\n');
  assert.equal(app.viewer.isEditing(), true);
  app.editor.value = 'flowchart TD\n  A --> B';
  await app.viewer.saveAndShow();
  assert.deepEqual(saved, ['flowchart TD\n  A --> B']);
  assert.match(app.diagram.innerHTML, /flowchart TD/);
  assert.equal(app.viewer.isEditing(), false);
  app.listeners.click();
  assert.equal(app.viewer.isEditing(), true);
});

test('keeps invalid or unsaved source open and reports the error', async () => {
  let saves = 0;
  const app = fixture(async () => { throw new Error('invalid syntax'); }, async () => { saves++; });
  await app.viewer.load('bad source');
  assert.equal(app.viewer.isEditing(), true);
  assert.match(app.error.textContent, /invalid syntax/);
  await app.viewer.saveAndShow();
  assert.equal(saves, 0);
  assert.equal(app.viewer.isEditing(), true);

  const unsaved = fixture(async () => '<svg></svg>', async () => { throw new Error('read only'); });
  await unsaved.viewer.load('%% blank');
  unsaved.editor.value = 'flowchart TD\n  A --> B';
  await unsaved.viewer.saveAndShow();
  assert.equal(unsaved.viewer.isEditing(), true);
  assert.match(unsaved.error.textContent, /read only/);
});

test('prevents edits while a source snapshot is being saved', async () => {
  let finishSave;
  const app = fixture(undefined, () => new Promise(resolve => { finishSave = resolve; }));
  await app.viewer.load('%% blank');
  app.editor.value = 'flowchart TD\n  A --> B';
  const saving = app.viewer.saveAndShow();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.editor.readOnly, true);
  finishSave();
  await saving;
  assert.equal(app.editor.readOnly, false);
  assert.equal(app.viewer.isEditing(), false);
});
