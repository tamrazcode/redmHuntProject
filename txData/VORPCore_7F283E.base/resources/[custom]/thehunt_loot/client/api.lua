-- =================================================================
-- HUNT: Hard RP — The Corruption | Public Client API & Exports
-- =================================================================

--- Получить список активного лута рядом с персонажем
--- @param maxDist number
--- @return table
exports('GetNearbyLoot', function(maxDist)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return {} end

    local pCoords = GetEntityCoords(ped)
    local radius = maxDist or 3.0
    local nearby = {}
    local activeSlots = LootStreamer.GetActiveSlots()

    for sId, slot in pairs(activeSlots) do
        local dist = #(pCoords - vector3(slot.x, slot.y, slot.z))
        if dist <= radius then
            table.insert(nearby, {
                slotId = sId,
                name = slot.item_name,
                label = slot.label or slot.item_name,
                count = slot.count,
                x = slot.x,
                y = slot.y,
                z = slot.z,
                distance = math.floor(dist * 10) / 10,
                metadata = slot.metadata or {}
            })
        end
    end

    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return nearby
end)

--- Проверить, активен ли сейчас режим админского редактора лута
--- @return boolean
exports('IsEditorActive', function()
    return (Editor and Editor.IsActive and Editor.IsActive()) == true
end)
