--[[
    HUNT: Hard RP — Movement Speed Controller (4 режима скорости из hex-walking)
    
    1 режим: 0.2 без Shift / 0.4 без Shift  -> walk 0.2 / sprint 0.4
    2 режим: 0.6 без Shift / 0.9 без Shift  -> walk 0.6 / sprint 0.9
    3 режим: 1.0 без Shift / 0.8 с Shift    -> walk 1.0 / sprint 1.6
    4 режим: 0.6 с Shift / 1.0 с Shift      -> walk 1.4 / sprint 2.0
    
    Управление:
    - Alt (0x580C4473) + Колесико мыши вверх / вниз -> Переключение режимов (1..4)
    - Alt + Стрелка вверх / вниз -> Переключение режимов (1..4)
    - Alt + R -> Сброс на стандартный режим (Режим 2: Walk 0.6 | Shift 0.9)
    - Alt + Стрелка вправо -> Максимальный режим (4: Walk 1.4 | Shift 2.0)
    - Alt + Стрелка влево -> Минимальный режим (1: Walk 0.2 | Shift 0.4)
    - Команды чата: /speed <1..4 или скорость>, /walkspeed <значение>
--]]

-- =================================================================
-- РЕЗЕРВ: Предыдущие конфигурации скоростей (сохранены)
-- =================================================================
-- Предыдущие 3 режима HUNT:
local BACKUP_THEHUNT_SPEEDS = {
    [1] = { walk = 0.2, sprint = 0.6, name = "Режим 1: Шаг 0.2 / Shift 0.6" },
    [2] = { walk = 0.8, sprint = 1.6, name = "Режим 2: Шаг 0.8 / Shift 1.6" },
    [3] = { walk = 1.4, sprint = 2.0, name = "Режим 3: Шаг 1.4 / Shift 2.0" }
}

-- Предыдущая непрерывная шкала hex-walking:
local BACKUP_HEX_WALKING = {
    MIN_SPEED = 0.2, MAX_SPEED = 3.0, SPEED_INCREMENT = 0.1, DEFAULT_SPEED = 1.0
}

-- =================================================================
-- НОВЫЕ 4 РЕЖИМА СКОРОСТИ
-- =================================================================
local SpeedLevels = {
    [1] = { walk = 0.2, sprint = 0.4, name = "Режим 1: Шаг 0.2 / Shift 0.4" },
    [2] = { walk = 0.6, sprint = 0.9, name = "Режим 2: Шаг 0.6 / Shift 0.9" },
    [3] = { walk = 1.0, sprint = 1.6, name = "Режим 3: Шаг 1.0 / Shift 1.6" },
    [4] = { walk = 1.4, sprint = 2.0, name = "Режим 4: Шаг 1.4 / Shift 2.0" }
}

local DEFAULT_INDEX = 2 -- По умолчанию: Режим 2 (Walk 0.6 | Shift 0.9)

local Controls = {
    ALT_HUD_SPECIAL = 0x580C4473, -- Left Alt (RDR2 joaat hash INPUT_HUD_SPECIAL)
    ALT_FALLBACK    = 0x8AAA0DE4, -- Left Alt fallback
    SPRINT          = 0x8FFC75D6, -- Left Shift
    RESET_SPEED     = 0xE30CD707, -- R
    MAX_SPEED       = 0xDEB34313, -- Right Arrow
    MIN_SPEED       = 0xA65EBAB4  -- Left Arrow
}

-- Блокируемые хэши селектора оружия RDR2 при зажатом Alt
local WHEEL_CONTROLS = {
    0xD0842EDF, -- INPUT_SELECT_NEXT_WEAPON (Wheel Down)
    0xFD0F0C2C, -- INPUT_NEXT_WEAPON (patch 1311.12+)
    0xF78D7337, -- INPUT_SELECT_PREV_WEAPON (Wheel Up)
    0xCC1075A7, -- INPUT_PREV_WEAPON (patch 1311.12+)
    0x6319DB71, -- INPUT_SELECT_NEXT_WEAPON legacy
    0x05CA7C52, -- INPUT_SELECT_PREV_WEAPON legacy
    0x48CE4ED3, -- INPUT_WEAPON_WHEEL_NEXT
    0x05047805, -- INPUT_WEAPON_WHEEL_PREV
    0xC13A5C50, -- INPUT_WEAPON_WHEEL_DISPLAY_HOLD (TAB)
    0x1F6D95E5, -- INPUT_QUICK_SELECT_INSPECT
    0x2497FBCE, -- INPUT_RADAR_ZOOM
    0xACBE180C  -- INPUT_RADAR_ZOOM_OUT
}

