// =================================================================
// HUNT: World Builder & Object Placer — JavaScript
// =================================================================

const app = document.getElementById('builderApp');
const builderWindow = document.getElementById('builderWindow');
const builderHeader = document.getElementById('builderHeader');
const closeBtn = document.getElementById('closeBtn');
const navTabs = document.querySelectorAll('.nav-tab');
const tabPanes = document.querySelectorAll('.tab-pane');

const propSearchInput = document.getElementById('propSearchInput');
const categoriesFilter = document.getElementById('categoriesFilter');
const propsGrid = document.getElementById('propsGrid');
const nearbyListBody = document.getElementById('nearbyListBody');
const inspectorQuickToggle = document.getElementById('inspectorQuickToggle');

// Модальное окно спавна своего пропа
const customModelModal = document.getElementById('customModelModal');
const customModelModalWindow = document.getElementById('customModelModalWindow');
const customModelModalHeader = document.getElementById('customModelModalHeader');
const customModelInput = document.getElementById('customModelInput');

const previewHud = document.getElementById('previewHud');
const hudPropName = document.getElementById('hudPropName');
const hudModeBadge = document.getElementById('hudModeBadge');
const hudPosControls = document.getElementById('hudPosControls');
const hudRotControls = document.getElementById('hudRotControls');

let categoriesData = [];
let activeCategory = 'all';
let isInspectorActive = false;
let savedWindowPos = null;

let isMMBActive = false;

window.addEventListener('mousedown', (e) => {
  if (e.button === 1) {
    e.preventDefault();
    isMMBActive = true;
    sendNui('setCameraRotationState', { active: true });
  }
});

window.addEventListener('mouseup', (e) => {
  if (e.button === 1 || (isMMBActive && (e.buttons & 4) === 0)) {
    isMMBActive = false;
    sendNui('setCameraRotationState', { active: false });
  }
});

// =================================================================
// DRAG & DROP ДЛЯ ОКОН
// =================================================================
function makeDraggable(headerEl, windowEl) {
  if (!headerEl || !windowEl) return;
  let isDragging = false;
  let offsetX = 0, offsetY = 0;

  headerEl.addEventListener('mousedown', (e) => {
    if (e.target.tagName === 'BUTTON' || e.target.closest('button')) return;
    isDragging = true;

    const rect = windowEl.getBoundingClientRect();
    offsetX = e.clientX - rect.left;
    offsetY = e.clientY - rect.top;

    windowEl.style.transform = 'none';
    windowEl.style.left = `${rect.left}px`;
    windowEl.style.top = `${rect.top}px`;

    document.body.style.userSelect = 'none';
  });

  window.addEventListener('mousemove', (e) => {
    if (!isDragging) return;

    let newX = e.clientX - offsetX;
    let newY = e.clientY - offsetY;

    const maxW = window.innerWidth - windowEl.offsetWidth;
    const maxH = window.innerHeight - windowEl.offsetHeight;

    newX = Math.max(5, Math.min(maxW - 5, newX));
    newY = Math.max(5, Math.min(maxH - 5, newY));

    windowEl.style.left = `${newX}px`;
    windowEl.style.top = `${newY}px`;

    if (windowEl === builderWindow) {
      savedWindowPos = { x: newX, y: newY };
    }
  });

  window.addEventListener('mouseup', () => {
    isDragging = false;
    document.body.style.userSelect = '';
  });
}

makeDraggable(builderHeader, builderWindow);
makeDraggable(customModelModalHeader, customModelModalWindow);

// NUI Callback
function sendNui(event, data = {}) {
  return fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

// Переключение вкладок
navTabs.forEach(tab => {
  tab.addEventListener('click', () => {
    const targetTab = tab.getAttribute('data-tab');

    navTabs.forEach(t => t.classList.remove('active'));
    tab.classList.add('active');

    if (targetTab === 'nearby') {
      tabPanes.forEach(p => p.classList.remove('active'));
      const nearbyPane = document.getElementById('tab-nearby');
      if (nearbyPane) nearbyPane.classList.add('active');
      requestNearbyProps();
    } else {
      tabPanes.forEach(p => p.classList.remove('active'));
      const catalogPane = document.getElementById('tab-catalog');
      if (catalogPane) catalogPane.classList.add('active');
      switchSection(targetTab);
    }
  });
});

// Закрытие окна каталога (возврат в свободный полёт камеры)
function closeCatalog() {
  closeCustomModelModal();
  app.style.display = 'none';
  sendNui('closeCatalogPanel');
}

closeBtn.addEventListener('click', closeCatalog);

function goBackToAdmin() {
  closeCustomModelModal();
  app.style.display = 'none';
  sendNui('returnToAdmin');
}

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (customModelModal && customModelModal.style.display !== 'none') {
      closeCustomModelModal();
      return;
    }
    if (app.style.display !== 'none') {
      closeCatalog();
    }
  }
});

