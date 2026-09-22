'use strict';
const $ = id => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'thehunt_zombie';
let data = null, draft = null, position = null, dirty = false, busy = false, confirmation = null, liveRefreshing = false;
const groups = [
  ['Зона и население', [
    ['name','Название','text'], ['profile','Профиль','profile'], ['enabled','Зона включена','check'],
    ['x','X','number',-20000,20000],['y','Y','number',-20000,20000],['z','Z','number',-1000,3000],
    ['radius','Радиус зоны, м','number',0,null],['height','Высота зоны, м','number',1,100],['activation','Активация, м','number',0,null],['spawnRadius','Радиус появления, м','number',0,null],
    ['count','Количество','number',0,500],['minCount','Минимум','number',0,500],['maxCount','Максимум','number',1,500],
    ['randomCount','Случайное количество','check'],['randomModel','Случайная модель','check'],['bucket','Измерение','number',0,65535],
    ['respawn','Респавн после смерти, с','number',5,86400],['replenish','Восстановление после миграции, с','number',1,3600]
  ]],
  ['Поведение и атака', [
    ['walkStyle','Стиль походки','walkStyle'],
    ['health','Здоровье','number',100,3000],['damage','Урон','number',0,100],['speed','Темп движения (0.3–3)','number',0.3,3],
    ['sight','Зрение, м','number',1,150],['hearingDistance','Слух, м','number',1,500],['hearing','Множитель слуха','number',0.1,3],['aggression','Агрессия (0 — выкл., 1–5)','number',0,5],
    ['fov','Угол зрения, °','number',30,180],['reaction','Реакция, мс','number',100,5000],['searchTime','Поиск цели, с','number',2,120],
    ['attackRange','Макс. дистанция урона, м','number',0.8,3],['attackCooldown','Интервал урона, мс','number',300,15000],['headshotOnly','Только попадание в голову','check']
  ]],
  ['Холодное оружие', [
    ['weaponType','Холодное оружие в руках','weaponType'],
    ['weaponChance','Шанс появления оружия, %','number',0,100],
    ['weaponDamage','Урон оружия (0–100)','number',0,100]
  ]],
  ['Миграция', [
    ['migration','Миграция включена','check'],['migrationChance','Вероятность (0–1)','number',0,1],
    ['migrationSize','Размер группы','number',1,20],['migrationInterval','Интервал, с','number',30,86400]
  ]]
];
const integers = new Set(['count','minCount','maxCount','health','damage','bucket','migrationSize','attackCooldown','reaction','weaponChance','weaponDamage']);
const help = {
  name:'Название зоны в редакторе и списке.',
  profile:'Базовый набор характеристик. После выбора подставляются боевые значения, которые можно изменить вручную.',
  enabled:'Выключенная зона не создаёт и не восстанавливает зомби.',
  x:'Координата центра зоны по оси X.', y:'Координата центра зоны по оси Y.', z:'Высота центра зоны по оси Z.',
  radius:'Горизонтальный радиус синей зоны. За этой границей зомби возвращается домой.',
  height:'Высота цилиндра зоны. В gizmo её меняет вертикальная ось масштаба; голубые кольца показывают верх и низ.',
  activation:'Расстояние от центра, на котором зона начинает создавать зомби для игрока.',
  spawnRadius:'Радиус выбора точек появления вокруг центра.',
  count:'Постоянное число зомби, которое поддерживает зона, если отключено случайное количество.',
  minCount:'Нижняя граница случайного числа зомби при активации зоны.',
  maxCount:'Верхняя граница случайного числа. Отдельного жёсткого лимита зоны нет: итог ограничен общим максимумом сервера — 500.',
  randomCount:'При каждой активации выбирает количество между «Минимум» и «Максимум».',
  randomModel:'Для каждого появления выбирает случайную разрешённую модель.',
  bucket:'Измерение (routing bucket), в котором работает зона.',
  respawn:'Задержка до замены погибшего зомби.', replenish:'Задержка восстановления численности после миграции.',
  walkStyle:'Походка вне боя. В преследовании используется нативная боевая анимация.',
  health:'Максимальное здоровье одного зомби.', damage:'Сила нативного удара без оружия.', speed:'Темп преследования и поиска: 1 — ходьба, около 2 — лёгкий бег, 3 — быстрый бег.',
  sight:'Максимальная дальность обнаружения глазами. Дождь её немного уменьшает.',
  hearingDistance:'Абсолютная дальность слуха.', hearing:'Множитель чувствительности к звукам. Дождь заметно снижает слышимость.',
  aggression:'Уровень боевой агрессии (0 — выкл., 1–3 — стандарт, 4 — погоня/напор, 5 — постоянная яростная атака по кд).', fov:'Угол зрения перед собой. Меньше — проще подкрасться сбоку и сзади.',
  reaction:'Пауза после обнаружения до погони, в миллисекундах.', searchTime:'Сколько секунд идёт поиск последней виденной, услышанной точки или тела.',
  attackRange:'Дистанция запуска нативной ближней атаки.', attackCooldown:'Интервал повторной постановки нативной атаки при контакте.',
  headshotOnly:'Урон по телу не убивает зомби; требуется попадание в голову.',
  weaponType:'Какое холодное оружие может получить зомби.', weaponChance:'Вероятность появления с оружием.', weaponDamage:'Множитель урона нативного удара оружием.',
  migration:'Разрешает группе уходить в другую подходящую зону.', migrationChance:'Вероятность миграции при проверке интервала.',
  migrationSize:'Сколько зомби отправляется одной группой.', migrationInterval:'Как часто зона проверяет миграцию.'
};
const clone = x => JSON.parse(JSON.stringify(x));
async function post(route, body={}) {
  const response = await fetch(`https://${resource}/${route}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
  return response.json();
}
function message(text,error=false) { $('message').textContent=text; $('message').classList.toggle('error',error); }
async function rpc(action,args={}) {
  const result=await post('request',{action,args});
  if (!result.ok) throw new Error(result.error || 'Ошибка сервера');
  return result.data;
}
function studioConfirm(text) {
  $('confirmText').textContent=text; $('confirm').hidden=false; $('cancelConfirm').focus();
  return new Promise(resolve => { confirmation=resolve; });
}
function finishConfirm(value) {
  $('confirm').hidden=true; if(confirmation) confirmation(value); confirmation=null;
}
$('acceptConfirm').onclick=()=>finishConfirm(true);
$('cancelConfirm').onclick=()=>finishConfirm(false);
$('confirm').onclick=e=>{if(e.target===$('confirm'))finishConfirm(false);};
async function safe(fn) {
  if(busy) return;
  busy=true;
  try { await fn(); } catch(e) { message(e.message,true); } finally { busy=false; }
}
function refreshStatus() {
  $('status').textContent=`${data.paused?'ОСТАНОВЛЕНО':'АКТИВНО'} · Мёртвых: ${data.total} · Зон: ${data.zones.length}`;
  $('pause').textContent=data.paused?'Запустить':'Остановить';
  $('info').classList.toggle('active',data.info); $('debug').classList.toggle('active',data.debug);
  $('immuneState').textContent=data.immune?'Мёртвые игнорируют вас':'Агрессия к вам включена';
}
function renderZones() {
  $('zones').replaceChildren();
  const query=$('search').value.toLowerCase();
  for(const z of data.zones.filter(z=>`${z.id} ${z.name}`.toLowerCase().includes(query))) {
    const button=document.createElement('button'); button.className='zone';
    button.classList.toggle('off',!z.enabled); button.classList.toggle('selected',draft?.id===z.id);
    const title=document.createElement('b'); title.textContent=`#${z.id} ${z.name}`;
    const detail=document.createElement('small'); detail.textContent=`${z.enabled?(z.active?'Активна':'Ожидает игроков'):'Выключена'} · ${z.alive}/${z.maxCount}${z.cooldown?` · ${z.cooldown} с`:''}`;
    button.append(title,detail);
    if(z.error) {const error=document.createElement('small');error.textContent=z.error;error.style.color='#ef4444';button.append(error);}
    button.onclick=()=>safe(async()=>{if(dirty && !await studioConfirm('Отменить несохранённые изменения?'))return;select(z);});
    $('zones').append(button);
  }
}
function renderFields() {
  $('fields').replaceChildren();
  for(const [title,fields] of groups) {
    const h=document.createElement('h3');h.textContent=title; const grid=document.createElement('div');grid.className='field-grid';
    for(const [key,label,type,min,max] of fields) {
      const wrap=document.createElement('div');wrap.className=`field ${type==='check'?'check':''}`;
      const text=document.createElement('label');text.textContent=label;text.htmlFor=`f-${key}`;
      const hint=document.createElement('span');hint.className='help';hint.textContent='?';hint.tabIndex=0;
      hint.dataset.tip=help[key]||'Описание этого параметра.';hint.setAttribute('aria-label',hint.dataset.tip);text.append(hint);
      const control=document.createElement((type==='profile'||type==='weaponType'||type==='walkStyle')?'select':'input');control.id=`f-${key}`;control.name=key;
      if(type==='profile') {
        for(const [id,p] of Object.entries(data.profiles)){const option=document.createElement('option');option.value=id;option.textContent=p.name;control.append(option);}
        control.value=draft[key];
      } else if(type==='weaponType') {
        const options=[
          ['none','Без оружия'],
          ['both','Случайно (мачете или нож)'],
          ['knife','Только охотничий нож'],
          ['machete','Только мачете']
        ];
        for(const [val,t] of options){const opt=document.createElement('option');opt.value=val;opt.textContent=t;control.append(opt);}
        control.value=draft[key]||'both';
      } else if(type==='walkStyle') {
        const options=[
          ['MP_Style_drunk','Пьяная (по умолчанию)'],
          ['zombie_very_drunk','Очень пьяная (максимально шаткая)'],
          ['random','Случайная (из зомби-стилей)']
        ];
        for(const [val,t] of options){const opt=document.createElement('option');opt.value=val;opt.textContent=t;control.append(opt);}
        control.value=draft[key]||'MP_Style_drunk';
      } else if(type==='check') {control.type='checkbox';control.checked=!!draft[key];}
      else {control.type=type;control.value=draft[key];control.required=true;if(type==='number'){if(min!==undefined&&min!==null)control.min=min;if(max!==undefined&&max!==null)control.max=max;control.step=integers.has(key)?'1':'any';}}
      control.onchange=()=>{
        draft[key]=type==='check'?control.checked:type==='number'?Number(control.value):control.value;dirty=true;
        if(type==='profile') {
          const p=data.profiles[draft.profile];
          for(const name of ['health','damage','weaponDamage','speed','sight','hearing','hearingDistance','aggression','attackRange','attackCooldown','reaction','headshotOnly','migration']) draft[name]=p[name];
          if(p.walkStyle) draft.walkStyle=p.walkStyle;
          draft.models=[]; renderFields();renderModels();
        }
        preview();
      };
      if(type==='check')wrap.append(control,text);else wrap.append(text,control);
      grid.append(wrap);
    }
    $('fields').append(h,grid);
  }
}
function renderModels() {
  $('models').replaceChildren();
  for(const [name,outfits] of Object.entries(data.models)) {
    const label=document.createElement('label'), check=document.createElement('input');check.type='checkbox';check.checked=draft.models.includes(name);
    check.onchange=()=>{draft.models=check.checked?[...draft.models,name]:draft.models.filter(m=>m!==name);dirty=true;};
    label.append(check,document.createTextNode(`${name} (${outfits.length})`));$('models').append(label);
  }
}
function preview() { post('preview',draft).catch(()=>{}); }
function select(zone) {
  draft={...clone(data.defaults),...clone(zone)};draft.models=draft.models||[];dirty=false;
  $('empty').hidden=true;$('form').hidden=false;$('zoneTitle').textContent=draft.id?`Зона #${draft.id}`:'Новая зона';
  for(const id of ['teleport','spawn','clear','delete'])$(id).disabled=!draft.id;
  renderFields();renderModels();renderZones();preview();
}
async function refresh(keepDraft=true) {
  data=await rpc('list');refreshStatus();renderZones();
  if(!keepDraft && draft?.id){const z=data.zones.find(z=>z.id===draft.id);if(z)select(z);else{draft=null;$('form').hidden=true;$('empty').hidden=false;}}
}
// Runtime figures are deliberately refreshed without calling select(): the zone
// cards/status stay live while an admin can type into an unsaved draft safely.
async function refreshLive() {
  if(liveRefreshing || busy || !data || document.body.hidden || confirmation) return;
  liveRefreshing=true;
  try {
    const next=await rpc('list');
    if(!document.body.hidden) { data=next; refreshStatus(); renderZones(); }
  } catch(_) {
    // The next cycle retries; do not overwrite an active editor with a transient error.
  } finally { liveRefreshing=false; }
}
window.setInterval(()=>{ void refreshLive(); },1000);
$('search').oninput=renderZones;
$('new').onclick=()=>safe(async()=>{
  if(dirty&&!await studioConfirm('Отменить несохранённые изменения?'))return;
  position=await post('position'); select({...clone(data.defaults),...position});
});
$('refresh').onclick=()=>safe(async()=>{if(dirty&&!await studioConfirm('Загрузить сохранённые настройки?'))return;await refresh(false);message('Список обновлён');});
$('position').onclick=()=>safe(async()=>{Object.assign(draft,await post('position'));dirty=true;renderFields();preview();});
$('gizmo').onclick=()=>safe(async()=>{if(draft)await post('gizmo',{zone:draft});});
$('form').onsubmit=e=>{e.preventDefault();safe(async()=>{
  const saved=await rpc('save',{id:draft.id,revision:draft.revision,zone:draft});draft.id=saved.id;dirty=false;
  await refresh(false);message('Зона сохранена. Активная группа будет создана с новыми настройками.');
});};
for(const action of ['teleport','spawn','clear','delete']) $(action).onclick=()=>safe(async()=>{
  if(!draft?.id)return;
  if(['clear','delete'].includes(action)&&!await studioConfirm(action==='delete'?'Удалить зону и всех её Мёртвых?':'Очистить Мёртвых в этой зоне?'))return;
  await rpc(action,{id:draft.id,revision:draft.revision});
  if(action!=='teleport'){await refresh(false);message(action==='spawn'?'Тестовый спавн разрешён; появление зависит от безопасной дистанции.':'Готово');}
});
for(const action of ['pause','info','debug'])$(action).onclick=()=>safe(async()=>{
  if(action==='pause'&&!data.paused&&!await studioConfirm('Остановить систему и очистить активных Мёртвых?'))return;
  await rpc(action);await refresh();
});
$('immunity').onclick=()=>safe(async()=>{
  const target=$('target').value?Number($('target').value):undefined;
  const result=await rpc('immunity',{target});await refresh();message(`Игрок ${result.target}: ${result.enabled?'Мёртвые игнорируют':'агрессия включена'}`);
});
async function close(){if(dirty&&!await studioConfirm('Закрыть без сохранения?'))return;finishConfirm(false);await post('close');$('app').hidden=true;document.body.hidden=true;document.body.classList.remove('nui-open');document.documentElement.classList.remove('nui-open');}
$('close').onclick=()=>safe(close);
document.addEventListener('keydown',e=>{if(e.key==='Escape'){e.preventDefault();if(confirmation)finishConfirm(false);else safe(close);}});
document.addEventListener('focusin',e=>{if(['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName))post('setInputFocusState',{hasFocus:true}).catch(()=>{});});
document.addEventListener('focusout',()=>{setTimeout(()=>{post('setInputFocusState',{hasFocus:['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)}).catch(()=>{});},0);});
let audioCtx = null;
function getAudioContext() {
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
  }
  if (audioCtx && audioCtx.state === 'suspended') {
    audioCtx.resume().catch(() => {});
  }
  return audioCtx;
}

['click', 'keydown', 'mousedown', 'focus'].forEach(evt => {
  window.addEventListener(evt, () => {
    if (audioCtx && audioCtx.state === 'suspended') {
      audioCtx.resume().catch(() => {});
    }
  }, { passive: true });
});

const SOUND_FILES = [
  'female_breathing_fast.mp3',
  'women_zombie_groan.mp3',
  'zombie_attack_woman_1.mp3',
  'zombie_attack_woman_2.mp3',
  'zombie_bellow_man_1.mp3',
  'zombie_bellow_man_2.mp3',
  'zombie_bellow_man_3.mp3',
  'zombie_bellow_woman_1.mp3',
  'zombie_bellow_woman_2.mp3',
  'zombie_bellow_woman_3.mp3',
  'zombie_bellow_woman_4.mp3',
  'zombie_bellow_woman_5.mp3',
  'zombie_calm.mp3',
  'zombie_hiss_man_2.mp3',
  'zombie_rattle_man.mp3',
  'zombie_roar_woman.mp3',
  '666herohero-monster-death-grunt-131480.mp3',
  'freesound_community-dying-monster-101276.mp3',
  'freesound_community-zombie-death.mp3',
  'freesound_community-zombie-die.mp3',
  'dragon-studio-zombie-dying-sound-357974.mp3',
  'freesound_community-zombie-moan-44932.mp3',
  'freesound_community-zombie-moaning-101369.mp3',
  'freesound_community-weird-zombie-moan-44938.mp3',
  'vilches86-zombie-15965.mp3',
  'Reanimated_Hoard.mp3',
  'Lurking_Undead_Attack.mp3',
  'Horrific_Clash.mp3',
  'Zombie_Rumble.mp3'
];

const SOUND_ALIASES = {
  'female-zombie-breathing-fast.mp3': 'female_breathing_fast.mp3',
  'women zombie groan - quicksounds.com.mp3': 'women_zombie_groan.mp3',
  'zombie attack woman - quicksounds.com.mp3': 'zombie_attack_woman_1.mp3',
  'zombie attack woman 2 - quicksounds.com.mp3': 'zombie_attack_woman_2.mp3',
  'zombie bellow man - quicksounds.com.mp3': 'zombie_bellow_man_1.mp3',
  'zombie bellow man 2 - quicksounds.com.mp3': 'zombie_bellow_man_2.mp3',
  'zombie bellow man 3 - quicksounds.com.mp3': 'zombie_bellow_man_3.mp3',
  'zombie bellow woman - quicksounds.com.mp3': 'zombie_bellow_woman_1.mp3',
  'zombie bellow woman 2 - quicksounds.com.mp3': 'zombie_bellow_woman_2.mp3',
  'zombie bellow woman 3 - quicksounds.com.mp3': 'zombie_bellow_woman_3.mp3',
  'zombie bellow woman 4 - quicksounds.com.mp3': 'zombie_bellow_woman_4.mp3',
  'zombie bellow woman 5 - quicksounds.com.mp3': 'zombie_bellow_woman_5.mp3',
  'zombie calm - quicksounds.com.mp3': 'zombie_calm.mp3',
  'zombie hiss man 2 - quicksounds.com.mp3': 'zombie_hiss_man_2.mp3',
  'zombie rattle man - quicksounds.com.mp3': 'zombie_rattle_man.mp3',
  'zombie roar woman - quicksounds.com.mp3': 'zombie_roar_woman.mp3'
};

const audioBuffers = new Map();
const bufferLoadingPromises = new Map();
const activeSounds = new Map();

function getCandidateUrls(fileName) {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'thehunt_zombie';
  const raw = (fileName || '').trim();
  const lower = raw.toLowerCase();
  const clean = SOUND_ALIASES[lower] || raw;
  const encodedClean = encodeURIComponent(clean);
  const encodedRaw = encodeURIComponent(raw);

  const urls = [
    `sounds/${clean}`,
    `sounds/${encodedClean}`,
    `../sounds/${clean}`,
    `../sounds/${encodedClean}`,
    `https://${resource}/html/sounds/${clean}`,
    `https://${resource}/sounds/${clean}`,
    `https://cfx-nui-${resource}/html/sounds/${clean}`,
    `https://cfx-nui-${resource}/sounds/${clean}`
  ];
  if (raw !== clean) {
    urls.push(
      `sounds/${raw}`,
      `sounds/${encodedRaw}`,
      `../sounds/${raw}`,
      `../sounds/${encodedRaw}`,
      `https://${resource}/html/sounds/${encodedRaw}`,
      `https://${resource}/sounds/${encodedRaw}`
    );
  }
  return urls;
}

async function fetchAndDecodeBuffer(fileName) {
  const ctx = getAudioContext();
  if (!ctx) return null;

  const urls = getCandidateUrls(fileName);
  for (const url of urls) {
    try {
      const resp = await fetch(url);
      if (resp && resp.ok) {
        const arrayBuf = await resp.arrayBuffer();
        if (arrayBuf && arrayBuf.byteLength > 0) {
          const audioBuf = await new Promise((resolve, reject) => {
            const ret = ctx.decodeAudioData(arrayBuf, resolve, reject);
            if (ret && typeof ret.then === 'function') {
              ret.then(resolve).catch(reject);
            }
          });
          if (audioBuf) return audioBuf;
        }
      }
    } catch (_) {}
  }
  return null;
}

async function getOrLoadAudioBuffer(fileName) {
  if (!fileName) return null;
  const raw = (fileName || '').trim();
  const lower = raw.toLowerCase();
  const clean = SOUND_ALIASES[lower] || raw;

  if (audioBuffers.has(clean)) return audioBuffers.get(clean);
  if (audioBuffers.has(lower)) return audioBuffers.get(lower);
  if (audioBuffers.has(raw)) return audioBuffers.get(raw);

  if (bufferLoadingPromises.has(clean)) {
    return bufferLoadingPromises.get(clean);
  }

  const promise = (async () => {
    try {
      const buf = await fetchAndDecodeBuffer(clean);
      if (buf) {
        audioBuffers.set(clean, buf);
        audioBuffers.set(lower, buf);
        audioBuffers.set(raw, buf);
        return buf;
      }
    } finally {
      bufferLoadingPromises.delete(clean);
    }
    return null;
  })();

  bufferLoadingPromises.set(clean, promise);
  return promise;
}

function preloadAllSounds() {
  const ctx = getAudioContext();
  if (!ctx) return;
  for (const file of SOUND_FILES) {
    getOrLoadAudioBuffer(file).catch(() => {});
  }
}

// Start background decoding of all sound files
preloadAllSounds();

const SOUND_VOLUME_MODIFIERS = {
  'zombie_calm.mp3': 0.85,
  'female_breathing_fast.mp3': 0.9,
  'women_zombie_groan.mp3': 0.9,
  'zombie_roar_woman.mp3': 0.85,
  'horrific_clash.mp3': 0.42,
  'zombie_rumble.mp3': 0.45,
  'lurking_undead_attack.mp3': 0.65
};

function calculateSpatialAudio(x, y, z, dist, maxRange, stage, soundFile) {
  const d = Math.max(0, Number(dist) || 0);

  // Maximum hearing distance per behavior stage (expanded wide-radius atmospheric range)
  let stageMaxRange = 60.0;
  if (stage === 'alert') stageMaxRange = 68.0;
  else if (stage === 'chase') stageMaxRange = 75.0;
  else if (stage === 'attack') stageMaxRange = 32.0;
  else if (stage === 'death') stageMaxRange = 45.0;

  const maxD = Math.min(Number(maxRange) || 65.0, stageMaxRange);

  if (d >= maxD) {
    return { gain: 0, pan: 0, cutoff: 22000 };
  }

  // 1. Proximity volume with stage scaling (increased presence across near and far ranges)
  let baseVolume = 0.075; // Idle/wander: gentle ambient groans & breathing
  if (stage === 'alert') baseVolume = 0.120;
  else if (stage === 'chase') baseVolume = 0.155;
  else if (stage === 'attack') baseVolume = 0.200;
  else if (stage === 'death') baseVolume = 0.200;

  if (soundFile) {
    const raw = String(soundFile).trim().toLowerCase();
    const clean = (SOUND_ALIASES[raw] || raw).toLowerCase();
    const mod = SOUND_VOLUME_MODIFIERS[clean] || SOUND_VOLUME_MODIFIERS[raw];
    if (mod) {
      baseVolume *= mod;
    }
  }

  // 2. Realistic inverse-distance curve with enhanced volume retention across distances
  // Point-blank distance clamp (<= 5.0m): clamped to 57% volume level up close so point-blank sounds are not 100% deafening
  // Far distance: natural gradual drop-off with increased volume percentage across near, mid and far ranges
  const nearDist = 5.0;
  const nearVolume = 0.57;
  let distanceFalloff = nearVolume;
  if (d > nearDist) {
    const distNorm = Math.max(0, Math.min(1.0, (d - nearDist) / (maxD - nearDist)));
    const windowFactor = Math.max(0, 1.0 - distNorm);
    distanceFalloff = nearVolume * (nearDist / d) * Math.pow(windowFactor, 1.18);
  }

  let finalGain = Math.max(0, baseVolume * distanceFalloff);

  // 3. 3D Stereo Panning (X: negative = left ear, positive = right ear)
  const horizontalDist = Math.hypot(x, y);
  let pan = 0.0;
  if (horizontalDist > 0.1) {
    const rawPan = x / Math.max(1.0, horizontalDist);
    pan = Math.max(-1.0, Math.min(1.0, rawPan * 1.25));
  }

  // 4. Head Shadow & Rear Attenuation (Y: negative = behind player)
  let cutoff = 22000;
  if (y < 0 && horizontalDist > 0.2) {
    const rearRatio = Math.min(1.0, Math.abs(y) / horizontalDist);
    cutoff = Math.round(22000 - (rearRatio * 17500)); // muffled down to ~4500Hz
    finalGain *= (1.0 - (rearRatio * 0.20)); // -20% when directly behind
  }

  // 5. Distance Air Absorption: high frequencies drop with distance so distant zombies sound appropriately far and muffled
  const distanceAirAbsorption = Math.max(0.40, 1.0 - (d / maxD) * 0.55);
  cutoff = Math.max(1800, Math.round(cutoff * distanceAirAbsorption));

  return { gain: finalGain, pan, cutoff };
}

function cleanupSoundEntry(entry) {
  if (!entry) return;
  entry.stopped = true;
  try {
    if (entry.source) {
      entry.source.onended = null;
      try { entry.source.stop(); } catch (_) {}
      try { entry.source.disconnect(); } catch (_) {}
      entry.source = null;
    }
    if (entry.gainNode) {
      try { entry.gainNode.disconnect(); } catch (_) {}
      entry.gainNode = null;
    }
    if (entry.filterNode) {
      try { entry.filterNode.disconnect(); } catch (_) {}
      entry.filterNode = null;
    }
    if (entry.pannerNode) {
      try { entry.pannerNode.disconnect(); } catch (_) {}
      entry.pannerNode = null;
    }
  } catch (_) {}
}

function applySpatialUpdate(entry, x, y, z, dist) {
  if (!entry || entry.stopped) return;
  entry.x = Number(x) || 0;
  entry.y = Number(y) || 0;
  entry.z = Number(z) || 0;
  entry.dist = Number(dist) || 0;

  const { gain, pan, cutoff } = calculateSpatialAudio(entry.x, entry.y, entry.z, entry.dist, entry.maxRange, entry.stage, entry.file);

  if (entry.gainNode && audioCtx && audioCtx.state !== 'closed') {
    try {
      const now = audioCtx.currentTime;
      entry.gainNode.gain.setTargetAtTime(gain, now, 0.04);
      if (entry.pannerNode) {
        entry.pannerNode.pan.setTargetAtTime(pan, now, 0.04);
      }
      if (entry.filterNode) {
        entry.filterNode.frequency.setTargetAtTime(cutoff, now, 0.04);
      }
    } catch (_) {}
  }
}

async function playZombieSound(msg) {
  if (!msg || !msg.file) return;
  const soundId = msg.soundId || `snd_${Date.now()}_${Math.random()}`;
  const maxRange = Number(msg.maxRange) || 55.0;
  const dist = Math.max(0, Number(msg.dist) || 0);
  if (dist >= maxRange) return;

  const ctx = getAudioContext();
  if (!ctx) return;

  // Single vocalization per zombie: cancel previous sound from the same zombie
  if (msg.zombieId) {
    for (const [sId, existing] of activeSounds.entries()) {
      if (existing.zombieId === msg.zombieId) {
        cleanupSoundEntry(existing);
        activeSounds.delete(sId);
      }
    }
  }

  const relX = Number(msg.x) || 0;
  const relY = Number(msg.y) || 0;
  const relZ = Number(msg.z) || 0;
  const stage = msg.stage || 'idle';

  const entry = {
    soundId,
    zombieId: msg.zombieId,
    file: msg.file,
    source: null,
    gainNode: null,
    filterNode: null,
    pannerNode: null,
    maxRange,
    stage,
    x: relX,
    y: relY,
    z: relZ,
    dist,
    stopped: false
  };
  activeSounds.set(soundId, entry);

  const buffer = await getOrLoadAudioBuffer(msg.file);
  if (!buffer || entry.stopped || !activeSounds.has(soundId)) {
    if (!buffer && activeSounds.has(soundId)) {
      activeSounds.delete(soundId);
    }
    return;
  }

  try {
    if (ctx.state === 'suspended') {
      await ctx.resume().catch(() => {});
    }

    const { gain, pan, cutoff } = calculateSpatialAudio(entry.x, entry.y, entry.z, entry.dist, entry.maxRange, entry.stage, entry.file);

    // AudioBufferSourceNode creates ZERO WebMediaPlayer instances, preventing crbug.com/1144736
    const source = ctx.createBufferSource();
    source.buffer = buffer;

    const gainNode = ctx.createGain();
    gainNode.gain.value = gain;

    const filterNode = ctx.createBiquadFilter();
    filterNode.type = 'lowpass';
    filterNode.frequency.value = cutoff;

    const pannerNode = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
    if (pannerNode) {
      pannerNode.pan.value = pan;
      source.connect(gainNode);
      gainNode.connect(filterNode);
      filterNode.connect(pannerNode);
      pannerNode.connect(ctx.destination);
      entry.pannerNode = pannerNode;
    } else {
      source.connect(gainNode);
      gainNode.connect(filterNode);
      filterNode.connect(ctx.destination);
    }

    entry.source = source;
    entry.gainNode = gainNode;
    entry.filterNode = filterNode;

    source.onended = () => {
      cleanupSoundEntry(entry);
      activeSounds.delete(soundId);
    };

    source.start(0);
  } catch (_) {
    cleanupSoundEntry(entry);
    activeSounds.delete(soundId);
  }
}

function updateZombieSounds(updates) {
  if (!updates) return;
  for (const [soundId, update] of Object.entries(updates)) {
    const entry = activeSounds.get(soundId);
    if (!entry) continue;

    if (update.remove) {
      cleanupSoundEntry(entry);
      activeSounds.delete(soundId);
    } else {
      applySpatialUpdate(entry, update.x, update.y, update.z, update.dist);
    }
  }
}

function stopZombieSounds(zombieId, preserveDeath = false) {
  for (const [soundId, entry] of activeSounds.entries()) {
    if (!zombieId || entry.zombieId === zombieId) {
      if (preserveDeath && entry.stage === 'death') continue;
      cleanupSoundEntry(entry);
      activeSounds.delete(soundId);
    }
  }
}

window.addEventListener('message',({data:msg})=>{
  if(msg.action==='playZombieSound3D'||msg.action==='zombieSound'){
    playZombieSound(msg);
  }
  if(msg.action==='updateZombieSounds3D'&&msg.updates){
    updateZombieSounds(msg.updates);
  }
  if(msg.action==='stopZombieSound3D'){
    stopZombieSounds(msg.zombieId, msg.preserveDeath);
  }
  if(msg.action==='open'){document.body.hidden=false;document.documentElement.classList.add('nui-open');document.body.classList.add('nui-open');data=msg.data;position=msg.position;draft=null;dirty=false;busy=false;$('app').hidden=false;$('form').hidden=true;$('empty').hidden=false;refreshStatus();renderZones();message('Выберите зону. Синее кольцо — зона, зелёное — появление.');}
  if(msg.action==='close'){$('app').hidden=true;document.body.hidden=true;document.body.classList.remove('nui-open');document.documentElement.classList.remove('nui-open');finishConfirm(false);}
  if(msg.action==='gizmoZone'&&draft){document.body.hidden=false;document.documentElement.classList.add('nui-open');document.body.classList.add('nui-open');$('app').hidden=false;Object.assign(draft,msg.zone);dirty=true;renderFields();preview();message('Положение, размер и поворот изменены gizmo. Сохраните зону.');}
});
