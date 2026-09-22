// =================================================================
// HUNT: Hard RP — World Loot Editor JavaScript
// =================================================================

let allZones = {};
let itemsCatalog = {};
let activeZone = null;
let savedSnapshot = '';
let zoneRuntime = {};
let savePending = false;
let saveTimer;
const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
function setSaveStatus(text, error = false) {
  const el = document.getElementById('saveStatus');
  el.textContent = text;
  el.classList.toggle('error', error);
  document.getElementById('saveZoneButton').disabled = savePending;
  document.querySelectorAll('#editorMainWorkspace input, #editorMainWorkspace select, #editorMainWorkspace button').forEach(el => el.disabled = savePending);
}
function updateDirtyStatus() {
  if (!savePending) setSaveStatus(activeZone && JSON.stringify(activeZone) !== savedSnapshot ? 'Есть несохранённые изменения' : 'Изменений нет');
}
function validateZoneForm() {
  if (!activeZone || !activeZone.name?.trim()) return 'Укажите название зоны';
  for (const input of document.querySelectorAll('#editorMainWorkspace input[type="number"]')) {
    if (input.offsetParent && (!input.value || !input.checkValidity())) return 'Проверьте числовые поля';
  }
  if (activeZone.min_items > activeZone.max_active_items) return 'Минимум предметов превышает максимум';
  if (activeZone.min_respawn_time > activeZone.max_respawn_time) return 'Минимальный кулдаун превышает максимальный';
  if (activeZone.is_enabled && !activeZone.selected_items?.length) return 'Выберите предметы или выключите пустую зону';
  if (activeZone.zone_type === 'polygon' && activeZone.points?.length < 3) return 'Полигону нужны минимум 3 вершины';
  return null;
}
let activeTabCategory = 'all';
let tempSelectedItemsMap = {}; // [itemName] = { item_name, weight, min_count, max_count }

const RARITY_COLORS = {
  white:  { hex: '#ffffff', label: 'Обычный' },
  green:  { hex: '#22c55e', label: 'Необычный' },
  blue:   { hex: '#38bdf8', label: 'Редкий' },
  amber:  { hex: '#ff9f43', label: 'Эпический' },
  orange: { hex: '#f97316', label: 'Легендарный' },
  red:    { hex: '#ef4444', label: 'Мифический' }
};

