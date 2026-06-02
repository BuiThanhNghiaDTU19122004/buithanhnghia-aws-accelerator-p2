type MedicalLabel =
  | 'Clinical Condition'
  | 'Medication Statement'
  | 'Clinical Finding'
  | 'Medical Procedure';

type AnnotationStatus = 'suggested' | 'accepted' | 'rejected' | 'corrected';

interface DocumentSummary {
  id: string;
  title?: string;
  category?: string;
  status?: string;
  createdAt?: string;
  s3Key?: string;
}

interface ClinicalDocument extends DocumentSummary {
  text?: string;
  annotations?: Annotation[];
}

interface Annotation {
  annotationId?: string;
  id?: string;
  documentId: string;
  text: string;
  label: MedicalLabel;
  startOffset: number;
  endOffset: number;
  createdAt?: string;
  source: 'human' | 'llm';
  status?: AnnotationStatus;
  confidence?: number;
}

interface SelectionState {
  start: number;
  end: number;
  text: string;
}

const CONFIG_KEY = 'clinannotate.api.config';

const labels: MedicalLabel[] = [
  'Clinical Condition',
  'Medication Statement',
  'Clinical Finding',
  'Medical Procedure',
];

const statuses: AnnotationStatus[] = [
  'suggested',
  'accepted',
  'rejected',
  'corrected',
];

const state = {
  apiBase: '',
  apiKey: '',
  connection: 'checking' as 'checking' | 'online' | 'offline',
  documents: [] as DocumentSummary[],
  selectedDocumentId: '',
  selectedDocument: null as ClinicalDocument | null,
  annotations: [] as Annotation[],
  selection: null as SelectionState | null,
  filter: '',
  isBusy: false,
  toast: null as null | { type: 'success' | 'error'; message: string },
};

const appRoot = document.querySelector<HTMLElement>('#app');

if (!appRoot) {
  throw new Error('App root not found');
}

const app: HTMLElement = appRoot;

loadConfig();
void refreshWorkspace();

function loadConfig() {
  try {
    const stored = localStorage.getItem(CONFIG_KEY);
    if (!stored) return;

    const parsed = JSON.parse(stored);
    state.apiBase = typeof parsed.apiBase === 'string' ? parsed.apiBase : '';
    state.apiKey = typeof parsed.apiKey === 'string' ? parsed.apiKey : '';
  } catch {
    state.apiBase = '';
    state.apiKey = '';
  }
}

function saveConfig() {
  localStorage.setItem(
    CONFIG_KEY,
    JSON.stringify({ apiBase: state.apiBase, apiKey: state.apiKey }),
  );
}

function apiUrl(path: string) {
  const base = state.apiBase.trim().replace(/\/$/, '');
  return base ? `${base}${path}` : path;
}

