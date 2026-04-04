/* ============================================================
   ERP Intelligence v2 — Frontend JS
   New: reference ground-truth table, enrichment note, scrape badge
   ============================================================ */

const chatMessages    = document.getElementById('chatMessages');
const questionInput   = document.getElementById('questionInput');
const sendBtn         = document.getElementById('sendBtn');
const clearBtn        = document.getElementById('clearBtn');
const schemaBtn       = document.getElementById('schemaBtn');
const statusPill      = document.getElementById('statusPill');
const statQueries     = document.getElementById('statQueries');
const statRows        = document.getElementById('statRows');
const charCount       = document.getElementById('charCount');
const sqlPanel        = document.getElementById('sqlPanel');
const sqlCode         = document.getElementById('sqlCode');
const sqlRowsBadge    = document.getElementById('sqlRowsBadge');
const sqlCopyBtn      = document.getElementById('sqlCopyBtn');
const sqlCloseBtn     = document.getElementById('sqlCloseBtn');
const schemaModal     = document.getElementById('schemaModal');
const schemaClose     = document.getElementById('schemaClose');
const schemaBody      = document.getElementById('schemaBody');
const tableModal      = document.getElementById('tableModal');
const tableClose      = document.getElementById('tableClose');
const tableModalTitle = document.getElementById('tableModalTitle');
const dataTableWrapper= document.getElementById('dataTableWrapper');

let queryCount = 0;
let totalRows  = 0;
let currentSQL = '';
let isLoading  = false;

// ── Health check ──────────────────────────────────────────────
async function checkHealth() {
  try {
    const res  = await fetch('/api/health');
    const data = await res.json();
    if (data.status === 'ok') {
      statusPill.classList.add('connected');
      statusPill.querySelector('.status-label').textContent = 'Connected';
    } else {
      statusPill.querySelector('.status-label').textContent = 'DB Error';
    }
  } catch {
    statusPill.querySelector('.status-label').textContent = 'Offline';
  }
}
checkHealth();

// ── Textarea auto-resize ───────────────────────────────────────
questionInput.addEventListener('input', () => {
  questionInput.style.height = 'auto';
  questionInput.style.height = Math.min(questionInput.scrollHeight, 120) + 'px';
  const len = questionInput.value.length;
  charCount.textContent = `${len} / 500`;
  sendBtn.disabled = len === 0 || len > 500 || isLoading;
});

questionInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    if (!sendBtn.disabled) sendMessage();
  }
});
sendBtn.addEventListener('click', sendMessage);

// ── Sample questions ──────────────────────────────────────────
document.querySelectorAll('.sample-q').forEach(btn => {
  btn.addEventListener('click', () => {
    questionInput.value = btn.dataset.question;
    questionInput.dispatchEvent(new Event('input'));
    questionInput.focus();
  });
});

// ── Clear chat ────────────────────────────────────────────────
clearBtn.addEventListener('click', async () => {
  await fetch('/api/clear', { method: 'POST' });
  document.querySelectorAll('.message:not(.welcome-message)').forEach(m => m.remove());
  queryCount = 0; totalRows = 0;
  statQueries.textContent = '0';
  statRows.textContent    = '0';
  sqlPanel.classList.remove('visible');
});

// ── Schema modal ──────────────────────────────────────────────
schemaBtn.addEventListener('click', async () => {
  schemaModal.classList.add('visible');
  if (schemaBody.textContent === 'Loading schema...') {
    const res  = await fetch('/api/schema');
    const data = await res.json();
    schemaBody.textContent = data.schema;
  }
});
schemaClose.addEventListener('click', () => schemaModal.classList.remove('visible'));
schemaModal.addEventListener('click', e => { if (e.target === schemaModal) schemaModal.classList.remove('visible'); });

// ── SQL panel ─────────────────────────────────────────────────
sqlCloseBtn.addEventListener('click', () => sqlPanel.classList.remove('visible'));
sqlCopyBtn.addEventListener('click', () => {
  navigator.clipboard.writeText(currentSQL).then(() => {
    sqlCopyBtn.textContent = 'Copied!';
    setTimeout(() => { sqlCopyBtn.textContent = 'Copy'; }, 1500);
  });
});
function showSqlPanel(sql, rowcount) {
  currentSQL = sql;
  sqlCode.textContent = sql;
  sqlRowsBadge.textContent = `${rowcount} row${rowcount !== 1 ? 's' : ''}`;
  sqlPanel.classList.add('visible');
}

