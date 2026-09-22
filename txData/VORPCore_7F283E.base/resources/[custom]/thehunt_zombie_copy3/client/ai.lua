-- Native combat: TaskCombatPed drives pursuit + melee animations entirely.
-- The engine handles approach, attack animations and physical hit registration.
-- Damage authorization uses actual RDR3 contact events in contact.lua.

local function transition(r, state, now)
    if r.state == state then return end
    local oldState = r.state
    r.state = state
    r.since = now
    r.taskAt = 0
    r.roamGoal = nil
    r.moveGoal = nil
    r.chaseTaskAt = 0

    -- Reset pursuit tracking when leaving combat so TaskCombatPed is re-issued on next target
    if state ~= 'CHASE' and state ~= 'ATTACK' then
        r.pursuedPed = nil
        r.pursueAssignedAt = nil
    end

    local ped = r.ped or ZC.entity(r)
    if ped and DoesEntityExist(ped) then
        local wasCombat = (oldState == 'CHASE' or oldState == 'ATTACK')
        local isCombat = (state == 'CHASE' or state == 'ATTACK')
        if not (wasCombat and isCombat) then
            if state == 'IDLE' then
                ClearPedTasks(ped)
                TaskStandStill(ped, -1)
            else
                ClearPedTasks(ped)
            end
        end
    end
end

local function getGroundPoint(center, radius)
    local a = math.random() * math.pi * 2
    local dist = math.sqrt(math.random()) * radius * 0.85
    local x = center.x + math.cos(a) * dist
    local y = center.y + math.sin(a) * dist
    local z = center.z
    if type(GetGroundZFor_3dCoord) == 'function' then
        local found, gz = GetGroundZFor_3dCoord(x, y, center.z + 25.0, false)
        if not found then found, gz = GetGroundZFor_3dCoord(x, y, center.z + 5.0, false) end
        if not found then found, gz = GetGroundZFor_3dCoord(x, y, center.z + 50.0, false) end
        if found then z = gz + 0.1 end
    end
    return { x = x, y = y, z = z }
end

local function move(r, pos, speed, now)
    local current = GetEntityCoords(r.ped)
    if now >= (r.progressAt or 0) then
        if r.progressPos and Zombie.distance(current, r.progressPos) < 0.25 then r.taskAt = 0 end
        r.progressPos = Zombie.coords(current)
        r.progressAt = now + 7000
    end
    if r.moveGoal and Zombie.distance(r.moveGoal,pos)<1.0 and (r.taskAt or 0)>0 then return end
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end
    r.taskAt = now + 7000
    r.moveGoal = Zombie.coords(pos)
    local moveSpeed = speed or 0.8
    if type(SetPedMaxMoveBlendRatio) == 'function' then
        SetPedMaxMoveBlendRatio(ped, moveSpeed)
    end
    if type(SetPedDesiredMoveBlendRatio) == 'function' then
        SetPedDesiredMoveBlendRatio(ped, moveSpeed)
    end
    TaskFollowNavMeshToCoord(ped, pos.x, pos.y, pos.z, moveSpeed, -1, 1.0, 0, 0.0)
end

local function roaming(r, now, state)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end
    if r.goal then
        transition(r, 'MIGRATION', now)
    elseif Zombie.distance(GetEntityCoords(ped), r.home) > r.radius then
        transition(r, 'RETURN', now)
    else
        transition(r, state or 'IDLE', now)
    end
end

local states = {}

-- 1. IDLE: Stand still, look around, rest for idleTime
states.IDLE = function(r, now)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end

    if r.goal then transition(r,'MIGRATION',now); return end
    if now - r.since > (r.idleTime or 5000) then
        transition(r, 'WANDER', now)
        if r.temperament == 'stander' then
            -- Lurkers/Standers only move a few short steps nearby (2-4 meters)
            r.roamGoal = Zombie.point(GetEntityCoords(ped), math.random(2, 4))
        else
            r.roamGoal = getGroundPoint(r.home, r.radius)
        end
    end
end

