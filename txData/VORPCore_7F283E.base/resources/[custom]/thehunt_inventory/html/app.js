// =================================================================
// HUNT: Hard RP — The Corruption | Grid Inventory JS (DayZ Style)
// =================================================================

const CELL_SIZE = 44;
const CELL_GAP = 1;
const DRAG_THRESHOLD_PX = 5;

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

  // Одежда и аксессуары (28 элементов)
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
  clothing_satchel: 'images/clothing_satchel.png',
  backpack: 'images/clothing_satchels.png'
};

// A few detailed assets also have a high-quality pre-rotated source. Using
// it for an item that is already horizontal avoids an extra rasterisation
// pass from CSS transform: rotate(90deg).
const ITEM_IMAGES_HORIZONTAL = {
  bandage_burdock: 'images/bandage_burdock_h.png',
  burdock_leaf: 'images/burdock_leaf_h.png',
  cloth: 'images/cloth_h.png',
  notebook: 'images/notebook_h.png',
  torn_page: 'images/torn_page_h.png',
  twigs: 'images/twigs_h.png',
  wood_log: 'images/wood_log_h.png',
  wood_plank: 'images/wood_plank_h.png',

  // Новые предметы с горизонтальной ориентацией (62)
  alcohol: 'images/alcohol_h.png',
  animal_bone: 'images/animal_bone_h.png',
  axe: 'images/axe_h.png',
  bag: 'images/bag_h.png',
  cactus_juice: 'images/cactus_juice_h.png',
  carrot: 'images/carrot_h.png',
  celery: 'images/celery_h.png',
  coffee: 'images/coffee_h.png',
  corn: 'images/corn_h.png',
  corn_boiled: 'images/corn_boiled_h.png',
  corn_flour: 'images/corn_flour_h.png',
  cornbread: 'images/cornbread_h.png',
  cursed_bone: 'images/cursed_bone_h.png',
  egg_fried: 'images/egg_fried_h.png',
  first_aid_kit: 'images/first_aid_kit_h.png',
  fishing_rod: 'images/fishing_rod_h.png',
  flask_glass: 'images/flask_glass_h.png',
  gold_ingot: 'images/gold_ingot_h.png',
  gold_pocket_watch: 'images/gold_pocket_watch_h.png',
  gunpowder: 'images/gunpowder_h.png',
  hammer: 'images/hammer_h.png',
  herb_desert_sage: 'images/herb_desert_sage_h.png',
  herb_ginseng_alaskan: 'images/herb_ginseng_alaskan_h.png',
  herb_ginseng_american: 'images/herb_ginseng_american_h.png',
  herb_hummingbird_sage: 'images/herb_hummingbird_sage_h.png',
  herb_oleander: 'images/herb_oleander_h.png',
  herb_red_sage: 'images/herb_red_sage_h.png',
  herb_yarrow: 'images/herb_yarrow_h.png',
  honey: 'images/honey_h.png',
  horn: 'images/horn_h.png',
  hunting_knife: 'images/hunting_knife_h.png',
  iron_ingot: 'images/iron_ingot_h.png',
  key_ring: 'images/key_ring_h.png',
  lantern: 'images/lantern_h.png',
  moonshine: 'images/moonshine_h.png',
  mush_bay_bolete: 'images/mush_bay_bolete_h.png',
  mush_chanterelle: 'images/mush_chanterelle_h.png',
  mush_fly_agaric: 'images/mush_fly_agaric_h.png',
  mush_parasol: 'images/mush_parasol_h.png',
  mush_parasol_twilight: 'images/mush_parasol_twilight_h.png',
  mush_rams_head: 'images/mush_rams_head_h.png',
  mysterious_orb: 'images/mysterious_orb_h.png',
  oil: 'images/oil_h.png',
  pelt: 'images/pelt_h.png',
  pickaxe: 'images/pickaxe_h.png',
  rope: 'images/rope_h.png',
  salt: 'images/salt_h.png',
  saltpeter: 'images/saltpeter_h.png',
  saw: 'images/saw_h.png',
  sharpening_stone: 'images/sharpening_stone_h.png',
  shovel: 'images/shovel_h.png',
  silver_ingot: 'images/silver_ingot_h.png',
  snake_venom: 'images/snake_venom_h.png',
  spore_pouch: 'images/spore_pouch_h.png',
  sulfur_powder: 'images/sulfur_powder_h.png',
  tea: 'images/tea_h.png',
  torch: 'images/torch_h.png',
  tree_bark: 'images/tree_bark_h.png',
  unknown_statue: 'images/unknown_statue_h.png',
  voodoo_doll: 'images/voodoo_doll_h.png',
  wheat_bread: 'images/wheat_bread_h.png',
  wheat_flour: 'images/wheat_flour_h.png',
  wool: 'images/wool_h.png',

  // Рыба (горизонтальная ориентация)
  fish_bluegill: 'images/fish_bluegill_h.png',
  fish_bullhead_catfish: 'images/fish_bullhead_catfish_h.png',
  fish_chain_pickerel: 'images/fish_chain_pickerel_h.png',
  fish_channel_catfish: 'images/fish_channel_catfish_h.png',
  fish_lake_sturgeon: 'images/fish_lake_sturgeon_h.png',
  fish_largemouth_bass: 'images/fish_largemouth_bass_h.png',
  fish_longnose_gar: 'images/fish_longnose_gar_h.png',
  fish_muskie: 'images/fish_muskie_h.png',
  fish_northern_pike: 'images/fish_northern_pike_h.png',
  fish_redfin_pickerel: 'images/fish_redfin_pickerel_h.png',
  fish_rock_bass: 'images/fish_rock_bass_h.png',
  fish_salmon: 'images/fish_salmon_h.png',
  fish_smallmouth_bass: 'images/fish_smallmouth_bass_h.png',
  fish_steelhead_trout: 'images/fish_steelhead_trout_h.png',
  fish_yellow_perch: 'images/fish_yellow_perch_h.png',
};

const SVG_ICONS = {};

const DEFAULT_FALLBACK_SVG = `<svg class="item-icon-svg" viewBox="0 0 24 24" fill="none" stroke="#e2e8f0" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05"/><path d="M12 22.08V12"/></svg>`;
const CLOTHING_ICON_SVG = `<svg class="item-icon-svg" viewBox="0 0 28 28" fill="none" stroke="#e2e8f0" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l5 3 5-3 5 5-3 4-2-1v10H9V13l-2 1-3-4 5-5z"/><path d="M11 8h6M11 19h6" stroke="#94a3b8" stroke-width="1.2"/></svg>`;
const ASSET_VER = '?v=27';

function escapeHtml(value) {
  if (value == null) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function getItemIconHtml(item) {
  if (!item) return DEFAULT_FALLBACK_SVG;
  const name = item.name || item.icon;
  const lowerName = String(name || '').toLowerCase();
  const lowerIcon = String(item.icon || '').toLowerCase();

  const clothingSlot = item.clothingSlot || (item.metadata && item.metadata.clothingSlot);
  let lookupName = lowerName;
  if ((!lookupName || !ITEM_IMAGES[lookupName]) && clothingSlot) {
    const slotKey = `clothing_${String(clothingSlot).toLowerCase()}`;
    if (ITEM_IMAGES[slotKey]) lookupName = slotKey;
  }

  const isRotated = item.isRotated === true || item.isRotated === 1 || Number(item.isRotated) === 1;
  const horizontalAsset = isRotated && !item.image && lookupName && ITEM_IMAGES[lookupName] && ITEM_IMAGES_HORIZONTAL[lookupName];
  const imageClass = horizontalAsset ? 'item-icon-img item-icon-native-rotated' : 'item-icon-img';
  const fallbackSvgEncoded = "data:image/svg+xml;utf8," + encodeURIComponent(DEFAULT_FALLBACK_SVG);
  const onErr = `onerror="this.onerror=null; this.src='${fallbackSvgEncoded}';"`;

  // 1. Реальные PNG изображения предметов
  if (lookupName && ITEM_IMAGES[lookupName]) {
    return `<img class="${imageClass}" src="${horizontalAsset || ITEM_IMAGES[lookupName]}${ASSET_VER}" ${onErr} alt="${escapeHtml(item.label || lookupName)}" draggable="false" />`;
  }
  if (lowerIcon && ITEM_IMAGES[lowerIcon]) {
    return `<img class="${imageClass}" src="${ITEM_IMAGES[lowerIcon]}${ASSET_VER}" ${onErr} alt="${escapeHtml(item.label || lowerIcon)}" draggable="false" />`;
  }
  if (item.image && typeof item.image === 'string' && item.image.trim() !== '') {
    return `<img class="${imageClass}" src="${item.image}${ASSET_VER}" ${onErr} alt="${escapeHtml(item.label || name)}" draggable="false" />`;
  }

  // 2. Векторные SVG контейнеров/сумок/фляг
  if (lookupName && SVG_ICONS[lookupName]) {
    return SVG_ICONS[lookupName];
  }
  if (lowerIcon && SVG_ICONS[lowerIcon]) {
    return SVG_ICONS[lowerIcon];
  }

  // 3. Заглушка одежды
  if (item.clothing) return CLOTHING_ICON_SVG;

  // 4. Для предметов без картинки — базовая иконка-заглушка
  return DEFAULT_FALLBACK_SVG;
}

// Keep the UI geometry stable even when a database driver serializes the
// TINYINT rotation flag as "0"/"1" or as a textual boolean.  Using the raw
// value in a truthy check would make "0" look rotated and swap every item's
// width/height while its saved coordinates stayed unchanged.
function normalizeRotatedFlag(value) {
  if (value === true || value === 1 || value === '1') return true;
  if (typeof value === 'string') return value.trim().toLowerCase() === 'true' || value.trim().toLowerCase() === 'yes';
  return false;
}

function normalizeInventoryItems(items) {
  if (!Array.isArray(items)) return [];
  return items.map((raw) => {
    const item = { ...raw };
    item.isRotated = normalizeRotatedFlag(raw && raw.isRotated);
    if (raw && raw.x !== undefined && Number.isFinite(Number(raw.x))) item.x = Number(raw.x);
    if (raw && raw.y !== undefined && Number.isFinite(Number(raw.y))) item.y = Number(raw.y);
    if (raw && raw.width !== undefined && Number.isFinite(Number(raw.width))) item.width = Number(raw.width);
    if (raw && raw.height !== undefined && Number.isFinite(Number(raw.height))) item.height = Number(raw.height);
    if (raw && raw.weight !== undefined && Number.isFinite(Number(raw.weight))) item.weight = Number(raw.weight);
    if (raw && raw.count !== undefined && Number.isFinite(Number(raw.count))) item.count = Number(raw.count);
    return item;
  });
}

function getItemFullness(item) {
  if (!item) return null;

  let meta = item.metadata;
  if (typeof meta === 'string') {
    try { meta = JSON.parse(meta); } catch (_) { meta = {}; }
  }
  meta = (meta && typeof meta === 'object') ? meta : {};

  // Определение максимального количества использований
  let maxUses = 0;
  if (item.maxUses !== undefined && item.maxUses !== null && Number(item.maxUses) > 0) {
    maxUses = Number(item.maxUses);
  } else if (meta.maxUses !== undefined && meta.maxUses !== null && Number(meta.maxUses) > 0) {
    maxUses = Number(meta.maxUses);
  } else if (item.name === 'waterskin_water') {
    maxUses = 2;
  } else if (item.name === 'flask_water') {
    maxUses = 3;
  }

  // Полоска отображается только если у предмета больше одного применения
  if (maxUses <= 1) return null;

  // Определение текущего количества использований
  let curUses = maxUses;
  if (meta.uses !== undefined && meta.uses !== null && !isNaN(Number(meta.uses))) {
    curUses = Number(meta.uses);
  } else if (item.uses !== undefined && item.uses !== null && !isNaN(Number(item.uses))) {
    curUses = Number(item.uses);
  }

  curUses = Math.max(0, Math.min(maxUses, curUses));
  const percent = Math.max(0, Math.min(100, (curUses / maxUses) * 100));

  return {
    curUses,
    maxUses,
    percent
  };
}

function getFullnessBarHtml(item) {
  const fullness = getItemFullness(item);
  if (!fullness) return '';
  return `<div class="item-liquid-bar"><div class="item-liquid-bar-fill" style="width: ${fullness.percent.toFixed(1)}%;"></div></div>`;
}

// =================================================================
// СИСТЕМА ПРОЦЕДУРНОГО ЗВУКА ПО КАТЕГОРИЯМ ПРЕДМЕТОВ (WEB AUDIO)
// =================================================================

const AudioContextClass = window.AudioContext || window.webkitAudioContext;
let audioCtx = null;

function getAudioContext() {
  if (!audioCtx && AudioContextClass) {
    audioCtx = new AudioContextClass();
  }
  if (audioCtx && audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  return audioCtx;
}

function getItemAudioCategory(item) {
  if (!item) return 'default';
  const name = (item.name || '').toLowerCase();
  if (name.includes('wood') || name.includes('log') || name.includes('plank')) return 'material_wood';
  if (name.includes('stone') || name.includes('rock') || name.includes('ore')) return 'material_stone';
  if (name.includes('iron') || name.includes('ingot') || name.includes('metal') || name.includes('key')) return 'metal';
  if (name.includes('glass') || name.includes('bottle')) return 'glass';
  if (name.includes('meat') || name.includes('apple') || name.includes('mango') || name.includes('pear') || item.category === 'food') return 'food';
  return item.category || 'default';
}

function playItemSound(category, type = 'pickup') {
  try {
    const ctx = getAudioContext();
    if (!ctx) return;
    const now = ctx.currentTime;

    if (category === 'material_wood') {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      const freq = (type === 'pickup') ? 160 : 120;
      osc.frequency.setValueAtTime(freq, now);
      osc.frequency.exponentialRampToValueAtTime(40, now + 0.08);
      gain.gain.setValueAtTime(0.045, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.08);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.08);
    } else if (category === 'material_stone') {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sawtooth';
      const freq = (type === 'pickup') ? 220 : 150;
      osc.frequency.setValueAtTime(freq, now);
      osc.frequency.exponentialRampToValueAtTime(30, now + 0.08);
      gain.gain.setValueAtTime(0.018, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.08);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.08);
    } else if (category === 'metal') {
      const osc1 = ctx.createOscillator();
      const osc2 = ctx.createOscillator();
      const gain = ctx.createGain();
      osc1.type = 'sine';
      osc2.type = 'sine';
      const baseFreq = 920;
      const shift = (type === 'pickup') ? 1.2 : 0.9;
      osc1.frequency.setValueAtTime(baseFreq * shift, now);
      osc2.frequency.setValueAtTime((baseFreq * 1.5) * shift, now);
      gain.gain.setValueAtTime(0.015, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.09);
      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(ctx.destination);
      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.09);
      osc2.stop(now + 0.09);
    } else if (category === 'glass') {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      const freq = (type === 'pickup') ? 2100 : 1800;
      osc.frequency.setValueAtTime(freq, now);
      gain.gain.setValueAtTime(0.016, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.1);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.1);
    } else if (category === 'food') {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      const freq = (type === 'pickup') ? 340 : 260;
      osc.frequency.setValueAtTime(freq, now);
      osc.frequency.exponentialRampToValueAtTime(140, now + 0.06);
      gain.gain.setValueAtTime(0.018, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.06);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.06);
    } else {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      const freq = (type === 'pickup') ? 520 : 420;
      osc.frequency.setValueAtTime(freq, now);
      gain.gain.setValueAtTime(0.015, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.04);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now);
      osc.stop(now + 0.04);
    }
  } catch (err) {
    // Игнорируем ошибки воспроизведения аудио в фоне
  }
}

let config = {
  MaxWeight: 30.0,
  MaxOverweightMargin: 5.0,
  Grids: {
    main: { label: "Основной", cols: 7, rows: 4 },
    ground: { label: "Рядом", cols: 9, rows: 5 }
  }
};

let playerItems = [];
let groundDrops = [];
let currentCharacterGender = 'Male';
let groundSlotOverrides = {};
let currentGroundRenderedItems = [];

// Drag & Drop State
let dragged = null;
let lastContainerClick = { id: null, time: 0 };
let currentHighlightedCells = [];
let activeHoveredItem = null;
let activeContextItem = null;
let pendingTransferItem = null;
let pendingTransferAmount = 1;
let activeSplitData = null;
let pendingInventoryUpdate = null;
let localMutationSequence = 0;
let lastAppliedInventoryRequestId = 0;
let optimisticGroundSequence = 0;
let hoverFramePending = false;
let pendingHoverX = 0;
let pendingHoverY = 0;

// DOM Elements
const app = document.getElementById('inventoryApp');
const dragGhost = document.getElementById('dragGhost');
const itemContextMenu = document.getElementById('itemContextMenu');
const hoverTooltip = document.getElementById('itemHoverTooltip');
const ttTitle = document.getElementById('ttTitle');
const ttBadge = document.getElementById('ttBadge');
const ttDesc = document.getElementById('ttDesc');
const ttGender = document.getElementById('ttGender');
const ttWeight = document.getElementById('ttWeight');
const ttCount = document.getElementById('ttCount');
const ttInsulation = document.getElementById('ttInsulation');

const amountModal = document.getElementById('amountModal');
const amountInput = document.getElementById('amountInput');
const amountMaxVal = document.getElementById('amountMaxVal');

const splitModal = document.getElementById('splitModal');
const splitAmountInput = document.getElementById('splitAmountInput');
const splitItemName = document.getElementById('splitItemName');
const splitItemTotal = document.getElementById('splitItemTotal');

const playersModal = document.getElementById('playersModal');
const nearbyPlayersContainer = document.getElementById('nearbyPlayersContainer');

const notebookEditor = document.getElementById('notebookEditor');
const notebookBook = document.getElementById('notebookBook');
const notebookPageScroll = document.getElementById('notebookPageScroll');
const notebookContent = document.getElementById('notebookContent');
const notebookTextColor = document.getElementById('notebookTextColor');
const notebookHighlightColor = document.getElementById('notebookHighlightColor');
const notebookImageDialog = document.getElementById('notebookImageDialog');
const notebookImageUrl = document.getElementById('notebookImageUrl');
const notebookSheet = document.querySelector('.notebook-sheet');
const notebookImgControls = document.getElementById('notebookImgControls');
const notebookImgResizer = document.getElementById('notebookImgResizer');

let activeNotebookItem = null;
let isNotebookReadOnly = false;
let isStandaloneNotebook = false;
let notebookIsDirty = false;
let notebookSavedHtml = '';
let notebookSelectionRange = null;
let selectedNotebookImg = null;
let isResizingNotebookImg = false;
let notebookAlignIndex = 0;
const notebookAlignCommands = ['justifyLeft', 'justifyCenter', 'justifyRight'];

// Состояние режима прямой передачи игроку
let isDirectTransferMode = false;
let directTransferModeType = 'transfer'; // 'transfer' | 'medicine'
let directTransferTargetId = null;
let directTransferTargetLabel = '';
let directMedicineKnockedTarget = false;
let selectedTransferBatch = {}; // { [dbId]: { item, count } }
let zombieCorpses = [];

// Safe Resource Name
const RESOURCE_NAME = (typeof window.GetParentResourceName === 'function') ? window.GetParentResourceName() : 'thehunt_inventory';

