-- =================================================================
-- HUNT: Hard RP — The Corruption | Клиентский 3D-текст, анимация печати и подсказки
-- =================================================================

local activeTexts = {}
local typingPlayers = {}
local textCounter = 0

-- Загрузка текстурного словаря для красивой подложки 3D-текста
Citizen.CreateThread(function()
    if Config.Text3D.DrawBackground then
        if not HasStreamedTextureDictLoaded("feeds") then
            RequestStreamedTextureDict("feeds", true)
            while not HasStreamedTextureDictLoaded("feeds") do
                Citizen.Wait(50)
            end
        end
    end
end)

-- Функция надежного получения координат головы персонажа в RedM
local function GetPedHeadPosition(ped)
    local boneIndex = GetEntityBoneIndexByName(ped, "SKEL_Head")
    if boneIndex and boneIndex ~= -1 then
        local bonePos = GetWorldPositionOfEntityBone(ped, boneIndex)
        if bonePos and (bonePos.x ~= 0.0 or bonePos.y ~= 0.0 or bonePos.z ~= 0.0) then
            return bonePos
        end
    end
    -- Fallback: центр персонажа + высота головы (0.95м)
    return GetEntityCoords(ped) + vector3(0.0, 0.0, 0.95)
end

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

-- =================================================================
-- ПРИЕМ СОБЫТИЙ: 3D-ТЕКСТ И СТАТУС ПЕЧАТИ
-- =================================================================

-- 3D-текст сообщений
RegisterNetEvent("thehunt_rp:show3DText", function(senderServerId, text, color)
    if not text or text == "" then return end

    textCounter = textCounter + 1
    local curTime = GetGameTimer()

    local textR = 255
    local textG = 255
    local textB = 255

    if type(color) == "table" then
        textR = color.r or color[1] or 255
        textG = color.g or color[2] or 255
        textB = color.b or color[3] or 255
    end

    local formattedText = FormatSentenceCase(tostring(text))

    table.insert(activeTexts, {
        id        = textCounter,
        senderId  = tonumber(senderServerId),
        text      = formattedText,
        color     = { r = textR, g = textG, b = textB },
        startTime = curTime,
        endTime   = curTime + (Config.Text3D.DurationMs or 7000)
    })
end)

-- Синхронизация статуса набора текста (три точки)
RegisterNetEvent("thehunt_chat:syncTyping", function(senderServerId, isTyping)
    local src = tonumber(senderServerId)
    if isTyping then
        typingPlayers[src] = true
    else
        typingPlayers[src] = nil
    end
end)

-- Проверка: открыто ли какое-либо другое меню (инвентарь, админка, крафт, двери, билдер, сцены, интеракции, пауза, меню анимаций)
local function IsOtherMenuOpen()
    if IsPauseMenuActive() then return true end

    -- 1. Админ-панель thehunt_core
    if TheHunt_IsAdminMenuOpen == true then
        return true
    end

    -- 2. Инвентарь thehunt_inventory
    local ok1, invOpen = pcall(function() return exports['thehunt_inventory']:isInventoryOpen() end)
    if ok1 and invOpen == true then return true end

    -- 3. Крафтинг thehunt_crafting
    local ok2, craftOpen = pcall(function() return exports['thehunt_crafting']:IsCraftingOpen() end)
    if ok2 and craftOpen == true then return true end

    -- 4. Меню дверей thehunt_doors
    local ok3, doorOpen = pcall(function() return exports['thehunt_doors']:isDoorMenuOpen() end)
    if ok3 and doorOpen == true then return true end

    -- 5. Редактор мира (билдер) thehunt_builder
    local ok4, bldOpen = pcall(function() return exports['thehunt_builder']:isBuilderOpen() end)
    if ok4 and bldOpen == true then return true end

    -- 6. Заметки сцен thehunt_scenes
    local ok5, scnOpen = pcall(function() return exports['thehunt_scenes']:isSceneOpen() end)
    if ok5 and scnOpen == true then return true end

    -- 7. Меню взаимодействия thehunt_interact
    local ok6, intOpen = pcall(function() return exports['thehunt_interact']:isInteractOpen() end)
    if ok6 and intOpen == true then return true end

    -- 8. Меню игрока thehunt_menu
    local ok7, pMenuOpen = pcall(function() return exports['thehunt_menu']:isPlayerMenuOpen() end)
    if ok7 and pMenuOpen == true then return true end

    -- 9. Создание и выбор персонажа thehunt_character
    local ok8, charOpen = pcall(function() return exports['thehunt_character']:isCharacterMenuOpen() end)
    if ok8 and charOpen == true then return true end
    if LocalPlayer.state.isCreatingChar or LocalPlayer.state.isSelectingChar then return true end

    -- 10. Меню анимаций thehunt_animations
    local ok9, animOpen = pcall(function() return exports['thehunt_animations']:isAnimationsOpen() end)
    if ok9 and animOpen == true then return true end
    local ok9b, animOpen2 = pcall(function() return exports['thehunt_animations']:isMenuOpen() end)
    if ok9b and animOpen2 == true then return true end
    local ok9c, radOpen = pcall(function() return exports['thehunt_animations']:isRadialOpen() end)
    if ok9c and radOpen == true then return true end
    if LocalPlayer.state.isAnimMenuOpen == true then return true end

    return false
