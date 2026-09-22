Raven = Raven or {}

local MODEL = 0xDDB5012B
local FLY_TASK = 0xD6CFC2D59DA72042
local CAPSULE = 0x28579D1B8F8AAC80
local KEY_CAST = `INPUT_ATTACK`
local KEY_CANCEL = `INPUT_AIM`
local KEY_LEFT = 0x7065027D
local KEY_RIGHT = 0xB4E465B4
local KEY_UP = 0x8FD015D8
local KEY_DOWN = 0xD27782E3
local LOOK_LR = 0xA987235F
local LOOK_UD = 0xD2047988
local KEY_RETURN = 0xB2F377E8
local SHAPE_FLAGS = 1

local session = {
    state = "idle",
    id = nil,
}

local aiming = false

local function notify(text, ms)
    TriggerEvent("vorp:TipRight", text, ms or 2500)
end

local function cfgOf(spell)
    return (spell and spell.raven) or {}
end

local function sameSession(id)
    return session.id ~= nil and id == session.id and session.state ~= "idle" and session.state ~= "returning"
end

local function groundZ(x, y, refZ)
    RequestCollisionAtCoord(x, y, refZ)
    local found, gz = GetGroundZFor_3dCoord(x, y, refZ + 2.0, false)
    if not found then
        found, gz = GetGroundZFor_3dCoord(x, y, refZ + 30.0, false)
    end
    if not found then
        return nil
    end
    return gz
end

local function dist3(a, b)
    return #(a - b)
end

local function shapeHit(from, to, ignore, radius)
    local handle
    if radius and radius > 0 then
        handle = Citizen.InvokeNative(CAPSULE, from.x, from.y, from.z, to.x, to.y, to.z, radius, SHAPE_FLAGS, ignore or 0, 7)
    else
        handle = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, SHAPE_FLAGS, ignore or 0, 0)
    end
    local deadline = GetGameTimer() + 40
    local state, hit = 1, 0
    while state == 1 and GetGameTimer() < deadline do
        Wait(0)
        state, hit = GetShapeTestResult(handle)
    end
    if state ~= 2 then
        return false
    end
    return hit == 1 or hit == true
end

local function loadModel(hash)
    if not IsModelValid(hash) then
        return false
    end
    RequestModel(hash, true)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        if session.state == "idle" or session.state == "returning" then
            return false
        end
        Wait(0)
    end
    return HasModelLoaded(hash)
end

local function loadPtfx(dict)
    RequestNamedPtfxAsset(dict)
    local deadline = GetGameTimer() + 600
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasNamedPtfxAssetLoaded(dict)
end

local function smokeBurst(x, y, z)
    if loadPtfx("scr_odd_fellows") then
        UseParticleFxAsset("scr_odd_fellows")
        StartParticleFxNonLoopedAtCoord("scr_river5_magician_smoke", x, y, z, 0.0, 0.0, 0.0, 0.85, false, false, false)
    end
end

local function canBegin(spell)
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
        return false, spell.failBird
    end
    if LocalPlayer.state.isDead or LocalPlayer.state.hhThornLocked then
        return false, spell.failBusy
    end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then
        return false, spell.failMounted
    end
    if IsEntityInWater(ped) then
        return false, spell.failPlace
    end
    if session.state ~= "idle" then
        return false, spell.failBusy
    end
    return true
end

local function findSpawn(body, cfg)
    local spots = {
        GetOffsetFromEntityInWorldCoords(body, 0.0, cfg.spawnAhead or 2.5, 0.0),
        GetOffsetFromEntityInWorldCoords(body, 0.9, cfg.spawnAhead or 2.5, 0.0),
        GetOffsetFromEntityInWorldCoords(body, -0.9, cfg.spawnAhead or 2.5, 0.0),
    }
    local origin = GetEntityCoords(body)
    for i = 1, #spots do
        local spot = spots[i]
        local gz = groundZ(spot.x, spot.y, origin.z)
        if gz and math.abs(gz - origin.z) < 4.0 then
            local spawn = vector3(spot.x, spot.y, gz + 0.15)
            local blocked = shapeHit(origin + vector3(0.0, 0.0, 0.6), spawn + vector3(0.0, 0.0, 0.4), body, 0.35)
            local lift = spawn + vector3(0.0, 0.0, 4.0)
            local ceiling = shapeHit(spawn + vector3(0.0, 0.0, 0.4), lift, body, 0.45)
            if not blocked and not ceiling then
                return spawn
            end
        end
    end
    return nil
