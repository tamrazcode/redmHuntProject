/* =================================================================
   HUNT: Hard RP — The Corruption | Status & Cores HUD App
   ================================================================= */

const CIRCLE_CIRCUMFERENCE = 113.097; // 2 * Math.PI * 18

// Элементы главного HUD
const fillHealth = document.getElementById('fillHealth');
const fillHealthGhost = document.getElementById('fillHealthGhost');
const fillStamina = document.getElementById('fillStamina');
const fillHorseHealth = document.getElementById('fillHorseHealth');
const fillHorseStamina = document.getElementById('fillHorseStamina');
const fillFood = document.getElementById('fillFood');
const fillWater = document.getElementById('fillWater');
const fillVoice = document.getElementById('fillVoice');
const fillSpeed = document.getElementById('fillSpeed');

const circleHealth = document.getElementById('circleHealth');
const circleStamina = document.getElementById('circleStamina');
const circleHorseHealth = document.getElementById('circleHorseHealth');
const circleHorseStamina = document.getElementById('circleHorseStamina');
const circleFood = document.getElementById('circleFood');
const circleWater = document.getElementById('circleWater');
const circleVoice = document.getElementById('circleVoice');
const circleSpeed = document.getElementById('circleSpeed');

const voiceIconContainer = document.getElementById('voiceIconContainer');
const mainStatusHud = document.getElementById('mainStatusHud');
const quickSlotsHud = document.getElementById('quickSlotsHud');
const quickSlotElements = [1, 2, 3, 4].map((slot) => document.getElementById(`quickSlot${slot}`));
const hintsHud = document.getElementById('hintsHud');

// Элементы всплывающих автономных индикаторов (когда основной худ скрыт)
const standaloneVoicePopup = document.getElementById('standaloneVoicePopup');
const popupCircleVoice = document.getElementById('popupCircleVoice');
const popupFillVoice = document.getElementById('popupFillVoice');
const popupVoiceIconContainer = document.getElementById('popupVoiceIconContainer');

const standaloneSpeedPopup = document.getElementById('standaloneSpeedPopup');
const popupCircleSpeed = document.getElementById('popupCircleSpeed');
const popupFillSpeed = document.getElementById('popupFillSpeed');

// Баффы и дебаффы
const statusHud = document.getElementById('statusHud');
const effectsList = document.getElementById('effectsList');
const activeEffects = new Map();

// Состояние HUD
let currentHudMode = 'always_on'; // 'always_on' | 'dynamic' | 'always_off'
let currentQuickSlotsMode = 'always_on'; // 'always_on' | 'dynamic' | 'always_off'
let currentHintsMode = 'always_on'; // 'always_on' | 'dynamic' | 'always_off'
let isSystemHudVisible = false;
let isMainHudCurrentlyVisible = false;
let dynamicHintsUntil = 0;
let dynamicHintsTimer = null;

let cachedData = {
  health: 100,
  stamina: 100,
  horseHealth: 100,
  horseStamina: 100,
  horseMounted: false,
  food: 100,
  water: 100,
  voiceMode: 2,
  isTalking: false,
  speedPercent: 66
};

let speedPopupTimer = null;
let lastTalkingState = null;
let activeAdminNotificationHide = null;
let cachedQuickSlots = [null, null, null, null];

// SVG иконки микрофона (перечёркнутый и активный)
const SVG_MIC_MUTED = `
  <svg viewBox="0 0 24 24">
    <line x1="2" y1="2" x2="22" y2="22" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M18.89 13.23A7.12 7.12 0 0 0 19 12v-2" stroke="#ffffff" stroke-width="2" fill="none"/>
    <path d="M5 10v2a7 7 0 0 0 12 5" stroke="#ffffff" stroke-width="2" fill="none"/>
    <path d="M15 9.34V5a3 3 0 0 0-5.68-1.33" stroke="#ffffff" stroke-width="2" fill="none"/>
    <path d="M9 9v3a3 3 0 0 0 5.12 2.12" stroke="#ffffff" stroke-width="2" fill="none"/>
    <line x1="12" y1="19" x2="12" y2="22" stroke="#ffffff" stroke-width="2"/>
  </svg>
`;

