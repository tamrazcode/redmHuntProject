-- =================================================================
-- HUNT: Hard RP — The Corruption | Scene Client Module
-- =================================================================

local isCharacterReady = false
local isSceneUIOpen = false
local isInputFocused = false
local isPlacementMode = false

-- Активные сцены в мире (синхронизируются сервером)
local ActiveScenes = {}

-- Данные текущей создаваемой сцены
local PendingScene = nil
local heightOffset = 0.0
local distanceOffset = 3.5
local currentHeading = 0.0
local lastScrollTime = 0

-- =================================================================
-- ИНИЦИАЛИЗАЦИЯ И СИНХРОНИЗАЦИЯ
-- =================================================================

RegisterNetEvent("thehunt:character:selected", function()
    isCharacterReady = true
    TriggerServerEvent("thehunt_scenes:requestScenes")
end)

AddEventHandler("thehunt:player:spawned", function()
    isCharacterReady = true
    TriggerServerEvent("thehunt_scenes:requestScenes")
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Wait(500)
    isCharacterReady = true
    TriggerServerEvent("thehunt_scenes:requestScenes")
end)

-- =================================================================
-- КОМАНДЫ /scene И /scenes
-- =================================================================

-- Создание сцены (/scene)
RegisterCommand("scene", function()
    if not isCharacterReady then
        TriggerEvent("thehunt_status:notify", "Сцены", "Подождите загрузки персонажа", "warning")
        return
    end
    if isPlacementMode then
        TriggerEvent("thehunt_status:notify", "Сцены", "Вы уже находитесь в режиме размещения", "warning")
        return
    end
    OpenSceneUI()
end, false)

-- Список и управление своими сценами (/scenes или /myscenes)
RegisterCommand("scenes", function()
    if not isCharacterReady then
        TriggerEvent("thehunt_status:notify", "Сцены", "Подождите загрузки персонажа", "warning")
        return
    end
    if isPlacementMode then
        TriggerEvent("thehunt_status:notify", "Сцены", "Сначала завершите режим размещения", "warning")
        return
    end
    TriggerServerEvent("thehunt_scenes:requestMyScenesList")
end, false)

RegisterCommand("myscenes", function()
    ExecuteCommand("scenes")
end, false)

-- =================================================================
-- NUI УПРАВЛЕНИЕ И CALLBACKS
-- =================================================================

function OpenSceneUI()
    isSceneUIOpen = true
    isInputFocused = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        type = 'OPEN_SCENE_UI',
        colors = Config.TextColors,
        durations = Config.DurationOptions,
        distances = Config.DistanceOptions,
        presets = Config.Presets,
        defaultColor = Config.DefaultColorIndex,
        defaultDuration = Config.DefaultDuration,
        defaultDistance = Config.DefaultDistance
    })
end

function OpenMyScenesUI(myScenesList)
    isSceneUIOpen = true
    isInputFocused = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    local listWithDistance = {}
    for _, s in ipairs(myScenesList) do
        local dist = #(pedCoords - vector3(tonumber(s.x) or 0.0, tonumber(s.y) or 0.0, tonumber(s.z) or 0.0))
        table.insert(listWithDistance, {
            id = s.id,
            text = s.text,
            color = s.color,
            colorIdx = s.colorIdx,
            expiresAt = s.expiresAt,
            distance = dist
        })
    end

    table.sort(listWithDistance, function(a, b) return a.distance < b.distance end)

    SendNUIMessage({
        type = 'OPEN_MY_SCENES_UI',
        scenes = listWithDistance,
        maxScenes = Config.MaxPlayerScenes or 5
    })
end

RegisterNetEvent("thehunt_scenes:openMyScenesUI", function(myScenes)
    OpenMyScenesUI(myScenes or {})
end)

function CloseSceneUI()
    isSceneUIOpen = false
    isInputFocused = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_SCENE_UI' })
end

RegisterNUICallback('closeSceneUI', function(data, cb)
    CloseSceneUI()
    cb('ok')
end)

