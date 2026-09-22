-- =================================================================
-- HUNT: Hard RP — The Corruption | Status, Cores & Buffs Client Main
-- =================================================================

local activeEffects = {}
local isCharacterReady = false

-- Текущие показатели игрока
local currentHealth = 100
local currentGhostHealth = nil
local currentStamina = 100
local currentHorseHealth = 100
local currentHorseStamina = 100
local currentHunger = 100
local currentThirst = 100
local currentVoiceMode = 2 -- 1=Шепот (33%), 2=Обычный (66%), 3=Крик (100%)
local currentSpeedPercent = 66
local isPlayerTalking = false
local isHudCurrentlyVisible = false
local horseSprintLocked = false
local injuryMovementApplied = false
local injuryMovementPed = 0

local HORSE_SPRINT_CONTROLS = {
    0x5AA007D7, -- INPUT_HORSE_SPRINT (RedM)
    0x8FFC75D6  -- INPUT_SPRINT (also active while mounted)
}
local HORSE_SPRINT_UNLOCK_PCT = 50.0
local SET_ATTRIBUTE_BASE_RANK_NATIVE = 0x5DA12E025D47D4E5
local GET_ATTRIBUTE_BASE_RANK_NATIVE = 0x147149F2E909323C
local protectedPlayerRanks = {}
local protectedPlayerMaxHealth = {}
local protectedHorseHealthRank = nil
local protectedHorseStaminaRank = nil
local protectedHorseEntity = 0

local function ResetProtectedAttributeRanks()
    protectedPlayerRanks = {}
    protectedHorseHealthRank = nil
    protectedHorseStaminaRank = nil
    protectedHorseEntity = 0
end

-- Keep the injury presentation independent from player-selected walk styles.
-- RedM's native injured-movement flag supplies the subtle forward lean/limp
-- without calling SetPedMovementClipset or overwriting saved locomotion.
local function UpdateLowHealthInjury(ped, healthPercent)
    local injuryConfig = Config.LowHealthInjury
    local shouldApply = injuryConfig and injuryConfig.enabled
        and healthPercent > 0
        and healthPercent <= (tonumber(injuryConfig.threshold) or 30)
        and not IsEntityDead(ped)
        and not IsPedDeadOrDying(ped, true)
        and not IsPedOnMount(ped)
        and not LocalPlayer.state.thehuntUnconscious

    if injuryMovementPed ~= 0 and injuryMovementPed ~= ped and DoesEntityExist(injuryMovementPed) then
        SetPedConfigFlag(injuryMovementPed, injuryConfig.pedConfigFlag, false)
        injuryMovementApplied = false
    end
    injuryMovementPed = ped

    if shouldApply == injuryMovementApplied then
        return
    end

    SetPedConfigFlag(ped, injuryConfig.pedConfigFlag, shouldApply)
    injuryMovementApplied = shouldApply
end

local function ClearLowHealthInjury()
    if injuryMovementApplied and injuryMovementPed ~= 0 and DoesEntityExist(injuryMovementPed) then
        local injuryConfig = Config.LowHealthInjury
        SetPedConfigFlag(injuryMovementPed, injuryConfig.pedConfigFlag, false)
    end
    injuryMovementApplied = false
    injuryMovementPed = 0
end

local function ReadAttributeBaseRank(entity, attributeIndex)
    local ok, value = pcall(function()
        return Citizen.InvokeNative(
            GET_ATTRIBUTE_BASE_RANK_NATIVE,
            entity,
            attributeIndex,
            Citizen.ResultAsInteger()
        )
    end)
    if not ok then return nil end
    return tonumber(value)
end

-- Preserve the attribute/tank base rank (the maximum available outer limit),
-- not the current core value. Current health, stamina, and their cores remain
-- free to drain and recover through the existing game/resource rules.
local function PreserveAttributeMaxRank(entity, attributeIndex, savedRank)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return savedRank
    end

    local currentRank = ReadAttributeBaseRank(entity, attributeIndex)
    if not currentRank or currentRank < 0 then
        return savedRank
    end

    if not savedRank or currentRank > savedRank then
        return currentRank
    end

    if currentRank < savedRank then
        pcall(function()
            Citizen.InvokeNative(SET_ATTRIBUTE_BASE_RANK_NATIVE, entity, attributeIndex, savedRank)
        end)
    end
    return savedRank
