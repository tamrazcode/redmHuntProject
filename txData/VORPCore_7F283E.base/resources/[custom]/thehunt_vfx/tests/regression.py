"""Isolated Lua 5.4/CEF checks. Does not connect to or restart FXServer."""
from pathlib import Path
from collections import Counter
from lupa.lua54 import LuaRuntime
import json
ROOT = Path(__file__).resolve().parents[1]

HARNESS = r'''
clock=0; jobs={}; events={}; sent={}; api={}; caller='test_magic'; writeOK=true
players={ [1]=0,[2]=0,[3]=1 }; assetReady=true; starts=0; stops=0; saved=nil
function GetGameTimer() return clock end
function GetCurrentResourceName() return 'thehunt_vfx' end
function GetInvokingResource() return caller end
function GetConvar(_,d) return d end
function GetPlayerRoutingBucket(s) return players[s] end
function GetPlayerName(s) return players[s]~=nil and ('Player'..s) or nil end
function GetPlayers() local r={} for s in pairs(players) do r[#r+1]=tostring(s) end return r end
function RegisterNetEvent(n,f) events[n]=f end
function AddEventHandler(n,f) events[n]=f end
function TriggerClientEvent(n,s,...) sent[#sent+1]={name=n,target=s,args={...}} end
function TriggerEvent(n,...) if events[n] then events[n](...) end end
function dispatch(n,s,...) source=s; events[n](...); source=nil end
function CreateThread(f) jobs[#jobs+1]={co=coroutine.create(f),at=clock} end
function Wait(ms) coroutine.yield(math.max(1,ms)) end
function advance(ms)
 local finish=clock+ms
 while true do
  local best
  for _,j in ipairs(jobs) do if coroutine.status(j.co)~='dead' and j.at<=finish and (not best or j.at<best.at) then best=j end end
  if not best then break end
  clock=best.at
  local ok,delay=coroutine.resume(best.co); assert(ok,delay)
  best.at=clock+(delay or 1)
 end
 clock=finish
end
exports=setmetatable({thehunt_core={IsPlayerAdmin=function(_,s) return s==1 end}}, {__call=function(_,n,f) api[n]=f end})
function LoadResourceFile() return nil end
function SaveResourceFile(_,_,data) if writeOK then saved=data end return writeOK end
json={encode=function(t) return 'encoded' end,decode=function() return {} end}
function PlayerPedId() return 10 end
function DoesEntityExist(e) return e==10 end
function GetEntityCoords() return {x=1,y=2,z=3} end
function GetOffsetFromEntityInWorldCoords(_,x,y,z) return {x=1+x,y=2+y,z=3+z} end
function GetEntityBoneIndexByName(_,b) return b=='bad' and -1 or 1 end
function GetWorldPositionOfEntityBone() return {x=1,y=2,z=4} end
function GetPlayerFromServerId(s) return players[s] and s or -1 end
function GetPlayerPed() return 10 end
function GetHashKey(_) return 123 end
Citizen={InvokeNative=function(hash,arg)
 if hash==0xF2B2353BBC0D4E8F or hash==0x65BB72F29138F5D6 then assert(type(arg)=='number','RedM dictionary requires hash') end
 if hash==0x65BB72F29138F5D6 then return assetReady end
end}
function start() starts=starts+1; return starts end
StartParticleFxLoopedAtCoord=start; StartParticleFxLoopedOnEntity=start; StartParticleFxLoopedOnEntityBone=start
StartParticleFxNonLoopedAtCoord=start
function StopParticleFxLooped() stops=stops+1 end
function noop() end
SetParticleFxLoopedAlpha=noop; SetParticleFxLoopedColour=noop; SetParticleFxNonLoopedAlpha=noop
SetParticleFxLoopedAlpha=function(_,alpha) assert(math.type(alpha)=='float','Alpha must be float even at 1') end
StartParticleFxLoopedAtCoord=function(_,x,y,z,rx,ry,rz,scale)
 for _,value in ipairs({x,y,z,rx,ry,rz,scale}) do assert(math.type(value)=='float','Native parameter must be float') end
 return start()
end
SetParticleFxNonLoopedColour=noop; DrawLightWithRange=noop
function AnimpostfxIsRunning() return false end
AnimpostfxPlay=noop; AnimpostfxStop=noop; SetTimecycleModifier=noop
SetTimecycleModifierStrength=noop; ClearTimecycleModifier=noop
function countEvents(name,target)
 local n=0; for _,e in ipairs(sent) do if e.name==name and (not target or e.target==target) then n=n+1 end end return n
end
'''

