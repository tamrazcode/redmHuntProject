// =================================================================
// HUNT: Hard RP — Crafting System NUI Script
// =================================================================

const RESOURCE_NAME = (typeof window.GetParentResourceName === 'function')
  ? window.GetParentResourceName()
  : 'thehunt_crafting';

function sendNui(event, data = {}) {
  return fetch(`https://${RESOURCE_NAME}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).then(resp => resp.json()).catch(() => ({}));
}

// =================================================================
// SVG ИКОНКИ КАТЕГОРИЙ И ПРЕДМЕТОВ
// =================================================================

const CATEGORY_ICONS = {
  survival: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2c.5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.3 1-3a2.5 2.5 0 0 0 2.5 3c0-1.4-.5-2-1-3-1.07-2.14-.22-4.05 2-6z"/><path d="M4 21h16"/></svg>`,
  tools: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`,
  items: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/></svg>`,
  medical: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="4"/><path d="M12 8v8"/><path d="M8 12h8"/></svg>`,
  material: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>`,
  default: `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`
};

const ITEM_IMAGES = {
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

const ASSET_VER = '?v=22';

const ITEM_SVGS = {
  bandage: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="14" cy="14" r="10"/><path d="M14 9v10M9 14h10"/><path d="M14 4a10 10 0 0 1 10 10"/></svg>`,
  campfire: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 4c.6 3 2.5 5.8 5 7.8 2.5 2 3.7 4.2 3.7 6.6a8.7 8.7 0 1 1-17.4 0c0-1.4.5-2.8 1.2-3.6a3 3 0 0 0 3 3.6c0-1.7-.6-2.4-1.2-3.6-1.3-2.6-.3-4.9 2.4-7.2z"/><path d="M5 24l18-4M23 24L5 20"/></svg>`,
  bandage_burdock: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="4" width="18" height="20" rx="4"/><path d="M14 9v10M9 14h10"/><path d="M18 6c2 1 3 3 2 5-1 2-4 2-5 4" stroke="#22c55e" stroke-width="2"/></svg>`,
  cloth: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V7z"/><path d="M6 12h16M11 5v18"/></svg>`,
  twigs: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22L22 6M10 18l4-4M18 10l3-1M14 14l1-3"/></svg>`,
  burdock_leaf: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 24c-5-4-9-9-9-14a9 9 0 0 1 18 0c0 5-4 10-9 14z"/><path d="M14 24V10M14 14l-4-3M14 17l4-3"/></svg>`,
  default: `<svg viewBox="0 0 28 28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M24 18.5v-9a2.3 2.3 0 0 0-1.15-2l-8-4.5a2.3 2.3 0 0 0-2.3 0l-8 4.5A2.3 2.3 0 0 0 3.4 9.5v9a2.3 2.3 0 0 0 1.15 2l8 4.5a2.3 2.3 0 0 0 2.3 0l8-4.5A2.3 2.3 0 0 0 24 18.5z"/><polyline points="3.7 8.2 13.7 13.8 23.7 8.2"/><line x1="13.7" y1="25" x2="13.7" y2="13.8"/></svg>`
};

// =================================================================
// СОСТОЯНИЕ ПРИЛОЖЕНИЯ
// =================================================================

let state = {
  isOpen: false,
  station: 'field',
  title: 'Полевое создание',
  categories: {},
  recipes: {},
  inventory: {},
  itemDefs: {},
  selectedRecipeId: null,
  craftAmount: 1,
  expandedCategories: new Set(['survival', 'tools', 'items', 'medical', 'material']),
  queue: [], // [ { id, recipeId, amount, totalDuration, remainingSeconds, status } ]
  queueTimer: null
};

// DOM Elements
const appEl = document.getElementById('craftingApp');
const windowEl = document.getElementById('craftingWindow');
const headerEl = document.getElementById('craftingHeader');
const titleEl = document.getElementById('craftingTitle');
const btnCloseEl = document.getElementById('btnCloseCrafting');

const accordionEl = document.getElementById('categoriesAccordion');
const emptyStateEl = document.getElementById('emptyState');
const recipeDetailsEl = document.getElementById('recipeDetails');

const previewBoxEl = document.getElementById('recipePreviewBox');
const previewIconEl = document.getElementById('recipePreviewIcon');
const recipeNameEl = document.getElementById('recipeName');
const recipeDescEl = document.getElementById('recipeDesc');
const craftTimeEl = document.getElementById('recipeCraftTime');

const ingredientsListEl = document.getElementById('ingredientsList');
const recipeReqRowEl = document.getElementById('recipeRequirementRow');
const recipeReqNameEl = document.getElementById('recipeRequirementName');
const recipeReqStatusEl = document.getElementById('recipeRequirementStatus');

const recipeToolRowEl = document.getElementById('recipeToolRow');
const recipeToolNameEl = document.getElementById('recipeToolName');
const recipeToolStatusEl = document.getElementById('recipeToolStatus');

const btnStepDecEl = document.getElementById('btnStepDec');
const btnStepIncEl = document.getElementById('btnStepInc');
const stepInputEl = document.getElementById('stepInput');
const btnCraftEl = document.getElementById('btnCraft');

const queueSlotsEl = document.getElementById('queueSlotsContainer');

// =================================================================
// СОХРАНЕНИЕ И ЗАГРУЗКА РАЗВЁРНУТЫХ КАТЕГОРИЙ (LOCAL STORAGE)
// =================================================================

function loadExpandedCategories() {
  try {
    const saved = localStorage.getItem('thehunt_crafting_expanded_cats');
    if (saved) {
      const arr = JSON.parse(saved);
      if (Array.isArray(arr)) {
        state.expandedCategories = new Set(arr);
        return;
      }
    }
  } catch (e) { }
  state.expandedCategories = new Set(['survival', 'tools', 'items', 'medical', 'material']);
}

function saveExpandedCategories() {
  try {
    localStorage.setItem('thehunt_crafting_expanded_cats', JSON.stringify([...state.expandedCategories]));
  } catch (e) { }
}

loadExpandedCategories();

// =================================================================
// ВИРТУАЛЬНЫЙ РАСЧЕТ РЕСУРСОВ С УЧЕТОМ ТЕКУЩЕЙ ОЧЕРЕДИ
// =================================================================

function getQueuedReservedCount(itemName) {
  let reserved = 0;
  for (let qItem of state.queue) {
    const rec = state.recipes[qItem.recipeId];
    if (rec && rec.ingredients) {
      for (let ing of rec.ingredients) {
        if (ing.item === itemName) {
          reserved += (ing.count || 1) * (qItem.amount || 1);
        }
      }
    }
  }
  return reserved;
}

function getAvailableItemCount(itemName) {
  const rawHave = state.inventory[itemName] || 0;
  const reserved = getQueuedReservedCount(itemName);
  return Math.max(0, rawHave - reserved);
}

// =================================================================
// ИНИЦИАЛИЗАЦИЯ И ОБРАБОТКА NUI СООБЩЕНИЙ
// =================================================================

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data) return;

  if (data.type === 'OPEN_CRAFTING') {
    openUI(data);
  } else if (data.type === 'CLOSE_CRAFTING') {
    closeUI();
  } else if (data.type === 'UPDATE_INVENTORY') {
    state.inventory = data.inventory || {};
    updateAccordionDots();
    if (state.selectedRecipeId) {
      renderRecipeDetails(state.selectedRecipeId);
    }
  } else if (data.type === 'CRAFT_CHECK_RESULT') {
    handleCraftCheckResult(data);
  }
});

