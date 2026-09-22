--[[
    HUNT: Hard RP — The Corruption | Enhanced Stamina Controller
    Fast Survival Regeneration & Smooth Depletion
--]]

local currentStamina = 100.0
local isExhausted = false
local isStaminaFrozen = false
local lastTime = GetGameTimer()
local wasJumping, jumpPed, jumpRecoveryUntil = false, 0, 0

---Проверка активности заморозки выносливости.
-- Состояние задаётся самим stamina-ресурсом через SetFreezeStamina,
-- поэтому проверка не зависит от порядка запуска status-HUD.
local function IsStaminaFrozenActive()
    return isStaminaFrozen == true
end

---Логирование для отладки
local function DebugLog(msg)
    if Config.Debug then
        print(string.format("[thehunt_stamina] %s", msg))
    end
end

---Проверка недееспособности персонажа
local function IsPlayerIncapacitated(ped)
    if not DoesEntityExist(ped) then return true end
    local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, ped)
    local cuffed = Citizen.InvokeNative(0x74E559B3BC910685, ped)
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedSwimming(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or hogtied or cuffed
end

---Получение текущей скорости из thehunt_walking
local function GetCurrentMovementSpeed(ped)
    local walkingSpeed = nil
    pcall(function()
        if exports["thehunt_walking"] and exports["thehunt_walking"].GetCurrentSpeed then
            walkingSpeed = exports["thehunt_walking"]:GetCurrentSpeed()
        end
    end)

    if walkingSpeed and type(walkingSpeed) == "number" then
        return walkingSpeed
    end

    local speed = GetEntitySpeed(ped)
    if speed > 4.5 then
        return 2.0
    elseif speed > 3.0 then
        return 1.6
    elseif speed > 2.0 then
        return 1.4
    elseif speed > 1.0 then
        return 0.8
    elseif speed > 0.5 then
        return 0.6
    else
        return 0.2
    end
end

---Получение индекса текущего режима (1..4) из thehunt_walking
local function GetCurrentMovementMode()
    local mode = nil
    pcall(function()
        if exports["thehunt_walking"] and exports["thehunt_walking"].GetCurrentSpeedIndex then
            mode = exports["thehunt_walking"]:GetCurrentSpeedIndex()
        end
    end)
    return mode
end

---Расчет скорости списания стамины (в % в секунду)
local function GetDrainRate(modeIdx, selectedSpeed, isShiftPressed)
    -- Без Shift нет расхода за бег; стоимость прыжков считается отдельно.
    if not isShiftPressed then
        return 0.0
    end

    -- Если известен номер режима из thehunt_walking
    if modeIdx == 3 then
        return Config.DrainMode3 or 0.25 -- 3 режим с Shift: около 400 секунд бега
    elseif modeIdx == 4 then
        return Config.DrainMode4 or 0.8 -- 4 режим с Shift: около 125 секунд бега
    elseif modeIdx == 1 or modeIdx == 2 then
        return 0.0 -- 1 и 2 режим с Shift: шаг и ускоренный шаг без расхода
    end

    -- Резервный fallback по значению скорости, если экспорт недоступен
    local rounded = tonumber(string.format("%.1f", selectedSpeed))
    if Config.SpeedDrain and Config.SpeedDrain[rounded] then
        return Config.SpeedDrain[rounded]
    end

    if selectedSpeed >= 1.8 then
        return Config.DrainMode4 or 0.8
    elseif selectedSpeed >= 1.3 then
        return Config.DrainMode3 or 0.25
    else
        return 0.0
    end
end

---Инициализация
local function InitStamina()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        local readStam = Citizen.InvokeNative(0x22F2A386D43048A9, ped, Citizen.ResultAsFloat())
        if readStam and readStam > 0.0 then
            currentStamina = readStam
        else
            currentStamina = 100.0
        end
    end
    lastTime = GetGameTimer()
end

RegisterNetEvent("thehunt:character:selected", function()
    Wait(500)
    InitStamina()
end)

AddEventHandler("thehunt:player:spawned", function()
    Wait(500)
    InitStamina()
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    InitStamina()
end)

-- =================================================================
-- ГЛАВНЫЙ ПОТОК ВЫНОСЛИВОСТИ
-- =================================================================

CreateThread(function()
    InitStamina()

    while true do
        Wait(Config.UpdateInterval)
        local now = GetGameTimer()
        local dt = math.min(0.25, (now - lastTime) / 1000.0)
        lastTime = now

        local ped = PlayerPedId()
        local plyId = PlayerId()

        if DoesEntityExist(ped) and IsPedOnFoot(ped) and not IsPlayerIncapacitated(ped) then
            if IsStaminaFrozenActive() then
                -- Режим бесконечной / замороженной выносливости (Админ)
                currentStamina = 100.0
                isExhausted = false

                pcall(function()
                    Citizen.InvokeNative(0x675680D08A22FC21, ped, 100.0) -- _SET_PED_STAMINA
                    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100.0) -- Stamina Core
                    Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, 100.0) -- Stamina Ring
                end)
                RestorePlayerStamina(plyId, 1.0)
            else
                if jumpPed ~= ped then wasJumping = false; jumpRecoveryUntil = 0; jumpPed = ped end
                local jumping = IsPedJumping(ped)
                if jumping and not wasJumping then
                    currentStamina = math.max(0.0, currentStamina - (Config.JumpCost or 6.0))
                end
                if jumping then jumpRecoveryUntil = now + (Config.JumpRecoveryDelay or 1500) end
                wasJumping = jumping
                local canRecover = now >= jumpRecoveryUntil
                local entitySpeed = GetEntitySpeed(ped)
                local isShiftPressed = IsControlPressed(0, 0x8FFC75D6) 
                    or IsDisabledControlPressed(0, 0x8FFC75D6) 

                if not isShiftPressed then
                    pcall(function()
                        if exports["thehunt_walking"] and exports["thehunt_walking"].IsShiftPressed then
                            isShiftPressed = exports["thehunt_walking"]:IsShiftPressed()
                        end
                    end)
                end
                local isMoving = entitySpeed > Config.MovingSpeedThreshold

                if isMoving then
                    local selectedSpeed = GetCurrentMovementSpeed(ped)
                    local modeIdx = GetCurrentMovementMode()
                    local drainPerSec = GetDrainRate(modeIdx, selectedSpeed, isShiftPressed)

                    -- Умный расход выносливости:
                    -- Списываем только когда drainPerSec > 0 (3 и 4 режимы с Shift)
                    local shouldDrain = (drainPerSec > 0.0) and not isExhausted

                    if shouldDrain then
                        -- 1. Блокируем нативную авто-регенерацию
                        SetPlayerStaminaRechargeMultiplier(plyId, 0.0)

                        -- 2. Списываем выносливость
                        local drainAmount = drainPerSec * dt
                        currentStamina = math.max(0.0, currentStamina - drainAmount)

                        -- 3. Применяем нативы (как ядро стамины, так и внешнее кольцо RDR2)
                        pcall(function()
                            Citizen.InvokeNative(0x675680D08A22FC21, ped, currentStamina + 0.0) -- _SET_PED_STAMINA
                            Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, currentStamina + 0.0) -- Stamina Ring (RDR2 Native HUD)
                        end)

                        -- 4. Если выносливость иссякла (0%), персонаж переходит на шаг
                        if currentStamina <= 0.0 and not isExhausted then
                            isExhausted = true
                            pcall(function()
                                if exports["thehunt_walking"] and exports["thehunt_walking"].SetSpeedLevelDirect then
                                    exports["thehunt_walking"]:SetSpeedLevelDirect(2)
                                end
                            end)
                        end

                        DebugLog(string.format("Бег (скорость %.1f): стамина %.1f (-%.2f%%/с)", selectedSpeed, currentStamina, drainPerSec))
                    else
                        -- Обычная ходьба без Shift — плавное восстановление на ходу
                        local regenPerSec = (Config.RegenWalk or 2.5) * (Config.RechargeMultiplier or 1.0)
                        currentStamina = math.min(100.0, currentStamina + (canRecover and (regenPerSec * dt) or 0.0))

                        pcall(function()
                            Citizen.InvokeNative(0x675680D08A22FC21, ped, currentStamina + 0.0)
                            Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, currentStamina + 0.0)
                        end)

                        if currentStamina > 15.0 and isExhausted then
                            isExhausted = false
                        end
                    end
                else
                    -- Стоя на месте — отдых
                    local regenPerSec = (Config.RegenRest or 5.5) * (Config.RechargeMultiplier or 1.0)
                    currentStamina = math.min(100.0, currentStamina + (canRecover and (regenPerSec * dt) or 0.0))

                    pcall(function()
                        Citizen.InvokeNative(0x675680D08A22FC21, ped, currentStamina + 0.0)
                        Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, currentStamina + 0.0)
                    end)

                    if currentStamina > 15.0 and isExhausted then
                        isExhausted = false
                    end
                end
            end
        else
            wasJumping = false
            Wait(250)
        end
    end
