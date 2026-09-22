--[[
  RootsFx — visual-only ethereal roots / blue ribbons for Thorns.
  Does NOT freeze, animate-bind, or own gameplay stun state.
]]

RootsFx = RootsFx or {}

local CFG = RootsFxConfig or {}
local active = {}
local propCount = 0
local loopOn = false
local ptfxOk = false

local HAND_L = { "skel_l_hand", "SKEL_L_Hand", "SKEL_L_HAND" }
local HAND_R = { "skel_r_hand", "SKEL_R_Hand", "SKEL_R_HAND" }

------------------------------------------------------------
-- utils
------------------------------------------------------------
local function cfg(k, d)
    local v = CFG[k]
    if v == nil then return d end
    return v
end

local function clamp01(t)
    if t <= 0.0 then return 0.0 end
    if t >= 1.0 then return 1.0 end
    return t
end

local function smooth(t)
    t = clamp01(t)
    return t * t * (3.0 - 2.0 * t)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function okNum(n)
    return type(n) == "number" and n == n and math.abs(n) < 50000.0
end

local function rotXY(heading, ox, oy)
    local r = math.rad(heading or 0.0)
    local c, s = math.cos(r), math.sin(r)
    return ox * c - oy * s, ox * s + oy * c
end

local function bez(p0, p1, p2, p3, t)
    local u = 1.0 - t
    local uu, tt = u * u, t * t
    return p0 * (uu * u) + p1 * (3.0 * uu * t) + p2 * (3.0 * u * tt) + p3 * (tt * t)
end

------------------------------------------------------------
-- assets
------------------------------------------------------------
local function requestModel(name)
    if not name or name == "" then return nil end
    local hash = joaat(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local untilAt = GetGameTimer() + cfg("modelTimeoutMs", 2000)
    while not HasModelLoaded(hash) and GetGameTimer() < untilAt do
        Wait(0)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function requestModelAny(primary, list)
    local h = requestModel(primary)
    if h then return h end
    for i = 1, #(list or {}) do
        h = requestModel(list[i])
        if h then return h end
    end
    return nil
end

local function requestPtfx()
    if ptfxOk then return true end
    local dict = (CFG.ptfx and CFG.ptfx.dict) or "core"
    local hash = joaat(dict)
    if Citizen.InvokeNative(0x65BB72F29138F5D6, hash) then
        ptfxOk = true
        return true
    end
    Citizen.InvokeNative(0xF2B2353BBC0D4E8F, hash)
    local untilAt = GetGameTimer() + cfg("ptfxTimeoutMs", 2000)
    while not Citizen.InvokeNative(0x65BB72F29138F5D6, hash) and GetGameTimer() < untilAt do
        Wait(0)
    end
    local v = Citizen.InvokeNative(0x65BB72F29138F5D6, hash)
    ptfxOk = (v == 1 or v == true)
    return ptfxOk
end

local function burstPtfx(fxName, x, y, z, scale)
    if not requestPtfx() then return end
    local dict = (CFG.ptfx and CFG.ptfx.dict) or "core"
    Citizen.InvokeNative(0xA10DB07FC234DD12, dict)
    StartParticleFxNonLoopedAtCoord(fxName, x, y, z, 0.0, 0.0, 0.0, scale or 0.3, false, false, false)
end

local function getGround(x, y, refZ)
    local found, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (refZ or 0.0) + 2.0, false)
    if found and okNum(gz) then return gz end
    local handle = StartShapeTestRay(x, y, (refZ or 0.0) + 3.0, x, y, (refZ or 0.0) - 5.0, 17, 0, 0)
    local st, hit, coords = GetShapeTestResult(handle)
    local n = 0
    while st == 1 and n < 6 do
        Wait(0)
        st, hit, coords = GetShapeTestResult(handle)
        n = n + 1
    end
    if (hit == 1 or hit == true) and coords and okNum(coords.z) then
        return coords.z
    end
    return refZ or 0.0
end

------------------------------------------------------------
-- objects
------------------------------------------------------------
local function delObj(obj)
    if not obj or obj == 0 then return end
    if DoesEntityExist(obj) then
        pcall(function()
            if IsEntityAttached(obj) then
                DetachEntity(obj, true, true)
            end
        end)
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
        propCount = math.max(0, propCount - 1)
    end
end

local function makeObj(hash, x, y, z, frozen)
    if propCount >= ((CFG.limits and CFG.limits.maxProps) or 28) then return 0 end
    if not (okNum(x) and okNum(y) and okNum(z)) then return 0 end
    local ok, obj = pcall(CreateObject, hash, x, y, z, false, false, false, false, true)
    if not ok or not obj or obj == 0 then return 0 end
    SetEntityAsMissionEntity(obj, true, false)
    SetEntityCollision(obj, false, false)
    if frozen then FreezeEntityPosition(obj, true) end
    propCount = propCount + 1
    return obj
end

local function growZs(hash, gz)
    local minD, maxD = GetModelDimensions(hash)
    if not minD or not maxD then
        -- fallback: sit roughly on ground
        return gz - 0.25, gz
    end
    if CFG.groundSit == true then
        -- place so model base rests on ground; tiny burrow only for pop-in
        local bur = math.max(0.0, cfg("rootBurrow", 0.08))
        local zOn = gz - minD.z
        return zOn - bur, zOn
    end
    local h = maxD.z - minD.z
    local vis = math.min(h, cfg("visibleRootHeight", 0.55))
    local bur = cfg("rootBurrow", 0.12)
    return gz - maxD.z - bur, gz - maxD.z + vis
end

local function moveZ(obj, z)
    if obj and DoesEntityExist(obj) and okNum(z) then
        local c = GetEntityCoords(obj)
        SetEntityCoords(obj, c.x, c.y, z, false, false, false, false)
    end
end