const SVG_MIC_ACTIVE = `
  <svg viewBox="0 0 24 24" fill="currentColor">
    <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
    <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
  </svg>
`;

/**
 * Установка процента заполнения кругового бара (0 - 100%)
 */
function setCircleProgress(circleFillElement, percent) {
  if (!circleFillElement) return;
  const p = Math.max(0, Math.min(100, Number(percent) || 0));
  const offset = CIRCLE_CIRCUMFERENCE * (1 - (p / 100));
  circleFillElement.style.strokeDashoffset = offset;
}

/**
 * Обновление круга дистанции войса (1 = 33%, 2 = 66%, 3 = 100%)
 */
function updateVoiceDistance(mode) {
  const m = Number(mode) || 2;
  const voicePercent = m === 1 ? 33 : (m === 2 ? 66 : 100);
  setCircleProgress(fillVoice, voicePercent);
  setCircleProgress(popupFillVoice, voicePercent);
}

/**
 * Обновление скорости походки
 */
function updateSpeedPercent(pct) {
  cachedData.speedPercent = pct;
  setCircleProgress(fillSpeed, pct);
  setCircleProgress(popupFillSpeed, pct);

  // Если основной худ скрыт, всплывает отдельный значок скорости
  if (isSystemHudVisible && !isMainHudCurrentlyVisible) {
    if (standaloneSpeedPopup) {
      standaloneSpeedPopup.classList.remove('popup-hidden');
      if (speedPopupTimer) clearTimeout(speedPopupTimer);
      speedPopupTimer = setTimeout(() => {
        if (standaloneSpeedPopup) {
          standaloneSpeedPopup.classList.add('popup-hidden');
        }
      }, 2500);
    }
  }
}

/**
 * Вычисление и применение видимости главного HUD по выбранному режиму
 */
const QUICK_SLOT_ASSET_BASE = 'https://cfx-nui-thehunt_inventory/html/';

function quickSlotAssetUrl(path) {
  const normalizedPath = String(path || '').replace(/^\/+/, '');
  if (!normalizedPath) return '';
  if (normalizedPath.startsWith('html/')) {
    return `https://cfx-nui-thehunt_inventory/${normalizedPath}`;
  }
  return `${QUICK_SLOT_ASSET_BASE}${normalizedPath}`;
}

function quickSlotIconUrl(item) {
  if (!item) return '';
  const raw = String(item.image || '').trim();
  if (raw.startsWith('nui://thehunt_inventory/')) {
    return quickSlotAssetUrl(raw.slice('nui://thehunt_inventory/'.length));
  }
  if (raw.startsWith('nui://') || raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:')) {
    return raw;
  }
  if (raw.startsWith('images/') || raw.startsWith('html/images/')) return quickSlotAssetUrl(raw);
  const name = String(item.icon || item.name || '').trim().toLowerCase();
  return name ? quickSlotAssetUrl(`images/${name}.png`) : '';
}

function renderQuickSlots(slots) {
  const normalized = [null, null, null, null];
  if (Array.isArray(slots)) {
    slots.forEach((item, index) => {
      const slot = Number(item && item.slot) || (index + 1);
      if (slot >= 1 && slot <= 4 && item && item.dbId) normalized[slot - 1] = item;
    });
  } else if (slots && typeof slots === 'object') {
    Object.values(slots).forEach((item) => {
      const slot = Number(item && item.slot);
      if (slot >= 1 && slot <= 4 && item.dbId) normalized[slot - 1] = item;
    });
  }
  cachedQuickSlots = normalized;

  quickSlotElements.forEach((slotElement, index) => {
    if (!slotElement) return;
    const item = normalized[index];
    const hasItem = Boolean(item && item.dbId);
    const content = slotElement.querySelector('.quick-slot-content');
    slotElement.classList.toggle('quick-slot-empty', !hasItem);
    slotElement.style.display = currentQuickSlotsMode === 'dynamic' && !hasItem ? 'none' : 'flex';
    if (!content) return;
    content.innerHTML = '';
    if (!hasItem) return;

    const imageUrl = quickSlotIconUrl(item);
    if (imageUrl) {
      const image = document.createElement('img');
      image.src = imageUrl;
      image.alt = String(item.label || item.name || 'Предмет');
      image.draggable = false;
      image.onerror = () => {
        const fallback = imageUrl.replace(QUICK_SLOT_ASSET_BASE, 'nui://thehunt_inventory/html/');
        if (fallback !== image.src && !image.dataset.fallback) {
          image.dataset.fallback = '1';
          image.src = fallback;
        } else {
          image.remove();
        }
      };
      content.appendChild(image);
    }
    const count = Number(item.count) || 0;
    if (count > 1) {
      const countBadge = document.createElement('span');
      countBadge.className = 'quick-slot-count';
      countBadge.textContent = String(count);
      content.appendChild(countBadge);
    }
  });
  evaluateQuickSlotsVisibility();
}

