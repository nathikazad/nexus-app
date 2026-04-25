// ───────────────────────────────────────────────────────────────────────
// nx_cooking — mobile prototype
// ───────────────────────────────────────────────────────────────────────

// Today is fixed for the prototype so seed data lines up predictably.
const TODAY = new Date(2026, 3, 28); // Apr 28, 2026 (Tuesday)
const NOW = new Date(2026, 3, 28, 11, 30);

// ── seed data ─────────────────────────────────────────────────────────
let _id = 1;
const id = () => `id${_id++}`;

const ITEMS = [
  { id: 'i_spaghetti',  name: 'Spaghetti' },
  { id: 'i_eggs',       name: 'Eggs' },
  { id: 'i_bacon',      name: 'Bacon' },
  { id: 'i_pecorino',   name: 'Pecorino Romano' },
  { id: 'i_pepper',     name: 'Black pepper' },
  { id: 'i_chicken',    name: 'Chicken thighs' },
  { id: 'i_soy',        name: 'Soy sauce' },
  { id: 'i_garlic',     name: 'Garlic' },
  { id: 'i_onion',      name: 'Onion' },
  { id: 'i_bell',       name: 'Bell pepper' },
  { id: 'i_oil',        name: 'Olive oil' },
  { id: 'i_tomato',     name: 'Tomato' },
  { id: 'i_basil',      name: 'Basil' },
  { id: 'i_rice',       name: 'Rice' },
  { id: 'i_cilantro',   name: 'Cilantro' },
  { id: 'i_lime',       name: 'Lime' },
  { id: 'i_lettuce',    name: 'Romaine lettuce' },
  { id: 'i_parmesan',   name: 'Parmesan' },
  { id: 'i_anchovy',    name: 'Anchovy fillets' },
];

const RECIPES = [
  {
    id: 'r_carb',
    name: 'Pasta Carbonara',
    instructions: '1. Boil pasta in salted water until al dente.\n2. Whisk eggs with grated pecorino and black pepper.\n3. Crisp bacon, kill heat.\n4. Toss hot pasta with bacon, then with egg mixture off-heat.\n5. Loosen with pasta water.',
    ingredients: [
      { itemId: 'i_spaghetti', qty: 500, unit: 'g' },
      { itemId: 'i_eggs',      qty: 4,   unit: 'whole' },
      { itemId: 'i_bacon',     qty: 200, unit: 'g' },
      { itemId: 'i_pecorino',  qty: 80,  unit: 'g' },
      { itemId: 'i_pepper',    qty: 1,   unit: 'tsp' },
    ],
    lastCooked: new Date(2026, 3, 24),
  },
  {
    id: 'r_stirfry',
    name: 'Chicken Stir Fry',
    instructions: '1. Slice chicken thin.\n2. Sear in hot oil until just done.\n3. Toss in garlic + veg.\n4. Splash soy sauce, finish with rice.',
    ingredients: [
      { itemId: 'i_chicken', qty: 500, unit: 'g' },
      { itemId: 'i_soy',     qty: 3,   unit: 'tbsp' },
      { itemId: 'i_garlic',  qty: 4,   unit: 'cloves' },
      { itemId: 'i_onion',   qty: 1,   unit: 'whole' },
      { itemId: 'i_bell',    qty: 2,   unit: 'whole' },
      { itemId: 'i_oil',     qty: 2,   unit: 'tbsp' },
      { itemId: 'i_rice',    qty: 1.5, unit: 'cup' },
    ],
    lastCooked: new Date(2026, 3, 21),
  },
  {
    id: 'r_caesar',
    name: 'Caesar Salad',
    instructions: '1. Tear lettuce.\n2. Whisk anchovy paste, garlic, lemon, oil.\n3. Toss, top with parmesan.',
    ingredients: [
      { itemId: 'i_lettuce',  qty: 1,   unit: 'whole' },
      { itemId: 'i_parmesan', qty: 60,  unit: 'g' },
      { itemId: 'i_anchovy',  qty: 4,   unit: 'fillets' },
      { itemId: 'i_garlic',   qty: 2,   unit: 'cloves' },
      { itemId: 'i_oil',      qty: 3,   unit: 'tbsp' },
    ],
    lastCooked: null,
  },
  {
    id: 'r_pomodoro',
    name: 'Pasta Pomodoro',
    instructions: '1. Sweat garlic in oil.\n2. Add tomatoes, simmer 15m.\n3. Toss with pasta, finish with basil.',
    ingredients: [
      { itemId: 'i_spaghetti', qty: 400, unit: 'g' },
      { itemId: 'i_tomato',    qty: 800, unit: 'g' },
      { itemId: 'i_basil',     qty: 1,   unit: 'bunch' },
      { itemId: 'i_garlic',    qty: 3,   unit: 'cloves' },
      { itemId: 'i_oil',       qty: 2,   unit: 'tbsp' },
    ],
    lastCooked: new Date(2026, 3, 14),
  },
  {
    id: 'r_friedrice',
    name: 'Quick Fried Rice',
    instructions: '1. Wok hot, oil shimmering.\n2. Egg first, scramble out.\n3. Rice, soy, scallion. Reintroduce egg.',
    ingredients: [
      { itemId: 'i_rice',     qty: 3,   unit: 'cup' },
      { itemId: 'i_eggs',     qty: 3,   unit: 'whole' },
      { itemId: 'i_soy',      qty: 2,   unit: 'tbsp' },
      { itemId: 'i_garlic',   qty: 2,   unit: 'cloves' },
      { itemId: 'i_oil',      qty: 2,   unit: 'tbsp' },
    ],
    lastCooked: new Date(2026, 3, 27),
  },
];

