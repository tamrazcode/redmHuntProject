from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path('txData/VORPCore_7F283E.base/resources/[custom]')
s=(root/'thehunt_builder/client/streamer.lua').read_text(encoding='utf-8')
start=s.index('function Streamer.DequeueSpawn(');end=s.index('\n-- ',start)
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('Streamer={};queuedProps={};spawnQueue={};spawnQueueDirty=false')
lua.execute(s[start:end])
lua.execute('''
local visits=0
spawnQueue=setmetatable({}, {__len=function()visits=visits+1;return 0 end})
for id=1,5000 do Streamer.DequeueSpawn(id)end
assert(visits==0,'distant objects must not inspect the queue')
spawnQueue={{p={id=2}},{p={id=3}}};queuedProps={[2]=spawnQueue[1],[3]=spawnQueue[2]}
Streamer.DequeueSpawn(2)
assert(#spawnQueue==1 and spawnQueue[1].p.id==3 and queuedProps[2]==nil and queuedProps[3] and spawnQueueDirty)
''')
print('PASS builder: 5000 absent removals perform zero queue scans; queued removal still removes the exact ID')