-- Фокус ввода текста: когда фокус на <input>/<textarea> -> 100% блокировка всего ввода
RegisterNUICallback('setInputFocusState', function(data, cb)
    isInputFocused = (data.hasFocus == true)
    cb('ok')
end)

-- Подтверждение создания сцены
RegisterNUICallback('confirmScene', function(data, cb)
    CloseSceneUI()

    local text = data.text
    if not text or string.gsub(text, "%s+", "") == "" then
        TriggerEvent("thehunt_status:notify", "Сцены", "Текст сцены не может быть пустым", "error")
        cb('ok')
        return
    end

    local cleanText = string.gsub(text, "^%s*(.-)%s*$", "%1")
    if string.len(cleanText) > (Config.MaxTextLength or 250) then
        TriggerEvent("thehunt_status:notify", "Сцены", "Текст слишком длинный", "error")
        cb('ok')
        return
    end

    local colorIdx = tonumber(data.colorIdx) or Config.DefaultColorIndex
    local duration = tonumber(data.duration) or Config.DefaultDuration
    local viewDistance = tonumber(data.viewDistance) or Config.DefaultDistance

    -- Запуск 3D-размещения в мире
    StartPlacementMode(cleanText, colorIdx, duration, viewDistance)
    cb('ok')
end)

-- Удаление конкретной сцены из меню /scenes
RegisterNUICallback('deleteSceneFromUI', function(data, cb)
    if data.sceneId then
        TriggerServerEvent("thehunt_scenes:deleteScene", data.sceneId)
    end
    cb('ok')
end)

-- Удаление всех сцен из меню /scenes
RegisterNUICallback('deleteAllMyScenesFromUI', function(data, cb)
    TriggerServerEvent("thehunt_scenes:deleteAllMyScenes")
    cb('ok')
end)

-- =================================================================
-- ПОТОК ФИЛЬТРАЦИИ И БЛОКИРОВКИ УПРАВЛЕНИЯ
-- =================================================================

Citizen.CreateThread(function()
    local whitelistUI = {
        0xF1301666, 0x05CA7C52, -- Голосовой чат (PTT)
        `INPUT_PUSH_TO_TALK`,
        `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_MOVE_UP_ONLY`, `INPUT_MOVE_DOWN_ONLY`, `INPUT_MOVE_LEFT_ONLY`, `INPUT_MOVE_RIGHT_ONLY`,
        `INPUT_SPRINT`, `INPUT_JUMP`, `INPUT_DUCK`,
        `INPUT_HORSE_MOVE_UD`, `INPUT_HORSE_MOVE_LR`,
    }

    local whitelistPlacement = {
        0xF1301666, 0x05CA7C52, -- Голосовой чат (PTT)
        `INPUT_PUSH_TO_TALK`,
        `INPUT_LOOK_LR`, `INPUT_LOOK_UD`,
        0xA987235F, 0xD2047988, 0x3E92BDE0, 0x6BA8B0D3, -- Осмотр мыши
        `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_MOVE_UP_ONLY`, `INPUT_MOVE_DOWN_ONLY`, `INPUT_MOVE_LEFT_ONLY`, `INPUT_MOVE_RIGHT_ONLY`,
        `INPUT_SPRINT`, `INPUT_DUCK`, -- Shift / Ctrl
    }

    while true do
        if isSceneUIOpen then
            Citizen.Wait(0)
            local ped = PlayerPedId()

            if isInputFocused then
                -- 1. ПОЛНАЯ БЛОКИРОВКА ПРИ ПЕЧАТИ ТЕКСТА
                for pad = 0, 2 do
                    DisableAllControlActions(pad)
                end
                DisablePlayerFiring(ped, true)
            else
                -- 2. БЕЛЫЙ СПИСОК КНОПОК ПРИ ОТКРЫТОМ ОКНЕ
                for pad = 0, 2 do
                    DisableAllControlActions(pad)
                    for _, control in ipairs(whitelistUI) do
                        EnableControlAction(pad, control, true)
                    end
                end
                DisablePlayerFiring(ped, true)
            end

        elseif isPlacementMode then
            -- 3. БЕЛЫЙ СПИСОК ПРИ 3D РАЗМЕЩЕНИИ В МИРЕ
            Citizen.Wait(0)
            local ped = PlayerPedId()

            for pad = 0, 2 do
                DisableAllControlActions(pad)
                for _, control in ipairs(whitelistPlacement) do
                    EnableControlAction(pad, control, true)
                end
            end

            -- Блокируем стрельбу, укрытия, посадку на транспорт и прокрутку оружия
            DisablePlayerFiring(ped, true)
            DisableControlAction(0, 0xDE794E3E, true) -- Q (Cover)
            DisableControlAction(0, 0xCEFD9220, true) -- E (Context/Mount)
            DisableControlAction(0, 0xCE6D099E, true) -- E
            DisableControlAction(0, 0xDFF812F9, true) -- F (Mount/Enter)
            DisableControlAction(0, 0xB2F377E8, true) -- F
            DisableControlAction(0, 0x07CE1E61, true) -- LMB (Attack)
            DisableControlAction(0, 0xF84FA74F, true) -- RMB (Aim)
            DisableControlAction(0, 0xCC1075A7, true) -- Wheel Up
            DisableControlAction(0, 0x26414742, true) -- Wheel Down
            DisableControlAction(0, 241, true)
            DisableControlAction(0, 242, true)
            DisableControlAction(0, 0xD64DE4DA, true) -- Wheel Down alt
            DisableControlAction(0, 0x3C3DD37A, true) -- Wheel Down / Page Down
            DisableControlAction(0, 0x8F9F9E58, true) -- Next Weapon
            DisableControlAction(0, 0x446258B6, true) -- Wheel Up / Page Up
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 99, true)
        else
            Citizen.Wait(150)
        end
    end