end

-- Автоматический локальный трекер набора текста в чате
Citizen.CreateThread(function()
    local wasTyping = false
    while true do
        Citizen.Wait(80)
        local isNuiOn = IsNuiFocused() or false
        local isTypingNow = false

        if isNuiOn then
            if not IsOtherMenuOpen() then
                isTypingNow = true
            end
        end

        if isTypingNow ~= wasTyping then
            wasTyping = isTypingNow
            local myId = GetPlayerServerId(PlayerId())
            if isTypingNow then
                typingPlayers[myId] = true
            else
                typingPlayers[myId] = nil
            end
            TriggerServerEvent("thehunt_chat:setTyping", isTypingNow)
        end
    end
end)


-- =================================================================
-- ФУНКЦИЯ ОТРИСОВКИ 3D-ТЕКСТА В ПРОСТРАНСТВЕ
-- =================================================================
local function DrawText3D(x, y, z, text, r, g, b, alpha, withBackground, customScale)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoord()
    local distance = #(camCoords - vector3(x, y, z))

    -- Динамический расчет масштаба по дистанции
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = ((1 / distance) * 2.0) * fov * (customScale or 0.36)

    -- Ограничения масштаба
    if scale < 0.22 then scale = 0.22 end
    if scale > 0.44 then scale = 0.44 end

    -- Отрисовка подложки (если включена и текстура загружена)
    if withBackground and Config.Text3D.DrawBackground and HasStreamedTextureDictLoaded("feeds") then
        local strLen = string.len(text)
        local bgWidth = (strLen * 0.0053) + 0.026
        local bgHeight = 0.033 * (scale / 0.32)
        local bgAlpha = math.floor((alpha / 255) * (Config.Text3D.BackgroundAlpha or 180))

        DrawSprite(
            "feeds", "hud_menu_4a",
            screenX, screenY + 0.0125,
            bgWidth, bgHeight,
            0.0,
            8, 8, 12, bgAlpha,
            false
        )
    end

    -- Отрисовка текста
    local textStr = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextScale(scale, scale)
    SetTextFontForCurrentCommand(Config.Text3D.Font or 1)
    SetTextColor(r, g, b, alpha)
    SetTextCentre(1)
    SetTextDropshadow(2, 0, 0, 0, alpha)
    DisplayText(textStr, screenX, screenY)
end


