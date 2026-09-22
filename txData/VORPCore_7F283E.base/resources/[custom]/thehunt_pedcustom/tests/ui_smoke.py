"""Headless NUI checks; does not connect to the game or live server."""
import functools
import http.server
import json
import subprocess
import sys
import threading
from pathlib import Path
sys.path.insert(0, r'C:\Users\borch\AppData\Local\Temp\hunt-pedcustom-validation')
import playwright
from playwright.sync_api import sync_playwright
root = Path(__file__).resolve().parents[1]
node = Path(playwright.__file__).parent/'driver/node.exe'
for path in [root/'html/app.js', root.parent/'thehunt_character/html/js/creator.js']:
    subprocess.run([str(node), '--check', str(path)], check=True)
class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=str(root.parent)))
threading.Thread(target=server.serve_forever, daemon=True).start()
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True)
    page = browser.new_page(viewport={'width':1440,'height':1000})
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.add_init_script("window.GetParentResourceName=()=> 'thehunt_pedcustom';")
    page.route('https://thehunt_pedcustom/**', lambda route: route.fulfill(
        content_type='application/json', body=json.dumps({'ok':True,'data':True})))
    page.goto(f'http://127.0.0.1:{server.server_port}/thehunt_pedcustom/html/index.html')
    page.wait_for_function('models.length > 1900')
    page.evaluate("window.postMessage({action:'open'},'*')")
    page.locator('#search').fill('a_c_bear_01')
    page.locator('#list button').first.click()
    assert page.locator('#title').inner_text() == 'a_c_bear_01'
    assert page.locator('#edit').is_disabled()
    page.locator('#search').fill('mp_female')
    page.locator('#list button').first.click()
    assert page.locator('#edit').is_enabled()
    page.locator('#name').fill('Тестовый пресет')
    page.evaluate("void studioConfirm('Удалить тест?').then(x=>window.answer=x)")
    page.locator('#no').click()
    assert page.evaluate('window.answer') is False
    assert page.evaluate("getComputedStyle(document.body).backgroundColor") == 'rgba(0, 0, 0, 0)'
    page.screenshot(path=str(root/'tests/ui-smoke.png'))
    assert not errors, errors
    browser.close()
server.shutdown()
print('UI OK: model search, animal/human editor gating, input, inline cancellation, transparency; JS syntax OK')
