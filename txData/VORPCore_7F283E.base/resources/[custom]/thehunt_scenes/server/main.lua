-- =================================================================
-- HUNT: Hard RP — The Corruption | Scene Server Module
-- =================================================================

local DB = {}
local ActiveScenes = {} -- id -> scene table
local isInitialized = false

-- =================================================================
-- МОДУЛЬ БАЗЫ ДАННЫХ (MySQL)
-- =================================================================

Citizen.CreateThread(function()
    Citizen.Wait(500)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS thehunt_scenes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            text VARCHAR(500) NOT NULL,
            color VARCHAR(16) NOT NULL DEFAULT '#FFFFFF',
            color_idx INT DEFAULT 1,
            view_distance FLOAT DEFAULT 15.0,
            x FLOAT NOT NULL,
            y FLOAT NOT NULL,
            z FLOAT NOT NULL,
            rot_z FLOAT DEFAULT 0.0,
            creator_identifier VARCHAR(64) NOT NULL,
            creator_name VARCHAR(64) DEFAULT 'Неизвестно',
            creator_charid INT DEFAULT 0,
            expires_at BIGINT NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print("^2[HUNT SCENES] База данных успешно инициализирована (таблица thehunt_scenes готова).^7")
        DB.GetActiveScenes(function(scenes)
            ActiveScenes = {}
            for _, s in ipairs(scenes) do
                ActiveScenes[s.id] = s
            end
            isInitialized = true
            print(string.format("^2[HUNT SCENES] Загружено активных сцен из БД: %d^7", #scenes))
        end)
    end)
end)

function DB.GetActiveScenes(callback)
    local now = os.time()
    local query = [[
        SELECT id, text, color, color_idx AS colorIdx, view_distance AS viewDistance,
               x, y, z, rot_z AS rotZ, creator_identifier AS creatorIdentifier,
               creator_name AS creatorName, creator_charid AS creatorCharId,
               expires_at AS expiresAt, UNIX_TIMESTAMP(created_at) AS createdAt
        FROM thehunt_scenes
        WHERE expires_at = 0 OR expires_at > ?
        ORDER BY id ASC
    ]]

    MySQL.query(query, { now }, function(rows)
        if callback then
            callback(rows or {})
        end
    end)
end

function DB.CreateScene(data, callback)
    local query = [[
        INSERT INTO thehunt_scenes 
        (text, color, color_idx, view_distance, x, y, z, rot_z, creator_identifier, creator_name, creator_charid, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    MySQL.insert(query, {
        data.text,
        data.color or '#FFFFFF',
        data.colorIdx or 1,
        data.viewDistance or 15.0,
        data.x,
        data.y,
        data.z,
        data.rotZ or 0.0,
        data.creatorIdentifier or 'UNKNOWN',
        data.creatorName or 'Игрок',
        data.creatorCharId or 0,
        data.expiresAt or 0
    }, function(insertId)
        if callback then callback(insertId) end
    end)
end

function DB.DeleteScene(sceneId, callback)
    MySQL.query('DELETE FROM thehunt_scenes WHERE id = ?', { sceneId }, function(res)
        if callback then callback(true) end
    end)
end

function DB.DeletePlayerScenes(identifier, callback)
    MySQL.query('DELETE FROM thehunt_scenes WHERE creator_identifier = ?', { identifier }, function(res)
        if callback then callback(true) end
    end)
end

function DB.CleanupExpiredScenes(callback)
    local now = os.time()
    MySQL.query('DELETE FROM thehunt_scenes WHERE expires_at > 0 AND expires_at <= ?', { now }, function(res)
        if callback then callback(true) end
    end)
end

-- =================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =================================================================

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

local function GetCharacterData(source)
    local identifier = GetPlayerIdentifier(source, 0) or "UNKNOWN"
    local charName = GetPlayerName(source) or "Неизвестный"
    local charId = 0

    local char = exports.thehunt_core:GetCharacter(source)
    if char then
        identifier = char.identifier or exports.thehunt_core:GetPlayerIdentifier(source) or identifier
        charId = char.charIdentifier or char.charid or 0
        local first = char.firstname or ""
        local last = char.lastname or ""
        if first ~= "" or last ~= "" then
            charName = string.format("%s %s", first, last)
        end
    end

    return identifier, charName, charId
end

local function CountPlayerScenes(identifier)
    local count = 0
    for _, scene in pairs(ActiveScenes) do
        if scene.creatorIdentifier == identifier then
            count = count + 1
        end
    end
    return count
end

-- =================================================================
-- ФОНОВАЯ ОЧИСТКА ИСТЕКШИХ СЦЕН
-- =================================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000)

        if isInitialized then
            local now = os.time()
            local expiredIds = {}

            for id, scene in pairs(ActiveScenes) do
                if scene.expiresAt and scene.expiresAt > 0 and scene.expiresAt <= now then
                    table.insert(expiredIds, id)
                end
            end

            if #expiredIds > 0 then
                for _, id in ipairs(expiredIds) do
                    ActiveScenes[id] = nil
                    TriggerClientEvent("thehunt_scenes:removeScene", -1, id)
                end
                DB.CleanupExpiredScenes()
            end
        end
    end
end)

-- =================================================================
-- СЕТЕВЫЕ СОБЫТИЯ
-- =================================================================

---Запрос списка всех активных сцен (при входе/спавне)
RegisterNetEvent("thehunt_scenes:requestScenes", function()
    local src = source
    local list = {}
    for _, s in pairs(ActiveScenes) do
        table.insert(list, s)
    end
    TriggerClientEvent("thehunt_scenes:receiveScenes", src, list)
end)

---Запрос списка моих сцен для меню /scenes
RegisterNetEvent("thehunt_scenes:requestMyScenesList", function()
    local src = source
    local identifier = GetCharacterData(src)
    local myList = {}

    for _, s in pairs(ActiveScenes) do
        if s.creatorIdentifier == identifier then
            table.insert(myList, s)
        end
    end

    TriggerClientEvent("thehunt_scenes:openMyScenesUI", src, myList)
end)

---Создание новой сцены
RegisterNetEvent("thehunt_scenes:createScene", function(data)
    local src = source
    if not data or not data.text or not data.x or not data.y or not data.z then
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "Некорректные данные для размещения", "error")
        return
    end

    local cleanText = tostring(data.text):gsub("^%s*(.-)%s*$", "%1")
    if cleanText == "" or string.len(cleanText) > (Config.MaxTextLength or 250) then
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "Недопустимая длина текста (1-250 символов)", "error")
        return
    end

    local identifier, charName, charId = GetCharacterData(src)
    local isAdmin = IsPlayerAdmin(src)

    -- Проверка лимита сцен для обычных игроков
    if not isAdmin and CountPlayerScenes(identifier) >= (Config.MaxPlayerScenes or 5) then
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", string.format("Вы достигли лимита сцен (%d макс.)", Config.MaxPlayerScenes or 5), "warning")
        return
    end

    local duration = tonumber(data.duration) or Config.DefaultDuration
    local expiresAt = 0
    if duration > 0 then
        expiresAt = os.time() + duration
    end

    local colorIdx = tonumber(data.colorIdx) or Config.DefaultColorIndex
    local colorData = Config.TextColors[colorIdx] or Config.TextColors[1]
    local viewDistance = tonumber(data.viewDistance) or Config.DefaultDistance

    local sceneData = {
        text = cleanText,
        color = colorData.hex,
        colorIdx = colorIdx,
        viewDistance = viewDistance,
        x = tonumber(data.x),
        y = tonumber(data.y),
        z = tonumber(data.z),
        rotZ = tonumber(data.rotZ) or 0.0,
        creatorIdentifier = identifier,
        creatorName = charName,
        creatorCharId = charId,
        expiresAt = expiresAt
    }

    DB.CreateScene(sceneData, function(insertId)
        local newId = tonumber(insertId) or math.random(10000, 99999)
        sceneData.id = newId
        ActiveScenes[newId] = sceneData

        -- Отправляем всем клиентам
        TriggerClientEvent("thehunt_scenes:newScene", -1, sceneData)
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "Сцена успешно создана и сохранена в мире", "success")
    end)
