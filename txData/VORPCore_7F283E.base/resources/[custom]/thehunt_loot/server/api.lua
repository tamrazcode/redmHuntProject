-- =================================================================
-- HUNT: Hard RP — The Corruption | Public Server API & Exports
-- =================================================================

--- Получить список всех зон рядом с координатами
--- @param coords vector3
--- @param maxDist number
--- @return table
exports('GetNearbyLootZones', function(coords, maxDist)
    if not coords then return {} end
    local radius = maxDist or 100.0
    local nearby = {}
    local allZones = Zones.GetAll()

    for zId, zone in pairs(allZones) do
        local dist = #(coords - zone.coords)
        if dist <= radius then
            table.insert(nearby, {
                id = zId,
                name = zone.name,
                zone_type = zone.zone_type,
                coords = zone.coords,
                radius = zone.radius,
                is_enabled = zone.is_enabled,
                active_slots = LootSpawner.GetZoneSlotsCount(zId),
                distance = math.floor(dist)
            })
        end
    end

    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return nearby
end)

--- Переключить активность зоны (Вкл / Выкл)
--- @param zoneId number
--- @param enabled boolean
--- @return boolean
exports('ToggleLootZone', function(zoneId, enabled)
    return Zones.Toggle(zoneId, enabled)
end)

--- Принудительно очистить и перегенерировать лут в зоне
--- @param zoneId number
exports('ForceRespawnZone', function(zoneId)
    LootSpawner.ForceRespawnZone(zoneId)
end)

--- Создать сюжетный или временный кастомный тайник/дроп
--- @param coords vector3 Координаты
--- @param itemsList table Список предметов { { item_name = 'apple', count = 2 }, ... }
--- @param options table Опции { model = 'p_chest01x', lifetime = 3600, heading = 90.0 }
--- @return table CreatedSlotData
exports('CreateCustomStash', function(coords, itemsList, options)
    if not coords or not itemsList or #itemsList == 0 then return nil end
    options = options or {}

    local selected = LootMath.SelectWeightedItem(itemsList)
    if not selected then return nil end

    local fakeZone = {
        id = 0,
        zone_type = "container",
        model_name = options.model or Config.DefaultContainerModel,
        item_lifetime = options.lifetime or 3600
    }

    return LootSpawner.CreateSlot(fakeZone, selected, coords, options)
end)

--- Удалить активный слот лута
--- @param slotId number
--- @return boolean
exports('RemoveLootSlot', function(slotId)
    return LootSpawner.RemoveSlot(slotId, "manual")
end)

--- Получить текущее состояние зоны
--- @param zoneId number
--- @return table
exports('GetZoneState', function(zoneId)
    local zone = Zones.Get(zoneId)
    if not zone then return nil end

    return {
        id = zone.id,
        name = zone.name,
        zone_type = zone.zone_type,
        coords = zone.coords,
        is_enabled = zone.is_enabled,
        active_slots_count = LootSpawner.GetZoneSlotsCount(zoneId),
        is_on_cooldown = Zones.IsOnCooldown(zoneId),
        cooldown_remaining = Zones.GetCooldownRemaining(zoneId),
        items_in_pool = #zone.selected_items
    }
end)

--- Получить все загруженные зоны
--- @return table
exports('GetAllZones', function()
    return Zones.GetAll()
end)
