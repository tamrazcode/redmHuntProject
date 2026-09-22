from pathlib import Path
from lupa.lua54 import LuaRuntime
import re
lua=LuaRuntime(unpack_returned_tuples=True)
root=Path('txData/VORPCore_7F283E.base/resources/[custom]')
files=[root/'thehunt_gizmo/client.lua',root/'thehunt_items/shared/backpack.lua',root/'thehunt_items/server/main.lua',root/'thehunt_inventory/client/main.lua',root/'thehunt_inventory/client/backpack.lua',root/'thehunt_builder/client/streamer.lua']
for p in files:
 source=re.sub(r'`[^`]+`','0',p.read_text(encoding='utf-8-sig'))
 result=lua.eval('function(s,n) local f,e=load(s,n);return f~=nil,e end')(source,str(p))
 print(p.name,result)
 assert result[0]
source=(root/'thehunt_items/server/backpack_sync.lua').read_text(encoding='utf-8')
assert lua.eval('function(s) return load(s) ~= nil end')(source)
