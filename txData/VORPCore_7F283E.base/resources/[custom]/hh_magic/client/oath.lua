Oath = Oath or {}

local aiming = false
local active = nil
local drops = {}
local sessions = {}

local KEY_CAST = `INPUT_ATTACK`
local KEY_CANCEL = `INPUT_AIM`
local KEY_RETURN = 0xB2F377E8
local MOVE = { 0x8FD015D8, 0xD27782E3, 0x7065027D, 0xB4E465B4, 0x4D8FB4C1, 0xFDA83190 }
local HAND_R = 22798
local HAND_L = 34606
local CHEST_BONE = 14413

local function notify(text, ms)
    TriggerEvent("vorp:TipRight", text, ms or 2800)
end

local function rules(spell)
    return (spell and spell.oath) or {}
end

local function maxHealth(ped)
    local maxHp = 0
    pcall(function()
        maxHp = GetEntityMaxHealth(ped)
    end)
    if not maxHp or maxHp <= 0 then
        pcall(function()
            maxHp = GetPedMaxHealth(ped)
        end)
    end
    if not maxHp or maxHp <= 0 then
        maxHp = 600
    end
    return maxHp
end

local function healthOf(ped)
    local hp = 0
    pcall(function()
        hp = GetEntityHealth(ped)
    end)
    return tonumber(hp) or 0
end

local function quote(ped, spell)
    local cfg = rules(spell)
    local maxHp = maxHealth(ped)
    local current = healthOf(ped)
    local floor = cfg.aliveFloor or 15
    local transfer = math.floor(maxHp * (cfg.transferRatio or 0.30))
    local reserve = math.max(math.ceil(maxHp * (cfg.reserveRatio or 0.20)), floor)
    return transfer, reserve, current, maxHp
end

local function playerOf(ped)
    if not ped or ped == 0 or not IsPedAPlayer(ped) or ped == PlayerPedId() then
        return nil
    end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if not idx or idx == -1 then
        return nil
    end
    return GetPlayerServerId(idx), idx
end

local function isKnocked(ped)
    local sid = playerOf(ped)
    if not sid then
        return false
    end
    local state = Player(sid).state
    if not state then
        return false
    end
    return state.isDead == true or state.thehuntUnconscious == true
end

local function closestKnocked(origin, radius)
    local best, bestDist
    for _, idx in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(idx)
        if isKnocked(ped) then
            local dist = #(GetEntityCoords(ped) - origin)
            if dist <= radius and (not bestDist or dist < bestDist) then
                best = ped
                bestDist = dist
            end
        end
    end
    return best, bestDist
end

local function bone(ped, id, fallbackZ)
    local pos = GetPedBoneCoords(ped, id, 0.0, 0.0, 0.0)
    if not pos or (pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0) then
        local base = GetEntityCoords(ped)
        return vector3(base.x, base.y, base.z + (fallbackZ or 0.4))
    end
    return pos
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 1200
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function reach(ped, spell)
    local anim = rules(spell).reach or {}
    local kneelDict = anim.kneelDict
    local kneelClip = anim.kneelClip or "base"
    if kneelDict and loadAnim(kneelDict) and not IsEntityPlayingAnim(ped, kneelDict, kneelClip, 3) then
        TaskPlayAnim(ped, kneelDict, kneelClip, 1.6, 1.0, -1, 1, 0.0, false, false, false)
    end
    if anim.dict and loadAnim(anim.dict) and not IsEntityPlayingAnim(ped, anim.dict, anim.clip or "base", 3) then
        TaskPlayAnim(ped, anim.dict, anim.clip or "base", 1.4, 1.0, -1, anim.flag or 49, 0.0, false, false, false)
    end
end

local function showOathTimer(seconds, left, total)
    SendNUIMessage({
        action = "oathTimer",
        show = true,
        seconds = seconds,
        left = left,
        total = total,
    })
end

local function hideOathTimer()
    SendNUIMessage({ action = "oathTimer", show = false })
end