end

local function RestorePlayerVitalsCapacity(ped)
    local target = ped or PlayerPedId()
    if not target or target == 0 or not DoesEntityExist(target) then
        return false
    end

    protectedPlayerRanks[0] = PreserveAttributeMaxRank(target, 0, protectedPlayerRanks[0])
    protectedPlayerRanks[1] = PreserveAttributeMaxRank(target, 1, protectedPlayerRanks[1])

    local model = GetEntityModel(target)
    local maximum = tonumber(GetEntityMaxHealth(target)) or 0
    local baseline = protectedPlayerMaxHealth[model]
    if maximum > 0 and (not baseline or maximum > baseline) then
        protectedPlayerMaxHealth[model] = maximum
    elseif baseline and maximum > 0 and maximum < baseline then
        local health = GetEntityHealth(target)
        SetEntityMaxHealth(target, baseline)
        -- Restoring capacity must not heal wounds or revive the player.
        if GetEntityHealth(target) ~= health then
            SetEntityHealth(target, health, 0)
        end
    end

    return true
end

exports('RestorePlayerVitalsCapacity', function()
    return RestorePlayerVitalsCapacity(PlayerPedId())
end)

-- The HUNT admin menu sends this immediately before VORP's revive event. It
-- lets the normal VORP heal step see the preserved capacity after ResurrectPed.
RegisterNetEvent('thehunt_admin:prepareReviveClient', function()
    RestorePlayerVitalsCapacity(PlayerPedId())
end)

Citizen.CreateThread(function()
    while true do
        if isCharacterReady then
            local ped = PlayerPedId()
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local isDead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
                if IsPedHuman(ped) and not LocalPlayer.state.huntPedCustomActive
                    and not LocalPlayer.state.isCreatingChar and not LocalPlayer.state.isSelectingChar
                    and not isDead then
                    RestorePlayerVitalsCapacity(ped)
                end

                if not isDead and IsPedOnMount(ped) then
                    local mount = GetMount(ped)
                    if mount ~= protectedHorseEntity then
                        protectedHorseEntity = mount or 0
                        protectedHorseHealthRank = nil
                        protectedHorseStaminaRank = nil
                    end
                    protectedHorseHealthRank = PreserveAttributeMaxRank(mount, 0, protectedHorseHealthRank)
                    protectedHorseStaminaRank = PreserveAttributeMaxRank(mount, 1, protectedHorseStaminaRank)
                else
                    protectedHorseEntity = 0
                    protectedHorseHealthRank = nil
                    protectedHorseStaminaRank = nil
                end
            end
            Citizen.Wait(50)
        else
            Citizen.Wait(500)
        end
    end
end)

local function ApplyHudVisibility(visible)
    local shouldBeVisible = (visible == true)
    if shouldBeVisible and not isCharacterReady then
        ResetProtectedAttributeRanks()
    end
    isCharacterReady = shouldBeVisible
    isHudCurrentlyVisible = shouldBeVisible
    SendNUIMessage({
        type = "SET_HUD_VISIBLE",
        visible = shouldBeVisible
    })
end

local function IsCharacterInWorld()
    if LocalPlayer.state.isCreatingChar or LocalPlayer.state.isSelectingChar then
        return false
    end

    local menuOk, characterMenuOpen = pcall(function()
        return exports["thehunt_character"]:isCharacterMenuOpen()
    end)
    if menuOk and characterMenuOpen == true then
        return false
    end

    local selectedOk, characterSelected = pcall(function()
        return exports["thehunt_character"]:isCharacterSelected()
    end)
    if selectedOk and characterSelected == true then
        return true
    end

    -- После restart thehunt_character его локальный флаг сбрасывается,
    -- хотя уже существующий ped игрока остаётся в игровом мире. В этом
    -- случае используем готовность core/сам факт существования ped.
    local coreOk, coreReady = pcall(function()
        return exports["thehunt_core"]:isCharacterReady()
    end)
    if coreOk and coreReady == true then
        return true
    end

    local ped = PlayerPedId()
    return ped and ped ~= 0 and DoesEntityExist(ped)
end

