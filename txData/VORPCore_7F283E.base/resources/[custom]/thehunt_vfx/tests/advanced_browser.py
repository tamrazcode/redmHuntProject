from playwright.sync_api import sync_playwright
from regression import ROOT
import json

with sync_playwright() as pw:
    browser=pw.chromium.launch(channel='msedge',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080})
    errors=[];requests=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('dialog',lambda d:d.accept())
    page.add_init_script("window.GetParentResourceName=()=> 'thehunt_vfx'")
    def route(r):
        requests.append((r.request.url,json.loads(r.request.post_data or '{}')))
        r.fulfill(status=200,content_type='application/json',body='{"ok":true}',headers={'Access-Control-Allow-Origin':'*'})
    page.route('https://thehunt_vfx/**',route)
    page.goto((ROOT/'html/index.html').as_uri())
    def message(action,data):
        page.evaluate('(m)=>window.dispatchEvent(new MessageEvent("message",{data:m}))',{'action':action,'data':data})
    message('catalog',[{'id':'light|point','name':'Point light','kind':'light'}])
    message('show',{})
    page.locator('#catalog .entry').click()
    page.locator('[data-tab=composition]').click();page.locator('#addLayer').click()
    page.get_by_role('button',name='Редактировать справа',exact=True).click()
    clip=page.locator('.timeline-clip').first
    clip.scroll_into_view_if_needed();box=clip.bounding_box()
    page.mouse.move(box['x']+10,box['y']+10);page.mouse.down();page.mouse.move(box['x']+70,box['y']+10,steps=8);page.mouse.up()
    assert page.evaluate('layers[0].at')>0
    resize=page.locator('.resize-clip').first;box=resize.bounding_box()
    before=page.evaluate('layers[0].params.lifetime')
    page.mouse.move(box['x']+4,box['y']+10);page.mouse.down();page.mouse.move(box['x']-40,box['y']+10,steps=8);page.mouse.up()
    assert page.evaluate('layers[0].params.lifetime')<before
    page.locator('#layers input[type=checkbox]').check()
    page.locator('#groupPanel>summary').click();page.locator('#groupName').fill('Orbital')
    page.get_by_role('button',name='Назначить группу',exact=True).click()
    page.locator('#gx').fill('2');page.locator('#gscale').fill('2')
    page.get_by_role('button',name='Применить к выделенным',exact=True).click()
    assert page.evaluate('layers[0].group')=='Orbital'
    assert page.evaluate('layers[0].params.offset.x')==2
    assert page.evaluate('layers[0].params.scale')==2
    page.locator('#generatorPanel>summary').click();page.locator('#generatorCount').fill('3')
    for kind in ['ring','sphere','spiral','wave']:
        page.locator('#generatorType').select_option(kind)
        page.get_by_role('button',name='Сгенерировать',exact=True).click()
    assert page.evaluate('layers.length')==13
    page.locator('#keyEditor>summary').click()
    page.locator('#keyTime').fill('0');page.get_by_role('button',name='Добавить кадр',exact=True).click()
    page.locator('#keyTime').fill('2');page.get_by_role('button',name='Добавить кадр',exact=True).click()
    assert page.locator('#keyList .key-row').count()==2
    page.get_by_role('button',name='Кадр 2',exact=True).click();page.locator('#scale').fill('3')
    page.get_by_role('button',name='Обновить кадр',exact=True).click()
    assert json.loads(page.locator('#trackJson').input_value())[1]['scale']==3
    page.get_by_role('button',name='Только выбранный слой',exact=True).click()
    page.get_by_role('button',name='Ⅱ Пауза',exact=True).click()
    page.locator('#transportSpeed').select_option('2')
    page.get_by_role('button',name='Продолжить',exact=True).click()
    assert any(url.endswith('/transport') and data.get('command')=='start' and len(data['definition']['phases'])==1 for url,data in requests)
    assert any(url.endswith('/transport') and data.get('command')=='pause' for url,data in requests)
    fixture={'world':[],'presets':{'Test':{'effectId':'light|point','params':{},'description':'Blue','verification':{'by':'Admin','date':'2026-09-10'}}},'reviews':{},'players':[],
        'annotations':{'light|point':{'note':'У входа','tags':['фонарь']}},
        'scenes':{'scene:1':{'name':'Lamp','enabled':False,'effectId':'light|point','params':{'coords':{'x':0,'y':0,'z':0}},'versions':[{'name':'Earlier','savedAt':'2026-09-10'}]}},'compositions':{}}
    message('studio',fixture)
    page.locator('[data-tab=library]').click();page.locator('#search').fill('фонарь')
    assert page.locator('#catalog .entry').count()==1
    page.locator('#reviewFilter').select_option('recent');assert page.locator('#catalog .entry').count()==1
    page.locator('[data-tab=presets]').click();page.locator('#onlyVerifiedPresets').check()
    assert page.locator('#presetList .entry:visible').count()==1
    page.locator('#presetList .entry button').first.click();assert page.locator('#name').input_value()=='Test'
    page.locator('[data-tab=world]').click()
    page.get_by_role('button',name='Показать',exact=True).click()
    page.get_by_role('button',name='Перенести в точку',exact=True).click()
    page.locator('#confirmAccept').click()
    page.get_by_role('button',name='Восстановить версию',exact=True).click()
    page.locator('#confirmAccept').click()
    assert any(d.get('action')=='manageScene' and d['data']['operation']=='restore' for _,d in requests)
    message('active',[{'id':'one','effectId':'light|point','state':'playing','owner':'studio','handles':0},{'id':'bad','effectId':'x','state':'failed','error':'Asset timeout','owner':'network'}])
    page.locator('[data-tab=diagnostics]').click()
    assert 'Asset timeout' in page.locator('#diagnostics').inner_text()
    page.locator('[data-tab=composition]').click()
    for width,height in [(1366,768),(1920,1080)]:
        page.set_viewport_size({'width':width,'height':height})
        for selector in ['#studio','.browser','aside']:
            assert page.locator(selector).evaluate('(e)=>e.scrollWidth<=e.clientWidth+1'),selector
    page.locator('.browser').evaluate('(e)=>e.scrollTop=0')
    page.locator('aside').evaluate('(e)=>e.scrollTop=0')
    page.screenshot(path=str(ROOT/'tests/advanced-desktop.png'))
    assert not errors,errors
    browser.close()
print('PASS: timeline drag/resize, groups, four generators, visual keys, solo transport, tags/recent, verified presets, scene actions, diagnostics, layouts')
