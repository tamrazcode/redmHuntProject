-- =================================================================
-- HUNT: Hard RP — The Corruption | Server Authoritative Loot Spawner
-- =================================================================

LootSpawner = {}

local SlotMutations = {}
local ClearingZones = {}
local ActiveSlots = {}      -- [slotId] = slotData
local SlotsByZone = {}      -- [zoneId] = { [slotId] = slotData }
local SpawnInProgress = {}  -- [zoneId] = true while its DB inserts are serialized
local SpawnBatchInProgress = false -- only one zone batch writes active slots at a time
local slotIdCounter = -1 -- transient slots cannot collide with SQL auto-increment IDs
local ready = false
function LootSpawner.IsReady() return ready end
function LootSpawner.IsZoneBusy(zoneId)
    local id = tonumber(zoneId)
    if SpawnInProgress[id] or ClearingZones[id] then return true end
    for slotId in pairs(SlotsByZone[id] or {}) do
        if SlotMutations[slotId] or (LootPickup and LootPickup.IsLocked(slotId)) then return true end
    end
    return false
end

-- =================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И ЗАГРУЗКА АКТИВНЫХ СЛОТОВ ИЗ БД
-- =================================================================

function LootSpawner.Init(callback)
    ready = false
    ActiveSlots = {}
    SlotsByZone = {}
    SpawnInProgress = {}
    SpawnBatchInProgress = false

    MySQL.query("SELECT *, UNIX_TIMESTAMP(spawned_at) AS spawned_unix, UNIX_TIMESTAMP(expires_at) AS expires_unix FROM thehunt_loot_active_slots", {}, function(results)
        if results and type(results) == "table" then
            for _, r in ipairs(results) do
                if r and r.id then
                    local sId = tonumber(r.id)
                    local zId = tonumber(r.zone_id) or 0
                    if sId then
                        local meta = {}
                        if r.metadata and r.metadata ~= "" then
                            local success, decoded = pcall(function() return json.decode(r.metadata) end)
                            if success and type(decoded) == "table" then
                                meta = decoded
                            end
                        end

                        local itemDef = nil
                        if Items and Items.Get then
                            itemDef = Items.Get(r.item_name)
                        elseif exports.thehunt_items and exports.thehunt_items.GetItemData then
                            itemDef = exports.thehunt_items:GetItemData(r.item_name)
                        end

                        local itemLabel = (type(meta) == "table" and meta.label) or (itemDef and itemDef.label) or r.item_name
                        local zoneData = Zones and Zones.Get and Zones.Get(zId)
                        local zCenter = zoneData and zoneData.coords or vector3(tonumber(r.x) or 0.0, tonumber(r.y) or 0.0, tonumber(r.z) or 0.0)

                        local slot = {
                            id = sId,
                            zone_id = zId,
                            zone_type = zoneData and zoneData.zone_type or "circle",
                            render_radius = zoneData and zoneData.render_radius or Config.DefaultRenderRadius,
                            zone_center_x = zCenter.x,
                            zone_center_y = zCenter.y,
                            zone_center_z = zCenter.z,
                            item_name = r.item_name,
                            label = itemLabel,
                            count = tonumber(r.count) or 1,
                            x = tonumber(r.x) or 0.0,
                            y = tonumber(r.y) or 0.0,
                            z = tonumber(r.z) or 0.0,
                            heading = tonumber(r.heading) or 0.0,
                            model_name = r.model_name,
                            model_hash = r.model_hash and tonumber(r.model_hash) or nil,
                            metadata = meta or {},
                            spawned_at = tonumber(r.spawned_unix) or os.time(),
                            expires_at = tonumber(r.expires_unix)
                        }

                        ActiveSlots[sId] = slot
                        if not SlotsByZone[zId] then SlotsByZone[zId] = {} end
                        SlotsByZone[zId][sId] = slot


                    end
                end
            end
            print(string.format("^2[HUNT LOOT] Загружено %d активных слотов лута в мире.^7", #results))
            -- Синхронизируем всех подключенных игроков сразу при старте
            TriggerClientEvent("thehunt_loot:receiveActiveSlots", -1, ActiveSlots)
        end

        ready = true
        LootSpawner.CheckExpiredSlots()
        for zoneId in pairs(SlotsByZone) do
            local zone = Zones.Get(zoneId)
            if not zone or not zone.is_enabled then LootSpawner.ClearZoneSlots(zoneId) end
        end
        if callback then callback() end
    end)
end

function LootSpawner.GetActiveSlots()
    return ActiveSlots
end

function LootSpawner.GetSlot(slotId)
    local sId = tonumber(slotId)
    local slot = sId and ActiveSlots[sId]
    if not slot or SlotMutations[sId] or ClearingZones[slot.zone_id] then return nil end
    return slot
end

function LootSpawner.GetZoneSlotsCount(zoneId)
    local zId = tonumber(zoneId)
    if not zId or not SlotsByZone[zId] then return 0 end
    local count = 0
    for _ in pairs(SlotsByZone[zId]) do count = count + 1 end
    return count
end

-- =================================================================
-- 2. ГЕНЕРАЦИЯ ТОЧЕК ВНУТРИ ЗОНЫ С ЖЕСТКОЙ ПРОВЕРКОЙ КОЛЛИЗИЙ
-- =================================================================

function LootSpawner.GenerateValidSlotPoint(zone, batchPoints)
    local minDistance = math.max(0.8, tonumber(zone.min_distance) or Config.DefaultMinDistance)
    local zoneId = tonumber(zone.id) or 0
    local zType = zone.zone_type or "circle"
    local zoneCenter = zone.coords or vector3(0, 0, 0)

    -- Для одиночных точек и контейнеров: если слот занят — спавн невозможен
    if zType == "point" or zType == "container" then
        if SlotsByZone[zoneId] and next(SlotsByZone[zoneId]) ~= nil then
            return nil
        end
        return zoneCenter
    end

    -- Собираем ВСЕ существующие точки из мира (ActiveSlots) в радиусе зоны + точки текущего батча
    local allOccupied = {}
    local maxZoneDim = math.max(tonumber(zone.radius) or 15.0, math.max(tonumber(zone.size_x) or 15.0, tonumber(zone.size_y) or 15.0)) + 6.0

    for _, slot in pairs(ActiveSlots) do
        if slot and slot.x and slot.y and slot.z then
            local slotPos = vector3(slot.x, slot.y, slot.z)
            if #(vector2(zoneCenter.x, zoneCenter.y) - vector2(slotPos.x, slotPos.y)) <= maxZoneDim then
                table.insert(allOccupied, slotPos)
            end
        end
    end

    if batchPoints then
        for _, pt in ipairs(batchPoints) do
            table.insert(allOccupied, pt)
        end
    end

    -- 1. Сначала ищем идеальную точку с полным соблюдением заданного min_distance
    local maxTries = 80
    for attempt = 1, maxTries do
        local cand = LootMath.GetRandomPointInZone(zone)
        if cand then
            local isValid = true
            for _, pt in ipairs(allOccupied) do
                local dist2D = #(vector2(cand.x, cand.y) - vector2(pt.x, pt.y))
                local distZ = math.abs(cand.z - pt.z)
                if dist2D < minDistance and distZ < 2.0 then
                    isValid = false
                    break
                end
            end

            if isValid then
                return cand
            end
        end
    end

    -- ЖЕСТКИЙ ЗАПРЕТ: Если невозможно найти свободное место — НЕ спавним предмет поверх другого!
    return nil
end

-- =================================================================
-- 3. СПАВН ПРЕДМЕТОВ В ЗОНЕ (SERVER AUTHORITATIVE)
-- =================================================================

local joaat = joaat or GetHashKey

function LootSpawner.SpawnLootForZone(zone)
    if not zone or not (zone.is_enabled == true or zone.is_enabled == 1) then return end
    if not zone.selected_items or #zone.selected_items == 0 then return end

    local zoneId = tonumber(zone.id)
    if not zoneId then return end
    if SpawnInProgress[zoneId] or SpawnBatchInProgress or ClearingZones[zoneId] or Zones.IsMutating(zoneId) then return end

    local zoneType = zone.zone_type or "circle"
    local currentCount = LootSpawner.GetZoneSlotsCount(zoneId)
    local maxItems = math.max(1, tonumber(zone.max_active_items) or Config.DefaultMaxItems)

    -- Для одиночных точек и контейнеров максимальная ёмкость строго ровно 1 предмет
    if zoneType == "point" or zoneType == "container" then
        maxItems = 1
    end

    -- ЖЕСТКАЯ ПРОВЕРКА: Если в слоте уже лежит предмет (currentCount >= maxItems) — НИКОГДА не спавним второй!
    if currentCount >= maxItems then return end

    local minItems = (zoneType == "point" or zoneType == "container") and 1 or math.min(maxItems, math.max(1, tonumber(zone.min_items) or Config.DefaultMinItems))

    -- Если в зоне пусто — стремимся заполнить до maxItems
    local targetCount = math.random(minItems, maxItems)

    local needed = math.max(0, targetCount - currentCount)
    if (currentCount + needed) > maxItems then
        needed = maxItems - currentCount
    end
    if needed <= 0 then return end

    SpawnInProgress[zoneId] = true
    SpawnBatchInProgress = true

    -- Асинхронный спавн с гарантией уникальности каждой точки
    Citizen.CreateThread(function()
        local batchPoints = {}
        local pool = {}
        for _, item in ipairs(zone.selected_items) do pool[#pool + 1] = item end
        for i = 1, needed do
            local selectedItem = LootMath.SelectWeightedItem(pool)
            if not selectedItem then break end
            if zone.custom_rules and zone.custom_rules.unique_items then
                for index, item in ipairs(pool) do
                    if item.item_name == selectedItem.item_name then table.remove(pool, index); break end
                end
            end
            if selectedItem then
                local pt = LootSpawner.GenerateValidSlotPoint(zone, batchPoints)
                if pt then
                    local finished = false
                    local createdSlot = nil

                    LootSpawner.CreateSlot(zone, selectedItem, pt, nil, function(slot)
                        createdSlot = slot
                        finished = true
                    end)

                    if not createdSlot then
                        print(string.format('[thehunt_loot] Spawn insert failed for zone %s; stopping current batch', zoneId))
                        break
                    end

                    table.insert(batchPoints, pt)

                    if needed > 1 then
                        Citizen.Wait(math.random(100, 300))
                    end
                end
            end
        end

        if LootSpawner.GetZoneSlotsCount(zoneId) == 0 then
            Zones.SetCooldown(zoneId, math.max(10, tonumber(zone.min_respawn_time) or 300))
        end
        SpawnInProgress[zoneId] = nil
        SpawnBatchInProgress = false
    end)
end

function LootSpawner.CreateSlot(zone, itemChoice, coords, customData, onComplete)
    slotIdCounter = slotIdCounter - 1
    local tempSlotId = slotIdCounter

    customData = type(customData) == "table" and customData or nil
    local itemName = itemChoice.item_name

    -- Получаем метаданные предмета и его максимальный стак из thehunt_items
    local itemDef = nil
    if Items and Items.Get then
        itemDef = Items.Get(itemName)
    elseif exports.thehunt_items and exports.thehunt_items.GetItemData then
        itemDef = exports.thehunt_items:GetItemData(itemName)
    end

    if not itemDef then if onComplete then onComplete(nil) end; return nil end
    local maxStack = math.max(1, tonumber(itemDef.maxStack) or 1)
    local minC = math.max(1, math.min(maxStack, tonumber(itemChoice.min_count) or 1))
    local maxC = math.max(minC, math.min(maxStack, tonumber(itemChoice.max_count) or minC))
    local rawCount = (maxC == minC) and minC or math.random(minC, maxC)
    -- Строго ограничиваем размер стака максимальным лимитом предмета
    local count = math.max(1, math.min(maxStack, rawCount))

    local modelName = (customData and customData.model)
                   or zone.model_name 
                   or (itemDef and (itemDef.dropModel or itemDef.propModel)) 
                   or Config.DefaultLootPropModel

    local modelHash = (customData and customData.model_hash) or zone.model_hash or joaat(modelName)
    local heading = (customData and customData.heading) or zone.heading or (math.random(0, 360) + 0.0)
    local lifetime = (customData and customData.lifetime) or zone.item_lifetime or Config.DefaultLifetime
    local expiresAt = (lifetime > 0) and (os.time() + lifetime) or nil

    local zoneId = tonumber(zone.id) or 0

    local zoneCenter = zone.coords or coords
    local slotData = {
        id = tempSlotId,
        zone_id = zoneId,
        zone_type = zone.zone_type or "circle",
        render_radius = zone.render_radius or Config.DefaultRenderRadius,
        zone_center_x = zoneCenter.x,
        zone_center_y = zoneCenter.y,
        zone_center_z = zoneCenter.z,
        item_name = itemName,
        label = (itemDef and itemDef.label) or itemName,
        count = count,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        model_name = modelName,
        model_hash = modelHash,
        metadata = itemChoice.metadata or {},
        spawned_at = os.time(),
        expires_at = expiresAt
    }

    if zoneId > 0 then
        -- Вставка в БД с авто-инкрементом
        local ok, insertedId = pcall(MySQL.insert.await, [[
            INSERT INTO thehunt_loot_active_slots (
                zone_id, item_name, count, x, y, z, heading,
                model_name, model_hash, metadata, expires_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(NULLIF(?, 0)))
        ]], {
            zoneId,
            itemName,
            count,
            coords.x,
            coords.y,
            coords.z,
            heading,
            modelName,
            modelHash,
            itemChoice.metadata and json.encode(itemChoice.metadata) or nil,
            expiresAt or 0
        })
            if not ok or not tonumber(insertedId) or tonumber(insertedId) <= 0 then
                if onComplete then onComplete(nil) end
                return
            end

            local finalId = tonumber(insertedId) or tempSlotId
            slotData.id = finalId

            ActiveSlots[finalId] = slotData
            if not SlotsByZone[zoneId] then SlotsByZone[zoneId] = {} end
            SlotsByZone[zoneId][finalId] = slotData

            TriggerClientEvent("thehunt_loot:onSlotCreated", -1, slotData)
            if onComplete then onComplete(slotData) end
        
    else
        ActiveSlots[tempSlotId] = slotData
        if not SlotsByZone[zoneId] then SlotsByZone[zoneId] = {} end
        SlotsByZone[zoneId][tempSlotId] = slotData

        TriggerClientEvent("thehunt_loot:onSlotCreated", -1, slotData)
        if onComplete then onComplete(slotData) end
    end

    return slotData
end

-- =================================================================
-- 4. ОЧИСТКА И УДАЛЕНИЕ СЛОТОВ
-- =================================================================

function LootSpawner.RemoveSlot(slotId, reason, persisted)
    local sId = tonumber(slotId)
    if not sId or not ActiveSlots[sId] then return false end
    if reason ~= "picked_up" and reason ~= "merged" and LootPickup and LootPickup.IsLocked(sId) then return false end

    local slot = ActiveSlots[sId]
    local zId = slot.zone_id

    if SlotMutations[sId] then return false end
    SlotMutations[sId] = true
    if sId > 0 and not persisted then
        local deleted = MySQL.update.await("DELETE FROM thehunt_loot_active_slots WHERE id = ? AND count = ?", {sId, slot.count})
        if tonumber(deleted) ~= 1 then SlotMutations[sId] = nil; return false end
    elseif sId > 0 then
        MySQL.update.await("DELETE FROM thehunt_loot_active_slots WHERE id = ? AND count = 0", {sId})
    end
    ActiveSlots[sId] = nil
    SlotMutations[sId] = nil
    if SlotsByZone[zId] then
        SlotsByZone[zId][sId] = nil
    end

    -- Удаляем из БД


    -- Оповещаем клиентов об удалении слота
    TriggerClientEvent("thehunt_loot:onSlotRemoved", -1, sId)

    -- Если слот был частью зоны и лут иссяк — запускаем кулдаун зоны
    if zId and zId > 0 and Zones then
        local remainingInZone = LootSpawner.GetZoneSlotsCount(zId)
        local zone = Zones.Get(zId)
        if zone and remainingInZone == 0 then
            local respawnSec = math.random(zone.min_respawn_time or Config.DefaultMinRespawn, zone.max_respawn_time or Config.DefaultMaxRespawn)
            Zones.SetCooldown(zId, respawnSec)
        end
    end

    return true
end

function LootSpawner.UpdateSlotCount(slotId, newCount, persisted)
    local sId = tonumber(slotId)
    local count = tonumber(newCount)
    if not sId or not count or count ~= count or count < 1 or count ~= math.floor(count) or not ActiveSlots[sId] then return false end

    if sId > 0 and not persisted then
        local changed = MySQL.update.await("UPDATE thehunt_loot_active_slots SET count = ? WHERE id = ? AND count = ?", {count, sId, ActiveSlots[sId].count})
        if tonumber(changed) ~= 1 then return false end
    end
    ActiveSlots[sId].count = count
    TriggerClientEvent("thehunt_loot:onSlotUpdated", -1, sId, count)
    return true
end

function LootSpawner.ClearZoneSlots(zoneId)
    local zId = tonumber(zoneId)
    if not zId or LootSpawner.IsZoneBusy(zId) then return false end
    if not SlotsByZone[zId] then return true end

    ClearingZones[zId] = true
    local deleted = MySQL.update.await("DELETE FROM thehunt_loot_active_slots WHERE zone_id = ?", { zId })
    if deleted == nil then ClearingZones[zId] = nil; return false end
    for sId, _ in pairs(SlotsByZone[zId]) do
        ActiveSlots[sId] = nil
        TriggerClientEvent("thehunt_loot:onSlotRemoved", -1, sId)
    end
    SlotsByZone[zId] = nil

    ClearingZones[zId] = nil
    return true
end

function LootSpawner.ForceRespawnZone(zoneId)
    local zId = tonumber(zoneId)
    if not zId or not Zones then return end

    local zone = Zones.Get(zId)
    if not zone or not zone.is_enabled or SpawnBatchInProgress or LootSpawner.IsZoneBusy(zId) then return false end

    if not LootSpawner.ClearZoneSlots(zId) then return false end
    Zones.SetCooldown(zId, 0)
    LootSpawner.SpawnLootForZone(zone)
    return true
end

function LootSpawner.CheckAndSpawnZone(zoneId)
    local zId = tonumber(zoneId)
    if not zId or not Zones then return end

    if not ready or Zones.IsOnCooldown(zId) or LootSpawner.GetZoneSlotsCount(zId) > 0 then return end

    local zone = Zones.Get(zId)
    if not zone or not (zone.is_enabled == true or zone.is_enabled == 1) then return end

    LootSpawner.SpawnLootForZone(zone)
end

function LootSpawner.CheckExpiredSlots()
    local now = os.time()
    local expiredSlots = {}

    for sId, slot in pairs(ActiveSlots) do
        if slot.expires_at and now >= slot.expires_at then
            table.insert(expiredSlots, sId)
        end
    end

    for _, sId in ipairs(expiredSlots) do
        LootSpawner.RemoveSlot(sId, "expired")
    end
end
