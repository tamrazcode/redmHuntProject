-- =================================================================
-- HUNT: Hard RP — Animations Server Module (oxmysql)
-- =================================================================

-- Инициализация таблицы избранных и закрепленных анимаций
Citizen.CreateThread(function()
    Citizen.Wait(500)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `thehunt_animation_favorites` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(64) NOT NULL UNIQUE,
            `favorites` LONGTEXT NOT NULL DEFAULT '[]',
            `pinned` LONGTEXT NOT NULL DEFAULT '[]',
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        -- Гарантируем добавление колонки pinned, если таблица уже существовала ранее
        MySQL.query([[
            ALTER TABLE `thehunt_animation_favorites` ADD COLUMN IF NOT EXISTS `pinned` LONGTEXT NOT NULL DEFAULT '[]';
        ]], {}, function()
            print("^2[HUNT ANIMATIONS] База данных успешно инициализирована (таблица thehunt_animation_favorites готова к избранному и закреплению).^7")
        end)
    end)
end)

-- Broadcast prop cleanup so a networked animation object cannot remain visible
-- on clients that already streamed the owner. The owner supplies only network
-- ids of props it is currently removing; the clients additionally scan the
-- owner's hands for scenario-generated props.
RegisterNetEvent('thehunt_animations:server:cleanupProps', function(networkIds, reason)
    local safeNetworkIds = {}
    local seen = {}

    if type(networkIds) == 'table' then
        for _, value in ipairs(networkIds) do
            local netId = tonumber(value)
            if netId and netId > 0 and netId % 1 == 0 and not seen[netId] then
                seen[netId] = true
                safeNetworkIds[#safeNetworkIds + 1] = netId
                if #safeNetworkIds >= 32 then break end
            end
        end
    end

    TriggerClientEvent('thehunt_animations:client:cleanupProps', -1, source, safeNetworkIds, reason)
end)

-- Получение уникального идентификатора персонажа (с поддержкой слотов VORP / thehunt_character)
-- =================================================================
-- Networked pointing direction (the arm IK itself runs on each client)
-- =================================================================
local pointingOwners = {}
local pointingLastUpdate = {}

local function NormalizePointingDirection(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 2.0 or math.abs(y) > 2.0 or math.abs(z) > 2.0 then return nil end
    local length = math.sqrt((x * x) + (y * y) + (z * z))
    if length < 0.25 then return nil end
    return { x = x / length, y = y / length, z = z / length }
end

RegisterNetEvent('thehunt_animations:server:pointing:start', function(direction)
    local src = source
    local normalized = NormalizePointingDirection(direction)
    if not normalized then return end
    if pointingOwners[src] then return end
    pointingOwners[src] = true
    pointingLastUpdate[src] = GetGameTimer()
    TriggerClientEvent('thehunt_animations:client:pointing:start', -1, src, normalized)
end)

RegisterNetEvent('thehunt_animations:server:pointing:update', function(direction)
    local src = source
    if not pointingOwners[src] then return end

    local now = GetGameTimer()
    if pointingLastUpdate[src] and now - pointingLastUpdate[src] < 40 then return end
    local normalized = NormalizePointingDirection(direction)
    if not normalized then return end

    pointingLastUpdate[src] = now
    TriggerClientEvent('thehunt_animations:client:pointing:update', -1, src, normalized)
end)

RegisterNetEvent('thehunt_animations:server:pointing:stop', function()
    local src = source
    if not pointingOwners[src] then return end
    pointingOwners[src] = nil
    pointingLastUpdate[src] = nil
    TriggerClientEvent('thehunt_animations:client:pointing:stop', -1, src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if pointingOwners[src] then
        pointingOwners[src] = nil
        pointingLastUpdate[src] = nil
        TriggerClientEvent('thehunt_animations:client:pointing:stop', -1, src)
    end
end)

local function GetCharacterIdentifier(src)
    local fallback = GetPlayerIdentifier(src, 0) or "UNKNOWN"
    
    local char = exports.thehunt_core:GetCharacter(src)
    if char then
        local ident = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src) or fallback
        local charId = char.charIdentifier or char.charid or 0
        return string.format("%s:%d", ident, charId)
    end

    return fallback
end

-- Запрос на открытие меню и загрузка списка избранных и закрепленных анимаций
RegisterServerEvent('thehunt_animations:server:open', function()
    local src = source
    local identifier = GetCharacterIdentifier(src)

    MySQL.query('SELECT favorites, pinned FROM thehunt_animation_favorites WHERE identifier = ? LIMIT 1;', { identifier }, function(result)
        local favorites = {}
        local pinned = {}
        if result and result[1] then
            if result[1].favorites then
                local ok, decoded = pcall(json.decode, result[1].favorites)
                if ok and type(decoded) == 'table' then
                    favorites = decoded
                end
            end
            if result[1].pinned then
                local ok, decoded = pcall(json.decode, result[1].pinned)
                if ok and type(decoded) == 'table' then
                    pinned = decoded
                end
            end
        else
            MySQL.insert('INSERT INTO thehunt_animation_favorites (identifier, favorites, pinned) VALUES (?, ?, ?);', { identifier, '[]', '[]' })
        end

        TriggerClientEvent('thehunt_animations:client:open', src, favorites, pinned)
    end)
end)

-- Запрос закрепленных анимаций для радиального меню (при спавне персонажа)
RegisterServerEvent('thehunt_animations:server:requestPinned', function()
    local src = source
    local identifier = GetCharacterIdentifier(src)

    MySQL.query('SELECT pinned FROM thehunt_animation_favorites WHERE identifier = ? LIMIT 1;', { identifier }, function(result)
        local pinned = {}
        if result and result[1] and result[1].pinned then
            local ok, decoded = pcall(json.decode, result[1].pinned)
            if ok and type(decoded) == 'table' then
                pinned = decoded
            end
        end
        TriggerClientEvent('thehunt_animations:client:syncPinned', src, pinned)
    end)
end)

-- Добавление / удаление из избранного
RegisterServerEvent('thehunt_animations:server:toggleFavorite', function(animationLabel, isFavorite)
    local src = source
    if not animationLabel or type(animationLabel) ~= 'string' then return end

    local identifier = GetCharacterIdentifier(src)

    MySQL.query('SELECT favorites, pinned FROM thehunt_animation_favorites WHERE identifier = ? LIMIT 1;', { identifier }, function(result)
        local favorites = {}
        local pinned = {}
        if result and result[1] then
            if result[1].favorites then
                local ok, decoded = pcall(json.decode, result[1].favorites)
                if ok and type(decoded) == 'table' then
                    favorites = decoded
                end
            end
            if result[1].pinned then
                local ok, decoded = pcall(json.decode, result[1].pinned)
                if ok and type(decoded) == 'table' then
                    pinned = decoded
                end
            end
        end

        local foundIndex = nil
        for i, label in ipairs(favorites) do
            if label == animationLabel then
                foundIndex = i
                break
            end
        end

        local pinnedChanged = false
        if isFavorite then
            if not foundIndex then
                table.insert(favorites, animationLabel)
            end
        else
            if foundIndex then
                table.remove(favorites, foundIndex)
            end
            -- Если анимация удалена из избранного — автоматически открепляем ее из радиального меню
            for pIdx, pLabel in ipairs(pinned) do
                if pLabel == animationLabel then
                    table.remove(pinned, pIdx)
                    pinnedChanged = true
                    break
                end
            end
        end

        MySQL.update('INSERT INTO thehunt_animation_favorites (identifier, favorites, pinned) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE favorites = ?, pinned = ?;', {
            identifier, json.encode(favorites), json.encode(pinned), json.encode(favorites), json.encode(pinned)
        })

        if pinnedChanged then
            TriggerClientEvent('thehunt_animations:client:syncPinned', src, pinned)
        end
    end)
end)

-- Закрепление / открепление анимации для радиального меню (максимум 4 штуки)
RegisterServerEvent('thehunt_animations:server:togglePin', function(animationLabel, isPinned)
    local src = source
    if not animationLabel or type(animationLabel) ~= 'string' then return end

    local identifier = GetCharacterIdentifier(src)

    MySQL.query('SELECT favorites, pinned FROM thehunt_animation_favorites WHERE identifier = ? LIMIT 1;', { identifier }, function(result)
        local favorites = {}
        local pinned = {}
        if result and result[1] then
            if result[1].favorites then
                local ok, decoded = pcall(json.decode, result[1].favorites)
                if ok and type(decoded) == 'table' then
                    favorites = decoded
                end
            end
            if result[1].pinned then
                local ok, decoded = pcall(json.decode, result[1].pinned)
                if ok and type(decoded) == 'table' then
                    pinned = decoded
                end
            end
        end

        local foundIndex = nil
        for i, label in ipairs(pinned) do
            if label == animationLabel then
                foundIndex = i
                break
            end
        end

        if isPinned then
            if not foundIndex then
                if #pinned >= 4 then
                    TriggerClientEvent("thehunt_status:notify", src, "Быстрое меню", "Максимум 4 закрепленные анимации", "warning", true)
                    return
                end
                table.insert(pinned, animationLabel)
            end
        else
            if foundIndex then
                table.remove(pinned, foundIndex)
            end
        end

        MySQL.update('INSERT INTO thehunt_animation_favorites (identifier, favorites, pinned) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE pinned = ?;', {
            identifier, json.encode(favorites), json.encode(pinned), json.encode(pinned)
        })

        TriggerClientEvent('thehunt_animations:client:syncPinned', src, pinned)
    end)
end)
