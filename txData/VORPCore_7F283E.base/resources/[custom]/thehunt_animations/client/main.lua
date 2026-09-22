-- =================================================================
-- HUNT: Hard RP — Animations Client Controller
-- Obsidian Dark Theme | Hotkeys F3 (Open) & Z (Cancel)
-- MMB Camera Rotation, Full Whitelist & RMB Ghost Ped Animation Preview
-- =================================================================

local isUIOpen = false
local isInputFocused = false
local isWindowFocused = true
local isMMBPressed = false
local isRadialOpen = false
local isHoldingX = false
local xHoldTimer = 0
local pointingRequest = 0
local isHoldingPoint = false
local isPointingActive = false
local pointingPed = nil
local pointingProfile = nil
local pointingDict = nil
local pointingBody = nil
local pointingFlag = nil
local pointingDirection = nil
local pointingIkState = false
local pointingIkRuntime = { target = nil, failed = false }
local remotePointing = {}
local retiringPointingTargets = {}
local pointingSyncNext = 0
local pointingReapplyAfter = 0
local pointingTurnNext = 0
local pointingClipNext = 0
local currentAnimation = nil
local currentBodyMode = 'full'
local favoritesList = {}
local pinnedList = {}
local protectedAction = nil
local thermalReaction = nil

local function StopThermalReaction()
    if not thermalReaction then return end
    StopAnimTask(thermalReaction.ped, thermalReaction.anim.Dict, thermalReaction.anim.Body, 1.0)
    RemoveAnimDict(thermalReaction.anim.Dict)
    thermalReaction = nil
end

local function IsProtectedActionActive()
    if not protectedAction then return false end

    if protectedAction.expiresAt and GetGameTimer() >= protectedAction.expiresAt then
        protectedAction = nil
        return false
    end

    return true
end

-- Item/world actions can temporarily make the animation non-cancellable.
-- Keep this separate from currentAnimation: those actions are owned by their
-- resource, while Z is owned by this resource.
RegisterNetEvent('thehunt_animations:client:setProtectedAction', function(enabled, actionName, durationMs)
    if enabled then
        StopThermalReaction()
        local timeout = tonumber(durationMs)
        protectedAction = {
            name = tostring(actionName or 'action'),
            expiresAt = timeout and (GetGameTimer() + math.max(0, timeout)) or nil
        }
    elseif not actionName or not protectedAction or protectedAction.name == tostring(actionName) then
        protectedAction = nil
    end
end)

-- Загружает закреплённые анимации для текущего персонажа. Список хранится
-- отдельно по charIdentifier, поэтому его нужно обновлять после каждой смены.
local function RequestPinnedAnimations()
    TriggerServerEvent('thehunt_animations:server:requestPinned')
end

-- thehunt_character не перезапускает этот ресурс при смене персонажа.
-- Сбрасываем старые слоты сразу и запрашиваем список уже нового персонажа.
RegisterNetEvent('thehunt_character:client:ApplyAndSpawn', function()
    pinnedList = {}
    SendNUIMessage({ type = 'SyncPinned', pinned = pinnedList })
    RequestPinnedAnimations()
end)

-- Переменные для режима предпросмотра (Ghost Ped Preview)
local previewPed = nil
local previewAnchor = nil
local previewLabel = nil

-- =================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ВЕКТОРОВ И ПРОИГРЫВАНИЯ
-- =================================================================

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- Arm IK is layered over one upper-body pointing clip. pcall catches Lua
-- invocation errors only; a successful call does not validate a ped skeleton.
local POINTING_IK_NATIVE = 0xC32779C16FCEECD9

local function DeletePointingIKTarget(runtime, fade)
    if not runtime or not runtime.target then return end
    if fade and DoesEntityExist(runtime.target) then
        local ik = Config.PointingAnimation and Config.PointingAnimation.ik
        retiringPointingTargets[#retiringPointingTargets + 1] = {
            target = runtime.target,
            expires = GetGameTimer() + ((ik and tonumber(ik.blendOut)) or 450) + 100
        }
        runtime.target = nil
        return
    end
    if DoesEntityExist(runtime.target) then
        SetEntityAsMissionEntity(runtime.target, true, true)
        DeleteEntity(runtime.target)
    end
    runtime.target = nil
end

local function EnsurePointingIKTarget(runtime, ped, ikCfg)
    if runtime.target and DoesEntityExist(runtime.target) then return true end
    runtime.loadStarted = runtime.loadStarted or GetGameTimer()
    if GetGameTimer() - runtime.loadStarted > 2500 then
        runtime.failed = true
        if runtime == pointingIkRuntime then pointingIkState = false end
        return false
    end
    local model = GetHashKey(ikCfg.targetModel or 'p_cs_shotglass01x')
    if not HasModelLoaded(model) then
        RequestModel(model)
        return false
    end

    local origin = GetEntityCoords(ped)
    local target = CreateObject(model, origin.x, origin.y, origin.z, false, false, false)
    if not target or target == 0 or not DoesEntityExist(target) then return false end

    SetEntityAsMissionEntity(target, true, true)
    SetEntityAlpha(target, 0, false)
    SetEntityVisible(target, false, false)
    SetEntityCollision(target, false, false)
    FreezeEntityPosition(target, true)
    SetModelAsNoLongerNeeded(model)
    runtime.target = target
    return true
end

local function GetCameraWorldDirection()
    local direction = RotationToDirection(GetGameplayCamRot(2))
    return { x = direction.x, y = direction.y, z = direction.z }
end

-- Entity origin is not the shoulder (and not necessarily the feet).
-- Resolve the actual skeleton; never substitute a guessed world height.
local function GetPointingArm(ped, runtime)
    if not runtime.arm then
        local shoulder = GetEntityBoneIndexByName(ped, 'SKEL_R_UpperArm')
        local elbow = GetEntityBoneIndexByName(ped, 'SKEL_R_Forearm')
        local hand = GetEntityBoneIndexByName(ped, 'SKEL_R_Hand')
        if not shoulder or shoulder < 0 or not elbow or elbow < 0 or not hand or hand < 0 then
            return nil
        end
        local a = GetWorldPositionOfEntityBone(ped, shoulder)
        local b = GetWorldPositionOfEntityBone(ped, elbow)
        local c = GetWorldPositionOfEntityBone(ped, hand)
        local function distance(p, q)
            return math.sqrt((p.x-q.x)^2 + (p.y-q.y)^2 + (p.z-q.z)^2)
        end
        local upper, lower = distance(a,b), distance(b,c)
        -- Missing/uninitialised skeleton data must not drive the solver.
        if not (upper > 0.1 and upper < 0.8 and lower > 0.1 and lower < 0.8) then return nil end
        runtime.arm = { shoulder = shoulder, reach = (upper + lower) * 0.92 }
        runtime.entry = { x = c.x-a.x, y = c.y-a.y, z = c.z-a.z,
            heading = GetEntityHeading(ped), elapsed = 0.0 }
    end
    return GetWorldPositionOfEntityBone(ped, runtime.arm.shoulder), runtime.arm.reach
end

local function ApplyPointingIK(ped, ikCfg, direction, runtime)
    if not ikCfg or ikCfg.enabled == false then return false end
    runtime = runtime or pointingIkRuntime
    if runtime.failed or not DoesEntityExist(ped) or not IsPedHuman(ped) then return false end
    if runtime.ped ~= ped then
        DeletePointingIKTarget(runtime)
        runtime.ped = ped
        runtime.shoulderYaw, runtime.pitch, runtime.loadStarted, runtime.arm = nil, nil, nil, nil
    end

    if SetPedCanArmIk then
        pcall(SetPedCanArmIk, ped, true)
    end

    direction = direction or GetCameraWorldDirection()
    if type(direction) ~= 'table' or not tonumber(direction.x) or not tonumber(direction.y) or not tonumber(direction.z) then
        return false
    end
    local origin, reach = GetPointingArm(ped, runtime)
    if not origin then
        runtime.failed = true
        if runtime == pointingIkRuntime then pointingIkState = false end
        return false
    end
    if not EnsurePointingIKTarget(runtime, ped, ikCfg) then return nil end

    -- Smooth within a convex shoulder envelope. Independent yaw/pitch clamps
    -- previously allowed the most extreme values simultaneously, and storing
    -- unclamped world yaw made body turns snap the arm between the limits.
    local heading = GetEntityHeading(ped)
    local dt = math.max(0.0, math.min(GetFrameTime(), 0.05))
    local pitch = math.deg(math.asin(math.max(-1.0, math.min(1.0, direction.z))))
    local yaw = (math.deg(math.atan(-direction.x, direction.y)) - heading + 180.0) % 360.0 - 180.0
    if direction.x * direction.x + direction.y * direction.y < 0.001 then
        yaw = runtime.shoulderYaw or 0.0
    end
    -- Positive relative yaw crosses the right arm over the chest.
    local cross = math.max(10.0, tonumber(ikCfg.crossBodyYaw) or 35.0)
    local outward = math.max(10.0, tonumber(ikCfg.maxYaw) or 60.0)
    local up = math.max(10.0, tonumber(ikCfg.maxPitchUp) or 55.0)
    local down = math.max(10.0, tonumber(ikCfg.maxPitchDown) or 50.0)
    yaw = math.max(-outward, math.min(cross, yaw))
    pitch = math.max(-down, math.min(up, pitch))
    local function envelope(y, p)
        local extent = math.sqrt((y / (y >= 0 and cross or outward))^2
            + (p / (p >= 0 and up or down))^2)
        if extent > 1.0 then return y / extent, p / extent end
        return y, p
    end
    yaw, pitch = envelope(yaw, pitch)
    local previousYaw, previousPitch = runtime.shoulderYaw or 0.0, runtime.pitch or 0.0
    local alpha = 1.0 - math.exp(-dt / math.max(0.01, tonumber(ikCfg.smoothingSeconds) or 0.12))
    local dy, dp = (yaw - previousYaw) * alpha, (pitch - previousPitch) * alpha
    local step = math.sqrt(dy * dy + dp * dp)
    local maxStep = math.max(1.0, tonumber(ikCfg.maxAngularSpeed) or 150.0) * dt
    if step > maxStep then dy, dp = dy * maxStep / step, dp * maxStep / step end
    runtime.shoulderYaw, runtime.pitch = envelope(previousYaw + dy, previousPitch + dp)
    local pitchRad = math.rad(runtime.pitch)
    local yawRad = math.rad(heading + runtime.shoulderYaw)
    -- Increase elbow bend gradually near the boundary; do not stretch the
    -- upper arm while the solver changes its elbow plane at steep angles.
    local effort = math.min(1.0, (runtime.shoulderYaw / (runtime.shoulderYaw >= 0 and cross or outward))^2
        + (runtime.pitch / (runtime.pitch >= 0 and up or down))^2)
    reach = reach * (1.0 - 0.08 * effort)
    local horizontal = math.cos(pitchRad) * reach
    local target = vector3(origin.x - math.sin(yawRad) * horizontal,
        origin.y + math.cos(yawRad) * horizontal,
        origin.z + math.sin(pitchRad) * reach)
    -- Start at the actual current wrist, including when N is pressed again
    -- during release. Ease to the live camera target with zero endpoint speed.
    local entry = runtime.entry
    local duration = math.max(0.01, (tonumber(ikCfg.raiseDuration) or 450) / 1000.0)
    if entry and entry.elapsed < duration then
        local t = math.min(1.0, entry.elapsed / duration)
        local weight = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
        local angle = math.rad(heading - entry.heading)
        local x = origin.x + entry.x * math.cos(angle) - entry.y * math.sin(angle)
        local y = origin.y + entry.x * math.sin(angle) + entry.y * math.cos(angle)
        local z = origin.z + entry.z
        target = vector3(x + (target.x-x)*weight, y + (target.y-y)*weight, z + (target.z-z)*weight)
        entry.elapsed = entry.elapsed + dt
    end
    SetEntityCoordsNoOffset(runtime.target, target.x, target.y, target.z, false, false, false)

    local ok = pcall(function()
        -- Passing a local entity target keeps the solver in the same
        -- coordinate space for the owner and for remote observers.
        Citizen.InvokeNative(
            POINTING_IK_NATIVE,
            ped,
            tonumber(ikCfg.rightArm) or 4,
            runtime.target,
            -1,
            0.0,
            0.0,
            0.0,
            tonumber(ikCfg.targetFlags) or 0,
            tonumber(ikCfg.blendIn) or 120,
            tonumber(ikCfg.blendOut) or 120
        )
    end)

    if not ok then
        runtime.failed = true
        if runtime == pointingIkRuntime then pointingIkState = false end
        return false
    end

    if runtime == pointingIkRuntime then pointingIkState = true end
    return true