const DEFAULT_SVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>`;

// =================================================================
// 1. NUI MESSAGE LISTENER
// =================================================================

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data) return;

  if (data.type === 'OPEN_EDITOR') {
    allZones = data.zones || {};
    itemsCatalog = data.catalog || {};
    document.getElementById('lootEditorApp').style.display = 'flex';
    document.getElementById('editorCrosshair').style.display = 'flex';
    updateTopStats();

    // Если зон нет или зона не выбрана
    savePending = false;
    savedSnapshot = JSON.stringify(data.activeZone || null);
    const firstZoneId = data.activeZone?.id;
    if (firstZoneId && allZones[firstZoneId]) {
      setActiveZone(allZones[firstZoneId]);
    } else {
      setActiveZone(null);
    }
  } else if (data.type === 'CLOSE_EDITOR') {
    document.getElementById('lootEditorApp').style.display = 'none';
    document.getElementById('editorCrosshair').style.display = 'none';
    closeAllModals();
  } else if (data.type === 'ZONE_STATUS') {
    zoneRuntime = data.states || {};
    renderRuntimeStatus();
  } else if (data.type === 'ZONE_SAVED') {
    clearTimeout(saveTimer);
    savePending = false;
    savedSnapshot = JSON.stringify(data.zone);
    setSaveStatus('Зона сохранена');
  } else if (data.type === 'SAVE_FAILED') {
    clearTimeout(saveTimer);
    savePending = false;
    setSaveStatus('Не удалось сохранить. Изменения остались в редакторе.', true);
  } else if (data.type === 'SET_ACTIVE_ZONE') {
    if (activeZone?.id !== data.activeZone?.id) savedSnapshot = JSON.stringify(data.activeZone?.id ? data.activeZone : null);
    setActiveZone(data.activeZone);
  } else if (data.type === 'UPDATE_ZONES_LIST') {
    allZones = data.zones || {};
    updateTopStats();
    renderZonesDrawerList();
    if (data.preserveDraft) return;
    if (data.activeZone) {
      setActiveZone(data.activeZone);
    } else {
      setActiveZone(null);
    }
  }
});

// =================================================================
// 2. УПРАВЛЕНИЕ АКТИВНОЙ ЗОНОЙ
// =================================================================

function setActiveZone(zone) {
  activeZone = zone ? JSON.parse(JSON.stringify(zone)) : null;
  zone = activeZone;
  updateDirtyStatus();

  const workspace = document.getElementById('editorMainWorkspace');
  const bottomBar = document.getElementById('editorBottomBar');
  const banner = document.getElementById('activeZoneBanner');
  const emptyHero = document.getElementById('emptyStateHero');

  if (!zone) {
    workspace.style.display = 'none';
    bottomBar.style.display = 'none';
    banner.style.display = 'none';
    emptyHero.style.display = 'flex';
    return;
  }

  emptyHero.style.display = 'none';
  workspace.style.display = 'flex';
  bottomBar.style.display = 'flex';
  banner.style.display = 'flex';

  // Заполняем верхний баннер
  document.getElementById('activeZoneTypeBadge').innerText = (zone.zone_type || 'circle').toUpperCase();
  document.getElementById('activeZoneNameText').innerText = zone.name || 'Новая зона';
  document.getElementById('activeZoneIdBadge').innerText = zone.id ? `#${zone.id}` : '#НОВАЯ';

  // Заполняем форму
  document.getElementById('zoneNameInput').value = zone.name || '';
  document.getElementById('zoneTypeSelect').value = zone.zone_type || 'circle';
  document.getElementById('zoneEnabledInput').checked = zone.is_enabled === true || zone.is_enabled === 1;

  document.getElementById('zoneRadiusInput').value = zone.radius || 10.0;
  document.getElementById('zoneHeightInput').value = zone.height || 4.0;
  document.getElementById('zoneSizeXInput').value = zone.size_x || 10.0;
  document.getElementById('zoneSizeYInput').value = zone.size_y || 10.0;
  document.getElementById('zoneSizeZInput').value = zone.size_z || 4.0;
  document.getElementById('zoneHeadingInput').value = Math.floor(zone.heading || 0);
  document.getElementById('zonePolyHeightInput').value = zone.height || 4.0;
  document.getElementById('zoneModelInput').value = zone.model_name || '';

  document.getElementById('zoneMaxItemsInput').value = zone.max_active_items || 5;
  document.getElementById('zoneMinItemsInput').value = zone.min_items || 2;
  document.getElementById('zoneMinDistInput').value = zone.min_distance || 2.0;

  document.getElementById('zoneMinRespawnInput').value = zone.min_respawn_time ?? 300;
  document.getElementById('zoneMaxRespawnInput').value = zone.max_respawn_time ?? 900;
  document.getElementById('zoneLifetimeInput').value = zone.item_lifetime !== undefined ? zone.item_lifetime : 1800;

  // Обновляем отображение координат центра
  const coordsEl = document.getElementById('zoneCoordsDisplay');
  if (coordsEl && zone.coords) {
    const cx = (zone.coords.x || 0).toFixed(1);
    const cy = (zone.coords.y || 0).toFixed(1);
    const cz = (zone.coords.z || 0).toFixed(1);
    coordsEl.innerText = `X: ${cx} | Y: ${cy} | Z: ${cz}`;
  }

  document.getElementById('zoneActivationInput').value = zone.activation_radius ?? 90;
  document.getElementById('zoneUniqueInput').checked = zone.custom_rules?.unique_items === true;
  document.getElementById('zoneExitInput').checked = zone.custom_rules?.respawn_after_exit === true;
  renderRuntimeStatus();
  updateGeometryPanels(zone.zone_type || 'circle');
  renderSelectedPoolItems();
}

function adjustZoneHeight(delta) {
  if (!activeZone) return;
  fetch(`https://${GetParentResourceName()}/adjustZoneZ`, {
    method: 'POST',
    body: JSON.stringify({ delta: delta })
  });
}

