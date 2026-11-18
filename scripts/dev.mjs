import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { prepareDiagramFile } from './diagram-prepare.mjs';

async function confirm(path) {
  const input = createInterface({ input: process.stdin, output: process.stderr });
  process.stderr.write(`Create ${path}? [y/n] `);
  for await (const line of input) {
    const answer = line.trim().toLowerCase();
    if (answer === 'y' || answer === 'yes') return true;
    if (answer === 'n' || answer === 'no') return false;
    process.stderr.write(`Please answer y or n.\nCreate ${path}? [y/n] `);
  }
  throw new Error('Cannot confirm file creation: no input available');
}

async function main() {
  if (process.argv.length !== 3 || !process.argv[2]) {
    throw new Error('Usage: npm run dev -- /path/to/diagram.mmd');
  }
  const path = process.argv[2];
  await prepareDiagramFile(path, confirm);
  const cli = fileURLToPath(new URL('../node_modules/@tauri-apps/cli/tauri.js', import.meta.url));
  const child = spawn(process.execPath, [cli, 'dev', '--', '--', path], { stdio: 'inherit' });
  child.on('error', error => {
    console.error(`Cannot start Tauri: ${error.message}`);
    process.exitCode = 1;
  });
  child.on('exit', (code, signal) => {
    if (signal) console.error(`Tauri exited due to ${signal}`);
    process.exitCode = code ?? 1;
  });
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 2;
});