end

-- Загрузка словаря анимаций с тайм-аутом
local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = 2500
    local elapsed = 0
    while not HasAnimDictLoaded(dict) and elapsed < timeout do
        Citizen.Wait(50)
        elapsed = elapsed + 50
    end
    return HasAnimDictLoaded(dict)
end

local function StartPointingAnimation()
    local baseCfg = Config.PointingAnimation
    if not baseCfg or baseCfg.enabled == false or isPointingActive then return false end
    if isUIOpen or isRadialOpen or isInputFocused or IsProtectedActionActive() then return false end
    if IsNuiFocused and IsNuiFocused() then return false end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or not IsPedHuman(ped) or IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
        or IsPedRagdoll(ped) or IsPedSwimming(ped) or IsPedClimbing(ped)
        or IsPedUsingAnyScenario(ped) or currentAnimation then
        return false
    end

    DeletePointingIKTarget(pointingIkRuntime)
    pointingIkRuntime = { target = nil, failed = false }

    local mountedState = IsPedOnMount(ped)
    local mounted = mountedState == true or mountedState == 1
    if not mounted and GetMount then
        local mount = GetMount(ped)
        mounted = mount ~= nil and mount ~= 0 and DoesEntityExist(mount)
    end
    local cfg = mounted and type(baseCfg.mounted) == 'table' and baseCfg.mounted or baseCfg

    local request = pointingRequest
    if not LoadAnimDict(cfg.dict) then return false end
    -- Release/menu/death can occur while LoadAnimDict yields.
    if request ~= pointingRequest or not isHoldingPoint or ped ~= PlayerPedId()
        or IsEntityDead(ped) or IsProtectedActionActive()
        or (IsNuiFocused and IsNuiFocused()) then return false end

    -- 31 is the same looping upper-body mode used by the animation menu. The
    -- lower-body locomotion task remains active while pointing.
    local flag = tonumber(cfg.flag) or 31
    local function hasBit(bit)
        return math.floor(flag / bit) % 2 == 1
    end
    if not hasBit(1) then flag = flag + 1 end
    if not hasBit(16) then flag = flag + 16 end

    local dict = cfg.dict
    local body = cfg.body
    local clipFlag = flag
    if cfg == baseCfg and (not baseCfg.ik or baseCfg.ik.enabled == false)
        and type(cfg.vertical) == 'table' and cfg.vertical.enabled ~= false then
        local camDir = RotationToDirection(GetGameplayCamRot(2))
        if camDir.z >= (tonumber(cfg.vertical.threshold) or 0.32) then
            body = cfg.vertical.upBody or body
            pointingDirection = 'up'
        else
            pointingDirection = 'forward'
        end
    else
        pointingDirection = 'forward'
    end

    if dict ~= cfg.dict and not LoadAnimDict(dict) then
        -- A generic male gesture dictionary may be unavailable for a streamed
        -- or custom ped. Keep N usable and fall back to the verified forward
        -- clip instead of cancelling the whole pointing action.
        dict = cfg.dict
        body = cfg.body
        clipFlag = flag
        pointingDirection = 'forward'
    end

    if baseCfg.ik and baseCfg.ik.enabled ~= false then
        pointingIkRuntime.ped = ped
        GetPointingArm(ped, pointingIkRuntime)
    end
    TaskPlayAnim(
        ped,
        dict,
        body,
        tonumber(cfg.blendIn) or 2.0,
        tonumber(cfg.blendOut) or -2.0,
        -1,
        clipFlag,
        0.0,
        false,
        false,
        false,
        0,
        true
    )

    isPointingActive = true
    pointingPed = ped
    pointingProfile = cfg
    pointingDict = dict
    pointingBody = body
    pointingFlag = clipFlag
    if type(baseCfg.ik) == 'table' and baseCfg.ik.enabled ~= false then
        pointingIkState = nil
    else
        pointingIkState = false
    end
    pointingSyncNext = 0
    pointingReapplyAfter = GetGameTimer() + (tonumber(cfg.reapplyDelay) or 700)
    pointingTurnNext = GetGameTimer()
    pointingClipNext = GetGameTimer() + (tonumber(cfg.vertical and cfg.vertical.switchCooldown) or 260)
    TriggerServerEvent('thehunt_animations:server:pointing:start', GetCameraWorldDirection())
    return true
end

local function StopPointingAnimation()
    pointingRequest = pointingRequest + 1
    isHoldingPoint = false
    local wasActive = isPointingActive
    local cfg = pointingProfile or Config.PointingAnimation
    local ped = pointingPed or PlayerPedId()
    local dict = pointingDict or (cfg and cfg.dict)
    local body = pointingBody or (cfg and cfg.body)
    if wasActive then
        TriggerServerEvent('thehunt_animations:server:pointing:stop')
    end
    DeletePointingIKTarget(pointingIkRuntime, true)
    pointingIkRuntime = { target = nil, failed = false }
    isPointingActive = false
    pointingPed = nil
    pointingProfile = nil
    pointingDict = nil
    pointingBody = nil
    pointingFlag = nil
    pointingIkState = false
    pointingDirection = nil
    pointingSyncNext = 0
    pointingReapplyAfter = 0
    pointingTurnNext = 0
    pointingClipNext = 0

    if wasActive and DoesEntityExist(ped) and cfg and dict and body then
        StopAnimTask(ped, dict, body, tonumber(cfg.blendOut) or -2.0)
    end
end

