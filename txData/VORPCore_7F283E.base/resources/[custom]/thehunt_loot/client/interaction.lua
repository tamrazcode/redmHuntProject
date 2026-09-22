-- =================================================================
-- HUNT: Hard RP — The Corruption | Client Loot 3D World Labeling
-- =================================================================

LootInteraction = {}

-- Отрисовка аккуратного 3D-текста над предметом (1-в-1 как в thehunt_items)
local function Draw3DText(x, y, z, text)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    local textStr = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextScale(0.24, 0.24)
    SetTextFontForCurrentCommand(1)
    SetTextColor(245, 248, 250, 230)
    SetTextCentre(1)
    SetTextDropshadow(2, 0, 0, 0, 180)
    DisplayText(textStr, screenX, screenY)
end

-- =================================================================
-- 1. ВЫСОКОЧАСТОТНЫЙ ПОТОК ОТРИСОВКИ 3D-НАЗВАНИЙ ПРЕДМЕТОВ В МИРЕ
-- =================================================================

Citizen.CreateThread(function()
    local TEXT_DISTANCE = 2.0

    while true do
        local ped = PlayerPedId()
        local hasNearbyItems = false

        if DoesEntityExist(ped) and not (Editor and Editor.IsActive and Editor.IsActive()) then
            local pCoords = GetEntityCoords(ped)
            local activeSlots = LootStreamer.GetActiveSlots()
            local spawnedEntities = LootStreamer.GetSpawnedEntities()

            for sId, slot in pairs(activeSlots) do
                local posX, posY, posZ = slot.x, slot.y, slot.z
                local ent = spawnedEntities[sId]
                if ent and DoesEntityExist(ent) then
                    local ec = GetEntityCoords(ent)
                    posX, posY, posZ = ec.x, ec.y, ec.z
                end

                local dist = #(pCoords - vector3(posX, posY, posZ))
                if dist < TEXT_DISTANCE then
                    hasNearbyItems = true

                    local itemDef = nil
                    if Items and Items.Get then
                        itemDef = Items.Get(slot.item_name)
                    elseif exports.thehunt_items and exports.thehunt_items.GetItemData then
                        itemDef = exports.thehunt_items:GetItemData(slot.item_name)
                    end

                    local label = (type(slot.metadata) == "table" and slot.metadata.label) or (itemDef and itemDef.label) or slot.label or slot.item_name
                    Draw3DText(posX, posY, posZ + 0.25, label)
                end
            end
        end

        Citizen.Wait(hasNearbyItems and 0 or 200)
    end
end)
