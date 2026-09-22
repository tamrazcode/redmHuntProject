/* =================================================================
   HUNT: Hard RP — The Corruption | Dynamic Interaction App
   ================================================================= */

const reticleDot = document.getElementById('reticleDot');
const interactionOverlay = document.getElementById('interactionOverlay');
const radialContainer = document.getElementById('radialContainer');
const radialButtonsWrapper = document.getElementById('radialButtonsWrapper');
const actionTooltip = document.getElementById('actionTooltip');
const tooltipLabel = document.getElementById('tooltipLabel');

const objectInfoModal = document.getElementById('objectInfoModal');
const objectInfoTitle = document.getElementById('objectInfoTitle');
const objectInfoRows = document.getElementById('objectInfoRows');

function closeObjectInfo() {
  if (objectInfoModal) objectInfoModal.style.display = 'none';
  fetch(`https://${GetParentResourceName()}/closeInfoModal`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
}

let currentActions = [];
let currentTargetInfo = null;

// =================================================================
// WEBAUDIO SOUNDS
// =================================================================

let audioCtx = null;
function playUiSound(freq = 600, type = 'sine', duration = 0.06, gainVal = 0.035) {
  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
    const osc = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
    gainNode.gain.setValueAtTime(gainVal, audioCtx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + duration);
    osc.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + duration);
  } catch (e) {}
}

// =================================================================
// BUILT-IN SVG ICONS
// =================================================================

