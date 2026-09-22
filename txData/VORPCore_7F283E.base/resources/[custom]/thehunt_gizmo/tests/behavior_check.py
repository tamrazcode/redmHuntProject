from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path('txData/VORPCore_7F283E.base/resources/[custom]')
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
events={}; notifications={}; state={}; writes=0; now=10000; source=7
GlobalState={}; admin=false; profileWrites=0
function IsPlayerAceAllowed() return admin end
function GetCurrentResourceName() return 'thehunt_items' end
function LoadResourceFile() return savedProfiles end
function SaveResourceFile(_,_,value) profileWrites=profileWrites+1;savedProfiles=value;return true end
row={id=42,item_name='backpack_1',metadata={note='preserve me'},identifier='owner',charidentifier=9,container='equipment',slot_x=29,count=1}
char={identifier='owner',charIdentifier=9}
exports={thehunt_core={GetCharacter=function() return char end}}
Items={Get=function(name) if name=='backpack_1' then return {isBackpack=true,propModel='kh_backpack1'} end end}
function SafeDecodeMeta(m) return m or {} end
function EquipmentSlotIndex() return 29 end
function GetGameTimer() return now end
function RegisterNetEvent(n,f) events[n]=f end
function AddEventHandler() end
function CreateThread() end
function TriggerClientEvent(n,src,...) notifications[n]={...} end
function Player() return {state={set=function(self,k,v) state[k]=v end}} end
json={encode=function(v) return v end,decode=function(v) return type(v)=='table' and v or {} end}
MySQL={single={await=function(sql,p)
 if char and row and row.id==p[1] and row.identifier==p[2] and row.charidentifier==p[3] and row.container=='equipment' and row.slot_x==p[4] then return row end
end},update={await=function(sql,p)
 if race then row.container='main' end
 if row.id==p[2] and row.identifier==p[3] and row.charidentifier==p[4] and row.item_name==p[5] and row.container=='equipment' and row.slot_x==p[6] then
  writes=writes+1; row.metadata.backpackFit=p[1]; return 1
 end
 return 0
end}}
function call(n,...) return events['thehunt_items:'..n](...) end
function begin() now=now+1500;call('beginBackpackFit',42); return notifications['thehunt_inventory:backpackFitStarted'][1] end
''')
lua.execute((root/'thehunt_items/shared/backpack.lua').read_text(encoding='utf-8'))
lua.execute((root/'thehunt_items/server/backpack_sync.lua').read_text(encoding='utf-8'))
s=(root/'thehunt_items/server/main.lua').read_text(encoding='utf-8')
lua.execute(s[s.index('-- Backpack fitting sessions:'):s.index('-- 1. Запрос полного инвентаря игрока')])
lua.execute('''
local v=BackpackFit.Normalize({})
assert(not BackpackFit.Normalize({x=math.huge},true))
assert(not BackpackFit.Normalize({x=0/0},true))
assert(not BackpackFit.Normalize({x='0',y=0,z=0,rx=0,ry=0,rz=0},true))
assert(not BackpackFit.Normalize({x=1,y=0,z=0,rx=0,ry=0,rz=0},true))
local token=begin();v.x=.08
call('previewBackpackFit',token,v)
assert(state.attachedBackpackFit.offset.x==.08 and writes==0)
call('cancelBackpackFit',token)
assert(state.attachedBackpackFit.offset.x==0 and writes==0)
token=begin();call('saveBackpackFit',token,v)
assert(writes==1 and row.metadata.note=='preserve me' and row.metadata.backpackFit.x==.08)
assert(notifications['thehunt_inventory:backpackFitSaved'][2]==true)
-- A new session reloads the saved per-item fit, as reconnect/equip does.
token=begin();assert(notifications['thehunt_inventory:backpackFitStarted'][2].offset.x==.08)
-- Invalid token, unbounded transform, and un-equipped item cannot write.
call('saveBackpackFit',token+999,v);assert(writes==1)
local bad={x=99,y=0,z=0,rx=0,ry=0,rz=0};call('saveBackpackFit',token,bad);assert(writes==1)
token=begin();row.container='main';now=now+500;call('previewBackpackFit',token,v);assert(writes==1)
row.container='equipment';token=begin();race=true;call('saveBackpackFit',token,v);assert(writes==1)
assert(notifications['thehunt_inventory:backpackFitSaved'][2]==false)
race=false;row.container='equipment';token=begin();char.charIdentifier=10;call('saveBackpackFit',token,v);assert(writes==1)
char.charIdentifier=9;row.identifier='someone else';local old=notifications['thehunt_inventory:backpackFitStarted'];begin();assert(notifications['thehunt_inventory:backpackFitStarted']==old)
''')
print('PASS server: preview/cancel, save+metadata, reload, malformed/bounds, ownership, character switch, unequip race')
lua.execute('''
row.identifier='owner';row.container='equipment';now=now+1500
local old=notifications['thehunt_inventory:backpackFitStarted']
call('beginBackpackFit',42,true)
assert(notifications['thehunt_inventory:backpackFitStarted']==old and profileWrites==0)
admin=true;now=now+1500;call('beginBackpackFit',42,true)
local token=notifications['thehunt_inventory:backpackFitStarted'][1]
local v={x=8,y=-12,z=20,rx=720,ry=-450,rz=360}
call('previewBackpackFit',token,v)
assert(state.attachedBackpackFit.calibration.x==8 and profileWrites==0)
call('saveBackpackFit',token,v)
assert(profileWrites==1 and GlobalState.huntBackpackProfiles.kh_backpack1.ry==-450)
assert(row.metadata.backpackFit.x==0 and state.attachedBackpackFit.calibration==nil)
call('requestBackpackStates')
assert(notifications['thehunt_inventory:backpackStates'][1][7].attachedBackpackFit.offset.x==0)
assert(notifications['thehunt_inventory:backpackStates'][2].kh_backpack1.x==8)
now=now+1500;call('beginBackpackFit',42,true)
assert(notifications['thehunt_inventory:backpackFitStarted'][2].calibration.z==20)
token=notifications['thehunt_inventory:backpackFitStarted'][1];admin=false
call('saveBackpackFit',token,v);assert(profileWrites==1)
assert(not BackpackFit.Normalize({x=0/0,y=0,z=0,rx=0,ry=0,rz=0},true,true))
''')
print('PASS admin: permission, unlimited fit, replicated profile, reopen, calibration item reset, snapshot, permission revoked')
lua.execute('GlobalState.huntBackpackProfiles=nil')
lua.execute(s[s.index('-- Backpack fitting sessions:'):s.index('-- 1. Запрос полного инвентаря игрока')])
lua.execute('assert(GlobalState.huntBackpackProfiles.kh_backpack1.x==8)')
print('PASS profile reload from saved resource file (mocked storage)')
