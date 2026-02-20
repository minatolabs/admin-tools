/* =============================================
   AssistAI — Frontend Logic
   Session data stored in sessionStorage only.
   Closing this tab destroys all data.
   ============================================= */

const SESSION_KEY = "assistai_current";

// ---- Ollama health check ----
async function checkHealth() {
  try {
    const res = await fetch("/api/health");
    const data = await res.json();
    const badge = document.getElementById("ollama-status");
    if (data.ollama === "connected") {
      badge.textContent = "● Ollama Connected";
      badge.className = "status-badge status-ok";
    } else {
      badge.textContent = "● Ollama Unavailable (fallback mode)";
      badge.className = "status-badge status-error";
    }
  } catch {
    const badge = document.getElementById("ollama-status");
    badge.textContent = "● API Unreachable";
    badge.className = "status-badge status-error";
  }
}

// ---- Main parse function ----
async function parseInput() {
  const text = document.getElementById("input-text").value.trim();
  const hireTypeOverride = document.getElementById("hire-type-override").value;
  const errDiv = document.getElementById("parse-error");

  errDiv.style.display = "none";
  errDiv.textContent = "";

  if (!text) {
    errDiv.textContent = "Please paste an email or Spiceworks ticket first.";
    errDiv.style.display = "block";
    return;
  }

  setParseLoading(true);

  try {
    const res = await fetch("/api/parse", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, hire_type_override: hireTypeOverride || null }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || `Server error: ${res.status}`);
    }

    const data = await res.json();

    // Inject checked state from sessionStorage if available
    const saved = loadSession();
    if (saved && saved.tasks) {
      const savedChecked = {};
      saved.tasks.forEach((t, i) => { savedChecked[t.name + i] = t.checked; });
      data.tasks.forEach((t, i) => {
        const key = t.name + i;
        if (key in savedChecked) t.checked = savedChecked[key];
      });
    }

    saveSession(data);
    renderResults(data);

  } catch (err) {
    errDiv.textContent = err.message || "An unexpected error occurred.";
    errDiv.style.display = "block";
  } finally {
    setParseLoading(false);
  }
}

function setParseLoading(loading) {
  const btn = document.getElementById("parse-btn");
  const label = document.getElementById("parse-btn-label");
  const spinner = document.getElementById("parse-spinner");
  btn.disabled = loading;
  label.style.display = loading ? "none" : "inline";
  spinner.style.display = loading ? "inline-block" : "none";
}

// ---- Render results ----
function renderResults(data) {
  renderEmployeeCard(data.employee);
  renderChecklist(data.tasks);
  renderSkipped(data.skipped || []);
  updateProgress(data.tasks);

  document.getElementById("results-section").style.display = "block";
  document.getElementById("clear-btn").style.display = "inline-flex";
  document.getElementById("results-section").scrollIntoView({ behavior: "smooth", block: "start" });
}

function renderEmployeeCard(emp) {
  if (!emp) return;

  const name = emp.preferred_name || emp.name || "Unknown Employee";
  document.getElementById("emp-name").textContent = name;
  document.getElementById("emp-position").textContent = [emp.position, emp.role ? `(${emp.role})` : null].filter(Boolean).join(" ");
  document.getElementById("emp-start").textContent = emp.start_date || "—";
  document.getElementById("emp-manager").textContent = emp.manager || "—";
  document.getElementById("emp-location").textContent = emp.location || "—";

  // Avatar initials
  const initials = name.split(" ").map(w => w[0]).slice(0, 2).join("").toUpperCase();
  document.getElementById("employee-avatar").textContent = initials || "?";

  // Hire type badge
  const hireBadge = document.getElementById("emp-hire-badge");
  hireBadge.textContent = emp.hire_type === "RNH" ? "RNH — Retail New Hire" : emp.hire_type === "CNH" ? "CNH — Corporate New Hire" : emp.hire_type || "—";

  // Scope badge
  const scopeBadge = document.getElementById("emp-scope-badge");
  const isIntl = (emp.scope || "").toLowerCase() === "international";
  scopeBadge.textContent = isIntl ? "🌐 International" : "🏠 Domestic";
  scopeBadge.className = `badge ${isIntl ? "badge-scope-international" : "badge-scope-domestic"}`;

  // Company badge
  const compBadge = document.getElementById("emp-company-badge");
  compBadge.textContent = emp.company_name ? `${emp.company_code} — ${emp.company_name}` : emp.company_code || "—";
}