// helpers for date math (work in local time)
function ymd(d) { return d.toISOString().slice(0,10); }
function addDays(d, n) { const x = new Date(d); x.setDate(x.getDate() + n); return x; }
function mondayOf(d) {
  const x = new Date(d); x.setHours(0,0,0,0);
  const dow = (x.getDay() + 6) % 7; // Mon=0
  return addDays(x, -dow);
}
function sameDay(a, b) { return ymd(a) === ymd(b); }
function fmtDow(d) { return ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d.getDay()]; }
function fmtDowLong(d) { return ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][d.getDay()]; }
function fmtMon(d) { return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getMonth()]; }
function fmtMonLong(d) { return ['January','February','March','April','May','June','July','August','September','October','November','December'][d.getMonth()]; }
function fmtMonDay(d) { return `${fmtMon(d)} ${d.getDate()}`; }
function fmtRelDay(d) {
  const days = Math.round((d - TODAY) / 86400000);
  if (days === 0) return 'Today';
  if (days === 1) return 'Tomorrow';
  if (days === -1) return 'Yesterday';
  if (days > 0) return `in ${days}d`;
  return `${-days}d ago`;
}
function fmtDuration(mins) {
  const h = Math.floor(mins / 60);
  const m = Math.round(mins % 60);
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
}
function relTime(d) {
  if (!d) return 'never cooked';
  const days = Math.round((TODAY - d) / 86400000);
  if (days === 0) return 'cooked today';
  if (days === 1) return 'cooked yesterday';
  if (days < 7) return `cooked ${days}d ago`;
  if (days < 30) return `cooked ${Math.round(days/7)}w ago`;
  return `cooked ${Math.round(days/30)}mo ago`;
}
function timeStr(d) {
  if (!d) return '';
  const h = d.getHours(), m = d.getMinutes();
  return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;
}
function parseTimeToDate(timeStr, baseDate) {
  if (!timeStr) return null;
  const [h, m] = timeStr.split(':').map(Number);
  const d = new Date(baseDate); d.setHours(h, m, 0, 0); return d;
}

// cooking tasks — seed across this week
const TASKS = [
  {
    id: 't1', recipeId: 'r_carb',
    date: ymd(TODAY), // Tue Apr 28
    status: 'cooking',
    ingredientChecks: { i_spaghetti: true, i_eggs: true, i_pecorino: true, i_pepper: true, i_bacon: false },
  },
  {
    id: 't2', recipeId: 'r_stirfry',
    date: ymd(addDays(TODAY, 2)), // Thu Apr 30
    status: 'planned',
    ingredientChecks: { i_chicken: true, i_garlic: true, i_oil: true },
  },
  {
    id: 't3', recipeId: 'r_caesar',
    date: ymd(addDays(TODAY, -1)), // Mon Apr 27
    status: 'done',
    ingredientChecks: { i_lettuce: true, i_parmesan: true, i_anchovy: true, i_garlic: true, i_oil: true },
  },
  {
    id: 't4', recipeId: 'r_pomodoro',
    date: ymd(addDays(TODAY, 4)), // Sat May 2
    status: 'planned',
    ingredientChecks: {},
  },
  {
    id: 't5', recipeId: 'r_friedrice',
    date: ymd(addDays(TODAY, -1)), // Mon Apr 27
    status: 'skipped',
    ingredientChecks: {},
  },
];

const ACTIONS = [
  { id: 'a1', taskId: 't3', recipeId: 'r_caesar',
    start: new Date(2026,3,27,19,15), end: new Date(2026,3,27,19,45),
    modifications: 'used kale instead of romaine', outcome: 'a bit bitter, dressing was great' },
  // task t1 is currently cooking — open action
  { id: 'a2', taskId: 't1', recipeId: 'r_carb',
    start: new Date(2026,3,28,11,0), end: null,
    modifications: '', outcome: '' },
];

// ── state ─────────────────────────────────────────────────────────────
const state = {
  tab: 'week',                                // 'week' | 'recipes' | 'buy' | 'stats'
  weekStart: mondayOf(TODAY),                 // shared Week/Buy/Stats
  selectedDay: ymd(TODAY),
  recipeNav: { id: null, editing: false },
  taskNav: { id: null },
  recipeSearch: '',
  recipeSort: 'recent',                       // 'recent' | 'alpha'
  // ephemeral sheet state
  pendingTaskId: null,
  calMonth: new Date(TODAY.getFullYear(), TODAY.getMonth(), 1),
  calMode: null,                              // 'add' (for recipe → task) | 'move' (for task)
  calContextRecipeId: null,
  pickerCallback: null,
};

// ── lookup helpers ────────────────────────────────────────────────────
const recipeById = id => RECIPES.find(r => r.id === id);
const itemById = id => ITEMS.find(i => i.id === id);
const taskById = id => TASKS.find(t => t.id === id);
const tasksOnDate = ymdStr => TASKS.filter(t => t.date === ymdStr);
const tasksInWeek = (start) => {
  const days = [...Array(7)].map((_, i) => ymd(addDays(start, i)));
  return TASKS.filter(t => days.includes(t.date));
};
const actionsInWeek = (start) => {
  const end = addDays(start, 7);
  return ACTIONS.filter(a => a.start >= start && a.start < end && a.end);
};

// ── chrome control ────────────────────────────────────────────────────
const $ = sel => document.querySelector(sel);
const content = $('#content');

