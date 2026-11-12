export async function startPlayer(video, status, tauri) {
  const showError = message => {
    status.textContent = message;
    status.hidden = false;
  };

  video.addEventListener('error', () => showError('Unable to play this video.'));
  try {
    const path = await tauri.core.invoke('get_video_path');
    video.src = tauri.core.convertFileSrc(path);
    await video.play();
    status.hidden = true;
  } catch (error) {
    showError(`Unable to start video: ${error}`);
  }
}

if (typeof document !== 'undefined') {
  startPlayer(document.querySelector('video'), document.querySelector('#status'), window.__TAURI__);
}