// NUI Helper
function sendNui(event, data = {}) {
  return fetch(`https://${RESOURCE_NAME}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).then(resp => resp.json()).catch(() => ({}));
}

const NOTEBOOK_ALLOWED_TAGS = new Set([
  'b', 'strong', 'i', 'em', 'u', 's', 'strike', 'del', 'mark', 'small',
  'sub', 'sup', 'p', 'div', 'h2', 'h3', 'blockquote', 'ul', 'ol', 'li',
  'br', 'hr', 'font', 'span', 'img'
]);
const NOTEBOOK_STYLE_PROPERTIES = new Set([
  'color', 'background-color', 'text-align', 'font-size', 'font-weight',
  'font-style', 'text-decoration', 'width', 'max-width', 'height',
  'float', 'margin', 'margin-left', 'margin-right', 'margin-top',
  'margin-bottom', 'display', 'clear', 'vertical-align', 'background'
]);

function sanitizeNotebookStyle(styleValue) {
  if (!styleValue) return '';
  const safeDeclarations = [];
  for (const declaration of String(styleValue).split(';')) {
    const separator = declaration.indexOf(':');
    if (separator < 0) continue;
    const property = declaration.slice(0, separator).trim().toLowerCase();
    let value = declaration.slice(separator + 1).trim();
    if (!NOTEBOOK_STYLE_PROPERTIES.has(property)) continue;
    if (/url\s*\(|expression\s*\(|javascript\s*:|@import|<|>/i.test(value)) continue;

    // Исключаем белые/серые подложки от скопированных сайтов
    if (property === 'background' || property === 'background-color') {
      const cleanVal = value.toLowerCase().replace(/\s+/g, '');
      if (cleanVal === '#fff' || cleanVal === '#ffffff' || cleanVal === 'white'
          || cleanVal === 'rgb(255,255,255)' || cleanVal === 'rgba(255,255,255,1)'
          || cleanVal === '#fafafa' || cleanVal === '#f8f8f8' || cleanVal === '#f5f5f5') {
        continue;
      }
    }

    value = value.replace(/[^#a-zA-Z0-9(),.%\s'"-]/g, '');
    if (value) safeDeclarations.push(`${property}:${value}`);
  }
  return safeDeclarations.join(';');
}

function isAllowedNotebookImageUrl(value) {
  try {
    const parsed = new URL(String(value || '').trim());
    return (parsed.protocol === 'https:' || parsed.protocol === 'http:') && parsed.hostname.length > 0;
  } catch (_) {
    return false;
  }
}

// The server repeats this allowlist before persistence. Keeping the NUI copy
// too prevents an old or externally supplied snapshot from being injected
// into the contenteditable surface.
function sanitizeNotebookHtml(html) {
  if (!html) return '';
  const container = document.createElement('div');
  container.innerHTML = String(html);

  const elements = Array.from(container.querySelectorAll('*')).reverse();
  for (const element of elements) {
    const tagName = element.tagName.toLowerCase();
    if (!NOTEBOOK_ALLOWED_TAGS.has(tagName)) {
      element.replaceWith(...Array.from(element.childNodes));
      continue;
    }

    if (tagName === 'img') {
      const src = (element.getAttribute('src') || element.src || '').trim();
      if (!src || src.length > 4096 || !/^https?:\/\//i.test(src)) {
        element.remove();
        continue;
      }
      const rawStyle = element.getAttribute('style') || '';
      const safeStyle = sanitizeNotebookStyle(rawStyle) || 'max-width:100%;height:auto;background:transparent;';
      element.removeAttribute('class');
      element.setAttribute('src', src);
      element.setAttribute('referrerpolicy', 'no-referrer');
      element.setAttribute('alt', '');
      element.setAttribute('style', safeStyle);
      element.setAttribute('draggable', 'true');
      continue;
    }

    const style = sanitizeNotebookStyle(element.getAttribute('style'));
    const fontColor = element.getAttribute('color');
    Array.from(element.attributes).forEach(attribute => element.removeAttribute(attribute.name));
    if (style) element.setAttribute('style', style);
    if (tagName === 'font' && fontColor && /^(#[0-9a-f]{3,8}|rgba?\([^)]*\)|hsla?\([^)]*\))$/i.test(fontColor.trim())) {
      element.setAttribute('color', fontColor.trim());
    }
  }
  return container.innerHTML;
}

function sanitizeNotebookTitle(value) {
  return String(value || '').replace(/[<>]/g, '').trim().slice(0, 120);
}

function truncateHtmlToPageLimit(html, maxLines = 15, maxChars = 1500) {
  if (!html) return '';
  const container = document.createElement('div');
  container.innerHTML = sanitizeNotebookHtml(html);

  let lineCount = 1;
  let charCount = 0;
  let hitLimit = false;

  const resultContainer = document.createElement('div');

  function traverse(node, targetParent) {
    if (hitLimit) return;

    if (node.nodeType === Node.TEXT_NODE) {
      const text = node.textContent || '';
      if (!text) return;
      let outText = '';
      for (let i = 0; i < text.length; i++) {
        const c = text[i];
        if (c === '\n') {
          if (lineCount >= maxLines) {
            hitLimit = true;
            break;
          }
          lineCount += 1;
        }
        if (charCount >= maxChars) {
          hitLimit = true;
          break;
        }
        charCount += 1;
        outText += c;
      }
      if (outText) {
        targetParent.appendChild(document.createTextNode(outText));
      }
      return;
    }

    if (node.nodeType === Node.ELEMENT_NODE) {
      const tag = node.tagName.toLowerCase();
      const isBlock = ['p', 'div', 'li', 'h2', 'h3', 'blockquote'].includes(tag);
      const isBr = tag === 'br';
      const isImg = tag === 'img';

      if (isImg) {
        if (lineCount >= maxLines) {
          hitLimit = true;
          return;
        }
        lineCount += 1;
        targetParent.appendChild(node.cloneNode(true));
        return;
      }

      if (isBr) {
        if (lineCount >= maxLines) {
          hitLimit = true;
          return;
        }
        lineCount += 1;
        targetParent.appendChild(node.cloneNode(true));
        return;
      }

      if (isBlock) {
        if (lineCount > maxLines) {
          hitLimit = true;
          return;
        }
      }

      const clone = node.cloneNode(false);
      targetParent.appendChild(clone);

      for (const child of Array.from(node.childNodes)) {
        if (hitLimit) break;
        traverse(child, clone);
      }

      if (isBlock) {
        if (lineCount >= maxLines) {
          hitLimit = true;
          return;
        }
        lineCount += 1;
      }
    }
  }

  for (const child of Array.from(container.childNodes)) {
    if (hitLimit) break;
    traverse(child, resultContainer);
  }

  return resultContainer.innerHTML;
}

function isNotebookEditorOpen() {
  return !!notebookEditor && notebookEditor.style.display === 'flex';
}

function markNotebookDirty() {
  if (!isNotebookEditorOpen() || isNotebookReadOnly) return;
  notebookIsDirty = true;
}

function rememberNotebookSelection() {
  if (!notebookContent) return;
  const selection = window.getSelection();
  if (!selection || !selection.rangeCount) return;
  const range = selection.getRangeAt(0);
  if (notebookContent.contains(range.commonAncestorContainer)) {
    notebookSelectionRange = range.cloneRange();
  }
}

function restoreNotebookSelection() {
  if (!notebookContent) return;
  notebookContent.focus();
  const selection = window.getSelection();
  if (!selection) return;
  selection.removeAllRanges();
  if (notebookSelectionRange && notebookContent.contains(notebookSelectionRange.commonAncestorContainer)) {
    selection.addRange(notebookSelectionRange);
    return;
  }
  const range = document.createRange();
  range.selectNodeContents(notebookContent);
  range.collapse(false);
  selection.addRange(range);
}

function executeNotebookCommand(command, value = null) {
  restoreNotebookSelection();
  try {
    document.execCommand(command, false, value);
  } catch (_) {
    // Older CEF builds can reject an unsupported command; the editor remains usable.
  }
  rememberNotebookSelection();
  markNotebookDirty();
}

function openNotebookImageDialog() {
  rememberNotebookSelection();
  if (!notebookImageDialog) return;
  notebookImageDialog.style.display = 'flex';
  if (notebookImageUrl) {
    notebookImageUrl.value = '';
    setTimeout(() => notebookImageUrl.focus(), 0);
  }
}

function closeNotebookImageDialog(restoreSelection = true) {
  if (notebookImageDialog) notebookImageDialog.style.display = 'none';
  if (notebookImageUrl) notebookImageUrl.value = '';
  if (restoreSelection) restoreNotebookSelection();
}

function insertNotebookImage() {
  let imageUrl = String(notebookImageUrl && notebookImageUrl.value || '').trim();
  if (!imageUrl) return;
  if (!/^https?:\/\//i.test(imageUrl)) {
    imageUrl = 'https://' + imageUrl;
  }
  if (!isAllowedNotebookImageUrl(imageUrl) || imageUrl.length > 2048) {
    if (notebookImageUrl) {
      notebookImageUrl.setCustomValidity('Нужна корректная ссылка на изображение.');
      notebookImageUrl.reportValidity();
    }
    return;
  }
  if (notebookImageUrl) notebookImageUrl.setCustomValidity('');

  closeNotebookImageDialog(false);
  notebookContent.focus();
  restoreNotebookSelection();

  const imgTag = `<img src="${imageUrl}" referrerpolicy="no-referrer" style="max-width:100%;width:50%;height:auto;background:transparent;" />`;
  let inserted = false;
  try {
    inserted = document.execCommand('insertHTML', false, imgTag);
  } catch (_) {
    inserted = false;
  }

  if (!inserted) {
    const img = document.createElement('img');
    img.src = imageUrl;
    img.referrerPolicy = 'no-referrer';
    img.setAttribute('referrerpolicy', 'no-referrer');
    img.alt = '';
    img.style.maxWidth = '100%';
    img.style.width = '50%';
    img.style.height = 'auto';
    img.style.background = 'transparent';
    notebookContent.appendChild(img);
  }

  rememberNotebookSelection();
  markNotebookDirty();

  setTimeout(() => {
    const newlyAdded = notebookContent.querySelector(`img[src="${imageUrl}"]`);
    if (newlyAdded) selectNotebookImg(newlyAdded);
  }, 60);
}

function openNotebookEditor(item, isReadOnly = false) {
  if (!item || (item.name !== 'notebook' && item.name !== 'torn_page')) return;
  if (!isReadOnly && item.isGround) return;

  activeNotebookItem = item;
  isNotebookReadOnly = !!isReadOnly;

  const isTornPage = (item.name === 'torn_page' || item.icon === 'torn_page');

  let metadata = item.metadata;
  if (typeof metadata === 'string') {
    try { metadata = JSON.parse(metadata); } catch (_) { metadata = {}; }
  }
  metadata = (metadata && typeof metadata === 'object') ? metadata : {};

  notebookSavedHtml = sanitizeNotebookHtml(metadata.notebook_html || '');
  if (isTornPage) {
    notebookSavedHtml = truncateHtmlToPageLimit(notebookSavedHtml, 15, 1500);
  }
  notebookIsDirty = false;
  notebookSelectionRange = null;

  if (notebookBook) {
    if (isNotebookReadOnly) notebookBook.classList.add('is-readonly');
    else notebookBook.classList.remove('is-readonly');

    if (isTornPage) {
      notebookBook.classList.add('is-torn-page');
      notebookBook.setAttribute('aria-label', item.label || 'Вырванная страница');
    } else {
      notebookBook.classList.remove('is-torn-page');
      notebookBook.setAttribute('aria-label', item.label || 'Блокнот');
    }
  }

  if (notebookContent) {
    notebookContent.innerHTML = notebookSavedHtml;
    notebookContent.contentEditable = isNotebookReadOnly ? 'false' : 'true';
    notebookContent.scrollTop = 0;
    if (isNotebookReadOnly) {
      notebookContent.removeAttribute('data-placeholder');
    } else {
      notebookContent.setAttribute('data-placeholder', 'Начните писать здесь…');
    }
  }
  if (notebookPageScroll) notebookPageScroll.scrollTop = 0;

  closeContextMenu();

  const layout = document.querySelector('.inventory-layout');
  const transferBar = document.getElementById('transferActionBar');
  if (layout) layout.style.display = 'none';
  if (transferBar) transferBar.style.display = 'none';

  if (notebookEditor) notebookEditor.style.display = 'flex';
  sendNui('notebookOpened', { isReadOnly: isNotebookReadOnly, isPlaced: isStandaloneNotebook });

  if (!isNotebookReadOnly && notebookContent) {
    notebookContent.focus();
    const range = document.createRange();
    range.selectNodeContents(notebookContent);
    range.collapse(false);
    const selection = window.getSelection();
    if (selection) {
      selection.removeAllRanges();
      selection.addRange(range);
    }
    rememberNotebookSelection();
  }
}

function closeNotebookEditor() {
  deselectNotebookImg();
  closeNotebookImageDialog(false);
  sendNui('setInputFocusState', { hasFocus: false });
  sendNui('notebookClosed', {});
  if (notebookEditor) notebookEditor.style.display = 'none';

  if (notebookBook) {
    notebookBook.classList.remove('is-torn-page');
    notebookBook.classList.remove('is-readonly');
  }
  if (notebookContent) {
    notebookContent.setAttribute('data-placeholder', 'Начните писать здесь…');
  }

  const layout = document.querySelector('.inventory-layout');
  const transferBar = document.getElementById('transferActionBar');

  if (isStandaloneNotebook) {
    isStandaloneNotebook = false;
    if (app) app.style.display = 'none';
    if (layout) layout.style.display = 'none';
    if (transferBar) transferBar.style.display = 'none';
  } else {
    if (layout) layout.style.display = 'flex';
    if (transferBar && !isDirectTransferMode) transferBar.style.display = 'none';
  }

  notebookSelectionRange = null;
  activeNotebookItem = null;
  notebookIsDirty = false;
  isNotebookReadOnly = false;
}

async function saveNotebook(closeAfter = false) {
  deselectNotebookImg();
  if (isNotebookReadOnly || !activeNotebookItem || !notebookContent || activeNotebookItem.isGround) {
    if (closeAfter) closeNotebookEditor();
    return;
  }

  const isTornPage = activeNotebookItem && (activeNotebookItem.name === 'torn_page' || activeNotebookItem.icon === 'torn_page');
  let html = sanitizeNotebookHtml(notebookContent.innerHTML);
  if (isTornPage) {
    html = truncateHtmlToPageLimit(html, 15, 1500);
    notebookContent.innerHTML = html;
  }
  await sendNui('saveNotebook', { dbId: activeNotebookItem.dbId, title: '', html });

  activeNotebookItem.metadata = { ...(activeNotebookItem.metadata || {}), notebook_html: html };
  notebookSavedHtml = html;
  notebookIsDirty = false;

  if (closeAfter) closeNotebookEditor();
}

function requestCloseNotebook() {
  if (!isNotebookReadOnly && activeNotebookItem && notebookContent) {
    const currentHtml = notebookContent.innerHTML || '';
    if (notebookIsDirty || currentHtml !== notebookSavedHtml) {
      saveNotebook(true);
      return;
    }
  }
  closeNotebookEditor();
}

function cycleNotebookAlign() {
  notebookAlignIndex = (notebookAlignIndex + 1) % notebookAlignCommands.length;
  executeNotebookCommand(notebookAlignCommands[notebookAlignIndex]);
}

function selectNotebookImg(img) {
  if (isNotebookReadOnly || !img) return;
  if (selectedNotebookImg && selectedNotebookImg !== img) {
    selectedNotebookImg.classList.remove('is-selected');
  }
  selectedNotebookImg = img;
  selectedNotebookImg.classList.add('is-selected');
  selectedNotebookImg.setAttribute('draggable', 'true');
  updateNotebookImgControlsPosition();
  if (notebookImgControls) notebookImgControls.style.display = 'block';
}

function deselectNotebookImg() {
  if (selectedNotebookImg) {
    selectedNotebookImg.classList.remove('is-selected');
    selectedNotebookImg = null;
  }
  if (notebookImgControls) notebookImgControls.style.display = 'none';
}

function updateNotebookImgControlsPosition() {
  if (!selectedNotebookImg || !notebookContent || !notebookContent.contains(selectedNotebookImg)) {
    deselectNotebookImg();
    return;
  }
  if (!notebookImgControls) return;

  const scrollEl = notebookPageScroll || document.getElementById('notebookPageScroll');
  const scrollRect = scrollEl ? scrollEl.getBoundingClientRect() : null;
  const imgRect = selectedNotebookImg.getBoundingClientRect();

  // Скрываем тулбар, если картинка полностью уехала за пределы видимой области скролла
  if (scrollRect && (imgRect.bottom < scrollRect.top + 8 || imgRect.top > scrollRect.bottom - 8)) {
    notebookImgControls.style.display = 'none';
    return;
  }
  notebookImgControls.style.display = 'block';

  const controlsBar = notebookImgControls.querySelector('.notebook-img-controls-bar');
  const resizer = notebookImgResizer;

  if (controlsBar) {
    const barWidth = controlsBar.offsetWidth || 285;
    const barHeight = controlsBar.offsetHeight || 36;
    const bookEl = notebookBook || document.getElementById('notebookBook');
    const bookRect = bookEl ? bookEl.getBoundingClientRect() : { left: 10, right: window.innerWidth - 10, top: 10, bottom: window.innerHeight - 10 };

    // Размещаем панель над изображением; если места сверху мало — опускаем под картинку
    let top = imgRect.top - barHeight - 8;
    if (top < bookRect.top + 10 || (scrollRect && top < scrollRect.top - 20)) {
      top = imgRect.bottom + 8;
    }

    // Ограничиваем панель по горизонтали строго в пределах видимого окна книги, чтобы ни одна кнопка не обрезалась
    const minLeft = Math.max(10, bookRect.left + 8);
    const maxLeft = Math.max(minLeft, Math.min(window.innerWidth - barWidth - 10, bookRect.right - barWidth - 8));
    const left = Math.max(minLeft, Math.min(maxLeft, imgRect.left));

    controlsBar.style.top = `${top}px`;
    controlsBar.style.left = `${left}px`;
  }

  if (resizer) {
    // Угловой маркер изменения размера должен отображаться ТОЛЬКО когда правый нижний угол
    // изображения находится в видимой области страницы блокнота, и никогда не вылезать за пределы книги
    const isBottomVisible = scrollRect ? (imgRect.bottom >= scrollRect.top + 20 && imgRect.bottom <= scrollRect.bottom + 4) : true;
    const isRightVisible = scrollRect ? (imgRect.right >= scrollRect.left + 20 && imgRect.right <= scrollRect.right + 20) : true;

    if (!isBottomVisible || !isRightVisible) {
      resizer.style.display = 'none';
    } else {
      resizer.style.display = 'block';
      const sheet = notebookSheet || document.querySelector('.notebook-sheet');
      const maxR = sheet ? (sheet.getBoundingClientRect().right - 8) : (window.innerWidth - 10);
      const maxB = sheet ? (sheet.getBoundingClientRect().bottom - 8) : (window.innerHeight - 10);

      const rTop = Math.min(maxB, imgRect.bottom - 8);
      const rLeft = Math.min(maxR, imgRect.right - 8);

      resizer.style.top = `${rTop}px`;
      resizer.style.left = `${rLeft}px`;
    }
  }
}

function initNotebookImageControls() {
  if (notebookImgResizer) {
    let startX = 0;
    let startWidth = 0;

    notebookImgResizer.addEventListener('mousedown', (e) => {
      if (!selectedNotebookImg) return;
      e.preventDefault();
      e.stopPropagation();
      isResizingNotebookImg = true;
      startX = e.clientX;
      startWidth = selectedNotebookImg.offsetWidth;

      const onMouseMove = (moveEvent) => {
        if (!isResizingNotebookImg || !selectedNotebookImg) return;
        const deltaX = moveEvent.clientX - startX;
        const scrollEl = notebookPageScroll || document.getElementById('notebookPageScroll');
        const maxW = (scrollEl ? scrollEl.clientWidth : 500) - 16;
        const newWidth = Math.max(50, Math.min(maxW, startWidth + deltaX));
        selectedNotebookImg.style.width = `${newWidth}px`;
        updateNotebookImgControlsPosition();
      };

      const onMouseUp = () => {
        isResizingNotebookImg = false;
        window.removeEventListener('mousemove', onMouseMove);
        window.removeEventListener('mouseup', onMouseUp);
        markNotebookDirty();
        updateNotebookImgControlsPosition();
      };

      window.addEventListener('mousemove', onMouseMove);
      window.addEventListener('mouseup', onMouseUp);
    });
  }

  document.getElementById('btnImgAlignLeft')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;

    if (selectedNotebookImg.nextElementSibling && selectedNotebookImg.nextElementSibling.tagName === 'BR') {
      selectedNotebookImg.nextElementSibling.remove();
    }

    const parent = selectedNotebookImg.parentElement;
    if (parent && parent !== notebookContent && parent.textContent.trim() === '') {
      parent.replaceWith(selectedNotebookImg);
    }

    const currentW = selectedNotebookImg.style.width;
    if (!currentW || currentW === '100%' || selectedNotebookImg.offsetWidth >= (notebookContent.clientWidth - 40)) {
      selectedNotebookImg.style.width = '45%';
    }

    selectedNotebookImg.style.float = 'left';
    selectedNotebookImg.style.display = 'inline-block';
    selectedNotebookImg.style.margin = '6px 16px 8px 0';
    selectedNotebookImg.style.clear = 'none';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgAlignCenter')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;
    selectedNotebookImg.style.float = 'none';
    selectedNotebookImg.style.display = 'block';
    selectedNotebookImg.style.margin = '10px auto';
    selectedNotebookImg.style.clear = 'both';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgAlignRight')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;

    if (selectedNotebookImg.nextElementSibling && selectedNotebookImg.nextElementSibling.tagName === 'BR') {
      selectedNotebookImg.nextElementSibling.remove();
    }

    const parent = selectedNotebookImg.parentElement;
    if (parent && parent !== notebookContent && parent.textContent.trim() === '') {
      parent.replaceWith(selectedNotebookImg);
    }

    const currentW = selectedNotebookImg.style.width;
    if (!currentW || currentW === '100%' || selectedNotebookImg.offsetWidth >= (notebookContent.clientWidth - 40)) {
      selectedNotebookImg.style.width = '45%';
    }

    selectedNotebookImg.style.float = 'right';
    selectedNotebookImg.style.display = 'inline-block';
    selectedNotebookImg.style.margin = '6px 0 8px 16px';
    selectedNotebookImg.style.clear = 'none';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgSize25')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;
    selectedNotebookImg.style.width = '25%';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgSize50')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;
    selectedNotebookImg.style.width = '50%';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgSize75')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;
    selectedNotebookImg.style.width = '75%';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgSize100')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;
    selectedNotebookImg.style.width = '100%';
    selectedNotebookImg.style.float = 'none';
    selectedNotebookImg.style.display = 'block';
    selectedNotebookImg.style.margin = '10px auto';
    updateNotebookImgControlsPosition();
    markNotebookDirty();
  });

  document.getElementById('btnImgDelete')?.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!selectedNotebookImg) return;
    const img = selectedNotebookImg;
    deselectNotebookImg();
    img.remove();
    markNotebookDirty();
  });

  if (notebookPageScroll) {
    notebookPageScroll.addEventListener('scroll', () => {
      if (selectedNotebookImg) updateNotebookImgControlsPosition();
    });
  }

  // Пользовательское перетаскивание картинки мышкой без зависимости от CEF OSR Drag&Drop
  let isDraggingNotebookImg = false;
  let dragTargetNotebookImg = null;
  let dragGhostEl = null;
  let dragStartMouseX = 0;
  let dragStartMouseY = 0;

  if (notebookContent) {
    notebookContent.addEventListener('mousedown', (e) => {
      if (isNotebookReadOnly || e.button !== 0) return;
      const img = e.target.closest('img');
      if (!img) return;

      dragTargetNotebookImg = img;
      dragStartMouseX = e.clientX;
      dragStartMouseY = e.clientY;
      isDraggingNotebookImg = false;
    });

    window.addEventListener('mousemove', (e) => {
      if (!dragTargetNotebookImg || isResizingNotebookImg) return;

      const dist = Math.hypot(e.clientX - dragStartMouseX, e.clientY - dragStartMouseY);
      if (dist > 5 && !isDraggingNotebookImg) {
        isDraggingNotebookImg = true;
        if (notebookImgControls) notebookImgControls.style.display = 'none';

        if (!dragGhostEl) {
          dragGhostEl = document.createElement('img');
          dragGhostEl.src = dragTargetNotebookImg.src;
          dragGhostEl.className = 'notebook-img-drag-ghost';
          const w = Math.min(180, dragTargetNotebookImg.offsetWidth || 140);
          dragGhostEl.style.width = `${w}px`;
          dragGhostEl.style.height = 'auto';
          const container = notebookEditor || document.body;
          container.appendChild(dragGhostEl);
          dragTargetNotebookImg.style.opacity = '0.35';
        }
      }

      if (isDraggingNotebookImg && dragGhostEl) {
        const gw = dragGhostEl.offsetWidth || 120;
        const gh = dragGhostEl.offsetHeight || 120;
        dragGhostEl.style.left = `${e.clientX - (gw / 2)}px`;
        dragGhostEl.style.top = `${e.clientY - (gh / 2)}px`;

        const range = document.caretRangeFromPoint(e.clientX, e.clientY);
        if (range && notebookContent.contains(range.commonAncestorContainer)) {
          const sel = window.getSelection();
          if (sel) {
            sel.removeAllRanges();
            sel.addRange(range);
          }
        }
      }
    });

    window.addEventListener('mouseup', (e) => {
      if (dragGhostEl) {
        dragGhostEl.remove();
        dragGhostEl = null;
      }

      if (dragTargetNotebookImg) {
        dragTargetNotebookImg.style.opacity = '';
      }

      if (isDraggingNotebookImg && dragTargetNotebookImg) {
        const targetImg = dragTargetNotebookImg;
        const dropRange = document.caretRangeFromPoint(e.clientX, e.clientY);

        if (dropRange && notebookContent.contains(dropRange.commonAncestorContainer)) {
          if (!targetImg.contains(dropRange.commonAncestorContainer)) {
            dropRange.insertNode(targetImg);
            if (targetImg.nextElementSibling && targetImg.nextElementSibling.tagName === 'BR' && targetImg.style.float && targetImg.style.float !== 'none') {
              targetImg.nextElementSibling.remove();
            }
          }
        }

        setTimeout(() => {
          selectNotebookImg(targetImg);
          markNotebookDirty();
        }, 30);
      }

      isDraggingNotebookImg = false;
      dragTargetNotebookImg = null;
    });

    notebookContent.addEventListener('click', (e) => {
      if (isNotebookReadOnly) return;
      const img = e.target.closest('img');
      if (img) {
        selectNotebookImg(img);
      } else {
        deselectNotebookImg();
      }
    });

    notebookContent.addEventListener('dragstart', (e) => {
      e.preventDefault();
      return false;
    });

    notebookContent.addEventListener('keydown', (e) => {
      if (selectedNotebookImg && (e.key === 'Delete' || e.key === 'Backspace')) {
        const img = selectedNotebookImg;
        deselectNotebookImg();
        img.remove();
        markNotebookDirty();
        e.preventDefault();
      }
    });
  }

  window.addEventListener('resize', () => {
    if (selectedNotebookImg) updateNotebookImgControlsPosition();
  });
}

function initNotebookEditor() {
  if (!notebookContent) return;
  initNotebookImageControls();
  function getEffectiveLimits() {
    const isPage = activeNotebookItem && (activeNotebookItem.name === 'torn_page' || activeNotebookItem.icon === 'torn_page');
    return {
      maxLines: isPage ? 15 : 35,
      maxChars: isPage ? 1500 : 3500
    };
  }

  function getMeaningfulLineCount() {
    const raw = (notebookContent.innerText || '').replace(/\r\n/g, '\n');
    const lines = raw.split('\n');
    let count = 0;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim().length > 0 || (i > 0 && lines[i - 1].trim().length > 0)) {
        count++;
      }
    }
    return count;
  }

  notebookContent.addEventListener('keydown', (e) => {
    if (isNotebookReadOnly) return;
    const limits = getEffectiveLimits();
    if (e.key === 'Enter') {
      const selection = window.getSelection();
      if (selection && selection.toString().length > 0) return;

      const lines = getMeaningfulLineCount();
      const textLen = (notebookContent.innerText || '').length;
      if (lines >= limits.maxLines || textLen >= limits.maxChars) {
        e.preventDefault();
        return;
      }
    } else if (e.key.length === 1 && !e.ctrlKey && !e.altKey && !e.metaKey) {
      const textLen = (notebookContent.innerText || '').length;
      if (textLen >= limits.maxChars) {
        e.preventDefault();
        return;
      }
    }
  });

  notebookContent.addEventListener('paste', (e) => {
    if (isNotebookReadOnly) return;
    e.preventDefault();

    // Получаем исключительно чистый текст (text/plain) без HTML-тегов, стилей и рамок сайта
    const paste = (e.clipboardData || window.clipboardData)?.getData('text/plain')
      || (e.clipboardData || window.clipboardData)?.getData('text')
      || '';

    if (!paste) return;

    const limits = getEffectiveLimits();
    const currentLines = getMeaningfulLineCount();
    const pasteTextNormalized = paste.replace(/\r\n/g, '\n');
    const pasteLines = pasteTextNormalized.split('\n');
    const nonEmptyPasteLines = pasteLines.filter(l => l.trim().length > 0);

    let textToInsert = pasteTextNormalized;

    // Проверяем лимит строк
    if (currentLines + nonEmptyPasteLines.length > limits.maxLines) {
      const allowedCount = Math.max(1, limits.maxLines - currentLines);
      textToInsert = pasteLines.slice(0, allowedCount).join('\n');
    }

    // Проверяем лимит символов
    const currentTextLen = (notebookContent.innerText || '').length;
    const remainingChars = Math.max(0, limits.maxChars - currentTextLen);
    if (textToInsert.length > remainingChars) {
      textToInsert = textToInsert.slice(0, remainingChars);
    }

    if (!textToInsert) return;

    // Вставляем как обычный рукописный текст блокнота (поддерживает Undo/Redo)
    if (document.queryCommandSupported && document.queryCommandSupported('insertText')) {
      document.execCommand('insertText', false, textToInsert);
    } else {
      const selection = window.getSelection();
      if (!selection || !selection.rangeCount) return;
      selection.deleteFromDocument();
      const textNode = document.createTextNode(textToInsert);
      const range = selection.getRangeAt(0);
      range.insertNode(textNode);
      range.setStartAfter(textNode);
      range.setEndAfter(textNode);
      selection.removeAllRanges();
      selection.addRange(range);
    }

    markNotebookDirty();
  });

  notebookContent.addEventListener('input', () => {
    markNotebookDirty();
    const isPage = activeNotebookItem && (activeNotebookItem.name === 'torn_page' || activeNotebookItem.icon === 'torn_page');
    if (isPage) {
      const lines = getMeaningfulLineCount();
      const textLen = (notebookContent.innerText || '').length;
      if (lines > 15 || textLen > 1500) {
        notebookContent.innerHTML = truncateHtmlToPageLimit(notebookContent.innerHTML, 15, 1500);
      }
    }
  });
  notebookContent.addEventListener('keyup', rememberNotebookSelection);
  notebookContent.addEventListener('mouseup', rememberNotebookSelection);
  notebookContent.addEventListener('blur', rememberNotebookSelection);

  document.querySelectorAll('.notebook-ink-btn[data-command]').forEach(button => {
    button.addEventListener('mousedown', event => {
      event.preventDefault();
      rememberNotebookSelection();
    });
    button.addEventListener('click', () => executeNotebookCommand(button.dataset.command));
  });

  document.getElementById('btnNotebookAlign')?.addEventListener('mousedown', event => {
    event.preventDefault();
    rememberNotebookSelection();
  });
  document.getElementById('btnNotebookAlign')?.addEventListener('click', cycleNotebookAlign);

  if (notebookTextColor) {
    notebookTextColor.addEventListener('mousedown', rememberNotebookSelection);
    notebookTextColor.addEventListener('input', () => {
      executeNotebookCommand('foreColor', notebookTextColor.value);
      const glyph = document.querySelector('.notebook-glyph-a');
      if (glyph) glyph.style.borderBottomColor = notebookTextColor.value;
    });
  }

  if (notebookHighlightColor) {
    notebookHighlightColor.addEventListener('mousedown', rememberNotebookSelection);
    notebookHighlightColor.addEventListener('input', () => {
      executeNotebookCommand('hiliteColor', notebookHighlightColor.value);
      const glyph = document.querySelector('.notebook-glyph-a-highlight');
      if (glyph) glyph.style.background = notebookHighlightColor.value;
    });
  }

  document.getElementById('btnNotebookClearFormat')?.addEventListener('mousedown', event => event.preventDefault());
  document.getElementById('btnNotebookClearFormat')?.addEventListener('click', () => executeNotebookCommand('removeFormat'));

  document.getElementById('btnNotebookImage')?.addEventListener('mousedown', event => event.preventDefault());
  document.getElementById('btnNotebookImage')?.addEventListener('click', openNotebookImageDialog);

  document.getElementById('btnNotebookImageCancel')?.addEventListener('click', closeNotebookImageDialog);
  document.getElementById('btnNotebookImageInsert')?.addEventListener('click', insertNotebookImage);

  document.getElementById('btnNotebookCloseTop')?.addEventListener('click', requestCloseNotebook);

  notebookImageUrl?.addEventListener('keydown', event => {
    if (event.key === 'Enter') {
      event.stopPropagation();
      insertNotebookImage();
    }
    if (event.key === 'Escape') {
      event.stopPropagation();
      closeNotebookImageDialog();
    }
  });
}

initNotebookEditor();

// Mutations remain fire-and-forget for the UI, but we remember their order so
// a refresh caused by an older drag cannot visually roll back a newer one.
function sendInventoryMutation(event, data = {}) {
  const mutationSequence = ++localMutationSequence;
  return sendNui(event, { ...data, mutationSequence });
}

function removePlayerItemOptimistically(dbId) {
  playerItems = playerItems.filter(item => item.dbId !== dbId);
  updateWeightBar();
}

function removeGroundDropOptimistically(dropId) {
  groundDrops = groundDrops.filter(drop => drop.dropId !== dropId);
  delete groundSlotOverrides[dropId];
}

function applyOptimisticMerge(sourceItem, targetItem, amount) {
  const mergeAmount = Math.max(0, Number(amount) || 0);
  if (!sourceItem || !targetItem || mergeAmount <= 0) return;

  targetItem.count = Math.max(0, (Number(targetItem.count) || 0) + mergeAmount);
  const sourceCount = Number(sourceItem.count) || 0;
  if (mergeAmount >= sourceCount) {
    if (sourceItem.isGround) removeGroundDropOptimistically(sourceItem.dropId);
    else removePlayerItemOptimistically(sourceItem.dbId);
  } else {
    sourceItem.count = sourceCount - mergeAmount;
  }
  updateWeightBar();
}

function applyOptimisticGroundMove(item, target, rotation = item && item.isRotated) {
  if (!item || !target) return;

  if (item.isGround) {
    removeGroundDropOptimistically(item.dropId);
    playerItems.push({
      ...item,
      dbId: `pending_pickup_${++optimisticGroundSequence}`,
      dropId: undefined,
      isGround: false,
      container: target.container,
      x: target.x,
      y: target.y,
      isRotated: !!rotation,
      pendingMutation: true
    });
    updateWeightBar();
    return;
  }

  removePlayerItemOptimistically(item.dbId);
  const pendingDropId = `pending_drop_${++optimisticGroundSequence}`;
  const pendingDrop = {
    ...item,
    dropId: pendingDropId,
    isGround: true,
    container: 'ground',
    x: target.x,
    y: target.y,
    isRotated: !!rotation,
    pendingMutation: true
  };
  groundDrops.push(pendingDrop);
  groundSlotOverrides[pendingDropId] = {
    x: target.x,
    y: target.y,
    isRotated: !!rotation
  };
  updateWeightBar();
}

function applyOptimisticZombieLootMove(item, target, rotation = item && item.isRotated) {
  if (!item || !target) return;
  playerItems.push({
    ...item,
    dbId: `pending_zombie_${item.zombieId}_${item.slotId}_${++optimisticGroundSequence}`,
    isZombieLoot: false,
    container: target.container,
    x: target.x,
    y: target.y,
    isRotated: !!rotation,
    pendingMutation: true
  });
  updateWeightBar();
}

function applyOptimisticContextDrop(item, amount) {
  if (!item) return;
  const count = Math.max(1, Number(amount) || 1);
  if (count >= (Number(item.count) || 1)) {
    removePlayerItemOptimistically(item.dbId);
  } else {
    item.count = (Number(item.count) || 1) - count;
    updateWeightBar();
  }
}

// =================================================================
// СЕТОЧНЫЙ РЕНДЕРИНГ
// =================================================================

function initGrids() {
  const mainRows = Math.max(config.Grids.main.rows || 4, ...playerItems
    .filter(item => (item.container || 'main') === 'main')
    .map(item => Number(item.y || 0) + (item.isRotated ? (item.width || 1) : (item.height || 1))));
  buildGridContainer('grid-main', config.Grids.main.cols, mainRows);
  buildGridContainer('grid-ground', config.Grids.ground.cols, config.Grids.ground.rows);
  buildEquipmentGrid();
  buildClothingStorageGrids();
}

// The weight card is the visual bottom edge of the usable inventory column.
// Keep the column viewport exactly as high as the equipment panel, so newly
// added storage grids continue below the card and are reached with its own
// scrollbar instead of changing the layout's vertical position.
function syncInventoryScrollViewport() {
  const panel = document.getElementById('equipmentPanel');
  const column = document.querySelector('.left-column');
  if (!panel || !column || panel.offsetHeight <= 0) return;
  const available = Math.max(0, window.innerHeight - 72);
  column.style.height = `${Math.min(panel.offsetHeight, available)}px`;
}

window.addEventListener('resize', syncInventoryScrollViewport);

const EQUIPMENT_SLOT_LABELS = {
  Hat: 'Шляпа', Mask: 'Маска', EyeWear: 'Очки', NeckWear: 'Шея', Shirt: 'Рубашка', Vest: 'Жилет',
  Coat: 'Пальто', CoatClosed: 'Закр. пальто', Poncho: 'Пончо', Cloak: 'Плащ', Pant: 'Штаны', Skirt: 'Юбка',
  Dress: 'Платье', Boots: 'Сапоги', Spurs: 'Шпоры', Spats: 'Гамаши', Chap: 'Чапсы', Gunbelt: 'Оруж. пояс',
  Holster: 'Кобура', Belt: 'Ремень', Suspender: 'Подтяжки', Glove: 'Перчатки',
  Gauntlets: 'Наручи', Accessories: 'Аксессуары', Bracelet: 'Браслет', RingLh: 'Кольцо Л',
  RingRh: 'Кольцо П', Satchels: 'Сумка'
};

const GENDER_LOCKED_SLOTS = { Skirt: 'Female', Dress: 'Female' };
const EQUIPMENT_LOGICAL_ORDER = [
  'Hat', 'Mask', 'EyeWear', 'NeckWear', 'Shirt', 'Vest', 'Coat', 'CoatClosed',
  'Poncho', 'Cloak', 'Pant', 'Skirt', 'Dress', 'Boots', 'Spurs', 'Spats',
  'Chap', 'Gunbelt', 'Holster', 'Belt', 'Suspender', 'Glove',
  'Gauntlets', 'Accessories', 'Bracelet', 'RingLh', 'RingRh', 'Satchels'
];
const EQUIPMENT_LOGICAL_INDEX = Object.fromEntries(EQUIPMENT_LOGICAL_ORDER.map((slot, index) => [slot, index]));

function normalizeGender(value) {
  return String(value || 'Male').toLowerCase().includes('female') ? 'Female' : 'Male';
}

function clothingGender(item) {
  const value = item && item.metadata && (item.metadata.gender || item.metadata.sex);
  return normalizeGender(value || currentCharacterGender);
}

function canUseClothingForGender(item) {
  if (!item || !item.clothing) return true;
  if (item.isBackpack || (typeof item.name === 'string' && item.name.startsWith('backpack_'))) return true;
  const itemGender = item.metadata && (item.metadata.gender || item.metadata.sex);
  return !itemGender || normalizeGender(itemGender) === normalizeGender(currentCharacterGender);
}

const EQUIPMENT_SLOT_LAYOUT = {
  // Все координаты привязаны к шагу сетки 45px (44px ячейка + 1px зазор).
  // Слева находятся части тела сверху вниз, справа — снаряжение и слои одежды.
  Hat: [0, 0], Mask: [90, 0], EyeWear: [135, 0], NeckWear: [90, 45],
  Shirt: [0, 135], Vest: [90, 135], Coat: [0, 225], Poncho: [90, 225],
  Pant: [0, 315], Boots: [0, 405], Spats: [90, 405], Spurs: [90, 450],
  Chap: [0, 495], Glove: [90, 495], Gauntlets: [90, 540],
  Bracelet: [0, 585], RingLh: [45, 585], RingRh: [90, 585],

  Gunbelt: [531, 0], Holster: [531, 45], Belt: [531, 90],
  Suspender: [531, 135], Accessories: [531, 180],
  CoatClosed: [531, 225], Cloak: [531, 315], Satchels: [531, 405],
  Skirt: [531, 495], Dress: [531, 585]
};

const LARGE_EQUIPMENT_SLOTS = new Set(['Hat', 'Shirt', 'Vest', 'Coat', 'CoatClosed', 'Poncho', 'Cloak', 'Pant', 'Skirt', 'Dress', 'Boots', 'Chap', 'Satchels']);
const MEDIUM_EQUIPMENT_SLOTS = new Set(['NeckWear', 'Gunbelt', 'Holster', 'Belt', 'Suspender', 'Glove', 'Gauntlets', 'Accessories', 'Spurs']);

function equipmentSlotSize(slot) {
  if (LARGE_EQUIPMENT_SLOTS.has(slot)) return { width: 2, height: 2 };
  if (MEDIUM_EQUIPMENT_SLOTS.has(slot)) return { width: 2, height: 1 };
  return { width: 1, height: 1 };
}

function equipmentSlotId(slot, fallbackIndex) {
  const configured = config.Equipment && config.Equipment.slotIds && config.Equipment.slotIds[slot];
  return Number.isFinite(Number(configured)) ? Number(configured) : fallbackIndex;
}

function equipmentSlotAtId(slotId) {
  const slots = (config.Equipment && config.Equipment.slots) || [];
  return slots.find((slot, index) => equipmentSlotId(slot, index) === Number(slotId)) || null;
}

function equipmentColumnCount() {
  const slots = (config.Equipment && config.Equipment.slots) || [];
  return Math.max(0, ...slots.map((slot, index) => equipmentSlotId(slot, index) + 1));
}

function buildEquipmentGrid() {
  const el = document.getElementById('grid-equipment');
  if (!el) return;
  const slots = (config.Equipment && config.Equipment.slots) || [];
  el.innerHTML = '';
  slots.forEach((slot, index) => {
    if (GENDER_LOCKED_SLOTS[slot] && GENDER_LOCKED_SLOTS[slot] !== normalizeGender(currentCharacterGender)) return;
    const slotId = equipmentSlotId(slot, index);
    const layout = EQUIPMENT_SLOT_LAYOUT[slot] || [0, index * 48];
    const size = equipmentSlotSize(slot);
    const cell = document.createElement('div');
    cell.className = 'equipment-cell'; cell.dataset.x = slotId; cell.dataset.y = 0;
    cell.dataset.slot = slot; cell.title = slot;
    cell.style.left = `${layout[0]}px`; cell.style.top = `${layout[1]}px`;
    cell.style.width = `${size.width * CELL_SIZE + (size.width - 1) * CELL_GAP}px`;
    cell.style.height = `${size.height * CELL_SIZE + (size.height - 1) * CELL_GAP}px`;
    cell.innerHTML = `<span>${EQUIPMENT_SLOT_LABELS[slot] || slot}</span>`;
    el.appendChild(cell);
  });
}

function updateCharacterSilhouette(gender) {
  currentCharacterGender = String(gender || 'Male');
  const silhouette = document.getElementById('characterSilhouette');
  if (!silhouette) return;
  const isFemale = currentCharacterGender.toLowerCase().includes('female');
  silhouette.src = `images/character_silhouette_${isFemale ? 'female' : 'male'}.png?v=4`;
}

function buildClothingStorageGrids() {
  const host = document.getElementById('clothing-storage-sections');
  if (!host) return;
  host.innerHTML = '';
  playerItems.filter(i => i.container === 'equipment' && i.storage && canUseClothingForGender(i))
    .sort((a, b) => (EQUIPMENT_LOGICAL_INDEX[a.clothingSlot] ?? 999) - (EQUIPMENT_LOGICAL_INDEX[b.clothingSlot] ?? 999))
    .forEach(item => {
      const storage = item.storage; const id = `grid-clothing-${item.dbId}`;
      const section = document.createElement('div'); section.className = 'grid-section clothing-storage-section';
      section.innerHTML = `<div class="section-header"><span class="section-title">${item.label || item.clothingSlot}</span></div><div class="grid-container clothing-grid" id="${id}" data-container="clothing:${item.dbId}"></div>`;
      host.appendChild(section); buildGridContainer(id, storage.cols, storage.rows);
      const grid = document.getElementById(id);
      (storage.rowWidths || []).forEach((width, row) => {
        for (let col = width; col < storage.cols; col++) {
          const cell = grid.querySelector(`[data-x="${col}"][data-y="${row}"]`); if (cell) cell.classList.add('disabled-cell');
        }
      });
    });
}

function buildZombieCorpseGrids(corpses) {
  const host = document.getElementById('zombie-storage-sections');
  if (!host) return;

  if (!corpses || corpses.length === 0) {
    host.innerHTML = '';
    stopZombieSearchQueue();
    return;
  }

  const activeZombieIds = new Set(corpses.map(c => String(c.zombieId)));
  host.querySelectorAll('.zombie-storage-section').forEach(sec => {
    const zid = sec.id.replace('section-zombie-', '');
    if (!activeZombieIds.has(zid)) {
      sec.remove();
      stopZombieSearchQueue(Number(zid) || zid);
    }
  });

  corpses.forEach(c => {
    const secId = `section-zombie-${c.zombieId}`;
    let section = document.getElementById(secId);
    const hasItems = c.items && c.items.length > 0;
    const dotHtml = hasItems ? '<span class="zombie-header-dot"></span>' : '';
    if (!section) {
      section = document.createElement('div');
      section.className = 'grid-section zombie-storage-section';
      section.id = secId;
      section.innerHTML = `
        <div class="section-header">
          <span class="section-title zombie-title">
            ${dotHtml}
            ${c.label || 'Мёртвый'}
          </span>
        </div>
        <div class="grid-container zombie-grid" id="grid-zombie-${c.zombieId}" data-container="zombie:${c.zombieId}"></div>
      `;
      host.appendChild(section);
      buildGridContainer(`grid-zombie-${c.zombieId}`, c.cols || 7, c.rows || 3);
    }
  });
}

let searchedCorpseSlots = {};
let activeCorpseSearches = {};

function getSearchDuration(rarity) {
  const r = (rarity || 'common').toLowerCase();
  if (r === 'white' || r === 'common') return 3900;
  if (r === 'green' || r === 'uncommon') return 6300;
  if (r === 'blue' || r === 'rare') return 9900;
  if (r === 'purple' || r === 'epic') return 13800;
  if (r === 'gold' || r === 'orange' || r === 'legendary' || r === 'yellow') return 18000;
  return 4500;
}

function stopZombieSearchQueue(zombieId) {
  if (zombieId !== undefined) {
    const q = activeCorpseSearches[zombieId];
    if (q && q.animFrame) {
      cancelAnimationFrame(q.animFrame);
    }
    delete activeCorpseSearches[zombieId];
    sendNui('setZombieSearchingState', { zombieId: zombieId, isSearching: false });
  } else {
    Object.keys(activeCorpseSearches).forEach(zid => {
      const q = activeCorpseSearches[zid];
      if (q && q.animFrame) {
        cancelAnimationFrame(q.animFrame);
      }
      sendNui('setZombieSearchingState', { zombieId: Number(zid) || zid, isSearching: false });
    });
    activeCorpseSearches = {};
  }
}

function ensureActiveSearchVisuals(zombieId, slotId) {
  const overlay = document.getElementById(`search-overlay-${zombieId}-${slotId}`);
  if (!overlay) return;
  overlay.classList.remove('waiting');
  if (!overlay.querySelector('.search-progress-circle')) {
    overlay.innerHTML = `
      <svg class="search-progress-circle" viewBox="0 0 36 36">
        <path class="circle-bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
        <path class="circle-bar" id="circle-bar-${zombieId}-${slotId}" stroke-dasharray="0, 100" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
      </svg>
    `;
  }
}

function startZombieSearchQueue(zombieId, items) {
  searchedCorpseSlots[zombieId] = searchedCorpseSlots[zombieId] || new Set();

  const unsearchedItems = items.filter(it => !searchedCorpseSlots[zombieId].has(it.slotId));
  if (unsearchedItems.length === 0) {
    stopZombieSearchQueue(zombieId);
    if (items.length > 0) {
      sendNui('onZombieAllItemsSearched', { zombieId: zombieId });
    }
    return;
  }

  // Если этот труп уже активно ищет предмет, который всё ещё не раскрыт - НЕ перезапускаем таймер!
  const currentSearch = activeCorpseSearches[zombieId];
  if (currentSearch) {
    const isStillValid = unsearchedItems.some(it => it.slotId === currentSearch.slotId);
    if (isStillValid) {
      ensureActiveSearchVisuals(zombieId, currentSearch.slotId);
      return;
    }
    if (currentSearch.animFrame) {
      cancelAnimationFrame(currentSearch.animFrame);
    }
    delete activeCorpseSearches[zombieId];
  }

  const targetItem = unsearchedItems[0];
  const duration = getSearchDuration(targetItem.rarity);
  const startTime = performance.now();

  const searchState = {
    zombieId: zombieId,
    slotId: targetItem.slotId,
    startTime: startTime,
    duration: duration,
    animFrame: null
  };
  activeCorpseSearches[zombieId] = searchState;

  ensureActiveSearchVisuals(zombieId, targetItem.slotId);
  sendNui('setZombieSearchingState', { zombieId: zombieId, isSearching: true });

  function step(now) {
    const active = activeCorpseSearches[zombieId];
    if (!active || active.slotId !== targetItem.slotId) {
      return;
    }

    const elapsed = now - active.startTime;
    const progress = Math.min(100, Math.round((elapsed / active.duration) * 100));

    const circleBar = document.getElementById(`circle-bar-${zombieId}-${targetItem.slotId}`);
    if (circleBar) {
      circleBar.setAttribute('stroke-dasharray', `${progress}, 100`);
    }

    if (elapsed < active.duration) {
      active.animFrame = requestAnimationFrame(step);
    } else {
      // 100% РґРѕСЃС‚РёРіРЅСѓС‚Рѕ!
      searchedCorpseSlots[zombieId].add(targetItem.slotId);
      sendNui('onZombieItemSearched', { zombieId: zombieId, slotId: targetItem.slotId });

      const gridEl = document.getElementById(`grid-zombie-${zombieId}`);
      if (gridEl) {
        const itemEl = gridEl.querySelector(`[data-db-id="z_${zombieId}_${targetItem.slotId}"]`);
        if (itemEl) {
          itemEl.classList.remove('item-unsearched');
          targetItem.isUnsearched = false;
          if (itemEl._item) {
            itemEl._item.isUnsearched = false;
          }
          const overlay = itemEl.querySelector('.search-overlay');
          if (overlay) overlay.remove();

          const hasStackCount = targetItem.count && targetItem.count > 1;
          const countBadgeHtml = hasStackCount ? `<span class="item-count-badge">x${targetItem.count}</span>` : '';
          const fullnessBarHtml = getFullnessBarHtml(targetItem);

          itemEl.innerHTML = `
            <div class="item-icon-wrapper" style="animation: itemReveal 0.3s ease-out;">
              ${getItemIconHtml(targetItem)}
            </div>
            ${countBadgeHtml}
            ${fullnessBarHtml}
          `;
        }
      }

      delete activeCorpseSearches[zombieId];
      const corpse = zombieCorpses.find(zc => zc.zombieId === zombieId);
      const remainingItems = corpse ? corpse.items : items;
      const stillUnsearched = (remainingItems || []).filter(it => !searchedCorpseSlots[zombieId].has(it.slotId));
      if (stillUnsearched.length === 0) {
        sendNui('setZombieSearchingState', { zombieId: zombieId, isSearching: false });
        if (remainingItems && remainingItems.length > 0) {
          sendNui('onZombieAllItemsSearched', { zombieId: zombieId });
        }
      } else {
        startZombieSearchQueue(zombieId, remainingItems || []);
      }
    }
  }

  searchState.animFrame = requestAnimationFrame(step);
}

function revealZombieItem(zombieId, slotId) {
  const zIdNum = Number(zombieId) || zombieId;
  const sIdNum = Number(slotId);
  searchedCorpseSlots[zIdNum] = searchedCorpseSlots[zIdNum] || new Set();
  searchedCorpseSlots[zIdNum].add(sIdNum);

  const corpse = (zombieCorpses || []).find(zc => zc.zombieId === zIdNum);
  const targetItem = corpse && corpse.items && corpse.items.find(it => it.slotId === sIdNum);
  if (targetItem) {
    targetItem.isUnsearched = false;
    targetItem.isSearched = true;
  }

  const gridEl = document.getElementById(`grid-zombie-${zIdNum}`);
  if (gridEl) {
    const itemEl = gridEl.querySelector(`[data-db-id="z_${zIdNum}_${sIdNum}"]`) || gridEl.querySelector(`[data-slot-id="${sIdNum}"]`);
    if (itemEl && itemEl.classList.contains('item-unsearched')) {
      itemEl.classList.remove('item-unsearched');
      if (itemEl._item) {
        itemEl._item.isUnsearched = false;
        itemEl._item.isSearched = true;
      }
      const overlay = itemEl.querySelector('.search-overlay');
      if (overlay) overlay.remove();

      const it = (itemEl._item || targetItem);
      if (it) {
        const hasStackCount = it.count && it.count > 1;
        const countBadgeHtml = hasStackCount ? `<span class="item-count-badge">x${it.count}</span>` : '';
        const fullnessBarHtml = getFullnessBarHtml(it);
        itemEl.innerHTML = `
          <div class="item-icon-wrapper" style="animation: itemReveal 0.3s ease-out;">
            ${getItemIconHtml(it)}
          </div>
          ${countBadgeHtml}
          ${fullnessBarHtml}
        `;
      }
    }
  }

  const currentSearch = activeCorpseSearches[zIdNum];
  if (currentSearch && currentSearch.slotId === sIdNum) {
    if (currentSearch.animFrame) {
      cancelAnimationFrame(currentSearch.animFrame);
    }
    delete activeCorpseSearches[zIdNum];
    if (corpse && corpse.items) {
      startZombieSearchQueue(zIdNum, corpse.items);
    }
  }
}

function renderZombieItems() {
  if (!zombieCorpses || zombieCorpses.length === 0) return;

  zombieCorpses.forEach(c => {
    const gridEl = document.getElementById(`grid-zombie-${c.zombieId}`);
    if (!gridEl) return;

    // Обновляем красный кружок в шапке: есть если есть предметы, нет если все забрали
    const sec = document.getElementById(`section-zombie-${c.zombieId}`);
    if (sec) {
      const dot = sec.querySelector('.zombie-header-dot');
      const hasItems = (c.items && c.items.length > 0);
      if (hasItems && !dot) {
        const title = sec.querySelector('.zombie-title');
        if (title) {
          const newDot = document.createElement('span');
          newDot.className = 'zombie-header-dot';
          title.insertBefore(newDot, title.firstChild);
        }
      } else if (!hasItems && dot) {
        dot.remove();
      }
    }

    searchedCorpseSlots[c.zombieId] = searchedCorpseSlots[c.zombieId] || new Set();

    const currentItemEls = new Map();
    gridEl.querySelectorAll('.grid-item').forEach(el => {
      const sId = el.dataset.slotId;
      if (sId !== undefined) {
        currentItemEls.set(Number(sId), el);
      }
    });

    const activeSlotIds = new Set();

    (c.items || []).forEach(rawItem => {
      activeSlotIds.add(rawItem.slotId);
      if (rawItem.isSearched) searchedCorpseSlots[c.zombieId].add(rawItem.slotId);
      const isSearched = searchedCorpseSlots[c.zombieId].has(rawItem.slotId);
      const existingEl = currentItemEls.get(rawItem.slotId);

      if (existingEl) {
        // Предмет уже в DOM, обновляем только при изменении состояния
        if (isSearched && existingEl.classList.contains('item-unsearched')) {
          existingEl.classList.remove('item-unsearched');
          if (existingEl._item) existingEl._item.isUnsearched = false;
          const overlay = existingEl.querySelector('.search-overlay');
          if (overlay) overlay.remove();
          const hasStackCount = rawItem.count && rawItem.count > 1;
          const countBadgeHtml = hasStackCount ? `<span class="item-count-badge">x${rawItem.count}</span>` : '';
          const fullnessBarHtml = getFullnessBarHtml(rawItem);
          existingEl.innerHTML = `
            <div class="item-icon-wrapper" style="animation: itemReveal 0.3s ease-out;">
              ${getItemIconHtml(rawItem)}
            </div>
            ${countBadgeHtml}
            ${fullnessBarHtml}
          `;
        }
        if (existingEl._item) {
          existingEl._item.count = rawItem.count;
          let badge = existingEl.querySelector('.item-count-badge');
          if (isSearched && rawItem.count > 1) {
            if (!badge) {
              badge = document.createElement('span');
              badge.className = 'item-count-badge';
              existingEl.appendChild(badge);
            }
            badge.innerText = `x${rawItem.count}`;
            existingEl.classList.add('has-stack-count');
          } else if (badge) {
            badge.remove();
            existingEl.classList.remove('has-stack-count');
          }
        }
      } else {
        const item = {
          ...rawItem,
          dbId: `z_${c.zombieId}_${rawItem.slotId}`,
          zombieId: c.zombieId,
          slotId: rawItem.slotId,
          container: `zombie:${c.zombieId}`,
          isZombieLoot: true,
          isUnsearched: !isSearched
        };
        const el = renderItemElement(item, gridEl);
        if (el) {
          el.dataset.slotId = String(rawItem.slotId);
        }
      }
    });

    // Удаляем элементы предметов, которых больше нет в трупе
    currentItemEls.forEach((el, slotId) => {
      if (!activeSlotIds.has(slotId)) {
        el.remove();
      }
    });

    startZombieSearchQueue(c.zombieId, c.items || []);
  });
}

// Backpacks use the equipped clothing storage grid.  They must never expose
// their hidden `container:<id>` grid while sitting in the main inventory: that
// would let a double click (or the context menu) bypass the wear requirement.
function isBackpackItem(item) {
  return Boolean(item && (item.isBackpack === true
    || (typeof item.name === 'string' && item.name.toLowerCase().startsWith('backpack_'))));
}

function canOpenInventoryContainer(item) {
  if (!item || item.isGround || (!item.isContainer && !item.containerStorage)) return false;
  // Ordinary bags, pouches and key rings keep their existing behaviour.
  return !isBackpackItem(item);
}

let activeContainerDbId = null;
let activePlacedContainer = null;
let isDraggingContainerWin = false;
let containerWinDragOffset = { x: 0, y: 0 };

function openPlacedContainerWindow(data) {
  if (!data || !data.propId || !data.storage) return;
  if (activePlacedContainer && activePlacedContainer.propId !== data.propId) {
    sendNui('closePlacedContainer', {});
  }
  activePlacedContainer = {
    propId: data.propId,
    itemName: data.itemName,
    label: data.label,
    storage: data.storage
  };
  activeContainerDbId = null;

  const modal = document.getElementById('containerModal');
  const titleEl = document.getElementById('containerTitle');
  const gridEl = document.getElementById('grid-container');

  if (!modal || !gridEl) return;

  if (titleEl) {
    titleEl.textContent = data.label || 'Контейнер';
  }

  gridEl.dataset.container = `prop:${data.propId}`;
  buildGridContainer('grid-container', data.storage.cols, data.storage.rows);

  modal.style.display = 'flex';
  initContainerWindowDraggable();
  renderPlayerItems();
}

function openContainerWindow(item) {
  if (!canOpenInventoryContainer(item)) return;
  const storage = item.containerStorage;
  if (!storage) return;

  if (activePlacedContainer) {
    sendNui('closePlacedContainer', {});
    activePlacedContainer = null;
  }

  activeContainerDbId = item.dbId;

  const modal = document.getElementById('containerModal');
  const win = document.getElementById('containerWindow');
  const titleEl = document.getElementById('containerTitle');
  const gridEl = document.getElementById('grid-container');

  if (!modal || !gridEl) return;

  if (titleEl) {
    titleEl.textContent = item.label || item.name || 'Контейнер';
  }

  gridEl.dataset.container = `container:${item.dbId}`;
  buildGridContainer('grid-container', storage.cols, storage.rows);

  modal.style.display = 'flex';
  initContainerWindowDraggable();
  renderPlayerItems();
}

function closeContainerWindow() {
  if (activePlacedContainer) {
    sendNui('closePlacedContainer', {});
    activePlacedContainer = null;
  }
  activeContainerDbId = null;
  const modal = document.getElementById('containerModal');
  if (modal) modal.style.display = 'none';
  const gridEl = document.getElementById('grid-container');
  if (gridEl) {
    gridEl.innerHTML = '';
    gridEl.dataset.container = 'container:0';
  }
}
window.closeContainerWindow = closeContainerWindow;

function initContainerWindowDraggable() {
  const header = document.getElementById('containerHeader');
  const win = document.getElementById('containerWindow');
  if (!header || !win || header._hasDragListener) return;
  header._hasDragListener = true;

  header.addEventListener('mousedown', (e) => {
    if (e.target.closest('#btnContainerClose')) return;
    isDraggingContainerWin = true;
    const rect = win.getBoundingClientRect();
    containerWinDragOffset.x = e.clientX - rect.left;
    containerWinDragOffset.y = e.clientY - rect.top;

    win.style.left = `${rect.left}px`;
    win.style.top = `${rect.top}px`;
    win.style.transform = 'none';

    const onWinMouseMove = (me) => {
      if (!isDraggingContainerWin) return;
      const newLeft = Math.max(10, Math.min(window.innerWidth - win.offsetWidth - 10, me.clientX - containerWinDragOffset.x));
      const newTop = Math.max(10, Math.min(window.innerHeight - win.offsetHeight - 10, me.clientY - containerWinDragOffset.y));
      win.style.left = `${newLeft}px`;
      win.style.top = `${newTop}px`;
    };

    const onWinMouseUp = () => {
      isDraggingContainerWin = false;
      window.removeEventListener('mousemove', onWinMouseMove);
      window.removeEventListener('mouseup', onWinMouseUp);
    };

    window.addEventListener('mousemove', onWinMouseMove);
    window.addEventListener('mouseup', onWinMouseUp);
  });
}

function buildGridContainer(elementId, cols, rows) {
  const container = document.getElementById(elementId);
  if (!container) return;

  container.innerHTML = '';
  container.style.gridTemplateColumns = `repeat(${cols}, ${CELL_SIZE}px)`;
  container.style.gridTemplateRows = `repeat(${rows}, ${CELL_SIZE}px)`;

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const cell = document.createElement('div');
      cell.className = 'grid-cell';
      cell.dataset.x = c;
      cell.dataset.y = r;
      container.appendChild(cell);
    }
  }
}

function isItemCarriedByPlayer(item, playerItemsMap, visited = new Set()) {
  if (!item || item.isGround) return false;
  if (item.dbId !== undefined && visited.has(item.dbId)) return false;
  if (item.dbId !== undefined) visited.add(item.dbId);

  const c = String(item.container || 'main');
  if (c === 'main' || c === 'equipment') {
    return true;
  }
  if (c.startsWith('prop:') || c === 'ground') {
    return false;
  }

  const match = c.match(/^(clothing|container):(.+)$/);
  if (match) {
    const parentId = match[2];
    const parent = playerItemsMap.get(Number(parentId)) || playerItemsMap.get(String(parentId));
    if (!parent) return false;
    return isItemCarriedByPlayer(parent, playerItemsMap, visited);
  }

  return false;
}

function getMaxWeight() {
  return (config && Number(config.MaxWeight)) ? Number(config.MaxWeight) : 30.0;
}

function getMaxOverweightMargin() {
  return (config && Number(config.MaxOverweightMargin) !== undefined && !isNaN(Number(config.MaxOverweightMargin)))
    ? Number(config.MaxOverweightMargin)
    : 5.0;
}

function getMaxAllowedWeight() {
  return getMaxWeight() + getMaxOverweightMargin();
}

function getItemWeight(item) {
  if (!item) return 0.0;
  const isBackpack = Boolean(item.isBackpack || (typeof item.name === 'string' && (item.name.startsWith('backpack_') || item.name === 'clothing_satchels')));
  if (!isBackpack && (item.clothing === true || item.category === 'clothing' || !!item.clothingSlot || (typeof item.name === 'string' && item.name.startsWith('clothing_')))) {
    return 0.0;
  }
  return (item.weight !== undefined && item.weight !== null && !isNaN(Number(item.weight)))
    ? Number(item.weight)
    : 0.1;
}

function getContainedItemsWeight(parentDbId, visited = new Set()) {
  if (parentDbId === undefined || parentDbId === null) return 0.0;
  const parentKey = String(parentDbId);
  if (visited.has(parentKey)) return 0.0;
  visited.add(parentKey);

  let totalWeight = 0.0;
  playerItems.forEach(child => {
    if (!child || String(child.dbId) === parentKey) return;

    const container = String(child.container || '');
    const match = container.match(/^(?:clothing|container):(.+)$/);
    if (!match || String(match[1]) !== parentKey) return;

    const count = (child.count !== undefined && child.count !== null && !isNaN(Number(child.count)) && Number(child.count) > 0)
      ? Number(child.count)
      : 1;
    totalWeight += getItemWeight(child) * count;

    if (child.dbId !== undefined && child.dbId !== null) {
      totalWeight += getContainedItemsWeight(child.dbId, visited);
    }
  });

  return totalWeight;
}

function getDisplayedItemWeight(item) {
  if (!item) return 0.0;
  const count = (item.count !== undefined && item.count !== null && !isNaN(Number(item.count)) && Number(item.count) > 0)
    ? Number(item.count)
    : 1;
  let totalWeight = getItemWeight(item) * count;

  const playerItemsMap = getPlayerItemsMap();
  if (isBackpackItem(item) && !item.isGround && isItemCarriedByPlayer(item, playerItemsMap)) {
    totalWeight += getContainedItemsWeight(item.dbId);
  }

  return Math.round(totalWeight * 10) / 10;
}

function getPlayerItemsMap() {
  const map = new Map();
  playerItems.forEach(item => {
    if (item && item.dbId !== undefined) {
      map.set(item.dbId, item);
      map.set(String(item.dbId), item);
    }
  });
  return map;
}

function isContainerCarriedByPlayer(containerId, playerItemsMap) {
  if (!containerId) return false;
  const c = String(containerId);
  if (c === 'main' || c === 'equipment') return true;
  if (c === 'ground' || c.startsWith('prop:')) return false;

  const match = c.match(/^(clothing|container):(.+)$/);
  if (match) {
    const parentId = match[2];
    const map = playerItemsMap || getPlayerItemsMap();
    const parent = map.get(Number(parentId)) || map.get(String(parentId));
    if (!parent) return false;
    return isItemCarriedByPlayer(parent, map);
  }
  return false;
}

function calculateTotalCarriedWeight() {
  const playerItemsMap = getPlayerItemsMap();

  let totalWeight = 0;
  playerItems.forEach(item => {
    if (isItemCarriedByPlayer(item, playerItemsMap)) {
      const unitWeight = getItemWeight(item);
      const count = (item.count !== undefined && item.count !== null && !isNaN(Number(item.count)) && Number(item.count) > 0)
        ? Number(item.count)
        : 1;
      totalWeight += unitWeight * count;
    }
  });

  return Math.round(totalWeight * 10) / 10;
}

function updateWeightBar() {
  const barFill = document.getElementById('equipmentWeightBar');
  const valueEl = document.getElementById('equipmentWeightValue');
  if (!barFill || !valueEl) return;

  const totalWeight = calculateTotalCarriedWeight();
  const maxWeight = getMaxWeight();
  const pct = Math.max(0, (totalWeight / maxWeight) * 100);
  const fillWidth = Math.min(100, pct);

  barFill.style.width = `${fillWidth.toFixed(1)}%`;

  valueEl.innerHTML = `
    <span class="weight-current">${totalWeight.toFixed(1)}</span>
    <span class="weight-divider">/</span>
    <span class="weight-max">${maxWeight.toFixed(1)}</span>
    <span class="weight-unit">кг</span>
  `;

  if (totalWeight > maxWeight) {
    barFill.classList.remove('is-warning');
    barFill.classList.add('is-danger');
    valueEl.classList.remove('is-warning');
    valueEl.classList.add('is-danger');
  } else if (pct >= 75) {
    barFill.classList.remove('is-danger');
    barFill.classList.add('is-warning');
    valueEl.classList.remove('is-danger');
    valueEl.classList.add('is-warning');
  } else {
    barFill.classList.remove('is-warning', 'is-danger');
    valueEl.classList.remove('is-warning', 'is-danger');
  }

  // Мгновенная синхронизация перевеса со скоростью передвижения клиента
  sendNui('onWeightUpdated', { weight: totalWeight });
}

function renderPlayerItems() {
  const mainGridEl = document.getElementById('grid-main');
  if (!mainGridEl) return;

  const hoveredDbId = activeHoveredItem && !activeHoveredItem.isGround
    ? activeHoveredItem.dbId
    : null;

  document.querySelectorAll('#grid-main .grid-item, #grid-equipment .grid-item, .clothing-grid .grid-item, #grid-container .grid-item').forEach(el => el.remove());

  if (activeContainerDbId) {
    const activeParent = playerItems.find(it => String(it.dbId) === String(activeContainerDbId));
    if (!activeParent || (activeParent.container !== 'main' && !String(activeParent.container).startsWith('clothing:'))) {
      closeContainerWindow();
    } else {
      const gridEl = document.getElementById('grid-container');
      if (gridEl && activeParent.containerStorage) {
        gridEl.dataset.container = `container:${activeParent.dbId}`;
      }
    }
  } else if (activePlacedContainer) {
    const gridEl = document.getElementById('grid-container');
    if (gridEl) {
      gridEl.dataset.container = `prop:${activePlacedContainer.propId}`;
    }
  }

  playerItems.forEach(item => {
    if ((item.container || 'main') === 'main') {
      const el = renderItemElement(item, mainGridEl);
      if (isDirectTransferMode && el && selectedTransferBatch[item.dbId]) {
        updateTransferItemVisual(item, el);
      }
    }
    if (item.container === 'equipment') {
      const target = document.querySelector(`#grid-equipment [data-x="${item.x}"][data-y="0"]`);
      if (target) { target.innerHTML = ''; const el = renderItemElement(item, target); if (el) { el.style.left = '0'; el.style.top = '0'; } }
    }
    if (String(item.container || '').startsWith('clothing:')) {
      const parentId = String(item.container).split(':')[1];
      const grid = document.getElementById(`grid-clothing-${parentId}`);
      if (grid) {
        renderItemElement(item, grid);
      } else if (activeContainerDbId && String(activeContainerDbId) === String(parentId)) {
        const cGrid = document.getElementById('grid-container');
        if (cGrid) renderItemElement(item, cGrid);
      }
    }
    if (String(item.container || '').startsWith('container:')) {
      const parentId = String(item.container).split(':')[1];
      const grid = document.getElementById(`grid-clothing-${parentId}`);
      if (grid) {
        renderItemElement(item, grid);
      } else if (activeContainerDbId && String(activeContainerDbId) === String(parentId)) {
        const cGrid = document.getElementById('grid-container');
        if (cGrid) renderItemElement(item, cGrid);
      }
    }
    if (activePlacedContainer && String(item.container || '') === `prop:${activePlacedContainer.propId}`) {
      const grid = document.getElementById('grid-container');
      if (grid) renderItemElement(item, grid);
    }
  });

  updateWeightBar();

  if (hoveredDbId !== null && hoveredDbId !== undefined) {
    const freshItem = playerItems.find(item => String(item.dbId) === String(hoveredDbId));
    const freshTarget = Array.from(document.querySelectorAll('.grid-item'))
      .find(element => String(element.dataset.dbId) === String(hoveredDbId));
    if (freshItem && freshTarget && freshTarget.matches(':hover')) {
      showHoverTooltip(freshItem, freshTarget);
    } else {
      hideHoverTooltip();
    }
  }
}

