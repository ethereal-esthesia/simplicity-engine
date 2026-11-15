import { setupWindowInteractions } from './window-interactions.mjs';

const status = document.querySelector('#status');
const expandButton = document.querySelector('#floating-expand');
const expandedArtwork = document.querySelector('#expanded-artwork');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const invoke = window.__TAURI__?.core?.invoke;
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
  let prepared = false;
  try {
    const corner = await invoke('prepare_window_expansion');
    prepared = true;
    expandButton.dataset.corner = corner;
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    await invoke('expand_window', { reducedMotion: reducedMotion.matches });
    isExpanded = true;
    expandButton.setAttribute('aria-expanded', 'true');
    expandButton.classList.add('is-fading');
    expandedArtwork.classList.add('is-visible');
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

setupWindowInteractions({
  element: expandButton,
  startDragging: () => invoke('start_window_dragging'),
  onActivate: expandWindow,
  onError: showError,
});

addEventListener('blur', requestShrink);
document.addEventListener('keydown', event => {
  if (event.key !== 'Escape' || !isDesktop || (!isExpanded && !isExpanding)) return;
  event.preventDefault();
  requestShrink();
});