function evaluateQuickSlotsVisibility() {
  if (!quickSlotsHud) return;
  const hasAnyItem = cachedQuickSlots.some((item) => Boolean(item && item.dbId));
  const shouldShow = isSystemHudVisible && currentQuickSlotsMode !== 'always_off'
    && (currentQuickSlotsMode === 'always_on' || hasAnyItem);
  quickSlotsHud.classList.toggle('quick-slots-hidden', !shouldShow);
  quickSlotsHud.setAttribute('aria-hidden', shouldShow ? 'false' : 'true');
}

function evaluateHudVisibility() {
  if (!isSystemHudVisible) {
    isMainHudCurrentlyVisible = false;
    mainStatusHud.classList.add('hud-hidden');
    if (standaloneVoicePopup) standaloneVoicePopup.classList.add('popup-hidden');
    if (standaloneSpeedPopup) standaloneSpeedPopup.classList.add('popup-hidden');
    evaluateQuickSlotsVisibility();
    return;
  }

  const isLowHorseValues = cachedData.horseMounted && (cachedData.horseHealth <= 25 || cachedData.horseStamina <= 25);
  const isLowValues = (Math.abs(cachedData.thermalStress || 0) >= 0.75 || cachedData.health <= 25 || cachedData.food <= 25 || cachedData.water <= 25 || isLowHorseValues);

  let shouldShowMain = false;
  if (currentHudMode === 'always_on') {
    shouldShowMain = true;
  } else if (currentHudMode === 'dynamic') {
    shouldShowMain = isLowValues;
  } else if (currentHudMode === 'always_off') {
    shouldShowMain = false;
  }

  isMainHudCurrentlyVisible = shouldShowMain;

  if (shouldShowMain) {
    mainStatusHud.classList.remove('hud-hidden');
    // Скрываем отдельные всплывающие индикаторы, так как они есть в основном ряду
    if (standaloneVoicePopup) standaloneVoicePopup.classList.add('popup-hidden');
    if (standaloneSpeedPopup) standaloneSpeedPopup.classList.add('popup-hidden');
  } else {
    mainStatusHud.classList.add('hud-hidden');
    // Если игрок говорит в данный момент — всплывает отдельный микрофон
    if (cachedData.isTalking && standaloneVoicePopup) {
      standaloneVoicePopup.classList.remove('popup-hidden');
    }
  }
  evaluateQuickSlotsVisibility();
}

/**
 * Отдельная видимость HUD подсказок. Она не зависит от режима показателей.
 * Динамический режим показывает подсказки временно после входа в мир или
 * после включения этого режима в меню.
 */
function evaluateHintsVisibility() {
  if (!hintsHud) return;

  const shouldShow = isSystemHudVisible && (
    currentHintsMode === 'always_on' ||
    (currentHintsMode === 'dynamic' && dynamicHintsUntil > Date.now())
  );

  hintsHud.classList.toggle('hints-hidden', !shouldShow);
  hintsHud.setAttribute('aria-hidden', shouldShow ? 'false' : 'true');
}

function showHintsTemporarily(duration = 10000) {
  const durationMs = Math.max(1000, Number(duration) || 10000);
  dynamicHintsUntil = Date.now() + durationMs;

  if (dynamicHintsTimer) clearTimeout(dynamicHintsTimer);
  evaluateHintsVisibility();

  dynamicHintsTimer = setTimeout(() => {
    dynamicHintsUntil = 0;
    evaluateHintsVisibility();
  }, durationMs + 50);
}

/**
 * Обновление значений HUD
 */
