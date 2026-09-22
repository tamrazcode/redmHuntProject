-- =================================================================
-- HUNT: Hard RP — Doors & Housing | Server Module
-- =================================================================

local Houses = {}
local Doors = {}

-- Compatibility view for legacy door code. Its data comes exclusively from
-- the HUNT facade, never from a direct VORP import.
local HuntSession = {
    getUser = function(src)
        local character = exports.thehunt_core:GetCharacter(src)
        if not character then return nil end
        return {
            identifier = exports.thehunt_core:GetPlayerIdentifier(src),
            getUsedCharacter = character
        }
    end
}

Citizen.CreateThread(function()
    Wait(1000)
    LoadAllFromDb()
end)

local function IsPlayerAdmin(src)
    if exports["thehunt_core"] and exports["thehunt_core"].IsPlayerAdmin then
        return exports["thehunt_core"]:IsPlayerAdmin(src)
    end
    return IsPlayerAceAllowed(src, "command")
end

function LoadAllFromDb()
    MySQL.query("SELECT * FROM thehunt_houses", {}, function(houseResults)
        Houses = {}
        if houseResults then
            for _, h in ipairs(houseResults) do
                local hId = tonumber(h.id)
                Houses[hId] = {
                    id = hId,
                    name = h.name,
                    owner_identifier = h.owner_identifier,
                    owner_charid = h.owner_charid and tonumber(h.owner_charid) or nil,
                    owner_name = h.owner_name,
                    is_locked = (h.is_locked == 1)
                }
            end
        end

        MySQL.query("SELECT * FROM thehunt_doors", {}, function(doorResults)
            Doors = {}
            if doorResults then
                for _, d in ipairs(doorResults) do
                    local dId = tonumber(d.id)
                    Doors[dId] = {
                        id = dId,
                        house_id = d.house_id and tonumber(d.house_id) or nil,
                        door_hash = d.door_hash,
                        model_hash = tonumber(d.model_hash),
                        x = tonumber(d.x),
                        y = tonumber(d.y),
                        z = tonumber(d.z),
                        heading = tonumber(d.heading) or 0.0,
                        state = tonumber(d.state) or 0
                    }
                end
            end

            TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
            print(("^2[HUNT DOORS] Загружено %d домов и %d дверей из базы данных.^7"):format(#houseResults or 0, #doorResults or 0))
        end)
    end)
end

-- Синхронизация при заходе игрока
RegisterNetEvent("thehunt_doors:requestSync", function()
    local src = source
    local charId = nil
    if HuntSession then
        local user = HuntSession.getUser(src)
        if user then
            local char = user.getUsedCharacter
            if char then
                charId = char.charIdentifier or char.charid
            end
        end
    end
    TriggerClientEvent("thehunt_doors:syncAllData", src, Houses, Doors, charId)
end)

-- Безопасное декодирование метаданных
local function SafeDecodeMeta(meta)
    if not meta then return {} end
    if type(meta) == "table" then return meta end
    if type(meta) == "string" then
        if meta == "" or meta == "null" or meta == "{}" then return {} end
        local success, decoded = pcall(json.decode, meta)
        if success and decoded then
            if type(decoded) == "string" then
                local s2, d2 = pcall(json.decode, decoded)
                if s2 and d2 and type(d2) == "table" then
                    return d2
                end
            elseif type(decoded) == "table" then
                return decoded
            end
        end
    end
    return {}
end

-- Проверка, переносится ли контейнер персонажем (не является ли сундуком/пропом в мире)
local function IsCarriedContainer(container, itemsByDbId, visited)
    if not container or container == "main" or container == "equipment" then
        return true
    end
    if string.sub(container, 1, 5) == "prop:" or container == "ground" then
        return false
    end
    visited = visited or {}
    local prefix, parentIdStr = string.match(container, "^([^:]+):(.+)$")
    if prefix and parentIdStr then
        local parentId = tonumber(parentIdStr)
        if parentId and not visited[parentId] then
            visited[parentId] = true
            local parent = itemsByDbId and itemsByDbId[parentId]
            if parent then
                return IsCarriedContainer(parent.container, itemsByDbId, visited)
            end
        end
    end
    return false
end

-- Поиск и подсчет всех предметов во всех слотах персонажа (main, карманы одежды clothing:<id>, контейнеры container:<id>, а также упакованное содержимое)
local function GetCarriedItemSources(allRows, itemsByDbId, targetItemName)
    local totalCount = 0
    local directRows = {}
    local packedEntries = {}

    for _, r in ipairs(allRows) do
        if IsCarriedContainer(r.container, itemsByDbId) then
            if r.item_name == targetItemName then
                local c = tonumber(r.count) or 1
                totalCount = totalCount + c
                table.insert(directRows, r)
            end

            if r.metadata then
                local meta = SafeDecodeMeta(r.metadata)
                if meta.clothing_contents and type(meta.clothing_contents) == "table" then
                    for idx, entry in ipairs(meta.clothing_contents) do
                        if entry.item_name == targetItemName then
                            local c = tonumber(entry.count) or 1
                            totalCount = totalCount + c
                            table.insert(packedEntries, {
                                row = r,
                                meta = meta,
                                field = "clothing_contents",
                                index = idx,
                                entry = entry
                            })
                        end
                    end
                end
                if meta.container_contents and type(meta.container_contents) == "table" then
                    for idx, entry in ipairs(meta.container_contents) do
                        if entry.item_name == targetItemName then
                            local c = tonumber(entry.count) or 1
                            totalCount = totalCount + c
                            table.insert(packedEntries, {
                                row = r,
                                meta = meta,
                                field = "container_contents",
                                index = idx,
                                entry = entry
                            })
                        end
                    end
                end
            end
        end
    end

    -- Приоритет списания прямых предметов: main -> clothing: -> container: -> прочие
    table.sort(directRows, function(a, b)
        local function prio(c)
            if not c or c == "main" then return 1 end
            if type(c) == "string" and string.sub(c, 1, 9) == "clothing:" then return 2 end
            if type(c) == "string" and string.sub(c, 1, 10) == "container:" then return 3 end
            return 4
        end
        local pa = prio(a.container)
        local pb = prio(b.container)
        if pa ~= pb then return pa < pb end
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)

    return totalCount, directRows, packedEntries
end

-- Списание необходимого количества ресурсов из найденных переносимых слотов
local function DeductCarriedItem(directRows, packedEntries, amountNeeded)
    local needed = amountNeeded

    -- Фаза 1: Списание из прямых записей thehunt_inventories (main, clothing:id, container:id)
    for _, r in ipairs(directRows) do
        if needed <= 0 then break end
        local rCount = tonumber(r.count) or 1
        if rCount <= needed then
            needed = needed - rCount
            MySQL.query.await("DELETE FROM thehunt_inventories WHERE id = ?", { r.id })
        else
            MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { needed, r.id })
            needed = 0
            break
        end
    end

    -- Фаза 2: Списание из упакованного содержимого метаданных
    if needed > 0 and packedEntries and #packedEntries > 0 then
        local rowsToUpdate = {}
        for _, p in ipairs(packedEntries) do
            if needed <= 0 then break end
            local eCount = tonumber(p.entry.count) or 1
            if eCount <= needed then
                needed = needed - eCount
                p.entry._remove = true
                rowsToUpdate[p.row.id] = { row = p.row, meta = p.meta }
            else
                p.entry.count = eCount - needed
                needed = 0
                rowsToUpdate[p.row.id] = { row = p.row, meta = p.meta }
                break
            end
        end

        for rowId, data in pairs(rowsToUpdate) do
            local meta = data.meta
            if meta.clothing_contents and type(meta.clothing_contents) == "table" then
                for i = #meta.clothing_contents, 1, -1 do
                    if meta.clothing_contents[i]._remove then
                        table.remove(meta.clothing_contents, i)
                    end
                end
            end
            if meta.container_contents and type(meta.container_contents) == "table" then
                for i = #meta.container_contents, 1, -1 do
                    if meta.container_contents[i]._remove then
                        table.remove(meta.container_contents, i)
                    end
                end
            end
            MySQL.update.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", {
                json.encode(meta), rowId
            })
        end
    end

    return needed <= 0
