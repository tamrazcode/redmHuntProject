-- =================================================================
-- HUNT: Hard RP — The Corruption | Server Authoritative Loot Pickup & Anti-Dupe
-- =================================================================

LootPickup = {}

local LockedSlots = {} -- [slotId] = { src } while an inventory write is pending
local LockedPlayers = {}
function LootPickup.IsLocked(id) return LockedSlots[tonumber(id)] ~= nil end
local function Unlock(id)
    local lock = LockedSlots[id]
    if lock then LockedPlayers[lock.src] = nil end
    LockedSlots[id] = nil
end
local function IsNear(src, slot)
    local ped = GetPlayerPed(src)
    return ped and ped ~= 0 and DoesEntityExist(ped)
        and #(GetEntityCoords(ped) - vector3(slot.x, slot.y, slot.z)) <= (Config.PickupDistance or 2.2) + 0.8
end
local function PositiveInteger(value)
    local n = tonumber(value)
    return n and n == n and n > 0 and n < 2147483647 and n == math.floor(n) and n or nil
end
local function SameMetadata(a, b)
    local function decode(v)
        if type(v) == "table" then return v end
        local ok, result = pcall(json.decode, v or "{}")
        return ok and type(result) == "table" and result or {}
    end
    local function equal(x, y)
        if type(x) ~= type(y) then return false end
        if type(x) ~= "table" then return x == y end
        for k, v in pairs(x) do if not equal(v, y[k]) then return false end end
        for k in pairs(y) do if x[k] == nil then return false end end
        return true
    end
    return equal(decode(a), decode(b))
end
local EQUIPMENT_SLOT_IDS = {
    Hat = 0, Mask = 1, EyeWear = 2, NeckWear = 3, Shirt = 4, Vest = 5,
    Coat = 6, CoatClosed = 7, Poncho = 8, Cloak = 9, Pant = 10, Skirt = 11,
    Dress = 12, Boots = 13, Spurs = 14, Spats = 15, Chap = 16, Gunbelt = 17,
    Holster = 18, Belt = 19, Suspender = 21, Glove = 22, Gauntlets = 23,
    Accessories = 24, Bracelet = 26, RingLh = 27, RingRh = 28, Satchels = 29
}

local function EquipmentSlotIndex(slot)
    return EQUIPMENT_SLOT_IDS[slot]
end

local function CanonicalGender(value)
    return tostring(value or "Male"):lower():find("female", 1, true) and "Female" or "Male"
end

local function GetCharacterGender(src)
    local character = exports.thehunt_core:GetCharacter(src)
    return CanonicalGender(character and character.gender)
end

local function RestoreClothingContents(identifier, charId, parentId, metadata)
    local content = metadata and metadata.clothing_contents
    if type(content) ~= "table" or #content == 0 then return end
    for _, entry in ipairs(content) do
        if entry and entry.item_name and Items and Items.Get and Items.Get(entry.item_name) then
            local contentRotation = (entry.is_rotated == true or entry.is_rotated == 1 or tonumber(entry.is_rotated) == 1) and 1 or 0
            MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                identifier, charId, "clothing:" .. tostring(parentId), tonumber(entry.slot_x) or 0, tonumber(entry.slot_y) or 0,
                contentRotation, entry.item_name, tonumber(entry.count) or 1, entry.metadata
            })
        end
    end
    metadata.clothing_contents = nil
    MySQL.update.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(metadata), parentId })
end

-- Вспомогательная функция получения связки идентификаторов игрока VORP / RedM
local function GetPlayerIdentifiersSafe(src)
    local char = exports.thehunt_core:GetCharacter(src)
    if not char then return nil, nil end
    local id = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src)
    local charId = tonumber(char.charIdentifier or char.charid)
    if not id or not charId then return nil, nil end
    return id, charId
end

-- =================================================================
-- =================================================================
-- 1. СЕРВЕРНАЯ ВАЛИДАЦИЯ И ПОДБОР ПРЕДМЕТА В ИНВЕНТАРЬ
-- =================================================================

