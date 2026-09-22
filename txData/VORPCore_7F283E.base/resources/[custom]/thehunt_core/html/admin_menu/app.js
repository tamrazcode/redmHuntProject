// =================================================================
// Панель администратора (thehunt_core) — Obsidian Dark UI
// Полное управление игроками, расширенный арсенал оружия и снаряжения
// =================================================================

const app = document.getElementById('adminApp');
const adminWindow = document.getElementById('adminWindow');
const adminHeader = document.getElementById('adminHeader');
const closeBtn = document.getElementById('closeBtn');
const navTabs = document.querySelectorAll('.nav-tab');
const tabPanes = document.querySelectorAll('.tab-pane');
const toastContainer = document.getElementById('toastContainer');

// Модальные окна
const playersModal = document.getElementById('playersModal');
const playersModalWindow = document.getElementById('playersModalWindow');
const playersModalHeader = document.getElementById('playersModalHeader');
const tpPlayerIdInput = document.getElementById('tpPlayerIdInput');
const modalPlayersList = document.getElementById('modalPlayersList');

const playerLogsModal = document.getElementById('playerLogsModal');
const playerLogsModalWindow = document.getElementById('playerLogsModalWindow');
const playerLogsModalHeader = document.getElementById('playerLogsModalHeader');
const playerLogsSearchInput = document.getElementById('playerLogsSearchInput');
const playerLogsDateFromInput = document.getElementById('playerLogsDateFrom');
const playerLogsDateToInput = document.getElementById('playerLogsDateTo');
const playerLogsList = document.getElementById('playerLogsList');
const playerLogsMeta = document.getElementById('playerLogsMeta');
const playerLogsSummary = document.getElementById('playerLogsSummary');
const playerLogsTargetName = document.getElementById('playerLogsTargetName');

const timeModal = document.getElementById('timeModal');
const timeModalWindow = document.getElementById('timeModalWindow');
const timeModalHeader = document.getElementById('timeModalHeader');
const timeInput = document.getElementById('timeInput');

// Новые модальные окна целевых действий
const giveWeaponModal = document.getElementById('giveWeaponModal');
const giveWeaponModalWindow = document.getElementById('giveWeaponModalWindow');
const giveWeaponModalHeader = document.getElementById('giveWeaponModalHeader');

const giveHorseModal = document.getElementById('giveHorseModal');
const giveHorseModalWindow = document.getElementById('giveHorseModalWindow');
const giveHorseModalHeader = document.getElementById('giveHorseModalHeader');

const playerStatsModal = document.getElementById('playerStatsModal');
const playerStatsModalWindow = document.getElementById('playerStatsModalWindow');
const playerStatsModalHeader = document.getElementById('playerStatsModalHeader');

const giveItemPlayerModal = document.getElementById('giveItemPlayerModal');
const giveItemPlayerModalWindow = document.getElementById('giveItemPlayerModalWindow');
const giveItemPlayerModalHeader = document.getElementById('giveItemPlayerModalHeader');

const kickModal = document.getElementById('kickModal');
const kickModalWindow = document.getElementById('kickModalWindow');
const kickModalHeader = document.getElementById('kickModalHeader');

const messageModal = document.getElementById('messageModal');
const messageModalWindow = document.getElementById('messageModalWindow');
const messageModalHeader = document.getElementById('messageModalHeader');

// Состояние панели
let state = {
  noclip: false,
  godmode: false,
  invis: false,
  adminBlips: false,
  emptyWorld: true,
  playerIDs: false,
  superJump: false,
  coordLaser: false,
  freezeHunger: false,
  freezeThirst: false,
  freezeStamina: false
};

let cachedPlayers = [];
let expandedPlayerIds = new Set();
let playerSearchQuery = '';
let savedPosition = null;

let modalTargetPlayerId = 0;
let modalTargetPlayerName = '';
let selectedModalWeapon = '';
let selectedModalItem = '';
let selectedModalHorse = '';
let playerLogsTargetId = 0;
let playerLogsSearchTimer = null;
let playerLogsRequestTimer = null;
let playerLogsQuery = '';
let playerLogsDateFrom = '';
let playerLogsDateTo = '';
let playerLogsNextOffset = 0;
let playerLogsHasMore = true;
let playerLogsLoading = false;
let playerLogsRequestSequence = 0;
let playerLogsActiveRequestId = 0;
let playerLogsFetchedCount = 0;
let playerLogsRenderedCount = 0;
let playerLogsTotal = 0;
let playerLogsSnapshotId = 0;

// Координаты лазера и игрока
let currentCoordsData = {
  pedX: 0, pedY: 0, pedZ: 0, pedH: 0,
  hitX: 0, hitY: 0, hitZ: 0, hitDist: 0,
  hitEntity: null, hitModel: 0
};

// =================================================================
// КАТАЛОГ ОРУЖИЯ, МЕТАТЕЛЬНОГО И НОСИМОГО СНАРЯЖЕНИЯ (femga/rdr3_discoveries)
// =================================================================
const WEAPONS_CATALOG = [
  // 1. Револьверы
  { id: 'WEAPON_REVOLVER_CATTLEMAN', name: 'Cattleman', desc: 'Армейский револьвер 1873 года', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_CATTLEMAN_JOHN', name: "John's Cattleman", desc: 'Именной револьвер Джона Марстона', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_CATTLEMAN_MEXICAN', name: "Granger's Cattleman", desc: 'Гравированный револьвер Эммета Грейнджера', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_CATTLEMAN_PIG', name: "Flaco's Cattleman", desc: 'Револьвер с костяной рукоятью Флако Эрнандеса', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_DOUBLEACTION', name: 'Double Action', desc: 'Скорострельный револьвер двойного действия', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_DOUBLEACTION_EXOTIC', name: "Algernon's Revolver", desc: 'Изукрашенный револьвер Элджернона', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_DOUBLEACTION_GAMBLER', name: 'High Roller', desc: 'Револьвер шулера с игральными костями', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_DOUBLEACTION_MICAH', name: "Micah's Revolver", desc: 'Черненый револьвер Мики Белла', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_SCHOFIELD', name: 'Schofield', desc: 'Мощный тяжелый револьвер Смит-Вессон', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_SCHOFIELD_CALLOWAY', name: "Calloway's Schofield", desc: 'Посеребренный револьвер Боя Каллоуэя', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_SCHOFIELD_GOLDEN', name: "Otis Miller's Schofield", desc: 'Золотой револьвер Отиса Миллера', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_LEMAT', name: 'LeMat', desc: '9-зарядный револьвер со встроенным стволом дробовика', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_NAVY', name: 'Navy Revolver', desc: 'Тяжелый морской капсюльный револьвер Кольта', cat: 'revolvers' },
  { id: 'WEAPON_REVOLVER_NAVY_CROSSOVER', name: "Lowry's Revolver", desc: 'Кровавый револьвер серийного убийцы Лаури', cat: 'revolvers' },

  // 2. Пистолеты
  { id: 'WEAPON_PISTOL_VOLCANIC', name: 'Volcanic', desc: 'Мощный рычажный пистолет 1855 года', cat: 'pistols' },
  { id: 'WEAPON_PISTOL_SEMIAUTO', name: 'Semi-Auto Pistol', desc: 'Скорострельный пистолет Борхардта', cat: 'pistols' },
  { id: 'WEAPON_PISTOL_MAUSER', name: 'Mauser C96', desc: 'Немецкий автоматический пистолет с обоймой', cat: 'pistols' },
  { id: 'WEAPON_PISTOL_M1899', name: 'M1899 Pistol', desc: 'Современный полуавтоматический пистолет Браунинга', cat: 'pistols' },

  // 3. Винтовки и карабины
  { id: 'WEAPON_REPEATER_CARBINE', name: 'Carbine Repeater', desc: 'Лёгкий кавалерийский карабин Спенсера', cat: 'repeaters' },
  { id: 'WEAPON_REPEATER_WINCHESTER', name: 'Lancaster Repeater', desc: 'Надежная рычажная винтовка Винчестер', cat: 'repeaters' },
  { id: 'WEAPON_REPEATER_HENRY', name: 'Litchfield Repeater', desc: 'Классическая винтовка системы Генри', cat: 'repeaters' },
  { id: 'WEAPON_REPEATER_EVANS', name: 'Evans Repeater', desc: '26-зарядная магазинная винтовка Эванса', cat: 'repeaters' },
  { id: 'WEAPON_RIFLE_SPRINGFIELD', name: 'Springfield', desc: 'Однозарядная армейская дальнобойная винтовка', cat: 'rifles' },
  { id: 'WEAPON_RIFLE_BOLTACTION', name: 'Bolt Action', desc: 'Высокоточная затворная винтовка Краг-Йоргенсен', cat: 'rifles' },
  { id: 'WEAPON_RIFLE_VARMINT', name: 'Varmint Rifle', desc: 'Малокалиберная винтовка для охоты на мелкую дичь', cat: 'rifles' },
  { id: 'WEAPON_RIFLE_ELEPHANT', name: 'Elephant Rifle', desc: 'Тяжелый двуствольный штуцер для охоты на слонов', cat: 'rifles' },

  // 4. Снайперские винтовки
  { id: 'WEAPON_SNIPERRIFLE_CARCANO', name: 'Carcano Rifle', desc: 'Итальянская магазинная снайперская винтовка', cat: 'snipers' },
  { id: 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', name: 'Rolling Block', desc: 'Тяжелая снайперская винтовка Ремингтон', cat: 'snipers' },
  { id: 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC', name: 'Rare Rolling Block', desc: 'Редкая снайперская винтовка с гравировкой', cat: 'snipers' },

  // 5. Дробовики
  { id: 'WEAPON_SHOTGUN_DOUBLEBARREL', name: 'Double-Barrel Shotgun', desc: 'Классический охотничий двуствольный дробовик', cat: 'shotguns' },
  { id: 'WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC', name: 'Rare Double-Barrel', desc: 'Редкий двуствольный дробовик отшельника', cat: 'shotguns' },
  { id: 'WEAPON_SHOTGUN_SAWEDOFF', name: 'Sawed-Off Shotgun', desc: 'Компактный мощный обрез двустволки', cat: 'shotguns' },
  { id: 'WEAPON_SHOTGUN_PUMP', name: 'Pump-Action Shotgun', desc: 'Помповый боевой дробовик Винчестер 1897', cat: 'shotguns' },
  { id: 'WEAPON_SHOTGUN_SEMIAUTO', name: 'Semi-Auto Shotgun', desc: 'Полуавтоматический дробовик Браунинг Авто-5', cat: 'shotguns' },
  { id: 'WEAPON_SHOTGUN_REPEATING', name: 'Repeating Shotgun', desc: 'Рычажный многозарядный дробовик', cat: 'shotguns' },

  // 6. Луки и метательное
  { id: 'WEAPON_BOW', name: 'Bow', desc: 'Бесшумный охотничий лук коренных народов', cat: 'bows' },
  { id: 'WEAPON_BOW_IMPROVED', name: 'Improved Bow', desc: 'Улучшенный составной лук с повышенной силой', cat: 'bows' },
  { id: 'WEAPON_LASSO', name: 'Lasso', desc: 'Плетеная веревка для связывания людей и животных', cat: 'bows' },
  { id: 'WEAPON_LASSO_REINFORCED', name: 'Reinforced Lasso', desc: 'Усиленное неразрываемое лассо охотника за головами', cat: 'bows' },
  { id: 'WEAPON_THROWN_DYNAMITE', name: 'Dynamite', desc: 'Шашка взрывчатки с огнепроводным запалом', cat: 'throwable' },
  { id: 'WEAPON_THROWN_MOLOTOV', name: 'Fire Bottle', desc: 'Бутылка с зажигательной смесью', cat: 'throwable' },
  { id: 'WEAPON_THROWN_MOLOTOV_VOLATILE', name: 'Volatile Fire Bottle', desc: 'Улучшенная зажигательная смесь мгновенного взрыва', cat: 'throwable' },
  { id: 'WEAPON_THROWN_TOMAHAWK', name: 'Tomahawk', desc: 'Метательный индейский топор', cat: 'throwable' },
  { id: 'WEAPON_THROWN_TOMAHAWK_ANCIENT', name: 'Ancient Tomahawk', desc: 'Древний каменный томагавк', cat: 'throwable' },
  { id: 'WEAPON_THROWN_TOMAHAWK_HOMING', name: 'Homing Tomahawk', desc: 'Сбалансированный томагавк высокой точности', cat: 'throwable' },
  { id: 'WEAPON_THROWN_THROWING_KNIVES', name: 'Throwing Knives', desc: 'Метательные балансирные ножи', cat: 'throwable' },
  { id: 'WEAPON_THROWN_BOLAS', name: 'Bolas', desc: 'Утяжеленные шары на веревке для спутывания ног', cat: 'throwable' },
  { id: 'WEAPON_THROWN_BOLAS_HAWKMOTH', name: 'Hawkmoth Bolas', desc: 'Коллекционный болас «Бражник»', cat: 'throwable' },
  { id: 'WEAPON_THROWN_BOLAS_IRONSPIKED', name: 'Iron Spiked Bolas', desc: 'Болас с шипованными железными грузилами', cat: 'throwable' },
  { id: 'WEAPON_THROWN_BOLAS_INTERTWINED', name: 'Intertwined Bolas', desc: 'Плетеный болас тройного охвата', cat: 'throwable' },

  // 7. Холодное оружие
  { id: 'WEAPON_MELEE_KNIFE', name: 'Hunting Knife', desc: 'Охотничий клинок с кожаной рукоятью', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_JAWBONE', name: 'Jawbone Knife', desc: 'Нож с рукоятью из челюсти койота', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_MINER', name: 'Miner Knife', desc: 'Широкий разделочный нож шахтёра', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_VAMPIRE', name: 'Ornate Dagger', desc: 'Изукрашенный кинжал вампира Сен-Дени', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_CIVIL_WAR', name: 'Civil War Knife', desc: 'Боевой нож Боуи времен Гражданской войны', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_BEAR', name: 'Antler Knife', desc: 'Охотничий нож с рукоятью из оленьего рога', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_RUSTIC', name: 'Rustic Knife', desc: 'Деревенский кованый нож', cat: 'melee' },
  { id: 'WEAPON_MELEE_KNIFE_TRADER', name: 'Trader Knife', desc: 'Профессиональный нож торговца шкурами', cat: 'melee' },
  { id: 'WEAPON_MELEE_MACHETE', name: 'Machete', desc: 'Длинный рубящий тростниковый тесак', cat: 'melee' },
  { id: 'WEAPON_MELEE_MACHETE_COLLECTOR', name: 'Aguila Machete', desc: 'Золоченое мачете коллекционера «Агила»', cat: 'melee' },
  { id: 'WEAPON_MELEE_MACHETE_HORROR', name: 'Zavala Machete', desc: 'Зубчатое мачете Савала', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET', name: 'Hatchet', desc: 'Универсальный походный топорик', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_CLEAVER', name: 'Cleaver Hatchet', desc: 'Топор-секач мясника', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_HEWING', name: 'Hewing Hatchet', desc: 'Плотницкий тёсочный топор с широким лезвием', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_VIKING', name: 'Viking Hatchet', desc: 'Древний скандинавский боевой топор викингов', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_HUNTER', name: 'Hunter Hatchet', desc: 'Охотничий топор с длинным топорищем', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_RUSTED_HUNTER', name: 'Rusted Hunter Hatchet', desc: 'Ржавый охотничий топор', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_DOUBLE_BIT', name: 'Double Bit Hatchet', desc: 'Двусторонний топор лесоруба', cat: 'melee' },
  { id: 'WEAPON_MELEE_HATCHET_RUSTED_DOUBLE_BIT', name: 'Rusted Double Bit', desc: 'Старый ржавый двусторонний топор', cat: 'melee' },
  { id: 'WEAPON_MELEE_HAMMER', name: 'Hammer', desc: 'Тяжелый кузнечный молот', cat: 'melee' },
  { id: 'WEAPON_MELEE_BROKEN_SWORD', name: 'Broken Pirate Sword', desc: 'Сломанный клинок пиратской абордажной сабли', cat: 'melee' },
  { id: 'WEAPON_MELEE_CLEAVER', name: 'Meat Cleaver', desc: 'Разделочный мясницкий тесак', cat: 'melee' },

  // 8. Носимое снаряжение, приборы и инструменты (Kit & Equipment)
  { id: 'WEAPON_KIT_BINOCULARS', name: 'Binoculars', desc: 'Оптический полевой бинокль с регулировкой зума', cat: 'equipment' },
  { id: 'WEAPON_KIT_BINOCULARS_IMPROVED', name: 'Improved Binoculars', desc: 'Улучшенный бинокль коллекционера с подсветкой', cat: 'equipment' },
  { id: 'WEAPON_KIT_CAMERA', name: 'Camera', desc: 'Стандартный фотоаппарат на треноге/ручной для снимков', cat: 'equipment' },
  { id: 'WEAPON_KIT_CAMERA_ADVANCED', name: 'Advanced Camera', desc: 'Улучшенная карманная фотокамера со светофильтрами', cat: 'equipment' },
  { id: 'WEAPON_KIT_METAL_DETECTOR', name: 'Metal Detector', desc: 'Электронный металлоискатель для поиска сокровищ', cat: 'equipment' },
  { id: 'WEAPON_FISHINGROD', name: 'Fishing Rod', desc: 'Телескопическая удочка с катушкой для ловли рыбы', cat: 'equipment' },
  { id: 'WEAPON_MELEE_LANTERN', name: 'Lantern', desc: 'Керосиновый переносной фонарь кругового освещения', cat: 'equipment' },
  { id: 'WEAPON_MELEE_LANTERN_ELECTRIC', name: 'Electric Lantern', desc: 'Электрический фонарь Марко Драгича', cat: 'equipment' },
  { id: 'WEAPON_MELEE_LANTERN_HALLOWEEN', name: 'Halloween Lantern', desc: 'Праздничный тыквенный фонарь со свечением', cat: 'equipment' },
  { id: 'WEAPON_MELEE_TORCH', name: 'Torch', desc: 'Деревянный смоляной факел с открытым пламенем', cat: 'equipment' },
  { id: 'WEAPON_MOONSHINEJUG_MP', name: 'Moonshine Jug', desc: 'Керамический кувшин самогона для розлива и поджога', cat: 'equipment' }
];

const HORSES_CATALOG = [
  { id: 'A_C_Horse_Turkoman_Gold', name: 'Туркоман', desc: 'Боевая верховая лошадь' },
  { id: 'A_C_Horse_Arabian_White', name: 'Арабская', desc: 'Белая элитная лошадь' },
  { id: 'A_C_Horse_Mustang_Grullodun', name: 'Мустанг', desc: 'Дикая выносливая лошадь' },
  { id: 'A_C_Horse_MissouriFoxTrotter_DappleGrey', name: 'Миссурийский фокстроттер', desc: 'Универсальная скаковая лошадь' },
  { id: 'A_C_Horse_Andalusian_DarkBay', name: 'Андалузская', desc: 'Тяжёлая боевая лошадь' },
  { id: 'A_C_Horse_Shire_DarkBay', name: 'Шайр', desc: 'Крупная тяжеловозная лошадь' },
  { id: 'A_C_Horse_Nokota_Reversedappleroan', name: 'Нокота', desc: 'Быстрая скаковая лошадь' },
  { id: 'A_C_Horse_Appaloosa_Blanket', name: 'Аппалуза', desc: 'Пятнистая рабочая лошадь' },
  { id: 'A_C_Horse_KentuckySaddle_Grey', name: 'Кентукки', desc: 'Верховая прогулочная лошадь' },
  { id: 'A_C_Horse_Thoroughbred_Brindle', name: 'Чистокровная', desc: 'Скоростная гоночная лошадь' }
];

let activeArsenalCategory = 'all';
let arsenalSearchQuery = '';

// =================================================================
// ЗВУКОВОЙ СИНТЕЗАТОР УВЕДОМЛЕНИЙ
// =================================================================
function playNotificationSound(type = 'success') {
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.connect(gain);
    gain.connect(ctx.destination);

    if (type === 'success') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880.00, ctx.currentTime + 0.10);
      gain.gain.setValueAtTime(0.04, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.20);
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 0.20);
    } else if (type === 'warn' || type === 'info') {
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(523.25, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(659.25, ctx.currentTime + 0.10);
      gain.gain.setValueAtTime(0.035, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.18);
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 0.18);
    } else {
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(300, ctx.currentTime);
      gain.gain.setValueAtTime(0.03, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
      osc.start(ctx.currentTime);
      osc.stop(ctx.currentTime + 0.15);
    }
  } catch (e) {}
}

function showToast(title, message, type = 'success') {
  if (!toastContainer) return;
  playNotificationSound(type);

  const toast = document.createElement('div');
  toast.className = `toast-item ${type}`;

  const iconSvg = type === 'success'
    ? `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>`
    : `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`;

  toast.innerHTML = `
    <div class="toast-icon-box">${iconSvg}</div>
    <div class="toast-content">
      <div class="toast-title">${escapeHtml(title)}</div>
      <div class="toast-msg">${escapeHtml(message)}</div>
    </div>
  `;

  toastContainer.appendChild(toast);

  setTimeout(() => {
    toast.classList.add('hide');
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 260);
  }, 2800);
}