function openUI(data) {
  state.isOpen = true;
  state.station = data.station || 'field';
  state.title = data.title || (state.station === 'workbench' ? 'Верстак' : state.station === 'campfire' ? 'Костёр' : state.station === 'med_table' ? 'Медицинский стол' : state.station === 'furnace' ? 'Плавильная печь' : state.station === 'anvil' ? 'Наковальня' : 'Полевое создание');
  state.allRecipes = data.allRecipes || data.recipes || state.allRecipes || {};
  state.categories = data.categories || {};
  state.recipes = data.recipes || {};
  state.inventory = data.inventory || {};
  state.itemDefs = data.itemDefs || {};

  titleEl.innerText = state.title;

  loadExpandedCategories();
  renderAccordion();
  renderQueue();

  if (state.selectedRecipeId && state.recipes[state.selectedRecipeId]) {
    selectRecipe(state.selectedRecipeId);
  } else {
    const firstRecipeId = Object.keys(state.recipes)[0];
    if (firstRecipeId) {
      selectRecipe(firstRecipeId);
    } else {
      emptyStateEl.style.display = 'flex';
      recipeDetailsEl.style.display = 'none';

      const emptyTitle = emptyStateEl.querySelector('h3');
      const emptyDesc = emptyStateEl.querySelector('p');
      if (emptyTitle) {
        emptyTitle.innerText = 'Нет доступных рецептов';
      }
      if (emptyDesc) {
        emptyDesc.innerText = (state.station === 'med_table')
          ? 'Для медицинского стола пока нет доступных рецептов'
          : (state.station === 'anvil')
          ? 'Для наковальни пока нет доступных рецептов'
          : 'В выбранной категории пока нет доступных рецептов';
      }
    }
  }

  appEl.style.display = 'flex';
}