-- 2. WANDER: Walk naturally to destination off-road or on paths at custom speed
states.WANDER = function(r, now)
    if r.goal then transition(r, 'MIGRATION', now); return end
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end

    local myPos = GetEntityCoords(ped)
    local distFromHome = Zombie.distance(myPos, r.home)

    -- Strict zone leash: if outside zone radius, immediately return
    if distFromHome > r.radius then
        transition(r, 'RETURN', now)
        return
    end

    r.roamGoal = r.roamGoal or getGroundPoint(r.home, r.radius)

    -- Walking speed based on zone setting and temperament
    local configuredSpeed = r.settings.speed or 1.0
    local walkSpeed = 0.75
    if r.temperament == 'stander' then
        walkSpeed = math.min(0.65, configuredSpeed * 0.45)
    elseif r.temperament == 'roamer' then
        walkSpeed = math.min(0.9, configuredSpeed * 0.7)
    else
        walkSpeed = math.min(1.2, configuredSpeed * 0.9)
    end

    move(r, r.roamGoal, walkSpeed, now)

    local maxWanderTime = 45000
    if now - r.since > maxWanderTime or Zombie.distance(myPos, r.roamGoal) < 1.8 then
        -- Pick new idle duration according to personality
        if r.temperament == 'stander' then
            r.idleTime = math.random(30000, 75000) -- Stands 30-75 sec
        elseif r.temperament == 'roamer' then
            r.idleTime = math.random(10000, 25000) -- Stands 10-25 sec
        else
            r.idleTime = math.random(2000, 5000)   -- Stands 2-5 sec
        end
        roaming(r, now, 'IDLE')
    end
end

-- 3. INVESTIGATE_SOUND: Heard footsteps, gunshots, or voice
states.INVESTIGATE_SOUND = function(r, now)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end
    if not r.last then roaming(r, now, 'IDLE'); return end

    local runSpeed = r.settings.speed
    move(r, r.last, runSpeed, now)

    if now - r.since > 14000 or Zombie.distance(GetEntityCoords(ped), r.last) < 2.5 then
        transition(r, 'SEARCH', now)
    end
end

-- 4. ALERT: Noticed player, approaches menacingly on foot during reaction time before sprinting
states.ALERT = function(r, now)
    if not r.seen then
        r.target = nil
        transition(r, 'SEARCH', now)
        return
    end

    local ped = r.ped or ZC.entity(r)
    if ped and DoesEntityExist(ped) and r.seen.pos then
        local myPos = GetEntityCoords(ped)
        if type(GetHeadingFromVector_2d) == 'function' and type(SetEntityHeading) == 'function' then
            SetEntityHeading(ped, GetHeadingFromVector_2d(r.seen.pos.x - myPos.x, r.seen.pos.y - myPos.y))
        end
        -- Menacing walking approach towards detected player before breaking into a sprint
        move(r, r.seen.pos, 0.95, now)
    end

    local reactionTime = (r.settings.reaction or 800) / math.max(0.1, r.settings.aggression or 1.0)
    if now - r.since >= reactionTime then
        transition(r, 'CHASE', now)
    end
end