// =================================================================
// МОДАЛЬНОЕ ОКНО СПАВНА ПО ИМЕНИ / ХЭШУ
// =================================================================
function openCustomModelModal() {
  if (!customModelModal) return;
  customModelModal.style.display = 'flex';
  if (customModelInput) {
    customModelInput.value = '';
    setTimeout(() => customModelInput.focus(), 50);
  }
}

function closeCustomModelModal() {
  if (customModelModal) customModelModal.style.display = 'none';
}

function submitCustomModel() {
  const val = customModelInput ? customModelInput.value.trim() : '';
  if (!val) return;

  closeCustomModelModal();
  startPropPreview({ name: val, model: val });
}

if (customModelInput) {
  customModelInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') submitCustomModel();
  });
}

// =================================================================
// МУЛЬТИ-КАТАЛОГИ (ОБЪЕКТЫ, NPC, ТРАНСПОРТ С VIRTUAL WINDOWING)
// =================================================================
const ROW_HEIGHT = 66;
const COLS = 2;
const BUFFER_ROWS = 2;

let currentSection = 'catalog'; // 'catalog', 'peds', 'vehicles'
const rawCatalogs = {
  catalog: null,
  peds: null,
  vehicles: null
};
let scenariosData = [];

let currentFilteredList = [];
let allFlatProps = [];
let totalRows = 0;
let lastRenderedStart = -1;
let lastRenderedEnd = -1;

// Сохранение позиции прокрутки каталога и категорий
const sectionScrollPositions = {
  catalog: 0,
  peds: 0,
  vehicles: 0
};
const categoryScrollPositions = {};
let savedCategoriesScrollLeft = 0;

// Инициализация всех каталогов и сценариев
function initCatalogs() {
  if (window.BUILDER_CATALOGS) {
    rawCatalogs.catalog = window.BUILDER_CATALOGS.catalog || [];
    rawCatalogs.peds = window.BUILDER_CATALOGS.peds || [];
    rawCatalogs.vehicles = window.BUILDER_CATALOGS.vehicles || [];
    scenariosData = window.BUILDER_CATALOGS.scenarios || [];
    populateScenariosSelect();
    switchSection('catalog');
    return;
  }

  fetch('props_catalog.json').then(r => r.json()).then(d => {
    rawCatalogs.catalog = d;
    if (currentSection === 'catalog') switchSection('catalog');
  }).catch(() => {});

  fetch('peds_catalog.json').then(r => r.json()).then(d => {
    rawCatalogs.peds = d;
    if (currentSection === 'peds') switchSection('peds');
  }).catch(() => {});

  fetch('vehicles_catalog.json').then(r => r.json()).then(d => {
    rawCatalogs.vehicles = d;
    if (currentSection === 'vehicles') switchSection('vehicles');
  }).catch(() => {});

  fetch('scenarios_catalog.json').then(r => r.json()).then(d => {
    scenariosData = d || [];
    populateScenariosSelect();
  }).catch(() => {});
}

initCatalogs();

function populateScenariosSelect() {
  const sel = document.getElementById('pedScenarioSelect');
  if (!sel) return;
  sel.innerHTML = '<option value="none">Без анимации (Статичная стойка)</option>';
  scenariosData.forEach(sc => {
    const opt = document.createElement('option');
    opt.value = sc.id;
    opt.textContent = sc.label || sc.id;
    sel.appendChild(opt);
  });
}