function updateStatusValues(data) {
  if (!data) return;

  // 1. Здоровье
  if (data.health !== undefined) {
    cachedData.health = Number(data.health);
    setCircleProgress(fillHealth, cachedData.health);
  }

  // 1.1 Превью отхила медициной (полупрозрачное кольцо будущего здоровья)
  if (data.healPreview !== undefined && data.healPreview !== null && Number(data.healPreview) > cachedData.health && cachedData.health < 100) {
    const ghostPct = Math.min(100, Math.max(cachedData.health, Number(data.healPreview)));
    setCircleProgress(fillHealthGhost, ghostPct);
    if (fillHealthGhost) fillHealthGhost.classList.add('is-active');
  } else {
    if (fillHealthGhost) {
      fillHealthGhost.classList.remove('is-active');
      setCircleProgress(fillHealthGhost, cachedData.health);
    }
  }

  // 2. Выносливость
  if (data.stamina !== undefined) {
    cachedData.stamina = Number(data.stamina);
    setCircleProgress(fillStamina, cachedData.stamina);
  }

  // 2.1. Здоровье и выносливость лошади отображаются только во время езды верхом.
  if (data.horseMounted !== undefined) {
    cachedData.horseMounted = data.horseMounted === true;
    if (data.horseHealth !== undefined) {
      cachedData.horseHealth = Number(data.horseHealth);
      setCircleProgress(fillHorseHealth, cachedData.horseHealth);
    }
    if (data.horseStamina !== undefined) {
      cachedData.horseStamina = Number(data.horseStamina);
      setCircleProgress(fillHorseStamina, cachedData.horseStamina);
    }
    if (circleHorseHealth) {
      circleHorseHealth.classList.toggle('horse-health-hidden', !cachedData.horseMounted);
    }
    if (circleHorseStamina) {
      circleHorseStamina.classList.toggle('horse-stamina-hidden', !cachedData.horseMounted);
    }
  }

  // 3. Сытость
  if (data.food !== undefined) {
    cachedData.food = Number(data.food);
    setCircleProgress(fillFood, cachedData.food);
  }

  // 4. Жажда
  if (data.water !== undefined) {
    cachedData.water = Number(data.water);
    setCircleProgress(fillWater, cachedData.water);
  }

  // 5. Войс мод (дистанция)
  if (data.voiceMode !== undefined) {
    cachedData.voiceMode = data.voiceMode;
    updateVoiceDistance(data.voiceMode);
  }

  // 6. Микрофон (разговор)
  if (data.isTalking !== undefined) {
    const isTalking = (data.isTalking === true);
    cachedData.isTalking = isTalking;

    if (lastTalkingState !== isTalking) {
      lastTalkingState = isTalking;
      
      // Обновляем стиль на основном круге
      circleVoice.classList.toggle('is-talking', isTalking);
      if (voiceIconContainer) {
        voiceIconContainer.innerHTML = isTalking ? SVG_MIC_ACTIVE : SVG_MIC_MUTED;
      }

      // Обновляем стиль на всплывающем микрофоне
      if (popupCircleVoice) {
        popupCircleVoice.classList.toggle('is-talking', isTalking);
      }
      if (popupVoiceIconContainer) {
        popupVoiceIconContainer.innerHTML = isTalking ? SVG_MIC_ACTIVE : SVG_MIC_MUTED;
      }

      // Управление всплыванием микрофона при скрытом основном HUD
      if (!isMainHudCurrentlyVisible && isSystemHudVisible && standaloneVoicePopup) {
        if (isTalking) {
          standaloneVoicePopup.classList.remove('popup-hidden');
        } else {
          standaloneVoicePopup.classList.add('popup-hidden');
        }
      }
    }
  }

  // Перепроверяем общую видимость худа (динамический порог)
  evaluateHudVisibility();
}

// Инициализация
setCircleProgress(fillHealth, 100);
setCircleProgress(fillStamina, 100);
setCircleProgress(fillHorseHealth, 100);
setCircleProgress(fillHorseStamina, 100);
setCircleProgress(fillFood, 100);
setCircleProgress(fillWater, 100);
updateVoiceDistance(2);
updateSpeedPercent(66);

if (voiceIconContainer) voiceIconContainer.innerHTML = SVG_MIC_MUTED;
if (popupVoiceIconContainer) popupVoiceIconContainer.innerHTML = SVG_MIC_MUTED;