-- 5. CHASE/COMBAT: Native engine combat — TaskCombatPed handles pursuit and melee animations.
-- Combat remains assigned until target/state changes or the native task finishes.
states.CHASE = function(r, now)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end

    local targetPed = r.targetPed
    if not targetPed or not DoesEntityExist(targetPed) then
        local idx = (type(GetPlayerFromServerId) == 'function') and GetPlayerFromServerId(r.target or 0) or -1
        if idx ~= -1 and type(GetPlayerPed) == 'function' then targetPed = GetPlayerPed(idx) end
        r.targetPed = targetPed
    end

    if not targetPed or not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then
        r.target = nil
        r.targetPed = nil
        transition(r, 'SEARCH', now)
        return
    end

    local myPos = GetEntityCoords(ped)
    local targetPos = GetEntityCoords(targetPed)
    local dist = Zombie.distance(myPos, targetPos)
    r.distance = dist

    -- Leash check: allow chasing up to 120m beyond zone boundary
    if not r.goal and r.home and r.radius and Zombie.distance(myPos, r.home) > (r.radius + 120.0) then
        r.target = nil
        r.targetPed = nil
        r.last = nil
        transition(r, 'RETURN', now)
        return
    end

    local speed = r.settings.speed
    if type(SetPedMaxMoveBlendRatio) == 'function' then SetPedMaxMoveBlendRatio(ped, speed) end

    -- Sprint when closing distance (> 2.5m).
    -- When within striking range (<= 2.5m), step down blend ratio to 1.0 (combat footwork)
    -- so momentum dissipates cleanly without running into the player's model.
    if type(SetPedDesiredMoveBlendRatio) == 'function' then
        if dist > 2.5 then
            SetPedDesiredMoveBlendRatio(ped, math.max(1.8, speed or 2.2))
        else
            SetPedDesiredMoveBlendRatio(ped, 1.0)
        end
    end

    -- Assign TaskCombatPed when target changes or if the ped is not currently in combat.
    -- TaskCombatPed natively manages melee approach, strikes, and combos smoothly without jitter.
    local inCombat = true
    if type(IsPedInCombat) == 'function' then
        inCombat = IsPedInCombat(ped, targetPed)
    end
    if r.pursuedPed ~= targetPed or not inCombat then
        r.pursuedPed = targetPed
        TaskCombatPed(ped, targetPed, 0, 16)
    end

    -- Close striking range (<= 2.2m): actively coordinate strikes from ~2 peds.
    -- Cooldown of 800-1100ms matches full punch animation length to completely eliminate twitching/jitter.
    -- Offset (0.0, 0.0, 0.0, 0) strikes naturally from current position without warping to -1.0.
    if dist <= 2.2 and now >= (r.meleeTaskAt or 0) then
        r.meleeTaskAt = now + math.random(800, 1100)

        ZC.meleeAttackers = ZC.meleeAttackers or {}
        local activeCount = 0
        for id, untilTime in pairs(ZC.meleeAttackers) do
            if untilTime > now then
                activeCount = activeCount + 1
            else
                ZC.meleeAttackers[id] = nil
            end
        end

        local isMySlot = (ZC.meleeAttackers[r.id] and ZC.meleeAttackers[r.id] > now)
        if activeCount < 2 or isMySlot then
            ZC.meleeAttackers[r.id] = now + 950

            local isPerformingMelee = false
            if type(IsPedPerformingMeleeAction) == 'function' then
                isPerformingMelee = IsPedPerformingMeleeAction(ped)
            elseif type(Citizen) == 'table' and type(Citizen.InvokeNative) == 'function' then
                local ok, res = pcall(Citizen.InvokeNative, 0xDCCA191DF9980FD7, ped)
                if ok then isPerformingMelee = res end
            end

            if not isPerformingMelee then
                if type(TaskPutPedDirectlyIntoMelee) == 'function' then
                    pcall(TaskPutPedDirectlyIntoMelee, ped, targetPed, 0.0, 0.0, 0.0, 0)
                end
                if not inCombat then
                    TaskCombatPed(ped, targetPed, 0, 16)
                end
            end

            if type(PlayerPedId) == 'function' and targetPed == PlayerPedId() and type(ZC.contact) == 'function' then
                ZC.contact(targetPed, ped, now)
            end
        end
    end

    -- Mounted player dismount: if target is riding a horse and within reach (<= 1.8m), trigger native unseat
    if targetPed and DoesEntityExist(targetPed) and type(IsPedOnMount) == 'function' and IsPedOnMount(targetPed) and dist <= 1.8 then
        if now >= (r.dismountReportAt or 0) then
            r.dismountReportAt = now + 4000
            if targetPed == PlayerPedId() then
                ZC.dismountLocalPlayer(ped, r.id)
            else
                TriggerServerEvent('thehunt_zombie:dismountRider', r.target, r.id)
            end
        end
    end
end

-- 5b. ATTACK is no longer a separate state — TaskCombatPed handles melee cycle natively.
-- Stub redirects any lingering FSM references back to CHASE.
states.ATTACK = function(r, now)
    r.state = 'CHASE'
    states.CHASE(r, now)
end

-- 6. SEARCH: Lost player, rushes to the last known position at full speed, then searches the area
states.SEARCH = function(r, now)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end

    if not r.last or now - r.since > (r.settings.searchTime or 12) * 1000 then
        r.last = nil
        r.reason = nil
        r.target = nil
        r.targetPed = nil
        roaming(r, now, 'IDLE')
        return
    end

    local myPos = GetEntityCoords(ped)
    if not r.roamGoal then r.roamGoal = Zombie.coords(r.last) end
    local distToLast = Zombie.distance(myPos, r.roamGoal)
    if distToLast < 2.0 then
        r.roamGoal = Zombie.point(r.last, 7)
    end
    -- Rush to the player's last known position at full speed first!
    -- Only slow down to search (0.85) once the zombie has actually reached the spot.
    local searchSpeed = (distToLast > 2.5) and (r.settings.speed or 2.0) or math.min(r.settings.speed or 1.0, 0.85)
    move(r, r.roamGoal, searchSpeed, now)
end

-- 8. MIGRATION & RETURN
states.MIGRATION = function(r, now)
    if not r.goal then roaming(r, now, 'IDLE'); return end
    move(r, r.goal, math.min(r.settings.speed or 1.0, 1.1), now)