function updateGeometryPanels(zType) {
  document.getElementById('geomParamsCircle').style.display = (zType === 'circle') ? 'block' : 'none';
  document.getElementById('geomParamsRectangle').style.display = (zType === 'rectangle') ? 'block' : 'none';
  document.getElementById('geomParamsPolygon').style.display = (zType === 'polygon') ? 'block' : 'none';
  document.getElementById('geomParamsContainer').style.display = (zType === 'container' || zType === 'point') ? 'block' : 'none';

  if (zType === 'polygon' && activeZone && activeZone.points) {
    document.getElementById('polygonVertexCount').innerText = activeZone.points.length;
  }
}

function handleZoneFieldChange(field, value) {
  if (!activeZone) return;
  if (typeof value === 'number' && !Number.isFinite(value)) return;
  activeZone[field] = value;
  updateDirtyStatus();

  if (field === 'name') {
    document.getElementById('activeZoneNameText').innerText = value || 'Без названия';
  }

  fetch(`https://${GetParentResourceName()}/updateActiveZoneField`, {
    method: 'POST',
    body: JSON.stringify({ field: field, value: value })
  });
}

function handleZoneTypeChange(newType) {
  if (!activeZone) return;
  activeZone.zone_type = newType;
  if (newType === 'point' || newType === 'container') {
    handleZoneFieldChange('min_items', 1);
    handleZoneFieldChange('max_active_items', 1);
    document.getElementById('zoneMinItemsInput').value = 1;
    document.getElementById('zoneMaxItemsInput').value = 1;
  }
  updateGeometryPanels(newType);
  document.getElementById('activeZoneTypeBadge').innerText = newType.toUpperCase();
  handleZoneFieldChange('zone_type', newType);
}



// =================================================================
// 3. ОТРИСОВКА ПРЕДМЕТОВ В ПУЛЕ ЗОНЫ
// =================================================================

function renderSelectedPoolItems() {
  const container = document.getElementById('poolItemsListContainer');
  const countLabel = document.getElementById('selectedPoolCount');

  if (!activeZone || !activeZone.selected_items || activeZone.selected_items.length === 0) {
    countLabel.innerText = '0';
    container.innerHTML = `
      <div class="empty-pool-hint">
        В этой зоне пока нет предметов.<br>
        Нажмите <strong>«+ Выбрать предметы»</strong>, чтобы сформировать список добычи.
      </div>
    `;
    return;
  }

  const items = activeZone.selected_items;
  const totalWeight = items.reduce((sum, item) => sum + (Number(item.weight) || 100), 0);
  countLabel.innerText = items.length;

  let html = '';
  items.forEach((it, idx) => {
    const itemDef = itemsCatalog[it.item_name] || { label: it.item_name, weight: 0.1, maxStack: 1, rarity: 'white' };
    const rarity = RARITY_COLORS[itemDef.rarity] || RARITY_COLORS.white;
    const iconHtml = getItemIconElement(itemDef, it.item_name);
    const maxStack = itemDef.maxStack || 1;

    html += `
      <div class="pool-item-card" style="border-left-color: ${rarity.hex}">
        <div class="pool-item-info">
          <div class="pool-item-icon">${iconHtml}</div>
          <div class="pool-item-text">
            <span class="pool-item-title">${escapeHtml(itemDef.label || it.item_name)}</span>
            <span class="pool-item-id">${escapeHtml(it.item_name)} <span class="max-stack-tag">(стак: ${maxStack}, шанс: ${((Number(it.weight || 100) / totalWeight) * 100).toFixed(1)}%)</span></span>
          </div>
        </div>

        <div class="pool-item-params">
          <div class="item-param-col">
            <span>Вес <span class="help-tip" data-tip="Относительный вес шанса выпадения предмета среди других в пуле. Чем выше вес, тем выше вероятность спавна.">?</span></span>
            <input type="number" min="1" max="1000" value="${it.weight || 100}" onchange="updatePoolItemParam(${idx}, 'weight', parseInt(this.value))" />
          </div>
          <div class="item-param-col">
            <span>Мин <span class="help-tip" data-tip="Минимальное количество предметов в выпавшем стаке (от 1 до ${maxStack}).">?</span></span>
            <input type="number" min="1" max="${maxStack}" value="${it.min_count || 1}" onchange="updatePoolItemParam(${idx}, 'min_count', Math.min(${maxStack}, Math.max(1, parseInt(this.value) || 1)))" />
          </div>
          <div class="item-param-col">
            <span>Макс <span class="help-tip" data-tip="Максимальное количество предметов в выпавшем стаке (ограничено лимитом стака: ${maxStack}).">?</span></span>
            <input type="number" min="1" max="${maxStack}" value="${it.max_count || 1}" onchange="updatePoolItemParam(${idx}, 'max_count', Math.min(${maxStack}, Math.max(1, parseInt(this.value) || 1)))" />
          </div>
          <button class="btn-remove-pool-item" onclick="removePoolItem(${idx})" title="Удалить из пула">&times;</button>
        </div>
      </div>
    `;
  });

  container.innerHTML = html;
}

