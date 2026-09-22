"""Browser smoke test with mocked NUI transport, using installed Edge."""
from pathlib import Path
from playwright.sync_api import sync_playwright
from regression import runtime, ROOT
import json

lua=runtime()
catalog=[{k:v for k,v in e.items()} for _,e in lua.globals().FX.catalog.items()]
requests=[]
with sync_playwright() as pw:
    browser=pw.chromium.launch(channel='msedge',headless=True)
    page=browser.new_page(viewport={'width':1920,'height':1080},device_scale_factor=1)
    errors=[]
    page.on('pageerror',lambda err:errors.append(str(err)))
    page.add_init_script("window.GetParentResourceName=()=> 'thehunt_vfx';")
    def route(r):
        requests.append((r.request.url,r.request.post_data))
        r.fulfill(status=200,content_type='application/json',body=json.dumps({'ok':True,'coords':{'x':-100,'y':200,'z':30}}),headers={'Access-Control-Allow-Origin':'*'})
    page.route('https://thehunt_vfx/**',route)
    page.goto((ROOT/'html/index.html').as_uri())
    assert not errors,errors
    page.evaluate("(data)=>window.dispatchEvent(new MessageEvent('message',{data:{action:'catalog',data}}))",catalog)
    page.evaluate("window.dispatchEvent(new MessageEvent('message',{data:{action:'show'}}))")
    assert page.locator('#catalog .entry').count()==60
    page.locator('#search').fill('ent_amb_elec_crackle')
    assert page.locator('#catalog .entry').count()>0
    page.locator('#catalog .entry').first.click()
    page.locator('#here').click()
    page.wait_for_function("document.getElementById('x').value==='-100.000'")
    page.locator('#preview').click()
    page.locator('[data-tab=composition]').click()
    page.locator('#addLayer').click()
    assert page.locator('#layers .entry').count()==1
    page.locator('#layers input[type=number]').fill('2')
    page.locator('#exchangePanel summary').click()
    page.locator('#compositionCode').click()
    assert 'at = 2' in page.locator('#compositionOutput').input_value()
    assert 'PlaySequence' in page.locator('#compositionOutput').input_value()
    page.locator('#testComposition').click()
    page.wait_for_timeout(100)
    assert any(url.endswith('/transport') and json.loads(body).get('definition',{}).get('phases',[{}])[0].get('at')==2 for url,body in requests)
    page.locator('[data-tab=library]').click()
    page.wait_for_timeout(100)
    assert any(url.endswith('/preview') for url,_ in requests)
    page.locator('aside details').filter(has_text='Смещение и вращение').locator('summary').click()
    page.locator('#ox').fill('0.2')
    page.locator('[data-tab=api]').click()
    assert 'PlayEffect' in page.locator('#code').input_value()
    page.locator('[data-tab=library]').click()
    page.locator('#search').fill('')
    assert page.locator('aside').evaluate('(e)=>e.scrollWidth<=e.clientWidth'), 'Inspector overflows horizontally'
    page.screenshot(path=str(ROOT/'tests/studio-desktop.png'))
    page.evaluate("window.dispatchEvent(new MessageEvent('message',{data:{action:'studio',data:{world:[{id:'example',effectId:'light|point',params:{coords:{x:0,y:0,z:0}},owner:'persistent',name:'<script>bad</script>'}],presets:{},reviews:{},players:[]}}}))")
    page.locator('[data-tab=world]').click()
    assert '<script>bad</script>' in page.locator('#worldList').inner_text()
    assert page.locator('#worldList script').count()==0
    page.keyboard.press('Escape')
    page.wait_for_timeout(100)
    assert any(url.endswith('/close') for url,_ in requests)
    assert not errors,errors
    browser.close()
print('PASS: Edge/Chromium NUI, full catalog pagination/search, preview transport, coordinate roundtrip, API code, escaped names, Escape, no JS errors')