-- Resolve carried item containers from authoritative inventory rows.
local function GetItemContainerStorage(parentId, identifier, charId, itemDef, itemName)
    if not parentId or not itemDef or itemDef.isContainer == true or itemDef.containerStorage then return nil end
    local rows = MySQL.query.await("SELECT item_name, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {parentId, identifier, charId})
    local parent = rows and rows[1]
    if not parent then return nil end
    local location = parent.container or 'main'
    if location ~= 'main' and location ~= 'equipment' then
        local clothingId = tostring(location):match('^clothing:(%d+)$')
        if not clothingId then return nil end
        local carried = MySQL.scalar.await("SELECT id FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", {tonumber(clothingId), identifier, charId})
        if not carried then return nil end
    end
    local parentDef = Items.Get(parent.item_name)
    local storage = parentDef and parentDef.containerStorage
    if not storage then return nil end
    local name = tostring(itemName or ''):lower()
    if storage.keyOnly == true and not (itemDef.category == 'key' or itemDef.isKey == true or name:find('key', 1, true)) then return nil end
    return storage
end

local function AwaitQuery(sql, params, cb) cb(MySQL.query.await(sql, params)) end
local function AwaitInsert(sql, params, cb) cb(MySQL.insert.await(sql, params)) end
local function AwaitUpdate(sql, params, cb) cb(MySQL.update.await(sql, params)) end
local function AwaitGive(src, name, count, meta, cb)
    local result = promise.new()
    exports.thehunt_items:GiveItem(src, name, count, meta, function(success, added, remaining)
        result:resolve({success, added, remaining})
    end)
    cb(table.unpack(Citizen.Await(result)))
end
local function Pickup(src, slotId, targetContainer, targetX, targetY, isRotated, requestedCount)
    local sId = tonumber(slotId)
    if not sId or LockedPlayers[src] then return end

    local slot = LootSpawner.GetSlot(sId)
    if slot and Zones.IsMutating(slot.zone_id) then return end
    if not slot then
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Предмет уже забран другим игроком", "info")
        return
    end

    -- 1. Anti-Dupe Mutex: защита от одновременного перетаскивания двумя игроками
    if LockedSlots[sId] then
        -- One authoritative pickup at a time, including repeated requests from
        -- the same client while the inventory write is still pending.
        if LockedSlots[sId].src ~= src then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот предмет сейчас забирает другой игрок", "warning")
        end
        return
    end

    LockedSlots[sId] = { src = src }
    LockedPlayers[src] = true

    -- 2. Проверка дистанции
    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then
        Unlock(sId)
        return
    end

    local pedCoords = GetEntityCoords(ped)
    local slotPos = vector3(slot.x, slot.y, slot.z)
    local dist = #(pedCoords - slotPos)

    if not IsNear(src, slot) then
        Unlock(sId)
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы находитесь слишком далеко от предмета", "error")
        return
    end

    local itemName = slot.item_name
    if string.lower(tostring(itemName or "")) == "clothing_badge"
        or string.lower(tostring(itemName or "")) == "clothing_buckle" then
        Unlock(sId)
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот предмет больше недоступен", "info")
        return
    end
    local originalCount = PositiveInteger(slot.count)
    local count = requestedCount and PositiveInteger(requestedCount) or originalCount
    if not originalCount or not count then Unlock(sId); return end
    count = math.min(count, originalCount)
    local function consume(amount)
        if LootSpawner.GetSlot(sId) ~= slot or slot.count < amount then return false end
        if amount == slot.count then return LootSpawner.RemoveSlot(sId, "picked_up") end
        return LootSpawner.UpdateSlotCount(sId, slot.count - amount)
    end
    local meta = slot.metadata or {}
    local itemDef = Items and Items.Get and Items.Get(itemName)
    if not itemDef then Unlock(sId); return end
    local maxStack = itemDef.maxStack or 1
    local itemW = itemDef and itemDef.width or 1
    local itemH = itemDef and itemDef.height or 1

    local steamId, charId = GetPlayerIdentifiersSafe(src)
    if not steamId or not charId then Unlock(sId); return end
    local targetXNum = targetX and tonumber(targetX) or nil
    local targetYNum = targetY and tonumber(targetY) or nil
    if (targetX ~= nil and (not targetXNum or targetXNum ~= targetXNum or targetXNum < 0 or targetXNum > 1000 or targetXNum ~= math.floor(targetXNum)))
        or (targetY ~= nil and (not targetYNum or targetYNum ~= targetYNum or targetYNum < 0 or targetYNum > 1000 or targetYNum ~= math.floor(targetYNum))) then Unlock(sId); return end
    if targetContainer and targetContainer ~= 'main' and targetContainer ~= 'ground' and targetContainer ~= 'equipment'
        and (type(targetContainer) ~= 'string' or (not targetContainer:match('^clothing:%d+$') and not targetContainer:match('^container:%d+$'))) then Unlock(sId); return end

    -- Garments from persistent world loot can be equipped directly instead
    -- of first placing them in the main grid.
    if targetContainer == 'equipment' and targetXNum and targetYNum then
        local expectedX = itemDef and EquipmentSlotIndex(itemDef.clothingSlot)
        local currentGender = GetCharacterGender(src)
        local itemGender = type(meta) == "table" and (meta.gender or meta.sex) or nil
        if itemGender and CanonicalGender(itemGender) ~= currentGender then
            Unlock(sId)
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Эта одежда предназначена для другого пола", "error")
            return
        end
        if not (itemDef and itemDef.clothing == true) or expectedX == nil or targetXNum ~= expectedX or targetYNum ~= 0 then
            Unlock(sId)
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот предмет нельзя надеть в выбранный слот", "error")
            return
        end

        if not itemGender then
            meta.gender = currentGender
        end

        AwaitQuery("SELECT id FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'equipment' AND slot_x = ? LIMIT 1", {
            steamId, charId, expectedX
        }, function(existing)
            if existing and existing[1] then
                Unlock(sId)
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот слот одежды уже занят", "warning")
                return
            end

            AwaitInsert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'equipment', ?, 0, 0, ?, 1, ?)", {
                steamId, charId, expectedX, itemName, json.encode(meta or {})
            }, function(insertId)
                if not insertId then
                    Unlock(sId)
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end
                if not consume(1) then
                    MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { insertId, steamId, charId })
                    Unlock(sId)
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end
                RestoreClothingContents(steamId, charId, insertId, meta)
                if meta.component then
                    TriggerClientEvent("thehunt_character:client:ApplySingleClothing", src, itemDef.clothingSlot, tonumber(meta.component) or -1, meta.tint, nil)
                end
                TriggerEvent("thehunt_character:server:syncInventoryClothing", src, itemDef.clothingSlot, meta)
                Unlock(sId)
                LootDB.LogAction("pickup", steamId, charId, slot.zone_id, itemName, 1, slot.x, slot.y, slot.z, "Подбор одежды сразу в слот экипировки")
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
            end)
        end)
        return
    end

    -- А) Если игрок перетащил предмет на конкретную ячейку в инвентаре
    -- World loot can also be placed directly into an equipped garment's
    -- storage grid (clothing:<parent inventory id>). Verify the parent and
    -- the complete grid server-side before consuming the world slot.
    local isItemContainer = type(targetContainer) == 'string' and targetContainer:match('^container:%d+$') ~= nil
    local isClothingContainer = type(targetContainer) == 'string' and targetContainer:match('^clothing:%d+$') ~= nil
    if (isItemContainer or isClothingContainer) and (not targetXNum or not targetYNum) then
        Unlock(sId)
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        return
    end
    if (isItemContainer or isClothingContainer) and targetXNum and targetYNum then
        local parentId = tonumber(targetContainer:match(':(%d+)$'))
        if itemDef.clothing then
            local parents = MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { parentId, steamId, charId })
            local parentDef = parents and parents[1] and Items.Get(parents[1].item_name)
            if not Items.CanPackClothing(itemDef, parentDef, meta, false) then
                Unlock(sId)
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Сначала освободите карманы одежды.", "warning")
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end
        end
        if not parentId or count > maxStack then
            Unlock(sId)
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end

        local rotState = (isRotated == true or isRotated == 1 or tonumber(isRotated) == 1)
        local effW = rotState and itemH or itemW
        local effH = rotState and itemW or itemH

        local function withStorage(callback)
            if isItemContainer then
                callback(GetItemContainerStorage(parentId, steamId, charId, itemDef, itemName))
            else
                AwaitQuery("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", {parentId, steamId, charId}, function(parentRows)
                    local parentDef = parentRows and parentRows[1] and Items.Get(parentRows[1].item_name)
                    callback(parentDef and parentDef.clothing == true and parentDef.storage or nil)
                end)
            end
        end
        withStorage(function(storage)
            local validBounds = storage and targetXNum >= 0 and targetYNum >= 0
                and targetXNum + effW <= (tonumber(storage.cols) or 0)
                and targetYNum + effH <= (tonumber(storage.rows) or 0)

            if validBounds and storage.rowWidths then
                for row = targetYNum, targetYNum + effH - 1 do
                    local rowWidth = tonumber(storage.rowWidths[row + 1]) or tonumber(storage.cols) or 0
                    if targetXNum + effW > rowWidth then
                        validBounds = false
                        break
                    end
                end
            end

            if not validBounds then
                Unlock(sId)
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end

            AwaitQuery("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
                steamId, charId, targetContainer
            }, function(existing)
                existing = existing or {}
                local overlaps = false
                for _, row in ipairs(existing) do
                    local rowDef = Items.Get(row.item_name)
                    local rowRot = row.is_rotated == 1 or row.is_rotated == true or tonumber(row.is_rotated) == 1
                    local rowW = rowRot and (rowDef and rowDef.height or 1) or (rowDef and rowDef.width or 1)
                    local rowH = rowRot and (rowDef and rowDef.width or 1) or (rowDef and rowDef.height or 1)
                    local rowX = tonumber(row.slot_x) or 0
                    local rowY = tonumber(row.slot_y) or 0
                    if not (targetXNum + effW <= rowX or targetXNum >= rowX + rowW
                        or targetYNum + effH <= rowY or targetYNum >= rowY + rowH) then
                        overlaps = true
                        break
                    end
                end

                if overlaps then
                    Unlock(sId)
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end

                AwaitInsert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                    steamId, charId, targetContainer, targetXNum, targetYNum, rotState and 1 or 0, itemName, count, json.encode(meta or {})
                }, function(insertId)
                    if not insertId then
                        Unlock(sId)
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        return
                    end
                    if not consume(count) then
                        MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { insertId, steamId, charId })
                        Unlock(sId)
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        return
                    end
                    LootDB.LogAction("pickup", steamId, charId, slot.zone_id, itemName, count, slot.x, slot.y, slot.z, "Подбор предмета в " .. targetContainer)
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    Unlock(sId)
                    TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
                end)
            end)
        end)
        return
    end

    if targetXNum and targetYNum and targetContainer ~= 'ground' then
        AwaitQuery("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
            steamId, charId
        }, function(existing)
            existing = existing or {}
            local rotState = (isRotated == true or isRotated == 1 or tonumber(isRotated) == 1)
            local effW = rotState and itemH or itemW
            local effH = rotState and itemW or itemH

            -- 1. Проверяем слияние со стаком того же типа
            local targetItem = nil
            for _, row in ipairs(existing) do
                local rX = tonumber(row.slot_x) or 0
                local rY = tonumber(row.slot_y) or 0
                local rDef = Items and Items.Get and Items.Get(row.item_name)
                local isRot = (row.is_rotated == 1 or row.is_rotated == true or tonumber(row.is_rotated) == 1)
                local rW = isRot and (rDef and rDef.height or 1) or (rDef and rDef.width or 1)
                local rH = isRot and (rDef and rDef.width or 1) or (rDef and rDef.height or 1)

                local overlap = not (targetXNum + effW <= rX or targetXNum >= rX + rW or targetYNum + effH <= rY or targetYNum >= rY + rH)
                if overlap and row.item_name == itemName then
                    targetItem = row
                    break
                end
            end

            if targetItem and targetItem.item_name == itemName and maxStack > 1 and SameMetadata(targetItem.metadata, meta) then
                local curTargetCount = tonumber(targetItem.count) or 1
                local spaceLeft = maxStack - curTargetCount
                if spaceLeft > 0 then
                    local mergeAmount = math.min(count, spaceLeft)
                    AwaitUpdate("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND count = ? AND identifier = ? AND charidentifier = ?", {
                        mergeAmount, targetItem.id, curTargetCount, steamId, charId
                    }, function(changed)
                        if tonumber(changed) ~= 1 then Unlock(sId); return end
                        if not consume(mergeAmount) then
                            MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND count >= ?", {mergeAmount, targetItem.id, mergeAmount})
                            Unlock(sId)
                            return
                        end
                        Unlock(sId)

                        LootDB.LogAction("pickup", steamId, charId, slot.zone_id, itemName, mergeAmount, slot.x, slot.y, slot.z, "Подбор предмета в стак инвентаря")
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
                    end)
                    return
                end
            end

            -- 2. Проверяем, свободна ли целевая ячейка
            local isValidSlot = false
            local mainCols = Items and Items.GetGridCols and Items.GetGridCols("main") or 10
            local mainRows = Items and Items.GetGridRows and Items.GetGridRows("main") or 14

            if (targetXNum >= 0) and (targetYNum >= 0) and (targetXNum + effW <= mainCols) and (targetYNum + effH <= mainRows) then
                local overlaps = false
                for _, row in ipairs(existing) do
                    local rX = tonumber(row.slot_x) or 0
                    local rY = tonumber(row.slot_y) or 0
                    local rDef = Items and Items.Get and Items.Get(row.item_name)
                    local isRot = (row.is_rotated == 1 or row.is_rotated == true or tonumber(row.is_rotated) == 1)
                    local rW = isRot and (rDef and rDef.height or 1) or (rDef and rDef.width or 1)
                    local rH = isRot and (rDef and rDef.width or 1) or (rDef and rDef.height or 1)

                    if not (targetXNum + effW <= rX or targetXNum >= rX + rW or targetYNum + effH <= rY or targetYNum >= rY + rH) then
                        overlaps = true
                        break
                    end
                end
                if not overlaps then
                    isValidSlot = true
                end
            end

            if isValidSlot then
                AwaitInsert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', ?, ?, ?, ?, ?, ?)", {
                    steamId, charId, targetXNum, targetYNum, rotState and 1 or 0, itemName, count, json.encode(meta or {})
                }, function(insertId)
                    if not insertId then
                        Unlock(sId)
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        return
                    end
                    if not consume(count) then
                        MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { insertId, steamId, charId })
                        Unlock(sId)
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        return
                    end
                    LootDB.LogAction("pickup", steamId, charId, slot.zone_id, itemName, count, slot.x, slot.y, slot.z, "Подбор предмета в слот инвентаря")
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    Unlock(sId)
                    TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
                end)
                return
            end

            -- Резерв: если выбранная ячейка занята, сначала заполняем неполные стаки, затем свободные слоты
            if exports.thehunt_items and exports.thehunt_items.GiveItem then
                AwaitGive(src, itemName, count, meta, function(success, addedCount, remaining)
                    if success and addedCount > 0 then
                        consume(addedCount)
                        Unlock(sId)
                        LootDB.LogAction("pickup", steamId, charId, slot.zone_id, itemName, addedCount, slot.x, slot.y, slot.z, "Подбор предмета в свободный слот инвентаря")
                        TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
                    else
                        Unlock(sId)
                        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!", "error")
                    end
                end)
            else
                Unlock(sId)
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!", "error")
            end
        end)
    else
        -- Б) Быстрый подбор (ПКМ "Подобрать" / контекстное меню / подбор без точных координат)
        -- 1. Сначала заполняет все доступные неполные стаки в инвентаре
        -- 2. Затем размещает остаток в свободные ячейки с учетом поворота
        if exports.thehunt_items and exports.thehunt_items.GiveItem then
            AwaitGive(src, itemName, count, meta, function(success, addedCount, remaining)
                if success and addedCount > 0 then
                    consume(addedCount)
                    Unlock(sId)
                    LootDB.LogAction("pickup", steamId, charId, slot.zone_id, itemName, addedCount, slot.x, slot.y, slot.z, "Подбор предмета в инвентарь")
                    TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
                else
                    Unlock(sId)
                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!", "error")
                end
            end)
        else
            Unlock(sId)
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!", "error")
        end
    end