def runtime(server=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(HARNESS)
    for file in ['config.lua','data/sources.lua','shared/core.lua','shared/tracks.lua','shared/composition.lua', 'server/main.lua' if server else 'client/runtime.lua']:
        lua.execute((ROOT/file).read_text(encoding='utf-8-sig'))
    return lua

def run():
    lua=LuaRuntime(unpack_returned_tuples=True)
    for p in ROOT.rglob('*.lua'):
        ok,err=lua.eval('function(s,n) local f,e=load(s,n); return f~=nil,e end')(p.read_text(encoding='utf-8-sig'),str(p))
        assert ok, (p,err)
    print('PASS: all Lua files parse (Lua 5.4)')
    c=runtime()
    entries=c.globals().FX.catalog
    counts=Counter(e['kind'] for _,e in entries.items())
    print('Catalog:',dict(counts))
    assert counts['loop']>1000 and counts['burst']>1000
    c.execute(r'''
        id='ptfx_looped|core|ent_amb_elec_crackle'
        assert(FX.byId[id])
        assert(FX.params(id,{coords={x=0/0,y=0,z=0}},true)==nil)
        assert(FX.params(id,{coords={x=0,y=0,z=0},attach=true},true)==nil)
        assetReady=false
        local a=api.PlayEffect(id,{lifetime=2})
        advance(30); api.StopEffect(a); assetReady=true; advance(30)
        assert(starts==0,'cancelled load spawned a particle')
        local b=api.PlayEffect(id,{lifetime=0.2})
        local d=api.PlayEffect(id,{lifetime=0.2})
        assert(b~=d); advance(100); assert(starts==2)
        caller='other_resource'; assert(not api.StopEffect(b)); caller='test_magic'
        advance(300); assert(FX.count(FXRuntime.active)==0 and stops==2)
        local g=api.PlaySequence({duration=1,phases={{at=0.5,effectId=id,params={}}}},{})
        advance(100); api.StopSequence(g); advance(700); assert(starts==2)
        local ownerId=api.PlayEffect(id,{lifetime=0}); advance(50)
        events.onResourceStop('test_magic'); assert(FXRuntime.active[ownerId]==nil)
    ''')
    print('PASS: finite payloads, hashed dictionary, concurrent IDs, expiry, load cancellation, sequence cancellation, owner cleanup')
    s=runtime(True)
    s.execute(r'''
        advance(1)
        id='ptfx_looped|core|ent_amb_elec_crackle'
        p={coords={x=1,y=2,z=3},lifetime=2}
        dispatch('thehunt_vfx:subscribe',1); dispatch('thehunt_vfx:subscribe',3)
        dispatch('thehunt_vfx:action',2,'spawn',{effectId=id,params=p})
        advance(250); assert(countEvents('thehunt_vfx:add')==0,'non-admin spawned effect')
        local key=api.PlayEffect(id,p,{bucket=0})
        assert(key); advance(250)
        assert(countEvents('thehunt_vfx:add',1)==1)
        assert(countEvents('thehunt_vfx:add',3)==0,'bucket leak')
        dispatch('thehunt_vfx:subscribe',2); advance(250)
        assert(countEvents('thehunt_vfx:add',2)==1,'late join missed effect')
        players[2]=1; advance(250)
        assert(countEvents('thehunt_vfx:remove',2)==1,'bucket change leaked effect')
        caller='other_resource'; assert(not api.StopEffect(key)); caller='test_magic'
        advance(1500); assert(not api.StopEffect(key),'server TTL did not expire')
        local scene=api.PlayEffect(id,{coords={x=1,y=2,z=3},lifetime=0},{bucket=0})
        writeOK=false
        dispatch('thehunt_vfx:action',1,'saveScene',{id=scene,name='ritual'})
        assert(FX.count(api.GetPersistentScenes())==0,'failed write changed persistent state')
        advance(200); writeOK=true
        dispatch('thehunt_vfx:action',1,'saveScene',{id=scene,name='ritual'})
        assert(FX.count(api.GetPersistentScenes())==1)
        advance(200); writeOK=false
        dispatch('thehunt_vfx:action',1,'stop',{id=scene})
        assert(FX.count(api.GetPersistentScenes())==1,'failed deletion lost scene')
        local n=countEvents('thehunt_vfx:add')
        local g=api.PlaySequence({duration=1,phases={{at=.5,effectId=id,params=p}}},{},{bucket=0})
        assert(g); api.StopSequence(g); advance(700)
        assert(countEvents('thehunt_vfx:add')==n)
        assert(not api.PlayEffect(id,{targetServerId=3,attach=true},{bucket=0}))
    ''')
    print('PASS: admin authorization, bucket isolation/change, late join, server TTL, transactional persistence, server sequence cancellation')
    (ROOT/'tests'/'catalog_counts.json').write_text(json.dumps(dict(counts),indent=2),encoding='utf-8')

if __name__=='__main__': run()
