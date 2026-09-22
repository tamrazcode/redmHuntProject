'use strict';
// Reorganise existing controls: IDs and their handlers remain the same.
function section(title,description,collapsible=false){
 const node=document.createElement(collapsible?'details':'section');node.className='work-section';
 const heading=document.createElement(collapsible?'summary':'h3');heading.textContent=title;node.append(heading);
 if(description){const text=document.createElement('p');text.textContent=description;node.append(text);}
 return node;
}
const project=document.createElement('div');project.className='project-strip';
const nameLabel=$('name').parentElement;nameLabel.firstChild.nodeValue='Название пресета / композиции';project.append(nameLabel);
const hint=document.createElement('span');hint.textContent='Эффект → параметры → слой → композиция';project.append(hint);
document.querySelector('nav').after(project);
document.querySelector('h1').innerHTML='VFX Studio <span>WORKSPACE</span>';
document.querySelector('[data-tab=library]').textContent='Библиотека';
document.querySelector('[data-tab=presets]').textContent='Мои сборки';
document.querySelector('aside').setAttribute('aria-label','Инспектор эффекта');
const inspectorTitle=document.createElement('div');inspectorTitle.className='eyebrow';inspectorTitle.textContent='ИНСПЕКТОР СЛОЯ';document.querySelector('aside').prepend(inspectorTitle);
const composition=$('composition');
const directButtons=node=>Array.from(node.children).filter(child=>child.tagName==='BUTTON');
const allButtons=directButtons(composition);
const head=section('Композиция','Добавьте эффекты из библиотеки. Выберите слой, измените параметры в инспекторе и примените изменения.');
head.classList.add('composition-head');head.append($('compositionDuration').parentElement);
const addTools=document.createElement('div');addTools.className='tool-row';
addTools.append(button('Выбрать эффект в библиотеке',()=>document.querySelector('[data-tab=library]').click()),$('addLayer'));head.append(addTools);
const timeline=section('Слои и таймлайн','Полоса — интервал жизни слоя. Выключенные слои остаются в проекте.');
timeline.classList.add('timeline-section');timeline.append($('layers'));
const empty=document.createElement('div');empty.id='emptyLayers';empty.textContent='Пока нет слоёв. Выберите эффект в библиотеке и нажмите «Добавить слоем».';timeline.append(empty);
const playback=section('Просмотр и запуск','Локальный тест видите только вы. Общий запуск доступен игрокам вашего измерения.');
const savePanel=section('Сохранение','Пресет сохраняет сборку. Постоянная сцена повторяет её в выбранной точке мира.');
const generators=section('Генераторы','Быстро создают несколько слоёв из выбранного эффекта.',true);
const exchange=section('Импорт, экспорт и API','JSON — перенос сборки; Lua — подключение к игровому ресурсу.',true);exchange.id='exchangePanel';
const historyTools=document.createElement('div');historyTools.className='tool-row';
for(const b of allButtons){
 if(b.id==='addLayer')continue;
 const text=b.textContent;
 if(text==='Отменить'||text==='Повторить')historyTools.append(b);
 else if(b===$('compositionCode')||b===exportComposition||b===importComposition)exchange.append(b);
 else if(text.includes('Кольцо из')||text.includes('Пара слоёв'))generators.append(b);
 else if(text.includes('Сохранить')||text.includes('Новая композиция'))savePanel.append(b);
 else playback.append(b);
}
head.append(historyTools);const outputNode=$('compositionOutput');exchange.append(outputNode);outputNode.placeholder='Экспортируйте сборку или вставьте JSON для импорта';outputNode.readOnly=false;
composition.replaceChildren(head,timeline,playback,savePanel,generators,exchange);
$('saveComposition').textContent='Сохранить как пресет';$('testComposition').textContent='▶ Тест всей композиции';$('compositionCode').textContent='Сформировать Lua';$('addLayer').textContent='+ Добавить слоем';
const originalRenderLayers=renderLayers;
renderLayers=function(){originalRenderLayers();$('emptyLayers').hidden=layers.length>0;
 for(const [index,row] of [...$('layers').children].entries()){
  row.classList.toggle('muted-layer',layers[index] && layers[index].enabled===false);
  const actions=document.createElement('div');actions.className='layer-actions';
  for(const b of directButtons(row))actions.append(b);
  row.append(actions);
 }
};renderLayers();
const libraryHeader=document.createElement('div');libraryHeader.className='library-caption';libraryHeader.textContent='Найдите эффект → настройте в инспекторе → добавьте в композицию';$('library').prepend(libraryHeader);
const quickAdd=button('+ В композицию',()=>{$('addLayer').click();compositionNav.click();});quickAdd.className='primary wide';$('favorite').after(quickAdd);
motionPanel.classList.add('inspector-section');trackPanel.classList.add('inspector-section');
for(const node of [playback,savePanel,generators,exchange])for(const b of directButtons(node))b.classList.add('panel-action');
// A compact mode leaves more of the game world visible.
const compact=button('Компактно',()=>{$('studio').classList.toggle('compact');compact.textContent=$('studio').classList.contains('compact')?'Развернуть':'Компактно';});document.querySelector('header').insertBefore(compact,$('close'));