function switchSection(section) {
  currentSection = section;
  activeCategory = 'all';
  if (propSearchInput) propSearchInput.value = '';

  const pedBar = document.getElementById('pedOptionsBar');
  if (pedBar) {
    pedBar.style.display = (section === 'peds') ? 'flex' : 'none';
  }

  let catData = null;
  if (window.BUILDER_CATALOGS && window.BUILDER_CATALOGS[section]) {
    catData = window.BUILDER_CATALOGS[section];
    rawCatalogs[section] = catData;
  } else if (rawCatalogs[section]) {
    catData = rawCatalogs[section];
  }

  if (catData && Array.isArray(catData)) {
    categoriesData = catData;
    buildFlatPropsIndex();
    renderCategoriesFilter();
    const targetScroll = sectionScrollPositions[section] || 0;
    renderPropsGrid(true, targetScroll);
  }
}

function buildFlatPropsIndex() {
  allFlatProps = [];
  const seen = new Set();
  categoriesData.forEach(cat => {
    if (cat.props) {
      cat.props.forEach(p => {
        if (!seen.has(p.model)) {
          seen.add(p.model);
          allFlatProps.push(p);
        }
      });
    }
  });
}

function renderCategoriesFilter() {
  if (!categoriesFilter) return;
  categoriesFilter.innerHTML = '';

  const totalCount = allFlatProps.length || categoriesData.reduce((acc, c) => acc + (c.count || (c.props ? c.props.length : 0)), 0);

  const allBtn = document.createElement('button');
  allBtn.className = `cat-btn ${activeCategory === 'all' ? 'active' : ''}`;
  allBtn.innerHTML = `Все <span class="cat-count">${totalCount}</span>`;
  allBtn.onclick = () => {
    if (activeCategory !== 'all') {
      activeCategory = 'all';
      renderCategoriesFilter();
      const targetScroll = categoryScrollPositions[`${currentSection}_all`] || 0;
      renderPropsGrid(true, targetScroll);
    }
  };
  categoriesFilter.appendChild(allBtn);

  categoriesData.forEach(cat => {
    const btn = document.createElement('button');
    btn.className = `cat-btn ${activeCategory === cat.id ? 'active' : ''}`;
    const pCount = cat.count || (cat.props ? cat.props.length : 0);
    btn.innerHTML = `${escapeHtml(cat.label)} <span class="cat-count">${pCount}</span>`;
    btn.onclick = () => {
      if (activeCategory !== cat.id) {
        activeCategory = cat.id;
        renderCategoriesFilter();
        const targetScroll = categoryScrollPositions[`${currentSection}_${cat.id}`] || 0;
        renderPropsGrid(true, targetScroll);
      }
    };
    categoriesFilter.appendChild(btn);
  });
}

function renderPropsGrid(preserveScroll = false, explicitScrollTop = null) {
  if (!propsGridContainer || !virtualScrollSpacer || !virtualGridContent) return;

  const searchVal = (propSearchInput ? propSearchInput.value : '').toLowerCase().trim();
  
  if (activeCategory === 'all') {
    if (!searchVal) {
      currentFilteredList = allFlatProps;
    } else {
      currentFilteredList = allFlatProps.filter(p => p.name.toLowerCase().includes(searchVal) || p.model.toLowerCase().includes(searchVal));
    }
  } else {
    const activeCatObj = categoriesData.find(c => c.id === activeCategory);
    const catProps = activeCatObj && activeCatObj.props ? activeCatObj.props : [];
    if (!searchVal) {
      currentFilteredList = catProps;
    } else {
      currentFilteredList = catProps.filter(p => p.name.toLowerCase().includes(searchVal) || p.model.toLowerCase().includes(searchVal));
    }
  }

  totalRows = Math.ceil(currentFilteredList.length / COLS);
  const totalHeight = Math.max(totalRows * ROW_HEIGHT, 0);
  virtualScrollSpacer.style.height = `${totalHeight}px`;

  let targetScroll = 0;
  if (explicitScrollTop !== null) {
    targetScroll = explicitScrollTop;
  } else if (preserveScroll) {
    const currentKey = `${currentSection}_${activeCategory}`;
    targetScroll = categoryScrollPositions[currentKey] !== undefined ? categoryScrollPositions[currentKey] : (sectionScrollPositions[currentSection] || 0);
  }

  if (searchVal && explicitScrollTop === null && !preserveScroll) {
    targetScroll = 0;
  }

  const maxScroll = Math.max(0, totalHeight - (propsGridContainer.clientHeight || 450));
  targetScroll = Math.max(0, Math.min(targetScroll, maxScroll));

  propsGridContainer.scrollTop = targetScroll;
  lastRenderedStart = -1;
  lastRenderedEnd = -1;

  if (currentFilteredList.length === 0) {
    virtualGridContent.innerHTML = '<div class="empty-msg" style="grid-column: 1 / -1; padding-top: 40px;">Ничего не найдено</div>';
    virtualGridContent.style.transform = 'translateY(0px)';
    return;
  }

  updateVirtualWindow();
}