end

-- Проверка свободного места для ключа (1x1) в инвентаре, карманах или контейнерах
local function HasSpaceForHouseKey(allRows, itemsByDbId)
    -- 1. Основной инвентарь (main)
    local mainItems = {}
    for _, r in ipairs(allRows) do
        if not r.container or r.container == "main" then
            table.insert(mainItems, r)
        end
    end
    if exports["thehunt_items"] and exports["thehunt_items"].CanFitItem then
        local canFit = exports["thehunt_items"]:CanFitItem(mainItems, "house_key", 1)
        if canFit then return true end
    else
        return true
    end

    -- 2. Карманы надетой одежды (clothing:<id>)
    for _, r in ipairs(allRows) do
        if r.container == "equipment" then
            local def = exports["thehunt_items"] and exports["thehunt_items"].GetItemData and exports["thehunt_items"]:GetItemData(r.item_name)
            if def and def.clothing and def.storage then
                local cName = "clothing:" .. tostring(r.id)
                local pItems = {}
                for _, child in ipairs(allRows) do
                    if child.container == cName then
                        table.insert(pItems, child)
                    end
                end
                local maxCap = 0
                if def.storage.pockets then
                    for _, p in ipairs(def.storage.pockets) do
                        maxCap = maxCap + ((p.w or 1) * (p.h or 1))
                    end
                elseif def.storage.cols and def.storage.rows then
                    maxCap = (tonumber(def.storage.cols) or 1) * (tonumber(def.storage.rows) or 1)
                end
                if #pItems < maxCap then
                    return true
                end
            end
        end
    end

    -- 3. Переносимые контейнеры (связка ключей container:<id> и др.)
    for _, r in ipairs(allRows) do
        if IsCarriedContainer(r.container, itemsByDbId) then
            local def = exports["thehunt_items"] and exports["thehunt_items"].GetItemData and exports["thehunt_items"]:GetItemData(r.item_name)
            if def and def.containerStorage then
                local cName = "container:" .. tostring(r.id)
                local cItems = {}
                for _, child in ipairs(allRows) do
                    if child.container == cName then
                        table.insert(cItems, child)
                    end
                end
                local maxCap = (tonumber(def.containerStorage.cols) or 2) * (tonumber(def.containerStorage.rows) or 2)
                if #cItems < maxCap then
                    return true
                end
            end
        end
    end

    return false