async function apiRequest<T>(path: string, options: RequestInit = {}) {
  const headers = new Headers(options.headers);
  if (options.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  if (state.apiKey.trim()) {
    headers.set('X-Api-Key', state.apiKey.trim());
  }

  const response = await fetch(apiUrl(path), {
    ...options,
    headers,
  });

  const contentType = response.headers.get('content-type') || '';
  const payload = contentType.includes('application/json')
    ? await response.json()
    : await response.text();

  if (!response.ok) {
    const message =
      typeof payload === 'object' && payload
        ? payload.message || payload.error
        : payload;
    throw new Error(message || `Request failed with ${response.status}`);
  }

  return payload as T;
}

async function refreshWorkspace() {
  render();
  await checkHealth();
  await loadDocuments();

  if (!state.selectedDocumentId && state.documents[0]?.id) {
    await selectDocument(state.documents[0].id);
  } else if (state.selectedDocumentId) {
    await selectDocument(state.selectedDocumentId);
  } else {
    render();
  }
}

async function checkHealth() {
  try {
    await apiRequest<{ status: string }>('/health');
    state.connection = 'online';
  } catch {
    state.connection = 'offline';
  }
  render();
}

async function loadDocuments() {
  state.isBusy = true;
  render();
  try {
    state.documents = await apiRequest<DocumentSummary[]>('/documents');
    state.toast = null;
  } catch (error) {
    state.documents = [];
    state.toast = { type: 'error', message: getErrorMessage(error) };
  } finally {
    state.isBusy = false;
    render();
  }
}

async function selectDocument(id: string) {
  state.selectedDocumentId = id;
  state.selectedDocument = null;
  state.annotations = [];
  state.selection = null;
  state.isBusy = true;
  render();

  try {
    const document = await apiRequest<ClinicalDocument>(
      `/documents/${encodeURIComponent(id)}`,
    );
    state.selectedDocument = document;
    state.annotations = normalizeAnnotations(document.annotations || []);

    if (!document.annotations) {
      await loadAnnotations(id);
    }
    state.toast = null;
  } catch (error) {
    state.toast = { type: 'error', message: getErrorMessage(error) };
  } finally {
    state.isBusy = false;
    render();
  }
}

async function loadAnnotations(documentId: string) {
  const annotations = await apiRequest<Annotation[]>(
    `/annotations?documentId=${encodeURIComponent(documentId)}`,
  );
  state.annotations = normalizeAnnotations(annotations);
}

async function createAnnotation() {
  if (!state.selectedDocument || !state.selection) return;

  const rawText = state.selection.text;
  const leadingWhitespace = rawText.search(/\S/);
  const trimmedText = rawText.trim();
  if (!trimmedText) {
    state.toast = { type: 'error', message: 'Select text before saving.' };
    render();
    return;
  }
  if (trimmedText.length > 500) {
    state.toast = {
      type: 'error',
      message: 'Selected text must be 500 characters or less.',
    };
    render();
    return;
  }

  const labelSelect = document.querySelector<HTMLSelectElement>('#labelSelect');
  const statusSelect = document.querySelector<HTMLSelectElement>('#statusSelect');
  const startOffset =
    state.selection.start + Math.max(0, leadingWhitespace);

  try {
    await apiRequest<Annotation>('/annotations', {
      method: 'POST',
      body: JSON.stringify({
        documentId: state.selectedDocument.id,
        text: trimmedText,
        label: labelSelect?.value || 'Clinical Finding',
        startOffset,
        endOffset: startOffset + trimmedText.length,
        source: 'human',
        status: statusSelect?.value || 'accepted',
      }),
    });
    state.toast = { type: 'success', message: 'Annotation saved.' };
    await selectDocument(state.selectedDocument.id);
  } catch (error) {
    state.toast = { type: 'error', message: getErrorMessage(error) };
    render();
  }
}

async function updateAnnotation(annotationId: string, updates: Partial<Annotation>) {
  try {
    await apiRequest<Annotation>(`/annotations/${encodeURIComponent(annotationId)}`, {
      method: 'PATCH',
      body: JSON.stringify(updates),
    });
    state.toast = { type: 'success', message: 'Annotation updated.' };
    if (state.selectedDocumentId) {
      await selectDocument(state.selectedDocumentId);
    }
  } catch (error) {
    state.toast = { type: 'error', message: getErrorMessage(error) };
    render();
  }
}

async function analyzeDocument() {
  if (!state.selectedDocumentId) return;

  state.isBusy = true;
  render();
  try {
    await apiRequest(`/documents/${encodeURIComponent(state.selectedDocumentId)}/analyze`, {
      method: 'POST',
    });
    state.toast = { type: 'success', message: 'Analysis queued.' };
    await selectDocument(state.selectedDocumentId);
  } catch (error) {
    state.toast = { type: 'error', message: getErrorMessage(error) };
    render();
  } finally {
    state.isBusy = false;
    render();
  }
}

function normalizeAnnotations(annotations: Annotation[]) {
  return annotations
    .map((annotation) => ({
      ...annotation,
      annotationId: annotation.annotationId || annotation.id,
    }))
    .filter((annotation) => annotation.annotationId)
    .sort((a, b) => a.startOffset - b.startOffset);
}

function captureSelection(textarea: HTMLTextAreaElement) {
  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  if (start === end) {
    state.selection = null;
  } else {
    state.selection = {
      start,
      end,
      text: textarea.value.slice(start, end),
    };
  }
  updateSelectionPreview();
}

function updateSelectionPreview() {
  const preview = document.querySelector<HTMLElement>('#selectionPreview');
  const meta = document.querySelector<HTMLElement>('#selectionMeta');
  const button = document.querySelector<HTMLButtonElement>('#createAnnotationButton');
  const text = state.selection?.text.trim();

  if (preview) {
    preview.textContent = text || 'No text selected';
  }
  if (meta) {
    meta.textContent = state.selection
      ? `${state.selection.start}-${state.selection.end}`
      : '0-0';
  }
  if (button) {
    button.disabled = !text || state.isBusy;
  }
}

function render() {
  const filteredDocuments = state.documents.filter((document) => {
    const query = state.filter.trim().toLowerCase();
    if (!query) return true;
    return [document.title, document.category, document.id]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query));
  });

  app.innerHTML = `
    <div class="shell">
      <aside class="sidebar">
        <div class="panel-inner">
          <div class="brand">
            <img src="/assets/brand-mark.svg" alt="ClinAnnotate mark" />
            <div>
              <strong>ClinAnnotate</strong>
              <span>EHR review</span>
            </div>
          </div>
          ${renderConnection()}
          ${renderConfig()}
          <div class="field-stack">
            <label class="field">
              <span>Search documents</span>
              <input id="documentFilter" class="filter-input" type="search" value="${escapeAttr(
                state.filter,
              )}" placeholder="Title, category, id" />
            </label>
            <div class="doc-list">
              ${renderDocumentList(filteredDocuments)}
            </div>
          </div>
        </div>
      </aside>
      <main class="workspace">
        ${renderWorkspace()}
      </main>
      <section class="assistant-panel">
        <div class="panel-inner">
          ${renderAssistantPanel()}
        </div>
      </section>
    </div>
  `;

  bindEvents();
}

