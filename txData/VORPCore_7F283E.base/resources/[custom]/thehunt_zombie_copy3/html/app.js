'use strict';
const $ = id => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'thehunt_zombie';
let data = null, draft = null, position = null, dirty = false, busy = false, confirmation = null, liveRefreshing = false;
const groups = [
  ['Зона и население', [
    ['name','Название','text'], ['profile','Профиль','profile'], ['enabled','Зона включена','check'],
    ['x','X','number',-20000,20000],['y','Y','number',-20000,20000],['z','Z','number',-1000,3000],
    ['radius','Радиус зоны, м','number',0,null],['activation','Активация, м','number',0,null],['spawnRadius','Радиус появления, м','number',0,null],
    ['count','Количество','number',0,40],['minCount','Минимум','number',0,40],['maxCount','Максимум','number',1,40],
    ['randomCount','Случайное количество','check'],['randomModel','Случайная модель','check'],['bucket','Измерение','number',0,65535],
    ['respawn','Респавн после смерти, с','number',5,86400],['replenish','Восстановление после миграции, с','number',1,3600]
  ]],
  ['Поведение и атака', [
    ['walkStyle','Стиль походки','walkStyle'],
    ['health','Здоровье','number',100,3000],['damage','Урон','number',0,100],['speed','Темп движения (0.3–3)','number',0.3,3],
    ['sight','Зрение, м','number',1,150],['hearingDistance','Слух, м','number',1,500],['hearing','Множитель слуха','number',0.1,3],['aggression','Агрессия (0 — выкл.)','number',0,3],
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
          ['MP_Style_Crazy','Безумная (дёрганая)'],
          ['MP_Style_SilentType','Скрытная (крадущаяся)'],
          ['MP_Style_EasyRider','Вразвалку (раскачивающаяся)'],
          ['MP_Style_Veteran','Тяжёлая (медленный шаг)'],
          ['MP_Style_Greenhorn','Шаткая (неуверенная)'],
          ['MP_Style_Casual','Обычная (человеческая)'],
          ['MP_Style_Gunslinger','Агрессивная (напряжённая)'],
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
window.addEventListener('message',({data:msg})=>{
  if(msg.action==='open'){document.body.hidden=false;document.documentElement.classList.add('nui-open');document.body.classList.add('nui-open');data=msg.data;position=msg.position;draft=null;dirty=false;busy=false;$('app').hidden=false;$('form').hidden=true;$('empty').hidden=false;refreshStatus();renderZones();message('Выберите зону. Синее кольцо — зона, зелёное — появление.');}
  if(msg.action==='close'){$('app').hidden=true;document.body.hidden=true;document.body.classList.remove('nui-open');document.documentElement.classList.remove('nui-open');finishConfirm(false);}
});
