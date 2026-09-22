/* =================================================================
   HUNT: Hard RP — The Corruption | Loading Screen Script & Tips
   ================================================================= */

const MOUSE_ICON_SVG = `
  <span class="key-badge key-badge-mouse" title="Колёсико мыши">
    <svg viewBox="0 0 24 24" class="key-icon-mouse">
      <rect x="5" y="2.5" width="14" height="19" rx="7" fill="none" stroke="currentColor" stroke-width="1.8"/>
      <line x1="12" y1="2.5" x2="12" y2="6.2" stroke="currentColor" stroke-width="1.2"/>
      <rect x="10.5" y="6.8" width="3" height="5.4" rx="1.2" fill="#ffffff"/>
      <path d="M12 4.2 L9.8 5.8 L14.2 5.8 Z" fill="#22c55e"/>
      <path d="M12 14.8 L9.8 13.2 L14.2 13.2 Z" fill="#22c55e"/>
    </svg>
  </span>
`;

const SurvivalTips = [
  "Не забывайте следить за показателями жажды и голода — это спасёт вам жизнь.",
  `Техническое меню на <span class="key-badge">Ё</span> или <span class="key-badge">~</span> открывает множество настроек для комфортной игры.`,
  `Используйте <span class="key-badge">ALT</span> + ${MOUSE_ICON_SVG} для изменения скорости персонажа.`,
  `Изменить дальность войс-чата можно с помощью клавиш <span class="key-badge">↑</span> и <span class="key-badge">↓</span>.`,
  `Открыть инвентарь можно с помощью клавиши <span class="key-badge">I</span>.`
];

let lastTipIndex = -1;

function showNextTip() {
  const tipEl = document.getElementById('survivalTip');
  if (!tipEl) return;

  tipEl.classList.remove('fade-in');
  tipEl.classList.add('fade-out');

  setTimeout(() => {
    let newIndex;
    do {
      newIndex = Math.floor(Math.random() * SurvivalTips.length);
    } while (newIndex === lastTipIndex && SurvivalTips.length > 1);

    lastTipIndex = newIndex;
    tipEl.innerHTML = SurvivalTips[newIndex];
    tipEl.classList.remove('fade-out');
    tipEl.classList.add('fade-in');
  }, 350);
}

// Первый показ подсказки сразу
showNextTip();

// Автоматическая смена подсказок каждые 6 секунд
setInterval(showNextTip, 6000);

// Обработка прогресса загрузки от FiveM/RedM
window.addEventListener('message', function (e) {
  if (e.data.eventName === 'loadProgress') {
    const fraction = Math.max(0, Math.min(1, Number(e.data.loadFraction) || 0));
    const percent = Math.floor(fraction * 100);

    const percentEl = document.getElementById('loadPercent');
    const barFillEl = document.querySelector('.bar-fill');

    if (percentEl) percentEl.innerText = percent + "%";
    if (barFillEl) barFillEl.style.width = percent + "%";
  }
});
