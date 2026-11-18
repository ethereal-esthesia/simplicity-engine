import { readFile, writeFile } from 'node:fs/promises';

export async function prepareDiagramFile(path, confirm) {
  try {
    await readFile(path);
    return;
  } catch (error) {
    if (error.code !== 'ENOENT') throw new Error(`Cannot read ${path}: ${error.message}`);
  }
  if (!await confirm(path)) throw new Error('File creation cancelled');
  const guidance = await readFile(new URL('../web/assets/diagram-guide.mmd', import.meta.url));
  try {
    await writeFile(path, guidance, { flag: 'wx' });
  } catch (error) {
    throw new Error(`Cannot create ${path}: ${error.message}`);
  }
}