evaluateHudVisibility();
evaluateHintsVisibility();

// =================================================================
// БАФФЫ И ДЕБАФФЫ
// =================================================================

function renderEffects() {
  effectsList.innerHTML = '';
  if (activeEffects.size === 0) {
    statusHud.style.display = 'none';
    return;
  }
  statusHud.style.display = 'flex';

  activeEffects.forEach(effect => {
    const card = document.createElement('div');
    card.className = 'effect-card';
    card.id = `effect-${effect.id}`;
    card.style.borderLeftColor = effect.color || '#f59e0b';

    card.innerHTML = `
      <div class="effect-icon-box" style="color: ${effect.color || '#f59e0b'}">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="12" y1="8" x2="12" y2="12"></line>
          <line x1="12" y1="16" x2="12.01" y2="16"></line>
        </svg>
      </div>
      <div class="effect-info">
        <span class="effect-label">${effect.label || 'Эффект'}</span>
        ${effect.duration > 0 ? `<span class="effect-timer" id="timer-${effect.id}">--:--</span>` : ''}
      </div>
    `;

    effectsList.appendChild(card);
  });
}

function updateEffectTimers() {
  const now = Date.now();
  activeEffects.forEach((effect, id) => {
    if (effect.duration > 0 && effect.expiresAt > 0) {
      const remainingMs = Math.max(0, effect.expiresAt - now);
      const timerEl = document.getElementById(`timer-${id}`);
      if (timerEl) {
        const totalSec = Math.ceil(remainingMs / 1000);
        const mins = Math.floor(totalSec / 60);
        const secs = totalSec % 60;
        timerEl.innerText = `${mins}:${secs < 10 ? '0' : ''}${secs}`;
      }
      if (remainingMs <= 0) {
        activeEffects.delete(id);
        renderEffects();
      }
    }
  });
}

setInterval(updateEffectTimers, 500);

// =================================================================
// NUI MESSAGE LISTENER
// =================================================================

window.addEventListener('message', function (event) {
  const item = event.data;
  if (!item) return;

  if (item.type === 'UPDATE_STATUS_VALUES' || item.action === 'update_status') {
    updateStatusValues(item.data || item);
  } else if (item.action === 'setWalkSpeed') {
    if (item.percent !== undefined) {
      updateSpeedPercent(item.percent);
    } else if (item.level !== undefined) {
      updateSpeedPercent(item.level === 1 ? 33 : (item.level === 2 ? 66 : (item.level === 3 ? 100 : 100)));
    }
  } else if (item.type === 'SET_HUD_VISIBLE') {
    const wasSystemHudVisible = isSystemHudVisible;
    isSystemHudVisible = (item.visible === true);
    evaluateHudVisibility();
    if (isSystemHudVisible && !wasSystemHudVisible && currentHintsMode === 'dynamic') {
      showHintsTemporarily();
    } else {
      evaluateHintsVisibility();
    }
  } else if (item.type === 'SET_HUD_MODE') {
    if (item.mode) {
      currentHudMode = item.mode;
      evaluateHudVisibility();
    }
  } else if (item.type === 'SET_QUICK_SLOTS_MODE') {
    if (item.mode === 'always_on' || item.mode === 'dynamic' || item.mode === 'always_off') {
      currentQuickSlotsMode = item.mode;
      renderQuickSlots(cachedQuickSlots);
    }
  } else if (item.type === 'SET_QUICK_SLOTS') {
    renderQuickSlots(item.slots);
  } else if (item.type === 'SET_HINTS_MODE') {
    if (item.mode === 'always_on' || item.mode === 'dynamic' || item.mode === 'always_off') {
      currentHintsMode = item.mode;
      if (item.mode === 'dynamic' && isSystemHudVisible) {
        showHintsTemporarily();
      } else {
        dynamicHintsUntil = 0;
        evaluateHintsVisibility();
      }
    }
  } else if (item.type === 'SHOW_HINTS_TEMP') {
    showHintsTemporarily(item.duration);
  } else if (item.type === 'ADD_EFFECT') {
    if (item.effect && item.effect.id) {
      activeEffects.set(item.effect.id, item.effect);
      renderEffects();
    }
  } else if (item.type === 'REMOVE_EFFECT') {
    if (item.effectId) {
      activeEffects.delete(item.effectId);
      renderEffects();
    }
  } else if (item.type === 'CLEAR_ALL_EFFECTS') {
    activeEffects.clear();
    renderEffects();
  } else if (item.type === 'SHOW_TOAST') {
    showToast(item.title || 'Инвентарь', item.message || '', item.notifyType || 'info');
  } else if (item.type === 'SHOW_ADMIN_NOTIFICATION') {
    showAdminNotification(item.message || '', item.duration);
  }
});