end

-- Вспомогательная функция проверки наличия ключа от конкретного дома во всех переносимых слотах игрока
local function HasHouseKey(steamId, charId, houseId, cb)
    local targetHouseId = tonumber(houseId)
    if not targetHouseId then
        cb(false)
        return
    end

    MySQL.query("SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }, function(allRows)
        allRows = allRows or {}
        local itemsByDbId = {}
        for _, r in ipairs(allRows) do
            itemsByDbId[tonumber(r.id)] = r
        end

        for _, r in ipairs(allRows) do
            if IsCarriedContainer(r.container, itemsByDbId) then
                if r.item_name == 'house_key' then
                    local meta = SafeDecodeMeta(r.metadata)
                    local keyHId = tonumber(meta.house_id) or tonumber(meta.houseId)
                    if keyHId and keyHId == targetHouseId then
                        cb(true)
                        return
                    end
                end

                if r.metadata then
                    local meta = SafeDecodeMeta(r.metadata)
                    if meta.clothing_contents and type(meta.clothing_contents) == "table" then
                        for _, entry in ipairs(meta.clothing_contents) do
                            if entry.item_name == 'house_key' then
                                local entryMeta = SafeDecodeMeta(entry.metadata)
                                local keyHId = tonumber(entryMeta.house_id) or tonumber(entryMeta.houseId)
                                if keyHId and keyHId == targetHouseId then
                                    cb(true)
                                    return
                                end
                            end
                        end
                    end
                    if meta.container_contents and type(meta.container_contents) == "table" then
                        for _, entry in ipairs(meta.container_contents) do
                            if entry.item_name == 'house_key' then
                                local entryMeta = SafeDecodeMeta(entry.metadata)
                                local keyHId = tonumber(entryMeta.house_id) or tonumber(entryMeta.houseId)
                                if keyHId and keyHId == targetHouseId then
                                    cb(true)
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end

        cb(false)
    end)