function renderGroundItems() {
  const groundGridEl = document.getElementById('grid-ground');
  if (!groundGridEl) return;

  // Если был открыт тултип описания для предмета с земли, которого больше нет рядом
  if (activeHoveredItem && activeHoveredItem.isGround) {
    const stillHoveredExists = groundDrops.some(d => d.dropId === activeHoveredItem.dropId);
    if (!stillHoveredExists) {
      hideHoverTooltip();
    }
  }

  // Если было открыто контекстное меню для предмета с земли, которого больше нет рядом
  if (activeContextItem && activeContextItem.isGround) {
    const stillContextExists = groundDrops.some(d => d.dropId === activeContextItem.dropId);
    if (!stillContextExists) {
      closeContextMenu();
    }
  }

  // Очистка устаревших оверрайдов для предметов, которых больше нет рядом
  const validDropIds = new Set(groundDrops.map(d => d.dropId));
  for (let dropId in groundSlotOverrides) {
    if (!validDropIds.has(parseInt(dropId, 10)) && !validDropIds.has(dropId)) {
      delete groundSlotOverrides[dropId];
    }
  }

  const maxCols = config.Grids.ground.cols || 7;
  const defaultRows = config.Grids.ground.rows || 5;

  // 2D матрица занятости ячеек сетки "Рядом"
  const occupied = {};
  function isCellFree(cx, cy, cw, ch) {
    for (let r = 0; r < ch; r++) {
      for (let c = 0; c < cw; c++) {
        const y = cy + r;
        const x = cx + c;
        if (x >= maxCols) return false;
        if (occupied[`${x},${y}`]) return false;
      }
    }
    return true;
  }

  function markCells(cx, cy, cw, ch) {
    for (let r = 0; r < ch; r++) {
      for (let c = 0; c < cw; c++) {
        occupied[`${cx + c},${cy + r}`] = true;
      }
    }
  }

  let maxRowUsed = 0;
  const placedGroundItems = [];
  const unplacedDrops = [];

  // 1. Сначала размещаем предметы, для которых игрок задал ручное положение в сетке
  groundDrops.forEach(drop => {
    const override = groundSlotOverrides[drop.dropId];
    if (override) {
      const isRot = override.isRotated || false;
      const effW = isRot ? (drop.height || 1) : (drop.width || 1);
      const effH = isRot ? (drop.width || 1) : (drop.height || 1);
      const ox = override.x;
      const oy = override.y;

      if (ox >= 0 && (ox + effW <= maxCols) && oy >= 0 && isCellFree(ox, oy, effW, effH)) {
        markCells(ox, oy, effW, effH);
        if (oy + effH > maxRowUsed) maxRowUsed = oy + effH;
        placedGroundItems.push({
          ...drop,
          isGround: true,
          x: ox,
          y: oy,
          container: 'ground',
          isRotated: isRot,
          description: drop.description || (drop.metadata && drop.metadata.description) || ''
        });
        return;
      } else {
        // Оверрайд некорректен или перекрыт — сбрасываем
        delete groundSlotOverrides[drop.dropId];
      }
    }
    unplacedDrops.push(drop);
  });

  // 2. Остальные предметы заполняем в первые свободные ячейки слева направо, сверху вниз
  unplacedDrops.forEach(drop => {
    const effW = drop.width || 1;
    const effH = drop.height || 1;

    let foundX = -1;
    let foundY = -1;

    for (let y = 0; y < 1000; y++) {
      for (let x = 0; x <= maxCols - effW; x++) {
        if (isCellFree(x, y, effW, effH)) {
          foundX = x;
          foundY = y;
          break;
        }
      }
      if (foundX !== -1) break;
    }

    if (foundX === -1) {
      foundX = 0;
      foundY = maxRowUsed;
    }

    markCells(foundX, foundY, effW, effH);
    if (foundY + effH > maxRowUsed) {
      maxRowUsed = foundY + effH;
    }

    placedGroundItems.push({
      ...drop,
      isGround: true,
      x: foundX,
      y: foundY,
      container: 'ground',
      isRotated: false,
      description: drop.description || (drop.metadata && drop.metadata.description) || ''
    });
  });

  currentGroundRenderedItems = placedGroundItems;

  // Динамически рассчитываем количество строк: минимум defaultRows, если предметов больше — расширяем
  const totalRowsNeeded = Math.max(defaultRows, maxRowUsed);
  config.Grids.ground.currentRows = totalRowsNeeded;

  // Перестраиваем ячейки сетки земли под актуальное число строк
  buildGridContainer('grid-ground', maxCols, totalRowsNeeded);

  // Очищаем старые предметы и рендерим новые
  groundGridEl.querySelectorAll('.grid-item').forEach(el => el.remove());
  placedGroundItems.forEach(item => {
    renderItemElement(item, groundGridEl);
  });
}