function closeUI() {
  state.isOpen = false;
  appEl.style.display = 'none';
  sendNui('close');
}

// =================================================================
// РЕНДЕРИНГ АККОРДЕОНА КАТЕГОРИЙ (ЛЕВАЯ ПАНЕЛЬ)
// =================================================================

function renderAccordion() {
  accordionEl.innerHTML = '';

  const catList = Object.values(state.categories).sort((a, b) => (a.order || 99) - (b.order || 99));

  catList.forEach(cat => {
    const catRecipes = Object.values(state.recipes).filter(r => r.category === cat.id);
    const isExpanded = state.expandedCategories.has(cat.id);

    const groupEl = document.createElement('div');
    groupEl.className = 'cat-group';

    // Шапка категории
    const headerEl = document.createElement('div');
    headerEl.className = `cat-header ${isExpanded ? 'is-expanded' : ''}`;
    headerEl.innerHTML = `
      <div class="cat-header-left">
        <span class="cat-title">${cat.label || cat.id}</span>
      </div>
      <div class="cat-header-right">
        <span class="cat-badge">${catRecipes.length}</span>
        <div class="cat-chevron">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="6 9 12 15 18 9"></polyline></svg>
        </div>
      </div>
    `;

    headerEl.addEventListener('click', () => {
      const willExpand = !state.expandedCategories.has(cat.id);
      if (willExpand) {
        state.expandedCategories.add(cat.id);
        headerEl.classList.add('is-expanded');
        listEl.classList.add('is-open');
      } else {
        state.expandedCategories.delete(cat.id);
        headerEl.classList.remove('is-expanded');
        listEl.classList.remove('is-open');
      }
      saveExpandedCategories();
    });

    // Список рецептов внутри категории
    const listEl = document.createElement('div');
    listEl.className = `cat-recipes-list ${isExpanded ? 'is-open' : ''}`;

    if (catRecipes.length === 0) {
      const emptyHint = document.createElement('div');
      emptyHint.className = 'cat-empty-hint';
      emptyHint.innerText = (state.station === 'workbench' || state.station === 'med_table' || state.station === 'furnace' || state.station === 'anvil' || state.station === 'campfire') ? 'Нет доступных рецептов' : 'Требуется верстак';
      listEl.appendChild(emptyHint);
    } else {
      catRecipes.forEach(rec => {
        const isCraftable = isRecipeCraftable(rec, 1);
        const isSelected = (state.selectedRecipeId === rec.id);
        const def = (state.itemDefs && state.itemDefs[rec.resultItem]) || {};
        let rarity = def.rarity || 'white';
        if (rarity === 'yellow') rarity = 'purple';

        const itemNavEl = document.createElement('div');
        itemNavEl.className = `recipe-nav-item rarity-${rarity} ${isSelected ? 'is-selected' : ''}`;
        itemNavEl.dataset.recipeId = rec.id;
        itemNavEl.innerHTML = `
          <div class="nav-item-left">
            <div class="recipe-nav-icon">
              ${getItemIconHtml(rec.resultItem, def)}
            </div>
            <span class="nav-item-label">${rec.label || rec.id}</span>
          </div>
          <div class="craftable-dot ${isCraftable ? 'is-available' : ''}" title="${isCraftable ? 'Ресурсы есть' : 'Не хватает ресурсов'}"></div>
        `;

        itemNavEl.addEventListener('click', () => {
          selectRecipe(rec.id);
        });

        listEl.appendChild(itemNavEl);
      });
    }

    groupEl.appendChild(headerEl);
    groupEl.appendChild(listEl);
    accordionEl.appendChild(groupEl);
  });
}