function setChrome() {
  const inDetail = state.tab === 'recipes' && state.recipeNav.id;
  const inTaskDetail = state.tab === 'week' && state.taskNav.id;

  // back button
  const back = $('#back-btn');
  back.hidden = !(inDetail || inTaskDetail);

  // logo / title
  const logo = $('#logo');
  const title = $('#top-title');
  if (inDetail || inTaskDetail) {
    logo.hidden = true;
    title.hidden = false;
    if (inTaskDetail) {
      const t = taskById(state.taskNav.id);
      title.textContent = t ? recipeById(t.recipeId).name : '';
    } else if (state.recipeNav.editing) {
      title.textContent = state.recipeNav.id === 'new' ? 'New recipe' : 'Edit recipe';
    } else {
      const r = recipeById(state.recipeNav.id);
      title.textContent = r ? r.name : '';
    }
  } else {
    logo.hidden = false;
    title.hidden = true;
  }

  // overflow button (recipe detail or task detail only)
  $('#overflow-btn').hidden = !((inDetail && !state.recipeNav.editing) || inTaskDetail);

  // subheader strips
  const showWeekStrip = (state.tab === 'buy' || state.tab === 'stats') ||
                        (state.tab === 'week' && !inTaskDetail);
  $('#week-strip').classList.toggle('hidden', !showWeekStrip);

  $('#day-strip').classList.toggle('hidden', state.tab !== 'week' || inTaskDetail);

  $('#search-wrap').classList.toggle('hidden',
    state.tab !== 'recipes' || inDetail);

  // FAB only on recipes list
  $('#fab').classList.toggle('hidden',
    state.tab !== 'recipes' || inDetail);

  // bottom nav active state
  document.querySelectorAll('.nav-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.tab === state.tab);
  });

  // week-strip text
  const ws = state.weekStart;
  const we = addDays(ws, 6);
  const sameMonth = ws.getMonth() === we.getMonth();
  $('#week-title').textContent = `Week of ${fmtMonDay(ws)}`;
  $('#week-sub').textContent = sameMonth
    ? `${fmtMon(ws)} ${ws.getDate()} – ${we.getDate()}`
    : `${fmtMonDay(ws)} – ${fmtMonDay(we)}`;
}

// ── render dispatch ───────────────────────────────────────────────────
function render() {
  setChrome();
  if (state.tab === 'week') {
    if (state.taskNav.id) renderTaskDetail();
    else { renderDayStrip(); renderWeekDay(); }
  } else if (state.tab === 'recipes') {
    if (state.recipeNav.editing) renderRecipeEdit();
    else if (state.recipeNav.id) renderRecipeDetail();
    else renderRecipesList();
  } else if (state.tab === 'buy') {
    renderBuyList();
  } else if (state.tab === 'stats') {
    renderStats();
  }
}

// ── Week tab ──────────────────────────────────────────────────────────
function renderDayStrip() {
  const strip = $('#day-strip');
  strip.innerHTML = '';
  for (let i = 0; i < 7; i++) {
    const d = addDays(state.weekStart, i);
    const dymd = ymd(d);
    const has = tasksOnDate(dymd).length > 0;
    const pill = document.createElement('button');
    pill.className = 'day-pill';
    if (sameDay(d, TODAY)) pill.classList.add('today');
    if (state.selectedDay === dymd) pill.classList.add('selected');
    if (has) pill.classList.add('has-tasks');
    pill.innerHTML = `
      <span class="dow">${fmtDow(d)}</span>
      <span class="num">${d.getDate()}</span>
      <span class="dot"></span>
    `;
    pill.onclick = () => { state.selectedDay = dymd; render(); };
    strip.appendChild(pill);
  }
}

function renderWeekDay() {
  const d = new Date(state.selectedDay);
  const tasks = tasksOnDate(state.selectedDay);

  let html = `
    <div class="section-head" style="padding-top:12px">
      <span>${fmtDowLong(d)} · ${fmtMonDay(d)}</span>
      <span class="count">${tasks.length} ${tasks.length === 1 ? 'meal' : 'meals'}</span>
    </div>
  `;

  if (tasks.length === 0) {
    html += `<div class="empty">Nothing planned for ${fmtDowLong(d).toLowerCase()}.<br/>Schedule a recipe from the Recipes tab.</div>`;
  } else {
    // chips summary
    const counts = { planned:0, cooking:0, done:0, skipped:0 };
    tasks.forEach(t => counts[t.status]++);
    html += `<div class="day-summary">`;
    if (counts.planned) html += `<span class="summary-chip planned">${counts.planned} <span class="lbl">planned</span></span>`;
    if (counts.cooking) html += `<span class="summary-chip cooking">${counts.cooking} <span class="lbl">cooking</span></span>`;
    if (counts.done)    html += `<span class="summary-chip done">${counts.done} <span class="lbl">done</span></span>`;
    if (counts.skipped) html += `<span class="summary-chip skipped">${counts.skipped} <span class="lbl">skipped</span></span>`;
    html += `</div>`;

    html += tasks.map(t => taskRowHtml(t)).join('');
  }

  content.innerHTML = html;

  // wire click handlers
  content.querySelectorAll('.task-row').forEach(el => {
    const tid = el.dataset.taskId;
    el.onclick = () => { state.taskNav.id = tid; render(); };
    let pressTimer;
    el.addEventListener('touchstart', () => {
      pressTimer = setTimeout(() => { state.pendingTaskId = tid; openSheet('sheet-task'); }, 500);
    });
    el.addEventListener('touchend', () => clearTimeout(pressTimer));
    el.addEventListener('touchmove', () => clearTimeout(pressTimer));
  });
}

