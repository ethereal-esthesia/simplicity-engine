const status = document.querySelector('#status');
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