end

local function giveFlightTarget(bird, destination, travel)
    if not bird or bird == 0 or not DoesEntityExist(bird) then
        return false
    end
    if not NetworkHasControlOfEntity(bird) then
        return false
    end
    Citizen.InvokeNative(FLY_TASK, bird, travel or 1.0, destination.x, destination.y, destination.z, true, true)
    return true
end

local function hud(show, seconds, warn)
    SendNUIMessage({
        action = "ravenHud",
        show = show and true or false,
        seconds = seconds or 0,
        warn = warn or 0,
    })
end

local function suppressMelee()
    CreateThread(function()
        for _ = 1, 2 do
            DisableControlAction(0, KEY_RETURN, true)
            DisableControlAction(0, `INPUT_ATTACK`, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        end
    end)
end

local function cleanupLocal(reason)
    local cam = session.cam
    local bird = session.bird
    local body = session.body
    local ownsLock = session.ownsLock
    local didFreeze = session.didFreeze
    local priorLock = session.priorLock
    session.cam = nil
    session.bird = 0
    session.probe = nil
    pcall(function()
        RenderScriptCams(false, false, 0, true, true, 0)
        if cam and cam ~= 0 then
            DestroyCam(cam, false)
        end
        ClearFocus()
    end)
    hud(false, 0, 0)
    if body and body ~= 0 and DoesEntityExist(body) then
        if didFreeze and not priorLock then
            FreezeEntityPosition(body, false)
        end
    end
    if ownsLock and not priorLock then
        LocalPlayer.state:set("hhThornLocked", false, false)
    end
    if bird and bird ~= 0 and DoesEntityExist(bird) then
        local pos = GetEntityCoords(bird)
        if reason ~= "resource_stop" then
            smokeBurst(pos.x, pos.y, pos.z + 0.3)
        end
        SetEntityAsMissionEntity(bird, true, true)
        DeletePed(bird)
        if DoesEntityExist(bird) then
            DeleteEntity(bird)
        end
    end
    if reason == "cancel" then
        suppressMelee()
    end
end

local function endSession(reason)
    if session.state == "idle" or session.state == "returning" then
        return
    end
    local id = session.id
    session.state = "returning"
    cleanupLocal(reason)
    session.state = "idle"
    session.id = nil
    session.ownsLock = false
    session.didFreeze = false
    if id then
        TriggerServerEvent("hh_magic:raven:stop", id, reason or "end")
    end
    local spell = session.spell
    session.spell = nil
    session.spellId = nil
    if reason == "cancel" then
        notify((spell and spell.notifyReturn) or "Вы снова в своём теле.", 2500)
    elseif reason == "time" or reason == "range" or reason == "dead" or reason == "hurt" or reason == "stuck" or reason == "control" then
        notify((spell and spell.notifyLost) or "Ворон рассеялся.", 2500)
    end
end

local function lockBody(body)
    session.priorLock = LocalPlayer.state.hhThornLocked == true
    session.ownsLock = not session.priorLock
    if session.ownsLock then
        LocalPlayer.state:set("hhThornLocked", true, false)
    end
    FreezeEntityPosition(body, true)
    session.didFreeze = true
    session.health = GetEntityHealth(body)
end

local function blockBody()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    DisablePlayerFiring(PlayerId(), true)
    local voice = { `INPUT_PUSH_TO_TALK`, 0xF1301666, 0x05CA7C52 }
    for i = 1, #voice do
        EnableControlAction(0, voice[i], true)
    end
    EnableControlAction(0, `INPUT_FRONTEND_PAUSE`, true)
    EnableControlAction(0, `INPUT_FRONTEND_PAUSE_ALTERNATE`, true)
end

local function smooth(current, target, dt)
    local k = 1.0 - math.exp(-8.0 * dt)
    return current + (target - current) * k
end

local function lerpAngle(fromAngle, toAngle, t)
    local delta = (toAngle - fromAngle) % 360.0
    if delta > 180.0 then
        delta = delta - 360.0
    elseif delta < -180.0 then
        delta = delta + 360.0
    end
    return fromAngle + delta * t
end

local function pressed(control)
    return IsDisabledControlPressed(0, control) or IsDisabledControlPressed(1, control)
end

local function lookNormal(control)
    local a = GetDisabledControlNormal(0, control)
    local b = GetDisabledControlNormal(1, control)
    if math.abs(b) > math.abs(a) then
        return b
    end
    return a
end

local function beginCamera(bird, cfg)
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local off = cfg.camOffset or { x = 0.0, y = 0.30, z = 0.10 }
    AttachCamToEntity(cam, bird, off.x or 0.0, off.y or 0.30, off.z or 0.10, true)
    SetCamFov(cam, cfg.fov or 75.0)
    pcall(function()
        SetCamNearClip(cam, 0.05)
    end)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(bird), 2)
    SetCamActive(cam, true)
    SetFocusEntity(bird)
    RenderScriptCams(true, true, 450, true, true, 0)
    session.cam = cam
    session.filteredHeading = GetEntityHeading(bird)
    session.lookYaw = 0.0
    session.lookPitch = 0.0
    session.steer = 0.0
    session.climb = 0.0
    session.returnArmed = not pressed(KEY_RETURN)
    session.warned = false
    session.nextFlight = 0
    session.stuckAt = GetGameTimer()
    session.lastPos = GetEntityCoords(bird)
    hud(true, math.floor((cfg.lifeMs or 60000) / 1000), 0)
