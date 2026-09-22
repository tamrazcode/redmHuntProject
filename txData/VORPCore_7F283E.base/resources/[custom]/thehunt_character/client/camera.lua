-- =================================================================
-- HUNT: Character creator camera. Centers on the live player ped.
-- =================================================================

Camera = {}

local activeCam = nil
local PRESETS = {
    -- Every target is resolved from the live skeleton, so height/scale changes
    -- cannot make a preset drift away from the requested body part.
    full  = { distance = 3.10, bones = { "SKEL_Pelvis" }, ratio = 0.52, fov = 42.0 },
    torso = { distance = 2.15, bones = { "SKEL_Spine3", "SKEL_Spine2", "SKEL_Spine1" }, ratio = 0.69, fov = 31.0 },
    head  = { distance = 1.35, bones = { "SKEL_Head" }, ratio = 0.96, fov = 25.0 },
    legs  = { distance = 1.35, bones = { "SKEL_L_Toe0", "SKEL_R_Toe0", "SKEL_L_Foot", "SKEL_R_Foot" }, ratio = 0.02, fov = 26.0 },
    -- The feet preset follows the midpoint of the two actual foot bones,
    -- not the ped origin or a static low-height approximation.
    feet  = { distance = 1.35, bones = { "SKEL_L_Foot", "SKEL_R_Foot" }, ratio = 0.02, fov = 26.0 },
}

-- Keep the original, comfortable creator controls.  Collision handling below
-- resolves the actual camera position instead of loosening these limits.
local MIN_ORBIT = math.pi - 1.05
local MAX_ORBIT = math.pi + 1.05
local MIN_ZOOM = 0.85
local MAX_ZOOM = 3.45
-- The same 18 cm clearance is used for walls, props and the floor.  There is
-- deliberately no fixed lower Z limit: the nearest streamed collision surface
-- is the limit instead.
local CAMERA_COLLISION_PADDING = 0.18
local CAMERA_SURFACE_CLEARANCE = 0.18
local CAMERA_COLLISION_FLAGS = -1 -- world, map props, interiors and objects
local CAMERA_ENVELOPE_RADIUS = 0.18

local desiredOrbit, currentOrbit = math.pi, math.pi
local desiredDistance, currentDistance = PRESETS.full.distance, PRESETS.full.distance
local desiredHeight, currentHeight = 0.90, 0.90
local desiredFov, currentFov = PRESETS.full.fov, PRESETS.full.fov
local desiredPedHeading = 90.0
local activePresetName = "full"

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function Lerp(from, to, amount)
    return from + (to - from) * amount
end

local function GetHeadHeight(ped)
    local target = ped or PlayerPedId()
    local root = GetEntityCoords(target)
    local headBone = GetEntityBoneIndexByName(target, "SKEL_Head")
    if headBone and headBone ~= -1 then
        local head = GetWorldPositionOfEntityBone(target, headBone)
        -- SKEL_Head is the actual centre of the face/head for the live model.
        if head then return math.max(0.02, head.z - root.z) end
    end
    return 1.70
end

local function GetBoneHeight(ped, boneNames, fallbackRatio)
    local target = ped or PlayerPedId()
    local root = GetEntityCoords(target)
    for _, boneName in ipairs(boneNames or {}) do
        local bone = GetEntityBoneIndexByName(target, boneName)
        if bone and bone ~= -1 then
            local position = GetWorldPositionOfEntityBone(target, bone)
            if position then
                local diff = position.z - root.z
                if diff > -0.05 then return math.max(0.04, diff) end
            end
        end
    end
    return math.max(0.04, GetHeadHeight(target) * (fallbackRatio or 0.5))
end

local function GetPresetHeight(presetName, ped)
    local preset = PRESETS[presetName] or PRESETS.full
    return GetBoneHeight(ped, preset.bones, preset.ratio)
end

local function GetBonesCenter(ped, boneNames)
    local totalX, totalY, totalZ, count = 0.0, 0.0, 0.0, 0
    for _, boneName in ipairs(boneNames or {}) do
        local bone = GetEntityBoneIndexByName(ped, boneName)
        if bone and bone ~= -1 then
            local position = GetWorldPositionOfEntityBone(ped, bone)
            if position then
                totalX = totalX + position.x
                totalY = totalY + position.y
                totalZ = totalZ + position.z
                count = count + 1
            end
        end
    end
    if count > 0 then return vector3(totalX / count, totalY / count, totalZ / count) end
    return nil
