local resource = GetCurrentResourceName()
-- Explicit bootstrap also handles a resource restarted with a cached older manifest.
if not PedEquipment then
    local code=assert(LoadResourceFile(resource,'equipment.lua'),'thehunt_pedcustom: equipment.lua is missing')
    local module=assert(load(code,'@thehunt_pedcustom/equipment.lua','t',_ENV))
    module()
end
assert(type(PedEquipment)=='table' and type(PedEquipment.Replace)=='function','thehunt_pedcustom: equipment module failed to initialize')
local models, spawned, transforms, cooldown = {}, {}, {}, {}
local ready = false
local spawnTickets, copyTickets, columns = {}, {}, {}
local copySequence = 0
local transitions, editorSnapshots = {}, {}
local function decodeTable(value)
    if type(value) == 'table' then return value end
    local ok, result = pcall(json.decode, value or '{}')
    return ok and type(result) == 'table' and result or {}
end
local function characterAppearance(id)
    local row = MySQL.single.await('SELECT * FROM characters WHERE charidentifier = ? LIMIT 1', {id})
    assert(row, 'Персонаж не найден')
    local gender = tostring(row.gender or 'Male'):lower() == 'female' and 'Female' or 'Male'
    return {skin=decodeTable(row.skin or row.skinPlayer), comps=decodeTable(row.comps or row.compPlayer),
        compTints=decodeTable(row.compTints), gender=gender, walk=row.walk}
