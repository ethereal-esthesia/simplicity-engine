import { easeProgress, edgeDeltas, interpolateEdges, targetEdges } from './expansion.mjs';

const status = document.querySelector('#status');
const expandButton = document.querySelector('#floating-expand');
const expansion = document.querySelector('#expanding-window');
const expandedArtwork = document.querySelector('#expanded-artwork');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const expansionDuration = reducedMotion.matches ? 1 : 1500;
let animation = null;

const readEdges = element => {
  const { left, top, right, bottom } = element.getBoundingClientRect();
  return { left, top, right, bottom };
};

const applyEdges = (element, edges) => {
  element.style.left = `${edges.left}px`;
  element.style.top = `${edges.top}px`;
  element.style.width = `${edges.right - edges.left}px`;
  element.style.height = `${edges.bottom - edges.top}px`;
};

function animateExpansion(now) {
  if (!animation) return;
  const progress = Math.min(1, (now - animation.startedAt) / animation.duration);
  const eased = easeProgress(progress);
  applyEdges(expansion, interpolateEdges(animation.start, animation.deltas, progress));
  expansion.style.borderRadius =
    `${animation.startRadius + (animation.endRadius - animation.startRadius) * eased}px`;

  if (progress < 1) {
    requestAnimationFrame(animateExpansion);
    return;
  }

  applyEdges(expansion, animation.target);
  expansion.style.borderRadius = `${animation.endRadius}px`;
  animation = null;
  expansion.setAttribute('aria-hidden', 'false');
  expansion.focus({ preventScroll: true });
  expandButton.classList.add('is-fading');
  expandedArtwork.classList.add('is-visible');
  window.setTimeout(() => { expandButton.hidden = true; }, reducedMotion.matches ? 1 : 450);
}

expandButton.addEventListener('click', () => {
  if (animation || expandButton.disabled) return;

  expandButton.disabled = true;
  expandButton.setAttribute('aria-expanded', 'true');
  expansion.hidden = false;
  const start = readEdges(expandButton);
  const target = targetEdges(innerWidth, innerHeight);
  applyEdges(expansion, start);
  animation = {
    start,
    target,
    deltas: edgeDeltas(start, target),
    startedAt: performance.now(),
    duration: expansionDuration,
    startRadius: Math.min(start.right - start.left, start.bottom - start.top) / 2,
    endRadius: 18,
  };
  requestAnimationFrame(animateExpansion);
});

addEventListener('resize', () => {
  if (!animation) return;
  const now = performance.now();
  const elapsed = now - animation.startedAt;
  const start = readEdges(expansion);
  const target = targetEdges(innerWidth, innerHeight);
  animation = {
    ...animation,
    start,
    target,
    deltas: edgeDeltas(start, target),
    startedAt: now,
    duration: Math.max(120, animation.duration - elapsed),
    startRadius: Number.parseFloat(getComputedStyle(expansion).borderRadius),
  };
});

try {
  const response = await fetch('./generated/simplicity_core.wasm');
  if (!response.ok) throw new Error(`Engine download failed (${response.status})`);
  const { instance } = await WebAssembly.instantiate(await response.arrayBuffer());
  const core = instance.exports;
  if (core.abi_version() !== 1) throw new Error('Unsupported engine interface');
  const canvas = document.querySelector('canvas');
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Canvas rendering is unavailable');
  const color = value => `#${value.toString(16).padStart(6, '0')}`;
  const draw = () => {
    canvas.width = Math.max(1, Math.round(innerWidth * devicePixelRatio));
    canvas.height = Math.max(1, Math.round(innerHeight * devicePixelRatio));
    context.fillStyle = color(core.background_rgb());
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.fillStyle = color(core.mark_rgb());
    context.fillRect(core.mark_origin(canvas.width), core.mark_origin(canvas.height),
      core.mark_size(), core.mark_size());
  };
  addEventListener('resize', draw);
  draw();
  status.hidden = true;
  document.documentElement.dataset.engine = 'ready';
} catch (error) {
  status.textContent = `Unable to start the engine: ${error.message}`;
  console.error(error);
}
