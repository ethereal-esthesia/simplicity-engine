import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';
import { setupWindowInteractions } from '../web/window-interactions.mjs';

const source = (await readFile(new URL('../web/main.js', import.meta.url), 'utf8'))
  .replace("import { setupWindowInteractions } from './window-interactions.mjs';", '')
  .replace("import { createDiagramViewer } from './diagram-viewer.mjs';", '')
  .replace("import { renderMermaid } from './generated/mermaid-renderer.mjs';", '');

async function windowApp(invoke, {
  diagram, imageDecode, whenIdle = async () => {}, onFrame = () => {}, frameLimit = 4,
  pngData = () => 'data:image/png;base64,c25hcHNob3Q=',
} = {}) {
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
  const surface = {
    addEventListener(name, callback) { listeners[`surface:${name}`] = callback; },
  };
  const elements = {
    '#status': status, '#floating-expand': button, '#expanded-artwork': artwork,
    '#window-surface': surface, '#diagram': diagram, '#diagram-view': {},
  };
  let animationFrames = 0;
  let pendingFrame;
  const canvases = [];
  const context = {
    document: {
      querySelector: selector => elements[selector],
      addEventListener(name, callback) { listeners[name] = callback; },
      createElement: () => {
        const canvas = {
          style: {},
          getContext: () => ({ drawImage() {} }),
          toDataURL: pngData,
          remove() {},
        };
        canvases.push(canvas);
        return canvas;
      },
    },
    window: { __TAURI__: { core: { invoke } }, screenX: 10, screenY: 20 },
    setupWindowInteractions,
    createDiagramViewer: () => ({
      load: async () => {},
      reveal() {},
      hide() {},
      isEditing: () => false,
      whenIdle,
    }),
    renderMermaid() {},
    matchMedia: () => ({ matches: false }),
    addEventListener(name, callback) { listeners[name] = callback; },
    requestAnimationFrame: callback => {
      animationFrames++;
      if (animationFrames <= frameLimit) queueMicrotask(() => { onFrame(); callback(); });
      else pendingFrame = callback;
      return animationFrames;
    },
    cancelAnimationFrame() {},
    setTimeout,
    clearTimeout,
    innerWidth: 1000,
    innerHeight: 800,
    devicePixelRatio: 1,
    Image: class { decode() { return imageDecode ? imageDecode() : Promise.reject(new Error('decode unavailable')); } },
    XMLSerializer: class { serializeToString() { return '<svg/>'; } },
    performance: { now: () => 1000, timeOrigin: 10000 },
    console: { error() {} },
  };
  vm.runInNewContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  return {
    button, status, attributes, listeners, context, canvases,
    runFrame() {
      const callback = pendingFrame;
      pendingFrame = undefined;
      callback();
    },
  };
}

test('bitmap scale and position follow the current viewport during shrink', async () => {
  let finishShrink;
  let styleAttribute = 'max-width: 1512px;';
  const svg = {
    style: {
      get cssText() { return styleAttribute; },
      set cssText(value) { styleAttribute = value; },
    },
    getBoundingClientRect: () => ({ width: 1512, height: 932 }),
    getAttribute: () => styleAttribute,
    setAttribute: (name, value) => { if (name === 'style') styleAttribute = value; },
    removeAttribute: () => {},
    cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
  };
  const app = await windowApp(async command => {
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-right';
    if (command === 'shrink_window') return new Promise(resolve => { finishShrink = resolve; });
  }, {
    diagram: { querySelector: () => svg, append() {} },
    imageDecode: async () => {},
  });
  app.context.innerWidth = 1812;
  app.context.innerHeight = 972;
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.ok(finishShrink);
  app.context.innerWidth = 1014;
  app.context.innerHeight = 563;
  app.runFrame();
  const scale = 1014 / 1812;
  const x = (1014 - 1512 * scale) / 2;
  const y = (563 - 932 * scale) / 2;
  assert.equal(app.canvases[0].style.transform, `translate(${x}px, ${y}px) scale(${scale})`);
  assert.ok(x > 0);
  app.context.innerWidth = 162;
  app.context.innerHeight = 126;
  app.runFrame();
  const smallScale = 162 / 1812;
  const smallX = (162 - 1512 * smallScale) / 2;
  const smallY = (126 - 932 * smallScale) / 2;
  assert.equal(app.canvases[3].style.transform, `translate(${smallX}px, ${smallY}px) scale(${smallScale})`);
  assert.ok(smallX > 0);
  finishShrink();
  await new Promise(resolve => setImmediate(resolve));
});