function taskRowHtml(t) {
  const r = recipeById(t.recipeId);
  const ings = r.ingredients;
  const checked = ings.filter(i => t.ingredientChecks[i.itemId]).length;
  const pct = ings.length ? (checked / ings.length) * 100 : 0;
  const action = ACTIONS.find(a => a.taskId === t.id);
  let timeText = '';
  if (t.status === 'cooking' && action) {
    timeText = `cooking since ${timeStr(action.start)}`;
  } else if (t.status === 'done' && action && action.end) {
    timeText = `${fmtDuration((action.end - action.start) / 60000)} · ${timeStr(action.start)}`;
  } else if (t.status === 'planned') {
    timeText = `${ings.length} ingredients`;
  } else if (t.status === 'skipped') {
    timeText = 'skipped';
  }
  return `
    <div class="task-row ${t.status}" data-task-id="${t.id}">
      <span class="status-dot"></span>
      <div class="main">
        <div class="name">${r.name}</div>
        <div class="meta">
          <span>${timeText}</span>
          ${t.status === 'planned' || t.status === 'cooking' ? `
            <span class="dot-sep">·</span>
            <span class="progress">
              <span class="mini-bar"><span class="fill" style="width:${pct}%"></span></span>
              <span>${checked}/${ings.length} bought</span>
            </span>
          ` : ''}
        </div>
      </div>
      <span class="chev">›</span>
    </div>
  `;
}

// ── Cooking-task detail ───────────────────────────────────────────────
function renderTaskDetail() {
  const t = taskById(state.taskNav.id);
  if (!t) { state.taskNav.id = null; render(); return; }
  const r = recipeById(t.recipeId);
  const date = new Date(t.date);
  const action = ACTIONS.find(a => a.taskId === t.id);

  let footer = '';
  if (t.status === 'planned') {
    footer = `
      <div class="action-bar">
        <button class="btn warn" data-act="skip">Skip</button>
        <button class="btn secondary" data-act="markdone">Mark done</button>
        <button class="btn primary" data-act="start">Start cooking</button>
      </div>`;
  } else if (t.status === 'cooking') {
    footer = `
      <div class="action-bar">
        <button class="btn secondary" data-act="cancel">Cancel</button>
        <button class="btn ok" data-act="markdone">Mark done</button>
      </div>`;
  } else if (t.status === 'done') {
    footer = `
      <div class="action-bar">
        <button class="btn secondary" data-act="editlog">Edit log</button>
      </div>`;
  } else if (t.status === 'skipped') {
    footer = `
      <div class="action-bar">
        <button class="btn primary" data-act="restore">Restore to planned</button>
      </div>`;
  }

  const cookingMeta = action && t.status === 'cooking'
    ? `<span class="dot-sep">·</span><span>started ${timeStr(action.start)}</span>` : '';
  const doneMeta = action && t.status === 'done' && action.end
    ? `<span class="dot-sep">·</span><span>${fmtDuration((action.end - action.start) / 60000)}</span>` : '';

  content.innerHTML = `
    <div class="detail">
      <div class="photo">
        <span class="icon">🍽️</span>
        <span class="label">photo placeholder</span>
      </div>

      <h2 class="title">${r.name}</h2>
      <div class="subtitle">
        <span class="status-pill ${t.status}"><span class="dot"></span>${t.status}</span>
        <span class="dot-sep">·</span>
        <span>${fmtDowLong(date)} ${fmtMonDay(date)}</span>
        ${cookingMeta}${doneMeta}
      </div>

      <div class="sect-h"><span>Ingredients</span><span class="hint">tap to mark bought</span></div>
      <div class="ing-list">
        ${r.ingredients.map(ing => {
          const item = itemById(ing.itemId);
          const isChecked = !!t.ingredientChecks[ing.itemId];
          return `
            <div class="ing-row ${isChecked ? 'checked' : ''}" data-item-id="${ing.itemId}">
              <span class="check">✓</span>
              <span class="name">${item.name}</span>
              <span class="qty">${ing.qty} ${ing.unit}</span>
            </div>`;
        }).join('')}
      </div>

      ${r.instructions ? `
        <div class="sect-h"><span>Instructions</span><span class="hint">from recipe</span></div>
        <div class="notes-block">${r.instructions}</div>
      ` : ''}

      ${action && (action.modifications || action.outcome) ? `
        <div class="sect-h"><span>Cook log</span></div>
        <div class="notes-block ${!action.modifications && !action.outcome ? 'dim' : ''}">${
          [action.modifications && `Modifications: ${action.modifications}`,
           action.outcome && `Outcome: ${action.outcome}`].filter(Boolean).join('\n\n') || '—'
        }</div>
      ` : ''}

      ${footer}
    </div>
  `;

  // wire ingredient toggles
  content.querySelectorAll('.ing-row').forEach(el => {
    el.onclick = () => {
      const itemId = el.dataset.itemId;
      t.ingredientChecks[itemId] = !t.ingredientChecks[itemId];
      render();
    };
  });

  // wire footer actions
  content.querySelectorAll('.action-bar [data-act]').forEach(btn => {
    btn.onclick = () => handleTaskAction(t, btn.dataset.act);
  });
}

function handleTaskAction(t, act) {
  if (act === 'start') {
    // open start-time sheet
    state.pendingTaskId = t.id;
    $('#start-time').value = timeStr(NOW);
    openSheet('sheet-start');
  } else if (act === 'markdone') {
    state.pendingTaskId = t.id;
    const action = ACTIONS.find(a => a.taskId === t.id);
    if (action && !action.end) {
      // already started — only need end time
      $('#done-start-field').hidden = true;
      $('#done-end').value = timeStr(NOW);
    } else {
      $('#done-start-field').hidden = false;
      $('#done-start').value = timeStr(new Date(NOW.getTime() - 30*60000));
      $('#done-end').value = timeStr(NOW);
    }
    $('#done-mods').value = '';
    $('#done-outcome').value = '';
    openSheet('sheet-done');
  } else if (act === 'skip') {
    t.status = 'skipped';
    render();
  } else if (act === 'cancel') {
    // discard open action, revert to planned
    const idx = ACTIONS.findIndex(a => a.taskId === t.id && !a.end);
    if (idx >= 0) ACTIONS.splice(idx, 1);
    t.status = 'planned';
    render();
  } else if (act === 'restore') {
    t.status = 'planned';
    render();
  } else if (act === 'editlog') {
    state.pendingTaskId = t.id;
    const action = ACTIONS.find(a => a.taskId === t.id);
    $('#done-start-field').hidden = false;
    $('#done-start').value = action ? timeStr(action.start) : '';
    $('#done-end').value = action && action.end ? timeStr(action.end) : '';
    $('#done-mods').value = action ? action.modifications : '';
    $('#done-outcome').value = action ? action.outcome : '';
    openSheet('sheet-done');
  }
}