function updateAccordionDots() {
  const navItems = accordionEl.querySelectorAll('.recipe-nav-item');
  navItems.forEach(itemEl => {
    const recId = itemEl.dataset.recipeId;
    const rec = state.recipes[recId];
    if (rec) {
      const isCraftable = isRecipeCraftable(rec, 1);
      const dot = itemEl.querySelector('.craftable-dot');
      if (dot) {
        dot.classList.toggle('is-available', isCraftable);
      }
    }
  });
}

function isRecipeCraftable(recipe, amount) {
  if (!recipe) return false;
  const count = amount || 1;

  if (recipe.requiredRecipeItem) {
    if (getAvailableItemCount(recipe.requiredRecipeItem) < 1) {
      return false;
    }
  }

  if (recipe.requiredTool) {
    if (getAvailableItemCount(recipe.requiredTool) < 1) {
      return false;
    }
  }

  for (let ing of (recipe.ingredients || [])) {
    const need = (ing.count || 1) * count;
    const available = getAvailableItemCount(ing.item);
    if (available < need) {
      return false;
    }
  }

  return true;
}

// =================================================================
// ВЫБОР И ДЕТАЛИ РЕЦЕПТА (ПРАВАЯ ПАНЕЛЬ)
// =================================================================

function selectRecipe(recipeId) {
  const recipe = state.recipes[recipeId];
  if (!recipe) return;

  state.selectedRecipeId = recipeId;
  state.craftAmount = 1;
  stepInputEl.value = 1;
  updateStepInputWidth();

  // Обновляем активный класс без удаления DOM-дерева, чтобы плавная анимация отрабатывала на лету
  const allNavItems = accordionEl.querySelectorAll('.recipe-nav-item');
  allNavItems.forEach(item => {
    const isThis = (item.dataset.recipeId === recipeId);
    item.classList.toggle('is-selected', isThis);
  });

  renderRecipeDetails(recipeId);
}