end

-- Заселение игрока в дом (Требуется 3 железных слитка для ковки ключа)
RegisterNetEvent("thehunt_doors:claimHouse", function(rawHouseId)
    local src = source
    if not HuntSession then return end

    local user = HuntSession.getUser(src)
    if not user then return end
    local char = user.getUsedCharacter
    if not char then return end

    local houseId = tonumber(rawHouseId)
    if not houseId then return end

    local house = Houses[houseId]
    if not house then return end

    if house.owner_charid ~= nil and house.owner_charid ~= 0 and house.owner_charid ~= "" then
        TriggerClientEvent("thehunt_status:notify", src, "Дом", "Этот дом уже занят другим жильцом", "warning")
        return
    end

    local charId = char.charIdentifier or char.charid or 1
    local steamId = char.identifier or user.identifier or "unknown"
    local fullName = ("%s %s"):format(char.firstname or "Житель", char.lastname or "")

    Citizen.CreateThread(function()
        -- Проверяем наличие 3 железных слитков во всех слотах переносимого инвентаря (main, одежда, контейнеры)
        local allInvRows = MySQL.query.await("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
            steamId, charId
        }) or {}

        local itemsByDbId = {}
        for _, r in ipairs(allInvRows) do
            itemsByDbId[tonumber(r.id)] = r
        end

        local totalIngots, directRows, packedEntries = GetCarriedItemSources(allInvRows, itemsByDbId, "iron_ingot")

        if totalIngots < 3 then
            TriggerClientEvent("thehunt_status:notify", src, "Регистрация дома", ("Для заселения требуется 3 железных слитка (у вас %s шт.)"):format(totalIngots), "error")
            return
        end

        -- Проверяем, освободит ли списание слитков хотя бы один слот для ключа
        local willVacate = false
        local testNeeded = 3
        for _, r in ipairs(directRows) do
            local rCount = tonumber(r.count) or 1
            if rCount <= testNeeded then
                willVacate = true
                break
            else
                testNeeded = 0
                break
            end
        end

        if not willVacate and not HasSpaceForHouseKey(allInvRows, itemsByDbId) then
            TriggerClientEvent("thehunt_status:notify", src, "Регистрация дома", "Инвентарь полон! Освободите место для ключа", "error")
            return
        end

        -- Списываем 3 железных слитка со всех слотов
        local successDeduct = DeductCarriedItem(directRows, packedEntries, 3)
        if not successDeduct then
            TriggerClientEvent("thehunt_status:notify", src, "Регистрация дома", "Ошибка списания материалов", "error")
            return
        end

        -- Выдаем ключ от дома игроку
        local keyMeta = {
            house_id = houseId,
            label = "Ключ от двери"
        }

        if exports["thehunt_items"] and exports["thehunt_items"].GiveItem then
            exports["thehunt_items"]:GiveItem(src, "house_key", 1, keyMeta)
        else
            MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', 0, 0, 0, 'house_key', 1, ?)", {
                steamId, charId, json.encode(keyMeta)
            })
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end

        -- Регистрируем владение домом в базе
        MySQL.update.await("UPDATE thehunt_houses SET owner_identifier = ?, owner_charid = ?, owner_name = ?, is_locked = 0 WHERE id = ?", {
            steamId,
            charId,
            fullName,
            houseId
        })

        house.owner_identifier = steamId
        house.owner_charid = tonumber(charId) or charId
        house.owner_name = fullName
        house.is_locked = false

        -- Разблокируем двери
        for _, door in pairs(Doors) do
            if door.house_id == houseId then
                door.state = 0
                MySQL.update.await("UPDATE thehunt_doors SET state = 0 WHERE id = ?", { door.id })
            end
        end

        TriggerClientEvent("thehunt_doors:setMyCharId", src, tonumber(charId))
        TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
        TriggerClientEvent("thehunt_status:notify", src, "Жильё", ("Вы выковали ключ и заселились в «%s»"):format(house.name), "success")
    end)
