from regression import runtime

lua=runtime(server=True)
lua.execute('''
advance(1)
local effect=FX.catalog[1].id
for _,e in ipairs(FX.catalog) do if e.kind=='loop' then effect=e.id; break end end
local def={duration=5,phases={{effectId=effect,at=1,params={lifetime=3,coords={x=1,y=2,z=3},entity=10}}}}
local clean=assert(FX.composition(def))
assert(clean.phases[1].params.coords==nil and clean.phases[1].params.entity==nil)
assert(not FX.composition({duration=1,phases={{effectId=effect,at=1}}}))
dispatch('thehunt_vfx:action',2,'composition',{name='blocked',definition=def})
assert(api.GetPreset('blocked')==nil)
dispatch('thehunt_vfx:action',1,'composition',{name='combo',definition=def})
assert(api.GetPreset('combo').definition.phases[1].effectId==effect)
local id=assert(api.PlayPreset('combo',{coords={x=1,y=2,z=3}},{bucket=0}))
dispatch('thehunt_vfx:subscribe',1)
assert(api.StopSequence(id))
local before=#sent
advance(6000)
for i=before+1,#sent do assert(sent[i].name~='thehunt_vfx:add','Cancelled delayed layer was sent') end
''')
print('PASS: portable composition validation, admin-only save, preset API owner cancellation')

client=runtime()
client.execute('''
local effect
for _,e in ipairs(FX.catalog) do if e.kind=='loop' then effect=e.id; break end end
local p=assert(FX.params(effect,{coords={x=0,y=0,z=0},lifetime=4,scale=1,
 animation={mode='orbit',radius=2,speed=90,fadeIn=1,fadeOut=1,endScale=3}},false))
local o,rot,alpha,scale=FX.frame(p,0)
assert(o.x==2 and alpha==0 and scale==1)
o,rot,alpha,scale=FX.frame(p,1)
assert(math.abs(o.x)<0.0001 and math.abs(o.y-2)<0.0001 and alpha==1 and scale==1.5)
o,rot,alpha,scale=FX.frame(p,3.5)
assert(alpha==0.5 and scale==2.75)
local resumed=FX.copy(p); resumed.elapsed=2; resumed.lifetime=2
local ro,rr,ra,rs=FX.frame(resumed,1.5)
assert(math.abs(ro.x-o.x)<0.0001 and ra==alpha and rs==scale)
local updated=0
SetParticleFxLoopedOffsets=function(_,x,y,z,rx,ry,rz)
 for _,v in ipairs({x,y,z,rx,ry,rz}) do assert(math.type(v)=='float') end
 updated=updated+1
end
SetParticleFxLoopedScale=function(_,v) assert(math.type(v)=='float') end
local id=assert(api.PlayEffect(effect,p))
advance(1200)
assert(updated>0)
assert(api.StopEffect(id))
local before=updated
advance(2000)
assert(updated==before)
''')
print('PASS: orbit, fade envelope, scale interpolation, native float types, animation cancellation')
client.execute('''
local keys=assert(FX.track({{at=0,offset={x=0,y=0,z=0},alpha=0,scale=1,easing='smooth'},
 {at=2,offset={x=4,y=0,z=0},alpha=1,scale=2}}))
local o,_,a,s=FX.sampleTrack(keys,1)
assert(o.x==2 and a==0.5 and s==1.5)
assert(not FX.track({{at=0},{at=0}}))
local burst
for _,e in ipairs(FX.catalog) do if e.kind=='burst' then burst=e.id;break end end
local travel=0
GetOffsetFromEntityInWorldCoords=function() return {x=travel+0.0,y=0.0,z=0.0} end
local id=assert(api.PlayEffect(burst,{entity=10,attach=true,lifetime=3,trail={distance=1,maxEmissions=3}}))
advance(10);local before=starts
advance(200);assert(starts==before)
travel=2;advance(200);assert(starts==before+1)
assert(api.StopEffect(id));travel=4;advance(200);assert(starts==before+1)
local drawn=0
GetResourceState=function() return 'started' end
exports.thehunt_shapes={DrawSphere=function() drawn=drawn+1 end}
local shape=assert(api.PlayEffect('shape|sphere',{coords={x=0,y=0,z=0},lifetime=1}))
advance(200);assert(drawn>0)
assert(api.StopEffect(shape));local old=drawn;advance(300);assert(drawn==old)
''')
print('PASS: smooth keyframes, duplicate rejection, distance-based trail, shape adapter cleanup')