end

local function clampGoal(origin, goal, cfg)
    local maxZ = origin.z + (cfg.maxHeight or 30.0)
    if goal.z > maxZ then
        goal = vector3(goal.x, goal.y, maxZ)
    end
    local gz = groundZ(goal.x, goal.y, goal.z)
    if gz and goal.z < gz + (cfg.minClearance or 1.5) then
        goal = vector3(goal.x, goal.y, gz + (cfg.minClearance or 1.5))
    end
    local offset = goal - origin
    local dist = #offset
    local limit = (cfg.maxDistance or 80.0) - 1.5
    if dist > limit and dist > 0.01 then
        goal = origin + offset * (limit / dist)
    end
    return goal
end

local function steerGoal(bird, cfg)
    local goal = GetOffsetFromEntityInWorldCoords(bird, session.steer * 5.0, cfg.leadDistance or 10.0, session.climb * 4.0)
    goal = clampGoal(session.origin, goal, cfg)
    if shapeHit(GetEntityCoords(bird), goal, bird, 0.55) then
        local lifted = vector3(goal.x, goal.y, goal.z + 3.0)
        if not shapeHit(GetEntityCoords(bird), lifted, bird, 0.45) then
            goal = lifted
        end
    end
    return goal
end

local function watchBody()
    local body = session.body
    if not body or body == 0 or not DoesEntityExist(body) or IsEntityDead(body) then
        endSession("hurt")
        return false
    end
    local hp = GetEntityHealth(body)
    if session.health and hp < session.health then
        endSession("hurt")
        return false
    end
    session.health = hp
    return true
end

