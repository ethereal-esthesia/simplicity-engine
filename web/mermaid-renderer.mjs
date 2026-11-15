import mermaid from 'mermaid';

mermaid.initialize({
  startOnLoad: false,
  securityLevel: 'strict',
  flowchart: { htmlLabels: false },
});

let nextId = 0;

export async function renderMermaid(source) {
  await mermaid.parse(source);
  const { svg } = await mermaid.render(`simplicity-diagram-${nextId++}`, source);
  return svg;
}
