import assert from 'node:assert/strict';
import test from 'node:test';
import { startPlayer } from '../web/main.mjs';

function player() {
  const video = {
    addEventListener(name, callback) { this[name] = callback; },
    async play() { this.played = true; },
  };
  const status = { hidden: false, textContent: '' };
  return { video, status };
}

test('starts the requested video and reports playback errors', async () => {
  const { video, status } = player();
  const tauri = { core: {
    invoke: async command => {
      assert.equal(command, 'get_video_path');
      return '/video.mp4';
    },
    convertFileSrc: path => `asset:${path}`,
  } };
  await startPlayer(video, status, tauri);
  assert.equal(video.src, 'asset:/video.mp4');
  assert.equal(video.played, true);
  assert.equal(status.hidden, true);
  video.error();
  assert.equal(status.hidden, false);
  assert.match(status.textContent, /Unable to play/);
});

test('shows command-line and playback failures', async () => {
  const { video, status } = player();
  const tauri = { core: {
    invoke: async () => { throw 'Usage: simplicity-app <video-path>'; },
    convertFileSrc: path => path,
  } };
  await startPlayer(video, status, tauri);
  assert.match(status.textContent, /Usage:/);
  tauri.core.invoke = async () => '/video.mp4';
  video.play = async () => { throw new Error('Playback blocked'); };
  await startPlayer(video, status, tauri);
  assert.equal(status.hidden, false);
  assert.match(status.textContent, /Playback blocked/);
});
