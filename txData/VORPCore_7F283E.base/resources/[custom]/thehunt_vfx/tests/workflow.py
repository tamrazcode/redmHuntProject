"""Regression checks for editor state, draft recovery and viewport layout."""
from playwright.sync_api import sync_playwright
from regression import ROOT
import json

with sync_playwright() as pw:
    browser = pw.chromium.launch(channel='msedge', headless=True)
    page = browser.new_page(viewport={'width': 1366, 'height': 768})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.add_init_script("window.GetParentResourceName=()=> 'thehunt_vfx'")
    page.route('https://thehunt_vfx/**', lambda r: r.fulfill(status=200, content_type='application/json', body='{"ok":true}', headers={'Access-Control-Allow-Origin':'*'}))
    def open_studio():
        page.goto((ROOT/'html/index.html').as_uri())
        page.evaluate("window.dispatchEvent(new MessageEvent('message',{data:{action:'catalog',data:[{id:'light|point',name:'Point light',kind:'light'}]}}))")
        page.evaluate("window.dispatchEvent(new MessageEvent('message',{data:{action:'show'}}))")
    open_studio()
    page.locator('#catalog .entry').click()
    page.locator('[data-tab=composition]').click()
    page.locator('#addLayer').click()
    page.get_by_role('button', name='Выключить слой', exact=True).click()
    page.get_by_role('button', name='Редактировать справа', exact=True).click()
    assert page.locator('.editing-layer').count() == 1
    page.locator('#scale').fill('2')
    page.get_by_role('button', name='Применить к слою', exact=True).click()
    assert page.evaluate('layers[0].enabled') is False
    assert page.evaluate('layers[0].params.scale') == 2
    assert page.locator('#testComposition').is_disabled()
    page.get_by_role('button', name='Включить слой', exact=True).click()
    page.get_by_role('button', name='Дублировать', exact=True).click()
    assert page.locator('#layers .entry').count() == 2
    page.locator('#layers input[type=number]').first.fill('20')
    page.locator('#layers input[type=number]').first.press('Tab')
    assert page.locator('#testComposition').is_disabled()
    assert 'Слой 1' in page.locator('#compositionDiagnostics').inner_text()
    page.locator('#layers input[type=number]').first.fill('1')
    page.locator('#layers input[type=number]').first.press('Tab')
    page.locator('#name').fill('QA draft')
    page.locator('#name').press('Tab')
    open_studio()
    page.get_by_role('button', name='Восстановить черновик (2 слоёв)', exact=True).click()
    assert page.locator('#name').input_value() == 'QA draft'
    assert page.evaluate('layers[0].params.scale') == 2
    page.keyboard.press('Control+z')
    assert page.locator('#layers .entry').count() == 0
    page.keyboard.press('Control+Shift+z')
    assert page.locator('#layers .entry').count() == 2
    page.evaluate("load({attach:true,bone:'SKEL_R_Hand'})")
    assert page.locator('#boneMenu input[value=SKEL_R_Hand]').is_checked()
    page.evaluate("layers=Array.from({length:24},()=>({at:0,effectId:'light|point',params:{}}));renderLayers()")
    page.get_by_role('button', name='Дублировать', exact=True).first.click()
    assert page.evaluate('layers.length') == 24
    page.get_by_role('button', name='Очистить композицию', exact=True).click()
    assert page.locator('#vfxConfirm').is_visible()
    assert page.evaluate('layers.length') == 24
    page.keyboard.press('Escape')
    assert page.locator('#vfxConfirm').is_hidden()
    assert page.evaluate('layers.length') == 24
    page.get_by_role('button', name='Очистить композицию', exact=True).click()
    page.locator('#confirmAccept').click()
    assert page.evaluate('layers.length') == 0
    for width, height in [(1366,768),(1920,1080)]:
        page.set_viewport_size({'width':width,'height':height})
        for selector in ['#studio','aside','.browser']:
            assert page.locator(selector).evaluate('(e)=>e.scrollWidth<=e.clientWidth+1'), selector
        box=page.locator('#studio').bounding_box()
        assert box['y']+box['height']<=height
    page.screenshot(path=str(ROOT/'tests/workflow-desktop.png'))
    assert not errors, errors
    browser.close()
print('PASS: layer editing/enabled state, limits, timing, draft recovery, undo/redo, legacy bone, 768p/1080p layout')
