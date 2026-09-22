-- =================================================================
-- HUNT: Hard RP — The Corruption | Zones Manager & Proximity Tracker
-- =================================================================

Zones = {}

local CachedZones = {}      -- [zoneId] = zoneTable
local ActiveZones = {}      -- [zoneId] = true (когда в зоне есть игроки)
local MutatingZones = {}
function Zones.IsMutating(id) return MutatingZones[tonumber(id)] == true end
local RespawnArmed = {}
local ZoneCooldowns = {}    -- [zoneId] = timestamp (когда зона готова к новому спавну)

-- =================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И ПОЛУЧЕНИЕ ЗОН
-- =================================================================

function Zones.Init(callback)
    LootDB.LoadAllZones(function(loadedZones)
        CachedZones = loadedZones or {}
        ActiveZones = {}
        ZoneCooldowns = {}
        RespawnArmed = {}
        MySQL.query("SELECT zone_id, ready_at FROM thehunt_loot_cooldowns", {}, function(rows)
            for _, row in ipairs(rows or {}) do
                ZoneCooldowns[tonumber(row.zone_id)] = tonumber(row.ready_at) or 0
                RespawnArmed[tonumber(row.zone_id)] = false
            end
            print(string.format("[HUNT LOOT] Loaded %d zones and persisted cooldowns", Zones.GetCount()))
            if callback then callback() end
        end)
    end)
end

function Zones.GetAll()
    return CachedZones
end

function Zones.Get(zoneId)
    local zId = tonumber(zoneId)
    return (zId and CachedZones[zId]) or (zId and CachedZones[tostring(zId)]) or nil
end

function Zones.GetCount()
    local count = 0
    for _ in pairs(CachedZones) do count = count + 1 end
    return count
end

-- =================================================================
-- 2. CRUD ОПЕРАЦИИ С ЗОНАМИ
-- =================================================================

function Zones.Save(zoneData, adminSrc, callback)
    local valid, reason = LootValidation.Zone(zoneData)
    if not valid then
        if adminSrc and adminSrc > 0 then
            TriggerClientEvent("thehunt_status:notify", adminSrc, "Редактор зон", reason, "error")
        end
        if callback then callback(nil, nil) end
        return
    end
    zoneData = valid
    if zoneData.id > 0 and not Zones.Get(zoneData.id) then
        if callback then callback(nil, nil) end
        return
    end
    if zoneData.id > 0 and (Zones.IsMutating(zoneData.id) or LootSpawner.IsZoneBusy(zoneData.id)) then
        if callback then callback(nil, nil) end
        return
    end
    local adminIdentifier = adminSrc and GetPlayerIdentifier(adminSrc, 0) or "ADMIN"
    if zoneData and zoneData.coords then
        zoneData.coords = vector3(
            tonumber(zoneData.coords.x) or 0.0,
            tonumber(zoneData.coords.y) or 0.0,
            tonumber(zoneData.coords.z) or 0.0
        )
    end

    if zoneData.id > 0 then MutatingZones[zoneData.id] = true end
    LootDB.SaveZone(zoneData, adminIdentifier, function(savedId)
        MutatingZones[zoneData.id] = nil
        if savedId then
            zoneData.id = savedId
            CachedZones[savedId] = zoneData
            CachedZones[tostring(savedId)] = nil

            -- Оповещаем всех активных администраторов в редакторе
            TriggerClientEvent("thehunt_loot:syncZoneUpdated", -1, zoneData)

            -- Сразу генерируем лут для сохранённой зоны
            if LootSpawner and LootSpawner.CheckAndSpawnZone then
                if not zoneData.is_enabled then LootSpawner.ClearZoneSlots(savedId) end
            end

            if callback then callback(savedId, zoneData) end
        else
            if callback then callback(nil, nil) end
        end
    end)
end

function Zones.Delete(zoneId, adminSrc, callback)
    local zId = tonumber(zoneId)
    if not zId or zId <= 0 or Zones.IsMutating(zId) or LootSpawner.IsZoneBusy(zId) then
        if callback then callback(false) end
        return
    end

    local adminIdentifier = adminSrc and GetPlayerIdentifier(adminSrc, 0) or "ADMIN"
    MutatingZones[zId] = true
    LootDB.DeleteZone(zId, adminIdentifier, function(success)
        MutatingZones[zId] = nil
        if not success then if callback then callback(false) end; return end
        CachedZones[zId] = nil
        CachedZones[tostring(zId)] = nil
        ActiveZones[zId] = nil
        ActiveZones[tostring(zId)] = nil
        ZoneCooldowns[zId] = nil
        ZoneCooldowns[tostring(zId)] = nil

        -- Очищаем все заспавненные слоты этой зоны в мире
        if LootSpawner and LootSpawner.ClearZoneSlots then
            LootSpawner.ClearZoneSlots(zId)
        end

        TriggerClientEvent("thehunt_loot:syncZoneDeleted", -1, zId)
        if callback then callback(true) end
    end)
end