-- =================================================================
-- ГЛАВНЫЙ ПОТОК ОТРИСОВКИ 3D-ТЕКСТОВ И АНИМАЦИИ ПЕЧАТИ
-- =================================================================
Citizen.CreateThread(function()
    while true do
        local count = #activeTexts
        local hasTyping = false
        for _ in pairs(typingPlayers) do
            hasTyping = true
            break
        end

        if count > 0 or hasTyping then
            Citizen.Wait(0)
            local curTime = GetGameTimer()
            local camCoords = GetGameplayCamCoord()

            -- 1. ОТРИСОВКА АНИМАЦИИ ПЕЧАТИ (ТРИ БЕЛЫЕ ТОЧКИ БЕЗ ФОНА)
            if hasTyping then
                local animPhase = math.floor((curTime % 1200) / 400)
                local dotsText = ".  "
                if animPhase == 1 then
                    dotsText = ". . "
                elseif animPhase == 2 then
                    dotsText = ". . ."
                end

                for senderId, _ in pairs(typingPlayers) do
                    local myServerId = GetPlayerServerId(PlayerId())
                    local ped = 0

                    if senderId == myServerId then
                        ped = PlayerPedId()
                    else
                        local targetPlayer = GetPlayerFromServerId(senderId)
                        if targetPlayer and targetPlayer ~= -1 then
                            ped = GetPlayerPed(targetPlayer)
                        end
                    end

                    if ped ~= 0 and DoesEntityExist(ped) then
                        local headPos = GetPedHeadPosition(ped)
                        local dist = #(camCoords - headPos)

                        if dist <= (Config.Text3D.MaxDistance or 25.0) then
                            local renderZ = headPos.z + (Config.Text3D.TypingOffsetZ or 0.35)
                            -- Рисуем белые точки БЕЗ фона
                            DrawText3D(
                                headPos.x,
                                headPos.y,
                                renderZ,
                                dotsText,
                                255, 255, 255, 235,
                                false, -- без подложки
                                0.52   -- крупнее для четкой видимости точек
                            )
                        end
                    end
                end
            end

            -- 2. ОТРИСОВКА 3D-ТЕКСТОВ СООБЩЕНИЙ С АВТО-СТЕКИНГОМ
            if count > 0 then
                local playerStacks = {}

                -- Проходим в обратном порядке для безопасного удаления истекших сообщений
                for i = count, 1, -1 do
                    local item = activeTexts[i]

                    if curTime >= item.endTime then
                        table.remove(activeTexts, i)
                    else
                        local targetPlayer = GetPlayerFromServerId(item.senderId)
                        if targetPlayer and NetworkIsPlayerActive(targetPlayer) then
                            local ped = GetPlayerPed(targetPlayer)
                            if DoesEntityExist(ped) and IsEntityVisible(ped) then
                                local headPos = GetPedHeadPosition(ped)
                                local dist = #(camCoords - headPos)

                                if dist <= (Config.Text3D.MaxDistance or 25.0) then
                                    playerStacks[item.senderId] = (playerStacks[item.senderId] or 0) + 1
                                    local stackIndex = playerStacks[item.senderId] - 1

                                    -- Базовый оффсет высоко над головой
                                    local zOffset = (Config.Text3D.BaseOffsetZ or 0.45) + (stackIndex * (Config.Text3D.StackOffsetZ or 0.16))
                                    local renderZ = headPos.z + zOffset

                                    -- Плавное затухание в конце времени жизни
                                    local remainingTime = item.endTime - curTime
                                    local alpha = 255
                                    if remainingTime < (Config.Text3D.FadeOutMs or 1000) then
                                        alpha = math.floor((remainingTime / (Config.Text3D.FadeOutMs or 1000)) * 255)
                                        if alpha < 0 then alpha = 0 end
                                    end

                                    DrawText3D(
                                        headPos.x,
                                        headPos.y,
                                        renderZ,
                                        item.text,
                                        item.color.r,
                                        item.color.g,
                                        item.color.b,
                                        alpha,
                                        true -- с аккуратной темной подложкой
                                    )
                                end
                            end
                        end
                    end
                end
            end
        else
            -- Если нет ни активных текстов, ни печатающих игроков — спим
            Citizen.Wait(120)
        end
    end
end)


-- =================================================================
-- РЕГИСТРАЦИЯ ПОДСКАЗОК ЧАТА (CHAT SUGGESTIONS)
-- =================================================================
local function RegisterChatSuggestions()
    -- /me
    TriggerEvent('chat:addSuggestion', '/me', 'Совершить RP-действие от первого лица (8м)', {
        { name = 'действие', help = 'Текст действия персонажа' }
    })

    -- /mes & /s
    TriggerEvent('chat:addSuggestion', '/mes', 'Совершить громкое RP-действие / крикнуть (25м)', {
        { name = 'действие', help = 'Текст громкого действия или крика' }
    })
    TriggerEvent('chat:addSuggestion', '/s', 'Крикнуть в радиусе 25 метров', {
        { name = 'текст', help = 'Текст крика' }
    })

    -- /mew & /w
    TriggerEvent('chat:addSuggestion', '/mew', 'Совершить тихое RP-действие / прошептать (3м)', {
        { name = 'действие', help = 'Текст тихого действия или шепота' }
    })
    TriggerEvent('chat:addSuggestion', '/w', 'Прошептать в радиусе 3 метров', {
        { name = 'текст', help = 'Текст шепота' }
    })

    -- /dice & /roll
    TriggerEvent('chat:addSuggestion', '/dice', 'Бросить игральные кости (1-10: 1-5 провал, 6-10 успех)')
    TriggerEvent('chat:addSuggestion', '/roll', 'Бросить игральные кости (1-10: 1-5 провал, 6-10 успех)')

    -- Инструменты тестирования и админа
    TriggerEvent('chat:addSuggestion', '/weapon', '[Тест] Выдать оружие в руки', {
        { name = 'название', help = 'Хэш (напр. WEAPON_REVOLVER_CATTLEMAN)' }
    })
    TriggerEvent('chat:addSuggestion', '/ammo', '[Тест] Полное пополнение патронов (999 шт)')
    TriggerEvent('chat:addSuggestion', '/fireball', '[Тест] Оккультный огненный шар (магия)')
    TriggerEvent('chat:addSuggestion', '/adminblips', '[Админ] Переключение отображения меток игроков на карте')
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    RegisterChatSuggestions()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        RegisterChatSuggestions()
    end
end)