end

local function GetPresetFocus(presetName, ped)
    local preset = PRESETS[presetName] or PRESETS.full
    local boneCenter = GetBonesCenter(ped, preset.bones)
    if boneCenter then return boneCenter end

    local coords = GetEntityCoords(ped)
    return vector3(coords.x, coords.y, coords.z + GetPresetHeight(presetName, ped))
end

local function GetRayHit(ped, from, to)
    local ray = StartShapeTestRay(
        from.x, from.y, from.z,
        to.x, to.y, to.z,
        CAMERA_COLLISION_FLAGS, ped, 0
    )
    local _, hit, hitCoords = GetShapeTestResult(ray)
    if (hit == 1 or hit == true) and hitCoords then return hitCoords end
    return nil
end

local function ResolveCameraCollision(ped, focus, desired)
    local dx, dy, dz = desired.x - focus.x, desired.y - focus.y, desired.z - focus.z
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length <= 0.001 then return desired end

    local nx, ny = dx / length, dy / length
    local sideX, sideY = -ny * CAMERA_ENVELOPE_RADIUS, nx * CAMERA_ENVELOPE_RADIUS
    -- Five probes approximate the camera body, so orbiting hugs collision
    -- geometry instead of allowing the camera point to cut through a prop.
    local offsets = {
        vector3(0.0, 0.0, 0.0),
        vector3(sideX, sideY, 0.0), vector3(-sideX, -sideY, 0.0),
        vector3(0.0, 0.0, CAMERA_ENVELOPE_RADIUS), vector3(0.0, 0.0, -CAMERA_ENVELOPE_RADIUS),
    }
    local safeDistance = length
    for _, offset in ipairs(offsets) do
        local hitCoords = GetRayHit(ped, focus + offset, desired + offset)
        if hitCoords then
            local hitDistance = math.sqrt(
                (hitCoords.x - (focus.x + offset.x)) ^ 2 +
                (hitCoords.y - (focus.y + offset.y)) ^ 2 +
                (hitCoords.z - (focus.z + offset.z)) ^ 2
            )
            safeDistance = math.min(safeDistance, math.max(0.01, hitDistance - CAMERA_COLLISION_PADDING))
        end
    end

    return vector3(
        focus.x + dx / length * safeDistance,
        focus.y + dy / length * safeDistance,
        focus.z + dz / length * safeDistance
    )
end

local function ResolveVerticalSurface(ped, previousCamPos, camPos)
    -- A vertical ray is also used when moving down with S.  It catches ground,
    -- furniture and other collision-bearing surfaces at the camera's X/Y.
    -- Start no higher than the previous safe camera level: this avoids a roof
    -- or other geometry above the camera being mistaken for the floor.
    local startZ = math.max(camPos.z, previousCamPos and previousCamPos.z or camPos.z) + 0.02
    local rayStart = vector3(camPos.x, camPos.y, startZ)
    local rayEnd = vector3(camPos.x, camPos.y, camPos.z - 4.0)
    local hitCoords = GetRayHit(ped, rayStart, rayEnd)
    if hitCoords then
        local safeZ = hitCoords.z + CAMERA_SURFACE_CLEARANCE
        if camPos.z < safeZ then return vector3(camPos.x, camPos.y, safeZ), true end
    end
    return camPos, false
end