function renderRecipeDetails(recipeId) {
  const recipe = state.recipes[recipeId];
  if (!recipe) {
    emptyStateEl.style.display = 'flex';
    recipeDetailsEl.style.display = 'none';
    return;
  }

  emptyStateEl.style.display = 'none';
  recipeDetailsEl.style.display = 'flex';

  const itemDef = state.itemDefs[recipe.resultItem] || {};

  previewIconEl.innerHTML = getItemIconHtml(recipe.resultItem, itemDef);
  recipeNameEl.innerText = itemDef.label || recipe.label || recipe.id;
  recipeDescEl.innerText = itemDef.description || 'Полезный предмет, изготовленный вручную.';

  const totalTime = (recipe.craftTime || 5) * state.craftAmount;
  craftTimeEl.innerText = `${totalTime} сек`;

  ingredientsListEl.innerHTML = '';
  let allIngredientsAvailable = true;

  (recipe.ingredients || []).forEach(ing => {
    const ingDef = state.itemDefs[ing.item] || {};
    const needed = (ing.count || 1) * state.craftAmount;
    const available = getAvailableItemCount(ing.item);
    const hasEnough = (available >= needed);

    if (!hasEnough) allIngredientsAvailable = false;

    const rowEl = document.createElement('div');
    rowEl.className = 'ingredient-row';
    rowEl.innerHTML = `
      <div class="ing-left">
        <div class="ing-icon-wrap">
          ${getItemIconHtml(ing.item, ingDef)}
        </div>
        <span class="ing-name">${ingDef.label || ing.item}</span>
      </div>
      <div class="ing-count-wrap ${hasEnough ? 'has-enough' : 'not-enough'}">
        <span class="ing-have">${available}</span>
        <span class="ing-sep">/</span>
        <span class="ing-need">${needed} шт</span>
      </div>
    `;

    ingredientsListEl.appendChild(rowEl);
  });

  if (recipe.requiredRecipeItem) {
    const hasBook = (getAvailableItemCount(recipe.requiredRecipeItem) >= 1);
    const reqDef = state.itemDefs[recipe.requiredRecipeItem] || {};
    recipeReqRowEl.style.display = 'flex';
    recipeReqNameEl.innerText = reqDef.label || recipe.requiredRecipeItem;
    recipeReqStatusEl.className = `req-status-tag ${hasBook ? 'is-ready' : 'is-missing'}`;
    recipeReqStatusEl.innerText = hasBook ? 'В наличии' : 'Отсутствует';
    if (!hasBook) allIngredientsAvailable = false;
  } else {
    recipeReqRowEl.style.display = 'none';
  }

  if (recipe.requiredTool) {
    const hasTool = (getAvailableItemCount(recipe.requiredTool) >= 1);
    const toolDef = state.itemDefs[recipe.requiredTool] || {};
    recipeToolRowEl.style.display = 'flex';
    recipeToolNameEl.innerText = toolDef.label || recipe.requiredTool;
    recipeToolStatusEl.className = `req-status-tag ${hasTool ? 'is-ready' : 'is-missing'}`;
    recipeToolStatusEl.innerText = hasTool ? 'В наличии' : 'Отсутствует';
    if (!hasTool) allIngredientsAvailable = false;
  } else {
    recipeToolRowEl.style.display = 'none';
  }

  const canCraft = allIngredientsAvailable && state.queue.length < 5;
  if (canCraft) {
    btnCraftEl.classList.remove('is-disabled');
  } else {
    btnCraftEl.classList.add('is-disabled');
  }
}

function getItemIconHtml(itemName, itemDef) {
  const iconKey = (itemName || (itemDef && (itemDef.icon || itemDef.name)) || '').toLowerCase();
  const label = (itemDef && itemDef.label) || iconKey || '';
  const fallbackSvg = ITEM_SVGS[iconKey] || (itemDef && itemDef.icon && ITEM_SVGS[itemDef.icon]) || ITEM_SVGS.default;
  const fallbackSvgEncoded = "data:image/svg+xml;utf8," + encodeURIComponent(fallbackSvg);
  const onErr = `onerror="this.onerror=null; this.src='${fallbackSvgEncoded}';"`;

  if (iconKey && ITEM_IMAGES[iconKey]) {
    return `<img class="item-icon-img" src="${ITEM_IMAGES[iconKey]}${ASSET_VER}" ${onErr} alt="${label}" draggable="false" />`;
  }
  if (itemDef && itemDef.image && typeof itemDef.image === 'string' && itemDef.image.trim() !== '') {
    return `<img class="item-icon-img" src="${itemDef.image}${ASSET_VER}" ${onErr} alt="${label}" draggable="false" />`;
  }
  return fallbackSvg;
}

// =================================================================
// СТЕППЕР КОЛИЧЕСТВА
// =================================================================

function updateStepInputWidth() {
  const len = Math.max(1, String(stepInputEl.value || '1').length);
  stepInputEl.style.width = (len * 1.1) + 'ch';
}

btnStepDecEl.addEventListener('click', () => {
  if (state.craftAmount > 1) {
    state.craftAmount--;
    stepInputEl.value = state.craftAmount;
    updateStepInputWidth();
    if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
  }
});