end)

-- =================================================================
-- ЭКСПОРТЫ И СОБЫТИЯ
-- =================================================================

exports('GetCurrentStamina', function()
    return currentStamina
end)

exports('SetCurrentStamina', function(val)
    if val then
        currentStamina = math.max(0.0, math.min(100.0, val + 0.0))
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            pcall(function()
                Citizen.InvokeNative(0x675680D08A22FC21, ped, currentStamina + 0.0)
            end)
        end
    end
end)

exports('SetFreezeStamina', function(frozen)
    isStaminaFrozen = (frozen == true)
    if isStaminaFrozen then
        currentStamina = 100.0
        isExhausted = false
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            pcall(function()
                Citizen.InvokeNative(0x675680D08A22FC21, ped, 100.0)
                Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100.0)
                Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, 100.0)
            end)
            RestorePlayerStamina(PlayerId(), 1.0)
        end
    end
end)

exports('IsStaminaFrozen', function()
    return IsStaminaFrozenActive()
end)

RegisterNetEvent("thehunt_stamina:setFreeze", function(frozen)
    isStaminaFrozen = (frozen == true)
    if isStaminaFrozen then
        currentStamina = 100.0
        isExhausted = false
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            pcall(function()
                Citizen.InvokeNative(0x675680D08A22FC21, ped, 100.0)
                Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100.0)
                Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, 100.0)
            end)
            RestorePlayerStamina(PlayerId(), 1.0)
        end
    end
end)
