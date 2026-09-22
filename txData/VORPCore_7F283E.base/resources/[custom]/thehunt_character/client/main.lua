-- =================================================================
-- HUNT: Hard RP — Client Main Entry, Controls Whitelist & Event Router
-- =================================================================

local isUIOpen = false
local isInputFocused = false
local isCharacterSelected = false
local cachedSkin, cachedComps, cachedCompTints = {}, {}, {}
local cachedGender = "Male"
local clothingVisualRevision = 0

local function MergeTables(base, changes)
    local result = Utils.DeepCopy(type(base) == "table" and base or {})
    for key, value in pairs(type(changes) == "table" and changes or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = MergeTables(result[key], value)
        else
            result[key] = Utils.DeepCopy(value)
        end
    end
    return result
end

local function DecodeTable(value)
    return Utils.SafeJsonDecode(value, {})
end

local function SetAppearanceCache(skin, comps, compTints, gender, merge)
    local decodedSkin, decodedComps, decodedTints = DecodeTable(skin), DecodeTable(comps), DecodeTable(compTints)
    if merge then
        decodedSkin = MergeTables(cachedSkin, decodedSkin)
        decodedComps = MergeTables(cachedComps, decodedComps)
        decodedTints = MergeTables(cachedCompTints, decodedTints)
    end
    cachedSkin, cachedGender = Utils.NormalizeSkin(decodedSkin, gender or cachedGender)
    LocalPlayer.state:set('thehuntScale', tonumber(cachedSkin.Scale or cachedSkin.scale) or 1.0, true)
    cachedComps = decodedComps
    cachedCompTints = decodedTints
    for _, category in ipairs({ "Hair", "Beard", "Teeth" }) do
        if cachedComps[category] == nil and cachedSkin[category] ~= nil then cachedComps[category] = cachedSkin[category] end
    end
    if cachedComps.Hair ~= nil then cachedSkin.Hair = type(cachedComps.Hair) == "table" and cachedComps.Hair.comp or cachedComps.Hair end
    if cachedComps.Beard ~= nil then cachedSkin.Beard = type(cachedComps.Beard) == "table" and cachedComps.Beard.comp or cachedComps.Beard end
    if cachedComps.Teeth ~= nil then cachedSkin.Teeth = type(cachedComps.Teeth) == "table" and cachedComps.Teeth.comp or cachedComps.Teeth end
end

local function ApplyCachedAppearance(ped)
    local target = ped or PlayerPedId()
    if target == PlayerPedId() and LocalPlayer.state.huntPedCustomActive then return end
    Appearance.ApplyAll(target, cachedSkin, cachedGender)
    Clothing.ApplyAll(target, cachedComps, cachedCompTints)
    Appearance.UpdatePedVariation(target)
    Appearance.ApplyFaceDetails(target, cachedSkin, cachedGender)
end

-- The body build is a pair of MetaPed base meshes.  Apply it explicitly after
-- VORP has finished its spawn preset, then put the saved clothes back over
-- it.  BuildIndex and ToneId are authoritative; missing/legacy data
-- deliberately falls back to entry #1 and tone #1.
local function ResolveCachedBodyBuild()
    local genderKey = cachedGender == "Female" and "female" or "male"
    local genderLetter = genderKey == "female" and "F" or "M"
    local builds = AppearanceData.BodyBuilds and AppearanceData.BodyBuilds[genderKey] or {}
    local buildIndex = math.floor(tonumber(cachedSkin.BuildIndex or cachedSkin.buildIndex) or 1)
    buildIndex = math.max(1, math.min(#builds, buildIndex))
    local build = builds[buildIndex] or builds[1]
    if not build then return nil end

    local toneCount = #(AppearanceData.SkinTones or {})
    local toneId = math.floor(tonumber(cachedSkin.ToneId or cachedSkin.toneId) or 1)
    toneId = math.max(1, math.min(toneCount > 0 and toneCount or 1, toneId))

    -- BodyBuilds stores the default V_001 variant.  Rebuild the same catalog
    -- entry with the saved skin tone, otherwise delayed spawn/clothing passes
    -- silently turn the torso and legs back to the light tone.
    local upperHash = joaat(string.format(
        "CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", genderLetter, buildIndex, toneId
    ))
    local lowerHash = joaat(string.format(
        "CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", genderLetter, buildIndex, toneId
    ))

    return buildIndex, upperHash, lowerHash
end

local function ApplyCachedBodyBuild(ped)
    local target = ped or PlayerPedId()
    if target == PlayerPedId() and LocalPlayer.state.huntPedCustomActive then return end
    local buildIndex, upperHash, lowerHash = ResolveCachedBodyBuild()
    if not buildIndex then return end

    cachedSkin.BuildIndex = buildIndex
    cachedSkin.BodyType = upperHash
    cachedSkin.LegsType = lowerHash
    Appearance.ApplyBodyBase(target, upperHash, lowerHash, false)
    Clothing.ApplyAll(target, cachedComps, cachedCompTints)
    Appearance.UpdatePedVariation(target)
    Appearance.ApplyFaceDetails(target, cachedSkin, cachedGender)
end

-- Apply only the saved body meshes. This is used when a lower garment is
-- removed; rebuilding all clothing here would reintroduce the very reload
-- that the inventory path is designed to avoid.
local function ApplyCachedBodyBaseOnly(ped)
    local target = ped or PlayerPedId()
    if target == PlayerPedId() and LocalPlayer.state.huntPedCustomActive then return end
    local buildIndex, upperHash, lowerHash = ResolveCachedBodyBuild()
    if not buildIndex then return end

    cachedSkin.BuildIndex = buildIndex
    cachedSkin.BodyType = upperHash
    cachedSkin.LegsType = lowerHash
    Appearance.ApplyBodyBase(target, upperHash, lowerHash, false)
end

local function ComponentHash(value)
    if type(value) == "table" then value = value.comp or value.hash end
    return tonumber(value) or -1
end

local function GetWorldSnapshot()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil, nil end
    local coords = GetEntityCoords(ped)
    -- These natives need explicit result converters in RedM. Without them the
    -- invoker can return nil, silently preventing the whole snapshot upload.
    local healthCore = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger()))
    local stamina = tonumber(Citizen.InvokeNative(0x22F2A386D43048A9, ped, Citizen.ResultAsFloat()))
    local staminaCore = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, ped, 1, Citizen.ResultAsInteger()))
    local sprintStamina = nil
    pcall(function()
        sprintStamina = exports["thehunt_stamina"]:GetCurrentStamina()
    end)
    if not coords or not healthCore or not stamina or not staminaCore then return nil, nil end
    sprintStamina = tonumber(sprintStamina) or math.max(0, math.min(100, stamina))
    return { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }, {
        health = GetEntityHealth(ped), healthCore = healthCore, stamina = stamina, staminaCore = staminaCore,
        sprintStamina = sprintStamina
    }
