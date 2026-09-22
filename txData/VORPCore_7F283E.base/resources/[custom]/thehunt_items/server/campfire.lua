-- =================================================================
-- HUNT: Hard RP — Campfire System | Server Controller & Lifecycle
-- =================================================================

local ActiveCampfires = {} -- [propId] = { id, type, expireTime, litStartTime, charcoalAvailable, charcoalCollected, x, y, z, rx, ry, rz, owner }

local function GetPlayerIdentifiersVORP(src)
    local steamId = "unknown"
    local charId = 1

    local char = exports.thehunt_core and exports.thehunt_core:GetCharacter(src)
    if char then
        steamId = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src) or "unknown"
        charId = tonumber(char.charIdentifier or char.charid) or 1
    end

    if steamId == "unknown" then
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if string.find(id, "steam:") or string.find(id, "license:") then
                steamId = id
                break
            end
        end
    end

    return steamId, charId
end

local function SafeDecode(str)
    if not str or str == "" then return {} end
    local ok, res = pcall(json.decode, str)
    return (ok and type(res) == "table") and res or {}
end

-- =================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ПОИСКА И СПИСАНИЯ ПРЕДМЕТОВ
-- (Проверяют основной инвентарь, карманы надетой одежды и лежащие контейнеры)
-- =================================================================

local function FindItemCountInFullInventory(steamId, charId, targetItemName)
    local rows = MySQL.query.await("SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    local totalCount = 0
    for _, r in ipairs(rows) do
        if r.item_name == targetItemName then
            totalCount = totalCount + (tonumber(r.count) or 1)
        end
        if r.metadata then
            local meta = SafeDecode(r.metadata)
            if meta.container_contents and type(meta.container_contents) == "table" then
                for _, entry in ipairs(meta.container_contents) do
                    if entry.item_name == targetItemName then
                        totalCount = totalCount + (tonumber(entry.count) or 1)
                    end
                end
            end
            if meta.clothing_contents and type(meta.clothing_contents) == "table" then
                for _, entry in ipairs(meta.clothing_contents) do
                    if entry.item_name == targetItemName then
                        totalCount = totalCount + (tonumber(entry.count) or 1)
                    end
                end
            end
        end
    end

    return totalCount, rows
end

local function ConsumeItemFromFullInventory(steamId, charId, targetItemName, countNeeded)
    local totalHave, rows = FindItemCountInFullInventory(steamId, charId, targetItemName)
    if totalHave < countNeeded then
        return false
    end

    local remainingNeeded = countNeeded

    -- Фаза 1: Списание из прямых записей thehunt_inventories (main, clothing:id, container:id)
    for _, r in ipairs(rows) do
        if remainingNeeded <= 0 then break end
        if r.item_name == targetItemName then
            local curCount = tonumber(r.count) or 1
            if curCount <= remainingNeeded then
                remainingNeeded = remainingNeeded - curCount
                MySQL.query.await("DELETE FROM thehunt_inventories WHERE id = ?", { r.id })
            else
                MySQL.query.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { remainingNeeded, r.id })
                remainingNeeded = 0
                break
            end
        end
    end

    -- Фаза 2: Списание из упакованного содержимого контейнеров/одежды (metadata.container_contents / clothing_contents)
    if remainingNeeded > 0 then
        for _, r in ipairs(rows) do
            if remainingNeeded <= 0 then break end
            if r.metadata then
                local meta = SafeDecode(r.metadata)
                local metaDirty = false

                if meta.container_contents and type(meta.container_contents) == "table" then
                    for i = #meta.container_contents, 1, -1 do
                        local entry = meta.container_contents[i]
                        if entry.item_name == targetItemName and remainingNeeded > 0 then
                            local eCount = tonumber(entry.count) or 1
                            if eCount <= remainingNeeded then
                                remainingNeeded = remainingNeeded - eCount
                                table.remove(meta.container_contents, i)
                                metaDirty = true
                            else
                                entry.count = eCount - remainingNeeded
                                remainingNeeded = 0
                                metaDirty = true
                                break
                            end
                        end
                    end
                end

                if remainingNeeded > 0 and meta.clothing_contents and type(meta.clothing_contents) == "table" then
                    for i = #meta.clothing_contents, 1, -1 do
                        local entry = meta.clothing_contents[i]
                        if entry.item_name == targetItemName and remainingNeeded > 0 then
                            local eCount = tonumber(entry.count) or 1
                            if eCount <= remainingNeeded then
                                remainingNeeded = remainingNeeded - eCount
                                table.remove(meta.clothing_contents, i)
                                metaDirty = true
                            else
                                entry.count = eCount - remainingNeeded
                                remainingNeeded = 0
                                metaDirty = true
                                break
                            end
                        end
                    end
                end

                if metaDirty then
                    MySQL.query.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), r.id })
                end
            end
        end
    end

    return true