btnStepIncEl.addEventListener('click', () => {
  if (state.craftAmount < 99) {
    state.craftAmount++;
    stepInputEl.value = state.craftAmount;
    updateStepInputWidth();
    if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
  }
});

stepInputEl.addEventListener('input', () => {
  updateStepInputWidth();
});

stepInputEl.addEventListener('change', () => {
  let val = parseInt(stepInputEl.value, 10);
  if (isNaN(val) || val < 1) val = 1;
  if (val > 99) val = 99;
  state.craftAmount = val;
  stepInputEl.value = val;
  updateStepInputWidth();
  if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
});

stepInputEl.addEventListener('focus', () => {
  sendNui('setInputFocus', { focused: true });
});

stepInputEl.addEventListener('blur', () => {
  sendNui('setInputFocus', { focused: false });
});

// =================================================================
// ЗАПУСК КРАФТА И ОЧЕРЕДЬ
// =================================================================

btnCraftEl.addEventListener('click', () => {
  if (btnCraftEl.classList.contains('is-disabled')) return;
  if (!state.selectedRecipeId) return;
  if (state.queue.length >= 5) return;

  const recipe = state.recipes[state.selectedRecipeId];
  if (!recipe) return;

  const amount = state.craftAmount;
  if (!isRecipeCraftable(recipe, amount)) return;

  const duration = (recipe.craftTime || 5) * amount;

  const queueItem = {
    id: Date.now() + Math.random(),
    recipeId: recipe.id,
    resultItem: recipe.resultItem,
    station: recipe.station || state.station || 'workbench',
    amount: amount,
    totalDuration: duration,
    remainingSeconds: duration,
    status: (state.queue.length === 0) ? 'active' : 'waiting'
  };

  state.queue.push(queueItem);
  renderQueue();

  if (state.queue.length === 1) {
    startQueueEngine();
  }

  updateAccordionDots();
  if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
});

function handleCraftCheckResult(data) {
  // Обработка дополнительных серверных валидаций при необходимости
}

function startQueueEngine() {
  if (state.queueTimer) clearInterval(state.queueTimer);

  sendNui('startCraftingAnim', { station: state.station });

  state.queueTimer = setInterval(() => {
    if (state.queue.length === 0) {
      clearInterval(state.queueTimer);
      state.queueTimer = null;
      sendNui('stopCraftingAnim');
      renderQueue();
      updateAccordionDots();
      if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
      return;
    }

    const current = state.queue[0];
    current.status = 'active';
    current.remainingSeconds -= 0.1;

    if (current.remainingSeconds <= 0) {
      sendNui('finishCraft', {
        recipeId: current.recipeId,
        amount: current.amount,
        station: current.station || 'workbench'
      });

      state.queue.shift();

      if (state.queue.length > 0) {
        state.queue[0].status = 'active';
      } else {
        clearInterval(state.queueTimer);
        state.queueTimer = null;
        sendNui('stopCraftingAnim');
      }

      renderQueue();
      updateAccordionDots();
      if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
    } else {
      // Обновляем прогресс и таймер активного слота на лету без пересоздания DOM
      const activeSlotEl = queueSlotsEl.querySelector('.queue-slot.is-active');
      if (activeSlotEl) {
        const progressPct = Math.max(0, Math.min(100, (1 - (current.remainingSeconds / current.totalDuration)) * 100));
        const progBar = activeSlotEl.querySelector('.queue-progress-bar');
        if (progBar) progBar.style.width = `${progressPct}%`;
        const timerBadge = activeSlotEl.querySelector('.queue-timer-badge');
        if (timerBadge) {
          const timeLeftSec = Math.ceil(current.remainingSeconds);
          timerBadge.innerText = formatTime(timeLeftSec);
        }
      }
    }
  }, 100);
}

function cancelQueueItem(index) {
  if (index < 0 || index >= state.queue.length) return;

  state.queue.splice(index, 1);

  if (state.queue.length === 0) {
    if (state.queueTimer) {
      clearInterval(state.queueTimer);
      state.queueTimer = null;
    }
    sendNui('stopCraftingAnim');
  } else if (index === 0) {
    state.queue[0].status = 'active';
  }

  renderQueue();
  updateAccordionDots();
  if (state.selectedRecipeId) renderRecipeDetails(state.selectedRecipeId);
}

