from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path('txData/VORPCore_7F283E.base/resources/[custom]')
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
api={};nui={};events={};messages={};owner='test_owner';focus=false;keep=false
exports=setmetatable({}, {__call=function(_,n,f)api[n]=f end})
function GetInvokingResource()return owner end
function IsNuiFocused()return focus end
function SetNuiFocus(v)focus=v end
function SetNuiFocusKeepInput(v)keep=v end
function SendNUIMessage(v)messages[#messages+1]=v end
function RegisterNUICallback(n,f)nui[n]=f end
function CreateThread(f)frameThread=f end
function AddEventHandler(n,f)events[n]=f end
function GetCurrentResourceName()return 'thehunt_gizmo' end
function cb(v)response=v end
applied={}; finishes={}
options={value={x=.02,y=0,z=0,rx=0,ry=0,rz=0},limits={x={-.1,.1}},
 point=function()end,apply=function(v)applied[#applied+1]=v end,
 finish=function(saved,v,reason)finishes[#finishes+1]={saved,v,reason}end}
''')
lua.execute((root/'thehunt_gizmo/client.lua').read_text(encoding='utf-8'))
lua.execute('''
assert(api.Start(options) and focus and keep and api.IsActive())
assert(not api.Start(options))
local id=messages[#messages].id
nui.change({id=id,value={x=4}},cb);assert(response.ok and response.value.x==.1)
local count=#applied;nui.change({id=id-1,value={x=-.05}},cb);assert(not response.ok and #applied==count)
owner='unrelated';api.Cancel();assert(api.IsActive())
owner='test_owner';api.Cancel();assert(not focus and not keep and not api.IsActive())
assert(applied[#applied].x==.02 and finishes[#finishes][1]==false)
assert(api.Start(options));events.onResourceStop('test_owner');assert(not focus and not api.IsActive())
assert(api.Start(options));id=messages[#messages].id;nui.finish({id=id,save=true},cb)
assert(finishes[#finishes][1] and not focus)
-- Exercise projection in both modes, including the vector math used by Cfx.
local mt={}
function vector3(x,y,z)return setmetatable({x=x,y=y,z=z},mt)end
mt.__add=function(a,b)return vector3(a.x+b.x,a.y+b.y,a.z+b.z)end
mt.__sub=function(a,b)return vector3(a.x-b.x,a.y-b.y,a.z-b.z)end
mt.__div=function(a,b)return vector3(a.x/b,a.y/b,a.z/b)end
mt.__mul=function(a,b)return vector3(a.x*b,a.y*b,a.z*b)end
function GetScreenCoordFromWorldCoord(x,y,z)return true,x+.5,y+z+.5 end
function DisableAllControlActions()end
function EnableControlAction()end
function DisablePlayerFiring()end
function PlayerId()return 0 end
local now=1000
function GetGameTimer()return now end
function Wait()coroutine.yield()end
local calls=0
options.point=function(v)calls=calls+1;return vector3(v.x,v.y,v.z)end
assert(api.Start(options));id=messages[#messages].id
local co=coroutine.create(frameThread);assert(coroutine.resume(co))
assert(calls==4 and messages[#messages].type=='frame' and next(messages[#messages].rings)==nil)
nui.mode({id=id,mode='rotate'},cb);now=now+100
assert(coroutine.resume(co))
assert(calls==8 and #messages[#messages].rings.x==49 and #messages[#messages].rings.y==49)
api.Cancel()
''')
print('PASS engine: exclusive focus, finite clamp, stale message rejection, owner-only cancellation, rollback, stop cleanup, save')
