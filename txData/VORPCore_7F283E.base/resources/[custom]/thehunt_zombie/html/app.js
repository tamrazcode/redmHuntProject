'use strict';
const $ = id => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'thehunt_zombie';
let data = null, draft = null, position = null, dirty = false, busy = false, confirmation = null, liveRefreshing = false;
const groups = [
  ['Зона и население', [
    ['name','Название','text'], ['profile','Профиль','profile'], ['enabled','Зона включена','check'],
    ['x','X','number',-20000,20000],['y','Y','number',-20000,20000],['z','Z','number',-1000,3000],
    ['radius','Радиус зоны, м','number',1,500],['height','Высота зоны, м','number',1,100],['activation','Активация, м','number',30,400],['spawnRadius','Радиус появления, м','number',0,200],
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
  ]],
  ['Лут с зомби', [
    ['lootEnabled','Лут с зомби включен','check'],
    ['lootChanceMode','Режим шанса лута','lootChanceMode'],
    ['lootChance','Фиксированный шанс (%)','number',0,100],
    ['lootChanceMin','Мин. шанс в диапазоне (%)','number',0,100],
    ['lootChanceMax','Макс. шанс в диапазоне (%)','number',0,100],
    ['lootMaxItems','Макс. предметов на зомби','number',1,5]
  ]]
];
const integers = new Set(['count','minCount','maxCount','health','damage','bucket','migrationSize','attackCooldown','reaction','weaponChance','weaponDamage','lootChance','lootChanceMin','lootChanceMax','lootMaxItems']);
const help = {
  name:'Название зоны в редакторе и списке.',
  profile:'Базовый набор характеристик. После выбора подставляются боевые значения, которые можно изменить вручную.',
  enabled:'Выключенная зона не создаёт и не восстанавливает зомби.',
  x:'Координата центра зоны по оси X.', y:'Координата центра зоны по оси Y.', z:'Высота центра зоны по оси Z.',
  radius:'Горизонтальный радиус синей зоны. За этой границей зомби возвращается домой.',
  height:'Высота цилиндра зоны. В gizmo её меняет вертикальная ось масштаба; голубые кольца показывают верх и низ.',
  activation:'Расстояние от центра, на котором зона начинает создавать зомби для игрока.',
  spawnRadius:'Радиус выбора точек появления вокруг центра. Не должен быть больше радиуса зоны.',
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
  migrationSize:'Сколько зомби отправляется одной группой.', migrationInterval:'Как часто зона проверяет миграцию.',
  lootEnabled:'Разрешает появление предметов в инвентаре погибших зомби в этой зоне. Если параметр выключен, зомби всегда будут пустыми.',
  lootChanceMode:'Режим вероятности лута: «Фиксированный шанс» устанавливает единый точный процент для всех зомби зоны. «Случайный диапазон» вычисляет вероятность индивидуально для каждого зомби в пределах указанных мин. и макс. процентов.',
  lootChance:'Базовая вероятность (в процентах от 0 до 100%), что у убитого зомби сгенерируется лут при фиксированном режиме.',
  lootChanceMin:'Нижняя граница вероятности наличия лута у зомби (в %) при режиме случайного диапазона.',
  lootChanceMax:'Верхняя граница вероятности наличия лута у зомби (в %) при режиме случайного диапазона.',
  lootMaxItems:'Максимальное количество предметов (слотов), которое может сгенерироваться в инвентаре одного мертвого зомби (от 1 до 5 шт).',
  lootSection:'Список предметов, которые могут выпасть с зомби в этой зоне. Сервер выбирает предметы случайно из этого пула с учетом их веса шанса (Roll Weight).',
  lootCatalogBtn:'Открыть визуальный каталог всех доступных на сервере предметов. Позволяет быстро выбрать нужные предметы по карточкам с иконками, названиями, весом и редкостью вместо ручного ввода ID.',
  lootItemName:'Идентификатор (ID) и название предмета из реестра предметов сервера (thehunt_items).',
  lootItemMin:'Минимальное количество этого конкретного предмета в стаке, если он выпадет у зомби.',
  lootItemMax:'Максимальное количество этого конкретного предмета в стаке, если он выпадет у зомби.',
  lootItemWeight:'Вес шанса выпадения (Roll Weight). Чем выше вес относительно других предметов в пуле, тем чаще будет выпадать этот предмет. Например, предмет с весом 100 выпадает намного чаще предмета с весом 10.',
  modelOutfits:'Разновидности внешности и одежды зомби для этой модели. Если ничего не выбрано — используются абсолютно все доступные варианты.',
  outfitPreview:'Тестовый спавн зомби в этом конкретном облике прямо перед вами в мире на 6 секунд для визуальной проверки.'
};

