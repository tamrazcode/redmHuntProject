local air, rawAir, felt, charId, clothingAt
local warmth, wet, stress = 0.0, 0.0, 0.0
local extreme, nextReaction, reactionUntil = false, 0, 0
local lastPed, nextClothing = nil, 0
local thermalValid = false

local function stopReaction()
    if GetResourceState('thehunt_animations') == 'started' then
        exports.thehunt_animations:SetThermalReaction(nil)
    end
    reactionUntil = 0
end

local function reset()
    stopReaction()
    air, rawAir, felt, charId, clothingAt = nil, nil, nil, nil, nil
    warmth, wet, stress, extreme, nextReaction = 0, 0, 0, false, 0
    thermalValid = false
    TriggerEvent('thehunt_status:temperature', nil)
end

RegisterNetEvent('thehunt_survival:clothing', function(value, id)
    if type(value) ~= 'number' or not id then return end
    if charId and charId ~= id then reset() end
    charId, warmth, clothingAt = id, Thermal.Clamp(value, 0, Config.MaxWarmth), GetGameTimer()
end)

local function ready(ped)
    return ped ~= 0 and DoesEntityExist(ped) and IsPedHuman(ped)
        and exports.thehunt_character:isCharacterSelected()
        and not exports.thehunt_character:isCharacterMenuOpen()
end

CreateThread(function()
    local previous = GetGameTimer()
    while true do
        Wait(Config.TickMs)
        local now, ped = GetGameTimer(), PlayerPedId()
        thermalValid = false
        local dt = Thermal.Clamp((now - previous) / 1000, 0, 3)
        previous = now
        if ped ~= lastPed then reset(); lastPed = ped; nextClothing = 0 end
        if not ready(ped) then
            reset()
        else
            if now >= nextClothing then
                nextClothing = now + 5000
                TriggerServerEvent('thehunt_survival:requestClothing')
            end
            local coords = GetEntityCoords(ped)
            local value = Citizen.InvokeNative(0xB98B78C3768AF6E0, coords.x, coords.y, coords.z, Citizen.ResultAsFloat())
            if type(value) == 'number' and value == value and value > -100 and value < 100 then
                rawAir = value
                air = air and Thermal.Approach(air, value, dt, Config.AirTimeConstant) or value
                local sheltered = GetInteriorFromEntity(ped) ~= 0
                local rain = sheltered and 0 or Citizen.InvokeNative(0x931B5F4CC130224B, Citizen.ResultAsFloat())
                if IsEntityInWater(ped) then wet = 1
                elseif rain > 0.05 then wet = math.min(1, wet + dt * rain / Config.WettingSeconds)
                else wet = math.max(0, wet - dt / Config.DryingSeconds) end
                if clothingAt and now - clothingAt < 20000 then
                    thermalValid = true
                    local target
                    target, felt = Thermal.Target(rawAir, warmth, wet)
                    stress = Thermal.Approach(stress, target, dt, Config.BodyTimeConstant)
                    local severity = math.abs(stress)
                    extreme = severity >= Config.ExtremeEnter or (extreme and severity > Config.ExtremeExit)
                    local incapacitated = IsEntityDead(ped) or LocalPlayer.state.isDead or LocalPlayer.state.thehuntUnconscious or IsPedRagdoll(ped) or IsPedSwimming(ped)
                    if incapacitated or severity < Config.ReactionStart then
                        stopReaction(); nextReaction = now; extreme = false
                    elseif now < reactionUntil or now >= nextReaction then
                        local name = stress < 0 and Config.ColdAnimation or Config.HotAnimation
                        if GetResourceState('thehunt_animations') == 'started' and exports.thehunt_animations:SetThermalReaction(name) then
                            if now >= reactionUntil then
                                reactionUntil = now + Config.ReactionDuration
                                local fraction = Thermal.Clamp((severity - Config.ReactionStart) / (1 - Config.ReactionStart), 0, 1)
                                nextReaction = reactionUntil + Config.LongInterval + (Config.ShortInterval - Config.LongInterval) * fraction
                            end
                        end
                    else stopReaction() end
                else stopReaction() end
                TriggerEvent('thehunt_status:temperature', { air = air, stress = stress, wet = wet })
            else
                stopReaction()
                TriggerEvent('thehunt_status:temperature', nil)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then reset() end
end)

-- Read-only diagnostics: no teleport, temperature override or inventory mutation.
RegisterCommand('survivaldebug', function()
    print(('[survival] native=%s display=%s felt=%s warmth=%.1f wet=%.2f stress=%.3f extreme=%s char=%s'):format(
        tostring(rawAir), tostring(air), tostring(felt), warmth, wet, stress, tostring(extreme), tostring(charId)))
end, false)
exports('GetThermalState', function()
    return { valid = thermalValid and clothingAt ~= nil and GetGameTimer() - clothingAt < 20000 and ready(PlayerPedId()), air = air, nativeAir = rawAir, felt = felt, warmth = warmth, wet = wet, stress = stress, extreme = extreme }
end)
