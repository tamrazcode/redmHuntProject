/* =================================================================
   HUNT: Hard RP — The Corruption | Doors & Housing App
   ================================================================= */

const houseInfoModal = document.getElementById('houseInfoModal');
const houseTitle = document.getElementById('houseTitle');
const houseOwner = document.getElementById('houseOwner');
const houseStatus = document.getElementById('houseStatus');

const doorAdminWrapper = document.getElementById('doorAdminWrapper');
const doorAdminWindow = document.getElementById('doorAdminWindow');
const doorAdminHeader = document.getElementById('doorAdminHeader');
const adminHouseListContainer = document.getElementById('adminHouseListContainer');
const toastContainer = document.getElementById('toastContainer');

const doorTargetingHud = document.getElementById('doorTargetingHud');
const hudModeTitle = document.getElementById('hudModeTitle');
const hudCounterRow = document.getElementById('hudCounterRow');
const hudDoorCount = document.getElementById('hudDoorCount');
const hudLmbLabel = document.getElementById('hudLmbLabel');
const hudRmbAction = document.getElementById('hudRmbAction');

const houseNameModal = document.getElementById('houseNameModal');
const nameModalDoorCount = document.getElementById('nameModalDoorCount');
const modalHouseNameInput = document.getElementById('modalHouseNameInput');

let cachedHouses = {};
let cachedDoors = {};

// =================================================================
// DRAG & DROP ДЛЯ АДМИНКИ
// =================================================================

let isDragging = false;
let dragStartX = 0;
let dragStartY = 0;
let windowInitialLeft = 0;
let windowInitialTop = 0;

doorAdminHeader.addEventListener('mousedown', function (e) {
  if (e.target.classList.contains('close-btn') || e.target.classList.contains('admin-tab-btn')) return;
  isDragging = true;
  dragStartX = e.clientX;
  dragStartY = e.clientY;
  const rect = doorAdminWindow.getBoundingClientRect();
  windowInitialLeft = rect.left;
  windowInitialTop = rect.top;
  doorAdminWindow.style.transform = 'none';
});

window.addEventListener('mousemove', function (e) {
  if (!isDragging) return;
  const deltaX = e.clientX - dragStartX;
  const deltaY = e.clientY - dragStartY;
  doorAdminWindow.style.left = `${Math.max(10, windowInitialLeft + deltaX)}px`;
  doorAdminWindow.style.top = `${Math.max(10, windowInitialTop + deltaY)}px`;
});

window.addEventListener('mouseup', function () {
  isDragging = false;
});

// Toast
function showToast(title, message) {
  const toast = document.createElement('div');
  toast.className = 'toast-item';
  toast.innerHTML = `
    <div class="toast-title">${title}</div>
    <div class="toast-message">${message}</div>
  `;
  toastContainer.appendChild(toast);
  setTimeout(() => {
    toast.classList.add('hide');
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 300);
  }, 3000);
}

// =================================================================
// МОДАЛЬНОЕ ОКНО ИНФОРМАЦИИ О ДОМЕ
// =================================================================

function closeHouseInfo() {
  houseInfoModal.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/closeHouseInfoModal`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
}

// =================================================================
// АДМИНИСТРАТИВНАЯ ПАНЕЛЬ ДВЕРЕЙ
// =================================================================

function closeDoorAdmin() {
  doorAdminWrapper.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/closeDoorAdmin`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
}

function switchAdminTab(tabName) {
  const tabs = document.querySelectorAll('.admin-tab-btn');
  tabs.forEach((t) => t.classList.remove('active'));

  document.getElementById('tabAdminCreate').style.display = 'none';
  document.getElementById('tabAdminList').style.display = 'none';

  if (tabName === 'create') {
    tabs[0].classList.add('active');
    document.getElementById('tabAdminCreate').style.display = 'block';
  } else {
    tabs[1].classList.add('active');
    document.getElementById('tabAdminList').style.display = 'block';

    fetch(`https://${GetParentResourceName()}/adminRequestList`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    })
      .then((r) => r.json())
      .then((res) => {
        if (res) {
          cachedHouses = res.houses || {};
          cachedDoors = res.doors || {};
        }
        renderAdminHouseList();
      })
      .catch(() => {
        renderAdminHouseList();
      });
  }
}