test('shrink restores the SVG inline styles after success or failure', async () => {
  for (const originalStyle of ['max-width: 168px; color: red;', null]) {
    for (const failure of [false, true]) {
      let styleAttribute = originalStyle;
      const style = {
        get cssText() { return styleAttribute ?? ''; },
        set cssText(value) { styleAttribute = value; },
      };
      const svg = {
        style,
        getBoundingClientRect: () => ({ width: 168, height: 200 }),
        getAttribute: () => styleAttribute,
        setAttribute: (name, value) => { if (name === 'style') styleAttribute = value; },
        removeAttribute: name => { if (name === 'style') styleAttribute = null; },
        cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
      };
      const commands = [];
      const app = await windowApp(async command => {
        commands.push(command);
        if (command === 'is_desktop') return true;
        if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
        if (command === 'prepare_window_expansion') return 'top-left';
        if (command === 'shrink_window' && failure) throw new Error('shrink failed');
      }, { diagram: { querySelector: () => svg } });
      app.listeners.click({ detail: 0 });
      await new Promise(resolve => setImmediate(resolve));
      app.listeners.keydown({ key: 'Escape', preventDefault() {} });
      await new Promise(resolve => setImmediate(resolve));
      assert.equal(commands.at(-1), 'shrink_window');
      assert.equal(styleAttribute, originalStyle);
      if (failure) assert.match(app.status.textContent, /shrink failed/);
    }
  }
});

test('waits for edits and a painted bitmap before shrinking the window', async () => {
  let finishEdit;
  let finishDecode;
  const idle = new Promise(resolve => { finishEdit = resolve; });
  const decoded = new Promise(resolve => { finishDecode = resolve; });
  const events = [];
  let styleAttribute = 'max-width: 168px;';
  const svg = {
    style: {
      get cssText() { return styleAttribute; },
      set cssText(value) { styleAttribute = value; },
    },
    getBoundingClientRect: () => ({ width: 168, height: 200 }),
    getAttribute: () => styleAttribute,
    setAttribute: (name, value) => { if (name === 'style') styleAttribute = value; },
    removeAttribute: () => {},
    cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
  };
  const app = await windowApp(async command => {
    events.push(command);
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-left';
    if (command === 'shrink_window') assert.equal(svg.style.visibility, 'hidden');
  }, {
    diagram: { querySelector: () => svg, append: () => events.push('bitmap') },
    whenIdle: () => idle,
    imageDecode: () => { events.push('decode'); return decoded; },
    onFrame: () => events.push('frame'),
  });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  events.length = 0;
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(events, []);
  finishEdit();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(events, ['decode']);
  finishDecode();
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(events, ['decode', 'bitmap', 'frame', 'frame', 'shrink_window']);
  assert.equal(styleAttribute, 'max-width: 168px;');
});

test('does not stall shrinking if animation frames are suspended', async () => {
  let styleAttribute = 'max-width: 168px;';
  const svg = {
    style: {
      get cssText() { return styleAttribute; },
      set cssText(value) { styleAttribute = value; },
    },
    getBoundingClientRect: () => ({ width: 168, height: 200 }),
    getAttribute: () => styleAttribute,
    setAttribute: (name, value) => { if (name === 'style') styleAttribute = value; },
    removeAttribute: () => {},
    cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
  };
  const commands = [];
  const app = await windowApp(async command => {
    commands.push(command);
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-left';
  }, { diagram: { querySelector: () => svg }, frameLimit: 2 });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setTimeout(resolve, 150));
  assert.equal(commands.at(-1), 'shrink_window');
  assert.equal(styleAttribute, 'max-width: 168px;');
});

test('buffers bitmap geometry and reports it after a debug shrink', async () => {
  let styleAttribute = 'max-width: 168px;';
  const svg = {
    style: {
      get cssText() { return styleAttribute; },
      set cssText(value) { styleAttribute = value; },
    },
    getBoundingClientRect: () => ({ width: 168, height: 200 }),
    getAttribute: () => styleAttribute,
    setAttribute: (name, value) => { if (name === 'style') styleAttribute = value; },
    removeAttribute: () => {},
    cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
  };
  const commands = [];
  let report;
  const app = await windowApp(async (command, args) => {
    commands.push(command);
    if (command === 'is_desktop' || command === 'shrink_debug_enabled') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-left';
    if (command === 'report_shrink_debug') report = JSON.parse(args.trace);
  }, {
    diagram: { querySelector: () => svg, append() {} },
    imageDecode: async () => {},
  });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.ok(commands.indexOf('shrink_window') < commands.indexOf('report_shrink_debug'));
  assert.deepEqual(report.samples[0], [11000, 1000, 800, 10, 20, 416, 300, 1, 0]);
  assert.equal(report.start.bitmap_width, 168);
  assert.equal(report.dropped, 0);
});