local function RestoreSavedDisplayModes()
    local savedHudMode = GetResourceKvpString("thehunt_status_hud_mode")
    if savedHudMode == "always_on" or savedHudMode == "dynamic" or savedHudMode == "always_off" then
        TriggerEvent("thehunt_status:setHudMode", savedHudMode)
    end

    local savedQuickSlotsMode = GetResourceKvpString("thehunt_status_quickslots_mode")
    if savedQuickSlotsMode == "always_on" or savedQuickSlotsMode == "dynamic" or savedQuickSlotsMode == "always_off" then
        TriggerEvent("thehunt_status:setQuickSlotsMode", savedQuickSlotsMode)
    end

    local savedHintsMode = GetResourceKvpString("thehunt_status_hints_mode")
    if savedHintsMode == "always_on" or savedHintsMode == "dynamic" or savedHintsMode == "always_off" then
        TriggerEvent("thehunt_status:setHintsMode", savedHintsMode)
    end
end

local function RestoreHudAfterRestart()
    if not IsCharacterInWorld() then return false end

    RestoreSavedDisplayModes()
    exports.thehunt_core:SetMetabolismHud(false)
    ApplyHudVisibility(true)
    return true
end

-- Регистрация видимости HUD из других систем (например, экран выбора персонажа)
RegisterNetEvent("thehunt_status:setVisible", function(visible)
    ApplyHudVisibility(visible)
end)

exports('SetVisible', function(visible)
    TriggerEvent("thehunt_status:setVisible", visible)
end)

-- Регистрация превью отхила от медицины
RegisterNetEvent("thehunt_status:setHealPreview", function(targetHealth)
    currentGhostHealth = targetHealth and tonumber(targetHealth) or nil
end)

exports('SetHealPreview', function(targetHealth)
    currentGhostHealth = targetHealth and tonumber(targetHealth) or nil
end)

-- Показ HUD только после выбора персонажа
RegisterNetEvent("thehunt:character:selected", function()
    exports.thehunt_core:SetMetabolismHud(false)
    ApplyHudVisibility(true)
end)

AddEventHandler("thehunt:player:spawned", function()
    exports.thehunt_core:SetMetabolismHud(false)
    ApplyHudVisibility(true)
end)

-- После restart status его локальные флаги сбрасываются, хотя персонаж уже
-- находится в мире. Восстанавливаем только свой HUD, не вызывая повторный
-- выбор персонажа и не затрагивая остальные ресурсы.
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.CreateThread(function()
        Citizen.Wait(250)
        -- Ресурсы персонажа/core могут завершать restart чуть позже status.
        -- Повторяем проверку несколько секунд, чтобы HUD не оставался
        -- невидимым до следующего ручного выбора персонажа.
        for _ = 1, 20 do
            if RestoreHudAfterRestart() then return end
            Citizen.Wait(500)
        end
    end)
end)

-- Прием обновлений сытости и жажды от vorp_metabolism
RegisterNetEvent("thehunt_status:updateMetabolism", function(hunger, thirst)
    if hunger ~= nil then
        if hunger <= 1.0 then
            currentHunger = math.floor(hunger * 100)
        elseif hunger > 100 then
            currentHunger = math.floor((hunger / 1000) * 100)
        else
            currentHunger = math.floor(hunger)
        end
    end

    if thirst ~= nil then
        if thirst <= 1.0 then
            currentThirst = math.floor(thirst * 100)
        elseif thirst > 100 then
            currentThirst = math.floor((thirst / 1000) * 100)
        else
            currentThirst = math.floor(thirst)
        end
    end
end)

exports('UpdateMetabolism', function(hunger, thirst)
    TriggerEvent("thehunt_status:updateMetabolism", hunger, thirst)
end)

-- Прием обновления скорости передвижения (из thehunt_walking)
RegisterNetEvent("thehunt_status:setSpeedPercent", function(pct)
    currentSpeedPercent = tonumber(pct) or 66
    SendNUIMessage({
        action = "setWalkSpeed",
        percent = currentSpeedPercent
    })
end)

-- Переключение режима статус-худа (always_on, dynamic, always_off)
RegisterNetEvent("thehunt_status:setHudMode", function(mode)
    if mode == "always_on" or mode == "dynamic" or mode == "always_off" then
        SendNUIMessage({
            type = "SET_HUD_MODE",
            mode = mode
        })
    end
end)

