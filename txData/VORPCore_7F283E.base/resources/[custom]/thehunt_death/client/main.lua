local unconscious = false
local wakeAt = 0
local screenVisible = false
local voiceDisabledByUs = false
local lastUiRemaining = nil
local retryAfter = 0
local wakeRequestAfter = 0
local aidedByMedicine = false

-- These are the actual RedM look controls.  0x4D8FB4C1 and 0xFDA83190
-- are MOVE_LR/MOVE_UD (keyboard A/D and W/S), which is why the previous
-- camera implementation rotated when the player pressed WASD.
local LOOK_LEFT_RIGHT = 0xA987235F
local LOOK_UP_DOWN = 0xD2047988
local MOVE_LEFT_RIGHT = 0x4D8FB4C1
local MOVE_UP_DOWN = 0xFDA83190
local MOVE_UP_DOWN_ALT = 0xEDA4707E
local MOVE_UP_DOWN_RDR2 = 0x8FD015D8
local unconsciousCamera = nil
local cameraYaw = 0.0
local cameraPitch = 58.0
local CAMERA_DISTANCE = 3.2

local function stopUnconsciousCamera()
    if not unconsciousCamera then return end
    RenderScriptCams(false, false, 0, true, false, 0)
    DestroyCam(unconsciousCamera, false)
    unconsciousCamera = nil
end

local function startUnconsciousCamera()
    if unconsciousCamera then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cameraYaw = GetEntityHeading(ped)
    cameraPitch = 58.0
    unconsciousCamera = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z + 2.5,
        0.0, 0.0, cameraYaw, GetGameplayCamFov(), true, 0
    )
    SetCamActive(unconsciousCamera, true)
    RenderScriptCams(true, false, 0, true, false, 0)
end

local function updateUnconsciousCamera()
    if not unconsciousCamera then return end

    -- Keep the usual mouse orbit controls available while the movement axes
    -- remain disabled.  Reading the disabled look axes is the same path VORP
    -- uses for its death camera and does not map WASD to camera movement.
    local mouseX = GetDisabledControlNormal(1, LOOK_LEFT_RIGHT)
    local mouseY = GetDisabledControlNormal(1, LOOK_UP_DOWN)
    if math.abs(mouseX) < 0.0001 then mouseX = GetDisabledControlNormal(0, LOOK_LEFT_RIGHT) end
    if math.abs(mouseY) < 0.0001 then mouseY = GetDisabledControlNormal(0, LOOK_UP_DOWN) end
    local normalX = GetControlNormal(0, LOOK_LEFT_RIGHT)
    local normalY = GetControlNormal(0, LOOK_UP_DOWN)
    if math.abs(normalX) > math.abs(mouseX) then mouseX = normalX end
    if math.abs(normalY) > math.abs(mouseY) then mouseY = normalY end

    EnableControlAction(0, LOOK_LEFT_RIGHT, true)
    EnableControlAction(0, LOOK_UP_DOWN, true)
    EnableControlAction(1, LOOK_LEFT_RIGHT, true)
    EnableControlAction(1, LOOK_UP_DOWN, true)
    DisableControlAction(0, MOVE_LEFT_RIGHT, true)
    DisableControlAction(0, MOVE_UP_DOWN, true)
    DisableControlAction(0, MOVE_UP_DOWN_ALT, true)
    DisableControlAction(0, MOVE_UP_DOWN_RDR2, true)
    DisableControlAction(1, MOVE_LEFT_RIGHT, true)
    DisableControlAction(1, MOVE_UP_DOWN, true)
    DisableControlAction(1, MOVE_UP_DOWN_ALT, true)
    DisableControlAction(1, MOVE_UP_DOWN_RDR2, true)
    cameraYaw = cameraYaw - mouseX * 9.0
    cameraPitch = math.max(14.0, math.min(82.0, cameraPitch + mouseY * 8.0))

    local ped = PlayerPedId()
    local target = GetEntityCoords(ped)
    local yawRadians = math.rad(cameraYaw)
    local pitchRadians = math.rad(cameraPitch)
    local horizontal = math.cos(pitchRadians) * CAMERA_DISTANCE
    local cameraX = target.x - math.sin(yawRadians) * horizontal
    local cameraY = target.y + math.cos(yawRadians) * horizontal
    local cameraZ = target.z + math.sin(pitchRadians) * CAMERA_DISTANCE + 0.35

    SetCamCoord(unconsciousCamera, cameraX, cameraY, cameraZ)
    PointCamAtCoord(unconsciousCamera, target.x, target.y, target.z + 0.45)