// =================================================================
// КАМЕРА НА СКМ (СРЕДНЯЯ КНОПКА МЫШИ)
// =================================================================
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
// DRAG & DROP
// =================================================================
function makeDraggable(headerEl, windowEl) {
  if (!headerEl || !windowEl) return;
  let isDragging = false;
  let dragStartX = 0, dragStartY = 0;
  let windowStartX = 0, windowStartY = 0;

  headerEl.addEventListener('mousedown', (e) => {
    if (e.target.tagName === 'BUTTON' || e.target.classList.contains('close-btn')) return;
    isDragging = true;
    dragStartX = e.clientX;
    dragStartY = e.clientY;

    const rect = windowEl.getBoundingClientRect();
    windowStartX = rect.left;
    windowStartY = rect.top;

    document.body.style.userSelect = 'none';
  });

  window.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    const deltaX = e.clientX - dragStartX;
    const deltaY = e.clientY - dragStartY;

    let newX = windowStartX + deltaX;
    let newY = windowStartY + deltaY;

    const maxW = window.innerWidth - windowEl.offsetWidth;
    const maxH = window.innerHeight - windowEl.offsetHeight;

    newX = Math.max(10, Math.min(maxW - 10, newX));
    newY = Math.max(10, Math.min(maxH - 10, newY));

    windowEl.style.left = `${newX}px`;
    windowEl.style.top = `${newY}px`;
    windowEl.style.transform = 'none';

    if (windowEl === adminWindow) {
      savedPosition = { x: newX, y: newY };
    }
  });

  window.addEventListener('mouseup', () => {
    if (isDragging) {
      isDragging = false;
      document.body.style.userSelect = '';
    }
  });
}

makeDraggable(adminHeader, adminWindow);
makeDraggable(playersModalHeader, playersModalWindow);
makeDraggable(playerLogsModalHeader, playerLogsModalWindow);
makeDraggable(timeModalHeader, timeModalWindow);
makeDraggable(giveWeaponModalHeader, giveWeaponModalWindow);
makeDraggable(giveHorseModalHeader, giveHorseModalWindow);
makeDraggable(playerStatsModalHeader, playerStatsModalWindow);
makeDraggable(giveItemPlayerModalHeader, giveItemPlayerModalWindow);
makeDraggable(kickModalHeader, kickModalWindow);
makeDraggable(messageModalHeader, messageModalWindow);

// =================================================================
// NUI CALLBACK
// =================================================================
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
    tabPanes.forEach(p => p.classList.remove('active'));

    tab.classList.add('active');
    const pane = document.getElementById(`tab-${targetTab}`);
    if (pane) pane.classList.add('active');

    if (targetTab === 'arsenal') {
      renderArsenal();
    }

    if (targetTab === 'players') {
      sendNui('requestPlayersList');
    }

    if (targetTab === 'items') {
      sendNui('getAdminItemsList');
      sendNui('getNearbyPlayersList');
      sendNui('toggleAdminItemsNearbyIDs', { active: true });
    } else {
      sendNui('toggleAdminItemsNearbyIDs', { active: false });
    }
  });
});

// Закрытие меню
function closeMenu() {
  if (document.activeElement && typeof document.activeElement.blur === 'function') {
    document.activeElement.blur();
  }
  window.blur();
  closeAllModals();
  sendNui('toggleAdminItemsNearbyIDs', { active: false });
  app.style.display = 'none';
  sendNui('closeAdminMenu');
}

closeBtn.addEventListener('click', closeMenu);

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' || e.key === 'F4') {
    if (isAnyModalOpen()) {
      closeAllModals();
      return;
    }
    closeMenu();
  }
});

function isAnyModalOpen() {
  return (
    (playersModal && playersModal.style.display !== 'none') ||
    (playerLogsModal && playerLogsModal.style.display !== 'none') ||
    (timeModal && timeModal.style.display !== 'none') ||
    (giveWeaponModal && giveWeaponModal.style.display !== 'none') ||
    (giveHorseModal && giveHorseModal.style.display !== 'none') ||
    (playerStatsModal && playerStatsModal.style.display !== 'none') ||
    (giveItemPlayerModal && giveItemPlayerModal.style.display !== 'none') ||
    (kickModal && kickModal.style.display !== 'none') ||
    (messageModal && messageModal.style.display !== 'none')
  );
}

function closeAllModals() {
  closePlayersModal();
  closePlayerLogsModal();
  closeTimeModal();
  closeGiveWeaponModal();
  closeGiveHorseModal();
  closePlayerStatsModal();
  closeGiveItemPlayerModal();
  closeKickModal();
  closeMessageModal();
}

// =================================================================
// ДЕЙСТВИЯ АДМИНИСТРАТОРА НАД СОБОЙ
// =================================================================
const ACTION_DESCRIPTIONS = {
  heal: { title: "Успешно", msg: "Здоровье и выносливость восполнены на 100%" },
  metabolism: { title: "Успешно", msg: "Голод и жажда полностью насыщены" },
  refillStamina: { title: "Успешно", msg: "Выносливость и ядра энергии восстановлены на 100%" },
  deleteCurrentVehicle: { title: "Успешно", msg: "Текущий транспорт / лошадь удалены" },
  toggleNoclip: { title: "No-clip", getMsg: () => state.noclip ? "Режим свободного полёта выключен" : "Режим свободного полёта включен" },
  toggleGodmode: { title: "Бессмертие", getMsg: () => state.godmode ? "Неуязвимость выключена" : "Неуязвимость включена" },
  toggleInvis: { title: "Невидимость", getMsg: () => state.invis ? "Персонаж снова видим" : "Персонаж скрыт (невидим)" },
  toggleSuperJump: { title: "Суперпрыжок", getMsg: () => state.superJump ? "Суперпрыжок выключен" : "Суперпрыжок активирован" },
  toggleFreezeHunger: { title: "Сытость", getMsg: () => state.freezeHunger ? "Заморозка еды выключена" : "Заморозка еды активирована (100%)" },
  toggleFreezeThirst: { title: "Жажда", getMsg: () => state.freezeThirst ? "Заморозка жажды выключена" : "Заморозка жажды активирована (100%)" },
  toggleFreezeStamina: { title: "Выносливость", getMsg: () => state.freezeStamina ? "Бесконечная выносливость выключена" : "Бесконечная выносливость активирована (100%)" },
  reviveSelf: { title: "Реанимация", msg: "Персонаж воскрешен" },
  cleanArea: { title: "Очистка мира", msg: "Зона в радиусе 50м полностью очищена" },

  // Лошади
  spawnHorseTurkoman: { title: "Успешно", msg: "Спавн лошади «Туркоман»" },
  spawnHorseArabian: { title: "Успешно", msg: "Спавн лошади «Арабская»" },
  spawnHorseMustang: { title: "Успешно", msg: "Спавн лошади «Мустанг»" },
  spawnHorseMissouri: { title: "Успешно", msg: "Спавн лошади «Фокстроттер»" },
  spawnHorseAndalusian: { title: "Успешно", msg: "Спавн лошади «Андалузская»" },
  spawnHorseShire: { title: "Успешно", msg: "Спавн лошади «Шайр»" },
  spawnHorseNokota: { title: "Успешно", msg: "Спавн лошади «Нокота»" },
  spawnHorseAppaloosa: { title: "Успешно", msg: "Спавн лошади «Аппалуза»" },
  spawnHorseKentucky: { title: "Успешно", msg: "Спавн лошади «Кентукки»" },
  spawnHorseThoroughbred: { title: "Успешно", msg: "Спавн лошади «Чистокровная»" },

  // Транспорт
  spawnWagonHunting: { title: "Успешно", msg: "Спавн «Охотничья повозка»" },
  spawnWagonCoach: { title: "Успешно", msg: "Спавн «Карета дилижанс»" },
  spawnWagonOpen: { title: "Успешно", msg: "Спавн «Открытая телега»" },
  spawnWagonSupply: { title: "Успешно", msg: "Спавн «Повозка снабжения»" },
  spawnBoatRowboat: { title: "Успешно", msg: "Спавн «Весельная лодка»" },
  spawnBoatCanoe: { title: "Успешно", msg: "Спавн «Каноэ»" },

  healMount: { title: "Успешно", msg: "Лошадь / транспорт полностью вылечены" },
  giveAmmo: { title: "Успешно", msg: "Боезапас оружия пополнен на максимум" },
  fireball: { title: "Магия", msg: "Огненный шар запущен!" },

  toggleEmptyWorld: { title: "Блокировка NPC", getMsg: () => state.emptyWorld ? "Блокировка NPC и повозок отключена (NPC включены)" : "Блокировка NPC и повозок включена (мир пуст)" },
  togglePlayerIDs: { title: "ID игроков", getMsg: () => state.playerIDs ? "Отображение ID выключено" : "Отображение ID над головами включено" },
  toggleAdminBlips: { title: "Метки на карте", getMsg: () => state.adminBlips ? "Метки игроков скрыты" : "Метки игроков отображаются" },
  toggleCoordLaser: { title: "3D-Лазер и координаты", getMsg: () => state.coordLaser ? "Режим координат и 3D-лазера выключен" : "Режим координат и 3D-лазера активирован" },
  tpToWaypoint: { title: "Телепортация", msg: "Телепортирован к метке на карте" },
};

