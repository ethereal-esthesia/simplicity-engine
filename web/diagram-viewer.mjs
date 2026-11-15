function hasDiagram(source) {
  return source.split(/\r?\n/).some(line => {
    const text = line.trim();
    return text && (!text.startsWith('%%') || text.startsWith('%%{'));
  });
}

export function createDiagramViewer({ root, diagram, editor, error, render, save }) {
  let editing = false;
  let busy = false;

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
    busy = true;
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
      busy = false;
    }
  }

  diagram.addEventListener('click', openEditor);
  diagram.addEventListener('keydown', event => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    openEditor();
  });

  return {
    load,
    isEditing: () => editing,
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
