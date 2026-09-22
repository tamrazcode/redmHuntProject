-- =================================================================
-- HUNT: Единый журнал активности игроков
-- JSONL-файл: одна JSON-запись на строку, время отображается в MSK.
-- =================================================================

-- Защита от повторного выполнения: server.lua имеет резервный загрузчик
-- для случаев, когда CFX не подхватывает новый server_script из manifest.
-- Флаг выставляется только после полной регистрации обработчиков ниже.
if HUNT_PLAYER_LOGS_LOADED == true then return end

local PlayerLogsConfig = Config.PlayerLogs or {}
local PlayerLogFile = PlayerLogsConfig.File or "logs/player_activity.log"
local PlayerLogRetentionDays = tonumber(PlayerLogsConfig.RetentionDays) or 30
local PlayerLogPageSize = tonumber(PlayerLogsConfig.PageSize) or 100
PlayerLogPageSize = math.max(25, math.min(PlayerLogPageSize, 200))

local ActivityLogs = {}
local SerializedActivityLogLines = {}
local NextActivityId = 0
local SaveQueued = false
local SaveRequiresFullRewrite = false
local PendingVorpDeaths = {}
local LOG_SAVE_DEBOUNCE_MS = 3000

local LogTypes = {
    connection = { label = "ПОДКЛЮЧЕНИЕ", css = "connection" },
    disconnect = { label = "ОТКЛЮЧЕНИЕ", css = "disconnect" },
    chat_ooc = { label = "OOC", css = "ooc" },
    chat_me = { label = "/ME", css = "me" },
    chat_mes = { label = "/MES", css = "mes" },
    chat_mew = { label = "/MEW", css = "mew" },
    chat_dice = { label = "/DICE", css = "dice" },
    command = { label = "КОМАНДА", css = "command" },
    death = { label = "СМЕРТЬ", css = "death" },
    kill = { label = "УБИЙСТВО", css = "kill" },
    admin_action = { label = "АДМИН-ДЕЙСТВИЕ", css = "admin" },
    security = { label = "БЕЗОПАСНОСТЬ", css = "security" },
}