function triggerAction(actionName) {
  sendNui('adminAction', { action: actionName });

  const desc = ACTION_DESCRIPTIONS[actionName];
  if (desc) {
    const msg = desc.getMsg ? desc.getMsg() : desc.msg;
    showToast(desc.title, msg, 'success');
  }
}

function triggerWeapon(weaponHash) {
  sendNui('giveWeapon', { weapon: weaponHash });
  showToast("Оружие", `Выдано оружие: ${weaponHash.replace('WEAPON_', '')}`, 'success');
}

function triggerTpLocation(x, y, z, locName = "Локация") {
  sendNui('tpLocation', { x: x, y: y, z: z });
  showToast("Телепортация", `Телепортирован: ${locName}`, 'success');
}

function updateBadges() {
  const badgeNoclip = document.getElementById('badgeNoclip');
  if (badgeNoclip) {
    badgeNoclip.textContent = state.noclip ? 'ВКЛ' : 'ВЫКЛ';
    badgeNoclip.className = state.noclip ? 'badge on' : 'badge';
  }

  const badgeGod = document.getElementById('badgeGod');
  if (badgeGod) {
    badgeGod.textContent = state.godmode ? 'ВКЛ' : 'ВЫКЛ';
    badgeGod.className = state.godmode ? 'badge on' : 'badge';
  }

  const badgeInvis = document.getElementById('badgeInvis');
  if (badgeInvis) {
    badgeInvis.textContent = state.invis ? 'ВКЛ' : 'ВЫКЛ';
    badgeInvis.className = state.invis ? 'badge on' : 'badge';
  }

  const badgeSuperJump = document.getElementById('badgeSuperJump');
  if (badgeSuperJump) {
    badgeSuperJump.textContent = state.superJump ? 'ВКЛ' : 'ВЫКЛ';
    badgeSuperJump.className = state.superJump ? 'badge on' : 'badge';
  }

  const badgeBlips = document.getElementById('badgeBlips');
  if (badgeBlips) {
    badgeBlips.textContent = state.adminBlips ? 'ВКЛ' : 'ВЫКЛ';
    badgeBlips.className = state.adminBlips ? 'badge on' : 'badge';
  }

  const badgeEmptyWorld = document.getElementById('badgeEmptyWorld');
  if (badgeEmptyWorld) {
    badgeEmptyWorld.textContent = state.emptyWorld ? 'ВКЛ' : 'ВЫКЛ';
    badgeEmptyWorld.className = state.emptyWorld ? 'badge on' : 'badge';
  }

  for (const [key, id] of [['zombieInfo', 'badgeZombieInfo'], ['zombieImmune', 'badgeZombieImmune']]) {
    const badge = document.getElementById(id);
    if (badge) { badge.textContent = state[key] ? 'ВКЛ' : 'ВЫКЛ'; badge.className = state[key] ? 'badge on' : 'badge'; }
  }

  const badgePlayerIDs = document.getElementById('badgePlayerIDs');
  if (badgePlayerIDs) {
    badgePlayerIDs.textContent = state.playerIDs ? 'ВКЛ' : 'ВЫКЛ';
    badgePlayerIDs.className = state.playerIDs ? 'badge on' : 'badge';
  }

  const badgeCoordLaser = document.getElementById('badgeCoordLaser');
  if (badgeCoordLaser) {
    badgeCoordLaser.textContent = state.coordLaser ? 'ВКЛ' : 'ВЫКЛ';
    badgeCoordLaser.className = state.coordLaser ? 'badge on' : 'badge';
  }

  const badgeFreezeHunger = document.getElementById('badgeFreezeHunger');
  if (badgeFreezeHunger) {
    badgeFreezeHunger.textContent = state.freezeHunger ? 'ВКЛ' : 'ВЫКЛ';
    badgeFreezeHunger.className = state.freezeHunger ? 'badge on' : 'badge';
  }

  const badgeFreezeThirst = document.getElementById('badgeFreezeThirst');
  if (badgeFreezeThirst) {
    badgeFreezeThirst.textContent = state.freezeThirst ? 'ВКЛ' : 'ВЫКЛ';
    badgeFreezeThirst.className = state.freezeThirst ? 'badge on' : 'badge';
  }

  const badgeFreezeStamina = document.getElementById('badgeFreezeStamina');
  if (badgeFreezeStamina) {
    badgeFreezeStamina.textContent = state.freezeStamina ? 'ВКЛ' : 'ВЫКЛ';
    badgeFreezeStamina.className = state.freezeStamina ? 'badge on' : 'badge';
  }
}

// =================================================================
// ВКЛАДКА "ОРУЖИЕ И СНАРЯЖЕНИЕ" (АРСЕНАЛ)
// =================================================================
function setArsenalCategory(cat) {
  activeArsenalCategory = cat;
  document.querySelectorAll('#arsenalCategoryPills .cat-pill').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-cat') === cat);
  });
  renderArsenal();
}

function filterArsenal() {
  const input = document.getElementById('arsenalSearchInput');
  arsenalSearchQuery = input ? input.value.trim().toLowerCase() : '';
  renderArsenal();
}

function renderArsenal() {
  const container = document.getElementById('arsenalGridContainer');
  if (!container) return;

  if (activeArsenalCategory === 'magic') {
    container.innerHTML = `
      <div class="action-card highlight-orange" onclick="triggerAction('fireball')">
        <div class="card-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14 0-5.5 3-5.5 1.5 0 3 1.5 3 3 0 2.14-1 3-1 3 .5 1 .5 2 .5 3a2.5 2.5 0 0 1-2.5 2.5"/><path d="M12 14v8"/></svg></div>
        <div class="card-info"><h3>Огненный шар</h3><p>Летящий шар с огнем и взрывом</p></div>
      </div>
    `;
    return;
  }

  const filtered = WEAPONS_CATALOG.filter(w => {
    const catMatch = (activeArsenalCategory === 'all') || (w.cat === activeArsenalCategory);
    const searchMatch = w.name.toLowerCase().includes(arsenalSearchQuery) || 
                        w.desc.toLowerCase().includes(arsenalSearchQuery) ||
                        w.id.toLowerCase().includes(arsenalSearchQuery);
    return catMatch && searchMatch;
  });

  if (filtered.length === 0) {
    container.innerHTML = '<div class="empty-msg">Оружие не найдено</div>';
    return;
  }

  container.innerHTML = '';
  filtered.forEach(w => {
    const card = document.createElement('div');
    card.className = 'action-card';
    card.onclick = () => triggerWeapon(w.id);
    card.innerHTML = `
      <div class="card-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 16l6-6 4 4 8-8"/><polyline points="15 4 20 4 20 9"/></svg>
      </div>
      <div class="card-info">
        <h3>${escapeHtml(w.name)}</h3>
        <p>${escapeHtml(w.desc)}</p>
      </div>
    `;
    container.appendChild(card);
  });
}

// =================================================================
// ВКЛАДКА "ИГРОКИ ОНЛАЙН" (ПОЛНЫЙ ACCORDION И ДЕТАЛИ)
// =================================================================
function filterPlayers() {
  const input = document.getElementById('playersSearchInput');
  playerSearchQuery = input ? input.value.trim().toLowerCase() : '';
  renderPlayersList(cachedPlayers);
}

function renderPlayersList(players) {
  cachedPlayers = players || [];

  const countBadge = document.getElementById('playersOnlineCount');
  if (countBadge) countBadge.textContent = cachedPlayers.length;

  const container = document.getElementById('playersCardsContainer');
  if (!container) return;

  const filtered = cachedPlayers.filter(p => {
    const q = playerSearchQuery;
    if (!q) return true;
    const idMatch = String(p.id).includes(q);
    const nameMatch = (p.name || '').toLowerCase().includes(q);
    const redmMatch = (p.redmName || '').toLowerCase().includes(q);
    const codeMatch = (p.charCode || '').toLowerCase().includes(q);
    const heightMatch = ((1.75 * (Number(p.scale) || 1.0)).toFixed(2) + ' м').includes(q);
    return idMatch || nameMatch || redmMatch || codeMatch || heightMatch;
  });

  if (filtered.length === 0) {
    container.innerHTML = '<div class="empty-msg">Игроки не найдены</div>';
    return;
  }

  container.innerHTML = '';

  filtered.forEach(p => {
    const isExpanded = expandedPlayerIds.has(p.id);
    const isDead = !!p.isDead;
    const coords = p.coords || { x: 0, y: 0, z: 0, h: 0 };
    const pedModelHex = p.pedModel ? `0x${Number(p.pedModel).toString(16).toUpperCase()}` : '0x0';
    const isTargetAdmin = (p.group === 'admin' || p.group === 'superadmin' || p.group === 'owner' || p.group === 'mod' || p.group === 'moderator');
    const health = Number.isFinite(Number(p.health)) ? Math.max(0, Math.round(Number(p.health))) : 100;
    const maxHealth = Number.isFinite(Number(p.maxHealth)) ? Math.max(1, Math.round(Number(p.maxHealth))) : 100;
    const healthPercent = Number.isFinite(Number(p.healthPercent))
      ? Math.max(0, Math.min(100, Math.round(Number(p.healthPercent))))
      : Math.max(0, Math.min(100, Math.round((health / maxHealth) * 100)));
    const food = Number.isFinite(Number(p.food)) ? Math.max(0, Math.min(100, Math.round(Number(p.food)))) : 100;
    const water = Number.isFinite(Number(p.water)) ? Math.max(0, Math.min(100, Math.round(Number(p.water)))) : 100;
    const birthYear = Number.isFinite(Number(p.birthYear)) && Number(p.birthYear) > 0 ? Math.round(Number(p.birthYear)) : '—';
    const age = Number.isFinite(Number(p.age)) && Number(p.age) > 0 ? Math.round(Number(p.age)) : '—';
    const scaleNum = Number.isFinite(Number(p.scale)) && Number(p.scale) > 0 ? Number(p.scale) : 1.0;
    const heightMeters = (1.75 * scaleNum).toFixed(2);
    const scaleFormatted = `${heightMeters} м <small style="color: #8890a0; font-size: 11px;">(${scaleNum.toFixed(2)}×)</small>`;

    const card = document.createElement('div');
    card.className = `player-accordion-card ${isExpanded ? 'is-expanded' : ''}`;
    card.id = `player-card-${p.id}`;

    card.innerHTML = `
      <!-- Шапка карточки игрока -->
      <div class="player-card-header" onclick="togglePlayerCard(${p.id})">
        <div class="player-head-left">
          <span class="p-id-badge">#${p.id}</span>
          <div class="p-names-block">
            <span class="p-rp-name">${escapeHtml(p.name || 'Неизвестный')}</span>
            <span class="p-redm-nick">${escapeHtml(p.redmName || '')}</span>
          </div>
        </div>
        <div class="player-head-right">
          <span class="p-ping-tag">${p.ping || 0} ms</span>
          <span class="p-status-tag ${isDead ? 'dead' : 'alive'}">${isDead ? 'Мёртв' : 'Жив'}</span>
          <div class="p-chevron">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="6 9 12 15 18 9"/></svg>
          </div>
        </div>
      </div>

      <!-- Раскрывающееся тело с полной информацией и кнопками -->
      <div class="player-card-body">
        
        <!-- Сетка параметров игрока (Hard RP) -->
        <div class="p-stats-grid">
          <div class="p-stat-box">
            <span class="p-stat-label">Группа / Права</span>
            <span class="p-stat-val ${isTargetAdmin ? 'admin-highlight' : ''}">${escapeHtml(p.group || 'user')}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Здоровье (HP)</span>
            <span class="p-stat-val stat-health-value">${health} / ${maxHealth} <small>(${healthPercent}%)</small></span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Голод</span>
            <span class="p-stat-val stat-food-value">${food}%</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Жажда</span>
            <span class="p-stat-val stat-water-value">${water}%</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Год рождения</span>
            <span class="p-stat-val">${birthYear}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Возраст</span>
            <span class="p-stat-val">${age}${age !== '—' ? ' лет' : ''}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Рост</span>
            <span class="p-stat-val">${scaleFormatted}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Уникальный код</span>
            <span class="p-stat-val mono" style="color: #ffffff; font-weight: 700;">#${escapeHtml(p.charCode || 'N/A')}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">CharIdentifier</span>
            <span class="p-stat-val mono">#${p.charId || 0}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Национальность</span>
            <span class="p-stat-val">${escapeHtml(p.nationality || 'Американец')}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Статус транспорта</span>
            <span class="p-stat-val">${p.inVehicle ? 'В повозке' : (p.onMount ? 'Верхом' : 'Пешком')}</span>
          </div>
          <div class="p-stat-box">
            <span class="p-stat-label">Пинг</span>
            <span class="p-stat-val">${p.ping || 0} ms</span>
          </div>
        </div>

        <!-- Координаты игрока с быстрым копированием -->
        <div class="p-coords-copy-row">
          <div class="p-coords-txt">
            <b>Позиция:</b> X: ${coords.x} | Y: ${coords.y} | Z: ${coords.z} | H: ${coords.h}°
          </div>
          <div class="p-coords-btns">
            <button class="copy-chip" onclick="copyPlayerVec3(${coords.x}, ${coords.y}, ${coords.z})">vec3</button>
            <button class="copy-chip" onclick="copyPlayerVec4(${coords.x}, ${coords.y}, ${coords.z}, ${coords.h})">vec4</button>
          </div>
        </div>

        <!-- История активности игрока -->
        <div class="p-actions-group p-logs-action-group">
          <span class="p-group-title">История активности</span>
          <div class="p-buttons-grid">
            <button class="btn-p-action player-logs-btn" onclick="openPlayerLogsModalForPlayer(${p.id})">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 4h16v16H4z"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>
              Открыть логи
            </button>
          </div>
        </div>

        <!-- Группы действий над целевым игроком -->
        <div class="p-actions-container">
          
          <!-- 1. Телепортация -->
          <div class="p-actions-group">
            <span class="p-group-title">Телепортация</span>
            <div class="p-buttons-grid">
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'tpTo')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                ТП к нему
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'tpHere')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 11l-5-5-5 5M12 6v12"/></svg>
                ТП к себе
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'tpLocation', { x: -179.3, y: 627.8, z: 113.8 })">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>
                В Валентайн
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'tpLocation', { x: 2508.8, y: -1305.4, z: 48.9 })">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>
                В Сен-Дени
              </button>
            </div>
          </div>

          <!-- 2. Управление телом и здоровьем -->
          <div class="p-actions-group">
            <span class="p-group-title">Управление телом и здоровьем</span>
            <div class="p-buttons-grid">
              <button class="btn-p-action green" onclick="targetAction(${p.id}, 'heal')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>
                Полный хилл
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'metabolism')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/></svg>
                Насытить
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'refillStamina')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                Энергия
              </button>
              <button class="btn-p-action stat-action" onclick="openPlayerStatsModalForPlayer(${p.id}, '${escapeHtml(p.name)}', 'health')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z"/></svg>
                Изменить HP
              </button>
              <button class="btn-p-action stat-action" onclick="openPlayerStatsModalForPlayer(${p.id}, '${escapeHtml(p.name)}', 'hunger')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 2v20M6 2c3 0 5 2 5 5H6M6 12c3 0 5 2 5 5H6M18 2v20M18 2c-3 0-5 2-5 5h5M18 12c-3 0-5 2-5 5h5"/></svg>
                Изменить голод
              </button>
              <button class="btn-p-action stat-action" onclick="openPlayerStatsModalForPlayer(${p.id}, '${escapeHtml(p.name)}', 'thirst')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>
                Изменить жажду
              </button>
              <button class="btn-p-action green" onclick="targetAction(${p.id}, 'revive')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/></svg>
                Воскресить
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.godmode) ? 'active' : ''}" onclick="targetAction(${p.id}, 'toggleGodmode')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                Бессмертие <span class="p-btn-badge ${(p.toggles && p.toggles.godmode) ? 'on' : ''}">${(p.toggles && p.toggles.godmode) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.invis) ? 'active' : ''}" onclick="targetAction(${p.id}, 'toggleInvis')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/></svg>
                Невидимость <span class="p-btn-badge ${(p.toggles && p.toggles.invis) ? 'on' : ''}">${(p.toggles && p.toggles.invis) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.superJump) ? 'active' : ''}" onclick="targetAction(${p.id}, 'toggleSuperJump')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                Суперпрыжок <span class="p-btn-badge ${(p.toggles && p.toggles.superJump) ? 'on' : ''}">${(p.toggles && p.toggles.superJump) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.frozen) ? 'active' : ''}" onclick="targetAction(${p.id}, 'freeze')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                Заморозка <span class="p-btn-badge ${(p.toggles && p.toggles.frozen) ? 'on' : ''}">${(p.toggles && p.toggles.frozen) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'cleanPed')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                Очистить педа
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.freezeHunger) ? 'active' : ''}" onclick="targetAction(${p.id}, 'toggleFreezeHunger')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/></svg>
                Заморозка еды <span class="p-btn-badge ${(p.toggles && p.toggles.freezeHunger) ? 'on' : ''}">${(p.toggles && p.toggles.freezeHunger) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.freezeThirst) ? 'active' : ''}" onclick="targetAction(${p.id}, 'toggleFreezeThirst')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"/></svg>
                Заморозка жажды <span class="p-btn-badge ${(p.toggles && p.toggles.freezeThirst) ? 'on' : ''}">${(p.toggles && p.toggles.freezeThirst) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
              <button class="btn-p-action toggle-btn ${(p.toggles && p.toggles.freezeStamina) ? 'active' : ''}" onclick="targetAction(${p.id}, 'toggleFreezeStamina')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                Заморозка энергии <span class="p-btn-badge ${(p.toggles && p.toggles.freezeStamina) ? 'on' : ''}">${(p.toggles && p.toggles.freezeStamina) ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </button>
            </div>
          </div>

          <!-- 3. Оружие и снаряжение -->
          <div class="p-actions-group">
            <span class="p-group-title">Оружие и снаряжение</span>
            <div class="p-buttons-grid">
              <button class="btn-p-action green" onclick="openGiveWeaponModalForPlayer(${p.id}, '${escapeHtml(p.name)}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 16l6-6 4 4 8-8"/><polyline points="15 4 20 4 20 9"/></svg>
                Выдать оружие
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'giveAmmo')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="7" width="20" height="14" rx="2"/></svg>
                Боезапас (999)
              </button>
              <button class="btn-p-action danger" onclick="targetAction(${p.id}, 'disarm')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                Разоружить
              </button>
              <button class="btn-p-action danger" onclick="targetAction(${p.id}, 'kill')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
                Убить (Slap)
              </button>
            </div>
          </div>

          <!-- 4. Предметы и транспорт -->
          <div class="p-actions-group">
            <span class="p-group-title">Предметы и транспорт</span>
            <div class="p-buttons-grid">
              <button class="btn-p-action" onclick="openGiveItemModalForPlayer(${p.id}, '${escapeHtml(p.name)}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>
                Выдать предмет
              </button>
              <button class="btn-p-action" onclick="openGiveHorseModalForPlayer(${p.id}, '${escapeHtml(p.name)}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12c0-3-2.5-5-5-5a6.5 6.5 0 0 0-5 2.5A6.5 6.5 0 0 0 7 7C4.5 7 2 9 2 12"/></svg>
                Выдать лошадь
              </button>
              <button class="btn-p-action" onclick="targetAction(${p.id}, 'deleteVehicle')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                Удалить транспорт
              </button>
            </div>
          </div>

          <!-- 5. Модерация и права -->
          <div class="p-actions-group">
            <span class="p-group-title">Модерация и права</span>
            <div class="p-buttons-grid">
              <button class="btn-p-action ${isTargetAdmin ? 'danger' : 'green'}" onclick="targetAction(${p.id}, 'toggleAdminGroup')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                ${isTargetAdmin ? 'Снять админа' : 'Выдать админа'}
                <span class="p-btn-badge ${isTargetAdmin ? 'on' : ''}">${isTargetAdmin ? 'ADMIN' : 'USER'}</span>
              </button>
              <button class="btn-p-action" onclick="openMessageModalForPlayer(${p.id}, '${escapeHtml(p.name)}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                Уведомление
              </button>
              <button class="btn-p-action danger" onclick="openKickModalForPlayer(${p.id}, '${escapeHtml(p.name)}')">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
                Кикнуть
              </button>
            </div>
          </div>

        </div>
      </div>
    `;

    container.appendChild(card);
  });
}

