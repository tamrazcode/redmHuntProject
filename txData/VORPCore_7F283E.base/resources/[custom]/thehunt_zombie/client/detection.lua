local function isStealthed(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    -- Check entity state bag
    local state = Entity(ped).state
    if state and (state.crouched or state.isCrouched or state.stealth or state.sneaking or state.isSneaking) then
        return true
    end
    -- If local player, check LocalPlayer.state & Duck input
    if ped == PlayerPedId() then
        local lp = LocalPlayer.state
        if lp and (lp.crouched or lp.isCrouched or lp.stealth or lp.sneaking or lp.isSneaking) then
            return true
        end
        -- Check INPUT_DUCK (0xDB096B85: Left Ctrl or Gamepad L3)
        if type(IsControlPressed) == 'function' and (IsControlPressed(0, 0xDB096B85) or (type(IsDisabledControlPressed) == 'function' and IsDisabledControlPressed(0, 0xDB096B85))) then
            return true
        end
    end
    -- Check native duck if function exists
    if type(IsPedDucking) == 'function' and IsPedDucking(ped) then
        return true
    end
    return false
end

local WEATHER_SENSE_MODIFIERS = {
    -- Rain weathers: sleet, rain, thunderstorm, drizzle, shower
    drizzle      = { sight = 0.85, hearing = 0.75 }, -- Мелкий дождь: -15% зрение, -25% слух
    rain         = { sight = 0.78, hearing = 0.60 }, -- Дождь: -22% зрение, -40% слух
    shower       = { sight = 0.75, hearing = 0.55 }, -- Ливень: -25% зрение, -45% слух
    sleet        = { sight = 0.75, hearing = 0.60 }, -- Дождь со снегом/крупой: -25% зрение, -40% слух
    thunderstorm = { sight = 0.70, hearing = 0.50 }, -- Гроза: -30% зрение, -50% слух
    thunder      = { sight = 0.70, hearing = 0.50 }, -- Гром (алиас)

    -- Fog weather: ухудшение слуха и зрения
    fog          = { sight = 0.60, hearing = 0.72 }, -- Густой туман: -40% зрение, -28% слух
    misty        = { sight = 0.65, hearing = 0.75 }, -- Дымка/туман: -35% зрение, -25% слух
}

local WEATHER_HASHES = {
    [GetHashKey('drizzle')]      = 'drizzle',
    [GetHashKey('rain')]         = 'rain',
    [GetHashKey('shower')]       = 'shower',
    [GetHashKey('sleet')]        = 'sleet',
    [GetHashKey('thunderstorm')] = 'thunderstorm',
    [GetHashKey('thunder')]      = 'thunder',
    [GetHashKey('fog')]          = 'fog',
    [GetHashKey('misty')]        = 'misty',
}

local syncedWeather = nil

RegisterNetEvent('weathersync:changeWeather', function(weather)
    if type(weather) == 'string' and weather ~= '' then
        syncedWeather = string.lower(weather)
    end
end)

RegisterNetEvent('weathersync:setMyWeather', function(weather)
    if type(weather) == 'string' and weather ~= '' then
        syncedWeather = string.lower(weather)
    end
end)

local function getCurrentWeatherName()
    if syncedWeather then
        return syncedWeather
    end
    if exports and exports.weathersync then
        local ok, w = pcall(function() return exports.weathersync:getWeather() end)
        if ok and type(w) == 'string' and w ~= '' then
            syncedWeather = string.lower(w)
            return syncedWeather
        end
    end
    if type(GetPrevWeatherTypeHashName) == 'function' then
        local ok, h = pcall(GetPrevWeatherTypeHashName)
        if ok and type(h) == 'number' and WEATHER_HASHES[h] then
            return WEATHER_HASHES[h]
        end
    end
    return nil
end

local function weatherSenseMultiplier()
    -- Rain masks footsteps and breaks up sightlines. Fog blocks visual lines of sight and muffles acoustics.
    local weather = getCurrentWeatherName()
    local wMod = weather and WEATHER_SENSE_MODIFIERS[weather]

    local sight = wMod and wMod.sight or 1.0
    local hearing = wMod and wMod.hearing or 1.0

    -- Dynamic rain level fallback & fine-tuning
    local rain = 0.0
    if type(GetRainLevel) == 'function' then
        local ok, level = pcall(GetRainLevel)
        if ok and type(level) == 'number' and level == level then rain = level end
    end
    rain = math.max(0.0, math.min(1.0, rain))
    if rain > 0.0 then
        local rainSight = 1.0 - (rain * 0.22)
        local rainHearing = 1.0 - (rain * 0.48)
        sight = math.min(sight, rainSight)
        hearing = math.min(hearing, rainHearing)
    end

    return sight, hearing
end

function ZC.visible(r, p)
    if ZC.immune[p.id] or p.dead or r.settings.aggression <= 0 then return false end
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return false end

    -- Zone boundary check: allows aggroed or returning zombies to detect and chase up to 120m beyond zone boundary
    local maxBoundary = (r.state == 'CHASE' or r.state == 'ALERT' or r.state == 'RETURN') and (r.radius + 120.0) or (r.radius + 15.0)
    if not r.goal and r.home and r.radius and Zombie.distance(p.pos, r.home) > maxBoundary then
        return false
    end

    local sightMultiplier = weatherSenseMultiplier()
    local pos = GetEntityCoords(ped)
    local distance = Zombie.distance(pos, p.pos)

    -- Direct close contact (within 3.0m): always detected; avoids capsule occlusion false-negatives in melee
    if distance <= 3.0 then
        return true
    end

    -- If already actively chasing/fighting this player, maintain combat awareness up to 18m without strict frontal FOV
    if r.state == 'CHASE' and r.target == p.id and distance <= 18.0 then
        if type(HasEntityClearLosToEntity) ~= 'function' or HasEntityClearLosToEntity(ped, p.ped, 17) then
            return true
        end
    end

    if distance > ((r.settings.sight or 38.0) * sightMultiplier) or (type(HasEntityClearLosToEntity) == 'function' and not HasEntityClearLosToEntity(ped, p.ped, 17)) then
        return false
    end

    local f = GetEntityForwardVector(ped)
    local dx, dy = p.pos.x - pos.x, p.pos.y - pos.y
    local len = math.sqrt(dx * dx + dy * dy)
    local inFront = (len == 0) or ((dx * f.x + dy * f.y) / len >= math.cos(math.rad((r.settings.fov or 110) * 0.5)))

    -- STEALTH / CROUCHING LOGIC
    if p.crouch then
        -- 1. Behind the zombie: complete blindspot! Can sneak right up behind them.
        -- Only physical body contact (distance <= 1.8m) alerts the zombie.
        if not inFront then
            if distance <= 1.8 then
                return true
            end
            return false
        end

        -- 2. In front of the zombie while in stealth:
        -- Stationary crouched/sneaking: only seen within 7 meters!
        -- Moving crouched/slow-walking: seen within 12 meters!
        local maxStealthDist = math.min((r.settings.sight or 38.0) * sightMultiplier, (p.speed < 0.5) and 7.0 or 12.0)
        if distance > maxStealthDist then return false end

        return (distance <= 2.2) or HasEntityClearLosToEntity(ped, p.ped, 17)
    end

    -- STANDING / NORMAL MOVEMENT (NOT IN STEALTH)
    -- Direct close contact (touching / melee range)
    if distance <= 2.2 then
        return true
    end

    -- 1. In front of the zombie:
    if inFront then
        local maxSight = (r.settings.sight or 38.0) * sightMultiplier
        if distance <= maxSight then
            return HasEntityClearLosToEntity(ped, p.ped, 17)
        end
        return false
    end

    -- Footsteps outside the field of view use the configured hearing path.
    return false
end

function ZC.detect(r)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return nil, math.huge end
    local pos = GetEntityCoords(ped)

    -- Target stickiness: if already pursuing a target, keep that target if still visible
    if r.target then
        for _, p in ipairs(ZC.players) do
            if p.id == r.target and not p.dead and not ZC.immune[p.id] then
                if ZC.visible(r, p) then
                    return p, Zombie.distance(pos, p.pos)
                end
                break
            end
        end
    end

    local chosen, best = nil, math.huge
    for _, p in ipairs(ZC.players) do
        local d = Zombie.distance(pos, p.pos)
        if d < best and ZC.visible(r, p) then chosen, best = p, d end
    end
    return chosen, best
end

RegisterNetEvent('thehunt_zombie:noise', function(pos, radius, kind, player)
    if source ~= 65535 then return end
    -- Personal zombie immunity hides the player, but a gunshot remains a
    -- world event worth investigating. Footsteps and voice stay ignored.
    if player and ZC.immune[player] and kind ~= 'shot' then return end
    local now = GetGameTimer()
    local _, hearingMultiplier = weatherSenseMultiplier()
    for _, r in pairs(ZC.peds) do
        local ped = ZC.entity(r)
        if not r.dead and ped and DoesEntityExist(ped) then
            if r.goal or not r.home or not r.radius or Zombie.distance(pos, r.home) <= (r.radius + 120.0) then
                local distance = Zombie.distance(GetEntityCoords(ped), pos)
                if distance <= math.min(radius * r.settings.hearing * hearingMultiplier, r.settings.hearingDistance * hearingMultiplier) then
                    r.sound = {pos = Zombie.point(pos, ZombieConfig.SoundUncertainty), untilTime = now + ZombieConfig.SoundLifetime, reason = kind, player = player}
                end
            end
        end
    end
end)

local activeZombieSounds = {}

local function getRelativeCamCoords(targetPos)
    local camCoord = (type(GetGameplayCamCoord) == 'function') and GetGameplayCamCoord() or {x=0.0, y=0.0, z=0.0}
    local camRot = (type(GetGameplayCamRot) == 'function') and GetGameplayCamRot(2) or {x=0.0, y=0.0, z=0.0}

    local pitch = math.rad(camRot.x or 0.0)
    local yaw = math.rad(camRot.z or 0.0)
    local cosPitch = math.cos(pitch)
    local sinPitch = math.sin(pitch)
    local cosYaw = math.cos(yaw)
    local sinYaw = math.sin(yaw)

    -- Forward vector (direction camera is pointing)
    local fwdX = -sinYaw * cosPitch
    local fwdY = cosYaw * cosPitch
    local fwdZ = sinPitch

    -- Right vector (horizontal right)
    local rightX = cosYaw
    local rightY = sinYaw
    local rightZ = 0.0

    -- Up vector (right x forward)
    local upX = rightY * fwdZ - rightZ * fwdY
    local upY = rightZ * fwdX - rightX * fwdZ
    local upZ = rightX * fwdY - rightY * fwdX

    local dx = targetPos.x - camCoord.x
    local dy = targetPos.y - camCoord.y
    local dz = targetPos.z - camCoord.z

    local relX = dx * rightX + dy * rightY + dz * rightZ
    local relY = dx * fwdX   + dy * fwdY   + dz * fwdZ
    local relZ = dx * upX    + dy * upY    + dz * upZ
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    return relX, relY, relZ, dist
end

local function resolveZombiePed(zombieId, netId)
    local ped = nil
    if zombieId then
        local r = ZC.peds[zombieId]
        if r then ped = ZC.entity(r) end
        if not ped and ZC.localPeds then ped = ZC.localPeds[zombieId] end
    end
    if (not ped or not DoesEntityExist(ped)) and netId and netId > 0 then
        if type(NetworkDoesNetworkIdExist) == 'function' and NetworkDoesNetworkIdExist(netId) then
            ped = (type(NetToPed) == 'function') and NetToPed(netId) or NetworkGetEntityFromNetworkId(netId)
        end
    end
    if ped and DoesEntityExist(ped) then
        return ped
    end
    return nil
end

local function getPedSoundPosition(ped, fallbackPos)
    if ped and DoesEntityExist(ped) then
        if type(GetPedBoneCoords) == 'function' then
            local bonePos = GetPedBoneCoords(ped, 21030, 0.0, 0.0, 0.0)
            if bonePos and (math.abs(bonePos.x) > 0.01 or math.abs(bonePos.y) > 0.01) then
                return bonePos
            end
        end
        local entPos = GetEntityCoords(ped)
        if entPos and (math.abs(entPos.x) > 0.01 or math.abs(entPos.y) > 0.01) then
            return { x = entPos.x, y = entPos.y, z = entPos.z + 0.8 }
        end
    end
    return fallbackPos
end

ZC.lastAliveSoundStartedAt = 0

function ZC.getActiveAliveSoundCount(nowTime)
    local count = 0
    local now = nowTime or (type(GetGameTimer) == 'function' and GetGameTimer() or 0)
    for _, s in pairs(activeZombieSounds) do
        if s.stage ~= 'death' and now <= (s.expires or 0) then
            count = count + 1
        end
    end
    return count
end

function ZC.canPlayZombieSound(stage, nowTime)
    if stage == 'death' then return true end
    local maxLimit = tonumber(ZombieConfig and ZombieConfig.MaxAliveSounds) or 0
    local minGap = tonumber(ZombieConfig and ZombieConfig.AliveSoundMinGap) or 0

    -- 0 означает, что ограничение отключено (все зомби звучат как раньше)
    if maxLimit <= 0 and minGap <= 0 then
        return true
    end

    local now = nowTime or (type(GetGameTimer) == 'function' and GetGameTimer() or 0)

    if maxLimit > 0 and ZC.getActiveAliveSoundCount(now) >= maxLimit then
        return false
    end

    if minGap > 0 and (now - (ZC.lastAliveSoundStartedAt or 0)) < minGap then
        return false
    end

    return true
end

RegisterNetEvent('thehunt_zombie:ambient', function(arg1, arg2, arg3, arg4, arg5, arg6)
    local zombieId, netId, file, pos, range, stage
    if type(arg1) == 'string' and type(arg2) == 'table' then
        -- Legacy broadcast: (file, pos, range)
        file = arg1
        pos = arg2
        range = arg3
        stage = arg4
    else
        zombieId = arg1
        netId = arg2
        file = arg3
        pos = arg4
        range = arg5
        stage = arg6
    end
    if type(file) ~= 'string' or type(pos) ~= 'table' then return end

    local maxRange = tonumber(range) or ZombieConfig.AmbientSoundRange or 55.0
    local ped = resolveZombiePed(zombieId, netId)
    local currentPos = getPedSoundPosition(ped, pos)
    local relX, relY, relZ, dist = getRelativeCamCoords(currentPos)

    if dist >= maxRange then return end

    -- Ограничение одновременных звуков для живых зомби (не более 2-3 активных звуков вокруг)
    local soundStage = stage or 'idle'
    if soundStage ~= 'death' then
        if not ZC.canPlayZombieSound(soundStage) then return end
        ZC.lastAliveSoundStartedAt = GetGameTimer()
    end

    local soundId = (zombieId and tostring(zombieId) or 'amb') .. '_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
    activeZombieSounds[soundId] = {
        zombieId = zombieId,
        netId = netId,
        ped = ped,
        lastPos = currentPos,
        maxRange = maxRange,
        stage = soundStage,
        expires = GetGameTimer() + 8000
    }

    SendNUIMessage({
        action = 'playZombieSound3D',
        soundId = soundId,
        zombieId = zombieId,
        file = file,
        x = relX,
        y = relY,
        z = relZ,
        dist = dist,
        maxRange = maxRange,
        stage = stage or 'idle'
    })
end)

RegisterNetEvent('thehunt_zombie:stopAmbient', function(zombieId)
    for sId, s in pairs(activeZombieSounds) do
        if (not zombieId or s.zombieId == zombieId) and s.stage ~= 'death' then
            activeZombieSounds[sId] = nil
        end
    end
    SendNUIMessage({
        action = 'stopZombieSound3D',
        zombieId = zombieId,
        preserveDeath = true
    })
end)

CreateThread(function()
    while true do
        if next(activeZombieSounds) then
            Wait(50)
            local now = GetGameTimer()
            local updates = {}
            local hasUpdates = false
            for sId, s in pairs(activeZombieSounds) do
                if now > s.expires then
                    activeZombieSounds[sId] = nil
                    updates[sId] = { remove = true }
                    hasUpdates = true
                else
                    local ped = s.ped
                    if not ped or not DoesEntityExist(ped) then
                        ped = resolveZombiePed(s.zombieId, s.netId)
                        s.ped = ped
                    end
                    if s.stage ~= 'death' and ped and DoesEntityExist(ped) and type(IsEntityDead) == 'function' and IsEntityDead(ped) then
                        activeZombieSounds[sId] = nil
                        updates[sId] = { remove = true }
                        hasUpdates = true
                    else
                        local currentPos = getPedSoundPosition(ped, s.lastPos)
                        s.lastPos = currentPos
                        local relX, relY, relZ, dist = getRelativeCamCoords(currentPos)
                        if dist > (s.maxRange * 1.15) then
                            activeZombieSounds[sId] = nil
                            updates[sId] = { remove = true }
                            hasUpdates = true
                        else
                            updates[sId] = { x = relX, y = relY, z = relZ, dist = dist }
                            hasUpdates = true
                        end
                    end
                end
            end
            if hasUpdates then
                SendNUIMessage({
                    action = 'updateZombieSounds3D',
                    updates = updates
                })
            end
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(ZombieConfig.PlayerCacheTick)
        local players = {}
        local myPed = PlayerPedId()
        local myId = GetPlayerServerId(PlayerId())
        if DoesEntityExist(myPed) then
            local state = LocalPlayer.state
            players[#players + 1] = {
                id = myId,
                ped = myPed,
                pos = Zombie.coords(GetEntityCoords(myPed)),
                speed = GetEntitySpeed(myPed),
                dead = IsEntityDead(myPed) or state.isSelectingChar or state.isCreatingChar,
                crouch = isStealthed(myPed)
            }
        end
        for _, index in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(index)
            local id = GetPlayerServerId(index)
            if id ~= myId and DoesEntityExist(ped) then
                local state = Player(id).state
                players[#players + 1] = {
                    id = id,
                    ped = ped,
                    pos = Zombie.coords(GetEntityCoords(ped)),
                    speed = GetEntitySpeed(ped),
                    dead = IsEntityDead(ped) or state.isSelectingChar or state.isCreatingChar,
                    crouch = isStealthed(ped)
                }
            end
        end
        ZC.players = players
    end
end)

CreateThread(function()
    local lastShot, lastMove, lastVoice = 0, 0, 0
    while true do
        Wait(next(ZC.peds) and 50 or 1000)
        local ped = PlayerPedId()
        local now = GetGameTimer()
        if next(ZC.peds) and not IsEntityDead(ped) and not LocalPlayer.state.isSelectingChar and not LocalPlayer.state.isCreatingChar then
            if IsPedShooting(ped) and now - lastShot > 250 then
                lastShot = now
                local _, weapon = GetCurrentPedWeapon(ped, true, 0, false)
                TriggerServerEvent('thehunt_zombie:noise', 'shot', weapon)
            end
            if now - lastMove > 1100 then
                lastMove = now
                local speed = GetEntitySpeed(ped)
                if not isStealthed(ped) then
                    if speed > 2.0 then TriggerServerEvent('thehunt_zombie:noise', 'run')
                    elseif speed > 0.8 then TriggerServerEvent('thehunt_zombie:noise', 'walk') end
                end
            end
            if now - lastVoice > 1000 and GetResourceState('pma-voice') == 'started' then
                local talking = MumbleIsPlayerTalking(PlayerId())
                if talking == true or talking == 1 then
                    lastVoice = now
                    TriggerServerEvent('thehunt_zombie:noise', 'voice')
                end
            end
        end
    end
end)