function renderAllItems() {
  renderPlayerItems();
  renderGroundItems();
  renderZombieItems();
  updateWeightBar();
}

function applyInventorySnapshot(data) {
  if (data.config) config = { ...config, ...data.config };
  if (data.gender !== undefined) updateCharacterSilhouette(data.gender);
  playerItems = normalizeInventoryItems(data.items);
  groundDrops = Array.isArray(data.groundDrops) ? data.groundDrops : [];
  zombieCorpses = Array.isArray(data.zombieCorpses) ? data.zombieCorpses : [];
  initGrids();
  buildZombieCorpseGrids(zombieCorpses);
  renderAllItems();
}

function flushPendingInventoryUpdate() {
  if (!pendingInventoryUpdate || dragged) return false;
  const queuedUpdate = pendingInventoryUpdate;
  pendingInventoryUpdate = null;
  // The snapshot may have been requested for a previous drag while the user
  // was already moving another item. Keep the optimistic state until the
  // refresh belonging to the newer mutation arrives.
  if (queuedUpdate.mutationSequence !== localMutationSequence) return false;
  if (queuedUpdate.dragMutationSequence !== undefined
      && queuedUpdate.mutationSequence > queuedUpdate.dragMutationSequence) return false;
  applyInventorySnapshot(queuedUpdate.data);
  return true;
}

