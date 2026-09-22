"""Offline execution of production Lua: authority, replication races and AI LOS.
Run with Python + lupa. This does not start FXServer or connect to the database.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.environ.get('TEMP', ''), 'hunt-pedcustom-validation'))
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=load(s,n); return f~=nil,e end')
paths = list(ROOT.rglob('*.lua')) + [ROOT.parent/'thehunt_core/client'/name for name in
    ['world_cleaner.lua', 'overhead_ids.lua', 'admin_menu.lua']]
for path in paths:
    ok, error = compile_lua(re.sub(r'`[^`]+`', '123', path.read_text(encoding='utf-8-sig')), str(path))
    assert ok, error
print(f'PASS: Lua compilation ({len(paths)} files)')

def shared(vm):
    for file in ['shared/models.lua', 'config.lua', 'shared/definitions.lua']:
        vm.execute((ROOT/file).read_text(encoding='utf-8'))

shared(lua)
lua.execute('''
clock=100000; handlers={}; hooks={}; threads={}; events={}; entities={}; playerStates={}; exported={}; writes=0
players={1,2}; playerPositions={[1]={x=100,y=0,z=0},[2]={x=105,y=0,z=0}}
owners={}; buckets={}; allowed=true; deleted={}; dbId=10; deaths=0
function GetGameTimer() return clock end
function GetCurrentResourceName() return 'thehunt_zombie' end
function GetHashKey(s) local h=0;for i=1,#s do h=(h*31+s:byte(i))%2147483647 end;return h end
function GetPlayers() return players end
function GetPlayerPed(id) return playerPositions[id] and id or 0 end
function GetPlayerName(id) return playerPositions[id] and 'player' or nil end
function GetPlayerRoutingBucket(id) return buckets[id] or 0 end
function SetEntityRoutingBucket(e,b) entities[e].bucket=b end
function SetEntityOrphanMode() end
function GetAllPeds() local out={};for e in pairs(entities)do out[#out+1]=e end;return out end
local function state() return {set=function(self,k,v)self[k]=v end} end
function Player(id) playerStates[id]=playerStates[id] or {state=state()};return playerStates[id] end
function Entity(e) return entities[e] end
function DoesEntityExist(e) return entities[e]~=nil or playerPositions[e]~=nil end
function GetEntityType()return 1 end
-- Match actual RedM server behavior, not FiveM's implemented health sync node.
function GetEntityHealth(e)return 0 end
function GetEntityCoords(e)return entities[e] and entities[e].pos or playerPositions[e] end
function GetEntityModel(e)return entities[e].model end
function NetworkGetEntityOwner(e)return owners[e] end
function NetworkGetEntityFromNetworkId(net)return entities[net] and net or 0 end
function DeleteEntity(e) deleted[e]=true;entities[e]=nil end
function RegisterNetEvent(n,f)handlers[n]=f end
function AddEventHandler(n,f)hooks[n]=hooks[n] or {};table.insert(hooks[n],f) end
function CreateThread(f) threads[#threads+1]=f end
function Wait(ms)clock=clock+ms end
function TriggerClientEvent(name,target,...)events[#events+1]={name=name,target=target,args={...}} end
function TriggerEvent(n,...)if n=='thehunt_zombie:died' then deaths=deaths+1 end end
exports=setmetatable({thehunt_core={IsPlayerAdmin=function()return allowed end}}, {__call=function(_,n,f)exported[n]=f end})
json={encode=function()return '{}' end,decode=function()return {} end}
MySQL={ready=function(f)f()end,query={await=function()return {} end},update={await=function()writes=writes+1;return 1 end},
 insert={await=function()writes=writes+1;dbId=dbId+1;return dbId end}}
function zone(id,overrides)
 local z=Zombie.copy(Zombie.defaults);z.name='test';z.count=2;z.minCount=1;z.maxCount=2;z.migration=false
 for k,v in pairs(overrides or {})do z[k]=v end
 z=Zombie.validate(z);z.revision=1;ZS.zones[id]=z;ZS.runtime[id]={nextSpawn=0};return z
end
function createFor(ticket,net,owner)
 entities[net]={state=state(),hp=350,pos=Zombie.copy(ticket.pos),model=GetHashKey(ticket.model)};owners[net]=owner
 entities[net].state.huntZombie={id=ticket.id,pending=true}
end
function ack(ticket,net,owner)
 source=owner;handlers['thehunt_zombie:spawnResult'](ticket.id,net);threads[#threads]()
end
function tickets()local list={};for _,t in pairs(ZS.tickets)do list[#list+1]=t end;return list end
function eventCount(name)local n=0;for _,e in ipairs(events)do if e.name==name then n=n+1 end end;return n end
''')
for file in ['server/spawn.lua', 'server/migration.lua', 'server/main.lua']:
    lua.execute((ROOT/file).read_text(encoding='utf-8'))

lua.execute('''
local z=zone(1)
local test=Zombie.copy(z);test.enabled=false;test.headshotOnly=false;test.randomCount=false
assert(Zombie.validate(test).enabled==false and Zombie.validate(test).randomCount==false)
assert(z.walkStyle=='MP_Style_drunk' and z.weaponDamage==25, 'default walkStyle/weaponDamage mismatch')
test.walkStyle='invalid_style'
assert(Zombie.validate(test).walkStyle=='MP_Style_drunk', 'invalid walkStyle fallback failed')
test.walkStyle='MP_Style_Crazy'
test.weaponDamage=45
local validated = Zombie.validate(test)
assert(validated.walkStyle=='MP_Style_Crazy' and validated.weaponDamage==45, 'custom walkStyle/weaponDamage failed')
for _,bad in ipairs({0/0,math.huge,-1,99999})do test.health=bad;assert(not pcall(Zombie.validate,test))end
test=Zombie.copy(z);test.models={'not_a_model'};assert(not pcall(Zombie.validate,test))
test=Zombie.copy(z);test.spawnRadius=199;assert(not pcall(Zombie.validate,test))
-- Several players and repeated activation share a single bounded population.
for _=1,10 do ZS.tick()end
assert(ZS.count(1)==2 and #tickets()==2,'duplicate population per player/tick')
local ts=tickets();createFor(ts[1],101,1);createFor(ts[2],102,1)
ack(ts[1],101,1);ack(ts[2],102,1)
local id=ts[1].id;assert(ZS.peds[id] and #tickets()==0)
-- The server returns 0 for LIVING RedM peds. Neither the corpse timer nor the
-- configured respawn interval may mark them dead or reduce population.
for _=1,4 do clock=clock+z.respawn*1000;ZS.tick() end
assert(ZS.count()==2 and not ZS.peds[id].dead and deaths==0,'server zero HP killed live population')
assert(ZS.runtime[1].nextSpawn==0,'live population started death cooldown')
local noises=eventCount('thehunt_zombie:noise')
source=1;handlers['thehunt_zombie:noise']('shot')
assert(eventCount('thehunt_zombie:noise')>noises,'server zero HP suppressed hearing')
source=1;handlers['thehunt_zombie:spawnResult'](id,101)
assert(ZS.count()==2,'duplicate commit')
-- Wrong owner cannot commit, remove or make this zombie attack.
source=2;handlers['thehunt_zombie:attack'](id,1);assert(eventCount('thehunt_zombie:hit')==0)
entities[101].pos={x=100,y=0,z=0};clock=clock+3000
source=1;handlers['thehunt_zombie:attack'](id,1);handlers['thehunt_zombie:attack'](id,1)
assert(eventCount('thehunt_zombie:hit')==1,'attack replay/cooldown')
-- Network ownership transfer keeps the same entity, HP, identity and server cooldown.
entities[101].hp=227;owners[101]=2
source=1;handlers['thehunt_zombie:attack'](id,1)
source=2;handlers['thehunt_zombie:attack'](id,1)
assert(eventCount('thehunt_zombie:hit')==1 and entities[101].hp==227)
clock=clock+3000;source=1;handlers['thehunt_zombie:attack'](id,1)
assert(eventCount('thehunt_zombie:hit')==2)
exported.SetPlayerAggression(1,false);clock=clock+3000;handlers['thehunt_zombie:attack'](id,1)
assert(eventCount('thehunt_zombie:hit')==2 and Player(1).state.huntZombieImmune)
exported.SetPlayerAggression(1,true)
-- Only the current owner reports client IsEntityDead; server health is unusable.
source=1;handlers['thehunt_zombie:pedDied'](id)
assert(not ZS.peds[id].dead,'non-owner reported death')
entities[101].hp=0;source=2
handlers['thehunt_zombie:pedDied'](id);handlers['thehunt_zombie:pedDied'](id)
ZS.tick();ZS.tick();assert(deaths==1 and ZS.peds[id].dead and #tickets()==0)
playerPositions[1]=nil;playerPositions[2]=nil;players={};clock=clock+ZombieConfig.DespawnGrace+1;ZS.tick();assert(ZS.count()==0)
playerPositions[2]={x=100,y=0,z=0};players={2};ZS.tick();assert(#tickets()==0,'exit/reentry bypassed respawn')
-- Timed-out / cancelled reservations cannot be registered later.
ZS.runtime[1].nextSpawn=0;ZS.tick();local t=tickets()[1];assert(t)
clock=clock+ZombieConfig.SpawnTimeout+1;ZS.tick()
createFor(t,103,2);source=2;handlers['thehunt_zombie:spawnResult'](t.id,103)
assert(not ZS.peds[t.id] and ZS.retired[t.id],'late commit accepted')
ZS.clear(nil,'test');assert(ZS.count()==0)
-- Every editor operation, including list/teleport/debug, is server gated.
allowed=false;source=2;local before=writes
for _,action in ipairs({'list','save','delete','clear','spawn','teleport','pause','info','debug','immunity'}) do
 handlers['thehunt_zombie:request'](1,action,{id=1,zone=z})
 local e=events[#events];assert(e.name=='thehunt_zombie:reply' and e.args[2]==false)
end
assert(writes==before)
allowed=true;clock=clock+2000;source=2
handlers['thehunt_zombie:request'](2,'save',{id=1,revision=0,zone=z})
assert(writes==before,'stale revision wrote DB')
handlers['thehunt_zombie:request'](3,'save',{id=1,revision=1,zone=z})
assert(writes==before+1 and ZS.zones[1].revision==2)
handlers['thehunt_zombie:request'](4,'list',{})
assert(events[#events].args[2]==true,'save followed by refresh was throttled')
-- Bucket isolation excludes players in a different instance from activation.
ZS.clear(nil,'test');ZS.zones={};ZS.runtime={};zone(2,{bucket=7});ZS.tick();assert(#tickets()==0)
-- Pending reservation, as well as living entities, consumes the global limit.
ZS.zones[2].bucket=0;ZS.runtime[2].nextSpawn=0;ZombieConfig.MaxAlive=1
for _=1,8 do ZS.tick()end;assert(#tickets()==1)
ZombieConfig.MaxAlive=120;ZS.clear(nil,'test')
-- Disconnect cancels only outstanding reservations; migrated living peds survive.
local zid=ZS.spawn(2,2,ZS.players());local t2=ZS.tickets[zid];createFor(t2,105,2);ack(t2,105,2)
local pendingId=ZS.spawn(2,2,ZS.players());source=2
for _,f in ipairs(hooks.playerDropped)do f()end
assert(ZS.peds[zid] and not ZS.tickets[pendingId],'disconnect duplicated/deleted committed entity')
-- Delete zone removes its peds AND its pending work before reactivation.
clock=clock+2000;source=2
handlers['thehunt_zombie:request'](5,'delete',{id=2,revision=1})
assert(not ZS.zones[2] and not ZS.peds[zid] and deleted[105])
''')
print('PASS: production server lifecycle: multi-player cap, commit replay, ownership transfer, HP retention,')
print('      attack replay, immunity, death once, reentry cooldown, late commit, permissions, revisions, buckets, disconnect, delete')
print('PASS: RedM server HP=0 keeps live population/AI alive and hearing/damage enabled; only owner death starts respawn')

client = LuaRuntime(unpack_returned_tuples=True)
shared(client)
client.execute('''
ZC={peds={},immune={},players={}};threads={};events={};los=true;position={x=0,y=0,z=0};calls=0
function RegisterNetEvent()end
function CreateThread(f)threads[#threads+1]=f end
function GetEntityCoords()return position end
function GetEntityForwardVector()return {x=1,y=0,z=0}end
function HasEntityClearLosToEntity()return los end
function DoesEntityExist()return true end
function NetworkHasControlOfEntity()return true end
function IsEntityDead()return false end
function ClearPedTasks()calls=calls+1 end
function TaskStandStill()end
function SetPedMaxMoveBlendRatio(_,speed)lastSpeed=speed end
function SetPedDesiredMoveBlendRatio()end
function GetHashKey()return 1 end
function GetScriptTaskStatus()return 1 end
function TaskCombatPed()combatCalls=(combatCalls or 0)+1 end
function TaskFollowNavMeshToCoord(...)lastMove={...}end
function ZC.entity(r)return r.ped end
function ZC.configure()end
function Entity()return {state={}}end
function FreezeEntityPosition()end
function HasAnimDictLoaded()return false end
function RequestAnimDict()end
''')
for file in ['client/detection.lua','client/ai.lua']:
    client.execute((ROOT/file).read_text(encoding='utf-8'))
client.execute('''
local z=Zombie.copy(Zombie.defaults)
local r={id='test',ped=10,settings=Zombie.settings(z),variance=1,owned=true,state='IDLE',since=0,
 home={x=0,y=0,z=0},radius=40,idleTime=9000}
ZC.peds.test=r;local p={id=1,ped=1,pos={x=10,y=0,z=0},speed=1,dead=false,crouch=false};ZC.players={p}
assert(ZC.visible(r,p));los=false;assert(not ZC.visible(r,p));los=true
p.pos.x=-10;assert(not ZC.visible(r,p));p.pos.x=30;p.crouch=true;assert(not ZC.visible(r,p))
p.pos.x=10;p.crouch=false;ZC.think(r,1000);assert(r.state=='ALERT')
ZC.think(r,2200);assert(r.state=='CHASE' and r.target==1)
ZC.think(r,2250)
local combatBefore=combatCalls
for now=2300,2450,50 do ZC.think(r,now) end
assert(combatCalls==combatBefore,'combat task restarted on perception tick')
assert(lastSpeed==z.speed,'configured speed ignored')
los=false;p.pos.x=70;ZC.think(r,2500)
assert(r.state=='SEARCH' and r.target==nil and r.last.x==10,'wall tracking')
ZC.immune[1]=true;los=true;p.pos.x=10;assert(not ZC.visible(r,p))
r.goal={x=150,y=0,z=0};ZC.think(r,20000);assert(r.state=='MIGRATION','migration did not resume after search')
''')
print('PASS: production perception/FSM: LOS, field of view, crouch, reaction, lost target, immunity, migration resume')

# Exercise the restored client producer, not just the server attack endpoint.
assert "'client/contact.lua'" in (ROOT/'fxmanifest.lua').read_text(encoding='utf-8')
client.execute('''
ZC.contacts={};LocalPlayer={state={}};ZC.immune={};los=true
function PlayerPedId()return 1 end
function PlayerId()return 0 end
function GetPlayerServerId()return 1 end
function GetEntityCoords(e)return e==1 and {x=1,y=0,z=0} or {x=0,y=0,z=0} end
function TriggerServerEvent(...)events[#events+1]={...}end
''')
client.execute((ROOT/'client/contact.lua').read_text(encoding='utf-8'))
client.execute('''
local r=ZC.peds.test;r.settings.attackRange=1.8;r.contactAt=nil
ZC.contact(1,10,30000)
assert(#events==1 and events[1][1]=='thehunt_zombie:attack' and ZC.contacts.test==30000)
ZC.contact(1,10,30001);assert(#events==1,'repeated impact bypassed cooldown')
ZC.contact(2,10,35000);assert(#events==1,'reported a different victim')
los=false;ZC.contact(1,10,35000);assert(#events==1,'impact through wall')
los=true;ZC.immune[1]=true;ZC.contact(1,10,35000);assert(#events==1,'immune victim')
ZC.immune={};r.settings.attackRange=0.8;ZC.contact(1,10,35000);assert(#events==1,'impact outside configured range')
r.settings.attackRange=1.8;ZC.contact(1,10,35000);assert(#events==2)
''')
print('PASS: restored contact file is loaded; native contact produces damage request with range/LOS/cooldown/immunity gates')

# Independent client registries receive the same server identity. Reused net IDs
# must never bind an old record to a different ped or delete the new entity.
for index in (1, 2):
    vm = LuaRuntime(unpack_returned_tuples=True)
    shared(vm)
    vm.execute('''
    source=65535;handlers={};threads={};deletions=0;unfreezes=0;clock=1000
    entities={[100]={state={huntZombie={id='epoch:1'}},hp=227}}
    function RegisterNetEvent(n,f)handlers[n]=f end
    function CreateThread(f)threads[#threads+1]=f end
    function AddEventHandler()end
    function GetGameTimer()return clock end
    function DoesEntityExist(e)return entities[e]~=nil end
    function Entity(e)return entities[e]end
    function NetworkGetNetworkIdFromEntity(e)return e end
    function NetworkDoesNetworkIdExist(e)return entities[e]~=nil end
    function NetToPed(e)return e end
    function NetworkHasControlOfEntity()return true end
    function FreezeEntityPosition()unfreezes=unfreezes+1 end
    function DeleteEntity()deletions=deletions+1 end
    function SetEntityAsMissionEntity()end
    function TriggerServerEvent()end
    function TriggerEvent()end
    function SetNuiFocus()end
    function SetNuiFocusKeepInput()end
    function GetEntityHealth(e)return entities[e].hp end
    exports=setmetatable({}, {__call=function()end})
    ''')
    vm.execute((ROOT/'client/runtime.lua').read_text(encoding='utf-8'))
    vm.execute('''
    local r={id='epoch:1',net=100,zone=1,model='test',settings={health=350,headshotOnly=false},home={x=0,y=0,z=0},radius=40}
    ZC.pending[r.id]={ped=100,expires=1}
    handlers['thehunt_zombie:upsert'](r)
    assert(not ZC.pending[r.id] and unfreezes==1,'delta did not acknowledge creation')
    assert(ZC.entity(ZC.peds[r.id])==100)
    assert(ZC.health(ZC.peds[r.id],100)==227,'snapshot healed HP')
    handlers['thehunt_zombie:snapshot']({r},{[2]=true},'epoch')
    assert(ZC.byNet[100]==r.id and ZC.immune[2])
    handlers['thehunt_zombie:committed'](r.id)
    assert(unfreezes==1,'duplicate commit reapplied initialization')
    entities[100].state.huntZombie={id='epoch:2'}
    assert(ZC.entity(ZC.peds[r.id])==nil,'old identity bound to reused network ID')
    handlers['thehunt_zombie:remove'](r.id)
    assert(deletions==0,'late remove deleted a different entity')
    ZC.pending.old={ped=100};handlers['thehunt_zombie:cancel']('old')
    assert(deletions==0,'late cancel deleted reused entity handle')
    source=12;handlers['thehunt_zombie:upsert'](r)
    assert(ZC.peds[r.id]==nil,'non-server entity registration accepted')
    ''')
print('PASS: two client registries: shared identity/HP, snapshot, commit race, net/handle reuse, stale removal, server-only deltas')