local RussianUpperToLower = {
    ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г", ["Д"] = "д",
    ["Е"] = "е", ["Ё"] = "ё", ["Ж"] = "ж", ["З"] = "з", ["И"] = "и",
    ["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м", ["Н"] = "н",
    ["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
    ["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч",
    ["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ", ["Ы"] = "ы", ["Ь"] = "ь",
    ["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
}

local function SafeString(value, maxLength)
    local result = tostring(value or "")
    result = result:gsub("\r", " "):gsub("\n", " "):gsub("%z", " ")

    if maxLength and #result > maxLength then
        result = result:sub(1, maxLength)
    end

    return result
end

local function LowerText(value)
    local result = string.lower(tostring(value or ""))
    for upper, lower in pairs(RussianUpperToLower) do
        result = result:gsub(upper, lower)
    end
    return result
end

local DeathCauseInfo = {
    -- GetPedCauseOfDeath returns a damage/weapon cause hash.
    [3049642225] = { name = "Аллигатор", text = "Аллигатора", killerType = "mob" }, -- 0xB5C5D8F1
    [148160082] = { name = "Пума", text = "Пумы", killerType = "mob" }, -- 0x08D4BE52
    [4194021054] = { name = "Животное", text = "животного", killerType = "mob" }, -- 0xF9FBAEBE
    [3452007600] = { name = "Падение", text = "падения", killerType = "environment" }, -- 0xCDC174B0
}

local function NormalizeHash(value)
    local number = tonumber(value) or 0
    if number < 0 then
        number = number + 4294967296
    end
    return number
end

local function GetDeathCauseInfo(cause)
    return DeathCauseInfo[NormalizeHash(cause)]
end

local function FormatMoscowTime(timestamp)
    local value = tonumber(timestamp) or os.time()
    return os.date("!%Y-%m-%d %H:%M:%S", value + (3 * 60 * 60)) .. " MSK"
end

local function NormalizeLogDate(value)
    local date = SafeString(value, 10)
    local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)

    if not year or year < 1 or year > 9999 or not month or month < 1 or month > 12 or not day or day < 1 then
        return ""
    end

    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
        daysInMonth[2] = 29
    end
    if day > daysInMonth[month] then return "" end

    return string.format("%04d-%02d-%02d", year, month, day)
end

local function GetIdentifierValues(source)
    local values = {}
    if not source or tonumber(source) == 0 then
        return values
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source) or {}) do
        local value = SafeString(identifier, 160)
        values[#values + 1] = value
    end

    return values
end

local function GetIdentifierByPrefix(identifiers, prefix)
    for _, identifier in ipairs(identifiers) do
        if string.sub(identifier, 1, #prefix) == prefix then
            return identifier
        end
    end
    return nil
end

local function GetCharacterNameSafe(source)
    local ok, name = pcall(function()
        return GetPlayerRPName(source)
    end)

    if ok and name then
        return SafeString(name, 120)
    end

    return "Не выбран"
end

local function BuildActor(source)
    local playerId = tonumber(source) or 0
    if playerId == 0 then
        return {
            key = "server",
            identityKeys = { "server" },
            sourceId = 0,
            redmName = "Сервер",
            platform = "Сервер",
            platformId = "server",
            characterName = "Система",
        }
    end

    local identifiers = GetIdentifierValues(playerId)
    local license = GetIdentifierByPrefix(identifiers, "license:")
    local license2 = GetIdentifierByPrefix(identifiers, "license2:")
    local fivem = GetIdentifierByPrefix(identifiers, "fivem:")
    local steam = GetIdentifierByPrefix(identifiers, "steam:")

    local identityKeys = {}
    local identityCandidates = { license2, license, fivem, steam }
    -- Не используем #identityCandidates: в Lua длина таблицы с nil в
    -- начале не определена, из-за чего часть игроков теряла ключи поиска.
    for index = 1, 4 do
        local identifier = identityCandidates[index]
        if identifier then
            identityKeys[#identityKeys + 1] = identifier
        end
    end

    local primaryKey = identityKeys[1] or ("source:" .. tostring(playerId))
    local platform = fivem and "FiveM" or (steam and "Steam" or "RedM")
    local platformId = fivem or steam or license2 or license or primaryKey

    return {
        key = primaryKey,
        identityKeys = identityKeys,
        sourceId = playerId,
        redmName = SafeString(GetPlayerName(playerId) or ("Игрок #" .. tostring(playerId)), 120),
        platform = platform,
        platformId = SafeString(platformId, 160),
        characterName = GetCharacterNameSafe(playerId),
    }
end

local function AttachActor(entry, prefix, actor)
    if not actor then return end

    entry[prefix .. "Key"] = actor.key
    entry[prefix .. "SourceId"] = actor.sourceId
    entry[prefix .. "RedmName"] = actor.redmName
    entry[prefix .. "Platform"] = actor.platform
    entry[prefix .. "CharacterName"] = actor.characterName
end

local function ScheduleSave()
    if SaveQueued then return end
    SaveQueued = true

    SetTimeout(LOG_SAVE_DEBOUNCE_MS, function()
        SaveQueued = false

        if SaveRequiresFullRewrite then
            local lines = {}
            for _, entry in ipairs(ActivityLogs) do
                local ok, encoded = pcall(json.encode, entry)
                if ok and encoded then
                    lines[#lines + 1] = encoded
                end
            end
            SerializedActivityLogLines = lines
            SaveRequiresFullRewrite = false
        end

        local payload = table.concat(SerializedActivityLogLines, "\n")
        if #payload > 0 then
            payload = payload .. "\n"
        end

        SaveResourceFile(GetCurrentResourceName(), PlayerLogFile, payload, -1)
    end)
end

local function LoadActivityLogs()
    local content = LoadResourceFile(GetCurrentResourceName(), PlayerLogFile)
    if not content then
        -- Создаём файл при первом запуске, чтобы журнал был доступен даже
        -- до появления первой записи активности.
        SaveResourceFile(GetCurrentResourceName(), PlayerLogFile, "", -1)
        return
    end
    if content == "" then return end

    local cutoff = os.time() - (PlayerLogRetentionDays * 24 * 60 * 60)
    local removedOldEntries = false
    local enrichedEntries = false

    for line in content:gmatch("[^\r\n]+") do
        if string.sub(line, 1, 1) == "{" then
            local ok, entry = pcall(json.decode, line)
            if ok and type(entry) == "table" and tonumber(entry.ts) then
                if tonumber(entry.ts) >= cutoff then
                    local causeInfo = entry.type == "death" and GetDeathCauseInfo(entry.cause) or nil
                    if causeInfo then
                        if entry.causeName ~= causeInfo.name then
                            entry.causeName = causeInfo.name
                            enrichedEntries = true
                        end

                        -- Older records only had a generic text and the cause hash.
                        -- Enrich them when the hash is sufficient to identify the cause.
                        if causeInfo.killerType == "mob" and (entry.killerType == nil or entry.killerType == "none") then
                            entry.killerType = "mob"
                            entry.killerModelName = causeInfo.name
                            entry.text = string.format("Персонаж погиб от %s", causeInfo.text)
                            enrichedEntries = true
                        elseif causeInfo.killerType == "environment" and (entry.killerType == nil or entry.killerType == "none") then
                            entry.killerType = "environment"
                            entry.text = string.format("Персонаж погиб от %s", causeInfo.text)
                            enrichedEntries = true
                        end
                    end
                    ActivityLogs[#ActivityLogs + 1] = entry
                    SerializedActivityLogLines[#SerializedActivityLogLines + 1] = line
                    NextActivityId = math.max(NextActivityId, tonumber(entry.id) or 0)
                else
                    removedOldEntries = true
                end
            end
        end
    end

    if removedOldEntries or enrichedEntries then
        SaveRequiresFullRewrite = true
        ScheduleSave()
    end
end

local function PruneActivityLogs()
    local cutoff = os.time() - (PlayerLogRetentionDays * 24 * 60 * 60)
    local removed = false
    local kept = {}

    for _, entry in ipairs(ActivityLogs) do
        if tonumber(entry.ts) and tonumber(entry.ts) < cutoff then
            removed = true
        else
            kept[#kept + 1] = entry
        end
    end

    if removed then
        ActivityLogs = kept
        SaveRequiresFullRewrite = true
    end

    if removed then
        ScheduleSave()
    end
end

local function GetTypeMeta(category)
    return LogTypes[category] or { label = string.upper(tostring(category or "ЛОГ")), css = "default" }
end

local function CreateActivityLog(source, category, message, details)
    local actor = BuildActor(source)
    NextActivityId = NextActivityId + 1
    local timestamp = os.time()

    local entry = {
        id = NextActivityId,
        ts = timestamp,
        time = FormatMoscowTime(timestamp),
        type = SafeString(category, 40),
        playerKey = actor.key,
        identityKeys = actor.identityKeys,
        sourceId = actor.sourceId,
        redmName = actor.redmName,
        platform = actor.platform,
        platformId = actor.platformId,
        characterName = actor.characterName,
        text = SafeString(message, 1200),
    }

    if type(details) == "table" then
        for key, value in pairs(details) do
            if type(value) == "string" then
                entry[SafeString(key, 40)] = SafeString(value, 500)
            elseif type(value) == "number" or type(value) == "boolean" then
                entry[SafeString(key, 40)] = value
            end
        end
    end

    ActivityLogs[#ActivityLogs + 1] = entry
    local encodedOk, encodedEntry = pcall(json.encode, entry)
    if encodedOk and encodedEntry then
        SerializedActivityLogLines[#SerializedActivityLogLines + 1] = encodedEntry
    else
        SaveRequiresFullRewrite = true
    end
    ScheduleSave()
    return entry
end

-- Public server-side API for other HUNT resources.
function LogPlayerActivity(source, category, message, details)
    return CreateActivityLog(source, category, message, details)
end

exports("LogPlayerActivity", LogPlayerActivity)

local function BuildSearchText(entry)
    local ok, encoded = pcall(json.encode, entry)
    local raw = table.concat({
        tostring(entry.ts or ""),
        tostring(entry.type or ""),
        tostring(entry.sourceId or ""),
        tostring(entry.redmName or ""),
        tostring(entry.platform or ""),
        tostring(entry.characterName or ""),
        tostring(entry.text or ""),
        ok and (encoded or "") or "",
        FormatMoscowTime(entry.ts),
    }, " ")

    return LowerText(raw)
end

local function EntryBelongsToActor(entry, actor)
    if entry.playerKey == actor.key then
        return true
    end

    for _, entryKey in ipairs(entry.identityKeys or {}) do
        for _, actorKey in ipairs(actor.identityKeys or {}) do
            if entryKey == actorKey then
                return true
            end
        end
    end

    return #actor.identityKeys == 0 and tonumber(entry.sourceId) == actor.sourceId
end

local function BuildNuiLog(entry)
    local typeMeta = GetTypeMeta(entry.type)
    return {
        id = tonumber(entry.id) or 0,
        timestamp = tonumber(entry.ts) or 0,
        time = FormatMoscowTime(entry.ts),
        type = entry.type,
        typeLabel = typeMeta.label,
        typeClass = typeMeta.css,
        text = SafeString(entry.text, 1200),
        sourceId = tonumber(entry.sourceId) or 0,
        redmName = SafeString(entry.redmName, 120),
        platform = SafeString(entry.platform, 30),
        characterName = SafeString(entry.characterName, 120),
        targetSourceId = tonumber(entry.targetSourceId),
        targetRedmName = SafeString(entry.targetRedmName, 120),
        targetCharacterName = SafeString(entry.targetCharacterName, 120),
        killerType = SafeString(entry.killerType, 20),
        killerModelName = SafeString(entry.killerModelName, 120),
        cause = tonumber(entry.cause),
        causeName = SafeString(entry.causeName, 120),
    }
end

-- Записи команд, введённых именно через чат. RP-команды ниже логируются
-- более информативными типами chat_me/chat_mes/chat_mew/chat_dice.
RegisterNetEvent("thehunt_logs:recordCommandInput", function(rawCommand)
    local sourceId = source
    local commandText = SafeString(rawCommand, 1200)
    if commandText == "" then return end

    local commandName = string.lower(commandText:match("^/?([^%s]+)") or "")
    local rpCommands = {
        me = true, mes = true, s = true,
        mew = true, w = true,
        dice = true, roll = true,
    }

    if rpCommands[commandName] then return end

    LogPlayerActivity(sourceId, "command", commandText, {
        command = commandName,
    })
end)

-- Смерть игрока. Источник убийцы определяется на клиенте по игровому педу,
-- а имя/персонаж убийцы повторно разрешаются здесь на сервере.
local function RecordPlayerDeath(victimSource, data)
    if type(data) ~= "table" then data = {} end

    local killerId = tonumber(data.killerId) or 0
    local killerType = SafeString(data.killerType, 20)
    local killerModel = tonumber(data.killerModel) or 0
    local killerModelName = SafeString(data.killerModelName, 120)
    local cause = tonumber(data.cause) or 0
    local causeName = SafeString(data.causeName, 120)
    local causeInfo = GetDeathCauseInfo(cause)
    local killer = nil

    if causeName == "" and causeInfo then
        causeName = causeInfo.name
    end

    if killerType == "" and causeInfo then
        killerType = causeInfo.killerType
    end

    if killerType == "none" and causeInfo and causeInfo.killerType == "mob" then
        killerType = "mob"
        killerModelName = causeInfo.name
    elseif killerType == "none" and causeInfo and causeInfo.killerType == "environment" then
        killerType = "environment"
    end

    if data.isSuicide == true then
        killerType = "suicide"
    end

    -- Самоубийство иногда приходит от клиента как playerId самой жертвы.
    -- Нельзя создавать для такого случая запись об убийстве.
    if killerId == victimSource then
        killerId = 0
        killerType = "suicide"
    end

    if killerType == "player" and killerId > 0 and GetPlayerName(killerId) then
        killer = BuildActor(killerId)
    else
        killerId = 0
    end

    local victim = BuildActor(victimSource)
    local deathText
    if killer then
        deathText = string.format(
            "Персонаж погиб от игрока #%d (%s)",
            killer.sourceId,
            killer.characterName
        )
    elseif killerType == "mob" then
        if killerModelName ~= "" then
            deathText = string.format("Персонаж погиб от %s", killerModelName)
        elseif causeInfo and causeInfo.killerType == "mob" then
            deathText = string.format("Персонаж погиб от %s", causeInfo.text)
        else
            deathText = "Персонаж погиб от моба/НПС"
        end
    elseif killerType == "suicide" then
        deathText = "Персонаж погиб в результате суицида"
    elseif killerType == "environment" and causeInfo then
        deathText = string.format("Персонаж погиб от %s", causeInfo.text)
    else
        deathText = "Персонаж погиб от окружения или неизвестной причины"
    end

    local deathEntry = CreateActivityLog(victimSource, "death", deathText, {
        killerType = killer and "player" or killerType,
        killerModel = killerModel,
        killerModelName = killerModelName,
        causeName = causeName,
        cause = cause,
        isSuicide = data.isSuicide == true,
    })

    if killer then
        AttachActor(deathEntry, "killer", killer)

        local killText = string.format(
            "Убийство персонажа #%d (%s)",
            victim.sourceId,
            victim.characterName
        )
        local killEntry = CreateActivityLog(killer.sourceId, "kill", killText, {
            victimSourceId = victim.sourceId,
            victimRedmName = victim.redmName,
            victimCharacterName = victim.characterName,
            weaponCause = cause,
        })
        AttachActor(killEntry, "victim", victim)
    end
end

RegisterNetEvent("thehunt_logs:playerDeath", function(data)
    local victimSource = source
    PendingVorpDeaths[victimSource] = nil
    RecordPlayerDeath(victimSource, data)
end)

-- VORP вызывает это событие при любой смерти. Если подробное клиентское
-- событие не дошло, сохраняем хотя бы факт смерти и причину через fallback.
RegisterNetEvent("vorp_core:Server:OnPlayerDeath", function(killerServerId, deathCause)
    local victimSource = source
    local token = tostring(victimSource) .. ":" .. tostring(os.time()) .. ":" .. tostring(math.random(1, 2147483647))
    PendingVorpDeaths[victimSource] = token

    -- Give the client enough time to send the detailed event with the animal ped
    -- and the IsSuicide flag before writing the server-only fallback.
    SetTimeout(2500, function()
        if PendingVorpDeaths[victimSource] ~= token then return end
        PendingVorpDeaths[victimSource] = nil

        RecordPlayerDeath(victimSource, {
            killerId = tonumber(killerServerId) or 0,
            killerType = tonumber(killerServerId) and tonumber(killerServerId) > 0 and "player" or "none",
            cause = tonumber(deathCause) or 0,
        })
    end)
end)

-- Подключения и отключения полезны при разборе спорных ситуаций и не требуют
-- участия клиента, поэтому считаются серверными записями.
AddEventHandler("playerJoining", function()
    LogPlayerActivity(source, "connection", "Игрок подключился к серверу")
end)

AddEventHandler("playerDropped", function(reason)
    LogPlayerActivity(source, "disconnect", "Игрок отключился от сервера", {
        reason = SafeString(reason, 300),
    })
end)

RegisterNetEvent("thehunt_admin:getPlayerLogs", function(targetId, query, offset, limit, requestId, snapshotId, dateFromInput, dateToInput)
    local adminSource = source
    local playerId = tonumber(targetId) or 0
    local pageOffset = math.max(0, math.floor(tonumber(offset) or 0))
    local pageSize = math.floor(tonumber(limit) or PlayerLogPageSize)
    pageSize = math.max(25, math.min(pageSize, PlayerLogPageSize))
    local logSnapshotId = math.max(0, math.floor(tonumber(snapshotId) or 0))
    if logSnapshotId == 0 then logSnapshotId = NextActivityId end
    local dateFrom = NormalizeLogDate(dateFromInput)
    local dateTo = NormalizeLogDate(dateToInput)
    if dateFrom ~= "" and dateTo ~= "" and dateFrom > dateTo then
        dateFrom, dateTo = dateTo, dateFrom
    end
    local function SendResult(payload)
        TriggerClientEvent("thehunt_admin:receivePlayerLogs", adminSource, payload)
    end

    local permissionOk, isAdmin = pcall(IsPlayerAdmin, adminSource)
    if not permissionOk or not isAdmin then
        if LogPlayerActivity then
            pcall(LogPlayerActivity, adminSource, "security", "Отклонён запрос логов без прав администратора")
        end
        SendResult({
            targetId = playerId,
            query = "",
            dateFrom = dateFrom,
            dateTo = dateTo,
            total = 0,
            returned = 0,
            offset = pageOffset,
            nextOffset = pageOffset,
            pageSize = pageSize,
            hasMore = false,
            requestId = requestId,
            snapshotId = logSnapshotId,
            logs = {},
            error = "Недостаточно прав для просмотра логов",
        })
        return
    end

    local ok, err = xpcall(function()
        local actor = playerId > 0 and BuildActor(playerId) or nil
        local searchQuery = LowerText(SafeString(query, 160))
        local result = {}
        local total = 0
        local matchedIndex = 0

        if actor and GetPlayerName(playerId) then
            for index = #ActivityLogs, 1, -1 do
                local entry = ActivityLogs[index]
                local entryDate = FormatMoscowTime(entry.ts):sub(1, 10)
                local matchesDate = (dateFrom == "" or entryDate >= dateFrom) and (dateTo == "" or entryDate <= dateTo)
                if (tonumber(entry.id) or 0) <= logSnapshotId and matchesDate and EntryBelongsToActor(entry, actor) and (searchQuery == "" or string.find(BuildSearchText(entry), searchQuery, 1, true)) then
                    total = total + 1
                    matchedIndex = matchedIndex + 1
                    if matchedIndex > pageOffset and #result < pageSize then
                        result[#result + 1] = BuildNuiLog(entry)
                    end
                end
            end
        end

        SendResult({
            targetId = playerId,
            target = actor and {
                sourceId = actor.sourceId,
                redmName = actor.redmName,
                platform = actor.platform,
                characterName = actor.characterName,
            } or nil,
            query = searchQuery,
            dateFrom = dateFrom,
            dateTo = dateTo,
            total = total,
            returned = #result,
            offset = pageOffset,
            nextOffset = pageOffset + #result,
            pageSize = pageSize,
            hasMore = total > (pageOffset + #result),
            requestId = requestId,
            snapshotId = logSnapshotId,
            logs = result,
        })
    end, function(errorMessage)
        return tostring(errorMessage)
    end)

    if not ok then
        print(string.format("^1[HUNT LOGS] Ошибка загрузки логов для #%d: %s^7", playerId, tostring(err)))
        SendResult({
            targetId = playerId,
            query = LowerText(SafeString(query, 160)),
            dateFrom = dateFrom,
            dateTo = dateTo,
            total = 0,
            returned = 0,
            offset = pageOffset,
            nextOffset = pageOffset,
            pageSize = pageSize,
            hasMore = false,
            requestId = requestId,
            snapshotId = logSnapshotId,
            logs = {},
            error = "Сервер не смог загрузить логи. Подробность записана в консоль.",
        })
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(0)
    LoadActivityLogs()
    print(string.format("^2[HUNT LOGS] Журнал активности загружен: %d записей, хранение %d дней^7", #ActivityLogs, PlayerLogRetentionDays))

    while true do
        Citizen.Wait(60 * 60 * 1000)
        PruneActivityLogs()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SaveQueued = false

    local lines = {}
    for _, entry in ipairs(ActivityLogs) do
        local ok, encoded = pcall(json.encode, entry)
        if ok and encoded then lines[#lines + 1] = encoded end
    end

    local payload = table.concat(lines, "\n")
    if #payload > 0 then payload = payload .. "\n" end
    SaveResourceFile(GetCurrentResourceName(), PlayerLogFile, payload, -1)
end)

-- Отмечаем модуль загруженным только после объявления всех обработчиков.
HUNT_PLAYER_LOGS_LOADED = true