// ── Recipes list ──────────────────────────────────────────────────────
function renderRecipesList() {
  $('#recipe-search').value = state.recipeSearch;
  $('#sort-recent').classList.toggle('active', state.recipeSort === 'recent');
  $('#sort-alpha').classList.toggle('active', state.recipeSort === 'alpha');

  const q = state.recipeSearch.trim().toLowerCase();
  let list = RECIPES.filter(r => !q || r.name.toLowerCase().includes(q));
  list.sort((a, b) => {
    if (state.recipeSort === 'alpha') return a.name.localeCompare(b.name);
    // recent: nulls last, newest first
    const ax = a.lastCooked ? a.lastCooked.getTime() : -Infinity;
    const bx = b.lastCooked ? b.lastCooked.getTime() : -Infinity;
    return bx - ax;
  });

  if (list.length === 0) {
    content.innerHTML = `<div class="empty">${q ? 'No recipes match.' : 'No recipes yet. Tap + to add your first.'}</div>`;
    return;
  }

  content.innerHTML = list.map(r => `
    <div class="recipe-row" data-recipe-id="${r.id}">
      <div class="thumb">🍳</div>
      <div class="main">
        <div class="name">${r.name}</div>
        <div class="sub">
          <span>${r.ingredients.length} ingredients</span>
          <span class="dot-sep">·</span>
          <span>${relTime(r.lastCooked)}</span>
        </div>
      </div>
      <span class="chev">›</span>
    </div>
  `).join('');

  content.querySelectorAll('.recipe-row').forEach(el => {
    el.onclick = () => {
      state.recipeNav.id = el.dataset.recipeId;
      state.recipeNav.editing = false;
      render();
    };
  });
}

// ── Recipe detail (read-only) ─────────────────────────────────────────
function renderRecipeDetail() {
  const r = recipeById(state.recipeNav.id);
  if (!r) { state.recipeNav.id = null; render(); return; }

  content.innerHTML = `
    <div class="detail">
      <div class="photo">
        <span class="icon">🍳</span>
        <span class="label">photo placeholder</span>
      </div>

      <h2 class="title">${r.name}</h2>
      <div class="subtitle">
        <span>${r.ingredients.length} ingredients</span>
        <span class="dot-sep">·</span>
        <span>${relTime(r.lastCooked)}</span>
      </div>

      <div class="sect-h"><span>Ingredients</span></div>
      <div class="ing-list">
        ${r.ingredients.map(ing => {
          const item = itemById(ing.itemId);
          return `
            <div class="ing-row read-only">
              <span class="bullet"></span>
              <span class="name">${item.name}</span>
              <span class="qty">${ing.qty} ${ing.unit}</span>
            </div>`;
        }).join('')}
      </div>

      ${r.instructions ? `
        <div class="sect-h"><span>Instructions</span></div>
        <div class="notes-block">${r.instructions}</div>
      ` : ''}

      <div class="action-bar">
        <button class="btn secondary" data-act="addday">📅 Add to day</button>
        <button class="btn primary" data-act="cooknow">Cook now</button>
      </div>
    </div>
  `;

  content.querySelectorAll('.action-bar [data-act]').forEach(btn => {
    btn.onclick = () => {
      if (btn.dataset.act === 'cooknow') {
        const t = createTaskFromRecipe(r.id, ymd(TODAY));
        // jump straight into "starting" the task
        state.tab = 'week';
        state.selectedDay = ymd(TODAY);
        state.recipeNav.id = null;
        state.taskNav.id = t.id;
        // immediate start prompt
        state.pendingTaskId = t.id;
        $('#start-time').value = timeStr(NOW);
        render();
        openSheet('sheet-start');
      } else {
        state.calMode = 'add';
        state.calContextRecipeId = r.id;
        openCalendar();
      }
    };
  });
}