function createHelpBadge(tipText) {
  const hint = document.createElement('span');
  hint.className = 'help';
  hint.textContent = '?';
  hint.tabIndex = 0;
  hint.dataset.tip = tipText;
  hint.setAttribute('aria-label', tipText);
  return hint;
}
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
      } else if(type==='lootChanceMode') {
        const options=[
          ['fixed','Фиксированный шанс для всех зомби'],
          ['range','Случайный шанс в диапазоне (от и до)']
        ];
        for(const [val,t] of options){const opt=document.createElement('option');opt.value=val;opt.textContent=t;control.append(opt);}
        control.value=draft[key]||'fixed';
      } else if(type==='check') {control.type='checkbox';control.checked=!!draft[key];}
      else {control.type=type;control.value=draft[key];control.required=true;if(type==='number'){control.min=min;control.max=max;control.step=integers.has(key)?'1':'any';}}
      control.onchange=()=>{
        draft[key]=type==='check'?control.checked:type==='number'?Number(control.value):control.value;dirty=true;
        if(type==='profile') {
          const p=data.profiles[draft.profile];
          for(const name of ['health','damage','weaponDamage','speed','sight','hearing','hearingDistance','aggression','attackRange','attackCooldown','reaction','headshotOnly','migration']) draft[name]=p[name];
          if(p.walkStyle) draft.walkStyle=p.walkStyle;
          draft.models=[]; renderFields();renderModels();renderLootItems();
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
  draft.modelOutfits = draft.modelOutfits || {};
  for(const [name,outfits] of Object.entries(data.models)) {
    const card = document.createElement('div');
    card.className = 'model-card';

    const header = document.createElement('div');
    header.className = 'model-header';

    const label = document.createElement('label');
    const check = document.createElement('input');
    check.type = 'checkbox';
    check.checked = draft.models.includes(name);
    check.onchange = () => {
      draft.models = check.checked ? [...draft.models, name] : draft.models.filter(m => m !== name);
      dirty = true;
      if (subpanel) subpanel.style.display = (check.checked && isExpanded) ? 'block' : 'none';
    };
    label.append(check, document.createTextNode(` ${name} (${outfits.length})`));
    header.append(label);

    let subpanel = null;
    let isExpanded = false;

    if (outfits.length > 1) {
      const toggleBtn = document.createElement('button');
      toggleBtn.type = 'button';
      toggleBtn.className = 'outfit-toggle-btn';
      toggleBtn.textContent = '▾ Разновидности';
      header.append(toggleBtn);

      subpanel = document.createElement('div');
      subpanel.className = 'outfit-subpanel';
      subpanel.style.display = 'none';

      toggleBtn.onclick = (e) => {
        e.preventDefault();
        isExpanded = !isExpanded;
        subpanel.style.display = isExpanded ? 'block' : 'none';
        toggleBtn.textContent = isExpanded ? '▴ Скрыть' : '▾ Разновидности';
      };

      const topBar = document.createElement('div');
      topBar.className = 'outfit-actions';

      const selectAllBtn = document.createElement('button');
      selectAllBtn.type = 'button';
      selectAllBtn.className = 'outfit-small-btn';
      selectAllBtn.textContent = 'Выбрать все';

      const clearAllBtn = document.createElement('button');
      clearAllBtn.type = 'button';
      clearAllBtn.className = 'outfit-small-btn';
      clearAllBtn.textContent = 'Снять все';

      const countInfo = document.createElement('small');
      countInfo.className = 'outfit-count-info';

      const updateCount = () => {
        const selected = draft.modelOutfits[name] || [];
        countInfo.textContent = selected.length === 0 ? 'Выбраны: все (по умолч.)' : `Выбрано: ${selected.length} из ${outfits.length}`;
      };
      updateCount();

      const chipsGrid = document.createElement('div');
      chipsGrid.className = 'outfit-chips-grid';

      const renderOutfitChips = () => {
        chipsGrid.replaceChildren();
        const selected = new Set(draft.modelOutfits[name] || []);
        outfits.forEach(o => {
          const chip = document.createElement('div');
          chip.className = `outfit-chip ${selected.has(o) ? 'active' : ''}`;

          const chipCheck = document.createElement('input');
          chipCheck.type = 'checkbox';
          chipCheck.checked = selected.has(o);
          chipCheck.onchange = () => {
            let cur = draft.modelOutfits[name] || [];
            if (chipCheck.checked) {
              if (!cur.includes(o)) cur = [...cur, o];
            } else {
              cur = cur.filter(x => x !== o);
            }
            draft.modelOutfits[name] = cur;
            dirty = true;
            chip.classList.toggle('active', chipCheck.checked);
            updateCount();
          };

          const chipText = document.createElement('span');
          chipText.textContent = `#${o}`;

          const previewBtn = document.createElement('button');
          previewBtn.type = 'button';
          previewBtn.className = 'outfit-preview-btn';
          previewBtn.title = 'Спавн перед вами на 6 секунд для теста';
          previewBtn.textContent = '👁';
          previewBtn.onclick = (e) => {
            e.stopPropagation();
            post('previewOutfit', { model: name, outfit: o }).catch(() => {});
          };

          chip.append(chipCheck, chipText, previewBtn);
          chipsGrid.append(chip);
        });
      };

      selectAllBtn.onclick = (e) => {
        e.preventDefault();
        draft.modelOutfits[name] = [...outfits];
        dirty = true;
        renderOutfitChips();
        updateCount();
      };

      clearAllBtn.onclick = (e) => {
        e.preventDefault();
        draft.modelOutfits[name] = [];
        dirty = true;
        renderOutfitChips();
        updateCount();
      };

      topBar.append(selectAllBtn, clearAllBtn, countInfo);
      subpanel.append(topBar);
      renderOutfitChips();
      subpanel.append(chipsGrid);
    }

    card.append(header);
    if (subpanel) card.append(subpanel);
    $('models').append(card);
  }
}
function renderLootItems() {
  const container = $('lootItemsList');
  if (!container) return;
  container.replaceChildren();
  draft.lootItems = draft.lootItems || [];

  const topActions = document.createElement('div');
  topActions.className = 'loot-top-actions';

  const catalogBtn = document.createElement('button');
  catalogBtn.type = 'button';
  catalogBtn.className = 'loot-catalog-btn';
  catalogBtn.innerHTML = `<span>📦 Выбрать предмет из каталога</span>`;
  catalogBtn.onclick = (e) => {
    e.preventDefault();
    openItemCatalogModal();
  };

  const catalogHelp = createHelpBadge(help.lootCatalogBtn);
  topActions.append(catalogBtn, catalogHelp);
  container.append(topActions);

  const poolWrap = document.createElement('div');
  poolWrap.className = 'loot-pool-container';

  const headerRow = document.createElement('div');
  headerRow.className = 'loot-item-row';
  headerRow.style.fontWeight = 'bold';
  headerRow.style.color = '#8f94a0';
  headerRow.style.background = 'transparent';
  headerRow.style.border = 'none';
  headerRow.style.padding = '0 10px';

  const hName = document.createElement('span');
  hName.className = 'loot-header-cell';
  hName.textContent = 'Предмет';
  hName.append(createHelpBadge(help.lootItemName));

  const hMin = document.createElement('span');
  hMin.className = 'loot-header-cell';
  hMin.textContent = 'Мин.';
  hMin.append(createHelpBadge(help.lootItemMin));

  const hMax = document.createElement('span');
  hMax.className = 'loot-header-cell';
  hMax.textContent = 'Макс.';
  hMax.append(createHelpBadge(help.lootItemMax));

  const hWeight = document.createElement('span');
  hWeight.className = 'loot-header-cell';
  hWeight.textContent = 'Вес';
  hWeight.append(createHelpBadge(help.lootItemWeight));

  const hEmpty = document.createElement('span');

  headerRow.append(hName, hMin, hMax, hWeight, hEmpty);
  poolWrap.append(headerRow);

  draft.lootItems.forEach((it, idx) => {
    const row = document.createElement('div');
    row.className = 'loot-item-row';

    const nameSpan = document.createElement('span');
    nameSpan.textContent = it.label ? `${it.label} (${it.name})` : it.name;

    const minInput = document.createElement('input');
    minInput.type = 'number';
    minInput.min = '1';
    minInput.value = it.minCount || 1;
    minInput.onchange = () => { it.minCount = Math.max(1, Number(minInput.value) || 1); dirty = true; };

    const maxInput = document.createElement('input');
    maxInput.type = 'number';
    maxInput.min = '1';
    maxInput.value = it.maxCount || 1;
    maxInput.onchange = () => { it.maxCount = Math.max(it.minCount, Number(maxInput.value) || 1); dirty = true; };

    const weightInput = document.createElement('input');
    weightInput.type = 'number';
    weightInput.min = '1';
    weightInput.value = it.weight || 10;
    weightInput.onchange = () => { it.weight = Math.max(1, Number(weightInput.value) || 10); dirty = true; };

    const delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.className = 'loot-del-btn';
    delBtn.textContent = '✕';
    delBtn.title = 'Удалить предмет';
    delBtn.onclick = () => {
      draft.lootItems.splice(idx, 1);
      dirty = true;
      renderLootItems();
    };

    row.append(nameSpan, minInput, maxInput, weightInput, delBtn);
    poolWrap.append(row);
  });

  const addRow = document.createElement('div');
  addRow.className = 'loot-add-row';

  const newNameInput = document.createElement('input');
  newNameInput.placeholder = 'ID предмета (напр. bandage)';

  const newMinInput = document.createElement('input');
  newMinInput.type = 'number';
  newMinInput.min = '1';
  newMinInput.value = '1';
  newMinInput.placeholder = 'Мин.';

  const newMaxInput = document.createElement('input');
  newMaxInput.type = 'number';
  newMaxInput.min = '1';
  newMaxInput.value = '1';
  newMaxInput.placeholder = 'Макс.';

  const newWeightInput = document.createElement('input');
  newWeightInput.type = 'number';
  newWeightInput.min = '1';
  newWeightInput.value = '25';
  newWeightInput.placeholder = 'Вес';

  const addBtn = document.createElement('button');
  addBtn.type = 'button';
  addBtn.className = 'outfit-toggle-btn';
  addBtn.textContent = '+ Добавить';
  addBtn.onclick = () => {
    const rawName = newNameInput.value.trim();
    if (!rawName) return;
    draft.lootItems.push({
      name: rawName,
      minCount: Math.max(1, Number(newMinInput.value) || 1),
      maxCount: Math.max(Math.max(1, Number(newMinInput.value) || 1), Number(newMaxInput.value) || 1),
      weight: Math.max(1, Number(newWeightInput.value) || 10)
    });
    dirty = true;
    renderLootItems();
  };

  addRow.append(newNameInput, newMinInput, newMaxInput, newWeightInput, addBtn);
  poolWrap.append(addRow);
  container.append(poolWrap);
}
function preview() { post('preview',draft).catch(()=>{}); }
function select(zone) {
  draft={...clone(data.defaults),...clone(zone)};
  draft.models=draft.models||[];
  draft.modelOutfits=draft.modelOutfits||{};
  draft.lootItems=draft.lootItems||[];
  dirty=false;
  $('empty').hidden=true;$('form').hidden=false;$('zoneTitle').textContent=draft.id?`Зона #${draft.id}`:'Новая зона';
  for(const id of ['teleport','spawn','clear','delete'])$(id).disabled=!draft.id;
  renderFields();renderModels();renderLootItems();renderZones();preview();
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
async function close(){if(dirty&&!await studioConfirm('Закрыть без сохранения?'))return;finishConfirm(false);hideTooltip();await post('close');$('app').hidden=true;document.body.hidden=true;document.body.classList.remove('nui-open');document.documentElement.classList.remove('nui-open');}
$('close').onclick=()=>safe(close);
document.addEventListener('keydown',e=>{if(e.key==='Escape'){e.preventDefault();if(confirmation)finishConfirm(false);else safe(close);}});
document.addEventListener('focusin',e=>{if(['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName))post('setInputFocusState',{hasFocus:true}).catch(()=>{});});
document.addEventListener('focusout',()=>{setTimeout(()=>{post('setInputFocusState',{hasFocus:['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)}).catch(()=>{});},0);});

// --- Floating Unclipped Tooltip Engine ---
const tooltipEl = $('tooltip');
let activeTipTarget = null;

function showTooltip(el, text) {
  if (!tooltipEl || !text) return;
  activeTipTarget = el;
  tooltipEl.textContent = text;
  tooltipEl.hidden = false;

  const rect = el.getBoundingClientRect();
  const tipWidth = 270;

  let left = rect.right + 12;
  let top = rect.top + (rect.height / 2) - 16;

  // If extending past the right screen boundary, flip to the left side of the icon
  if (left + tipWidth > window.innerWidth - 14) {
    left = rect.left - tipWidth - 12;
  }
  if (left < 10) left = 10;

  const tipHeight = tooltipEl.offsetHeight || 44;
  if (top + tipHeight > window.innerHeight - 10) {
    top = window.innerHeight - tipHeight - 10;
  }
  if (top < 10) top = 10;

  tooltipEl.style.left = `${Math.round(left)}px`;
  tooltipEl.style.top = `${Math.round(top)}px`;
  tooltipEl.classList.add('visible');
}

function hideTooltip() {
  if (!tooltipEl) return;
  activeTipTarget = null;
  tooltipEl.classList.remove('visible');
  tooltipEl.hidden = true;
}

document.addEventListener('mouseover', e => {
  const helpEl = e.target.closest('.help[data-tip]');
  if (helpEl) {
    showTooltip(helpEl, helpEl.dataset.tip);
  }
});

document.addEventListener('mouseout', e => {
  const helpEl = e.target.closest('.help[data-tip]');
  if (helpEl && helpEl === activeTipTarget) {
    hideTooltip();
  }
});

document.addEventListener('focusin', e => {
  if (e.target.classList && e.target.classList.contains('help') && e.target.dataset.tip) {
    showTooltip(e.target, e.target.dataset.tip);
  }
});

document.addEventListener('focusout', e => {
  if (e.target.classList && e.target.classList.contains('help')) {
    hideTooltip();
  }
});

document.addEventListener('scroll', () => {
  if (activeTipTarget) hideTooltip();
}, true);

// --- Draggable Menu Header ---
function initDraggableHeader() {
  const header = document.querySelector('header');
  const app = $('app');
  if (!header || !app) return;

  let isDragging = false;
  let startX = 0;
  let startY = 0;
  let startLeft = 0;
  let startTop = 0;

  header.addEventListener('mousedown', e => {
    if (e.button !== 0) return;
    if (e.target.closest('button') || e.target.closest('input') || e.target.closest('a')) return;

    isDragging = true;
    startX = e.clientX;
    startY = e.clientY;

    const rect = app.getBoundingClientRect();
    startLeft = rect.left;
    startTop = rect.top;

    app.style.left = `${startLeft}px`;
    app.style.top = `${startTop}px`;
    app.style.right = 'auto';
    app.style.bottom = 'auto';

    header.style.cursor = 'grabbing';
    document.body.style.userSelect = 'none';
    e.preventDefault();
  });

  window.addEventListener('mousemove', e => {
    if (!isDragging) return;

    const dx = e.clientX - startX;
    const dy = e.clientY - startY;

    const w = app.offsetWidth;
    const h = app.offsetHeight;

    const minLeft = 10;
    const maxLeft = Math.max(10, window.innerWidth - w - 10);
    const minTop = 10;
    const maxTop = Math.max(10, window.innerHeight - 60);

    const newLeft = Math.max(minLeft, Math.min(maxLeft, startLeft + dx));
    const newTop = Math.max(minTop, Math.min(maxTop, startTop + dy));

    app.style.left = `${Math.round(newLeft)}px`;
    app.style.top = `${Math.round(newTop)}px`;
  });

  const stopDrag = () => {
    if (isDragging) {
      isDragging = false;
      header.style.cursor = 'grab';
      document.body.style.userSelect = '';
    }
  };

  window.addEventListener('mouseup', stopDrag);
}
initDraggableHeader();

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


// --- Catalog Modal Logic ---
let itemsCatalog = {};
let activeCatalogCategory = 'all';
let tempCatalogSelected = {};

const RARITY_COLORS = {
  common: { label: 'Обычный', hex: '#94a3b8' },
  white: { label: 'Обычный', hex: '#94a3b8' },
  uncommon: { label: 'Необычный', hex: '#22c55e' },
  green: { label: 'Необычный', hex: '#22c55e' },
  rare: { label: 'Редкий', hex: '#38bdf8' },
  blue: { label: 'Редкий', hex: '#38bdf8' },
  epic: { label: 'Эпический', hex: '#a855f7' },
  purple: { label: 'Эпический', hex: '#a855f7' },
  legendary: { label: 'Легендарный', hex: '#f97316' },
  orange: { label: 'Легендарный', hex: '#f97316' },
  gold: { label: 'Легендарный', hex: '#f97316' }
};

function openItemCatalogModal() {
  if (!draft) return;
  tempCatalogSelected = {};
  (draft.lootItems || []).forEach(it => {
    tempCatalogSelected[it.name] = {
      name: it.name,
      label: it.label || it.name,
      minCount: it.minCount || 1,
      maxCount: it.maxCount || 1,
      weight: it.weight || 25
    };
  });

  const modal = $('itemCatalogModal');
  if (!modal) return;
  modal.hidden = false;

  buildCatalogCategories();
  renderCatalogItemsGrid();
  updateCatalogCount();

  const searchInput = $('catalogSearchInput');
  if (searchInput) {
    searchInput.value = '';
    searchInput.focus();
  }
}

function closeItemCatalogModal() {
  const modal = $('itemCatalogModal');
  if (modal) modal.hidden = true;
}

function buildCatalogCategories() {
  const tabs = $('catalogCategoryTabs');
  if (!tabs) return;
  const categories = {
    all: 'Все предметы',
    food: 'Еда и напитки',
    medical: 'Медицина',
    material: 'Материалы',
    survival: 'Выживание',
    melee: 'Холодное',
    gun: 'Огнестрельное',
    storage: 'Хранение',
    item: 'Разное'
  };

  tabs.replaceChildren();
  for (const [k, label] of Object.entries(categories)) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `cat-tab-btn ${k === activeCatalogCategory ? 'active' : ''}`;
    btn.textContent = label;
    btn.onclick = () => {
      activeCatalogCategory = k;
      buildCatalogCategories();
      renderCatalogItemsGrid();
    };
    tabs.append(btn);
  }
}

function updateCatalogCount() {
  const countEl = $('catalogModalSelectedCount');
  if (countEl) countEl.textContent = Object.keys(tempCatalogSelected).length;
}

function renderCatalogItemsGrid() {
  const grid = $('catalogItemsGrid');
  if (!grid) return;
  grid.replaceChildren();

  const search = ($('catalogSearchInput')?.value || '').toLowerCase().trim();
  let displayed = 0;

  for (const [name, it] of Object.entries(itemsCatalog)) {
    const cat = it.category || 'item';
    if (activeCatalogCategory !== 'all' && cat !== activeCatalogCategory) continue;

    const label = (it.label || name).toLowerCase();
    if (search && !label.includes(search) && !name.toLowerCase().includes(search)) continue;

    displayed++;
    const isSelected = !!tempCatalogSelected[name];
    const card = document.createElement('div');
    card.className = `catalog-item-card ${isSelected ? 'selected' : ''}`;

    const rarityKey = (it.rarity || 'common').toLowerCase();
    const rarity = RARITY_COLORS[rarityKey] || RARITY_COLORS.common;

    const top = document.createElement('div');
    top.className = 'catalog-item-top';
    const rBadge = document.createElement('span');
    rBadge.className = 'item-rarity-badge';
    rBadge.style.color = rarity.hex;
    rBadge.textContent = rarity.label;

    const checkInd = document.createElement('div');
    checkInd.className = 'item-check-indicator';
    checkInd.textContent = isSelected ? '✓' : '';
    top.append(rBadge, checkInd);

    const iconBox = document.createElement('div');
    iconBox.className = 'catalog-item-icon-box';
    const img = document.createElement('img');
    img.src = `https://cfx-nui-thehunt_inventory/html/images/${name}.png`;
    img.alt = it.label || name;
    img.onerror = () => {
      img.style.display = 'none';
      iconBox.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="${rarity.hex}" stroke-width="1.8" style="width:28px;height:28px"><rect x="3" y="3" width="18" height="18" rx="3"/><path d="M12 8v8M8 12h8"/></svg>`;
    };
    iconBox.append(img);

    const title = document.createElement('div');
    title.className = 'catalog-item-name';
    title.textContent = it.label || name;
    title.title = `${it.label || name} (${name})`;

    const desc = document.createElement('div');
    desc.className = 'catalog-item-desc';
    desc.textContent = it.description || 'Описание отсутствует.';

    const meta = document.createElement('div');
    meta.className = 'catalog-item-meta';
    meta.innerHTML = `<span>Вес: ${it.weight != null ? it.weight : 0.1} кг</span><span>ID: ${name}</span>`;

    card.append(top, iconBox, title, desc, meta);
    card.onclick = () => {
      if (tempCatalogSelected[name]) {
        delete tempCatalogSelected[name];
      } else {
        tempCatalogSelected[name] = {
          name: name,
          label: it.label || name,
          minCount: 1,
          maxCount: 1,
          weight: 25
        };
      }
      updateCatalogCount();
      renderCatalogItemsGrid();
    };

    grid.append(card);
  }

  if (displayed === 0) {
    const empty = document.createElement('div');
    empty.style.gridColumn = '1/-1';
    empty.style.textAlign = 'center';
    empty.style.color = '#8f94a0';
    empty.style.padding = '40px';
    empty.textContent = 'Предметы не найдены';
    grid.append(empty);
  }
}

function applyCatalogSelection() {
  if (!draft) return;
  const existingMap = {};
  (draft.lootItems || []).forEach(it => { existingMap[it.name] = it; });

  const newLootItems = [];
  for (const [name, sel] of Object.entries(tempCatalogSelected)) {
    if (existingMap[name]) {
      newLootItems.push(existingMap[name]);
    } else {
      newLootItems.push({
        name: name,
        label: sel.label || name,
        minCount: sel.minCount || 1,
        maxCount: sel.maxCount || 1,
        weight: sel.weight || 25
      });
    }
  }

  draft.lootItems = newLootItems;
  dirty = true;
  closeItemCatalogModal();
  renderLootItems();
}

if ($('closeCatalogModalBtn')) $('closeCatalogModalBtn').onclick = closeItemCatalogModal;
if ($('cancelCatalogBtn')) $('cancelCatalogBtn').onclick = closeItemCatalogModal;
if ($('applyCatalogBtn')) $('applyCatalogBtn').onclick = applyCatalogSelection;
if ($('catalogSearchInput')) $('catalogSearchInput').oninput = () => renderCatalogItemsGrid();
if ($('itemCatalogModal')) $('itemCatalogModal').onclick = e => { if (e.target === $('itemCatalogModal')) closeItemCatalogModal(); };

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
  if(msg.action==='open'){document.body.hidden=false;document.documentElement.classList.add('nui-open');document.body.classList.add('nui-open');data=msg.data;position=msg.position;itemsCatalog=msg.catalog||{};draft=null;dirty=false;busy=false;$('app').hidden=false;$('form').hidden=true;$('empty').hidden=false;refreshStatus();renderZones();message('Выберите зону. Синее кольцо — зона, зелёное — появление.');}
  if(msg.action==='close'){hideTooltip();$('app').hidden=true;document.body.hidden=true;document.body.classList.remove('nui-open');document.documentElement.classList.remove('nui-open');finishConfirm(false);}
  if(msg.action==='gizmoZone'&&draft){document.body.hidden=false;document.documentElement.classList.add('nui-open');document.body.classList.add('nui-open');$('app').hidden=false;Object.assign(draft,msg.zone);dirty=true;renderFields();preview();message('Положение, размер и поворот изменены gizmo. Сохраните зону.');}
});