function updatePoolItemParam(idx, field, value) {
  if (!activeZone || !activeZone.selected_items || !activeZone.selected_items[idx]) return;
  const item = activeZone.selected_items[idx];
  const maxStack = itemsCatalog[item.item_name]?.maxStack || 1;
  item[field] = Math.max(1, Math.min(field === 'weight' ? 100000 : maxStack, Math.floor(value) || 1));
  if (item.min_count > item.max_count) item[field === 'min_count' ? 'max_count' : 'min_count'] = item[field];
  renderSelectedPoolItems();
  handleZoneFieldChange('selected_items', activeZone.selected_items);
}

function removePoolItem(idx) {
  if (!activeZone || !activeZone.selected_items) return;
  activeZone.selected_items.splice(idx, 1);
  renderSelectedPoolItems();
  handleZoneFieldChange('selected_items', activeZone.selected_items);
}

// =================================================================
// 4. МОДАЛКА ВЫБОРА ПРЕДМЕТОВ (КАТАЛОГ THEHUNT_ITEMS)
// =================================================================

function openItemCatalogModal() {
  if (!activeZone) return;

  tempSelectedItemsMap = {};
  if (activeZone.selected_items) {
    activeZone.selected_items.forEach(it => {
      tempSelectedItemsMap[it.item_name] = {
        item_name: it.item_name,
        weight: it.weight || 100,
        min_count: it.min_count || 1,
        max_count: it.max_count || 1,
        chance_override: it.chance_override,
        metadata: it.metadata
      };
    });
  }

  buildCatalogCategoryTabs();
  renderCatalogItems();
  updateModalSelectedCount();

  document.getElementById('itemCatalogModal').style.display = 'flex';
}

function closeItemCatalogModal() {
  document.getElementById('itemCatalogModal').style.display = 'none';
}

function buildCatalogCategoryTabs() {
  const tabsContainer = document.getElementById('catalogCategoryTabs');
  const categories = {
    all: 'Все предметы',
    food: 'Съедобное',
    medical: 'Медицина',
    material: 'Материалы',
    survival: 'Выживание',
    melee: 'Холодное оружие',
    gun: 'Огнестрельное',
    storage: 'Хранение',
    item: 'Разное'
  };

  let html = '';
  for (let key in categories) {
    const activeClass = (key === activeTabCategory) ? 'active' : '';
    html += `<button class="cat-tab-btn ${activeClass}" onclick="setCatalogCategory('${key}')">${categories[key]}</button>`;
  }
  tabsContainer.innerHTML = html;
}

function setCatalogCategory(cat) {
  activeTabCategory = cat;
  buildCatalogCategoryTabs();
  renderCatalogItems();
}