// Запуск 3D режима лазерного выбора дверей
function startTargeting(mode) {
  doorAdminWrapper.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/startTargeting`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mode: mode })
  });
}

// Завершение сохранения дома с названием
function confirmHouseSave() {
  const name = modalHouseNameInput.value.trim() || 'Жилое здание';
  houseNameModal.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/confirmHouseSave`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ houseName: name })
  });
}

function cancelHouseNaming() {
  houseNameModal.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/cancelHouseNaming`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
}

// =================================================================
// РЕНДЕР СПИСКА ДОМОВ И ДВЕРЕЙ В АДМИНКЕ
// =================================================================

function renderAdminHouseList() {
  adminHouseListContainer.innerHTML = '';

  const validDoors = Object.values(cachedDoors || {}).filter((d) => d && typeof d === 'object' && d.id);
  const validHouses = Object.values(cachedHouses || {}).filter((h) => h && typeof h === 'object' && h.id);
  const standaloneDoors = validDoors.filter((d) => !d.house_id);

  if (validHouses.length === 0 && standaloneDoors.length === 0) {
    adminHouseListContainer.innerHTML = '<div style="color: #8c909c; font-size: 11.5px; text-align: center; padding: 20px;">Нет зарегистрированных домов или дверей</div>';
    return;
  }

  // 1. Дома
  validHouses.forEach((house) => {
    const hId = house.id;
    const linkedDoors = validDoors.filter((d) => d.house_id == hId);

    const card = document.createElement('div');
    card.className = 'house-item-card';

    const ownerText = house.owner_name ? `Жилец: ${house.owner_name}` : 'Свободен для заселения';
    const lockText = house.is_locked ? 'Заперто' : 'Открыто';

    card.innerHTML = `
      <div class="house-item-header">
        <span class="house-item-title">${house.name || 'Жилое здание'}</span>
        <span class="badge" style="background: rgba(255,255,255,0.06); border-color: rgba(255,255,255,0.2); color: #fff;">${linkedDoors.length} дв.</span>
      </div>
      <div class="house-item-info">
        <span>${ownerText}</span>
        <span style="color: ${house.is_locked ? '#f87171' : '#4ade80'};">${lockText}</span>
      </div>
      <div class="house-item-actions">
        <button class="btn-small-tp" onclick="teleportToHouse(${hId})">Телепорт</button>
        <button class="btn-small-del" onclick="deleteHouse(${hId})">Удалить</button>
      </div>
    `;

    adminHouseListContainer.appendChild(card);
  });

  // 2. Одиночные двери
  standaloneDoors.forEach((door) => {
    const card = document.createElement('div');
    card.className = 'house-item-card';

    card.innerHTML = `
      <div class="house-item-header">
        <span class="house-item-title">Одиночная дверь #${door.id}</span>
        <span class="badge">Физичная</span>
      </div>
      <div class="house-item-info">
        <span>Координаты: ${Math.round(door.x)}, ${Math.round(door.y)}, ${Math.round(door.z)}</span>
      </div>
      <div class="house-item-actions">
        <button class="btn-small-tp" onclick="teleportToDoor(${door.id})">Телепорт</button>
        <button class="btn-small-del" onclick="deleteDoor(${door.id})">Удалить</button>
      </div>
    `;

    adminHouseListContainer.appendChild(card);
  });
}

function teleportToHouse(houseId) {
  fetch(`https://${GetParentResourceName()}/adminTeleportToHouse`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ houseId: houseId })
  });
}

function teleportToDoor(doorId) {
  fetch(`https://${GetParentResourceName()}/adminTeleportToDoor`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ doorId: doorId })
  });
}

function deleteHouse(houseId) {
  fetch(`https://${GetParentResourceName()}/adminDeleteHouse`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ houseId: houseId })
  }).then(() => {
    delete cachedHouses[houseId];
    renderAdminHouseList();
    showToast('Удалено', 'Дом удален из базы данных');
  });
}