local function NormalizePointingDirection(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z
        or math.abs(x) > 2 or math.abs(y) > 2 or math.abs(z) > 2 then return nil end
    local length = math.sqrt((x * x) + (y * y) + (z * z))
    if length < 0.25 then return nil end
    return { x = x / length, y = y / length, z = z / length }
end

local function CleanupRemotePointing(serverId, fade)
    local state = remotePointing[serverId]
    if not state then return end
    DeletePointingIKTarget(state, fade)
    remotePointing[serverId] = nil
end

RegisterNetEvent('thehunt_animations:client:pointing:start', function(serverId, direction)
    serverId = tonumber(serverId)
    if not serverId or serverId == GetPlayerServerId(PlayerId()) then return end
    local normalized = NormalizePointingDirection(direction)
    if not normalized then return end
    CleanupRemotePointing(serverId)
    remotePointing[serverId] = {
        direction = normalized,
        lastUpdate = GetGameTimer(),
        failed = false,
        target = nil
    }
end)

RegisterNetEvent('thehunt_animations:client:pointing:update', function(serverId, direction)
    serverId = tonumber(serverId)
    if not serverId or serverId == GetPlayerServerId(PlayerId()) then return end
    local normalized = NormalizePointingDirection(direction)
    if not normalized then return end
    local state = remotePointing[serverId]
    if not state then
        state = { target = nil, failed = false }
        remotePointing[serverId] = state
    end
    state.direction = normalized
    state.lastUpdate = GetGameTimer()
end)

RegisterNetEvent('thehunt_animations:client:pointing:stop', function(serverId)
    serverId = tonumber(serverId)
    if serverId then CleanupRemotePointing(serverId, true) end
end)

Citizen.CreateThread(function()
    while true do
        if isPointingActive then
            local cfg = pointingProfile or Config.PointingAnimation
            local ped = PlayerPedId()
            if not cfg or cfg.enabled == false or ped ~= pointingPed
                or IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
                or IsPedRagdoll(ped) or IsPedSwimming(ped) or IsPedClimbing(ped)
                or IsProtectedActionActive() or isUIOpen or isRadialOpen
                or (IsNuiFocused and IsNuiFocused()) then
                StopPointingAnimation()
            else
                local now = GetGameTimer()
                -- Keep the pointing direction aligned with the camera for the
                -- whole hold. While still, use the native turn task. During
                -- locomotion the game's own movement task already turns the
                -- ped; issuing a second heading/turn task here caused jitter.
                if not IsPedOnMount(ped) and now >= pointingTurnNext then
                    local relativeHeading = (GetGameplayCamRot(2).z - GetEntityHeading(ped) + 180.0) % 360.0 - 180.0
                    local currentHeading = GetEntityHeading(ped)
                    local desiredHeading = (currentHeading + relativeHeading) % 360.0
                    local headingDelta = (desiredHeading - currentHeading + 540.0) % 360.0 - 180.0
                    local speed = GetEntitySpeed(ped)
                    if math.abs(headingDelta) > 12.0 then
                        local movingInput = IsControlPressed(0, `INPUT_MOVE_UP_ONLY`)
                            or IsControlPressed(0, `INPUT_MOVE_DOWN_ONLY`)
                            or IsControlPressed(0, `INPUT_MOVE_LEFT_ONLY`)
                            or IsControlPressed(0, `INPUT_MOVE_RIGHT_ONLY`)
                        if speed < 0.05 and not movingInput and TaskTurnPedToFaceCoord then
                            local pos = GetEntityCoords(ped)
                            local angle = math.rad(desiredHeading)
                            local target = vector3(pos.x - math.sin(angle) * 8.0, pos.y + math.cos(angle) * 8.0, pos.z)
                            pcall(TaskTurnPedToFaceCoord, ped, target.x, target.y, target.z, 500)
                        end
                    end
                    pointingTurnNext = now + 550
                end
                if pointingIkState == false and cfg == Config.PointingAnimation and type(cfg.vertical) == 'table'
                    and cfg.vertical.enabled ~= false and now >= pointingClipNext then
                    local camDir = RotationToDirection(GetGameplayCamRot(2))
                    local nextDirection
                    if camDir.z >= (tonumber(cfg.vertical.threshold) or 0.32) then
                        nextDirection = 'up'
                    else
                        nextDirection = 'forward'
                    end
                    if nextDirection ~= pointingDirection then
                        local nextDict = cfg.dict
                        local nextBody = cfg.body
                        local nextFlag = tonumber(cfg.flag) or 31
                        if nextDirection == 'up' then
                            nextBody = cfg.vertical.upBody or nextBody
                        end
                        if nextDict ~= pointingDict and not HasAnimDictLoaded(nextDict) then
                            RequestAnimDict(nextDict)
                        end
                        local switched = false
                        if (nextDict == pointingDict or HasAnimDictLoaded(nextDict)) and (nextDict ~= pointingDict or nextBody ~= pointingBody or nextFlag ~= pointingFlag) then
                            TaskPlayAnim(ped, nextDict, nextBody, tonumber(cfg.blendIn) or 2.0, tonumber(cfg.blendOut) or -2.0, -1, nextFlag, 0.0, false, false, false, 0, true)
                            pointingDict = nextDict
                            pointingBody = nextBody
                            pointingFlag = nextFlag
                            pointingReapplyAfter = now + (tonumber(cfg.reapplyDelay) or 700)
                            switched = true
                        end
                        if switched then pointingDirection = nextDirection end
                    end
                    pointingClipNext = now + (tonumber(cfg.vertical.switchCooldown) or 260)
                end
                if now >= pointingReapplyAfter
                    and not IsEntityPlayingAnim(ped, pointingDict or cfg.dict, pointingBody or cfg.body, 3) then
                    local flag = pointingFlag or tonumber(cfg.flag) or 31
                    local function hasBit(bit)
                        return math.floor(flag / bit) % 2 == 1
                    end
                    if not hasBit(1) then flag = flag + 1 end
                    if not hasBit(16) then flag = flag + 16 end
                    TaskPlayAnim(ped, pointingDict or cfg.dict, pointingBody or cfg.body, tonumber(cfg.blendIn) or 2.0, tonumber(cfg.blendOut) or -2.0, -1, flag, 0.0, false, false, false, 0, true)
                    pointingReapplyAfter = now + (tonumber(cfg.reapplyDelay) or 700)
                end
            end
            Citizen.Wait(100)
        else
            Citizen.Wait(400)
        end
    end
end)

-- Arm IK is a per-frame target in RDR2, so it must be refreshed independently
-- from the 100 ms animation keepalive.  The first failed native call disables
-- the experiment for this hold and leaves the regular animation untouched.
Citizen.CreateThread(function()
    while true do
        local didWork = false
        local ikCfg = Config.PointingAnimation and Config.PointingAnimation.ik

        if isPointingActive and ikCfg and ikCfg.enabled ~= false then
            if PlayerPedId() == pointingPed then ApplyPointingIK(pointingPed, ikCfg) end
            didWork = true
        end

        local now = GetGameTimer()
        for i = #retiringPointingTargets, 1, -1 do
            local target = retiringPointingTargets[i]
            if now >= target.expires then
                DeletePointingIKTarget(target)
                table.remove(retiringPointingTargets, i)
            end
        end
        local remoteTimeout = (ikCfg and tonumber(ikCfg.remoteTimeout)) or 1500
        for serverId, state in pairs(remotePointing) do
            if now - (state.lastUpdate or 0) > remoteTimeout then
                CleanupRemotePointing(serverId)
            else
                local player = GetPlayerFromServerId(serverId)
                if player and player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped and ped ~= 0 and DoesEntityExist(ped)
                        and not IsEntityDead(ped) and not IsPedRagdoll(ped) then
                        if ikCfg and ikCfg.enabled ~= false then
                            ApplyPointingIK(ped, ikCfg, state.direction, state)
                            didWork = true
                        end
                    end
                end
            end
        end

        Citizen.Wait(didWork and 0 or 20)
    end
end)

Citizen.CreateThread(function()
    while true do
        if isPointingActive then
            local now = GetGameTimer()
            if now >= pointingSyncNext then
                TriggerServerEvent('thehunt_animations:server:pointing:update', GetCameraWorldDirection())
                pointingSyncNext = now + ((Config.PointingAnimation.ik and tonumber(Config.PointingAnimation.ik.syncInterval)) or 60)
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)

-- Определение категории для нативной функции TASK_EMOTE (согласно документации femga)
Citizen.CreateThread(function()
    Citizen.Wait(0)
    local cfg = Config.PointingAnimation
    if not cfg or cfg.enabled == false then return end
    if cfg.dict then LoadAnimDict(cfg.dict) end
    if type(cfg.mounted) == 'table' and cfg.mounted.dict then
        LoadAnimDict(cfg.mounted.dict)
    end
    if type(cfg.ik) == 'table' and cfg.ik.targetModel then
        RequestModel(GetHashKey(cfg.ik.targetModel))
    end
end)

local function GetEmoteCategory(emoteName)
    if not emoteName then return 0 end
    local upper = string.upper(emoteName)
    if string.find(upper, "DANCE") then return 5 end
    if string.find(upper, "TWIRL") then return 4 end
    if string.find(upper, "GREET") or string.find(upper, "BOW") or string.find(upper, "WAVE") or string.find(upper, "HAT") then return 3 end
    if string.find(upper, "TAUNT") or string.find(upper, "FLIP") or string.find(upper, "PROVOKE") then return 2 end
    if string.find(upper, "ACTION") or string.find(upper, "SMOKE") or string.find(upper, "COIN") or string.find(upper, "SPIT") then return 1 end
    return 0
end

-- =================================================================
-- СИСТЕМА УПРАВЛЕНИЯ ПРИКРЕПЛЕННЫМИ ПРОПАМИ (Props Engine)
-- =================================================================

local PROTECTED_PROPS_HASHES = {
    [`p_lantern01x`] = true,
    [`p_lantern02x`] = true,
    [`p_lantern03x`] = true,
    [`p_torch01x`] = true,
    [`p_torch02x`] = true,
}

local currentAttachedProps = {}
local previewAttachedProps = {}

local function IsNetworkedEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local ok, networked = pcall(NetworkGetEntityIsNetworked, entity)
    return ok and (networked == true or networked == 1)
end

local function RequestEntityControl(entity)
    if not IsNetworkedEntity(entity) or NetworkHasControlOfEntity(entity) then return end

    NetworkRequestControlOfEntity(entity)
    local deadline = GetGameTimer() + 250
    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
end

local function GetEntityNetworkId(entity)
    if not IsNetworkedEntity(entity) then return nil end
    local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
    if ok and tonumber(netId) and tonumber(netId) > 0 then
        return tonumber(netId)
    end
    return nil
end

local function DeleteAnimationObject(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    RequestEntityControl(entity)
    DetachEntity(entity, true, true)
    SetEntityAsMissionEntity(entity, true, true)
    DeleteObject(entity)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function AddNetworkId(networkIds, seen, entity)
    local netId = GetEntityNetworkId(entity)
    if netId and not seen[netId] then
        seen[netId] = true
        networkIds[#networkIds + 1] = netId
    end
end

local function MergeNetworkIds(target, source)
    local seen = {}
    for _, netId in ipairs(target or {}) do seen[netId] = true end
    for _, netId in ipairs(source or {}) do
        if netId and not seen[netId] then
            seen[netId] = true
            target[#target + 1] = netId
        end
    end
    return target
end

local function DeleteAttachedProp()
    local networkIds = {}
    local seen = {}
    for _, obj in ipairs(currentAttachedProps) do
        if DoesEntityExist(obj) then
            AddNetworkId(networkIds, seen, obj)
            DeleteAnimationObject(obj)
        end
    end
    currentAttachedProps = {}
    return networkIds
end

local function DeletePreviewProp()
    for _, obj in ipairs(previewAttachedProps) do
        if DoesEntityExist(obj) then
            DeleteAnimationObject(obj)
        end
    end
    previewAttachedProps = {}
end

local function AttachSingleProp(ped, propItem, isPreview)
    if not propItem or not propItem.model or not DoesEntityExist(ped) then return end

    local modelHash = (type(propItem.model) == 'number') and propItem.model or GetHashKey(propItem.model)
    RequestModel(modelHash)
    local timeout = 2000
    local elapsed = 0
    while not HasModelLoaded(modelHash) and elapsed < timeout do
        Citizen.Wait(50)
        elapsed = elapsed + 50
    end

    if not HasModelLoaded(modelHash) then return end

    local pCoords = GetEntityCoords(ped)
    local isNet = not isPreview
    local obj = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z + 0.2, isNet, isNet, false, false, true)
    if DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, isNet)
        if isPreview then
            pcall(function()
                Citizen.InvokeNative(0xF1CA12B18AEF5298, obj, true) -- _NETWORK_SET_ENTITY_INVISIBLE_TO_NETWORK
            end)
            SetEntityAlpha(obj, 180, false)
            SetEntityCollision(obj, false, false)
            SetEntityNoCollisionEntity(PlayerPedId(), obj, false)
        end

        local boneName = propItem.bone or 'SKEL_R_Hand'
        local boneIdx = GetEntityBoneIndexByName(ped, boneName)
        if boneIdx == -1 then boneIdx = GetEntityBoneIndexByName(ped, 'SKEL_R_Hand') end
        if boneIdx == -1 then boneIdx = 0 end

        local off = propItem.coords or { x = 0.0, y = 0.0, z = 0.0, xr = 0.0, yr = 0.0, zr = 0.0 }
        AttachEntityToEntity(obj, ped, boneIdx, off.x, off.y, off.z, off.xr, off.yr, off.zr, true, true, false, true, 1, true)

        if isPreview then
            table.insert(previewAttachedProps, obj)
        else
            table.insert(currentAttachedProps, obj)
        end
    end
    SetModelAsNoLongerNeeded(modelHash)
end

local function AttachPropToPed(ped, propData, isPreview)
    if isPreview then
        DeletePreviewProp()
    else
        DeleteAttachedProp()
    end
    if not propData then return end

    if propData[1] then
        for _, p in ipairs(propData) do
            AttachSingleProp(ped, p, isPreview)
        end
    else
        AttachSingleProp(ped, propData, isPreview)
    end
end

-- Точечное удаление временных пропсов только из кистей рук персонажа (макс. 0.35м от костей кистей)
local function CleanScenarioAndAttachedProps(ped)
    if not ped or not DoesEntityExist(ped) then return {} end

    local removedNetworkIds = {}
    local removedNetworkIdsSeen = {}

    local boneR = GetEntityBoneIndexByName(ped, "SKEL_R_Hand")
    local boneL = GetEntityBoneIndexByName(ped, "SKEL_L_Hand")
    local handRCoords = (boneR ~= -1) and GetWorldPositionOfEntityBone(ped, boneR) or nil
    local handLCoords = (boneL ~= -1) and GetWorldPositionOfEntityBone(ped, boneL) or nil

    if not handRCoords and not handLCoords then return removedNetworkIds end

    local handle, obj = FindFirstObject()
    local success = true

    while success do
        local isOurs = false
        for _, o in ipairs(currentAttachedProps) do
            if o == obj then isOurs = true break end
        end
        for _, o in ipairs(previewAttachedProps) do
            if o == obj then isOurs = true break end
        end

        if DoesEntityExist(obj) and not isOurs then
            local objCoords = GetEntityCoords(obj)
            local distR = handRCoords and #(objCoords - handRCoords) or 999.0
            local distL = handLCoords and #(objCoords - handLCoords) or 999.0

            if (distR <= 0.35 or distL <= 0.35) and not IsPedAPlayer(obj) then
                local model = GetEntityModel(obj)
                if not PROTECTED_PROPS_HASHES[model] then
                    AddNetworkId(removedNetworkIds, removedNetworkIdsSeen, obj)
                    DeleteAnimationObject(obj)
                end
            end
        end
        success, obj = FindNextObject(handle)
    end
    EndFindObject(handle)
    return removedNetworkIds
end

local function SyncPropCleanup(networkIds, reason, force)
    if (not force) and (not networkIds or #networkIds == 0) then return end
    TriggerServerEvent('thehunt_animations:server:cleanupProps', networkIds or {}, reason or 'animation')
end

-- Проверка, активна ли сейчас какая-либо анимация или сценарий на персонаже
local function IsAnyAnimationPlaying()
    local ped = PlayerPedId()
    if isRagdollActive then return true end
    if isPointingActive then return true end
    for _, obj in ipairs(currentAttachedProps) do
        if DoesEntityExist(obj) then return true end
    end
    if IsPedUsingAnyScenario(ped) then return true end
    if currentAnimation then
        -- Если это анимация по словарю, проверяем, играет ли она ещё в движке
        if currentAnimation.Type == 'Anim' and currentAnimation.Dict and currentAnimation.Body then
            if IsEntityPlayingAnim(ped, currentAnimation.Dict, currentAnimation.Body, 3) then
                return true
            else
                currentAnimation = nil
                SendNUIMessage({ type = 'AnimationStopped' })
                return false
            end
        end
        return true
    end
    return false
end

-- Остановка текущей анимации персонажа без жёсткой остановки его движения
local function StopCurrentAnimation(force)
    StopThermalReaction()
    local ped = PlayerPedId()
    local animationToStop = currentAnimation
    local hadScenario = IsPedUsingAnyScenario(ped)
    local hadAttachedProps = #currentAttachedProps > 0
    local hadPointing = isPointingActive

    -- Если анимация НЕ включена и нет активных сценариев/пропов — ничего не сбрасываем, чтобы не дёргать персонажа
    if not force and not IsAnyAnimationPlaying() then
        return false
    end

    local removedNetworkIds = DeleteAttachedProp()
    if hadPointing then
        StopPointingAnimation()
    end
    isRagdollActive = false
    isInputFocused = false

    -- Если сценарий принадлежит worldinteractions (currentAnimation == nil и нет пропов из меню),
    -- то НЕ запускаем здесь ни ClearPedTasks, ни тред ожидания — это приведёт к конкуренции двух
    -- параллельных тредов, которые оба пытаются дождаться конца сценария и очистить задачи.
    -- stopActiveAction в thehunt_worldinteractions сам полностью справится с плавным выходом.
    local wiOwnsScenario = hadScenario and not animationToStop and not hadAttachedProps and not hadPointing
    if wiOwnsScenario and not force then
        currentAnimation = nil
        SendNUIMessage({ type = 'AnimationStopped' })
        return true
    end

    -- Для обычной анимации останавливаем только её dict/clip. Очистка всех
    -- задач сбрасывает и текущую locomotion-задачу, из-за чего пед встаёт на
    -- месте во время отмены.
    if animationToStop and animationToStop.Type == 'Anim' and animationToStop.Dict and animationToStop.Body then
        StopAnimTask(ped, animationToStop.Dict, animationToStop.Body, 1.0)
    elseif hadPointing then
        -- StopPointingAnimation already removed its secondary task. Do not
        -- clear the locomotion task, otherwise releasing N would stop walking.
    elseif IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) or currentBodyMode == 'upper' then
        ClearPedSecondaryTask(ped)
    else
        if force then
            ClearPedTasksImmediately(ped)
        else
            -- Запускаем плавную нативную анимацию выхода из сценария (пед плавно встаёт, убирает предмет и т.д.)
            ClearPedTasks(ped)
        end
    end

    -- Гарантированное снятие блокировок физики
    FreezeEntityPosition(ped, false)

    local moveControls = {
        `INPUT_MOVE_LR`,
        `INPUT_MOVE_UD`,
        `INPUT_MOVE_UP_ONLY`,
        `INPUT_MOVE_DOWN_ONLY`,
        `INPUT_MOVE_LEFT_ONLY`,
        `INPUT_MOVE_RIGHT_ONLY`,
        `INPUT_SPRINT`,
        `INPUT_JUMP`
    }

    -- Поток отслеживания плавного завершения выхода из сценария и очистки
    Citizen.CreateThread(function()
        local myPed = PlayerPedId()
        local startTime = GetGameTimer()

        -- Если был активен сценарий и отмена не принудительная:
        -- даем персонажу плавно доиграть анимацию выхода (но не более 3.2 сек)
        if hadScenario and not force then
            local wantMove = false
            while IsPedUsingAnyScenario(myPed) and (GetGameTimer() - startTime < 3200) do
                Citizen.Wait(50)
                myPed = PlayerPedId()

                -- Если игрок во время выхода нажал клавишу движения (WASD / Shift / Space) —
                -- моментально освобождаем движение, чтобы персонаж сразу пошёл
                for i = 1, #moveControls do
                    if IsControlJustPressed(0, moveControls[i]) or IsDisabledControlJustPressed(0, moveControls[i]) then
                        wantMove = true
                        break
                    end
                end
                if wantMove then break end
            end

            -- После завершения анимации выхода (или нажатия WASD):
            -- сбрасываем остаточные задачи сценария, гарантируя 100% разблокировку движения
            ClearPedTasksImmediately(myPed)
            FreezeEntityPosition(myPed, false)
        end

        -- Очищаем остаточные сценарийные предметы из рук только ПОСЛЕ завершения выхода
        local finalNetworkIds = CleanScenarioAndAttachedProps(myPed)
        SyncPropCleanup(finalNetworkIds, 'animation', false)
    end)

    currentAnimation = nil
    SendNUIMessage({ type = 'AnimationStopped' })
    return true
end

local function CleanupLocalAnimationProps(reason)
    local networkIds = DeleteAttachedProp()
    networkIds = MergeNetworkIds(networkIds, CleanScenarioAndAttachedProps(PlayerPedId()))
    SyncPropCleanup(networkIds, reason or 'worldinteractions', true)
end

-- worldinteractions uses the same cleanup path for props spawned by scenarios.
RegisterNetEvent('thehunt_animations:client:cleanupLocalProps', function(reason)
    CleanupLocalAnimationProps(reason)
end)

local function DeletePropByNetworkId(netId)
    local numericId = tonumber(netId)
    if not numericId or numericId <= 0 then return end

    local ok, entity = pcall(NetworkGetEntityFromNetworkId, numericId)
    if ok and entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 3 then
        DeleteAnimationObject(entity)
    end
end

-- The owner normally deletes first, but this also removes the same object from
-- clients that already streamed it and are currently looking at the player.
RegisterNetEvent('thehunt_animations:client:cleanupProps', function(ownerServerId, networkIds)
    for _, netId in ipairs(networkIds or {}) do
        DeletePropByNetworkId(netId)
    end

    local ownerPlayer = GetPlayerFromServerId(tonumber(ownerServerId) or -1)
    if ownerPlayer and ownerPlayer ~= -1 then
        local ownerPed = GetPlayerPed(ownerPlayer)
        if ownerPed and ownerPed ~= 0 and DoesEntityExist(ownerPed) then
            CleanScenarioAndAttachedProps(ownerPed)
        end
    end
end)

-- =================================================================
-- РЕЖИМ ПРЕДПРОСМОТРА (GHOST PED PREVIEW)
-- =================================================================

-- Остановка предпросмотра
local function StopPreview(notifyNui)
    DeletePreviewProp()
    if previewPed and DoesEntityExist(previewPed) then
        CleanScenarioAndAttachedProps(previewPed)
        DeleteEntity(previewPed)
    end
    if previewAnchor and DoesEntityExist(previewAnchor) then
        DeleteEntity(previewAnchor)
    end
    previewAnchor = nil
    previewPed = nil
    previewLabel = nil

    if notifyNui ~= false then
        SendNUIMessage({ type = 'PreviewStopped' })
    end
end

local function CancelActiveAnimation()
    if IsProtectedActionActive() then
        return false
    end

    -- worldinteractions owns its own active-state flag, so cancel it through
    -- its public client event as well as stopping animations from this menu.
    TriggerEvent('thehunt_worldinteractions:cancel')
    local stopped = StopCurrentAnimation()
    StopPreview(true)
    return stopped
end

local lastCancelRequest = 0
local function RequestCancel()
    local now = GetGameTimer()
    if now - lastCancelRequest < 250 then return false end
    lastCancelRequest = now
    return CancelActiveAnimation()
end



-- Запуск предпросмотра анимации на призрачном клоне
-- Клон привязан к кинематическому якорному объекту, плавно интерполируется без рывков,
-- всегда невидим для других игроков и НИКОГДА не отсоединяется.
local function StartPreview(animData, bodyMode)
    if not animData then return end

    -- Если уже идет предпросмотр этой же анимации — выключаем его
    if previewLabel == animData.Label then
        StopPreview(true)
        return
    end

    -- Останавливаем предыдущий предпросмотр
    StopPreview(false)

    previewLabel = animData.Label
    bodyMode = bodyMode or currentBodyMode or 'full'

    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local camRot = GetGameplayCamRot(2)
    local yawRad = math.rad(camRot.z)
    local fwd = vector3(-math.sin(yawRad), math.cos(yawRad), 0.0)
    local rgt = vector3(math.cos(yawRad), math.sin(yawRad), 0.0)

    local distance = 2.1
    local sideOffset = -0.80
    local relZ = 0.12

    local spawnX = pCoords.x + (fwd.x * distance) + (rgt.x * sideOffset)
    local spawnY = pCoords.y + (fwd.y * distance) + (rgt.y * sideOffset)
    local spawnZ = pCoords.z + relZ
    local spawnHeading = (camRot.z + 180.0) % 360.0

    -- 1. Создаем невидимый якорный объект для абсолютно плавного ведения без дерганий
    local anchorModel = `p_cs_shotglass01x`
    RequestModel(anchorModel)
    local t = 0
    while not HasModelLoaded(anchorModel) and t < 50 do
        Citizen.Wait(10)
        t = t + 1
    end

    previewAnchor = CreateObject(anchorModel, spawnX, spawnY, spawnZ, false, false, false)
    SetEntityVisible(previewAnchor, false)
    SetEntityAlpha(previewAnchor, 0, false)
    SetEntityCollision(previewAnchor, false, false)
    FreezeEntityPosition(previewAnchor, true)
    SetEntityAsMissionEntity(previewAnchor, true, false)
    SetModelAsNoLongerNeeded(anchorModel)

    -- 2. Создаем полностью локальный клиентский клон
    local ok, ghost = pcall(ClonePed, playerPed, false, false, false, false)
    if not ok or not ghost or ghost == 0 or not DoesEntityExist(ghost) then
        local model = GetEntityModel(playerPed)
        ghost = CreatePed(model, spawnX, spawnY, spawnZ, spawnHeading, false, false, false, false)
    end
    previewPed = ghost
    if not previewPed or not DoesEntityExist(previewPed) then
        StopPreview(false)
        return
    end

    SetEntityCoordsNoOffset(previewPed, spawnX, spawnY, spawnZ, false, false, false)
    SetEntityHeading(previewPed, spawnHeading)
    SetEntityAsMissionEntity(previewPed, true, false)
    SetEntityVisible(previewPed, true)

    -- ClonePed копирует внешний вид, но не всегда переносит SetPedScale.
    -- Берём только текущий рост персонажа и применяем его к клону предпросмотра.
    local gotAppearance, skin = pcall(function()
        return exports['thehunt_character']:GetCachedAppearance()
    end)
    local playerScale = gotAppearance and skin and tonumber(skin.Scale or skin.scale)
    if playerScale then
        SetPedScale(previewPed, playerScale + 0.0)
    end

    pcall(function()
        Citizen.InvokeNative(0xF1CA12B18AEF5298, previewPed, true) -- _NETWORK_SET_ENTITY_INVISIBLE_TO_NETWORK
    end)

    SetEntityAlpha(previewPed, 180, false)
    SetEntityCollision(previewPed, false, false)
    SetEntityNoCollisionEntity(playerPed, previewPed, false)
    SetEntityNoCollisionEntity(previewPed, playerPed, false)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedCanRagdoll(previewPed, false)
    SetPedCanRagdollFromPlayerImpact(previewPed, false)
    SetEntityCanBeDamaged(previewPed, false)
    Entity(previewPed).state:set('isGhostPreview', true, false)
    Entity(previewPed).state:set('isProtected', true, false)

    -- Прикрепляем клона к невидимому якорному объекту:
    -- Физика RedM никогда не сбрасывает анимацию при перемещении родительского объекта,
    -- а клон никогда не падает и всегда находится строго на заданной высоте!
    AttachEntityToEntity(previewPed, previewAnchor, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

    ClearPedTasksImmediately(previewPed)
    Citizen.Wait(50)

    -- 3. Запускаем анимацию на клоне
    local extraProp = animData.Prop

    if animData.Type == 'Anim' and animData.Dict and animData.Body then
        if LoadAnimDict(animData.Dict) then
            local flag = (bodyMode == 'upper') and 31 or (animData.Flag or 1)
            TaskPlayAnim(previewPed, animData.Dict, animData.Body, 8.0, -8.0, -1, flag, 0.0, false, false, false, 0, true)
        end
    elseif animData.Type == 'Emote' and animData.EmoteType then
        local emoteMode = (bodyMode == 'upper') and 0 or 2
        local category = GetEmoteCategory(animData.EmoteType)
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, previewPed, category, emoteMode, GetHashKey(animData.EmoteType), 0, 0, 0, 0, 0)
    elseif animData.Type == 'Scenario' and animData.Scenario then
        DetachEntity(previewPed, true, true)
        local scenarioHash = (type(animData.Scenario) == 'number') and animData.Scenario or GetHashKey(animData.Scenario)
        TaskStartScenarioInPlace(previewPed, scenarioHash, -1, true, false, false, false)
    elseif animData.Type == 'Walkstyle' and animData.Clipset then
        if animData.Clipset ~= 'default' then
            RequestClipSet(animData.Clipset)
            if HasClipSetLoaded(animData.Clipset) then
                SetPedMovementClipset(previewPed, animData.Clipset, 0.2)
            end
        end
    end

    if extraProp then
        AttachPropToPed(previewPed, extraProp, true)
    end

    SendNUIMessage({
        type = 'PreviewStarted',
        label = animData.Label
    })

    -- 4. Поток непрерывного ультраплавного следования (Smooth Damped Lerp)
    Citizen.CreateThread(function()
        local thisPed = previewPed
        local thisAnchor = previewAnchor
        local startTime = GetGameTimer()
        local maxDuration = 30000 -- 30 секунд

        local curX = spawnX
        local curY = spawnY
        local curZ = spawnZ
        local curHeading = spawnHeading

        while DoesEntityExist(thisPed) and thisPed == previewPed and DoesEntityExist(thisAnchor) and isUIOpen do
            local pPed = PlayerPedId()
            local curCoords = GetEntityCoords(pPed)
            local curCamRot = GetGameplayCamRot(2)
            local yRad = math.rad(curCamRot.z)
            local forward = vector3(-math.sin(yRad), math.cos(yRad), 0.0)
            local right = vector3(math.cos(yRad), math.sin(yRad), 0.0)

            local targetX = curCoords.x + (forward.x * distance) + (right.x * sideOffset)
            local targetY = curCoords.y + (forward.y * distance) + (right.y * sideOffset)
            local targetZ = curCoords.z + relZ
            local targetHeading = (curCamRot.z + 180.0) % 360.0

            -- Плавная интерполяция позиции (Lerp factor = 0.12: абсолютно плавное скольжение без рывков)
            local factor = 0.12
            curX = curX + (targetX - curX) * factor
            curY = curY + (targetY - curY) * factor
            curZ = curZ + (targetZ - curZ) * factor

            -- Плавная интерполяция угла рыскания (с учетом перехода через 0/360)
            local diffRot = (targetHeading - curHeading) % 360.0
            if diffRot > 180.0 then diffRot = diffRot - 360.0 end
            if diffRot < -180.0 then diffRot = diffRot + 360.0 end
            curHeading = (curHeading + (diffRot * factor)) % 360.0

            -- Перемещаем якорный объект плавно в мировых координатах
            SetEntityCoordsNoOffset(thisAnchor, curX, curY, curZ, false, false, false)
            SetEntityHeading(thisAnchor, curHeading)

            -- Гарантированное удержание клона перед камерой:
            -- Если нативный сценарий открепил педа (DetachEntity), возвращаем прикрепление
            -- либо принудительно двигаем самого клона прямо по координатам камеры
            if not IsEntityAttachedToEntity(thisPed, thisAnchor) then
                if animData.Type ~= 'Scenario' then
                    AttachEntityToEntity(thisPed, thisAnchor, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end
                if not IsEntityAttachedToEntity(thisPed, thisAnchor) then
                    SetEntityCoordsNoOffset(thisPed, curX, curY, curZ, false, false, false)
                    SetEntityHeading(thisPed, curHeading)
                end
            end

            -- Запрет коллизий с персонажем
            SetEntityNoCollisionEntity(pPed, thisPed, false)
            SetEntityNoCollisionEntity(thisPed, pPed, false)

            if GetGameTimer() - startTime >= maxDuration then
                break
            end

            Citizen.Wait(0)
        end

        if thisPed == previewPed then
            StopPreview(true)
        end
    end)
end


-- =================================================================
-- ВОСПРОИЗВЕДЕНИЕ НА САМОМ ПЕРСОНАЖЕ (ЛКМ)
-- =================================================================

-- Проигрывание обычной анимации (Anim Dict)
local function PlayAnimDictionary(dict, body, duration, flag, intro, exitTiming, bodyMode)
    local ped = PlayerPedId()
    local isOnMount = IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true)
    local isUpper = (bodyMode == 'upper') or isOnMount

    if not LoadAnimDict(dict) then
        TriggerEvent("thehunt_status:notify", "Анимации", "Не удалось загрузить анимацию", "error", true)
        return false
    end

    if isUpper then
        ClearPedSecondaryTask(ped)
    else
        ClearPedTasks(ped)
    end

    local finalFlag = flag or 0
    if isUpper then
        finalFlag = 31 -- Верхняя часть тела
    end

    TaskPlayAnim(ped, dict, body, tonumber(intro) or 2.0, tonumber(exitTiming) or 2.0, duration or -1, finalFlag, 0, false, false, false, 0, true)
    RemoveAnimDict(dict)
    return true
end

-- Проигрывание нативной эмоции (RDR3 Emote)
local function PlayNativeEmote(emoteType, bodyMode)
    local ped = PlayerPedId()
    local isOnMount = IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true)
    local isUpper = (bodyMode == 'upper') or isOnMount
    local category = GetEmoteCategory(emoteType)

    if isUpper then
        ClearPedSecondaryTask(ped)
        -- 0xB31A277C1AC7B7FF: TaskEmote (upper body mode = 0)
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, category, 0, GetHashKey(emoteType), 1, 1, 0, 0, 0)
    else
        ClearPedTasks(ped)
        -- Full body mode = 2
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, category, 2, GetHashKey(emoteType), 0, 0, 0, 0, 0)
    end
    return true