local function findBone(ped, names)
    for i = 1, #names do
        local idx = GetEntityBoneIndexByName(ped, names[i])
        if idx and idx ~= -1 then return idx end
    end
    return -1
end

local function bonePos(ped, names)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local idx = findBone(ped, names)
    if idx == -1 then return nil end
    local p = GetWorldPositionOfEntityBone(ped, idx)
    if not p or not okNum(p.x) then return nil end
    return p
end

local function line(x1, y1, z1, x2, y2, z2, r, g, b, a)
    if not (okNum(x1) and okNum(y1) and okNum(z1) and okNum(x2) and okNum(y2) and okNum(z2)) then
        return false
    end
    local ok = pcall(DrawLine, x1, y1, z1, x2, y2, z2, r, g, b, a)
    return ok == true
end

------------------------------------------------------------
-- target resolve (ped handle OR netId)
------------------------------------------------------------
local function getPed(fx)
    if fx.targetPed and fx.targetPed ~= 0 and DoesEntityExist(fx.targetPed) then
        return fx.targetPed
    end
    local nid = fx.targetNetId
    if nid and nid ~= 0 and NetworkDoesNetworkIdExist(nid) then
        local ped = NetworkGetEntityFromNetworkId(nid)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            fx.targetPed = ped
            return ped
        end
    end
    return 0
end

local function wipeProps(fx)
    fx.gen = (fx.gen or 0) + 1
    fx.building = false
    for i = 1, #(fx.roots or {}) do
        delObj(fx.roots[i].obj)
        fx.roots[i].obj = 0
    end
    fx.roots = {}
    for i = 1, #(fx.wraps or {}) do
        delObj(fx.wraps[i])
        fx.wraps[i] = 0
    end
    fx.wraps = {}
    delObj(fx.rope)
    fx.rope = 0
    fx.propsBuilt = false
    fx.etherUntil = 0
    fx.releaseLeavesDone = false
end

local function stopSameTarget(netId, ped)
    for id, fx in pairs(active) do
        local same = false
        if ped and ped ~= 0 and fx.targetPed == ped then
            same = true
        elseif netId and netId ~= 0 and fx.targetNetId == netId then
            same = true
        end
        if same then
            wipeProps(fx)
            active[id] = nil
        end
    end
end

local function bestAnchor(fx, hand)
    local best, bestD = nil, 1e9
    for i = 1, #(fx.roots or {}) do
        local r = fx.roots[i]
        if r.anchor and not r.isThorn and not r.isVine then
            local d = #(hand - r.anchor)
            if d < bestD then bestD, best = d, r.anchor end
        end
    end
    if best then return best end
    return vector3(fx.x, fx.y, (fx.z or 0.0) + 0.05)
end

-- prefer a ground point on the correct body side (avoids crotch cluster)
local function sideAnchor(fx, ped, sideSign, right)
    local feet = GetEntityCoords(ped)
    local prefer = vector3(
        feet.x + right.x * sideSign * 0.38,
        feet.y + right.y * sideSign * 0.38,
        (fx.z or feet.z) + 0.04
    )
    local best, bestD = nil, 1e9
    for i = 1, #(fx.roots or {}) do
        local r = fx.roots[i]
        if r.anchor and not r.isThorn and not r.isVine then
            local d = #(prefer - r.anchor)
            -- also require anchor to be on the same side of ped
            local sideDot = (r.anchor.x - feet.x) * right.x + (r.anchor.y - feet.y) * right.y
            if sideDot * sideSign >= -0.05 and d < bestD then
                bestD, best = d, r.anchor
            end
        end
    end
    if best then
        return vector3(best.x, best.y, best.z + 0.02)
    end
    local gz = prefer.z
    return vector3(prefer.x, prefer.y, gz)
end

------------------------------------------------------------
-- living roots sequence
------------------------------------------------------------
local function stillActive(fx, gen)
    return fx and active[fx.id] == fx and fx.gen == gen and fx.phase ~= "done"
end

