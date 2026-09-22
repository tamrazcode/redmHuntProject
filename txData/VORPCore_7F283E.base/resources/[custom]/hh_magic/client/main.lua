local casting = false
local nextReadyAt = {}
local heldProp = 0
local activeAnim = nil
local loopedFx = {}

local function notify(text, ms)
    TriggerEvent("vorp:TipRight", text, ms or 3500)
end

local function loadAnim(dict, timeoutMs)
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
    local timeout = GetGameTimer() + (timeoutMs or 2500)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function loadModel(name)
    local hash = type(name) == "number" and name or joaat(name)
    if not IsModelValid(hash) then
        return nil
    end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 4000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then
        return nil
    end
    return hash
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
    local timeout = GetGameTimer() + 3000
    while not Citizen.InvokeNative(0x65BB72F29138F5D6, hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    return Citizen.InvokeNative(0x65BB72F29138F5D6, hash) == true
        or Citizen.InvokeNative(0x65BB72F29138F5D6, hash) == 1
end

--- Keep scripted cams off; never enter cig-card FP inspect.
local function releaseCamera()
    pcall(function()
        RenderScriptCams(false, false, 0, true, true)
    end)
    pcall(function()
        StopGameplayCamShaking(true)
    end)
    pcall(function()
        Citizen.InvokeNative(0x9C473089A934C930) -- DISABLE_ON_FOOT_FIRST_PERSON_VIEW_THIS_UPDATE
    end)
    pcall(function()
        Citizen.InvokeNative(0x8370D34BD2E60B73) -- _FORCE_THIRD_PERSON_CAM_THIS_FRAME
    end)
    local stuck = {
        "EagleEye",
        "MP_SkillGeneric01",
        "CamTransitionFlash",
        "CamTransition01",
        "CamTransitionBlink",
        "MP_MatchEndPulse",
        "MP_PickupCollectible",
    }
    for i = 1, #stuck do
        pcall(function()
            AnimpostfxStop(stuck[i])
        end)
    end
end

local thirdPersonLock = false
local camLockToken = 0

local function startThirdPersonLock()
    thirdPersonLock = true
    camLockToken = camLockToken + 1
    local token = camLockToken
    CreateThread(function()
        while thirdPersonLock and token == camLockToken do
            releaseCamera()
            Wait(0)
        end
    end)
end

local function stopThirdPersonLock()
    thirdPersonLock = false
    camLockToken = camLockToken + 1
    releaseCamera()
end

local function boneIndex(ped, boneName)
    local names = {}
    if type(boneName) == "table" then
        names = boneName
    elseif boneName and boneName ~= "" then
        names = { boneName }
    end
    names[#names + 1] = "SKEL_L_Hand"
    names[#names + 1] = "skel_l_hand"
    names[#names + 1] = "PH_L_Hand"
    names[#names + 1] = "SKEL_L_Finger12"
    for i = 1, #names do
        local idx = GetEntityBoneIndexByName(ped, names[i])
        if idx and idx ~= -1 then
            return idx
        end
    end
    return GetEntityBoneIndexByName(ped, "SKEL_L_Hand")
end

local function forcePedAnimUpdate(ped)
    pcall(function()
        Citizen.InvokeNative(0x2208438012482A1A, ped, false, true)
    end)
end

--- RedM TaskPlayAnim signature used on this build.
local function taskAnim(ped, dict, clip, duration, flag)
    TaskPlayAnim(
        ped, dict, clip,
        1.0, 8.0,
        duration or -1,
        flag or 25,
        0,
        false, false, false
    )
    forcePedAnimUpdate(ped)
end

local function playPedAnim(ped, dict, clip, duration, flag, noWait)
    if not loadAnim(dict) then
        return false
    end
    taskAnim(ped, dict, clip, duration or -1, flag or 25)
    if not noWait then
        Wait(200)
        if not IsEntityPlayingAnim(ped, dict, clip, 3) then
            return false
        end
    end
    activeAnim = { dict = dict, clip = clip }
    return true
end

local function stopActiveAnim(ped)
    if activeAnim then
        StopAnimTask(ped, activeAnim.dict, activeAnim.clip, 1.0)
        activeAnim = nil
    end
end

local function deleteHeldProp()
    if heldProp ~= 0 and DoesEntityExist(heldProp) then
        pcall(function()
            DetachEntity(heldProp, false, false)
        end)
        SetEntityAsMissionEntity(heldProp, true, true)
        SetEntityVisible(heldProp, false)
        DeleteObject(heldProp)
    end
    heldProp = 0
end

local pickedCardModel = nil

local function resolveCardModel(cardCfg)
    local names = {}
    if pickedCardModel and pickedCardModel ~= "" then
        names[#names + 1] = pickedCardModel
    end
    if type(cardCfg.props) == "table" then
        for i = 1, #cardCfg.props do
            names[#names + 1] = cardCfg.props[i]
        end
    end
    if cardCfg.prop and cardCfg.prop ~= "" then
        names[#names + 1] = cardCfg.prop
    end
    if type(cardCfg.propFallback) == "table" then
        for i = 1, #cardCfg.propFallback do
            names[#names + 1] = cardCfg.propFallback[i]
        end
    end

    local seen = {}
    for i = 1, #names do
        local name = names[i]
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            local hash = loadModel(name)
            if hash then
                pickedCardModel = name
                return hash, name
            end
        end
    end
    return nil, nil
end

local function bindCardToHand(ped, cardCfg, obj)
    if not obj or obj == 0 or not DoesEntityExist(obj) then
        return false
    end
    local bone = boneIndex(ped, cardCfg.bones or cardCfg.bone or "PH_L_Hand")
    local pos = cardCfg.pos or { x = 0.0, y = 0.0, z = 0.0 }
    local rot = cardCfg.rot or { x = 0.0, y = 0.0, z = 0.0 }
    pcall(function()
        DetachEntity(obj, false, false)
    end)
    pcall(function()
        AttachEntityToEntity(
            obj, ped, bone,
            pos.x + 0.0, pos.y + 0.0, pos.z + 0.0,
            rot.x + 0.0, rot.y + 0.0, rot.z + 0.0,
            true, true, false, true, 1, true, false, false
        )
    end)
    return true
end

local function spawnCardProp(ped, cardCfg)
    deleteHeldProp()
    if not cardCfg then
        return false
    end
    local hash = resolveCardModel(cardCfg)
    if not hash then
        return false
    end
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false, false, true)
    if not obj or obj == 0 then
        obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.15, false, false, false, false, true)
    end
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return false
    end
    SetEntityAsMissionEntity(obj, true, false)
    SetEntityVisible(obj, true)
    SetEntityCollision(obj, false, false)
    heldProp = obj
    SetModelAsNoLongerNeeded(hash)
    return true
end

--- Native cig-card pocket motions (INTRO / HOLSTER). Not BASE — BASE opens FP inspect UI.
local function playCardPocket(ped, cardCfg, stateName)
    if not ped or ped == 0 or heldProp == 0 or not DoesEntityExist(heldProp) then
        return false
    end
    local ix = cardCfg and cardCfg.interaction
    if not ix or not stateName then
        return false
    end
    local itemHash = 0
    if type(ix.item) == "number" then
        itemHash = ix.item
    elseif ix.item and ix.item ~= "" then
        itemHash = joaat(ix.item)
    end
    local propId = joaat(ix.propId or "PrimaryItem")
    local stateHash = type(stateName) == "number" and stateName or joaat(stateName)
    local ok = pcall(function()
        TaskItemInteraction_2(ped, itemHash, heldProp, propId, stateHash, 1, 0, -1.0)
    end)
    forcePedAnimUpdate(ped)
    releaseCamera()
    return ok
end

local function attachCardProp(ped, cardCfg)
    deleteHeldProp()
    if not cardCfg then
        return false
    end
    if not spawnCardProp(ped, cardCfg) then
        return false
    end
    return bindCardToHand(ped, cardCfg, heldProp)
end

local function showNuiCard(cardCfg, mode)
    SendNUIMessage({
        action = "showCard",
        image = cardCfg and cardCfg.image or "card.png",
        mode = mode or "hold",
    })
end

local function hideNuiCard()
    SendNUIMessage({ action = "hideCard" })
end

local function dropNuiCard()
    SendNUIMessage({ action = "dropCard" })
end

local function fadeNuiCard()
    SendNUIMessage({ action = "burnCard" })
end

local function stopLoopedFx()
    for i = 1, #loopedFx do
        local handle = loopedFx[i]
        if handle then
            pcall(function()
                StopParticleFxLooped(handle, false)
            end)
        end
    end
    loopedFx = {}
end

local function usePtfx(dict)
    if not loadPtfx(dict) then
        return false
    end
    Citizen.InvokeNative(0xA10DB07FC234DD12, dict)
    return true
end

local function loopOnCard(dict, name, scale)
    if heldProp == 0 or not DoesEntityExist(heldProp) then
        return
    end
    if not usePtfx(dict) then
        return
    end
    local handle = StartParticleFxLoopedOnEntity(
        name,
        heldProp,
        0.0, 0.0, 0.01,
        0.0, 0.0, 0.0,
        scale or 0.35,
        false, false, false
    )
    if handle and handle ~= 0 then
        loopedFx[#loopedFx + 1] = handle
    end
end

local function burstOnCard(dict, name, scale)
    if heldProp == 0 or not DoesEntityExist(heldProp) then
        return
    end
    if not usePtfx(dict) then
        return
    end
    StartParticleFxNonLoopedOnEntity(
        name,
        heldProp,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale or 0.45,
        false, false, false
    )
end

local function flareCard()
    loopOnCard("anm_fire", "ent_anim_candle_flame", 0.28)
    loopOnCard("anm_fire", "ent_anim_rslvc_burn_book", 0.18)
    burstOnCard("anm_fire", "ent_anim_fire_fuel_burst", 0.22)
end

local lightOn = false

local function startCardLight(durationMs)
    lightOn = true
    CreateThread(function()
        local ends = GetGameTimer() + (durationMs or 4500)
        while lightOn and GetGameTimer() < ends do
            local ped = PlayerPedId()
            if ped ~= 0 and DoesEntityExist(ped) then
                local hand = GetWorldPositionOfEntityBone(ped, boneIndex(ped, "SKEL_L_Hand"))
                if hand and hand.x then
                    local flick = 0.9 + math.random() * 0.35
                    DrawLightWithRange(hand.x, hand.y, hand.z + 0.05, 255, 140, 40, 1.1, flick)
                end
            end
            Wait(0)
        end
        lightOn = false
    end)
end

local function stopCardLight()
    lightOn = false
end

local function fadePropAway(durationMs)
    if heldProp == 0 or not DoesEntityExist(heldProp) then
        return
    end
    local prop = heldProp
    CreateThread(function()
        local steps = 12
        local stepWait = math.floor((durationMs or 1200) / steps)
        for i = 1, steps do
            if not DoesEntityExist(prop) then
                return
            end
            local alpha = math.floor(255 * (1 - i / steps))
            pcall(function()
                SetEntityAlpha(prop, alpha, false)
            end)
            Wait(stepWait)
        end
    end)
end

local function playEmote(ped, emoteName)
    if not emoteName or emoteName == "" then
        return false
    end
    -- ped, emoteType, playbackMode, emoteHash, ...
    Citizen.InvokeNative(0xB31A277C1AC7B7FF, ped, 0, 0, joaat(emoteName), 1, 1, 0, 0)
    forcePedAnimUpdate(ped)
    return true
end

local function playHoldLoop(ped, hold, noWait)
    if not hold then
        return false
    end
    if type(hold.clips) == "table" and hold.dict then
        for i = 1, #hold.clips do
            local clip = hold.clips[i]
            if clip and clip ~= "" and playPedAnim(ped, hold.dict, clip, -1, hold.flag or 25, true) then
                if noWait then
                    return true
                end
                Wait(180)
                if IsEntityPlayingAnim(ped, hold.dict, clip, 3) then
                    return true
                end
            end
        end
    end
    if hold.clip and playPedAnim(ped, hold.dict, hold.clip, -1, hold.flag or 25, noWait) then
        return true
    end
    local fallback = hold.fallback
    if fallback and playPedAnim(ped, fallback.dict, fallback.clip, -1, fallback.flag or 25, noWait) then
        return true
    end
    return false
end

local function playInspect(ped, hold)
    if not hold then
        return false
    end
    return playHoldLoop(ped, hold)
end

local function lookAtCard(ped, ms)
    if heldProp ~= 0 and DoesEntityExist(heldProp) then
        pcall(function()
            TaskLookAtEntity(ped, heldProp, ms or 60000, 2048, 3, 0)
        end)
    end
end

local function cleanupCast(ped)
    stopCardLight()
    stopLoopedFx()
    hideNuiCard()
    deleteHeldProp()
    stopActiveAnim(ped)
    if ped and DoesEntityExist(ped) then
        ClearPedSecondaryTask(ped)
        ClearPedTasks(ped)
        pcall(function()
            TaskClearLookAt(ped)
        end)
    end
    stopThirdPersonLock()
end

------------------------------------------------------------
-- Shared card-hold API (used by aim loop + cast ritual)
------------------------------------------------------------
MagicCards = MagicCards or {}
local cardHold = {
    active = false,
    spellId = nil,
}

function MagicCards.isHolding()
    return cardHold.active and heldProp ~= 0 and DoesEntityExist(heldProp)
end

function MagicCards.isHoldingSpell(spellId)
    return cardHold.active and cardHold.spellId == spellId and heldProp ~= 0 and DoesEntityExist(heldProp)
end

function MagicCards.getSpellId()
    return cardHold.spellId
end

function MagicCards.startHold(spellId)
    local spell = Config.Spells and Config.Spells[spellId]
    if not spell then
        return false
    end
    local ped = PlayerPedId()
    if ped == 0 then
        return false
    end

    cardHold.active = true
    cardHold.spellId = spellId
    casting = true
    startThirdPersonLock()
    releaseCamera()

    SetCurrentPedWeapon(ped, joaat("WEAPON_UNARMED"), true)
    ClearPedTasks(ped)
    Wait(40)

    notify(spell.notify or ("Casting " .. (spell.label or spellId)), 2500)
    if spell.cancelHint then
        notify(spell.cancelHint, 3500)
    end

    -- PNG floats on screen; Page card sits on PH_L_Hand (authored grip, no FP inspect)
    hideNuiCard()
    local cardCfg = spell.card or {}
    pickedCardModel = nil
    if type(cardCfg.props) == "table" and #cardCfg.props > 0 then
        pickedCardModel = cardCfg.props[math.random(1, #cardCfg.props)]
    end
    playHoldLoop(ped, spell.hold)
    attachCardProp(ped, cardCfg)
    showNuiCard(cardCfg, "hold")
    lookAtCard(ped, 120000)
    releaseCamera()
    return true
end

function MagicCards.keepHold()
    if not cardHold.active then
        return
    end
    local spell = Config.Spells and Config.Spells[cardHold.spellId]
    local ped = PlayerPedId()
    if ped == 0 or not spell then
        return
    end
    local cardCfg = spell.card or {}
    local hold = spell.hold

    if heldProp == 0 or not DoesEntityExist(heldProp) then
        attachCardProp(ped, cardCfg)
        playHoldLoop(ped, hold, true)
        lookAtCard(ped, 60000)
    elseif activeAnim and not IsEntityPlayingAnim(ped, activeAnim.dict, activeAnim.clip, 3) then
        playHoldLoop(ped, hold, true)
        lookAtCard(ped, 60000)
    elseif hold and hold.dict and hold.clip and not IsEntityPlayingAnim(ped, hold.dict, hold.clip, 3) then
        playHoldLoop(ped, hold, true)
        lookAtCard(ped, 60000)
    end
    releaseCamera()
end

function MagicCards.putAway(silent)
    if not cardHold.active and heldProp == 0 then
        casting = false
        return
    end
    local spell = Config.Spells and Config.Spells[cardHold.spellId]
    local ped = PlayerPedId()
    if not silent and spell then
        notify(spell.notifyCancel or "Вы убираете карту...", 2000)
    end
    -- Cancel: PNG flies down, world card just disappears
    dropNuiCard()
    deleteHeldProp()
    stopActiveAnim(ped)
    if ped ~= 0 then
        ClearPedSecondaryTask(ped)
        ClearPedTasks(ped)
        pcall(function()
            TaskClearLookAt(ped)
        end)
    end
    stopThirdPersonLock()
    pickedCardModel = nil
    cardHold.active = false
    cardHold.spellId = nil
    casting = false
end

--- Successful cast: burn the floating card, then drop the hold.
function MagicCards.finishRitual()
    local spell = Config.Spells and Config.Spells[cardHold.spellId]
    local ritual = spell and spell.ritual or {}
    local ped = PlayerPedId()
    fadeNuiCard()
    fadePropAway(math.floor((ritual.burnMs or 1500) * 0.6))
    Wait((ritual.burnMs or 1500) + 150)
    deleteHeldProp()
    stopActiveAnim(ped)
    if ped ~= 0 then
        ClearPedSecondaryTask(ped)
        pcall(function()
            TaskClearLookAt(ped)
        end)
    end
    hideNuiCard()
    stopThirdPersonLock()
    pickedCardModel = nil
    cardHold.active = false
    cardHold.spellId = nil
    casting = false
end

function MagicCards.beginRitual()
    return cardHold.active and MagicCards.isHolding()
end

function MagicCards.endHold()
    cardHold.active = false
    cardHold.spellId = nil
    stopThirdPersonLock()
end

--- Screen burn is driven by the NUI shader. World: hold pose + candle flame.
local function castSpellStub(spellId, spell)
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    casting = true
    releaseCamera()

    local cardCfg = spell.card or {}
    local ritual = spell.ritual or {}
    local alreadyHolding = MagicCards.isHoldingSpell and MagicCards.isHoldingSpell(spellId)

    if not alreadyHolding then
        notify(spell.notify or ("Casting " .. (spell.label or spellId)), 2500)
        SetCurrentPedWeapon(ped, joaat("WEAPON_UNARMED"), true)
        ClearPedTasks(ped)
        Wait(40)
        startThirdPersonLock()
        playHoldLoop(ped, spell.hold)
        attachCardProp(ped, cardCfg)
        showNuiCard(cardCfg, "hold")
    else
        playHoldLoop(ped, spell.hold)
        if heldProp == 0 or not DoesEntityExist(heldProp) then
            attachCardProp(ped, cardCfg)
        end
    end

    -- PNG already floating from aim — start the burn shader
    fadeNuiCard()

    loadPtfx("core")
    loadPtfx("anm_fire")
    lookAtCard(ped, (ritual.seeMs or 500) + (ritual.burnMs or 1500) + 500)
    releaseCamera()

    Wait(ritual.seeMs or 500)

    flareCard()
    startCardLight(ritual.burnMs or 1500)
    if spell.thorns then
        TriggerServerEvent("hh_magic:server:thornsRelease", spellId)
    end
    fadePropAway(math.floor((ritual.burnMs or 1500) * 0.6))
    Wait((ritual.burnMs or 1500) + 200)
    deleteHeldProp()
    Wait(200)

    stopLoopedFx()
    stopCardLight()
    hideNuiCard()
    stopActiveAnim(ped)
    ClearPedTasks(ped)
    pcall(function()
        TaskClearLookAt(ped)
    end)

    MagicCards.endHold()
    cleanupCast(ped)
    casting = false
    return true
end

RegisterNetEvent("hh_magic:client:tryCast", function(spellId)
    local spell = Config.Spells and Config.Spells[spellId]
    if not spell then
        return
    end

    -- Aim phase already set casting=true via MagicCards.startHold — that is OK.
    local fromAim = MagicCards and MagicCards.getSpellId and MagicCards.getSpellId() == spellId
    if casting and not fromAim then
        notify(spell.failBusy or "Already casting.", 2500)
        TriggerServerEvent("hh_magic:server:castResult", spellId, false, "busy")
        if MagicCards and MagicCards.putAway then
            MagicCards.putAway(true)
        end
        return
    end

    local now = GetGameTimer()
    if now < (nextReadyAt[spellId] or 0) then
        notify(spell.failCooldown or "Not ready.", 2500)
        TriggerServerEvent("hh_magic:server:castResult", spellId, false, "cooldown")
        if MagicCards and MagicCards.putAway then
            MagicCards.putAway(true)
        end
        return
    end

    local ok = false
    local castOk, castErr = pcall(function()
        ok = castSpellStub(spellId, spell)
    end)
    if not castOk then
        cleanupCast(PlayerPedId())
        if MagicCards and MagicCards.endHold then
            MagicCards.endHold()
        end
        casting = false
        if Config.Debug then
            print(("[hh_magic] cast error: %s"):format(tostring(castErr)))
        end
        ok = false
    end

    if ok then
        nextReadyAt[spellId] = GetGameTimer() + (spell.cooldownMs or 3000)
    end
    TriggerServerEvent("hh_magic:server:castResult", spellId, ok == true, ok and "ok" or "fail")
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    cleanupCast(PlayerPedId())
    closeGiver()
end)

CreateThread(function()
    Wait(500)
    releaseCamera()
end)

-- ===== Dev card giver =====

local giverOpen = false

local function buildGiverCards()
    local cards = {}
    for spellId, spell in pairs(Config.Spells or {}) do
        cards[#cards + 1] = {
            id = spellId,
            label = spell.label or spellId,
            description = spell.description or "",
            item = spell.item or "",
            image = (spell.card and spell.card.image) or "card.png",
        }
    end
    table.sort(cards, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return cards
end

local function openGiver()
    if giverOpen then
        return
    end
    giverOpen = true
    local menu = Config.DevMenu or {}
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = "openGiver",
        title = menu.title or "Magic Cards",
        cards = buildGiverCards(),
    })
end

function closeGiver()
    if not giverOpen then
        SendNUIMessage({ action = "closeGiver" })
        SetNuiFocus(false, false)
        return
    end
    giverOpen = false
    SendNUIMessage({ action = "closeGiver" })
    SetNuiFocus(false, false)
end

RegisterCommand((Config.DevMenu and Config.DevMenu.command) or "jarvisshozahuynya", function()
    if giverOpen then
        closeGiver()
        return
    end
    openGiver()
end, false)

RegisterNUICallback("giverClose", function(_, cb)
    closeGiver()
    cb({ ok = true })
end)

RegisterNUICallback("giverGive", function(data, cb)
    local spellId = data and data.spellId
    if type(spellId) == "string" and spellId ~= "" then
        TriggerServerEvent("hh_magic:server:giveCard", spellId)
    end
    cb({ ok = true })
end)