function renderCatalogItems() {
  const container = document.getElementById('catalogItemsGrid');
  const search = (document.getElementById('catalogSearchInput').value || '').toLowerCase().trim();

  let html = '';
  let count = 0;

  for (let itemName in itemsCatalog) {
    const it = itemsCatalog[itemName];
    const cat = it.category || 'item';

    if (activeTabCategory !== 'all' && cat !== activeTabCategory) continue;

    const label = (it.label || itemName).toLowerCase();
    if (search && !label.includes(search) && !itemName.toLowerCase().includes(search)) {
      continue;
    }

    count++;
    const isSelected = !!tempSelectedItemsMap[itemName];
    const selectedClass = isSelected ? 'selected' : '';
    const rarity = RARITY_COLORS[it.rarity] || RARITY_COLORS.white;
    const iconHtml = getItemIconElement(it, itemName);

    html += `
      <div class="catalog-item-card ${selectedClass}" onclick="toggleCatalogItem(${escapeHtml(JSON.stringify(itemName))})">
        <div class="catalog-item-top">
          <span style="color: ${rarity.hex}; font-size: 10px; font-weight: 700;">${rarity.label}</span>
          <div class="item-check-indicator">${isSelected ? '&#10003;' : ''}</div>
        </div>
        <div class="catalog-item-icon-box">${iconHtml}</div>
        <div class="catalog-item-name" title="${escapeHtml(it.label || itemName)}">${escapeHtml(it.label || itemName)}</div>
        <div class="catalog-item-meta">
          <span>${it.weight || 0.1} кг</span>
          <span>стак: ${it.maxStack || 1}</span>
        </div>
      </div>
    `;
  }

  if (count === 0) {
    html = `<div style="grid-column: 1/-1; text-align: center; color: #64748b; padding: 40px;">Предметы не найдены</div>`;
  }

  container.innerHTML = html;
}

function filterCatalogItems() {
  renderCatalogItems();
}

function toggleCatalogItem(itemName) {
  if (tempSelectedItemsMap[itemName]) {
    delete tempSelectedItemsMap[itemName];
  } else {
    tempSelectedItemsMap[itemName] = {
      item_name: itemName,
      weight: 100,
      min_count: 1,
      max_count: 1
    };
  }
  updateModalSelectedCount();
  renderCatalogItems();
}

function updateModalSelectedCount() {
  const count = Object.keys(tempSelectedItemsMap).length;
  document.getElementById('catalogModalSelectedCount').innerText = count;
}

function applyCatalogSelection() {
  if (!activeZone) return;

  const newList = [];
  for (let itemName in tempSelectedItemsMap) {
    newList.push(tempSelectedItemsMap[itemName]);
  }

  activeZone.selected_items = newList;
  renderSelectedPoolItems();
  handleZoneFieldChange('selected_items', newList);
  closeItemCatalogModal();
}

// =================================================================
// 5. МОДАЛКА ВЫБОРА ТИПА НОВОЙ ЗОНЫ
// =================================================================

function openCreateZoneModal() {
  if (savePending) return;
  if (activeZone && JSON.stringify(activeZone) !== savedSnapshot) {
    openConfirmDeleteModal('Создать новую зону и отменить несохранённые изменения текущей?', () => {
      savedSnapshot = JSON.stringify(activeZone);
      openCreateZoneModal();
    }, 'Продолжить');
    return;
  }
  document.getElementById('createZoneModal').style.display = 'flex';
}

function closeCreateZoneModal() {
  document.getElementById('createZoneModal').style.display = 'none';
}

function selectNewZoneType(zType) {
  closeCreateZoneModal();
  fetch(`https://${GetParentResourceName()}/createNewZone`, {
    method: 'POST',
    body: JSON.stringify({ zoneType: zType })
  });
}

// =================================================================
// 6. СПИСОК ВСЕХ ЗОН (DRAWER)
// =================================================================



function updateTopStats() {
  const el = document.getElementById('topZonesCount');
  if (!el) return;
  let count = 0;
  for (let key in allZones) {
    const z = allZones[key];
    if (z && (z.id || parseInt(key) > 0)) count++;
  }
  el.innerText = count;
}

function openZonesListDrawer() {
  renderZonesDrawerList();
  document.getElementById('zonesListDrawer').style.display = 'flex';
}

function closeZonesListDrawer() {
  document.getElementById('zonesListDrawer').style.display = 'none';
}

