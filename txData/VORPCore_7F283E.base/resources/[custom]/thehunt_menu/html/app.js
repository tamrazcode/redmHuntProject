/* =================================================================
   HUNT: Hard RP — The Corruption | Player Settings Menu Script
   ================================================================= */

const playerWrapper = document.getElementById('playerWrapper');
const playerWindow = document.getElementById('playerWindow');
const playerHeader = document.getElementById('playerHeader');
const closeBtn = document.getElementById('closeBtn');
const toastContainer = document.getElementById('toastContainer');

let activeHudMode = 'always_on';
let activeHintsMode = 'always_on';

// Стили походки полностью из vorp_walkanim (локализация на русский)
const WALK_STYLES = [
  { id: 'MP_Style_Casual', label: 'Обычная' },
  { id: 'MP_Style_Crazy', label: 'Безумная' },
  { id: 'MP_Style_drunk', label: 'Пьяная' },
  { id: 'MP_Style_EasyRider', label: 'Вразвалку' },
  { id: 'MP_Style_Flamboyant', label: 'Щегольская' },
  { id: 'MP_Style_Greenhorn', label: 'Новичок' },
  { id: 'MP_Style_Gunslinger', label: 'Стрелок' },
  { id: 'MP_Style_inquisitive', label: 'Любопытная' },
  { id: 'MP_Style_Refined', label: 'Изысканная' },
  { id: 'MP_Style_SilentType', label: 'Скрытная' },
  { id: 'MP_Style_Veteran', label: 'Ветеран' },
  { id: 'noanim', label: 'По умолчанию' },
];

let currentWalkIndex = 0;

// =================================================================
// WEBAUDIO SOUND CHIMES
// =================================================================

let audioCtx = null;

function playUiSound(freq = 600, type = 'sine', duration = 0.08, gainVal = 0.035) {
  // UI sounds disabled for the player menu.
  return;
}

function playSuccessChime() {
  playUiSound(540, 'sine', 0.07, 0.04);
  setTimeout(() => {
    playUiSound(720, 'sine', 0.12, 0.035);
  }, 60);
}

// =================================================================
// DRAGGABLE WINDOW & POSITION PERSISTENCE
// =================================================================

let isDragging = false;
let dragStartX = 0;
let dragStartY = 0;
let windowInitialLeft = 0;
let windowInitialTop = 0;

function loadSavedPosition() {
  const saved = localStorage.getItem('thehunt_player_menu_pos');
  if (saved) {
    try {
      const pos = JSON.parse(saved);
      if (pos.x !== undefined && pos.y !== undefined) {
        // Проверяем границы экрана
        const maxLeft = window.innerWidth - playerWindow.offsetWidth - 10;
        const maxTop = window.innerHeight - playerWindow.offsetHeight - 10;
        const left = Math.max(10, Math.min(maxLeft, pos.x));
        const top = Math.max(10, Math.min(maxTop, pos.y));
        playerWindow.style.left = `${left}px`;
        playerWindow.style.top = `${top}px`;
        playerWindow.style.transform = 'none';
        return;
      }
    } catch (e) {}
  }
  // По умолчанию — слева по центру
  playerWindow.style.left = '80px';
  playerWindow.style.top = '140px';
  playerWindow.style.transform = 'none';
}

function saveWindowPosition() {
  const rect = playerWindow.getBoundingClientRect();
  localStorage.setItem('thehunt_player_menu_pos', JSON.stringify({
    x: Math.round(rect.left),
    y: Math.round(rect.top)
  }));
}

playerHeader.addEventListener('mousedown', function (e) {
  if (e.target === closeBtn || closeBtn.contains(e.target)) return;
  isDragging = true;
  dragStartX = e.clientX;
  dragStartY = e.clientY;
  const rect = playerWindow.getBoundingClientRect();
  windowInitialLeft = rect.left;
  windowInitialTop = rect.top;
  playerWindow.style.transform = 'none';
});

window.addEventListener('mousemove', function (e) {
  if (!isDragging) return;
  const deltaX = e.clientX - dragStartX;
  const deltaY = e.clientY - dragStartY;
  const newLeft = windowInitialLeft + deltaX;
  const newTop = windowInitialTop + deltaY;

  const maxLeft = window.innerWidth - playerWindow.offsetWidth - 10;
  const maxTop = window.innerHeight - playerWindow.offsetHeight - 10;

  playerWindow.style.left = `${Math.max(10, Math.min(maxLeft, newLeft))}px`;
  playerWindow.style.top = `${Math.max(10, Math.min(maxTop, newTop))}px`;
});