end

states.RETURN = function(r, now)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end
    local myPos = GetEntityCoords(ped)
    local retSpeed = math.max(2.0, r.settings.speed or 2.2)
    move(r, r.home, retSpeed, now)
    if Zombie.distance(myPos, r.home) < r.radius * 0.5 then
        transition(r, 'IDLE', now)
    end
end

function ZC.think(r, now)
    local ped = ZC.entity(r)
    if not ped or not DoesEntityExist(ped) or r.dead or IsEntityDead(ped) then return end

    -- Multiple clients must not replace each other's tasks. The earlier freeze
    -- was server-side false death, not this ownership check.
    if not NetworkHasControlOfEntity(ped) then r.owned=false; return end

    if not r.owned then
        -- A tuning native must never leave a spawned ped in TaskStandStill.
        r.owned = true
        local configured, err = pcall(ZC.configure, ped, r.settings, false, r.weapon or (r.settings and r.settings.chosenWeapon))
        if not configured then
            print(('[thehunt_zombie] configure failed for %s: %s'):format(r.id, tostring(err)))
        end
        if ZC.applyWalkStyle then
            ZC.applyWalkStyle(ped, (r.settings and (r.settings.chosenWalkStyle or r.settings.walkStyle)) or 'MP_Style_drunk')
        end
        FreezeEntityPosition(ped, false)
        r.taskAt = 0
        r.lostTargetAt = 0

        local previous = Entity(ped).state.huntZombieAI
        r.last = previous and previous.last or nil
        r.target = nil
        r.targetPed = nil

        r.temperament = r.temperament or 'roamer'
        r.idleTime = r.idleTime or math.random(3000, 10000)
        r.state = r.last and 'SEARCH' or (r.goal and 'MIGRATION' or 'IDLE')
        r.pursuedPed = nil
        r.moveGoal = nil
        r.since = now

        -- Initial detection check
        local initSeen, initDist = ZC.detect(r)
        if initSeen then
            r.seen = initSeen
            r.target = initSeen.id
            r.targetPed = initSeen.ped
            r.last = Zombie.coords(initSeen.pos)
            r.distance = initDist
            r.lostTargetAt = now + 10000
            r.state = 'ALERT'
            r.chaseTaskAt = now + 1200
        else
            if r.state == 'IDLE' then
                ClearPedTasks(ped)
                TaskStandStill(ped, -1)
            end
        end
    end

    -- Zone leash check: while aggroed on player (CHASE/ALERT/RETURN), allow chasing up to 120m outside the zone
    local myPos = GetEntityCoords(ped)
    local maxLeash = (r.state == 'CHASE' or r.state == 'ALERT' or r.state == 'RETURN') and (r.radius + 120.0) or r.radius
    if not r.goal and r.home and r.radius and Zombie.distance(myPos, r.home) > maxLeash then
        if r.state ~= 'RETURN' and (r.state == 'CHASE' or r.state == 'WANDER' or r.state == 'IDLE' or r.state == 'SEARCH' or r.state == 'INVESTIGATE_SOUND' or r.state == 'ALERT') then
            r.target = nil
            r.targetPed = nil
            r.last = nil
            transition(r, 'RETURN', now)
        end
    end

    -- Perception scan: runs for ALL states (including RETURN) so returning zombies can re-aggro on sight, sound or damage
    if r.settings.aggression <= 0 or (r.target and ZC.immune[r.target]) then
        r.target=nil; r.targetPed=nil; r.last=nil; r.sound=nil
        if r.state=='CHASE' or r.state=='ALERT' or r.state=='SEARCH' then roaming(r,now,'IDLE') end
    end
    local seen, distance = ZC.detect(r)
    if r.attacker then
        for _,p in ipairs(ZC.players) do
            if p.ped==r.attacker and not p.dead and not ZC.immune[p.id] and r.settings.aggression>0 then
                seen=p; distance=Zombie.distance(GetEntityCoords(ped),p.pos); break
            end
        end
        r.attacker=nil
    end
    r.seen = seen
    if distance then r.distance = distance end

    if seen then
        r.last = Zombie.coords(seen.pos)
        r.target = seen.id
        r.targetPed = seen.ped
        r.lostTargetAt = now + 6500
        r.reason = 'vision'
        if r.state ~= 'CHASE' then
            if r.state == 'SEARCH' or r.state == 'INVESTIGATE_SOUND' or r.state == 'RETURN' then
                transition(r, 'CHASE', now)
            elseif r.state ~= 'ALERT' then
                transition(r, 'ALERT', now)
            end
        end
    elseif r.target then
        r.target = nil
        r.targetPed = nil
        transition(r, 'SEARCH', now)
    elseif r.sound and r.sound.untilTime > now and r.settings.aggression > 0 then
        if not r.sound.player or not ZC.immune[r.sound.player] then
            r.last = r.sound.pos
            r.reason = 'sound:' .. r.sound.reason
            transition(r, 'INVESTIGATE_SOUND', now)
        end
        r.sound = nil
    end

    (states[r.state] or states.IDLE)(r, now)

    -- Stuck check: if stationary while trying to wander or return, pick new goal
    if now > (r.checkMoveAt or 0) then
        local pos = Zombie.coords(GetEntityCoords(ped))
        if r.movePos and Zombie.distance(pos, r.movePos) < 0.3 and r.state ~= 'IDLE' and r.state ~= 'ALERT' and r.state ~= 'CHASE' then
            r.taskAt = 0
            r.roamGoal = Zombie.point(pos, 5)
            if r.state == 'RETURN' then
                move(r, r.roamGoal, math.max(2.0, r.settings.speed or 2.2), now)
            elseif r.state == 'MIGRATION' then
                move(r, r.roamGoal, 0.85, now)
            elseif r.state == 'WANDER' then
                move(r, r.roamGoal, 0.75, now)
            end
        end
        r.movePos = pos
        r.checkMoveAt = now + 7000
    end