end

-- Проигрывание сценария (Scenario)
local function PlayScenarioAnim(scenarioName)
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) then
        TriggerEvent("thehunt_status:notify", "Анимации", "Сценарии нельзя использовать верхом на лошади", "warning", true)
        return false
    end

    local scenarioHash = (type(scenarioName) == 'number') and scenarioName or GetHashKey(scenarioName)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    ClearPedTasksImmediately(ped)
    Citizen.Wait(50)
    TaskStartScenarioInPlace(ped, scenarioHash, -1, true, false, false, false)
    return true
end

-- Общая функция запуска анимации по данным
local function StartAnimation(animData, bodyMode)
    StopThermalReaction()
    if not animData then return false end
    if isPointingActive then
        StopPointingAnimation()
    end
    StopPreview(true) -- Запуск на персонаже выключает предпросмотр

    -- Если уже играет другая анимация — плавно завершаем её и дожидаемся перехода
    if currentAnimation then
        StopCurrentAnimation()
        Citizen.Wait(200)
    end

    TriggerEvent('thehunt_worldinteractions:cancel')
    DeleteAttachedProp()
    CleanScenarioAndAttachedProps(PlayerPedId())

    bodyMode = bodyMode or currentBodyMode or 'full'
    currentBodyMode = bodyMode

    local success = false
    if animData.Type == 'Walkstyle' and animData.Clipset then
        local ped = PlayerPedId()
        if animData.Clipset == 'default' then
            ResetPedMovementClipset(ped, 0.2)
            TriggerEvent("thehunt_status:notify", "Походка", "Стиль походки сброшен на стандартный", "info", true)
            return true
        else
            RequestClipSet(animData.Clipset)
            local timeout = 2000
            local elapsed = 0
            while not HasClipSetLoaded(animData.Clipset) and elapsed < timeout do
                Citizen.Wait(50)
                elapsed = elapsed + 50
            end
            if HasClipSetLoaded(animData.Clipset) then
                SetPedMovementClipset(ped, animData.Clipset, 0.2)
                TriggerEvent("thehunt_status:notify", "Походка", string.format("Выбран стиль: %s", animData.Label), "success", true)
                return true
            else
                TriggerEvent("thehunt_status:notify", "Походка", "Не удалось загрузить стиль походки", "error", true)
                return false
            end
        end
    elseif animData.Type == 'Anim' and animData.Dict and animData.Body then
        success = PlayAnimDictionary(animData.Dict, animData.Body, -1, animData.Flag, nil, nil, bodyMode)
        if success and animData.Prop then
            AttachPropToPed(PlayerPedId(), animData.Prop, false)
        end
    elseif animData.Type == 'Emote' and animData.EmoteType then
        success = PlayNativeEmote(animData.EmoteType, bodyMode)
    elseif animData.Type == 'Scenario' and animData.Scenario then
        success = PlayScenarioAnim(animData.Scenario)
    end

    if success then
        currentAnimation = animData
        SendNUIMessage({
            type = 'AnimationStarted',
            label = animData.Label
        })
    end
    return success