window.addEventListener('mouseup', function () {
  if (isDragging) {
    isDragging = false;
    saveWindowPosition();
  }
});

// =================================================================
// TOAST NOTIFICATIONS
// =================================================================

function showToast(title, message) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = 'toast-item';
  toast.innerHTML = `
    <div class="toast-title">${title}</div>
    <div class="toast-message">${message}</div>
  `;
  container.appendChild(toast);
  playSuccessChime();

  setTimeout(() => {
    toast.classList.add('hide');
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 300);
  }, 3500);
}

// =================================================================
// ACTIONS
// =================================================================

function requestCharReload() {
  playUiSound(480, 'sine', 0.05, 0.03);
  fetch(`https://${GetParentResourceName()}/requestCharacterReload`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
}

function updateCharacterPositionUi(enabled) {
  const button = document.getElementById('btnCharacterPosition');
  if (!button) return;
  button.disabled = !enabled;
  button.classList.toggle('disabled', !enabled);
}

function requestCharacterPosition() {
  const button = document.getElementById('btnCharacterPosition');
  if (!button || button.disabled) return;
  fetch(`https://${GetParentResourceName()}/requestCharacterPosition`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({})
  }).catch(() => {});
}

function updateHudModeUi(mode) {
  activeHudMode = mode;
  document.querySelectorAll('.status-hud-mode-card').forEach((card) => {
    card.classList.remove('active');
  });

  if (mode === 'always_on') {
    document.getElementById('modeAlwaysOn').classList.add('active');
  } else if (mode === 'dynamic') {
    document.getElementById('modeDynamic').classList.add('active');
  } else if (mode === 'always_off') {
    document.getElementById('modeAlwaysOff').classList.add('active');
  }
}

function updateHintsModeUi(mode) {
  // Для подсказок доступны только постоянное отображение и отключение.
  // Старое сохранённое значение dynamic переводим в постоянный режим.
  if (mode !== 'always_on' && mode !== 'always_off') {
    mode = 'always_on';
  }

  activeHintsMode = mode;
  document.querySelectorAll('.hints-hud-mode-card').forEach((card) => {
    card.classList.remove('active');
  });

  if (mode === 'always_on') {
    document.getElementById('hintsModeAlwaysOn').classList.add('active');
  } else if (mode === 'always_off') {
    document.getElementById('hintsModeAlwaysOff').classList.add('active');
  }
}

function setHudMode(mode) {
  if (activeHudMode === mode) return;
  playUiSound(650, 'sine', 0.06, 0.035);
  updateHudModeUi(mode);

  fetch(`https://${GetParentResourceName()}/setHudMode`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mode: mode })
  });

  const modeLabels = {
    always_on: 'Постоянно',
    dynamic: 'Динамически',
    always_off: 'Отключено'
  };

  showToast('Отображение показателей', modeLabels[mode] || mode);
}

function setHintsMode(mode) {
  if (mode !== 'always_on' && mode !== 'always_off') return;
  if (activeHintsMode === mode) return;
  playUiSound(650, 'sine', 0.06, 0.035);
  updateHintsModeUi(mode);

  fetch(`https://${GetParentResourceName()}/setHintsMode`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mode: mode })
  });

  const modeLabels = {
    always_on: 'Постоянно',
    always_off: 'Отключено'
  };

  showToast('Отображение подсказок', modeLabels[mode] || mode);
}

let isWalkDropdownOpen = false;

function renderWalkDropdown() {
  const container = document.getElementById('walkDropdownMenu');
  if (!container) return;

  container.innerHTML = '';
  WALK_STYLES.forEach((style, index) => {
    const itemEl = document.createElement('div');
    itemEl.className = 'walk-dropdown-item' + (index === currentWalkIndex ? ' active' : '');
    itemEl.setAttribute('data-index', index);
    itemEl.setAttribute('data-id', style.id);
    itemEl.innerHTML = `
      <span>${style.label}</span>
      <svg class="walk-item-check" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="20 6 9 17 4 12"></polyline>
      </svg>
    `;
    itemEl.addEventListener('click', (e) => {
      e.stopPropagation();
      selectWalkStyle(index);
      closeWalkDropdown();
    });
    container.appendChild(itemEl);
  });
}

