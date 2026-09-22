-- Native combat: TaskCombatPed drives pursuit + melee animations entirely.
-- The engine handles approach, attack animations and physical hit registration.
-- Damage is applied solely by RDR3 when its native melee strike connects.

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
        if r.attackModeActive then
            r.attackModeActive = false
            local p = r.ped or ZC.entity(r)
            if p and DoesEntityExist(p) then
                SetBlockingOfNonTemporaryEvents(p, true)
                SetPedKeepTask(p, true)
                if ZC.applyWalkStyle then
                    ZC.applyWalkStyle(p, (r.settings and (r.settings.chosenWalkStyle or r.settings.walkStyle)) or 'MP_Style_drunk')
                end
            end
        end
    end

    local ped = r.ped or ZC.entity(r)
    if ped and DoesEntityExist(ped) then
        local wasCombat = (oldState == 'CHASE' or oldState == 'ATTACK')
        local isCombat = (state == 'CHASE' or state == 'ATTACK')
        if not (wasCombat and isCombat) then
            -- Clearing a completed route is enough. An infinite stand task prevents
            ClearPedTasks(ped)
        end
    end
end

local MeleeWeapons = {
    [GetHashKey('WEAPON_UNARMED')] = true,
    [GetHashKey('weapon_unarmed')] = true,
    [0] = true,
    [GetHashKey('WEAPON_MELEE_KNIFE')] = true,
    [GetHashKey('WEAPON_MELEE_KNIFE_MINER')] = true,
    [GetHashKey('WEAPON_MELEE_KNIFE_CIVIL_WAR')] = true,
    [GetHashKey('WEAPON_MELEE_KNIFE_JAWBONE')] = true,
    [GetHashKey('WEAPON_MELEE_KNIFE_RUSTIC')] = true,
    [GetHashKey('WEAPON_MELEE_KNIFE_JOHN')] = true,
    [GetHashKey('WEAPON_MELEE_MACHETE')] = true,
    [GetHashKey('WEAPON_MELEE_HATCHET')] = true,
    [GetHashKey('WEAPON_MELEE_HATCHET_MELEEONLY')] = true,
    [GetHashKey('WEAPON_MELEE_CLEAVER')] = true,
    [GetHashKey('WEAPON_MELEE_TORCH')] = true,
    [GetHashKey('WEAPON_FISHINGROD')] = true,
    [GetHashKey('WEAPON_LASSO')] = true,
}

local function isRangedWeapon(weaponHash)
    if not weaponHash or weaponHash == 0 then return false end
    if MeleeWeapons[weaponHash] then return false end
    return true
end

local function isCloseCombat(ped, attackerPed)
    local att = (attackerPed and DoesEntityExist(attackerPed)) and attackerPed or PlayerPedId()
    if not att or not DoesEntityExist(att) or not ped or not DoesEntityExist(ped) then return false end
    local pPos = GetEntityCoords(ped)
    local aPos = GetEntityCoords(att)
    local maxDist = ZombieConfig.HeadshotCloseDistance or 3.5
    return Zombie.distance(pPos, aPos) <= maxDist
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
    r.aggroSoundPlayed = false
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

local function idleMotion(r, ped, now)
    -- Keep the zombie in the engine's idle graph: no civilian scenarios or
    -- authored human gestures are used here.
    if type(SetPedCanPlayAmbientAnims) == 'function' then SetPedCanPlayAmbientAnims(ped, true) end
    if type(SetPedCanPlayAmbientBaseAnims) == 'function' then SetPedCanPlayAmbientBaseAnims(ped, true) end
    if now < (r.idleLookAt or 0) then return end
    r.idleLookAt = now + math.random(7000, 16000)
    local pos = GetEntityCoords(ped)
    local angle = math.random() * math.pi * 2
    TaskLookAtCoord(ped, pos.x + math.cos(angle) * 3.0, pos.y + math.sin(angle) * 3.0,
        pos.z + math.random(0, 2) * 0.25, math.random(900, 1800), 0, 3)
end

