local session, sequence = nil, 0
local keys = {'x', 'y', 'z', 'rx', 'ry', 'rz', 'sx', 'sy', 'sz'}
local function copy(value)
    local result = {}
    for _, key in ipairs(keys) do
        local fallback = key:sub(1, 1) == 's' and 1.0 or 0.0
        result[key] = tonumber(value and value[key]) or fallback
    end
    return result
end
local function constrain(value, limits)
    local result = copy(value)
    for _, key in ipairs(keys) do
        local range = limits and limits[key]
        if result[key] ~= result[key] or math.abs(result[key]) == math.huge then return nil end
        if range then result[key] = math.max(range[1], math.min(range[2], result[key])) end
    end
    return result
end
local function finish(save, reason)
    local s = session
    if not s then return end
    session = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({type = 'close'})
    if not save then pcall(s.apply, copy(s.initial)) end
    if s.finish then
        local ok, err = pcall(s.finish, save, copy(save and s.value or s.initial), reason)
        if not ok then print('[thehunt_gizmo] finish: ' .. tostring(err)) end
    end
end

-- The owner supplies local/world projection and application. No entity ownership,
-- persistence or network authority is assumed by this UI-only resource.
exports('Start', function(options)
    if session or IsNuiFocused() or type(options) ~= 'table'
        or not options.apply or not options.point then return false end
    local value = constrain(options.value, options.limits)
    if not value then return false end
    sequence = sequence + 1
    session = {
        id = sequence, owner = GetInvokingResource(), value = value, initial = copy(value),
        defaults = copy(options.defaults), limits = options.limits,
        apply = options.apply, point = options.point, valid = options.valid,
        finish = options.finish, tick = options.tick, camera = options.camera, cameraPoint = options.cameraPoint,
        cancelAction = options.cancelAction, allowRotation = options.allowRotation ~= false,
        allowScale = options.allowScale == true,
    }
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({type = 'open', id = sequence, title = options.title or 'Расположение', value = value, limits = options.limits,
        allowRotation = session.allowRotation, allowScale = session.allowScale,
        cancelAction = session.cancelAction ~= nil})
    return true
end)
exports('IsActive', function() return session ~= nil end)
exports('Cancel', function()
    if session and session.owner == GetInvokingResource() then finish(false, 'owner') end
end)

RegisterNUICallback('change', function(data, cb)
    local s = session
    if not s or data.id ~= s.id then cb({ok=false}); return end
    local value = constrain(data.reset and s.defaults or data.value, s.limits)
    if not value then cb({ok=false}); return end
    local ok, err = pcall(s.apply, value)
    if not ok then
        print('[thehunt_gizmo] apply: ' .. tostring(err))
        cb({ok=false}); finish(false, 'error'); return
    end
    s.value = value
    cb({ok=true, value=value})
end)
RegisterNUICallback('finish', function(data, cb)
    cb({ok=true})
    if session and data.id == session.id then finish(data.save == true, 'user') end
end)
RegisterNUICallback('camera', function(data, cb)
    if session and data.id == session.id and session.camera then
        local dx, dy = tonumber(data.dx) or 0, tonumber(data.dy) or 0
        pcall(session.camera, math.max(-100, math.min(100, dx)), math.max(-100, math.min(100, dy)))
    end
    cb({ok=true})
end)
RegisterNUICallback('mode', function(data, cb)
    if session and data.id == session.id and (data.mode == 'move'
        or (data.mode == 'rotate' and session.allowRotation)
        or (data.mode == 'scale' and session.allowScale)) then
        session.mode = data.mode
    end
    cb({ok=true})
end)

RegisterNUICallback('cancelAction', function(data, cb)
    cb({ok=true})
    local s = session
    if s and data.id == s.id and s.cancelAction then
        finish(false, 'action')
        pcall(s.cancelAction)
    end
end)

local function project(point)
    local visible, x, y = GetScreenCoordFromWorldCoord(point.x, point.y, point.z)
    if visible then return {x=x, y=y} end
end
CreateThread(function()
    while true do
        if not session then Wait(200) else
            local s = session
            local ok, err = pcall(function()
                if s.valid and not s.valid() then finish(false, 'invalid'); return end
                for pad = 0, 2 do
                    DisableAllControlActions(pad)
                    EnableControlAction(pad, 0xF1301666, true)
                    EnableControlAction(pad, 0x05CA7C52, true)
                end
                DisablePlayerFiring(PlayerId(), true)
                if s.tick then s.tick(s.value) end
                if GetGameTimer() < (s.nextFrame or 0) then return end
                s.nextFrame = GetGameTimer() + 33
                local origin = s.point(s.value)
                local length = 0.22
                if s.cameraPoint then
                    local camera = s.cameraPoint()
                    if camera then
                        local distance = #(camera - origin)
                        length = math.max(0.6, math.min(6.0, distance * 0.15))
                    end
                end
                local frame = {type='frame', id=s.id, origin=project(origin), axes={}, rings={}, length=length}
                local basis = {}
                for _, axis in ipairs({'x','y','z'}) do
                    local v = copy(s.value); v[axis] = v[axis] + frame.length
                    local endpoint = s.point(v)
                    frame.axes[axis] = project(endpoint)
                    basis[axis] = (endpoint-origin)/frame.length
                end
                -- Do not sample rotation rings in translation mode. Bone/world
                -- projection is affine, so four owner calls suffice for either mode.
                if s.mode == 'rotate' then
                    for _, axis in ipairs({'x','y','z'}) do
                        local a, b = axis == 'x' and 'y' or 'x', axis == 'z' and 'y' or 'z'
                        local ring = {}
                        for i = 0, 48 do
                            local t = i * math.pi * 2 / 48
                            local point = origin+basis[a]*(math.cos(t)*length*0.8)+basis[b]*(math.sin(t)*length*0.8)
                            local p = project(point)
                            if not p then ring = {}; break end
                            ring[#ring+1] = p
                        end
                        frame.rings[axis] = ring
                    end
                end
                SendNUIMessage(frame)
            end)
            if not ok then print('[thehunt_gizmo] frame: ' .. tostring(err)); finish(false, 'error') end
            Wait(0)
        end
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if session and (resource == GetCurrentResourceName() or resource == session.owner) then finish(false, 'stop') end
end)