local function startBloodFx(ped, target)
    local handles = {}
    local function loopOn(entity, dict, name, ox, oy, oz, scale)
        RequestNamedPtfxAsset(dict)
        local deadline = GetGameTimer() + 600
        while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < deadline do
            Wait(0)
        end
        if not HasNamedPtfxAssetLoaded(dict) then
            return
        end
        UseParticleFxAsset(dict)
        local handle = StartParticleFxLoopedOnEntity(name, entity, ox, oy, oz, 0.0, 0.0, 0.0, scale, false, false, false)
        if handle and handle ~= 0 then
            handles[#handles + 1] = handle
        end
    end
    pcall(function()
        loopOn(ped, "core", "blood_entry", 0.18, 0.02, 0.55, 0.45)
        loopOn(ped, "core", "blood_entry", -0.18, 0.02, 0.55, 0.45)
        if target and DoesEntityExist(target) then
            loopOn(target, "core", "blood_entry", 0.0, 0.05, 0.35, 0.7)
        end
    end)
    active.fx = handles
end

local function stopBloodFx()
    if not active or not active.fx then
        return
    end
    for i = 1, #active.fx do
        local handle = active.fx[i]
        if handle and handle ~= 0 then
            pcall(function()
                StopParticleFxLooped(handle, false)
            end)
        end
    end
    active.fx = nil
end

local function standCaster(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
        return
    end
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    pcall(function()
        TaskClearLookAt(ped)
    end)
end

local function puffBlood(pos, scale)
    RequestNamedPtfxAsset("core")
    if HasNamedPtfxAssetLoaded("core") then
        UseParticleFxAsset("core")
        StartParticleFxNonLoopedAtCoord("blood_entry", pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, scale or 0.6, false, false, false)
    end
    DrawLightWithRange(pos.x, pos.y, pos.z, 160, 10, 16, 1.8, 2.2)
end

local function bezier(p0, p1, p2, p3, t)
    local u = 1.0 - t
    return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)
end

local function drawDrop(pos, scale)
    puffBlood(pos, 0.45 * (scale or 1.0))
end

local function spawnDrop(caster, target, handBone)
    if #drops >= 16 then
        return
    end
    local hand = bone(caster, handBone or HAND_R, 0.9)
    local chest = bone(target, CHEST_BONE, 0.35)
    local side = (math.random() - 0.5) * 0.16
    local p0 = hand
    local p1 = hand + vector3(side, side * 0.35, 0.28)
    local p2 = chest + vector3(-side, side * 0.15, 0.4)
    local p3 = chest + vector3(0.0, 0.0, 0.08)
    drops[#drops + 1] = {
        p0 = p0, p1 = p1, p2 = p2, p3 = p3,
        born = GetGameTimer(),
        life = math.random(700, 900),
        last = p0,
    }
end

local function tickDrops(now, fading)
    local keep = {}
    for i = 1, #drops do
        local drop = drops[i]
        local age = now - drop.born
        local t = age / drop.life
        if fading then
            t = math.min(1.0, t + 0.35)
        end
        if t < 1.0 then
            local pos = bezier(drop.p0, drop.p1, drop.p2, drop.p3, t)
            if not drop.nextPuff or now >= drop.nextPuff then
                drop.nextPuff = now + 140
                local scale = t > 0.78 and (1.0 - (t - 0.78) / 0.22) or 1.0
                drawDrop(pos, scale)
            end
            drop.last = pos
            keep[#keep + 1] = drop
        end
    end
    drops = keep
end

local function clearChannel(unlock)
    local ped = PlayerPedId()
    stopBloodFx()
    if active and active.targetPed and DoesEntityExist(active.targetPed) then
        local chest = bone(active.targetPed, CHEST_BONE, 0.35)
        puffBlood(chest, 1.6)
    end
    standCaster(ped)
    hideOathTimer()
    if active and active.ownsLock and unlock then
        LocalPlayer.state:set("hhThornLocked", false, false)
    end
    active = nil
    drops = {}
end

local function beginChannel(spell, castId, targetSid, transfer, remain)
    local ped = PlayerPedId()
    local idx = GetPlayerFromServerId(targetSid)
    local targetPed = idx ~= -1 and GetPlayerPed(idx) or 0
    active = {
        id = castId,
        spell = spell,
        target = targetSid,
        targetPed = targetPed,
        transfer = transfer,
        ends = GetGameTimer() + remain,
        total = remain,
        health = healthOf(ped),
        ownsLock = LocalPlayer.state.hhThornLocked ~= true,
        returnArmed = not IsDisabledControlPressed(0, KEY_RETURN),
        nextDrop = GetGameTimer() + 1600,
        fading = false,
        posed = false,
    }
    if active.ownsLock then
        LocalPlayer.state:set("hhThornLocked", true, false)
    end
    if MagicCards and MagicCards.finishRitual then
        CreateThread(function()
            MagicCards.finishRitual()
        end)
    end
    CreateThread(function()
        local id = castId
        while active and active.id == id do
            local now = GetGameTimer()
            Wait(0)
            if not active or active.id ~= id then
                return
            end
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            local look = { 0xA987235F, 0xD2047988 }
            for pad = 0, 1 do
                for i = 1, #look do
                    EnableControlAction(pad, look[i], true)
                end
            end
            EnableControlAction(0, KEY_RETURN, true)
            local voice = { `INPUT_PUSH_TO_TALK`, 0xF1301666, 0x05CA7C52 }
            for i = 1, #voice do
                EnableControlAction(0, voice[i], true)
            end
            local body = PlayerPedId()
            local left = math.max(0, active.ends - now)
            local sec = math.ceil(left / 1000)
            if sec ~= active.shown then
                active.shown = sec
                showOathTimer(sec, left, active.total or remain)
            end
            local targetNow = GetPlayerPed(GetPlayerFromServerId(active.target))
            active.targetPed = targetNow
            if not active.returnArmed then
                if not IsDisabledControlPressed(0, KEY_RETURN) then
                    active.returnArmed = true
                end
            elseif IsDisabledControlJustReleased(0, KEY_RETURN) then
                TriggerServerEvent("hh_magic:oath:cancel", id, "cancel")
                return
            end
            for i = 1, #MOVE do
                if IsDisabledControlPressed(0, MOVE[i]) then
                    TriggerServerEvent("hh_magic:oath:cancel", id, "move")
                    return
                end
            end
            local hp = healthOf(body)
            if IsEntityDead(body) or hp < (active.health or hp) then
                TriggerServerEvent("hh_magic:oath:cancel", id, "hurt")
                return
            end
            if targetNow and targetNow ~= 0 and DoesEntityExist(targetNow) then
                local dist = #(GetEntityCoords(body) - GetEntityCoords(targetNow))
                if dist > (rules(spell).breakRange or 3.0) then
                    TriggerServerEvent("hh_magic:oath:cancel", id, "range")
                    return
                end
                if now >= active.nextDrop and not active.fading then
                    active.nextDrop = now + math.random(70, 100)
                    spawnDrop(body, targetNow, HAND_R)
                    spawnDrop(body, targetNow, HAND_L)
                    if not active.fx then
                        startBloodFx(body, targetNow)
                    end
                end
                reach(body, spell)
            end
            tickDrops(now, active.fading)
        end
        local fadeUntil = GetGameTimer() + 180
        while GetGameTimer() < fadeUntil and #drops > 0 do
            Wait(0)
            tickDrops(GetGameTimer(), true)
        end
        drops = {}
    end)
end

RegisterNetEvent("hh_magic:oath:begin", function(payload)
    if type(payload) ~= "table" then
        return
    end
    beginChannel(activeSpellHold or Config.Spells.oath, payload.id, payload.target, payload.transfer, payload.remain or 5000)
end)

RegisterNetEvent("hh_magic:oath:deny", function(text)
    notify(text or "Обет не состоялся.", 2500)
    if MagicCards and MagicCards.putAway then
        MagicCards.putAway(true)
    end
    aiming = false
end)

RegisterNetEvent("hh_magic:oath:pay", function(castId, ratio, reserveRatio, floorHp)
    if not active or active.id ~= castId or active.paid then
        TriggerServerEvent("hh_magic:oath:paid", castId, false, 0)
        return
    end
    local ped = PlayerPedId()
    local before = healthOf(ped)
    local maxHp = maxHealth(ped)
    local transfer = math.floor(maxHp * (tonumber(ratio) or 0.30))
    local reserve = math.max(math.ceil(maxHp * (tonumber(reserveRatio) or 0.20)), math.floor(tonumber(floorHp) or 15))
    if IsEntityDead(ped) or transfer < 1 or before - transfer < reserve then
        TriggerServerEvent("hh_magic:oath:paid", castId, false, 0)
        return
    end
    SetEntityHealth(ped, before - transfer, 0)
    active.paid = true
    active.health = before - transfer
    TriggerServerEvent("hh_magic:oath:paid", castId, true, transfer)
end)

RegisterNetEvent("hh_magic:oath:refund", function(amount)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        return
    end
    local hp = healthOf(ped)
    local cap = maxHealth(ped)
    SetEntityHealth(ped, math.min(cap, hp + math.floor(amount or 0)), 0)
end)

RegisterNetEvent("hh_magic:oath:end", function(castId, ok, text)
    if active and active.id == castId then
        active.fading = true
        clearChannel(true)
    end
    sessions[castId] = nil
    if text and text ~= "" then
        notify(text, 2500)
    elseif ok then
        notify("Кровь принята. Союзник возвращается.", 2500)
    end
end)

RegisterNetEvent("hh_magic:oath:visual", function(payload)
    if type(payload) ~= "table" or payload.caster == GetPlayerServerId(PlayerId()) then
        return
    end
    sessions[payload.id] = payload
    CreateThread(function()
        local row = payload
        local nextDrop = GetGameTimer()
        while sessions[row.id] do
            Wait(0)
            local casterIdx = GetPlayerFromServerId(row.caster)
            local targetIdx = GetPlayerFromServerId(row.target)
            if casterIdx == -1 or targetIdx == -1 then
                break
            end
            local caster = GetPlayerPed(casterIdx)
            local target = GetPlayerPed(targetIdx)
            if not DoesEntityExist(caster) or not DoesEntityExist(target) then
                break
            end
            if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(caster)) > 40.0 then
                Wait(200)
            elseif GetGameTimer() >= nextDrop then
                nextDrop = GetGameTimer() + 120
                spawnDrop(caster, target, HAND_R)
                spawnDrop(caster, target, HAND_L)
            end
            tickDrops(GetGameTimer(), false)
        end
    end)
end)

RegisterNetEvent("hh_magic:oath:visualStop", function(castId)
    sessions[castId] = nil
end)

local activeSpellHold

function Oath.start(spellId, spell)
    if aiming or active then
        notify(spell.failBusy or "Вы уже творите заклинание.", 2500)
        return
    end
    aiming = true
    activeSpellHold = spell
    if MagicCards and MagicCards.startHold then
        MagicCards.startHold(spellId)
    end
    CreateThread(function()
        local keepAt = 0
        while aiming and not active do
            Wait(0)
            DisableControlAction(0, KEY_CAST, true)
            DisableControlAction(0, KEY_CANCEL, true)
            DisablePlayerFiring(PlayerId(), true)
            local now = GetGameTimer()
            if MagicCards and MagicCards.keepHold and now >= keepAt then
                MagicCards.keepHold()
                keepAt = now + 400
            end
            local ped = PlayerPedId()
            local origin = GetEntityCoords(ped)
            local reach = rules(spell).selectRange or 2.5
            local target, dist = closestKnocked(origin, 12.0)
            local transfer, reserve, current = quote(ped, spell)
            local after = current - transfer
            local inRange = target and dist and dist <= reach
            local canPay = transfer >= (rules(spell).aliveFloor or 15) and after >= reserve
            if target then
                local mark = GetEntityCoords(target)
                local r, g, b = 180, 40, 40
                if inRange then
                    r, g, b = 40, 180, 70
                end
                DrawMarker(0x94FDAE17, mark.x, mark.y, mark.z + 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 0.3, r, g, b, 200, false, false, 2, nil, nil, false, false)
            end
            if IsDisabledControlJustPressed(0, KEY_CAST) then
                if not target or not inRange then
                    notify(spell.failTarget or "Рядом нет того, кого можно поднять из нока.", 2500)
                elseif not canPay and transfer < (rules(spell).aliveFloor or 15) then
                    notify(spell.failBlood or "Недостаточно крови для возвращения.", 2500)
                elseif not canPay then
                    notify(spell.failHealth or "Недостаточно здоровья для обета.", 2500)
                else
                    aiming = false
                    notify(("Отдать %s HP. После обета останется %s HP."):format(transfer, after), 3500)
                    local sid = playerOf(target)
                    TriggerServerEvent("hh_magic:oath:begin", spellId, sid)
                    return
                end
            elseif IsDisabledControlJustPressed(0, KEY_CANCEL) or IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`) then
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
    clearChannel(true)
    drops = {}
end)
