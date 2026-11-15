const status = document.querySelector('#status');
const expandButton = document.querySelector('#floating-expand');
const expandedArtwork = document.querySelector('#expanded-artwork');
const windowSurface = document.querySelector('#window-surface');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const invoke = window.__TAURI__?.core?.invoke;
let dragStart = null;
let suppressClickUntil = 0;

function showError(error) {
  status.textContent = `Unable to control the window: ${error.message ?? String(error)}`;
  status.hidden = false;
  console.error(error);
}

if (!invoke) {
  showError(new Error('Tauri command interface is unavailable'));
} else {
  invoke('is_desktop').then(isDesktop => {
    if (isDesktop) {
      windowSurface.classList.add('is-desktop');
      expandButton.hidden = false;
      return;
    }

    windowSurface.classList.add('is-expanded');
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

expandButton.addEventListener('click', async () => {
  if (expandButton.disabled || performance.now() < suppressClickUntil) return;

  expandButton.disabled = true;
  try {
    await invoke('expand_window', { reducedMotion: reducedMotion.matches });
    expandButton.setAttribute('aria-expanded', 'true');
    windowSurface.classList.add('is-expanded');
    expandButton.classList.add('is-fading');
    expandedArtwork.classList.add('is-visible');
  } catch (error) {
    expandButton.disabled = false;
    showError(error);
  }
});
