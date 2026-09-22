const $=id=>document.getElementById(id), clone=x=>JSON.parse(JSON.stringify(x));
let models=[],rows=[],owner='',mode='catalog',data=null,selected=null,spawned=[],locked=false;
let page=0,more=false,playerMode='online',players=[],history=[],historyIndex=-1,favorites=[];
try{favorites=JSON.parse(localStorage.getItem('hunt-ped-favorites')||'[]');if(!Array.isArray(favorites))favorites=[];}catch{}
const classes={human:'Человек',predator:'Хищник',animal:'Животное',bird:'Птица',horse:'Лошадь',aquatic:'Водное'};
function getClassification(model){
 const m=(model||'').toLowerCase().replace(/^mp_a_c_/,'a_c_');
 if(!m.startsWith('a_c_'))return 'human';
 if(/horse|donkey|mule/.test(m))return 'horse';
 if(/fish|shark|crab|crawfish|turtle/.test(m))return 'aquatic';
 if(/eagle|hawk|owl|raven|vulture|duck|seagull|crow|pigeon|pelican|cormorant|crane|egret|heron|loon|pheasant|quail|robin|rooster|spoonbill|songbird|sparrow|turkey|woodpecker|cardinal|bluejay|waxwing|bat|parakeet|goose|prairiechicken|booby|condor|oriole|parrot/.test(m))return 'bird';
 if(/bear|wolf|cougar|panther|alligator|coyote|dog|fox|boar|lion|bull|buffalo|buck|ram/.test(m))return 'predator';
 return 'animal';
}
fetch('../data/models.json').then(r=>r.json()).then(x=>{models=x;render();}).catch(()=>{$('status').textContent='Не удалось загрузить каталог.';});
async function call(action,args={}){
 const response=await fetch(`https://${GetParentResourceName()}/action`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,args})});
 const result=await response.json();if(!result.ok)throw Error(result.error||'Действие не выполнено');return result.data;
}
async function run(fn){if(locked)return;locked=true;$('studio').setAttribute('aria-busy','true');$('status').textContent='Выполняется…';try{await fn();$('status').textContent='Готово';}catch(e){$('status').textContent=e.message;}finally{locked=false;$('studio').removeAttribute('aria-busy');}}
function permissions(){$('update').disabled=!selected||selected.owner!==owner;$('delete').disabled=!selected||selected.owner!==owner;$('duplicate').disabled=!selected;}
function library(result){
 const recovery=$('equipmentRecovery');if(recovery)recovery.hidden=!result.equipmentRecovery;
 rows=result.rows||[];owner=result.owner;const previous=$('author').value;
 $('author').replaceChildren(new Option('Все администраторы',''),new Option('Только мои',owner));
 for(const [id,name] of new Map(rows.map(r=>[r.owner,r.author])))if(id!==owner)$('author').add(new Option(name,id));
 $('author').value=previous;if(result.spawned)spawned=result.spawned;renderSpawn();render();permissions();
}
function detail(name){document.querySelectorAll('[data-panel]').forEach(el=>el.hidden=el.dataset.panel!==name);document.querySelectorAll('[data-detail]').forEach(el=>el.classList.toggle('active',el.dataset.detail===name));}
function layout(){
 const auxiliary=mode==='npc'||mode==='help';$('editor').hidden=auxiliary||!data;$('empty').hidden=auxiliary||!!data;
 $('npcPanel').hidden=mode!=='npc';$('helpPanel').hidden=mode!=='help';$('browserControls').hidden=auxiliary;$('list').hidden=auxiliary;$('pagination').hidden=auxiliary;
 $('category').hidden=!['catalog','favorites'].includes(mode);$('author').hidden=mode!=='library';$('playerControls').hidden=mode!=='players';
 $('search').placeholder=mode==='players'?'Имя или ID персонажа…':'Модель, название или автор…';
 document.querySelectorAll('[data-mode]').forEach(el=>el.classList.toggle('active',el.dataset.mode===mode));
}
async function navigate(next){mode=next;page=0;$('search').value='';layout();if(mode==='library'||mode==='npc')library(await call('list'));if(mode==='players')await fetchPlayers();render();}
function render(){
 layout();const q=$('search').value.toLowerCase().trim();let items;
 if(mode==='players')items=playerMode==='online'?players.filter(r=>`${r.name} ${r.id} ${r.characterName}`.toLowerCase().includes(q)):players;
 else{
  items=(mode==='library'?rows:models).filter(r=>`${r.model} ${r.name||''} ${r.author||''}`.toLowerCase().includes(q));
  if(mode==='library'&&$('author').value)items=items.filter(r=>r.owner===$('author').value);
  if(mode==='favorites')items=items.filter(r=>favorites.includes(r.model));
  if(['catalog','favorites'].includes(mode)&&$('category').value){const cat=$('category').value;items=items.filter(r=>cat==='spirit'?!!r.spiritOutfits?.length:getClassification(r.model)===cat);}
 }
 const remote=mode==='players'&&playerMode==='offline',maxPage=Math.max(0,Math.ceil(items.length/80)-1);if(!remote)page=Math.min(page,maxPage);
 $('matchCount').textContent=remote?`Страница ${page+1} · ${items.length} персонажей`:`Найдено: ${items.length}`;
 $('pageNumber').textContent=page+1;$('prev').disabled=page===0;$('next').disabled=remote?!more:page>=maxPage;$('list').replaceChildren();
 for(const item of remote?items:items.slice(page*80,page*80+80)){
  const b=document.createElement('button');b.className='list-item';const title=document.createElement('span'),sub=document.createElement('span');title.className='list-title';sub.className='list-sub';
  if(mode==='players'){title.textContent=playerMode==='online'?`#${item.id} · ${item.name}`:`${item.firstname||''} ${item.lastname||''}`;sub.textContent=playerMode==='online'?`${item.characterName} · персонаж #${item.characterId||'—'}`:`Персонаж #${item.id} · ${item.gender==='Female'?'Женщина':'Мужчина'}`;}
  else if(mode==='library'){title.textContent=item.name;sub.textContent=`${item.author} · ${item.model}`;}
  else{title.textContent=item.label||item.model;sub.textContent=`${classes[getClassification(item.model)]} · ${item.outfits} вариантов${item.spiritOutfits?.length?' · призрачная форма':''}`;}
  // Untrusted names are always text, never HTML.
  b.append(title,sub);if(mode==='library'?selected?.id===item.id:data?.model===item.model)b.classList.add('selected');
  b.onclick=()=>run(async()=>{
   if(mode==='players'){const value=await call(playerMode==='online'?'copyPlayer':'copyCharacter',{id:item.id});selected=null;show(value,title.textContent);}
   else if(mode==='library'){const row=await call('get',{id:item.id});selected=row;show(row.data,row.name);}
   else{selected=null;show({model:item.model,outfit:0,spirit:$('category').value==='spirit',scale:1,health:200,collision:true,ragdoll:true,frozen:false},'');}render();
  });$('list').append(b);
 }
 if(!items.length){const p=document.createElement('p');p.className='hint';p.textContent=mode==='favorites'?'Добавьте модели кнопкой ☆ у выбранного облика.':'Ничего не найдено. Измените поиск или категорию.';$('list').append(p);}
}
function remember(){if(!data)return;const value={data:clone(data),name:$('name').value};if(historyIndex>=0&&JSON.stringify(history[historyIndex])===JSON.stringify(value))return;history=history.slice(0,historyIndex+1);history.push(value);if(history.length>30)history.shift();historyIndex=history.length-1;historyButtons();}
function historyButtons(){$('undo').disabled=historyIndex<=0;$('redo').disabled=historyIndex>=history.length-1;}
function show(value,name='',record=true){
 data=clone(value);$('title').textContent=data.model;$('name').value=name;
 const info=models.find(m=>m.model===data.model),max=Math.max(0,(info?.outfits||1)-1);
 for(const key of ['outfit','scale','health'])$(key).value=data[key]??(key==='scale'?1:key==='health'?200:0);
 for(const key of ['invincible','frozen','collision','ragdoll'])$(key).checked=data[key]??['collision','ragdoll'].includes(key);
 $('behavior').value=data.behavior||'idle';$('outfit').max=max;$('outfitRange').max=max;for(const key of ['scale','outfit'])syncSlider(key);
 $('sourceLabel').textContent=data.sourceLabel||'Самостоятельный черновик';const editable=['mp_male','mp_female'].includes(data.model),cls=getClassification(data.model);
 $('edit').disabled=!editable;$('edit').textContent=editable&&data.appearance?'Редактор выбранного персонажа':'Редактор персонажа';
 $('outfitHint').textContent=data.appearance?'У этого облика есть лицо и одежда персонажа. Для изменения используйте редактор ниже.':`Варианты Rockstar: 0–${max}.`;
 $('outfit').disabled=$('outfitRange').disabled=!!data.appearance;
 $('modelGuide').textContent=editable?(data.appearance?'Откроется лицо, тело и одежда выбранной копии. Исходный игрок не изменится.':'Новая MP-модель: редактор создаст базовую внешность для выбранного пола.'):cls==='bird'?'Пробел — взлёт; мышь — курс; Ctrl — посадка на открытую сушу.':cls==='human'?'Готовая NPC-модель: варианты и палитры. Полный редактор лица доступен только MP-моделям.':'ЛКМ / F — нативная атака по цели впереди. Движок выбирает доступные этому виду движения.';
 $('badges').replaceChildren();for(const text of [classes[cls],editable?'Редактируемый персонаж':`${info?.outfits||1} вариантов`,...(data.spirit?['Призрачный вариант Rockstar']:[])]){const el=document.createElement('span');el.className='badge';el.textContent=text;$('badges').append(el);}
 $('favorite').textContent=favorites.includes(data.model)?'★':'☆';renderTags();permissions();layout();if(record)remember();historyButtons();
}
function read(){
 if(!data)throw Error('Сначала выберите облик');
 for(const key of ['outfit','scale','health']){if(!$(key).checkValidity())throw Error(`Проверьте поле: ${key}`);data[key]=Number($(key).value);}
 for(const key of ['invincible','frozen','collision','ragdoll'])data[key]=$(key).checked;data.behavior=$('behavior').value;
 if(data.appearance){data.appearance.skin=data.appearance.skin||{};data.appearance.skin.Scale=data.scale;}return clone(data);
}
function syncSlider(key){$(key+'Range').value=$(key).value;$(key+'Val').textContent=key==='scale'?`${Number($(key).value).toFixed(2)}×`:$(key).value;}
function renderTags(){$('component').replaceChildren(...(data?.tags||[]).map((t,i)=>new Option(`${i+1} · ${t.drawable}`,i)));loadTag();}
function loadTag(){const t=data?.tags?.[Number($('component').value)];for(const k of ['palette','tint0','tint1','tint2'])$(k).value=t?.[k]||0;}
function renderSpawn(){$('spawned').replaceChildren(...spawned.map(s=>new Option(`${s.model} · #${s.net}`,s.net)));$('npcCount').textContent=spawned.length;}
function selectedNet(){const net=Number($('spawned').value);if(!net)throw Error('Выберите NPC в списке');return net;}
async function fetchPlayers(){if(playerMode==='online'){players=await call('players');more=false;}else{const result=await call('characters',{query:$('search').value,page});players=result.rows;more=result.more;}render();}
function studioConfirm(question){return new Promise(resolve=>{
 $('question').textContent=question;const dialog=$('confirm');dialog.showModal();syncFocus();let done=false;
 const finish=value=>{if(done)return;done=true;dialog.close();syncFocus();resolve(value);};$('yes').onclick=()=>finish(true);$('no').onclick=()=>finish(false);dialog.oncancel=e=>{e.preventDefault();finish(false);};
 dialog.onclick=e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)finish(false);}};
});}
for(const el of document.querySelectorAll('[data-mode]'))el.onclick=()=>run(()=>navigate(el.dataset.mode));
for(const el of document.querySelectorAll('[data-detail]'))el.onclick=()=>detail(el.dataset.detail);
$('search').oninput=()=>{if(mode==='players'&&playerMode==='offline')return;page=0;render();};
$('search').onkeydown=e=>{if(e.key==='Enter'&&mode==='players')run(async()=>{page=0;await fetchPlayers();});};
for(const id of ['category','author'])$(id).onchange=()=>{page=0;render();};
$('refresh').onclick=()=>run(async()=>{if(mode==='players')await fetchPlayers();else library(await call('list'));});
for(const id of ['online','offline'])$(id).onclick=()=>run(async()=>{playerMode=id;page=0;$('online').classList.toggle('active',id==='online');$('offline').classList.toggle('active',id==='offline');await fetchPlayers();});
$('findPlayers').onclick=()=>run(async()=>{page=0;await fetchPlayers();});
for(const [id,delta] of [['prev',-1],['next',1]])$(id).onclick=()=>run(async()=>{page=Math.max(0,page+delta);if(mode==='players'&&playerMode==='offline')await fetchPlayers();else render();});
$('capture').onclick=()=>run(async()=>{selected=null;const result=await call('capture');if(['npc','help'].includes(mode))mode='catalog';show(result);render();});
for(const id of ['apply','applyKeepOpen'])$(id).onclick=()=>run(async()=>{const d=read();d.frozen=false;await call(id,{data:d});remember();});
$('edit').onclick=()=>run(()=>call('edit',{data:read()}));
$('spawn').onclick=()=>run(async()=>{const result=await call('spawn',{data:read()});spawned=result.spawned;renderSpawn();});
$('save').onclick=()=>run(async()=>{library(await call('save',{name:$('name').value.trim()||data?.model,data:read()}));selected=null;permissions();});
$('update').onclick=()=>run(async()=>{if(selected&&await studioConfirm('Перезаписать выбранный пресет?')){library(await call('save',{id:selected.id,revision:selected.revision,name:$('name').value,data:read()}));selected=null;permissions();}});
$('duplicate').onclick=()=>run(async()=>{if(selected)library(await call('duplicate',{id:selected.id}));});
$('delete').onclick=()=>run(async()=>{if(selected&&await studioConfirm('Удалить выбранный пресет?')){library(await call('delete',{id:selected.id,revision:selected.revision}));selected=null;permissions();}});
$('favorite').onclick=()=>run(async()=>{if(!data)return;favorites=favorites.includes(data.model)?favorites.filter(m=>m!==data.model):[...favorites,data.model];localStorage.setItem('hunt-ped-favorites',JSON.stringify(favorites));$('favorite').textContent=favorites.includes(data.model)?'★':'☆';render();});
for(const [id,delta] of [['undo',-1],['redo',1]])$(id).onclick=()=>{if(locked)return;const index=historyIndex+delta;if(!history[index])return;historyIndex=index;selected=null;show(history[index].data,history[index].name,false);};
for(const key of ['scale','outfit']){$(key+'Range').oninput=()=>{if(locked)return;$(key).value=$(key+'Range').value;syncSlider(key);};$(key).oninput=()=>syncSlider(key);}
for(const id of ['name','scale','scaleRange','outfit','outfitRange','health','invincible','frozen','collision','ragdoll','behavior'])$(id).addEventListener('change',()=>{if(!data||locked)return;try{if(id.startsWith('outfit'))data.tags=null;read();remember();}catch(e){$('status').textContent=e.message;}});
$('readTags').onclick=()=>run(async()=>{data.tags=await call('tags',{model:read().model});renderTags();remember();});$('component').onchange=loadTag;
$('setTag').onclick=()=>run(async()=>{const tag=data?.tags?.[Number($('component').value)];if(!tag)throw Error('Сначала прочитайте компоненты');for(const k of ['palette','tint0','tint1','tint2']){if(!$(k).checkValidity())throw Error('Проверьте значения цвета');tag[k]=Number($(k).value);}remember();});
$('export').onclick=()=>run(async()=>{$('presetJson').value=JSON.stringify({version:1,name:$('name').value,data:read()},null,2);$('presetJson').focus();$('presetJson').select();});
$('import').onclick=()=>run(async()=>{const parsed=JSON.parse($('presetJson').value);if(parsed.version!==1)throw Error('Неизвестная версия пресета');const d=await call('validate',{data:parsed.data});selected=null;show(d,typeof parsed.name==='string'?parsed.name:'');});
$('loadSpawn').onclick=()=>run(async()=>{const result=await call('getSpawn',{net:selectedNet()});selected=null;mode='catalog';show(result);render();});
$('teleportSpawn').onclick=()=>run(()=>call('teleportSpawn',{net:selectedNet()}));
$('updateSpawn').onclick=()=>run(async()=>{if(await studioConfirm('Применить выбранный черновик к этому NPC?'))await call('updateSpawn',{net:selectedNet(),data:read()});});
$('removeSpawn').onclick=()=>run(async()=>{const net=selectedNet();if(await studioConfirm('Удалить выбранного NPC?')){await call('removeSpawn',{net});spawned=spawned.filter(s=>s.net!==net);renderSpawn();}});
$('removeAllSpawn').onclick=()=>run(async()=>{if(spawned.length&&await studioConfirm(`Удалить всех ваших NPC (${spawned.length})?`)){await call('removeAllSpawn');spawned=[];renderSpawn();}});
$('diagnostics').onclick=()=>run(async()=>{$('diagnosticResult').textContent=JSON.stringify(await call('diagnostics'),null,2);});
for(const b of document.querySelectorAll('[data-action]'))b.onclick=()=>run(()=>call(b.dataset.action));
function syncFocus(){fetch(`https://${GetParentResourceName()}/setInputFocusState`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({hasFocus:$('confirm').open||!!document.activeElement?.matches('input,textarea,select')})}).catch(()=>{});}
for(const event of ['focusin','focusout'])document.addEventListener(event,()=>setTimeout(syncFocus,0));
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('confirm').open)run(()=>call('close'));});
let drag=null;
$('studioHeader').onpointerdown=e=>{if(e.target.closest('button'))return;const r=$('studio').getBoundingClientRect();drag={x:e.clientX-r.left,y:e.clientY-r.top};$('studioHeader').setPointerCapture(e.pointerId);};
$('studioHeader').onpointermove=e=>{if(!drag)return;const el=$('studio'),r=el.getBoundingClientRect();el.style.left=`${Math.max(0,Math.min(innerWidth-r.width,e.clientX-drag.x))}px`;el.style.top=`${Math.max(0,Math.min(innerHeight-r.height,e.clientY-drag.y))}px`;el.style.right='auto';};
$('studioHeader').onpointerup=()=>drag=null;
$('studioHeader').ondblclick=()=>{$('studio').style.left='';$('studio').style.top='';$('studio').style.right='';};
window.addEventListener('resize',()=>{$('studio').style.left='';$('studio').style.top='';$('studio').style.right='';});
window.addEventListener('message',({data:message})=>{
 if(message.action==='open'){$('studio').hidden=false;$('animalHint').hidden=true;}
 if(message.action==='close'){$('studio').hidden=true;if($('confirm').open)$('no').click();document.activeElement?.blur();}
 if(message.action==='library'){library(message.data);spawned=message.spawned||[];renderSpawn();if(message.draft)show(message.draft);}
 if(message.action==='draft'){selected=null;if(message.data)show(message.data);else{data=null;layout();}}
 if(message.action==='animalHint'){$('animalHint').textContent=message.text||'';$('animalHint').hidden=!message.text||!$('studio').hidden;}
});

window.addEventListener('message',async({data:message})=>{
 if(message.action==='confirmationExpired'&&$('confirm').open){$('no').click();return;}
 if(message.action!=='equipmentConfirm')return;
 const accepted=await studioConfirm(message.message);
 await fetch(`https://${GetParentResourceName()}/equipmentConfirm`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({accepted})});
});
