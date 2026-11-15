import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';
import { setupWindowInteractions } from '../web/window-interactions.mjs';

const source = (await readFile(new URL('../web/main.js', import.meta.url), 'utf8'))
  .replace("import { setupWindowInteractions } from './window-interactions.mjs';", '')
  .replace("import { createDiagramViewer } from './diagram-viewer.mjs';", '')
  .replace("import { renderMermaid } from './generated/mermaid-renderer.mjs';", '');

async function windowApp(invoke) {
  const listeners = {};
  const attributes = {};
  const eventTarget = { addEventListener(name, callback) { listeners[`window:${name}`] = callback; } };
  const button = {
    dataset: {},
    ownerDocument: { defaultView: eventTarget },
    classList: { add() {}, remove() {}, toggle() {} },
    setAttribute(name, value) { attributes[name] = value; },
    addEventListener(name, callback) { listeners[name] = callback; },
  };
  const status = {};
  const artwork = { classList: { add() {}, remove() {} } };
  const elements = { '#status': status, '#floating-expand': button, '#expanded-artwork': artwork };
  const context = {
    document: {
      querySelector: selector => elements[selector],
      addEventListener(name, callback) { listeners[name] = callback; },
    },
    window: { __TAURI__: { core: { invoke } } },
    setupWindowInteractions,
    createDiagramViewer: () => ({
      load: async () => {},
      reveal() {},
      hide() {},
      isEditing: () => false,
    }),
    renderMermaid() {},
    matchMedia: () => ({ matches: false }),
    addEventListener(name, callback) { listeners[name] = callback; },
    requestAnimationFrame: callback => queueMicrotask(callback),
    performance: { now: () => 1000 },
    console: { error() {} },
  };
  vm.runInNewContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  return { button, status, attributes, listeners };
}

test('prepares the selected corner before expanding and collapses on Escape', async () => {
  const commands = [];
  const app = await windowApp(async command => {
    commands.push(command);
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-left';
  });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.button.dataset.corner, 'top-left');
  assert.equal(app.attributes['aria-expanded'], 'true');
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.attributes['aria-expanded'], 'false');
  assert.deepEqual(commands, [
    'is_desktop', 'load_diagram_source', 'prepare_window_expansion', 'expand_window', 'shrink_window',
  ]);
});

test('cancels a prepared expansion if the animation command fails', async () => {
  const commands = [];
  const app = await windowApp(async command => {
    commands.push(command);
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'bottom-right';
    if (command === 'expand_window') throw new Error('animation failed');
  });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(app.button.disabled, false);
  assert.match(app.status.textContent, /animation failed/);
  assert.deepEqual(commands, [
    'is_desktop', 'load_diagram_source', 'prepare_window_expansion', 'expand_window', 'cancel_window_expansion',
  ]);
});

function interactionApp(showDragCursor = false) {
  const buttonListeners = {};
  const windowListeners = {};
  const classes = new Set();
  const actions = { activations: 0, drags: 0, errors: [] };
  const element = {
    ownerDocument: { defaultView: {
      addEventListener(name, listener) { windowListeners[name] = listener; },
    } },
    classList: { toggle(name, enabled) { if (enabled) classes.add(name); else classes.delete(name); } },
    addEventListener(name, listener) { buttonListeners[name] = listener; },
  };
  setupWindowInteractions({
    element,
    showDragCursor,
    startDragging: async () => { actions.drags++; },
    onActivate: () => { actions.activations++; },
    onError: error => { actions.errors.push(error); },
  });
  const pointer = (x, y) => ({ pointerId: 1, button: 0, screenX: x, screenY: y });
  return { buttonListeners, windowListeners, classes, actions, pointer };
}

test('only activates a pointer click released within the movement tolerance', () => {
  const app = interactionApp();
  assert.equal(app.classes.has('show-drag-cursor'), false);
  app.buttonListeners.pointerdown(app.pointer(10, 10));
  app.windowListeners.pointerup(app.pointer(13, 12));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.activations, 1);
  assert.equal(app.actions.drags, 0);

  app.buttonListeners.pointerdown(app.pointer(10, 10));
  app.windowListeners.pointerup(app.pointer(15, 10));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.activations, 1);
});

test('a drag suppresses its click until a new gesture, but not keyboard activation', () => {
  const app = interactionApp(true);
  assert.equal(app.classes.has('show-drag-cursor'), true);
  app.buttonListeners.pointerdown(app.pointer(10, 10));
  app.windowListeners.pointermove(app.pointer(15, 10));
  app.windowListeners.pointerup(app.pointer(10, 10));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.drags, 1);
  assert.equal(app.actions.activations, 0);

  app.buttonListeners.click({ detail: 0 });
  app.buttonListeners.pointerdown(app.pointer(30, 10));
  app.windowListeners.pointerup(app.pointer(30, 10));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.activations, 2);
});

test('a native drag without a pointerup cannot cause a subsequent pointer click', () => {
  const app = interactionApp();
  app.buttonListeners.pointerdown(app.pointer(10, 10));
  app.windowListeners.pointermove(app.pointer(20, 10));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.activations, 0);

  app.buttonListeners.pointerdown(app.pointer(20, 10));
  app.windowListeners.pointerup(app.pointer(20, 10));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.activations, 1);
});

test('a cancelled pointer gesture cannot activate the window', () => {
  const app = interactionApp();
  app.buttonListeners.pointerdown(app.pointer(10, 10));
  app.windowListeners.pointercancel(app.pointer(10, 10));
  app.buttonListeners.click({ detail: 1 });
  assert.equal(app.actions.activations, 0);
});