function renderZonesDrawerList() {
  const container = document.getElementById('zonesDrawerListContainer');
  if (!container) return;
  const search = (document.getElementById('zonesDrawerSearchInput').value || '').toLowerCase().trim();

  let html = '';
  let count = 0;

  for (let key in allZones) {
    const z = allZones[key];
    if (!z) continue;

    const zId = parseInt((z.id !== undefined && z.id !== null) ? z.id : key);
    if (!zId || isNaN(zId) || zId <= 0) continue;

    const name = (z.name || `Зона #${zId}`).toLowerCase();

    if (search && !name.includes(search) && !zId.toString().includes(search)) {
      continue;
    }

    count++;
    const isActiveRow = (activeZone && parseInt(activeZone.id) === zId) ? 'active-zone-row' : '';

    html += `
      <div class="zone-drawer-card ${isActiveRow}">
        <div class="drawer-card-info" onclick="selectZoneFromDrawer(${zId})" style="cursor: pointer;">
          <span class="drawer-card-title">${escapeHtml(z.name || `Зона #${zId}`)}</span>
          <div class="drawer-card-meta">
            <span>[#${zId}]</span>
            <span style="text-transform: uppercase;">${z.zone_type || 'circle'}</span>
            <span>Предметов: ${(z.selected_items && z.selected_items.length) || 0}</span>
            <span>${z.is_enabled ? '🟢 Вкл' : '🔴 Выкл'}</span>
          </div>
        </div>

        <div class="drawer-card-actions">
          <button class="btn-drawer-action" onclick="teleportToZoneById(${zId})" title="Телепорт камеры">📍 ТП</button>
          <button class="btn-drawer-action" onclick="selectZoneFromDrawer(${zId})">Редакт.</button>
          <button class="btn-drawer-action btn-sm-danger" onclick="deleteZoneById(${zId})" style="color: #ef4444;">&times;</button>
        </div>
      </div>
    `;
  }

  if (count === 0) {
    html = `<div style="text-align: center; color: #64748b; padding: 40px;">Зоны не найдены</div>`;
  }

  container.innerHTML = html;
}

function filterZonesDrawerList() {
  renderZonesDrawerList();
}

function selectZoneFromDrawer(zId) {
  if (savePending) return;
  if (activeZone && JSON.stringify(activeZone) !== savedSnapshot) {
    openConfirmDeleteModal('Перейти к другой зоне и отменить несохранённые изменения?', () => {
      savedSnapshot = JSON.stringify(activeZone);
      selectZoneFromDrawer(zId);
    }, 'Перейти');
    return;
  }
  closeZonesListDrawer();
  fetch(`https://${GetParentResourceName()}/selectZone`, {
    method: 'POST',
    body: JSON.stringify({ zoneId: zId })
  });
}

function teleportToZoneById(zId) {
  fetch(`https://${GetParentResourceName()}/teleportToZone`, {
    method: 'POST',
    body: JSON.stringify({ zoneId: zId })
  });
}

let pendingDeleteCallback = null;

function openConfirmDeleteModal(messageText, onConfirm, label = 'Удалить') {
  const modal = document.getElementById('confirmDeleteModal');
  const textEl = document.getElementById('confirmDeleteText');
  const btn = document.getElementById('btnConfirmDeleteAction');

  if (textEl) textEl.innerText = messageText;
  pendingDeleteCallback = onConfirm;
  btn.textContent = label;

  btn.onclick = () => {
    if (pendingDeleteCallback) {
      pendingDeleteCallback();
      pendingDeleteCallback = null;
    }
    closeConfirmDeleteModal();
  };

  if (modal) modal.style.display = 'flex';
}

function closeConfirmDeleteModal() {
  const modal = document.getElementById('confirmDeleteModal');
  if (modal) modal.style.display = 'none';
  pendingDeleteCallback = null;
}

function deleteZoneById(zId) {
  const idNum = parseInt(zId);
  if (!idNum || idNum <= 0) return;
  openConfirmDeleteModal(`Вы действительно хотите удалить зону #${idNum}?`, () => {
    fetch(`https://${GetParentResourceName()}/deleteZone`, {
      method: 'POST',
      body: JSON.stringify({ zoneId: idNum })
    });
  });
}

// =================================================================
// 7. ДЕЙСТВИЯ НИЖНЕЙ ПАНЕЛИ
// =================================================================

function saveCurrentZone() {
  if (!activeZone || savePending) return;
  const error = validateZoneForm();
  if (error) { setSaveStatus(error, true); return; }
  savePending = true;
  setSaveStatus('Сохранение…');
  saveTimer = setTimeout(() => {
    savePending = false;
    setSaveStatus('Нет ответа сервера. Проверьте список зон перед повтором.', true);
  }, 15000);
  fetch(`https://${GetParentResourceName()}/saveActiveZone`, {
    method: 'POST',
    body: JSON.stringify({ zoneData: activeZone })
  });
}