-- Визуальные индикаторы скорости (4 уровня)
local SPEED_INDICATORS = {
    { threshold = 0.25, text = "~COLOR_GREEN~+~COLOR_WHITE~+++" },  -- Режим 1
    { threshold = 0.50, text = "~COLOR_GREEN~++~COLOR_WHITE~++" },  -- Режим 2
    { threshold = 0.75, text = "~COLOR_YELLOW~+++~COLOR_WHITE~+" }, -- Режим 3
    { threshold = 1.00, text = "~COLOR_RED~++++" }                  -- Режим 4
}

local currentIndex = DEFAULT_INDEX
local currentActiveSpeed = SpeedLevels[DEFAULT_INDEX].walk
local lastAdjustTime = 0
local showSpeedTimer = 0
local isPhysicalShift = false

---Отрисовка 2D текста на экране
local function DrawText2D(text)
    DrawRect(0.5, 0.85, 0.34, 0.036, 15, 15, 15, 160)

    SetTextScale(0.38, 0.38)
    SetTextColor(255, 255, 255, 235)
    SetTextCentre(1)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), 0.5, 0.836)
end

---Получение значков ++++ для индикатора
local function GetSpeedIndicator()
    local pct = currentIndex / #SpeedLevels
    for _, ind in ipairs(SPEED_INDICATORS) do
        if pct <= ind.threshold then
            return ind.text
        end
    end
    return SPEED_INDICATORS[#SPEED_INDICATORS].text
end

---Показ временной подсказки скорости на экране
local function ShowSpeedDisplay()
    showSpeedTimer = GetGameTimer() + 2500
end

---Проверка недееспособности персонажа
local function IsPlayerIncapacitated(ped)
    if not DoesEntityExist(ped) then return true end
    local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, ped)
    local cuffed = Citizen.InvokeNative(0x74E559B3BC910685, ped)
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedSwimming(ped)
        or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or hogtied or cuffed
        or IsPedUsingAnyScenario(ped)
end

---Применение скорости к персонажу
local function ApplyMovementSpeed(ped, speed, isShiftPressed, isMoving)
    if not DoesEntityExist(ped) or not IsPedOnFoot(ped) then return end

    -- Transformed animal peds in Ped Custom have their own dedicated locomotion controller
    -- with full 3.0 sprint, quadruped gaits, Alt+wheel speeds, combat and flight.
    -- Yield control so human locomotion overrides do not clamp or zero out animal movement.
    if LocalPlayer.state.huntPedCustomActive and not IsPedHuman(ped) then
        return
    end

    SetPedMaxMoveBlendRatio(ped, speed)

    -- Если скорость выше 1.0 без Shift (Режим 4: 1.5) и персонаж движется:
    -- Нативно задаем минимальный blend ratio через SET_PED_MIN_MOVE_BLEND_RATIO (0x01A898D26E2333DD),
    -- что заставляет движок RDR2 физически вести персонажа на 1.5 без нажатия Shift и без фейковых клавиш/звуков!
    if not isShiftPressed and speed > 1.0 then
        if isMoving then
            if SetPedMinMoveBlendRatio then
                SetPedMinMoveBlendRatio(ped, speed)
            else
                Citizen.InvokeNative(0x01A898D26E2333DD, ped, speed)
            end
        else
            if SetPedMinMoveBlendRatio then
                SetPedMinMoveBlendRatio(ped, 0.0)
            else
                Citizen.InvokeNative(0x01A898D26E2333DD, ped, 0.0)
            end
        end
        SetPedMoveRateOverride(ped, 1.0)
    else
        if SetPedMinMoveBlendRatio then
            SetPedMinMoveBlendRatio(ped, 0.0)
        else
            Citizen.InvokeNative(0x01A898D26E2333DD, ped, 0.0)
        end

        if speed <= 1.0 then
            SetPedMoveRateOverride(ped, speed)
        else
            SetPedMoveRateOverride(ped, 1.0)
        end
    end
end

