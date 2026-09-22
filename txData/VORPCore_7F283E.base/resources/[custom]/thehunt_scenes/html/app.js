// =================================================================
// HUNT: Hard RP — The Corruption | Scene Placer & Manager App
// =================================================================

// SVG Иконки вместо эмодзи
const SVG_ICONS = {
  clock: `<svg style="width:12px;height:12px;vertical-align:-1px;margin-right:3px;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>`,
  pin: `<svg style="width:12px;height:12px;vertical-align:-1px;margin-right:3px;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>`
};

let selectedColorIdx = 1;
let selectedDuration = 1800;
let selectedDistance = 15.0;

// =================================================================
// ОТСЛЕЖИВАНИЕ ФОКУСА ВВОДА ТЕКСТА (100% БЛОКИРОВКА УПРАВЛЕНИЯ В ИГРЕ)
// =================================================================
document.addEventListener('focusin', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
    fetch('https://thehunt_scenes/setInputFocusState', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hasFocus: true })
    }).catch(() => {});
  }
});

document.addEventListener('focusout', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
    fetch('https://thehunt_scenes/setInputFocusState', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hasFocus: false })
    }).catch(() => {});
  }
});

// =================================================================
// УНИВЕРСАЛЬНЫЙ DRAG & DROP
// =================================================================
function enableDragging(headerEl, windowEl) {
  if (!headerEl || !windowEl) return;
  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let initialLeft = 0;
  let initialTop = 0;

  headerEl.addEventListener('mousedown', (e) => {
    if (e.target.classList.contains('close-btn')) return;
    isDragging = true;
    dragStartX = e.clientX;
    dragStartY = e.clientY;
    const rect = windowEl.getBoundingClientRect();
    initialLeft = rect.left;
    initialTop = rect.top;
    windowEl.style.transform = 'none';
    windowEl.style.position = 'absolute';
    windowEl.style.left = `${initialLeft}px`;
    windowEl.style.top = `${initialTop}px`;
  });

  window.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    const deltaX = e.clientX - dragStartX;
    const deltaY = e.clientY - dragStartY;
    windowEl.style.left = `${Math.max(10, initialLeft + deltaX)}px`;
    windowEl.style.top = `${Math.max(10, initialTop + deltaY)}px`;
  });

  window.addEventListener('mouseup', () => {
    isDragging = false;
  });
}

document.addEventListener('DOMContentLoaded', () => {
  const sceneModalHeader = document.getElementById('sceneModalHeader');
  const sceneWindow = document.getElementById('sceneWindow');
  const myScenesModalHeader = document.getElementById('myScenesModalHeader');
  const myScenesWindow = document.getElementById('myScenesWindow');

  enableDragging(sceneModalHeader, sceneWindow);
  enableDragging(myScenesModalHeader, myScenesWindow);

  const sceneText = document.getElementById('sceneText');
  const charCounter = document.getElementById('charCounter');
  if (sceneText && charCounter) {
    sceneText.addEventListener('input', () => {
      const len = sceneText.value.length;
      charCounter.textContent = `${len} / 250`;
      if (len > 230) {
        charCounter.style.color = '#ef4444';
      } else {
        charCounter.style.color = '#94a3b8';
      }
    });
  }

  const btnCloseHeader = document.getElementById('btnCloseHeader');
  const btnCancel = document.getElementById('btnCancel');
  const btnConfirm = document.getElementById('btnConfirm');
  if (btnCloseHeader) btnCloseHeader.addEventListener('click', closeSceneModal);
  if (btnCancel) btnCancel.addEventListener('click', closeSceneModal);
  if (btnConfirm) btnConfirm.addEventListener('click', confirmPlacement);

  const btnMyScenesCloseHeader = document.getElementById('btnMyScenesCloseHeader');
  const btnMyScenesCancel = document.getElementById('btnMyScenesCancel');
  const btnDeleteAllMyScenes = document.getElementById('btnDeleteAllMyScenes');
  if (btnMyScenesCloseHeader) btnMyScenesCloseHeader.addEventListener('click', closeMyScenesModal);
  if (btnMyScenesCancel) btnMyScenesCancel.addEventListener('click', closeMyScenesModal);
  if (btnDeleteAllMyScenes) {
    btnDeleteAllMyScenes.addEventListener('click', () => {
      fetch('https://thehunt_scenes/deleteAllMyScenesFromUI', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      }).catch(() => {});
      closeMyScenesModal();
    });
  }
});

