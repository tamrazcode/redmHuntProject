-- Real inventory equipment, with original equipment escrowed until /pedrestore.
-- Blueprint metadata is an allowlist: container contents and item identities never copy.
if PedEquipment then return end
PedEquipment = {ready=false}
local plans, locks, sessions = {}, {}, {}
function PedEquipment.HasSession(charId) return sessions[tonumber(charId)]==true end
local slots={Hat=0,Mask=1,EyeWear=2,NeckWear=3,Shirt=4,Vest=5,Coat=6,CoatClosed=7,Poncho=8,Cloak=9,
 Pant=10,Skirt=11,Dress=12,Boots=13,Spurs=14,Spats=15,Chap=16,Gunbelt=17,Holster=18,Belt=19,
 Suspender=21,Glove=22,Gauntlets=23,Accessories=24,Bracelet=26,RingLh=27,RingRh=28,Satchels=29}
local function decode(v)
 if type(v)=='table' then return v end
 local ok,data=pcall(json.decode,v or '{}');return ok and type(data)=='table' and data or {}
end
local function owner(src)
 return exports.thehunt_core:GetPlayerIdentifier(src),exports.thehunt_core:GetCharacterId(src)
end
local function clean(meta)
 meta=decode(meta)
 return {component=tonumber(meta.component),category=meta.category,gender=meta.gender,tint=meta.tint,
  label=meta.label,backpackFit=meta.backpackFit}