end

-- Списание воды для тушения костра:
-- Приоритет: bottle_water (остается bottle_empty) -> waterskin_water (-1 use) -> flask_water (-1 use)
local function ConsumeWaterFromFullInventory(src, steamId, charId)
    local rows = MySQL.query.await("SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    -- 1. Бутылка с водой
    for _, r in ipairs(rows) do
        if r.item_name == "bottle_water" and (tonumber(r.count) or 1) > 0 then
            local curCount = tonumber(r.count) or 1
            if curCount <= 1 then
                MySQL.query.await("UPDATE thehunt_inventories SET item_name = 'bottle_empty', count = 1 WHERE id = ?", { r.id })
            else
                MySQL.query.await("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { r.id })
                if exports.thehunt_items and exports.thehunt_items.GiveItem then
                    exports.thehunt_items:GiveItem(src, "bottle_empty", 1)
                end
            end
            return true, "bottle_water"
        end
    end

    -- 2. Бурдюк с водой
    for _, r in ipairs(rows) do
        if r.item_name == "waterskin_water" then
            local meta = SafeDecode(r.metadata)
            local curUses = tonumber(meta.uses) or 2
            curUses = curUses - 1
            if curUses <= 0 then
                MySQL.query.await("UPDATE thehunt_inventories SET item_name = 'waterskin', metadata = NULL WHERE id = ?", { r.id })
            else
                meta.uses = curUses
                MySQL.query.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), r.id })
            end
            return true, "waterskin_water"
        end
    end

    -- 3. Фляга с жидкостью
    for _, r in ipairs(rows) do
        if r.item_name == "flask_water" then
            local meta = SafeDecode(r.metadata)
            local curUses = tonumber(meta.uses) or 3
            curUses = curUses - 1
            if curUses <= 0 then
                MySQL.query.await("UPDATE thehunt_inventories SET item_name = 'flask', metadata = NULL WHERE id = ?", { r.id })
            else
                meta.uses = curUses
                MySQL.query.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), r.id })
            end
            return true, "flask_water"
        end
    end

    return false, nil
end

-- =================================================================
-- ИНИЦИАЛИЗАЦИЯ И ФОНОВЫЙ ТАЙМЕР КОСТРОВ
-- =================================================================

Citizen.CreateThread(function()
    Citizen.Wait(2500)
    local rows = MySQL.query.await("SELECT id, model_name, model_hash, item_name, metadata, x, y, z, rot_x, rot_y, rot_z, owner_identifier FROM thehunt_placed_props WHERE item_name IN ('campfire_lit', 'campfire_smolder')") or {}
    local now = os.time()

    for _, r in ipairs(rows) do
        local pId = tonumber(r.id)
        local meta = SafeDecode(r.metadata)
        local expireTime = tonumber(meta.expireTime) or (now + 600)

        if now >= expireTime then
            -- Время вышло пока сервер был выключен — удаляем
            if exports.thehunt_builder and exports.thehunt_builder.DeletePlacedProp then
                exports.thehunt_builder:DeletePlacedProp(pId)
            end
        else
            ActiveCampfires[pId] = {
                id = pId,
                type = (r.item_name == "campfire_smolder") and "smolder" or "lit",
                expireTime = expireTime,
                litStartTime = tonumber(meta.litStartTime) or now,
                charcoalAvailable = (meta.charcoalAvailable == true),
                charcoalCollected = (meta.charcoalCollected == true),
                x = r.x, y = r.y, z = r.z,
                rx = r.rot_x, ry = r.rot_y, rz = r.rot_z,
                owner = r.owner_identifier
            }
        end
    end
    print(string.format("^2[HUNT CAMPFIRE] Загружено активных костров: %d^7", #rows))
end)

-- Оптимизированный фоновый поток проверки времени жизни костров (каждые 3 сек)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)
        local now = os.time()
        for propId, fire in pairs(ActiveCampfires) do
            if now >= fire.expireTime then
                ActiveCampfires[propId] = nil
                if exports.thehunt_builder and exports.thehunt_builder.DeletePlacedProp then
                    exports.thehunt_builder:DeletePlacedProp(propId)
                end
            end
        end
    end
end)

-- =================================================================
-- ОБРАБОТКА СЕТЕВЫХ СОБЫТИЙ ВЗАИМОДЕЙСТВИЯ
-- =================================================================

