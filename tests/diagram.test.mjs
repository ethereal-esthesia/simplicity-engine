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
    contains: () => true,
    ownerDocument: { createElement: () => ({
      set innerHTML(value) { this.svg = value; },
      querySelectorAll: () => [node('A', true)],
    }) },
    addEventListener(name, callback) { listeners[name] = callback; },
  };
  const editor = { setAttribute() {}, focus() {} };
  const error = {};
  const viewer = createDiagramViewer({ root, diagram, editor, error, render, save });
  return { viewer, diagram, editor, error, listeners };
}

function node(id, disabled) {
  return {
    getAttribute: () => `simplicity-diagram-1-flowchart-${id}-0`,
    classList: { contains: name => name === 'disabled' && disabled },
  };
}

function clickNode(app, id, disabled) {
  return app.listeners.click({ target: { closest: () => node(id, disabled) } });
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

test('clicking a flowchart node saves its disabled class and clicking again removes it', async () => {
  const saved = [];
  const app = fixture(async source => source, async source => saved.push(source));
  app.diagram.ownerDocument.createElement = () => ({
    set innerHTML(value) { this.source = value; },
    querySelectorAll() { return [node('A', /class A disabled/.test(this.source))]; },
  });
  await app.viewer.load('flowchart TD\n  A[Start] --> B[Finish]\n');
  await clickNode(app, 'A', false);
  assert.match(saved[0], /classDef disabled fill:#e0e0e0,stroke:#cccccc,color:#888888;/);
  assert.match(saved[0], /class A disabled;/);
  assert.equal(app.viewer.isEditing(), false);
  await clickNode(app, 'A', true);
  assert.doesNotMatch(saved[1], /class A disabled/);
  assert.doesNotMatch(saved[1], /^\s*;\s*$/m);
  assert.match(saved[1], /A\[Start\] --> B\[Finish\]/);
});

test('enabling preserves other nodes, labels and an existing disabled style', async () => {
  const saved = [];
  const app = fixture(async source => source, async source => saved.push(source));
  app.diagram.ownerDocument.createElement = () => ({
    set innerHTML(value) { this.source = value; },
    querySelectorAll() { return [node('A', false)]; },
  });
  const source = 'flowchart TD\n  A["class A disabled"]:::disabled --> B\n  class A,B disabled;\n  classDef disabled fill:red;\n';
  await app.viewer.load(source);
  await clickNode(app, 'A', true);
  assert.equal(saved[0], 'flowchart TD\n  A["class A disabled"] --> B\n  class B disabled;\n  classDef disabled fill:red;\n');
});

test('failed toggle leaves the source and displayed diagram unchanged', async () => {
  const app = fixture(undefined, async () => { throw new Error('read only'); });
  const source = 'flowchart TD\n  A --> B';
  await app.viewer.load(source);
  const originalSvg = app.diagram.innerHTML;
  await clickNode(app, 'A', false);
  assert.equal(app.editor.value, source);
  assert.equal(app.diagram.innerHTML, originalSvg);
  assert.match(app.error.textContent, /read only/);
});

test('reuses an existing style and ignores repeated clicks during a save', async () => {
  let finishSave;
  const saved = [];
  const app = fixture(async source => source, source => {
    saved.push(source);
    return new Promise(resolve => { finishSave = resolve; });
  });
  const source = 'flowchart TD\r\nA --> B\r\nclassDef disabled fill:red;\r\n';
  await app.viewer.load(source);
  const saving = clickNode(app, 'A', false);
  await new Promise(resolve => setImmediate(resolve));
  await clickNode(app, 'A', false);
  assert.equal(saved.length, 1);
  assert.equal(saved[0], `${source}class A disabled;\r\n`);
  finishSave();
  await saving;
});

test('does not save when the rendered node still has the old class', async () => {
  const saved = [];
  const app = fixture(undefined, async source => saved.push(source));
  await app.viewer.load('flowchart TD\n  A:::disabled --> B');
  await clickNode(app, 'A', true);
  assert.equal(saved.length, 0);
  assert.match(app.error.textContent, /Cannot safely toggle A/);
});