function toggleWalkDropdown(e) {
  if (e) e.stopPropagation();
  if (isWalkDropdownOpen) {
    closeWalkDropdown();
  } else {
    openWalkDropdown();
  }
}

function openWalkDropdown() {
  const menu = document.getElementById('walkDropdownMenu');
  const box = document.getElementById('walkStyleValueBox');
  if (!menu || !box) return;

  renderWalkDropdown();
  menu.classList.add('show');
  box.classList.add('open');
  isWalkDropdownOpen = true;
  playUiSound(540, 'sine', 0.04, 0.02);

  setTimeout(() => {
    const activeEl = menu.querySelector('.walk-dropdown-item.active');
    if (activeEl) {
      activeEl.scrollIntoView({ block: 'nearest' });
    }
  }, 20);
}

function closeWalkDropdown() {
  const menu = document.getElementById('walkDropdownMenu');
  const box = document.getElementById('walkStyleValueBox');
  if (!menu || !box) return;

  menu.classList.remove('show');
  box.classList.remove('open');
  isWalkDropdownOpen = false;
}

function selectWalkStyle(index) {
  const len = WALK_STYLES.length;
  currentWalkIndex = ((index % len) + len) % len;
  const chosenStyle = WALK_STYLES[currentWalkIndex];

  const labelEl = document.getElementById('currentWalkStyleLabel');
  if (labelEl) {
    labelEl.textContent = chosenStyle.label;
  }

  playUiSound(620, 'sine', 0.05, 0.03);

  fetch(`https://${GetParentResourceName()}/setWalkStyle`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ style: chosenStyle.id })
  });

  showToast('Стиль походки', chosenStyle.label);
}

function updateWalkStyleUi(styleId) {
  const index = WALK_STYLES.findIndex((s) => s.id === styleId);
  currentWalkIndex = index !== -1 ? index : 0;
  const labelEl = document.getElementById('currentWalkStyleLabel');
  if (labelEl) {
    labelEl.textContent = WALK_STYLES[currentWalkIndex].label;
  }
  if (isWalkDropdownOpen) {
    renderWalkDropdown();
  }
}

function changeWalkStyle(direction, event) {
  if (event && event.stopPropagation) event.stopPropagation();
  closeWalkDropdown();
  selectWalkStyle(currentWalkIndex + direction);
}

function closeMenu() {
  closeWalkDropdown();
  playerWrapper.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/closePlayerMenu`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
}

closeBtn.addEventListener('click', closeMenu);

document.addEventListener('click', function (e) {
  if (isWalkDropdownOpen) {
    const group = document.querySelector('.walk-style-group');
    if (group && !group.contains(e.target)) {
      closeWalkDropdown();
    }
  }
});

window.addEventListener('keydown', function (e) {
  if (e.key === 'Escape' || e.code === 'Backquote' || e.key === '`' || e.key === 'ё' || e.key === 'Ё' || e.key === '~') {
    if (playerWrapper.style.display !== 'none') {
      closeMenu();
    }
  }
});

// =================================================================
// NUI MESSAGE LISTENER
// =================================================================

window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data) return;

  if (data.type === 'OPEN_PLAYER_MENU') {
    if (data.hudMode) {
      updateHudModeUi(data.hudMode);
    }
    if (data.hintsMode) {
      updateHintsModeUi(data.hintsMode);
    }
    if (data.walkStyle) {
      updateWalkStyleUi(data.walkStyle);
    }
    updateCharacterPositionUi(data.positionEnabled === true);
    loadSavedPosition();
    playerWrapper.style.display = 'flex';
    playUiSound(580, 'sine', 0.08, 0.03);
  } else if (data.type === 'CLOSE_PLAYER_MENU') {
    playerWrapper.style.display = 'none';
  } else if (data.type === 'UPDATE_CHARACTER_POSITION') {
    updateCharacterPositionUi(data.enabled === true);
  } else if (data.type === 'SHOW_TOAST') {
    showToast(data.title || 'Уведомление', data.message || '');
  }
});
