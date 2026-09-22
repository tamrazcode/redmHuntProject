# Offline Lua logic checks. Requires Python packages lupa and luaparser.
# Native stubs cannot validate in-game animation/IK rendering or replication.
from pathlib import Path
import re, math
from lupa import LuaRuntime
from luaparser import ast
base=Path(__file__).resolve().parents[1]
for name in ['client/main.lua','server/main.lua','config.lua']:
    ast.parse(re.sub(r'`[^`]+`','0',(base/name).read_text(encoding='utf-8-sig')))
print('PASS: Lua syntax client/server/config')
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
boneScale=1; boneX=100; boneY=200; boneZ=50; missingBones=false
now=1000; heading=0; dt=1/60; loaded=true; plays=0; stops=0; events={}; handlers={}; nextEntity=100
function vector3(x,y,z) return {x=x,y=y,z=z} end
Citizen={InvokeNative=function(...) nativeArgs={...} end, Wait=function(ms) now=now+ms; if onWait then onWait() end; loaded=true end}
function RegisterNetEvent(name,fn) handlers[name]=fn end
function TriggerServerEvent(...) events[#events+1]={...} end
function GetGameTimer() return now end
function PlayerPedId() return 1 end
function PlayerId() return 0 end
function GetPlayerServerId() return 1 end
function DoesEntityExist(e) return e and e~=0 end
function IsPedHuman() return true end
function IsEntityDead() return false end
IsPedDeadOrDying=IsEntityDead; IsPedRagdoll=IsEntityDead; IsPedSwimming=IsEntityDead; IsPedClimbing=IsEntityDead; IsPedUsingAnyScenario=IsEntityDead; IsPedOnMount=IsEntityDead; IsNuiFocused=IsEntityDead
function GetHashKey() return 1 end
function HasModelLoaded() return true end
function GetEntityCoords() return vector3(0,0,0) end
function CreateObject() nextEntity=nextEntity+1; return nextEntity end
function noop() end
SetEntityAsMissionEntity=noop; DeleteEntity=noop; SetEntityAlpha=noop; SetEntityVisible=noop; SetEntityCollision=noop; FreezeEntityPosition=noop; SetModelAsNoLongerNeeded=noop; RequestModel=noop; RequestAnimDict=noop; SetPedCanArmIk=noop; ClearPedSecondaryTask=noop
function GetGameplayCamRot() return vector3(0,0,heading) end
function GetFrameTime() return dt end
function GetEntityHeading() return heading end
function GetOffsetFromEntityInWorldCoords(_,x,y,z) return vector3(boneX+x,boneY+y,boneZ+z) end
function GetEntityBoneIndexByName(_,name)
    if missingBones then return -1 end
    return ({SKEL_R_UpperArm=10, SKEL_R_Forearm=11, SKEL_R_Hand=12})[name] or -1
end
function GetWorldPositionOfEntityBone(_,bone)
    -- Ped origin is deliberately above ground. Shoulder height differs by
    -- model; using origin+1.4 instead of this bone must fail the assertions.
    local z=({[10]=0.45,[11]=0.15,[12]=-0.15})[bone]*boneScale
    return vector3(boneX+0.22*boneScale,boneY,boneZ+z)
end
function SetEntityCoordsNoOffset(_,x,y,z) target=vector3(x,y,z) end
function HasAnimDictLoaded() return loaded end
function TaskPlayAnim() plays=plays+1 end
function StopAnimTask() stops=stops+1 end
''')
lua.execute((base/'config.lua').read_text(encoding='utf-8-sig'))
s=(base/'client/main.lua').read_text(encoding='utf-8-sig')
end=s.index('Citizen.CreateThread(function()',s.index("RegisterNetEvent('thehunt_animations:client:pointing:stop'"))
api=lua.execute(s[:end]+'''
return {apply=ApplyPointingIK, start=function() isHoldingPoint=true; pointingRequest=pointingRequest+1; return StartPointingAnimation() end,
stop=StopPointingAnimation, active=function() return isPointingActive end, normalize=NormalizePointingDirection}
''')
g=lua.globals(); cfg=g.Config.PointingAnimation.ik
for h in [0,45,179,270,359]:
  for y in [-179,-90,0,90,179]:
    for pitch in [-89,-65,0,65,89]:
      g.heading=h; state=lua.table()
      direction=lua.table_from(dict(x=-math.sin(math.radians(y))*math.cos(math.radians(pitch)),y=math.cos(math.radians(y))*math.cos(math.radians(pitch)),z=math.sin(math.radians(pitch))))
      for i in range(90): assert api.apply(1,cfg,direction,state)
      t=g.target; x,yv,z=t.x-(g.boneX+.22),t.y-g.boneY,t.z-(g.boneZ+.45)
      assert .6*.92*.92-1e-8 <= math.sqrt(x*x+yv*yv+z*z) <= .6*.92+1e-8
      actual=math.degrees(math.atan2(-x,yv)); rel=(actual-h+180)%360-180
      assert abs(rel)<=70.0001
      assert abs(math.degrees(math.asin(max(-1,min(1,z/(.6*.92))))))<=65.0001
print('PASS: 125 angle combinations, shoulder reach, rear target limits, up/down limits')
# Same trajectory for owner and remote given identical input and ped heading.
g.heading=0; a=lua.table(); b=lua.table(); direction=lua.table_from(dict(x=.5,y=.5,z=-math.sqrt(.5)))
for i in range(30):
 api.apply(1,cfg,direction,a); first=(g.target.x,g.target.y,g.target.z)
 api.apply(1,cfg,direction,b); assert first==(g.target.x,g.target.y,g.target.z)
print('PASS: same local/remote solver trajectory')
assert api.start(); assert api.active(); api.stop(); assert not api.active()
# Release while animation dictionary yields must never call TaskPlayAnim.
g.loaded=False; before=g.plays; g.onWait=api.stop
assert not api.start(); assert not api.active(); assert g.plays==before
g.onWait=None
for bad in [dict(x=float('nan'),y=1,z=0),dict(x=float('inf'),y=1,z=0),dict(x=0,y=0,z=0)]:
 assert api.normalize(lua.table_from(bad)) is None
print('PASS: press/release, release during dictionary loading, invalid direction rejection')
# Horizontal camera aim must produce a horizontal arm at the actual shoulder,
# independent of world elevation, ped origin, body size, or mounted height.
g.heading=0
for scale in [.75,1,1.25]:
 for height in [-10,0,150,150.9]:
  g.boneScale=scale; g.boneZ=height
  state=lua.table(); direction=lua.table_from(dict(x=0,y=1,z=0))
  for _ in range(90): assert api.apply(1,cfg,direction,state)
  assert abs(g.target.z-(height+.45*scale))<1e-8
  assert abs(g.target.y-g.boneY-.6*scale*.92)<1e-8
# Missing bone data falls back without sending an invalid IK target.
g.missingBones=True; old=g.nativeArgs
assert api.apply(1,cfg,direction,lua.table()) is False
print('PASS: real shoulder height at 4 elevations and 3 body sizes; missing-bone fallback')

# Abrupt camera reversals and simultaneous elevation/side aim must stay inside
# the shoulder envelope, with bounded angular motion at different frame rates.
g.missingBones=False; g.boneScale=1; g.boneZ=50
for fps in [20,30,60,144]:
 g.dt=1/fps; g.heading=0; state=lua.table()
 for yaw,pitch in [(0,85),(150,85),(-150,-85),(179,0),(-179,0),(0,0)]:
  d=lua.table_from(dict(x=-math.sin(math.radians(yaw))*math.cos(math.radians(pitch)),y=math.cos(math.radians(yaw))*math.cos(math.radians(pitch)),z=math.sin(math.radians(pitch))))
  for frame in range(fps):
   y0,p0=state.shoulderYaw or 0,state.pitch or 0
   assert api.apply(1,cfg,d,state)
   y1,p1=state.shoulderYaw,state.pitch
   extent=(y1/(35 if y1>=0 else 60))**2+(p1/(55 if p1>=0 else 50))**2
   assert extent <= 1.000001
   assert math.hypot(y1-y0,p1-p0) <= 150/fps+1e-7
print('PASS: abrupt up/side/down/rear transitions at 20/30/60/144 FPS; combined shoulder envelope and angular speed')

# Entry starts at the actual wrist, and reaches pointing without a first-frame
# target jump. Native release retains its helper until blend-out finishes.
g.dt=1/60; g.heading=0; g.boneScale=1; g.boneZ=50; g.missingBones=False
state=lua.table(); direction=lua.table_from(dict(x=0,y=1,z=0))
assert api.apply(1,cfg,direction,state)
assert abs(g.target.x-(g.boneX+.22))<1e-8
assert abs(g.target.y-g.boneY)<1e-8
assert abs(g.target.z-(g.boneZ-.15))<1e-8
previous=g.target.y
for _ in range(40):
 assert api.apply(1,cfg,direction,state)
 assert g.target.y>=previous-1e-8
 previous=g.target.y
assert abs(g.target.z-(g.boneZ+.45))<1e-8
assert g.nativeArgs[11]==450
lua.execute('deletedTargets=0; function DeleteEntity() deletedTargets=deletedTargets+1 end')
assert api.start()
assert api.apply(1,cfg,direction)
before=g.deletedTargets
api.stop()
assert g.deletedTargets==before
assert not api.active()
print('PASS: entry begins at wrist; monotonic 450ms lift; target survives release for native blend-out')