local function controlLoop(cfg)
    local bird = session.bird
    local last = GetGameTimer()
    local endsAt = GetGameTimer() + (cfg.lifeMs or 60000)
    while session.state == "active" and session.id do
        local now = GetGameTimer()
        local dt = math.max(0.001, (now - last) / 1000.0)
        last = now
        Wait(0)
        if session.state ~= "active" then
            return
        end
        blockBody()
        if IsNuiFocused and IsNuiFocused() then
            endSession("cancel")
            return
        end
        if not watchBody() then
            return
        end
        if not DoesEntityExist(bird) or IsEntityDead(bird) or GetEntityHealth(bird) <= 0 then
            endSession("dead")
            return
        end
        if now >= endsAt then
            endSession("time")
            return
        end
        if not session.returnArmed then
            if not pressed(KEY_RETURN) then
                session.returnArmed = true
            end
        elseif IsDisabledControlJustReleased(0, KEY_RETURN) then
            endSession("cancel")
            return
        end

        local left = pressed(KEY_LEFT)
        local right = pressed(KEY_RIGHT)
        local up = pressed(KEY_UP)
        local down = pressed(KEY_DOWN)
        local targetSteer = (right and 1 or 0) - (left and 1 or 0)
        local targetClimb = (up and 1 or 0) - (down and 1 or 0)
        session.steer = smooth(session.steer, targetSteer, dt)
        session.climb = smooth(session.climb, targetClimb, dt)
        session.lookYaw = math.max(-55.0, math.min(55.0, session.lookYaw - lookNormal(LOOK_LR) * 8.0))
        session.lookPitch = math.max(-60.0, math.min(60.0, session.lookPitch - lookNormal(LOOK_UD) * 6.0))

        local heading = GetEntityHeading(bird)
        session.filteredHeading = lerpAngle(session.filteredHeading or heading, heading, 1.0 - math.exp(-10.0 * dt))
        if session.cam then
            local roll = session.steer * 4.0
            SetCamRot(session.cam, session.lookPitch, roll, session.filteredHeading + session.lookYaw, 2)
        end

        local pos = GetEntityCoords(bird)
        local away = dist3(pos, session.origin)
        local warn = 0
        if away >= (cfg.warnDistance or 70.0) then
            warn = math.min(1.0, (away - (cfg.warnDistance or 70.0)) / 10.0)
            if not session.warned then
                session.warned = true
                notify((session.spell and session.spell.notifyWeak) or "Связь слабеет.", 2000)
            end
        else
            session.warned = false
        end
        if away > (cfg.maxDistance or 80.0) or pos.z > session.origin.z + (cfg.maxHeight or 30.0) then
            endSession("range")
            return
        end
        local gz = groundZ(pos.x, pos.y, pos.z)
        if gz and pos.z < gz + 0.4 then
            endSession("stuck")
            return
        end

        if dist3(pos, session.lastPos or pos) > 0.45 then
            session.lastPos = pos
            session.stuckAt = now
        elseif now - (session.stuckAt or now) > 1000 then
            endSession("stuck")
            return
        end

        hud(true, math.max(0, math.ceil((endsAt - now) / 1000)), warn)

        if now >= (session.nextFlight or 0) then
            session.nextFlight = now + (cfg.flightEveryMs or 200)
            if not NetworkHasControlOfEntity(bird) then
                NetworkRequestControlOfEntity(bird)
                session.lostControl = session.lostControl or now
                if now - session.lostControl > 1000 then
                    endSession("control")
                    return
                end
            else
                session.lostControl = nil
                giveFlightTarget(bird, steerGoal(bird, cfg), cfg.travelMbr or 1.0)
            end
        end
    end
end