end

local function SaveWorldSnapshot()
    if not isCharacterSelected or isUIOpen or LocalPlayer.state.isCreatingChar or LocalPlayer.state.isSelectingChar then return end
    local coords, state = GetWorldSnapshot()
    if coords and state then
        TriggerServerEvent(Constants.Events.SAVE_WORLD_STATE, coords, state)
        exports.thehunt_core:SaveMetabolism()
    end
end

RegisterNetEvent(Constants.Events.PREPARE_SELECTION, function()
    SaveWorldSnapshot()
    -- Client->server events are ordered. The server opens the selector only
    -- after the snapshot event queued immediately above has been handled.
    TriggerServerEvent(Constants.Events.OPEN_SELECTION_AFTER_SAVE)
end)

local function RestoreWorldState(ped, state, charIdentifier)
    if type(state) ~= "table" or tonumber(state.charidentifier) ~= tonumber(charIdentifier) then return false end
    local health, healthCore = tonumber(state.health), tonumber(state.health_core)
    local stamina, staminaCore = tonumber(state.stamina), tonumber(state.stamina_core)
    local sprintStamina = tonumber(state.sprint_stamina)
    if health and healthCore and stamina and staminaCore then
        SetAttributeCoreValue(ped, 0, math.max(0, math.min(100, healthCore)))
        SetEntityHealth(ped, math.max(0, math.min(1000, health)), 0)
        SetAttributeCoreValue(ped, 1, math.max(0, math.min(100, staminaCore)))
        local currentStamina = tonumber(Citizen.InvokeNative(0x22F2A386D43048A9, ped, Citizen.ResultAsFloat())) or 0
        ChangePedStamina(ped, (math.max(0, math.min(1000, stamina)) - currentStamina) + 0.0)
    end
    if sprintStamina then
        pcall(function() exports["thehunt_stamina"]:SetCurrentStamina(math.max(0, math.min(100, sprintStamina))) end)
    end
    return true
end