end

local function SafePickup(src, ...)
    local args = table.pack(...)
    local ok, err = pcall(function() Pickup(src, table.unpack(args, 1, args.n)) end)
    if not ok then
        for id, lock in pairs(LockedSlots) do if lock.src == src then Unlock(id) end end
        print('[HUNT LOOT] Pickup failed: ' .. tostring(err))
        TriggerClientEvent('thehunt_items:refreshInventory', src)
    end
end
RegisterNetEvent("thehunt_loot:requestPickupToInventory", function(id, container, x, y, rotated)
    -- Inventory may append mutationSequence. It is not a requested stack count.
    SafePickup(source, id, container, x, y, rotated)
end)
RegisterNetEvent("thehunt_loot:splitLootToInventory", function(id, count, container, x, y, rotated)
    if not PositiveInteger(count) then return end
    SafePickup(source, id, container, x, y, rotated, count)
end)

-- Both counters change in one SQL statement. Conditional counts reject stale
-- requests from other inventory operations without creating additional items.
local function Merge(src, fromKind, fromId, toKind, toId, requested)
    local amount = PositiveInteger(requested)
    fromId, toId = PositiveInteger(fromId), PositiveInteger(toId)
    if not amount or not fromId or not toId or LockedPlayers[src] then return end
    if fromKind == toKind and fromId == toId then return end
    local identifier, charId = GetPlayerIdentifiersSafe(src)
    if not identifier then return end
    local locked, dropLocks = {}, {}
    local token = 'loot:' .. src .. ':' .. GetGameTimer()
    local function finish()
        for _, id in ipairs(locked) do Unlock(id) end
        for _, id in ipairs(dropLocks) do exports.thehunt_items:ReleaseLootDropLock(id, token) end
        LockedPlayers[src] = nil
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        TriggerClientEvent("thehunt_inventory:refreshNearbyDrops", src)
    end
    local ok, err = pcall(function()
        local tables = {loot = 'thehunt_loot_active_slots', inventory = 'thehunt_inventories', drop = 'thehunt_drops'}
        local function get(kind, id)
            if kind == 'loot' then
                local slot = LootSpawner.GetSlot(id)
                if not slot or Zones.IsMutating(slot.zone_id) or LockedSlots[id] or not IsNear(src, slot) then return nil end
                LockedSlots[id] = { src = src }
                locked[#locked + 1] = id
                local rows = MySQL.query.await('SELECT * FROM thehunt_loot_active_slots WHERE id = ?', {id})
                return rows and rows[1]
            end
            if kind == 'drop' then
                local drop = exports.thehunt_items:AcquireLootDropLock(id, token)
                if not drop then return nil end
                dropLocks[#dropLocks + 1] = id
            end
            local rows = MySQL.query.await('SELECT * FROM ' .. tables[kind] .. ' WHERE id = ?', { id })
            local row = rows and rows[1]
            if not row then return nil end
            if kind == 'inventory' then
                if row.identifier ~= identifier or tonumber(row.charidentifier) ~= charId then return nil end
                local itemContainerId = tostring(row.container):match('^container:(%d+)$')
                if itemContainerId then
                    if not GetItemContainerStorage(tonumber(itemContainerId), identifier, charId, Items.Get(row.item_name), row.item_name) then return nil end
                elseif row.container ~= 'main' and not tostring(row.container):match('^clothing:%d+$') then return nil end
                if row.container ~= 'main' and not itemContainerId then
                    local parent = MySQL.scalar.await("SELECT id FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", { tonumber(row.container:sub(10)), identifier, charId })
                    if not parent then return nil end
                end
            elseif not IsNear(src, row) then return nil end
            return row
        end
        LockedPlayers[src] = true
        local a = get(fromKind, fromId)
        if not a then return end
        local b = get(toKind, toId)
        if not b or a.item_name ~= b.item_name or not SameMetadata(a.metadata, b.metadata) then return end
        local def = Items.Get(a.item_name)
        if not def or (tonumber(def.maxStack) or 1) <= 1 then return end
        local oldA, oldB = tonumber(a.count), tonumber(b.count)
        if not oldA or not oldB then return end
        amount = math.min(amount, oldA, def.maxStack - oldB)
        if amount < 1 then return end
        if (fromKind == 'loot' or fromKind == 'drop') and not IsNear(src, a) then return end
        if (toKind == 'loot' or toKind == 'drop') and not IsNear(src, b) then return end
        local query = 'UPDATE ' .. tables[fromKind] .. ' a JOIN ' .. tables[toKind] .. ' b ON b.id = ? '
            .. 'SET a.count = a.count - ?, b.count = b.count + ? '
            .. 'WHERE a.id = ? AND a.count = ? AND b.count = ? AND a.item_name = b.item_name'
        local params = {toId, amount, amount, fromId, oldA, oldB}
        query = query .. " AND COALESCE(a.metadata, '{}') = ? AND COALESCE(b.metadata, '{}') = ?"
        params[#params + 1] = type(a.metadata) == 'table' and json.encode(a.metadata) or a.metadata or '{}'
        params[#params + 1] = type(b.metadata) == 'table' and json.encode(b.metadata) or b.metadata or '{}'
        -- Ownership and location are checked again in the mutation, after all awaited reads.
        for alias, kind in pairs({a = fromKind, b = toKind}) do
            if kind == 'inventory' then
                query = query .. ' AND ' .. alias .. '.identifier = ? AND ' .. alias .. '.charidentifier = ? AND ' .. alias .. '.container = ?'
                params[#params + 1] = identifier; params[#params + 1] = charId
                params[#params + 1] = alias == 'a' and a.container or b.container
            end
        end
        local changed = MySQL.update.await(query, params)
        if not changed or changed < 1 then return end
        local function publish(kind, id, count)
            if kind == 'loot' then
                if count <= 0 then LootSpawner.RemoveSlot(id, 'merged', true)
                else LootSpawner.UpdateSlotCount(id, count, true) end
            elseif count <= 0 then
                MySQL.update.await('DELETE FROM ' .. tables[kind] .. ' WHERE id = ? AND count = 0', {id})
            end
        end
        publish(fromKind, fromId, oldA - amount)
        publish(toKind, toId, oldB + amount)
        LootDB.LogAction('merge', identifier, charId, a.zone_id or b.zone_id, a.item_name, amount, a.x or b.x, a.y or b.y, a.z or b.z, 'Перенос стака лута')
    end)
    finish()
    if not ok then print('[HUNT LOOT] Merge failed: ' .. tostring(err)) end
end

RegisterNetEvent('thehunt_loot:mergeLootIntoInventory', function(a, b, n) Merge(source, 'loot', a, 'inventory', b, n) end)
RegisterNetEvent('thehunt_loot:mergeInventoryIntoLoot', function(a, b, n) Merge(source, 'inventory', a, 'loot', b, n) end)
RegisterNetEvent('thehunt_loot:mergeLootIntoLoot', function(a, b, n) Merge(source, 'loot', a, 'loot', b, n) end)
RegisterNetEvent('thehunt_loot:mergeDropIntoLoot', function(a, b, n) Merge(source, 'drop', a, 'loot', b, n) end)
RegisterNetEvent('thehunt_loot:mergeLootIntoDrop', function(a, b, n) Merge(source, 'loot', a, 'drop', b, n) end)