local function zombieGender(r)
    if r.cachedGender then return r.cachedGender end
    local model = string.lower(tostring(r.model or ''))
    if model:find('_f_') or model:find('female') or model:find('prostitute') then
        r.cachedGender = 'female'
        return 'female'
    elseif model:find('_m_') or model:find('male') or model:find('mradler') or model:find('vampire') or model:find('swampfreak') or model:find('master') then
        r.cachedGender = 'male'
        return 'male'
    end

    local ped = r.ped or ZC.entity(r)
    if ped and DoesEntityExist(ped) and type(IsPedMale) == 'function' then
        local m = IsPedMale(ped)
        if m == 1 or m == true then
            r.cachedGender = 'male'
            return 'male'
        elseif m == 0 or m == false then
            r.cachedGender = 'female'
            return 'female'
        end
    end
    r.cachedGender = 'male'
    return 'male'
end

local function pickDifferentSound(sounds, lastSound)
    if not sounds or #sounds == 0 then return nil end
    if #sounds == 1 then return sounds[1] end
    local pool = {}
    for _, s in ipairs(sounds) do
        if s ~= lastSound then
            pool[#pool + 1] = s
        end
    end
    if #pool > 0 then
        return pool[math.random(1, #pool)]
    end
    return sounds[math.random(1, #sounds)]
end

local function ambientSound(r, ped, now, forcedStage)
    local stage = forcedStage
    if not stage then
        if r.state == 'IDLE' or r.state == 'WANDER' or r.state == 'RETURN' or r.state == 'MIGRATION' then stage = 'idle'
        elseif r.state == 'ALERT' or r.state == 'INVESTIGATE_SOUND' or r.state == 'SEARCH' then stage = 'alert'
        else stage = 'chase' end
    end
    local timerKey = forcedStage and ('combatAmbientAt_' .. forcedStage) or 'ambientAt'
    if now < (r[timerKey] or 0) then return end

    -- Не спамить звуками, если вокруг уже рычат 2-3 зомби: отложить звук
    if stage ~= 'death' and ZC.canPlayZombieSound and not ZC.canPlayZombieSound(stage, now) then
        r[timerKey] = now + math.random(1400, 2800)
        return
    end

    local gender = zombieGender(r)
    local soundList = ZombieConfig.AmbientSounds and ZombieConfig.AmbientSounds[gender]
    local sounds = soundList and soundList[stage]
    if not sounds or #sounds == 0 then return end
    local intervals = ZombieConfig.SoundIntervals and ZombieConfig.SoundIntervals[stage]
    local minDelay = intervals and intervals.min or 7000
    local maxDelay = intervals and intervals.max or 18000
    if not intervals then
        if stage == 'alert' then minDelay, maxDelay = 7000, 15000
        elseif stage == 'chase' then minDelay, maxDelay = 5000, 11000
        elseif stage == 'attack' then minDelay, maxDelay = 3000, 6000 end
    end
    r[timerKey] = now + math.random(minDelay, maxDelay)
    local chosenSound = pickDifferentSound(sounds, r.lastSound)
    r.lastSound = chosenSound
    TriggerServerEvent('thehunt_zombie:ambient', r.id, chosenSound, stage)
    if type(TriggerEvent) == 'function' and type(GetEntityCoords) == 'function' then
        local pos = Zombie.coords(GetEntityCoords(ped))
        TriggerEvent('thehunt_zombie:ambient', r.id, r.net or 0, chosenSound, pos, ZombieConfig.AmbientSoundRange, stage)
    end
end

-- 100% guaranteed aggro sound played once when engaging the player
local function playAggroSound(r, ped, now)
    if r.aggroSoundPlayed then return end
    r.aggroSoundPlayed = true

    local gender = zombieGender(r)
    local soundList = ZombieConfig.AmbientSounds and ZombieConfig.AmbientSounds[gender]
    local sounds = soundList and (soundList['alert'] or soundList['chase'])
    if not sounds or #sounds == 0 then return end

    local chosenSound = pickDifferentSound(sounds, r.lastSound)
    r.lastSound = chosenSound

    -- Offset ambient intervals so other vocalizations don't clash immediately
    r.ambientAt = now + math.random(6000, 10000)
    r.combatAmbientAt_alert = now + math.random(7000, 12000)
    r.combatAmbientAt_chase = now + math.random(6000, 10000)

    TriggerServerEvent('thehunt_zombie:ambient', r.id, chosenSound, 'alert')
    if type(TriggerEvent) == 'function' and type(GetEntityCoords) == 'function' then
        local pos = Zombie.coords(GetEntityCoords(ped))
        TriggerEvent('thehunt_zombie:ambient', r.id, r.net or 0, chosenSound, pos, ZombieConfig.AmbientSoundRange, 'alert')
    end
end

local function noticeZombieCorpse(r, ped, now)
    -- Only inspect the resource registry, never the full world-ped pool. A dead
    -- zombie is a clue, not an automatic target: it creates a short, quicker
    -- search around the body for whoever killed it.
    if r.state == 'CHASE' or r.state == 'ALERT' or now < (r.corpseCheckAt or 0) then return false end
    r.corpseCheckAt = now + 900
    local myPos = GetEntityCoords(ped)
    for id, other in pairs(ZC.peds) do
        if id ~= r.id and (other.dead or other.state == 'DEAD') then
            local corpse = ZC.entity(other)
            if corpse and DoesEntityExist(corpse) and Zombie.distance(myPos, GetEntityCoords(corpse)) <= 20.0
                and (type(HasEntityClearLosToEntity) ~= 'function' or HasEntityClearLosToEntity(ped, corpse, 17)) then
                if r.lastCorpse ~= id or now >= (r.corpseMemoryUntil or 0) then
                    r.lastCorpse = id
                    r.corpseMemoryUntil = now + 18000
                    r.last = Zombie.coords(GetEntityCoords(corpse))
                    r.reason = 'corpse'
                    transition(r, 'SEARCH', now)
                    return true
                end
            end
        end
    end
    return false
end

local states = {}

-- 1. IDLE: Stand still, look around, rest for idleTime
states.IDLE = function(r, now)
    local ped = r.ped or ZC.entity(r)
    if not ped or not DoesEntityExist(ped) then return end

    idleMotion(r, ped, now)
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
    local targetPos = (r.seen and r.seen.ped == targetPed and r.seen.pos) or GetEntityCoords(targetPed)
    local dist = (r.seen and r.seen.pos and Zombie.distance(myPos, r.seen.pos)) or (r.last and Zombie.distance(myPos, r.last)) or Zombie.distance(myPos, targetPos)
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

    -- Hysteresis: enter attack mode at <= 3.6m, leave at > 5.2m (from hh_zombies)
    local inAttackRange = false
    if r.attackModeActive then
        inAttackRange = (dist <= 5.2)
    else
        inAttackRange = (dist <= 3.6)
    end

    if inAttackRange then
        -- ENTER / MAINTAIN ATTACK MODE
        if not r.attackModeActive then
            r.attackModeActive = true
            -- Для удара и захвата с лошади блок событий надо снять, иначе TaskCombatPed не атакует нативно
            SetBlockingOfNonTemporaryEvents(ped, false)
            SetPedKeepTask(ped, false)
            SetPedFleeAttributes(ped, 0, false)
            if ClearEntityLastDamageEntity then
                ClearEntityLastDamageEntity(ped)
            end
            if ZC.applyWalkStyle then
                ZC.applyWalkStyle(ped, 'default')
            end
            if type(SetPedSeeingRange) == 'function' then SetPedSeeingRange(ped, 80.0) end
            if type(SetPedHearingRange) == 'function' then SetPedHearingRange(ped, 80.0) end
            SetPedCombatMovement(ped, 2)
            if type(ClearPedTasks) == 'function' then ClearPedTasks(ped, true, true) end
            TaskCombatPed(ped, targetPed, 0, 16)
            r.pursuedPed = targetPed
            r.lastCombatReengage = now
        else
            -- Anti-flee failsafe: если движок попытался перевести зомби в бегство (IsPedFleeing), мгновенно сбиваем панику
            if type(IsPedFleeing) == 'function' and IsPedFleeing(ped) then
                if type(ClearPedTasksImmediately) == 'function' then
                    ClearPedTasksImmediately(ped, true, true)
                else
                    ClearPedTasks(ped, true, true)
                end
                SetBlockingOfNonTemporaryEvents(ped, false)
                SetPedKeepTask(ped, false)
                SetPedFleeAttributes(ped, 0, false)
                TaskCombatPed(ped, targetPed, 0, 16)
            end

            local inCombat = true
            if type(IsPedInCombat) == 'function' then
                inCombat = IsPedInCombat(ped, targetPed)
            end
            if not inCombat and (now - (r.lastCombatReengage or 0) > 1200) then
                r.lastCombatReengage = now
                TaskCombatPed(ped, targetPed, 0, 16)
            end
        end

        -- Attack sounds during melee proximity
        if dist <= 2.8 and now >= (r.attackSoundAt or 0) then
            r.attackSoundAt = now + math.random(1600, 3000)
            ambientSound(r, ped, now, 'attack')
        end

        -- Direct combat handling for mounted vs on-foot targets
        local isTargetMounted = (type(IsPedOnMount) == 'function' and IsPedOnMount(targetPed))
        if isTargetMounted then
            -- Allow native horse unseat / drag-down by hostile combat AI (like in story mode)
            if type(SetPedCanBeDraggedOut) == 'function' then
                SetPedCanBeDraggedOut(targetPed, true)
            end
            if type(SetPedCanBeKnockedOffVehicle) == 'function' then
                SetPedCanBeKnockedOffVehicle(targetPed, 0)
            end
            -- Re-engage native TaskCombatPed directly against mounted target, never interrupt with TaskPutPedDirectlyIntoMelee
            local inCombat = (type(IsPedInCombat) == 'function') and IsPedInCombat(ped, targetPed) or true
            if not inCombat or (now - (r.lastCombatReengage or 0) > 1200) then
                r.lastCombatReengage = now
                TaskCombatPed(ped, targetPed, 0, 16)
            end
        else
            -- Direct melee strike enforcement for on-foot targets: if close and not already throwing a strike
            if dist <= 2.6 and now >= (r.meleeTaskAt or 0) then
                r.meleeTaskAt = now + 2000
                local agg = tonumber(r.settings and r.settings.aggression) or 1.0
                local cd = 2000
                if agg >= 5 then
                    cd = 800
                elseif agg >= 4 then
                    cd = 1200
                elseif r.settings and r.settings.attackCooldown then
                    cd = math.max(600, tonumber(r.settings.attackCooldown) or 2000)
                end
                r.meleeTaskAt = now + cd

                local isPerformingMelee = false
                if type(IsPedPerformingMeleeAction) == 'function' then
                    isPerformingMelee = IsPedPerformingMeleeAction(ped)
                end
                if not isPerformingMelee then
                    if type(TaskPutPedDirectlyIntoMelee) == 'function' then
                        pcall(TaskPutPedDirectlyIntoMelee, ped, targetPed, 0.0, -1.0, 0.0, false)
                    end
                end
            end
        end
    else
        -- CHASE MODE (dist > 3.6m / 5.2m)
        if r.attackModeActive then
            r.attackModeActive = false
            -- При выходе из ближнего боя снова блокируем события для устойчивой погони
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedKeepTask(ped, true)
            if ZC.applyWalkStyle then
                ZC.applyWalkStyle(ped, (r.settings and (r.settings.chosenWalkStyle or r.settings.walkStyle)) or 'MP_Style_drunk')
            end
        end

        -- Sprint when closing distance (> 3.6m)
        if type(SetPedDesiredMoveBlendRatio) == 'function' then
            SetPedDesiredMoveBlendRatio(ped, math.max(1.8, speed or 2.2))
        end

        local inCombat = true
        if type(IsPedInCombat) == 'function' then
            inCombat = IsPedInCombat(ped, targetPed)
        end
        if r.pursuedPed ~= targetPed or not inCombat then
            r.pursuedPed = targetPed
            TaskCombatPed(ped, targetPed, 0, 16)
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
    -- Losing sight never switches the zombie to a walk. It reaches the last
    -- known point at full speed, then searches around it at a light run.
    local lightRun = math.max(1.35, math.min(1.75, (r.settings.speed or 2.2) * 0.78))
    local searchSpeed = (distToLast > 2.5) and (r.settings.speed or 2.0) or lightRun
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
    local isDead = (not ped or not DoesEntityExist(ped) or r.dead or (type(GetEntityHealth) == 'function' and GetEntityHealth(ped) <= 0) or IsEntityDead(ped))
    if isDead then
        if ped and DoesEntityExist(ped) and not r.dead and ((type(GetEntityHealth) == 'function' and GetEntityHealth(ped) <= 0) or IsEntityDead(ped)) and now >= (r.deathReportAt or 0) then
            r.dead = true
            r.state = 'DEAD'
            r.deathReportAt = now + 1000
            SetEntityAsMissionEntity(ped, true, true)
            SetPedKeepTask(ped, true)
            local deathSounds = ZombieConfig.DeathSounds
            local chosenSound = deathSounds and #deathSounds > 0 and deathSounds[math.random(1, #deathSounds)]
            if chosenSound and not r.deathSoundPlayed then
                r.deathSoundPlayed = true
                if type(TriggerEvent) == 'function' and type(GetEntityCoords) == 'function' then
                    local pos = Zombie.coords(GetEntityCoords(ped))
                    TriggerEvent('thehunt_zombie:ambient', r.id, r.net or 0, chosenSound, pos, ZombieConfig.AmbientSoundRange, 'death')
                end
            end
            TriggerServerEvent('thehunt_zombie:pedDied', r.id, chosenSound)
        end
        return
    end

    -- Multiple clients must not replace each other's tasks. The earlier freeze
    -- was server-side false death, not this ownership check.
    if not NetworkHasControlOfEntity(ped) then r.owned=false; return end

    if not r.owned then
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
        -- Let a new zombie demonstrate its individual ambience with a natural random pause
        r.ambientAt = r.ambientAt or (now + math.random(3000, 10000))
        if not r.headshotsNeeded then
            local oneShotRoll = math.random()
            if oneShotRoll <= (ZombieConfig.HeadshotOneShotChance or 0.40) then
                r.headshotsNeeded = 1
            else
                local minHits = math.max(2, ZombieConfig.HeadshotsToKillMin or 2)
                local maxHits = math.max(minHits, ZombieConfig.HeadshotsToKillMax or 3)
                r.headshotsNeeded = math.random(minHits, maxHits)
            end
            r.headHits = 0
        end
        local initialState = r.state
        -- The server publishes new zombies as WANDER. Keep that state instead of
        -- overwriting it with IDLE when this client becomes the entity owner.
        r.state = r.last and 'SEARCH' or (r.goal and 'MIGRATION' or (initialState == 'WANDER' and 'WANDER' or 'IDLE'))
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
            playAggroSound(r, ped, now)
        else
            if r.state == 'IDLE' then
                ClearPedTasks(ped)
            end
        end
    end

    -- Zone leash check: while aggroed on player (CHASE/ATTACK/ALERT/RETURN), allow chasing up to 120m outside the zone
    local myPos = GetEntityCoords(ped)
    local maxLeash = (r.state == 'CHASE' or r.state == 'ATTACK' or r.state == 'ALERT' or r.state == 'RETURN') and (r.radius + 120.0) or r.radius
    if not r.goal and r.home and r.radius and Zombie.distance(myPos, r.home) > maxLeash then
        if r.state ~= 'RETURN' and (r.state == 'CHASE' or r.state == 'ATTACK' or r.state == 'WANDER' or r.state == 'IDLE' or r.state == 'SEARCH' or r.state == 'INVESTIGATE_SOUND' or r.state == 'ALERT') then
            r.target = nil
            r.targetPed = nil
            r.last = nil
            r.aggroSoundPlayed = false
            transition(r, 'RETURN', now)
        end
    end

    -- Perception scan: runs for ALL states (including RETURN) so returning zombies can re-aggro on sight, sound or damage
    if r.settings.aggression <= 0 or (r.target and ZC.immune[r.target]) then
        r.target=nil; r.targetPed=nil; r.aggroSoundPlayed = false
        if r.state=='CHASE' or r.state=='ATTACK' or r.state=='ALERT' then
            if r.sound and r.sound.untilTime > now then transition(r,'INVESTIGATE_SOUND',now)
            else roaming(r,now,'IDLE') end
        end
    end
    local seen, distance = ZC.detect(r)
    if r.attacker then
        for _,p in ipairs(ZC.players) do
            if p.ped==r.attacker and not p.dead and not ZC.immune[p.id] and r.settings.aggression>0 then
                seen=p; distance=Zombie.distance(GetEntityCoords(ped),p.pos); break
            end
        end
        r.attacker=nil
        if seen then
            playAggroSound(r, ped, now)
        end
    end
    r.seen = seen
    if distance then r.distance = distance end

    if seen then
        playAggroSound(r, ped, now)
        r.last = Zombie.coords(seen.pos)
        r.target = seen.id
        r.targetPed = seen.ped
        r.lostTargetAt = now + 2000
        r.reason = 'vision'
        if r.state ~= 'CHASE' and r.state ~= 'ATTACK' then
            if r.state == 'SEARCH' or r.state == 'INVESTIGATE_SOUND' or r.state == 'RETURN' then
                if r.distance and r.distance <= 2.4 then
                    transition(r, 'ATTACK', now)
                    ambientSound(r, ped, now, 'attack')
                else
                    transition(r, 'CHASE', now)
                    ambientSound(r, ped, now, 'chase')
                end
            elseif r.state ~= 'ALERT' then
                transition(r, 'ALERT', now)
                ambientSound(r, ped, now, 'alert')
            end
        end
    elseif r.target then
        -- A single LOS flicker must not reset pursuit. Once that short grace
        -- expires, use the last confirmed coordinate rather than the player.
        if now >= (r.lostTargetAt or now) then
            r.target = nil
            r.targetPed = nil
            r.aggroSoundPlayed = false
            transition(r, 'SEARCH', now)
        end
    elseif r.sound and r.sound.untilTime > now then
        r.last = r.sound.pos
        r.reason = 'sound:' .. r.sound.reason
        transition(r, 'INVESTIGATE_SOUND', now)
        r.sound = nil
    elseif not r.target then
        noticeZombieCorpse(r, ped, now)
    end

    (states[r.state] or states.IDLE)(r, now)
    ambientSound(r, ped, now)

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
        Wait(50)
        local now=GetGameTimer()
        for id,r in pairs(ZC.peds) do
            local ped = not r.dead and (r.ped or ZC.entity(r))
            local isPedDead = ped and DoesEntityExist(ped) and ((type(GetEntityHealth) == 'function' and GetEntityHealth(ped) <= 0) or IsEntityDead(ped))
            if isPedDead and now>=(r.deathReportAt or 0) then
                local survivedHeadshot = false
                local hit, bone = GetPedLastDamageBone(ped)
                if hit and ZombieConfig.HeadBones and ZombieConfig.HeadBones[bone] then
                    local damageWeapon = 0
                    if type(GetPedLastDamageWeapon) == 'function' then
                        local ok, w = pcall(GetPedLastDamageWeapon, ped)
                        if ok and w and w ~= 0 then damageWeapon = w end
                    end
                    if damageWeapon == 0 and type(GetPedCauseOfDeath) == 'function' then
                        local ok, w = pcall(GetPedCauseOfDeath, ped)
                        if ok and w and w ~= 0 then damageWeapon = w end
                    end
                    if damageWeapon == 0 then
                        local myPed = PlayerPedId()
                        if myPed and DoesEntityExist(myPed) and type(GetSelectedPedWeapon) == 'function' then
                            damageWeapon = GetSelectedPedWeapon(myPed)
                        end
                    end

                    if isRangedWeapon(damageWeapon) then
                        local close = isCloseCombat(ped, r.targetPed)
                        if close then
                            -- Вблизи (в бою рядом с зомби, добивание, казнь, фаталити): 100% ваншот!
                            r.headshotsNeeded = 1
                        elseif not r.headshotsNeeded then
                            local oneShotRoll = math.random()
                            if oneShotRoll <= (ZombieConfig.HeadshotOneShotChance or 0.40) then
                                r.headshotsNeeded = 1
                            else
                                local minHits = math.max(2, ZombieConfig.HeadshotsToKillMin or 2)
                                local maxHits = math.max(minHits, ZombieConfig.HeadshotsToKillMax or 2)
                                r.headshotsNeeded = math.random(minHits, maxHits)
                            end
                            r.headHits = 0
                        end

                        if (r.headHits or 0) + 1 < r.headshotsNeeded then
                            -- Survived headshot!
                            survivedHeadshot = true
                            r.dead = false
                            r.state = 'CHASE'
                            r.deathReportAt = nil
                            r.headHits = (r.headHits or 0) + 1
                            if type(ResurrectPed) == 'function' then
                                ResurrectPed(ped)
                            end
                            local maxHp = (r.settings and r.settings.health) or 250
                            local restoreHp = (r.settings and r.settings.headshotOnly and ZombieConfig.HeadshotReserve) or math.max(60, math.floor(maxHp * 0.45))
                            SetEntityHealth(ped, restoreHp, 0)
                            ClearPedTasks(ped)
                            ClearPedLastDamageBone(ped)
                            local targetPed = r.targetPed or PlayerPedId()
                            if targetPed and DoesEntityExist(targetPed) then
                                TaskCombatPed(ped, targetPed, 0, 16)
                            end
                        end
                    end
                end

                if not survivedHeadshot then
                    r.dead = true
                    r.state = 'DEAD'
                    r.deathReportAt=now+1000
                    SetEntityAsMissionEntity(ped, true, true)
                    SetPedKeepTask(ped, true)
                    local deathSounds = ZombieConfig.DeathSounds
                    local chosenSound = deathSounds and #deathSounds > 0 and deathSounds[math.random(1, #deathSounds)]
                    if chosenSound and not r.deathSoundPlayed then
                        r.deathSoundPlayed = true
                        if type(TriggerEvent) == 'function' and type(GetEntityCoords) == 'function' then
                            local pos = Zombie.coords(GetEntityCoords(ped))
                            TriggerEvent('thehunt_zombie:ambient', r.id, r.net or 0, chosenSound, pos, ZombieConfig.AmbientSoundRange, 'death')
                        end
                    end
                    TriggerServerEvent('thehunt_zombie:pedDied', id, chosenSound)
                end
            end
        end
    end
end)

-- Headshot & damage durability handler
CreateThread(function()
    while true do
        local active=false
        for _,r in pairs(ZC.peds) do
            if not r.dead then
                local ped=ZC.entity(r)
                if ped and DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) and not IsEntityDead(ped) then
                    active=true
                    local hit,bone=GetPedLastDamageBone(ped)
                    if hit then
                        ClearPedLastDamageBone(ped)
                        local damageWeapon = 0
                        if type(GetPedLastDamageWeapon) == 'function' then
                            local ok, w = pcall(GetPedLastDamageWeapon, ped)
                            if ok and w and w ~= 0 then damageWeapon = w end
                        end
                        if damageWeapon == 0 then
                            local myPed = PlayerPedId()
                            if myPed and DoesEntityExist(myPed) and type(GetSelectedPedWeapon) == 'function' then
                                damageWeapon = GetSelectedPedWeapon(myPed)
                            end
                        end

                        if isRangedWeapon(damageWeapon) and ZombieConfig.HeadBones and ZombieConfig.HeadBones[bone] then
                            -- Ranged headshot (bow, rifle, revolver, etc.)
                            local close = isCloseCombat(ped, r.targetPed)
                            if close then
                                -- Вблизи (в бою рядом с зомби, добивание, казнь, фаталити): 100% ваншот!
                                r.headshotsNeeded = 1
                            elseif not r.headshotsNeeded then
                                local oneShotRoll = math.random()
                                if oneShotRoll <= (ZombieConfig.HeadshotOneShotChance or 0.40) then
                                    r.headshotsNeeded = 1
                                else
                                    local minHits = math.max(2, ZombieConfig.HeadshotsToKillMin or 2)
                                    local maxHits = math.max(minHits, ZombieConfig.HeadshotsToKillMax or 2)
                                    r.headshotsNeeded = math.random(minHits, maxHits)
                                end
                                r.headHits = 0
                            end

                            r.headHits = (r.headHits or 0) + 1
                            if r.headHits >= r.headshotsNeeded then
                                SetEntityHealth(ped, 0, 0)
                            else
                                -- Survived headshot: keep alive so bullet impact damage doesn't 1-shot
                                local maxHp = (r.settings and r.settings.health) or 250
                                local surviveHp = math.max(60, math.floor(maxHp * 0.45))
                                if r.settings and r.settings.headshotOnly then
                                    SetEntityHealth(ped, ZombieConfig.HeadshotReserve, 0)
                                else
                                    local curHp = GetEntityHealth(ped)
                                    if curHp < surviveHp then
                                        SetEntityHealth(ped, surviveHp, 0)
                                    end
                                end
                            end
                        else
                            -- Melee hit, fist punch, or body hit:
                            -- Apply normal damage naturally, never trigger instant headshot kill!
                            if r.settings and r.settings.headshotOnly then
                                SetEntityHealth(ped, ZombieConfig.HeadshotReserve, 0)
                            end
                        end
                    elseif r.settings and r.settings.headshotOnly and GetEntityHealth(ped)<ZombieConfig.HeadshotReserve then
                        SetEntityHealth(ped,ZombieConfig.HeadshotReserve,0)
                    end
                end
            end
        end
        Wait(active and 0 or 250)
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