end

-- Поиск анимации по названию
local function FindAnimationByLabel(name)
    if not name or name == '' then return nil end

    -- 1. Строгое точное совпадение (гарантия вызова именно той анимации, что привязана к кнопке)
    for _, anim in ipairs(Config.Animations or {}) do
        if anim.Label == name then
            return anim
        end
    end

    local query = string.lower(name)
    for _, anim in ipairs(Config.Animations or {}) do
        if anim.Label and string.lower(anim.Label) == query then
            return anim
        end
    end

    -- 2. Поиск по частичному совпадению (только если не найдено точное)
    for _, anim in ipairs(Config.Animations or {}) do
        if anim.Label and string.find(string.lower(anim.Label), query, 1, true) then
            return anim
        end
    end
    return nil
end

-- =================================================================
-- ОТКРЫТИЕ И ЗАКРЫТИЕ ИНТЕРФЕЙСА
-- =================================================================

local function OpenAnimationMenu()
    if isUIOpen then return end
    TriggerServerEvent('thehunt_animations:server:open')
end

local function CloseAnimationMenu()
    if not isUIOpen then return end
    StopPreview(false)

    isUIOpen = false
    isInputFocused = false
    isWindowFocused = true
    isMMBPressed = false
    LocalPlayer.state:set('isAnimMenuOpen', false, false)
    TriggerServerEvent('thehunt_chat:setTyping', false)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'Close' })
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
end