end)

-- Освобождение дома
RegisterNetEvent("thehunt_doors:unclaimHouse", function(rawHouseId)
    local src = source
    if not HuntSession then return end

    local user = HuntSession.getUser(src)
    if not user then return end
    local char = user.getUsedCharacter
    if not char then return end

    local houseId = tonumber(rawHouseId)
    if not houseId then return end

    local house = Houses[houseId]
    if not house then return end

    local charId = char.charIdentifier or char.charid or 1
    local steamId = char.identifier or user.identifier or "unknown"

    -- Проверяем, является ли игрок владельцем дома (прописан в нем)
    if tostring(house.owner_charid) ~= tostring(charId) and tostring(house.owner_identifier) ~= tostring(steamId) then
        TriggerClientEvent("thehunt_status:notify", src, "Жильё", "Вы не являетесь владельцем этого дома", "error")
        return
    end

    -- Снимаем статус владельца со строения (наличие физического ключа в инвентаре НЕ требуется)
    MySQL.update("UPDATE thehunt_houses SET owner_identifier = NULL, owner_charid = NULL, owner_name = NULL, is_locked = 0 WHERE id = ?", { houseId }, function()
        house.owner_identifier = nil
        house.owner_charid = nil
        house.owner_name = nil
        house.is_locked = false

        -- Разблокируем и сбрасываем двери дома
        for _, door in pairs(Doors) do
            if door.house_id == houseId then
                door.state = 0
                MySQL.update("UPDATE thehunt_doors SET state = 0 WHERE id = ?", { door.id })
            end
        end

        -- Полное удаление всех оставшихся ключей от дома (инвентари, земля, постройки)
        if exports["thehunt_items"] and exports["thehunt_items"].DeleteHouseKeys then
            exports["thehunt_items"]:DeleteHouseKeys(houseId)
        end

        TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
        TriggerClientEvent("thehunt_status:notify", src, "Жильё", ("Дом «%s» освобожден. Все ключи уничтожены"):format(house.name), "info")
    end)
end)