local function ApplyFreshCharacterVitals(ped)
    -- A newly created or legacy character with no snapshot must never inherit
    -- values from the preview ped of the character selected just before it.
    SetAttributeCoreValue(ped, 0, 100)
    SetEntityHealth(ped, GetEntityMaxHealth(ped), 0)
    SetAttributeCoreValue(ped, 1, 100)
    pcall(function() exports["thehunt_stamina"]:SetCurrentStamina(100.0) end)
end

-- =================================================================
-- UI Control & Input Focus Management (AI_NOTES & ui_controls_guidelines)
-- =================================================================

RegisterNUICallback("setInputFocusState", function(data, cb)
    isInputFocused = (data and data.hasFocus == true)
    cb("ok")
end)

-- UI Control Filter Thread
CreateThread(function()
    local whitelistUI = {
        0xF1301666, 0x05CA7C52, -- Voice Push to talk
        `INPUT_PUSH_TO_TALK`,
        `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_MOVE_UP_ONLY`, `INPUT_MOVE_DOWN_ONLY`, `INPUT_MOVE_LEFT_ONLY`, `INPUT_MOVE_RIGHT_ONLY`,
        `INPUT_SPRINT`, `INPUT_JUMP`, `INPUT_CLIMB`, `INPUT_DUCK`,
        `INPUT_HORSE_MOVE_UD`, `INPUT_HORSE_MOVE_LR`,
        `INPUT_VEH_ACCELERATE`, `INPUT_VEH_BRAKE`
    }

    while true do
        if isInputFocused then
            -- TOTAL CONTROL LOCK DURING TEXT INPUT FOCUS
            Wait(0)
            local ped = PlayerPedId()
            for pad = 0, 2 do
                DisableAllControlActions(pad)
            end
            DisablePlayerFiring(ped, true)
        elseif isUIOpen then
            -- WHITELIST MOVEMENT ONLY WHEN UI IS OPEN
            Wait(0)
            local ped = PlayerPedId()
            for pad = 0, 2 do
                DisableAllControlActions(pad)
                for _, control in ipairs(whitelistUI) do
                    EnableControlAction(pad, control, true)
                end
            end
            DisablePlayerFiring(ped, true)
        else
            Wait(150)
        end
    end
end)