function updateVirtualWindow() {
  if (!propsGridContainer || !virtualGridContent || currentFilteredList.length === 0) return;

  const scrollTop = propsGridContainer.scrollTop || 0;
  const viewportHeight = 450;

  const startRow = Math.max(0, Math.floor(scrollTop / ROW_HEIGHT) - BUFFER_ROWS);
  const endRow = Math.min(totalRows, Math.ceil((scrollTop + viewportHeight) / ROW_HEIGHT) + BUFFER_ROWS);

  const startIndex = startRow * COLS;
  const endIndex = Math.min(currentFilteredList.length, endRow * COLS);

  if (startIndex === lastRenderedStart && endIndex === lastRenderedEnd) return;

  lastRenderedStart = startIndex;
  lastRenderedEnd = endIndex;

  const offsetY = startRow * ROW_HEIGHT;
  virtualGridContent.style.transform = `translateY(${offsetY}px)`;

  const visibleSlice = currentFilteredList.slice(startIndex, endIndex);
  let html = '';
  for (let i = 0; i < visibleSlice.length; i++) {
    const prop = visibleSlice[i];
    const actionLabel = currentSection === 'peds' ? 'Заспавнить NPC' : (currentSection === 'vehicles' ? 'Заспавнить транспорт' : 'Разместить в мире');
    html += `
      <div class="prop-card" data-idx="${startIndex + i}">
        <div>
          <div class="prop-card-title">${escapeHtml(prop.name)}</div>
          <div class="prop-card-model">${escapeHtml(prop.model)}</div>
        </div>
        <div class="prop-card-btn">${actionLabel}</div>
      </div>
    `;
  }

  virtualGridContent.innerHTML = html;
}

// Делегированный клик
if (virtualGridContent) {
  virtualGridContent.addEventListener('click', (e) => {
    const card = e.target.closest('.prop-card');
    if (!card) return;
    const idx = parseInt(card.getAttribute('data-idx'), 10);
    if (!isNaN(idx) && currentFilteredList[idx]) {
      startPropPreview(currentFilteredList[idx]);
    }
  });
}

if (propsGridContainer) {
  propsGridContainer.addEventListener('scroll', () => {
    const currentKey = `${currentSection}_${activeCategory}`;
    categoryScrollPositions[currentKey] = propsGridContainer.scrollTop;
    sectionScrollPositions[currentSection] = propsGridContainer.scrollTop;
    updateVirtualWindow();
  }, { passive: true });
}

if (categoriesFilter) {
  categoriesFilter.addEventListener('scroll', () => {
    savedCategoriesScrollLeft = categoriesFilter.scrollLeft;
  }, { passive: true });
}

let searchDebounce = null;
if (propSearchInput) {
  propSearchInput.addEventListener('input', () => {
    clearTimeout(searchDebounce);
    searchDebounce = setTimeout(() => {
      renderPropsGrid(false);
    }, 60);
  });
}

function startPropPreview(prop) {
  app.style.display = 'none';
  sendNui('closeCatalogPanel');

  let entityType = 'object';
  let scenario = 'none';

  if (currentSection === 'peds' || prop.entityType === 'ped') {
    entityType = 'ped';
    const sel = document.getElementById('pedScenarioSelect');
    scenario = sel ? sel.value : 'none';
  } else if (currentSection === 'vehicles' || prop.entityType === 'vehicle') {
    entityType = 'vehicle';
  }

  sendNui('startPropPreview', {
    name: prop.name,
    model: prop.model,
    entityType: entityType,
    scenario: scenario
  });
}

