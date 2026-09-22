"""Isolated persistence/transport regressions. No live server writes."""
from regression import runtime, ROOT

s=runtime(server=True)
s.execute(r'''
advance(1)
function latest()
 for i=#sent,1,-1 do if sent[i].name=='thehunt_vfx:studio' then return sent[i].args[1] end end
end
function act(name,data,src) advance(200);dispatch('thehunt_vfx:action',src or 1,name,data) end
act('spawn',{effectId='light|point',params={coords={x=1,y=2,z=3},lifetime=0}})
local key=latest().world[1].id
act('saveScene',{id=key,name='Lamp'})
assert(latest().scenes[key])
act('manageScene',{kind='scene',id=key,operation='toggle'})
assert(latest().scenes[key].enabled==false and #latest().world==0)
act('manageScene',{kind='scene',id=key,operation='move',coords={x=9,y=8,z=7}})
assert(latest().scenes[key].params.coords.x==9)
act('manageScene',{kind='scene',id=key,operation='restore',version=1})
assert(latest().scenes[key].params.coords.x==1)
act('manageScene',{kind='scene',id=key,operation='duplicate'})
assert(FX.count(latest().scenes)==2)
for _,e in pairs(latest().scenes) do assert(e.enabled==false) end
writeOK=false
act('manageScene',{kind='scene',id=key,operation='toggle'})
assert(latest().scenes[key].enabled==false,'failed write changed enabled state')
writeOK=true
for i=1,10 do act('manageScene',{kind='scene',id=key,operation='move',coords={x=i,y=0,z=0}}) end
assert(#latest().scenes[key].versions==8)
local before=latest().scenes[key].params.coords.x
act('manageScene',{kind='scene',id=key,operation='move',coords={x=999,y=0,z=0}},2)
dispatch('thehunt_vfx:open',1)
assert(latest().scenes[key].params.coords.x==before,'nonadmin wrote scene')
players[1]=1
act('manageScene',{kind='scene',id=key,operation='toggle'})
players[1]=0;dispatch('thehunt_vfx:open',1)
assert(latest().scenes[key].enabled==false,'cross-bucket mutation')
act('annotate',{effectId='light|point',tags={'lamp','свет'},note='blue light'})
assert(latest().annotations['light|point'].note=='blue light')
act('preset',{name='Lamp',effectId='light|point',params={}})
act('describePreset',{name='Lamp',description='Point light',verified=true})
assert(latest().presets.Lamp.verification.by=='Player1')
local def={duration=1,phases={{at=0,effectId='light|point',group='Ring',params={lifetime=1}}}}
act('saveWorldComposition',{name='Composition',coords={x=0,y=0,z=0},definition=def})
local compKey=next(latest().compositions)
assert(latest().compositions[compKey].definition.phases[1].group=='Ring')
act('manageScene',{kind='composition',id=compKey,operation='toggle'})
advance(1500);dispatch('thehunt_vfx:open',1)
for _,e in ipairs(latest().world) do assert(e.owner~='scene:'..compKey,'hidden composition restarted') end
fixture={version=4,scenes=FX.copy(latest().scenes),presets=FX.copy(latest().presets),reviews={},compositions=FX.copy(latest().compositions),annotations=FX.copy(latest().annotations)}
''')
# Reinitialize a fresh server with the persisted records, including hidden scenes.
reload=runtime(server=True)
fixture=s.eval('fixture')
def convert(value):
    if hasattr(value,'items'):
        return reload.table_from({k:convert(v) for k,v in value.items()})
    return value
reload.globals().fixture=convert(fixture)
reload.execute("function LoadResourceFile() return 'fixture' end;json.decode=function() return fixture end;advance(1);dispatch('thehunt_vfx:open',1)")
reload.execute(r'''
local data
for _,msg in ipairs(sent) do if msg.name=='thehunt_vfx:studio' then data=msg.args[1] end end
assert(#data.world==0,'hidden scene visible after restart')
assert(FX.count(data.scenes)==2 and FX.count(data.compositions)==1)
assert(data.annotations['light|point'].note=='blue light')
''')
print('PASS: scene hide/copy/move/8 versions/restore/restart, failed writes, permissions/buckets, groups, annotations and verified presets')

c=runtime()
c.execute('messages={};function SendNUIMessage(m) messages[#messages+1]=m end')
c.execute((ROOT/'client/preview.lua').read_text(encoding='utf-8'))
c.execute(r'''
local def={duration=60,phases={{at=0,effectId='light|point',params={lifetime=60}}}}
assert(FXPreview.control({command='start',definition=def,coords={x=0,y=0,z=0},speed=2}).ok)
advance(500)
assert(FX.count(FXRuntime.active)==1)
assert(messages[#messages].data.cursor>.8)
FXPreview.control({command='pause'});advance(100)
assert(FX.count(FXRuntime.active)==0)
local cursor=messages[#messages].data.cursor;advance(500)
assert(messages[#messages].data.cursor==cursor,'paused cursor advanced')
FXPreview.control({command='seek',cursor=20});advance(100)
assert(messages[#messages].data.cursor==20)
FXPreview.control({command='resume'});advance(100)
local effect=FXRuntime.active[next(FXRuntime.active)]
assert(effect.params.elapsed>=20 and effect.previewSpeed==2)
FXPreview.control({command='stop'});advance(100)
assert(FX.count(FXRuntime.active)==0)
def.duration=.2;def.phases[1].params.lifetime=.2
FXPreview.control({command='start',definition=def,loop=true});advance(650)
assert(messages[#messages].data.state=='playing','loop ended early')
advance(30000)
assert(FX.count(FXRuntime.active)==0 and messages[#messages].data.state=='stopped','preview deadline ignored')
''')
print('PASS: transport start, speed, pause, seek, resume, stop, loop and 30-second deadline')