local function runTakeoff(cfg)
    local bird = session.bird
    local start = GetEntityCoords(bird)
    Wait(300)
    if session.state ~= "takeoff" then
        return
    end
    local up = GetOffsetFromEntityInWorldCoords(bird, 0.0, 8.0, 4.0)
    giveFlightTarget(bird, up, cfg.travelMbr or 1.0)
    local deadline = GetGameTimer() + (cfg.takeoffTimeoutMs or 4000)
    while GetGameTimer() < deadline do
        Wait(100)
        if session.state ~= "takeoff" then
            return
        end
        if not watchBody() then
            return
        end
        if not DoesEntityExist(bird) or IsEntityDead(bird) then
            endSession("dead")
            return
        end
        if NetworkHasControlOfEntity(bird) then
            local pos = GetEntityCoords(bird)
            local gz = groundZ(pos.x, pos.y, pos.z) or start.z
            if (pos.z - gz) > 1.0 and dist3(pos, start) > 0.8 then
                TriggerServerEvent("hh_magic:raven:ready", session.id)
                return
            end
        else
            NetworkRequestControlOfEntity(bird)
        end
    end
    notify((session.spell and session.spell.failTakeoff) or "Ворон не смог подняться.", 2500)
    endSession("takeoff")
end

local function createBird(body, spawn)
    local hash = IsModelValid(MODEL) and MODEL or joaat("a_c_raven_01")
    local bird = CreatePed(hash, spawn.x, spawn.y, spawn.z, GetEntityHeading(body), true, true, false, false)
    if not bird or bird == 0 or not DoesEntityExist(bird) then
        return 0
    end
    SetEntityAsMissionEntity(bird, true, true)
    Citizen.InvokeNative(0x283978A15512B2FE, bird, true)
    SetBlockingOfNonTemporaryEvents(bird, true)
    SetPedKeepTask(bird, true)
    SetEntityCollision(bird, true, true)
    SetEntityInvincible(bird, false)
    SetEntityCanBeDamaged(bird, true)
    pcall(function()
        local net = NetworkGetNetworkIdFromEntity(bird)
        if net and net ~= 0 then
            SetNetworkIdExistsOnAllMachines(net, true)
        end
    end)
    smokeBurst(spawn.x, spawn.y, spawn.z + 0.4)
    return bird
end

RegisterNetEvent("hh_magic:raven:approved", function(payload)
    if type(payload) ~= "table" or session.state ~= "preparing" then
        return
    end
    session.id = payload.id
    session.spellId = payload.spellId or session.spellId
    CreateThread(function()
        local id = session.id
        local spell = session.spell
        local cfg = cfgOf(spell)
        if not loadModel(IsModelValid(MODEL) and MODEL or joaat("a_c_raven_01")) then
            if session.id == id then
                notify((spell and spell.failBird) or "Ворон не откликнулся.", 2500)
                endSession("model")
            end
            SetModelAsNoLongerNeeded(MODEL)
            return
        end
        if session.id ~= id or session.state ~= "preparing" then
            SetModelAsNoLongerNeeded(MODEL)
            return
        end
        local body = session.body
        local spawn = findSpawn(body, cfg)
        if not spawn then
            notify((spell and spell.failPlace) or "Ворону негде взлететь.", 2500)
            endSession("place")
            SetModelAsNoLongerNeeded(MODEL)
            return
        end
        session.state = "casting"
        if MagicCards and MagicCards.finishRitual then
            MagicCards.finishRitual()
        end
        local ritual = (spell and spell.ritual) or {}
        local waitMs = (ritual.seeMs or 500) + (ritual.burnMs or 1500) + 250
        local untilCast = GetGameTimer() + waitMs
        while GetGameTimer() < untilCast do
            Wait(0)
            if session.id ~= id or session.state ~= "casting" then
                SetModelAsNoLongerNeeded(MODEL)
                return
            end
        end
        if not DoesEntityExist(body) or IsEntityDead(body) then
            endSession("hurt")
            SetModelAsNoLongerNeeded(MODEL)
            return
        end
        local bird = createBird(body, spawn)
        SetModelAsNoLongerNeeded(MODEL)
        if bird == 0 then
            notify((spell and spell.failBird) or "Ворон не откликнулся.", 2500)
            endSession("spawn")
            return
        end
        session.bird = bird
        session.spawn = spawn
        local net = NetworkGetNetworkIdFromEntity(bird)
        TriggerServerEvent("hh_magic:raven:spawned", id, net, spawn.x, spawn.y, spawn.z)
    end)
end)