end)

-- =================================================================
-- СЕРВЕРНЫЕ СОБЫТИЯ
-- =================================================================

RegisterNetEvent("thehunt_scenes:receiveScenes", function(scenes)
    ActiveScenes = scenes or {}
end)

RegisterNetEvent("thehunt_scenes:newScene", function(scene)
    if not scene or not scene.id then return end
    for i = #ActiveScenes, 1, -1 do
        if ActiveScenes[i].id == scene.id then
            table.remove(ActiveScenes, i)
        end
    end
    table.insert(ActiveScenes, scene)
end)

RegisterNetEvent("thehunt_scenes:removeScene", function(sceneId)
    local id = tonumber(sceneId)
    for i = #ActiveScenes, 1, -1 do
        if ActiveScenes[i].id == id then
            table.remove(ActiveScenes, i)
            break
        end
    end
end)

-- =================================================================
-- РЕЖИМ 3D РАЗМЕЩЕНИЯ (Raycast + Controls)
-- =================================================================

function StartPlacementMode(text, colorIdx, duration, viewDistance)
    local myPed = PlayerPedId()
    currentHeading = GetEntityHeading(myPed)
    heightOffset = 0.0
    distanceOffset = 3.5
    lastScrollTime = 0

    PendingScene = {
        text = text,
        colorIdx = colorIdx,
        duration = duration,
        viewDistance = viewDistance
    }
    isPlacementMode = true

    TriggerEvent("thehunt_status:notify", "Размещение сцены", "Наведите на поверхность: [ЛКМ/Enter] — установить, [ПКМ/Esc] — отмена", "info")
end

function StopPlacementMode()
    isPlacementMode = false
    PendingScene = nil
end

---Raycast луч из камеры с ограничением дальности
local function RaycastFromCamera(maxDist)
    local dist = maxDist or 8.0
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local radZ = math.rad(camRot.z)
    local radX = math.rad(camRot.x)
    local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
    local destCoords = camCoords + (forward * dist)

    local ped = PlayerPedId()
    local shapeTest = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, destCoords.x, destCoords.y, destCoords.z, 287, ped, 4)
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(shapeTest)

    if (hit == 1 or hit == true) and endCoords and endCoords.x ~= 0.0 then
        return {
            hit = true,
            coords = endCoords,
            normal = surfaceNormal,
            forward = forward
        }
    end

    return {
        hit = false,
        coords = destCoords,
        forward = forward
    }
