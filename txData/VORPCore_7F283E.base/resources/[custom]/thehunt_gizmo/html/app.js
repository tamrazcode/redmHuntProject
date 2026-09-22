'use strict';
const editor = document.getElementById('editor'), svg = document.getElementById('gizmo');
const colors = {x:'#ef4444', y:'#22c55e', z:'#38bdf8'};
let id = null, value = {}, limits = {}, frame = null, mode = 'move', drag = null, camera = null, hoverAxis = null;
let queued = null, sending = false, closing = false, drainWaiters = [];
let allowRotation = true, allowScale = false, canCancelAction = false;
const post = (event, data={}) => fetch(`https://${GetParentResourceName()}/${event}`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({id,...data})}).then(r=>r.json());
function displayValue() {
  document.getElementById('readout').textContent = mode === 'move'
    ? `X ${(value.x*100).toFixed(1)} см   ·   Y ${(value.y*100).toFixed(1)} см   ·   Z ${(value.z*100).toFixed(1)} см`
    : mode === 'scale'
      ? `X ${value.sx.toFixed(1)} м   ·   Y ${value.sy.toFixed(1)} м   ·   Z ${value.sz.toFixed(1)}`
      : `X ${value.rx.toFixed(1)}°   ·   Y ${value.ry.toFixed(1)}°   ·   Z ${value.rz.toFixed(1)}°`;
}
async function pump() {
  if (sending) return;
  sending = true;
  try {
    while (queued && id !== null) {
      const data = queued, requestId = id; queued = null;
      const result = await post('change', data);
      if (requestId === id && result.ok && !queued) {value = result.value; displayValue();}
    }
  } catch (_) { queued = null; }
  finally { sending = false; drainWaiters.splice(0).forEach(resolve=>resolve()); }
}
function change(next) {
  for (const [key,range] of Object.entries(limits)) next[key]=Math.max(range[0],Math.min(range[1],next[key]));
  value = next; displayValue(); queued = {value:{...next}}; pump();
}
async function finish(save) {
  if (closing || id === null) return;
  closing = true; drag = null;
  if (sending) await new Promise(resolve=>drainWaiters.push(resolve));
  await post('finish',{save}).catch(()=>{});
  closing = false;
}
function setMode(next) {
  if (next === 'rotate' && !allowRotation) return;
  if (next === 'scale' && !allowScale) return;
  mode = next; drag = null;
  if (id !== null) post('mode',{mode}).catch(()=>{});
  document.getElementById('move').classList.toggle('active',mode==='move');
  document.getElementById('rotate').classList.toggle('active',mode==='rotate');
  document.getElementById('scale').classList.toggle('active',mode==='scale');
  displayValue(); render();
}
const px = p => ({x:p.x*innerWidth,y:p.y*innerHeight});
function axisColor(axis) {
  if (drag?.axis === axis) return '#ffffff';
  if (hoverAxis !== axis) return colors[axis];
  const base=colors[axis].slice(1).match(/../g).map(v=>parseInt(v,16));
  return '#'+base.map(v=>Math.round(v+(255-v)*.55).toString(16).padStart(2,'0')).join('');
}
function ringAngle(ring, x, y) {
  let best=Infinity, angle=0;
  for(let i=0;i<ring.length-1;i++) {
    const a=px(ring[i]), b=px(ring[i+1]), dx=b.x-a.x, dy=b.y-a.y;
    const t=Math.max(0,Math.min(1,((x-a.x)*dx+(y-a.y)*dy)/(dx*dx+dy*dy || 1)));
    const distance=(x-a.x-dx*t)**2+(y-a.y-dy*t)**2;
    if(distance<best){best=distance;angle=(i+t)/(ring.length-1)*Math.PI*2;}
  }
  return angle;
}
function element(name, attrs) {
  const e = document.createElementNS('http://www.w3.org/2000/svg',name);
  Object.entries(attrs).forEach(([k,v])=>e.setAttribute(k,v)); svg.appendChild(e); return e;
}
function render() {
  svg.replaceChildren();
  if (!frame || !frame.origin) return;
  const o = px(frame.origin);
  for (const axis of ['x','y','z']) {
    const color=axisColor(axis), width=drag?.axis===axis ? 5 : hoverAxis===axis ? 4 : 3;
    if (mode==='move' || mode==='scale') {
      if (!frame.axes[axis]) continue;
      const p = px(frame.axes[axis]), dx=p.x-o.x, dy=p.y-o.y, len=Math.hypot(dx,dy);
      if (len < 12) continue;
      element('line',{x1:o.x,y1:o.y,x2:p.x,y2:p.y,stroke:color,'stroke-width':width,'pointer-events':'none'});
      const ux=dx/len,uy=dy/len;
      element('polygon',{points:`${p.x},${p.y} ${p.x-ux*13-uy*5},${p.y-uy*13+ux*5} ${p.x-ux*13+uy*5},${p.y-uy*13-ux*5}`,fill:color,'pointer-events':'none'});
      element('line',{x1:o.x+ux*14,y1:o.y+uy*14,x2:p.x,y2:p.y,stroke:'transparent','stroke-width':18,'data-axis':axis,class:'hit'});
      const label=element('text',{x:p.x+8,y:p.y-8,fill:color,'font-size':14,'font-weight':700,'pointer-events':'none'});label.textContent=axis.toUpperCase();
    } else {
      const ring=frame.rings[axis]; if (!ring || ring.length < 2) continue;
      const points=ring.map(p=>`${p.x*innerWidth},${p.y*innerHeight}`).join(' ');
      element('polyline',{points,fill:'none',stroke:color,'stroke-width':width,'pointer-events':'none'});
      element('polyline',{points,fill:'none',stroke:'transparent','stroke-width':15,'data-axis':axis,class:'hit'});
    }
  }
  element('circle',{cx:o.x,cy:o.y,r:4,fill:'#fff','pointer-events':'none'});
}
svg.addEventListener('pointerdown',e=>{
  if (closing) return;
  if (e.button===2) {camera={x:e.clientX,y:e.clientY};return;}
  const axis=e.target.dataset.axis;
  if (e.button!==0 || !axis || !frame?.origin) return;
  const o=px(frame.origin), p=frame.axes[axis] ? px(frame.axes[axis]) : o;
  const ring=frame.rings[axis] || [];
  drag={axis,x:e.clientX,y:e.clientY,start:{...value},o,dx:p.x-o.x,dy:p.y-o.y,ring,
    angle:ringAngle(ring,e.clientX,e.clientY),total:0};
  hoverAxis=axis; render();
});
window.addEventListener('pointermove',e=>{
  if (camera) {
    post('camera',{dx:e.clientX-camera.x,dy:e.clientY-camera.y}).catch(()=>{});
    camera={x:e.clientX,y:e.clientY};return;
  }
  if (!drag || closing) {
    const next=e.target?.dataset?.axis || null;
    if(next!==hoverAxis){hoverAxis=next;render();}
    return;
  }
  const d=drag, next={...d.start}, fine=e.shiftKey ? .15 : 1;
  if (mode==='move') {
    const len2=d.dx*d.dx+d.dy*d.dy; if (len2<144) return;
    next[d.axis]+=((e.clientX-d.x)*d.dx+(e.clientY-d.y)*d.dy)/len2*frame.length*fine;
  } else if (mode==='scale') {
    const len2=d.dx*d.dx+d.dy*d.dy; if (len2<144) return;
    next['s'+d.axis]+=((e.clientX-d.x)*d.dx+(e.clientY-d.y)*d.dy)/len2*frame.length*fine;
  } else {
    const angle=ringAngle(d.ring,e.clientX,e.clientY);
    let delta=angle-d.angle;
    if(delta>Math.PI)delta-=Math.PI*2;if(delta<-Math.PI)delta+=Math.PI*2;
    d.total+=delta*fine;d.angle=angle;
    next['r'+d.axis]+=d.total*180/Math.PI*(d.axis==='y'?-1:1);
  }
  change(next);
});
window.addEventListener('pointerup',()=>{drag=null;camera=null;render();});
window.addEventListener('blur',()=>{drag=null;camera=null;hoverAxis=null;render();});
svg.addEventListener('pointerleave',()=>{if(!drag){hoverAxis=null;render();}});
window.addEventListener('contextmenu',e=>e.preventDefault());
window.addEventListener('keydown',e=>{
  if(id===null)return;
  if(['Tab','Enter','Escape'].includes(e.key))e.preventDefault();
  if(e.repeat)return;
  if(e.key==='F1' && canCancelAction){e.preventDefault();post('cancelAction').catch(()=>{});return;}
  if(e.key==='Escape')finish(false);
  if(e.key==='Enter')finish(true);
  if(e.key==='Tab') {
    if(mode==='move') setMode(allowRotation?'rotate':(allowScale?'scale':'move'));
    else if(mode==='rotate') setMode(allowScale?'scale':'move');
    else setMode('move');
  }
});
document.getElementById('move').onclick=()=>setMode('move');
document.getElementById('rotate').onclick=()=>setMode('rotate');
document.getElementById('scale').onclick=()=>setMode('scale');
document.getElementById('save').onclick=()=>finish(true);
document.getElementById('cancel').onclick=()=>finish(false);
document.getElementById('reset').onclick=()=>{drag=null;queued={reset:true};pump();};
window.addEventListener('message',({data:d})=>{
  if(d.type==='open'){id=d.id;value=d.value;limits=d.limits || {};allowRotation=d.allowRotation!==false;allowScale=d.allowScale===true;canCancelAction=d.cancelAction===true;document.getElementById('rotate').hidden=!allowRotation;document.getElementById('scale').hidden=!allowScale;document.getElementById('modeHint').hidden=!allowRotation&&!allowScale;document.getElementById('dragHint').textContent=(allowRotation||allowScale)?'Тянуть ось / кольцо':'Тянуть ось';frame=null;drag=null;camera=null;hoverAxis=null;closing=false;editor.hidden=false;document.getElementById('title').textContent=d.title;setMode('move');}
  if(d.type==='close'){id=null;editor.hidden=true;drag=null;camera=null;hoverAxis=null;queued=null;frame=null;svg.replaceChildren();}
  if(d.type==='frame' && d.id===id){frame=d;render();}
});