local function attachWrap(fx, ped, boneNames, modelName, falls)
    if not ped or not DoesEntityExist(ped) then return 0 end
    local bone = findBone(ped, boneNames or {})
    if bone == -1 then return 0 end
    local hash = requestModelAny(modelName, falls)
    if not hash then return 0 end
    local c = GetEntityCoords(ped)
    local obj = makeObj(hash, c.x, c.y, c.z, false)
    if obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return 0
    end
    local wp = CFG.wrapPreview or {}
    local pos = wp.pos or { x = 0.0, y = 0.0, z = 0.0 }
    local rot = wp.rot or { x = 0.0, y = 0.0, z = 0.0 }
    local ok = pcall(AttachEntityToEntity, obj, ped, bone, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 0, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ok then
        delObj(obj)
        return 0
    end
    return obj
end

local function spawnProps(fx, ped, gen)
    if fx.propsBuilt or fx.building then return end
    fx.building = true

    local models = CFG.models or {}
    local seq = CFG.sequence or {}
    local offsets = CFG.rootOffsets or {
        { x = -0.42, y = 0.12 },
        { x = 0.42, y = 0.12 },
    }
    local names = {
        models.rootA or "rdr_bush_dry_thin_aa_sim",
        models.rootB or "rdr_bush_brush_dead_aa_sim",
    }
    local falls = models.rootFallback or {
        "rdr_bush_dry_thin_aa_sim",
        "rdr_bush_brush_dead_aa_sim",
        "p_tumbleweed01x",
    }
    local pt = CFG.ptfx or {}
    local wrapCfg = CFG.wrapPreview or {}
    local dirtAt = seq.dirtAt or 0
    local rootsAt = seq.rootsStartAt or 100
    local growMs = seq.rootsGrowMs or cfg("growMs", 350)
    local wrapLegsAt = seq.wrapLegsAt or 320
    local wrapHandsAt = seq.wrapHandsAt or 480
    local etherStart = seq.etherStartAt or 450
    local etherEnd = seq.etherEndAt or 780
    local midDirtAt = seq.midDirtAt or 260

    CreateThread(function()
        local t0 = fx.t0 or GetGameTimer()
        local function waitUntil(msFromStart)
            local target = t0 + msFromStart
            while GetGameTimer() < target do
                if not stillActive(fx, gen) then return false end
                Wait(0)
            end
            return stillActive(fx, gen)
        end

        -- 0ms: dirt burst at future root spots
        if not waitUntil(dirtAt) then
            fx.building = false
            return
        end

        local spots = {}
        local refZ = fx.z or 0.0
        for i = 1, #offsets do
            local off = offsets[i]
            local wx, wy = rotXY(fx.heading, off.x, off.y)
            local ax, ay = fx.x + wx, fx.y + wy
            local gz = getGround(ax, ay, refZ)
            spots[i] = { x = ax, y = ay, z = gz }
            burstPtfx(pt.dirt or "ent_dst_dirt", ax, ay, gz + 0.03, pt.dirtScale or 0.30)
        end

        -- create roots under surface
        if not waitUntil(rootsAt) then
            fx.building = false
            return
        end

        local roots = {}
        for i = 1, #spots do
            if not stillActive(fx, gen) then break end
            local sp = spots[i]
            local hash = requestModelAny(names[((i - 1) % #names) + 1], falls)
            if not stillActive(fx, gen) then
                if hash then SetModelAsNoLongerNeeded(hash) end
                break
            end
            if hash then
                local z0, z1 = growZs(hash, sp.z)
                local obj = makeObj(hash, sp.x, sp.y, z0, true)
                if obj ~= 0 then
                    local yaw0 = (fx.heading or 0.0) + ((i - 2) * 14.0)
                    SetEntityHeading(obj, yaw0)
                    roots[#roots + 1] = {
                        obj = obj, ax = sp.x, ay = sp.y, gz = sp.z,
                        z0 = z0, z1 = z1,
                        yaw0 = yaw0,
                        yaw1 = yaw0 + (cfg("growTwistDeg", 18.0) * ((i % 2 == 0) and 1.0 or -1.0)),
                        anchor = vector3(sp.x, sp.y, sp.z + cfg("anchorLift", 0.05)),
                    }
                end
                SetModelAsNoLongerNeeded(hash)
            end
        end

        if not stillActive(fx, gen) then
            for j = 1, #roots do delObj(roots[j].obj) end
            fx.building = false
            return
        end

        fx.roots = roots
        fx.wraps = {}
        fx.propsBuilt = true
        fx.building = false
        fx.growStart = GetGameTimer()
        fx.growMs = growMs
        fx.etherFrom = t0 + etherStart
        fx.etherUntil = t0 + etherEnd

        -- second dirt kick while stock is still pushing up
        CreateThread(function()
            if not waitUntil(midDirtAt) then return end
            if not stillActive(fx, gen) then return end
            for i = 1, #spots do
                local sp = spots[i]
                burstPtfx(pt.dirt or "ent_dst_dirt", sp.x, sp.y, sp.z + 0.05, pt.midDirtScale or 0.22)
            end
        end)

        -- optional stock wrap preview on bones (off by default — needs custom .ydr for real look)
        if wrapCfg.enabled == true and ped and DoesEntityExist(ped) then
            CreateThread(function()
                if not waitUntil(wrapLegsAt) then return end
                if not stillActive(fx, gen) then return end
                local wrapModel = models.wrapPreview or "p_cs_gua_vines03x"
                local wrapFalls = models.wrapFallback or { "p_cs_roots_01x" }
                local l = attachWrap(fx, ped, wrapCfg.legBoneL, wrapModel, wrapFalls)
                local r = attachWrap(fx, ped, wrapCfg.legBoneR, wrapModel, wrapFalls)
                if stillActive(fx, gen) then
                    if l ~= 0 then fx.wraps[#fx.wraps + 1] = l end
                    if r ~= 0 then fx.wraps[#fx.wraps + 1] = r end
                else
                    delObj(l)
                    delObj(r)
                    return
                end

                if not waitUntil(wrapHandsAt) then return end
                if not stillActive(fx, gen) then return end
                local hl = attachWrap(fx, ped, wrapCfg.handBoneL, wrapModel, wrapFalls)
                local hr = attachWrap(fx, ped, wrapCfg.handBoneR, wrapModel, wrapFalls)
                if stillActive(fx, gen) then
                    if hl ~= 0 then fx.wraps[#fx.wraps + 1] = hl end
                    if hr ~= 0 then fx.wraps[#fx.wraps + 1] = hr end
                else
                    delObj(hl)
                    delObj(hr)
                end
            end)
        end
    end)
end

local function growEase(t)
    t = clamp01(t)
    local over = cfg("growOvershoot", 0.0)
    if over <= 0.0 then
        return smooth(t)
    end
    if t < 0.72 then
        return smooth(t / 0.72) * (1.0 + over)
    end
    local u = smooth((t - 0.72) / 0.28)
    return lerp(1.0 + over, 1.0, u)
end

local function liftRoots(fx, t)
    local tt = growEase(t)
    local over = cfg("growOvershoot", 0.0)
    for i = 1, #(fx.roots or {}) do
        local r = fx.roots[i]
        if r.obj and DoesEntityExist(r.obj) then
            moveZ(r.obj, lerp(r.z0, r.z1, math.min(tt, 1.0 + over)))
            if r.yaw0 and r.yaw1 then
                SetEntityHeading(r.obj, lerp(r.yaw0, r.yaw1, clamp01(t)))
            end
        end
    end
end

local function buryRoots(fx, t)
    for i = 1, #(fx.roots or {}) do
        local r = fx.roots[i]
        if r.obj and DoesEntityExist(r.obj) then
            moveZ(r.obj, lerp(r.z1, r.z0, t))
        end
    end
end

local function releaseLeaves(fx)
    if fx.releaseLeavesDone then return end
    fx.releaseLeavesDone = true
    local pt = CFG.ptfx or {}
    for i = 1, #(fx.roots or {}) do
        local r = fx.roots[i]
        if r.gz then
            burstPtfx(pt.leaves or "ent_col_bush_leaves", r.ax, r.ay, r.gz + 0.12, pt.leavesScale or 0.25)
        end
    end
end

------------------------------------------------------------
-- draw (ethereal DrawPoly ribbons — DrawLine path disabled)
------------------------------------------------------------
local function vNorm(v)
    local m = #(v)
    if m < 0.0001 then return vector3(0.0, 0.0, 1.0), 0.0 end
    return v / m, m
end

local function vCross(a, b)
    return vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

local function okVec(v)
    return v and okNum(v.x) and okNum(v.y) and okNum(v.z)
end

local function ribbonSide(a, b, cam)
    if not (okVec(a) and okVec(b) and okVec(cam)) then
        return nil
    end
    local tan, len = vNorm(b - a)
    if len < 0.0008 then
        return nil
    end
    local mid = (a + b) * 0.5
    local view, vlen = vNorm(cam - mid)
    if vlen < 0.0008 then
        view = vector3(0.0, 0.0, 1.0)
    end
    local side = vCross(tan, view)
    if #(side) < 0.0001 then
        side = vCross(tan, vector3(0.0, 0.0, 1.0))
    end
    if #(side) < 0.0001 then
        side = vCross(tan, vector3(1.0, 0.0, 0.0))
    end
    if #(side) < 0.0001 then
        return nil
    end
    local n = vNorm(side)
    return n
end

local function drawPolySafe(ax, ay, az, bx, by, bz, cx, cy, cz, r, g, b, a)
    if not (okNum(ax) and okNum(ay) and okNum(az) and okNum(bx) and okNum(by) and okNum(bz)
        and okNum(cx) and okNum(cy) and okNum(cz)) then
        return false
    end
    local abx, aby, abz = bx - ax, by - ay, bz - az
    local acx, acy, acz = cx - ax, cy - ay, cz - az
    local cxp = aby * acz - abz * acy
    local cyp = abz * acx - abx * acz
    local czp = abx * acy - aby * acx
    if (cxp * cxp + cyp * cyp + czp * czp) < 1.0e-10 then
        return false
    end
    -- RedM: try both the Lua name and the native hash
    local ok = pcall(DrawPoly, ax, ay, az, bx, by, bz, cx, cy, cz, r, g, b, a)
    if not ok then
        ok = pcall(Citizen.InvokeNative, 0xAC26716048436851, ax, ay, az, bx, by, bz, cx, cy, cz, r, g, b, a)
    end
    return ok == true
end

-- camera-facing ribbon segment: both windings (DrawPoly is single-sided)
local function drawPolySeg(a, b, side, fullWidth, col, budget)
    if budget < 4 or not side or not col then
        return budget
    end
    local half = (fullWidth or 0.0) * 0.5
    if half < 0.001 then
        return budget
    end
    if not (okVec(a) and okVec(b)) then
        return budget
    end
    local aL = a - side * half
    local aR = a + side * half
    local bL = b - side * half
    local bR = b + side * half
    local r, g, bl, al = col.r or 255, col.g or 255, col.b or 255, col.a or 200
    -- front
    if drawPolySafe(aL.x, aL.y, aL.z, bL.x, bL.y, bL.z, bR.x, bR.y, bR.z, r, g, bl, al) then
        budget = budget - 1
    end
    if budget > 0 and drawPolySafe(aL.x, aL.y, aL.z, bR.x, bR.y, bR.z, aR.x, aR.y, aR.z, r, g, bl, al) then
        budget = budget - 1
    end
    -- back (reverse winding)
    if budget > 0 and drawPolySafe(bR.x, bR.y, bR.z, bL.x, bL.y, bL.z, aL.x, aL.y, aL.z, r, g, bl, al) then
        budget = budget - 1
    end
    if budget > 0 and drawPolySafe(aR.x, aR.y, aR.z, bR.x, bR.y, bR.z, aL.x, aL.y, aL.z, r, g, bl, al) then
        budget = budget - 1
    end
    return budget
end

-- RedM-reliable thickness: dense parallel DrawLines + depth layers
local function drawLineFat(a, b, side, fullWidth, col, strands, budget, upAxis, depthLayers, depthStep)
    if budget <= 0 or not side or not col or not (okVec(a) and okVec(b)) then
        return budget
    end
    local n = math.max(1, strands or 3)
    local half = (fullWidth or 0.04) * 0.5
    local r, g, bl, al = col.r or 255, col.g or 255, col.b or 255, col.a or 200
    local layers = math.max(1, depthLayers or 1)
    local step = depthStep or 0.006
    local up = upAxis
    if not up or #(up) < 0.0001 then
        up = vector3(0.0, 0.0, 1.0)
    end
    for d = 0, layers - 1 do
        local dz = (layers == 1) and 0.0 or ((d / (layers - 1)) * 2.0 - 1.0) * step * (layers - 1) * 0.5
        local shift = up * dz
        for i = 0, n - 1 do
            if budget <= 0 then return budget end
            local u = (n == 1) and 0.0 or ((i / (n - 1)) * 2.0 - 1.0)
            -- denser middle: ease u toward center packing
            local packed = u * (0.55 + 0.45 * math.abs(u))
            local o = side * (half * packed) + shift
            if line(a.x + o.x, a.y + o.y, a.z + o.z, b.x + o.x, b.y + o.y, b.z + o.z, r, g, bl, al) then
                budget = budget - 1
            end
        end
    end
    return budget
end

local FOOT_L = { 'skel_l_foot', 'SKEL_L_Foot', 'skel_l_ankle', 'SKEL_L_Ankle' }
local FOOT_R = { 'skel_r_foot', 'SKEL_R_Foot', 'skel_r_ankle', 'SKEL_R_Ankle' }
local CALF_L = { 'skel_l_calf', 'SKEL_L_Calf' }
local CALF_R = { 'skel_r_calf', 'SKEL_R_Calf' }
local THIGH_L = { 'skel_l_thigh', 'SKEL_L_Thigh' }
local THIGH_R = { 'skel_r_thigh', 'SKEL_R_Thigh' }

local function pedAxes(ped)
    local h = math.rad(GetEntityHeading(ped) or 0.0)
    local fwd = vector3(-math.sin(h), math.cos(h), 0.0)
    local right = vector3(math.cos(h), math.sin(h), 0.0)
    return fwd, right
end

local function softLine(a, b, col, budget)
    if budget <= 0 or not (okVec(a) and okVec(b) and col) then
        return budget
    end
    if line(a.x, a.y, a.z, b.x, b.y, b.z, col.r or 255, col.g or 255, col.b or 255, col.a or 180) then
        return budget - 1
    end
    return budget
end

-- sample a point along one leg (ankle -> calf -> thigh), always outside
local function legPoint(ped, sideSign, t, fwd, right)
    local foot = bonePos(ped, sideSign < 0 and FOOT_L or FOOT_R)
    local calf = bonePos(ped, sideSign < 0 and CALF_L or CALF_R)
    local thigh = bonePos(ped, sideSign < 0 and THIGH_L or THIGH_R)
    local c = GetEntityCoords(ped)
    local out = right * sideSign
    if not foot then foot = c + out * 0.18 + vector3(0, 0, 0.05) end
    if not calf then calf = foot + vector3(0, 0, 0.38) end
    if not thigh then thigh = calf + vector3(0, 0, 0.38) end
    local base
    if t < 0.45 then
        base = foot + (calf - foot) * (t / 0.45)
    else
        base = calf + (thigh - calf) * ((t - 0.45) / 0.55)
    end
    return base, out, -fwd
end

--[[
  Living nature bind: a soft glowing spiral around each leg.
  Only 2 lines (vine + core) — reads as energy, not a laser cage.
]]
local function drawLegSpiral(ped, sideSign, full, budget, age, lv)
    local fwd, right = pedAxes(ped)
    local segs = full and (lv.legSegs or 18) or 12
    local turns = lv.legTurns or 2.15
    local baseR = lv.legRadius or 0.13
    local rPulse = lv.legRadiusPulse or 0.018
    local grow = smooth(math.min(1.0, age / 0.45))
    local pulseT = 0.0
    local period = (lv.pulsePeriodMs or 1400) * 0.001
    if period > 0.05 then
        pulseT = (age % period) / period
    end

    local vine = lv.vineColor or { r = 48, g = 92, b = 52, a = 130 }
    local flow = lv.flowColor or { r = 110, g = 160, b = 85, a = 175 }
    local core = lv.coreColor or { r = 210, g = 235, b = 170, a = 220 }

    local prev, prevT
    local maxS = math.floor(segs * grow)
    for s = 0, maxS do
        if budget < 2 then break end
        local t = s / segs
        local base, out, back = legPoint(ped, sideSign, t, fwd, right)
        local ang = t * turns * math.pi * 2.0 + age * (lv.waveSpeed or 1.35) * sideSign
        local rad = baseR + math.sin(age * 2.1 + t * 6.0) * rPulse
        -- breathe the spiral so it feels alive
        rad = rad * (1.0 + 0.06 * math.sin(age * 1.7 + sideSign))
        local pt = base + out * math.cos(ang) * rad + back * math.sin(ang) * rad
        -- slight lift so it sits on boot/pant surface
        pt = pt + vector3(0.0, 0.0, 0.02)

        if prev and okVec(prev) and okVec(pt) then
            local onPulse = math.abs(t - pulseT) < 0.08
            local mid = flow
            local hi = core
            if onPulse then
                mid = { r = math.min(255, flow.r + 30), g = math.min(255, flow.g + 25), b = flow.b, a = math.min(255, (flow.a or 175) + 40) }
                hi = { r = 235, g = 250, b = 200, a = 255 }
            end
            -- soft outer vine + bright life core (2 lines only)
            budget = softLine(prev, pt, vine, budget)
            budget = softLine(prev, pt, mid, budget)
            if onPulse or full then
                budget = softLine(prev, pt, hi, budget)
            end
        end
        prev, prevT = pt, t
    end
    return budget
end

-- soft energy ring around cuffed wrists
local function drawWristBind(ped, full, budget, age, lv)
    local lh, rh = bonePos(ped, HAND_L), bonePos(ped, HAND_R)
    if not (lh and rh) then return budget end
    local mid = (lh + rh) * 0.5
    local fwd, right = pedAxes(ped)
    local segs = full and (lv.wristSegs or 12) or 8
    local rad = (lv.wristRadius or 0.11) * (1.0 + 0.08 * math.sin(age * 2.4))
    local spin = age * 1.1
    local vine = lv.vineColor or { r = 48, g = 92, b = 52, a = 130 }
    local core = lv.coreColor or { r = 210, g = 235, b = 170, a = 220 }
    local prev
    for s = 0, segs do
        if budget < 2 then break end
        local t = s / segs
        local ang = spin + t * math.pi * 2.0
        local pt = mid + right * math.cos(ang) * rad + fwd * math.sin(ang) * (rad * 0.55) + vector3(0, 0, math.sin(ang * 2.0) * 0.015)
        if prev then
            budget = softLine(prev, pt, vine, budget)
            budget = softLine(prev, pt, core, budget)
        end
        prev = pt
    end
    return budget
end

-- floating life wisps rising from the roots / feet
local function drawEnergyWisps(ped, full, budget, age, seed, lv)
    local n = full and (lv.wispCount or 5) or 3
    local feet = GetEntityCoords(ped)
    local fwd, right = pedAxes(ped)
    local col = lv.wispColor or { r = 180, g = 210, b = 140, a = 140 }
    for i = 1, n do
        if budget < 1 then break end
        local phase = seed * 0.01 + i * 1.7
        local life = (age * 0.35 + phase) % 1.0
        local side = ((i % 2 == 0) and 1.0 or -1.0)
        local orbit = life * math.pi * 2.0 + phase
        local rad = 0.22 + 0.10 * math.sin(phase)
        local a = feet + right * (math.cos(orbit) * rad * side) + fwd * (math.sin(orbit) * rad * 0.6)
            + vector3(0, 0, 0.08 + life * 0.95)
        local b = a + vector3(
            math.sin(orbit + 0.4) * 0.04,
            math.cos(orbit + 0.4) * 0.04,
            0.06 + 0.03 * math.sin(age * 3.0 + i)
        )
        local alpha = math.floor((col.a or 140) * (1.0 - life) * (0.35 + 0.65 * math.sin(life * math.pi)))
        if alpha > 25 then
            budget = softLine(a, b, { r = col.r, g = col.g, b = col.b, a = alpha }, budget)
        end
    end
    return budget
end

local function drawLivingEnergy(fx, ped, full, budget, cam)
    local lv = CFG.living or {}
    if lv.enabled == false then
        return budget
    end
    local age = (GetGameTimer() - fx.t0) * 0.001
    budget = drawLegSpiral(ped, -1.0, full, budget, age, lv)
    budget = drawLegSpiral(ped, 1.0, full, budget, age, lv)
    budget = drawWristBind(ped, full, budget, age, lv)
    budget = drawEnergyWisps(ped, full, budget, age, fx.seed or 1, lv)
    return budget
end

local function auraBurst(fx, ped)
    local pt = CFG.ptfx or {}
    local every = pt.auraEveryMs or 1600
    local now = GetGameTimer()
    if now < (fx.nextAura or 0) then return end
    fx.nextAura = now + every
    local c = GetEntityCoords(ped)
    burstPtfx(pt.leaves or 'ent_col_bush_leaves', c.x, c.y, c.z + 0.15, pt.leavesScale or 0.30)
    burstPtfx(pt.plant or 'ent_dst_plant_leaves', c.x, c.y, c.z + 0.05, pt.plantScale or 0.22)
end

local function getGroundFast(x, y, refZ)
    local found, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (refZ or 0.0) + 2.0, false)
    if found and okNum(gz) then return gz end
    return refZ or 0.0
end

local SPINE = { 'skel_spine2', 'SKEL_Spine2', 'SKEL_SPINE2', 'skel_spine1', 'SKEL_Spine1', 'skel_pelvis', 'SKEL_PELVIS' }

local function bodyCenter(ped)
    local spine = bonePos(ped, SPINE)
    if spine then return spine end
    return GetEntityCoords(ped) + vector3(0.0, 0.0, 0.85)
end

local function drawBodyWrap(fx, ped, full, budget, cam)
    local bw = CFG.bodyWrap
    if not bw or bw.enabled == false then return budget end
    return budget
end

local function drawRing(fx, ped, budget)
    local ring = CFG.footRing
    if not ring or ring.enabled == false then return budget end
    local c = GetEntityCoords(ped)
    local gz = getGroundFast(c.x, c.y, c.z)
    local rad = (ring.radius or 0.55) * (1.0 + math.sin(GetGameTimer() * 0.004 + (fx.seed or 0)) * 0.08)
    local segs = ring.segments or 20
    local col = ring.color or { r = 55, g = 130, b = 255, a = 150 }
    for i = 1, segs do
        local a1 = (i / segs) * math.pi * 2.0
        local a2 = ((i % segs) + 1) / segs * math.pi * 2.0
        local x1, y1 = c.x + math.cos(a1) * rad, c.y + math.sin(a1) * rad
        local x2, y2 = c.x + math.cos(a2) * rad, c.y + math.sin(a2) * rad
        if line(x1, y1, gz + 0.045, x2, y2, gz + 0.045, col.r, col.g, col.b, col.a) then
            budget = budget - 1
        end
        if budget <= 0 then break end
    end
    return budget
end

local function drawSparks(fx, ped, budget)
    local sc = CFG.sparks or {}
    if (sc.count or 0) < 1 then return budget end
    local col = sc.color or { r = 180, g = 220, b = 255, a = 210 }
    local now = GetGameTimer()
    if not fx.sparks then
        fx.sparks = {}
        for i = 1, (sc.count or 6) do
            fx.sparks[i] = {
                t = math.random(),
                life = math.random(sc.minLifeMs or 280, sc.maxLifeMs or 480),
                born = now - math.random(0, 200),
                len = lerp(sc.minLen or 0.03, sc.maxLen or 0.07, math.random()),
                side = math.random() < 0.5 and -1.0 or 1.0,
            }
        end
    end
    local lh, rh = bonePos(ped, HAND_L), bonePos(ped, HAND_R)
    if not lh or not rh then return budget end
    local mid = (lh + rh) * 0.5
    for i = 1, #fx.sparks do
        local sp = fx.sparks[i]
        local age = now - sp.born
        if age >= sp.life then
            sp.born, sp.t, age = now, math.random(), 0
            sp.life = math.random(sc.minLifeMs or 280, sc.maxLifeMs or 480)
            sp.len = lerp(sc.minLen or 0.03, sc.maxLen or 0.07, math.random())
        end
        local lt = age / sp.life
        local a = math.floor(col.a * (1.0 - lt))
        if a > 20 then
            local p0 = bestAnchor(fx, mid)
            local p = bez(p0, p0 + vector3(0, 0, 0.35), mid + vector3(0, 0, -0.12), mid, sp.t)
            if line(p.x, p.y, p.z, p.x + sp.side * sp.len, p.y, p.z + lt * 0.08, col.r, col.g, col.b, a) then
                budget = budget - 1
            end
        end
        if budget <= 0 then break end
    end
    return budget
end

local function inRibbonWindow(fx, now)
    local rb = CFG.ribbon or {}
    local lc = CFG.light or {}
    if not rb.etherOnly and not (lc.etherOnly) then
        return true
    end
    if now >= (fx.etherFrom or 0) and now <= (fx.etherUntil or 0) then
        return true
    end
    local every = rb.pulseEveryMs or 0
    if every <= 0 or now <= (fx.etherUntil or 0) then
        return false
    end
    local since = now - (fx.etherUntil or fx.t0)
    if since <= 0 then
        return false
    end
    local hold = rb.pulseMs or 700
    return (since % every) < hold
end

local function drawGlow(fx, ped)
    local lc = CFG.light or {}
    if lc.enabled == false then return end
    local now = GetGameTimer()
    if lc.etherOnly and not inRibbonWindow(fx, now) then
        return
    end
    local f = 1.0 + math.sin(now * 0.004 + (fx.seed or 0)) * (lc.flicker or 0.06)
    local inten = (lc.intensity or 0.70) * f
    local rad = lc.radius or 0.70
    local r, g, b = lc.r or 140, lc.g or 190, lc.b or 110

    if lc.atFeet then
        local c = GetEntityCoords(ped)
        pcall(DrawLightWithRange, c.x, c.y, c.z + 0.15, r, g, b, rad * 1.15, inten * 0.85)
    end

    local lh, rh = bonePos(ped, HAND_L), bonePos(ped, HAND_R)
    if lc.atHands then
        if lh and okNum(lh.x) then
            pcall(DrawLightWithRange, lh.x, lh.y, lh.z, r, g, b, rad * 0.75, inten)
        end
        if rh and okNum(rh.x) then
            pcall(DrawLightWithRange, rh.x, rh.y, rh.z, r, g, b, rad * 0.75, inten)
        end
        return
    end

    local mid
    if lh and rh then
        mid = (lh + rh) * 0.5 + vector3(0, 0, -0.05)
    else
        mid = GetEntityCoords(ped) + vector3(0, 0, 0.85)
    end
    if not okNum(mid.x) then return end
    pcall(DrawLightWithRange, mid.x, mid.y, mid.z, r, g, b, rad, inten)
end

------------------------------------------------------------
-- tick / loop
------------------------------------------------------------
local function tick(fx, now, cam, dist, budget, lights, ribbons)
    if fx.phase == "done" then
        return budget, lights, ribbons
    end

    local ped = getPed(fx)
    local lim = CFG.limits or {}
    local sinkMs = cfg("sinkMs", 350)

    if ped ~= 0 then
        if IsPedDeadOrDying(ped, true) and fx.phase == "active" then
            fx.tEnd = now
        end
        if not fx.propsBuilt then
            local c = GetEntityCoords(ped)
            fx.x, fx.y, fx.z = c.x, c.y, c.z
            fx.heading = GetEntityHeading(ped)
        end
    end

    if now >= fx.tEnd and fx.phase ~= "sinking" then
        fx.phase = "sinking"
        fx.tSink = now
        releaseLeaves(fx)
        -- hide wraps immediately on release
        for i = 1, #(fx.wraps or {}) do
            delObj(fx.wraps[i])
            fx.wraps[i] = 0
        end
        fx.wraps = {}
        fx.etherUntil = 0
    end

    if fx.phase == "sinking" then
        local t = smooth((now - (fx.tSink or now)) / sinkMs)
        buryRoots(fx, t)
        if t >= 1.0 then
            wipeProps(fx)
            fx.phase = "done"
            active[fx.id] = nil
        end
        return budget, lights, ribbons
    end

    if dist > (lim.cullDist or 45.0) then
        return budget, lights, ribbons
    end

    if not fx.propsBuilt and not fx.building then
        spawnProps(fx, ped ~= 0 and ped or nil, fx.gen or 1)
    end

    if fx.propsBuilt then
        local g0 = fx.growStart or fx.t0
        local gMs = fx.growMs or cfg("growMs", 350)
        liftRoots(fx, smooth(math.min(1.0, (now - g0) / gMs)))
    end

    if ped == 0 or dist > (lim.simpleDetailDist or 32.0) then
        return budget, lights, ribbons
    end
    if ribbons >= (lim.maxRibbonTargets or 2) then
        return budget, lights, ribbons
    end

    local full = dist <= (lim.fullDetailDist or 18.0)
    local lv = CFG.living or {}
    local rb = CFG.ribbon or {}

    if ped ~= 0 then
        if lv.enabled ~= false then
            budget = drawLivingEnergy(fx, ped, full, budget, cam)
            if dist <= (lim.fullDetailDist or 24.0) then
                auraBurst(fx, ped)
            end
        end
    end
    ribbons = ribbons + 1

    if lights < (lim.maxLights or 0) then
        drawGlow(fx, ped)
        lights = lights + 1
    end

    return budget, lights, ribbons
end

local function ensureLoop()
    if loopOn then return end
    loopOn = true
    CreateThread(function()
        while next(active) do
            Wait(0)
            local cam = GetGameplayCamCoord()
            local now = GetGameTimer()
            local lim = CFG.limits or {}
            local budget = lim.maxDrawCalls or 420
            local lights, ribbons = 0, 0
            local list = {}
            for _, fx in pairs(active) do
                local ped = getPed(fx)
                local pos = ped ~= 0 and GetEntityCoords(ped) or vector3(fx.x, fx.y, fx.z)
                list[#list + 1] = { fx = fx, dist = #(cam - pos) }
            end
            table.sort(list, function(a, b) return a.dist < b.dist end)
            local cull = lim.cullDist or 48.0
            for i = 1, #list do
                local fx = list[i].fx
                if list[i].dist <= cull and fx.phase ~= "done" and fx.phase ~= "sinking" and not fx.propsBuilt and not fx.building then
                    local ped = getPed(fx)
                    spawnProps(fx, ped ~= 0 and ped or nil, fx.gen or 1)
                end
            end
            for i = 1, #list do
                budget, lights, ribbons = tick(list[i].fx, now, cam, list[i].dist, budget, lights, ribbons)
                if budget <= 0 then break end
            end
        end
        loopOn = false
    end)
end

------------------------------------------------------------
-- public API
------------------------------------------------------------
function RootsFx.start(data)
    if type(data) ~= "table" or not data.effectId then return false end

    local now = GetGameTimer()
    local remain = tonumber(data.remainingMs) or 30000
    local elapsed = tonumber(data.elapsedMs) or 0

    local old = active[data.effectId]
    if old then
        old.tEnd = now + remain
        if data.targetPed and data.targetPed ~= 0 then
            old.targetPed = data.targetPed
        end
        return true
    end

    local netId = tonumber(data.targetNetId) or 0
    local ped = 0
    if data.targetPed and data.targetPed ~= 0 and DoesEntityExist(data.targetPed) then
        ped = data.targetPed
    elseif netId ~= 0 and NetworkDoesNetworkIdExist(netId) then
        ped = NetworkGetEntityFromNetworkId(netId)
        if not ped or ped == 0 or not DoesEntityExist(ped) then ped = 0 end
    end

    -- kill leftover FX on same target from a previous cast (prevents double props / crash)
    stopSameTarget(netId, ped)

    local x, y, z, heading
    if ped ~= 0 then
        local c = GetEntityCoords(ped)
        x, y, z = c.x, c.y, c.z
        heading = GetEntityHeading(ped)
    elseif type(data.coords) == "table" then
        x = data.coords.x or 0.0
        y = data.coords.y or 0.0
        z = data.coords.z or 0.0
        heading = data.coords.heading or 0.0
    else
        return false
    end

    active[data.effectId] = {
        id = data.effectId,
        targetNetId = netId,
        targetPed = ped ~= 0 and ped or nil,
        x = x, y = y, z = z,
        heading = heading,
        seed = tonumber(data.seed) or math.random(1, 99999),
        t0 = now - elapsed,
        tEnd = now + remain,
        phase = "active",
        roots = {},
        wraps = {},
        propsBuilt = false,
        building = false,
        gen = 1,
        show = true,
        etherFrom = 0,
        etherUntil = 0,
    }

    ensureLoop()
    return true
end

function RootsFx.stop(effectId, reason)
    local fx = active[effectId]
    if not fx then return end
    if reason == "resource_stop" or reason == "replace" then
        wipeProps(fx)
        active[effectId] = nil
        return
    end
    if fx.phase ~= "sinking" and fx.phase ~= "done" then
        fx.tEnd = GetGameTimer()
        fx.phase = "sinking"
        fx.tSink = GetGameTimer()
        releaseLeaves(fx)
        for i = 1, #(fx.wraps or {}) do
            delObj(fx.wraps[i])
            fx.wraps[i] = 0
        end
        fx.wraps = {}
        fx.etherUntil = 0
    end
end

function RootsFx.clearAll()
    for id, fx in pairs(active) do
        wipeProps(fx)
        active[id] = nil
    end
    propCount = 0
end

RegisterCommand("rootsfx_preview", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local models = CFG.previewModels or {}
    CreateThread(function()
        for i = 1, #models do
            local name = models[i]
            local hash = requestModel(name)
            print(("[rootsfx_preview] %s valid=%s loaded=%s"):format(
                name, tostring(IsModelValid(joaat(name))), tostring(hash ~= nil)
            ))
            TriggerEvent("vorp:TipRight", ("%s loaded=%s"):format(name, tostring(hash ~= nil)), 2800)
            if hash then
                local wx, wy = rotXY(heading, 0.0, 1.4 + i * 0.55)
                local px, py = coords.x + wx, coords.y + wy
                local gz = getGround(px, py, coords.z)
                local z0, z1 = growZs(hash, gz)
                local isRope = name:find("rope") ~= nil
                local obj = makeObj(hash, px, py, z0, not isRope)
                if obj ~= 0 then
                    if isRope then
                        local bone = findBone(ped, HAND_L)
                        if bone ~= -1 then
                            AttachEntityToEntity(obj, ped, bone, 0, 0, 0, 0, 0, 0, false, false, false, false, 0, true, false, false)
                        end
                    else
                        local t0 = GetGameTimer()
                        while GetGameTimer() - t0 < 350 do
                            moveZ(obj, lerp(z0, z1, smooth((GetGameTimer() - t0) / 350)))
                            Wait(0)
                        end
                    end
                    Wait(2000)
                    if isRope then DetachEntity(obj, true, true) end
                    local t1 = GetGameTimer()
                    while GetGameTimer() - t1 < 350 do
                        moveZ(obj, lerp(z1, z0, smooth((GetGameTimer() - t1) / 350)))
                        Wait(0)
                    end
                    delObj(obj)
                end
                SetModelAsNoLongerNeeded(hash)
            end
            Wait(250)
        end
        TriggerEvent("vorp:TipRight", "Roots FX preview done.", 2500)
    end)
end, false)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        RootsFx.clearAll()
    end
end)
