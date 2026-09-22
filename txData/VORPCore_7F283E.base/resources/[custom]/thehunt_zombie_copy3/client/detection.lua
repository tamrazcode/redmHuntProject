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

function ZC.visible(r, p)
    if ZC.immune[p.id] or p.dead or r.settings.aggression <= 0 then return false end
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return false end

    -- Zone boundary check: allows aggroed or returning zombies to detect and chase up to 120m beyond zone boundary
    local maxBoundary = (r.state == 'CHASE' or r.state == 'ALERT' or r.state == 'RETURN') and (r.radius + 120.0) or (r.radius + 15.0)
    if not r.goal and r.home and r.radius and Zombie.distance(p.pos, r.home) > maxBoundary then
        return false
    end

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

    if distance > (r.settings.sight or 38.0) or (type(HasEntityClearLosToEntity) == 'function' and not HasEntityClearLosToEntity(ped, p.ped, 17)) then
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
        local maxStealthDist = math.min(r.settings.sight, (p.speed < 0.5) and 7.0 or 12.0)
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
        local maxSight = (r.settings.sight or 38.0)
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
    if player and ZC.immune[player] then return end
    local now = GetGameTimer()
    for _, r in pairs(ZC.peds) do
        local ped = ZC.entity(r)
        if not r.dead and ped and DoesEntityExist(ped) and r.settings.aggression > 0 then
            if r.goal or not r.home or not r.radius or Zombie.distance(pos, r.home) <= (r.radius + 120.0) then
                local distance = Zombie.distance(GetEntityCoords(ped), pos)
                if distance <= math.min(radius * r.settings.hearing, r.settings.hearingDistance) then
                    r.sound = {pos = Zombie.point(pos, ZombieConfig.SoundUncertainty), untilTime = now + ZombieConfig.SoundLifetime, reason = kind, player = player}
                end
            end
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