function Zones.Duplicate(zoneId, adminSrc, callback)
    local orig = Zones.Get(zoneId)
    if not orig then
        if callback then callback(nil, nil) end
        return
    end

    local copyData = json.decode(json.encode(orig))
    copyData.id = 0
    copyData.name = (orig.name or "Зона") .. " (Копия)"
    copyData.coords = vector3(orig.coords.x + 3.0, orig.coords.y + 3.0, orig.coords.z)
    for _, point in ipairs(copyData.points or {}) do
        point.x, point.y = point.x + 3.0, point.y + 3.0
    end

    Zones.Save(copyData, adminSrc, callback)
end

function Zones.Toggle(zoneId, enabled, adminSrc, callback)
    local zId = tonumber(zoneId)
    if not zId or not CachedZones[zId] then if callback then callback(false) end; return false end

    local copy = json.decode(json.encode(CachedZones[zId]))
    copy.is_enabled = enabled == true
    Zones.Save(copy, adminSrc, function(id)
        if callback then callback(id ~= nil) end
    end)
    return true
end

-- =================================================================
-- 3. УПРАВЛЕНИЕ КУЛДАУНАМИ РЕСПАВНА
-- =================================================================

function Zones.IsOnCooldown(zoneId)
    local zId = tonumber(zoneId)
    if not zId then return false end
    local readyAt = ZoneCooldowns[zId] or 0
    return os.time() < readyAt
end

function Zones.SetCooldown(zoneId, seconds)
    local zId = tonumber(zoneId)
    if not zId then return end
    local sec = tonumber(seconds) or 300
    local readyAt = os.time() + sec
    ZoneCooldowns[zId] = readyAt
    RespawnArmed[zId] = false

    MySQL.query([[
        INSERT INTO thehunt_loot_cooldowns (zone_id, ready_at, last_spawned_at)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE ready_at = VALUES(ready_at), last_spawned_at = VALUES(last_spawned_at)
    ]], { zId, readyAt, os.time() })
end

function Zones.GetCooldownRemaining(zoneId)
    local zId = tonumber(zoneId)
    if not zId or not ZoneCooldowns[zId] then return 0 end
    local rem = ZoneCooldowns[zId] - os.time()
    return rem > 0 and rem or 0
end

-- =================================================================
-- 4. СИМУЛЯЦИОННЫЙ ПОТОК ПРОВЕРКИ ДИСТАНЦИИ И СПАВНА
-- =================================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.ServerSimulationInterval or 3000)

        if LootSpawner and LootSpawner.IsReady() then LootSpawner.CheckExpiredSlots() end
        local players = GetPlayers()
        if #players > 0 and LootSpawner and LootSpawner.IsReady() then
            -- Собираем координаты всех игроков
            local playerCoords = {}
            for _, pId in ipairs(players) do
                local ped = GetPlayerPed(pId)
                if ped and ped ~= 0 then
                    local pPos = GetEntityCoords(ped)
                    if pPos and (math.abs(pPos.x) > 0.1 or math.abs(pPos.y) > 0.1) then
                        table.insert(playerCoords, {
                            src = tonumber(pId),
                            coords = pPos
                        })
                    end
                end
            end

            -- Проверяем каждую зону
            for zId, zone in pairs(CachedZones) do
                if zone and (zone.is_enabled == true or zone.is_enabled == 1) then
                    local isPlayerNear = false
                    local actRadius = tonumber(zone.activation_radius) or Config.DefaultActivationRadius
                    local zCoords = zone.coords

                    if zCoords then
                        local zv = vector3(
                            tonumber(zCoords.x) or 0.0,
                            tonumber(zCoords.y) or 0.0,
                            tonumber(zCoords.z) or 0.0
                        )

                        for _, p in ipairs(playerCoords) do
                            local dist = #(p.coords - zv)
                            if dist <= actRadius then
                                isPlayerNear = true
                                break
                            end
                        end
                    end

                    if isPlayerNear then
                        ActiveZones[zId] = true
                        local rules = zone.custom_rules or {}
                        if not rules.respawn_after_exit or RespawnArmed[zId] ~= false then
                            LootSpawner.CheckAndSpawnZone(zId)
                        end
                    else
                        ActiveZones[zId] = nil
                        RespawnArmed[zId] = true
                    end
                end
            end

            -- Проверяем таймеры жизни активных слотов (деспавн устаревших)

        elseif #players == 0 then
            ActiveZones = {}
            for id in pairs(CachedZones) do RespawnArmed[id] = true end
        end
    end
end)

function Zones.GetRuntimeState()
    local result = {}
    for id, zone in pairs(CachedZones) do
        result[id] = {
            count = LootSpawner.GetZoneSlotsCount(id),
            cooldown = Zones.GetCooldownRemaining(id),
            nearby = ActiveZones[id] == true,
            busy = LootSpawner.IsZoneBusy(id),
            waiting_exit = zone.custom_rules and zone.custom_rules.respawn_after_exit and RespawnArmed[id] == false or false
        }
    end
    return result
end