-- UI Status HUD Suppressor Thread
CreateThread(function()
    while true do
        if isUIOpen then
            TriggerEvent("thehunt_status:setVisible", false)
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

-- =================================================================
-- Character Events Router
-- =================================================================

exports('isCharacterMenuOpen', function()
    return isUIOpen
end)

-- Позволяет HUD-ресурсам восстановить состояние после собственного restart,
-- не повторяя событие выбора персонажа для остальных систем.
exports('isCharacterSelected', function()
    return isCharacterSelected
end)

RegisterNetEvent(Constants.Events.RECEIVE_CHARACTERS, function(data)
    isUIOpen = true
    LocalPlayer.state:set('isSelectingChar', true, false)
    SetPlayerInvincible(PlayerId(), true)
    TriggerEvent("thehunt_status:setVisible", false)
    pcall(function()
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end)
    Creator.Close()
    Selection.Open(data)
end)

RegisterNetEvent(Constants.Events.OPEN_CREATOR, function(data)
    isUIOpen = true
    LocalPlayer.state:set('isCreatingChar', true, false)
    SetPlayerInvincible(PlayerId(), true)
    TriggerEvent("thehunt_status:setVisible", false)
    pcall(function()
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end)
    Selection.Close()
    Creator.Start(data)
end)

RegisterNetEvent(Constants.Events.OPEN_SELECTION, function(data)
    isUIOpen = true
    LocalPlayer.state:set('isSelectingChar', true, false)
    SetPlayerInvincible(PlayerId(), true)
    TriggerEvent("thehunt_status:setVisible", false)
    pcall(function()
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end)
    Creator.Close()
    Selection.Open(data)
end)

RegisterNetEvent("thehunt_character:client:ApplyAndSpawn", function(data)
    isUIOpen = false
    isInputFocused = false
    isCharacterSelected = true

    DoScreenFadeOut(500)
    Wait(500)

    -- 1. Close selection and creator
    Selection.Close()
    Creator.Close()

    -- 2. Destroy camera, cleanup preview, clear timecycles & audio
    Camera.Destroy()
    Preview.Cleanup()
    ClearFocus()
    ClearTimecycleModifier()
    pcall(function()
        NetworkClearClockTimeOverride()
        Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area", false, false)
    end)

    -- 3. Load Model
    SetAppearanceCache(data.skin, data.comps, data.compTints, data.gender, false)
    local gender = cachedGender
    local modelHash = (gender == "Female" or gender == "mp_female") and AppearanceData.Models.female or AppearanceData.Models.male

    RequestModel(modelHash)
    local t = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - t > 6000 then break end
    end

    Appearance.ReleasePed(PlayerPedId())
    SetPlayerModel(PlayerId(), modelHash, false)
    SetModelAsNoLongerNeeded(modelHash)

    Wait(150)
    local ped = PlayerPedId()

    -- 4. Apply Appearance & Clothing
    ApplyCachedAppearance(ped)
    if ComponentHash(cachedComps.Gunbelt) == -1 then
        Clothing.RemoveTag(ped, ClothingData.Categories.Gunbelt)
    end
    if ComponentHash(cachedComps.Holster) == -1 then
        Clothing.RemoveTag(ped, ClothingData.Categories.Holster)
    end
    Appearance.UpdatePedVariation(ped)

    -- 5. Teleport to saved position (with collision wait)
    local coords = data.coords or Config.DefaultSpawn
    local heading = data.heading or 0.0

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    StartPlayerTeleport(PlayerId(), coords.x, coords.y, coords.z, heading, true, true, true, true)
    t = GetGameTimer()
    while IsPlayerTeleportActive() and (GetGameTimer() - t < 5000) do
        Wait(10)
    end

    -- Extra wait for collision to load
    t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - t < 3000) do
        Wait(50)
    end

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255, false)
    -- The isolated UI scene ends only once the player has reached the world.
    -- Until this point metabolism and damage remain paused.
    LocalPlayer.state:set('isCreatingChar', false, false)
    LocalPlayer.state:set('isSelectingChar', false, false)
    SetPlayerInvincible(PlayerId(), false)
    TriggerServerEvent("thehunt_character:server:spawnComplete")

    -- 6. Trigger VORP core spawn handlers & status restoration
    TriggerEvent("thehunt_core:client:initializeCharacter", coords, heading, data.isDead)
    -- Some VORP spawn handlers finish their default MetaPed setup after the
    -- event returns. Apply the exact cached snapshot once that pass is over:
    -- do not rebuild hashes here, as the snapshot already contains the
    -- validated heritage selected in the creator.
    SetTimeout(650, function()
        if isCharacterSelected and not isUIOpen then
            ApplyCachedAppearance(PlayerPedId())
            ApplyCachedBodyBuild(PlayerPedId())
        end
    end)
    if not RestoreWorldState(ped, data.worldState, data.charIdentifier) then
        ApplyFreshCharacterVitals(ped)
    end
    -- thehunt_stamina re-initializes after VORP's character events; restore
    -- once more after that handler has completed.
    SetTimeout(900, function()
        if isCharacterSelected and not isUIOpen then
            if not RestoreWorldState(PlayerPedId(), data.worldState, data.charIdentifier) then
                ApplyFreshCharacterVitals(PlayerPedId())
            end
        end
    end)
    TriggerEvent("thehunt_status:setVisible", true)

    SaveWorldSnapshot()

    Wait(600)
    DoScreenFadeIn(1000)
end)

RegisterNetEvent(Constants.Events.CHARACTER_SPAWNED, function(data)
    isUIOpen = false
    isInputFocused = false
    isCharacterSelected = true
    LocalPlayer.state:set('isCreatingChar', false, false)
    LocalPlayer.state:set('isSelectingChar', false, false)
    SetPlayerInvincible(PlayerId(), false)
    Selection.Close()
    Creator.Close()
    pcall(function()
        TriggerEvent("thehunt_status:setVisible", true)
    end)
end)

RegisterNetEvent(Constants.Events.NOTIFY_ERROR, function(msg)
    SendNUIMessage({ action = "selectionActionFailed" })
    SendNUIMessage({
        action = "showNotification",
        type = "error",
        message = msg
    })
    -- Fallback to hunt status notification if available
    pcall(function()
        TriggerEvent("thehunt_status:notify", "Ошибка", msg, "error")
    end)
end)

RegisterNetEvent(Constants.Events.APPEARANCE_SAVED, function(data)
    if type(data) == "table" then
        SetAppearanceCache(data.skin, data.comps, data.compTints, data.gender, false)
        if isCharacterSelected and not isUIOpen then ApplyCachedAppearance(PlayerPedId()) end
    end
end)