const SVG_ICONS = {
  search: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><line x1="16.5" y1="16.5" x2="21" y2="21"/></svg>`,
  pickup: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 16.5 14.7 H 18.5 V 16.5 H 20.3 V 18.5 H 18.5 V 20.3 H 16.5 V 18.5 H 14.7 V 16.5 H 16.5 Z" fill="#ffffff"/></svg>`,
  pickup_lock: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 14.7 16.05 L 16.05 14.7 L 17.5 16.15 L 18.95 14.7 L 20.3 16.05 L 18.85 17.5 L 20.3 18.95 L 18.95 20.3 L 17.5 18.85 L 16.05 20.3 L 14.7 18.95 L 16.15 17.5 Z" fill="#ffffff"/></svg>`,
  pickup_unlock: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 15.4 15.9 L 14.1 17.2 L 16.9 20.2 L 21.0 14.8 L 19.7 13.5 L 16.9 17.5 Z" fill="#ffffff"/></svg>`,
  open: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 20.0 16.6 H 16.3 L 17.8 15.1 L 16.5 13.8 L 13.1 17.5 L 16.5 21.2 L 17.8 19.9 L 16.3 18.4 H 20.0 Z" fill="#ffffff"/></svg>`,
  workbench: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 20.0 16.6 H 16.3 L 17.8 15.1 L 16.5 13.8 L 13.1 17.5 L 16.5 21.2 L 17.8 19.9 L 16.3 18.4 H 20.0 Z" fill="#ffffff"/></svg>`,
  lock_pickup: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 14.7 16.05 L 16.05 14.7 L 17.5 16.15 L 18.95 14.7 L 20.3 16.05 L 18.85 17.5 L 20.3 18.95 L 18.95 20.3 L 17.5 18.85 L 16.05 20.3 L 14.7 18.95 L 16.15 17.5 Z" fill="#ffffff"/></svg>`,
  unlock_pickup: `<svg viewBox="0 0 24 24" class="solid-icon"><rect x="4" y="4" width="16" height="3.5" rx="0.75" fill="#ffffff"/><path fill-rule="evenodd" d="M 5 9.5 H 19 V 11.9 A 5.8 5.8 0 0 0 12.5 20.5 H 6 A 1 1 0 0 1 5 19.5 V 9.5 Z M 9.5 11.5 H 14.5 V 13 H 9.5 Z" fill="#ffffff"/><path d="M 15.4 15.9 L 14.1 17.2 L 16.9 20.2 L 21.0 14.8 L 19.7 13.5 L 16.9 17.5 Z" fill="#ffffff"/></svg>`,
  ignite: `<svg viewBox="0 0 24 24"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 3z"/></svg>`,
  furnace: `<svg viewBox="0 0 24 24"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 3z"/></svg>`,
  anvil: `<svg viewBox="0 0 24 24"><path d="M4 7h16c.6 0 1 .4 1 1v1c0 .4-.2.7-.6.9L18 11.5V15l2 4v1H4v-1l2-4v-3.5L4.6 9.9C4.2 9.7 4 9.4 4 9V8c0-.6.4-1 1-1zM7 5h9a1 1 0 0 0 0-2H7a3 3 0 0 0-3 3v1h2V5z"/></svg>`,
  extinguish: `<svg viewBox="0 0 24 24"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>`,
  wood: `<svg viewBox="0 0 24 24"><path d="M4 7l12-4 4 2-12 4z"/><path d="M4 7v10l4 2V9z"/><path d="M8 19l12-4V5"/><ellipse cx="6" cy="12" rx="2" ry="4.5"/></svg>`,
  twigs: `<svg viewBox="0 0 24 24"><path d="M4 20l7-7m-3-1l4 1m-1-4l4-1m0 0l5-5m-5 5l2 3"/></svg>`,
  cook: `<svg viewBox="0 0 24 24"><path d="M4 11h16a1 1 0 0 1 1 1v2a6 6 0 0 1-6 6H9a6 6 0 0 1-6-6v-2a1 1 0 0 1 1-1z"/><path d="M2 13h20"/><path d="M8 7c0-1.5.5-2.5 1-3"/><path d="M12 7c0-1.5.5-2.5 1-3"/><path d="M16 7c0-1.5.5-2.5 1-3"/></svg>`,
  charcoal: `<svg viewBox="0 0 24 24"><path d="M6 18l-3-4 2-5 6-3 6 2 4 6-2 5-6 2z"/><path d="M8 11l4-2 4 3-2 4-5 1z"/></svg>`,
  unlock: `<svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></svg>`,
  lock: `<svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`,
  house: `<svg viewBox="0 0 24 24"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`,
  unclaim: `<svg viewBox="0 0 24 24"><path d="M3 10.5L10.5 3.5L18 10.5"/><path d="M5.5 10V20.5H13"/><path d="M15.5 10V13.5"/><path d="M9 17H21"/><path d="M17 13L21 17L17 21"/></svg>`,
  leave_house: `<svg viewBox="0 0 24 24"><path d="M3 10.5L10.5 3.5L18 10.5"/><path d="M5.5 10V20.5H13"/><path d="M15.5 10V13.5"/><path d="M9 17H21"/><path d="M17 13L21 17L17 21"/></svg>`,
  key: `<svg viewBox="0 0 24 24"><circle cx="7.5" cy="15.5" r="4.5"/><path d="m21 3-9.5 9.5"/><path d="m15.5 7.5 3 3"/><path d="m18.5 4.5 2 2"/></svg>`,
  info: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>`,
  knock: `<svg viewBox="0 0 24 24"><path d="M18 11V6a2 2 0 0 0-2-2v0a2 2 0 0 0-2 2v0"/><path d="M14 10V4a2 2 0 0 0-2-2v0a2 2 0 0 0-2 2v6"/><path d="M10 10.5V6a2 2 0 0 0-2-2v0a2 2 0 0 0-2 2v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/></svg>`,
  interact: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>`,
  transfer: `<svg viewBox="0 0 24 24"><path d="M17 1l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="M7 23l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>`,
  medicine: `<svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  seat: `<svg viewBox="0 0 24 24"><path d="M6 3v8"/><path d="M18 3v8"/><path d="M5 11h14v5H5z"/><path d="M7 16v5"/><path d="M17 16v5"/><path d="M5 21h14"/></svg>`,
  rest: `<svg viewBox="0 0 24 24"><path d="M4 15.5c2.3-2.8 5.2-4.2 8-4.2 3.1 0 5.7 1.5 8 4.2"/><path d="M4 19h16"/><path d="M7 11V8.5a2.5 2.5 0 0 1 5 0V11"/><path d="M14 11V9a2 2 0 0 1 4 0v2"/></svg>`,
  activity: `<svg viewBox="0 0 24 24"><path d="M9 18V5l10-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="16" cy="16" r="3"/><path d="M9 9l10-2"/></svg>`,
  read: `<svg viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>`,
  next: `<svg viewBox="0 0 24 24"><path d="M5 12h13"/><path d="m13 6 6 6-6 6"/></svg>`,
  bottle: `<svg viewBox="0 0 24 24"><path d="M10 2h4v3h-4z"/><path d="M9 5h6l1 3v11a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2V8l1-3z"/><line x1="8" y1="13" x2="16" y2="13"/></svg>`,
  flask: `<svg viewBox="0 0 24 24"><path d="M10 2h4v2h-4z"/><rect x="5" y="6" width="14" height="15" rx="5"/><line x1="5" y1="13" x2="19" y2="13"/></svg>`,
  wash: `<svg viewBox="0 0 24 24"><path d="M12 2.5c0 0-6 6.5-6 10.5a6 6 0 0 0 12 0c0-4-6-10.5-6-10.5z"/><circle cx="12" cy="14" r="2"/></svg>`,
  default: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 8v8"/><path d="M8 12h8"/></svg>`
};

