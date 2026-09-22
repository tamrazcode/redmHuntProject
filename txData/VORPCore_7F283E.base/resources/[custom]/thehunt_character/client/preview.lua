-- =================================================================
-- HUNT: Hard RP — Selection Scene & Preview Ped Management
-- Full-LOD Scene Streaming, Immediate Ped Materialization & Illumination
-- =================================================================

Preview = {}
local previewPed = nil
local activeScene = nil
local activeCam = nil
local previewRequestId = 0

local function DeletePreviewPed(ped)
    if ped and DoesEntityExist(ped) then
        Appearance.ReleasePed(ped)
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
    end
end

local function ComponentHash(value)
    if type(value) == "table" then value = value.comp or value.hash end
    return tonumber(value) or -1
end

-- Match the stock VORP LoadAll preparation for a newly-created presentation
-- ped. CreatePed retains default MetaPed tags, unlike a player ped immediately
-- after SetPlayerModel; those leftover BODIES_LOWER layers are the source of
-- underwear/pantaloon textures leaking through a saved pair of trousers.
local function ResetPreviewComponents(ped)
    for _, categoryHash in pairs(ClothingData.Categories or {}) do
        Clothing.RemoveTagRaw(ped, categoryHash)
    end
    ResetPedComponents(ped)
    Appearance.UpdatePedVariation(ped)
    Appearance.WaitForPedReady(ped)
end

--- Setup ambient environment for character selection scene
--- @param sceneData table
function Preview.SetupScene(sceneData)
    -- See the matching guard in thehunt_core/world_cleaner.lua.  This is a
    -- client-local UI mode, so it cannot weaken NPC cleanup for other players.
    TriggerEvent("thehunt_core:worldCleaner:setCharacterSelectionMode", true)
    activeScene = sceneData or (Config.SelectionScenes and Config.SelectionScenes[1]) or {
        spawn = vector4(-558.506, -3781.050, 237.60, 93.2),
        camera = { x = -560.85, y = -3781.05, z = 238.40, rotx = 0.0, roty = 0.0, rotz = -90.0, fov = 45.0 }
    }

    local spawnCoords = activeScene.spawn or vector4(-558.506, -3781.050, 237.60, 93.2)
    local camData = activeScene.camera or { x = spawnCoords.x - 2.5, y = spawnCoords.y, z = spawnCoords.z + 0.8, fov = 45.0 }
    
    -- 1. Stream scene sphere and focus around spawn to load full-resolution textures & collision
    Citizen.InvokeNative(0x513F8AA5BF2F17CF, spawnCoords.x, spawnCoords.y, spawnCoords.z, 60.0, 20)
    SetFocusPosAndVel(spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)

    local ped = PlayerPedId()
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
    -- The displayed character is a separate preview NPC. Hide the real player
    -- ped so the two entities can never overlap in the selection scene.
    SetEntityVisible(ped, false)
    FreezeEntityPosition(ped, true)

    local timer = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - timer < 2500) do
        Wait(20)
    end
    
    -- 2. Set weather and time safely
    if activeScene.weather then
        pcall(function()
            local weatherHash = GetHashKey(activeScene.weather)
            Citizen.InvokeNative(0x59174F1AF63842E8, weatherHash, true, true, true, true, false)
        end)
    end

    if activeScene.time then
        pcall(function()
            NetworkClockTimeOverride(activeScene.time.hour or 12, activeScene.time.minute or 0, 0, 0, true)
        end)
    end

    -- Re-apply the deliberately frozen atmosphere while this screen is open.
    CreateThread(function()
        local sceneAtStart = activeScene
        while activeScene == sceneAtStart do
            if sceneAtStart.time then
                NetworkClockTimeOverride(sceneAtStart.time.hour or 19, sceneAtStart.time.minute or 20, 0, 0, true)
            end
            if sceneAtStart.weather then
                Citizen.InvokeNative(0x59174F1AF63842E8, GetHashKey(sceneAtStart.weather), true, true, true, true, false)
            end
            Wait(1000)
        end
    end)

    if activeScene.timecycle and activeScene.timecycle.name then
        pcall(function()
            SetTimecycleModifier(activeScene.timecycle.name)
            SetTimecycleModifierStrength(activeScene.timecycle.strength or 1.0)
        end)
    end

    -- 3. Setup Camera pointing directly at character spawn
    Camera.Destroy()
    if activeCam and DoesCamExist(activeCam) then
        DestroyCam(activeCam, false)
        activeCam = nil
    end

    activeCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camData.x, camData.y, camData.z, 0.0, 0.0, 0.0, camData.fov or 45.0, false, 0)
    PointCamAtCoord(activeCam, spawnCoords.x, spawnCoords.y, spawnCoords.z + 0.92)
    SetCamActive(activeCam, true)
    RenderScriptCams(true, true, 800, true, true)

    CreateThread(function()
        local sceneAtStart = activeScene
        while activeScene == sceneAtStart and activeCam and DoesCamExist(activeCam) do
            -- Warm key light from camera-left: keeps the face readable against
            -- the sunset while preserving the silhouette and landscape mood.
            -- A compact key light sits directly on the camera side of the
            -- scene, illuminating the preview without changing its location.
            DrawLightWithRange(camData.x, camData.y, camData.z + 0.18, 255, 244, 224, 10.0, 20.0)
            if type(DrawSpotLight) == "function" then
                local dx = spawnCoords.x - camData.x
                local dy = spawnCoords.y - camData.y
                local dz = (spawnCoords.z + 1.0) - (camData.z + 0.18)
                local length = math.sqrt(dx * dx + dy * dy + dz * dz)
                if length > 0.001 then
                    DrawSpotLight(camData.x, camData.y, camData.z + 0.18,
                        dx / length, dy / length, dz / length,
                        255, 244, 224, 12.0, 18.0, 4.0, 24.0, 1.0)
                end
            end
            DrawLightWithRange(spawnCoords.x + 0.70, spawnCoords.y + 0.35, spawnCoords.z + 1.15, 170, 205, 255, 4.0, 2.5)
            Wait(0)
        end
    end)