// =================================================================
// МОДАЛКА 1: СОЗДАНИЕ СЦЕНЫ (/scene)
// =================================================================
function openSceneModal(data) {
  const myScenesApp = document.getElementById('myScenesApp');
  const sceneApp = document.getElementById('sceneApp');
  const sceneText = document.getElementById('sceneText');
  const charCounter = document.getElementById('charCounter');
  const sceneWindow = document.getElementById('sceneWindow');
  const colorsContainer = document.getElementById('colorsContainer');
  const durationsContainer = document.getElementById('durationsContainer');
  const distancesContainer = document.getElementById('distancesContainer');

  if (myScenesApp) myScenesApp.style.display = 'none';
  if (sceneText) sceneText.value = '';
  if (charCounter) {
    charCounter.textContent = '0 / 250';
    charCounter.style.color = '#94a3b8';
  }

  selectedColorIdx = data.defaultColor || 1;
  selectedDuration = data.defaultDuration || 1800;
  selectedDistance = data.defaultDistance || 15.0;

  if (sceneWindow) {
    sceneWindow.style.transform = 'none';
    sceneWindow.style.position = 'relative';
    sceneWindow.style.left = 'auto';
    sceneWindow.style.top = 'auto';
  }

  // Цвета
  if (colorsContainer) {
    colorsContainer.innerHTML = '';
    if (data.colors && Array.isArray(data.colors)) {
      data.colors.forEach((c, idx) => {
        const colIdx = c.id || (idx + 1);
        const card = document.createElement('div');
        card.className = `color-card ${colIdx === selectedColorIdx ? 'active' : ''}`;

        card.innerHTML = `
          <div class="color-dot" style="background-color: ${c.hex}; box-shadow: 0 0 6px ${c.hex}88;"></div>
          <span class="color-name">${c.label}</span>
        `;

        card.addEventListener('click', () => {
          selectedColorIdx = colIdx;
          document.querySelectorAll('.color-card').forEach(el => el.classList.remove('active'));
          card.classList.add('active');
        });

        colorsContainer.appendChild(card);
      });
    }
  }

  // Длительность
  if (durationsContainer) {
    durationsContainer.innerHTML = '';
    if (data.durations && Array.isArray(data.durations)) {
      data.durations.forEach(d => {
        const pill = document.createElement('div');
        pill.className = `pill-card ${d.value === selectedDuration ? 'active' : ''}`;
        pill.textContent = d.label;

        pill.addEventListener('click', () => {
          selectedDuration = d.value;
          document.querySelectorAll('#durationsContainer .pill-card').forEach(el => el.classList.remove('active'));
          pill.classList.add('active');
        });

        durationsContainer.appendChild(pill);
      });
    }
  }

  // Дальность
  if (distancesContainer) {
    distancesContainer.innerHTML = '';
    if (data.distances && Array.isArray(data.distances)) {
      data.distances.forEach(dst => {
        const pill = document.createElement('div');
        pill.className = `pill-card ${dst.value === selectedDistance ? 'active' : ''}`;
        pill.textContent = dst.label;

        pill.addEventListener('click', () => {
          selectedDistance = dst.value;
          document.querySelectorAll('#distancesContainer .pill-card').forEach(el => el.classList.remove('active'));
          pill.classList.add('active');
        });

        distancesContainer.appendChild(pill);
      });
    }
  }

  if (sceneApp) {
    sceneApp.style.display = 'flex';
    setTimeout(() => {
      if (sceneText) sceneText.focus();
    }, 50);
  }
}

function closeSceneModal() {
  const sceneApp = document.getElementById('sceneApp');
  if (sceneApp) sceneApp.style.display = 'none';
  fetch('https://thehunt_scenes/closeSceneUI', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).catch(() => {});
}

function confirmPlacement() {
  const sceneText = document.getElementById('sceneText');
  const sceneApp = document.getElementById('sceneApp');
  const text = sceneText ? sceneText.value.trim() : '';
  if (!text) {
    if (sceneText) sceneText.focus();
    return;
  }

  if (sceneApp) sceneApp.style.display = 'none';

  fetch('https://thehunt_scenes/confirmScene', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: text,
      colorIdx: selectedColorIdx,
      duration: selectedDuration,
      viewDistance: selectedDistance
    })
  }).catch(() => {});
}