end

local function setScreenVisible(visible)
    if screenVisible == visible then
        return
    end

    screenVisible = visible
    lastUiRemaining = nil
    SendNUIMessage({ action = visible and 'show' or 'hide' })
end

local function updateScreen()
    if not unconscious then
        return
    end

    local remaining = math.max(0, math.ceil((wakeAt - GetGameTimer()) / 1000))
    if remaining == lastUiRemaining then
        return
    end
    lastUiRemaining = remaining
    SendNUIMessage({
        action = 'update',
        remaining = remaining,
        canWake = remaining <= 0
    })
end

local function setVoiceDisabled(disabled)
    LocalPlayer.state:set('isDead', disabled, true)

    if GetResourceState('pma-voice') ~= 'started' then
        return
    end

    pcall(function()
        if disabled then
            -- pma-voice's supported API: zero outgoing proximity and prevent
            -- F11 from replacing it until the character wakes up.
            exports['pma-voice']:overrideProximityRange(0.0, true)
            voiceDisabledByUs = true
        elseif voiceDisabledByUs then
            exports['pma-voice']:clearProximityOverride()
            voiceDisabledByUs = false
        end
    end)
end

local function setUnconsciousVisuals(enabled)
    pcall(function()
        if enabled then
            AnimpostfxPlay('OJDominoBlur')
            AnimpostfxSetStrength('OJDominoBlur', 0.42)
        else
            AnimpostfxStop('OJDominoBlur')
        end
    end)
end

local function startUnconsciousness()
    if unconscious then
        return
    end

    local ped = PlayerPedId()
    local killerPed = GetPedSourceOfDeath(ped)
    local killerServerId = 0
    if killerPed ~= 0 and IsPedAPlayer(killerPed) then
        local killer = NetworkGetPlayerIndexFromPed(killerPed)
        if killer and killer ~= -1 then
            killerServerId = GetPlayerServerId(killer)
        end
    end

    unconscious = true
    aidedByMedicine = false
    wakeRequestAfter = 0
    wakeAt = GetGameTimer() + Config.UnconsciousDuration * 1000
    startUnconsciousCamera()
    setVoiceDisabled(true)
    setUnconsciousVisuals(true)
    setScreenVisible(true)
    TriggerServerEvent('thehunt_death:server:knocked', killerServerId, GetPedCauseOfDeath(ped))
end

RegisterNetEvent('thehunt_death:client:started', function(remainingSeconds)
    if not unconscious then
        return
    end

    wakeAt = GetGameTimer() + math.max(0, tonumber(remainingSeconds) or Config.UnconsciousDuration) * 1000
    updateScreen()
end)

RegisterNetEvent('thehunt_death:client:sync', function(remainingSeconds)
    if unconscious then
        wakeAt = GetGameTimer() + math.max(0, tonumber(remainingSeconds) or 0) * 1000
        updateScreen()
    end
end)

RegisterNetEvent('thehunt_death:client:restore', function(remainingSeconds)
    if unconscious then return end

    unconscious = true
    wakeRequestAfter = 0
    wakeAt = GetGameTimer() + math.max(0, tonumber(remainingSeconds) or 0) * 1000
    startUnconsciousCamera()
    setVoiceDisabled(true)
    setUnconsciousVisuals(true)
    setScreenVisible(true)
    updateScreen()

    -- Selection normally creates an alive ped. Restore the physical knocked
    -- state after the spawn path has settled, without registering a new death.
    CreateThread(function()
        local deadline = GetGameTimer() + 10000
        while GetGameTimer() < deadline and not LocalPlayer.state.IsInSession do
            Wait(250)
        end

        Wait(1500)

        local ped = PlayerPedId()
        if unconscious and not IsEntityDead(ped) then
            SetEntityHealth(ped, 0)
        end
    end)
end)

RegisterNetEvent('thehunt_death:client:cancel', function()
    unconscious = false
    aidedByMedicine = false
    wakeAt = 0
    wakeRequestAfter = 0
    setVoiceDisabled(false)
    setUnconsciousVisuals(false)
    stopUnconsciousCamera()
    setScreenVisible(false)
    retryAfter = GetGameTimer() + 3000
end)

local function RestoreVitalsCapacityBeforeWake()
    if GetResourceState('thehunt_status') ~= 'started' then return end
    pcall(function()
        exports.thehunt_status:RestorePlayerVitalsCapacity()
    end)