// ── Data table modal ──────────────────────────────────────────
tableClose.addEventListener('click', () => tableModal.classList.remove('visible'));
tableModal.addEventListener('click', e => { if (e.target === tableModal) tableModal.classList.remove('visible'); });

function buildDataTable(columns, rows, rowcount) {
  if (!columns.length) return '<p style="color:var(--text-2)">No data returned.</p>';

  let html = '<table class="data-table"><thead><tr>';
  columns.forEach(col => { html += `<th>${escapeHtml(col)}</th>`; });
  html += '</tr></thead><tbody>';
  rows.forEach(row => {
    html += '<tr>';
    columns.forEach(col => {
      const val = row[col];
      const display = val === null ? '—' : String(val);
      html += `<td title="${escapeHtml(display)}">${escapeHtml(display)}</td>`;
    });
    html += '</tr>';
  });
  html += '</tbody></table>';
  if (rowcount > rows.length) {
    html += `<p class="table-note">Showing first ${rows.length} of ${rowcount} rows.</p>`;
  }
  return html;
}

function showDataTable(columns, rows, rowcount, title = 'Query Results') {
  tableModalTitle.textContent = `${title} — ${rowcount} row${rowcount !== 1 ? 's' : ''}`;
  dataTableWrapper.innerHTML  = buildDataTable(columns, rows, rowcount);
  tableModal.classList.add('visible');
}

// ── Message helpers ───────────────────────────────────────────
function appendUserMessage(text) {
  const div = document.createElement('div');
  div.className = 'message user-message';
  div.innerHTML = `
    <div class="message-avatar user-avatar">U</div>
    <div class="message-content">
      <div class="message-text">${escapeHtml(text)}</div>
      <div class="message-time">${now()}</div>
    </div>`;
  chatMessages.appendChild(div);
  scrollBottom();
}

function appendLoadingMessage() {
  const div = document.createElement('div');
  div.className = 'message bot-message loading-msg';
  div.innerHTML = `
    <div class="message-avatar bot-avatar">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="10"/></svg>
    </div>
    <div class="message-content">
      <div class="message-text">
        <div class="dot-flashing"><span></span><span></span><span></span></div>
        <span class="loading-label">Thinking...</span>
      </div>
    </div>`;
  chatMessages.appendChild(div);
  scrollBottom();
  return div;
}

function appendBotMessage(data) {
  const div = document.createElement('div');
  div.className = 'message bot-message';

  const hasError   = !!data.error;
  const hasRef     = data.reference_cols && data.reference_cols.length > 0;
  const hasResults = data.columns && data.columns.length > 0;

  // Enrichment badge
  let enrichHtml = '';
  if (data.enrich_note) {
    const isSuccess = data.enrich_note.startsWith('🔍');
    enrichHtml = `<div class="enrich-badge ${isSuccess ? 'enrich-success' : 'enrich-warn'}">${escapeHtml(data.enrich_note)}</div>`;
  }

  // Action buttons
  let actionsHtml = '';
  if (data.sql) {
    actionsHtml += `<button class="msg-action-btn show-sql-btn">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>
      </svg>View SQL</button>`;
  }
  if (hasResults) {
    actionsHtml += `<button class="msg-action-btn show-table-btn">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/>
      </svg>View Table (${data.rowcount} rows)</button>`;
  }

  div.innerHTML = `
    <div class="message-avatar bot-avatar">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
    </div>
    <div class="message-content">
      ${hasError  ? `<div class="error-badge">⚠ Query had an issue</div>` : ''}
      ${enrichHtml}
      <div class="message-text">${formatAnswer(data.answer)}</div>
      ${actionsHtml ? `<div class="message-actions">${actionsHtml}</div>` : ''}
      ${hasRef ? buildInlineRefTable(data.reference_cols, data.reference_rows) : ''}
      <div class="message-time">${now()}</div>
    </div>`;

  chatMessages.appendChild(div);

  div.querySelector('.show-sql-btn')  ?.addEventListener('click', () => showSqlPanel(data.sql, data.rowcount));
  div.querySelector('.show-table-btn')?.addEventListener('click', () => showDataTable(data.columns, data.rows, data.rowcount));

  scrollBottom();
}