exports('SetHudMode', function(mode)
    TriggerEvent("thehunt_status:setHudMode", mode)
end)

RegisterNetEvent("thehunt_status:setQuickSlotsMode", function(mode)
    if mode == "always_on" or mode == "dynamic" or mode == "always_off" then
        SendNUIMessage({
            type = "SET_QUICK_SLOTS_MODE",
            mode = mode
        })
    end
end)

RegisterNetEvent("thehunt_status:setQuickSlots", function(slots)
    SendNUIMessage({
        type = "SET_QUICK_SLOTS",
        slots = slots or {}
    })
end)

exports('SetQuickSlotsMode', function(mode)
    TriggerEvent("thehunt_status:setQuickSlotsMode", mode)
end)

-- Переключение режима HUD подсказок (always_on, dynamic, always_off)
RegisterNetEvent("thehunt_status:setHintsMode", function(mode)
    if mode == "always_on" or mode == "dynamic" or mode == "always_off" then
        SendNUIMessage({
            type = "SET_HINTS_MODE",
            mode = mode
        })
    end
end)

exports('SetHintsMode', function(mode)
    TriggerEvent("thehunt_status:setHintsMode", mode)
end)

-- Слушаем переключение дальности войс-чата (pma-voice)
RegisterNetEvent("pma-voice:setTalkingMode", function(mode)
    currentVoiceMode = tonumber(mode) or 2
end)

AddStateBagChangeHandler('proximity', nil, function(bagName, key, value, _unused, _replicated)
    if value then
        if type(value) == "table" and value.index then
            currentVoiceMode = tonumber(value.index) or 2
        elseif type(value) == "number" then
            if value <= 2.2 then
                currentVoiceMode = 1
            elseif value <= 8.0 then
                currentVoiceMode = 2
            else
                currentVoiceMode = 3
            end
        end
    end
end)

-- 1. ПОТОК ПОЛНОГО ОТКЛЮЧЕНИЯ РАДАРА В КАЖДОМ КАДРЕ
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        -- Полное отключение радара и миникарты
        DisplayRadar(false)
        SetMinimapType(0)

        -- Скрытие худа в меню паузы / загрузке
        local isPaused = IsPauseMenuActive() or IsScreenFadedOut() or (NetworkIsInSpectatorMode and NetworkIsInSpectatorMode())
        if isPaused and isHudCurrentlyVisible then
            isHudCurrentlyVisible = false
            SendNUIMessage({ type = "SET_HUD_VISIBLE", visible = false })
        elseif not isPaused and not isHudCurrentlyVisible and isCharacterReady then
            isHudCurrentlyVisible = true
            SendNUIMessage({ type = "SET_HUD_VISIBLE", visible = true })
        end
    end
end)