function renderItemElement(item, containerEl) {
  const isEquipmentContainer = item.container === 'equipment' || (containerEl && containerEl.classList && containerEl.classList.contains('equipment-cell'));
  let effW = item.isRotated ? (item.height || 1) : (item.width || 1);
  let effH = item.isRotated ? (item.width || 1) : (item.height || 1);

  if (isEquipmentContainer) {
    const slotName = item.clothingSlot || (containerEl && containerEl.dataset ? containerEl.dataset.slot : null) || (item.x !== undefined ? equipmentSlotAtId(item.x) : null);
    const slotSize = equipmentSlotSize(slotName);
    effW = slotSize.width;
    effH = slotSize.height;
  }

  const wPx = effW * CELL_SIZE + (effW - 1) * CELL_GAP;
  const hPx = effH * CELL_SIZE + (effH - 1) * CELL_GAP;

  const isMedicalItem = (directMedicineKnockedTarget && directTransferModeType === 'medicine')
    ? item.name === 'first_aid_kit'
    : (item.name !== 'first_aid_kit' && (item.category === 'medical' || (item.healAmount && item.healAmount > 0) || item.name === 'bandage' || item.name === 'bandage_burdock'));
  const disabledInMedicineClass = (isDirectTransferMode && directTransferModeType === 'medicine' && !isMedicalItem) ? 'item-disabled-medicine' : '';

  const itemEl = document.createElement('div');
  const hasStackCount = !item.isUnsearched && item.count && item.count > 1;
  const itemRarity = (item.rarity === 'yellow' ? 'purple' : (item.rarity || 'green'));
  itemEl.className = `grid-item rarity-${itemRarity} ${item.isRotated ? 'item-rotated' : ''} ${hasStackCount ? 'has-stack-count' : ''} ${disabledInMedicineClass} ${item.pendingMutation ? 'item-pending-mutation' : ''}`;
  itemEl.dataset.dbId = String(item.dbId);
  if (isEquipmentContainer) {
    itemEl.style.left = '0';
    itemEl.style.top = '0';
    itemEl.style.width = '100%';
    itemEl.style.height = '100%';
  } else {
    itemEl.style.left = `${item.x * (CELL_SIZE + CELL_GAP)}px`;
    itemEl.style.top = `${item.y * (CELL_SIZE + CELL_GAP)}px`;
    itemEl.style.width = `${wPx}px`;
    itemEl.style.height = `${hPx}px`;
  }
  itemEl.style.setProperty('--item-w', `${wPx}px`);
  itemEl.style.setProperty('--item-h', `${hPx}px`);

  if (item.slotId !== undefined) {
    itemEl.dataset.slotId = String(item.slotId);
  }

  const countBadgeHtml = hasStackCount ? `<span class="item-count-badge">x${item.count}</span>` : '';
  const fullnessBarHtml = getFullnessBarHtml(item);

  if (item.isUnsearched) {
    itemEl.classList.add('item-unsearched');
    itemEl.innerHTML = `
      <div class="search-overlay waiting" id="search-overlay-${item.zombieId}-${item.slotId}"></div>
    `;
  } else {
    itemEl.innerHTML = `
      <div class="item-icon-wrapper">
        ${getItemIconHtml(item)}
      </div>
      ${countBadgeHtml}
      ${fullnessBarHtml}
    `;
  }

  itemEl._item = item;

  // Двойной клик ЛКМ - быстрое открытие контейнера
  itemEl.addEventListener('dblclick', (e) => {
    if (itemEl.classList.contains('item-unsearched') || (itemEl._item && itemEl._item.isUnsearched)) return;
    const currentItem = itemEl._item || item;
    if (e.button === 0 && canOpenInventoryContainer(currentItem)) {
      e.preventDefault();
      e.stopPropagation();
      cancelActiveDrag();
      openContainerWindow(currentItem);
    }
  });

  // ЛКМ - перетаскивание (обычное или с Shift) или выбор при передаче
  itemEl.addEventListener('mousedown', (e) => {
    if (itemEl.classList.contains('item-unsearched') || (itemEl._item && itemEl._item.isUnsearched)) { e.preventDefault(); return; }
    const currentItem = itemEl._item || item;
    if (e.button === 0) {
      hideHoverTooltip();
      if (currentItem.pendingMutation) return;
      if (isDirectTransferMode) {
        handleTransferItemClick(currentItem, itemEl, e);
        return;
      }

      // Быстрое открытие контейнера при двойном клике ЛКМ
      const isContainer = canOpenInventoryContainer(currentItem);
      if (isContainer) {
        const now = Date.now();
        const itemId = currentItem.dbId;
        if (lastContainerClick.id === itemId && (now - lastContainerClick.time) < 400) {
          lastContainerClick = { id: null, time: 0 };
          e.preventDefault();
          e.stopPropagation();
          cancelActiveDrag();
          openContainerWindow(currentItem);
          return;
        }
        lastContainerClick = { id: itemId, time: now };
      } else {
        lastContainerClick = { id: null, time: 0 };
      }

      startDragging(currentItem, e, itemEl);
    }
  });

  // ПКМ - Контекстное меню или уменьшение счетчика при передаче
  itemEl.addEventListener('contextmenu', (e) => {
    if (itemEl.classList.contains('item-unsearched') || (itemEl._item && itemEl._item.isUnsearched)) { e.preventDefault(); e.stopPropagation(); return; }
    const currentItem = itemEl._item || item;
    e.preventDefault();
    e.stopPropagation();
    hideHoverTooltip();
    if (currentItem.pendingMutation) return;
    if (isDirectTransferMode) {
      handleTransferItemRightClick(currentItem, itemEl, e);
      return;
    }
    openContextMenu(currentItem, e);
  });

  // Наведение мыши - всплывающий тултип с описанием справа снизу от угла предмета
  itemEl.addEventListener('mouseenter', () => {
    if (itemEl.classList.contains('item-unsearched') || (itemEl._item && itemEl._item.isUnsearched)) return;
    showHoverTooltip(itemEl._item || item, itemEl);
  });
  itemEl.addEventListener('mouseleave', () => {
    hideHoverTooltip();
  });

  containerEl.appendChild(itemEl);
  return itemEl;
}

// =================================================================
// ВСПЛЫВАЮЩИЙ ТУЛТИП ОПИСАНИЯ ПРЕДМЕТА
// =================================================================

function showHoverTooltip(item, target) {
  if (!item || item.isUnsearched || dragged || (itemContextMenu && itemContextMenu.style.display === 'block') || (splitModal && splitModal.style.display === 'flex')) {
    hideHoverTooltip();
    return;
  }

  activeHoveredItem = item;

  const count = item.count || 1;
  const unitWeight = getItemWeight(item);
  const isBackpack = isBackpackItem(item);
  const totalWeight = isBackpack ? getDisplayedItemWeight(item) : unitWeight * count;

  let descText = (item.description && item.description.trim() !== '') ? item.description : 'Нет описания.';
  ttTitle.innerText = item.label || item.name;
  ttDesc.innerText = descText;
  if (ttGender && item.clothing && !isBackpack && item.metadata && (item.metadata.gender || item.metadata.sex)) {
    const itemGender = normalizeGender(item.metadata.gender || item.metadata.sex);
    ttGender.innerText = itemGender === 'Female' ? 'Женская одежда' : 'Мужская одежда';
    ttGender.style.display = 'inline';
  } else if (ttGender) {
    ttGender.style.display = 'none';
  }

  const isClothing = !isBackpack && (item.clothing === true || item.category === 'clothing' || !!item.clothingSlot || (typeof item.name === 'string' && item.name.startsWith('clothing_') && item.name !== 'clothing_satchels'));
  if (isClothing || unitWeight <= 0) {
    ttWeight.style.display = 'none';
  } else {
    ttWeight.style.display = 'inline';
    ttWeight.innerText = `${totalWeight.toFixed(1)} кг`;
  }
  ttCount.innerText = `${count} шт.`;
  ttInsulation.textContent = item.insulationLabel || '';
  ttInsulation.style.display = item.insulationLabel ? 'block' : 'none';

  hoverTooltip.style.display = 'flex';
  updateTooltipPosition(target);
}

function updateTooltipPosition(target) {
  if (!hoverTooltip || hoverTooltip.style.display === 'none' || !target) return;

  const targetEl = (target instanceof Element) ? target : (target.currentTarget || target.target);
  if (!targetEl || typeof targetEl.getBoundingClientRect !== 'function') return;

  const rect = targetEl.getBoundingClientRect();
  const tooltipRect = hoverTooltip.getBoundingClientRect();
  const tooltipW = tooltipRect.width || 210;
  const tooltipH = tooltipRect.height || 85;

  // Фиксированная позиция: строго справа снизу от угла предмета
  let posX = rect.right + 6;
  let posY = rect.bottom + 6;

  // Если тултип не помещается справа от предмета, отображаем его слева от предмета
  if (posX + tooltipW > window.innerWidth - 8) {
    posX = rect.left - tooltipW - 6;
  }

  // Если тултип не помещается снизу экрана, поднимаем вверх
  if (posY + tooltipH > window.innerHeight - 8) {
    posY = rect.bottom - tooltipH;
    if (posY < 8) {
      posY = rect.top - tooltipH - 6;
    }
  }

  posX = Math.max(8, Math.min(posX, window.innerWidth - tooltipW - 8));
  posY = Math.max(8, Math.min(posY, window.innerHeight - tooltipH - 8));

  hoverTooltip.style.transform = `translate3d(${Math.round(posX)}px, ${Math.round(posY)}px, 0)`;
}

function hideHoverTooltip() {
  if (hoverTooltip) {
    hoverTooltip.style.display = 'none';
    hoverTooltip.style.transform = 'translate3d(-9999px, -9999px, 0)';
  }
  activeHoveredItem = null;
}

// =================================================================
// DRAG & DROP, СТАКИ И ВРАЩЕНИЕ НА [R]
// =================================================================

function startDragging(item, e, sourceEl) {
  closeContextMenu();
  hideHoverTooltip();
  e.preventDefault();

  const effW = item.isRotated ? (item.height || 1) : (item.width || 1);
  const effH = item.isRotated ? (item.width || 1) : (item.height || 1);

  dragged = {
    item: item,
    sourceEl: sourceEl || null,
    hasMoved: false,
    visualsActive: false,
    isRotated: !!item.isRotated,
    fromIsRotated: !!item.isRotated,
    origW: item.width || 1,
    origH: item.height || 1,
    currentW: effW,
    currentH: effH,
    fromContainer: item.container || 'main',
    fromX: item.x,
    fromY: item.y,
    mutationSequenceAtStart: localMutationSequence,
    startX: e.clientX,
    startY: e.clientY,
    isShiftDrag: e.shiftKey === true && item.count > 1
  };
  window.__lastMouseX = e.clientX;
  window.__lastMouseY = e.clientY;

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
}