// =================================================================
// ИНСПЕКТОР (БЫСТРАЯ КНОПКА В ШАПКЕ)
// =================================================================
function toggleInspectorMode() {
  isInspectorActive = !isInspectorActive;
  if (inspectorQuickToggle) {
    inspectorQuickToggle.className = isInspectorActive ? 'inspector-quick-btn active' : 'inspector-quick-btn';
    inspectorQuickToggle.title = isInspectorActive ? 'Инспектор мира: ВКЛЮЧЕН (нажмите для выключения)' : 'Инспектор мира: ВЫКЛЮЧЕН (нажмите для включения)';
  }
  sendNui('toggleInspector', { active: isInspectorActive });
}

if (inspectorQuickToggle) {
  inspectorQuickToggle.addEventListener('click', toggleInspectorMode);
}

// =================================================================
// =================================================================
// ОБЪЕКТЫ В БАЗЕ ДАННЫХ
// =================================================================
let rawDBProps = [];
let currentDBFilter = 'all';

function requestNearbyProps() {
  sendNui('requestNearbyProps');
}

function backupBuilderDatabase() {
  sendNui('backupBuilderDatabase');
}

function setDBFilter(filter) {
  currentDBFilter = filter || 'all';
  document.querySelectorAll('.db-filter-btn').forEach(btn => {
    if (btn.getAttribute('data-filter') === currentDBFilter) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
  applyDBFilter();
}

function filterDBProps() {
  applyDBFilter();
}

function applyDBFilter() {
  if (!nearbyListBody) return;
  nearbyListBody.innerHTML = '';

  const searchInput = document.getElementById('dbPropsSearchInput');
  const searchVal = searchInput ? searchInput.value.toLowerCase().trim() : '';

  const filtered = rawDBProps.filter(p => {
    // 1. Фильтр по категории
    if (currentDBFilter === 'placed' && p.db_type !== 'placed') return false;
    if (currentDBFilter === 'moved' && p.db_type !== 'moved') return false;
    if (currentDBFilter === 'deleted' && p.db_type !== 'deleted') return false;

    // 2. Поиск по тексту
    if (searchVal) {
      const matchId = ('#' + p.id).includes(searchVal) || String(p.id).includes(searchVal);
      const matchName = p.name && p.name.toLowerCase().includes(searchVal);
      const matchHash = p.model_hash && (String(p.model_hash).includes(searchVal) || ('0x' + (p.model_hash >>> 0).toString(16).toLowerCase()).includes(searchVal));
      if (!matchId && !matchName && !matchHash) return false;
    }
    return true;
  });

  if (filtered.length === 0) {
    nearbyListBody.innerHTML = '<tr><td colspan="6" class="empty-msg">Нет объектов, соответствующих фильтрам</td></tr>';
    return;
  }

  filtered.forEach(p => {
    const tr = document.createElement('tr');
    const badgeClass = p.db_type === 'placed' ? 'placed' : (p.db_type === 'moved' ? 'moved' : 'deleted');
    const hashHex = p.model_hash ? '0x' + (p.model_hash >>> 0).toString(16).toUpperCase() : '';

    let actionButtons = '';
    actionButtons += `<button class="btn-sm" onclick="tpToProp(${p.x}, ${p.y}, ${p.z})" title="Телепортироваться">ТП</button>`;
    
    if (p.can_move) {
      actionButtons += `<button class="btn-sm primary" onclick="movePropById(${p.id})" title="Взять в режим перемещения">Передвинуть</button>`;
    }
    if (p.can_restore) {
      actionButtons += `<button class="btn-sm warning" onclick="restorePropById(${p.id}, '${p.db_type}')" title="Восстановить объект на исходное место">Восстановить</button>`;
    }
    if (p.can_delete) {
      const delLabel = p.db_type === 'deleted' ? 'Снять скрытие' : 'Удалить';
      actionButtons += `<button class="btn-sm danger" onclick="deletePropById(${p.id}, '${p.db_type}')" title="Удалить навсегда из БД">${delLabel}</button>`;
    }

    tr.innerHTML = `
      <td><b>#${p.id}</b></td>
      <td><span class="db-status-badge ${badgeClass}">${escapeHtml(p.status_text || p.db_type)}</span></td>
      <td>
        <div style="font-weight: 600;">${escapeHtml(p.name)}</div>
        <div style="font-size: 9px; opacity: 0.55;">${hashHex}</div>
      </td>
      <td style="font-size: 9.5px; opacity: 0.85;">${p.x}, ${p.y}, ${p.z}</td>
      <td>${p.dist} м</td>
      <td style="text-align: right; white-space: nowrap;">
        ${actionButtons}
      </td>
    `;
    nearbyListBody.appendChild(tr);
  });
}

function renderNearbyProps(props) {
  rawDBProps = props || [];

  // Подсчёт количества в категориях
  let countPlaced = 0;
  let countMoved = 0;
  let countDeleted = 0;

  rawDBProps.forEach(p => {
    if (p.db_type === 'placed') countPlaced++;
    else if (p.db_type === 'moved') countMoved++;
    else if (p.db_type === 'deleted') countDeleted++;
  });

  const elAll = document.getElementById('count-all');
  const elPlaced = document.getElementById('count-placed');
  const elMoved = document.getElementById('count-moved');
  const elDeleted = document.getElementById('count-deleted');

  if (elAll) elAll.innerText = rawDBProps.length;
  if (elPlaced) elPlaced.innerText = countPlaced;
  if (elMoved) elMoved.innerText = countMoved;
  if (elDeleted) elDeleted.innerText = countDeleted;

  applyDBFilter();
}

function movePropById(id) {
  sendNui('movePropById', { id: id });
}

function tpToProp(x, y, z) {
  sendNui('tpToProp', { x: x, y: y, z: z });
}

function deletePropById(id, dbType) {
  sendNui('deletePropById', { id: id, dbType: dbType });
  setTimeout(requestNearbyProps, 300);
}

function restorePropById(id, dbType) {
  sendNui('restorePropById', { id: id, dbType: dbType });
  setTimeout(requestNearbyProps, 300);
}

window.movePropById = movePropById;
window.tpToProp = tpToProp;
window.deletePropById = deletePropById;
window.restorePropById = restorePropById;
window.backupBuilderDatabase = backupBuilderDatabase;
window.setDBFilter = setDBFilter;
window.filterDBProps = filterDBProps;

function escapeHtml(text) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return String(text).replace(/[&<>"']/g, m => map[m]);
}

// Отслеживание фокуса ввода текста для полной блокировки управления
document.addEventListener('focusin', (e) => {
  if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
    sendNui('setInputFocusState', { hasFocus: true });
  }
});

document.addEventListener('focusout', (e) => {
  if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
    sendNui('setInputFocusState', { hasFocus: false });
  }
});

// =================================================================
// СООБЩЕНИЯ ОТ КЛИЕНТА REDM
// =================================================================
function renderFreecamHud(isInspector) {
  const hudListContainer = document.getElementById('hudListContainer');
  const ch = document.getElementById('builderCrosshair');
  if (!hudListContainer) return;

  if (isInspector) {
    if (ch) ch.style.display = 'flex';
    hudListContainer.innerHTML = `
      <div class="hud-item"><span class="key-badge">WASD</span><span class="key-desc">Полёт камеры</span></div>
      <div class="hud-item"><span class="key-badge">Мышь</span><span class="key-desc">Обзор и прицел</span></div>
      <div class="hud-item"><span class="key-badge">Space / Ctrl</span><span class="key-desc">Вверх / Вниз</span></div>
      <div class="hud-item"><span class="key-badge action-ok">B</span><span class="key-desc">Каталог спавна</span></div>
      <div class="hud-item"><span class="key-badge">N</span><span class="key-desc">Объекты в базе</span></div>
      <div class="hud-item primary"><span class="key-badge action-ok">T</span><span class="key-desc">Инспектор: ВКЛ</span></div>
      <div class="hud-item"><span class="key-badge">E</span><span class="key-desc">Взять объект</span></div>
      <div class="hud-item"><span class="key-badge">C</span><span class="key-desc">Клон объекта</span></div>
      <div class="hud-item danger"><span class="key-badge action-cancel">Delete</span><span class="key-desc">Удалить объект</span></div>
      <div class="hud-divider"></div>
      <div class="hud-item"><span class="key-badge action-cancel">Esc</span><span class="key-desc">Выйти из редактора</span></div>
    `;
  } else {
    if (ch) ch.style.display = 'none';
    hudListContainer.innerHTML = `
      <div class="hud-item"><span class="key-badge">WASD</span><span class="key-desc">Полёт камеры</span></div>
      <div class="hud-item"><span class="key-badge">Мышь</span><span class="key-desc">Обзор</span></div>
      <div class="hud-item"><span class="key-badge">Space / Ctrl</span><span class="key-desc">Вверх / Вниз</span></div>
      <div class="hud-item"><span class="key-badge action-ok">B</span><span class="key-desc">Каталог спавна</span></div>
      <div class="hud-item"><span class="key-badge">N</span><span class="key-desc">Объекты в базе</span></div>
      <div class="hud-item"><span class="key-badge">T</span><span class="key-desc">Инспектор: ВЫКЛ</span></div>
      <div class="hud-divider"></div>
      <div class="hud-item"><span class="key-badge action-cancel">Esc</span><span class="key-desc">Выйти из редактора</span></div>
    `;
  }
}

window.addEventListener('message', (event) => {
  const data = event.data;

  if (data.type === 'OPEN_CATALOG_PANEL' || data.type === 'OPEN_BUILDER') {
    app.style.display = 'block';
    if (!savedWindowPos) {
      builderWindow.style.left = '50%';
      builderWindow.style.top = '50%';
      builderWindow.style.transform = 'translate(-50%, -50%)';
    } else {
      builderWindow.style.left = `${savedWindowPos.x}px`;
      builderWindow.style.top = `${savedWindowPos.y}px`;
      builderWindow.style.transform = 'none';
    }

    if (data.section === 'nearby') {
      const tabBtn = document.querySelector(`.nav-tab[data-tab="nearby"]`);
      if (tabBtn) tabBtn.click();
      if (data.props) {
        renderNearbyProps(data.props);
      } else {
        requestNearbyProps();
      }
    } else {
      const activeTab = document.querySelector('.nav-tab.active');
      const curTab = activeTab ? activeTab.getAttribute('data-tab') : 'catalog';
      if (curTab === 'nearby') {
        const tabBtn = document.querySelector(`.nav-tab[data-tab="catalog"]`);
        if (tabBtn) tabBtn.click();
      }
      if (allFlatProps.length === 0) {
        buildFlatPropsIndex();
      }
      renderCategoriesFilter();
      if (categoriesFilter && savedCategoriesScrollLeft > 0) {
        categoriesFilter.scrollLeft = savedCategoriesScrollLeft;
      }
      renderPropsGrid(true);

      requestAnimationFrame(() => {
        const currentKey = `${currentSection}_${activeCategory}`;
        const targetScroll = categoryScrollPositions[currentKey] !== undefined ? categoryScrollPositions[currentKey] : (sectionScrollPositions[currentSection] || 0);
        if (propsGridContainer && targetScroll > 0) {
          propsGridContainer.scrollTop = targetScroll;
          updateVirtualWindow();
        }
        if (categoriesFilter && savedCategoriesScrollLeft > 0) {
          categoriesFilter.scrollLeft = savedCategoriesScrollLeft;
        }
      });
    }
  }

  if (data.type === 'CLOSE_CATALOG_PANEL' || data.type === 'CLOSE_BUILDER') {
    app.style.display = 'none';
  }

  if (data.type === 'SHOW_CROSSHAIR') {
    const ch = document.getElementById('builderCrosshair');
    if (ch) ch.style.display = 'flex';
  }

  if (data.type === 'HIDE_CROSSHAIR') {
    const ch = document.getElementById('builderCrosshair');
    if (ch) ch.style.display = 'none';
  }

  if (data.type === 'UPDATE_PHYSICS_STATE') {
    const physicsDesc = document.getElementById('hudPhysicsDesc');
    if (physicsDesc) physicsDesc.textContent = `Physics / active door: ${data.isDynamic === true ? 'ON' : 'OFF'}`;
  }

  if (data.type === 'SET_NEARBY_PROPS') {
    renderNearbyProps(data.props || []);
  }

  if (data.type === 'START_PREVIEW_MODE') {
    previewHud.style.display = 'flex';

    if (hudPropName && data.prop) {
      hudPropName.textContent = data.prop.name || 'Редактор мира';
    }

    const modeBadge = document.getElementById('hudModeBadge');
    const hudListContainer = document.getElementById('hudListContainer');
    const ch = document.getElementById('builderCrosshair');

    if (data.isWorldEditorFreeMode) {
      if (modeBadge) modeBadge.textContent = 'СВОБОДНАЯ КАМЕРА';
      renderFreecamHud(data.isInspectorActive === true);
    } else if (data.isFreecam) {
      if (ch) ch.style.display = 'flex';
      if (modeBadge) modeBadge.textContent = 'РАЗМЕЩЕНИЕ';
      if (hudListContainer) {
        hudListContainer.innerHTML = `
          <div class="hud-item"><span class="key-badge">WASD</span><span class="key-desc">Полёт камеры</span></div>
          <div class="hud-item"><span class="key-badge">Мышь</span><span class="key-desc">Обзор и прицел</span></div>
          <div class="hud-item"><span class="key-badge">Space / Ctrl</span><span class="key-desc">Вверх / Вниз</span></div>
          <div class="hud-item"><span class="key-badge">Z / X</span><span class="key-desc">Вращать вокруг оси</span></div>
          <div class="hud-item"><span class="key-badge">Q / E</span><span class="key-desc">Высота объекта</span></div>
          <div class="hud-item"><span class="key-badge">R / F</span><span class="key-desc">Дистанция</span></div>
          <div class="hud-item"><span class="key-badge">Стрелки</span><span class="key-desc">Наклон и крен</span></div>
          <div class="hud-item"><span class="key-badge">G</span><span class="key-desc" id="hudSnapDesc">${data.isSnapping === false ? 'Прилипание: ВЫКЛ' : 'Прилипание: ВКЛ'}</span></div>
          <div class="hud-item"><span class="key-badge">O</span><span class="key-desc" id="hudPhysicsDesc">Physics / active door: ${data.isDynamic === true ? 'ON' : 'OFF'}</span></div>
          <div class="hud-divider"></div>
          <div class="hud-item primary"><span class="key-badge action-ok">ЛКМ / Enter</span><span class="key-desc">Установить</span></div>
          <div class="hud-item danger"><span class="key-badge action-cancel">ПКМ / Esc</span><span class="key-desc">Отменить выбор</span></div>
        `;
      }
    } else {
      if (ch) ch.style.display = 'none';
      if (modeBadge) modeBadge.textContent = 'ПРЕДПРОСМОТР';
      if (hudListContainer) {
        hudListContainer.innerHTML = `
          <div class="hud-item"><span class="key-badge">WASD</span><span class="key-desc">Перемещение персонажа</span></div>
          <div class="hud-item"><span class="key-badge">Мышь</span><span class="key-desc">Прицеливание и осмотр</span></div>
          <div class="hud-item"><span class="key-badge">Z / X</span><span class="key-desc">Вращать вокруг оси</span></div>
          <div class="hud-item"><span class="key-badge">Q / E</span><span class="key-desc">Высота</span></div>
          <div class="hud-item"><span class="key-badge">R / F</span><span class="key-desc">Дистанция</span></div>
          <div class="hud-item"><span class="key-badge">Стрелки</span><span class="key-desc">Наклон и крен</span></div>
          <div class="hud-item"><span class="key-badge">G</span><span class="key-desc" id="hudSnapDesc">${data.isSnapping === false ? 'Прилипание: ВЫКЛ' : 'Прилипание: ВКЛ'}</span></div>
          <div class="hud-item"><span class="key-badge">O</span><span class="key-desc" id="hudPhysicsDesc">Physics / active door: ${data.isDynamic === true ? 'ON' : 'OFF'}</span></div>
          <div class="hud-divider"></div>
          <div class="hud-item primary"><span class="key-badge action-ok">ЛКМ / Enter</span><span class="key-desc">Установить</span></div>
          <div class="hud-item danger"><span class="key-badge action-cancel">ПКМ / Esc</span><span class="key-desc">Отменить</span></div>
        `;
      }
    }
  }

  if (data.type === 'UPDATE_INSPECTOR_STATE') {
    renderFreecamHud(data.isInspectorActive === true);
  }

  if (data.type === 'UPDATE_SNAP_STATE') {
    const snapDesc = document.getElementById('hudSnapDesc');
    if (snapDesc) {
      snapDesc.textContent = data.isSnapping ? 'Прилипание: ВКЛ' : 'Прилипание: ВЫКЛ';
    }
  }

  if (data.type === 'STOP_PREVIEW_MODE' || data.type === 'STOP_WORLD_EDITOR') {
    previewHud.style.display = 'none';
    const ch = document.getElementById('builderCrosshair');
    if (ch) ch.style.display = 'none';
    app.style.display = 'none';
  }
});