-- 2. ГЛАВНЫЙ ЦИКЛ СЧИТЫВАНИЯ ЗДОРОВЬЯ, ВЫНОСЛИВОСТИ И ВОЙСА (каждые 80мс)
Citizen.CreateThread(function()
    while true do
        if isCharacterReady and isHudCurrentlyVisible then
            Citizen.Wait(80)
            local ped = PlayerPedId()
            local playerId = PlayerId()

            -- Полное отключение авто-восстановления HP
            SetPlayerHealthRechargeMultiplier(playerId, 0.0)

            -- 1. Здоровье игрока
            local maxHp = GetEntityMaxHealth(ped)
            if maxHp <= 0 then maxHp = 100 end
            local curHp = GetEntityHealth(ped)
            local hpPct = math.floor((curHp / maxHp) * 100)
            if hpPct > 100 then hpPct = 100 elseif hpPct < 0 then hpPct = 0 end
            currentHealth = hpPct
            UpdateLowHealthInjury(ped, hpPct)

            -- 2. Выносливость игрока (Stamina / Sprint)
            local stamVal = nil
            pcall(function()
                if exports["thehunt_stamina"] and exports["thehunt_stamina"].GetCurrentStamina then
                    stamVal = exports["thehunt_stamina"]:GetCurrentStamina()
                end
            end)

            if stamVal == nil then
                local curStam = Citizen.InvokeNative(0x22F2A386D43048A9, ped, Citizen.ResultAsFloat()) or 100.0
                if curStam ~= nil then
                    if curStam <= 1.0 and curStam > 0.0 then
                        stamVal = math.floor(curStam * 100)
                    elseif curStam > 100 then
                        stamVal = math.floor((curStam / 1000) * 100)
                    else
                        stamVal = math.floor(curStam)
                    end
                end
            end

            local stamPct = math.floor(tonumber(stamVal) or 100)
            if stamPct > 100 then stamPct = 100 elseif stamPct < 0 then stamPct = 0 end
            currentStamina = stamPct

            -- 2.1. Здоровье и выносливость лошади показываются только во время езды верхом.
            -- В одном кольце учитываем и внешнюю шкалу, и ядро:
            -- отображаем результирующее значение, чтобы просадка любого показателя была видна.
            local horseMounted = false
            local horseHealthPct = 0
            local horseStaminaPct = 0
            local horseStaminaCorePct = 0
            -- The single HUD ring uses the combined outer/core percentage.
            if IsPedOnMount(ped) then
                local mount = GetMount(ped)
                if mount and mount ~= 0 and DoesEntityExist(mount) then
                    horseMounted = true

                    -- 1. Здоровье лошади: внешняя шкала HP + ядро здоровья
                    if IsEntityDead(mount) or IsPedDeadOrDying(mount, true) then
                        horseHealthPct = 0
                    else
                        local hCur = GetEntityHealth(mount)
                        local hMax = GetEntityMaxHealth(mount)
                        if hMax <= 0 then hMax = 100 end
                        local outerHpPct = math.floor((hCur / hMax) * 100)
                        if outerHpPct > 100 then outerHpPct = 100 elseif outerHpPct < 0 then outerHpPct = 0 end

                        local hCoreVal = nil
                        pcall(function()
                            hCoreVal = Citizen.InvokeNative(0x36731AC041289BB1, mount, 0, Citizen.ResultAsInteger())
                        end)
                        hCoreVal = tonumber(hCoreVal)
                        if hCoreVal then
                            if hCoreVal > 100 then hCoreVal = 100 elseif hCoreVal < 0 then hCoreVal = 0 end
                            horseHealthPct = math.floor((outerHpPct * hCoreVal / 100) + 0.5)
                        else
                            horseHealthPct = outerHpPct
                        end
                        if horseHealthPct > 100 then horseHealthPct = 100 elseif horseHealthPct < 0 then horseHealthPct = 0 end
                    end

                    -- 2. Выносливость лошади:
                    local horseStamVal = nil
                    local horseCoreVal = nil
                    pcall(function()
                        horseStamVal = Citizen.InvokeNative(0x22F2A386D43048A9, mount, Citizen.ResultAsFloat())
                    end)

                    horseStamVal = tonumber(horseStamVal)
                    if horseStamVal then
                        if horseStamVal <= 1.0 then
                            horseStaminaPct = math.floor(horseStamVal * 100)
                        elseif horseStamVal > 100 then
                            horseStaminaPct = math.floor((horseStamVal / 1000) * 100)
                        else
                            horseStaminaPct = math.floor(horseStamVal)
                        end
                    end

                    pcall(function()
                        horseCoreVal = Citizen.InvokeNative(0x36731AC041289BB1, mount, 1, Citizen.ResultAsInteger())
                    end)
                    horseCoreVal = tonumber(horseCoreVal)
                    if horseCoreVal then
                        horseStaminaCorePct = math.floor(horseCoreVal)
                    end

                    -- Если внешнее значение недоступно, используем ядро как запасной источник.
                    if horseStaminaCorePct > 100 then horseStaminaCorePct = 100 elseif horseStaminaCorePct < 0 then horseStaminaCorePct = 0 end
                    if not horseStamVal then
                        horseStaminaPct = horseStaminaCorePct
                    elseif horseCoreVal then
                        horseStaminaPct = math.floor((horseStaminaPct * horseStaminaCorePct / 100) + 0.5)
                    end
                    if horseStaminaPct > 100 then horseStaminaPct = 100 elseif horseStaminaPct < 0 then horseStaminaPct = 0 end
                end
            end
            currentHorseHealth = horseHealthPct
            currentHorseStamina = horseStaminaPct

            -- Ускорение сначала может полностью израсходовать общий запас.
            -- После достижения 0% фиксируем блокировку до восстановления 15%.
            if horseMounted then
                if horseSprintLocked then
                    if currentHorseStamina >= HORSE_SPRINT_UNLOCK_PCT then
                        horseSprintLocked = false
                    end
                elseif currentHorseStamina <= 0 then
                    horseSprintLocked = true
                end
            end

            -- 3. Режим дальности войса
            local prox = LocalPlayer.state.proximity
            if type(prox) == "table" and prox.index then
                currentVoiceMode = tonumber(prox.index) or 2
            elseif type(prox) == "number" then
                currentVoiceMode = tonumber(prox) or 2
            end

            -- 4. Голосовой чат (talking state)
            isPlayerTalking = false
            pcall(function()
                isPlayerTalking = (MumbleIsPlayerTalking and MumbleIsPlayerTalking(playerId) == 1)
                    or (NetworkIsPlayerTalking and NetworkIsPlayerTalking(playerId))
                    or false
            end)

            -- Отправка всех данных в NUI
            SendNUIMessage({
                type = "UPDATE_STATUS_VALUES",
                data = {
                    health = currentHealth,
                    healPreview = currentGhostHealth,
                    stamina = currentStamina,
                    horseHealth = currentHorseHealth,
                    horseStamina = currentHorseStamina,
                    horseMounted = horseMounted,
                    food = currentHunger,
                    water = currentThirst,
                    voiceMode = currentVoiceMode,
                    isTalking = isPlayerTalking
                }
            })
        else
            Citizen.Wait(600)
        end
    end
end)

