-- =================================================================
-- HUNT: Hard RP — The Corruption | World Builder Server Module
-- =================================================================

local PlacedPropsCache = {}
local DeletedPropsCache = {}
local worldMoveSequence = 0
local builderBackupInProgress = false
local builderBackupSequence = 0

local function NewWorldMoveToken(source)
    worldMoveSequence = worldMoveSequence + 1
    return string.format('%s:%s:%s:%s', tostring(source), tostring(os.time()), tostring(GetGameTimer()), tostring(worldMoveSequence))
end


local function GetPlayerIdentifierVORP(src)
    local owner = "UNKNOWN"
    local char = exports.thehunt_core:GetCharacter(src)
    if char then owner = char.identifier or owner end
    if owner == "UNKNOWN" then owner = exports.thehunt_core:GetPlayerIdentifier(src) or owner end
    if owner == "UNKNOWN" then
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if string.find(id, "license:") or string.find(id, "steam:") then
                owner = id
                break
            end
        end
    end
    return owner
end

local function IsPlayerAdmin(source)
    if source == 0 then return true end

    -- 1. Централизованная проверка через thehunt_core
    if exports.thehunt_core and exports.thehunt_core.IsPlayerAdmin then
        return exports.thehunt_core:IsPlayerAdmin(source)
    end

    -- 2. Резервная проверка FiveM/RedM/txAdmin ACE-прав
    if IsPlayerAceAllowed(source, "group.admin") or IsPlayerAceAllowed(source, "command") 
    or IsPlayerAceAllowed(source, "admin") or IsPlayerAceAllowed(source, "txadmin") then
        return true
    end

    return false
end

local isDataLoaded = false