function activateDragVisuals() {
  if (!dragged || dragged.visualsActive) return;
  dragged.visualsActive = true;
  dragged.hasMoved = true;
  lastContainerClick = { id: null, time: 0 };

  playItemSound(getItemAudioCategory(dragged.item), 'pickup');

  if (dragged.sourceEl) {
    dragged.sourceEl.classList.add('item-source-ghost');
  }

  document.body.classList.add('is-dragging-active');

  const wPx = dragged.currentW * CELL_SIZE + (dragged.currentW - 1) * CELL_GAP;
  const hPx = dragged.currentH * CELL_SIZE + (dragged.currentH - 1) * CELL_GAP;

  dragGhost.style.display = 'flex';
  dragGhost.style.width = `${wPx}px`;
  dragGhost.style.height = `${hPx}px`;
  dragGhost.style.setProperty('--item-w', `${wPx}px`);
  dragGhost.style.setProperty('--item-h', `${hPx}px`);
  const ghostRarity = (dragged.item.rarity === 'yellow' ? 'purple' : (dragged.item.rarity || 'green'));
  dragGhost.className = `drag-ghost rarity-${ghostRarity} ${dragged.isRotated ? 'rotated' : ''} ${!dragged.isShiftDrag && dragged.item.count > 1 ? 'has-stack-count' : ''}`;

  const splitIconSvg = `<svg class="split-drag-badge-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="4" y1="12" x2="20" y2="12"/><circle cx="12" cy="5.5" r="2" fill="currentColor"/><circle cx="12" cy="18.5" r="2" fill="currentColor"/></svg>`;
  const ghostFullnessBarHtml = getFullnessBarHtml(dragged.item);

  dragGhost.innerHTML = `
    <div class="item-icon-wrapper">
      ${getItemIconHtml({ ...dragged.item, isRotated: dragged.isRotated })}
    </div>
    ${dragged.isShiftDrag ? `<span class="split-drag-indicator">${splitIconSvg}</span>` : (dragged.item.count > 1 ? `<span class="item-count-badge">x${dragged.item.count}</span>` : '')}
    ${ghostFullnessBarHtml}
  `;

  const posX = (window.__lastMouseX !== undefined) ? window.__lastMouseX : dragged.startX;
  const posY = (window.__lastMouseY !== undefined) ? window.__lastMouseY : dragged.startY;
  updateGhostPosition(posX, posY);
  scheduleHover(posX, posY);
}

function rotateDraggedItem() {
  if (!dragged || !dragged.hasMoved) return;
  // Квадратные предметы (1х1, 2х2, 3х3 и т.д.) не переворачиваются
  if (dragged.origW === dragged.origH) return;

  dragged.isRotated = !dragged.isRotated;
  const temp = dragged.currentW;
  dragged.currentW = dragged.currentH;
  dragged.currentH = temp;

  const wPx = dragged.currentW * CELL_SIZE + (dragged.currentW - 1) * CELL_GAP;
  const hPx = dragged.currentH * CELL_SIZE + (dragged.currentH - 1) * CELL_GAP;

  dragGhost.style.width = `${wPx}px`;
  dragGhost.style.height = `${hPx}px`;
  dragGhost.style.setProperty('--item-w', `${wPx}px`);
  dragGhost.style.setProperty('--item-h', `${hPx}px`);

  if (dragged.isRotated) {
    dragGhost.classList.add('rotated');
  } else {
    dragGhost.classList.remove('rotated');
  }

  // Re-select a native horizontal asset (when one exists) after pressing R.
  // The drag ghost keeps the stack badge outside this wrapper, so only the
  // icon node needs to be rebuilt.
  const iconWrapper = dragGhost.querySelector('.item-icon-wrapper');
  if (iconWrapper) {
    iconWrapper.innerHTML = getItemIconHtml({ ...dragged.item, isRotated: dragged.isRotated });
  }

  if (window.__lastMouseX !== undefined && window.__lastMouseY !== undefined) {
    updateGhostPosition(window.__lastMouseX, window.__lastMouseY);
    scheduleHover(window.__lastMouseX, window.__lastMouseY);
  }
}

function onMouseMove(e) {
  window.__lastMouseX = e.clientX;
  window.__lastMouseY = e.clientY;

  if (dragged && !dragged.hasMoved) {
    const dx = e.clientX - dragged.startX;
    const dy = e.clientY - dragged.startY;
    if ((dx * dx) + (dy * dy) < (DRAG_THRESHOLD_PX * DRAG_THRESHOLD_PX)) {
      return;
    }
    activateDragVisuals();
  }

  if (!dragged || !dragged.hasMoved) return;

  updateGhostPosition(e.clientX, e.clientY);

  if (dragged) {
    const groundScroll = document.getElementById('ground-scroll-container');
    if (groundScroll) {
      const rect = groundScroll.getBoundingClientRect();
      if (e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom) {
        if (e.clientY - rect.top < 40) {
          groundScroll.scrollTop -= 7;
        } else if (rect.bottom - e.clientY < 40) {
          groundScroll.scrollTop += 7;
        }
      }
    }
  }

  scheduleHover(e.clientX, e.clientY);
}

function updateGhostPosition(x, y) {
  dragGhost.style.left = `${Math.round(x)}px`;
  dragGhost.style.top = `${Math.round(y)}px`;
}

function scheduleHover(x, y) {
  pendingHoverX = x;
  pendingHoverY = y;

  if (hoverFramePending) return;
  if (typeof requestAnimationFrame !== 'function') {
    if (dragged && dragged.hasMoved) updateHover(x, y);
    return;
  }

  hoverFramePending = true;
  requestAnimationFrame(() => {
    hoverFramePending = false;
    if (dragged && dragged.hasMoved) {
      updateHover(pendingHoverX, pendingHoverY);
    }
  });
}

function clearHighlights() {
  if (currentHighlightedCells.length > 0) {
    for (let i = 0; i < currentHighlightedCells.length; i++) {
      currentHighlightedCells[i].classList.remove('cell-valid', 'cell-invalid');
    }
    currentHighlightedCells = [];
  }
}

function getItemAt(containerId, x, y, ignoreId) {
  if (containerId !== 'ground') {
    for (let it of playerItems) {
      const itContainer = it.container || 'main';
      if (itContainer === containerId && it.dbId !== ignoreId) {
        if (containerId === 'equipment') {
          if (Number(it.x) === Number(x)) return it;
          continue;
        }
        const itW = it.isRotated ? (it.height || 1) : (it.width || 1);
        const itH = it.isRotated ? (it.width || 1) : (it.height || 1);
        if (x >= it.x && x < it.x + itW && y >= it.y && y < it.y + itH) {
          return it;
        }
      }
    }
  } else if (containerId === 'ground') {
    for (let it of currentGroundRenderedItems) {
      if (it.dropId !== ignoreId) {
        const itW = it.isRotated ? (it.height || 1) : (it.width || 1);
        const itH = it.isRotated ? (it.width || 1) : (it.height || 1);
        if (x >= it.x && x < it.x + itW && y >= it.y && y < it.y + itH) {
          return it;
        }
      }
    }
  } else if (String(containerId).startsWith('zombie:')) {
    const zId = String(containerId).split(':')[1];
    const corpse = zombieCorpses.find(c => String(c.zombieId) === String(zId));
    if (corpse && corpse.items) {
      for (let rawItem of corpse.items) {
        const itemKey = `z_${zId}_${rawItem.slotId}`;
        if (rawItem.slotId !== ignoreId && itemKey !== ignoreId) {
          const itW = rawItem.isRotated ? (rawItem.height || 1) : (rawItem.width || 1);
          const itH = rawItem.isRotated ? (rawItem.width || 1) : (rawItem.height || 1);
          if (x >= rawItem.x && x < rawItem.x + itW && y >= rawItem.y && y < rawItem.y + itH) {
            return {
              ...rawItem,
              dbId: itemKey,
              zombieId: Number(zId) || zId,
              container: `zombie:${zId}`,
              isZombieLoot: true
            };
          }
        }
      }
    }
  }
  return null;
}

function updateHover(x, y) {
  clearHighlights();

  if (!dragged || !dragged.hasMoved) return;
  dragged.overweightBlocked = false;

  // Быстрый поиск сетки под курсором
  const elUnderCursor = document.elementFromPoint(x, y);
  let actualContainerEl = elUnderCursor ? (elUnderCursor.matches('.grid-container, .equipment-grid') ? elUnderCursor : elUnderCursor.closest('.grid-container, .equipment-grid')) : null;

  if (!actualContainerEl && elUnderCursor) {
    const scrollContainer = elUnderCursor.closest('#ground-scroll-container');
    if (scrollContainer) {
      actualContainerEl = document.getElementById('grid-ground');
    }
  }

  if (!actualContainerEl) {
    dragged.targetPlacement = null;
    return;
  }

  const containerId = actualContainerEl.dataset.container || (actualContainerEl.id === 'grid-ground' ? 'ground' : 'main');
  const containerConfig = getContainerConfig(containerId);
  if (!containerConfig) {
    dragged.targetPlacement = null;
    return;
  }

  const w = dragged.currentW;
  const h = dragged.currentH;
  const cols = containerConfig.cols;
  const rows = containerConfig.rows || containerConfig.currentRows || 5;

  const rect = actualContainerEl.getBoundingClientRect();
  const itemPixelW = w * CELL_SIZE + (w - 1) * CELL_GAP;
  const itemPixelH = h * CELL_SIZE + (h - 1) * CELL_GAP;

  const itemLeft = x - (itemPixelW / 2) - rect.left;
  const itemTop = y - (itemPixelH / 2) - rect.top;

  const rawX = containerId === 'equipment' ? Number((elUnderCursor.closest('.equipment-cell') || {}).dataset?.x) : Math.round(itemLeft / (CELL_SIZE + CELL_GAP));
  const rawY = containerId === 'equipment' ? 0 : Math.round(itemTop / (CELL_SIZE + CELL_GAP));

  let isWithinBounds = containerId === 'equipment'
    ? Number.isInteger(rawX) && rawX >= 0 && rawX < cols
    : (rawX >= 0) && (rawY >= 0) && (rawX + w <= cols) && (rawY + h <= rows);

  // Match server packing rules, including live pockets and serialized ground contents.
  if (isWithinBounds && dragged.item.clothing && /^(clothing|container):/.test(containerId)) {
    const parentId = String(containerId).split(':')[1];
    const parent = playerItems.find(i => String(i.dbId) === parentId);
    const isBag = parent && (parent.isBackpack || parent.clothingSlot === 'Satchels'
      || (parent.containerStorage && !parent.containerStorage.keyOnly));
    const meta = dragged.item.metadata || {};
    const hasSavedContents = ['clothing_contents', 'container_contents'].some(key =>
      meta[key] != null && (typeof meta[key] !== 'object' || Object.keys(meta[key]).length > 0));
    const hasLiveContents = dragged.item.dbId != null && playerItems.some(i =>
      i.container === `clothing:${dragged.item.dbId}` || i.container === `container:${dragged.item.dbId}`);
    if (!isBag || hasSavedContents || hasLiveContents || dragged.item.isContainer
        || dragged.item.containerStorage || dragged.item.isBackpack || String(dragged.item.dbId) === parentId) {
      isWithinBounds = false;
    }
  }

  // Ограничения для переносных контейнеров (мешок, сумка, связка ключей) и размещенных контейнеров
  if (isWithinBounds && (String(containerId).startsWith('container:') || String(containerId).startsWith('prop:'))) {
    if (String(containerId).startsWith('container:')) {
      const parentDbId = String(containerId).split(':')[1];
      if (String(dragged.item.dbId) === parentDbId) {
        isWithinBounds = false;
      }
    }
    if (dragged.item.isContainer || dragged.item.containerStorage) {
      isWithinBounds = false;
    }
    if (containerConfig.keyOnly) {
      const isKey = dragged.item.category === 'key' || dragged.item.name === 'house_key' || (typeof dragged.item.name === 'string' && dragged.item.name.includes('key')) || dragged.item.isKey;
      if (!isKey) {
        isWithinBounds = false;
      }
    }
  }

  // Clothing storage can have shorter rows (disabled cells). Keep the
  // immediate green/red feedback in sync with the authoritative server
  // validation instead of allowing a drop over a disabled tail cell.
  if (isWithinBounds && containerConfig.rowWidths && containerId !== 'equipment') {
    for (let row = rawY; row < rawY + h; row++) {
      const rowWidth = Number(containerConfig.rowWidths[row]) || cols;
      if (rawX + w > rowWidth) {
        isWithinBounds = false;
        break;
      }
    }
  }
  const ignoreId = dragged.item.isGround ? dragged.item.dropId : dragged.item.dbId;

  let isValid = false;
  let isMerge = false;
  let targetItem = null;

  // Equipment cells accept only their matching garment.  The same state is
  // authoritatively checked on the server; this is the immediate DayZ-style
  // green/red feedback while dragging.
  const equipmentSlot = containerId === 'equipment' ? equipmentSlotAtId(rawX) : null;
  if (containerId === 'equipment' && (!dragged.item.clothing || dragged.item.clothingSlot !== equipmentSlot || !canUseClothingForGender(dragged.item))) {
    const cell = elUnderCursor.closest('.equipment-cell');
    if (cell) { cell.classList.add('cell-invalid'); currentHighlightedCells.push(cell); }
    dragged.targetPlacement = null;
    return;
  }

  // 1. Проверяем ячейку прямо под курсором мыши для быстрого объединения в стак
  const cursorCellX = Math.floor((x - rect.left) / (CELL_SIZE + CELL_GAP));
  const cursorCellY = Math.floor((y - rect.top) / (CELL_SIZE + CELL_GAP));
  let cursorHoveredItem = null;
  if (cursorCellX >= 0 && cursorCellX < cols && cursorCellY >= 0 && cursorCellY < rows) {
    cursorHoveredItem = getItemAt(containerId, cursorCellX, cursorCellY, ignoreId);
  }

  // 2. Проверяем ячейку по расчетным координатам рамки предмета
  let boxHoveredItem = null;
  if (isWithinBounds) {
    boxHoveredItem = getItemAt(containerId, rawX, rawY, ignoreId);
  }

  const candidateItem = cursorHoveredItem || boxHoveredItem;
  const effMaxStack = (candidateItem && (candidateItem.maxStack || dragged.item.maxStack)) || (dragged.item.maxStack || 1);

  if (candidateItem && candidateItem.name === dragged.item.name && (effMaxStack > 1) && candidateItem.count < effMaxStack) {
    isMerge = true;
    targetItem = candidateItem;
    isValid = true;
  } else if (isWithinBounds) {
    const isFree = isAreaFree(containerId, rawX, rawY, w, h, ignoreId);
    isValid = isFree;
  }

  // Запрещено класть любые предметы в инвентарь зомби
  if (containerId && String(containerId).startsWith('zombie:')) {
    isValid = false;
    isMerge = false;
    targetItem = null;
  }

  // Проверка превышения максимального допустимого веса (30 кг базовый + 5 кг запас = 35.0 кг)
  if (isValid) {
    const itemsMap = getPlayerItemsMap();
    const isSourceCarried = isItemCarriedByPlayer(dragged.item, itemsMap);
    const isTargetCarried = isContainerCarriedByPlayer(containerId, itemsMap);

    if (!isSourceCarried && isTargetCarried) {
      const curWeight = calculateTotalCarriedWeight();
      const unitWeight = getItemWeight(dragged.item);
      let countToAdd = 1;
      if (isMerge && targetItem) {
        const targetMaxStack = targetItem.maxStack || dragged.item.maxStack || 100;
        const spaceLeft = Math.max(0, targetMaxStack - (targetItem.count || 1));
        countToAdd = Math.min(dragged.item.count || 1, Math.max(1, spaceLeft));
      } else {
        countToAdd = (dragged.isShiftDrag && dragged.item.count > 1) ? 1 : (dragged.item.count || 1);
      }
      const addedWeight = unitWeight * countToAdd;
      if (curWeight + addedWeight > getMaxAllowedWeight() + 0.001) {
        isValid = false;
        dragged.overweightBlocked = true;
      }
    }
  }

  // Моментальная подсветка ячеек сетки (зеленый при успехе, красный при занятости или выходе за край)
  const highlightClass = isValid ? 'cell-valid' : 'cell-invalid';
  if (containerId === 'equipment') {
    const targetCell = actualContainerEl.querySelector(`.equipment-cell[data-x="${rawX}"]`);
    if (targetCell) { targetCell.classList.add(highlightClass); currentHighlightedCells.push(targetCell); }
  } else for (let r = 0; r < h; r++) {
    for (let c = 0; c < w; c++) {
      const cellX = rawX + c;
      const cellY = rawY + r;
      if (cellX >= 0 && cellX < cols && cellY >= 0 && cellY < rows) {
        const targetCell = actualContainerEl.querySelector(`.grid-cell[data-x="${cellX}"][data-y="${cellY}"], .equipment-cell[data-x="${cellX}"][data-y="${cellY}"]`);
        if (targetCell) {
          targetCell.classList.add(highlightClass);
          currentHighlightedCells.push(targetCell);
        }
      }
    }
  }

  if (isValid) {
    dragged.targetPlacement = {
      container: containerId,
      x: rawX,
      y: rawY,
      isValid: true,
      isMerge: isMerge,
      targetItem: targetItem
    };
  } else {
    dragged.targetPlacement = null;
  }
}

function cancelActiveDrag() {
  window.removeEventListener('mousemove', onMouseMove);
  window.removeEventListener('mouseup', onMouseUp);
  document.body.classList.remove('is-dragging-active');
  if (dragGhost) dragGhost.style.display = 'none';
  clearHighlights();
  if (dragged && dragged.sourceEl) {
    try { dragged.sourceEl.classList.remove('item-source-ghost'); } catch (e) { }
  }
  dragged = null;
}

function onMouseUp(e) {
  let shouldRenderAfterDrag = false;
  try {
    if (dragged && dragged.hasMoved) {
      updateHover(e.clientX, e.clientY);
    }

    const hasDragAction = dragged && (
      dragged.hasMoved ||
      dragged.isRotated !== dragged.fromIsRotated
    );
    if (hasDragAction) {
      lastContainerClick = { id: null, time: 0 };
    }
    shouldRenderAfterDrag = !!hasDragAction;
    if (hasDragAction && dragged.targetPlacement && dragged.targetPlacement.isValid) {
      playItemSound(getItemAudioCategory(dragged.item), 'place');

      const target = dragged.targetPlacement;
      const item = dragged.item;

      if (target.isMerge && target.targetItem) {
        // Перетаскивание из инвентаря зомби напрямую в существующий стак
        if (item.isZombieLoot || (dragged.fromContainer && String(dragged.fromContainer).startsWith('zombie:'))) {
          playItemSound(getItemAudioCategory(item), 'place');
          const targetMaxStack = target.targetItem.maxStack || item.maxStack || 100;
          const spaceLeft = Math.max(0, targetMaxStack - (target.targetItem.count || 1));
          const mergeCount = Math.min(item.count || 1, Math.max(1, spaceLeft));

          target.targetItem.count = (Number(target.targetItem.count) || 0) + mergeCount;
          updateWeightBar();

          const c = zombieCorpses.find(zc => zc.zombieId === item.zombieId);
          if (c && c.items) {
            c.items = c.items.filter(it => it.slotId !== item.slotId);
            if (c.items.length === 0) {
              buildZombieCorpseGrids(zombieCorpses);
            }
          }

          sendInventoryMutation('takeZombieLoot', {
            zombieId: item.zombieId,
            slotId: item.slotId,
            container: target.targetItem.container || target.container,
            x: target.targetItem.x,
            y: target.targetItem.y,
            isRotated: target.targetItem.isRotated || false
          });

          renderAllItems();
          return;
        }

        // 1. Объединение в стак (Инвентарь <-> Земля / Мировой лут <-> Инвентарь)
        if (dragged.isShiftDrag && item.count > 1) {
          openSplitModal({
            sourceItem: item,
            isMerge: true,
            targetItem: target.targetItem
          });
        } else {
          const targetMaxStack = target.targetItem.maxStack || item.maxStack || 100;
          const spaceLeft = targetMaxStack - target.targetItem.count;
          const mergeCount = Math.min(item.count, Math.max(1, spaceLeft));
          if (mergeCount > 0) {
            sendInventoryMutation('mergeItems', {
              sourceDbId: item.isGround ? null : item.dbId,
              sourceDropId: item.isGround ? item.dropId : null,
              targetDbId: target.targetItem.isGround ? null : target.targetItem.dbId,
              targetDropId: target.targetItem.isGround ? target.targetItem.dropId : null,
              count: mergeCount
            });
            applyOptimisticMerge(item, target.targetItem, mergeCount);
          }
        }
      } else if (dragged.isShiftDrag && item.count > 1) {
        // 2. Разделение стака через Shift + Drag
        if (item.isGround) {
          if (target.container === 'ground') {
            openSplitModal({
              sourceItem: item,
              isGround: true,
              targetContainer: 'ground',
              targetX: target.x,
              targetY: target.y,
              isRotated: dragged.isRotated
            });
          } else {
            let destX = target.x;
            let destY = target.y;
            let destRot = dragged.isRotated;
            const isFree = isAreaFree(target.container, target.x, target.y, dragged.currentW, dragged.currentH, null);
            if (!isFree) {
              const freeSlot = findFirstFreeSlot(target.container, dragged.origW, dragged.origH);
              if (freeSlot) {
                destX = freeSlot.x;
                destY = freeSlot.y;
                destRot = freeSlot.isRotated;
              }
            }
            openSplitModal({
              sourceItem: item,
              targetContainer: target.container,
              targetX: destX,
              targetY: destY,
              isRotated: destRot
            });
          }
        } else {
          if (target.container === 'ground') {
            openSplitModal({
              sourceItem: item,
              isGround: true,
              targetContainer: 'ground'
            });
          } else {
            let destX = target.x;
            let destY = target.y;
            let destRot = dragged.isRotated;
            const isSameSlot = (target.container === dragged.fromContainer && target.x === dragged.fromX && target.y === dragged.fromY);
            const isFree = isAreaFree(target.container, target.x, target.y, dragged.currentW, dragged.currentH, null);
            if (isSameSlot || !isFree) {
              const freeSlot = findFirstFreeSlot(target.container, dragged.origW, dragged.origH);
              if (freeSlot) {
                destX = freeSlot.x;
                destY = freeSlot.y;
                destRot = freeSlot.isRotated;
              }
            }
            openSplitModal({
              sourceItem: item,
              targetContainer: target.container,
              targetX: destX,
              targetY: destY,
              isRotated: destRot
            });
          }
        }
      } else {
        // 3. Забор предмета из трупа зомби
        if (item.isZombieLoot || (dragged.fromContainer && String(dragged.fromContainer).startsWith('zombie:'))) {
          if (target.container && String(target.container).startsWith('zombie:')) {
            cancelActiveDrag();
            return;
          }

          playItemSound(getItemAudioCategory(item), 'place');

          if (target.container !== 'ground') {
            applyOptimisticZombieLootMove(item, target, dragged.isRotated);
          }

          sendInventoryMutation('takeZombieLoot', {
            zombieId: item.zombieId,
            slotId: item.slotId,
            container: target.container,
            x: target.x,
            y: target.y,
            isRotated: dragged.isRotated
          });

          const c = zombieCorpses.find(zc => zc.zombieId === item.zombieId);
          if (c && c.items) {
            c.items = c.items.filter(it => it.slotId !== item.slotId);
            if (c.items.length === 0) {
              buildZombieCorpseGrids(zombieCorpses);
            }
          }
          renderAllItems();
          return;
        } else if (item.isGround) {
          if (target.container === 'ground') {
            groundSlotOverrides[item.dropId] = {
              x: target.x,
              y: target.y,
              isRotated: dragged.isRotated
            };
          } else {
            delete groundSlotOverrides[item.dropId];
            applyOptimisticGroundMove(item, target, dragged.isRotated);
            sendInventoryMutation('pickupDrop', {
              dropId: item.dropId,
              container: target.container,
              x: target.x,
              y: target.y,
              isRotated: dragged.isRotated
            });
          }
        } else {
          if (target.container === 'ground') {
            applyOptimisticGroundMove(item, target, dragged.isRotated);
            sendInventoryMutation('dropItem', {
              name: item.name,
              count: item.count,
              dbId: item.dbId,
              metadata: item.metadata
            });
          } else {
            const previousContainer = item.container;
            const isSamePlacement =
              target.container === dragged.fromContainer &&
              Number(target.x) === Number(dragged.fromX) &&
              Number(target.y) === Number(dragged.fromY) &&
              Boolean(dragged.isRotated) === Boolean(dragged.fromIsRotated);

            if (!isSamePlacement) {
              item.container = target.container;
              item.x = target.x;
              item.y = target.y;
              item.isRotated = dragged.isRotated;
              sendInventoryMutation('saveItemPlacement', {
                dbId: item.dbId,
                container: target.container,
                x: target.x,
                y: target.y,
                isRotated: dragged.isRotated,
                previousContainer,
                clothingSlot: item.clothingSlot
              });
            }
          }
        }
      }
    } else if (hasDragAction && dragged && dragged.overweightBlocked) {
      sendNui('notifyOverweightExceeded', { maxWeight: getMaxAllowedWeight() });
    }
  } catch (err) {
    console.error('onMouseUp error:', err);
  } finally {
    cancelActiveDrag();
    if (pendingInventoryUpdate) {
      if (!flushPendingInventoryUpdate()) renderAllItems();
    } else if (shouldRenderAfterDrag) {
      renderAllItems();
    }
  }
}

