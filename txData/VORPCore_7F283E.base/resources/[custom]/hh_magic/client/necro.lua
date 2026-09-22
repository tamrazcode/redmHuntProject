Necro = Necro or {}

local selecting = false
local attackSelecting = false
local commandsOn = false
local activeSpell = nil
local minions = {}
local serviceOn = false

local MARKER = 0x94FDAE17
local KEY_FOLLOW = 0x760A9C6F -- G
local KEY_ATTACK = 0xCEFD9220 -- E
local KEY_RELEASE = 0x3B24C470 -- F
local GROUP_NAME = "HH_NECRO_MINION"

local function notify(text, ms)
    TriggerEvent("vorp:TipRight", text, ms or 2500)
end

local function cfgOf(spell)
    return (spell and spell.necro) or {}
end

local function rotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function raycast(dist)
    local cam = GetGameplayCamCoord()
    local dir = rotationToDirection(GetGameplayCamRot(2))
    local dest = cam + dir * dist
    local handle = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 4 + 8, PlayerPedId(), 0)
    local state, hit, coords, _, entity = GetShapeTestResult(handle)
    local spins = 0
    while state == 1 and spins < 8 do
        Wait(0)
        state, hit, coords, _, entity = GetShapeTestResult(handle)
        spins = spins + 1
    end
    if hit == 1 or hit == true then
        return true, coords, entity
    end
    return false, dest, 0
end

