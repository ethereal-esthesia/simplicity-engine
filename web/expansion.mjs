const EDGES = ['left', 'top', 'right', 'bottom'];

export function targetEdges(width, height) {
  const inset = Math.min(width, height) * 0.05;
  return {
    left: inset,
    top: inset,
    right: width - inset,
    bottom: height - inset,
  };
}

export function edgeDeltas(start, target) {
  return Object.fromEntries(EDGES.map(edge => [edge, target[edge] - start[edge]]));
}

export function easeProgress(progress) {
  const clamped = Math.max(0, Math.min(1, progress));
  return clamped * clamped * (3 - 2 * clamped);
}

export function interpolateEdges(start, deltas, progress) {
  const amount = easeProgress(progress);
  return Object.fromEntries(
    EDGES.map(edge => [edge, start[edge] + deltas[edge] * amount]),
  );
}