const TOAST_ICONS = {
  error: {
    color: '#ef4444',
    svg: `<svg viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`
  },
  warning: {
    color: '#f59e0b',
    svg: `<svg viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`
  },
  success: {
    color: '#22c55e',
    svg: `<svg viewBox="0 0 24 24" fill="none" stroke="#22c55e" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="8 12 11 15 16 9"/></svg>`
  },
  info: {
    color: '#38bdf8',
    svg: `<svg viewBox="0 0 24 24" fill="none" stroke="#38bdf8" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>`
  }
};

function resolveNotifyType(title, message, notifyType) {
  if (notifyType && TOAST_ICONS[notifyType]) return notifyType;
  const str = ((title || '') + ' ' + (message || '')).toLowerCase();
  if (str.includes('ошибк') || str.includes('организ') || str.includes('полн') || str.includes('нет') || str.includes('нельзя') || str.includes('далеко') || str.includes('занят') || str.includes('не найден') || str.includes('закончилось')) {
    return 'error';
  }
  if (str.includes('внимани') || str.includes('предупрежд') || str.includes('откалиброван')) {
    return 'warning';
  }
  if (str.includes('выпили') || str.includes('подобр') || str.includes('успешн') || str.includes('заселил') || str.includes('передач') || str.includes('передан') || str.includes('выдан')) {
    return 'success';
  }
  return 'info';
}

let toastAudioCtx = null;

function getToastAudioContext() {
  if (!toastAudioCtx) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (AudioContext) {
      toastAudioCtx = new AudioContext();
    }
  }
  if (toastAudioCtx && toastAudioCtx.state === 'suspended') {
    toastAudioCtx.resume();
  }
  return toastAudioCtx;
}

function playToastSound(type) {
  try {
    const ctx = getToastAudioContext();
    if (!ctx) return;

    const now = ctx.currentTime;

    if (type === 'error') {
      // Мягкий двухтональный нисходящий звук ошибки (не раздражающий)
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gain = ctx.createGain();

      osc1.type = 'sine';
      osc2.type = 'triangle';
      osc1.frequency.setValueAtTime(320, now);
      osc1.frequency.exponentialRampToValueAtTime(220, now + 0.14);

      osc2.frequency.setValueAtTime(160, now);
      osc2.frequency.exponentialRampToValueAtTime(110, now + 0.14);

      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.16);
      osc2.stop(now + 0.16);
    } else if (type === 'success') {
      // Мягкий восходящий колокольчик успеха
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(520, now);
      osc.frequency.setValueAtTime(780, now + 0.07);

      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.24);
    } else if (type === 'warning') {
      // Мягкий одиночный колокольчик внимания
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(460, now);

      gain.gain.setValueAtTime(0.10, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.18);
    } else {
      // Информационный легкий клик
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(620, now);

      gain.gain.setValueAtTime(0.06, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.10);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.12);
    }
  } catch (e) {
    // Безопасный фолбэк
  }
}

function formatNotificationText(text) {
  if (!text || typeof text !== 'string') return '';
  const trimmed = text.trim();
  const words = trimmed.split(/\s+/);
  if (words.length <= 3) {
    return words.join('\u00A0');
  }
  // Связываем последние 3 слова неразрывными пробелами (\u00A0), чтобы никогда не переносились 1 или 2 висячих слова
  const start = words.slice(0, -3).join(' ');
  const end = words.slice(-3).join('\u00A0');
  return start + ' ' + end;
}

