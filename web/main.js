const status = document.querySelector('#status');
const expandButton = document.querySelector('#floating-expand');
const expandedArtwork = document.querySelector('#expanded-artwork');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const invoke = window.__TAURI__?.core?.invoke;
let dragStart = null;
let suppressClickUntil = 0;
let isDesktop = false;
let isExpanded = false;
let isExpanding = false;
let isShrinking = false;
let shrinkRequested = false;

function showError(error) {
  status.textContent = `Unable to control the window: ${error.message ?? String(error)}`;
  status.hidden = false;
  console.error(error);
}

async function expandWindow() {
  if (!isDesktop || isExpanded || isExpanding || isShrinking) return;

  isExpanding = true;
  expandButton.disabled = true;
  try {
    await invoke('expand_window', { reducedMotion: reducedMotion.matches });
    isExpanded = true;
    expandButton.setAttribute('aria-expanded', 'true');
    expandButton.classList.add('is-fading');
    expandedArtwork.classList.add('is-visible');
  } catch (error) {
    expandButton.disabled = false;
    shrinkRequested = false;
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
  try {
    await invoke('shrink_window', { reducedMotion: reducedMotion.matches });
    isExpanded = false;
    expandButton.setAttribute('aria-expanded', 'false');
    expandButton.disabled = false;
    expandButton.classList.remove('is-fading');
    expandedArtwork.classList.remove('is-visible');
  } catch (error) {
    showError(error);
  } finally {
    isShrinking = false;
  }
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
      expandButton.hidden = false;
      return;
    }

    expandedArtwork.classList.add('is-visible');
  }).catch(error => {
    showError(error);
  });
}

expandButton.addEventListener('pointerdown', event => {
  if (event.button !== 0 || expandButton.disabled) return;
  dragStart = { x: event.screenX, y: event.screenY };
});

expandButton.addEventListener('pointermove', event => {
  if (!dragStart) return;
  if (Math.hypot(event.screenX - dragStart.x, event.screenY - dragStart.y) < 5) return;

  dragStart = null;
  suppressClickUntil = performance.now() + 500;
  invoke('start_window_dragging').catch(showError);
});

expandButton.addEventListener('pointerup', () => { dragStart = null; });
expandButton.addEventListener('pointercancel', () => { dragStart = null; });

expandButton.addEventListener('click', () => {
  if (expandButton.disabled || performance.now() < suppressClickUntil) return;
  expandWindow();
});

addEventListener('blur', requestShrink);
document.addEventListener('keydown', event => {
  if (event.key !== 'Escape' || !isDesktop || (!isExpanded && !isExpanding)) return;
  event.preventDefault();
  requestShrink();
});