end)

---Удаление сцены по запросу игрока
RegisterNetEvent("thehunt_scenes:deleteScene", function(sceneId)
    local src = source
    local id = tonumber(sceneId)
    if not id or not ActiveScenes[id] then
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "Сцена не найдена", "error")
        return
    end

    local scene = ActiveScenes[id]
    local identifier = GetCharacterData(src)
    local isAdmin = IsPlayerAdmin(src)

    -- Удалить может только автор или администратор
    if scene.creatorIdentifier ~= identifier and not isAdmin then
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "Вы не можете удалить чужую сцену", "error")
        return
    end

    DB.DeleteScene(id, function(success)
        ActiveScenes[id] = nil
        TriggerClientEvent("thehunt_scenes:removeScene", -1, id)
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "Сцена удалена", "info")
    end)
end)

---Удаление всех своих сцен из UI (/scenes)
RegisterNetEvent("thehunt_scenes:deleteAllMyScenes", function()
    local src = source
    local identifier = GetCharacterData(src)

    local idsToRemove = {}
    for id, s in pairs(ActiveScenes) do
        if s.creatorIdentifier == identifier then
            table.insert(idsToRemove, id)
        end
    end

    if #idsToRemove == 0 then
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", "У вас нет активных сцен", "info")
        return
    end

    DB.DeletePlayerScenes(identifier, function(success)
        for _, id in ipairs(idsToRemove) do
            ActiveScenes[id] = nil
            TriggerClientEvent("thehunt_scenes:removeScene", -1, id)
        end
        TriggerClientEvent("thehunt_status:notify", src, "Сцены", string.format("Удалено ваших сцен: %d", #idsToRemove), "success")
    end)
end)

-- =================================================================
-- КОМАНДЫ ЧАТА
-- =================================================================

---Удаление всех своих сцен (/clearmyscenes)
RegisterCommand("clearmyscenes", function(source, args)
    if source == 0 then return end
    local identifier = GetCharacterData(source)

    local idsToRemove = {}
    for id, s in pairs(ActiveScenes) do
        if s.creatorIdentifier == identifier then
            table.insert(idsToRemove, id)
        end
    end

    if #idsToRemove == 0 then
        TriggerClientEvent("thehunt_status:notify", source, "Сцены", "У вас нет активных сцен", "info")
        return
    end

    DB.DeletePlayerScenes(identifier, function(affected)
        for _, id in ipairs(idsToRemove) do
            ActiveScenes[id] = nil
            TriggerClientEvent("thehunt_scenes:removeScene", -1, id)
        end
        TriggerClientEvent("thehunt_status:notify", source, "Сцены", string.format("Удалено ваших сцен: %d", #idsToRemove), "success")
    end)
end, false)

---Полная очистка мира администратором (/clearallscenes)
RegisterCommand("clearallscenes", function(source, args)
    if source ~= 0 and not IsPlayerAdmin(source) then
        TriggerClientEvent("thehunt_status:notify", source, "Сцены", "Недостаточно прав", "error")
        return
    end

    MySQL.query('TRUNCATE TABLE thehunt_scenes', {}, function()
        ActiveScenes = {}
        TriggerClientEvent("thehunt_scenes:receiveScenes", -1, {})
        if source ~= 0 then
            TriggerClientEvent("thehunt_status:notify", source, "Сцены", "Все сцены в мире были удалены", "success")
        end
        print("^2[HUNT SCENES] Все сцены были очищены администратором.^7")
    end)
end, false)