function getContainerConfig(containerId) {
  if (containerId === 'main') {
    const base = config.Grids.main;
    const cells = document.querySelectorAll('#grid-main .grid-cell').length;
    return { ...base, rows: Math.max(base.rows || 4, Math.floor(cells / base.cols)) };
  }
  if (containerId === 'equipment') return { cols: equipmentColumnCount(), rows: 1 };
  if (String(containerId).startsWith('clothing:')) {
    const parentId = String(containerId).split(':')[1];
    const parent = playerItems.find(item => String(item.dbId) === parentId && item.container === 'equipment');
    return parent && parent.storage ? parent.storage : null;
  }
  if (String(containerId).startsWith('container:')) {
    const parentId = String(containerId).split(':')[1];
    const parent = playerItems.find(item => String(item.dbId) === parentId);
    return parent && parent.containerStorage ? parent.containerStorage : null;
  }
  if (String(containerId).startsWith('prop:')) {
    if (activePlacedContainer && String(containerId) === `prop:${activePlacedContainer.propId}`) {
      return activePlacedContainer.storage;
    }
    return null;
  }
  if (containerId === 'ground') {
    return {
      label: config.Grids.ground.label || 'Рядом',
      cols: config.Grids.ground.cols,
      rows: config.Grids.ground.currentRows || config.Grids.ground.rows
    };
  }
  if (String(containerId).startsWith('zombie:')) {
    const zId = String(containerId).split(':')[1];
    const corpse = zombieCorpses.find(c => String(c.zombieId) === String(zId));
    return {
      label: (corpse && corpse.label) || 'Труп зомби',
      cols: (corpse && corpse.cols) || 7,
      rows: (corpse && corpse.rows) || 3
    };
  }
  return null;
}

function findFirstFreeSlot(containerId, w, h) {
  const containerConfig = getContainerConfig(containerId);
  if (!containerConfig) return null;

  // 1. Попробуем без поворота
  for (let r = 0; r <= containerConfig.rows - h; r++) {
    for (let c = 0; c <= containerConfig.cols - w; c++) {
      if (isAreaFree(containerId, c, r, w, h, null)) {
        return { x: c, y: r, isRotated: false };
      }
    }
  }

  // 2. Попробуем с поворотом
  for (let r = 0; r <= containerConfig.rows - w; r++) {
    for (let c = 0; c <= containerConfig.cols - h; c++) {
      if (isAreaFree(containerId, c, r, h, w, null)) {
        return { x: c, y: r, isRotated: true };
      }
    }
  }

  return null;
}

function isAreaFree(containerId, startX, startY, w, h, ignoreDbId) {
  if (containerId === 'ground') return true;

  if (containerId === 'equipment') {
    return !playerItems.some(it => it.container === 'equipment' && it.dbId !== ignoreDbId && Number(it.x) === Number(startX));
  }

  const containerConfig = getContainerConfig(containerId);
  if (containerConfig) {
    if (startX < 0 || startY < 0 || startX + w > containerConfig.cols || startY + h > containerConfig.rows) {
      return false;
    }
  }
  if (containerConfig && containerConfig.rowWidths) {
    for (let row = startY; row < startY + h; row++) {
      const rowWidth = Number(containerConfig.rowWidths[row]) || containerConfig.cols;
      if (startX < 0 || startX + w > rowWidth) return false;
    }
  }

  for (let it of playerItems) {
    const itContainer = it.container || 'main';
    if (itContainer === containerId && it.dbId !== ignoreDbId) {
      const itW = it.isRotated ? (it.height || 1) : (it.width || 1);
      const itH = it.isRotated ? (it.width || 1) : (it.height || 1);

      const overlap = !(startX + w <= it.x || startX >= it.x + itW || startY + h <= it.y || startY >= it.y + itH);
      if (overlap) return false;
    }
  }
  return true;
}

// =================================================================
// ЗАКРЫТИЕ ИНВЕНТАРЯ (БЕЗ ДЮПОВ)
// =================================================================

// Context-menu pickup deliberately sends no cell coordinates. The server is
// authoritative and searches compatible stacks/free cells across `main` and
// every pocket grid contributed by currently equipped clothing.
function findContextPickupTarget(item) {
  return { container: 'main' };
}

function closeInventoryUI() {
  if (isNotebookEditorOpen()) closeNotebookEditor();
  closeContainerWindow();
  app.style.display = 'none';
  pendingInventoryUpdate = null;

  if (dragged) {
    dragGhost.style.display = 'none';
    clearHighlights();
    dragged = null;
    renderAllItems();
  }

  hideHoverTooltip();
  closeContextMenu();
  closeAmountModal();
  closeSplitModal();
  closePlayersModal();
  stopZombieSearchQueue();
  sendNui('toggleTransferIDs', { active: false });
  sendNui('closeInventory');
}

// =================================================================
// КОНТЕКСТНОЕ МЕНЮ (ПКМ)
// =================================================================

function openContextMenu(item, e) {
  activeContextItem = item;
  hideHoverTooltip();

  const clickX = (e && typeof e.clientX === 'number') ? e.clientX : (window.innerWidth / 2);
  const clickY = (e && typeof e.clientY === 'number') ? e.clientY : (window.innerHeight / 2);
  const posX = Math.max(10, Math.min(clickX, window.innerWidth - 185));
  const posY = Math.max(10, Math.min(clickY, window.innerHeight - 250));

  itemContextMenu.style.left = `${posX}px`;
  itemContextMenu.style.top = `${posY}px`;
  itemContextMenu.style.display = 'block';

  const btnPosition = document.getElementById('btnContextPosition');
  if (btnPosition) btnPosition.style.display = item.isBackpack && !item.isGround && !String(item.container || '').startsWith('prop:') ? 'flex' : 'none';
  const btnPickup = document.getElementById('btnContextPickup');
  const btnOpenContainer = document.getElementById('btnContextOpenContainer');
  const btnUse = document.getElementById('btnContextUse');
  const btnNotebookRead = document.getElementById('btnContextNotebookRead');
  const btnNotebookWrite = document.getElementById('btnContextNotebookWrite');
  const btnNotebookTear = document.getElementById('btnContextNotebookTear');
  const btnNotebookTearText = document.getElementById('btnContextNotebookTearText');
  const btnPlace = document.getElementById('btnContextPlace');
  const btnSplit = document.getElementById('btnContextSplit');
  const btnTransfer = document.getElementById('btnContextTransfer');
  const btnDrop = document.getElementById('btnContextDrop');

  const isContainerItem = canOpenInventoryContainer(item);
  const isPureNotebook = (item.name === 'notebook' || item.icon === 'notebook');
  const isNotebookOrPage = isPureNotebook || (item.name === 'torn_page' || item.icon === 'torn_page');
  const canUse = !isNotebookOrPage && (item.canUse === true || (item.actions && item.actions.includes('use')) || item.name === 'bottle_water');
  const isPlacedItem = String(item.container || '').startsWith('prop:');
  const canPlace = !item.clothing && (item.placeable !== false) && (!item.actions || item.actions.includes('place')) && !isPlacedItem;

  let meta = item.metadata;
  if (typeof meta === 'string') {
    try { meta = JSON.parse(meta); } catch (_) { meta = {}; }
  }
  const pagesLeft = (meta && meta.pages_left !== undefined) ? Number(meta.pages_left) : 5;

  if (item.isZombieLoot) {
    if (btnPickup) btnPickup.style.display = 'flex';
    if (btnOpenContainer) btnOpenContainer.style.display = 'none';
    if (btnUse) btnUse.style.display = 'none';
    if (btnNotebookRead) btnNotebookRead.style.display = 'none';
    if (btnNotebookWrite) btnNotebookWrite.style.display = 'none';
    if (btnNotebookTear) btnNotebookTear.style.display = 'none';
    if (btnPlace) btnPlace.style.display = 'none';
    if (btnSplit) btnSplit.style.display = 'none';
    if (btnTransfer) btnTransfer.style.display = 'none';
    if (btnDrop) btnDrop.style.display = 'none';
  } else if (item.isGround) {
    if (btnPickup) btnPickup.style.display = 'flex';
    if (btnOpenContainer) btnOpenContainer.style.display = 'none';
    if (btnUse) btnUse.style.display = (canUse && item.name !== 'bottle_empty') ? 'flex' : 'none';
    if (btnNotebookRead) btnNotebookRead.style.display = isNotebookOrPage ? 'flex' : 'none';
    if (btnNotebookWrite) btnNotebookWrite.style.display = 'none';
    if (btnNotebookTear) btnNotebookTear.style.display = 'none';
    if (btnPlace) btnPlace.style.display = 'none';
    if (btnSplit) btnSplit.style.display = (item.count > 1) ? 'flex' : 'none';
    if (btnTransfer) btnTransfer.style.display = 'none';
    if (btnDrop) btnDrop.style.display = 'none';
  } else {
    if (btnPickup) btnPickup.style.display = 'none';
    if (btnOpenContainer) btnOpenContainer.style.display = isContainerItem ? 'flex' : 'none';
    if (btnUse) btnUse.style.display = (canUse && item.name !== 'bottle_empty') ? 'flex' : 'none';
    if (btnNotebookRead) btnNotebookRead.style.display = isNotebookOrPage ? 'flex' : 'none';
    if (btnNotebookWrite) btnNotebookWrite.style.display = isNotebookOrPage ? 'flex' : 'none';
    if (btnNotebookTear) {
      if (isPureNotebook && pagesLeft > 0) {
        btnNotebookTear.style.display = 'flex';
        if (btnNotebookTearText) btnNotebookTearText.textContent = 'Вырвать лист';
      } else {
        btnNotebookTear.style.display = 'none';
      }
    }
    if (btnPlace) btnPlace.style.display = canPlace ? 'flex' : 'none';
    if (btnSplit) btnSplit.style.display = (item.count > 1) ? 'flex' : 'none';
    if (btnTransfer) btnTransfer.style.display = isPlacedItem ? 'none' : 'flex';
    if (btnDrop) btnDrop.style.display = 'flex';
  }
}

function closeContextMenu() {
  if (itemContextMenu) itemContextMenu.style.display = 'none';
  activeContextItem = null;
}

function executeContextAction(action) {
  if (!activeContextItem) return;
  const item = activeContextItem;
  closeContextMenu();

  if (action === 'position') {
    sendNui('positionBackpack', {dbId:item.dbId});
  } else if (action === 'open') {
    if (canOpenInventoryContainer(item)) {
      openContainerWindow(item);
    }
  } else if (action === 'read') {
    openNotebookEditor(item, true);
  } else if (action === 'write') {
    openNotebookEditor(item, false);
  } else if (action === 'tear_page') {
    if (!item.isGround && (item.name === 'notebook' || item.icon === 'notebook')) {
      sendNui('tearNotebookPage', { dbId: item.dbId });
    }
  } else if (action === 'pickup') {
    if (item.isZombieLoot) {
      const itemWeight = getItemWeight(item) * (Number(item.count) || 1);
      const curWeight = calculateTotalCarriedWeight();
      if (curWeight + itemWeight > getMaxAllowedWeight() + 0.001) {
        sendNui('notifyOverweightExceeded', { maxWeight: getMaxAllowedWeight() });
        return;
      }
      playItemSound(getItemAudioCategory(item), 'pickup');
      sendInventoryMutation('takeZombieLoot', {
        zombieId: item.zombieId,
        slotId: item.slotId,
        container: 'main'
      });
      const c = zombieCorpses.find(zc => zc.zombieId === item.zombieId);
      if (c && c.items) {
        c.items = c.items.filter(it => it.slotId !== item.slotId);
        if (c.items.length === 0) {
          zombieCorpses = zombieCorpses.filter(zc => zc.zombieId !== item.zombieId);
          buildZombieCorpseGrids(zombieCorpses);
        }
      }
      renderAllItems();
      return;
    } else if (item.isGround && item.dropId) {
      const itemWeight = getItemWeight(item) * (Number(item.count) || 1);
      const curWeight = calculateTotalCarriedWeight();
      if (curWeight + itemWeight > getMaxAllowedWeight() + 0.001) {
        sendNui('notifyOverweightExceeded', { maxWeight: getMaxAllowedWeight() });
        return;
      }
      delete groundSlotOverrides[item.dropId];
      const pickupTarget = findContextPickupTarget(item);
      if (pickupTarget.mergeTarget) {
        const targetMaxStack = pickupTarget.mergeTarget.maxStack || item.maxStack || 1;
        const spaceLeft = Math.max(0, targetMaxStack - (pickupTarget.mergeTarget.count || 1));
        const mergeCount = Math.min(item.count || 1, spaceLeft);
        if (mergeCount > 0) {
          sendInventoryMutation('mergeItems', {
            sourceDbId: null,
            sourceDropId: item.dropId,
            targetDbId: pickupTarget.mergeTarget.dbId,
            targetDropId: null,
            count: mergeCount
          });
          applyOptimisticMerge(item, pickupTarget.mergeTarget, mergeCount);
          renderAllItems();
        }
      } else {
        // No coordinates: the server fills compatible stacks and then searches
        // `main` plus all storage grids contributed by equipped clothing.
        if (pickupTarget.x !== undefined) {
          applyOptimisticGroundMove(item, pickupTarget, pickupTarget.isRotated);
        } else {
          removeGroundDropOptimistically(item.dropId);
        }
        sendInventoryMutation('pickupDrop', {
          dropId: item.dropId,
          container: pickupTarget.container,
          ...(pickupTarget.x !== undefined ? {
            x: pickupTarget.x,
            y: pickupTarget.y,
            isRotated: pickupTarget.isRotated
          } : {})
        });
        renderAllItems();
      }
    }
  } else if (action === 'place') {
    if (!item.isGround) {
      closeInventoryUI();
      sendNui('placeItem', {
        name: item.name,
        dbId: item.dbId,
        metadata: item.metadata
      });
    }
  } else if (action === 'split') {
    if (item.count > 1) {
      if (item.isGround) {
        openSplitModal({ sourceItem: item, isGround: true, targetContainer: 'ground' });
      } else {
        const freeSlot = findFirstFreeSlot(item.container || 'main', item.width || 1, item.height || 1);
        openSplitModal({
          sourceItem: item,
          targetContainer: item.container || 'main',
          targetX: freeSlot ? freeSlot.x : 0,
          targetY: freeSlot ? freeSlot.y : 0,
          isRotated: freeSlot ? freeSlot.isRotated : false
        });
      }
    }
  } else if (action === 'use') {
    sendNui('useItem', {
      name: item.name,
      dbId: item.dbId,
      isGround: !!item.isGround,
      dropId: item.dropId
    });
  } else if (action === 'drop') {
    if (item.count > 1) {
      openAmountModal(item, (count) => {
        applyOptimisticContextDrop(item, count);
        sendInventoryMutation('dropItem', { name: item.name, count: count, dbId: item.dbId, metadata: item.metadata });
        renderAllItems();
      });
    } else {
      applyOptimisticContextDrop(item, 1);
      sendInventoryMutation('dropItem', { name: item.name, count: 1, dbId: item.dbId, metadata: item.metadata });
      renderAllItems();
    }
  } else if (action === 'transfer') {
    if (item.count > 1) {
      openAmountModal(item, (count) => {
        pendingTransferItem = item;
        pendingTransferAmount = count;
        openPlayersModal();
      });
    } else {
      pendingTransferItem = item;
      pendingTransferAmount = 1;
      openPlayersModal();
    }
  }
}

// =================================================================
// МОДАЛЬНОЕ ОКНО: РАЗДЕЛЕНИЕ СТАКА (SHIFT + DRAG)
// =================================================================

function openSplitModal(data) {
  activeSplitData = data;
  const item = data.sourceItem;
  let maxSplit = data.isMerge ? Math.min(item.count, (data.targetItem.maxStack || 1) - data.targetItem.count) : (item.count - 1 > 0 ? item.count - 1 : 1);

  const itemsMap = getPlayerItemsMap();
  const isSourceCarried = isItemCarriedByPlayer(item, itemsMap);
  const targetCont = data.isMerge ? (data.targetItem && data.targetItem.container) : data.targetContainer;
  const isTargetCarried = isContainerCarriedByPlayer(targetCont, itemsMap);

  if (!isSourceCarried && isTargetCarried) {
    const spaceWeight = Math.max(0, getMaxAllowedWeight() - calculateTotalCarriedWeight());
    const unitWeight = getItemWeight(item);
    if (unitWeight > 0) {
      const maxWeightCount = Math.floor((spaceWeight + 0.001) / unitWeight);
      maxSplit = Math.max(0, Math.min(maxSplit, maxWeightCount));
      if (maxSplit <= 0) {
        activeSplitData = null;
        sendNui('notifyOverweightExceeded', { maxWeight: getMaxAllowedWeight() });
        return;
      }
    }
  }

  splitItemName.innerText = item.label || item.name;
  splitItemTotal.innerText = `Всего: ${item.count}`;

  splitAmountInput.min = 1;
  splitAmountInput.max = maxSplit;
  splitAmountInput.value = Math.min(maxSplit, Math.max(1, Math.floor(item.count / 2)));

  splitModal.style.display = 'flex';
}

function closeSplitModal() {
  if (splitModal) splitModal.style.display = 'none';
  activeSplitData = null;
  renderAllItems();
}

function stepSplitAmount(step) {
  let val = parseInt(splitAmountInput.value, 10) || 1;
  val += step;
  validateAndSetSplit(val);
}

function setSplitAmount(amount) {
  validateAndSetSplit(amount);
}

function setSplitFraction(fraction) {
  if (!activeSplitData) return;
  const item = activeSplitData.sourceItem;
  const val = Math.max(1, Math.floor(item.count * fraction));
  validateAndSetSplit(val);
}

function setSplitMax() {
  if (!activeSplitData) return;
  const maxVal = parseInt(splitAmountInput.max, 10) || 1;
  validateAndSetSplit(maxVal);
}

function validateSplitInput() {
  let val = parseInt(splitAmountInput.value, 10) || 1;
  validateAndSetSplit(val);
}

function validateAndSetSplit(val) {
  const max = parseInt(splitAmountInput.max, 10) || 1;
  if (val < 1) val = 1;
  if (val > max) val = max;
  splitAmountInput.value = val;
}