function togglePlayerCard(playerId) {
  if (expandedPlayerIds.has(playerId)) {
    expandedPlayerIds.delete(playerId);
  } else {
    expandedPlayerIds.add(playerId);
  }
  const card = document.getElementById(`player-card-${playerId}`);
  if (card) {
    card.classList.toggle('is-expanded', expandedPlayerIds.has(playerId));
  }
}

// =================================================================
// МОДАЛЬНОЕ ОКНО ЛОГОВ ИГРОКА
// =================================================================
function legacyOpenPlayerLogsModalForPlayer(playerId) {
  playerLogsTargetId = Number(playerId) || 0;
  const target = cachedPlayers.find((player) => Number(player.id) === playerLogsTargetId);

  if (playerLogsTargetId <= 0 || !playerLogsModal) return;

  if (playerLogsTargetName) {
    playerLogsTargetName.textContent = `#${playerLogsTargetId} (${target ? (target.name || 'Неизвестный') : 'Неизвестный'})`;
  }
  if (playerLogsSearchInput) playerLogsSearchInput.value = '';
  if (playerLogsRequestTimer) {
    clearTimeout(playerLogsRequestTimer);
    playerLogsRequestTimer = null;
  }
  if (playerLogsSummary) playerLogsSummary.textContent = 'Загрузка данных игрока...';
  if (playerLogsMeta) playerLogsMeta.textContent = 'Загрузка логов...';
  if (playerLogsList) playerLogsList.innerHTML = '<div class="empty-msg">Загрузка логов...</div>';

  playerLogsModal.style.display = 'flex';
  playerLogsModalWindow.style.left = '50%';
  playerLogsModalWindow.style.top = '50%';
  playerLogsModalWindow.style.transform = 'translate(-50%, -50%)';
  requestPlayerLogs();
}

function legacyClosePlayerLogsModal() {
  if (playerLogsModal) playerLogsModal.style.display = 'none';
  playerLogsTargetId = 0;
  if (playerLogsSearchTimer) {
    clearTimeout(playerLogsSearchTimer);
    playerLogsSearchTimer = null;
  }
  if (playerLogsRequestTimer) {
    clearTimeout(playerLogsRequestTimer);
    playerLogsRequestTimer = null;
  }
}

function legacyFilterPlayerLogs() {
  if (playerLogsSearchTimer) clearTimeout(playerLogsSearchTimer);
  playerLogsSearchTimer = setTimeout(() => {
    playerLogsSearchTimer = null;
    requestPlayerLogs();
  }, 180);
}

function legacyRequestPlayerLogs() {
  if (!playerLogsTargetId || !playerLogsModal || playerLogsModal.style.display === 'none') return;

  if (playerLogsRequestTimer) clearTimeout(playerLogsRequestTimer);
  playerLogsRequestTimer = setTimeout(() => {
    playerLogsRequestTimer = null;
    if (!playerLogsTargetId || !playerLogsModal || playerLogsModal.style.display === 'none') return;
    if (playerLogsSummary) playerLogsSummary.textContent = 'Ошибка загрузки логов';
    if (playerLogsMeta) playerLogsMeta.textContent = 'Сервер не ответил на запрос логов.';
    if (playerLogsList) playerLogsList.innerHTML = '<div class="empty-msg">Сервер не ответил на запрос логов. Проверьте запуск журнала в консоли.</div>';
  }, 5000);

  sendNui('requestPlayerLogs', {
    playerId: playerLogsTargetId,
    query: playerLogsSearchInput ? playerLogsSearchInput.value.trim() : ''
  });
}

function legacyRenderPlayerLogs(payload) {
  if (!payload || Number(payload.targetId) !== playerLogsTargetId) return;

  if (playerLogsRequestTimer) {
    clearTimeout(playerLogsRequestTimer);
    playerLogsRequestTimer = null;
  }

  if (payload.error) {
    if (playerLogsSummary) playerLogsSummary.textContent = 'Ошибка загрузки логов';
    if (playerLogsMeta) playerLogsMeta.textContent = payload.error;
    if (playerLogsList) playerLogsList.innerHTML = `<div class="empty-msg">${escapeHtml(payload.error)}</div>`;
    return;
  }

  const target = payload.target || {};
  if (playerLogsSummary) {
    const name = target.characterName || 'Персонаж не выбран';
    const platform = target.platform ? `${target.platform}: ${target.redmName || '—'}` : (target.redmName || '—');
    playerLogsSummary.textContent = `#${target.sourceId || playerLogsTargetId} • ${name} • ${platform}`;
  }

  const total = Number(payload.total) || 0;
  const returned = Number(payload.returned) || 0;
  const query = payload.query || '';
  if (playerLogsMeta) {
    const suffix = returned < total ? ` Показаны последние ${returned} из ${total}.` : '';
    playerLogsMeta.textContent = query
      ? `Найдено записей: ${total}.${suffix}`
      : `Всего записей: ${total}.${suffix}`;
  }

  if (!playerLogsList) return;
  playerLogsList.innerHTML = '';

  if (!Array.isArray(payload.logs) || payload.logs.length === 0) {
    playerLogsList.innerHTML = '<div class="empty-msg">По этому запросу логов нет</div>';
    return;
  }

  payload.logs.forEach((log) => {
    const row = document.createElement('div');
    const safeClass = String(log.typeClass || 'default').replace(/[^a-z0-9_-]/gi, '');
    row.className = `player-log-entry log-${safeClass || 'default'}`;

    const actorParts = [];
    if (log.sourceId) actorParts.push(`ID #${log.sourceId}`);
    if (log.characterName) actorParts.push(`Персонаж: ${log.characterName}`);
    if (log.platform && log.redmName) actorParts.push(`${log.platform}: ${log.redmName}`);

    row.innerHTML = `
      <div class="player-log-head">
        <span class="player-log-type">${escapeHtml(log.typeLabel || log.type || 'ЛОГ')}</span>
        <span class="player-log-time">${escapeHtml(log.time || '')}</span>
      </div>
      <div class="player-log-text">${escapeHtml(log.text || '')}</div>
      <div class="player-log-actor">${escapeHtml(actorParts.join(' • '))}</div>
    `;
    playerLogsList.appendChild(row);
  });
}

// =================================================================
// ВИРТУАЛЬНАЯ ЗАГРУЗКА ЛОГОВ
// =================================================================
const PLAYER_LOG_PAGE_SIZE = 100;
const PLAYER_LOG_MAX_RENDERED = 240;
const PLAYER_LOG_UNLOAD_BATCH = 100;

function resetPlayerLogsState(query, dateFrom, dateTo) {
  playerLogsQuery = query || '';
  playerLogsDateFrom = dateFrom || '';
  playerLogsDateTo = dateTo || '';
  playerLogsNextOffset = 0;
  playerLogsHasMore = true;
  playerLogsLoading = false;
  playerLogsActiveRequestId = 0;
  playerLogsFetchedCount = 0;
  playerLogsRenderedCount = 0;
  playerLogsTotal = 0;
  playerLogsSnapshotId = 0;

  if (playerLogsRequestTimer) {
    clearTimeout(playerLogsRequestTimer);
    playerLogsRequestTimer = null;
  }

  if (playerLogsList) {
    playerLogsList.innerHTML = '<div class="empty-msg">\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u043b\u043e\u0433\u043e\u0432...</div>';
    playerLogsList.scrollTop = 0;
  }
}

function openPlayerLogsModalForPlayer(playerId) {
  playerLogsTargetId = Number(playerId) || 0;
  const target = cachedPlayers.find((player) => Number(player.id) === playerLogsTargetId);

  if (playerLogsTargetId <= 0 || !playerLogsModal) return;

  if (playerLogsTargetName) {
    playerLogsTargetName.textContent = `#${playerLogsTargetId} (${target ? (target.name || '\u041d\u0435\u0438\u0437\u0432\u0435\u0441\u0442\u043d\u044b\u0439') : '\u041d\u0435\u0438\u0437\u0432\u0435\u0441\u0442\u043d\u044b\u0439'})`;
  }

  if (playerLogsSearchInput) playerLogsSearchInput.value = '';
  if (playerLogsDateFromInput) playerLogsDateFromInput.value = '';
  if (playerLogsDateToInput) playerLogsDateToInput.value = '';
  if (playerLogsSummary) playerLogsSummary.textContent = '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u0434\u0430\u043d\u043d\u044b\u0445 \u0438\u0433\u0440\u043e\u043a\u0430...';
  if (playerLogsMeta) playerLogsMeta.textContent = '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u043b\u043e\u0433\u043e\u0432...';

  playerLogsModal.style.display = 'flex';
  playerLogsModalWindow.style.left = '50%';
  playerLogsModalWindow.style.top = '50%';
  playerLogsModalWindow.style.transform = 'translate(-50%, -50%)';
  requestPlayerLogs({ reset: true });
}