-- Экспорты для других скриптов
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if isCharacterReady and horseSprintLocked then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and IsPedOnMount(ped) then
                for i = 1, #HORSE_SPRINT_CONTROLS do
                    DisableControlAction(0, HORSE_SPRINT_CONTROLS[i], true)
                end
            end
        end
    end
end)

exports('GetPlayerHealth', function() return currentHealth end)
exports('GetPlayerStamina', function() return currentStamina end)
exports('GetPlayerHunger', function() return currentHunger end)
exports('GetPlayerThirst', function() return currentThirst end)
exports('GetHorseHealth', function() return currentHorseHealth end)
exports('GetHorseStamina', function() return currentHorseStamina end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearLowHealthInjury()
    end
end)

-- =================================================================
-- СИСТЕМА ЭФФЕКТОВ И БАФФОВ
-- =================================================================

function AddEffect(effectData)
    if not effectData or not effectData.id then return false end

    local template = Config.EffectTemplates[effectData.id]
    if template then
        effectData.label = effectData.label or template.label
        effectData.color = effectData.color or template.color
        effectData.icon = effectData.icon or template.icon
        if effectData.duration == nil then
            effectData.duration = template.duration
        end
    end

    local durationMs = effectData.duration or 0
    local startTime = GetGameTimer()
    local expiresAt = (durationMs > 0) and (startTime + durationMs) or 0

    local effectEntry = {
        id = effectData.id,
        label = effectData.label or "Эффект",
        icon = effectData.icon or "activity",
        color = effectData.color or "#ffffff",
        duration = durationMs,
        startTime = startTime,
        expiresAt = expiresAt,
        isPersistent = effectData.isPersistent or false,
        metadata = effectData.metadata or {}
    }

    activeEffects[effectData.id] = effectEntry

    SendNUIMessage({
        type = "ADD_EFFECT",
        effect = {
            id = effectEntry.id,
            label = effectEntry.label,
            icon = effectEntry.icon,
            color = effectEntry.color,
            duration = effectEntry.duration,
            expiresAt = effectEntry.expiresAt
        }
    })

    return true
end

function RemoveEffect(effectId)
    if not effectId then return false end
    if activeEffects[effectId] then
        activeEffects[effectId] = nil
        SendNUIMessage({
            type = "REMOVE_EFFECT",
            effectId = effectId
        })
        return true
    end
    return false
end

function HasEffect(effectId)
    if not effectId then return false end
    return activeEffects[effectId] ~= nil
end

function GetActiveEffects()
    return activeEffects
end

function ClearAllEffects()
    activeEffects = {}
    SendNUIMessage({
        type = "CLEAR_ALL_EFFECTS"
    })
