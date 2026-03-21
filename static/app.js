/* ============================================================
   ERP Intelligence — Frontend JS
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

// ============================================================
// Health check on load
// ============================================================
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

// Auto-resize textarea

questionInput.addEventListener('input', () => {
  questionInput.style.height = 'auto';
  questionInput.style.height = Math.min(questionInput.scrollHeight, 120) + 'px';
  const len = questionInput.value.length;
  charCount.textContent = `${len} / 500`;
  sendBtn.disabled = len === 0 || len > 500 || isLoading;
});


// Enter key handling

questionInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    if (!sendBtn.disabled) sendMessage();
  }
});

sendBtn.addEventListener('click', sendMessage);


// Sample questions

document.querySelectorAll('.sample-q').forEach(btn => {
  btn.addEventListener('click', () => {
    questionInput.value = btn.dataset.question;
    questionInput.dispatchEvent(new Event('input'));
    questionInput.focus();
  });
});


// Clear chat

clearBtn.addEventListener('click', async () => {
  await fetch('/api/clear', { method: 'POST' });
  // Remove all messages except welcome
  const msgs = chatMessages.querySelectorAll('.message:not(.welcome-message)');
  msgs.forEach(m => m.remove());
  queryCount = 0;
  totalRows  = 0;
  statQueries.textContent = '0';
  statRows.textContent    = '0';
  sqlPanel.classList.remove('visible');
});


// Schema modal

schemaBtn.addEventListener('click', async () => {
  schemaModal.classList.add('visible');
  if (schemaBody.textContent === 'Loading schema...') {
    const res  = await fetch('/api/schema');
    const data = await res.json();
    schemaBody.textContent = data.schema;
  }
});
schemaClose.addEventListener('click', () => schemaModal.classList.remove('visible'));
schemaModal.addEventListener('click', (e) => {
  if (e.target === schemaModal) schemaModal.classList.remove('visible');
});


// SQL panel

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


// Data table modal

tableClose.addEventListener('click', () => tableModal.classList.remove('visible'));
tableModal.addEventListener('click', (e) => {
  if (e.target === tableModal) tableModal.classList.remove('visible');
});

function showDataTable(columns, rows, rowcount) {
  tableModalTitle.textContent = `Query Results — ${rowcount} row${rowcount !== 1 ? 's' : ''}`;

  if (!columns.length) {
    dataTableWrapper.innerHTML = '<p style="color:var(--text-2)">No data returned.</p>';
  } else {
    const table = document.createElement('table');
    table.className = 'data-table';

    // Header
    const thead = document.createElement('thead');
    const trh   = document.createElement('tr');
    columns.forEach(col => {
      const th = document.createElement('th');
      th.textContent = col;
      trh.appendChild(th);
    });
    thead.appendChild(trh);
    table.appendChild(thead);

    // Body
    const tbody = document.createElement('tbody');
    rows.forEach(row => {
      const tr = document.createElement('tr');
      columns.forEach(col => {
        const td = document.createElement('td');
        const val = row[col];
        td.textContent = val === null ? '—' : String(val);
        td.title = val === null ? '' : String(val);
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
    table.appendChild(tbody);
    dataTableWrapper.innerHTML = '';
    dataTableWrapper.appendChild(table);

    if (rowcount > rows.length) {
      const note = document.createElement('p');
      note.className = 'table-note';
      note.textContent = `Showing first ${rows.length} of ${rowcount} rows.`;
      dataTableWrapper.appendChild(note);
    }
  }
  tableModal.classList.add('visible');
}


// Append message helpers

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
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
        <circle cx="12" cy="12" r="10"/>
      </svg>
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
  const hasResults = data.columns && data.columns.length > 0;

  let actionsHtml = '';
  if (data.sql) {
    actionsHtml += `
      <button class="msg-action-btn show-sql-btn">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>
        </svg>
        View SQL
      </button>`;
  }
  if (hasResults) {
    actionsHtml += `
      <button class="msg-action-btn show-table-btn">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/>
        </svg>
        View Table (${data.rowcount} rows)
      </button>`;
  }

  div.innerHTML = `
    <div class="message-avatar bot-avatar">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
    </div>
    <div class="message-content">
      ${hasError ? `<div class="error-badge">⚠ Query had an issue</div>` : ''}
      <div class="message-text">${formatAnswer(data.answer)}</div>
      ${actionsHtml ? `<div class="message-actions">${actionsHtml}</div>` : ''}
      <div class="message-time">${now()}</div>
    </div>`;

  chatMessages.appendChild(div);

  // Wire up buttons
  const sqlBtn   = div.querySelector('.show-sql-btn');
  const tableBtn = div.querySelector('.show-table-btn');
  if (sqlBtn)   sqlBtn.addEventListener('click',   () => showSqlPanel(data.sql, data.rowcount));
  if (tableBtn) tableBtn.addEventListener('click', () => showDataTable(data.columns, data.rows, data.rowcount));

  scrollBottom();
}


// Main send function

async function sendMessage() {
  const question = questionInput.value.trim();
  if (!question || isLoading) return;

  isLoading = true;
  sendBtn.disabled = true;

  // Reset input
  questionInput.value = '';
  questionInput.style.height = 'auto';
  charCount.textContent = '0 / 500';

  appendUserMessage(question);
  const loadingEl = appendLoadingMessage();

  try {
    const res  = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question }),
    });
    const data = await res.json();

    loadingEl.remove();
    appendBotMessage(data);

    // Update stats
    queryCount++;
    totalRows += data.rowcount || 0;
    statQueries.textContent = queryCount;
    statRows.textContent    = totalRows.toLocaleString('en-IN');

    // Auto-show SQL panel for valid queries
    if (data.sql && data.sql !== 'CANNOT_ANSWER' && !data.error) {
      showSqlPanel(data.sql, data.rowcount);
    }

  } catch (err) {
    loadingEl.remove();
    appendBotMessage({
      answer: 'Network error. Please check your connection and try again.',
      sql: '', rowcount: 0, columns: [], rows: [],
      error: err.message,
    });
  } finally {
    isLoading = false;
    sendBtn.disabled = false;
    questionInput.focus();
  }
}


// Utilities

function scrollBottom() {
  requestAnimationFrame(() => {
    chatMessages.scrollTop = chatMessages.scrollHeight;
  });
}

function now() {
  return new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
}

function escapeHtml(str) {
  return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
            .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

function formatAnswer(text) {
  // Convert newlines to <br>, bold **text**, and keep it clean
  return escapeHtml(text)
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\n/g, '<br>');
}