-- Инициализация кэша объектов при старте ресурса
Citizen.CreateThread(function()
    Citizen.Wait(200)
    DB.Init(function()
        DB.GetAllPlacedProps(function(placed)
            PlacedPropsCache = placed or {}
            print(string.format("^2[HUNT BUILDER] Загружено кастомных объектов из БД: %d^7", #PlacedPropsCache))
            DB.GetAllDeletedWorldProps(function(deleted)
                DeletedPropsCache = deleted or {}
                isDataLoaded = true
                print(string.format("^2[HUNT BUILDER] Загружено удаленных объектов мира из БД: %d^7", #DeletedPropsCache))
                -- Синхронизируем данные всем активным игрокам на сервере при перезапуске ресурса
                TriggerClientEvent("thehunt_builder:receiveAllData", -1, PlacedPropsCache, DeletedPropsCache)
            end)
        end)
    end)
end)

-- Запрос данных при подключении игрока
RegisterNetEvent("thehunt_builder:requestInitialData", function()
    local src = source
    local myOwner = GetPlayerIdentifierVORP(src)
    if isDataLoaded then
        TriggerClientEvent("thehunt_builder:receiveAllData", src, PlacedPropsCache, DeletedPropsCache, myOwner)
    else
        -- Если игрок подключился раньше готовности кэша, запрашиваем из БД напрямую
        DB.GetAllPlacedProps(function(placed)
            PlacedPropsCache = placed or PlacedPropsCache
            DB.GetAllDeletedWorldProps(function(deleted)
                DeletedPropsCache = deleted or DeletedPropsCache
                isDataLoaded = true
                TriggerClientEvent("thehunt_builder:receiveAllData", src, PlacedPropsCache, DeletedPropsCache, myOwner)
            end)
        end)
    end
end)

-- Проверка прав и открытие редактора
RegisterNetEvent("thehunt_builder:checkPermissionAndOpen", function()
    local src = source
    if IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_builder:openBuilderClient", src)
    else
        TriggerClientEvent("thehunt_rp:show3DText", src, src, "(( [Ошибка] У вас нет прав для режима редактирования мира ))", { 255, 60, 60 })
    end
end)

-- Сохранение нового установленного объекта
RegisterNetEvent("thehunt_builder:placeObject", function(propData)
    local src = source
    if not IsPlayerAdmin(src) and not propData.isPlayerBaseItem and not propData.item_name then return end

    if not propData or not propData.model_hash or propData.model_hash == 0 or not propData.x or not propData.y or not propData.z then
        return
    end

    local isFromInventory = (propData.is_player_item == 1 or propData.is_player_item == true or propData.from_inventory == true) and (propData.item_name ~= nil and propData.item_name ~= "")
    local isProtected = (propData.is_protected == 1 or propData.is_protected == true) and 1 or 0
    local playerOwner = isFromInventory and GetPlayerIdentifierVORP(src) or "ADMIN"

    if isFromInventory then
        local ped = GetPlayerPed(src)
        if ped and DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(pedCoords - vector3(tonumber(propData.x) + 0.0, tonumber(propData.y) + 0.0, tonumber(propData.z) + 0.0))
            if dist > 3.5 then
                print(string.format("^1[HUNT BUILDER] Игрок %s попытался поставить предмет слишком далеко (%.2fm)^7", GetPlayerName(src), dist))
                TriggerClientEvent("thehunt_status:notify", src, "Ошибка", "Слишком далеко от персонажа!", "error", 3000)
                return
            end
        end
    end

    local newProp = {
        model_name = propData.model_name or "prop",
        model_hash = tonumber(propData.model_hash),
        item_name = isFromInventory and propData.item_name or nil,
        metadata = propData.metadata or nil,
        x = tonumber(propData.x) + 0.0,
        y = tonumber(propData.y) + 0.0,
        z = tonumber(propData.z) + 0.0,
        rot_x = tonumber(propData.rot_x or 0.0) + 0.0,
        rot_y = tonumber(propData.rot_y or 0.0) + 0.0,
        rot_z = tonumber(propData.rot_z or 0.0) + 0.0,
        original_x = propData.original_x and (tonumber(propData.original_x) + 0.0) or nil,
        original_y = propData.original_y and (tonumber(propData.original_y) + 0.0) or nil,
        original_z = propData.original_z and (tonumber(propData.original_z) + 0.0) or nil,
        original_rx = propData.original_rx and (tonumber(propData.original_rx) + 0.0) or nil,
        original_ry = propData.original_ry and (tonumber(propData.original_ry) + 0.0) or nil,
        original_rz = propData.original_rz and (tonumber(propData.original_rz) + 0.0) or nil,
        owner = playerOwner,
        is_protected = isProtected,
        is_admin_prop = (not isFromInventory) and 1 or 0
    }

    DB.SavePlacedProp(newProp, function(insertId)
        if insertId then
            newProp.id = insertId
            table.insert(PlacedPropsCache, newProp)
            -- Синхронизируем новый объект всем игрокам
            TriggerClientEvent("thehunt_builder:syncNewProp", -1, newProp)
            print(string.format("^2[HUNT BUILDER] Создан новый объект #%d (%s) [admin: %d, item: %s] игроком %s^7", insertId, newProp.model_name, newProp.is_admin_prop, tostring(newProp.item_name), GetPlayerName(src)))

            if isFromInventory and propData.item_name then
                TriggerEvent("thehunt_items:onItemPlacedInWorld", src, propData.item_name, propData.dbId, insertId)
            end
        end
    end)
end)

-- Переключение запрета на подбор предмета (Запретить / Разрешить подбирать)
RegisterNetEvent("thehunt_builder:togglePropProtection", function(propId, setProtected)
    local src = source
    local pId = tonumber(propId)
    if not pId then return end

    local prop = nil
    local propIndex = nil
    for idx, p in ipairs(PlacedPropsCache) do
        if tonumber(p.id) == pId then
            prop = p
            propIndex = idx
            break
        end
    end

    if not prop then return end

    local myOwner = GetPlayerIdentifierVORP(src)
    local isOwner = (prop.owner and (prop.owner == myOwner or prop.owner == "ADMIN"))
    local isAdmin = IsPlayerAdmin(src)

    if not isOwner and not isAdmin then
        TriggerClientEvent("thehunt_status:notify", src, "Предмет", "Вы не являетесь владельцем этого предмета!", "error")
        return
    end

    local newProt = setProtected and 1 or 0
    prop.is_protected = newProt
    PlacedPropsCache[propIndex].is_protected = newProt

    DB.UpdatePropProtection(pId, newProt, function()
        TriggerClientEvent("thehunt_builder:syncPropProtection", -1, pId, newProt)
        if newProt == 1 then
            TriggerClientEvent("thehunt_status:notify", src, "Предмет", "Подбор предмета запрещен для других игроков", "warning")
        else
            TriggerClientEvent("thehunt_status:notify", src, "Предмет", "Подбор предмета разрешен для всех игроков", "success")
        end
        print(string.format("^2[HUNT BUILDER] Статус защиты объекта #%d изменен на %d игроком %s^7", pId, newProt, GetPlayerName(src)))
    end)
end)

-- Обновление позиции (перемещение)
RegisterNetEvent("thehunt_builder:updateObjectPos", function(propId, x, y, z, rx, ry, rz, metadata)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local id = tonumber(propId)
    if not id then return end

    local function finalizeUpdate()
        for _, p in ipairs(PlacedPropsCache) do
            if p.id == id then
                p.x = x
                p.y = y
                p.z = z
                p.rot_x = rx
                p.rot_y = ry
                p.rot_z = rz
                if metadata ~= nil then
                    p.metadata = metadata
                end
                break
            end
        end
        TriggerClientEvent("thehunt_builder:syncUpdateProp", -1, id, x, y, z, rx, ry, rz, metadata)
    end

    DB.UpdatePlacedProp(id, x, y, z, rx, ry, rz, function()
        if metadata ~= nil then
            DB.UpdatePlacedPropMetadata(id, metadata, finalizeUpdate)
        else
            finalizeUpdate()
        end
    end)
end)

-- Удаление кастомного объекта
-- A native map prop move must either save both its replacement and its world
-- hide record, or save neither. Do not expose local-only movement to clients.
RegisterNetEvent("thehunt_builder:moveWorldStaticObject", function(moveData)
    local src = source
    if not IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_builder:moveWorldStaticObjectFailed", src, "Нет прав на редактирование мира")
        return
    end
    if type(moveData) ~= "table" then
        TriggerClientEvent("thehunt_builder:moveWorldStaticObjectFailed", src, "Некорректные данные перемещения")
        return
    end

    local required = {
        moveData.model_hash, moveData.original_model_hash,
        moveData.x, moveData.y, moveData.z,
        moveData.original_x, moveData.original_y, moveData.original_z
    }
    for _, value in ipairs(required) do
        if type(value) ~= "number" or value ~= value then
            TriggerClientEvent("thehunt_builder:moveWorldStaticObjectFailed", src, "Некорректные данные перемещения")
            return
        end
    end

    local newProp = {
        model_name = "Перемещенный объект",
        model_hash = tonumber(moveData.model_hash),
        metadata = moveData.metadata or nil,
        x = tonumber(moveData.x) + 0.0,
        y = tonumber(moveData.y) + 0.0,
        z = tonumber(moveData.z) + 0.0,
        rot_x = tonumber(moveData.rot_x or 0.0) + 0.0,
        rot_y = tonumber(moveData.rot_y or 0.0) + 0.0,
        rot_z = tonumber(moveData.rot_z or 0.0) + 0.0,
        original_x = tonumber(moveData.original_x) + 0.0,
        original_y = tonumber(moveData.original_y) + 0.0,
        original_z = tonumber(moveData.original_z) + 0.0,
        original_rx = tonumber(moveData.original_rx or 0.0) + 0.0,
        original_ry = tonumber(moveData.original_ry or 0.0) + 0.0,
        original_rz = tonumber(moveData.original_rz or 0.0) + 0.0,
        original_model_hash = tonumber(moveData.original_model_hash),
        deleted_by = GetPlayerName(src),
        move_token = NewWorldMoveToken(src)
    }

    DB.MoveWorldProp(newProp, function(insertId, deletedId)
        if not insertId then
            TriggerClientEvent("thehunt_builder:moveWorldStaticObjectFailed", src, "Не удалось сохранить перемещение в базу данных")
            return
        end

        newProp.id = insertId
        newProp.move_token = nil
        table.insert(PlacedPropsCache, newProp)

        local deletedItem = {
            id = deletedId,
            model_hash = newProp.original_model_hash,
            x = newProp.original_x,
            y = newProp.original_y,
            z = newProp.original_z,
            deleted_by = newProp.deleted_by
        }
        local exists = false
        for _, del in ipairs(DeletedPropsCache) do
            if tonumber(del.model_hash) == tonumber(deletedItem.model_hash)
            and math.abs((del.x or 0.0) - deletedItem.x) < 0.35
            and math.abs((del.y or 0.0) - deletedItem.y) < 0.35
            and math.abs((del.z or 0.0) - deletedItem.z) < 0.35 then
                exists = true
                deletedItem.id = del.id
                break
            end
        end
        if not exists then table.insert(DeletedPropsCache, deletedItem) end

        -- New prop first protects a very-short move from being treated as
        -- the original by the subsequent world-hide pass.
        TriggerClientEvent("thehunt_builder:moveWorldStaticObjectConfirmed", src, insertId)
        TriggerClientEvent("thehunt_builder:syncNewProp", -1, newProp)
        TriggerClientEvent("thehunt_builder:syncDeleteWorldProp", -1, deletedItem)
    end)
end)

RegisterNetEvent("thehunt_builder:deletePlacedObject", function(propId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local id = tonumber(propId)
    if not id then return end

    DB.DeletePlacedProp(id, function()
        for idx, p in ipairs(PlacedPropsCache) do
            if p.id == id then
                table.remove(PlacedPropsCache, idx)
                break
            end
        end
        TriggerClientEvent("thehunt_builder:syncDeleteProp", -1, id)
        print(string.format("^1[HUNT BUILDER] Кастомный объект #%d удален админом %s^7", id, GetPlayerName(src)))
    end)
end)

-- Возврат статического объекта мира на исходное положение
RegisterNetEvent("thehunt_builder:restoreWorldObject", function(propId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local id = tonumber(propId)
    if not id then return end

    local targetProp = nil
    local targetIdx = nil
    for idx, p in ipairs(PlacedPropsCache) do
        if p.id == id then
            targetProp = p
            targetIdx = idx
            break
        end
    end

    if targetProp and targetProp.original_x then
        -- 1. Удаляем перемещенный дубликат
        DB.DeletePlacedProp(id, function()
            table.remove(PlacedPropsCache, targetIdx)
            TriggerClientEvent("thehunt_builder:syncDeleteProp", -1, id)

            -- 2. Удаляем запись из черного списка удаленных объектов мира
            DB.RestoreWorldProp(targetProp.model_hash, targetProp.original_x, targetProp.original_y, targetProp.original_z, function()
                for dIdx, del in ipairs(DeletedPropsCache) do
                    if del.model_hash == targetProp.model_hash and math.abs(del.x - targetProp.original_x) < 2.5 and math.abs(del.y - targetProp.original_y) < 2.5 then
                        table.remove(DeletedPropsCache, dIdx)
                        break
                    end
                end
                TriggerClientEvent("thehunt_builder:syncRestoreWorldProp", -1, targetProp.model_hash, targetProp.original_x, targetProp.original_y, targetProp.original_z)
                print(string.format("^2[HUNT BUILDER] Объект мира успешно возвращен на исходную позицию админом %s^7", GetPlayerName(src)))
            end)
        end)
    end
end)

-- Прямое восстановление удаленного объекта мира по ID записи в thehunt_deleted_props
RegisterNetEvent("thehunt_builder:restoreDeletedWorldObjectDirect", function(deletedId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local id = tonumber(deletedId)
    if not id then return end

    local targetDel = nil
    local targetIdx = nil
    for idx, del in ipairs(DeletedPropsCache) do
        if del.id == id then
            targetDel = del
            targetIdx = idx
            break
        end
    end

    if targetDel then
        if exports.oxmysql then
            exports.oxmysql:execute('DELETE FROM thehunt_deleted_props WHERE id = ?', { id }, function()
                table.remove(DeletedPropsCache, targetIdx)
                TriggerClientEvent("thehunt_builder:syncRestoreWorldProp", -1, targetDel.model_hash, targetDel.x, targetDel.y, targetDel.z)
                print(string.format("^2[HUNT BUILDER] Объект мира #%d восстановлен на карте админом %s^7", id, GetPlayerName(src)))
            end)
        end
    end
end)

-- Удаление статического объекта мира (занесение в черный список)
RegisterNetEvent("thehunt_builder:deleteWorldStaticObject", function(modelHash, x, y, z)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local deletedItem = {
        model_hash = modelHash,
        x = x,
        y = y,
        z = z,
        deleted_by = GetPlayerName(src)
    }

    DB.SaveDeletedWorldProp(modelHash, x, y, z, GetPlayerName(src), function(insertId)
        deletedItem.id = insertId
        table.insert(DeletedPropsCache, deletedItem)
        TriggerClientEvent("thehunt_builder:syncDeleteWorldProp", -1, deletedItem)
        print(string.format("^1[HUNT BUILDER] Статический объект мира (Hash: %s) навсегда удален админом %s^7", tostring(modelHash), GetPlayerName(src)))
    end)
end)

-- Удаление кастомного объекта по ID (включая подбор предмета в инвентарь)
local function DeletePlacedPropInternal(propId)
    local id = tonumber(propId)
    if not id then return end

    DB.DeletePlacedProp(id, function()
        for idx, p in ipairs(PlacedPropsCache) do
            if p.id == id then
                table.remove(PlacedPropsCache, idx)
                break
            end
        end
        TriggerClientEvent("thehunt_builder:syncDeleteProp", -1, id)
    end)
end

RegisterNetEvent("thehunt_builder:deletePlacedObjectDirectly", DeletePlacedPropInternal)
AddEventHandler("thehunt_builder:deletePlacedObjectDirectly", DeletePlacedPropInternal)

-- API Экспорт для систем крафта / инвентаря (разрешает игрокам ставить палатки/костры)
exports('StartPlayerPlacement', function(source, modelHash, metadata, callbackEvent)
    TriggerClientEvent("thehunt_builder:startPlayerPlacementClient", source, modelHash, metadata, callbackEvent)
end)

exports('GetPropById', function(propId)
    local id = tonumber(propId)
    if not id then return nil end
    for _, p in ipairs(PlacedPropsCache) do
        if p.id == id then
            return p
        end
    end
    return nil
end)

exports('UpdatePlacedPropMetadata', function(propId, metadata)
    local id = tonumber(propId)
    if not id then return end
    for _, p in ipairs(PlacedPropsCache) do
        if p.id == id then
            p.metadata = metadata
            break
        end
    end
    DB.UpdatePlacedPropMetadata(id, metadata)
end)

exports('CreatePlacedProp', function(propData, cb)
    if not propData or not propData.model_hash or not propData.x or not propData.y or not propData.z then
        if cb then cb(nil) end
        return nil
    end

    local newProp = {
        model_name = propData.model_name or "prop",
        model_hash = tonumber(propData.model_hash),
        item_name = propData.item_name or nil,
        metadata = propData.metadata or nil,
        x = tonumber(propData.x) + 0.0,
        y = tonumber(propData.y) + 0.0,
        z = tonumber(propData.z) + 0.0,
        rot_x = tonumber(propData.rot_x or 0.0) + 0.0,
        rot_y = tonumber(propData.rot_y or 0.0) + 0.0,
        rot_z = tonumber(propData.rot_z or 0.0) + 0.0,
        original_x = propData.original_x and (tonumber(propData.original_x) + 0.0) or nil,
        original_y = propData.original_y and (tonumber(propData.original_y) + 0.0) or nil,
        original_z = propData.original_z and (tonumber(propData.original_z) + 0.0) or nil,
        original_rx = propData.original_rx and (tonumber(propData.original_rx) + 0.0) or nil,
        original_ry = propData.original_ry and (tonumber(propData.original_ry) + 0.0) or nil,
        original_rz = propData.original_rz and (tonumber(propData.original_rz) + 0.0) or nil,
        owner = propData.owner or "ADMIN",
        is_protected = (propData.is_protected == 1 or propData.is_protected == true) and 1 or 0,
        is_admin_prop = (propData.is_admin_prop == 1 or propData.is_admin_prop == true) and 1 or 0
    }

    DB.SavePlacedProp(newProp, function(insertId)
        if insertId then
            newProp.id = insertId
            table.insert(PlacedPropsCache, newProp)
            TriggerClientEvent("thehunt_builder:syncNewProp", -1, newProp)
            if cb then cb(insertId, newProp) end
        else
            if cb then cb(nil) end
        end
    end)
end)

exports('DeletePlacedProp', function(propId, cb)
    local id = tonumber(propId)
    if not id then
        if cb then cb(false) end
        return
    end

    DeletePlacedPropInternal(id)
    if cb then cb(true) end
end)

local function SqlBackupValue(value)
    if value == nil then return "NULL" end
    if type(value) == "number" then return tostring(value) end

    local text = tostring(value)
    text = text:gsub("\\", "\\\\")
    text = text:gsub("\0", "\\0")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\'", "\'\'")
    return "'" .. text .. "'"
end

local function BuildBackupInsert(tableName, columns, rows)
    local quotedColumns = {}
    for _, column in ipairs(columns) do
        quotedColumns[#quotedColumns + 1] = "`" .. column .. "`"
    end

    if #rows == 0 then
        return string.format("-- `%s` is empty in this backup.\n", tableName)
    end

    local values = {}
    for _, row in ipairs(rows) do
        local rowValues = {}
        for _, column in ipairs(columns) do
            rowValues[#rowValues + 1] = SqlBackupValue(row[column])
        end
        values[#values + 1] = "    (" .. table.concat(rowValues, ", ") .. ")"
    end

    local updates = {}
    for index = 2, #columns do
        local column = columns[index]
        updates[#updates + 1] = "`" .. column .. "` = VALUES(`" .. column .. "`)"
    end

    return string.format(
        "INSERT INTO `%s` (%s) VALUES\n%s\nON DUPLICATE KEY UPDATE %s;\n",
        tableName,
        table.concat(quotedColumns, ", "),
        table.concat(values, ",\n"),
        table.concat(updates, ", ")
    )
end

local function BuildBuilderBackupSql(placedRows, deletedRows)
    local placedColumns = {
        "id", "model_name", "model_hash", "item_name", "metadata",
        "x", "y", "z", "rot_x", "rot_y", "rot_z",
        "original_x", "original_y", "original_z", "original_rx", "original_ry", "original_rz",
        "owner_identifier", "is_protected", "is_admin_prop", "move_token", "created_at"
    }
    local deletedColumns = { "id", "model_hash", "x", "y", "z", "deleted_by", "deleted_at" }

    local lines = {
        "-- HUNT Builder database backup",
        "-- Generated at: " .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
        "-- This backup is non-destructive when imported: rows are upserted by primary key.",
        "SET NAMES utf8mb4;",
        "START TRANSACTION;",
        "",
        [[CREATE TABLE IF NOT EXISTS `thehunt_placed_props` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `model_name` VARCHAR(64) NOT NULL,
    `model_hash` BIGINT NOT NULL,
    `item_name` VARCHAR(64) DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `rot_x` FLOAT DEFAULT 0.0,
    `rot_y` FLOAT DEFAULT 0.0,
    `rot_z` FLOAT DEFAULT 0.0,
    `original_x` FLOAT DEFAULT NULL,
    `original_y` FLOAT DEFAULT NULL,
    `original_z` FLOAT DEFAULT NULL,
    `original_rx` FLOAT DEFAULT NULL,
    `original_ry` FLOAT DEFAULT NULL,
    `original_rz` FLOAT DEFAULT NULL,
    `owner_identifier` VARCHAR(64) DEFAULT 'ADMIN',
    `is_protected` TINYINT DEFAULT 0,
    `is_admin_prop` TINYINT DEFAULT 1,
    `move_token` VARCHAR(64) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
        "",
        [[CREATE TABLE IF NOT EXISTS `thehunt_deleted_props` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `model_hash` BIGINT NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `deleted_by` VARCHAR(64) DEFAULT 'ADMIN',
    `deleted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]],
        "",
        BuildBackupInsert("thehunt_placed_props", placedColumns, placedRows),
        BuildBackupInsert("thehunt_deleted_props", deletedColumns, deletedRows),
        "COMMIT;",
        ""
    }
    return table.concat(lines, "\n")
end

RegisterNetEvent("thehunt_builder:backupDatabase", function()
    local src = source
    if not IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_status:notify", src, "Builder", "Недостаточно прав для создания бэкапа.", "error", 3000)
        return
    end
    if builderBackupInProgress then
        TriggerClientEvent("thehunt_status:notify", src, "Builder", "Бэкап уже создаётся. Подождите.", "warning", 3000)
        return
    end

    builderBackupInProgress = true
    DB.GetBackupRows(function(placedRows, deletedRows)
        if not placedRows or not deletedRows then
            builderBackupInProgress = false
            print("^1[HUNT BUILDER] Не удалось прочитать таблицы для бэкапа.^7")
            TriggerClientEvent("thehunt_status:notify", src, "Builder", "Не удалось прочитать таблицы builder-а.", "error", 4000)
            return
        end

        builderBackupSequence = builderBackupSequence + 1
        local fileName = string.format(
            "backups/builder_%s_%03d.sql",
            os.date("%Y%m%d_%H%M%S"),
            builderBackupSequence
        )
        local sql = BuildBuilderBackupSql(placedRows, deletedRows)
        SaveResourceFile(GetCurrentResourceName(), fileName, sql, #sql)
        local written = LoadResourceFile(GetCurrentResourceName(), fileName)
        local success = written == sql
        builderBackupInProgress = false

        if not success then
            print("^1[HUNT BUILDER] Файл бэкапа не прошёл проверку после записи: " .. fileName .. "^7")
            TriggerClientEvent("thehunt_status:notify", src, "Builder", "Бэкап не удалось проверить после записи.", "error", 4000)
            return
        end

        print(string.format(
            "^2[HUNT BUILDER] Бэкап БД создан: %s (установленных: %d, скрытых мировых: %d)^7",
            fileName, #placedRows, #deletedRows
        ))
        TriggerClientEvent(
            "thehunt_status:notify",
            src,
            "Builder",
            string.format("Бэкап создан: %s | установленных: %d, скрытых мировых: %d", fileName, #placedRows, #deletedRows),
            "success",
            7000
        )
    end)
end)