function deleteCurrentZone() {
  if (!activeZone) return;

  const zId = parseInt(activeZone.id) || 0;
  if (zId <= 0) {
    // Несохраненная черновая зона — просто сбрасываем её
    fetch(`https://${GetParentResourceName()}/deleteZone`, {
      method: 'POST',
      body: JSON.stringify({ zoneId: 0 })
    });
    setActiveZone(null);
    renderZonesDrawerList();
    updateTopStats();
    return;
  }

  openConfirmDeleteModal(`Вы уверены, что хотите удалить зону «${activeZone.name || 'Без названия'}» [#${zId}]?`, () => {
    const delId = zId;
    fetch(`https://${GetParentResourceName()}/deleteZone`, {
      method: 'POST',
      body: JSON.stringify({ zoneId: delId })
    });
  });
}

function duplicateCurrentZone() {
  if (!activeZone || !activeZone.id || savePending) return;
  if (JSON.stringify(activeZone) !== savedSnapshot) { setSaveStatus('Сначала сохраните изменения зоны', true); return; }
  fetch(`https://${GetParentResourceName()}/duplicateZone`, {
    method: 'POST',
    body: JSON.stringify({ zoneId: activeZone.id })
  });
}

function triggerTestLootSpawn() {
  if (!activeZone) return;
  const error = validateZoneForm();
  if (error) { setSaveStatus(error, true); return; }
  fetch(`https://${GetParentResourceName()}/testGenerateLoot`, {
    method: 'POST',
    body: JSON.stringify({ zoneData: activeZone })
  });
}

function triggerForceRespawn() {
  if (!activeZone || !activeZone.id || savePending) return;
  if (JSON.stringify(activeZone) !== savedSnapshot) { setSaveStatus('Сначала сохраните изменения зоны', true); return; }
  fetch(`https://${GetParentResourceName()}/forceRespawn`, {
    method: 'POST',
    body: JSON.stringify({ zoneId: activeZone.id })
  });
}

function moveZoneToCursor() {
  fetch(`https://${GetParentResourceName()}/moveZoneCenterToRaycast`, {
    method: 'POST',
    body: JSON.stringify({})
  });
}

function addVertexAtRaycast() {
  fetch(`https://${GetParentResourceName()}/addPolygonVertex`, {
    method: 'POST',
    body: JSON.stringify({})
  });
}

function removeSelectedVertex() {
  fetch(`https://${GetParentResourceName()}/removeSelectedVertex`, {
    method: 'POST',
    body: JSON.stringify({})
  });
}

function closeEditor() {
  if (savePending) return;
  if (activeZone && JSON.stringify(activeZone) !== savedSnapshot) {
    openConfirmDeleteModal('Есть несохранённые изменения. Закрыть редактор и отменить их?', () => {
      savedSnapshot = JSON.stringify(activeZone);
      closeEditor();
    }, 'Закрыть без сохранения');
    return;
  }
  fetch(`https://${GetParentResourceName()}/closeEditor`, {
    method: 'POST',
    body: JSON.stringify({})
  });
}

function closeAllModals() {
  closeItemCatalogModal();
  closeCreateZoneModal();
  closeZonesListDrawer();
  closeConfirmDeleteModal();
}

// =================================================================
// 8. ХЕЛПЕРЫ ИКОНОК И ФОКУСА
// =================================================================

function getItemIconElement(itemDef, itemName) {
  const name = itemName || (itemDef && itemDef.name);
  if (!name) return DEFAULT_SVG;

  const label = (itemDef && itemDef.label) || name;
  const imgSrc = (itemDef && itemDef.image) ? itemDef.image : `https://cfx-nui-thehunt_inventory/html/images/${name}.png`;

  return `<img class="item-icon-img" src="${escapeHtml(imgSrc)}" onload="if(this.nextElementSibling) this.nextElementSibling.style.display='none';" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';" alt="${escapeHtml(label)}" draggable="false" /><span class="fallback-icon-svg" style="display:flex;">${DEFAULT_SVG}</span>`;
}