end

-- =================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ОТРИСОВКИ 3D ТЕКСТА
-- =================================================================

---Разбивка длинного текста на несколько строк (до 150 символов в строке)
local function WrapText(text, maxCharsPerLine)
    local limit = maxCharsPerLine or 150
    if string.len(text) <= limit then
        return { text }
    end

    local lines = {}
    local currentLine = ""

    for word in string.gmatch(text, "%S+") do
        if string.len(currentLine) == 0 then
            currentLine = word
        elseif (string.len(currentLine) + 1 + string.len(word)) <= limit then
            currentLine = currentLine .. " " .. word
        else
            table.insert(lines, currentLine)
            currentLine = word
        end
    end

    if string.len(currentLine) > 0 then
        table.insert(lines, currentLine)
    end

    return lines
end

---Отрисовка чистого 3D текста с контрастной тенью
local function DrawScene3DText(x, y, z, text, color, alpha, isPreview, sphereZ)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoord()
    local distance = #(camCoords - vector3(x, y, z))
    if distance > 45.0 then return end

    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = ((1 / math.max(1.0, distance)) * 2.0) * fov * 0.36
    if scale < 0.22 then scale = 0.22 end
    if scale > 0.44 then scale = 0.44 end

    local r = color.r or 255
    local g = color.g or 255
    local b = color.b or 255
    local a = alpha or 255

    -- До 150 символов в строке
    local lines = WrapText(text, 150)
    local lineSpacing = 0.024 * (scale / 0.34)

    -- Строки текста строго над шаром
    for i, line in ipairs(lines) do
        local lineY = screenY + ((i - 1) * lineSpacing)
        local textStr = VarString(10, "LITERAL_STRING", line, Citizen.ResultAsLong())
        SetTextScale(scale, scale)
        SetTextFontForCurrentCommand(1)
        SetTextColor(r, g, b, a)
        SetTextCentre(1)
        SetTextDropshadow(2, 0, 0, 0, math.floor(a * 0.95))
        DisplayText(textStr, screenX, lineY)
    end

    -- Подсказка управления в режиме превью — отрисовывается аккуратно под шаром
    if isPreview and sphereZ then
        local underScreen, underX, underY = GetScreenCoordFromWorldCoord(x, y, sphereZ - 0.22)
        if underScreen then
            local hintStr1 = VarString(10, "LITERAL_STRING", "[ЛКМ / Enter] Установить   [ПКМ / Esc] Отмена", Citizen.ResultAsLong())
            SetTextScale(0.21, 0.21)
            SetTextFontForCurrentCommand(1)
            SetTextColor(245, 158, 11, 240)
            SetTextCentre(1)
            SetTextDropshadow(2, 0, 0, 0, 255)
            DisplayText(hintStr1, underX, underY)

            local hintStr2 = VarString(10, "LITERAL_STRING", "[Q / E] Высота   [R / F] Дистанция   [Space] Прилипание", Citizen.ResultAsLong())
            SetTextScale(0.18, 0.18)
            SetTextFontForCurrentCommand(1)
            SetTextColor(170, 180, 195, 220)
            SetTextCentre(1)
            SetTextDropshadow(2, 0, 0, 0, 255)
            DisplayText(hintStr2, underX, underY + 0.016)
        end
    end
end