function renderConnection() {
  const label =
    state.connection === 'online'
      ? 'API online'
      : state.connection === 'offline'
        ? 'API offline'
        : 'Checking API';

  return `
    <div class="status-row">
      <div class="status-copy">
        <span class="status-dot ${state.connection}"></span>
        <strong>${label}</strong>
      </div>
      <button id="refreshButton" class="ghost-button" type="button">Refresh</button>
    </div>
  `;
}

function renderConfig() {
  return `
    <form id="configForm" class="field-stack">
      <label class="field">
        <span>API base</span>
        <input id="apiBaseInput" type="url" value="${escapeAttr(
          state.apiBase,
        )}" placeholder="Same origin" />
      </label>
      <label class="field">
        <span>API key</span>
        <input id="apiKeyInput" type="password" value="${escapeAttr(
          state.apiKey,
        )}" placeholder="Optional x-api-key" />
      </label>
      <button class="secondary-button" type="submit">Save connection</button>
    </form>
  `;
}

function renderDocumentList(documents: DocumentSummary[]) {
  if (state.isBusy && !documents.length) {
    return '<div class="loading-state">Loading documents...</div>';
  }

  if (!documents.length) {
    return '<div class="empty-state">No documents found</div>';
  }

  return documents
    .map((document) => {
      const active = document.id === state.selectedDocumentId ? 'active' : '';
      return `
        <button class="doc-item ${active}" type="button" data-doc-id="${escapeAttr(
          document.id,
        )}">
          <span class="doc-title">${escapeHtml(document.title || document.id)}</span>
          <span class="pill-row">
            <span class="pill">${escapeHtml(document.category || 'Clinical')}</span>
            <span class="pill teal">${escapeHtml(document.status || 'ready')}</span>
          </span>
        </button>
      `;
    })
    .join('');
}

function renderWorkspace() {
  if (state.isBusy && !state.selectedDocument) {
    return '<div class="loading-state">Loading workspace...</div>';
  }

  if (!state.selectedDocument) {
    return '<div class="empty-state">Select a document</div>';
  }

  const document = state.selectedDocument;
  const total = state.annotations.length;
  const accepted = state.annotations.filter(
    (annotation) => annotation.status === 'accepted',
  ).length;
  const suggested = state.annotations.filter(
    (annotation) => annotation.status === 'suggested',
  ).length;
  const human = state.annotations.filter(
    (annotation) => annotation.source === 'human',
  ).length;

  return `
    <div class="workspace-grid">
      ${renderToast()}
      <div class="topbar">
        <div>
          <p class="eyebrow">${escapeHtml(document.category || 'Clinical')}</p>
          <h1>${escapeHtml(document.title || document.id)}</h1>
          <div class="pill-row">
            <span class="pill">${escapeHtml(document.id)}</span>
            <span class="pill teal">${escapeHtml(document.status || 'ready')}</span>
            <span class="pill blue">${formatDate(document.createdAt)}</span>
          </div>
        </div>
        <button id="analyzeButton" class="primary-button" type="button" ${
          state.isBusy ? 'disabled' : ''
        }>AI analyze</button>
      </div>
      <div class="summary-grid">
        ${renderSummaryTile(total, 'Annotations')}
        ${renderSummaryTile(suggested, 'Suggested')}
        ${renderSummaryTile(accepted, 'Accepted')}
        ${renderSummaryTile(human, 'Human')}
      </div>
      <div class="document-layout">
        <section class="workspace-card">
          <h2>Clinical note</h2>
          <textarea id="noteText" class="note-text" readonly spellcheck="false"></textarea>
        </section>
        <section class="workspace-card">
          <h2>New annotation</h2>
          <div class="selection-box">
            <span class="mini-label">Selection <strong id="selectionMeta">0-0</strong></span>
            <p id="selectionPreview" class="selection-preview">No text selected</p>
          </div>
          <form id="annotationForm" class="annotation-form">
            <label class="field">
              <span>Label</span>
              <select id="labelSelect">
                ${renderLabelOptions('Clinical Finding')}
              </select>
            </label>
            <label class="field">
              <span>Status</span>
              <select id="statusSelect">
                ${renderStatusOptions('accepted')}
              </select>
            </label>
            <button id="createAnnotationButton" class="primary-button" type="submit" disabled>
              Save annotation
            </button>
          </form>
        </section>
      </div>
      <section class="workspace-card">
        <h2>Annotations</h2>
        ${renderAnnotations()}
      </section>
    </div>
  `;
}

