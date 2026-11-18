function hasDiagram(source) {
  return source.split(/\r?\n/).some(line => {
    const text = line.trim();
    return text && (!text.startsWith('%%') || text.startsWith('%%{'));
  });
}

const disabledStyle = 'classDef disabled fill:#e0e0e0,stroke:#cccccc,color:#888888;';
const disabledNote = '%% Nodes disabled by clicking (managed automatically)';

function flowchartNodeId(node) {
  return node?.getAttribute('id')?.match(/(?:^|-)flowchart-(.+)-\d+$/)?.[1];
}

// Hide labels and comments while retaining offsets for edits to Mermaid syntax.
function syntaxMask(source, commentStarts = []) {
  let mask = '';
  let depth = 0;
  let quote = false;
  let comment = false;
  for (let i = 0; i < source.length; i++) {
    const char = source[i];
    if (char === '\n') {
      comment = false;
      mask += char;
      continue;
    }
    if (!comment && !depth && !quote && char === '%' && source[i + 1] === '%') {
      commentStarts.push(i);
      comment = true;
    }
    if (comment) {
      mask += ' ';
      continue;
    }
    if (char === '"' && source[i - 1] !== '\\') quote = !quote;
    if (!quote && /[\[({]/.test(char)) depth++;
    if (!quote && /[\])}]/.test(char) && depth) {
      depth--;
      mask += ' ';
      continue;
    }
    mask += depth || quote || char === '"' ? ' ' : char;
  }
  return mask;
}

function toggleDisabled(source, id, disabled) {
  const newline = source.includes('\r\n') ? '\r\n' : '\n';
  const sectionPattern = /^%% Nodes disabled by clicking \(managed automatically\)\r?$(?:\n|$)/gm;
  const commentStarts = [];
  syntaxMask(source, commentStarts);
  const sections = [...source.matchAll(sectionPattern)].filter(section => commentStarts.includes(section.index));
  if (sections.length > 1) {
    throw new Error('Multiple automatically managed disabled sections found; edit the Mermaid source instead.');
  }
  let ids = [];
  let style = '';
  if (sections.length) {
    const section = sections[0];
    let end = section.index + section[0].length;
    const styleLine = source.slice(end).match(/^classDef[ \t]+disabled[ \t]+[^\r\n]*(?:\r?\n|$)/);
    if (styleLine) {
      style = styleLine[0].replace(/\r?\n$/, '');
      end += styleLine[0].length;
    }
    const classLine = source.slice(end).match(/^class[ \t]+([^\s;,]+(?:,[^\s;,]+)*)[ \t]+disabled;[ \t]*(?:\r?\n|$)/);
    if (classLine) {
      ids = classLine[1].split(',');
      end += classLine[0].length;
    } else if (/^class[ \t]/.test(source.slice(end))) {
      throw new Error('Invalid automatically managed disabled list; edit the Mermaid source instead.');
    }
    source = source.slice(0, section.index) + source.slice(end);
  }

  const mask = syntaxMask(source);
  const edits = [];
  const managed = ids.includes(id);
  ids = ids.filter(value => value !== id);
  if (disabled) {
    const assignments = /(?:^|[;\n])[ \t]*class[ \t]+([^\s;]+)[ \t]+([^\s;]+)/g;
    for (const match of mask.matchAll(assignments)) {
      const ids = match[1].split(',');
      const classes = match[2].split(',');
      if (!ids.includes(id) || !classes.includes('disabled')) continue;
      const remainingIds = ids.filter(value => value !== id);
      const remainingClasses = classes.filter(value => value !== 'disabled');
      const indent = match[0].match(/(?:^|[;\n])([ \t]*)class/)[1];
      const statements = [];
      if (remainingIds.length) statements.push(`class ${remainingIds.join(',')} ${classes.join(',')}`);
      if (remainingClasses.length) statements.push(`class ${id} ${remainingClasses.join(',')}`);
      const start = match.index + match[0].lastIndexOf('class');
      let end = match.index + match[0].length;
      if (!statements.length && source[end] === ';') end++;
      edits.push({ start, end, text: statements.join(`;${newline}${indent}`) });
    }
    const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const inline = new RegExp(`(^|[^\\p{L}\\p{N}_-])${escaped}[ \\t]*:::disabled\\b`, 'gu');
    for (const match of mask.matchAll(inline)) {
      const start = match.index + match[0].lastIndexOf(':::disabled');
      edits.push({ start, end: start + ':::disabled'.length, text: '' });
    }
    if (!edits.length && !managed) {
      throw new Error(`Cannot safely remove the disabled class from ${id}; edit the Mermaid source instead.`);
    }
    for (const edit of edits.sort((a, b) => b.start - a.start)) {
      source = source.slice(0, edit.start) + edit.text + source.slice(edit.end);
    }
  } else {
    ids.push(id);
  }

  const needsStyle = !style && !/(?:^|[;\n])[ \t]*classDef[ \t]+disabled(?:[ \t,]|$)/.test(syntaxMask(source));
  const separator = source.endsWith('\n') ? '' : newline;
  return source + separator + disabledNote + newline
    + (style || needsStyle ? (style || disabledStyle) + newline : '')
    + (ids.length ? `class ${ids.join(',')} disabled;` + newline : '');
}

