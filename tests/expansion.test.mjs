import test from 'node:test';
import assert from 'node:assert/strict';
import { edgeDeltas, easeProgress, interpolateEdges, targetEdges } from '../web/expansion.mjs';

test('expanded artwork edges settle exactly five percent inside the viewport', () => {
  assert.deepEqual(targetEdges(800, 600), {
    left: 30,
    top: 30,
    right: 770,
    bottom: 570,
  });
  assert.deepEqual(targetEdges(600, 800), {
    left: 30,
    top: 30,
    right: 570,
    bottom: 770,
  });
});

test('all four edges follow the same eased fraction of their precomputed deltas', () => {
  const start = { left: 700, top: 500, right: 780, bottom: 580 };
  const target = targetEdges(800, 600);
  const deltas = edgeDeltas(start, target);
  const eased = easeProgress(0.25);
  const current = interpolateEdges(start, deltas, 0.25);

  for (const edge of ['left', 'top', 'right', 'bottom']) {
    assert.equal(current[edge], start[edge] + deltas[edge] * eased);
  }
  assert.deepEqual(interpolateEdges(start, deltas, 1), target);
});