local function isHuman(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end
    if IsPedHuman then
        return IsPedHuman(ped)
    end
    return not IsEntityAPed or true
end

local function isDeadPed(ped)
    if not isHuman(ped) or ped == PlayerPedId() or minions[ped] then
        return false
    end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then
        return false
    end
    if IsEntityDead and IsEntityDead(ped) then
        return true
    end
    return IsPedDeadOrDying(ped, true)
end

local function isLivingTarget(ped, servant)
    if not isHuman(ped) or ped == PlayerPedId() or ped == servant or minions[ped] then
        return false
    end
    if IsPedOnMount(ped) then
        return false
    end
    if IsEntityDead and IsEntityDead(ped) then
        return false
    end
    return not IsPedDeadOrDying(ped, true)
end

local function closestPed(point, radius, predicate)
    local best, bestDist
    local pool = {}
    if GetGamePool then
        pool = GetGamePool("CPed") or {}
    end
    if #pool == 0 then
        local handle, ped = FindFirstPed()
        local ok = true
        if handle and handle ~= -1 then
            repeat
                pool[#pool + 1] = ped
                ok, ped = FindNextPed(handle)
            until not ok
            EndFindPed(handle)
        end
    end
    for i = 1, #pool do
        local ped = pool[i]
        if predicate(ped) then
            local dist = #(GetEntityCoords(ped) - point)
            if dist <= radius and (not bestDist or dist < bestDist) then
                best = ped
                bestDist = dist
            end
        end
    end
    return best
end

local function blockFight()
    DisableControlAction(0, `INPUT_ATTACK`, true)
    DisableControlAction(0, `INPUT_AIM`, true)
    DisableControlAction(0, `INPUT_MELEE_ATTACK`, true)
    DisablePlayerFiring(PlayerId(), true)
end

local function loadAnim(dict)
    if not dict or dict == "" then
        return false
    end
    if HasAnimDictLoaded(dict) then
        return true
    end
    if DoesAnimDictExist and not DoesAnimDictExist(dict) then
        return false
    end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function playClip(ped, dict, clip, duration, flag)
    if not loadAnim(dict) then
        return false
    end
    TaskPlayAnim(ped, dict, clip, 1.2, 1.0, duration or -1, flag or 1, 0, false, false, false)
    return true
end

local function playEmote(ped, name)
    if not name or name == "" then
        return false
    end
    pcall(function()
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, 0, 2, joaat(name), 1, 1, 0, 0, 0)
    end)
    return true
end

local function pointAt(ped, spell)
    local point = cfgOf(spell).point or {}
    playClip(ped, point.dict, point.clip, 1600, point.flag or 25)
end

local function playOrder(ped, spell, kind)
    local necro = cfgOf(spell)
    if kind == "follow" then
        playEmote(ped, necro.followEmote)
        local anim = necro.followAnim or {}
        playClip(ped, anim.dict, anim.clip, anim.durationMs or 1600, anim.flag or 25)
    elseif kind == "attack" then
        playEmote(ped, necro.attackEmote or "KIT_EMOTE_ACTION_POINT_1")
        pointAt(ped, spell)
    elseif kind == "release" then
        playEmote(ped, necro.releaseEmote or "KIT_EMOTE_GREET_WAVENEAR_1")
    end
end

local function loadPtfx(dict)
    if not dict or dict == "" then
        return false
    end
    local hash = joaat(dict)
    if Citizen.InvokeNative(0x65BB72F29138F5D6, hash) then
        return true
    end
    Citizen.InvokeNative(0xF2B2353BBC0D4E8F, hash)
    local timeout = GetGameTimer() + 1500
    while not Citizen.InvokeNative(0x65BB72F29138F5D6, hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    return Citizen.InvokeNative(0x65BB72F29138F5D6, hash) == true
        or Citizen.InvokeNative(0x65BB72F29138F5D6, hash) == 1
end

local function usePtfx(dict)
    if not loadPtfx(dict) then
        return false
    end
    Citizen.InvokeNative(0xA10DB07FC234DD12, dict)
    return true
end

local function loopOnPed(ped, dict, name, ox, oy, oz, scale)
    if not usePtfx(dict) then
        return 0
    end
    local handle = 0
    pcall(function()
        handle = StartParticleFxLoopedOnEntity(name, ped, ox or 0.0, oy or 0.0, oz or 0.0, 0.0, 0.0, 0.0, scale or 0.4, false, false, false) or 0
    end)
    return handle or 0
end

local function stopFx(handles)
    for i = 1, #handles do
        local handle = handles[i]
        if handle and handle ~= 0 then
            pcall(function()
                StopParticleFxLooped(handle, false)
            end)
        end
    end
end

local function riseFx(ped, ms)
    CreateThread(function()
        local started = GetGameTimer()
        local dur = ms or 2600
        local smoke = loopOnPed(ped, "scr_odd_fellows", "scr_river5_magician_smoke_loop", 0.0, 0.0, 0.05, 0.28)
        while DoesEntityExist(ped) and GetGameTimer() - started < dur do
            local c = GetEntityCoords(ped)
            DrawLightWithRange(c.x, c.y, c.z + 0.4, 170, 185, 175, 0.9, 0.45)
            if smoke == 0 and (GetGameTimer() - started) % 500 < 20 and usePtfx("scr_odd_fellows") then
                pcall(function()
                    StartParticleFxNonLoopedOnEntity("scr_river5_magician_smoke", ped, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.22, false, false, false)
                end)
            end
            Wait(0)
        end
        stopFx({ smoke })
    end)
end

local function healthOf(ped)
    local hp = 0
    pcall(function()
        hp = GetEntityHealth(ped)
    end)
    return tonumber(hp) or 0
end

-- IsPedDeadOrDying(ped, true) is true during a melee execution, including the killer.
-- That was dropping the servant right after they downed the player.
local function reallyDead(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return true
    end
    return healthOf(ped) <= 0
end

local function ownerDown(ped)
    if reallyDead(ped) then
        return true
    end
    local state = LocalPlayer and LocalPlayer.state
    return state and state.isDead == true
end

local function pinServant(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end
    SetEntityAsMissionEntity(ped, true, true)
    pcall(function()
        local net = NetworkGetNetworkIdFromEntity(ped)
        if net and net ~= 0 then
            SetNetworkIdExistsOnAllMachines(net, true)
            SetNetworkIdCanMigrate(net, false)
        end
    end)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedFleeAttributes(ped, 0, false)
end

local function stopTasks(ped)
    ClearPedTasksImmediately(ped)
end

local function takeControl(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        return false
    end
    SetEntityAsMissionEntity(ent, true, true)
    if not NetworkGetEntityIsNetworked or not NetworkGetEntityIsNetworked(ent) then
        return true
    end
    local deadline = GetGameTimer() + 900
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(ent)
        Wait(0)
    end
    return NetworkHasControlOfEntity(ent)
end

local function applyDrunkRunner(ped)
    local motion = "very_drunk"
    if IsPedMale and not IsPedMale(ped) then
        motion = "moderate_drunk"
    end
    pcall(function()
        Citizen.InvokeNative(0x923583741DC87BCE, ped, "default")
        Citizen.InvokeNative(0x89F5E7ADECCCB49C, ped, motion)
    end)
    SetPedMaxMoveBlendRatio(ped, 3.0)
end

local function servantGroup(ped)
    local net = 0
    pcall(function()
        if NetworkGetEntityIsNetworked(ped) then
            net = NetworkGetNetworkIdFromEntity(ped) or 0
        end
    end)
    local name = ("HH_NECRO_%s"):format(net ~= 0 and tostring(net) or tostring(ped))
    pcall(function()
        AddRelationshipGroup(name)
    end)
    local group = joaat(name)
    pcall(function()
        Entity(ped).state:set("necroGroup", group, true)
    end)
    return group
end

local function keepFriendly(ped, owner)
    local group = servantGroup(ped)
    local playerGroup = joaat("PLAYER")
    SetPedRelationshipGroupHash(ped, group)
    pcall(function()
        SetRelationshipBetweenGroups(1, group, playerGroup)
        SetRelationshipBetweenGroups(1, playerGroup, group)
        SetRelationshipBetweenGroups(1, group, group)
        SetCanAttackFriendly(ped, false, false)
    end)
    pcall(function()
        SetEntityCanBeDamagedByRelationshipGroup(owner, false, group)
    end)
end

local function joinOwner(ped, owner)
    pcall(function()
        local memberOf = GetPedGroupIndex(owner)
        if memberOf and memberOf ~= -1 and memberOf ~= 0 then
            SetPedAsGroupMember(ped, memberOf)
            SetPedNeverLeavesGroup(ped, true)
        end
    end)
end

local function markPrey(ped, target, owner)
    local myGroup = servantGroup(ped)
    local prey = GetPedRelationshipGroupHash(target)
    pcall(function()
        local tagged = Entity(target).state.necroGroup
        if type(tagged) == "number" and tagged ~= 0 then
            prey = tagged
        end
    end)
    local playerGroup = joaat("PLAYER")
    if IsPedAPlayer(target) then
        -- The owner shares PLAYER. Hating that group makes the servant swing at whoever stands next to them.
        pcall(function()
            SetCanAttackFriendly(ped, true, false)
        end)
        return
    end
    if not prey or prey == 0 or prey == myGroup or prey == playerGroup then
        return
    end
    pcall(function()
        SetRelationshipBetweenGroups(5, myGroup, prey)
    end)
end

local function bury(ped)
    if not ped or not DoesEntityExist(ped) then
        return
    end
    ClearPedTasks(ped)
    pcall(function()
        SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false)
    end)
    pcall(function()
        SetEntityHealth(ped, 0, 0)
    end)
    pcall(function()
        SetEntityHealth(ped, 0)
    end)
end

local function vanishPed(ped)
    if not ped or not DoesEntityExist(ped) then
        return
    end
    pcall(function()
        StopEntityFire(ped)
    end)
    SetEntityAsMissionEntity(ped, true, true)
    pcall(function()
        DeletePed(ped)
    end)
    if DoesEntityExist(ped) then
        pcall(function()
            DeleteEntity(ped)
        end)
    end
end

local function orderFollow(ped, owner, necro, breakCombat)
    takeControl(ped)
    pinServant(ped)
    if breakCombat then
        ClearPedTasks(ped)
    end
    applyDrunkRunner(ped)
    keepFriendly(ped, owner)
    joinOwner(ped, owner)
    local speed = necro.followSpeed or 2.6
    local back = necro.followOffset or 1.8
    if ownerDown(owner) then
        local coords = GetEntityCoords(owner)
        TaskGoToCoordAnyMeans(ped, coords.x + 0.8, coords.y + 0.4, coords.z, speed, 0, false, 786603, 0.0)
        return
    end
    local ok = pcall(function()
        TaskFollowToOffsetOfEntity(ped, owner, 0.0, -back, 0.0, speed, -1, 1.15, true)
    end)
    if not ok then
        pcall(function()
            TaskGoToEntity(ped, owner, -1, back, speed, 0.0, 0)
        end)
    end
end

local function orderAttack(ped, target, owner)
    if not target or target == owner or not DoesEntityExist(target) or reallyDead(target) then
        return
    end
    takeControl(ped)
    pinServant(ped)
    local already = IsPedInCombat(ped, target)
    if not already then
        ClearPedTasks(ped)
    end
    applyDrunkRunner(ped)
    keepFriendly(ped, owner)
    markPrey(ped, target, owner)
    pcall(function()
        RemovePedFromGroup(ped)
    end)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedSeeingRange(ped, 40.0)
    SetPedHearingRange(ped, 40.0)
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 0)
    pcall(function()
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatAttributes(ped, 46, true)
        SetPedCombatAttributes(ped, 50, true)
        SetPedCombatAttributes(ped, 58, true)
        SetPedCombatAttributes(ped, 0, false)
    end)
    local hittingOwner = IsPedInCombat(ped, owner)
    if not already or hittingOwner then
        ClearPedTasks(ped)
        pcall(function()
            TaskCombatPed(ped, target, 0, 16)
        end)
    end
    SetPedKeepTask(ped, true)
end

local function commandLiving(mode, target)
    local owner = PlayerPedId()
    for ped, state in pairs(minions) do
        if DoesEntityExist(ped) and not reallyDead(ped) then
            state.mode = mode
            state.target = target
            state.nextTask = GetGameTimer() + 400
            if mode == "follow" then
                orderFollow(ped, owner, state.necro or {}, true)
            elseif mode == "attack" and target and target ~= owner then
                orderAttack(ped, target, owner)
            end
        end
    end
end

local function anyServant()
    for ped in pairs(minions) do
        if DoesEntityExist(ped) and not reallyDead(ped) then
            return true
        end
    end
    return false
end

local burningCount = 0
local servantReported = false
local burnAlive

local function reportServant()
    local up = anyServant() or burningCount > 0
    if up == servantReported then
        return
    end
    servantReported = up
    TriggerServerEvent("hh_magic:server:servant", up)
end

local function ensureService()
    if serviceOn then
        return
    end
    serviceOn = true
    CreateThread(function()
        while next(minions) do
            local now = GetGameTimer()
            local owner = PlayerPedId()
            for ped, state in pairs(minions) do
                if not DoesEntityExist(ped) then
                    minions[ped] = nil
                elseif reallyDead(ped) then
                    local died = (state and state.diedText) or "Ваш подопечный умер."
                    minions[ped] = nil
                    notify(died, 2500)
                    burnAlive(ped, nil, true)
                elseif now >= state.expires then
                    local expired = state.expiredText or "Слуга снова падает замертво."
                    minions[ped] = nil
                    notify(expired, 2500)
                    burnAlive(ped, nil, true)
                else
                    local rooted = false
                    pcall(function()
                        rooted = Entity(ped).state.huntThornRoot == true
                    end)
                    if rooted then
                        FreezeEntityPosition(ped, true)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        SetPedKeepTask(ped, true)
                    else
                    pinServant(ped)
                    if state.mode == "attack" then
                        SetBlockingOfNonTemporaryEvents(ped, false)
                    end
                    if ZC and ZC.markNecroServant then
                        ZC.markNecroServant(ped)
                    end
                    if ZC and ZC.peds then
                        for id, record in pairs(ZC.peds) do
                            if record.ped == ped or record.corpsePed == ped then
                                ZC.peds[id] = nil
                            end
                        end
                    end
                    local target = state.target
                    local targetAlive = target and target ~= owner and not reallyDead(target) and isLivingTarget(target, ped)
                    local hittingOwner = IsPedInCombat(ped, owner)
                    local down = ownerDown(owner)
                    if hittingOwner and state.mode == "follow" and now >= (state.nextTask or 0) then
                        orderFollow(ped, owner, state.necro or {}, true)
                        state.nextTask = now + 2500
                    elseif state.mode == "attack" and targetAlive then
                        if hittingOwner or (now >= (state.nextTask or 0) and not IsPedInCombat(ped, target)) then
                            orderAttack(ped, target, owner)
                            state.nextTask = now + 2500
                        end
                    else
                        if state.mode == "attack" then
                            state.mode = "follow"
                            state.target = nil
                            state.forceFollow = true
                        end
                        if state.mode == "follow" and DoesEntityExist(owner) and now >= (state.nextTask or 0) then
                            local dist = #(GetEntityCoords(ped) - GetEntityCoords(owner))
                            local resume = state.forceFollow or state.ownerWasDown ~= down
                            if resume or dist > 2.6 then
                                orderFollow(ped, owner, state.necro or {}, resume)
                            end
                            state.forceFollow = false
                            state.ownerWasDown = down
                            state.nextTask = now + 1200
                        end
                    end
                end
            end
            Wait(400)
        end
    end
    serviceOn = false
end)
end

local function bindMinion(ped, spell)
    local necro = cfgOf(spell)
    pcall(function()
        AddRelationshipGroup(GROUP_NAME)
    end)
    local group = joaat(GROUP_NAME)
    local playerGroup = GetPedRelationshipGroupHash(PlayerPedId())
    SetPedRelationshipGroupHash(ped, group)
    keepFriendly(ped, PlayerPedId())
    pcall(function()
        SetRelationshipBetweenGroups(1, group, playerGroup)
        SetRelationshipBetweenGroups(1, playerGroup, group)
    end)
    pcall(function()
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAbility(ped, 2)
        SetPedCombatMovement(ped, 2)
        SetPedCombatRange(ped, 0)
        SetPedSeeingRange(ped, 40.0)
        SetPedHearingRange(ped, 40.0)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedKeepTask(ped, true)
    end)
    pinServant(ped)
    applyDrunkRunner(ped)
    local health = necro.health or 280
    pcall(function()
        SetEntityMaxHealth(ped, health)
    end)
    pcall(function()
        SetEntityHealth(ped, health, 0)
    end)
    pcall(function()
        SetEntityHealth(ped, health)
    end)
    minions[ped] = {
        expires = GetGameTimer() + (necro.lifeMs or 300000),
        mode = "idle",
        target = nil,
        nextTask = 0,
        necro = necro,
        expiredText = spell.notifyExpired,
        diedText = spell.notifyDied,
    }
    ensureService()
    reportServant()
end

local function playGetup(ped, spell)
    local stages = cfgOf(spell).getup or {}
    for i = 1, #stages do
        if not DoesEntityExist(ped) or reallyDead(ped) then
            return
        end
        local stage = stages[i]
        local dur = stage.duration or 2800
        if loadAnim(stage.dict) then
            TaskPlayAnim(ped, stage.dict, stage.clip, 0.8, 0.8, dur, 0, 0.0, false, false, false)
            Wait(math.max(600, dur - 200))
        end
    end
end

local function claimHuntZombie(ped)
    local id
    pcall(function()
        local tag = Entity(ped).state.huntZombie
        if type(tag) == "table" then
            id = tag.id
        end
        Entity(ped).state:set("huntNecroServant", true, true)
        Entity(ped).state:set("isProtected", true, true)
    end)
    if not id and ZC and ZC.peds then
        for zid, record in pairs(ZC.peds) do
            local same = record.ped == ped or record.corpsePed == ped
            if not same and ZC.entity then
                same = ZC.entity(record) == ped
            end
            if same then
                id = zid
                break
            end
        end
    end
    if ZC and ZC.markNecroServant then
        ZC.markNecroServant(ped)
    elseif ZC and ZC.untrackCorpse then
        ZC.untrackCorpse(ped)
    end
    if id and ZC and ZC.peds then
        ZC.peds[id] = nil
    end
    if id then
        TriggerServerEvent("thehunt_zombie:claim", id)
    end
end

local function resurrect(ped, spell)
    if not takeControl(ped) then
        return false
    end
    claimHuntZombie(ped)
    local coords = GetEntityCoords(ped)
    local ok = pcall(function()
        ResurrectPed(ped)
    end)
    if not ok then
        pcall(function()
            Citizen.InvokeNative(0x71BC8E838B9C6035, ped)
        end)
    end
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    Wait(150)
    if IsPedDeadOrDying(ped, true) then
        return false
    end
    riseFx(ped, 2400)
    return true
end

local function makePrompt(control, text, group)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, control)
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", text))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetStandardMode(prompt, true)
    PromptSetGroup(prompt, group)
    PromptRegisterEnd(prompt)
    return prompt
end

local followPrompt, attackPrompt, releasePrompt
local choiceGroup

local function ensureChoicePrompts()
    if followPrompt then
        return
    end
    choiceGroup = GetRandomIntInRange(0, 0xffffff)
    followPrompt = makePrompt(KEY_FOLLOW, "Следовать", choiceGroup)
    attackPrompt = makePrompt(KEY_ATTACK, "Атаковать", choiceGroup)
    releasePrompt = makePrompt(KEY_RELEASE, "Отпустить", choiceGroup)
end

local function promptPressed(prompt, control)
    EnableControlAction(0, control, true)
    if prompt and PromptHasStandardModeCompleted and PromptHasStandardModeCompleted(prompt) then
        return true
    end
    return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

local function showOrderPrompts()
    PromptSetEnabled(followPrompt, true)
    PromptSetVisible(followPrompt, true)
    PromptSetEnabled(attackPrompt, true)
    PromptSetVisible(attackPrompt, true)
    PromptSetEnabled(releasePrompt, true)
    PromptSetVisible(releasePrompt, true)
    PromptSetActiveGroupThisFrame(choiceGroup, CreateVarString(10, "LITERAL_STRING", "Некромант"))
end

burnAlive = function(ped, diedText, silent)
    burningCount = burningCount + 1
    reportServant()
    CreateThread(function()
        takeControl(ped)
        pinServant(ped)
        stopTasks(ped)
        pcall(function()
            SetEntityInvincible(ped, false)
            SetEntityCanBeDamaged(ped, true)
            SetEntityProofs(ped, false, false, false, false, false, false, false, false)
        end)
        local ends = GetGameTimer() + 3200
        local function ignite()
            pcall(function()
                StartEntityFire(ped)
            end)
            pcall(function()
                Citizen.InvokeNative(0x6B83617E04503888, ped)
            end)
        end
        ignite()
        local handles = {
            loopOnPed(ped, "anm_fire", "ent_anim_candle_flame", 0.0, 0.05, 0.55, 1.6),
            loopOnPed(ped, "anm_fire", "ent_anim_candle_flame", 0.12, 0.0, 0.95, 1.1),
            loopOnPed(ped, "anm_fire", "ent_anim_candle_flame", -0.1, 0.0, 0.25, 1.25),
            loopOnPed(ped, "anm_fire", "ent_anim_rslvc_burn_book", 0.0, 0.0, 0.4, 0.9),
        }
        local nextBurst = 0
        while DoesEntityExist(ped) and GetGameTimer() < ends do
            local c = GetEntityCoords(ped)
            DrawLightWithRange(c.x, c.y, c.z + 0.6, 255, 90, 15, 1.6, 1.35)
            if GetGameTimer() >= nextBurst then
                nextBurst = GetGameTimer() + 350
                ignite()
                if usePtfx("anm_fire") then
                    pcall(function()
                        StartParticleFxNonLoopedOnEntity("ent_anim_fire_fuel_burst", ped, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.55, false, false, false)
                    end)
                end
            end
            Wait(0)
        end
        takeControl(ped)
        stopTasks(ped)
        bury(ped)
        Wait(2000)
        pcall(function()
            StopEntityFire(ped)
        end)
        stopFx(handles)
        vanishPed(ped)
        burningCount = math.max(0, burningCount - 1)
        reportServant()
        if not silent then
            notify(diedText or "Ваш подопечный умер.", 2500)
        end
    end)
end

local function releaseServants(spell)
    local doomed = {}
    for ped in pairs(minions) do
        if DoesEntityExist(ped) and not reallyDead(ped) then
            doomed[#doomed + 1] = ped
            takeControl(ped)
            stopTasks(ped)
            minions[ped] = nil
        end
    end
    if #doomed == 0 then
        return
    end
    notify((spell and spell.notifyRelease) or "Вы отпускаете слугу.", 2000)
    playOrder(PlayerPedId(), spell or {}, "release")
    local died = (spell and spell.notifyDied) or "Ваш подопечный умер."
    for i = 1, #doomed do
        burnAlive(doomed[i], died)
    end
end

local function ensureCommands(spell)
    activeSpell = spell or activeSpell
    if commandsOn then
        return
    end
    commandsOn = true
    ensureChoicePrompts()
    CreateThread(function()
        local lockUntil = 0
        notify((activeSpell and activeSpell.notifyChoice) or "G — следовать  |  E — атаковать  |  F — отпустить", 4500)
        while anyServant() do
            Wait(0)
            if not selecting and not attackSelecting then
                showOrderPrompts()
                local now = GetGameTimer()
                if now >= lockUntil and promptPressed(followPrompt, KEY_FOLLOW) then
                    lockUntil = now + 600
                    local spell = activeSpell
                    playOrder(PlayerPedId(), spell or {}, "follow")
                    commandLiving("follow", nil)
                    notify((spell and spell.notifyFollow) or "Слуга идёт за вами.", 2000)
                elseif now >= lockUntil and promptPressed(attackPrompt, KEY_ATTACK) then
                    lockUntil = now + 600
                    Necro.pickAttack(activeSpell)
                elseif now >= lockUntil and promptPressed(releasePrompt, KEY_RELEASE) then
                    lockUntil = now + 600
                    releaseServants(activeSpell)
                end
            end
        end
        commandsOn = false
    end)
end

function Necro.pickAttack(spell)
    local necro = cfgOf(spell)
    attackSelecting = true
    notify("ЛКМ — цель  |  ПКМ — назад", 2500)
    local range = necro.range or 12.0
    local radius = necro.aimRadius or 1.8
    pointAt(PlayerPedId(), spell)
    while attackSelecting and anyServant() do
        Wait(0)
        blockFight()
        local player = PlayerPedId()
        if necro.point and not IsEntityPlayingAnim(player, necro.point.dict, necro.point.clip, 3) then
            pointAt(player, spell)
        end
        local hit, point = raycast(range + 6.0)
        local target = closestPed(point, radius, function(ped)
            return isLivingTarget(ped, 0)
        end)
        local ok = hit and target and #(GetEntityCoords(player) - GetEntityCoords(target)) <= (range + 2.0)
        local r, g, b = 180, 40, 40
        local mark = point
        if ok then
            r, g, b = 120, 200, 80
            mark = GetEntityCoords(target)
        end
        DrawMarker(MARKER, mark.x, mark.y, mark.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 1.2, r, g, b, 180, false, false, 2, nil, nil, false, false)
        if IsDisabledControlJustPressed(0, `INPUT_ATTACK`) then
            if ok then
                attackSelecting = false
                ClearPedSecondaryTask(player)
                commandLiving("attack", target)
                playOrder(PlayerPedId(), spell or {}, "attack")
                notify((spell and spell.notifyAttack) or "Слуга бросается на цель.", 2000)
                return
            end
            notify((spell and spell.failNoTarget) or "Некого атаковать.", 2000)
        elseif IsDisabledControlJustPressed(0, `INPUT_AIM`)
            or IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`) then
            attackSelecting = false
            ClearPedSecondaryTask(player)
            return
        end
    end
    attackSelecting = false
end

local function selectCorpse(spellId, spell)
    local necro = cfgOf(spell)
    local range = necro.range or 12.0
    local radius = necro.aimRadius or 1.8
    selecting = true
    if MagicCards and MagicCards.startHold then
        MagicCards.startHold(spellId)
    end
    CreateThread(function()
        local keepAt = 0
        while selecting do
            Wait(0)
            blockFight()
            local now = GetGameTimer()
            if MagicCards and MagicCards.keepHold and now >= keepAt then
                MagicCards.keepHold()
                keepAt = now + 400
            end
            local hit, point = raycast(range + 6.0)
            local corpse = closestPed(point, radius, isDeadPed)
            local origin = GetEntityCoords(PlayerPedId())
            local dist = corpse and #(origin - GetEntityCoords(corpse)) or 999.0
            local ok = hit and corpse and dist <= range
            local r, g, b = 160, 40, 40
            local mark = point
            if ok then
                r, g, b = 70, 160, 90
                mark = GetEntityCoords(corpse)
            end
            local gz = mark.z
            local found, ground = GetGroundZFor_3dCoord(mark.x, mark.y, mark.z + 1.2, false)
            if found then
                gz = ground + 0.05
            end
            DrawMarker(MARKER, mark.x, mark.y, gz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.85, 0.85, 1.35, r, g, b, 190, false, false, 2, nil, nil, false, false)

            if IsDisabledControlJustPressed(0, `INPUT_ATTACK`) then
                if ok then
                    selecting = false
                    local raised = corpse
                    if not resurrect(raised, spell) then
                        notify(spell.failControl or "Этот труп не поддаётся.", 2500)
                        selectCorpse(spellId, spell)
                        return
                    end
                    notify(spell.notifyRaised or "Труп поднимается.", 2500)
                    if MagicCards and MagicCards.finishRitual then
                        CreateThread(function()
                            MagicCards.finishRitual()
                        end)
                    end
                    TriggerServerEvent("hh_magic:server:castResult", spellId, true, "ok")
                    playGetup(raised, spell)
                    bindMinion(raised, spell)
                    ensureCommands(spell)
                    return
                end
                notify(spell.failNoCorpse or "Здесь нет трупа.", 2000)
            elseif IsDisabledControlJustPressed(0, `INPUT_AIM`)
                or IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`)
                or IsDisabledControlJustPressed(0, `INPUT_GAME_MENU_CANCEL`) then
                selecting = false
                if MagicCards and MagicCards.putAway then
                    MagicCards.putAway(false)
                end
                TriggerServerEvent("hh_magic:server:aimCancel", spellId)
                return
            end
        end
    end)
end

function Necro.start(spellId, spell)
    if selecting or attackSelecting then
        return
    end
    if anyServant() or burningCount > 0 then
        notify(spell.failServant or "Пока слуга жив, карту нельзя использовать.", 2500)
        return
    end
    selectCorpse(spellId, spell)
end

RegisterNetEvent("hh_magic:client:aimAborted", function()
    selecting = false
    attackSelecting = false
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    selecting = false
    attackSelecting = false
    commandsOn = false
    for ped in pairs(minions) do
        bury(ped)
    end
    minions = {}
end)