function renderChecklist(tasks) {
  const container = document.getElementById("checklist-container");
  container.innerHTML = "";

  if (!tasks || tasks.length === 0) {
    container.innerHTML = '<div class="card"><p style="color:var(--text-muted)">No tasks generated.</p></div>';
    return;
  }

  // Group by category
  const categories = {};
  tasks.forEach((task, idx) => {
    const cat = task.category || "General";
    if (!categories[cat]) categories[cat] = [];
    categories[cat].push({ ...task, _idx: idx });
  });

  Object.entries(categories).forEach(([category, catTasks]) => {
    const card = document.createElement("div");
    card.className = "category-card";

    const header = document.createElement("div");
    header.className = "category-header";
    header.innerHTML = `
      <span class="category-title">${escHtml(category)}</span>
      <span class="category-count">${catTasks.length} task${catTasks.length !== 1 ? "s" : ""}</span>
    `;
    card.appendChild(header);

    const ul = document.createElement("ul");
    ul.className = "task-list";

    catTasks.forEach(task => {
      ul.appendChild(renderTaskItem(task));
    });

    card.appendChild(ul);
    container.appendChild(card);
  });
}

function renderTaskItem(task) {
  const li = document.createElement("li");
  li.className = `task-item${task.checked ? " completed" : ""}`;
  li.dataset.idx = task._idx;

  const checkbox = document.createElement("div");
  checkbox.className = `task-checkbox${task.checked ? " checked" : ""}`;

  const priorityDot = document.createElement("div");
  const pClass = task.priority === 1 ? "p1" : task.priority === 2 ? "p2" : "p3";
  priorityDot.className = `priority-dot ${pClass}`;

  const body = document.createElement("div");
  body.className = "task-body";

  let bodyHtml = `<div class="task-name">${escHtml(task.name)}</div>`;

  if (task.subtasks && task.subtasks.length > 0) {
    bodyHtml += `<div class="task-subtasks">`;
    task.subtasks.forEach(sub => {
      bodyHtml += `<div class="task-subtask">↳ ${escHtml(sub)}</div>`;
    });
    bodyHtml += `</div>`;
  }

  if (task.details) {
    bodyHtml += `<div class="task-details">${escHtml(task.details)}</div>`;
  }

  body.innerHTML = bodyHtml;

  li.appendChild(checkbox);
  li.appendChild(priorityDot);
  li.appendChild(body);

  li.addEventListener("click", () => toggleTask(task._idx));

  return li;
}

function renderSkipped(skipped) {
  const section = document.getElementById("skipped-section");
  const list = document.getElementById("skipped-list");
  list.innerHTML = "";

  if (!skipped || skipped.length === 0) {
    section.style.display = "none";
    return;
  }

  skipped.forEach(item => {
    const li = document.createElement("li");
    li.className = "skipped-item";
    const val = item.value !== null && item.value !== undefined ? ` — "${escHtml(String(item.value))}"` : "";
    li.textContent = escHtml(item.field) + val;
    list.appendChild(li);
  });

  section.style.display = "block";
}

// ---- Task toggle ----
function toggleTask(idx) {
  const session = loadSession();
  if (!session || !session.tasks) return;

  session.tasks[idx].checked = !session.tasks[idx].checked;
  saveSession(session);

  // Update DOM
  const li = document.querySelector(`.task-item[data-idx="${idx}"]`);
  if (li) {
    const checked = session.tasks[idx].checked;
    li.classList.toggle("completed", checked);
    li.querySelector(".task-checkbox").classList.toggle("checked", checked);
  }

  updateProgress(session.tasks);
}

// ---- Progress bar ----
function updateProgress(tasks) {
  if (!tasks || tasks.length === 0) return;
  const total = tasks.length;
  const done = tasks.filter(t => t.checked).length;
  const pct = Math.round((done / total) * 100);

  document.getElementById("progress-label").textContent = `${done} / ${total} tasks complete`;
  document.getElementById("progress-bar-fill").style.width = `${pct}%`;
}

// ---- Session storage ----
function saveSession(data) {
  try {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(data));
  } catch {
    // sessionStorage not available (private browsing etc.)
  }
}

function loadSession() {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function clearSession() {
  try {
    sessionStorage.removeItem(SESSION_KEY);
  } catch {}
  document.getElementById("results-section").style.display = "none";
  document.getElementById("clear-btn").style.display = "none";
  document.getElementById("input-text").value = "";
  document.getElementById("hire-type-override").value = "";
  document.getElementById("parse-error").style.display = "none";
  document.getElementById("checklist-container").innerHTML = "";
}

// ---- Restore session on page load ----
function restoreSession() {
  const data = loadSession();
  if (data) {
    renderResults(data);
  }
}

// ---- Utility ----
function escHtml(str) {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// ---- Init ----
document.addEventListener("DOMContentLoaded", () => {
  checkHealth();
  setInterval(checkHealth, 30000);
  restoreSession();

  // Parse on Ctrl+Enter in textarea
  document.getElementById("input-text").addEventListener("keydown", e => {
    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      parseInput();
    }
  });
});