function deleteDoor(doorId) {
  fetch(`https://${GetParentResourceName()}/adminDeleteDoor`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ doorId: doorId })
  }).then(() => {
    delete cachedDoors[doorId];
    renderAdminHouseList();
    showToast('Удалено', 'Дверь удалена из базы данных');
  });
}

window.addEventListener('keydown', function (e) {
  if (e.key === 'Escape') {
    if (houseInfoModal.style.display !== 'none') {
      closeHouseInfo();
    } else if (houseNameModal.style.display !== 'none') {
      cancelHouseNaming();
    } else if (doorAdminWrapper.style.display !== 'none') {
      closeDoorAdmin();
    }
  } else if (e.key === 'Enter') {
    if (houseNameModal.style.display !== 'none') {
      confirmHouseSave();
    }
  }
});

// NUI Messages
window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data) return;

  if (data.type === 'SHOW_HOUSE_INFO') {
    houseTitle.innerText = data.title || 'Жилой дом';
    houseOwner.innerText = data.owner || 'Свободен';
    houseStatus.innerText = data.status || 'Открыто';
    houseInfoModal.style.display = 'flex';
  } else if (data.type === 'CLOSE_HOUSE_INFO') {
    houseInfoModal.style.display = 'none';
  } else if (data.type === 'OPEN_DOOR_ADMIN') {
    doorTargetingHud.style.display = 'none';
    houseNameModal.style.display = 'none';
    cachedHouses = data.houses || {};
    cachedDoors = data.doors || {};
    switchAdminTab('create');
    doorAdminWrapper.style.display = 'flex';
  } else if (data.type === 'CLOSE_DOOR_ADMIN') {
    doorAdminWrapper.style.display = 'none';
    doorTargetingHud.style.display = 'none';
    houseNameModal.style.display = 'none';
  } else if (data.type === 'SHOW_TARGETING_HUD') {
    doorAdminWrapper.style.display = 'none';
    if (data.mode === 'single') {
      hudModeTitle.innerText = 'Разблокировка одиночной двери';
      hudCounterRow.style.display = 'none';
      hudLmbLabel.innerText = 'Разблокировать дверь (сделать физичной)';
      hudRmbAction.style.display = 'none';
    } else if (data.mode === 'single_lock') {
      hudModeTitle.innerText = 'Блокировка двери обратно';
      hudCounterRow.style.display = 'none';
      hudLmbLabel.innerText = 'Заблокировать дверь обратно (запереть)';
      hudRmbAction.style.display = 'none';
    } else {
      hudModeTitle.innerText = 'Режим выбора дверей дома';
      hudCounterRow.style.display = 'flex';
      hudDoorCount.innerText = data.count || 0;
      hudLmbLabel.innerText = 'Добавить дверь';
      hudRmbAction.style.display = 'flex';
    }
    doorTargetingHud.style.display = 'block';
  } else if (data.type === 'UPDATE_HUD_COUNT') {
    hudDoorCount.innerText = data.count || 0;
  } else if (data.type === 'HIDE_TARGETING_HUD') {
    doorTargetingHud.style.display = 'none';
  } else if (data.type === 'OPEN_HOUSE_NAMING_MODAL') {
    doorTargetingHud.style.display = 'none';
    nameModalDoorCount.innerText = data.count || 0;
    modalHouseNameInput.value = '';
    houseNameModal.style.display = 'flex';
    setTimeout(() => {
      modalHouseNameInput.focus();
    }, 100);
  } else if (data.type === 'UPDATE_ADMIN_LIST') {
    cachedHouses = data.houses || {};
    cachedDoors = data.doors || {};
    renderAdminHouseList();
  } else if (data.type === 'SHOW_TOAST') {
    showToast(data.title || 'Инвентарь', data.message || '', data.notifyType || 'info');
  }
});

function showToast(title, message, notifyType = 'info') {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `toast-item toast-${notifyType}`;

  toast.innerHTML = `
    <div class="toast-title">${title}</div>
    <div class="toast-message">${message}</div>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.classList.add('hide');
    setTimeout(() => {
      toast.remove();
    }, 280);
  }, 3500);
}
