-- =================================================================
-- Серверный RP-чат и OOC-роутинг
-- OOC: [ID] НикRedM: сообщение
-- /me, /mes, /mew, /dice: [ID] Незнакомец/Незнакомка: действие
-- =================================================================

local RussianUpperToLower = {
    ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г", ["Д"] = "д",
    ["Е"] = "е", ["Ё"] = "ё", ["Ж"] = "ж", ["З"] = "з", ["И"] = "и",
    ["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м", ["Н"] = "н",
    ["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
    ["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч",
    ["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ", ["Ы"] = "ы", ["Ь"] = "ь",
    ["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
}

local RussianLowerToUpper = {
    ["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г", ["д"] = "Д",
    ["е"] = "Е", ["ё"] = "Ё", ["ж"] = "Ж", ["з"] = "З", ["и"] = "И",
    ["й"] = "Й", ["к"] = "К", ["л"] = "Л", ["м"] = "М", ["н"] = "Н",
    ["о"] = "О", ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т",
    ["у"] = "У", ["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц", ["ч"] = "Ч",
    ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ", ["ы"] = "Ы", ["ь"] = "Ь",
    ["э"] = "Э", ["ю"] = "Ю", ["я"] = "Я",
}

local function ToLower(text)
    local res = string.lower(tostring(text or ""))
    for upper, lower in pairs(RussianUpperToLower) do
        res = res:gsub(upper, lower)
    end
    return res
end

local function FormatSentenceCase(text)
    if not text or text == "" then return "" end
    local lowered = ToLower(text)

    -- Поиск первого буквенного символа (латиница или кириллица)
    local prefix, ruChar, rest = lowered:match("^(.-)([\xD0\xD1][\x80-\xBF])(.*)$")
    local prefixAscii, asciiChar, restAscii = lowered:match("^(.-)([a-z])(.*)$")

    local res = lowered
    if ruChar and asciiChar then
        if #prefix <= #prefixAscii then
            local upperRu = RussianLowerToUpper[ruChar] or ruChar
            res = prefix .. upperRu .. rest
        else
            res = prefixAscii .. string.upper(asciiChar) .. restAscii
        end
    elseif ruChar then
        local upperRu = RussianLowerToUpper[ruChar] or ruChar
        res = prefix .. upperRu .. rest
    elseif asciiChar then
        res = prefixAscii .. string.upper(asciiChar) .. restAscii
    end

    -- Также переводим в заглавную букву после точки/восклицательного/вопросительного знака с пробелом
    res = res:gsub("([%.%!%?]%s+)([\xD0\xD1][\x80-\xBF])", function(punct, char)
        return punct .. (RussianLowerToUpper[char] or char)
    end)
    res = res:gsub("([%.%!%?]%s+)([a-z])", function(punct, char)
        return punct .. string.upper(char)
    end)

    return res
end

-- Универсальная функция рассылки сообщения и 3D-текста по радиусу
function BroadcastProximityRP(senderSource, distance, chatMessage, chatColor, text3D, color3D, customTemplate)
    local senderPed = GetPlayerPed(senderSource)
    if not DoesEntityExist(senderPed) then return end

    local senderCoords = GetEntityCoords(senderPed)
    local maxDistance = tonumber(distance) or 10.0

    for _, playerId in ipairs(GetPlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(senderCoords - targetCoords)

            if dist <= maxDistance then
                -- 1. Отправляем сообщение в чат
                if chatMessage then
                    local msgData = {
                        color = chatColor or { 255, 255, 255 },
                        multiline = true,
                        args = type(chatMessage) == 'table' and chatMessage or { chatMessage }
                    }
                    if customTemplate then
                        msgData.template = customTemplate
                    end
                    TriggerClientEvent('chat:addMessage', playerId, msgData)
                end

                -- 2. Отправляем 3D-текст над головой (начинается с большой буквы, далее маленькие)
                if text3D then
                    local formatted3D = FormatSentenceCase(text3D)
                    TriggerClientEvent('thehunt_rp:show3DText', playerId, senderSource, formatted3D, color3D or chatColor)
                end
            end
        end
    end
end

-- Отправка системного сообщения об ошибке
local function SendErrorMessage(source, text)
    TriggerClientEvent('chat:addMessage', source, {
        color = Config.Chat.Colors.Error,
        multiline = true,
        args = { text }
    })
end

-- Обработка обычного текста как локального OOC
-- Формат: (( [ID] НикRedM: сообщение ))
local function HandleOOCMessage(source, message)
    if not message or message == "" then return end
    if type(message) == "string" and message:sub(1, 1) == "/" then return end

    if LogPlayerActivity then
        LogPlayerActivity(source, "chat_ooc", message, {
            command = "OOC",
        })
    end

    -- Снимаем индикатор печати при отправке
    TriggerClientEvent("thehunt_chat:syncTyping", -1, source, false)

    local redmName = GetPlayerRedMName(source)
    local serverId = tostring(source)
    local chatMsg = string.format("(( [%s] %s: %s ))", serverId, redmName, message)
    local text3D  = string.format("(( %s ))", message)

    BroadcastProximityRP(
        source,
        Config.Chat.Distances.OOC,
        chatMsg,
        Config.Chat.Colors.OOC,
        text3D,
        Config.Chat.Colors.OOC
    )
end

-- Перехват обычных сообщений чата
AddEventHandler('chatMessage', function(source, author, message)
    if source and source > 0 then
        CancelEvent()
        HandleOOCMessage(source, message)
    end
end)

-- Перехват через хук chat ресурса
Citizen.CreateThread(function()
    Citizen.Wait(500)
    if exports.chat and exports.chat.registerMessageHook then
        exports.chat:registerMessageHook(function(source, outMessage, hookRef)
            if source and source > 0 then
                hookRef.cancel()
                local rawMessage = outMessage.args[#outMessage.args]
                HandleOOCMessage(source, rawMessage)
            end
        end)
    end
end)

-- =================================================================
-- ИНДИКАТОР ПЕЧАТИ (TYPING STATE SYNC)
-- =================================================================
RegisterNetEvent("thehunt_chat:setTyping", function(isTyping)
    local src = source
    TriggerClientEvent("thehunt_chat:syncTyping", -1, src, isTyping and true or false)
end)

AddEventHandler("playerDropped", function()
    local src = source
    TriggerClientEvent("thehunt_chat:syncTyping", -1, src, false)
end)


-- =================================================================
-- 1. /me [действие] — Действие персонажа (Незнакомец/Незнакомка)
-- =================================================================
RegisterCommand("me", function(source, args)
    if source == 0 then return end

    if #args == 0 then
        SendErrorMessage(source, "Используйте: /me [действие]")
        return
    end

    local rawAction = table.concat(args, " ")
    local action = FormatSentenceCase(rawAction)
    local strangerName = GetStrangerName(source)
    local serverId = tostring(source)

    local prefix = string.format("[%s] %s", serverId, strangerName)
    local col = Config.Chat.Colors.Me
    local template = string.format('<div class="chat-message" style="color: rgb(%d, %d, %d); font-weight: normal;"><b style="font-weight: 700;">{0}</b> {1}</div>', col[1], col[2], col[3])

    if LogPlayerActivity then
        LogPlayerActivity(source, "chat_me", action, {
            command = "/me",
        })
    end

    BroadcastProximityRP(
        source,
        Config.Chat.Distances.Me,
        { prefix, action },
        col,
        action,
        col,
        template
    )
end, false)


-- =================================================================
-- 2. /mes [действие] / /s [действие] — Крик (20м)
-- =================================================================
local function HandleShout(source, args)
    if source == 0 then return end

    if #args == 0 then
        SendErrorMessage(source, "Используйте: /mes [крик] или /s [крик]")
        return
    end

    local rawAction = table.concat(args, " ")
    local action = FormatSentenceCase(rawAction)
    local strangerName = GetStrangerName(source)
    local serverId = tostring(source)

    local prefix = string.format("[%s] %s:", serverId, strangerName)
    local shoutText = string.format("%s!", action)
    local col = Config.Chat.Colors.Mes
    local template = string.format('<div class="chat-message" style="color: rgb(%d, %d, %d); font-weight: normal;"><b style="font-weight: 700;">{0}</b> {1}</div>', col[1], col[2], col[3])

    if LogPlayerActivity then
        LogPlayerActivity(source, "chat_mes", action, {
            command = "/mes",
        })
    end

    BroadcastProximityRP(
        source,
        Config.Chat.Distances.Mes,
        { prefix, shoutText },
        col,
        shoutText,
        col,
        template
    )
end

RegisterCommand("mes", HandleShout, false)
RegisterCommand("s", HandleShout, false)


-- =================================================================
-- 3. /mew [действие] / /w [действие] — Шёпот (3м, без трёх точек)
-- =================================================================
local function HandleWhisper(source, args)
    if source == 0 then return end

    if #args == 0 then
        SendErrorMessage(source, "Используйте: /mew [шёпот] или /w [шёпот]")
        return
    end

    local rawAction = table.concat(args, " ")
    local action = FormatSentenceCase(rawAction)
    local strangerName = GetStrangerName(source)
    local serverId = tostring(source)

    local prefix = string.format("[%s] %s:", serverId, strangerName)
    local col = Config.Chat.Colors.Mew
    local template = string.format('<div class="chat-message" style="color: rgb(%d, %d, %d); font-weight: normal;"><b style="font-weight: 700;">{0}</b> {1}</div>', col[1], col[2], col[3])

    if LogPlayerActivity then
        LogPlayerActivity(source, "chat_mew", action, {
            command = "/mew",
        })
    end

    BroadcastProximityRP(
        source,
        Config.Chat.Distances.Mew,
        { prefix, action },
        col,
        action,
        col,
        template
    )
end

RegisterCommand("mew", HandleWhisper, false)
RegisterCommand("w", HandleWhisper, false)


-- =================================================================
-- 4. /dice [или /roll] — Бросок костей 1-10
-- =================================================================
local function HandleDice(source)
    if source == 0 then return end

    local roll = math.random(1, 10)
    local isSuccess = (roll >= 6)
    local outcomeColor = isSuccess and Config.Chat.Colors.DiceSuccess or Config.Chat.Colors.DiceFail

    local strangerName = GetStrangerName(source)
    local serverId = tostring(source)

    local prefix = string.format("[%s] %s", serverId, strangerName)
    local diceText = string.format("бросает кости: %d", roll)
    local text3D = string.format("Бросок: %d", roll)
    local template = string.format('<div class="chat-message" style="color: rgb(%d, %d, %d); font-weight: normal;"><b style="font-weight: 700;">{0}</b> {1}</div>', outcomeColor[1], outcomeColor[2], outcomeColor[3])

    if LogPlayerActivity then
        LogPlayerActivity(source, "chat_dice", diceText, {
            command = "/dice",
            roll = roll,
            outcome = isSuccess and "success" or "fail",
        })
    end

    BroadcastProximityRP(
        source,
        Config.Chat.Distances.Dice,
        { prefix, diceText },
        outcomeColor,
        text3D,
        outcomeColor,
        template
    )
end

RegisterCommand("dice", HandleDice, false)
RegisterCommand("roll", HandleDice, false)

-- =================================================================
-- 5. /event — глобальная RP-информация для всех игроков
-- =================================================================
RegisterCommand("event", function(source, args)
    if source == 0 then return end
    if not IsPlayerAdmin(source) then
        SendErrorMessage(source, "Команда доступна только администраторам")
        return
    end

    if #args == 0 then
        SendErrorMessage(source, "Используйте: /event [текст события]")
        return
    end

    local eventText = table.concat(args, " "):sub(1, 500)
    if eventText == "" then return end

    -- Отправляем через штатный chat:addMessage каждому подключённому игроку
    -- отдельно. Поэтому событие не зависит от координат, routing bucket и
    -- расстояния, а режим _global не зависит от выбранного режима чата.
    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent("chat:addMessage", tonumber(playerId), {
            color = Config.Chat.Colors.Event,
            multiline = true,
            mode = "_global",
            templateId = "defaultAlt",
            -- Маркер нужен только штатному клиентскому фильтру: в создании и
            -- выборе персонажа глобальное событие не должно отображаться.
            huntEvent = true,
            -- Единственный аргумент — чистый текст события, без префикса.
            args = { eventText },
        })
    end

    if LogPlayerActivity then
        LogPlayerActivity(source, "chat_event", eventText, {
            command = "/event",
        })
    end
end, false)

-- Показываем подсказку только администраторам, если чат поддерживает suggestions.
RegisterNetEvent("chat:init", function()
    local source = source
    if IsPlayerAdmin(source) then
        TriggerClientEvent("chat:addSuggestion", source, "/event", "Глобальная RP-информация для игроков", {
            { name = "текст", help = "Текст события" }
        })
    end
end)
