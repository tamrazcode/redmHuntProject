"""Headless NUI checks using mocked callbacks, never a game client."""
import json
import os
import sys
from pathlib import Path
sys.path.insert(0, os.path.join(os.environ.get('TEMP', ''), 'hunt-pedcustom-validation'))
from lupa import LuaRuntime, lua_type
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
for file in ['shared/models.lua', 'config.lua', 'shared/definitions.lua']:
    lua.execute((root/file).read_text(encoding='utf-8'))
def plain(value):
    if lua_type(value) != 'table': return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and set(keys) == set(range(1, len(keys)+1)):
        return [plain(value[i]) for i in range(1, len(keys)+1)]
    return {k:plain(v) for k,v in value.items()}

defaults = plain(lua.globals().Zombie.defaults)
defaults['models'] = []
data = {'zones':[], 'defaults':defaults, 'profiles':plain(lua.globals().ZombieConfig.Profiles),
        'models':plain(lua.globals().ZombieModels),'paused':False,'immune':False,'info':False,'debug':False,'total':0}
calls = []
def handle(route):
    endpoint = route.request.url.rsplit('/', 1)[-1]
    body = route.request.post_data_json
    result = {'ok':True}
    if endpoint == 'position': result = {'x':123.45,'y':-22.5,'z':77.0}
    elif endpoint == 'request':
        action = body['action']; args = body['args']; calls.append(action)
        if action == 'list': result['data'] = data
        elif action == 'save':
            zone = args['zone']; zone.update(id=1,revision=1,alive=0,active=False)
            data['zones'] = [zone]; result['data'] = {'id':1,'revision':1}
        elif action == 'delete': data['zones'] = []; result['data'] = {}
        else: result['data'] = {}
    route.fulfill(status=200,content_type='application/json',body=json.dumps(result))

with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge',headless=True)
    page = browser.new_page(viewport={'width':1920,'height':1080})
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.route('https://thehunt_zombie/**',handle)
    page.goto((root/'html/index.html').as_uri())
    assert page.evaluate('getComputedStyle(document.body).display') == 'none'
    page.evaluate('(data)=>window.postMessage({action:"open",data,position:{x:0,y:0,z:0}},"*")',data)
    assert page.evaluate('getComputedStyle(document.body).display') == 'block'
    page.wait_for_timeout(1100)
    assert calls.count('list') >= 1, calls
    page.locator('#new').click()
    page.locator('#f-name').fill('Тестовая зона')
    page.wait_for_timeout(1100)
    assert page.locator('#f-name').input_value() == 'Тестовая зона'
    page.locator('#f-profile').select_option('hollow')
    assert page.locator('#f-headshotOnly').is_checked()
    assert page.locator('#f-walkStyle').input_value() == 'MP_Style_drunk'
    assert page.locator('#f-weaponDamage').input_value() == '30'
    page.locator('#f-enabled').uncheck()
    page.locator('#f-name').fill('Тестовая зона')
    page.locator('#f-name').blur()
    page.screenshot(path=str(root/'tests/editor.png'))
    page.locator('button[type=submit]').click()
    page.wait_for_function('document.getElementById("zoneTitle").textContent.includes("#1")')
    assert data['zones'][0]['enabled'] is False
    assert data['zones'][0]['headshotOnly'] is True
    assert data['zones'][0]['walkStyle'] == 'MP_Style_drunk'
    assert data['zones'][0]['weaponDamage'] == 30
    assert data['zones'][0]['x']==123.45
    # Every generated field must round-trip through the actual form payload.
    expected = page.evaluate('''() => {
      const values={};
      for(const c of document.querySelectorAll('#fields input,#fields select')) {
        values[c.name]=c.type==='checkbox'?c.checked:c.type==='number'?Number(c.value):c.value;
      }
      return values;
    }''')
    for key,value in expected.items():
        assert data['zones'][0][key] == value, (key,value,data['zones'][0].get(key))
    assert len(expected) == 39, len(expected)
    page.locator('#delete').click()
    page.locator('#confirm').wait_for(state='visible')
    page.keyboard.press('Escape')
    page.locator('#confirm').wait_for(state='hidden')
    assert 'delete' not in calls
    page.locator('#delete').click();page.locator('#acceptConfirm').click()
    page.locator('#empty').wait_for(state='visible')
    assert calls.count('delete')==1 and not data['zones']
    assert not errors, errors
    page.locator('#close').click();page.locator('#app').wait_for(state='hidden')
    browser.close()
print('PASS: NUI profile fields, false flags, coordinates, save/refresh, confirmation Escape, delete, close; no JS errors')
