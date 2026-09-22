'use strict';
(()=>{
const clone=value=>JSON.parse(JSON.stringify(value));
const clamp=(n,a,b)=>Math.max(a,Math.min(b,Number(n)||0));
function field(parent,label,id,value,type='number'){
 const l=document.createElement('label');l.textContent=label;const input=document.createElement('input');input.id=id;input.type=type;input.value=value;if(type==='number')input.step='.1';l.append(input);parent.append(l);return input;
}
function selectField(parent,label,id,options){const l=document.createElement('label');l.textContent=label;const input=document.createElement('select');input.id=id;for(const [value,text] of options){const o=document.createElement('option');o.value=value;o.textContent=text;input.append(o);}l.append(input);parent.append(l);return input;}
function tabPanel(id,label){const panel=document.createElement('div');panel.id=id;panel.className='tab';panel.hidden=true;document.querySelector('.browser').append(panel);const nav=button(label,()=>{tab=id;document.querySelectorAll('.tab').forEach(p=>p.hidden=p!==panel);document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('selected',b===nav));});nav.dataset.tab=id;document.querySelector('nav').append(nav);return panel;}

// Dragging uses one history transaction at pointer-up, not one per frame.
const transport=section('Предпросмотр','Пауза останавливает эмиссию. Продолжение и перемотка пересоздают частицы. Скорость меняет таймлайн и анимацию; собственная симуляция частиц идёт со скоростью движка. Сеанс — до 30 секунд.');
transport.id='transportPanel';document.querySelector('.timeline-section').before(transport);
const transportTools=document.createElement('div');transportTools.className='tool-row';transport.append(transportTools);
let transportCursor=0;
function startTransport(onlyLayer=false){
 let def=clone(definition());if(onlyLayer){if(!editingLayer||!layers.includes(editingLayer))return status('Выберите слой для редактирования',false);def.phases=[clone(editingLayer)];def.phases[0].enabled=true;}
 if(!def.phases.length)return status('Добавьте слои',false);
 return call('transport',{command:'start',definition:def,coords:params().coords,self:$('placement').value==='self',targetServerId:params().targetServerId,cursor:transportCursor,speed:num('transportSpeed'),loop:$('transportLoop').checked});
}
transportTools.append(button('▶ С начала',()=>{transportCursor=0;startTransport();}),button('▶ С курсора',()=>startTransport()),button('Только выбранный слой',()=>startTransport(true)),button('Ⅱ Пауза',()=>call('transport',{command:'pause'})),button('Продолжить',()=>call('transport',{command:'resume'})),button('■ Стоп',()=>call('transport',{command:'stop'})));
selectField(transport,'Скорость','transportSpeed',[['.25','¼×'],['.5','½×'],['1','1×'],['2','2×']]).value='1';$('transportSpeed').onchange=()=>call('transport',{command:'speed',speed:num('transportSpeed')});
const loopLabel=document.createElement('label');loopLabel.className='check-label';loopLabel.innerHTML='<input id="transportLoop" type="checkbox"> Повторять в пределах сеанса';transport.append(loopLabel);$('transportLoop').onchange=()=>call('transport',{command:'loop',loop:$('transportLoop').checked});
const cursor=field(transport,'Курсор времени','transportCursor',0,'range');cursor.min=0;cursor.max=10;cursor.step='.05';const cursorText=document.createElement('small');transport.append(cursorText);
cursor.oninput=()=>{transportCursor=Number(cursor.value);cursorText.textContent=transportCursor.toFixed(2)+' сек.';};cursor.onchange=()=>call('transport',{command:'seek',cursor:transportCursor});
$('testComposition').onclick=()=>{transportCursor=0;startTransport();};

const groupPanel=section('Группы и преобразования','Отметьте слои, задайте группу и примените перенос, вращение или масштаб. Изменения записываются в параметры и ключевые кадры; Ctrl+Z отменяет операцию.',true);
groupPanel.id='groupPanel';document.querySelector('.timeline-section').after(groupPanel);
field(groupPanel,'Имя группы','groupName','','text');
function checkedLayers(){return layers.filter(l=>l.editorSelected);}
const groupTools=document.createElement('div');groupTools.className='tool-row';groupPanel.append(groupTools);
groupTools.append(button('Выделить все',()=>{layers.forEach(l=>l.editorSelected=true);renderLayers();}),button('Снять выделение',()=>{layers.forEach(l=>l.editorSelected=false);renderLayers();}),button('Назначить группу',()=>{const name=$('groupName').value.trim().slice(0,80);checkedLayers().forEach(l=>l.group=name);renderLayers();}),button('Выделить группу',()=>{layers.forEach(l=>l.editorSelected=l.group===$('groupName').value.trim());renderLayers();}));
const transforms=document.createElement('div');transforms.className='param-grid';groupPanel.append(transforms);
for(const [id,label,value] of [['gx','Перенос X',0],['gy','Перенос Y',0],['gz','Перенос Z',0],['grx','Поворот X',0],['gry','Поворот Y',0],['grz','Поворот Z',0],['gscale','Масштаб',1]])field(transforms,label,id,value);
function rotate(v,r){let {x=0,y=0,z=0}=v||{};const [a,b,c]=r.map(n=>n*Math.PI/180);[y,z]=[y*Math.cos(a)-z*Math.sin(a),y*Math.sin(a)+z*Math.cos(a)];[x,z]=[x*Math.cos(b)+z*Math.sin(b),-x*Math.sin(b)+z*Math.cos(b)];return {x:x*Math.cos(c)-y*Math.sin(c),y:x*Math.sin(c)+y*Math.cos(c),z};}
function transformParams(p,translation,rotation,scale){
 const vec=v=>{const q=rotate(v,rotation);for(const a of ['x','y','z'])q[a]*=scale;return q;};
 p.offset=vec(p.offset);for(const a of ['x','y','z'])p.offset[a]+=translation[a];
 p.rotation=p.rotation||{x:0,y:0,z:0};['x','y','z'].forEach((a,i)=>p.rotation[a]=(p.rotation[a]||0)+rotation[i]);
 p.scale=clamp((p.scale??1)*scale,.01,10);
 if(p.keyframes){for(const k of p.keyframes){k.offset=vec(k.offset);k.rotation=k.rotation||{x:0,y:0,z:0};for(const a of ['x','y','z']){k.offset[a]+=p.offset[a];k.rotation[a]=(k.rotation[a]||0)+p.rotation[a];}k.scale=clamp((k.scale??1)*p.scale,.01,10);k.alpha=clamp((k.alpha??1)*(p.alpha??1),0,1);}p.offset={x:0,y:0,z:0};p.rotation={x:0,y:0,z:0};p.scale=1;p.alpha=1;}
 if(p.animation){p.animation.radius=clamp((p.animation.radius||0)*scale,0,20);p.animation.velocity=vec(p.animation.velocity);p.animation.endScale=clamp((p.animation.endScale??1)*scale,.01,10);}
}
groupPanel.append(button('Применить к выделенным',()=>{const chosen=checkedLayers();if(!chosen.length)return status('Отметьте слои',false);for(const l of chosen)transformParams(l.params,{x:num('gx'),y:num('gy'),z:num('gz')},[num('grx'),num('gry'),num('grz')],clamp(num('gscale'),.01,10));renderLayers();status('Преобразовано слоёв: '+chosen.length);}));

const generator=section('Генератор слоёв','Использует выбранный эффект и параметры инспектора. Результат — обычные редактируемые слои.',true);generator.id='generatorPanel';groupPanel.after(generator);
selectField(generator,'Форма','generatorType',[['ring','Кольцо'],['sphere','Сфера'],['spiral','Спираль'],['wave','Волна']]);
const generatorFields=document.createElement('div');generatorFields.className='param-grid';generator.append(generatorFields);
for(const [id,label,value] of [['generatorCount','Количество',8],['generatorRadius','Радиус / размах',2],['generatorHeight','Высота',3],['generatorTurns','Витки / волны',2],['generatorDelay','Задержка между слоями, сек',0]])field(generatorFields,label,id,value);
generator.append(button('Сгенерировать',()=>{
 if(!selected||!['loop','burst','light','shape'].includes(selected.kind))return status('Выберите частицы, свет или геометрию',false);
 const count=Math.floor(clamp(num('generatorCount'),1,24));if(layers.length+count>24)return status('Недостаточно места: максимум 24 слоя',false);
 const delay=Math.max(0,num('generatorDelay'));if(delay*(count-1)>=num('compositionDuration'))return status('Последний слой начинается после конца композиции',false);
 const radius=clamp(num('generatorRadius'),0,20),height=clamp(num('generatorHeight'),-20,20),turns=clamp(num('generatorTurns'),.1,12),type=$('generatorType').value,group=$('groupName').value||type+' '+(layers.length+1);
 for(let i=0;i<count;i++){const t=count===1?0:i/(count-1),a=2*Math.PI*i/count,p=params();let point;
  if(type==='sphere'){const y=1-2*(i+.5)/count,r=Math.sqrt(1-y*y),theta=i*Math.PI*(3-Math.sqrt(5));point={x:radius*r*Math.cos(theta),y:radius*r*Math.sin(theta),z:radius*y};}
  else if(type==='spiral')point={x:radius*Math.cos(t*turns*2*Math.PI),y:radius*Math.sin(t*turns*2*Math.PI),z:height*t};
  else if(type==='wave')point={x:(2*t-1)*radius,y:0,z:height*Math.sin(t*turns*2*Math.PI)};
  else point={x:radius*Math.cos(a),y:radius*Math.sin(a),z:0};
  for(const axis of ['x','y','z'])p.offset[axis]+=point[axis];layers.push({effectId:selected.id,at:i*delay,enabled:true,group,params:p});
 }renderLayers();status('Создано '+count+' слоёв');
}));

// Keyframe table edits the actual track consumed by the runtime, without JSON typing.
const keyEditor=section('Ключевые кадры','Выберите кадр, измените параметры в инспекторе и нажмите «Обновить кадр». После редактирования примените параметры к слою.',true);keyEditor.id='keyEditor';trackPanel.before(keyEditor);
const keyList=document.createElement('div');keyList.id='keyList';keyEditor.append(keyList);let selectedKey=-1;
function keys(){const data=JSON.parse($('trackJson').value);if(!Array.isArray(data))throw Error('Ожидается список кадров');return data;}
function writeKeys(data){data.sort((a,b)=>a.at-b.at);$('trackJson').value=JSON.stringify(data,null,2);$('useTrack').checked=data.length>0;renderKeys();code();}
function renderKeys(){
 keyList.replaceChildren();let data;try{data=keys();}catch{keyList.textContent='Некорректный JSON траектории. Исправьте его в расширенных параметрах.';return;}
 data.forEach((key,index)=>{const row=document.createElement('div');row.className='key-row';const time=field(row,'Сек.','frameTime'+index,key.at);time.min=0;time.onchange=()=>{const at=clamp(time.value,0,600);if(data.some((k,i)=>i!==index&&k.at===at)){status('Время кадров должно отличаться',false);renderKeys();return;}key.at=at;writeKeys(data);};
  row.append(button('Кадр '+(index+1),()=>{selectedKey=index;$('keyTime').value=key.at;$('keyEase').value=key.easing||'linear';for(const [prefix,v] of [['o',key.offset],['r',key.rotation]])for(const a of ['x','y','z'])$(prefix+a).value=v?.[a]||0;$('scale').value=key.scale??1;$('alpha').value=key.alpha??1;status('Выбран кадр '+(index+1));}),button('Удалить',()=>{data.splice(index,1);selectedKey=-1;writeKeys(data);}));keyList.append(row);
 });if(!data.length)keyList.textContent='Кадров пока нет. Настройте смещение, вращение и масштаб, затем добавьте кадр.';
}
keyEditor.append(button('Добавить кадр',()=>{try{const data=keys(),at=num('keyTime');if(data.length>=32||data.some(k=>k.at===at))return status('Максимум 32 кадра; время должно отличаться',false);data.push({at,offset:{x:num('ox'),y:num('oy'),z:num('oz')},rotation:{x:num('rx'),y:num('ry'),z:num('rz')},scale:num('scale'),alpha:num('alpha'),easing:$('keyEase').value});writeKeys(data);}catch(e){status(e.message,false);}}),button('Обновить кадр',()=>{try{const data=keys();if(!data[selectedKey])return status('Выберите кадр',false);Object.assign(data[selectedKey],{offset:{x:num('ox'),y:num('oy'),z:num('oz')},rotation:{x:num('rx'),y:num('ry'),z:num('rz')},scale:num('scale'),alpha:num('alpha'),easing:$('keyEase').value});writeKeys(data);}catch(e){status(e.message,false);}}));
// Move the existing time/easing controls into the visual editor.
keyEditor.prepend($('keyTime').parentElement,$('keyEase').parentElement);
const advancedLoad=load;load=function(p){advancedLoad(p);selectedKey=-1;renderKeys();};$('trackJson').addEventListener('change',renderKeys);renderKeys();

const advancedRender=renderLayers;
renderLayers=function(){if(editingLayer&&!layers.includes(editingLayer))editingLayer=null;advancedRender();cursor.max=Math.max(.1,num('compositionDuration'));
 for(const [index,row] of [...$('layers').children].entries()){
  const layer=layers[index];const selection=document.createElement('label');selection.className='check-label';const check=document.createElement('input');check.type='checkbox';check.checked=!!layer.editorSelected;check.onchange=()=>{layer.editorSelected=check.checked;saveDraft();};selection.append(check,document.createTextNode(layer.group?'Группа: '+layer.group:'Выделить для группы'));row.prepend(selection);
  const bar=[...row.children].find(e=>e.style.height==='8px');if(!bar)continue;bar.className='visual-timeline';bar.removeAttribute('style');bar.replaceChildren();
  const clip=document.createElement('div');clip.className='timeline-clip';const end=document.createElement('span');end.className='resize-clip';clip.append(end);bar.append(clip);
  const duration=Math.max(.1,num('compositionDuration'));const draw=()=>{clip.style.left=layer.at/duration*100+'%';clip.style.width=Math.max(.8,Math.min(duration-layer.at,layer.params.lifetime||duration-layer.at)/duration*100)+'%';clip.title=layer.at.toFixed(2)+' сек. · длительность '+(layer.params.lifetime||duration-layer.at).toFixed(2)+' сек.';};draw();
  clip.onpointerdown=e=>{e.preventDefault();const start=e.clientX,at=layer.at,life=layer.params.lifetime||duration-layer.at,resizing=e.target===end,width=bar.getBoundingClientRect().width;clip.setPointerCapture(e.pointerId);
   clip.onpointermove=ev=>{const delta=(ev.clientX-start)/width*duration;if(resizing)layer.params.lifetime=Math.max(.1,Math.min(duration-layer.at,Math.round((life+delta)*20)/20));else layer.at=clamp(Math.round((at+delta)*20)/20,0,Math.max(0,duration-.1));draw();};
   clip.onpointerup=()=>{clip.onpointermove=null;renderLayers();};clip.onpointercancel=()=>{layer.at=at;layer.params.lifetime=life;clip.onpointermove=null;renderLayers();};
  };
 }
};

// Catalog annotations are shared, recent selections are local to this client.
let annotations={},recent=[];try{recent=JSON.parse(localStorage.getItem('hunt-vfx-recent')||'[]');}catch{}
const recentOption=document.createElement('option');recentOption.value='recent';recentOption.textContent='Недавние';$('reviewFilter').append(recentOption);
const annotationPanel=section('Теги и заметки','Общие заметки администраторов. Метка «Виден» ставится после проверки в игре.',true);annotationPanel.id='annotationPanel';document.querySelector('aside').append(annotationPanel);
field(annotationPanel,'Теги через запятую','effectTags','','text');const note=document.createElement('textarea');note.id='effectNote';note.maxLength=1000;note.placeholder='Где виден, к какой кости подходит, удачный масштаб…';annotationPanel.append(note,button('Сохранить заметку',()=>{if(selected)action('annotate',{effectId:selected.id,note:note.value,tags:$('effectTags').value.split(',').map(s=>s.trim()).filter(Boolean).slice(0,12)});}));
const advancedChoose=choose;choose=function(e){advancedChoose(e);if(!e)return;recent=[e.id,...recent.filter(id=>id!==e.id)].slice(0,40);try{localStorage.setItem('hunt-vfx-recent',JSON.stringify(recent));}catch{}$('effectTags').value=(annotations[e.id]?.tags||[]).join(', ');note.value=annotations[e.id]?.note||'';};
catalogMatches=function(e,q){const a=annotations[e.id]||{};return !q||(e.id+' '+(a.tags||[]).join(' ')+' '+(a.note||'')).toLowerCase().includes(q);};
catalogReviewMatches=function(e,filter){return !filter||(filter==='recent'?recent.includes(e.id):filter==='favorite'?favorites.has(e.id):(reviews[e.id]?.status||'untested')===filter);};

const presetDescription=section('Описание и проверка сборки','Выберите сохранённую сборку. Отметьте проверку только после просмотра результата в RedM.',true);$('presets').prepend(presetDescription);
const description=document.createElement('textarea');description.id='presetDescription';description.placeholder='Ожидаемый результат, подходящая точка или кость, условия применения';description.maxLength=1000;presetDescription.append(description);
const verifiedLabel=document.createElement('label');verifiedLabel.className='check-label';verifiedLabel.innerHTML='<input id="presetVerified" type="checkbox"> Проверено мной в игре';presetDescription.append(verifiedLabel,button('Сохранить описание и проверку',()=>action('describePreset',{name:$('name').value,description:description.value,verified:$('presetVerified').checked})));
const verifiedFilter=document.createElement('label');verifiedFilter.className='check-label';verifiedFilter.innerHTML='<input id="onlyVerifiedPresets" type="checkbox"> Только проверенные сборки';$('presetList').before(verifiedFilter);$('onlyVerifiedPresets').onchange=()=>renderPresets();
const advancedPresets=renderPresets;renderPresets=function(){advancedPresets();for(const [index,[name,preset]] of Object.entries(presets).entries()){
 const row=$('presetList').children[index];if(!row)continue;row.hidden=$('onlyVerifiedPresets').checked&&!preset.verification;
 const first=row.querySelector('button'),handler=first.onclick;first.onclick=()=>{selectedComposition=null;editingLayer=null;handler();$('name').value=name;description.value=preset.description||'';$('presetVerified').checked=!!preset.verification;};
 const text=document.createElement('p');text.textContent=(preset.verification?'✓ Проверено '+preset.verification.by+' · '+preset.verification.date:'Не проверено в игре')+(preset.description?' — '+preset.description:'');row.append(text);
 }};
const advancedRecipes=renderRecipes;renderRecipes=function(){advancedRecipes();const details=['Полупрозрачная сфера с мягким светом и изменением масштаба.','Геометрическое кольцо и слой дыма над общей точкой.','Искры и свет с круговым движением вокруг общей точки.','Частицы небольшого огня со светом и плавным затуханием.'];$('recipes')?.querySelectorAll('button').forEach((b,i)=>{const text=document.createElement('small');text.textContent=details[i]||'Составная заготовка; проверьте результат локально.';b.append(text);});};

const diagnosticsPanel=tabPanel('diagnostics','Диагностика');diagnosticsPanel.append(section('Активные локальные эффекты','Показывает загрузку и запуск на вашем клиенте, включая стриминг мира. Успешный запуск не гарантирует видимость.'));
const counters=document.createElement('p'),activeList=document.createElement('div'),errorList=document.createElement('div');diagnosticsPanel.append(counters,activeList,section('Последние ошибки','До 30 сообщений текущего сеанса.'),errorList);let errorsLog=[];
function diagnostics(data){const counts={};for(const e of data)counts[e.state]=(counts[e.state]||0)+1;const lights=data.filter(e=>e.effectId==='light|point').length;counters.textContent='Всего '+data.length+' · загружается '+(counts.loading||0)+' · работает '+(counts.playing||0)+' · ошибок '+(counts.failed||0)+' · свет '+lights;activeList.replaceChildren();for(const e of data){const row=document.createElement('div');row.className='entry';row.textContent=e.effectId+' · '+e.state+(e.error?' · '+e.error:'');if(e.owner==='studio')row.append(button('Остановить',()=>call('stopLocal',{id:e.id})));activeList.append(row);}}

const scenesPanel=section('Сохранённые сцены','Скрытие сохраняется после перезапуска. Копия создаётся скрытой. Перенос использует точку инспектора. Хранятся последние 8 версий каждой сцены.');scenesPanel.id='sceneManager';$('world').prepend(scenesPanel);field(scenesPanel,'Найти сцену','sceneSearch','','search');const savedList=document.createElement('div');scenesPanel.append(savedList);let savedScenes={},savedCompositions={};
function sceneOperation(kind,id,operation,extra={}){return action('manageScene',{kind,id,operation,...extra});}
function renderSceneManager(){savedList.replaceChildren();const q=$('sceneSearch').value.toLowerCase();for(const [kind,records] of [['scene',savedScenes],['composition',savedCompositions]])for(const [id,e] of Object.entries(records)){
 if(q&&!(e.name||id).toLowerCase().includes(q))continue;const row=document.createElement('div');row.className='entry';const title=document.createElement('strong');title.textContent=(e.enabled===false?'Скрыта · ':'Активна · ')+(e.name||id);row.append(title);
 row.append(button('Открыть',()=>{if(kind==='composition'){selectedComposition=id;editingLayer=null;layers=clone(e.definition.phases);$('compositionDuration').value=e.definition.duration;coords(e.coords);$('placement').value='coords';$('targetWrap').hidden=true;renderLayers();compositionNav.click();}else{choose(catalog.find(x=>x.id===e.effectId));load(e.params);selectedWorld=id;$('updateWorld').disabled=false;}$('name').value=e.name||'';}),button(e.enabled===false?'Показать':'Скрыть',()=>sceneOperation(kind,id,'toggle')),button('Дублировать',()=>sceneOperation(kind,id,'duplicate')),button('Перенести в точку',async()=>{if(await studioConfirm('Перенести сцену в координаты инспектора?'))sceneOperation(kind,id,'move',{coords:params().coords});}),button('Удалить сцену',async()=>{if(await studioConfirm('Удалить сцену вместе с её историей?'))action(kind==='composition'?'deleteWorldComposition':'stop',{id});}));
 if(e.versions?.length){const versions=document.createElement('select');for(const [i,v] of e.versions.entries()){const option=document.createElement('option');option.value=i+1;option.textContent=(v.savedAt||'Версия')+' · '+(v.name||'Сцена');versions.append(option);}row.append(versions,button('Восстановить версию',async()=>{if(await studioConfirm('Восстановить выбранную версию сцены?'))sceneOperation(kind,id,'restore',{version:Number(versions.value)});}));}savedList.append(row);
 }if(!savedList.children.length)savedList.textContent='Сохранённых сцен по этому запросу нет.';}
$('sceneSearch').oninput=renderSceneManager;
window.addEventListener('message',event=>{const {action:a,data:d}=event.data||{};
 if(a==='studio'){annotations=d.annotations||{};savedScenes=d.scenes||{};savedCompositions=d.compositions||{};renderSceneManager();renderCatalog();if(selected){$('effectTags').value=(annotations[selected.id]?.tags||[]).join(', ');note.value=annotations[selected.id]?.note||'';}}
 if(a==='active')diagnostics(d||[]);
 if(a==='status'&&d.ok===false){errorsLog.unshift(d.text);errorsLog=errorsLog.slice(0,30);errorList.replaceChildren();for(const text of errorsLog){const row=document.createElement('p');row.textContent=text;errorList.append(row);}}
 if(a==='transport'){transportCursor=d.cursor||0;cursor.value=transportCursor;cursorText.textContent=transportCursor.toFixed(2)+' сек. · '+({playing:'воспроизведение',paused:'пауза',stopped:'остановлено'}[d.state]||d.state);}
 if(a==='gizmoDefinition'){layers=d.phases;$('compositionDuration').value=d.duration;renderLayers();}
});
})();