end

-- Явно регистрируем API эффектов для других клиентских ресурсов.
-- Это также защищает вызовы при перезапуске ресурсов от отсутствующего экспорта.
exports('AddEffect', AddEffect)
exports('RemoveEffect', RemoveEffect)
exports('HasEffect', HasEffect)
exports('GetActiveEffects', GetActiveEffects)
exports('ClearAllEffects', ClearAllEffects)

RegisterNetEvent("thehunt_status:addEffect", function(effectData)
    AddEffect(effectData)
end)

RegisterNetEvent("thehunt_status:removeEffect", function(effectId)
    RemoveEffect(effectId)
end)

RegisterNetEvent("thehunt_status:clearAll", function()
    ClearAllEffects()
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local now = GetGameTimer()
        for id, eff in pairs(activeEffects) do
            if eff.duration > 0 and eff.expiresAt > 0 and now >= eff.expiresAt then
                RemoveEffect(id)
            end
        end
    end
end)

-- =================================================================
-- ЕДИНАЯ СИСТЕМА УВЕДОМЛЕНИЙ (TOAST NOTIFICATIONS)
-- =================================================================

local function HandleNotification(title, message, notifyType, silent)
    title = title or "Инвентарь"
    message = message or ""

    -- Автоопределение типа уведомления
    if not notifyType then
        local lTitle = string.lower(title)
        local lMsg = string.lower(message)
        if string.find(lTitle, "ошибк") or string.find(lTitle, "организ") or string.find(lMsg, "полн") or string.find(lMsg, "нет ") or string.find(lMsg, "нельзя") or string.find(lMsg, "далеко") or string.find(lMsg, "занят") or string.find(lMsg, "не найден") or string.find(lMsg, "закончилось") then
            notifyType = "error"
        elseif string.find(lTitle, "внимани") or string.find(lMsg, "внимани") or string.find(lTitle, "предупрежд") then
            notifyType = "warning"
        elseif string.find(lMsg, "выпили") or string.find(lMsg, "подобр") or string.find(lMsg, "успешн") or string.find(lMsg, "заселил") or string.find(lTitle, "передач") or string.find(lMsg, "передан") then
            notifyType = "success"
        else
            notifyType = "info"
        end
    end

    -- Мягкие ненавязчивые звуки RedM Frontend
    if not silent then
        if notifyType == "error" then
            PlaySoundFrontend("BACK", "HUD_PLAYER_MENU", true, 0)
        elseif notifyType == "warning" then
            PlaySoundFrontend("NAV_UP_DOWN", "HUD_PLAYER_MENU", true, 0)
        elseif notifyType == "success" then
            PlaySoundFrontend("SELECT", "HUD_PLAYER_MENU", true, 0)
        else
            PlaySoundFrontend("NAV_LEFT_RIGHT", "HUD_PLAYER_MENU", true, 0)
        end
    end

    SendNUIMessage({
        type = 'SHOW_TOAST',
        title = title,
        message = message,
        notifyType = notifyType
    })
end

RegisterNetEvent("thehunt_status:notify", function(title, message, notifyType, silent)
    HandleNotification(title, message, notifyType, silent == true)
end)

-- Отдельный формат для личных сообщений администрации: фоновый градиент
-- сверху по центру с автоматическим таймером. Обычные уведомления не меняются.
RegisterNetEvent("thehunt_status:adminNotification", function(message, duration)
    SendNUIMessage({
        type = 'SHOW_ADMIN_NOTIFICATION',
        title = "Сообщение от администратора",
        message = tostring(message or ""),
        duration = tonumber(duration) or 15000
    })
end)

-- Обратная совместимость
RegisterNetEvent("thehunt_doors:notify", function(title, message, notifyType)
    HandleNotification(title, message, notifyType)
end)

exports('Notify', function(title, message, notifyType, silent)
    HandleNotification(title, message, notifyType, silent == true)
end)

exports('notify', function(title, message, notifyType, silent)
    HandleNotification(title, message, notifyType, silent == true)
end)

-- Local resource event: no extra NUI page and no focus changes.
AddEventHandler('thehunt_status:temperature', function(data)
    SendNUIMessage({ type = 'THERMAL_UPDATE', data = data or false })
end)