// ── Recipe edit (stub form) ───────────────────────────────────────────
function renderRecipeEdit() {
  const isNew = state.recipeNav.id === 'new';
  const r = isNew ? { name: '', instructions: '', ingredients: [] } : recipeById(state.recipeNav.id);
  if (!r) { state.recipeNav.id = null; state.recipeNav.editing = false; render(); return; }

  content.innerHTML = `
    <div class="detail" style="padding-top:8px">
      <div class="field"><label class="field-label">Name</label>
        <input id="edit-name" class="field-input" value="${r.name.replace(/"/g, '&quot;')}" placeholder="Recipe name" /></div>

      <div class="field" style="margin-top:14px"><label class="field-label">Instructions</label>
        <textarea id="edit-instructions" class="field-input" rows="5" placeholder="Cooking steps…">${r.instructions || ''}</textarea></div>

      <div class="sect-h"><span>Ingredients</span></div>
      <div id="edit-ings">
        ${r.ingredients.map((ing, i) => ingEditRowHtml(ing, i)).join('')}
      </div>
      <button class="add-ingredient" id="add-ing">+ Add ingredient</button>

      <div class="action-bar">
        <button class="btn secondary" data-act="cancel">Cancel</button>
        <button class="btn primary" data-act="save">Save</button>
      </div>
    </div>
  `;

  // wire footer
  content.querySelector('[data-act="cancel"]').onclick = () => {
    if (isNew) state.recipeNav.id = null;
    state.recipeNav.editing = false;
    render();
  };
  content.querySelector('[data-act="save"]').onclick = () => {
    const name = $('#edit-name').value.trim();
    const instructions = $('#edit-instructions').value.trim();
    if (!name) { alert('Recipe needs a name.'); return; }
    const ings = readEditedIngredients();
    if (isNew) {
      const newR = { id: 'r_' + id(), name, instructions, ingredients: ings, lastCooked: null };
      RECIPES.unshift(newR);
      state.recipeNav.id = newR.id;
    } else {
      r.name = name;
      r.instructions = instructions;
      r.ingredients = ings;
    }
    state.recipeNav.editing = false;
    render();
  };
  $('#add-ing').onclick = () => {
    const wrap = $('#edit-ings');
    const idx = wrap.children.length;
    const div = document.createElement('div');
    div.innerHTML = ingEditRowHtml({ itemId: '', qty: '', unit: '' }, idx);
    wrap.appendChild(div.firstElementChild);
    wireIngEditRow(wrap.lastElementChild);
  };
  content.querySelectorAll('.ing-edit-row').forEach(wireIngEditRow);
}

function ingEditRowHtml(ing, i) {
  const item = ing.itemId ? itemById(ing.itemId) : null;
  return `
    <div class="ing-edit-row" data-idx="${i}">
      <button class="pick ${item ? '' : 'empty'}" data-role="pick" data-item-id="${ing.itemId}">${item ? item.name : 'Pick item…'}</button>
      <input type="number" min="0" step="0.5" placeholder="qty" value="${ing.qty || ''}" data-role="qty" />
      <input class="unit-input" placeholder="unit" value="${ing.unit || ''}" data-role="unit" />
      <button class="x" data-role="remove" aria-label="Remove">×</button>
    </div>
  `;
}

function wireIngEditRow(row) {
  row.querySelector('[data-role=pick]').onclick = (e) => {
    state.pickerCallback = (itemId) => {
      const item = itemById(itemId);
      e.target.dataset.itemId = itemId;
      e.target.textContent = item.name;
      e.target.classList.remove('empty');
    };
    openItemPicker();
  };
  row.querySelector('[data-role=remove]').onclick = () => row.remove();
}

function readEditedIngredients() {
  const rows = content.querySelectorAll('.ing-edit-row');
  return [...rows].map(row => ({
    itemId: row.querySelector('[data-role=pick]').dataset.itemId,
    qty: parseFloat(row.querySelector('[data-role=qty]').value) || 0,
    unit: row.querySelector('[data-role=unit]').value.trim(),
  })).filter(i => i.itemId && i.qty);
}

// ── Buy tab ───────────────────────────────────────────────────────────
function renderBuyList() {
  const tasks = tasksInWeek(state.weekStart)
    .filter(t => t.status !== 'skipped')
    .sort((a, b) => recipeById(a.recipeId).name.localeCompare(recipeById(b.recipeId).name));

  let total = 0, bought = 0;
  tasks.forEach(t => {
    const r = recipeById(t.recipeId);
    total += r.ingredients.length;
    bought += r.ingredients.filter(i => t.ingredientChecks[i.itemId]).length;
  });

  if (tasks.length === 0) {
    content.innerHTML = `<div class="empty">Nothing scheduled for this week.</div>`;
    return;
  }

  let html = `
    <div class="buy-summary">
      <span>Buy list · ${tasks.length} ${tasks.length === 1 ? 'meal' : 'meals'}</span>
      <span><b>${bought}</b> / ${total} bought</span>
    </div>
    <div class="buy-progress"><div class="fill" style="width:${total ? (bought/total)*100 : 0}%"></div></div>
  `;

  html += tasks.map(t => {
    const r = recipeById(t.recipeId);
    const d = new Date(t.date);
    return `
      <div class="buy-section" data-task-id="${t.id}">
        <div class="head">
          <span class="name">${r.name}</span>
          <span class="when">${fmtDow(d)} · ${fmtMonDay(d)}</span>
        </div>
        <div class="ing-list">
          ${r.ingredients.map(ing => {
            const item = itemById(ing.itemId);
            const isChecked = !!t.ingredientChecks[ing.itemId];
            return `
              <div class="ing-row ${isChecked ? 'checked' : ''}" data-item-id="${ing.itemId}">
                <span class="check">✓</span>
                <span class="name">${item.name}</span>
                <span class="qty">${ing.qty} ${ing.unit}</span>
              </div>`;
          }).join('')}
        </div>
      </div>
    `;
  }).join('');

  content.innerHTML = html;

  content.querySelectorAll('.buy-section').forEach(sec => {
    const tid = sec.dataset.taskId;
    const t = taskById(tid);
    sec.querySelectorAll('.ing-row').forEach(row => {
      row.onclick = () => {
        const itemId = row.dataset.itemId;
        t.ingredientChecks[itemId] = !t.ingredientChecks[itemId];
        render();
      };
    });
  });
}