function escapeHtml(text) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return String(text || '').replace(/[&<>"']/g, character => map[character]);
}

function showToast(title, message, notifyType = 'info') {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const resolvedType = resolveNotifyType(title, message, notifyType);
  const iconConfig = TOAST_ICONS[resolvedType] || TOAST_ICONS.info;
  const toast = document.createElement('div');
  toast.className = `toast-item toast-${resolvedType}`;

  const formattedMsg = formatNotificationText(message);

  toast.innerHTML = `
    <div class="toast-icon-box">
      ${iconConfig.svg}
    </div>
    <div class="toast-content">
      <div class="toast-title">${escapeHtml(title)}</div>
      ${formattedMsg ? `<div class="toast-message">${escapeHtml(formattedMsg)}</div>` : ''}
    </div>
  `;

  container.appendChild(toast);
  playToastSound(resolvedType);

  setTimeout(() => {
    toast.classList.add('hide');
    setTimeout(() => {
      toast.remove();
    }, 280);
  }, 3500);
}

function showAdminNotification(message, duration = 15000) {
  const container = document.getElementById('adminNotificationContainer');
  if (!container) return;

  if (activeAdminNotificationHide) {
    activeAdminNotificationHide(true);
  }

  const visibleDuration = Math.max(2500, Number(duration) || 15000);
  const notification = document.createElement('div');
  notification.className = 'admin-notification-item';
  notification.innerHTML = `
    <div class="admin-notification-head">
      <div class="admin-notification-title">Сообщение от администратора</div>
    </div>
    <div class="admin-notification-message">${escapeHtml(message)}</div>
    <div class="admin-notification-progress" aria-hidden="true"><span></span></div>
  `;

  const progress = notification.querySelector('.admin-notification-progress span');
  let removed = false;
  let closeTimer = null;

  const close = (fast = false) => {
    if (removed) return;
    removed = true;
    if (closeTimer) clearTimeout(closeTimer);
    notification.classList.add('hide');
    setTimeout(() => {
      if (notification.parentNode) notification.parentNode.removeChild(notification);
      if (activeAdminNotificationHide === close) activeAdminNotificationHide = null;
    }, fast ? 300 : 420);
  };

  activeAdminNotificationHide = close;
  container.appendChild(notification);

  if (progress) {
    progress.style.width = '100%';
    void progress.offsetWidth;
    progress.style.transition = `width ${visibleDuration}ms linear`;
    requestAnimationFrame(() => {
      progress.style.width = '0%';
    });
  }
  closeTimer = setTimeout(() => close(false), visibleDuration);
}

window.addEventListener('message', (event) => {
  if (event.data.type !== 'THERMAL_UPDATE') return;
  const data = event.data.data;
  const circle = document.getElementById('circleTemperature');
  const valid = data && Number.isFinite(data.air) && Number.isFinite(data.stress);
  circle.style.display = valid ? '' : 'none';
  cachedData.thermalStress = valid ? data.stress : 0;
  evaluateHudVisibility();
  if (!valid) return;
  const degrees = Math.round(data.air);
  document.getElementById('temperatureValue').textContent = `${degrees === 0 ? 0 : degrees}°`;
  const amount = Math.min(1, Math.abs(data.stress));
  const hot = data.stress > 0;
  const canvas = document.getElementById('temperatureRing');
  const ctx = canvas.getContext('2d');
  ctx.setTransform(3, 0, 0, 3, 0, 0);
  ctx.clearRect(0, 0, 44, 44);
  ctx.lineWidth = 3;
  ctx.strokeStyle = 'rgba(255,255,255,0.12)';
  ctx.beginPath(); ctx.arc(22, 22, 18, 0, Math.PI * 2); ctx.stroke();
  if (amount > 0.003) {
    const from = hot ? [191, 111, 105] : [110, 159, 191];
    const to = hot ? [119, 43, 46] : [42,  70, 112];
    ctx.strokeStyle = `rgb(${from.map((v, i) => Math.round(v + (to[i] - v) * amount)).join(',')})`;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.arc(22, 22, 18, -Math.PI / 2, -Math.PI / 2 + (hot ? -1 : 1) * Math.PI * 2 * amount, hot);
    ctx.stroke();
  }
  circle.setAttribute('aria-label', `${degrees}°C · ${amount < 0.05 ? 'Комфортно' : hot ? 'Жарко' : 'Холодно'}`);
});
