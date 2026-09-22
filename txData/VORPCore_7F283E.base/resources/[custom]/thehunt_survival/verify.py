"""Offline regression checks; does not claim RedM runtime verification."""
from pathlib import Path
import re
from lupa import LuaRuntime

root = Path(__file__).resolve().parent.parent
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=load(s,n); return f ~= nil,e end')
files = list((root/'thehunt_survival').rglob('*.lua'))
for resource in ['thehunt_items','thehunt_animations','thehunt_status','thehunt_loot','thehunt_crafting']:
    files.extend((root/resource).rglob('*.lua'))
for path in files:
    source = re.sub(r'`[^`]*`', '1', path.read_text(encoding='utf-8-sig'))
    ok, error = compile_lua(source, str(path))
    assert ok, error
print(f'Lua syntax: {len(files)} files passed (RedM hash literals normalized)')
for path in ['thehunt_survival/config.lua','thehunt_survival/shared/thermal.lua','thehunt_items/shared/insulation.lua']:
    lua.execute((root/path).read_text(encoding='utf-8-sig'))
lua.execute('''
assert(Thermal.Target(22, 0, 0) == 0)
local bare = Thermal.Target(-10, 0, 0)
local dressed = Thermal.Target(-10, 24, 0)
local soaked = Thermal.Target(-10, 24, 1)
assert(bare < -1 and dressed > bare and soaked < dressed)
assert(Thermal.Target(35, 24, 0) > Thermal.Target(35, 0, 0))
assert(Thermal.Target(50, 0, 0) > 1)
assert(HuntInsulation.RingLh == nil and HuntInsulation.Belt == nil)
assert(HuntInsulation.Pant.level == 3 and HuntInsulation.Hat.level == 1)
local first = Thermal.Approach(-20, 40, 1, Config.AirTimeConstant)
assert(first > -20 and first < -16)
local many = -20
for i=1,60 do many=Thermal.Approach(many,40,1,Config.AirTimeConstant) end
assert(math.abs(many-Thermal.Approach(-20,40,60,Config.AirTimeConstant)) < 1e-8)
''')
lua.execute('exports = function(...) end')
lua.execute((root/'thehunt_items/shared/items.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
assert(Items.Get('clothing_pant').insulationLabel == 'Высокое утепление')
assert(Items.Get('clothing_pants').insulationLabel == 'Высокое утепление')
assert(Items.Get('clothing_ringlh').insulationLabel == nil)
assert(Items.Get('clothing_coatclosed').insulation.warmth == 8)
''')
print('Thermal balance, wet clothing, accessories, registry and smoothing checks passed')