// ── Stats tab ─────────────────────────────────────────────────────────
function renderStats() {
  const acts = actionsInWeek(state.weekStart);
  const totalMin = acts.reduce((sum, a) => sum + (a.end - a.start) / 60000, 0);

  let html = `
    <div class="stat-cards">
      <div class="stat-card">
        <div class="num ${acts.length === 0 ? 'muted' : ''}">${acts.length || '—'}</div>
        <div class="lbl">${acts.length === 1 ? 'meal cooked' : 'meals cooked'}</div>
      </div>
      <div class="stat-card">
        <div class="num ${acts.length === 0 ? 'muted' : ''}">${acts.length === 0 ? '—' : fmtDuration(totalMin)}</div>
        <div class="lbl">total cooking</div>
      </div>
    </div>
  `;

  if (acts.length === 0) {
    html += `<div class="empty">Nothing cooked yet this week.</div>`;
  } else {
    html += `<div class="section-head"><span>Cooked this week</span><span class="count">${acts.length}</span></div>`;
    html += acts
      .sort((a, b) => a.start - b.start)
      .map(a => {
        const r = recipeById(a.recipeId);
        const mins = (a.end - a.start) / 60000;
        return `
          <div class="action-row" data-task-id="${a.taskId}">
            <span class="glyph">●</span>
            <div class="name">${r.name}</div>
            <div class="meta">${fmtDow(a.start)} · ${fmtDuration(mins)}</div>
          </div>
        `;
      }).join('');
  }

  content.innerHTML = html;

  content.querySelectorAll('.action-row').forEach(el => {
    el.onclick = () => {
      const tid = el.dataset.taskId;
      if (tid && taskById(tid)) {
        state.tab = 'week';
        state.selectedDay = taskById(tid).date;
        state.taskNav.id = tid;
        render();
      }
    };
  });
}

// ── sheet management ──────────────────────────────────────────────────
const backdrop = $('#sheet-backdrop');
function openSheet(id) {
  document.querySelectorAll('.sheet').forEach(s => s.classList.remove('open'));
  $('#' + id).classList.add('open');
  backdrop.classList.add('open');
}
function closeSheets() {
  document.querySelectorAll('.sheet').forEach(s => s.classList.remove('open'));
  backdrop.classList.remove('open');
}
backdrop.onclick = closeSheets;
document.querySelectorAll('[data-close]').forEach(b => b.onclick = closeSheets);

// task long-press sheet
$('#sheet-task').addEventListener('click', (e) => {
  const mi = e.target.closest('.mi'); if (!mi) return;
  const t = taskById(state.pendingTaskId); if (!t) { closeSheets(); return; }
  const act = mi.dataset.act;
  if (act === 'open') { state.taskNav.id = t.id; closeSheets(); render(); }
  else if (act === 'move') { state.calMode = 'move'; closeSheets(); openCalendar(); }
  else if (act === 'del') {
    const i = TASKS.indexOf(t); if (i >= 0) TASKS.splice(i, 1);
    closeSheets(); render();
  }
});

// task overflow (in detail)
$('#overflow-btn').onclick = () => {
  if (state.tab === 'week' && state.taskNav.id) {
    state.pendingTaskId = state.taskNav.id;
    openSheet('sheet-task-menu');
  } else if (state.tab === 'recipes' && state.recipeNav.id && !state.recipeNav.editing) {
    openSheet('sheet-recipe-menu');
  }
};
$('#sheet-task-menu').addEventListener('click', (e) => {
  const mi = e.target.closest('.mi'); if (!mi) return;
  const t = taskById(state.pendingTaskId); if (!t) { closeSheets(); return; }
  if (mi.dataset.act === 'move') { state.calMode = 'move'; closeSheets(); openCalendar(); }
  else if (mi.dataset.act === 'del') {
    const i = TASKS.indexOf(t); if (i >= 0) TASKS.splice(i, 1);
    state.taskNav.id = null;
    closeSheets(); render();
  }
});

// recipe overflow (in detail)
$('#sheet-recipe-menu').addEventListener('click', (e) => {
  const mi = e.target.closest('.mi'); if (!mi) return;
  const r = recipeById(state.recipeNav.id); if (!r) { closeSheets(); return; }
  if (mi.dataset.act === 'edit') {
    state.recipeNav.editing = true;
    closeSheets(); render();
  } else if (mi.dataset.act === 'del') {
    const i = RECIPES.indexOf(r); if (i >= 0) RECIPES.splice(i, 1);
    state.recipeNav.id = null;
    closeSheets(); render();
  }
});

// ── calendar sheet ────────────────────────────────────────────────────
function openCalendar() {
  // anchor month around the relevant date
  const t = state.calMode === 'move' ? taskById(state.pendingTaskId) : null;
  const anchor = t ? new Date(t.date) : TODAY;
  state.calMonth = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  renderCalendar();
  openSheet('sheet-cal');
}
function renderCalendar() {
  const m = state.calMonth;
  $('#cal-month-name').textContent = `${fmtMonLong(m)} ${m.getFullYear()}`;
  const grid = $('#cal-grid');
  grid.innerHTML = '';
  ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].forEach(d => {
    const h = document.createElement('div'); h.className = 'dow-h'; h.textContent = d; grid.appendChild(h);
  });
  const first = new Date(m.getFullYear(), m.getMonth(), 1);
  const firstDow = (first.getDay() + 6) % 7;
  const startDay = addDays(first, -firstDow);
  for (let i = 0; i < 42; i++) {
    const d = addDays(startDay, i);
    const cell = document.createElement('div');
    cell.className = 'day';
    if (d.getMonth() !== m.getMonth()) cell.classList.add('muted');
    if (sameDay(d, TODAY)) cell.classList.add('today');
    if (state.calMode === 'add' && d < TODAY && !sameDay(d, TODAY)) cell.classList.add('disabled');
    if (tasksOnDate(ymd(d)).length) cell.classList.add('has');
    cell.textContent = d.getDate();
    cell.onclick = () => {
      if (cell.classList.contains('disabled')) return;
      handleCalPick(d);
    };
    grid.appendChild(cell);
  }
}
$('#cal-prev').onclick = () => { state.calMonth = new Date(state.calMonth.getFullYear(), state.calMonth.getMonth()-1, 1); renderCalendar(); };
$('#cal-next').onclick = () => { state.calMonth = new Date(state.calMonth.getFullYear(), state.calMonth.getMonth()+1, 1); renderCalendar(); };

