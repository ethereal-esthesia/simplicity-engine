import { setupWindowInteractions } from './window-interactions.mjs';
import { createDiagramViewer } from './diagram-viewer.mjs';
import { renderMermaid } from './generated/mermaid-renderer.mjs';

const status = document.querySelector('#status');
const windowSurface = document.querySelector('#window-surface');
const expandButton = document.querySelector('#floating-expand');
const expandedArtwork = document.querySelector('#expanded-artwork');
const diagramRoot = document.querySelector('#diagram-view');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const invoke = window.__TAURI__?.core?.invoke;
let isDesktop = false;
let isExpanded = false;
let isExpanding = false;
let isShrinking = false;
let shrinkRequested = false;
let diagramViewer = null;
let diagramReady = Promise.resolve();
let diagramLoadError = null;

function showError(error) {
  status.textContent = `Unable to control the window: ${error.message ?? String(error)}`;
  status.hidden = false;
  console.error(error);
}

async function expandWindow() {
  if (!isDesktop || isExpanded || isExpanding || isShrinking) return;

  isExpanding = true;
  expandButton.disabled = true;
  let prepared = false;
  try {
    await diagramReady;
    if (diagramLoadError) throw diagramLoadError;
    const corner = await invoke('prepare_window_expansion');
    prepared = true;
    expandButton.dataset.corner = corner;
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    await invoke('expand_window', { reducedMotion: reducedMotion.matches });
    isExpanded = true;
    expandButton.setAttribute('aria-expanded', 'true');
    expandButton.classList.add('is-fading');
    diagramViewer.reveal();
  } catch (error) {
    expandButton.disabled = false;
    shrinkRequested = false;
    if (prepared) {
      try {
        await invoke('cancel_window_expansion');
      } catch (cleanupError) {
        showError(new Error(`${error.message ?? String(error)}; cleanup failed: ${cleanupError.message ?? String(cleanupError)}`));
        return;
      }
    }
    showError(error);
  } finally {
    isExpanding = false;
    if (shrinkRequested && isExpanded) {
      shrinkRequested = false;
      shrinkWindow();
    }
  }
}

async function shrinkWindow() {
  if (!isDesktop) return;
  if (isExpanding) {
    shrinkRequested = true;
    return;
  }
  if (!isExpanded || isShrinking) return;

  isShrinking = true;
  const stopScaling = scaleDiagramWithWindow();
  try {
    await invoke('shrink_window', { reducedMotion: reducedMotion.matches });
    isExpanded = false;
    expandButton.setAttribute('aria-expanded', 'false');
    expandButton.disabled = false;
    expandButton.classList.remove('is-fading');
    diagramViewer.hide();
  } catch (error) {
    showError(error);
  } finally {
    stopScaling();
    isShrinking = false;
  }
}

const COMPACT_SIZE = 88;
const SHRINK_MS = 1500;

// Rasterize the SVG once into a bitmap, then scale that texture each frame to match the window's animated size.
function scaleDiagramWithWindow() {
  const container = document.querySelector('#diagram');
  const svg = container?.querySelector?.('svg');
  if (!svg || diagramViewer.isEditing()) return () => {};
  const { width, height } = svg.getBoundingClientRect();
  const startW = innerWidth;
  const startH = innerHeight;
  if (!width || !height || !startW || !startH) return () => {};
  const layerStyle = `max-width:none;max-height:none;width:${width}px;height:${height}px;position:absolute;left:0;top:0;transform-origin:0 0;will-change:transform;`;
  svg.style.cssText += `;${layerStyle}`;
  let layer = svg;
  let canvas = null;
  let cancelled = false;

  const clone = svg.cloneNode(true);
  clone.setAttribute('width', width);
  clone.setAttribute('height', height);
  clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
  clone.removeAttribute('style');
  const image = new Image();
  image.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(new XMLSerializer().serializeToString(clone))}`;
  image.decode().then(() => {
    if (cancelled) return;
    const ratio = devicePixelRatio || 1;
    canvas = document.createElement('canvas');
    canvas.width = Math.ceil(width * ratio);
    canvas.height = Math.ceil(height * ratio);
    canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
    canvas.style.cssText = layerStyle;
    canvas.style.transform = svg.style.transform;
    container.append(canvas);
    svg.style.visibility = 'hidden';
    layer = canvas;
  }).catch(() => {});

  const started = performance.now();
  // The webview reports its size late, so derive the window size from the native animation's smoothstep timing instead.
  const update = () => {
    const t = reducedMotion.matches ? 1 : Math.min((performance.now() - started) / SHRINK_MS, 1);
    const eased = t * t * (3 - 2 * t);
    const w = startW + (COMPACT_SIZE - startW) * eased;
    const h = startH + (COMPACT_SIZE - startH) * eased;
    const scale = Math.max(0, Math.min(w / startW, h / startH, 1));
    const x = (w - width * scale) / 2;
    const y = (h - height * scale) / 2;
    layer.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
  };
  let frame = 0;
  const tick = () => {
    update();
    frame = requestAnimationFrame(tick);
  };
  tick();
  return () => {
    cancelled = true;
    cancelAnimationFrame(frame);
    canvas?.remove();
    for (const property of ['max-width', 'max-height', 'width', 'height', 'position', 'left', 'top', 'transform-origin', 'will-change', 'transform', 'visibility']) {
      svg.style.removeProperty(property);
    }
  };
}

function requestShrink() {
  if (isExpanded || isExpanding) shrinkWindow();
}

if (!invoke) {
  showError(new Error('Tauri command interface is unavailable'));
} else {
  invoke('is_desktop').then(desktop => {
    isDesktop = desktop;
    if (isDesktop) {
      diagramViewer = createDiagramViewer({
        root: diagramRoot,
        diagram: document.querySelector('#diagram'),
        editor: document.querySelector('#diagram-source'),
        error: document.querySelector('#diagram-error'),
        render: renderMermaid,
        save: source => invoke('save_diagram_source', { source }),
      });
      diagramReady = invoke('load_diagram_source')
        .then(source => diagramViewer.load(source))
        .catch(error => {
          diagramLoadError = error;
          showError(error);
        });
      expandButton.hidden = false;
      return;
    }

    expandedArtwork.classList.add('is-visible');
  }).catch(error => {
    showError(error);
  });
}

setupWindowInteractions({
  element: expandButton,
  startDragging: () => invoke('start_window_dragging'),
  onActivate: expandWindow,
  onError: showError,
});

windowSurface.addEventListener('contextmenu', event => {
  if (!isDesktop || isExpanded || isExpanding || isShrinking) return;
  event.preventDefault();
  invoke('show_compact_menu', { x: event.clientX, y: event.clientY }).catch(showError);
});

addEventListener('blur', requestShrink);
document.addEventListener('keydown', event => {
  if (event.key !== 'Escape' || !isDesktop || (!isExpanded && !isExpanding)) return;
  event.preventDefault();
  if (isExpanded && diagramViewer.isEditing()) {
    diagramViewer.saveAndShow();
    return;
  }
  requestShrink();
});