// =================================================================
// RADIAL MENU RENDERING
// =================================================================

function renderRadialMenu(rawActions) {
  if (!radialButtonsWrapper) return;
  radialButtonsWrapper.innerHTML = '';
  if (actionTooltip) actionTooltip.style.display = 'none';

  // Cfx may serialize a Lua sequence as either a JS array or a numeric-keyed
  // object. Normalise both forms before rendering the radial menu.
  const actionList = Array.isArray(rawActions)
    ? rawActions
    : (rawActions && typeof rawActions === 'object' ? Object.values(rawActions) : []);
  const actions = actionList.filter((a) => a && typeof a === 'object');
  if (actions.length === 0) return;

  const count = actions.length;
  const radius = 68; // Расстояние от центра (px)

  let pickupAction = null;
  const otherActions = [];

  actions.forEach((act) => {
    if (act.id === 'pickup' || act.isPickup || act.position === 'right') {
      pickupAction = act;
    } else {
      otherActions.push(act);
    }
  });

  actions.forEach((action, idx) => {
    let angleRad = 0;

    if (action === pickupAction) {
      angleRad = 0; // Справа (0 рад)
    } else if (pickupAction) {
      const otherIdx = otherActions.indexOf(action);
      const otherTotal = otherActions.length;
      if (otherTotal === 1) {
        angleRad = Math.PI; // Слева (180 град)
      } else {
        const startAngle = (120 * Math.PI) / 180;
        const endAngle = (240 * Math.PI) / 180;
        const step = (endAngle - startAngle) / (otherTotal - 1);
        angleRad = startAngle + step * otherIdx;
      }
    } else {
      if (count === 1) {
        angleRad = 0; // Справа, если 1 кнопка
      } else if (count === 2) {
        angleRad = idx === 0 ? -Math.PI / 2 : Math.PI / 2; // Сверху и Снизу
      } else {
        const step = (2 * Math.PI) / count;
        angleRad = -Math.PI / 2 + step * idx;
      }
    }

    const posX = Math.round(120 + radius * Math.cos(angleRad));
    const posY = Math.round(120 + radius * Math.sin(angleRad));

    const btn = document.createElement('div');
    btn.className = 'radial-btn';
    btn.style.left = `${posX}px`;
    btn.style.top = `${posY}px`;

    // Подбор иконки
    let iconSvg = SVG_ICONS.default;
    if (action.icon && SVG_ICONS[action.icon]) {
      iconSvg = SVG_ICONS[action.icon];
    } else if (action.id && SVG_ICONS[action.id]) {
      iconSvg = SVG_ICONS[action.id];
    } else if (action.customSvg) {
      iconSvg = action.customSvg;
    }
    btn.innerHTML = iconSvg;

    // Персональная плашка названия кнопки (сверху, снизу, слева или справа)
    let labelPosClass = 'pos-top';
    if (posY < 105) {
      labelPosClass = 'pos-top';
    } else if (posY > 135) {
      labelPosClass = 'pos-bottom';
    } else if (posX < 105) {
      labelPosClass = 'pos-left';
    } else {
      labelPosClass = 'pos-right';
    }

    const labelEl = document.createElement('div');
    labelEl.className = `radial-btn-label ${labelPosClass}`;
    labelEl.innerText = action.label || 'Действие';
    btn.appendChild(labelEl);

    // Звук ховера
    btn.addEventListener('mouseenter', () => {
      playUiSound(750, 'sine', 0.03, 0.02);
      fetch(`https://${GetParentResourceName()}/previewAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          actionId: action.id,
          targetInfo: Object.assign({}, currentTargetInfo || {}, action.targetInfo || {})
        })
      });
    });

    // Клик
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      playUiSound(900, 'triangle', 0.08, 0.04);
      fetch(`https://${GetParentResourceName()}/triggerAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          actionId: action.id,
          event: action.event,
          isServer: action.isServer || false,
          targetInfo: Object.assign({}, currentTargetInfo || {}, action.targetInfo || {}),
          data: action.data || {}
        })
      });
    });

    radialButtonsWrapper.appendChild(btn);

    // Плавный запуск анимации
    setTimeout(() => {
      btn.classList.add('active-bloom');
    }, 15 + idx * 35);
  });
}