export function createDiagramViewer({ root, diagram, editor, error, render, save }) {
  let editing = false;
  let busy = false;
  let idle = Promise.resolve();
  let resolveIdle;

  function setBusy(value) {
    busy = value;
    if (value) idle = new Promise(resolve => { resolveIdle = resolve; });
    else resolveIdle();
  }

  function setEditing(value) {
    editing = value;
    root.classList.toggle('is-editing', value);
    diagram.setAttribute('aria-hidden', String(value));
    diagram.tabIndex = value ? -1 : 0;
    editor.setAttribute('aria-hidden', String(!value));
    editor.tabIndex = value ? 0 : -1;
    if (root.classList.contains('is-visible')) {
      (value ? editor : diagram).focus();
    }
  }

  function clearError() {
    error.hidden = true;
    error.textContent = '';
  }

  function showError(reason) {
    error.textContent = `Unable to display or save the diagram: ${reason.message ?? String(reason)}`;
    error.hidden = false;
  }

  async function renderSource(source) {
    return hasDiagram(source) ? render(source) : '';
  }

  async function load(source) {
    editor.value = source;
    clearError();
    if (!hasDiagram(source)) {
      setEditing(true);
      return;
    }
    try {
      diagram.innerHTML = await renderSource(source);
      setEditing(false);
    } catch (reason) {
      setEditing(true);
      showError(reason);
    }
  }

  function openEditor() {
    if (busy) return;
    clearError();
    setEditing(true);
  }

  async function saveAndShow() {
    if (busy) return;
    setBusy(true);
    editor.readOnly = true;
    clearError();
    try {
      const source = editor.value;
      const svg = await renderSource(source);
      await save(source);
      diagram.innerHTML = svg;
      setEditing(false);
    } catch (reason) {
      showError(reason);
    } finally {
      editor.readOnly = false;
      setBusy(false);
    }
  }

  diagram.addEventListener('click', async event => {
    const node = event?.target?.closest?.('g.node');
    const id = flowchartNodeId(node);
    if (!id || !diagram.contains(node)) {
      openEditor();
      return;
    }
    if (busy) return;
    setBusy(true);
    clearError();
    try {
      const disabled = node.classList.contains('disabled');
      const source = toggleDisabled(editor.value, id, disabled);
      const svg = await renderSource(source);
      const preview = diagram.ownerDocument.createElement('div');
      preview.innerHTML = svg;
      const updatedNode = [...preview.querySelectorAll('g.node')].find(item => flowchartNodeId(item) === id);
      if (!updatedNode || updatedNode.classList.contains('disabled') === disabled) {
        throw new Error(`Cannot safely toggle ${id}; edit the Mermaid source instead.`);
      }
      await save(source);
      editor.value = source;
      diagram.innerHTML = svg;
    } catch (reason) {
      showError(reason);
    } finally {
      setBusy(false);
    }
  });
  diagram.addEventListener('keydown', event => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    openEditor();
  });

  return {
    load,
    isEditing: () => editing,
    whenIdle: () => idle,
    saveAndShow,
    reveal() {
      root.setAttribute('aria-hidden', 'false');
      root.classList.add('is-visible');
      (editing ? editor : diagram).focus();
    },
    hide() {
      root.setAttribute('aria-hidden', 'true');
      root.classList.remove('is-visible');
    },
  };
}