// ── Inline reference table (ground truth) ────────────────────
function buildInlineRefTable(cols, rows) {
  if (!cols.length || !rows.length) return '';

  // Decide which columns to show inline (max 6 most useful)
  const priority = ['name','product_name','sku','erp_unit_price','market_price_avg',
                    'market_price_min','market_price_max','availability','market_availability',
                    'qty_in_stock','category','status','total_amount','customer_name',
                    'first_name','last_name','salary','department'];
  let displayCols = cols.filter(c => priority.includes(c));
  if (displayCols.length === 0) displayCols = cols.slice(0, 6);
  else if (displayCols.length > 7) displayCols = displayCols.slice(0, 7);

  let html = `
    <div class="ref-table-wrap">
      <div class="ref-table-header">
        <span>📋 Ground Truth — Reference Records</span>
        <span class="ref-count">${rows.length} record${rows.length !== 1 ? 's' : ''}</span>
      </div>
      <div class="ref-table-scroll">
        <table class="ref-table">
          <thead><tr>`;
  displayCols.forEach(c => { html += `<th>${escapeHtml(c.replace(/_/g,' '))}</th>`; });
  html += '</tr></thead><tbody>';
  rows.forEach(row => {
    html += '<tr>';
    displayCols.forEach(c => {
      let val = row[c];
      if (val === null || val === undefined) val = '—';
      // Format prices nicely
      if (typeof val === 'number' && (c.includes('price') || c.includes('salary') || c.includes('amount'))) {
        val = '₹' + Number(val).toLocaleString('en-IN');
      }
      html += `<td>${escapeHtml(String(val))}</td>`;
    });
    html += '</tr>';
  });
  html += '</tbody></table></div></div>';
  return html;
}

// ── Main send ─────────────────────────────────────────────────
async function sendMessage() {
  const question = questionInput.value.trim();
  if (!question || isLoading) return;

  isLoading = true;
  sendBtn.disabled = true;
  questionInput.value = '';
  questionInput.style.height = 'auto';
  charCount.textContent = '0 / 500';

  appendUserMessage(question);
  const loadingEl = appendLoadingMessage();

  // Update loading text if scraping might happen
  const scrapeKeywords = ['price','market','stock','inventory','product','buy','cost','availability'];
  if (scrapeKeywords.some(k => question.toLowerCase().includes(k))) {
    setTimeout(() => {
      const label = loadingEl.querySelector('.loading-label');
      if (label) label.textContent = 'Checking market data...';
    }, 2000);
    setTimeout(() => {
      const label = loadingEl.querySelector('.loading-label');
      if (label) label.textContent = 'Generating answer...';
    }, 5000);
  }

  try {
    const res  = await fetch('/api/chat', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ question }),
    });
    const data = await res.json();

    loadingEl.remove();
    appendBotMessage(data);

    queryCount++;
    totalRows += data.rowcount || 0;
    statQueries.textContent = queryCount;
    statRows.textContent    = totalRows.toLocaleString('en-IN');

    if (data.sql && data.sql !== 'CANNOT_ANSWER' && !data.error) {
      showSqlPanel(data.sql, data.rowcount);
    }
  } catch (err) {
    loadingEl.remove();
    appendBotMessage({
      answer: 'Network error. Please check your connection and try again.',
      sql: '', rowcount: 0, columns: [], rows: [],
      reference_cols: [], reference_rows: [], enrich_note: '',
      error: err.message,
    });
  } finally {
    isLoading = false;
    sendBtn.disabled = false;
    questionInput.focus();
  }
}

// ── Utilities ─────────────────────────────────────────────────
function scrollBottom() {
  requestAnimationFrame(() => { chatMessages.scrollTop = chatMessages.scrollHeight; });
}
function now() {
  return new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
}
function escapeHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
function formatAnswer(text) {
  return escapeHtml(text)
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\n/g, '<br>');
}