function closePlayerLogsModal() {
  if (playerLogsModal) playerLogsModal.style.display = 'none';
  playerLogsTargetId = 0;
  playerLogsLoading = false;

  if (playerLogsSearchTimer) {
    clearTimeout(playerLogsSearchTimer);
    playerLogsSearchTimer = null;
  }
  if (playerLogsRequestTimer) {
    clearTimeout(playerLogsRequestTimer);
    playerLogsRequestTimer = null;
  }
}

function filterPlayerLogs() {
  if (playerLogsSearchTimer) clearTimeout(playerLogsSearchTimer);
  playerLogsSearchTimer = setTimeout(() => {
    playerLogsSearchTimer = null;
    requestPlayerLogs({ reset: true });
  }, 180);
}

function filterPlayerLogsByDate() {
  requestPlayerLogs({ reset: true });
}

function requestPlayerLogs(options = {}) {
  if (!playerLogsTargetId || !playerLogsModal || playerLogsModal.style.display === 'none') return;

  const query = playerLogsSearchInput ? playerLogsSearchInput.value.trim() : '';
  const dateFrom = playerLogsDateFromInput ? playerLogsDateFromInput.value : '';
  const dateTo = playerLogsDateToInput ? playerLogsDateToInput.value : '';
  if (options.reset === true || query !== playerLogsQuery || dateFrom !== playerLogsDateFrom || dateTo !== playerLogsDateTo) {
    resetPlayerLogsState(query, dateFrom, dateTo);
  }

  if (playerLogsLoading || !playerLogsHasMore) return;

  const requestId = ++playerLogsRequestSequence;
  const offset = playerLogsNextOffset;
  playerLogsActiveRequestId = requestId;
  playerLogsLoading = true;

  if (playerLogsRequestTimer) clearTimeout(playerLogsRequestTimer);
  playerLogsRequestTimer = setTimeout(() => {
    if (requestId !== playerLogsActiveRequestId || !playerLogsLoading) return;
    playerLogsLoading = false;
    if (playerLogsFetchedCount === 0) {
      if (playerLogsSummary) playerLogsSummary.textContent = '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u043b\u043e\u0433\u043e\u0432';
      if (playerLogsMeta) playerLogsMeta.textContent = '\u0421\u0435\u0440\u0432\u0435\u0440 \u043d\u0435 \u043e\u0442\u0432\u0435\u0442\u0438\u043b \u043d\u0430 \u0437\u0430\u043f\u0440\u043e\u0441 \u043b\u043e\u0433\u043e\u0432.';
      if (playerLogsList) playerLogsList.innerHTML = '<div class="empty-msg">\u0421\u0435\u0440\u0432\u0435\u0440 \u043d\u0435 \u043e\u0442\u0432\u0435\u0442\u0438\u043b \u043d\u0430 \u0437\u0430\u043f\u0440\u043e\u0441 \u043b\u043e\u0433\u043e\u0432.</div>';
    } else if (playerLogsMeta) {
      playerLogsMeta.textContent = '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0434\u043e\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0441\u043b\u0435\u0434\u0443\u044e\u0449\u0443\u044e \u043f\u043e\u0440\u0446\u0438\u044e.';
    }
  }, 5000);

  if (playerLogsMeta) {
    playerLogsMeta.textContent = playerLogsFetchedCount > 0
      ? `\u0417\u0430\u0433\u0440\u0443\u0436\u0435\u043d\u043e ${playerLogsFetchedCount}${playerLogsTotal ? ` \u0438\u0437 ${playerLogsTotal}` : ''}. \u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430...`
      : '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u043b\u043e\u0433\u043e\u0432...';
  }

  sendNui('requestPlayerLogs', {
    playerId: playerLogsTargetId,
    query,
    offset,
    limit: PLAYER_LOG_PAGE_SIZE,
    requestId,
    snapshotId: playerLogsSnapshotId,
    dateFrom,
    dateTo
  });
}

function appendPlayerLogEntry(log) {
  if (!playerLogsList) return;

  const row = document.createElement('div');
  const safeClass = String(log.typeClass || 'default').replace(/[^a-z0-9_-]/gi, '');
  row.className = `player-log-entry log-${safeClass || 'default'}`;

  const actorParts = [];
  if (log.sourceId) actorParts.push(`ID #${log.sourceId}`);
  if (log.characterName) actorParts.push(`\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436: ${log.characterName}`);
  if (log.platform && log.redmName) actorParts.push(`${log.platform}: ${log.redmName}`);

  row.innerHTML = `
    <div class="player-log-head">
      <span class="player-log-type">${escapeHtml(log.typeLabel || log.type || '\u041b\u041e\u0413')}</span>
      <span class="player-log-time">${escapeHtml(log.time || '')}</span>
    </div>
    <div class="player-log-text">${escapeHtml(log.text || '')}</div>
    <div class="player-log-actor">${escapeHtml(actorParts.join(' \u2022 '))}</div>
  `;
  playerLogsList.appendChild(row);
}

function unloadScrolledPlayerLogs() {
  if (!playerLogsList || playerLogsRenderedCount <= PLAYER_LOG_MAX_RENDERED) return;

  const rows = Array.from(playerLogsList.querySelectorAll('.player-log-entry'));
  if (rows.length <= PLAYER_LOG_MAX_RENDERED) return;

  const viewportTop = playerLogsList.scrollTop;
  const removable = rows.filter((row) => row.offsetTop + row.offsetHeight < viewportTop - 120);
  const removeCount = Math.min(
    PLAYER_LOG_UNLOAD_BATCH,
    rows.length - PLAYER_LOG_MAX_RENDERED,
    removable.length
  );
  if (removeCount <= 0) return;

  const oldScrollTop = playerLogsList.scrollTop;
  let removedHeight = 0;
  for (let index = 0; index < removeCount; index += 1) {
    const row = rows[index];
    const styles = window.getComputedStyle(row);
    removedHeight += row.getBoundingClientRect().height + (parseFloat(styles.marginBottom) || 0);
    row.remove();
  }

  playerLogsRenderedCount = Math.max(0, playerLogsRenderedCount - removeCount);
  playerLogsList.scrollTop = Math.max(0, oldScrollTop - removedHeight);
}

function handlePlayerLogsScroll() {
  if (!playerLogsList || !playerLogsTargetId) return;

  unloadScrolledPlayerLogs();

  const distanceToBottom = playerLogsList.scrollHeight - playerLogsList.scrollTop - playerLogsList.clientHeight;
  if (distanceToBottom < 280 && playerLogsHasMore && !playerLogsLoading) {
    requestPlayerLogs();
  }
}

function renderPlayerLogs(payload) {
  if (!payload || Number(payload.targetId) !== playerLogsTargetId) return;
  if (payload.requestId && Number(payload.requestId) !== playerLogsActiveRequestId) return;

  if (playerLogsRequestTimer) {
    clearTimeout(playerLogsRequestTimer);
    playerLogsRequestTimer = null;
  }
  playerLogsLoading = false;

  if (payload.error) {
    if (playerLogsFetchedCount === 0) {
      if (playerLogsSummary) playerLogsSummary.textContent = '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438 \u043b\u043e\u0433\u043e\u0432';
      if (playerLogsList) playerLogsList.innerHTML = `<div class="empty-msg">${escapeHtml(payload.error)}</div>`;
    }
    if (playerLogsMeta) playerLogsMeta.textContent = payload.error;
    return;
  }

  const offset = Math.max(0, Number(payload.offset) || 0);
  const logs = Array.isArray(payload.logs) ? payload.logs : [];
  const snapshotId = Number(payload.snapshotId) || 0;
  if (snapshotId > 0) playerLogsSnapshotId = snapshotId;
  playerLogsTotal = Math.max(0, Number(payload.total) || 0);
  playerLogsHasMore = Boolean(payload.hasMore);
  playerLogsNextOffset = Number.isFinite(Number(payload.nextOffset))
    ? Number(payload.nextOffset)
    : offset + logs.length;
  playerLogsFetchedCount = Math.max(playerLogsFetchedCount, offset + logs.length);

  const target = payload.target || {};
  if (playerLogsSummary) {
    const name = target.characterName || '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436 \u043d\u0435 \u0432\u044b\u0431\u0440\u0430\u043d';
    const platform = target.platform ? `${target.platform}: ${target.redmName || '\u2014'}` : (target.redmName || '\u2014');
    playerLogsSummary.textContent = `#${target.sourceId || playerLogsTargetId} \u2022 ${name} \u2022 ${platform}`;
  }

  if (offset === 0 && playerLogsList) playerLogsList.innerHTML = '';
  logs.forEach(appendPlayerLogEntry);
  playerLogsRenderedCount = playerLogsList ? playerLogsList.querySelectorAll('.player-log-entry').length : 0;

  if (playerLogsRenderedCount === 0 && playerLogsList) {
    playerLogsList.innerHTML = '<div class="empty-msg">\u041f\u043e \u044d\u0442\u043e\u043c\u0443 \u0437\u0430\u043f\u0440\u043e\u0441\u0443 \u043b\u043e\u0433\u043e\u0432 \u043d\u0435\u0442</div>';
  }

  unloadScrolledPlayerLogs();

  if (playerLogsMeta) {
    const loaded = playerLogsTotal ? `\u0417\u0430\u0433\u0440\u0443\u0436\u0435\u043d\u043e ${playerLogsFetchedCount} \u0438\u0437 ${playerLogsTotal}.` : '\u0417\u0430\u043f\u0438\u0441\u0435\u0439 \u043d\u0435\u0442.';
    const dateFrom = payload.dateFrom || playerLogsDateFrom;
    const dateTo = payload.dateTo || playerLogsDateTo;
    const dateLabel = dateFrom || dateTo
      ? ` \u041f\u0435\u0440\u0438\u043e\u0434: ${dateFrom || '\u2014'} \u2014 ${dateTo || '\u2014'}.`
      : '';
    playerLogsMeta.textContent = playerLogsHasMore
      ? `${loaded}${dateLabel} \u041f\u0440\u043e\u043a\u0440\u0443\u0442\u0438\u0442\u0435 \u043d\u0438\u0436\u0435 \u0434\u043b\u044f \u0434\u043e\u0433\u0440\u0443\u0437\u043a\u0438.`
      : `${loaded}${dateLabel}`;
  }
}

if (playerLogsList) playerLogsList.addEventListener('scroll', handlePlayerLogsScroll);

function targetAction(targetId, actionName, extraData = {}) {
  sendNui('adminPlayerAction', {
    targetId: targetId,
    action: actionName,
    extraData: extraData
  });

  const titles = {
    tpTo: "Телепортация",
    tpHere: "Телепортация",
    tpLocation: "Телепортация",
    heal: "Лечение",
    metabolism: "Метаболизм",
    refillStamina: "Выносливость",
    revive: "Реанимация",
    kill: "Убийство",
    toggleGodmode: "Бессмертие",
    toggleInvis: "Невидимость",
    toggleFreezeHunger: "Сытость",
    toggleFreezeThirst: "Жажда",
    toggleFreezeStamina: "Выносливость",
    freeze: "Заморозка",
    cleanPed: "Очистка педа",
    giveAmmo: "Боезапас",
    disarm: "Разоружение",
    spawnHorse: "Лошадь",
    deleteVehicle: "Транспорт",
    setStats: "Показатели"
  };

  showToast(titles[actionName] || "Действие", `Команда отправлена для игрока #${targetId}`, 'info');
}

function copyPlayerVec3(x, y, z) {
  const t = `vector3(${Number(x).toFixed(2)}, ${Number(y).toFixed(2)}, ${Number(z).toFixed(2)})`;
  copyToClipboard(t, "Игрок (vector3)");
}

function copyPlayerVec4(x, y, z, h) {
  const t = `vector4(${Number(x).toFixed(2)}, ${Number(y).toFixed(2)}, ${Number(z).toFixed(2)}, ${Number(h).toFixed(2)})`;
  copyToClipboard(t, "Игрок (vector4)");
}

// =================================================================
// МОДАЛЬНЫЕ ОКНА ДЛЯ ЦЕЛЕВОГО ИГРОКА
// =================================================================

// 1. Выдача оружия
function openGiveWeaponModalForPlayer(playerId, playerName) {
  modalTargetPlayerId = playerId;
  modalTargetPlayerName = playerName;
  selectedModalWeapon = '';

  const titleEl = document.getElementById('weaponModalTargetName');
  if (titleEl) titleEl.textContent = `#${playerId} (${playerName})`;

  const searchInp = document.getElementById('weaponModalSearch');
  if (searchInp) searchInp.value = '';

  renderWeaponModalList(WEAPONS_CATALOG);

  giveWeaponModal.style.display = 'flex';
  giveWeaponModalWindow.style.left = '50%';
  giveWeaponModalWindow.style.top = '50%';
  giveWeaponModalWindow.style.transform = 'translate(-50%, -50%)';
}

function closeGiveWeaponModal() {
  if (giveWeaponModal) giveWeaponModal.style.display = 'none';
}

function filterWeaponModalList() {
  const searchInp = document.getElementById('weaponModalSearch');
  const q = searchInp ? searchInp.value.trim().toLowerCase() : '';
  const filtered = WEAPONS_CATALOG.filter(w => 
    w.name.toLowerCase().includes(q) || 
    w.desc.toLowerCase().includes(q) || 
    w.id.toLowerCase().includes(q)
  );
  renderWeaponModalList(filtered);
}

function renderWeaponModalList(weapons) {
  const listEl = document.getElementById('weaponModalList');
  if (!listEl) return;

  listEl.innerHTML = '';
  weapons.forEach(w => {
    const itemEl = document.createElement('div');
    itemEl.className = 'modal-select-item';
    itemEl.onclick = () => {
      sendNui('adminPlayerAction', {
        targetId: modalTargetPlayerId,
        action: 'giveWeapon',
        extraData: { weapon: w.id }
      });
      showToast("Оружие", `Выдано ${w.name} игроку #${modalTargetPlayerId}`, 'success');
      closeGiveWeaponModal();
    };
    itemEl.innerHTML = `
      <div>
        <div class="modal-select-name">${escapeHtml(w.name)}</div>
        <div class="modal-select-sub">${escapeHtml(w.desc)}</div>
      </div>
      <button class="btn-sm modal-give-btn">Выдать</button>
    `;
    listEl.appendChild(itemEl);
  });
}

// 2. Выдача лошади выбранному игроку
function openGiveHorseModalForPlayer(playerId, playerName) {
  modalTargetPlayerId = playerId;
  modalTargetPlayerName = playerName;
  selectedModalHorse = '';

  const titleEl = document.getElementById('horseModalTargetName');
  if (titleEl) titleEl.textContent = `#${playerId} (${playerName})`;

  const searchInp = document.getElementById('horseModalSearch');
  if (searchInp) searchInp.value = '';

  renderHorseModalList(HORSES_CATALOG);

  giveHorseModal.style.display = 'flex';
  giveHorseModalWindow.style.left = '50%';
  giveHorseModalWindow.style.top = '50%';
  giveHorseModalWindow.style.transform = 'translate(-50%, -50%)';
}