-- Сетка единичной сферы для заливного призрачного 3D шара
local SphereVertices = {}
local SphereTriangles = {}
local function InitSphereMesh()
    local rings = 10
    local segs = 16
    local pi = math.pi
    SphereVertices = {}
    SphereTriangles = {}

    for i = 0, rings do
        local phi = (i / rings) * pi
        local sinPhi = math.sin(phi)
        local cosPhi = math.cos(phi)
        for j = 0, segs do
            local theta = (j / segs) * (2 * pi)
            table.insert(SphereVertices, { x = sinPhi * math.cos(theta), y = sinPhi * math.sin(theta), z = cosPhi })
        end
    end

    local segsPlusOne = segs + 1
    for i = 0, rings - 1 do
        for j = 0, segs - 1 do
            local p1 = (i * segsPlusOne) + j + 1
            local p2 = p1 + segsPlusOne
            local p3 = p1 + 1
            local p4 = p2 + 1
            table.insert(SphereTriangles, { p1, p2, p3 })
            table.insert(SphereTriangles, { p3, p2, p4 })
        end
    end
end
InitSphereMesh()

local function DrawSolidSphere(x, y, z, radius, r, g, b, a)
    local rad = radius or 0.11
    local red = r or 255
    local green = g or 255
    local blue = b or 255
    local alpha = a or 170

    for _, tri in ipairs(SphereTriangles) do
        local v1 = SphereVertices[tri[1]]
        local v2 = SphereVertices[tri[2]]
        local v3 = SphereVertices[tri[3]]
        if v1 and v2 and v3 then
            local x1, y1, z1 = x + v1.x * rad, y + v1.y * rad, z + v1.z * rad
            local x2, y2, z2 = x + v2.x * rad, y + v2.y * rad, z + v2.z * rad
            local x3, y3, z3 = x + v3.x * rad, y + v3.y * rad, z + v3.z * rad
            DrawPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, red, green, blue, alpha)
            DrawPoly(x3, y3, z3, x2, y2, z2, x1, y1, z1, red, green, blue, math.floor(alpha * 0.75))
        end
    end
end

-- =================================================================
-- ГЛАВНЫЙ ПОТОК: РЕНДЕРИНГ И РАЗМЕЩЕНИЕ
-- =================================================================