-- Получение ответа от сервера с избранными и закрепленными анимациями
RegisterNetEvent('thehunt_animations:client:open', function(favorites, pinned)
    favoritesList = favorites or {}
    pinnedList = pinned or {}
    isUIOpen = true
    isInputFocused = false
    isWindowFocused = true
    isMMBPressed = false
    LocalPlayer.state:set('isAnimMenuOpen', true, false)
    TriggerServerEvent('thehunt_chat:setTyping', false)
    StopPreview(false)

    local animsWithFavs = {}
    for i, v in ipairs(Config.Animations or {}) do
        local isFav = false
        for _, favLabel in ipairs(favoritesList) do
            if favLabel == v.Label then
                isFav = true
                break
            end
        end

        local isPinned = false
        for _, pinLabel in ipairs(pinnedList) do
            if pinLabel == v.Label then
                isPinned = true
                break
            end
        end

        animsWithFavs[i] = {
            Label = v.Label,
            Category = v.Category or 'Gestures',
            Type = v.Type or 'Anim',
            Favorite = isFav,
            Pinned = isPinned,
            Playing = (currentAnimation and currentAnimation.Label == v.Label) or false
        }
    end

    SendNUIMessage({
        type = 'Open',
        categories = Config.Categories,
        animations = animsWithFavs,
        pinned = pinnedList,
        bodyMode = currentBodyMode
    })

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
end)

-- Синхронизация закрепленных анимаций с сервером
RegisterNetEvent('thehunt_animations:client:syncPinned', function(pinned)
    pinnedList = pinned or {}
    SendNUIMessage({
        type = 'SyncPinned',
        pinned = pinnedList
    })
end)

-- =================================================================
-- NUI CALLBACKS
-- =================================================================

RegisterNUICallback('thehunt_animations:play', function(data, cb)
    local animLabel = data.label
    local bodyMode = data.bodyMode or currentBodyMode or 'full'
    local anim = FindAnimationByLabel(animLabel)
    if anim then
        StartAnimation(anim, bodyMode)
    end
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:preview', function(data, cb)
    local animLabel = data.label
    local bodyMode = data.bodyMode or currentBodyMode or 'full'
    local anim = FindAnimationByLabel(animLabel)
    if anim then
        StartPreview(anim, bodyMode)
    end
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:stop', function(data, cb)
    CancelActiveAnimation()
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:toggleFavorite', function(data, cb)
    local label = data.label
    local isFav = data.isFavorite
    TriggerServerEvent('thehunt_animations:server:toggleFavorite', label, isFav)
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:close', function(data, cb)
    CloseAnimationMenu()
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:playSound', function(data, cb)
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:setInputFocus', function(data, cb)
    isInputFocused = (data.hasFocus == true)
    cb({ ok = true })
end)

-- Фокус меню (клик внутри окна / клик вне окна)
RegisterNUICallback('thehunt_animations:setWindowFocus', function(data, cb)
    isWindowFocused = (data.isFocused == true)
    cb({ ok = true })
end)