end

local function CalculateWakeHealth(ped, wasAided)
    RestoreVitalsCapacityBeforeWake()
    local maxHp = GetEntityMaxHealth(ped)
    if not maxHp or maxHp <= 0 then maxHp = 600 end
    local isAided = (wasAided == true) or (aidedByMedicine == true)
    local targetPct = isAided and (Config.WakeHealthAided or 25) or (Config.WakeHealthDefault or 10)
    return math.max(10, math.floor(maxHp * (targetPct / 100) + 0.5))
end

-- VORP's authoritative revive path emits this event on the revived client.
-- The VORP controller performs the actual ResurrectPed call; this handler
-- only drops HUNT's knock state, camera, voice lock and NUI.
RegisterNetEvent('vorp_core:Client:OnPlayerRevive', function()
    local wasUnconscious = unconscious
    local isAided = aidedByMedicine == true
    aidedByMedicine = false
    unconscious = false
    wakeAt = 0
    wakeRequestAfter = 0
    setVoiceDisabled(false)
    setUnconsciousVisuals(false)
    stopUnconsciousCamera()
    setScreenVisible(false)
    retryAfter = GetGameTimer() + 3000
    TriggerServerEvent('thehunt_death:server:externalRevive')

    if wasUnconscious then
        CreateThread(function()
            local ped = PlayerPedId()
            local wakeHp = CalculateWakeHealth(ped, isAided)
            for i = 1, 6 do
                Wait(500)
                if DoesEntityExist(ped) and not unconscious and not IsEntityDead(ped) then
                    if GetEntityHealth(ped) > wakeHp then
                        SetEntityHealth(ped, wakeHp, 0)
                    end
                end
            end
        end)
    end
end)

RegisterNetEvent('thehunt_death:client:aidReady', function()
    if not unconscious then return end
    aidedByMedicine = true
    wakeAt = math.max(1, GetGameTimer())
    wakeRequestAfter = 0
    lastUiRemaining = nil
    updateScreen()
end)

RegisterNetEvent('thehunt_death:client:wake', function(wasAided)
    if not unconscious then
        return
    end

    local ped = PlayerPedId()
    ResurrectPed(ped)
    local wakeHp = CalculateWakeHealth(ped, wasAided)
    SetEntityHealth(ped, wakeHp, 0)
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)

    unconscious = false
    aidedByMedicine = false
    wakeAt = 0
    wakeRequestAfter = 0
    setVoiceDisabled(false)
    setUnconsciousVisuals(false)
    stopUnconsciousCamera()
    setScreenVisible(false)
    retryAfter = GetGameTimer() + 3000
    TriggerServerEvent("vorp:ImDead", false)
    TriggerServerEvent('thehunt_death:server:externalRevive')

    CreateThread(function()
        for i = 1, 6 do
            Wait(500)
            if DoesEntityExist(ped) and not unconscious and not IsEntityDead(ped) then
                if GetEntityHealth(ped) > wakeHp then
                    SetEntityHealth(ped, wakeHp, 0)
                end
            end
        end
    end)
end)

CreateThread(function()
    while true do
        if unconscious then
            updateUnconsciousCamera()
            updateScreen()
            local now = GetGameTimer()
            local wakePressed = false
            if wakeAt > 0 and now >= wakeAt then
                -- RedM exposes Space through two jump hashes depending on the
                -- active input context.  Enable and check both control groups
                -- so the key is still detected while the ped is knocked.
                local wakeKeys = { Config.WakeKey, 0xD42E6C65 }
                for _, key in ipairs(wakeKeys) do
                    if key then
                        EnableControlAction(0, key, true)
                        EnableControlAction(1, key, true)
                        if IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key)
                            or IsControlJustPressed(1, key) or IsDisabledControlJustPressed(1, key) then
                            wakePressed = true
                            break
                        end
                    end
                end
            end
            if wakePressed and now >= wakeRequestAfter then
                wakeRequestAfter = now + 1000
                TriggerServerEvent('thehunt_death:server:requestWake')
                Wait(0)
            else
                Wait(0)
            end
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if not unconscious and GetGameTimer() >= retryAfter and IsEntityDead(PlayerPedId()) then
            startUnconsciousness()
            Wait(1000)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        setVoiceDisabled(false)
        setUnconsciousVisuals(false)
        stopUnconsciousCamera()
        setScreenVisible(false)
    end
end)