end
local function ownedSpawns(src)
    local rows = {}
    for net, record in pairs(spawned) do
        if not DoesEntityExist(record.entity) then spawned[net] = nil
        elseif record.owner == src then rows[#rows+1] = {net=net,model=record.data.model} end
    end
    return rows
end
exports('GetTemporaryAppearance',function(src)return transforms[tonumber(src)] end)
exports('IsTemporaryAppearanceActive', function(src)
    src=tonumber(src)
    return transforms[src]~=nil or PedEquipment.HasSession(exports.thehunt_core:GetCharacterId(src))
end)
for _, entry in ipairs(json.decode(LoadResourceFile(resource, 'data/models.json'))) do models[entry.model] = entry end
local function admin(src) return exports.thehunt_core:IsPlayerAdmin(src) == true end
local function identity(src) return exports.thehunt_core:GetPlayerIdentifier(src) end
local function validate(data)
    assert(type(data) == 'table' and models[data.model], 'Неизвестная модель')
    assert(#json.encode(data) <= 60000, 'Пресет слишком большой')
    local function number(v, lo, hi, default)
        v = tonumber(v) or default
        assert(v == v and v >= lo and v <= hi, 'Значение вне допустимого диапазона')
        return v
    end
    data.outfit = math.floor(number(data.outfit, 0, math.max(0, models[data.model].outfits - 1), 0))
    data.scale = number(data.scale, 0.2, 3.0, 1.0)
    data.health = math.floor(number(data.health, 1, 10000, 200))
    data.invincible = data.invincible == true
    data.frozen = data.frozen == true
    data.collision = data.collision ~= false
    data.ragdoll = data.ragdoll ~= false
    data.spirit = data.spirit == true and models[data.model].spiritHash ~= nil
    if data.tags then
        assert(type(data.tags) == 'table' and #data.tags <= 100, 'Слишком много компонентов')
        for _, tag in ipairs(data.tags) do
            assert(type(tag) == 'table', 'Неверный компонент')
            for _, key in ipairs({'drawable','albedo','normal','material','palette'}) do
                tag[key] = math.floor(number(tag[key], -2147483648, 4294967295, 0))
            end
            for _, key in ipairs({'tint0','tint1','tint2'}) do tag[key] = math.floor(number(tag[key], 0, 255, 0)) end
        end
    end
    assert(data.behavior == nil or data.behavior == 'idle' or data.behavior == 'wander', 'Неизвестное поведение')
    if data.appearance then
        if data.model ~= 'mp_male' and data.model ~= 'mp_female' then
            data.appearance = nil
        else
            assert(type(data.appearance) == 'table', 'Неверная внешность')
            assert(type(data.appearance.skin) == 'table', 'Отсутствует снимок внешности')
            for _, key in ipairs({'comps','compTints'}) do
                assert(data.appearance[key] == nil or type(data.appearance[key]) == 'table', 'Неверные компоненты внешности')
            end
            data.appearance.gender = data.model == 'mp_female' and 'Female' or 'Male'
        end
    end
    if data.equipment then assert(type(data.equipment)=='table' and #data.equipment<=30,'Неверная экипировка') end
    data.equipment=PedEquipment.Blueprint(data)
    return data
end
local function list()
    return MySQL.query.await('SELECT id, name, owner, author, model, revision FROM thehunt_pedcustom_presets ORDER BY updated_at DESC LIMIT 2000')
end
MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS thehunt_pedcustom_presets (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        owner VARCHAR(100) NOT NULL, author VARCHAR(100) NOT NULL,
        name VARCHAR(100) NOT NULL, model VARCHAR(100) NOT NULL,
        payload MEDIUMTEXT NOT NULL, revision INT NOT NULL DEFAULT 1,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX owner_idx (owner)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    for _, row in ipairs(MySQL.query.await('SHOW COLUMNS FROM characters')) do columns[row.Field:lower()] = true end
    ready = true
end)
RegisterNetEvent('thehunt_pedcustom:request', function(requestId, action, args)
    local src = source
    if type(requestId) ~= 'number' then return end
    if not admin(src) then
        TriggerClientEvent('thehunt_pedcustom:response', src, requestId, false, 'Доступ только для администраторов')
        return
    end
    local now = GetGameTimer()
    local bucket=cooldown[src] or {tokens=20,time=now}
    bucket.tokens=math.min(20,bucket.tokens+(now-bucket.time)/100);bucket.time=now
    cooldown[src]=bucket
    if bucket.tokens<1 then TriggerClientEvent('thehunt_pedcustom:response',src,requestId,false,'Слишком много запросов');return end
    bucket.tokens=bucket.tokens-1
    local ok, result = pcall(function()
        assert(ready and PedEquipment.ready, 'База ещё загружается')
        args = type(args) == 'table' and args or {}
        local owner = identity(src)
        assert(owner, 'Сессия не готова')
        if action == 'list' then
            local charId=exports.thehunt_core:GetCharacterId(src)
            return {rows=list(),owner=owner,characterId=charId,spawned=ownedSpawns(src),equipmentRecovery=not transforms[src] and PedEquipment.HasSession(charId)}
        end
        if action == 'players' then
            local rows = {}
            for _, player in ipairs(GetPlayers()) do
                local id = tonumber(player)
                local char = exports.thehunt_core:GetCharacter(id)
                rows[#rows+1] = {id=id, name=GetPlayerName(id), characterId=exports.thehunt_core:GetCharacterId(id),
                    characterName=char and ((char.firstname or '') .. ' ' .. (char.lastname or '')) or 'Выбор персонажа'}
            end
            table.sort(rows, function(a,b) return a.id < b.id end)
            return rows
        end
        if action == 'characters' then
            local q = tostring(args.query or ''):sub(1,80)
            local page = math.max(0, math.min(100000, math.floor(tonumber(args.page) or 0)))
            local filter = columns.deleted_at and ' AND deleted_at IS NULL' or ''
            local rows = MySQL.query.await("SELECT charidentifier AS id, firstname, lastname, gender FROM characters WHERE (CONCAT(firstname, ' ', lastname) LIKE ? OR CAST(charidentifier AS CHAR) = ?)" .. filter .. ' ORDER BY charidentifier DESC LIMIT 51 OFFSET ?', {'%'..q..'%', q, page*50})
            local more = #rows > 50
            if more then table.remove(rows) end
            return {rows=rows,page=page,more=more}
        end
        if action == 'copyCharacter' then
            local app = characterAppearance(tonumber(args.id) or 0)
            assert(next(app.skin), 'У персонажа нет сохранённой внешности')
            PedEquipment.ApplyOriginalClothes(app,tonumber(args.id))
            return validate({model=app.gender == 'Female' and 'mp_female' or 'mp_male', appearance=app,equipment=PedEquipment.Capture(tonumber(args.id),true),
                scale=tonumber(app.skin.Scale) or 1, sourceLabel='Персонаж #'..tostring(args.id)})
        end
        if action == 'copyPlayer' then
            local target = tonumber(args.id)
            assert(target and GetPlayerName(target) and exports.thehunt_core:GetCharacterId(target), 'Игрок вышел или ещё не выбрал персонажа')
            copySequence = copySequence + 1
            local token, p = copySequence, promise.new()
            copyTickets[token] = {target=target, requester=src, promise=p, characterId=exports.thehunt_core:GetCharacterId(target)}
            TriggerClientEvent('thehunt_pedcustom:captureRequested', target, token)
            SetTimeout(8000, function()
                if copyTickets[token] then copyTickets[token]=nil; p:resolve({error='Игрок не ответил. Можно скопировать его сохранённого персонажа.'}) end
            end)
            local result = Citizen.Await(p)
            assert(not result.error, result.error)
            local snapshot = validate(result.data)
            assert(GetPlayerName(target) and exports.thehunt_core:GetCharacterId(target) == result.characterId, 'Игрок сменил персонажа')
            local ped = GetPlayerPed(target)
            assert(ped ~= 0 and (GetEntityModel(ped) & 0xffffffff) == (joaat(snapshot.model) & 0xffffffff), 'Игрок сменил модель — повторите копирование')
            snapshot.equipment=PedEquipment.Capture(result.characterId)
            snapshot.sourceLabel = 'Онлайн #'..target..' · '..GetPlayerName(target)
            return snapshot
        end
        if action == 'abortAppearance' then
            local tx=transitions[src]
            if tx then transforms[src]=tx.previous;transitions[src]=nil end
            PedEquipment.Cancel(src)
            return true
        end
        if action == 'commitAppearance' then
            local tx=transitions[src]
            assert(tx and tx.token==args.token and tx.characterId==exports.thehunt_core:GetCharacterId(src),'Смена облика устарела')
            local model=tx.restoring and (tx.gender=='Female' and 'mp_female' or 'mp_male') or tx.data.model
            local ped,deadline=GetPlayerPed(src),GetGameTimer()+4000
            while (ped==0 or (GetEntityModel(ped)&0xffffffff)~=(joaat(model)&0xffffffff)) and GetGameTimer()<deadline do
                Wait(100);ped=GetPlayerPed(src)
            end
            assert(ped~=0 and (GetEntityModel(ped)&0xffffffff)==(joaat(model)&0xffffffff),'Модель ещё не синхронизирована')
            PedEquipment.Replace(src,tx.data,tx.token,tx.restoring)
            if tx.data then tx.data._transition=nil end
            transforms[src]=tx.restoring and nil or tx.data
            transitions[src]=nil;editorSnapshots[src]=nil
            if ped~=0 then Entity(ped).state:set('huntPedCustom',transforms[src],true) end
            return true
        end
        if action == 'cancelEdit' then
            local snapshot=editorSnapshots[src]
            assert(snapshot,'Редактор не открыт')
            transforms[src]=snapshot.data;editorSnapshots[src]=nil
            local charId=exports.thehunt_core:GetCharacterId(src)
            return {data=transforms[src],character=not transforms[src] and PedEquipment.ApplyOriginalClothes(characterAppearance(charId),charId) or nil}
        end
        if action == 'captureEquipment' then return PedEquipment.Capture(exports.thehunt_core:GetCharacterId(src)) end
        if action == 'equipmentPlan' then return PedEquipment.Plan(src,args.data,args.restoring) end
        if action == 'equipmentCancel' then PedEquipment.Cancel(src);return true end
        if action == 'validate' then return validate(args.data) end
        if action == 'getSpawn' then
            local record = spawned[tonumber(args.net)]
            assert(record and record.owner == src and DoesEntityExist(record.entity), 'NPC не найден')
            return record.data
        end
        if action == 'get' then
            local row = MySQL.single.await('SELECT * FROM thehunt_pedcustom_presets WHERE id = ?', { tonumber(args.id) or 0 })
            assert(row, 'Пресет не найден')
            row.data = json.decode(row.payload); row.payload = nil
            return row
        end
        if action == 'save' then
            local data = validate(args.data)
            local name = tostring(args.name or ''):match('^%s*(.-)%s*$')
            if #name == 0 then name = tostring(data.model or 'Preset') end
            assert(#name <= 100, 'Название: от 1 до 100 байт')
            if args.id then
                local changed = MySQL.update.await('UPDATE thehunt_pedcustom_presets SET name=?, model=?, payload=?, revision=revision+1 WHERE id=? AND owner=? AND revision=?',
                    { name, data.model, json.encode(data), tonumber(args.id) or 0, owner, tonumber(args.revision) or 0 })
                assert(changed == 1, 'Пресет чужой или уже изменён. Сохраните копию либо обновите список')
            else
                local count = MySQL.scalar.await('SELECT COUNT(*) FROM thehunt_pedcustom_presets WHERE owner=?', {owner})
                assert(count < 300, 'Лимит: 300 пресетов на администратора')
                MySQL.insert.await('INSERT INTO thehunt_pedcustom_presets (owner,author,name,model,payload) VALUES (?,?,?,?,?)',
                    { owner, GetPlayerName(src) or 'Admin', name, data.model, json.encode(data) })
            end
            return { rows = list(), owner = owner }
        end
        if action == 'delete' then
            local changed = MySQL.update.await('DELETE FROM thehunt_pedcustom_presets WHERE id=? AND owner=? AND revision=?',
                {tonumber(args.id) or 0, owner, tonumber(args.revision) or 0})
            assert(changed == 1, 'Удаление недоступно: чужой или изменённый пресет')
            return { rows = list(), owner = owner }
        end
        if action == 'apply' or action == 'edit' then
            assert(not transitions[src],'Предыдущая смена ещё не завершена')
            local data = validate(args.data)
            data.frozen = false
            if action=='edit' then
                assert(not editorSnapshots[src],'Редактор уже открыт')
                editorSnapshots[src]={data=transforms[src]}
            else
                assert(type(args.equipmentToken)=='string','Отсутствует подтверждение экипировки')
                local previous=transforms[src]
                if editorSnapshots[src] then previous=editorSnapshots[src].data end
                transitions[src]={data=data,token=args.equipmentToken,previous=previous,characterId=exports.thehunt_core:GetCharacterId(src)}
                data._transition=args.equipmentToken
            end
            transforms[src] = data
            return data
        end
        if action == 'restore' then
            assert(not transitions[src],'Предыдущая смена ещё не завершена')
            local charId = exports.thehunt_core:GetCharacterId(src)
            assert(charId, 'Персонаж не выбран')
            local app = characterAppearance(charId)
            PedEquipment.ApplyOriginalClothes(app,charId)
            transitions[src]={restoring=true,gender=app.gender,token=args.equipmentToken,previous=transforms[src],characterId=charId}
            return {character=app, owner=owner, characterId=charId,_transition=args.equipmentToken}
        end
        if action == 'spawn' then
            local data = validate(args.data)
            local count = 0
            for _, record in pairs(spawned) do if record.owner == src then count = count + 1 end end
            assert(count < 20, 'Лимит: 20 созданных NPC на администратора')
            local ped = GetPlayerPed(src)
            assert(ped ~= 0, 'Игрок не готов')
            local pos = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local radians = math.rad(heading)
            assert(not spawnTickets[src] or spawnTickets[src].expires < now, 'Предыдущее создание ещё не завершено')
            local position = {x=pos.x-math.sin(radians)*3, y=pos.y+math.cos(radians)*3, z=pos.z, heading=heading}
            spawnTickets[src] = {data=data, position=position, expires=now+15000}
            return {data=data, position=position}
        end
        if action == 'registerSpawn' then
            local ticket = spawnTickets[src]
            assert(ticket and ticket.expires >= now, 'Разрешение на создание истекло')
            local net = tonumber(args.net)
            local entity = net and NetworkGetEntityFromNetworkId(net) or 0
            assert(entity ~= 0 and DoesEntityExist(entity), 'NPC ещё не зарегистрирован в сети')
            assert(NetworkGetEntityOwner(entity) == src and GetEntityType(entity) == 1, 'Неверный владелец NPC')
            assert(entity ~= GetPlayerPed(src), 'Нельзя зарегистрировать игрока как NPC')
            for _, player in ipairs(GetPlayers()) do assert(entity ~= GetPlayerPed(tonumber(player)), 'Это пед игрока') end
            assert((GetEntityModel(entity) & 0xffffffff) == (joaat(ticket.data.model) & 0xffffffff), 'Модель не совпала')
            local pos, target = GetEntityCoords(entity), ticket.position
            assert((pos.x-target.x)^2+(pos.y-target.y)^2+(pos.z-target.z)^2 < 64, 'NPC слишком далеко от разрешённой точки')
            assert(not spawned[net], 'NPC уже зарегистрирован')
            spawnTickets[src] = nil
            Entity(entity).state:set('isProtected', true, true)
            Entity(entity).state:set('huntPedCustom', ticket.data, true)
            spawned[net] = { entity = entity, owner = src, data = ticket.data }
            return {net = net}
        end
        if action == 'updateSpawn' or action == 'removeSpawn' then
            local net = tonumber(args.net)
            local record = spawned[net]
            assert(record and record.owner == src and DoesEntityExist(record.entity), 'NPC не найден или принадлежит другому админу')
            if action == 'removeSpawn' then DeleteEntity(record.entity); spawned[net] = nil
            else
                local data = validate(args.data)
                assert(data.model == record.data.model, 'Для другой модели создайте нового NPC')
                record.data = data
                Entity(record.entity).state:set('huntPedCustom', data, true)
            end
            return true
        end
        if action == 'duplicate' then
            local row = MySQL.single.await('SELECT * FROM thehunt_pedcustom_presets WHERE id = ?', { tonumber(args.id) or 0 })
            assert(row, 'Пресет не найден')
            local count = MySQL.scalar.await('SELECT COUNT(*) FROM thehunt_pedcustom_presets WHERE owner=?', {owner})
            assert(count < 300, 'Лимит: 300 пресетов на администратора')
            local dupName = (row.name .. ' (Копия)'):sub(1, 100)
            MySQL.insert.await('INSERT INTO thehunt_pedcustom_presets (owner,author,name,model,payload) VALUES (?,?,?,?,?)',
                { owner, GetPlayerName(src) or 'Admin', dupName, row.model, row.payload })
            return { rows = list(), owner = owner }
        end
        if action == 'teleportSpawn' then
            local net = tonumber(args.net)
            local record = spawned[net]
            assert(record and record.owner == src and DoesEntityExist(record.entity), 'NPC не найден или принадлежит другому админу')
            local coords = GetEntityCoords(record.entity)
            local heading = GetEntityHeading(record.entity)
            local ped = GetPlayerPed(src)
            if ped ~= 0 then
                SetEntityCoords(ped, coords.x + 1.0, coords.y, coords.z, false, false, false, false)
            end
            return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
        end
        if action == 'removeAllSpawn' then
            for net, record in pairs(spawned) do
                if record.owner == src then
                    if DoesEntityExist(record.entity) then DeleteEntity(record.entity) end
                    spawned[net] = nil
                end
            end
            return { spawned = {} }
        end
        error('Неизвестное действие')
    end)
    if not ok then
        local tx=transitions[src]
        if tx then transforms[src]=tx.previous;transitions[src]=nil end
        pcall(PedEquipment.Cancel,src)
    end
    TriggerClientEvent('thehunt_pedcustom:response', src, requestId, ok, ok and result or tostring(result))
end)
RegisterNetEvent('thehunt_pedcustom:publish', function()
    local src = source
    if not admin(src) or not transforms[src] or transitions[src] or editorSnapshots[src] then return end
    local snapshot = transforms[src]
    CreateThread(function()
        for attempt=1,30 do
            if transforms[src] ~= snapshot or not admin(src) then return end
            local ped = GetPlayerPed(src)
            if ped ~= 0 and (GetEntityModel(ped) & 0xffffffff) == (joaat(snapshot.model) & 0xffffffff) then
                Entity(ped).state:set('huntPedCustom', snapshot, true)
                return
            end
            Wait(100)
        end
    end)
end)
AddEventHandler('playerDropped', function()
    local src = source
    transforms[src], cooldown[src], spawnTickets[src],transitions[src],editorSnapshots[src] = nil,nil,nil,nil,nil
    for net, record in pairs(spawned) do
        if record.owner == src then DeleteEntity(record.entity); spawned[net] = nil end
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= resource then return end
    for _, record in pairs(spawned) do if DoesEntityExist(record.entity) then DeleteEntity(record.entity) end end
end)

RegisterNetEvent('thehunt_pedcustom:captureResponse', function(token, data, err)
    local ticket = copyTickets[token]
    if not ticket or ticket.target ~= source then return end
    copyTickets[token] = nil
    if not admin(ticket.requester) then ticket.promise:resolve({error='Доступ отозван'}); return end
    ticket.promise:resolve({data=data, error=err, characterId=ticket.characterId})
end)

RegisterNetEvent('thehunt_pedcustom:clearSession',function()local src=source;transforms[src]=nil;transitions[src]=nil;editorSnapshots[src]=nil;PedEquipment.Cancel(src)end)

AddEventHandler('thehunt_pedcustom:inventoryClothingChanged',function(src,category,metadata)
    local data=transforms[src]
    if not data or not data.appearance or transitions[src] or editorSnapshots[src] then return end
    data.appearance.comps=data.appearance.comps or {}
    data.appearance.compTints=data.appearance.compTints or {}
    data.appearance.comps[category]=metadata and tonumber(metadata.component) or -1
    data.appearance.compTints[category]=metadata and metadata.tint or nil
    data.tags=nil
    data.equipment=PedEquipment.Capture(exports.thehunt_core:GetCharacterId(src))
    TriggerClientEvent('thehunt_pedcustom:inventoryAppearance',src,data)
    local ped=GetPlayerPed(src)
    if ped~=0 then Entity(ped).state:set('huntPedCustom',data,true) end
end)
print('[thehunt_pedcustom] Studio 2.0: equipment module loaded; awaiting database readiness')
AddEventHandler('thehunt_pedcustom:equipmentPlanExpired',function(src)
    local tx=transitions[src]
    if tx then transforms[src]=tx.previous;transitions[src]=nil end
end)
