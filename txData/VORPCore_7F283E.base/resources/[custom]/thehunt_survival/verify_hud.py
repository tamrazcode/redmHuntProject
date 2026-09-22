from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True)
    page = browser.new_page(viewport={'width': 1280, 'height': 720}, device_scale_factor=1)
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto((root/'thehunt_status/html/index.html').as_uri())
    page.evaluate("window.postMessage({type:'SET_HUD_VISIBLE',visible:true}, '*')")
    for air, stress in [(-18,-1.1),(0,0),(38,1.1)]:
        page.evaluate('(v) => window.postMessage({type:"THERMAL_UPDATE",data:v},"*")', {'air':air,'stress':stress})
        page.wait_for_timeout(100)
        assert page.locator('#temperatureValue').inner_text() == f'{air}°'
        assert page.locator('#circleTemperature').is_visible()
    # Verify both edited JS programs parse in the actual Chromium engine.
    for resource in ['thehunt_status','thehunt_inventory']:
        page.evaluate('(s) => { new Function(s); }', (root/resource/'html/app.js').read_text(encoding='utf-8-sig'))
    page.evaluate("window.postMessage({type:'THERMAL_UPDATE',data:{air:-18,stress:-1}}, '*')")
    page.wait_for_timeout(500)
    page.screenshot(path=str(root/'thehunt_survival/hud-preview.png'), clip={'x':360,'y':630,'width':560,'height':90})
    page.evaluate("window.postMessage({type:'THERMAL_UPDATE',data:false}, '*')")
    page.wait_for_timeout(50)
    assert not page.locator('#circleTemperature').is_visible()
    assert not errors, errors
    browser.close()
print('Chromium: HUD negative/zero/hot/reset and JS syntax passed')