function closeGiveHorseModal() {
  if (giveHorseModal) giveHorseModal.style.display = 'none';
}

function filterHorseModalList() {
  const searchInp = document.getElementById('horseModalSearch');
  const q = searchInp ? searchInp.value.trim().toLowerCase() : '';
  const filtered = HORSES_CATALOG.filter(h =>
    h.name.toLowerCase().includes(q) ||
    h.desc.toLowerCase().includes(q) ||
    h.id.toLowerCase().includes(q)
  );
  renderHorseModalList(filtered);
}

function renderHorseModalList(horses) {
  const listEl = document.getElementById('horseModalList');
  if (!listEl) return;

  listEl.innerHTML = '';
  if (!horses.length) {
    listEl.innerHTML = '<div class="empty-msg">Лошади не найдены</div>';
    return;
  }

  horses.forEach(h => {
    const itemEl = document.createElement('div');
    itemEl.className = `modal-select-item ${selectedModalHorse === h.id ? 'is-selected' : ''}`;
    itemEl.onclick = () => {
      selectedModalHorse = h.id;
      sendNui('adminPlayerAction', {
        targetId: modalTargetPlayerId,
        action: 'spawnHorse',
        extraData: { model: h.id }
      });
      showToast("Лошадь", `Заспавнена ${h.name} игроку #${modalTargetPlayerId}`, 'success');
      closeGiveHorseModal();
    };
    itemEl.innerHTML = `
      <div>
        <div class="modal-select-name">${escapeHtml(h.name)}</div>
        <div class="modal-select-sub">${escapeHtml(h.desc)} · ${escapeHtml(h.id)}</div>
      </div>
      <button class="btn-sm modal-give-btn">Выдать</button>
    `;
    listEl.appendChild(itemEl);
  });
}

// 3. Изменение показателей выбранного игрока
function openPlayerStatsModalForPlayer(playerId, playerName, focusField = '') {
  modalTargetPlayerId = playerId;
  modalTargetPlayerName = playerName;
  const player = cachedPlayers.find(p => Number(p.id) === Number(playerId)) || {};

  const titleEl = document.getElementById('playerStatsModalTargetName');
  if (titleEl) titleEl.textContent = `#${playerId} (${playerName})`;

  const health = Number.isFinite(Number(player.healthPercent))
    ? Math.round(Number(player.healthPercent))
    : Math.round((Number(player.health || 100) / Math.max(1, Number(player.maxHealth || 100))) * 100);
  const healthInput = document.getElementById('playerStatHealthInput');
  const hungerInput = document.getElementById('playerStatHungerInput');
  const thirstInput = document.getElementById('playerStatThirstInput');
  if (healthInput) healthInput.value = Math.max(0, Math.min(100, health));
  if (hungerInput) hungerInput.value = Math.max(0, Math.min(100, Number(player.food ?? 100)));
  if (thirstInput) thirstInput.value = Math.max(0, Math.min(100, Number(player.water ?? 100)));

  playerStatsModal.style.display = 'flex';
  playerStatsModalWindow.style.left = '50%';
  playerStatsModalWindow.style.top = '50%';
  playerStatsModalWindow.style.transform = 'translate(-50%, -50%)';

  if (focusField) {
    setTimeout(() => {
      const input = document.getElementById(`playerStat${focusField.charAt(0).toUpperCase()}${focusField.slice(1)}Input`);
      if (input) input.focus();
    }, 0);
  }
}

function closePlayerStatsModal() {
  if (playerStatsModal) playerStatsModal.style.display = 'none';
}

function readPlayerStatInput(field) {
  const id = `playerStat${field.charAt(0).toUpperCase()}${field.slice(1)}Input`;
  const input = document.getElementById(id);
  const value = input ? Number(input.value) : NaN;
  if (!Number.isFinite(value)) return null;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function submitPlayerStat(field) {
  const value = readPlayerStatInput(field);
  if (value === null) {
    showToast("Ошибка", "Укажите значение от 0 до 100", "warn");
    return;
  }

  targetAction(modalTargetPlayerId, 'setStats', { [field]: value });
  closePlayerStatsModal();
}

function submitAllPlayerStats() {
  const health = readPlayerStatInput('health');
  const hunger = readPlayerStatInput('hunger');
  const thirst = readPlayerStatInput('thirst');
  if (health === null || hunger === null || thirst === null) {
    showToast("Ошибка", "Все значения должны быть от 0 до 100", "warn");
    return;
  }

  targetAction(modalTargetPlayerId, 'setStats', { health, hunger, thirst });
  closePlayerStatsModal();
}

// 4. Выдача предметов
function openGiveItemModalForPlayer(playerId, playerName) {
  modalTargetPlayerId = playerId;
  modalTargetPlayerName = playerName;
  selectedModalItem = '';

  const titleEl = document.getElementById('itemModalTargetName');
  if (titleEl) titleEl.textContent = `#${playerId} (${playerName})`;

  const searchInp = document.getElementById('itemModalSearch');
  if (searchInp) searchInp.value = '';

  const countInp = document.getElementById('itemCountInput');
  if (countInp) countInp.value = '1';

  sendNui('getAdminItemsList');

  giveItemPlayerModal.style.display = 'flex';
  giveItemPlayerModalWindow.style.left = '50%';
  giveItemPlayerModalWindow.style.top = '50%';
  giveItemPlayerModalWindow.style.transform = 'translate(-50%, -50%)';
}

function closeGiveItemPlayerModal() {
  if (giveItemPlayerModal) giveItemPlayerModal.style.display = 'none';
}

let modalSearchDebounce = null;
function filterItemModalList() {
  clearTimeout(modalSearchDebounce);
  modalSearchDebounce = setTimeout(() => {
    const searchInp = document.getElementById('itemModalSearch');
    const q = searchInp ? searchInp.value.trim().toLowerCase() : '';
    const filtered = adminItems.filter(it => 
      (it.label || '').toLowerCase().includes(q) || 
      (it.name || '').toLowerCase().includes(q)
    );
    renderItemModalList(filtered);
  }, 100);
}

function renderItemModalList(items) {
  const listEl = document.getElementById('itemModalList');
  if (!listEl) return;

  listEl.innerHTML = '';
  const safeItems = items || [];
  const displayed = safeItems.slice(0, 80);
  displayed.forEach(it => {
    const itemEl = document.createElement('div');
    itemEl.className = `modal-select-item ${selectedModalItem === it.name ? 'is-selected' : ''}`;
    itemEl.onclick = () => {
      selectedModalItem = it.name;
      document.querySelectorAll('#itemModalList .modal-select-item').forEach(el => el.classList.remove('is-selected'));
      itemEl.classList.add('is-selected');
    };
    itemEl.innerHTML = `
      <div>
        <div class="modal-select-name">${escapeHtml(it.label || it.name)}</div>
        <div class="modal-select-sub">${escapeHtml(it.name)}</div>
      </div>
      <button class="btn-sm" onclick="quickGiveItemToPlayer('${it.name}')">Выдать 1</button>
    `;
    listEl.appendChild(itemEl);
  });

  if (safeItems.length > 80) {
    const hint = document.createElement('div');
    hint.className = 'empty-hint';
    hint.style.padding = '8px';
    hint.style.textAlign = 'center';
    hint.textContent = `Показано 80 из ${safeItems.length}. Уточните поиск для других предметов.`;
    listEl.appendChild(hint);
  }
}

function quickGiveItemToPlayer(itemName) {
  sendNui('adminPlayerAction', {
    targetId: modalTargetPlayerId,
    action: 'giveItem',
    extraData: { item: itemName, count: 1 }
  });
  showToast("Предметы", `Выдано ${itemName} (x1) игроку #${modalTargetPlayerId}`, 'success');
  closeGiveItemPlayerModal();
}

function submitGiveItemToPlayer() {
  if (!selectedModalItem) {
    showToast("Ошибка", "Выберите предмет из списка", "warn");
    return;
  }
  const countInp = document.getElementById('itemCountInput');
  const count = countInp ? (parseInt(countInp.value, 10) || 1) : 1;

  sendNui('adminPlayerAction', {
    targetId: modalTargetPlayerId,
    action: 'giveItem',
    extraData: { item: selectedModalItem, count: count }
  });

  showToast("Предметы", `Выдано ${selectedModalItem} (x${count}) игроку #${modalTargetPlayerId}`, 'success');
  closeGiveItemPlayerModal();
}

// 5. Кик игрока
function openKickModalForPlayer(playerId, playerName) {
  modalTargetPlayerId = playerId;
  modalTargetPlayerName = playerName;

  const titleEl = document.getElementById('kickModalTargetName');
  if (titleEl) titleEl.textContent = `#${playerId} (${playerName})`;

  const reasonInp = document.getElementById('kickReasonInput');
  if (reasonInp) reasonInp.value = 'Исключен администратором';

  kickModal.style.display = 'flex';
  kickModalWindow.style.left = '50%';
  kickModalWindow.style.top = '50%';
  kickModalWindow.style.transform = 'translate(-50%, -50%)';
}

function closeKickModal() {
  if (kickModal) kickModal.style.display = 'none';
}

function submitKickPlayer() {
  const reasonInp = document.getElementById('kickReasonInput');
  const reason = reasonInp ? reasonInp.value.trim() : 'Исключен администратором';

  sendNui('adminPlayerAction', {
    targetId: modalTargetPlayerId,
    action: 'kick',
    extraData: { reason: reason }
  });

  showToast("Кик", `Игрок #${modalTargetPlayerId} исключен с сервера`, 'warn');
  closeKickModal();
  setTimeout(() => sendNui('requestPlayersList'), 500);
}

// 6. Личное сообщение игроку
function openMessageModalForPlayer(playerId, playerName) {
  modalTargetPlayerId = playerId;
  modalTargetPlayerName = playerName;

  const titleEl = document.getElementById('messageModalTargetName');
  if (titleEl) titleEl.textContent = `#${playerId} (${playerName})`;

  const msgInp = document.getElementById('playerMessageInput');
  if (msgInp) msgInp.value = '';
  const durationInput = document.getElementById('messageDurationInput');
  if (durationInput) durationInput.value = '15';

  messageModal.style.display = 'flex';
  messageModalWindow.style.left = '50%';
  messageModalWindow.style.top = '50%';
  messageModalWindow.style.transform = 'translate(-50%, -50%)';
}

function closeMessageModal() {
  if (messageModal) messageModal.style.display = 'none';
}

function submitMessagePlayer() {
  const msgInp = document.getElementById('playerMessageInput');
  const msg = msgInp ? msgInp.value.trim() : '';
  const durationInput = document.getElementById('messageDurationInput');
  const duration = Math.max(1, Math.min(60, Number(durationInput ? durationInput.value : 15) || 15));
  if (!msg) {
    showToast("Ошибка", "Введите текст сообщения", "warn");
    return;
  }

  sendNui('adminPlayerAction', {
    targetId: modalTargetPlayerId,
    action: 'sendToast',
    extraData: { message: msg, duration: duration }
  });

  showToast("Сообщение", `Отправлено игроку #${modalTargetPlayerId} на ${duration} сек.`, 'success');
  closeMessageModal();
}

// =================================================================
// МОДАЛЬНЫЕ ОКНА: ТЕЛЕПОРТ ПО ID И ИЗМЕНЕНИЕ ВРЕМЕНИ
// =================================================================
function openPlayersModal() {
  playersModal.style.display = 'flex';
  playersModalWindow.style.left = '50%';
  playersModalWindow.style.top = '50%';
  playersModalWindow.style.transform = 'translate(-50%, -50%)';
  if (tpPlayerIdInput) tpPlayerIdInput.value = '';
  sendNui('requestPlayersList');
}

function closePlayersModal() {
  if (playersModal) playersModal.style.display = 'none';
}

function tpToPlayerById() {
  const val = tpPlayerIdInput ? tpPlayerIdInput.value.trim() : '';
  const targetId = parseInt(val, 10);
  if (!isNaN(targetId) && targetId > 0) {
    sendNui('tpToPlayerById', { targetId: targetId });
    showToast("Телепортация", `Телепорт к игроку #${targetId}`, 'info');
    closePlayersModal();
  }
}

function openTimeModal() {
  timeModal.style.display = 'flex';
  timeModalWindow.style.left = '50%';
  timeModalWindow.style.top = '50%';
  timeModalWindow.style.transform = 'translate(-50%, -50%)';
  if (timeInput) {
    timeInput.value = '';
    timeInput.focus();
  }
}

function closeTimeModal() {
  if (timeModal) timeModal.style.display = 'none';
}

function submitTime() {
  const val = timeInput ? timeInput.value.trim() : '';
  if (val) {
    sendNui('setTime', { time: val });
    showToast("Время суток", `Установлено время: ${val}`, 'success');
    closeTimeModal();
  }
}

// =================================================================
// ВКЛАДКА "ПРЕДМЕТЫ" (ADMIN ITEMS)
// =================================================================
let adminItems = [];
let activeItemCategory = 'all';
let itemSearchQuery = '';
let adminItemsCurrentPage = 1;
const ADMIN_ITEMS_PER_PAGE = 32;
let searchDebounceTimeout = null;

function setAdminItemCategory(cat) {
  activeItemCategory = cat;
  adminItemsCurrentPage = 1;
  document.querySelectorAll('#adminCategoryPills .cat-pill').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-category') === cat);
  });
  renderAdminItems();
}

function filterAdminItems() {
  clearTimeout(searchDebounceTimeout);
  searchDebounceTimeout = setTimeout(() => {
    const input = document.getElementById('itemsSearchInput');
    itemSearchQuery = input ? input.value.trim().toLowerCase() : '';
    adminItemsCurrentPage = 1;
    renderAdminItems();
  }, 120);
}

function changeAdminItemsPage(delta) {
  adminItemsCurrentPage += delta;
  renderAdminItems();
  const contentEl = document.querySelector('.admin-content');
  if (contentEl) contentEl.scrollTop = 0;
}