-- Вращение камеры на СКМ (зажатие колесика мыши)
RegisterNUICallback('thehunt_animations:setCameraRotationState', function(data, cb)
    isMMBPressed = (data.active == true)
    -- Нативный курсор RedM рисуется не CSS-слоем NUI. Пока зажата СКМ,
    -- оставляем фокус у меню, но выключаем только отображение курсора.
    SetNuiFocus(true, not isMMBPressed)
    SetNuiFocusKeepInput(true)
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:togglePin', function(data, cb)
    local label = data.label
    local isPinned = data.isPinned
    TriggerServerEvent('thehunt_animations:server:togglePin', label, isPinned)
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:radialPlay', function(data, cb)
    local label = data.label
    local bodyMode = data.bodyMode == 'upper' and 'upper' or 'full'
    if isRadialOpen then
        isRadialOpen = false
        LocalPlayer.state:set('isAnimMenuOpen', false, false)
        TriggerServerEvent('thehunt_chat:setTyping', false)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CloseRadial' })
    end
    if label then
        local anim = FindAnimationByLabel(label)
        if anim then
            StartAnimation(anim, bodyMode)
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('thehunt_animations:radialClose', function(data, cb)
    if isRadialOpen then
        isRadialOpen = false
        LocalPlayer.state:set('isAnimMenuOpen', false, false)
        TriggerServerEvent('thehunt_chat:setTyping', false)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CloseRadial' })
    end
    cb({ ok = true })
end)

-- Сборка 4 слотов для радиального меню
local function BuildRadialSlots()
    local slots = {}
    for i = 1, 4 do
        local label = pinnedList[i]
        if label then
            local anim = FindAnimationByLabel(label)
            slots[i] = {
                slot = i,
                label = label,
                category = anim and anim.Category or 'Gestures',
                type = anim and anim.Type or 'Anim',
                isEmpty = false
            }
        else
            slots[i] = {
                slot = i,
                label = 'Слот ' .. i,
                isEmpty = true
            }
        end
    end
    return slots
end

-- =================================================================
-- БЫСТРОЕ РАДИАЛЬНОЕ МЕНЮ (УДЕРЖАНИЕ Y)
-- =================================================================

local function OnOpenRadial()
    if isUIOpen or isRadialOpen or LocalPlayer.state.isAnimMenuOpen or IsEntityDead(PlayerPedId()) then return end
    isRadialOpen = true
    LocalPlayer.state:set('isAnimMenuOpen', true, false)
    TriggerServerEvent('thehunt_chat:setTyping', false)
    local slots = BuildRadialSlots()
    SendNUIMessage({
        type = 'OpenRadial',
        pinned = slots
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
end

local function OnCloseRadial()
    if isRadialOpen then
        isRadialOpen = false
        LocalPlayer.state:set('isAnimMenuOpen', false, false)
        TriggerServerEvent('thehunt_chat:setTyping', false)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            type = 'CloseRadial'
        })
    end
end

RegisterCommand('+hunt_anim_wheel_y', OnOpenRadial, false)
RegisterCommand('-hunt_anim_wheel_y', OnCloseRadial, false)
RegisterKeyMapping('+hunt_anim_wheel_y', 'Радиальное меню анимаций (Удержание)', 'keyboard', 'Y')

-- =================================================================
-- ДОЛГОЕ НАЖАТИЕ X (0.5 СЕКУНДЫ) — РУКИ ВВЕРХ
-- =================================================================

RegisterCommand('+hunt_handsup_hold', function()
    if isUIOpen or isRadialOpen or LocalPlayer.state.isAnimMenuOpen or IsEntityDead(PlayerPedId()) then return end
    isHoldingX = true
    xHoldTimer = GetGameTimer()

    Citizen.CreateThread(function()
        local thisTimer = xHoldTimer
        while isHoldingX and (GetGameTimer() - thisTimer < 500) do
            Citizen.Wait(100)
        end
        if isHoldingX and (xHoldTimer == thisTimer) then
            local anim = FindAnimationByLabel('Руки вверх')
            if anim then
                if currentAnimation and currentAnimation.Label == 'Руки вверх' then
                    StopCurrentAnimation()
                else
                    StartAnimation(anim, 'full')
                end
            end
        end
    end)
end, false)

RegisterCommand('-hunt_handsup_hold', function()
    isHoldingX = false
    xHoldTimer = 0
end, false)

RegisterKeyMapping('+hunt_handsup_hold', 'Руки вверх (Удержание 0.5 сек)', 'keyboard', 'X')

-- =================================================================
-- Показать пальцем (удержание B)
-- =================================================================

local function OnStartPointing()
    if isHoldingPoint then return end
    pointingRequest = pointingRequest + 1
    local request = pointingRequest
    isHoldingPoint = true
    if not StartPointingAnimation() and pointingRequest == request then
        isHoldingPoint = false
    end
end

local function OnStopPointing()
    isHoldingPoint = false
    StopPointingAnimation()
end

RegisterCommand('+hunt_point_b', OnStartPointing, false)
RegisterCommand('-hunt_point_b', OnStopPointing, false)
RegisterKeyMapping('+hunt_point_b', 'Показать пальцем (удержание)', 'keyboard', 'B')

-- Обратная совместимость для сохранённых биндов в локальном кэше RedM (cfx_keys.xml):
-- Если у старого клиента клавиша B вызывает +hunt_anim_radial, она направляется на указание пальцем.
-- Старые сохранённые бинды колеса на N намеренно отключены.
RegisterCommand('+hunt_anim_radial', OnStartPointing, false)
RegisterCommand('-hunt_anim_radial', OnStopPointing, false)
RegisterCommand('+hunt_anim_wheel', function() end, false)
RegisterCommand('-hunt_anim_wheel', function() end, false)
RegisterCommand('+hunt_point_hold', function() end, false)
RegisterCommand('-hunt_point_hold', function() end, false)

-- =================================================================
-- КОМАНДЫ И ГОРЯЧИЕ КЛАВИШИ (F3: Открыть, Z: Отменить)
-- =================================================================

-- Команда открытия меню анимаций
RegisterCommand('hunt_anim_open', function()
    if isUIOpen then
        CloseAnimationMenu()
    else
        OpenAnimationMenu()
    end
end, false)

-- Привязка клавиши F3 для открытия/закрытия меню анимаций
RegisterKeyMapping('hunt_anim_open', 'Открыть меню анимаций (HUNT)', 'keyboard', Config.KeyOpen or 'F3')

-- Команда и клавиша Z для отмены/остановки текущей анимации
RegisterCommand('hunt_anim_stop', function()
    RequestCancel()
end, false)

RegisterKeyMapping('hunt_anim_stop', 'Остановить анимацию (HUNT)', 'keyboard', Config.KeyCancel or 'Z')

-- Команда hunt_anim_cancel для совместимости со сторонними ресурсами/меню
RegisterCommand('hunt_anim_cancel', function()
    -- Игнорируем устаревший бинд F1 (0xA8E3F467) из старого кэша клиента,
    -- так как F1 теперь выделена под NoClip админ-панели
    if IsControlJustPressed(0, 0xA8E3F467) or IsDisabledControlJustPressed(0, 0xA8E3F467) or IsControlPressed(0, 0xA8E3F467) then
        return
    end
    RequestCancel()
end, false)

-- Дополнительные удобные чат-команды
RegisterCommand(Config.CommandOpen or 'anim', function()
    OpenAnimationMenu()
end, false)

RegisterCommand('emotes', function()
    OpenAnimationMenu()
end, false)

RegisterCommand('e', function(source, args)
    if not args or #args == 0 then
        OpenAnimationMenu()
        return
    end

    local firstArg = string.lower(args[1])
    if firstArg == 'c' or firstArg == 'cancel' or firstArg == 'stop' then
        CancelActiveAnimation()
        return
    end

    local mode = 'full'
    if args[#args] and (string.lower(args[#args]) == 'upper' or string.lower(args[#args]) == 'full') then
        mode = string.lower(args[#args])
        table.remove(args, #args)
    end

    local name = table.concat(args, ' ')
    local anim = FindAnimationByLabel(name)
    if anim then
        StartAnimation(anim, mode)
    else
        TriggerEvent("thehunt_status:notify", "Анимации", string.format("Анимация «%s» не найдена", name), "error", true)
    end
end, false)

RegisterCommand(Config.CommandCancel or 'c', function()
    CancelActiveAnimation()
end, false)

-- =================================================================
-- РЭГДОЛЛ (RAGDOLL) НА КЛАВИШУ L
-- =================================================================

local isRagdollActive = false
local lastRagdollToggleTime = 0

local function ToggleRagdollState()
    local now = GetGameTimer()
    if now - lastRagdollToggleTime < 450 then
        -- Защита от двойного срабатывания при нескольких биндах на клавишу L в одном кадре
        return
    end
    lastRagdollToggleTime = now

    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) then return end
    if isUIOpen or isInputFocused then return end

    isRagdollActive = not isRagdollActive
    if isRagdollActive then
        if currentAnimation or isPointingActive then
            StopCurrentAnimation()
        end
        StopPreview(true)
        SetPedCanRagdoll(ped, true)
        SetPedToRagdoll(ped, 1000, 1000, 0, 0, 0, 0)
    end
end

RegisterNetEvent('thehunt_animations:client:toggleRagdoll', function()
    ToggleRagdollState()
end)

RegisterCommand('hunt_ragdoll_toggle', function()
    ToggleRagdollState()
end, false)

RegisterCommand('ragdoll', function()
    ToggleRagdollState()
end, false)

if RegisterKeyMapping then
    pcall(RegisterKeyMapping, 'hunt_ragdoll_toggle', 'Рэгдолл / Упасть (HUNT)', 'keyboard', 'L')
end

Citizen.CreateThread(function()
    while true do
        if isRagdollActive then
            local ped = PlayerPedId()
            if not IsPedDeadOrDying(ped, true) and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, true) then
                SetPedCanRagdoll(ped, true)
                SetPedToRagdoll(ped, 1000, 1000, 0, 0, 0, 0)
                ResetPedRagdollTimer(ped)
            else
                isRagdollActive = false
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)

-- =================================================================
-- ПОТОК ФИЛЬТРАЦИИ УПРАВЛЕНИЯ И КАМЕРЫ (Стандарт ui_controls_guidelines.md)
-- =================================================================

Citizen.CreateThread(function()
    local allowedControls = {
        -- Отмена анимации (Z) должна оставаться доступной даже при открытом UI.
        Config.CancelKey,

        -- Войс-чат
        `INPUT_PUSH_TO_TALK`,
        0xF1301666,
        0x05CA7C52,

        -- Движение пешком (WASD, Shift, Space, Ctrl)
        `INPUT_MOVE_LR`,
        `INPUT_MOVE_UD`,
        `INPUT_MOVE_UP_ONLY`,
        `INPUT_MOVE_DOWN_ONLY`,
        `INPUT_MOVE_LEFT_ONLY`,
        `INPUT_MOVE_RIGHT_ONLY`,
        `INPUT_SPRINT`,
        `INPUT_JUMP`,
        `INPUT_CLIMB`,
        `INPUT_DUCK`,

        -- Движение на лошади (WASD, Shift, Space, Ctrl)
        `INPUT_HORSE_MOVE_UD`,
        `INPUT_HORSE_MOVE_LR`,
        `INPUT_HORSE_MOVE_UP_ONLY`,
        `INPUT_HORSE_MOVE_DOWN_ONLY`,
        `INPUT_HORSE_MOVE_LEFT_ONLY`,
        `INPUT_HORSE_MOVE_RIGHT_ONLY`,
        `INPUT_HORSE_SPRINT`,
        `INPUT_HORSE_JUMP`,
        `INPUT_HORSE_STOP`,

        -- Управление повозками / транспортом
        `INPUT_VEH_ACCELERATE`,
        `INPUT_VEH_BRAKE`,
        `INPUT_VEH_MOVE_LR`,
        `INPUT_VEH_HANDBRAKE`,

        -- Числовые хэши RDR2 на случай нестандартных названий
        0x4D8FB4C1, -- MOVE_LR
        0xEDA4707E, -- MOVE_UD
        0x8FD015D8, -- MOVE_UD (RDR2)
        0xD27782E3, -- MOVE_UP_ONLY (W)
        0x7065027D, -- MOVE_DOWN_ONLY (S)
        0xB4E465B4, -- MOVE_LEFT_ONLY (A)
        0x399C6619, -- MOVE_RIGHT_ONLY (D)
        0x8FFC75D0, -- SPRINT (Shift)
        0x2C4B7E05, -- SPRINT_ALT
        0xD42E6C65, -- JUMP (Space)
        0x9330C873, -- CLIMB (Space)
        0xDB096B85, -- DUCK (Ctrl)
        0x78564D7B, -- DUCK_ALT
        0x82CA7BA9, -- HORSE_MOVE_UD
        0x227DCC40, -- HORSE_MOVE_LR
        0xE95F4F0C, -- HORSE_MOVE_UP_ONLY (W)
        0x866B5DB8, -- HORSE_MOVE_DOWN_ONLY (S)
        0x51E13F58, -- HORSE_MOVE_LEFT_ONLY (A)
        0xC229CF67, -- HORSE_MOVE_RIGHT_ONLY (D)
        0x54182BC1, -- HORSE_SPRINT (Shift)
        0x63A38928, -- HORSE_JUMP (Space)
        0xD2315E39, -- HORSE_CLIMB (Space)
        0x153A478C   -- HORSE_STOP (Ctrl)
    }

    local cameraControls = {
        `INPUT_LOOK_LR`,
        `INPUT_LOOK_UD`,
        0xA987235F, -- LOOK_LR
        0xD2047988, -- LOOK_UD
        0x3E92BDE0, -- дополнительные оси мыши RedM
        0x6BA8B0D3
    }

    local wasUIOpen = false

    while true do
        if IsProtectedActionActive() then
            if Config.CancelKey then
                for pad = 0, 2 do
                    DisableControlAction(pad, Config.CancelKey, true)
                end
            end
        elseif Config.CancelKey and (IsControlJustPressed(0, Config.CancelKey) or IsDisabledControlJustPressed(0, Config.CancelKey)) then
            RequestCancel()
        end

        if isUIOpen and isInputFocused then
            wasUIOpen = true
            Citizen.Wait(0)
            local ped = PlayerPedId()
            for pad = 0, 2 do
                DisableAllControlActions(pad)

                -- СКМ — явное действие для обзора. Разрешаем только оси
                -- камеры даже при активном поле поиска: печать и остальное
                -- управление по-прежнему полностью заблокированы.
                if isMMBPressed then
                    for i = 1, #cameraControls do
                        EnableControlAction(pad, cameraControls[i], true)
                    end
                end
            end
            DisablePlayerFiring(ped, true)

        elseif isUIOpen then
            wasUIOpen = true
            Citizen.Wait(0)
            local ped = PlayerPedId()

            for pad = 0, 2 do
                DisableAllControlActions(pad)
                for i = 1, #allowedControls do
                    EnableControlAction(pad, allowedControls[i], true)
                end

                if isMMBPressed then
                    for i = 1, #cameraControls do
                        EnableControlAction(pad, cameraControls[i], true)
                    end
                end
            end
            DisablePlayerFiring(ped, true)

        elseif isRadialOpen then
            wasUIOpen = true
            Citizen.Wait(0)
            local ped = PlayerPedId()
            for pad = 0, 2 do
                DisableAllControlActions(pad)
                for i = 1, #allowedControls do
                    EnableControlAction(pad, allowedControls[i], true)
                end
            end
            DisablePlayerFiring(ped, true)

        else
            wasUIOpen = false
            isInputFocused = false
            Citizen.Wait(150)
        end
    end
end)

-- Аварийная команда для мгновенного восстановления управления и снятия любых блокировок
RegisterCommand('fixanim', function()
    StopThermalReaction()
    isUIOpen = false
    isRadialOpen = false
    isInputFocused = false
    isMMBPressed = false
    isHoldingX = false
    isHoldingPoint = false
    StopPointingAnimation()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    StopPreview(false)
    SendNUIMessage({ type = 'CloseRadial' })
    TriggerEvent('thehunt_worldinteractions:cancel')
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    TriggerEvent("thehunt_status:notify", "Анимации", "Управление персонажем разблокировано", "success", true)
end, false)

-- Автоматический сброс блокировок при запуске и перезапуске ресурса
Citizen.CreateThread(function()
    Citizen.Wait(100)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    Citizen.Wait(800)
    RequestPinnedAnimations()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    isUIOpen = false
    isRadialOpen = false
    isHoldingPoint = false
    StopPointingAnimation()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    StopPreview(false)
    SendNUIMessage({ type = 'CloseRadial' })
    for serverId in pairs(remotePointing) do
        CleanupRemotePointing(serverId)
    end
    for _, target in ipairs(retiringPointingTargets) do DeletePointingIKTarget(target) end
    retiringPointingTargets = {}
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
end)

-- Экспорты для внешних скриптов
exports('PlayAnimation', function(name, bodyOption)
    local anim = FindAnimationByLabel(name)
    if anim then
        return StartAnimation(anim, bodyOption or 'full')
    end
    return false
end)

exports('StopAnimation', function()
    CancelActiveAnimation()
end)

exports('OpenMenu', OpenAnimationMenu)
exports('CloseMenu', CloseAnimationMenu)
exports('IsPlayingAnimation', function()
    return currentAnimation ~= nil
end)
exports('GetCurrentAnimation', function()
    return currentAnimation
end)
exports('GetPreviewPed', function()
    return previewPed
end)
exports('isAnimationsOpen', function()
    return isUIOpen == true or isRadialOpen == true
end)
exports('IsAnimationsOpen', function()
    return isUIOpen == true or isRadialOpen == true
end)
exports('isMenuOpen', function()
    return isUIOpen == true or isRadialOpen == true
end)
exports('isAnimMenuOpen', function()
    return isUIOpen == true or isRadialOpen == true
end)
exports('isRadialOpen', function()
    return isRadialOpen == true
end)
exports('IsRadialOpen', function()
    return isRadialOpen == true
end)

-- Survival requests background reactions; intentional player actions take priority.
local function ThermalHasPriorityConflict(ped)
    return currentAnimation ~= nil or isPointingActive or LocalPlayer.state.huntWorldInteractionActive
        or IsPedUsingAnyScenario(ped)
        or (protectedAction and (not protectedAction.expiresAt or GetGameTimer() < protectedAction.expiresAt))
end
RegisterNetEvent('thehunt_animations:client:yieldThermal', StopThermalReaction)

exports('SetThermalReaction', function(name)
    if GetInvokingResource() ~= 'thehunt_survival' then return false end
    if not name then StopThermalReaction(); return true end
    if ThermalHasPriorityConflict(PlayerPedId()) then
        StopThermalReaction()
        return false
    end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or LocalPlayer.state.isDead or IsPedRagdoll(ped) or IsPedSwimming(ped) then
        StopThermalReaction()
        return false
    end
    if thermalReaction and thermalReaction.anim.Label == name and thermalReaction.ped == ped then
        thermalReaction.expires = GetGameTimer() + 2500
        return true
    end
    StopThermalReaction()
    local anim = FindAnimationByLabel(name)
    if not anim or anim.Type ~= 'Anim' or not LoadAnimDict(anim.Dict) then return false end
    -- Loading can yield; a medical/campfire action may acquire priority meanwhile.
    if ThermalHasPriorityConflict(PlayerPedId()) then
        RemoveAnimDict(anim.Dict)
        return false
    end
    -- Background reaction: never clear another resource's task or selected animation.
    TaskPlayAnim(ped, anim.Dict, anim.Body, 2.0, 2.0, -1, 31, 0, false, false, false, 0, true)
    thermalReaction = { anim = anim, ped = ped, expires = GetGameTimer() + 2500 }
    return true
end)

CreateThread(function()
    while true do
        Wait(250)
        local active = thermalReaction
        if active then
            if GetGameTimer() > active.expires or PlayerPedId() ~= active.ped
                or ThermalHasPriorityConflict(active.ped)
                or IsEntityDead(active.ped) or LocalPlayer.state.isDead
                or IsPedRagdoll(active.ped) or IsPedSwimming(active.ped) then
                StopThermalReaction()
            elseif not IsEntityPlayingAnim(active.ped, active.anim.Dict, active.anim.Body, 3) then
                -- Native task interruption does not cure thermal stress.
                TaskPlayAnim(active.ped, active.anim.Dict, active.anim.Body, 2.0, 2.0, -1, 31, 0, false, false, false, 0, true)
            end
        end
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name == 'thehunt_survival' or name == GetCurrentResourceName() then StopThermalReaction() end
end)