function renderSummaryTile(value: number, label: string) {
  return `
    <div class="summary-tile">
      <span class="summary-number">${value}</span>
      <span class="meta">${label}</span>
    </div>
  `;
}

function renderAssistantPanel() {
  const suggested = state.annotations.filter(
    (annotation) => annotation.status === 'suggested',
  );
  const reviewed = state.annotations.filter(
    (annotation) =>
      annotation.status === 'accepted' ||
      annotation.status === 'corrected' ||
      annotation.status === 'rejected',
  ).length;
  const confidenceValues = state.annotations
    .map((annotation) => annotation.confidence)
    .filter((value): value is number => typeof value === 'number');
  const averageConfidence = confidenceValues.length
    ? Math.round(
        (confidenceValues.reduce((sum, value) => sum + value, 0) /
          confidenceValues.length) *
          100,
      )
    : 0;

  return `
    <div class="assistant-card">
      <div class="assistant-header">
        <img src="/assets/brand-mark.svg" alt="" />
        <div>
          <h2>Care assistant</h2>
          <span class="meta">${state.selectedDocumentId || 'No document'}</span>
        </div>
      </div>
    </div>
    <div class="assistant-card">
      <h3>Review queue</h3>
      <div class="queue-list">
        ${renderQueueItem('Suggested', suggested.length, 'orange')}
        ${renderQueueItem('Reviewed', reviewed, 'green')}
        ${renderQueueItem('Avg confidence', averageConfidence ? `${averageConfidence}%` : '-', 'blue')}
      </div>
    </div>
    <div class="assistant-card">
      <h3>Suggested entities</h3>
      <div class="annotation-list">
        ${
          suggested.length
            ? suggested.slice(0, 6).map(renderCompactAnnotation).join('')
            : '<div class="empty-state">No pending suggestions</div>'
        }
      </div>
    </div>
  `;
}

function renderQueueItem(label: string, value: number | string, tone: string) {
  const toneClass = tone === 'green' ? 'green' : tone === 'blue' ? 'blue' : '';
  return `
    <div class="queue-item">
      <span>${escapeHtml(label)}</span>
      <span class="pill ${toneClass}">${escapeHtml(String(value))}</span>
    </div>
  `;
}

function renderAnnotations() {
  if (!state.annotations.length) {
    return '<div class="empty-state">No annotations yet</div>';
  }

  return `
    <div class="annotation-list">
      ${state.annotations.map(renderAnnotation).join('')}
    </div>
  `;
}

function renderAnnotation(annotation: Annotation) {
  const id = annotation.annotationId || annotation.id || '';
  const statusClass = getStatusClass(annotation.status);
  return `
    <article class="annotation-item">
      <div class="annotation-head">
        <div>
          <p class="annotation-text">${escapeHtml(annotation.text)}</p>
          <span class="meta">${annotation.startOffset}-${annotation.endOffset}</span>
        </div>
        <span class="pill ${statusClass}">${escapeHtml(annotation.status || 'draft')}</span>
      </div>
      <div class="pill-row">
        <span class="pill">${escapeHtml(annotation.label)}</span>
        <span class="pill ${annotation.source === 'llm' ? 'blue' : 'green'}">${escapeHtml(
          annotation.source,
        )}</span>
        ${
          typeof annotation.confidence === 'number'
            ? `<span class="pill teal">${Math.round(annotation.confidence * 100)}%</span>`
            : ''
        }
      </div>
      <div class="annotation-actions">
        <select data-annotation-status="${escapeAttr(id)}">
          ${renderStatusOptions(annotation.status || 'suggested')}
        </select>
        <select data-annotation-label="${escapeAttr(id)}">
          ${renderLabelOptions(annotation.label)}
        </select>
      </div>
    </article>
  `;
}

