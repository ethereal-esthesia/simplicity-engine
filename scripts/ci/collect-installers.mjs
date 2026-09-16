import { readdir, mkdir, copyFile, readFile, writeFile } from 'node:fs/promises';
import { join, basename, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const [kind, label, source] = process.argv.slice(2);
if (!['desktop', 'android', 'ios'].includes(kind) || !label || !source) {
  throw new Error('Usage: collect-installers.mjs <desktop|android|ios> <label> <source>');
}
const output = resolve('dist/test-installers', label);
await mkdir(output, { recursive: true });
const files = [];
async function collect(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name.endsWith('.app')) {
        // Preserve executable bits, symlinks and macOS metadata in downloadable apps.
        if (kind === 'desktop' || (kind === 'ios' && path.includes('.xcarchive/Products/Applications/'))) {
          const plist = join(path, kind === 'ios' ? 'Info.plist' : 'Contents/Info.plist');
          const readPlist = key => execFileSync('/usr/libexec/PlistBuddy',
            ['-c', `Print :${key}`, plist], { encoding: 'utf8' }).trim();
          const executable = readPlist('CFBundleExecutable');
          const binary = join(path, kind === 'ios' ? executable : `Contents/MacOS/${executable}`);
          const expected = label.endsWith('-x64') ? 'x86_64' : 'arm64';
          const actual = execFileSync('lipo', ['-archs', binary], { encoding: 'utf8' }).trim().split(/\s+/);
          if (!actual.includes(expected)) throw new Error(`${label} contains ${actual}, expected ${expected}`);
          if (kind === 'ios' && readPlist('DTPlatformName') !== 'iphonesimulator') {
            throw new Error('Refusing to package a device app as a simulator download');
          }
          const name = `${label}-${entry.name}.zip`;
          execFileSync('ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', path, join(output, name)]);
          files.push(name);
        }
      } else {
        await collect(path);
      }
    } else if (entry.isFile() && ((kind === 'desktop' && /\.(dmg|exe|msi|deb|rpm|AppImage)$/.test(entry.name)) ||
               (kind === 'android' && entry.name.endsWith('.apk')))) {
      const name = `${label}-${basename(path)}`;
      if (files.includes(name)) throw new Error(`Duplicate artifact name: ${name}`);
      await copyFile(path, join(output, name));
      files.push(name);
    }
  }
}
await collect(source);
if (!files.length) throw new Error(`No ${kind} packages found under ${source}`);
const hashes = [];
for (const file of files.sort()) {
  hashes.push(`${createHash('sha256').update(await readFile(join(output, file))).digest('hex')}  ${file}`);
}
await writeFile(join(output, 'SHA256SUMS.txt'), hashes.join('\n') + '\n');
const commit = process.env.GITHUB_SHA ?? execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
await writeFile(join(output, 'BUILD.txt'), `Simplicity Engine test build\nTarget: ${label}\nCommit: ${commit}\nThese are development packages, not production-signed releases.\n`);
console.log(`Collected ${files.length} packages in ${output}`);