function confirmSplit() {
  if (!activeSplitData) return;
  const splitAmount = parseInt(splitAmountInput.value, 10) || 1;
  const d = activeSplitData;

  const itemsMap = getPlayerItemsMap();
  const isSourceCarried = isItemCarriedByPlayer(d.sourceItem, itemsMap);
  const targetCont = d.isMerge ? (d.targetItem && d.targetItem.container) : d.targetContainer;
  const isTargetCarried = isContainerCarriedByPlayer(targetCont, itemsMap);

  if (!isSourceCarried && isTargetCarried) {
    const unitWeight = getItemWeight(d.sourceItem);
    const addedWeight = unitWeight * splitAmount;
    if (calculateTotalCarriedWeight() + addedWeight > getMaxAllowedWeight() + 0.001) {
      closeSplitModal();
      sendNui('notifyOverweightExceeded', { maxWeight: getMaxAllowedWeight() });
      return;
    }
  }

  closeSplitModal();

  if (d.isMerge) {
    sendInventoryMutation('mergeItems', {
      sourceDbId: d.sourceItem.isGround ? null : d.sourceItem.dbId,
      sourceDropId: d.sourceItem.isGround ? d.sourceItem.dropId : null,
      targetDbId: d.targetItem.isGround ? null : d.targetItem.dbId,
      targetDropId: d.targetItem.isGround ? d.targetItem.dropId : null,
      count: splitAmount
    });
  } else if (d.sourceItem.isGround) {
    sendInventoryMutation('splitItem', {
      sourceDropId: d.sourceItem.dropId,
      count: splitAmount,
      targetContainer: d.targetContainer || 'ground',
      targetX: d.targetX || 0,
      targetY: d.targetY || 0,
      isRotated: d.isRotated || false,
      isGroundSplit: (d.targetContainer === 'ground' || d.isGround)
    });
  } else if (d.isGround || d.targetContainer === 'ground') {
    sendInventoryMutation('splitItem', {
      sourceDbId: d.sourceItem.dbId,
      count: splitAmount,
      targetContainer: 'ground',
      isGround: true
    });
  } else {
    sendInventoryMutation('splitItem', {
      sourceDbId: d.sourceItem.dbId,
      count: splitAmount,
      targetContainer: d.targetContainer || 'main',
      targetX: d.targetX,
      targetY: d.targetY,
      isRotated: d.isRotated
    });
  }
}

// =================================================================
// МОДАЛЬНЫЕ ОКНА: КОЛИЧЕСТВО И ПЕРЕДАЧА ИГРОКАМ
// =================================================================

let onAmountConfirmed = null;

function openAmountModal(item, cb) {
  onAmountConfirmed = cb;
  amountInput.value = 1;
  amountInput.max = item.count || 1;
  amountMaxVal.textContent = item.count || 1;
  amountModal.style.display = 'flex';
}

function closeAmountModal() {
  amountModal.style.display = 'none';
  onAmountConfirmed = null;
}

function stepAmount(step) {
  let val = parseInt(amountInput.value, 10) || 1;
  const max = parseInt(amountInput.max, 10) || 1;
  val = Math.max(1, Math.min(max, val + step));
  amountInput.value = val;
}

function confirmAmount() {
  const val = parseInt(amountInput.value, 10) || 1;
  if (onAmountConfirmed) {
    onAmountConfirmed(val);
  }
  closeAmountModal();
}

function openPlayersModal() {
  const invLayout = document.querySelector('.inventory-layout');
  if (invLayout) invLayout.style.display = 'none';
  app.classList.add('transfer-view');

  closeContextMenu();
  nearbyPlayersContainer.innerHTML = '<div style="color:#94a3b8; font-size:11px; text-align:center; padding:10px 0;">Поиск игроков рядом...</div>';
  playersModal.style.display = 'flex';
  sendNui('toggleTransferIDs', { active: true });

  sendNui('getNearbyPlayers', {}).then(res => {
    const players = (res && res.players) || [];
    nearbyPlayersContainer.innerHTML = '';

    if (players.length === 0) {
      nearbyPlayersContainer.innerHTML = '<div style="color:#94a3b8; font-size:11px; text-align:center; padding:10px 0;">Рядом нет других игроков (макс. 1.0м)</div>';
      return;
    }

    players.forEach(p => {
      const chip = document.createElement('div');
      chip.className = 'player-chip';
      chip.innerHTML = `
        <span class="player-chip-name"><span class="player-id-badge">[${p.id}]</span> ${p.label || 'Незнакомец'}</span>
        <span class="player-chip-dist">${p.distance}</span>
      `;
      chip.onclick = () => selectPlayerForTransfer(p.id);
      nearbyPlayersContainer.appendChild(chip);
    });
  });
}

function closePlayersModal() {
  playersModal.style.display = 'none';
  pendingTransferItem = null;
  sendNui('toggleTransferIDs', { active: false });

  // Возвращаем сетки инвентаря обратно на экран
  const invLayout = document.querySelector('.inventory-layout');
  if (invLayout) invLayout.style.display = 'flex';
  app.classList.remove('transfer-view');
}

function selectPlayerForTransfer(targetPlayerId) {
  if (!pendingTransferItem) return;

  sendNui('transferItem', {
    dbId: pendingTransferItem.dbId,
    targetPlayerId: targetPlayerId,
    count: pendingTransferAmount
  });

  // Закрываем окно выбора и возвращаем инвентарь
  closePlayersModal();
}

// =================================================================
// РЕЖИМ ПРЯМОЙ ПАКЕТНОЙ ПЕРЕДАЧИ ИГРОКУ (DIRECT TRANSFER)
// =================================================================

function handleTransferItemClick(item, itemEl, e) {
  if (!isDirectTransferMode) return;
  const dbId = item.dbId;
  const maxCount = item.count || 1;

  if (directTransferModeType === 'medicine') {
    const isMedicalItem = (directMedicineKnockedTarget)
      ? item.name === 'first_aid_kit'
      : (item.name !== 'first_aid_kit' && (item.category === 'medical' || (item.healAmount && item.healAmount > 0) || item.name === 'bandage' || item.name === 'bandage_burdock'));
    if (!isMedicalItem) return;

    if (selectedTransferBatch[dbId]) {
      delete selectedTransferBatch[dbId];
    } else {
      selectedTransferBatch = {};
      selectedTransferBatch[dbId] = {
        item: item,
        count: 1
      };
      playItemSound(getItemAudioCategory(item), 'pickup');
    }
    renderPlayerItems();
    updateTransferActionBar();
    return;
  }

  if (!selectedTransferBatch[dbId]) {
    // Впервые выбран: ставим count = 1
    selectedTransferBatch[dbId] = {
      item: item,
      count: 1
    };
    playItemSound(getItemAudioCategory(item), 'pickup');
  } else {
    // Уже выбран: если еще есть запас в стаке - увеличиваем счетчик
    const current = selectedTransferBatch[dbId].count;
    if (current < maxCount) {
      selectedTransferBatch[dbId].count = current + 1;
      playItemSound(getItemAudioCategory(item), 'pickup');
    } else {
      // Кликнули сверх максимума — сбрасываем выбор этого конкретного предмета
      delete selectedTransferBatch[dbId];
    }
  }

  updateTransferItemVisual(item, itemEl);
  updateTransferActionBar();
}

function handleTransferItemRightClick(item, itemEl, e) {
  if (!isDirectTransferMode) return;
  const dbId = item.dbId;

  if (directTransferModeType === 'medicine') {
    delete selectedTransferBatch[dbId];
    renderPlayerItems();
    updateTransferActionBar();
    return;
  }

  if (selectedTransferBatch[dbId]) {
    const current = selectedTransferBatch[dbId].count;
    if (current > 1) {
      selectedTransferBatch[dbId].count = current - 1;
    } else {
      delete selectedTransferBatch[dbId];
    }
    updateTransferItemVisual(item, itemEl);
    updateTransferActionBar();
  }
}

function updateTransferItemVisual(item, itemEl) {
  const dbId = item.dbId;
  const selected = selectedTransferBatch[dbId];
  let badgeEl = itemEl.querySelector('.item-count-badge');

  if (selected) {
    itemEl.classList.add('item-transfer-selected');
    itemEl.classList.add('has-stack-count');
    if (!badgeEl) {
      badgeEl = document.createElement('span');
      badgeEl.className = 'item-count-badge';
      itemEl.appendChild(badgeEl);
    }
    const maxCount = item.count || 1;
    if (directTransferModeType === 'medicine') {
      badgeEl.innerText = `1`;
    } else if (maxCount > 1) {
      badgeEl.innerText = `${selected.count} / ${maxCount}`;
    } else {
      badgeEl.innerText = `1`;
    }
  } else {
    itemEl.classList.remove('item-transfer-selected');
    const maxCount = item.count || 1;
    if (maxCount > 1) {
      itemEl.classList.add('has-stack-count');
      if (badgeEl) badgeEl.innerText = `x${maxCount}`;
    } else {
      itemEl.classList.remove('has-stack-count');
      if (badgeEl) badgeEl.remove();
    }
  }
}

function updateTransferActionBar() {
  const transferActionBar = document.getElementById('transferActionBar');
  const transferSelectedCount = document.getElementById('transferSelectedCount');
  const btnConfirm = document.getElementById('btnConfirmBatchTransfer');
  if (!transferActionBar) return;

  const keys = Object.keys(selectedTransferBatch);
  if (keys.length === 0) {
    transferActionBar.style.display = 'none';
    return;
  }

  transferActionBar.style.display = 'flex';

  if (directTransferModeType === 'medicine') {
    const selected = selectedTransferBatch[keys[0]];
    const label = (selected && selected.item && (selected.item.label || selected.item.name)) || 'Медикамент';
    if (transferSelectedCount) {
      transferSelectedCount.innerText = `Медицина: «${label}» (1 шт.)`;
    }
    if (btnConfirm) {
      btnConfirm.innerText = `Применить`;
    }
    return;
  }

  let totalItemsCount = 0;
  keys.forEach(k => {
    totalItemsCount += selectedTransferBatch[k].count;
  });

  if (transferSelectedCount) {
    transferSelectedCount.innerText = `Выбрано: ${keys.length} предм. (${totalItemsCount} шт.)`;
  }
  if (btnConfirm) {
    btnConfirm.innerText = `Передать (${totalItemsCount})`;
  }
}

function clearBatchSelection() {
  selectedTransferBatch = {};
  document.querySelectorAll('.grid-item.item-transfer-selected').forEach(el => {
    el.classList.remove('item-transfer-selected');
  });
  renderPlayerItems();
  updateTransferActionBar();
}

function confirmBatchTransfer() {
  const keys = Object.keys(selectedTransferBatch);
  if (keys.length === 0 || !directTransferTargetId) return;

  if (directTransferModeType === 'medicine') {
    const entry = selectedTransferBatch[keys[0]];
    sendNui('applyMedicineToTarget', {
      targetPlayerId: directTransferTargetId,
      dbId: entry.item.dbId,
      itemName: entry.item.name
    });
    clearBatchSelection();
    closeInventoryUI();
    return;
  }

  const itemsToSend = keys.map(k => ({
    dbId: parseInt(k, 10),
    count: selectedTransferBatch[k].count
  }));

  sendNui('transferBatch', {
    targetPlayerId: directTransferTargetId,
    items: itemsToSend
  });

  clearBatchSelection();
  closeInventoryUI();
}

// =================================================================
// ПРИЕМ СООБЩЕНИЙ ОТ REDM
// =================================================================

window.addEventListener('message', (event) => {
  const data = event.data;

  if (data.type === 'OPEN_INVENTORY') {
    const openRequestId = Number(data.requestId) || 0;
    const openMutationSequence = Number(data.mutationSequence) || 0;
    if (openRequestId > 0 && openRequestId < lastAppliedInventoryRequestId) return;
    if (openMutationSequence < localMutationSequence) return;
    if (openRequestId > lastAppliedInventoryRequestId) lastAppliedInventoryRequestId = openRequestId;
    pendingInventoryUpdate = null;
    cancelActiveDrag();
    isDirectTransferMode = false;
    directTransferTargetId = null;
    directMedicineKnockedTarget = false;
    selectedTransferBatch = {};

    const transferActionBar = document.getElementById('transferActionBar');
    const columnGround = document.getElementById('columnGround');
    if (transferActionBar) transferActionBar.style.display = 'none';
    if (columnGround) columnGround.style.display = 'flex';

    if (data.config) config = { ...config, ...data.config };
    updateCharacterSilhouette(data.gender);
    playerItems = normalizeInventoryItems(data.items);
    groundDrops = data.groundDrops || [];
    zombieCorpses = Array.isArray(data.zombieCorpses) ? data.zombieCorpses : [];

    const invLayout = document.querySelector('.inventory-layout');
    if (invLayout) invLayout.style.display = 'flex';
    app.classList.remove('transfer-view');

    initGrids();
    buildZombieCorpseGrids(zombieCorpses);
    renderAllItems();
    app.style.display = 'flex';
    syncInventoryScrollViewport();
  }

  if (data.type === 'OPEN_DIRECT_TRANSFER') {
    const openRequestId = Number(data.requestId) || 0;
    const openMutationSequence = Number(data.mutationSequence) || 0;
    if (openRequestId > 0 && openRequestId < lastAppliedInventoryRequestId) return;
    if (openMutationSequence < localMutationSequence) return;
    if (openRequestId > lastAppliedInventoryRequestId) lastAppliedInventoryRequestId = openRequestId;
    pendingInventoryUpdate = null;
    cancelActiveDrag();
    isDirectTransferMode = true;
    directTransferModeType = data.modeType || 'transfer';
    directTransferTargetId = data.targetId;
    directTransferTargetLabel = data.targetLabel || `[${data.targetId}] Незнакомец`;
    directMedicineKnockedTarget = data.targetKnocked === true;
    selectedTransferBatch = {};

    const transferActionBar = document.getElementById('transferActionBar');
    const columnGround = document.getElementById('columnGround');

    if (transferActionBar) transferActionBar.style.display = 'none';
    if (columnGround) columnGround.style.display = 'none';

    if (data.config) config = { ...config, ...data.config };
    updateCharacterSilhouette(data.gender);
    playerItems = normalizeInventoryItems(data.items);
    groundDrops = [];

    const invLayout = document.querySelector('.inventory-layout');
    if (invLayout) invLayout.style.display = 'flex';
    app.classList.remove('transfer-view');

    initGrids();
    renderAllItems();
    app.style.display = 'flex';
    syncInventoryScrollViewport();
  }

  if (data.type === 'UPDATE_INVENTORY') {
    const requestId = Number(data.requestId) || 0;
    const requestMutationSequence = Number(data.mutationSequence) || 0;
    if (requestId > 0 && requestId < lastAppliedInventoryRequestId) return;
    // The server echoes the mutation counter captured when this snapshot was
    // requested. A response started before the latest drag must never roll
    // the optimistic item back to its old slot.
    if (requestMutationSequence < localMutationSequence) return;
    if (requestId > 0) lastAppliedInventoryRequestId = requestId;

    if (dragged) {
      pendingInventoryUpdate = {
        data,
        mutationSequence: localMutationSequence,
        dragMutationSequence: dragged.mutationSequenceAtStart
      };
    } else {
      applyInventorySnapshot(data);
    }
  }

  if (data.type === 'CLOSE_INVENTORY') {
    pendingInventoryUpdate = null;
    if (isNotebookEditorOpen() && !isNotebookReadOnly && activeNotebookItem && notebookContent) {
      const currentHtml = notebookContent.innerHTML || '';
      if (notebookIsDirty || currentHtml !== notebookSavedHtml) {
        saveNotebook(false);
      }
    }
    closeNotebookEditor();
    app.style.display = 'none';
    app.classList.remove('transfer-view');
    const invLayout = document.querySelector('.inventory-layout');
    if (invLayout) invLayout.style.display = 'flex';

    isDirectTransferMode = false;
    directTransferTargetId = null;
    directMedicineKnockedTarget = false;
    selectedTransferBatch = {};

    const transferActionBar = document.getElementById('transferActionBar');
    const columnGround = document.getElementById('columnGround');
    if (transferActionBar) transferActionBar.style.display = 'none';
    if (columnGround) columnGround.style.display = 'flex';

    closeContainerWindow();
    cancelActiveDrag();
    hideHoverTooltip();
    closeContextMenu();
    closeAmountModal();
    closeSplitModal();
    closePlayersModal();
    stopZombieSearchQueue();
  }

  if (data.type === 'OPEN_PLACED_CONTAINER') {
    openPlacedContainerWindow(data.data);
  }

  if (data.type === 'CLOSE_PLACED_CONTAINER') {
    closeContainerWindow();
  }

  if (data.type === 'OPEN_PLACED_NOTE_READER') {
    isStandaloneNotebook = true;
    const invLayout = document.querySelector('.inventory-layout');
    if (invLayout) invLayout.style.display = 'none';
    const transferActionBar = document.getElementById('transferActionBar');
    if (transferActionBar) transferActionBar.style.display = 'none';

    app.style.display = 'flex';
    app.classList.remove('transfer-view');

    openNotebookEditor(data.item, true);
  }

  if (data.type === 'CLOSE_PLACED_NOTE_READER') {
    if (isStandaloneNotebook || isNotebookEditorOpen()) {
      isStandaloneNotebook = false;
      closeNotebookEditor();
      app.style.display = 'none';
    }
  }

  if (data.type === 'ZOMBIE_ITEM_SEARCHED') {
    revealZombieItem(data.zombieId, data.slotId);
  }

  if (data.type === 'UPDATE_ZOMBIE_CORPSES') {
    zombieCorpses = data.zombieCorpses || [];
    buildZombieCorpseGrids(zombieCorpses);
    renderZombieItems();
  }

  if (data.type === 'UPDATE_GROUND_DROPS') {
    groundDrops = data.groundDrops || [];
    if (data.zombieCorpses !== undefined) {
      zombieCorpses = data.zombieCorpses || [];
      buildZombieCorpseGrids(zombieCorpses);
    }

    if (dragged && dragged.item && dragged.item.isGround) {
      const stillNearby = groundDrops.some(d => d.dropId === dragged.item.dropId);
      if (!stillNearby) {
        cancelActiveDrag();
      }
    }

    if (dragged && dragged.item && dragged.item.isZombieLoot) {
      const corpseStillNearby = zombieCorpses.some(c => c.zombieId === dragged.item.zombieId);
      const itemStillInCorpse = corpseStillNearby && zombieCorpses
        .find(c => c.zombieId === dragged.item.zombieId).items
        .some(it => it.slotId === dragged.item.slotId);
      if (!itemStillInCorpse) {
        cancelActiveDrag();
      }
    }

    renderGroundItems();
    renderZombieItems();
  }

  if (data.type === 'ROTATE_DRAGGED_ITEM') {
    rotateDraggedItem();
  }
});

// Закрытие по ESC или I, переворот по R
window.addEventListener('keydown', (e) => {
  const isTextTarget = e.target && (
    e.target.tagName === 'INPUT' ||
    e.target.tagName === 'TEXTAREA' ||
    e.target.isContentEditable === true
  );

  if (isNotebookEditorOpen()) {
    if (e.key === 'Escape') {
      if (notebookImageDialog && notebookImageDialog.style.display === 'flex') closeNotebookImageDialog();
      else requestCloseNotebook();
    }
    return;
  }

  if (isTextTarget) {
    if (e.key === 'Escape') {
      if (playersModal && playersModal.style.display === 'flex') closePlayersModal();
      else if (splitModal && splitModal.style.display === 'flex') closeSplitModal();
      else if (amountModal && amountModal.style.display === 'flex') closeAmountModal();
      else if (activeContainerDbId) closeContainerWindow();
      else closeInventoryUI();
    }
    return;
  }

  if (e.key === 'Escape' || e.key === 'i' || e.key === 'I' || e.key === 'ш' || e.key === 'Ш' || e.code === 'KeyI' || e.keyCode === 27 || e.keyCode === 73) {
    if (playersModal.style.display === 'flex') {
      closePlayersModal();
    } else if (splitModal && splitModal.style.display === 'flex') {
      closeSplitModal();
    } else if (amountModal.style.display === 'flex') {
      closeAmountModal();
    } else if (itemContextMenu.style.display === 'block') {
      closeContextMenu();
    } else if (activeContainerDbId && (e.key === 'Escape' || e.keyCode === 27)) {
      closeContainerWindow();
    } else {
      closeInventoryUI();
    }
  }

  if (e.key === 'r' || e.key === 'R' || e.key === 'к' || e.key === 'К' || e.code === 'KeyR' || e.keyCode === 82) {
    rotateDraggedItem();
  }
});

window.addEventListener('mousedown', (e) => {
  if (itemContextMenu && !itemContextMenu.contains(e.target)) {
    closeContextMenu();
  }
});

// Живое обновление подсветки ячеек при прокрутке колесиком мыши или скроллбаром
// Text entry must fully suppress game controls while the NUI keeps input
// focus. The Lua side applies DisableAllControlActions for this state.
document.addEventListener('focusin', event => {
  const target = event.target;
  if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable === true)) {
    sendNui('setInputFocusState', { hasFocus: true });
  }
});

document.addEventListener('focusout', event => {
  const target = event.target;
  if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable === true)) {
    sendNui('setInputFocusState', { hasFocus: false });
  }
});

window.addEventListener('wheel', () => {
  if (dragged && window.__lastMouseX !== undefined) {
    scheduleHover(window.__lastMouseX, window.__lastMouseY);
  }
}, { passive: true });

const groundScrollEl = document.getElementById('ground-scroll-container');
if (groundScrollEl) {
  groundScrollEl.addEventListener('scroll', () => {
    if (dragged && window.__lastMouseX !== undefined) {
      scheduleHover(window.__lastMouseX, window.__lastMouseY);
    }
  }, { passive: true });
}