// =================================================================
// МОДАЛКА 2: СПИСОК МОИХ СЦЕН (/scenes)
// =================================================================
function openMyScenesModal(data) {
  const sceneApp = document.getElementById('sceneApp');
  const myScenesApp = document.getElementById('myScenesApp');
  const myScenesWindow = document.getElementById('myScenesWindow');
  const myScenesCountBadge = document.getElementById('myScenesCountBadge');
  const myScenesListContainer = document.getElementById('myScenesListContainer');

  if (sceneApp) sceneApp.style.display = 'none';
  const scenes = data.scenes || [];
  const maxScenes = data.maxScenes || 5;

  if (myScenesCountBadge) myScenesCountBadge.textContent = `${scenes.length} / ${maxScenes}`;

  if (myScenesWindow) {
    myScenesWindow.style.transform = 'none';
    myScenesWindow.style.position = 'relative';
    myScenesWindow.style.left = 'auto';
    myScenesWindow.style.top = 'auto';
  }

  if (myScenesListContainer) {
    myScenesListContainer.innerHTML = '';
    if (scenes.length === 0) {
      myScenesListContainer.innerHTML = '<div class="empty-scenes-placeholder">У вас нет активных сцен в мире</div>';
    } else {
      scenes.forEach(s => {
        const card = document.createElement('div');
        card.className = 'scene-item-card';

        let expStr = 'Навсегда';
        if (s.expiresAt && s.expiresAt > 0) {
          const remaining = Math.max(0, Math.floor(s.expiresAt - (Date.now() / 1000)));
          const mins = Math.floor(remaining / 60);
          const hours = Math.floor(mins / 60);
          expStr = hours > 0 ? `Осталось ~${hours} ч ${mins % 60} мин` : `Осталось ~${mins} мин`;
        }

        card.innerHTML = `
          <div class="scene-item-info">
            <div class="scene-item-text" style="color: ${s.color || '#fff'}">${s.text}</div>
            <div class="scene-item-meta">
              <span>${SVG_ICONS.clock}${expStr}</span>
              <span>${SVG_ICONS.pin}${s.distance ? Math.floor(s.distance) + ' м от вас' : 'В мире'}</span>
            </div>
          </div>
          <button class="scene-del-btn" data-id="${s.id}">Удалить</button>
        `;

        card.querySelector('.scene-del-btn').addEventListener('click', () => {
          fetch('https://thehunt_scenes/deleteSceneFromUI', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ sceneId: s.id })
          }).catch(() => {});
          card.remove();
          const currentCount = myScenesListContainer.querySelectorAll('.scene-item-card').length;
          if (myScenesCountBadge) myScenesCountBadge.textContent = `${currentCount} / ${maxScenes}`;
          if (currentCount === 0) {
            myScenesListContainer.innerHTML = '<div class="empty-scenes-placeholder">У вас нет активных сцен в мире</div>';
          }
        });

        myScenesListContainer.appendChild(card);
      });
    }
  }

  if (myScenesApp) myScenesApp.style.display = 'flex';
}

function closeMyScenesModal() {
  const myScenesApp = document.getElementById('myScenesApp');
  if (myScenesApp) myScenesApp.style.display = 'none';
  fetch('https://thehunt_scenes/closeSceneUI', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).catch(() => {});
}

// =================================================================
// ГЛОБАЛЬНЫЕ ГОРЯЧИЕ КЛАВИШИ И NUI СООБЩЕНИЯ
// =================================================================
window.addEventListener('keydown', (e) => {
  const sceneApp = document.getElementById('sceneApp');
  const myScenesApp = document.getElementById('myScenesApp');

  if (sceneApp && sceneApp.style.display !== 'none') {
    if (e.key === 'Escape') {
      closeSceneModal();
    } else if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      confirmPlacement();
    }
  } else if (myScenesApp && myScenesApp.style.display !== 'none') {
    if (e.key === 'Escape') {
      closeMyScenesModal();
    }
  }
});

window.addEventListener('message', (event) => {
  const item = event.data;
  if (!item) return;

  if (item.type === 'OPEN_SCENE_UI') {
    openSceneModal(item);
  } else if (item.type === 'OPEN_MY_SCENES_UI') {
    openMyScenesModal(item);
  } else if (item.type === 'CLOSE_SCENE_UI') {
    const sceneApp = document.getElementById('sceneApp');
    const myScenesApp = document.getElementById('myScenesApp');
    if (sceneApp) sceneApp.style.display = 'none';
    if (myScenesApp) myScenesApp.style.display = 'none';
  }
});