-- 1. Розжиг костра: проверка спичек и запуск анимации на клиенте
RegisterNetEvent("thehunt_items:serverLightCampfire", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(pId)
    if not propData then return end

    -- Проверка дистанции
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - vector3(propData.x, propData.y, propData.z)) > 4.0 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы слишком далеко!", "error")
        return
    end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local matchCount = FindItemCountInFullInventory(steamId, charId, "matches")

    if matchCount < 1 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "У вас нет спичек, чтобы разжечь костёр!", "error")
        return
    end

    -- Списываем ровно 1 спичку
    local consumed = ConsumeItemFromFullInventory(steamId, charId, "matches", 1)
    if not consumed then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "У вас нет спичек, чтобы разжечь костёр!", "error")
        return
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    TriggerClientEvent("thehunt_items:clientStartIgniteSequence", src, pId)
end)

-- Завершение анимации розжига: удаление unlit костра и моментальный спавн p_campfirefresh01x
RegisterNetEvent("thehunt_items:serverFinishLightCampfire", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(pId)
    if not propData then return end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - vector3(propData.x, propData.y, propData.z)) > 4.5 then
        return
    end

    local now = os.time()
    local expireTime = now + 600 -- 10 минут горения

    local litPropData = {
        model_name = "p_campfirefresh01x",
        model_hash = GetHashKey("p_campfirefresh01x"),
        item_name = "campfire_lit",
        metadata = {
            litStartTime = now,
            expireTime = expireTime
        },
        x = propData.x,
        y = propData.y,
        z = propData.z,
        rot_x = propData.rot_x,
        rot_y = propData.rot_y,
        rot_z = propData.rot_z,
        owner = propData.owner,
        is_protected = 0,
        is_admin_prop = 0
    }

    -- 1. Удаляем незажженный костер
    if exports.thehunt_builder and exports.thehunt_builder.DeletePlacedProp then
        exports.thehunt_builder:DeletePlacedProp(pId)
    end

    -- 2. Спавним на том же месте горящий костер
    if exports.thehunt_builder and exports.thehunt_builder.CreatePlacedProp then
        exports.thehunt_builder:CreatePlacedProp(litPropData, function(newId, created)
            if newId then
                ActiveCampfires[newId] = {
                    id = newId,
                    type = "lit",
                    expireTime = expireTime,
                    litStartTime = now,
                    charcoalAvailable = false,
                    charcoalCollected = false,
                    x = propData.x, y = propData.y, z = propData.z,
                    rx = propData.rot_x, ry = propData.rot_y, rz = propData.rot_z,
                    owner = propData.owner
                }
                TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы разожгли костёр", "success")
            end
        end)
    end
end)

-- 2. Подкинуть древесину (+10 минут горения, тратит 1 wood_log)
RegisterNetEvent("thehunt_items:serverAddFuelWood", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local fire = ActiveCampfires[pId]
    if not fire or fire.type ~= "lit" then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Костёр не горит", "warning")
        return
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - vector3(fire.x, fire.y, fire.z)) > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы слишком далеко!", "error")
        return
    end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local woodCount = FindItemCountInFullInventory(steamId, charId, "wood_log")

    if woodCount < 1 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "У вас нет древесины!", "error")
        return
    end

    local consumed = ConsumeItemFromFullInventory(steamId, charId, "wood_log", 1)
    if not consumed then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "У вас нет древесины!", "error")
        return
    end

    fire.expireTime = fire.expireTime + 600 -- +10 минут
    if exports.thehunt_builder and exports.thehunt_builder.UpdatePlacedPropMetadata then
        exports.thehunt_builder:UpdatePlacedPropMetadata(pId, {
            litStartTime = fire.litStartTime,
            expireTime = fire.expireTime
        })
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    TriggerClientEvent("thehunt_items:clientPlayFuelAnim", src)
    TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы подкинули древесину в костёр", "success")
end)

-- 3. Подкинуть ветки (+5 минут горения, тратит 4 twigs)
RegisterNetEvent("thehunt_items:serverAddFuelTwigs", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local fire = ActiveCampfires[pId]
    if not fire or fire.type ~= "lit" then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Костёр не горит", "warning")
        return
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - vector3(fire.x, fire.y, fire.z)) > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы слишком далеко!", "error")
        return
    end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local twigsCount = FindItemCountInFullInventory(steamId, charId, "twigs")

    if twigsCount < 4 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Необходимо 4 ветки!", "error")
        return
    end

    local consumed = ConsumeItemFromFullInventory(steamId, charId, "twigs", 4)
    if not consumed then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Необходимо 4 ветки!", "error")
        return
    end

    fire.expireTime = fire.expireTime + 300 -- +5 минут
    if exports.thehunt_builder and exports.thehunt_builder.UpdatePlacedPropMetadata then
        exports.thehunt_builder:UpdatePlacedPropMetadata(pId, {
            litStartTime = fire.litStartTime,
            expireTime = fire.expireTime
        })
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    TriggerClientEvent("thehunt_items:clientPlayFuelAnim", src)
    TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы подкинули ветки в костёр", "success")