end
function PedEquipment.Capture(charId, original)
 local stash=original and MySQL.single.await('SELECT captured FROM thehunt_pedcustom_equipment WHERE charid=?',{charId})
 local rows
 if stash and stash.captured==1 then
  rows=MySQL.query.await("SELECT item_name,metadata FROM thehunt_inventories WHERE charidentifier=? AND container='equipment' AND identifier=?",{charId,'pedcustom:'..charId})
 else
  rows=MySQL.query.await("SELECT item_name,metadata FROM thehunt_inventories WHERE charidentifier=? AND container='equipment' AND identifier NOT LIKE 'pedcustom:%'",{charId})
 end
 local result={}
 for _,row in ipairs(rows or {}) do
  local def=exports.thehunt_items:GetItemData(row.item_name)
  if def and def.clothing and slots[def.clothingSlot] then result[#result+1]={item=row.item_name,metadata=clean(row.metadata)} end
 end
 return result
end
function PedEquipment.ApplyOriginalClothes(app,charId)
 app.comps=app.comps or {};app.compTints=app.compTints or {}
 local items=PedEquipment.Capture(charId,true)
 local session=MySQL.single.await('SELECT captured FROM thehunt_pedcustom_equipment WHERE charid=?',{charId})
 if #items==0 and not session then return app end -- legacy characters may only have a saved clothing snapshot
 for category in pairs(slots)do app.comps[category]=-1;app.compTints[category]=nil end
 for _,entry in ipairs(items)do
  local def=exports.thehunt_items:GetItemData(entry.item)
  if def and not def.isBackpack then
   app.comps[def.clothingSlot]=entry.metadata.component or -1
   app.compTints[def.clothingSlot]=entry.metadata.tint
  end
 end
 return app
end
function PedEquipment.Blueprint(data)
 if not data or (data.model~='mp_male' and data.model~='mp_female') then return {} end
 local result,bySlot={},{}
 -- Appearance is authoritative for actual garments; retained equipment supplies physical backpacks.
 for category,value in pairs(data.appearance and data.appearance.comps or {}) do
  local component=tonumber(type(value)=='table' and (value.comp or value.hash) or value)
  local item='clothing_'..category:lower()
  local def=exports.thehunt_items:GetItemData(item)
  if def and def.clothing and slots[category] and component and component~=0 and component~=-1 then
   bySlot[category]={item=item,metadata={component=component,category=category,
    gender=data.model=='mp_female' and 'Female' or 'Male',tint=data.appearance.compTints and data.appearance.compTints[category]}}
  end
 end
 for _,entry in ipairs(data.equipment or {}) do
  local def=exports.thehunt_items:GetItemData(entry.item)
  assert(def and def.clothing and slots[def.clothingSlot], 'Неизвестный предмет экипировки')
  if def.isBackpack or not data.appearance then bySlot[def.clothingSlot]={item=entry.item,metadata=clean(entry.metadata)} end
 end
 for _,entry in pairs(bySlot) do result[#result+1]=entry end
 return result
end
local function rowsFor(identifier,charId)
 return MySQL.query.await('SELECT * FROM thehunt_inventories WHERE identifier=? AND charidentifier=? ORDER BY id',{identifier,charId}) or {}
end
local function tree(rows, roots)
 local ids={}
 for _,row in ipairs(rows) do if roots(row) then ids[row.id]=true end end
 local changed=true
 while changed do
  changed=false
  for _,row in ipairs(rows) do
   local parent=tonumber((row.container or ''):match('^clothing:(%d+)$') or (row.container or ''):match('^container:(%d+)$'))
   if parent and ids[parent] and not ids[row.id] then ids[row.id]=true;changed=true end
  end
 end
 return ids
end
local function stamp(rows)
 local values={}
 for _,row in ipairs(rows) do values[#values+1]={row.id,row.container,row.count,row.metadata,row.slot_x,row.slot_y} end
 return json.encode(values)
end
local function unlock(src)
 locks[src]=nil
 local player=Player(src)
 if player then player.state:set('huntPedEquipmentLocked',false,true) end
end
exports('IsInventorySwitching',function(src)return locks[tonumber(src)]~=nil end)
function PedEquipment.Plan(src, data, restoring)
 assert(PedEquipment.ready,'Модуль экипировки ещё загружается')
 local identifier,charId=owner(src);assert(identifier and charId,'Персонаж не выбран')
 local rows=rowsFor(identifier,charId)
 local session=MySQL.single.await('SELECT * FROM thehunt_pedcustom_equipment WHERE charid=?',{charId})
 local temporary=session and session.captured==1
 local ids=tree(rows,function(row)return row.container=='equipment' or decode(row.metadata).pedcustom==true end)
 local count=0
 local function packed(meta)
  local n=0
  for _,key in ipairs({'container_contents','clothing_contents'})do
   for _,item in ipairs(type(meta[key])=='table' and meta[key] or {})do
    n=n+(tonumber(item.count) or 1)+packed(decode(item.metadata))
   end
  end
  return n
 end
 if temporary then for _,row in ipairs(rows) do if ids[row.id] and not decode(row.metadata).pedcustom then count=count+(tonumber(row.count) or 1) end end end
 if temporary then for _,row in ipairs(rows)do if ids[row.id] then count=count+packed(decode(row.metadata)) end end end
 local token=tostring(GetGameTimer())..':'..tostring(math.random(100000,999999))
 plans[src]={token=token,charId=charId,identifier=identifier,stamp=stamp(rows),expires=GetGameTimer()+120000}
 locks[src]=true;Player(src).state:set('huntPedEquipmentLocked',true,true)
 SetTimeout(120000,function()if plans[src] and plans[src].token==token then plans[src]=nil;unlock(src);TriggerEvent('thehunt_pedcustom:equipmentPlanExpired',src);TriggerClientEvent('thehunt_pedcustom:confirmationExpired',src) end end)
 return {token=token,count=count,first=not temporary,restoring=restoring,
  message=count>0 and ('В карманах, сумках и рюкзаке временного облика есть '..count..' предметов. При смене они исчезнут. Вещи исходного персонажа сохранены отдельно. Продолжить?') or nil}
end
function PedEquipment.Cancel(src)
 plans[src]=nil;unlock(src)
end
function PedEquipment.Replace(src,data,token,restoring)
 local identifier,charId=owner(src)
 local plan=plans[src]
 assert(plan and plan.token==token and plan.charId==charId and plan.expires>=GetGameTimer(),'Подтвердите смену экипировки ещё раз')
 local rows=rowsFor(identifier,charId)
 assert(stamp(rows)==plan.stamp,'Инвентарь изменился. Повторите смену и подтверждение')
 local session=MySQL.single.await('SELECT * FROM thehunt_pedcustom_equipment WHERE charid=?',{charId})
 local captured=session and session.captured==1
 local stash='pedcustom:'..charId
 local queries={}
 local function query(sql,values)queries[#queries+1]={query=sql,values=values} end
 -- Lock the owned inventory range, then recheck every row inside the transaction.
 -- A conflicting insert into the sentinel aborts the entire transaction on a stale snapshot.
 query('SELECT id FROM thehunt_inventories WHERE identifier=? AND charidentifier=? FOR UPDATE',{identifier,charId})
 local matches,params={}, {identifier,charId,#rows,identifier,charId}
 for _,row in ipairs(rows)do
  matches[#matches+1]='(id=? AND container=? AND count=? AND slot_x=? AND slot_y=? AND is_rotated=? AND item_name=? AND COALESCE(metadata,\'\')=?)'
  for _,v in ipairs({row.id,row.container,row.count,row.slot_x,row.slot_y,row.is_rotated,row.item_name,row.metadata or ''})do params[#params+1]=v end
 end
 query('INSERT INTO thehunt_pedcustom_guard (id) SELECT 1 WHERE (SELECT COUNT(*) FROM thehunt_inventories WHERE identifier=? AND charidentifier=?)<>? OR EXISTS (SELECT 1 FROM thehunt_inventories WHERE identifier=? AND charidentifier=? AND NOT ('..(#matches>0 and table.concat(matches,' OR ') or 'FALSE')..'))',params)
 if not captured and not restoring then
  query('INSERT INTO thehunt_pedcustom_equipment (charid,identifier,captured) VALUES (?,?,1) ON DUPLICATE KEY UPDATE captured=1,identifier=VALUES(identifier)',{charId,identifier})
  local originals=tree(rows,function(row)return row.container=='equipment' end)
  for id in pairs(originals)do query('UPDATE thehunt_inventories SET identifier=? WHERE id=? AND identifier=? AND charidentifier=?',{stash,id,identifier,charId})end
 elseif captured then
  local temporary=tree(rows,function(row)return row.container=='equipment' or decode(row.metadata).pedcustom==true end)
  for id in pairs(temporary)do query('DELETE FROM thehunt_inventories WHERE id=? AND identifier=? AND charidentifier=?',{id,identifier,charId})end
 end
 if restoring then
  if captured then
   query('UPDATE thehunt_inventories SET identifier=? WHERE identifier=? AND charidentifier=?',{identifier,stash,charId})
   query('DELETE FROM thehunt_pedcustom_equipment WHERE charid=?',{charId})
  end
 else
  for _,entry in ipairs(PedEquipment.Blueprint(data))do
   local def=exports.thehunt_items:GetItemData(entry.item)
   local meta=clean(entry.metadata);meta.pedcustom=true
   query("INSERT INTO thehunt_inventories (identifier,charidentifier,container,slot_x,slot_y,is_rotated,item_name,count,metadata) VALUES (?,?,'equipment',?,0,0,?,1,?)",
    {identifier,charId,slots[def.clothingSlot],entry.item,json.encode(meta)})
  end
 end
 local ok=#queries==0 or MySQL.transaction.await(queries)
 PedEquipment.Cancel(src)
 assert(ok,'Не удалось сменить экипировку — транзакция отменена')
 sessions[charId]=not restoring or nil
 TriggerClientEvent('thehunt_items:refreshInventory',src)
 return true
end
MySQL.ready(function()
 MySQL.query.await([[CREATE TABLE IF NOT EXISTS thehunt_pedcustom_equipment (
 charid INT NOT NULL PRIMARY KEY, identifier VARCHAR(100) NOT NULL,captured TINYINT NOT NULL DEFAULT 0
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
 MySQL.query.await('CREATE TABLE IF NOT EXISTS thehunt_pedcustom_guard (id TINYINT NOT NULL PRIMARY KEY) ENGINE=InnoDB')
 MySQL.query.await('INSERT IGNORE INTO thehunt_pedcustom_guard (id) VALUES (1)')
 for _,row in ipairs(MySQL.query.await('SELECT charid FROM thehunt_pedcustom_equipment WHERE captured=1'))do sessions[tonumber(row.charid)]=true end
 PedEquipment.ready=true
end)
AddEventHandler('playerDropped',function()plans[source]=nil;locks[source]=nil end)
AddEventHandler('onResourceStop',function(name)
 if name~=GetCurrentResourceName()then return end
 for src in pairs(locks)do unlock(src)end
end)
