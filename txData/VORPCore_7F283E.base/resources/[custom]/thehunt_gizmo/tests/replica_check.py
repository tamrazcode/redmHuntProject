from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path('txData/VORPCore_7F283E.base/resources/[custom]')
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
threads={}; handlers={}; commands={}; api={}; bags={}; entities={[10]=true,[20]=true}; attached={}; deleted={}; created=100; now=1000
exports=setmetatable({}, {__call=function(_,n,f) api[n]=f end})
local vecmt={__add=function(a,b)return vector3(a.x+b.x,a.y+b.y,a.z+b.z)end,__sub=function(a,b)return vector3(a.x-b.x,a.y-b.y,a.z-b.z)end,__len=function(a)return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z)end}
function vector3(x,y,z)return setmetatable({x=x,y=y,z=z},vecmt)end
local state={attachedBackpack='kh_backpack1',attachedBackpackFit={itemId=42,model='kh_backpack1',offset={x=0,y=0,z=0,rx=0,ry=0,rz=0}}}
local other={attachedBackpack='kh_backpack1',attachedBackpackFit={itemId=99,model='kh_backpack1',offset={x=.08,y=0,z=0,rx=0,ry=0,rz=0}}}
LocalPlayer={state=state}
GlobalState={huntBackpackProfiles={}}
json={encode=function(v) local s='';for _,k in ipairs({'x','y','z','rx','ry','rz'}) do s=s..tostring(v[k])..':' end;return s end}
function Player(p)assert(p==70 or p==80,'state bags require server IDs');return {state=p==70 and state or other}end
function PlayerId()return 7 end
function PlayerPedId()return 10 end
function GetPlayerServerId(p)return p*10 end
function GetPlayerFromServerId(p)return p/10 end
function GetPlayerPed(p)return p==7 and 10 or 20 end
function GetActivePlayers()return {7,8}end
function GetHashKey(s)return s end
function GetPedBoneIndex(p,b)return b end
function GetEntityBoneIndexByName(p,n)return 84 end
function IsPedMale()return true end
function DoesEntityExist(e)return entities[e]==true end
function IsEntityDead()return false end
function GetModelDimensions()return vector3(-.1,-.2,-.4),vector3(.3,.6,.8)end
function AttachEntityToEntity(e,p,b,x,y,z,rx,ry,rz,...)attached[e]={p=p,b=b,x=x,y=y,z=z,rx=rx,ry=ry,rz=rz}end
function DetachEntity()end
function SetEntityAsMissionEntity()end
function DeleteEntity(e)entities[e]=nil;deleted[#deleted+1]=e end
function CreateThread(f)threads[#threads+1]=f end
function RequestModel()end
function GetGameTimer()return now end
function HasModelLoaded()return true end
function SetModelAsNoLongerNeeded()end
function GetEntityCoords()return vector3(0,0,0)end
function CreateObject()created=created+1;entities[created]=true;return created end
function SetEntityCollision()end
function SetEntityCompletelyDisableCollision()end
function SetEntityVisible()end
function SetEntityAlpha()end
function ResetEntityAlpha()end
function FreezeEntityPosition()end
function SetEntityLodDist()end
function IsEntityVisible()return true end
function GetEntityAlpha()return 255 end
function GetEntityAttachedTo(e)return attached[e] and attached[e].p or 0 end
function GetWorldPositionOfEntityBone()return vector3(0,0,0)end
function RegisterNetEvent(n,f)handlers[n]=f end
function AddEventHandler(n,f)handlers[n]=f end
function AddStateBagChangeHandler(n,_,f)bags[n]=f end
function SetTimeout(t,f)if t==0 then f()end end
function RegisterCommand(n,f)commands[n]=f end
function TriggerEvent()end
function TriggerServerEvent(n,...)lastServer={n,...}end
function Wait(ms)now=now+ms end
function GetGamePool()return {}end
function IsPedRagdoll()return false end
function IsPedOnMount()return false end
function IsPedInAnyVehicle()return false end
function IsPedSwimming()return false end
function IsPedClimbing()return false end
''')
lua.execute((root/'thehunt_items/shared/backpack.lua').read_text(encoding='utf-8'))
lua.execute((root/'thehunt_inventory/client/backpack.lua').read_text(encoding='utf-8'))
lua.execute('''
assert(BackpackFit.BoneId==14412)
api.AttachLocalBackpack('kh_backpack1');threads[#threads]()
assert(created==101 and attached[101].b==84 and attached[101].rx==-90 and attached[101].ry==0)
-- Same model/fit should reuse the entity, not duplicate it.
api.AttachLocalBackpack('kh_backpack1');assert(created==101)
local initialX=attached[101].x
LocalPlayer.state.attachedBackpackFit.offset.x=.10
bags.attachedBackpackFit('player:70');assert(created==101 and math.abs(attached[101].x-initialX-.10)<1e-8)
-- Other players use their own fit rather than the local player's offsets.
bags.attachedBackpackFit('player:80');threads[#threads]()
assert(created==102 and math.abs(attached[102].x-initialX-.08)<1e-8)
-- Model defaults apply to both replicas while preserving independent personal fit.
GlobalState.huntBackpackProfiles.kh_backpack1={x=2,y=3,z=4,rx=360,ry=0,rz=0}
api.AttachLocalBackpack('kh_backpack1');bags.attachedBackpackFit('player:80')
assert(math.abs(attached[101].x-initialX-2.10)<1e-8)
assert(math.abs(attached[102].x-initialX-2.08)<1e-8 and attached[102].rx==270)
-- Admin preview replaces the model profile, and cancellation restores it.
Player(80).state.attachedBackpackFit.calibration={x=10,y=0,z=0,rx=0,ry=0,rz=0}
bags.attachedBackpackFit('player:80');assert(attached[102].x==10)
Player(80).state.attachedBackpackFit.calibration=nil
bags.attachedBackpackFit('player:80');assert(math.abs(attached[102].x-initialX-2.08)<1e-8)
-- Stream-out invalidates and cleans its replica.
Player(80).state.attachedBackpack=false;bags.attachedBackpack('player:80');assert(not entities[102])
-- A model request superseded before completion cannot spawn a ghost.
api.AttachLocalBackpack('kh_backpack2');local pending=threads[#threads];api.DetachLocalBackpack();pending();assert(created==102)
-- Bogus models are rejected before load/spawn.
api.AttachLocalBackpack('not_a_backpack');assert(created==102)
-- Explicit transport must work even when the remote state bag is empty.
Player(80).state.attachedBackpack=nil
handlers['thehunt_inventory:backpackState'](80, {attachedBackpack='kh_backpack1',attachedBackpackFit={model='kh_backpack1',offset={x=.03}}})
bags.attachedBackpack('player:80');threads[#threads]()
assert(created==103 and math.abs(attached[103].x-2.03)<1e-8)
handlers['thehunt_inventory:backpackState'](80, {attachedBackpack=false})
bags.attachedBackpack('player:80');assert(not entities[103])
''')
print('PASS replicas: real RDR bone, transform-only updates, independent remote fit, stream cleanup, stale load cancellation, model allowlist')