test('passes the bitmap to native scaling without updating its transform per frame', async () => {
  let finishShrink;
  let args;
  let styleAttribute = 'max-width: 168px;';
  const svg = {
    style: {
      get cssText() { return styleAttribute; },
      set cssText(value) { styleAttribute = value; },
    },
    getBoundingClientRect: () => ({ width: 168, height: 200 }),
    getAttribute: () => styleAttribute,
    setAttribute: (name, value) => { if (name === 'style') styleAttribute = value; },
    removeAttribute: () => {},
    cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
  };
  const app = await windowApp(async (command, input) => {
    if (command === 'is_desktop' || command === 'native_shrink_scaling') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-right';
    if (command === 'shrink_window') {
      args = input;
      return new Promise(resolve => { finishShrink = resolve; });
    }
  }, {
    diagram: { querySelector: () => svg, append() {} },
    imageDecode: async () => {},
  });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(args.snapshotPng, 'c25hcHNob3Q=');
  assert.equal(args.bitmapWidth, 168);
  assert.equal(args.bitmapHeight, 200);
  assert.equal(app.canvases[0].style.transform, 'translate(416px, 300px) scale(1)');
  app.context.innerWidth = 500;
  assert.equal(app.canvases[0].style.transform, 'translate(416px, 300px) scale(1)');
  finishShrink();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(styleAttribute, 'max-width: 168px;');
});

test('uses web scaling when the native bitmap cannot be serialized', async () => {
  let finishShrink;
  let args;
  const svg = {
    style: { cssText: 'max-width: 168px;' },
    getBoundingClientRect: () => ({ width: 168, height: 200 }),
    getAttribute: () => 'max-width: 168px;',
    setAttribute() {},
    removeAttribute() {},
    cloneNode: () => ({ setAttribute() {}, removeAttribute() {} }),
  };
  const app = await windowApp(async (command, input) => {
    if (command === 'is_desktop' || command === 'native_shrink_scaling') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'top-right';
    if (command === 'shrink_window') {
      args = input;
      return new Promise(resolve => { finishShrink = resolve; });
    }
  }, {
    diagram: { querySelector: () => svg, append() {} },
    imageDecode: async () => {},
    pngData: () => { throw new Error('Cannot serialize canvas'); },
  });
  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  app.listeners.keydown({ key: 'Escape', preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(args.snapshotPng, null);
  app.context.innerWidth = 500;
  app.context.innerHeight = 400;
  app.runFrame();
  assert.equal(app.canvases[1].style.transform, 'translate(208px, 150px) scale(0.5)');
  finishShrink();
  await new Promise(resolve => setImmediate(resolve));
});

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
    'is_desktop', 'load_diagram_source', 'shrink_debug_enabled', 'native_shrink_scaling',
    'prepare_window_expansion', 'expand_window', 'shrink_window',
  ]);
});

test('right-click opens the compact menu without replacing the expanded context menu', async () => {
  const commands = [];
  const app = await windowApp(async (command, args) => {
    commands.push({ command, args });
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'prepare_window_expansion') return 'bottom-right';
  });
  let prevented = false;
  app.listeners['surface:contextmenu']({
    clientX: 45, clientY: 23, preventDefault() { prevented = true; },
  });
  assert.equal(prevented, true);
  assert.equal(commands.at(-1).command, 'show_compact_menu');
  assert.equal(commands.at(-1).args.x, 45);
  assert.equal(commands.at(-1).args.y, 23);

  app.listeners.click({ detail: 0 });
  await new Promise(resolve => setImmediate(resolve));
  prevented = false;
  const count = commands.length;
  app.listeners['surface:contextmenu']({
    clientX: 20, clientY: 20, preventDefault() { prevented = true; },
  });
  assert.equal(prevented, false);
  assert.equal(commands.length, count);
});

test('context menu errors are shown to the user', async () => {
  const app = await windowApp(async command => {
    if (command === 'is_desktop') return true;
    if (command === 'load_diagram_source') return 'flowchart TD\n  A --> B';
    if (command === 'show_compact_menu') throw new Error('menu unavailable');
  });
  app.listeners['surface:contextmenu']({ clientX: 0, clientY: 0, preventDefault() {} });
  await new Promise(resolve => setImmediate(resolve));
  assert.match(app.status.textContent, /menu unavailable/);
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
    'is_desktop', 'load_diagram_source', 'shrink_debug_enabled', 'native_shrink_scaling',
    'prepare_window_expansion', 'expand_window', 'cancel_window_expansion',
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
