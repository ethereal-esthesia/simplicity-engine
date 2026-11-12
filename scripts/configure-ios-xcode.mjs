import { readFile, writeFile, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';

// Xcode launched from Finder does not inherit the terminal's tooling PATH.
const root = 'src-tauri/gen/apple';
const projects = (await readdir(root)).filter(name => name.endsWith('.xcodeproj'));
if (projects.length !== 1) throw new Error('Expected one generated Xcode project; run ios init first');
const nodeDir = dirname(process.execPath);
const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
const prefix = `export PATH=${quote(nodeDir)}:"$HOME/.cargo/bin":/opt/homebrew/bin:/usr/local/bin:"$PATH"; `;
const marker = 'npm run -- tauri ios xcode-script';
for (const [path, encoded] of [
  [join(root, projects[0], 'project.pbxproj'), true],
  [join(root, 'project.yml'), false],
]) {
  let source = await readFile(path, 'utf8');
  // The generated Rust host does not use SwiftUI Previews. Keep its debug code
  // in the executable, avoiding an unsigned debug dylib at simulator launch.
  // https://developer.apple.com/documentation/xcode/understanding-build-product-layout-changes
  if (!source.includes('ENABLE_DEBUG_DYLIB')) {
    const anchor = encoded ? /^(\s*)CODE_SIGN_ENTITLEMENTS =/gm : /^(        )ENABLE_BITCODE:/gm;
    if (!anchor.test(source)) throw new Error(`Missing app target settings in ${path}`);
    anchor.lastIndex = 0;
    source = source.replace(anchor, (match, indent) =>
      `${indent}ENABLE_DEBUG_DYLIB${encoded ? ' = NO;' : ': false'}\n${match}`);
  }

  if (!source.includes(marker)) throw new Error(`Tauri build script changed in ${path}`);
  const addition = encoded ? JSON.stringify(prefix).slice(1, -1) : prefix;
  if (!source.includes(addition + marker)) {
    source = source.replace(marker, addition + marker);
  }
  await writeFile(path, source);
}
console.log('Configured Xcode to find Node/npm and Rust.');
