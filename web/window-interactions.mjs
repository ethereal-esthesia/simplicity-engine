const DRAG_TOLERANCE = 5;

export function setupWindowInteractions({
  element,
  startDragging,
  onActivate,
  onError,
  showDragCursor = false,
}) {
  let pointer = null;
  let clickAllowed = false;
  const eventTarget = element.ownerDocument.defaultView;
  element.classList.toggle('show-drag-cursor', showDragCursor);

  element.addEventListener('pointerdown', event => {
    if (event.button !== 0 || element.disabled) return;
    pointer = { id: event.pointerId, x: event.screenX, y: event.screenY, dragged: false };
    clickAllowed = false;
  });

  eventTarget.addEventListener('pointermove', event => {
    if (!pointer || pointer.id !== event.pointerId || pointer.dragged) return;
    if (Math.hypot(event.screenX - pointer.x, event.screenY - pointer.y) < DRAG_TOLERANCE) return;
    pointer.dragged = true;
    startDragging().catch(onError);
  });

  eventTarget.addEventListener('pointerup', event => {
    if (!pointer || pointer.id !== event.pointerId) return;
    clickAllowed = !pointer.dragged &&
      Math.hypot(event.screenX - pointer.x, event.screenY - pointer.y) < DRAG_TOLERANCE;
    pointer = null;
  });

  eventTarget.addEventListener('pointercancel', event => {
    if (!pointer || pointer.id !== event.pointerId) return;
    pointer = null;
    clickAllowed = false;
  });

  eventTarget.addEventListener('blur', () => {
    pointer = null;
    clickAllowed = false;
  });

  element.addEventListener('click', event => {
    if (element.disabled) return;
    const activate = event.detail === 0 || clickAllowed;
    clickAllowed = false;
    if (activate) onActivate();
  });
}
