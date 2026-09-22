local aiming = false
local rootedPeds = {}
local bushPatches = {} -- [castId] = { objs... }

local MARKER = 0x94FDAE17

local function notify(text, ms)
    TriggerEvent("vorp:TipRight", text, ms or 2500)
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
    local handle = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 16, PlayerPedId(), 0)
    local state, hit, coords = GetShapeTestResult(handle)
    local spins = 0
    while state == 1 and spins < 8 do
        Wait(0)
        state, hit, coords = GetShapeTestResult(handle)
        spins = spins + 1
    end
    if hit == 1 or hit == true then
        return true, coords
    end
    return false, dest
end

local function blockAimControls()
    local controls = {
        `INPUT_ATTACK`,
        `INPUT_AIM`,
        `INPUT_MELEE_ATTACK`,
        `INPUT_ATTACK2`,
        `INPUT_JUMP`,
        `INPUT_SPRINT`,
    }
    for i = 1, #controls do
        DisableControlAction(0, controls[i], true)
    end
    DisablePlayerFiring(PlayerId(), true)
end

local function startAim(spellId, spell)
    if aiming then
        return
    end
    aiming = true
    local thorns = spell.thorns
    local range = thorns.range or 20.0
    local radius = thorns.radius or 4.0

    -- pull card out and look at it for the whole aim phase
    if MagicCards and MagicCards.startHold then
        MagicCards.startHold(spellId)
    end

    CreateThread(function()
        local keepAt = 0
        while aiming do
            Wait(0)
            blockAimControls()

            -- keep hold pose + card attached while choosing the spot
            local now = GetGameTimer()
            if MagicCards and MagicCards.keepHold and now >= keepAt then
                MagicCards.keepHold()
                keepAt = now + 400
            end

            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            local hit, point = raycast(range + 8.0)
            local dist = #(origin - point)
            local ok = hit and dist <= range

            local r, g, b = 40, 120, 255
            if not ok then
                r, g, b = 180, 40, 40
            end
            local gz = point.z + 0.06
            local found, ground = GetGroundZFor_3dCoord(point.x, point.y, point.z + 1.5, false)
            if found then
                gz = ground + 0.08
            end

            DrawMarker(
                MARKER, point.x, point.y, gz,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                radius * 2.0, radius * 2.0, 0.18,
                r, g, b, 170,
                false, false, 2, nil, nil, false, false
            )
            local pegs = 24
            for i = 1, pegs do
                local ang = (i / pegs) * math.pi * 2.0
                DrawMarker(
                    MARKER,
                    point.x + math.cos(ang) * radius,
                    point.y + math.sin(ang) * radius,
                    gz,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.28, 0.28, 1.15,
                    r, g, b, 230,
                    false, false, 2, nil, nil, false, false
                )
            end

            if IsDisabledControlJustPressed(0, `INPUT_ATTACK`) then
                if ok then
                    aiming = false
                    TriggerServerEvent("hh_magic:server:aimConfirm", spellId, point.x, point.y, point.z)
                else
                    notify(spell.failAim or "Сюда нельзя.", 2000)
                end
            elseif IsDisabledControlJustPressed(0, `INPUT_AIM`)
                or IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`)
                or IsDisabledControlJustPressed(0, `INPUT_GAME_MENU_CANCEL`) then
                aiming = false
                if MagicCards and MagicCards.putAway then
                    MagicCards.putAway(false)
                end
                TriggerServerEvent("hh_magic:server:aimCancel", spellId)
            end
        end
    end)
end

RegisterNetEvent("hh_magic:client:aimAborted", function()
    aiming = false
    if MagicCards and MagicCards.putAway then
        MagicCards.putAway(true)
    end
end)

RegisterNetEvent("hh_magic:client:beginAim", function(spellId)
    local spell = Config.Spells and Config.Spells[spellId]
    if not spell or not spell.thorns then
        if spell and spell.necro and Necro and Necro.start then
            Necro.start(spellId, spell)
            return
        end
        if spell and spell.raven and Raven and Raven.start then
            Raven.start(spellId, spell)
            return
        end
        if spell and spell.oath and Oath and Oath.start then
            Oath.start(spellId, spell)
            return
        end
        TriggerEvent("hh_magic:client:tryCast", spellId)
        return
    end
    startAim(spellId, spell)
end)

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelValid(hash) then
        return nil
    end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 2500
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then
        return nil
    end
    return hash
end

local function firstBush(names)
    for i = 1, #(names or {}) do
        local hash = loadModel(names[i])
        if hash then
            return hash
        end
    end
    return nil
end

local function growBush(hash, x, y, z)
    local ok, obj = pcall(CreateObject, hash, x, y, z - 1.15, false, false, false, false, true)
    if not ok or not obj or obj == 0 then
        return 0
    end
    SetEntityAsMissionEntity(obj, true, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    CreateThread(function()
        local start = GetGameTimer()
        local grow = 350
        while DoesEntityExist(obj) do
            local t = (GetGameTimer() - start) / grow
            if t >= 1.0 then
                SetEntityCoords(obj, x, y, z, false, false, false, false)
                return
            end
            SetEntityCoords(obj, x, y, z - 1.15 * (1.0 - t), false, false, false, false)
            Wait(0)
        end
    end)
    return obj
end

local function deleteBushList(list)
    for i = 1, #(list or {}) do
        local obj = list[i]
        if obj and DoesEntityExist(obj) then
            SetEntityAsMissionEntity(obj, true, true)
            DeleteObject(obj)
        end
    end
end

local function sinkBushes(list, castId)
    CreateThread(function()
        local start = GetGameTimer()
        local origin = {}
        for i = 1, #list do
            local obj = list[i]
            if DoesEntityExist(obj) then
                origin[i] = GetEntityCoords(obj)
            end
        end
        while GetGameTimer() - start < 350 do
            local t = (GetGameTimer() - start) / 350
            for i = 1, #list do
                local obj = list[i]
                local pos = origin[i]
                if pos and DoesEntityExist(obj) then
                    SetEntityCoords(obj, pos.x, pos.y, pos.z - 1.15 * t, false, false, false, false)
                end
            end
            Wait(0)
        end
        deleteBushList(list)
        if castId and bushPatches[castId] == list then
            bushPatches[castId] = nil
        end
    end)
end

local function clearBushPatch(castId)
    local list = bushPatches[castId]
    if list then
        deleteBushList(list)
        bushPatches[castId] = nil
    end
end

local function clearAllBushPatches()
    for id, list in pairs(bushPatches) do
        deleteBushList(list)
        bushPatches[id] = nil
    end
end

local function playBind(ped, anim, durationMs)
    if not anim then
        return false
    end
    local function tryPlay(dict, clip, flag)
        if not dict or not loadAnimDict(dict) then
            return false
        end
        TaskPlayAnim(ped, dict, clip, 2.0, 2.0, durationMs or -1, flag or 1, 0.0, false, false, false, "", false)
        return true
    end
    if tryPlay(anim.dict, anim.clip, anim.flag) then
        return true
    end
    if anim.fallback then
        return tryPlay(anim.fallback.dict, anim.fallback.clip, anim.fallback.flag)
    end
    return false
end

function loadAnimDict(dict)
    if not dict or dict == "" then
        return false
    end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function lineBlocked(from, to, ignore)
    local handle = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 1, ignore or 0, 0)
    local state, hit = GetShapeTestResult(handle)
    local spins = 0
    while state == 1 and spins < 6 do
        Wait(0)
        state, hit = GetShapeTestResult(handle)
        spins = spins + 1
    end
    return hit == 1 or hit == true
end

local function isHumanPed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false
    end
    if IsPedHuman then
        return IsPedHuman(ped) == true or IsPedHuman(ped) == 1
    end
    return false
end

local function mountOf(ped)
    if not IsPedOnMount(ped) or not GetMount then
        return 0
    end
    local mount = GetMount(ped)
    if mount and mount ~= 0 and DoesEntityExist(mount) then
        return mount
    end
    return 0
end

local function canBind(ped, point, cfg)
    if not isHumanPed(ped) or IsPedDeadOrDying(ped, true) then
        return false
    end
    local mounted = IsPedOnMount(ped)
    if not mounted and (IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or not IsPedOnFoot(ped)) then
        return false
    end
    local mount = mounted and mountOf(ped) or 0
    local coords = mount ~= 0 and GetEntityCoords(mount) or GetEntityCoords(ped)
    if math.abs(coords.z - point.z) > (cfg.maxHeightDiff or 2.5) then
        return false
    end
    local flat = #(vector3(coords.x, coords.y, point.z) - point)
    if flat > (cfg.radius or 4.0) then
        return false
    end
    local chest = coords + vector3(0.0, 0.0, mounted and 1.1 or 0.6)
    if lineBlocked(point + vector3(0.0, 0.0, 0.4), chest, mount ~= 0 and mount or ped) then
        return false
    end
    return true
end

local function takeControl(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end
    if NetworkHasControlOfEntity(entity) then
        return true
    end
    local deadline = GetGameTimer() + 700
    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return DoesEntityExist(entity) and NetworkHasControlOfEntity(entity)
end

-- Action 2 throws the rider. Then the horse is cut loose so it bolts instead of staying in the thorns.
local function throwFromHorse(ped)
    if not DoesEntityExist(ped) or not IsPedOnMount(ped) then
        return
    end
    local mount = mountOf(ped)
    if mount == 0 then
        TaskDismountAnimal(ped, 0, 0, 0, 0, 0)
        return
    end
    takeControl(mount)
    pcall(function()
        Citizen.InvokeNative(0x931B241409216C1F, ped, mount, false)
    end)
    Citizen.InvokeNative(0xA09CFD29100F06C3, mount, 2, 0, 0)
    local deadline = GetGameTimer() + 1600
    while DoesEntityExist(ped) and IsPedOnMount(ped) and GetGameTimer() < deadline do
        Wait(50)
    end
    if DoesEntityExist(ped) and IsPedOnMount(ped) then
        TaskDismountAnimal(ped, 0, 0, 0, 0, mount)
        Wait(350)
    end
    if DoesEntityExist(ped) and IsPedOnMount(ped) then
        local coords = GetEntityCoords(ped)
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, coords.x + 0.8, coords.y, coords.z, false, false, false, false)
    end
    if DoesEntityExist(mount) then
        takeControl(mount)
        pcall(function()
            if TaskSmartFleePed then
                TaskSmartFleePed(mount, ped, 80.0, 15000, false, false)
            else
                Citizen.InvokeNative(0x22B0D0E37CCB840D, mount, ped, 80.0, 15000, false, false)
            end
        end)
        SetPedKeepTask(mount, true)
    end
end

local function owns(ped)
    if ped == PlayerPedId() then
        return true
    end
    if IsPedAPlayer and IsPedAPlayer(ped) then
        return false
    end
    return NetworkGetEntityOwner(ped) == PlayerId()
end

local function dropProps(list)
    for i = 1, #(list or {}) do
        local obj = list[i]
        if obj and DoesEntityExist(obj) then
            DetachEntity(obj, true, true)
            DeleteObject(obj)
        end
    end
end

local function pedNetId(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return 0
    end
    if NetworkGetEntityIsNetworked(ped) then
        return NetworkGetNetworkIdFromEntity(ped)
    end
    return 0
end

-- After the throw, the rider is still moving. Wait until they are off the horse and have settled.
local function waitLanded(ped)
    local deadline = GetGameTimer() + 2600
    while DoesEntityExist(ped) and IsPedOnMount(ped) and GetGameTimer() < deadline do
        Wait(50)
    end
    local prev = DoesEntityExist(ped) and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local stillUntil = GetGameTimer() + 900
    while DoesEntityExist(ped) and GetGameTimer() < stillUntil do
        Wait(80)
        if IsPedOnMount(ped) then
            stillUntil = GetGameTimer() + 700
        else
            local pos = GetEntityCoords(ped)
            local moving = #(pos - prev) > 0.4 or IsPedRagdoll(ped)
            prev = pos
            if not moving then
                break
            end
        end
    end
    Wait(400)
end

local function startRootsVisual(ped, castId, durationMs)
    if not castId or not RootsFx or not RootsFx.start then
        return nil
    end
    local netId = pedNetId(ped)
    local effectId = ("%s_%s"):format(tostring(castId), tostring(netId ~= 0 and netId or ped))
    local coords = GetEntityCoords(ped)
    RootsFx.start({
        effectId = effectId,
        targetNetId = netId,
        targetPed = ped,
        coords = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) },
        seed = (castId * 997) + (ped % 1000),
        remainingMs = durationMs or 30000,
    })
    return effectId
end

local function lockPlayerControls()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    DisablePlayerFiring(PlayerId(), true)
    local voice = {
        `INPUT_PUSH_TO_TALK`,
        0xF1301666,
        0x05CA7C52,
    }
    for pad = 0, 2 do
        for i = 1, #voice do
            EnableControlAction(pad, voice[i], true)
        end
    end
    if IsNuiFocused and IsNuiFocused() then
        TriggerEvent("thehunt_inventory:forceClose")
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

local function setThornRoot(ped, on)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end
    pcall(function()
        Entity(ped).state:set("huntThornRoot", on and true or false, true)
    end)
end

local function holdRoot(ped, cfg, bushes, castId, relocate)
    -- prevent stacking freeze/threads on the same ped (2nd cast crash)
    local prev = rootedPeds[ped]
    if prev then
        if prev.effectId and RootsFx and RootsFx.stop then
            RootsFx.stop(prev.effectId, "replace")
        end
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            ClearPedTasks(ped)
        end
        rootedPeds[ped] = nil
        Wait(0)
    end

    local untilAt = GetGameTimer() + (cfg.durationMs or 30000)
    local bind = cfg.bind or {}
    local token = GetGameTimer()
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    if ped == PlayerPedId() then
        LocalPlayer.state:set("hhThornLocked", true, false)
        TriggerEvent("thehunt_inventory:forceClose")
    else
        setThornRoot(ped, true)
    end
    playBind(ped, bind)
    if GetResourceState("hh_zombies") == "started" then
        pcall(function()
            exports.hh_zombies:HHZombiesSetRooted(ped, cfg.durationMs or 30000)
        end)
    end

    local effectId
    if relocate and RootsFx and RootsFx.stop then
        local netId = pedNetId(ped)
        RootsFx.stop(("%s_%s"):format(tostring(castId), tostring(netId ~= 0 and netId or ped)), "replace")
    end
    effectId = startRootsVisual(ped, castId, cfg.durationMs)
    rootedPeds[ped] = { untilAt = untilAt, bushes = bushes, effectId = effectId, token = token }

    CreateThread(function()
        while DoesEntityExist(ped) and GetGameTimer() < untilAt do
            local state = rootedPeds[ped]
            if not state or state.token ~= token then
                return
            end
            if IsPedDeadOrDying(ped, true) then
                break
            end
            if ped == PlayerPedId() then
                lockPlayerControls()
            else
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedKeepTask(ped, true)
            end
            if bind.dict and not IsEntityPlayingAnim(ped, bind.dict, bind.clip or "idle", 3) then
                playBind(ped, bind)
            end
            Wait(ped == PlayerPedId() and 0 or 400)
        end
        local state = rootedPeds[ped]
        if not state or state.token ~= token then
            return
        end
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, false)
            ClearPedTasks(ped)
            setThornRoot(ped, false)
        end
        if ped == PlayerPedId() then
            LocalPlayer.state:set("hhThornLocked", false, false)
        end
        dropProps(bushes)
        if effectId then
            RootsFx.stop(effectId, "release")
        end
        rootedPeds[ped] = nil
    end)
end

local function fillCircle(hash, x, y, z, radius, count)
    local list = {}
    local placed = {}
    local tries = 0
    local minDist = 1.05
    while #list < count and tries < count * 12 do
        tries = tries + 1
        local ang = math.random() * math.pi * 2.0
        local dist = math.sqrt(math.random()) * radius * 0.92
        local px = x + math.cos(ang) * dist
        local py = y + math.sin(ang) * dist
        local ok = true
        for i = 1, #placed do
            local dx = placed[i].x - px
            local dy = placed[i].y - py
            if (dx * dx) + (dy * dy) < (minDist * minDist) then
                ok = false
                break
            end
        end
        if ok then
            local obj = growBush(hash, px, py, z)
            if obj ~= 0 then
                list[#list + 1] = obj
                placed[#placed + 1] = { x = px, y = py }
            end
        end
    end
    return list
end

RegisterNetEvent("hh_magic:client:thornsApply", function(data)
    if type(data) ~= "table" then
        return
    end
    local point = vector3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    local cfg = {
        radius = data.radius or 4.0,
        durationMs = data.durationMs or 30000,
        maxHeightDiff = data.maxHeightDiff or 2.5,
        bind = (Config.Spells and Config.Spells.spark and Config.Spells.spark.thorns and Config.Spells.spark.thorns.bind) or {},
    }

    local castId = data.id or GetGameTimer()
    local me = PlayerPedId()
    local rooted = {}
    local visuals = {}

    if canBind(me, point, cfg) then
        rooted[#rooted + 1] = me
        visuals[#visuals + 1] = me
    end

    local handle, ped = FindFirstPed()
    local success = true
    if handle and handle ~= -1 then
        repeat
            if ped and ped ~= me and canBind(ped, point, cfg) then
                visuals[#visuals + 1] = ped
                if owns(ped) then
                    rooted[#rooted + 1] = ped
                end
            end
            success, ped = FindNextPed(handle)
        until not success
        EndFindPed(handle)
    end

    -- Riders get the bush only after the horse has thrown them.
    for i = 1, #visuals do
        local vped = visuals[i]
        if not rootedPeds[vped] then
            if IsPedOnMount(vped) then
                CreateThread(function()
                    waitLanded(vped)
                    if DoesEntityExist(vped) and not IsPedOnMount(vped) and not rootedPeds[vped] then
                        startRootsVisual(vped, castId, cfg.durationMs)
                    end
                end)
            else
                startRootsVisual(vped, castId, cfg.durationMs)
            end
        end
    end

    -- Gameplay stun only on owned peds / local player.
    -- A rider is thrown first; the bush is placed under them, not under the horse.
    for i = 1, #rooted do
        local target = rooted[i]
        local wasMounted = IsPedOnMount(target)
        CreateThread(function()
            throwFromHorse(target)
            if wasMounted then
                waitLanded(target)
            elseif IsPedRagdoll(target) then
                local land = GetGameTimer() + 1200
                while DoesEntityExist(target) and IsPedRagdoll(target) and GetGameTimer() < land do
                    Wait(50)
                end
            end
            if DoesEntityExist(target) and not IsPedDeadOrDying(target, true) and not IsPedOnMount(target) then
                holdRoot(target, cfg, {}, castId, wasMounted)
            end
        end)
    end

    -- Auto-stop visuals for non-owned targets after duration
    CreateThread(function()
        Wait(cfg.durationMs or 30000)
        for i = 1, #visuals do
            local vped = visuals[i]
            if not rootedPeds[vped] then
                local netId = pedNetId(vped)
                local effectId = ("%s_%s"):format(tostring(castId), tostring(netId ~= 0 and netId or vped))
                if RootsFx and RootsFx.stop then
                    RootsFx.stop(effectId, "expire")
                end
            end
        end
    end)
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    aiming = false
    clearAllBushPatches()
    RootsFx.clearAll()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    for rooted, state in pairs(rootedPeds) do
        if state.effectId then
            RootsFx.stop(state.effectId, "resource_stop")
        end
        if DoesEntityExist(rooted) then
            FreezeEntityPosition(rooted, false)
            ClearPedTasks(rooted)
        end
        if state.bushes then
            deleteBushList(state.bushes)
        end
    end
    rootedPeds = {}
end)