const ADMIN_ITEM_IMAGES = {
  apple: 'images/apple.png',
  bandage: 'images/bandage.png',
  bandage_burdock: 'images/bandage_burdock.png',
  bottle_empty: 'images/bottle_empty.png',
  bottle_water: 'images/bottle_water.png',
  burdock_leaf: 'images/burdock_leaf.png',
  campfire: 'images/campfire.png',
  cloth: 'images/cloth.png',
  glass: 'images/glass.png',
  house_key: 'images/house_key.png',
  iron_ingot: 'images/iron_ingot.png',
  iron_ore: 'images/iron_ore.png',
  mango: 'images/mango.png',
  notebook: 'images/notebook.png',
  torn_page: 'images/torn_page.png',
  meat_bear_cooked: 'images/meat_bear_cooked.png',
  meat_bear_raw: 'images/meat_bear_raw.png',
  meat_beef_cooked: 'images/meat_beef_cooked.png',
  meat_beef_raw: 'images/meat_beef_raw.png',
  meat_bird_cooked: 'images/meat_bird_cooked.png',
  meat_bird_raw: 'images/meat_bird_raw.png',
  meat_deer_cooked: 'images/meat_deer_cooked.png',
  meat_deer_raw: 'images/meat_deer_raw.png',
  meat_pork_cooked: 'images/meat_pork_cooked.png',
  meat_pork_raw: 'images/meat_pork_raw.png',
  meat_rabbit_cooked: 'images/meat_rabbit_cooked.png',
  meat_rabbit_raw: 'images/meat_rabbit_raw.png',
  pear: 'images/pear.png',
  stone: 'images/stone.png',
  twigs: 'images/twigs.png',
  wood_log: 'images/wood_log.png',
  wood_plank: 'images/wood_plank.png',

  // Новые предметы (126)
  alcohol: 'images/alcohol.png',
  alligator_tooth: 'images/alligator_tooth.png',
  animal_bone: 'images/animal_bone.png',
  animal_fat: 'images/animal_fat.png',
  animal_skull: 'images/animal_skull.png',
  axe: 'images/axe.png',
  bag: 'images/bag.png',
  bag_large: 'images/bag_large.png',
  beeswax: 'images/beeswax.png',
  black_pollen: 'images/black_pollen.png',
  cactus_juice: 'images/cactus_juice.png',
  candy_apple: 'images/candy_apple.png',
  canned_beans: 'images/canned_beans.png',
  canned_clams: 'images/canned_clams.png',
  canned_fish: 'images/canned_fish.png',
  canned_meat: 'images/canned_meat.png',
  canned_peaches: 'images/canned_peaches.png',
  canned_pineapple: 'images/canned_pineapple.png',
  canned_strawberries: 'images/canned_strawberries.png',
  canned_tomatoes: 'images/canned_tomatoes.png',
  carrot: 'images/carrot.png',
  celery: 'images/celery.png',
  charcoal: 'images/charcoal.png',
  chewing_tobacco: 'images/chewing_tobacco.png',
  coffee: 'images/coffee.png',
  corn: 'images/corn.png',
  corn_bait: 'images/corn_bait.png',
  corn_boiled: 'images/corn_boiled.png',
  corn_flour: 'images/corn_flour.png',
  cornbread: 'images/cornbread.png',
  corrupted_organ: 'images/corrupted_organ.png',
  cursed_bone: 'images/cursed_bone.png',
  egg: 'images/egg.png',
  egg_boiled: 'images/egg_boiled.png',
  egg_fried: 'images/egg_fried.png',
  feather: 'images/feather.png',
  first_aid_kit: 'images/first_aid_kit.png',
  fish_oil: 'images/fish_oil.png',
  fishing_rod: 'images/fishing_rod.png',
  flask: 'images/flask.png',
  flask_glass: 'images/flask_glass.png',
  flask_water: 'images/flask_water.png',
  gold_ingot: 'images/gold_ingot.png',
  gold_ore: 'images/gold_ore.png',
  gold_pocket_watch: 'images/gold_pocket_watch.png',
  gold_tooth: 'images/gold_tooth.png',
  grooming_kit: 'images/grooming_kit.png',
  gunpowder: 'images/gunpowder.png',
  hammer: 'images/hammer.png',
  herb_desert_sage: 'images/herb_desert_sage.png',
  herb_ginseng_alaskan: 'images/herb_ginseng_alaskan.png',
  herb_ginseng_american: 'images/herb_ginseng_american.png',
  herb_hummingbird_sage: 'images/herb_hummingbird_sage.png',
  herb_mint: 'images/herb_mint.png',
  herb_oleander: 'images/herb_oleander.png',
  herb_red_sage: 'images/herb_red_sage.png',
  herb_tobacco: 'images/herb_tobacco.png',
  herb_yarrow: 'images/herb_yarrow.png',
  honey: 'images/honey.png',
  horn: 'images/horn.png',
  horseshoe: 'images/horseshoe.png',
  human_skull: 'images/human_skull.png',
  hunting_knife: 'images/hunting_knife.png',
  key_ring: 'images/key_ring.png',
  lantern: 'images/lantern.png',
  leather: 'images/leather.png',
  lemon: 'images/lemon.png',
  map: 'images/map.png',
  matches: 'images/matches.png',
  monster_eye: 'images/monster_eye.png',
  moonshine: 'images/moonshine.png',
  mug: 'images/mug.png',
  mush_bay_bolete: 'images/mush_bay_bolete.png',
  mush_chanterelle: 'images/mush_chanterelle.png',
  mush_fly_agaric: 'images/mush_fly_agaric.png',
  mush_parasol: 'images/mush_parasol.png',
  mush_parasol_twilight: 'images/mush_parasol_twilight.png',
  mush_rams_head: 'images/mush_rams_head.png',
  mysterious_orb: 'images/mysterious_orb.png',
  nails: 'images/nails.png',
  needle_thread: 'images/needle_thread.png',
  oil: 'images/oil.png',
  onion: 'images/onion.png',
  padlock: 'images/padlock.png',
  pelt: 'images/pelt.png',
  pickaxe: 'images/pickaxe.png',
  potato: 'images/potato.png',
  potato_baked: 'images/potato_baked.png',
  pouch: 'images/pouch.png',
  prickly_pear: 'images/prickly_pear.png',
  raven_claw: 'images/raven_claw.png',
  raven_eye: 'images/raven_eye.png',
  reptile_scale: 'images/reptile_scale.png',
  resin: 'images/resin.png',
  rock_salt: 'images/rock_salt.png',
  rope: 'images/rope.png',
  salt: 'images/salt.png',
  saltpeter: 'images/saltpeter.png',
  sandstone: 'images/sandstone.png',
  saw: 'images/saw.png',
  scarlet_stone: 'images/scarlet_stone.png',
  sewing_kit: 'images/sewing_kit.png',
  sharpening_stone: 'images/sharpening_stone.png',
  shovel: 'images/shovel.png',
  silver_ingot: 'images/silver_ingot.png',
  silver_ore: 'images/silver_ore.png',
  snake_venom: 'images/snake_venom.png',
  spore_pouch: 'images/spore_pouch.png',
  sugar: 'images/sugar.png',
  sulfur_ore: 'images/sulfur_ore.png',
  sulfur_powder: 'images/sulfur_powder.png',
  tea: 'images/tea.png',
  tomato: 'images/tomato.png',
  torch: 'images/torch.png',
  tree_bark: 'images/tree_bark.png',
  unknown_statue: 'images/unknown_statue.png',
  vial: 'images/vial.png',
  voodoo_doll: 'images/voodoo_doll.png',
  waterskin: 'images/waterskin.png',
  waterskin_water: 'images/waterskin_water.png',
  wheat_bread: 'images/wheat_bread.png',
  wheat_flour: 'images/wheat_flour.png',
  wolf_claw: 'images/wolf_claw.png',
  wolf_tooth: 'images/wolf_tooth.png',
  wool: 'images/wool.png',
  worm: 'images/worm.png',

  // Рыба (15 видов)
  fish_bluegill: 'images/fish_bluegill.png',
  fish_bullhead_catfish: 'images/fish_bullhead_catfish.png',
  fish_chain_pickerel: 'images/fish_chain_pickerel.png',
  fish_channel_catfish: 'images/fish_channel_catfish.png',
  fish_lake_sturgeon: 'images/fish_lake_sturgeon.png',
  fish_largemouth_bass: 'images/fish_largemouth_bass.png',
  fish_longnose_gar: 'images/fish_longnose_gar.png',
  fish_muskie: 'images/fish_muskie.png',
  fish_northern_pike: 'images/fish_northern_pike.png',
  fish_redfin_pickerel: 'images/fish_redfin_pickerel.png',
  fish_rock_bass: 'images/fish_rock_bass.png',
  fish_salmon: 'images/fish_salmon.png',
  fish_smallmouth_bass: 'images/fish_smallmouth_bass.png',
  fish_steelhead_trout: 'images/fish_steelhead_trout.png',
  fish_yellow_perch: 'images/fish_yellow_perch.png',

  // Одежда и аксессуары
  clothing_hat: 'images/clothing_hat.png',
  clothing_mask: 'images/clothing_mask.png',
  clothing_eyewear: 'images/clothing_eyewear.png',
  clothing_neckwear: 'images/clothing_neckwear.png',
  clothing_shirt: 'images/clothing_shirt.png',
  clothing_vest: 'images/clothing_vest.png',
  clothing_coat: 'images/clothing_coat.png',
  clothing_coatclosed: 'images/clothing_coatclosed.png',
  clothing_poncho: 'images/clothing_poncho.png',
  clothing_cloak: 'images/clothing_cloak.png',
  clothing_pant: 'images/clothing_pant.png',
  clothing_pants: 'images/clothing_pants.png',
  clothing_skirt: 'images/clothing_skirt.png',
  clothing_dress: 'images/clothing_dress.png',
  clothing_boots: 'images/clothing_boots.png',
  clothing_spurs: 'images/clothing_spurs.png',
  clothing_spats: 'images/clothing_spats.png',
  clothing_chap: 'images/clothing_chap.png',
  clothing_gunbelt: 'images/clothing_gunbelt.png',
  clothing_holster: 'images/clothing_holster.png',
  clothing_belt: 'images/clothing_belt.png',
  clothing_suspender: 'images/clothing_suspender.png',
  clothing_glove: 'images/clothing_glove.png',
  clothing_gloves: 'images/clothing_gloves.png',
  clothing_gauntlets: 'images/clothing_gauntlets.png',
  clothing_accessories: 'images/clothing_accessories.png',
  clothing_bracelet: 'images/clothing_bracelet.png',
  clothing_ringlh: 'images/clothing_ringlh.png',
  clothing_ringrh: 'images/clothing_ringrh.png',
  clothing_satchels: 'images/clothing_satchels.png',
  clothing_satchel: 'images/clothing_satchel.png'
};

const DEFAULT_ADMIN_SVG = `<svg class="item-icon-svg" viewBox="0 0 24 24" fill="none" stroke="#e2e8f0" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05"/><path d="M12 22.08V12"/></svg>`;

function getAdminItemIconHtml(item) {
  if (!item) return DEFAULT_ADMIN_SVG;
  const name = (item.name || '').toLowerCase();
  const icon = (item.icon || '').toLowerCase();
  const fallbackSvgEncoded = "data:image/svg+xml;utf8," + encodeURIComponent(DEFAULT_ADMIN_SVG);
  const onErr = `onerror="this.onerror=null; this.src='${fallbackSvgEncoded}';"`;

  // 1. Проверяем локальные растровые PNG, которые реально существуют в папке images/
  if (ADMIN_ITEM_IMAGES[name]) {
    return `<img class="item-icon-img" src="${ADMIN_ITEM_IMAGES[name]}?v=27" ${onErr} alt="${escapeHtml(item.label || name)}" draggable="false" />`;
  }
  if (ADMIN_ITEM_IMAGES[icon]) {
    return `<img class="item-icon-img" src="${ADMIN_ITEM_IMAGES[icon]}?v=27" ${onErr} alt="${escapeHtml(item.label || icon)}" draggable="false" />`;
  }

  // 2. Если у предмета явно задан image (URL / base64)
  if (item.image && typeof item.image === 'string' && item.image.trim() !== '') {
    return `<img class="item-icon-img" src="${item.image}" ${onErr} alt="${escapeHtml(item.label || name)}" draggable="false" />`;
  }

  // 3. Для предметов без картинки — стандартная базовая иконка
  return DEFAULT_ADMIN_SVG;
}

function renderAdminItems() {
  const container = document.getElementById('adminItemsList');
  if (!container) return;

  const filtered = adminItems.filter(item => {
    const matchesCat = (activeItemCategory === 'all') || (item.category === activeItemCategory);
    const labelMatch = (item.label || '').toLowerCase().includes(itemSearchQuery);
    const nameMatch = (item.name || '').toLowerCase().includes(itemSearchQuery);
    return matchesCat && (labelMatch || nameMatch);
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / ADMIN_ITEMS_PER_PAGE));
  if (adminItemsCurrentPage > totalPages) adminItemsCurrentPage = totalPages;
  if (adminItemsCurrentPage < 1) adminItemsCurrentPage = 1;

  // Обновление элементов управления пагинацией
  const pageStr = `Стр. ${adminItemsCurrentPage} из ${totalPages} (${filtered.length} предм.)`;
  const isFirst = adminItemsCurrentPage <= 1;
  const isLast = adminItemsCurrentPage >= totalPages;

  const prevBtn = document.getElementById('adminItemsPrevBtn');
  const nextBtn = document.getElementById('adminItemsNextBtn');
  const pageInfo = document.getElementById('adminItemsPageInfo');
  if (prevBtn) prevBtn.disabled = isFirst;
  if (nextBtn) nextBtn.disabled = isLast;
  if (pageInfo) pageInfo.textContent = pageStr;

  const bPrevBtn = document.getElementById('adminItemsBottomPrevBtn');
  const bNextBtn = document.getElementById('adminItemsBottomNextBtn');
  const bPageInfo = document.getElementById('adminItemsBottomPageInfo');
  if (bPrevBtn) bPrevBtn.disabled = isFirst;
  if (bNextBtn) bNextBtn.disabled = isLast;
  if (bPageInfo) bPageInfo.textContent = pageStr;

  const bottomPagination = document.getElementById('adminItemsBottomPagination');
  if (bottomPagination) {
    bottomPagination.style.display = totalPages > 1 ? 'flex' : 'none';
  }

  if (filtered.length === 0) {
    container.innerHTML = '<div class="empty-msg">Предметы не найдены</div>';
    return;
  }

  const categoryLabels = {
    food: 'Съедобное',
    material: 'Материалы',
    medical: 'Медицина',
    clothing: 'Одежда',
    key: 'Ключи',
    item: 'Предмет',
    survival: 'Выживание',
    melee: 'Холодное',
    gun: 'Огнестрельное',
    furniture: 'Интерьер',
    storage: 'Хранение'
  };

  const startIndex = (adminItemsCurrentPage - 1) * ADMIN_ITEMS_PER_PAGE;
  const pageItems = filtered.slice(startIndex, startIndex + ADMIN_ITEMS_PER_PAGE);

  container.innerHTML = '';
  pageItems.forEach(item => {
    const card = document.createElement('div');
    card.className = 'admin-item-card';
    card.innerHTML = `
      <div class="item-card-inner">
        <div class="item-card-preview">
          ${getAdminItemIconHtml(item)}
        </div>
        <div class="item-card-main">
          <div class="item-card-header">
            <div class="item-card-title-box">
              <span class="item-card-label">${escapeHtml(item.label || item.name)}</span>
              <span class="item-card-name">${escapeHtml(item.name)}</span>
            </div>
            <span class="item-card-cat">${categoryLabels[item.category] || 'Предмет'}</span>
          </div>
          <div class="item-card-controls">
            <input type="number" class="item-count-input" min="1" max="999" value="1" title="Количество" />
            <button class="item-give-btn primary" onclick="giveItemSelf('${item.name}', this)">Себе</button>
            <input type="text" class="item-player-input" placeholder="ID" title="ID игрока" />
            <button class="item-give-btn" onclick="giveItemTarget('${item.name}', this)">Игроку</button>
          </div>
        </div>
      </div>
    `;
    container.appendChild(card);
  });
}