-- Дубликат ключа от дома (требуется 3 железных слитка и наличие оригинального ключа от этого дома)
RegisterNetEvent("thehunt_doors:duplicateHouseKey", function(rawHouseId)
    local src = source
    if not HuntSession then return end

    local user = HuntSession.getUser(src)
    if not user then return end
    local char = user.getUsedCharacter
    if not char then return end

    local houseId = tonumber(rawHouseId)
    if not houseId then return end

    local house = Houses[houseId]
    if not house then return end

    local charId = char.charIdentifier or char.charid or 1
    local steamId = char.identifier or user.identifier or "unknown"

    -- 1. Проверяем, есть ли у игрока ключ от этого дома во всех переносимых слотах
    HasHouseKey(steamId, charId, houseId, function(hasKey)
        if not hasKey then
            TriggerClientEvent("thehunt_status:notify", src, "Дубликат ключа", "У вас нет ключа от этого дома для создания дубликата", "error")
            return
        end

        Citizen.CreateThread(function()
            -- 2. Получаем весь переносимый инвентарь игрока (main, карманы одежды, контейнеры)
            local allInvRows = MySQL.query.await("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
                steamId, charId
            }) or {}

            local itemsByDbId = {}
            for _, r in ipairs(allInvRows) do
                itemsByDbId[tonumber(r.id)] = r
            end

            local totalIngots, directRows, packedEntries = GetCarriedItemSources(allInvRows, itemsByDbId, "iron_ingot")

            if totalIngots < 3 then
                TriggerClientEvent("thehunt_status:notify", src, "Дубликат ключа", ("Для дубликата требуется 3 железных слитка (у вас %s шт.)"):format(totalIngots), "error")
                return
            end

            -- Проверяем, освободит ли списание слитков хотя бы один слот для ключа
            local willVacate = false
            local testNeeded = 3
            for _, r in ipairs(directRows) do
                local rCount = tonumber(r.count) or 1
                if rCount <= testNeeded then
                    willVacate = true
                    break
                else
                    testNeeded = 0
                    break
                end
            end

            if not willVacate and not HasSpaceForHouseKey(allInvRows, itemsByDbId) then
                TriggerClientEvent("thehunt_status:notify", src, "Дубликат ключа", "Инвентарь полон! Освободите место для ключа", "error")
                return
            end

            -- 3. Списываем 3 железных слитка со всех слотов
            local successDeduct = DeductCarriedItem(directRows, packedEntries, 3)
            if not successDeduct then
                TriggerClientEvent("thehunt_status:notify", src, "Дубликат ключа", "Ошибка списания материалов", "error")
                return
            end

            -- 4. Выдаем новый ключ от дома (дубликат)
            local keyMeta = {
                house_id = houseId,
                label = "Ключ от двери"
            }

            if exports["thehunt_items"] and exports["thehunt_items"].GiveItem then
                exports["thehunt_items"]:GiveItem(src, "house_key", 1, keyMeta)
            else
                MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', 0, 0, 0, 'house_key', 1, ?)", {
                    steamId, charId, json.encode(keyMeta)
                })
                TriggerClientEvent("thehunt_items:refreshInventory", src)
            end

            TriggerClientEvent("thehunt_status:notify", src, "Дубликат ключа", ("Дубликат ключа от «%s» успешно изготовлен!"):format(house.name), "success")
        end)
    end)
end)

-- Переключение замка конкретной двери (проверка физического ключа)
RegisterNetEvent("thehunt_doors:toggleDoorLock", function(rawDoorId)
    local src = source
    if not HuntSession then return end

    local user = HuntSession.getUser(src)
    if not user then return end
    local char = user.getUsedCharacter
    if not char then return end

    local doorId = tonumber(rawDoorId)
    if not doorId then return end

    local door = Doors[doorId]
    if not door then return end

    local house = door.house_id and Houses[door.house_id] or nil
    local charId = char.charIdentifier or char.charid
    local steamId = char.identifier or user.identifier or "unknown"

    local function performToggle()
        local newState = (door.state == 1) and 0 or 1
        door.state = newState

        MySQL.update("UPDATE thehunt_doors SET state = ? WHERE id = ?", {
            newState,
            doorId
        }, function()
            TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
            TriggerClientEvent("thehunt_doors:playDoorSound", src, (newState == 1) and "lock" or "unlock")
            TriggerClientEvent("thehunt_doors:playKeyAnimation", src)
            TriggerClientEvent("thehunt_status:notify", src, "Дверь", (newState == 1) and "Дверь заперта на ключ" or "Дверь отперта ключом", "info")
        end)
    end

    if house then
        HasHouseKey(steamId, charId, house.id, function(hasKey)
            if hasKey then
                performToggle()
            else
                TriggerClientEvent("thehunt_status:notify", src, "Дверь", "У вас нет подходящего ключа от этого дома", "error")
            end
        end)
    else
        TriggerClientEvent("thehunt_status:notify", src, "Дверь", "У этой двери нет замка", "error")
    end
end)