function handleCalPick(d) {
  if (state.calMode === 'add') {
    const t = createTaskFromRecipe(state.calContextRecipeId, ymd(d));
    closeSheets();
    // jump to that day in the Week tab
    state.tab = 'week';
    state.recipeNav.id = null;
    state.weekStart = mondayOf(d);
    state.selectedDay = ymd(d);
    state.taskNav.id = null;
    render();
  } else if (state.calMode === 'move') {
    const t = taskById(state.pendingTaskId);
    if (t) {
      t.date = ymd(d);
      state.weekStart = mondayOf(d);
      state.selectedDay = ymd(d);
    }
    closeSheets();
    render();
  }
}

function createTaskFromRecipe(recipeId, dateYmd) {
  const t = {
    id: 't_' + id(),
    recipeId,
    date: dateYmd,
    status: 'planned',
    ingredientChecks: {},
  };
  TASKS.push(t);
  return t;
}

// ── start-cooking sheet ───────────────────────────────────────────────
$('#start-save').onclick = () => {
  const t = taskById(state.pendingTaskId); if (!t) { closeSheets(); return; }
  const r = recipeById(t.recipeId);
  const start = parseTimeToDate($('#start-time').value, NOW);
  t.status = 'cooking';
  ACTIONS.push({
    id: 'a_' + id(), taskId: t.id, recipeId: r.id,
    start, end: null, modifications: '', outcome: '',
  });
  closeSheets();
  render();
};

// ── done sheet ────────────────────────────────────────────────────────
$('#done-save').onclick = () => {
  const t = taskById(state.pendingTaskId); if (!t) { closeSheets(); return; }
  const r = recipeById(t.recipeId);
  let action = ACTIONS.find(a => a.taskId === t.id);
  const dateBase = new Date(t.date);
  const end = parseTimeToDate($('#done-end').value, dateBase);
  let start;
  if (!$('#done-start-field').hidden) {
    start = parseTimeToDate($('#done-start').value, dateBase);
  } else if (action) {
    start = action.start;
  }
  if (!action) {
    action = { id: 'a_' + id(), taskId: t.id, recipeId: r.id,
               start, end, modifications: '', outcome: '' };
    ACTIONS.push(action);
  } else {
    if (start) action.start = start;
    action.end = end;
  }
  action.modifications = $('#done-mods').value.trim();
  action.outcome = $('#done-outcome').value.trim();
  t.status = 'done';
  r.lastCooked = end;
  closeSheets();
  render();
};

// ── item picker ───────────────────────────────────────────────────────
function openItemPicker() {
  $('#item-search').value = '';
  renderItemPicker('');
  openSheet('sheet-item');
}
function renderItemPicker(q) {
  const list = ITEMS.filter(i => !q || i.name.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name));
  const wrap = $('#item-list');
  wrap.innerHTML = '';
  list.forEach(item => {
    const row = document.createElement('div');
    row.className = 'mi';
    row.textContent = item.name;
    row.onclick = () => {
      state.pickerCallback?.(item.id);
      state.pickerCallback = null;
      closeSheets();
    };
    wrap.appendChild(row);
  });
  if (q && !list.find(i => i.name.toLowerCase() === q.toLowerCase())) {
    const row = document.createElement('div');
    row.className = 'mi';
    row.style.color = 'var(--accent)';
    row.textContent = `+ Create "${q}"`;
    row.onclick = () => {
      const newItem = { id: 'i_' + id(), name: q };
      ITEMS.push(newItem);
      state.pickerCallback?.(newItem.id);
      state.pickerCallback = null;
      closeSheets();
    };
    wrap.appendChild(row);
  }
}
$('#item-search').oninput = (e) => renderItemPicker(e.target.value);

// ── chrome wiring ─────────────────────────────────────────────────────
document.querySelectorAll('.nav-btn').forEach(b => {
  b.onclick = () => {
    state.tab = b.dataset.tab;
    state.recipeNav = { id: null, editing: false };
    state.taskNav = { id: null };
    render();
  };
});

$('#back-btn').onclick = () => {
  if (state.tab === 'week' && state.taskNav.id) {
    state.taskNav.id = null;
  } else if (state.tab === 'recipes' && state.recipeNav.editing) {
    if (state.recipeNav.id === 'new') state.recipeNav.id = null;
    state.recipeNav.editing = false;
  } else if (state.tab === 'recipes' && state.recipeNav.id) {
    state.recipeNav.id = null;
  }
  render();
};

$('#week-prev').onclick = () => {
  state.weekStart = addDays(state.weekStart, -7);
  // keep selected day within the week (same dow)
  if (state.tab === 'week') {
    const idxInWeek = (new Date(state.selectedDay).getDay() + 6) % 7;
    state.selectedDay = ymd(addDays(state.weekStart, idxInWeek));
  }
  render();
};
$('#week-next').onclick = () => {
  state.weekStart = addDays(state.weekStart, 7);
  if (state.tab === 'week') {
    const idxInWeek = (new Date(state.selectedDay).getDay() + 6) % 7;
    state.selectedDay = ymd(addDays(state.weekStart, idxInWeek));
  }
  render();
};

$('#recipe-search').oninput = (e) => { state.recipeSearch = e.target.value; render(); };
$('#sort-recent').onclick = () => { state.recipeSort = 'recent'; render(); };
$('#sort-alpha').onclick = () => { state.recipeSort = 'alpha'; render(); };

$('#fab').onclick = () => {
  state.recipeNav.id = 'new';
  state.recipeNav.editing = true;
  render();
};

// initial render
render();