Citizen.CreateThread(function()
    while true do
        local sleep = 500

        -- 1. Режим установки сцены
        if isPlacementMode and PendingScene then
            sleep = 0
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local curTime = GetGameTimer()

            -- 1. Регулировка высоты (Q / E / Стрелки / Page Up / Page Down)
            local isHeightUp = IsDisabledControlPressed(0, 0xDE794E3E) or IsControlPressed(0, 0xDE794E3E) -- Q
                or IsDisabledControlPressed(0, 0x6319DB71) or IsControlPressed(0, 0x6319DB71) -- Up Arrow
                or IsDisabledControlPressed(0, 0x446258B6) or IsControlPressed(0, 0x446258B6) -- Page Up

            local isHeightDown = IsDisabledControlPressed(0, 0xCEFD9220) or IsControlPressed(0, 0xCEFD9220) -- E
                or IsDisabledControlPressed(0, 0xCE6D099E) or IsControlPressed(0, 0xCE6D099E) -- E
                or IsDisabledControlPressed(0, 0x05CA7C52) or IsControlPressed(0, 0x05CA7C52) -- Down Arrow
                or IsDisabledControlPressed(0, 0x3C3DD37A) or IsControlPressed(0, 0x3C3DD37A) -- Page Down

            if isHeightUp then
                heightOffset = math.min(3.0, heightOffset + 0.02)
            elseif isHeightDown then
                heightOffset = math.max(-3.0, heightOffset - 0.02)
            end

            -- 2. Прилипание Space
            if IsDisabledControlJustPressed(0, 0xD9D0E1C0) or IsControlJustPressed(0, 0xD9D0E1C0) then
                heightOffset = 0.0
            end

            -- 3. Регулировка дистанции клавишами R (Отдалять) и F (Приближать)
            local isDistFarther = IsDisabledControlPressed(0, 0xE30CD707) or IsControlPressed(0, 0xE30CD707) -- R
                or IsDisabledControlPressed(0, 0x410CD45F) or IsControlPressed(0, 0x410CD45F) -- R
                or IsDisabledControlPressed(0, 45) or IsControlPressed(0, 45)

            local isDistCloser = IsDisabledControlPressed(0, 0xDFF812F9) or IsControlPressed(0, 0xDFF812F9) -- F
                or IsDisabledControlPressed(0, 0xB2F377E8) or IsControlPressed(0, 0xB2F377E8) -- F
                or IsDisabledControlPressed(0, 23) or IsControlPressed(0, 23)

            local maxDistLimit = Config.RaycastDistance or 8.0

            if isDistFarther then
                distanceOffset = math.min(maxDistLimit, distanceOffset + 0.05)
            elseif isDistCloser then
                distanceOffset = math.max(0.6, distanceOffset - 0.05)
            end

            -- 4. Вычисление точки прицела (Raycast с ограничением дистанции)
            local ray = RaycastFromCamera(distanceOffset)
            local targetCoords = ray.coords

            -- Ограничиваем отдаление шара от персонажа
            local distFromPed = #(pedCoords - targetCoords)
            if distFromPed > maxDistLimit then
                local dir = (targetCoords - pedCoords)
                targetCoords = pedCoords + (dir / distFromPed * maxDistLimit)
            end

            local finalX = targetCoords.x
            local finalY = targetCoords.y
            local finalZ = targetCoords.z + heightOffset

            local textFinalZ = finalZ + 0.32

            -- 5. ОТРИСОВКА АККУРАТНОГО КОМПАКТНОГО 3D ШАРА (РАДИУС 0.11м)
            DrawSolidSphere(finalX, finalY, finalZ, 0.11, 255, 255, 255, 175)

            -- 6. Отрисовка превью 3D текста НАД ШАРОМ
            local color = Config.TextColors[PendingScene.colorIdx] or Config.TextColors[1]
            DrawScene3DText(finalX, finalY, textFinalZ, PendingScene.text, color, 255, true, finalZ)

            -- 7. Подтверждение (ЛКМ / Enter)
            local isConfirm = IsDisabledControlJustPressed(0, 0x07CE1E61) or IsControlJustPressed(0, 0x07CE1E61)
                or IsDisabledControlJustPressed(0, 0xC7B5340A) or IsControlJustPressed(0, 0xC7B5340A)

            if isConfirm then
                TriggerServerEvent("thehunt_scenes:createScene", {
                    text = PendingScene.text,
                    colorIdx = PendingScene.colorIdx,
                    duration = PendingScene.duration,
                    viewDistance = PendingScene.viewDistance,
                    x = finalX,
                    y = finalY,
                    z = textFinalZ,
                    rotZ = currentHeading
                })
                StopPlacementMode()
            end

            -- 8. Отмена (ПКМ / Esc / Backspace)
            local isCancel = IsDisabledControlJustPressed(0, 0xF84FA74F) or IsControlJustPressed(0, 0xF84FA74F)
                or IsDisabledControlJustPressed(0, 0x156F7119) or IsControlJustPressed(0, 0x156F7119)
                or IsDisabledControlJustPressed(0, 0xD82E0BD2) or IsControlJustPressed(0, 0xD82E0BD2)

            if isCancel then
                StopPlacementMode()
                TriggerEvent("thehunt_status:notify", "Сцены", "Размещение отменено", "info")
            end
        end

        -- 2. Отрисовка всех активных сцен в мире
        if #ActiveScenes > 0 then
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)

            for _, scene in ipairs(ActiveScenes) do
                local sceneCoords = vector3(tonumber(scene.x) or 0.0, tonumber(scene.y) or 0.0, tonumber(scene.z) or 0.0)
                local dist = #(pedCoords - sceneCoords)
                local maxDist = tonumber(scene.viewDistance) or Config.DefaultDistance or 15.0

                if dist <= maxDist then
                    sleep = 0
                    local alphaFactor = 1.0 - (dist / maxDist)
                    local alpha = math.max(50, math.floor(alphaFactor * 255))
                    local color = Config.TextColors[tonumber(scene.colorIdx) or 1] or Config.TextColors[1]

                    DrawScene3DText(sceneCoords.x, sceneCoords.y, sceneCoords.z, scene.text, color, alpha, false, nil)
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

exports('isSceneOpen', function()
    return isSceneUIOpen == true
end)