end

-- Main AI batch processor
CreateThread(function()
    local order,cursor={},1; local refresh=0
    while true do
        Wait(next(ZC.peds) and 50 or 800)
        local now=GetGameTimer()
        if now>refresh then
            order={}; for id in pairs(ZC.peds) do order[#order+1]=id end
            refresh=now+1000; cursor=math.min(cursor,math.max(1,#order))
        end
        local processed,scanned=0,0
        while scanned<#order and processed<ZombieConfig.AIBatch do
            local r=ZC.peds[order[cursor]]; cursor=cursor%#order+1; scanned=scanned+1
            if r and now>=(r.nextTick or 0) then
                local ped=ZC.entity(r); local near=ped and Zombie.distance(GetEntityCoords(ped),GetEntityCoords(PlayerPedId()))<65
                r.nextTick=now+(near and ZombieConfig.NearTick or ZombieConfig.FarTick)
                ZC.think(r,now); processed=processed+1
            end
        end
    end
end)

-- All profiles report real death from the client that simulates this ped.
-- Retry until the server publishes dead=true (ownership may migrate mid-report).
CreateThread(function()
    while true do
        Wait(500)
        local now=GetGameTimer()
        for id,r in pairs(ZC.peds) do
            local ped=not r.dead and ZC.entity(r)
            if ped and NetworkHasControlOfEntity(ped) and IsEntityDead(ped)
                and now>=(r.deathReportAt or 0) then
                r.deathReportAt=now+1000
                TriggerServerEvent('thehunt_zombie:pedDied',id)
            end
        end
    end
end)

-- Headshot handler for headshotOnly profiles
CreateThread(function()
    while true do
        local active=false
        for _,r in pairs(ZC.peds) do
            if r.settings.headshotOnly and not r.dead then
                local ped=ZC.entity(r)
                if ped and DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) then
                    active=true
                    local hit,bone=GetPedLastDamageBone(ped)
                    if hit then
                        ClearPedLastDamageBone(ped)
                        if ZombieConfig.HeadBones[bone] then SetEntityHealth(ped,0,0)
                        else SetEntityHealth(ped,ZombieConfig.HeadshotReserve,0) end
                    elseif GetEntityHealth(ped)<ZombieConfig.HeadshotReserve then
                        SetEntityHealth(ped,ZombieConfig.HeadshotReserve,0)
                    end
                end
            end
        end
        Wait(active and 0 or 500)
    end
end)

-- State reporting to server
CreateThread(function()
    while true do
        Wait(2000)
        local batch={}
        for id,r in pairs(ZC.peds) do
            local ped=ZC.entity(r)
            if ped and DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) and not r.dead then
                batch[#batch+1]={id=id,state=r.state,target=r.target,last=r.last,reason=r.reason}
                Entity(ped).state:set('huntZombieAI',{last=r.last},true)
            end
        end
        if #batch>0 then TriggerServerEvent('thehunt_zombie:report',batch) end
    end
end)