end)

-- 4. Запрос информации об оставшемся времени горения костра
RegisterNetEvent("thehunt_items:serverRequestCampfireInfo", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local fire = ActiveCampfires[pId]
    if not fire or fire.type ~= "lit" then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Костёр не горит", "warning")
        return
    end

    local now = os.time()
    local remainingSeconds = math.max(0, fire.expireTime - now)

    TriggerClientEvent("thehunt_items:clientShowCampfireInfo", src, pId, remainingSeconds, { x = fire.x, y = fire.y, z = fire.z })
end)

-- 5. Потушить костёр: требует бутылку с водой / бурдюк / флягу
RegisterNetEvent("thehunt_items:serverExtinguishCampfire", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local fire = ActiveCampfires[pId]
    if not fire or fire.type ~= "lit" then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Костёр не горит", "warning")
        return
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - vector3(fire.x, fire.y, fire.z)) > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы слишком далеко!", "error")
        return
    end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local waterConsumed, waterType = ConsumeWaterFromFullInventory(src, steamId, charId)

    if not waterConsumed then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "У вас нет воды, чтобы потушить костёр!", "error")
        return
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    TriggerClientEvent("thehunt_items:clientPlayExtinguishAnim", src)

    local now = os.time()
    local burnedSeconds = now - (fire.litStartTime or now)
    local charcoalAvailable = (burnedSeconds >= 300) -- Горел больше 5 минут
    local smolderExpireTime = now + 300              -- 5 минут жизни потухшего костра

    local smolderPropData = {
        model_name = "p_campfire_win2_smolder01x",
        model_hash = GetHashKey("p_campfire_win2_smolder01x"),
        item_name = "campfire_smolder",
        metadata = {
            expireTime = smolderExpireTime,
            charcoalAvailable = charcoalAvailable,
            charcoalCollected = false,
            burnedDuration = burnedSeconds
        },
        x = fire.x,
        y = fire.y,
        z = fire.z,
        rot_x = fire.rx,
        rot_y = fire.ry,
        rot_z = fire.rz,
        owner = fire.owner or "ADMIN",
        is_protected = 0,
        is_admin_prop = 0
    }

    -- 1. Удаляем горящий костер
    ActiveCampfires[pId] = nil
    if exports.thehunt_builder and exports.thehunt_builder.DeletePlacedProp then
        exports.thehunt_builder:DeletePlacedProp(pId)
    end

    -- 2. Спавним потухший тлеющий костер
    if exports.thehunt_builder and exports.thehunt_builder.CreatePlacedProp then
        exports.thehunt_builder:CreatePlacedProp(smolderPropData, function(newId, created)
            if newId then
                ActiveCampfires[newId] = {
                    id = newId,
                    type = "smolder",
                    expireTime = smolderExpireTime,
                    charcoalAvailable = charcoalAvailable,
                    charcoalCollected = false,
                    x = fire.x, y = fire.y, z = fire.z,
                    rx = fire.rx, ry = fire.ry, rz = fire.rz,
                    owner = fire.owner
                }
                TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы потушили костёр", "info")
            end
        end)
    end
end)

-- 6. Собрать древесный уголь
RegisterNetEvent("thehunt_items:serverGatherCharcoal", function(propId)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local fire = ActiveCampfires[pId]
    if not fire or fire.type ~= "smolder" then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Здесь нельзя собрать уголь", "warning")
        return
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - vector3(fire.x, fire.y, fire.z)) > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы слишком далеко!", "error")
        return
    end

    if fire.charcoalCollected then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Древесный уголь уже собран!", "warning")
        return
    end

    if not fire.charcoalAvailable then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Древесина плохо прогорела, собрать уголь не получилось", "error")
        return
    end

    -- Успешный сбор 2 шт. древесного угля
    fire.charcoalCollected = true
    if exports.thehunt_items and exports.thehunt_items.GiveItem then
        exports.thehunt_items:GiveItem(src, "charcoal", 2, nil, function(success)
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end)
    end

    -- Удаляем остатки костра из мира
    ActiveCampfires[pId] = nil
    if exports.thehunt_builder and exports.thehunt_builder.DeletePlacedProp then
        exports.thehunt_builder:DeletePlacedProp(pId)
    end

    TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Вы собрали древесный уголь (2 шт.)", "success")
end)