// Отслеживание фокуса на текстовых полях ввода (блокировка контролов в игре)
document.addEventListener('focusin', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') {
    fetch(`https://${GetParentResourceName()}/setInputFocus`, {
      method: 'POST',
      body: JSON.stringify({ focused: true })
    });
  }
});

document.addEventListener('focusout', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') {
    fetch(`https://${GetParentResourceName()}/setInputFocus`, {
      method: 'POST',
      body: JSON.stringify({ focused: false })
    });
  }
});

// Закрытие по клавише Escape
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (document.getElementById('confirmDeleteModal').style.display === 'flex') {
      closeConfirmDeleteModal();
    } else if (document.getElementById('itemCatalogModal').style.display === 'flex') {
      closeItemCatalogModal();
    } else if (document.getElementById('createZoneModal').style.display === 'flex') {
      closeCreateZoneModal();
    } else if (document.getElementById('zonesListDrawer').style.display === 'flex') {
      closeZonesListDrawer();
    } else {
      closeEditor();
    }
  }
});

// =================================================================
// 9. ГЛОБАЛЬНАЯ СИСТЕМА УМНЫХ ВСПЛЫВАЮЩИХ ПОДСКАЗОК (TOOLTIPS)
// =================================================================

const globalTooltipEl = document.getElementById('globalHelpTooltip');

document.addEventListener('mouseover', (e) => {
  const tipTrigger = e.target.closest('.help-tip, [data-tip]');
  if (tipTrigger) {
    const tipText = tipTrigger.getAttribute('data-tip');
    if (tipText && globalTooltipEl) {
      globalTooltipEl.innerText = tipText;
      globalTooltipEl.style.display = 'block';
      globalTooltipEl.classList.add('visible');
      positionGlobalTooltip(tipTrigger);
    }
  }
});

document.addEventListener('mouseout', (e) => {
  const tipTrigger = e.target.closest('.help-tip, [data-tip]');
  if (tipTrigger && globalTooltipEl) {
    globalTooltipEl.classList.remove('visible');
    globalTooltipEl.style.display = 'none';
  }
});

function positionGlobalTooltip(targetEl) {
  if (!globalTooltipEl) return;
  const rect = targetEl.getBoundingClientRect();
  const tipRect = globalTooltipEl.getBoundingClientRect();

  // По умолчанию размещаем над элементом
  let top = rect.top - tipRect.height - 8;
  if (top < 10) {
    // Если сверху нет места — размещаем под элементом
    top = rect.bottom + 8;
  }

  // Центрируем по горизонтали относительно иконки
  let left = rect.left + (rect.width / 2) - (tipRect.width / 2);

  // Защита от вылета за левый и правый край экрана
  const padding = 12;
  if (left < padding) {
    left = padding;
  } else if (left + tipRect.width > window.innerWidth - padding) {
    left = window.innerWidth - tipRect.width - padding;
  }

  globalTooltipEl.style.top = `${top}px`;
  globalTooltipEl.style.left = `${left}px`;
}

function clearTestPreview() {
  fetch(`https://${GetParentResourceName()}/clearTestPreview`, {method: 'POST', body: '{}'});
}
document.addEventListener('keydown', event => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') {
    event.preventDefault();
    saveCurrentZone();
  }
});

function changeZoneRule(name, checked) {
  if (!activeZone) return;
  handleZoneFieldChange('custom_rules', {...activeZone.custom_rules, [name]: checked});
}
function renderRuntimeStatus() {
  const state = activeZone && zoneRuntime[activeZone.id];
  const label = !activeZone?.id ? 'Черновик — сохраните для активации'
    : !allZones[activeZone.id]?.is_enabled ? 'Зона выключена'
    : !state ? 'Получение состояния…'
    : `Лут: ${state.count} · ${state.busy ? 'Генерация / подбор' : state.cooldown > 0 ? `Респавн через ${Math.ceil(state.cooldown / 60)} мин` : state.waiting_exit ? 'Ожидание ухода игроков' : state.count > 0 ? 'Лут доступен' : 'Готова к генерации'} · ${state.nearby ? 'Игрок рядом' : 'Игроков рядом нет'}`;
  document.getElementById('zoneRuntimeStatus').textContent = label;
}