-- Переключение замка дома (открыть / запереть все двери дома)
RegisterNetEvent("thehunt_doors:toggleHouseLock", function(rawHouseId)
    local src = source
    if not HuntSession then return end

    local user = HuntSession.getUser(src)
    if not user then return end
    local char = user.getUsedCharacter
    if not char then return end

    local houseId = tonumber(rawHouseId)
    if not houseId then return end

    local house = Houses[houseId]
    if not house then return end

    local charId = char.charIdentifier or char.charid
    local steamId = char.identifier or user.identifier or "unknown"

    local function performHouseToggle()
        local newLockState = not house.is_locked
        local newStateNum = newLockState and 1 or 0

        MySQL.update("UPDATE thehunt_houses SET is_locked = ? WHERE id = ?", {
            newStateNum,
            houseId
        }, function()
            house.is_locked = newLockState

            for _, door in pairs(Doors) do
                if door.house_id == houseId then
                    door.state = newStateNum
                    MySQL.update("UPDATE thehunt_doors SET state = ? WHERE id = ?", { newStateNum, door.id })
                end
            end

            TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
            TriggerClientEvent("thehunt_doors:playDoorSound", src, newLockState and "lock" or "unlock")
            TriggerClientEvent("thehunt_doors:playKeyAnimation", src)
            TriggerClientEvent("thehunt_status:notify", src, "Дом", newLockState and ("Дом «%s» заперт"):format(house.name) or ("Дом «%s» открыт"):format(house.name), "info")
        end)
    end

    HasHouseKey(steamId, charId, houseId, function(hasKey)
        if hasKey then
            performHouseToggle()
        else
            TriggerClientEvent("thehunt_status:notify", src, "Дверь", "У вас нет подходящего ключа от этого дома", "error")
        end
    end)
end)