local function UpdateCamera()
    if not activeCam or not DoesCamExist(activeCam) then return end
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    if activePresetName then
        desiredHeight = GetPresetHeight(activePresetName, ped)
    end

    local heading = GetEntityHeading(ped)
    local headingDelta = ((desiredPedHeading - heading + 540.0) % 360.0) - 180.0
    if math.abs(headingDelta) > 0.02 then
        SetEntityHeading(ped, (heading + headingDelta * 0.18) % 360.0)
    end

    currentOrbit = Lerp(currentOrbit, desiredOrbit, 0.22)
    currentDistance = Lerp(currentDistance, desiredDistance, 0.20)
    currentHeight = Lerp(currentHeight, desiredHeight, 0.20)
    currentFov = Lerp(currentFov, desiredFov, 0.20)

    local coords = GetEntityCoords(ped)
    local focus = activePresetName and GetPresetFocus(activePresetName, ped)
        or vector3(coords.x, coords.y, coords.z + currentHeight)
    local desiredPosition = vector3(
        focus.x + math.cos(currentOrbit) * currentDistance,
        focus.y + math.sin(currentOrbit) * currentDistance,
        focus.z + 0.04
    )
    local previousCameraPosition = GetCamCoord(activeCam)
    local cameraPosition = ResolveCameraCollision(ped, focus, desiredPosition)
    local surfaceLimited
    cameraPosition, surfaceLimited = ResolveVerticalSurface(ped, previousCameraPosition, cameraPosition)
    -- Keep the desired value at the detected surface as well.  Holding S can
    -- therefore never accumulate a hidden negative offset that would make W
    -- appear unresponsive afterwards.
    if surfaceLimited and not activePresetName then
        local surfaceHeight = cameraPosition.z - coords.z - 0.04
        currentHeight = math.max(currentHeight, surfaceHeight)
        desiredHeight = math.max(desiredHeight, surfaceHeight)
    end

    SetCamCoord(activeCam, cameraPosition.x, cameraPosition.y, cameraPosition.z)
    SetCamFov(activeCam, currentFov)
    PointCamAtCoord(activeCam, focus.x, focus.y, focus.z)
end

function Camera.Create(ped, initialPreset)
    Camera.Destroy()
    local preset = PRESETS[initialPreset] or PRESETS.full
    activePresetName = PRESETS[initialPreset] and initialPreset or "full"
    desiredOrbit, currentOrbit = math.pi, math.pi
    desiredDistance, currentDistance = preset.distance, preset.distance
    local initialHeight = GetPresetHeight(activePresetName, ped or PlayerPedId())
    desiredHeight, currentHeight = initialHeight, initialHeight
    desiredFov, currentFov = preset.fov, preset.fov
    desiredPedHeading = GetEntityHeading(ped or PlayerPedId())

    local coords = GetEntityCoords(ped or PlayerPedId())
    activeCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x - preset.distance, coords.y, coords.z + initialHeight, 0.0, 0.0, 0.0, preset.fov, false, 0)
    SetCamActive(activeCam, true)
    RenderScriptCams(true, true, 350, true, true)
    UpdateCamera()

    CreateThread(function()
        while activeCam and DoesCamExist(activeCam) do
            UpdateCamera()
            local currentPed = PlayerPedId()
            if DoesEntityExist(currentPed) then
                local p = GetEntityCoords(currentPed)
                DrawLightWithRange(p.x - 1.2, p.y - 0.8, p.z + 1.5, 255, 248, 230, 7.0, 5.0)
                DrawLightWithRange(p.x, p.y, p.z + 2.2, 255, 255, 255, 5.0, 3.5)
            end
            Wait(0)
        end
    end)
end

function Camera.SetPreset(presetName)
    local preset = PRESETS[presetName]
    if not preset or not activeCam or not DoesCamExist(activeCam) then return end
    desiredDistance = preset.distance
    activePresetName = presetName
    desiredHeight = GetPresetHeight(presetName, PlayerPedId())
    desiredFov = preset.fov
end

function Camera.RotatePed(delta)
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        desiredPedHeading = (desiredPedHeading + (tonumber(delta) or 0.0)) % 360.0
    end
end

function Camera.SetPedHeading(heading)
    desiredPedHeading = (tonumber(heading) or 90.0) % 360.0
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then SetEntityHeading(ped, desiredPedHeading) end
end

function Camera.MoveZ(delta)
    activePresetName = nil
    local ped = PlayerPedId()
    local step = (tonumber(delta) or 0.0)
    -- No artificial lower bound.  UpdateCamera resolves the requested
    -- position against the surface below it and keeps the 0.18 m clearance.
    desiredHeight = math.min(GetHeadHeight(ped) + 0.05, desiredHeight + step)
end

function Camera.Orbit(delta)
    desiredOrbit = Clamp(desiredOrbit + (tonumber(delta) or 0.0), MIN_ORBIT, MAX_ORBIT)
end

function Camera.Zoom(delta)
    desiredDistance = Clamp(desiredDistance + (tonumber(delta) or 0.0), MIN_ZOOM, MAX_ZOOM)
end

function Camera.Destroy()
    if activeCam and DoesCamExist(activeCam) then
        DestroyCam(activeCam, false)
    end
    activeCam = nil
    activePresetName = "full"
    RenderScriptCams(false, true, 350, true, true)
end