-- Full database appearance restore used by the player menu.  The caller
-- supplies the live inventory clothing components separately, so this event
-- restores body/face data without replacing equipment-owned garments.
RegisterNetEvent("thehunt_character:client:ApplyDatabaseAppearance", function(skin, comps, compTints, gender)
    SetAppearanceCache(skin, comps, compTints, gender or cachedGender, false)
    if isCharacterSelected and not isUIOpen then
        local ped = PlayerPedId()
        ApplyCachedAppearance(ped)
        -- Character spawn applies the selected body build as a separate
        -- MetaPed base pass. The menu reload must do the same or VORP's
        -- default body can remain underneath the restored clothing.
        ApplyCachedBodyBuild(ped)
        SetTimeout(150, function()
            if isCharacterSelected and not isUIOpen then
                local currentPed = PlayerPedId()
                ApplyCachedBodyBuild(currentPed)
            end
        end)
    end
end)

exports('ApplyDatabaseAppearance', function(skin, comps, compTints, gender)
    TriggerEvent("thehunt_character:client:ApplyDatabaseAppearance", skin, comps, compTints, gender)
end)

-- Inventory clothing changes are intentionally incremental.  Apply only the
-- changed MetaPed tag and keep cachedSkin (including body morph/build values)
-- untouched; no full Appearance.ApplyAll/Clothing.ApplyAll pass is needed.
RegisterNetEvent("thehunt_character:client:ApplySingleClothing", function(category, component, tint, gender)
    if LocalPlayer.state.huntPedCustomActive then return end
    if type(category) ~= "string" then return end
    clothingVisualRevision = clothingVisualRevision + 1
    local revision = clothingVisualRevision
    cachedGender = gender or cachedGender
    cachedComps[category] = tonumber(component) or -1
    if type(tint) == "table" then cachedCompTints[category] = tint else cachedCompTints[category] = nil end
    if not isUIOpen and DoesEntityExist(PlayerPedId()) then
        local ped = PlayerPedId()
        local componentHash = cachedComps[category]
        if componentHash == -1 or componentHash == 0 then
            -- Removal is deliberately explicit.  Some MetaPed categories
            -- keep their wearable state after the generic apply path, which
            -- leaves the old garment visible until the next full outfit
            -- rebuild.  Clear the exact category first, then restore the
            -- selected body's base layer for torso/legs.
            local categoryHash = ClothingData.Categories and ClothingData.Categories[category]
            if categoryHash then Clothing.RemoveTag(ped, categoryHash) end
            if category == "Pant" or category == "Skirt" then
                ApplyCachedBodyBaseOnly(ped)
                Clothing.RemoveTagRaw(ped, ClothingData.Categories.Boots)
            elseif category == "Shirt" then
                Appearance.RestoreUpperBody(ped, false)
            end
            Appearance.UpdatePedVariation(ped)
        else
            Clothing.ApplyComponent(ped, componentHash, category, cachedCompTints[category], false)
            -- Boots stay equipped in the inventory while bare legs hide their
            -- native layer. Once a lower garment is put back, reveal those
            -- same boots without requiring a full outfit reload.
            if category == "Pant" or category == "Skirt" or category == "Dress" then
                local boots = ComponentHash(cachedComps.Boots)
                if boots ~= -1 and boots ~= 0 then
                    Clothing.ApplyComponent(ped, boots, "Boots", cachedCompTints.Boots, true)
                end
            end
        end
        Appearance.UpdatePedVariation(ped)

        -- VORP/MetaPed may finish a queued wearable-state update one frame
        -- after the native removal. Re-assert only this category once; do
        -- not rebuild the complete outfit. The revision guard prevents an
        -- old removal from clearing a newly equipped item.
        if componentHash == -1 or componentHash == 0 then
            CreateThread(function()
                Wait(150)
                if revision ~= clothingVisualRevision or isUIOpen then return end
                local currentPed = PlayerPedId()
                if not DoesEntityExist(currentPed) then return end
                local currentHash = ClothingData.Categories and ClothingData.Categories[category]
                if currentHash then Clothing.RemoveTagRaw(currentPed, currentHash) end
                if category == "Pant" or category == "Skirt" then
                    ApplyCachedBodyBaseOnly(currentPed)
                    Clothing.RemoveTagRaw(currentPed, ClothingData.Categories.Boots)
                elseif category == "Shirt" then
                    Appearance.RestoreUpperBody(currentPed, false)
                end
                Appearance.UpdatePedVariation(currentPed)
            end)
        end
    end
end)

