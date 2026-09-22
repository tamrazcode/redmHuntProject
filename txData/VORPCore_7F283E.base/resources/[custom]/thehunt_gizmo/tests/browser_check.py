from pathlib import Path
from playwright.sync_api import sync_playwright
import math
root=Path('txData/VORPCore_7F283E.base/resources/[custom]')
with sync_playwright() as pw:
 browser=pw.chromium.launch(channel='msedge',headless=True)
 page=browser.new_page(viewport={'width':1440,'height':900})
 errors=[];page.on('pageerror',lambda err:errors.append(str(err)))
 page.add_init_script('''window.GetParentResourceName=()=> 'thehunt_gizmo';window.requests=[];
 window.fetch=async(url,options)=>{const data=JSON.parse(options.body);requests.push({url,data});await new Promise(r=>setTimeout(r,15));return {json:async()=>({ok:true,value:data.reset?{x:0,y:0,z:0,rx:0,ry:0,rz:0}:data.value})};};''')
 page.goto((root/'thehunt_gizmo/html/index.html').resolve().as_uri())
 initial={k:0 for k in ['x','y','z','rx','ry','rz']}
 limits={k:([-45,45] if k.startswith('r') else [-.12,.12]) for k in initial}
 page.evaluate('(d)=>window.postMessage(d,"*")',{'type':'open','id':1,'title':'Расположение рюкзака','value':initial,'limits':limits})
 frame={'type':'frame','id':1,'origin':{'x':.5,'y':.5},'axes':{'x':{'x':.65,'y':.5},'y':{'x':.44,'y':.62},'z':{'x':.5,'y':.3}},'length':.22,'rings':{}}
 for axis,rx,ry in [('x',.06,.16),('y',.15,.06),('z',.12,.12)]:
  frame['rings'][axis]=[{'x':.5+rx*math.cos(i*math.pi/24),'y':.5+ry*math.sin(i*math.pi/24)} for i in range(49)]
 page.evaluate('(d)=>window.postMessage(d,"*")',frame)
 page.wait_for_selector('[data-axis="x"]',state='attached')
 page.mouse.move(860,450);page.wait_for_timeout(50)
 hover_stroke=page.locator('svg line').first.get_attribute('stroke')
 assert hover_stroke not in ('#ef4444','#ffffff'),hover_stroke
 page.mouse.move(860,450);page.mouse.down();page.wait_for_timeout(30)
 assert page.locator('svg line').first.get_attribute('stroke')=='#ffffff'
 page.mouse.move(950,450,steps=4);page.mouse.up();page.wait_for_timeout(120)
 moves=page.evaluate('requests.filter(r=>r.url.endsWith("/change"))')
 assert moves and 0<moves[-1]['data']['value']['x']<=.12,moves
 # Clamp well beyond permitted bounds.
 page.mouse.move(860,450);page.mouse.down();page.mouse.move(1400,450,steps=3);page.mouse.up();page.wait_for_timeout(100)
 assert page.evaluate('value.x')==.12
 page.keyboard.press('Tab');assert page.locator('#rotate').get_attribute('class')=='active'
 page.mouse.move(802,495);page.mouse.down();page.mouse.move(768,575,steps=5);page.mouse.up();page.wait_for_timeout(100)
 assert any(abs(n)>0 for n in page.evaluate('[value.rx,value.ry,value.rz]'))
 page.locator('#reset').click();page.wait_for_timeout(80);assert page.evaluate('value.x===0 && value.rx===0 && value.ry===0 && value.rz===0')
 page.screenshot(path='.tmp/backpack-gizmo-rotate.png',omit_background=True)
 page.keyboard.press('Tab');page.screenshot(path='.tmp/backpack-gizmo-move.png',omit_background=True)
 # Save must drain queued transformations before sending finish.
 page.mouse.move(860,450);page.mouse.down();page.mouse.move(900,450);page.mouse.up();page.keyboard.press('Enter');page.wait_for_timeout(120)
 requests=page.evaluate('requests');assert requests[-1]['url'].endswith('/finish') and requests[-1]['data']['save'] is True
 page.evaluate('window.postMessage({type:"close"},"*")');page.wait_for_timeout(30);assert page.locator('#editor').is_hidden()
 page.evaluate('(d)=>window.postMessage(d,"*")',{'type':'open','id':2,'title':'Тест','value':initial,'limits':limits})
 page.keyboard.press('Escape');page.wait_for_timeout(60);assert page.evaluate('requests.at(-1).data.save===false')
 assert not errors,errors
 # Parse and exercise the real inventory context menu without a game connection.
 page.goto((root/'thehunt_inventory/html/index.html').resolve().as_uri());page.wait_for_timeout(100)
 page.evaluate('app.style.display="flex";openContextMenu({dbId:42,name:"backpack_1",isBackpack:true,container:"equipment",count:1},{clientX:500,clientY:300})')
 assert page.locator('#btnContextPosition').is_visible()
 assert page.locator('#btnContextPosition svg').count()==1
 page.screenshot(path='.tmp/backpack-context-position.png',omit_background=True)
 page.locator('#btnContextPosition').click();page.wait_for_timeout(50)
 assert page.evaluate('requests.some(r=>r.url.endsWith("/positionBackpack") && r.data.dbId===42)')
 page.evaluate('openContextMenu({dbId:43,name:"apple",container:"main",count:1},{clientX:500,clientY:300})')
 assert page.locator('#btnContextPosition').is_hidden()
 # Hints stay clear of the bottom-centre status HUD.
 page.goto((root/'thehunt_gizmo/html/index.html').resolve().as_uri())
 assert page.locator('footer').evaluate('(e)=>getComputedStyle(e).bottom')=='142px'
 assert not errors,errors
 browser.close()
print('PASS browser: axis drag, rotation, clamp, reset, save ordering, Esc, transparent UI, inventory context integration')

