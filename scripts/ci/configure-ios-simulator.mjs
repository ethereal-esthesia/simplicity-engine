import { readFile, writeFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const arch = process.argv[2] === 'x64' ? 'x86_64' : process.argv[2];
if (!['arm64', 'x86_64'].includes(arch)) throw new Error('Expected arm64 or x64');
const root = 'src-tauri/gen/apple';
const projects = (await readdir(root)).filter(name => name.endsWith('.xcodeproj'));
if (projects.length !== 1) throw new Error('Expected one generated Xcode project');
// Tauri 2.11 generates an arm64-only project regardless of the CLI build target.
// Set both source and generated settings, so Xcode cannot silently archive arm64
// for the x86_64 simulator job. Artifact collection independently checks the CPU.
const projectPath = join(root, projects[0], 'project.pbxproj');
let project = await readFile(projectPath, 'utf8');
let replacements = 0;
project = project.replace(/(\bARCHS = \(\s*)(arm64|x86_64)(,\s*\);)/g, (_, a, _old, b) => {
  replacements++;
  return `${a}${arch}${b}`;
});
if (!replacements) throw new Error('Generated ARCHS format changed; review the Tauri template');
project = project.replace(/\bVALID_ARCHS = (arm64|x86_64);/g, `VALID_ARCHS = ${arch};`);
await writeFile(projectPath, project);
const specPath = join(root, 'project.yml');
const spec = await readFile(specPath, 'utf8');
await writeFile(specPath, spec.replace(/ARCHS: \[(arm64|x86_64)\]/g, `ARCHS: [${arch}]`)
  .replace(/VALID_ARCHS: (arm64|x86_64)/g, `VALID_ARCHS: ${arch}`));
console.log(`Configured generated iOS project for ${arch}`);