RegisterNetEvent("thehunt:character:frameworkCache", function(skin, comps, compTints)
    SetAppearanceCache(skin, comps, compTints, cachedGender, true)
    if isCharacterSelected and not isUIOpen then ApplyCachedAppearance(PlayerPedId()) end
    TriggerServerEvent(Constants.Events.UPDATE_APPEARANCE, {
        skin = cachedSkin, comps = cachedComps, compTints = cachedCompTints, fullSnapshot = true
    })
end)

RegisterNetEvent("thehunt:character:frameworkSaveNew", function(comps, skin)
    local skinChanges, compChanges = DecodeTable(skin), DecodeTable(comps)
    -- Stock vorp_barbershop sends { Hair, Beard } as its second (skin)
    -- argument. Mirror those shop items into the component snapshot because
    -- this resource applies them through both schemas for compatibility.
    for _, category in ipairs({ "Hair", "Beard", "Teeth" }) do
        if skinChanges[category] ~= nil and compChanges[category] == nil then
            compChanges[category] = skinChanges[category]
        end
    end
    SetAppearanceCache(skinChanges, compChanges, nil, cachedGender, true)
    if isCharacterSelected and not isUIOpen then ApplyCachedAppearance(PlayerPedId()) end
    TriggerServerEvent(Constants.Events.UPDATE_APPEARANCE, {
        skin = cachedSkin, comps = cachedComps, compTints = cachedCompTints, fullSnapshot = true
    })
end)

RegisterNetEvent("thehunt:character:frameworkReloadAfterDeath", function()
    if isCharacterSelected then
        Wait(100)
        ApplyCachedAppearance(PlayerPedId())
    end
end)

RegisterNetEvent(Constants.Events.NOTIFY_SUCCESS, function(msg)
    SendNUIMessage({
        action = "showNotification",
        type = "success",
        message = msg
    })
    pcall(function()
        TriggerEvent("thehunt_status:notify", "Персонаж", msg, "success")
    end)
end)

RegisterNetEvent(Constants.Events.CREATION_FAILED, function(msg)
    isUIOpen = true
    isInputFocused = false
    SendNUIMessage({ action = "creatorSubmissionFailed", message = msg })
    pcall(function()
        TriggerEvent("thehunt_status:notify", "Персонаж", msg, "error")
    end)
end)

-- =================================================================
-- Periodic Autosave & Character Reload Command
-- =================================================================

CreateThread(function()
    while true do
        Wait(Config.WorldStateSaveInterval or 10000)
        SaveWorldSnapshot()
    end
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then SaveWorldSnapshot() end
end)

RegisterCommand(Config.ReloadCharCommand or "rc", function()
    if not isCharacterSelected or isUIOpen then return end
    local ped = PlayerPedId()
    Citizen.InvokeNative(0x8FE22675A5A3F450, ped) -- ClearPedBloodDamage
    Citizen.InvokeNative(0xD729577D7D9A4C0B, ped) -- ClearPedWetness
    Citizen.InvokeNative(0xB6545CF858EECD5B, ped) -- ClearPedEnvDirt
    Citizen.InvokeNative(0xD86D07CF3813B1F3, ped) -- ResetPedVisibleDamage
    ApplyCachedAppearance(ped)
    pcall(function()
        TriggerEvent("thehunt_status:notify", "Персонаж", "Внешний вид обновлен", "info")
    end)
end, false)

exports('GetCachedAppearance', function()
    return Utils.DeepCopy(cachedSkin), Utils.DeepCopy(cachedComps), Utils.DeepCopy(cachedCompTints), cachedGender
end)

exports('GetAppearanceState', function()
    return {
        skin = Utils.DeepCopy(cachedSkin),
        comps = Utils.DeepCopy(cachedComps),
        compTints = Utils.DeepCopy(cachedCompTints),
        gender = cachedGender
    }
end)

exports('ApplySingleClothing', function(category, component, tint, gender)
    TriggerEvent("thehunt_character:client:ApplySingleClothing", category, component, tint, gender)
end)

exports('ApplyAppearance', function(skin, comps, compTints, gender)
    SetAppearanceCache(skin, comps, compTints, gender, false)
    ApplyCachedAppearance(PlayerPedId())
end)

exports('SaveAppearance', function(skin, comps, compTints)
    SetAppearanceCache(skin, comps, compTints, cachedGender, false)
    TriggerServerEvent(Constants.Events.UPDATE_APPEARANCE, {
        skin = cachedSkin, comps = cachedComps, compTints = cachedCompTints, fullSnapshot = true
    })
end)