-- Админ: создание дома и дверей
RegisterNetEvent("thehunt_doors:adminSaveHouseAndDoors", function(houseName, doorList)
    local src = source
    if not IsPlayerAdmin(src) then return end

    if not houseName or houseName == "" then
        houseName = "Жилое здание"
    end

    MySQL.insert("INSERT INTO thehunt_houses (name, is_locked) VALUES (?, 0)", {
        houseName
    }, function(houseId)
        if not houseId or houseId == 0 then return end
        local hId = tonumber(houseId)

        Houses[hId] = {
            id = hId,
            name = houseName,
            owner_identifier = nil,
            owner_charid = nil,
            owner_name = nil,
            is_locked = false
        }

        for _, d in ipairs(doorList) do
            local doorHashStr = tostring(d.doorHash or d.hash or math.random(100000, 999999))
            MySQL.insert("INSERT INTO thehunt_doors (house_id, door_hash, model_hash, x, y, z, heading, state) VALUES (?, ?, ?, ?, ?, ?, ?, 0)", {
                hId,
                doorHashStr,
                d.modelHash,
                d.x,
                d.y,
                d.z,
                d.heading or 0.0
            }, function(doorId)
                if doorId then
                    local dId = tonumber(doorId)
                    Doors[dId] = {
                        id = dId,
                        house_id = hId,
                        door_hash = doorHashStr,
                        model_hash = d.modelHash,
                        x = d.x,
                        y = d.y,
                        z = d.z,
                        heading = d.heading or 0.0,
                        state = 0
                    }
                    TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
                end
            end)
        end

        TriggerClientEvent("thehunt_status:notify", src, "Редактор дверей", ("Дом «%s» и %d дверей успешно зарегистрированы"):format(houseName, #doorList))
    end)
end)

-- Админ: разблокировка одиночной двери без привязки к дому
RegisterNetEvent("thehunt_doors:adminSaveSingleDoor", function(doorData)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if not doorData then return end

    local dX = tonumber(doorData.x) or 0.0
    local dY = tonumber(doorData.y) or 0.0
    local dZ = tonumber(doorData.z) or 0.0
    local mHash = tonumber(doorData.modelHash) or 0
    local dHeading = tonumber(doorData.heading) or 0.0
    local doorHashStr = tostring(doorData.doorHash or math.random(100000, 999999))

    -- 1. Проверяем, есть ли уже эта дверь в базе (по координатам в радиусе 1.5м)
    local existingDoorId = nil
    for dId, d in pairs(Doors) do
        if not d.house_id then
            local dist = #(vector3(d.x, d.y, d.z) - vector3(dX, dY, dZ))
            if dist < 1.5 then
                existingDoorId = dId
                break
            end
        end
    end

    if existingDoorId then
        Doors[existingDoorId].state = 0
        Doors[existingDoorId].heading = dHeading
        MySQL.update("UPDATE thehunt_doors SET state = 0, heading = ? WHERE id = ?", { dHeading, existingDoorId }, function()
            TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
            TriggerClientEvent("thehunt_status:notify", src, "Двери", "Дверь разблокирована и сделана физичной", "success")
        end)
    else
        MySQL.insert("INSERT INTO thehunt_doors (house_id, door_hash, model_hash, x, y, z, heading, state) VALUES (NULL, ?, ?, ?, ?, ?, ?, 0)", {
            doorHashStr,
            mHash,
            dX,
            dY,
            dZ,
            dHeading
        }, function(doorId)
            if doorId then
                local dId = tonumber(doorId)
                Doors[dId] = {
                    id = dId,
                    house_id = nil,
                    door_hash = doorHashStr,
                    model_hash = mHash,
                    x = dX,
                    y = dY,
                    z = dZ,
                    heading = dHeading,
                    state = 0
                }
                TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
                TriggerClientEvent("thehunt_status:notify", src, "Двери", "Дверь разблокирована и сделана физичной", "success")
            end
        end)
    end
end)

-- Админ: блокировка одиночной двери обратно в закрытое состояние
RegisterNetEvent("thehunt_doors:adminLockSingleDoor", function(doorData)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if not doorData then return end

    local dX = tonumber(doorData.x) or 0.0
    local dY = tonumber(doorData.y) or 0.0
    local dZ = tonumber(doorData.z) or 0.0

    -- Ищем и удаляем ВСЕ одиночные двери в радиусе 1.8м
    local toDelete = {}
    for dId, d in pairs(Doors) do
        if not d.house_id then
            local dist = #(vector3(d.x, d.y, d.z) - vector3(dX, dY, dZ))
            if dist < 1.8 then
                table.insert(toDelete, dId)
            end
        end
    end

    for _, dId in ipairs(toDelete) do
        Doors[dId] = nil
        MySQL.query("DELETE FROM thehunt_doors WHERE id = ?", { dId })
    end

    -- Удаляем по координатам в MySQL на случай дубликатов
    MySQL.query("DELETE FROM thehunt_doors WHERE house_id IS NULL AND ABS(x - ?) < 1.5 AND ABS(y - ?) < 1.5", { dX, dY })

    TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
    TriggerClientEvent("thehunt_status:notify", src, "Двери", "Дверь заблокирована обратно в закрытое состояние", "info")
end)

-- Админ: удаление дома и всех его дверей (с отпиранием замков)
RegisterNetEvent("thehunt_doors:adminDeleteHouse", function(rawHouseId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local houseId = tonumber(rawHouseId)
    if not houseId then return end

    -- Удаляем ВСЕ ключи от этого дома из всех инвентарей, мира и построек
    if exports["thehunt_items"] and exports["thehunt_items"].DeleteHouseKeys then
        exports["thehunt_items"]:DeleteHouseKeys(houseId)
    end

    MySQL.query("DELETE FROM thehunt_doors WHERE house_id = ?", { houseId })
    MySQL.query("DELETE FROM thehunt_houses WHERE id = ?", { houseId })

    Houses[houseId] = nil
    for id, d in pairs(Doors) do
        if d.house_id == houseId then
            Doors[id] = nil
        end
    end

    TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
    TriggerClientEvent("thehunt_status:notify", src, "Редактор дверей", "Дом и ключи удалены, двери отперты", "info")
end)

-- Админ: удаление одиночной двери (с отпиранием замка)
RegisterNetEvent("thehunt_doors:adminDeleteDoor", function(rawDoorId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local doorId = tonumber(rawDoorId)
    if not doorId then return end

    MySQL.query("DELETE FROM thehunt_doors WHERE id = ?", { doorId })
    Doors[doorId] = nil

    TriggerClientEvent("thehunt_doors:syncAllData", -1, Houses, Doors)
    TriggerClientEvent("thehunt_status:notify", src, "Редактор дверей", "Дверь удалена из базы и отперта", "info")
end)