RegisterNetEvent("hh_magic:raven:registered", function(id)
    if not sameSession(id) or session.state ~= "casting" then
        return
    end
    session.state = "takeoff"
    CreateThread(function()
        runTakeoff(cfgOf(session.spell))
    end)
end)

RegisterNetEvent("hh_magic:raven:active", function(id, lifeMs)
    if not sameSession(id) or session.state ~= "takeoff" then
        return
    end
    local cfg = cfgOf(session.spell)
    if lifeMs then
        cfg.lifeMs = lifeMs
    end
    session.state = "active"
    session.health = GetEntityHealth(session.body)
    beginCamera(session.bird, cfg)
    CreateThread(function()
        controlLoop(cfg)
    end)
end)

RegisterNetEvent("hh_magic:raven:stop", function(id, reason)
    if session.id ~= id or session.state == "idle" or session.state == "returning" then
        return
    end
    session.id = id
    endSession(reason or "server")
end)

RegisterNetEvent("hh_magic:raven:denied", function(text)
    if session.state ~= "preparing" and session.state ~= "casting" and session.state ~= "takeoff" then
        return
    end
    local spell = session.spell
    session.state = "returning"
    cleanupLocal("denied")
    session.state = "idle"
    session.id = nil
    session.ownsLock = false
    session.didFreeze = false
    session.spell = nil
    notify(text or (spell and spell.failBusy) or "Сейчас нельзя.", 2500)
    if MagicCards and MagicCards.putAway then
        MagicCards.putAway(true)
    end
end)

function Raven.start(spellId, spell)
    if aiming or session.state ~= "idle" then
        notify(spell.failBusy or "Вы уже творите заклинание.", 2500)
        return
    end
    local ok, why = canBegin(spell)
    if not ok then
        notify(why or spell.failBusy, 2500)
        TriggerServerEvent("hh_magic:server:aimCancel", spellId)
        return
    end
    aiming = true
    if MagicCards and MagicCards.startHold then
        MagicCards.startHold(spellId)
    end
    CreateThread(function()
        local keepAt = 0
        while aiming and session.state == "idle" do
            Wait(0)
            DisableControlAction(0, KEY_CAST, true)
            DisableControlAction(0, KEY_CANCEL, true)
            DisablePlayerFiring(PlayerId(), true)
            local now = GetGameTimer()
            if MagicCards and MagicCards.keepHold and now >= keepAt then
                MagicCards.keepHold()
                keepAt = now + 400
            end
            if IsDisabledControlJustPressed(0, KEY_CAST) then
                aiming = false
                local allowed, reason = canBegin(spell)
                if not allowed then
                    notify(reason or spell.failBusy, 2500)
                    if MagicCards and MagicCards.putAway then
                        MagicCards.putAway(false)
                    end
                    TriggerServerEvent("hh_magic:server:aimCancel", spellId)
                    return
                end
                session.state = "preparing"
                session.spellId = spellId
                session.spell = spell
                session.body = PlayerPedId()
                session.origin = GetEntityCoords(session.body)
                lockBody(session.body)
                TriggerServerEvent("hh_magic:raven:request", spellId)
                return
            elseif IsDisabledControlJustPressed(0, KEY_CANCEL)
                or IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`) then
                aiming = false
                if MagicCards and MagicCards.putAway then
                    MagicCards.putAway(false)
                end
                TriggerServerEvent("hh_magic:server:aimCancel", spellId)
                return
            end
        end
    end)
end

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    aiming = false
    if session.state ~= "idle" then
        local id = session.id
        session.state = "returning"
        cleanupLocal("resource_stop")
        session.state = "idle"
        session.id = nil
        if id then
            TriggerServerEvent("hh_magic:raven:stop", id, "resource_stop")
        end
    end
end)
