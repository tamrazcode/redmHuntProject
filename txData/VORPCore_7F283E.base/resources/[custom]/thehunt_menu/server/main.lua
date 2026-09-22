-- =================================================================
-- HUNT: Hard RP — Player Settings Menu | Server Module
-- =================================================================

-- Перезагрузка персонажа из сохранённых данных в базе
RegisterNetEvent("thehunt_menu:reloadCharacter", function()
    local src = source
    local char = exports.thehunt_core:GetCharacter(src)
    if not char then return end

    -- Always read the authoritative appearance snapshot from the database;
    -- VORP's in-memory object can still contain the previous outfit after an
    -- inventory equip/unequip operation.
    local charId = char.charIdentifier
    if charId then
        exports.oxmysql:execute('SELECT skinPlayer, compPlayer, compTints, walk FROM characters WHERE charidentifier = @charidentifier LIMIT 1', { charidentifier = charId }, function(result)
            local savedRow = result and result[1]
            local skin, comps, compTints
            if savedRow and savedRow.skinPlayer then
                skin = type(savedRow.skinPlayer) == "table" and savedRow.skinPlayer or json.decode(savedRow.skinPlayer)
            end
            if savedRow and savedRow.compPlayer then
                comps = type(savedRow.compPlayer) == "table" and savedRow.compPlayer or json.decode(savedRow.compPlayer)
            end
            if savedRow and savedRow.compTints then
                compTints = type(savedRow.compTints) == "table" and savedRow.compTints or json.decode(savedRow.compTints)
            end
            local walkStyle = (savedRow and savedRow.walk) or char.walk or "MP_Style_Casual"
            TriggerClientEvent("thehunt_menu:applyCharacterReload", src, skin, comps, compTints, walkStyle)
        end)
    else
        TriggerClientEvent("thehunt_menu:applyCharacterReload", src, nil, nil, nil, char.walk or "MP_Style_Casual")
    end
end)

-- Сохранение выбранного стиля походки в базу данных
local ALLOWED_WALK_STYLES = {
    MP_Style_Casual = true,
    MP_Style_Crazy = true,
    MP_Style_drunk = true,
    MP_Style_EasyRider = true,
    MP_Style_Flamboyant = true,
    MP_Style_Greenhorn = true,
    MP_Style_Gunslinger = true,
    MP_Style_inquisitive = true,
    MP_Style_Refined = true,
    MP_Style_SilentType = true,
    MP_Style_Veteran = true,
    noanim = true
}

RegisterNetEvent("thehunt_menu:saveWalkStyle", function(walkStyle)
    local src = source
    local char = exports.thehunt_core:GetCharacter(src)
    if not char then return end
    local charId = char.charIdentifier
    if not charId then return end

    if type(walkStyle) ~= "string" or not ALLOWED_WALK_STYLES[walkStyle] then return end
    local walk = walkStyle
    exports.oxmysql:execute("UPDATE characters SET walk = @walk WHERE charidentifier = @charidentifier", {
        walk = walk,
        charidentifier = charId
    })
    char.walk = walk
end)

-- Запрос исходного стиля походки при старте/выборе персонажа
RegisterNetEvent("thehunt_menu:requestInitialWalkStyle", function()
    local src = source
    local char = exports.thehunt_core:GetCharacter(src)
    if not char then return end
    local charId = char.charIdentifier
    if not charId then return end

    exports.oxmysql:execute("SELECT walk FROM characters WHERE charidentifier = @charidentifier LIMIT 1", {
        charidentifier = charId
    }, function(result)
        local walk = (result and result[1] and result[1].walk) or (char.walk) or "MP_Style_Casual"
        TriggerClientEvent("thehunt_menu:setWalkStyle", src, walk)
    end)
end)

-- Синхронизация позиции персонажа для всех игроков
local activeCharacterPositions = {}

RegisterNetEvent("thehunt_menu:syncCharacterPosition", function(coords, heading)
    local src = source
    if not coords then return end
    activeCharacterPositions[src] = { coords = coords, heading = heading }
    TriggerClientEvent("thehunt_menu:onCharacterPositionSynced", -1, src, coords, heading)
end)

RegisterNetEvent("thehunt_menu:releaseCharacterPosition", function()
    local src = source
    if activeCharacterPositions[src] then
        activeCharacterPositions[src] = nil
    end
    TriggerClientEvent("thehunt_menu:onCharacterPositionReleased", -1, src)
end)

AddEventHandler("playerDropped", function()
    local src = source
    if activeCharacterPositions[src] then
        activeCharacterPositions[src] = nil
        TriggerClientEvent("thehunt_menu:onCharacterPositionReleased", -1, src)
    end
end)

RegisterNetEvent("thehunt_menu:requestActiveCharacterPositions", function()
    local src = source
    for targetSrc, data in pairs(activeCharacterPositions) do
        if targetSrc ~= src then
            TriggerClientEvent("thehunt_menu:onCharacterPositionSynced", src, targetSrc, data.coords, data.heading)
        end
    end
end)