function renderCompactAnnotation(annotation: Annotation) {
  const id = annotation.annotationId || annotation.id || '';
  return `
    <article class="annotation-item">
      <p class="annotation-text">${escapeHtml(annotation.text)}</p>
      <div class="pill-row">
        <span class="pill">${escapeHtml(annotation.label)}</span>
        ${
          typeof annotation.confidence === 'number'
            ? `<span class="pill teal">${Math.round(annotation.confidence * 100)}%</span>`
            : ''
        }
      </div>
      <button class="tiny-button" type="button" data-accept-annotation="${escapeAttr(
        id,
      )}">Accept</button>
    </article>
  `;
}

function renderLabelOptions(selected: string) {
  return labels
    .map(
      (label) =>
        `<option value="${escapeAttr(label)}" ${
          label === selected ? 'selected' : ''
        }>${escapeHtml(label)}</option>`,
    )
    .join('');
}

function renderStatusOptions(selected: string) {
  return statuses
    .map(
      (status) =>
        `<option value="${escapeAttr(status)}" ${
          status === selected ? 'selected' : ''
        }>${escapeHtml(status)}</option>`,
    )
    .join('');
}

function renderToast() {
  if (!state.toast) return '';

  return `
    <div class="toast ${state.toast.type}">
      ${escapeHtml(state.toast.message)}
    </div>
  `;
}

function bindEvents() {
  document.querySelector('#refreshButton')?.addEventListener('click', () => {
    void refreshWorkspace();
  });

  document.querySelector('#configForm')?.addEventListener('submit', (event) => {
    event.preventDefault();
    const apiBaseInput =
      document.querySelector<HTMLInputElement>('#apiBaseInput');
    const apiKeyInput = document.querySelector<HTMLInputElement>('#apiKeyInput');
    state.apiBase = apiBaseInput?.value.trim() || '';
    state.apiKey = apiKeyInput?.value.trim() || '';
    saveConfig();
    state.toast = { type: 'success', message: 'Connection saved.' };
    void refreshWorkspace();
  });

  document.querySelector('#documentFilter')?.addEventListener('input', (event) => {
    state.filter = (event.target as HTMLInputElement).value;
    render();
  });

  document.querySelectorAll<HTMLElement>('[data-doc-id]').forEach((button) => {
    button.addEventListener('click', () => {
      const id = button.dataset.docId;
      if (id) void selectDocument(id);
    });
  });

  const noteText = document.querySelector<HTMLTextAreaElement>('#noteText');
  if (noteText && state.selectedDocument?.text) {
    noteText.value = state.selectedDocument.text;
    noteText.addEventListener('mouseup', () => captureSelection(noteText));
    noteText.addEventListener('keyup', () => captureSelection(noteText));
    noteText.addEventListener('select', () => captureSelection(noteText));
  }

  document.querySelector('#annotationForm')?.addEventListener('submit', (event) => {
    event.preventDefault();
    void createAnnotation();
  });

  document.querySelector('#analyzeButton')?.addEventListener('click', () => {
    void analyzeDocument();
  });

  document
    .querySelectorAll<HTMLSelectElement>('[data-annotation-status]')
    .forEach((select) => {
      select.addEventListener('change', () => {
        const id = select.dataset.annotationStatus;
        if (id) void updateAnnotation(id, { status: select.value as AnnotationStatus });
      });
    });

  document
    .querySelectorAll<HTMLSelectElement>('[data-annotation-label]')
    .forEach((select) => {
      select.addEventListener('change', () => {
        const id = select.dataset.annotationLabel;
        if (id) void updateAnnotation(id, { label: select.value as MedicalLabel });
      });
    });

  document
    .querySelectorAll<HTMLButtonElement>('[data-accept-annotation]')
    .forEach((button) => {
      button.addEventListener('click', () => {
        const id = button.dataset.acceptAnnotation;
        if (id) void updateAnnotation(id, { status: 'accepted' });
      });
    });

  updateSelectionPreview();
}

function getStatusClass(status?: string) {
  switch (status) {
    case 'accepted':
      return 'green';
    case 'rejected':
      return 'rose';
    case 'corrected':
      return 'teal';
    default:
      return '';
  }
}

function formatDate(value?: string) {
  if (!value) return 'No date';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: '2-digit',
    year: 'numeric',
  }).format(date);
}

function getErrorMessage(error: unknown) {
  return error instanceof Error ? error.message : 'Unexpected error';
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function escapeAttr(value: string) {
  return escapeHtml(value);
}

export {};
