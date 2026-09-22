"""Offline Lua compilation and server authorization/payload boundary checks."""
import json
import re
import sys
from pathlib import Path
sys.path.insert(0, r'C:\Users\borch\AppData\Local\Temp\hunt-pedcustom-validation')
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=load(s,n); return f~=nil,e end')
paths = list(root.glob('*.lua')) + [root.parent/'thehunt_character'/p for p in
    ['client/creator.lua','client/main.lua','server/main.lua']]
paths.append(root.parent/'thehunt_items/server/main.lua')
for path in paths:
    source = re.sub(r'`[^`]+`', '123', path.read_text(encoding='utf-8-sig'))
    ok, error = compile_lua(source, str(path))
    assert ok, error
    print('Lua syntax OK:', path.name)

catalog = json.loads((root/'data/models.json').read_text())
assert len({x['model'] for x in catalog}) == len(catalog)
lua.execute('''
handlers = {}; writes=0; replies={}; allowed=true; source=7; clock=1000
exports = setmetatable({thehunt_core={IsPlayerAdmin=function() return allowed end,
    GetPlayerIdentifier=function() return 'owner-7' end}}, {__call=function() end})
function GetCurrentResourceName() return 'thehunt_pedcustom' end
function LoadResourceFile() return '' end
function RegisterNetEvent(name, fn) handlers[name]=fn end
function AddEventHandler() end
function Player() return {state={set=function() end}} end
function GetGameTimer() clock=clock+200; return clock end
function TriggerClientEvent(_,src,id,ok,data) replies[#replies+1]={ok=ok,data=data} end
function GetPlayerName() return 'Admin' end
json={decode=function() return {{model='mp_male',outfits=138},{model='a_c_bear_01',outfits=11}} end,
encode=function() return '{}' end}
MySQL={query={await=function() return {} end},scalar={await=function() return 0 end},
update={await=function() writes=writes+1; return 0 end},
insert={await=function() writes=writes+1;return 1 end},ready=function(fn) fn() end}
''')
lua.execute((root/'equipment.lua').read_text(encoding='utf-8'))
lua.execute((root/'server.lua').read_text(encoding='utf-8'))
lua.execute('''
local request=handlers['thehunt_pedcustom:request']
allowed=false; request(1,'save',{name='test',data={model='mp_male'}})
assert(writes==0 and not replies[#replies].ok, 'non-admin request reached database')
for _, action in ipairs({'list','get','apply','edit','spawn','registerSpawn','updateSpawn','removeSpawn','delete'}) do
    request(1,action,{})
    assert(not replies[#replies].ok and writes==0, 'non-admin accessed '..action)
end
allowed=true
request(2,'save',{name='test',data={model='unknown'}})
assert(not replies[#replies].ok and writes==0)
request(3,'save',{name='test',data={model='a_c_bear_01',outfit=11}})
assert(not replies[#replies].ok and writes==0)
request(4,'save',{name='test',data={model='mp_male',scale=0/0}})
assert(not replies[#replies].ok and writes==0)
request(5,'save',{name='test',data={model='mp_male',tags={{tint0=999}}}})
assert(not replies[#replies].ok and writes==0)
request(6,'save',{name='test',data={model='mp_male'}})
assert(replies[#replies].ok and writes==1)
request(7,'save',{id=1,revision=1,name='test',data={model='mp_male'}})
assert(not replies[#replies].ok, 'stale or foreign update accepted')
request(8,'removeSpawn',{net=999})
assert(not replies[#replies].ok, 'unmanaged entity deletion accepted')
''')
print('Server boundaries OK: all non-admin actions denied, models, outfit bounds, NaN, tints, save, stale ownership, entity scope')
print(f'Catalog: {len(catalog)} unique models')