function renderNearbyPlayersChips(players) {
  const container = document.getElementById('adminNearbyPlayersChips');
  if (!container) return;

  container.innerHTML = '';
  if (!players || players.length === 0) {
    container.innerHTML = '<span class="empty-hint">Нет игроков поблизости</span>';
    return;
  }

  players.forEach(p => {
    const chip = document.createElement('button');
    chip.className = 'nearby-player-chip';
    chip.innerHTML = `#${p.id} ${escapeHtml(p.name || '')} (${p.distance || '0m'})`;
    chip.onclick = () => {
      document.querySelectorAll('.item-player-input').forEach(inp => {
        inp.value = p.id;
      });
      showToast("Выбор игрока", `Выбран игрок #${p.id} (${p.name})`, 'info');
    };
    container.appendChild(chip);
  });
}

function giveItemSelf(itemName, btnEl) {
  const card = btnEl.closest('.admin-item-card');
  const countInp = card ? card.querySelector('.item-count-input') : null;
  const count = countInp ? (parseInt(countInp.value, 10) || 1) : 1;

  sendNui('giveAdminItem', {
    name: itemName,
    count: count,
    targetPlayerId: 0
  });

  showToast("Выдача предмета", `Выдано ${itemName} (x${count}) себе`, 'success');
}

function giveItemTarget(itemName, btnEl) {
  const card = btnEl.closest('.admin-item-card');
  const countInp = card ? card.querySelector('.item-count-input') : null;
  const playerInp = card ? card.querySelector('.item-player-input') : null;

  const count = countInp ? (parseInt(countInp.value, 10) || 1) : 1;
  const targetId = playerInp ? parseInt(playerInp.value, 10) : null;

  if (!targetId || isNaN(targetId)) {
    showToast("Ошибка", "Укажите корректный ID игрока", 'warn');
    return;
  }

  sendNui('giveAdminItem', {
    name: itemName,
    count: count,
    targetPlayerId: targetId
  });

  showToast("Выдача предмета", `Отправлен запрос на выдачу ${itemName} (x${count}) игроку #${targetId}`, 'info');
}

// =================================================================
// СООБЩЕНИЯ ОТ REDM КЛИЕНТА
// =================================================================
window.addEventListener('message', (event) => {
  const data = event.data;

  if (data.type === 'OPEN_ADMIN_MENU') {
    app.style.display = 'flex';

    if (savedPosition) {
      adminWindow.style.left = `${savedPosition.x}px`;
      adminWindow.style.top = `${savedPosition.y}px`;
      adminWindow.style.transform = 'none';
    } else {
      adminWindow.style.left = '50%';
      adminWindow.style.top = '50%';
      adminWindow.style.transform = 'translate(-50%, -50%)';
    }

    if (data.state) {
      state = { ...state, ...data.state };
      updateBadges();
    }

    // Автоматически запрашиваем актуальный список игроков
    sendNui('requestPlayersList');
  }

  if (data.type === 'CLOSE_ADMIN_MENU') {
    closeMenu();
  }

  if (data.type === 'UPDATE_STATE') {
    if (data.state) {
      state = { ...state, ...data.state };
      updateBadges();
    }
  }

  if (data.type === 'SET_PLAYERS_LIST') {
    cachedPlayers = data.players || [];
    renderPlayersList(cachedPlayers);

    // Также обновляем список в модальном окне телепорта
    if (modalPlayersList) {
      modalPlayersList.innerHTML = '';
      if (cachedPlayers.length === 0) {
        modalPlayersList.innerHTML = '<div class="empty-msg">Нет игроков онлайн</div>';
      } else {
        cachedPlayers.forEach(p => {
          const row = document.createElement('div');
          row.className = 'modal-player-row';
          row.innerHTML = `
            <div class="modal-player-info">
              <span class="modal-player-id">#${p.id}</span>
              <span class="modal-player-name">${escapeHtml(p.name || 'Неизвестный')}</span>
              <span class="modal-player-redm">(${escapeHtml(p.redmName || '')})</span>
            </div>
            <div class="modal-player-actions">
              <button class="btn-sm" onclick="targetAction(${p.id}, 'tpTo'); closePlayersModal();">ТП к нему</button>
              <button class="btn-sm" onclick="targetAction(${p.id}, 'tpHere'); closePlayersModal();">ТП сюда</button>
            </div>
          `;
          modalPlayersList.appendChild(row);
        });
      }
    }
  }

  if (data.type === 'SET_PLAYER_LOGS') {
    renderPlayerLogs(data.data || {});
  }

  if (data.type === 'UPDATE_PLAYER_TOGGLES') {
    const p = cachedPlayers.find(pl => pl.id === data.targetId);
    if (p) {
      p.toggles = { ...(p.toggles || {}), ...(data.toggles || {}) };
      renderPlayersList(cachedPlayers);
    }
  }

  if (data.type === 'UPDATE_COORDS_DATA') {
    currentCoordsData = { ...currentCoordsData, ...data };

    const elPedX = document.getElementById('pedCoordX');
    const elPedY = document.getElementById('pedCoordY');
    const elPedZ = document.getElementById('pedCoordZ');
    const elPedH = document.getElementById('pedCoordH');
    if (elPedX) elPedX.textContent = (data.pedX !== undefined) ? Number(data.pedX).toFixed(4) : '0.0000';
    if (elPedY) elPedY.textContent = (data.pedY !== undefined) ? Number(data.pedY).toFixed(4) : '0.0000';
    if (elPedZ) elPedZ.textContent = (data.pedZ !== undefined) ? Number(data.pedZ).toFixed(4) : '0.0000';
    if (elPedH) elPedH.textContent = (data.pedH !== undefined) ? Number(data.pedH).toFixed(1) + '°' : '0.0°';

    const elHitX = document.getElementById('hitCoordX');
    const elHitY = document.getElementById('hitCoordY');
    const elHitZ = document.getElementById('hitCoordZ');
    const elHitDist = document.getElementById('hitDistVal');
    if (elHitX) elHitX.textContent = (data.hitX !== undefined) ? Number(data.hitX).toFixed(4) : '0.0000';
    if (elHitY) elHitY.textContent = (data.hitY !== undefined) ? Number(data.hitY).toFixed(4) : '0.0000';
    if (elHitZ) elHitZ.textContent = (data.hitZ !== undefined) ? Number(data.hitZ).toFixed(4) : '0.0000';
    if (elHitDist) elHitDist.textContent = (data.hitDist !== undefined) ? Number(data.hitDist).toFixed(1) + 'м' : '0.0м';

    const elEntityName = document.getElementById('hitEntityName');
    const elCopyModelBtn = document.getElementById('copyEntityModelBtn');
    if (elEntityName) {
      if (data.hitEntity && data.hitEntity !== 0) {
        elEntityName.textContent = `Хэш: ${data.hitModel || '0x0'} (Handle: ${data.hitEntity})`;
        if (elCopyModelBtn) elCopyModelBtn.style.display = 'inline-flex';
      } else {
        elEntityName.textContent = 'Земля / окружение';
        if (elCopyModelBtn) elCopyModelBtn.style.display = 'none';
      }
    }

    // Экранный HUD
    const hud = document.getElementById('adminCoordsHud');
    if (hud) {
      if (state.coordLaser) {
        hud.style.display = 'block';
        const hudPed = document.getElementById('hudPedCoords');
        const hudHit = document.getElementById('hudHitCoords');
        const hudHitDist = document.getElementById('hudHitDist');
        const hudEntityRow = document.getElementById('hudHitEntityRow');
        const hudEntity = document.getElementById('hudHitEntity');

        if (hudPed) {
          hudPed.textContent = `X: ${Number(data.pedX || 0).toFixed(2)} | Y: ${Number(data.pedY || 0).toFixed(2)} | Z: ${Number(data.pedZ || 0).toFixed(2)} | H: ${Number(data.pedH || 0).toFixed(1)}°`;
        }
        if (hudHit) {
          hudHit.innerHTML = `X: ${Number(data.hitX || 0).toFixed(2)} | Y: ${Number(data.hitY || 0).toFixed(2)} | Z: ${Number(data.hitZ || 0).toFixed(2)} (<span id="hudHitDist">${Number(data.hitDist || 0).toFixed(1)}</span>м)`;
        }
        if (hudEntityRow && hudEntity) {
          if (data.hitEntity && data.hitEntity !== 0) {
            hudEntityRow.style.display = 'flex';
            hudEntity.textContent = `0x${Number(data.hitModel || 0).toString(16).toUpperCase()} (${data.hitModel || 0})`;
          } else {
            hudEntityRow.style.display = 'none';
          }
        }
      } else {
        hud.style.display = 'none';
      }
    }
  }

  if (data.type === 'SET_NOCLIP_VISIBLE') {
    state.noclip = !!data.active;
    updateBadges();
    const noclipHud = document.getElementById('adminNoclipHud');
    if (noclipHud) {
      noclipHud.style.display = data.active ? 'block' : 'none';
    }
    if (!data.active) {
      if (document.activeElement && typeof document.activeElement.blur === 'function') {
        document.activeElement.blur();
      }
      window.blur();
    }
  }

  if (data.type === 'UPDATE_NOCLIP_DATA') {
    const noclipHud = document.getElementById('adminNoclipHud');
    if (noclipHud && noclipHud.style.display !== 'none') {
      const badge = document.getElementById('noclipSpeedBadge');
      const speedVal = document.getElementById('noclipSpeedVal');
      const speedStep = document.getElementById('noclipSpeedStep');
      const speedFill = document.getElementById('noclipSpeedFill');
      const coordX = document.getElementById('noclipCoordX');
      const coordY = document.getElementById('noclipCoordY');
      const coordZ = document.getElementById('noclipCoordZ');
      const coordH = document.getElementById('noclipCoordH');

      if (badge) badge.textContent = data.speedLabel || 'Бег';
      if (speedVal) speedVal.textContent = `${data.speedValue || '2.20'} м/с`;
      if (speedStep) speedStep.textContent = `(${data.speedIndex || 4}/${data.maxSpeedIndex || 8})`;
      if (speedFill) {
        const percent = ((data.speedIndex || 4) / (data.maxSpeedIndex || 8)) * 100;
        speedFill.style.width = `${percent}%`;
      }

      if (coordX) coordX.textContent = Number(data.x || 0).toFixed(2);
      if (coordY) coordY.textContent = Number(data.y || 0).toFixed(2);
      if (coordZ) coordZ.textContent = Number(data.z || 0).toFixed(2);
      if (coordH) coordH.textContent = `${Number(data.h || 0).toFixed(1)}°`;
    }
  }

  if (data.type === 'SET_COORD_LASER_VISIBLE') {
    state.coordLaser = !!data.active;
    updateBadges();
    const hud = document.getElementById('adminCoordsHud');
    if (hud) {
      hud.style.display = state.coordLaser ? 'block' : 'none';
    }
  }

  if (data.type === 'COPY_TO_CLIPBOARD') {
    copyToClipboard(data.text, data.label || 'Координаты');
  }

  if (data.type === 'RECEIVE_ADMIN_ITEMS') {
    adminItems = data.items || [];
    renderAdminItems();
    renderItemModalList(adminItems);
  }

  if (data.type === 'RECEIVE_NEARBY_PLAYERS') {
    renderNearbyPlayersChips(data.players || []);
  }
});

// =================================================================
// КОПИРОВАНИЕ В БУФЕР ОБМЕНА
// =================================================================
function copyToClipboard(text, label = "Координаты") {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).catch(() => {
      const ta = document.createElement('textarea');
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
    });
  } else {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }
  showToast("Скопировано", `${label}: ${text}`, "success");
}

function copyPedVector3() {
  const t = `vector3(${Number(currentCoordsData.pedX || 0).toFixed(2)}, ${Number(currentCoordsData.pedY || 0).toFixed(2)}, ${Number(currentCoordsData.pedZ || 0).toFixed(2)})`;
  copyToClipboard(t, "Игрок (vector3)");
}

function copyPedVector4() {
  const t = `vector4(${Number(currentCoordsData.pedX || 0).toFixed(2)}, ${Number(currentCoordsData.pedY || 0).toFixed(2)}, ${Number(currentCoordsData.pedZ || 0).toFixed(2)}, ${Number(currentCoordsData.pedH || 0).toFixed(2)})`;
  copyToClipboard(t, "Игрок (vector4)");
}

function copyPedTable() {
  const t = `{ x = ${Number(currentCoordsData.pedX || 0).toFixed(2)}, y = ${Number(currentCoordsData.pedY || 0).toFixed(2)}, z = ${Number(currentCoordsData.pedZ || 0).toFixed(2)}, h = ${Number(currentCoordsData.pedH || 0).toFixed(2)} }`;
  copyToClipboard(t, "Игрок (Table)");
}

function copyPedRaw() {
  const t = `${Number(currentCoordsData.pedX || 0).toFixed(2)}, ${Number(currentCoordsData.pedY || 0).toFixed(2)}, ${Number(currentCoordsData.pedZ || 0).toFixed(2)}`;
  copyToClipboard(t, "Игрок (X, Y, Z)");
}

function copyHitVector3() {
  const t = `vector3(${Number(currentCoordsData.hitX || 0).toFixed(2)}, ${Number(currentCoordsData.hitY || 0).toFixed(2)}, ${Number(currentCoordsData.hitZ || 0).toFixed(2)})`;
  copyToClipboard(t, "Прицел (vector3)");
}

function copyHitRaw() {
  const t = `${Number(currentCoordsData.hitX || 0).toFixed(2)}, ${Number(currentCoordsData.hitY || 0).toFixed(2)}, ${Number(currentCoordsData.hitZ || 0).toFixed(2)}`;
  copyToClipboard(t, "Прицел (X, Y, Z)");
}

function copyHitModel() {
  if (currentCoordsData.hitModel) {
    const t = `${currentCoordsData.hitModel}`;
    copyToClipboard(t, "Модель объекта");
  }
}

function escapeHtml(text) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return String(text || '').replace(/[&<>"']/g, m => map[m]);
}

// Фокус ввода
document.addEventListener('focusin', (e) => {
  if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
    sendNui('setAdminInputFocus', { focused: true });
  }
});

document.addEventListener('focusout', (e) => {
  if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
    sendNui('setAdminInputFocus', { focused: false });
  }
});
