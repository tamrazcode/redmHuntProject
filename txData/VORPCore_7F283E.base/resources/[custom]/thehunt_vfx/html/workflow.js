'use strict';
// Studio workflow only; all shared effects still go through server validation.
const draftKey='hunt-vfx-draft-v1';
function validProject(d){
 return d&&Number.isFinite(d.duration)&&d.duration>0&&d.duration<=600&&Array.isArray(d.phases)&&d.phases.length>0&&d.phases.length<=24&&d.phases.every(l=>l&&catalog.some(e=>e.id===l.effectId)&&Number.isFinite(l.at)&&l.at>=0&&l.at<d.duration&&l.params&&typeof l.params==='object'&&!Array.isArray(l.params));
}
importComposition.onclick=()=>{
 try{const d=JSON.parse($('compositionOutput').value);if(!validProject(d))throw Error('Проверьте каталог, длительность, время запуска и лимит 24 слоя');layers=d.phases;editingLayer=null;selectedComposition=null;$('compositionDuration').value=d.duration;renderLayers();status('Композиция импортирована. Сохраните её как пресет.');}
 catch(e){status('Импорт: '+e.message,false);}
};
const workflow=document.createElement('section');workflow.className='workflow';
const workflowHelp=document.createElement('details');
workflowHelp.innerHTML='<summary>Как работать со студией</summary><ol><li>Найдите эффект в библиотеке и выберите его.</li><li>Укажите поверхность или выберите привязку к игроку.</li><li>Нажмите «Тест локально»: результат видите только вы.</li><li>Для нескольких эффектов добавьте слои в композицию. Изменения инспектора применяются кнопкой «Применить к слою».</li><li>Сохраните пресет для повторного использования. Постоянная сцена сохраняет ещё и точку в мире.</li></ol><p>Ctrl+Enter — тест эффекта или композиции · Ctrl+Z / Ctrl+Shift+Z — история композиции вне полей ввода · Ctrl+F — поиск.</p>';
const draftStatus=document.createElement('small');draftStatus.id='draftStatus';draftStatus.textContent='Черновик композиции сохраняется на этом компьютере';
workflow.append(workflowHelp,draftStatus);document.querySelector('.project-strip').after(workflow);
$('status').setAttribute('role','status');$('status').setAttribute('aria-live','polite');
$('search').setAttribute('aria-label','Поиск эффектов');
const diagnostics=document.createElement('div');diagnostics.id='compositionDiagnostics';diagnostics.setAttribute('role','status');
document.querySelector('.composition-head').append(diagnostics);
function compositionIssues(){
 const d=definition(),issues=[];
 if(!Number.isFinite(d.duration)||d.duration<=0||d.duration>600)issues.push('Длительность: от 0.1 до 600 секунд.');
 if(d.phases.length>24)issues.push('Допустимо не больше 24 слоёв.');
 if(d.phases.length&&!d.phases.some(l=>l.enabled!==false))issues.push('Все слои выключены.');
 d.phases.forEach((l,i)=>{if(!Number.isFinite(l.at)||l.at<0||l.at>=d.duration)issues.push('Слой '+(i+1)+': начало должно быть раньше конца композиции.');});
 return issues;
}
function saveDraft(){
 try{localStorage.setItem(draftKey,JSON.stringify({version:1,name:$('name').value,definition:definition()}));draftStatus.textContent='Черновик сохранён на этом компьютере · '+layers.length+'/24 слоёв';}
 catch{draftStatus.textContent='Не удалось сохранить локальный черновик. Сохраните пресет или экспортируйте JSON.';}
}
const workflowRender=renderLayers;
renderLayers=function(){
 workflowRender();const issues=compositionIssues();diagnostics.textContent=issues.join(' ');diagnostics.classList.toggle('error',issues.length>0);
 for(const node of [$('testComposition'),$('saveComposition'),networkComposition])node.disabled=!layers.length||issues.length>0;
 for(const [i,row] of [...$('layers').children].entries()){
  const move=(step)=>{const to=i+step;if(to<0||to>=layers.length)return;[layers[i],layers[to]]=[layers[to],layers[i]];renderLayers();};
  const up=button('↑',()=>move(-1)),down=button('↓',()=>move(1));up.title='Поднять слой';down.title='Опустить слой';up.disabled=i===0;down.disabled=i===layers.length-1;
  row.querySelector('.layer-actions').append(up,down);
 }
 saveDraft();
};
let storedDraft=null;
try{storedDraft=JSON.parse(localStorage.getItem(draftKey)||'null');}catch{}
if(storedDraft?.version===1&&Array.isArray(storedDraft.definition?.phases)&&storedDraft.definition.phases.length){
 const restore=button('Восстановить черновик ('+storedDraft.definition.phases.length+' слоёв)',()=>{
  if(!catalog.length)return status('Дождитесь загрузки каталога',false);
  const d=storedDraft.definition;
  if(d.phases.length>24||!Number.isFinite(d.duration)||d.duration<=0||d.duration>600||d.phases.some(l=>!l||!catalog.some(e=>e.id===l.effectId)||!l.params||Array.isArray(l.params)||typeof l.params!=='object'||!Number.isFinite(l.at)||l.at<0||l.at>=d.duration))return status('Черновик несовместим с текущим каталогом',false);
  layers=JSON.parse(JSON.stringify(d.phases));editingLayer=null;selectedComposition=null;$('compositionDuration').value=d.duration;$('name').value=storedDraft.name||'';renderLayers();compositionNav.click();restore.remove();status('Черновик восстановлен. Для хранения на сервере сохраните пресет.');
 });workflow.append(restore);
}
$('name').addEventListener('change',saveDraft);
// Do not overwrite a recoverable draft merely by opening an empty workspace.
const newProject=button('Очистить композицию',async()=>{
 if(layers.length&&!await studioConfirm('Очистить текущие слои? Сохранённые пресеты останутся. Действие можно отменить.'))return;
 layers=[];editingLayer=null;selectedComposition=null;$('compositionDuration').value=10;$('name').value='';renderLayers();status('Новая композиция');
});document.querySelector('.composition-head .tool-row').append(newProject);
const copyCode=button('Копировать Lua',async()=>{
 try{await navigator.clipboard.writeText($('code').value);status('Lua скопирован');}catch{$('code').focus();$('code').select();status('Код выделен — нажмите Ctrl+C');}
});$('selectCode').after(copyCode);
const inspectHint=document.createElement('p');inspectHint.className='effect-help';$('effectDict').after(inspectHint);
const workflowChoose=choose;
choose=function(e){workflowChoose(e);if(!e)return;inspectHint.textContent=({loop:'Непрерывные частицы. Время 0 — до остановки; локальный тест ограничен 30 секундами.',burst:'Разовая эмиссия. Стоп отменяет будущие повторы; выпущенные частицы исчезают сами.',light:'Точечный свет. Настройте цвет, радиус и яркость.',shape:'Геометрия через thehunt_shapes. Настройте масштаб, цвет и прозрачность.',postfx:'Экранный эффект: доступен только локальный тест.',timecycle:'Общий канал освещения. Доступность задаётся настройкой AllowTimecycle.'})[e.kind]||'';};
document.addEventListener('keydown',e=>{
 const typing=e.target.matches('input,textarea,select,[contenteditable=true]');
 if(!(e.ctrlKey||e.metaKey))return;
 if(e.key.toLowerCase()==='f'){e.preventDefault();document.querySelector('[data-tab=library]').click();$('search').focus();$('search').select();}
 if(e.key==='Enter'){e.preventDefault();(tab==='composition'?$('testComposition'):$('preview')).click();}
 if(!typing&&e.key.toLowerCase()==='z'){e.preventDefault();const label=e.shiftKey?'Повторить':'Отменить';[...document.querySelectorAll('.tool-row button')].find(b=>b.textContent===label)?.click();}
});