// Закрытие при клике в пустое место
if (interactionOverlay) {
  interactionOverlay.addEventListener('click', function (e) {
    if (e.target === interactionOverlay || e.target === radialContainer || e.target === radialButtonsWrapper) {
      fetch(`https://${GetParentResourceName()}/closeInteraction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });
    }
  });
}

// Закрытие на клавиши G / Escape / П
window.addEventListener('keydown', function (e) {
  if (objectInfoModal && objectInfoModal.style.display === 'flex' && (e.key === 'Escape' || e.key === 'g' || e.key === 'G' || e.key === 'п' || e.key === 'П')) {
    closeObjectInfo();
    return;
  }
  if (e.key === 'g' || e.key === 'G' || e.key === 'Escape' || e.key === 'п' || e.key === 'П') {
    fetch(`https://${GetParentResourceName()}/closeInteraction`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
  }
});

window.addEventListener('contextmenu', function (e) {
  if (!interactionOverlay || interactionOverlay.style.display !== 'flex') return;
  e.preventDefault();
  fetch(`https://${GetParentResourceName()}/backInteraction`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });
});

// =================================================================
// NUI MESSAGE LISTENER
// =================================================================

window.addEventListener('message', function (event) {
  const data = event.data;
  if (!data) return;

  if (data.type === 'SHOW_RETICLE' || (data.type === 'SET_RETICLE_VISIBLE' && data.visible)) {
    if (reticleDot) reticleDot.style.display = 'block';
  } else if (data.type === 'HIDE_RETICLE' || (data.type === 'SET_RETICLE_VISIBLE' && !data.visible)) {
    if (reticleDot) reticleDot.style.display = 'none';
  } else if (data.type === 'OPEN_INTERACTION_MENU') {
    if (reticleDot) reticleDot.style.display = 'none';
    currentActions = data.actions || [];
    currentTargetInfo = data.targetInfo || {};
    renderRadialMenu(currentActions);
    if (interactionOverlay) interactionOverlay.style.display = 'flex';
    playUiSound(520, 'sine', 0.06, 0.03);
  } else if (data.type === 'CLOSE_INTERACTION_MENU') {
    if (interactionOverlay) interactionOverlay.style.display = 'none';
    if (radialButtonsWrapper) radialButtonsWrapper.innerHTML = '';
    if (actionTooltip) actionTooltip.style.display = 'none';
    currentActions = [];
    currentTargetInfo = null;
  } else if (data.type === 'SHOW_INFO_MODAL') {
    if (objectInfoTitle) objectInfoTitle.innerText = data.title || 'Информация';
    if (objectInfoRows) {
      objectInfoRows.innerHTML = '';
      (data.rows || []).forEach(row => {
        const rowDiv = document.createElement('div');
        rowDiv.className = 'info-row';
        rowDiv.innerHTML = `
          <span class="info-label">${row.label || ''}</span>
          <span class="info-value ${row.valueClass || ''}">${row.value || ''}</span>
        `;
        objectInfoRows.appendChild(rowDiv);
      });
    }
    if (objectInfoModal) objectInfoModal.style.display = 'flex';
  } else if (data.type === 'CLOSE_INFO_MODAL') {
    if (objectInfoModal) objectInfoModal.style.display = 'none';
  }
});
