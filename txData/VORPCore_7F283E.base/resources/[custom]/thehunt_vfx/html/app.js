'use strict';
const $=id=>document.getElementById(id);
let pendingConfirm=null;
const confirmOverlay=document.createElement('div');
confirmOverlay.hidden=true;confirmOverlay.id='vfxConfirm';
confirmOverlay.style.cssText='position:fixed;inset:0;z-index:1000;display:grid;place-items:center;background:rgba(0,0,0,.55)';
confirmOverlay.innerHTML='<section role="dialog" aria-modal="true" aria-labelledby="confirmTitle" aria-describedby="confirmText" style="width:min(440px,90vw);padding:24px;background:#101014;border:1px solid rgba(255,255,255,.22);border-radius:10px;box-shadow:0 16px 60px #0008"><h2 id="confirmTitle">Подтверждение</h2><p id="confirmText" style="white-space:pre-wrap;overflow-wrap:anywhere"></p><div class="row"><button id="confirmCancel">Отмена</button><button id="confirmAccept" class="primary">Подтвердить</button></div></section>';
document.body.append(confirmOverlay);
function finishConfirm(value){
 if(!pendingConfirm)return;
 const {resolve,focus}=pendingConfirm;pendingConfirm=null;confirmOverlay.hidden=true;
 if(focus?.isConnected)focus.focus();
 call('focus',{value:document.activeElement.matches('input,textarea,select')});resolve(value);
}
function studioConfirm(text){
 if(pendingConfirm)return Promise.resolve(false);
 return new Promise(resolve=>{pendingConfirm={resolve,focus:document.activeElement};$('confirmText').textContent=text;confirmOverlay.hidden=false;$('confirmCancel').focus();call('focus',{value:true});});
}
$('confirmCancel').onclick=()=>finishConfirm(false);$('confirmAccept').onclick=()=>finishConfirm(true);
confirmOverlay.onclick=e=>{if(e.target===confirmOverlay)finishConfirm(false);};
document.addEventListener('keydown',e=>{
 if(!pendingConfirm)return;
 e.stopImmediatePropagation();
 if(e.key==='Escape'){e.preventDefault();finishConfirm(false);}
 if(e.key==='Tab'){e.preventDefault();(document.activeElement===$('confirmCancel')?$('confirmAccept'):$('confirmCancel')).focus();}
},true);
document.addEventListener('focusin',e=>{if(pendingConfirm&&!confirmOverlay.contains(e.target))$('confirmCancel').focus();},true);
window.addEventListener('message',e=>{if(e.data?.action==='close')finishConfirm(false);});
let catalog=[],selected=null,world=[],presets={},reviews={},page=0,tab='library';
let selectedWorld=null;
let selectedComposition=null;
let ownId=null;
const motionPanel=document.createElement('details');motionPanel.innerHTML='<summary>Движение и плавные переходы</summary><label><input id="animate" type="checkbox"> Анимировать слой</label><label>Траектория<select id="motion"><option value="static">На месте</option><option value="orbit">Орбита XY</option><option value="linear">Прямая</option></select></label>';
for(const [id,label,value] of [['radius','Радиус орбиты',1],['speed','Орбита, градусов/сек',90],['vx','Скорость X, м/сек',0],['vy','Скорость Y, м/сек',0],['vz','Скорость Z, м/сек',0],['sx','Вращение X, градусов/сек',0],['sy','Вращение Y, градусов/сек',0],['sz','Вращение Z, градусов/сек',0],['fadeIn','Появление, сек',0],['fadeOut','Затухание, сек',0],['endScale','Конечный масштаб',1]]){const labelNode=document.createElement('label');labelNode.textContent=label;const input=document.createElement('input');input.type='number';input.step='.1';input.id=id;input.value=value;labelNode.append(input);motionPanel.append(labelNode);}
document.querySelector('aside').insertBefore(motionPanel,$('preview').parentElement);
let layers=[];
let editingLayer=null;
let history=[JSON.stringify({duration:10,phases:[]})],historyIndex=0,restoring=false;
const compositionNav=document.createElement('button');compositionNav.dataset.tab='composition';compositionNav.textContent='Композиция';document.querySelector('nav').append(compositionNav);
const networkComposition=document.createElement('button');networkComposition.textContent='Запустить композицию для игроков';networkComposition.onclick=()=>action('spawnComposition',{definition:definition(),coords:params().coords,self:$('placement').value==='self',targetServerId:params().targetServerId});$('composition').append(networkComposition);
const stopComposition=document.createElement('button');stopComposition.textContent='Остановить мои композиции';stopComposition.onclick=()=>{call('stopPreview');action('stopCompositions',{});};$('composition').append(stopComposition);
function definition(){return {duration:num('compositionDuration'),phases:layers};}
const ringButton=document.createElement('button');ringButton.textContent='Кольцо из 8 выбранных эффектов';ringButton.onclick=()=>{
 if(!selected||!['loop','burst','light'].includes(selected.kind))return status('Выберите частицы или свет',false);
 if(layers.length+8>24)return status('Максимум 24 слоя',false);
 const radius=Math.max(.1,num('radius'));
 for(let i=0;i<8;i++){const p=params(),angle=i*Math.PI/4;p.offset={x:p.offset.x+Math.cos(angle)*radius,y:p.offset.y+Math.sin(angle)*radius,z:p.offset.z};layers.push({at:0,effectId:selected.id,params:p});}renderLayers();
};$('composition').append(ringButton);
const feetButton=document.createElement('button');feetButton.textContent='Пара слоёв на ступнях';feetButton.onclick=()=>{
 if(!selected||!['loop','burst','light'].includes(selected.kind))return status('Выберите частицы или свет',false);
 if(layers.length+2>24)return status('Максимум 24 слоя',false);
 for(const bone of ['SKEL_L_Foot','SKEL_R_Foot']){const p=params();p.attach=true;p.bone=bone;layers.push({at:0,effectId:selected.id,params:p});}$('placement').value='self';renderLayers();
};$('composition').append(feetButton);
function renderLayers(){
 if(!restoring){const state=JSON.stringify(definition());if(history[historyIndex]!==state){history=history.slice(0,historyIndex+1);history.push(state);if(history.length>50)history.shift();historyIndex=history.length-1;}}
 $('layers').replaceChildren();
 layers.forEach((layer,index)=>{
 const row=document.createElement('div');row.className='entry';
 row.append(button(layer.enabled===false?'Включить слой':'Выключить слой',()=>{layer.enabled=layer.enabled===false;renderLayers();}));
 const title=document.createElement('div');title.textContent=(index+1)+'. '+(catalog.find(e=>e.id===layer.effectId)?.name||layer.effectId);row.append(title);
 const timeline=document.createElement('div');timeline.style.cssText='height:8px;background:#22252b;margin:8px 0;overflow:hidden';const bar=document.createElement('div');const duration=Math.max(.1,num('compositionDuration'));bar.style.cssText='height:100%;background:#38bdf8';bar.style.marginLeft=Math.min(100,layer.at/duration*100)+'%';bar.style.width=Math.max(0,Math.min(duration-layer.at,layer.params.lifetime||duration)/duration*100)+'%';timeline.append(bar);row.append(timeline);
 const label=document.createElement('label');label.textContent='Начало, секунды';const input=document.createElement('input');input.type='number';input.min='0';input.step='.1';input.value=layer.at;input.oninput=()=>layer.at=Number(input.value)||0;input.onchange=renderLayers;label.append(input);row.append(label);
 row.classList.toggle('editing-layer',editingLayer===layer);
 row.append(button('Редактировать справа',()=>{choose(catalog.find(e=>e.id===layer.effectId));load(layer.params);editingLayer=layer;renderLayers();status('Редактируется слой '+(index+1)+'. После настройки нажмите «Применить к слою».');}),button('Применить к слою',()=>{if(selected){Object.assign(layer,{effectId:selected.id,params:params()});editingLayer=layer;renderLayers();status('Параметры слоя '+(index+1)+' применены');}}),button('Дублировать',()=>{if(layers.length>=24)return status('Максимум 24 слоя',false);layers.splice(index+1,0,JSON.parse(JSON.stringify(layer)));renderLayers();}),button('Удалить слой',()=>{if(editingLayer===layer)editingLayer=null;layers.splice(index,1);renderLayers();}));
 $('layers').append(row);
 });
}
let favorites=new Set(); try{favorites=new Set(JSON.parse(localStorage.getItem('hunt-vfx-favorites')||'[]'));}catch{}
const kinds={loop:'Цикл',burst:'Разовый',postfx:'Экранный',timecycle:'Timecycle',light:'Свет',shape:'Геометрия'};
const shapeOption=document.createElement('option');shapeOption.value='shape';shapeOption.textContent='Геометрия / thehunt_shapes';$('kind').append(shapeOption);
const themes={fire:/fire|flame|burn|campfire/,smoke:/smoke|fog|steam|mist/,insects:/flies|insect|fly_swarm|butterfly|firefly|mosquito/,nature:/leav|leaf|foliage|pollen|petal|vegetation/,sparks:/spark|electric|lightning/,dust:/dust|debris|dirt/,magic:/ghost|ring|magic|spirit|orb|shimmer/,water:/water|splash|bubble|spray/};
const aliases={'огонь':'fire','пламя':'flame','дым':'smoke','мухи':'flies','листва':'leav','искры':'spark','пыль':'dust','туман':'fog','пар':'steam'};
function renderStarters(){
 const picks=[['Малый костёр','ent_amb_campfire_sma'],['Большой костёр','ent_amb_campfire_lrg'],['Дым','env_smoke'],['Рой мух','ent_amb_insect_fly_swarm'],['Падающая листва','ent_ray_tree_fall_leaves'],['Огненное кольцо','scr_net_target_fire_ring_mp'],['Электрические искры','ent_amb_elec_crackle']];
 $('starterEffects').replaceChildren();
 for(const [label,name] of picks){const e=catalog.find(x=>x.name===name&&x.kind==='loop')||catalog.find(x=>x.name===name);if(!e)continue;
 $('starterEffects').append(button(label,()=>{choose(e);load({scale:1,alpha:1,lifetime:30,attach:false,offset:{x:0,y:0,z:0},rotation:{x:0,y:0,z:0},repeatCount:e.kind==='burst'?6:1,repeatInterval:1000});status('Выбран '+label+'. Укажите точку в мире и запустите тест.');}));}
}
function status(text,ok=true){$('status').textContent=text;$('status').className=ok?'ok':'error';}
async function call(name,data={}){
 try{const response=await fetch('https://'+GetParentResourceName()+'/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
 const r=await response.json();if(r.ok===false)status(r.error||'Ошибка',false);return r;
 }catch{status('Нет ответа ресурса',false);return {ok:false};}
}
const num=id=>Number($(id).value)||0;
function params(){
 const mode=$('placement').value;
 const p={coords:{x:num('x'),y:num('y'),z:num('z')},offset:{x:num('ox'),y:num('oy'),z:num('oz')},rotation:{x:num('rx'),y:num('ry'),z:num('rz')},
 scale:num('scale'),alpha:num('alpha'),lifetime:num('lifetime'),range:num('range'),intensity:num('intensity'),repeatCount:num('repeatCount'),repeatInterval:num('repeatInterval'),attach:mode!=='coords'};
 if(mode==='target')p.targetServerId=Number($('target').value);
  if(mode!=='coords'){
   const bones=[...document.querySelectorAll('#boneMenu input:checked')].map(input=>input.value);
   if(bones.length){p.bones=bones;p.bone=bones[0];}
  }
 if($('tint').checked){const c=$('color').value;p.color={r:parseInt(c.slice(1,3),16),g:parseInt(c.slice(3,5),16),b:parseInt(c.slice(5,7),16)};}
 if($('animate').checked)p.animation={mode:$('motion').value,radius:num('radius'),speed:num('speed'),velocity:{x:num('vx'),y:num('vy'),z:num('vz')},spin:{x:num('sx'),y:num('sy'),z:num('sz')},fadeIn:num('fadeIn'),fadeOut:num('fadeOut'),endScale:num('endScale')};
 if($('useTrack')?.checked){try{p.keyframes=JSON.parse($('trackJson').value);}catch{p.keyframes='invalid';status('Некорректный JSON ключевых кадров',false);}p.trackLoop=$('trackLoop').checked;p.offset={x:0,y:0,z:0};p.rotation={x:0,y:0,z:0};p.alpha=1;p.scale=1;}
 if($('useTrail')?.checked)p.trail={distance:num('trailDistance'),maxEmissions:60};
 return p;
}
function action(name,data){return call('action',{action:name,data});}
function button(label,fn){const b=document.createElement('button');b.textContent=label;b.onclick=fn;return b;}
function catalogMatches(e,q){return !q||e.id.toLowerCase().includes(q);}
function catalogReviewMatches(e,filter){return !filter||(filter==='favorite'?favorites.has(e.id):(reviews[e.id]?.status||'untested')===filter);}
function renderCatalog(){
 const input=$('search').value.trim().toLowerCase(),q=aliases[input]||input,kind=$('kind').value,filter=$('reviewFilter').value,theme=themes[$('theme').value];
 const list=catalog.filter(e=>(!kind||kind===e.kind)&&(!theme||((e.kind==='loop'||e.kind==='burst')&&theme.test(e.name)))&&catalogMatches(e,q)&&catalogReviewMatches(e,filter));
 const pages=Math.max(1,Math.ceil(list.length/60));page=Math.min(page,pages-1);
 $('count').textContent=list.length+' из '+catalog.length+' записей · Проверка видимости — вручную';
 $('catalog').replaceChildren();
 for(const e of list.slice(page*60,page*60+60)){
  const b=button((favorites.has(e.id)?'★ ':'')+e.name,()=>choose(e));
  b.className='entry'+(selected?.id===e.id?' selected':'');
  const sub=document.createElement('small');sub.textContent=kinds[e.kind]+' / '+(e.dict||'RDR3')+' / '+({visible:'виден',invisible:'не виден',untested:'не проверен'}[reviews[e.id]?.status||'untested']);
  b.append(sub);$('catalog').append(b);
 }
 $('page').textContent=(page+1)+' / '+pages;$('prev').disabled=page===0;$('next').disabled=page===pages-1;
}
function choose(e){
 if(!e)return;
 selectedWorld=null;$('updateWorld').disabled=true;
 selected=e;$('effectKind').textContent=kinds[e.kind];$('effectName').textContent=e.name;$('effectDict').textContent=e.dict||'Экранный канал / освещение';
 if(/trail|proj_|wheel|exhaust/.test(e.name))$('effectDict').textContent+=' · Может требовать движения или исходного игрового объекта';
 $('favorite').textContent=favorites.has(e.id)?'★ В избранном':'☆ В избранное';
 $('lightFields').hidden=e.kind!=='light';$('burstFields').hidden=e.kind!=='burst';
 $('spawn').disabled=e.kind==='postfx'||e.kind==='timecycle';
 renderCatalog();code();
}
function coords(c){for(const k of ['x','y','z'])$(k).value=Number(c[k]).toFixed(3);code();}
function load(p){
 if($('useTrack')){$('useTrack').checked=!!p.keyframes;$('trackJson').value=JSON.stringify(p.keyframes||[],null,2);$('trackLoop').checked=!!p.trackLoop;$('useTrail').checked=!!p.trail;$('trailDistance').value=p.trail?.distance||.5;}
 $('animate').checked=!!p.animation;
 if(p.animation){const a=p.animation;$('motion').value=a.mode||'static';for(const k of ['radius','speed','fadeIn','fadeOut','endScale'])if(a[k]!=null)$(k).value=a[k];for(const [prefix,v] of [['v',a.velocity],['s',a.spin]])for(const k of ['x','y','z'])$(prefix+k).value=v?.[k]||0;}
 for(const k of ['scale','alpha','lifetime','range','intensity','repeatCount','repeatInterval'])if(p[k]!=null)$(k).value=p[k];
 for(const [prefix,v] of [['o',p.offset],['r',p.rotation]])if(v)for(const k of ['x','y','z'])$(prefix+k).value=v[k]||0;
 if(p.coords)coords(p.coords);
 $('placement').value=p.attach?(p.targetServerId?'target':'self'):'coords';
 $('targetWrap').hidden=$('placement').value!=='target';
 const loadedBones=Array.isArray(p.bones)?p.bones:(p.bone?[p.bone]:[]);
 document.querySelectorAll('#boneMenu input').forEach(input=>input.checked=loadedBones.includes(input.value));
 updateBoneSummary();
 $('tint').checked=!!p.color;
 if(p.color)$('color').value='#'+['r','g','b'].map(k=>Math.round(p.color[k]).toString(16).padStart(2,'0')).join('');
 code();
}
function renderWorld(){
 $('worldList').replaceChildren();
 for(const e of world){
 const row=document.createElement('div');row.className='entry';
 const label=document.createElement('div');label.textContent=(e.owner==='persistent'?'СЦЕНА · ':'')+(e.name||e.effectId);row.append(label);
 const controls=document.createElement('div');controls.className='row';
 controls.append(button('Параметры',()=>{choose(catalog.find(x=>x.id===e.effectId));load(e.params);selectedWorld=e.id;$('updateWorld').disabled=false;}),button('Сохранить сцену',()=>action('saveScene',{id:e.id,name:$('name').value})),button('Удалить',async()=>{if(await studioConfirm('Удалить эффект'+(e.owner==='persistent'?' и сохранённую сцену':'')+'?'))action('stop',{id:e.id});}));
 row.append(controls);$('worldList').append(row);
 }
 if(!world.length)$('worldList').textContent='Нет активных эффектов мира.';
}
function renderPresets(){
 $('presetList').replaceChildren();
 for(const [name,p] of Object.entries(presets)){
 if(p.definition){const row=document.createElement('div');row.className='entry';row.append(button('Композиция · '+name,()=>{layers=JSON.parse(JSON.stringify(p.definition.phases));$('compositionDuration').value=p.definition.duration;renderLayers();compositionNav.click();}),button('Удалить',async()=>{if(await studioConfirm('Удалить '+name+'?'))action('deletePreset',{name});}));$('presetList').append(row);continue;}
 const row=document.createElement('div');row.className='entry';row.append(button(name,()=>{choose(catalog.find(e=>e.id===p.effectId));load(p.params);}),button('Удалить',async()=>{if(await studioConfirm('Удалить пресет '+name+'?'))action('deletePreset',{name});}));$('presetList').append(row);
 }
}
function lua(v){
 if(Array.isArray(v))return '{ '+v.map(lua).join(', ')+' }';
 if(v===null||v===undefined)return 'nil';
 if(typeof v==='number'||typeof v==='boolean')return String(v);
 if(typeof v==='string')return JSON.stringify(v);
 return '{ '+Object.entries(v).map(([k,x])=>k+' = '+lua(x)).join(', ')+' }';
}
function code(){
 if(!selected)return;
 const p=params(),server=$('apiSide').value==='server';
 if($('placement').value==='self'){
   if(server)p.targetServerId=1;
   else {delete p.coords;p.entity='__PLAYER_PED__';}
 }
 let str=lua(p).replace('"__PLAYER_PED__"','PlayerPedId()');
 $('code').value=(server?'-- server.lua: замените ID игрока и bucket при необходимости\n':'-- client.lua\n')+
 "local id, err = exports['thehunt_vfx']:PlayEffect("+lua(selected.id)+',\n    '+str+(server?', { bucket = 0 }':'')+")\nif not id then print(err) end\n\n-- Остановить этот запуск:\nexports['thehunt_vfx']:StopEffect(id)";
}
window.addEventListener('message',ev=>{
 const {action:a,data:d}=ev.data||{};
 if(a==='close'){$('studio').hidden=true;$('placementHint').hidden=true;}
 if(a==='show'){$('studio').hidden=false;$('placementHint').hidden=true;}
 if(a==='placing'){$('studio').hidden=true;$('placementHint').hidden=false;}
 if(a==='catalog'){catalog=d;renderCatalog();renderStarters();renderRecipes();}
 if(a==='coords')coords(d);
 if(a==='status')status(d.text,d.ok);
 if(a==='studio'){
 $('compositionScenes')?.remove();const scenes=document.createElement('div');scenes.id='compositionScenes';
 for(const [id,e] of Object.entries(d.compositions||{})){const row=document.createElement('div');row.className='entry';row.append(button('Композиция мира · '+e.name,()=>{selectedComposition=id;layers=JSON.parse(JSON.stringify(e.definition.phases));$('compositionDuration').value=e.definition.duration;$('name').value=e.name;coords(e.coords);renderLayers();compositionNav.click();}),button('Удалить композицию мира',async()=>{if(await studioConfirm('Удалить постоянную композицию?'))action('deleteWorldComposition',{id});}));scenes.append(row);}$('world').append(scenes);
 ownId=d.ownId||ownId;
 world=d.world||[];presets=d.presets||{};reviews=d.reviews||{};
 const target=$('target').value;$('target').replaceChildren();
 for(const p of d.players||[]){const o=document.createElement('option');o.value=p.id;o.textContent=p.id+' · '+p.name;$('target').append(o);}if(target)$('target').value=target;
 renderCatalog();renderWorld();renderPresets();
 }
});
for(const b of document.querySelectorAll('[data-tab]'))b.onclick=()=>{tab=b.dataset.tab;for(const e of document.querySelectorAll('.tab'))e.hidden=e.id!==tab;for(const n of document.querySelectorAll('[data-tab]'))n.classList.toggle('selected',n===b);code();};
$('close').onclick=()=>call('close');
$('addLayer').onclick=()=>{if(!selected)return status('Сначала выберите эффект в каталоге',false);if(layers.length>=24)return status('Максимум 24 слоя',false);layers.push({at:0,effectId:selected.id,params:params()});renderLayers();};
$('testComposition').onclick=()=>call('previewComposition',{definition:definition(),coords:params().coords,self:$('placement').value==='self',targetServerId:params().targetServerId});
$('saveComposition').onclick=()=>action('composition',{name:$('name').value,definition:definition()});
$('compositionCode').onclick=()=>{const def=JSON.parse(JSON.stringify(definition()));for(const layer of def.phases){delete layer.params.coords;delete layer.params.entity;delete layer.params.targetServerId;}$('compositionOutput').value="local id, err = exports['thehunt_vfx']:PlaySequence("+lua(def)+", { entity = PlayerPedId(), coords = GetEntityCoords(PlayerPedId()) })\n-- client.lua\n-- StopSequence(id) отменяет все слои";};
$('compositionDuration').onchange=renderLayers;
const exportComposition=button('Экспорт JSON',()=>{const def=JSON.parse(JSON.stringify(definition()));for(const layer of def.phases){delete layer.params.coords;delete layer.params.entity;delete layer.params.targetServerId;}$('compositionOutput').readOnly=false;$('compositionOutput').value=JSON.stringify(def,null,2);});
const importComposition=button('Импорт JSON из поля',()=>{try{const def=JSON.parse($('compositionOutput').value);if(!Number.isFinite(def.duration)||def.duration<=0||def.duration>600||!Array.isArray(def.phases)||!def.phases.length||def.phases.length>32)throw Error('Неверная длительность или число слоёв');for(const layer of def.phases)if(!catalog.some(e=>e.id===layer.effectId)||!Number.isFinite(layer.at)||layer.at<0||layer.at>=def.duration||!layer.params||typeof layer.params!=='object')throw Error('Некорректный слой');layers=def.phases;$('compositionDuration').value=def.duration;renderLayers();status('Импортировано. При сохранении параметры проверит сервер.');}catch(e){status('Импорт: '+e.message,false);}});
$('composition').append(exportComposition,importComposition);
$('search').oninput=()=>{page=0;renderCatalog();};
for(const id of ['kind','reviewFilter','theme'])$(id).onchange=()=>{page=0;renderCatalog();};
$('resetParams').onclick=()=>{load({scale:1,alpha:1,lifetime:30,offset:{x:0,y:0,z:0},rotation:{x:0,y:0,z:0},repeatCount:1,repeatInterval:500,attach:false});status('Базовые параметры восстановлены. Укажите точку в мире и запустите тест.');};
$('prev').onclick=()=>{page--;renderCatalog();};$('next').onclick=()=>{page++;renderCatalog();};
$('favorite').onclick=()=>{if(!selected)return;if(favorites.has(selected.id))favorites.delete(selected.id);else favorites.add(selected.id);try{localStorage.setItem('hunt-vfx-favorites',JSON.stringify([...favorites]));}catch{}choose(selected);};
$('placement').onchange=()=>{$('targetWrap').hidden=$('placement').value!=='target';code();};
$('here').onclick=async()=>{const r=await call('coords');if(r.coords)coords(r.coords);};
$('aim').onclick=()=>call('aim');
$('preview').onclick=()=>{if(selected)call('preview',{effectId:selected.id,params:params(),self:$('placement').value==='self'});};
$('stopPreview').onclick=()=>call('stopPreview');
$('spawn').onclick=()=>{if(!selected)return;const p=params();if($('placement').value==='self')p.targetServerId=ownId;action('spawn',{effectId:selected.id,params:p});};
$('savePreset').onclick=()=>{if(selected)action('preset',{name:$('name').value,effectId:selected.id,params:params()});};
$('updateWorld').onclick=()=>{if(selectedWorld&&selected)action('update',{id:selectedWorld,effectId:selected.id,params:params()});};
for(const id of ['visible','invisible'])$(id).onclick=()=>{if(selected)action('review',{effectId:selected.id,status:id});};
$('refresh').onclick=()=>action('refresh',{});
$('clear').onclick=async()=>{if(await studioConfirm('Остановить все временные VFX вашего измерения?'))action('clear',{});};
$('apiSide').onchange=code;$('selectCode').onclick=()=>{$('code').focus();$('code').select();};
document.addEventListener('input',code);
function updateBoneSummary(){const names=[...document.querySelectorAll('#boneMenu input:checked')].map(input=>input.parentElement.textContent.trim());$('boneSummary').textContent=names.length?names.join(', '):'Центр объекта';}
document.querySelectorAll('#boneMenu input').forEach(input=>input.onchange=()=>{updateBoneSummary();code();});
const boneMenu=$('boneMenu');if(boneMenu){boneMenu.style.display='grid';boneMenu.style.gap='3px';boneMenu.querySelectorAll('label').forEach(label=>{label.style.display='flex';label.style.flexDirection='row';label.style.alignItems='center';label.style.justifyContent='flex-start';label.style.gap='8px';label.style.margin='0';label.style.padding='5px';label.style.width='100%';label.querySelector('input').style.cssText='width:16px;height:16px;flex:0 0 16px;margin:0;';});}
document.addEventListener('keydown',e=>{if(e.key==='Escape')call('close');});
document.addEventListener('focusin',e=>{if(e.target.matches('input,textarea,select'))call('focus',{value:true});});
document.addEventListener('focusout',()=>setTimeout(()=>call('focus',{value:!!pendingConfirm||document.activeElement.matches('input,textarea,select')}),0));
document.addEventListener('mousedown',e=>{if(e.button===1){e.preventDefault();call('look',{value:true});}});
document.addEventListener('mouseup',e=>{if(e.button===1)call('look',{value:false});});
window.addEventListener('blur',()=>call('look',{value:false}));
function renderRecipes(){
 $('recipes')?.remove();const box=document.createElement('div');box.id='recipes';
 const title=document.createElement('p');title.textContent='Заготовки композиций — визуальный результат ещё не проверен в RedM';box.append(title);
 const recipes=[['Пульсирующая сфера',['shape|sphere','light|point']],['Кольцо с дымом',['shape|hoop','env_smoke']],['Орбитальные искры',['ent_amb_elec_crackle','light|point']],['Двухслойное пламя',['ent_amb_campfire_sma','light|point']]];
 for(const [name,names] of recipes){const effects=names.map(n=>catalog.find(e=>e.id===n)||catalog.find(e=>e.name===n&&e.kind==='loop'));if(effects.some(e=>!e))continue;
 box.append(button(name,()=>{layers=effects.map((e,i)=>({at:i*.3,effectId:e.id,params:{lifetime:8,scale:1,alpha:e.kind==='shape'?.25:1,offset:{x:0,y:0,z:1},rotation:{x:0,y:0,z:0},color:{r:100,g:180,b:255},animation:{mode:name.includes('Орбит')?'orbit':'static',radius:1,speed:90,fadeIn:1,fadeOut:2,endScale:1.5}}}));$('compositionDuration').value=10;renderLayers();compositionNav.click();}));}
 $('presets').append(box);
}
const trackPanel=document.createElement('details');trackPanel.innerHTML='<summary>Ключевые кадры и след</summary><label><input id="useTrack" type="checkbox"> Ключевые кадры (приоритет над простой анимацией)</label><label><input id="trackLoop" type="checkbox"> Повторять траекторию</label><label>Время кадра, сек<input id="keyTime" type="number" value="0" min="0" step=".1"></label><label>Переход<select id="keyEase"><option value="linear">Линейный</option><option value="smooth">Плавный</option><option value="hold">Удерживать</option></select></label><textarea id="trackJson" spellcheck="false">[]</textarea><label><input id="useTrail" type="checkbox"> След по расстоянию (разовый PTFX)</label><label>Шаг следа, метры<input id="trailDistance" type="number" min=".1" max="10" step=".1" value=".5"></label>';
trackPanel.append(button('Записать кадр из параметров справа',()=>{try{const keys=JSON.parse($('trackJson').value);if(!Array.isArray(keys)||keys.length>=32)throw Error('Максимум 32 кадра');const at=num('keyTime');const frame={at,offset:{x:num('ox'),y:num('oy'),z:num('oz')},rotation:{x:num('rx'),y:num('ry'),z:num('rz')},alpha:num('alpha'),scale:num('scale'),easing:$('keyEase').value};const index=keys.findIndex(k=>k.at===at);if(index<0)keys.push(frame);else keys[index]=frame;keys.sort((a,b)=>a.at-b.at);$('trackJson').value=JSON.stringify(keys,null,2);$('useTrack').checked=true;status('Кадр записан. Примените параметры к слою.');}catch(e){status(e.message,false);}}));
document.querySelector('aside').append(trackPanel);
$('composition').append(button('Новая композиция / сохранить отдельной копией',()=>{selectedComposition=null;status('Следующее сохранение создаст новую композицию мира.');}));
const gizmoOverlay=document.createElement('div');gizmoOverlay.hidden=true;gizmoOverlay.style.cssText='position:fixed;inset:0;z-index:100';document.body.append(gizmoOverlay);
const gizmoToolbar=document.createElement('div');gizmoToolbar.style.cssText='position:absolute;top:20px;left:20px;background:#101014;padding:12px;color:white';gizmoToolbar.append('Перетащите X / Y / Z для перемещения ',button('Применить',()=>call('gizmoEnd',{})),button('Отмена',()=>call('gizmoEnd',{cancel:true})));gizmoOverlay.append(gizmoToolbar);
let axesData=null,axisDrag=null,lastGizmoSend=0;
for(const axis of ['x','y','z']){const handle=button(axis.toUpperCase(),()=>{});handle.id='gizmoAxis'+axis;handle.style.cssText='position:absolute;width:36px;height:36px;touch-action:none';handle.onpointerdown=e=>{if(!axesData?.origin||!axesData.axes[axis])return;const end=axesData.axes[axis],origin=axesData.origin;axisDrag={axis,x:e.clientX,y:e.clientY,dx:(end.x-origin.x)*innerWidth,dy:(end.y-origin.y)*innerHeight,coords:{...axesData.coords}};handle.setPointerCapture(e.pointerId);};handle.onpointermove=e=>{if(!axisDrag)return;const d=axisDrag,length=d.dx*d.dx+d.dy*d.dy;if(length<4)return;const value=((e.clientX-d.x)*d.dx+(e.clientY-d.y)*d.dy)/length;const c={...d.coords};c[d.axis]+=value;if(performance.now()-lastGizmoSend>50){lastGizmoSend=performance.now();call('gizmoMove',{coords:c});}};handle.onpointerup=e=>{axisDrag=null;handle.releasePointerCapture(e.pointerId);};gizmoOverlay.append(handle);}
window.addEventListener('message',event=>{const {action:a,data:d}=event.data||{};if(a==='gizmoShow'){$('studio').hidden=true;gizmoOverlay.hidden=false;}if(a==='gizmoAxes'){axesData=d;for(const axis of ['x','y','z']){const handle=$('gizmoAxis'+axis),point=d.axes[axis];handle.hidden=!point;if(point){handle.style.left=point.x*100+'%';handle.style.top=point.y*100+'%';}}}if(a==='show'||a==='close'){gizmoOverlay.hidden=true;axisDrag=null;}});
$('here').parentElement.append(button('3D-оси',()=>call('gizmoStart',{coords:params().coords})));
 $('composition').append(button('Сохранить постоянную композицию в этой точке',()=>action('saveWorldComposition',{id:selectedComposition,definition:definition(),coords:params().coords,name:$('name').value})));
for(const [label,delta] of [['Отменить',-1],['Повторить',1]])$('composition').append(button(label,()=>{const next=historyIndex+delta;if(next<0||next>=history.length)return;historyIndex=next;const state=JSON.parse(history[next]);layers=state.phases;$('compositionDuration').value=state.duration;restoring=true;renderLayers();restoring=false;}));