// =================================================================
// РЕНДЕРИНГ ПАНЕЛИ ОЧЕРЕДИ
// =================================================================

function renderQueue() {
  queueSlotsEl.innerHTML = '';

  state.queue.forEach((item, i) => {
    const rec = (state.recipes && state.recipes[item.recipeId]) || (state.allRecipes && state.allRecipes[item.recipeId]) || {};
    const resultItem = item.resultItem || rec.resultItem;
    const def = (state.itemDefs && state.itemDefs[resultItem]) || {};
    const isActive = (i === 0 && item.status === 'active');

    const slotEl = document.createElement('div');
    slotEl.className = `queue-slot ${isActive ? 'is-active' : ''}`;
    slotEl.dataset.slotIndex = i;

    const progressPct = isActive
      ? Math.max(0, Math.min(100, (1 - (item.remainingSeconds / item.totalDuration)) * 100))
      : 0;

    const timeLeftSec = Math.ceil(item.remainingSeconds || item.totalDuration);
    const timeStr = formatTime(timeLeftSec);

    slotEl.innerHTML = `
      <div class="queue-item-icon">
        ${getItemIconHtml(resultItem, def)}
      </div>
      ${isActive ? `<div class="queue-progress-bar" style="width: ${progressPct}%"></div>` : ''}
      <span class="queue-timer-badge">${timeStr}</span>
      <span class="queue-amount-badge">x${item.amount}</span>
      <button class="queue-cancel-btn" title="Отменить создание" data-slot="${i}">✖</button>
    `;

    queueSlotsEl.appendChild(slotEl);
  });
}

// Делегированная обработка клика и mousedown для гарантированной отмены слота очереди
queueSlotsEl.addEventListener('click', (e) => {
  const btn = e.target.closest('.queue-cancel-btn');
  if (btn) {
    e.stopPropagation();
    e.preventDefault();
    const slotIdx = parseInt(btn.dataset.slot, 10);
    if (!isNaN(slotIdx) && slotIdx >= 0) {
      cancelQueueItem(slotIdx);
    }
  }
});

function formatTime(seconds) {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m > 0 ? m + ':' : ''}${s < 10 && m > 0 ? '0' : ''}${s}с`;
}

// =================================================================
// ПЕРЕМЕЩЕНИЕ ОКНА (DRAG WINDOW)
// =================================================================

let isDraggingWindow = false;
let dragStartX = 0;
let dragStartY = 0;
let winStartX = 0;
let winStartY = 0;

headerEl.addEventListener('mousedown', (e) => {
  if (e.target.closest('.btn-close')) return;
  isDraggingWindow = true;
  dragStartX = e.clientX;
  dragStartY = e.clientY;
  const rect = windowEl.getBoundingClientRect();
  winStartX = rect.left;
  winStartY = rect.top;
});

window.addEventListener('mousemove', (e) => {
  if (!isDraggingWindow) return;
  const dx = e.clientX - dragStartX;
  const dy = e.clientY - dragStartY;
  windowEl.style.left = `${Math.max(10, Math.min(window.innerWidth - 890, winStartX + dx))}px`;
  windowEl.style.top = `${Math.max(10, Math.min(window.innerHeight - 610, winStartY + dy))}px`;
  windowEl.style.transform = 'none';
  windowEl.style.position = 'fixed';
});

window.addEventListener('mouseup', () => {
  isDraggingWindow = false;
});

// Закрытие по кнопке и клавишам
btnCloseEl.addEventListener('click', closeUI);

window.addEventListener('keydown', (e) => {
  if (state.isOpen) {
    if (e.key === 'Escape' || e.keyCode === 27) {
      closeUI();
    } else if (e.key === 'j' || e.key === 'J' || e.key === 'о' || e.key === 'О' || e.keyCode === 74) {
      if (document.activeElement !== stepInputEl) {
        closeUI();
      }
    }
  }
});