---Синхронизация процента в HUD (от 1 до #SpeedLevels -> 25% .. 100%)
local function SyncHud()
    local pct = math.floor((currentIndex / #SpeedLevels) * 100)
    pct = math.max(0, math.min(100, pct))
    TriggerEvent("thehunt_status:setSpeedPercent", pct)
end

-- =================================================================
-- СОСТОЯНИЕ ПЕРЕГРУЗА (ИНТЕГРАЦИЯ С THEHUNT_INVENTORY)
-- =================================================================
local isOverweight = false
local previousSpeedIndex = nil

local function CheckIsOverweight()
    if isOverweight then return true end
    local expOverweight = false
    pcall(function()
        if exports['thehunt_inventory'] and exports['thehunt_inventory'].IsOverweight then
            expOverweight = exports['thehunt_inventory']:IsOverweight() == true
        end
    end)
    return expOverweight
end

RegisterNetEvent("thehunt_walking:setOverweight", function(state)
    local wasOverweight = isOverweight
    isOverweight = state == true

    if isOverweight and not wasOverweight then
        if not previousSpeedIndex then
            previousSpeedIndex = currentIndex
        end
        currentIndex = 1
        SyncHud()
        ShowSpeedDisplay()
        TriggerEvent("thehunt_status:notify", "Перевес", "Вы перегружены! Скорость ограничена 1-м режимом.", "warning", 3500)
    elseif not isOverweight and wasOverweight then
        if previousSpeedIndex then
            currentIndex = previousSpeedIndex
            previousSpeedIndex = nil
        else
            currentIndex = DEFAULT_INDEX
        end
        SyncHud()
        ShowSpeedDisplay()
        TriggerEvent("thehunt_status:notify", "Вес в норме", "Перегруз снят. Ограничение скорости отключено.", "success", 3000)
    end
end)

---Смена шага скорости (+1 / -1)
local function AdjustSpeedIndex(step)
    if CheckIsOverweight() then
        if currentIndex ~= 1 then
            currentIndex = 1
            SyncHud()
        end
        ShowSpeedDisplay()
        return false
    end

    local now = GetGameTimer()
    if (now - lastAdjustTime) < 60 then return false end
    lastAdjustTime = now

    local newIdx = currentIndex + step
    if newIdx < 1 then
        newIdx = 1
    elseif newIdx > #SpeedLevels then
        newIdx = #SpeedLevels
    end

    if newIdx ~= currentIndex then
        currentIndex = newIdx
        SyncHud()
        ShowSpeedDisplay()
        return true
    end
    return false
end

---Прямая установка уровня скорости (поддержка номера режима 1..4 или значения скорости)
local function SetSpeedLevelDirect(lvl)
    if CheckIsOverweight() then
        if currentIndex ~= 1 then
            currentIndex = 1
            SyncHud()
        end
        ShowSpeedDisplay()
        return false
    end

    local val = tonumber(lvl)
    if not val then return false end

    -- Если передан номер режима (1..4)
    if val >= 1 and val <= #SpeedLevels and math.floor(val) == val then
        currentIndex = val
        SyncHud()
        ShowSpeedDisplay()
        return true
    end

    -- Если передано конкретное значение скорости, ищем ближайший режим по walk или sprint
    local closestIdx = DEFAULT_INDEX
    local minDiff = 999.0
    for i, data in ipairs(SpeedLevels) do
        for _, target in ipairs({ data.walk, data.sprint }) do
            local diff = math.abs(target - val)
            if diff < minDiff then
                minDiff = diff
                closestIdx = i
            end
        end
    end

    currentIndex = closestIdx
    SyncHud()
    ShowSpeedDisplay()
    return true
end

-- =================================================================
-- ГЛАВНЫЙ ПОТОК УПРАВЛЕНИЯ И ПРИМЕНЕНИЯ СКОРОСТИ
-- =================================================================

CreateThread(function()
    Wait(500)
    SyncHud()

    while true do
        Wait(0)
        local ped = PlayerPedId()

        if DoesEntityExist(ped) and not IsPlayerIncapacitated(ped) then
            local isAltPressed = IsControlPressed(0, Controls.ALT_HUD_SPECIAL) or IsDisabledControlPressed(0, Controls.ALT_HUD_SPECIAL)
                or IsControlPressed(0, Controls.ALT_FALLBACK) or IsDisabledControlPressed(0, Controls.ALT_FALLBACK)
            local isShiftPressed = IsControlPressed(0, Controls.SPRINT) or IsDisabledControlPressed(0, Controls.SPRINT)

            local overweightActive = CheckIsOverweight()
            if overweightActive then
                if currentIndex ~= 1 then
                    if not previousSpeedIndex then
                        previousSpeedIndex = currentIndex
                    end
                    currentIndex = 1
                    SyncHud()
                    ShowSpeedDisplay()
                end
            elseif previousSpeedIndex and not overweightActive then
                currentIndex = previousSpeedIndex
                previousSpeedIndex = nil
                SyncHud()
                ShowSpeedDisplay()
            end

            -- 1. Вычисляем текущую скорость: обычная ходьба vs зажатый Shift
            local levelData = SpeedLevels[currentIndex] or SpeedLevels[DEFAULT_INDEX]
            if isShiftPressed then
                currentActiveSpeed = levelData.sprint
            else
                currentActiveSpeed = levelData.walk
            end

            -- 2. Применение скорости к персонажу на ногах
            ApplyMovementSpeed(ped, currentActiveSpeed, isShiftPressed, false)

            -- 3. Перехват управления скоростью (Alt + Колесико мыши / Стрелки / R)
            if isAltPressed then
                -- Блокируем селектор оружия при зажатом Alt
                for _, c in ipairs(WHEEL_CONTROLS) do
                    DisableControlAction(0, c, true)
                end

                -- Скролл вверх / Стрелка вверх
                local isWheelUp = IsDisabledControlJustPressed(0, 0xF78D7337) or IsControlJustPressed(0, 0xF78D7337)
                    or IsDisabledControlJustPressed(0, 0xCC1075A7) or IsControlJustPressed(0, 0xCC1075A7)
                    or IsDisabledControlJustPressed(0, 0x6319DB71) or IsControlJustPressed(0, 0x6319DB71)
                    or IsDisabledControlJustPressed(0, 0x911CB09E) or IsControlJustPressed(0, 0x911CB09E)

                -- Скролл вниз / Стрелка вниз
                local isWheelDown = IsDisabledControlJustPressed(0, 0xD0842EDF) or IsControlJustPressed(0, 0xD0842EDF)
                    or IsDisabledControlJustPressed(0, 0xFD0F0C2C) or IsControlJustPressed(0, 0xFD0F0C2C)
                    or IsDisabledControlJustPressed(0, 0x05CA7C52) or IsControlJustPressed(0, 0x05CA7C52)
                    or IsDisabledControlJustPressed(0, 0x4403F97F) or IsControlJustPressed(0, 0x4403F97F)

                if isWheelUp or isWheelDown or IsControlJustPressed(0, Controls.RESET_SPEED) or IsDisabledControlJustPressed(0, Controls.RESET_SPEED)
                    or IsControlJustPressed(0, Controls.MAX_SPEED) or IsDisabledControlJustPressed(0, Controls.MAX_SPEED)
                    or IsControlJustPressed(0, Controls.MIN_SPEED) or IsDisabledControlJustPressed(0, Controls.MIN_SPEED) then
                    if overweightActive then
                        currentIndex = 1
                        SyncHud()
                        ShowSpeedDisplay()
                    else
                        if isWheelUp then
                            AdjustSpeedIndex(1)
                        elseif isWheelDown then
                            AdjustSpeedIndex(-1)
                        elseif IsControlJustPressed(0, Controls.RESET_SPEED) or IsDisabledControlJustPressed(0, Controls.RESET_SPEED) then
                            currentIndex = DEFAULT_INDEX
                            SyncHud()
                            ShowSpeedDisplay()
                        elseif IsControlJustPressed(0, Controls.MAX_SPEED) or IsDisabledControlJustPressed(0, Controls.MAX_SPEED) then
                            currentIndex = #SpeedLevels
                            SyncHud()
                            ShowSpeedDisplay()
                        elseif IsControlJustPressed(0, Controls.MIN_SPEED) or IsDisabledControlJustPressed(0, Controls.MIN_SPEED) then
                            currentIndex = 1
                            SyncHud()
                            ShowSpeedDisplay()
                        end
                    end
                end
            end

            -- 4. Временная текстовая подсказка при смене скорости
            if GetGameTimer() < showSpeedTimer then
                local ind = GetSpeedIndicator()
                local text
                if overweightActive then
                    text = string.format("~COLOR_RED~[ПЕРЕГРУЗ] Скорость [1/%d]: без Shift %.1f | с Shift %.1f (Заблокировано)~COLOR_WHITE~", #SpeedLevels, levelData.walk, levelData.sprint)
                else
                    text = string.format("Скорость [%d/%d]: без Shift %.1f | с Shift %.1f  %s", currentIndex, #SpeedLevels, levelData.walk, levelData.sprint, ind)
                end
                DrawText2D(text)
            end
        end
    end
end)

-- Отдельный постоянный enforcement-поток. Некоторые игровые задачи и
-- сторонние ресурсы сбрасывают movement blend после спавна или смены походки.
-- Повторное применение здесь не зависит от UI, админ-меню и текстовых подсказок.
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()

        if DoesEntityExist(ped) and not IsPlayerIncapacitated(ped) then
            local levelData = SpeedLevels[currentIndex] or SpeedLevels[DEFAULT_INDEX]
            local isShiftPressed = IsControlPressed(0, Controls.SPRINT) or IsDisabledControlPressed(0, Controls.SPRINT)
            isPhysicalShift = isShiftPressed
            currentActiveSpeed = isShiftPressed and levelData.sprint or levelData.walk

            local hasInput = (
                IsControlPressed(0, 0x8FD015D8) or IsDisabledControlPressed(0, 0x8FD015D8) -- W
                or IsControlPressed(0, 0xD27782E3) or IsDisabledControlPressed(0, 0xD27782E3) -- S
                or IsControlPressed(0, 0x7065027D) or IsDisabledControlPressed(0, 0x7065027D) -- A
                or IsControlPressed(0, 0xB4E465B4) or IsDisabledControlPressed(0, 0xB4E465B4) -- D
                or math.abs(GetControlNormal(0, 0x4D8FB4C1)) > 0.1
                or math.abs(GetControlNormal(0, 0xFDA83190)) > 0.1
            )

            ApplyMovementSpeed(ped, currentActiveSpeed, isShiftPressed, hasInput)
        else
            isPhysicalShift = false
            Wait(250)
        end
    end
end)

-- KeyMapping команды для клавиш UP / DOWN
RegisterCommand('+walkspeed_up', function()
    local isAlt = IsControlPressed(0, Controls.ALT_HUD_SPECIAL) or IsDisabledControlPressed(0, Controls.ALT_HUD_SPECIAL)
        or IsControlPressed(0, Controls.ALT_FALLBACK) or IsDisabledControlPressed(0, Controls.ALT_FALLBACK)
    if isAlt then
        AdjustSpeedIndex(1)
    end
end, false)
RegisterCommand('-walkspeed_up', function() end, false)

RegisterCommand('+walkspeed_down', function()
    local isAlt = IsControlPressed(0, Controls.ALT_HUD_SPECIAL) or IsDisabledControlPressed(0, Controls.ALT_HUD_SPECIAL)
        or IsControlPressed(0, Controls.ALT_FALLBACK) or IsDisabledControlPressed(0, Controls.ALT_FALLBACK)
    if isAlt then
        AdjustSpeedIndex(-1)
    end
end, false)
RegisterCommand('-walkspeed_down', function() end, false)

if RegisterKeyMapping then
    pcall(RegisterKeyMapping, '+walkspeed_up', 'Увеличить скорость ходьбы', 'keyboard', 'UP')
    pcall(RegisterKeyMapping, '+walkspeed_down', 'Уменьшить скорость ходьбы', 'keyboard', 'DOWN')
end

-- Консольные команды для чата
RegisterCommand('speed', function(source, args)
    local val = tonumber(args[1])
    if val then SetSpeedLevelDirect(val) end
end, false)

RegisterCommand('walkspeed', function(source, args)
    local val = tonumber(args[1])
    if val then SetSpeedLevelDirect(val) end
end, false)

-- Синхронизация при выборе и спавне персонажа
RegisterNetEvent("thehunt:character:selected", function()
    Wait(1500)
    SyncHud()
end)

AddEventHandler("thehunt:player:spawned", function()
    Wait(1500)
    SyncHud()
end)

local function ApplyCurrentSpeed()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) and IsPedOnFoot(ped) then
        local levelData = SpeedLevels[currentIndex] or SpeedLevels[DEFAULT_INDEX]
        local isShiftPressed = IsControlPressed(0, Controls.SPRINT) or IsDisabledControlPressed(0, Controls.SPRINT)
        isPhysicalShift = isShiftPressed
        currentActiveSpeed = isShiftPressed and levelData.sprint or levelData.walk
        ApplyMovementSpeed(ped, currentActiveSpeed, isShiftPressed, false)
    end
    SyncHud()
end

-- Экспорты для thehunt_stamina, thehunt_menu и других систем
exports('GetCurrentSpeed', function()
    return currentActiveSpeed or 1.0
end)

exports('GetCurrentSpeedIndex', function()
    return currentIndex or DEFAULT_INDEX
end)

exports('GetSpeedLevels', function()
    return SpeedLevels
end)

exports('SetSpeed', SetSpeedLevelDirect)
exports('SetSpeedLevelDirect', SetSpeedLevelDirect)
exports('ApplyCurrentSpeed', ApplyCurrentSpeed)
exports('IsShiftPressed', function()
    return isPhysicalShift == true
end)