end

--- Spawn or update 3D preview ped for a selected character card
--- @param charData table
function Preview.ShowCharacter(charData)
    if not charData then return end
    previewRequestId = previewRequestId + 1
    local requestId = previewRequestId
    -- The selection ped must be built from the same normalized skin snapshot
    -- as the actual spawned character.  In particular BodyType/LegsType and
    -- Waist select the compatible naked body meshes before trousers/shirts
    -- are layered, preventing their albedo from leaking into skin/underwear.
    local savedSkin, savedGender = Utils.NormalizeSkin(
        Utils.SafeJsonDecode(charData.skin, {}),
        charData.gender
    )
    local savedComps = Utils.SafeJsonDecode(charData.comps, {})
    local savedCompTints = Utils.SafeJsonDecode(charData.compTints, {})
    -- Keep the snapshot identical to the one applied by ApplyAndSpawn.
    for _, category in ipairs({ "Hair", "Beard", "Teeth" }) do
        if savedComps[category] == nil and savedSkin[category] ~= nil then
            savedComps[category] = savedSkin[category]
        end
    end
    for _, category in ipairs({ "Hair", "Beard", "Teeth" }) do
        if savedComps[category] ~= nil then
            savedSkin[category] = ComponentHash(savedComps[category])
        end
    end
    if not activeScene then
        activeScene = (Config.SelectionScenes and Config.SelectionScenes[1]) or {
            spawn = vector4(-558.506, -3781.050, 237.60, 93.2),
            camera = { x = -560.85, y = -3781.05, z = 238.40, rotx = 0.0, roty = 0.0, rotz = -90.0, fov = 45.0 }
        }
    end

    local modelHash = savedGender == "Female" and AppearanceData.Models.female or AppearanceData.Models.male
    
    RequestModel(modelHash)
    local timer = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - timer > 5000 then
            print("[thehunt_character] Preview model did not load: " .. tostring(modelHash))
            return
        end
    end

    local spawnCoords = activeScene.spawn or vector4(-558.506, -3781.050, 237.60, 93.2)
    local groundZ = spawnCoords.z
    local hit, foundZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z + 1.5, false)
    if hit and foundZ and foundZ > 10.0 then groundZ = foundZ end
    local incomingPed = CreatePed(modelHash, spawnCoords.x, spawnCoords.y, groundZ, spawnCoords.w or 0.0, false, false, false, false)
    if not incomingPed or incomingPed == 0 then
        print("[thehunt_character] Preview ped could not be created")
        SetModelAsNoLongerNeeded(modelHash)
        return
    end
    SetEntityAsMissionEntity(incomingPed, true, true)
    PlaceObjectOnGroundProperly(incomingPed)
    FreezeEntityPosition(incomingPed, true)
    SetEntityCollision(incomingPed, false, false)

    -- Always turn the preview toward the active scene camera. Scene spawn
    -- headings differ, while the character card must consistently show a face.
    local camData = activeScene.camera
    if camData then
        SetEntityHeading(incomingPed, GetHeadingFromVector_2d(camData.x - spawnCoords.x, camData.y - spawnCoords.y))
    end
    SetEntityVisible(incomingPed, true)
    -- Never depend on the transition thread for the initial model: if a
    -- native used by an idle scenario is unavailable, the preview must still
    -- be visible.
    SetEntityAlpha(incomingPed, 0, false)
    SetEntityInvincible(incomingPed, true)
    SetBlockingOfNonTemporaryEvents(incomingPed, true)
    SetPedCanBeTargetted(incomingPed, false)
    
    Appearance.WaitForPedReady(incomingPed)
    ResetPreviewComponents(incomingPed)

    -- Appearance composition yields while texture data is prepared.  A newer
    -- card click may have completed during that wait; a stale request must
    -- never delete or replace the current preview.
    if requestId ~= previewRequestId or not activeScene then
        DeletePreviewPed(incomingPed)
        return
    end

    -- Aim at the finalized, ground-aligned ped rather than the authored
    -- coordinate, keeping the full figure centred even on uneven terrain.
    if activeCam and DoesCamExist(activeCam) then
        local finalCoords = GetEntityCoords(incomingPed)
        local pelvis = GetEntityBoneIndexByName(incomingPed, "SKEL_Pelvis")
        local targetZ = finalCoords.z + 0.92
        if pelvis and pelvis ~= -1 then
            local pelvisPos = GetWorldPositionOfEntityBone(incomingPed, pelvis)
            if pelvisPos then targetZ = pelvisPos.z end
        end
        PointCamAtCoord(activeCam, finalCoords.x, finalCoords.y, targetZ)
    end

    -- Always compose the saved base body before the saved outfit.  Do not use
    -- a generic preview build here: body mesh and waist must match the actual
    -- character for MetaPed to select the correct garment texture layers.
    Appearance.ApplyAll(incomingPed, savedSkin, savedGender)
    local hasLowerGarment = ComponentHash(savedComps.Pant) ~= -1
        or ComponentHash(savedComps.Skirt) ~= -1
        or ComponentHash(savedComps.Dress) ~= -1
    -- This is the same final lower-base pass used when fitting trousers in the
    -- creator. It prevents the default CreatePed underwear layer from winning
    -- the MetaPed resolve that follows the trouser tag.
    if hasLowerGarment then
        Appearance.RestoreLowerBody(incomingPed, false)
    end
    if next(savedComps) then
        Clothing.ApplyAll(incomingPed, savedComps, savedCompTints)
    end
    if ComponentHash(savedComps.Gunbelt) == -1 then
        Clothing.RemoveTag(incomingPed, ClothingData.Categories.Gunbelt)
    end
    if ComponentHash(savedComps.Holster) == -1 then
        Clothing.RemoveTag(incomingPed, ClothingData.Categories.Holster)
    end
    Appearance.UpdatePedVariation(incomingPed)

    if requestId ~= previewRequestId or not activeScene then
        DeletePreviewPed(incomingPed)
        return
    end

    -- Replace the old preview only after the new one is fully composed.  The
    -- model is then revealed at full opacity immediately: no fall, movement,
    -- cross-fade or overlap is visible to the player.
    local outgoingPed = previewPed
    if outgoingPed and DoesEntityExist(outgoingPed) then
        DeletePreviewPed(outgoingPed)
    end
    previewPed = incomingPed
    SetEntityVisible(previewPed, true)
    SetEntityAlpha(previewPed, 255, false)
    ResetEntityAlpha(previewPed)
    FreezeEntityPosition(previewPed, true)
    SetFocusEntity(previewPed)

    -- Scenario tasks can despawn this frozen, isolated presentation ped.
    -- Keep it in a stable standing pose until a dedicated idle animation is
    -- configured for preview entities.

    SetModelAsNoLongerNeeded(modelHash)
end

--- Clear preview ped
function Preview.ClearPed()
    previewRequestId = previewRequestId + 1
    DeletePreviewPed(previewPed)
    previewPed = nil
end

--- Clean up selection environment
function Preview.Cleanup()
    Preview.ClearPed()
    if activeCam and DoesCamExist(activeCam) then
        DestroyCam(activeCam, false)
        activeCam = nil
    end
    Camera.Destroy()
    ClearFocus()
    pcall(function()
        NetworkClearClockTimeOverride()
        ClearTimecycleModifier()
    end)
    activeScene = nil
    TriggerEvent("thehunt_core:worldCleaner:setCharacterSelectionMode", false)
end
