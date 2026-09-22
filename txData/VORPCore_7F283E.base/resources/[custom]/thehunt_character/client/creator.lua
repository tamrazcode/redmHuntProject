-- =================================================================
-- HUNT: Hard RP — Character Creator Controller
-- Full Pipeline: IPL Load → Ped Spawn → Camera → NUI → Appearance
-- =================================================================

Creator = {}

local isCreating = false
local worldEditor = false

exports('ApplyPedCustomAppearance', function(ped, data)
    if not DoesEntityExist(ped) then return false end
    if GetInvokingResource() ~= 'thehunt_pedcustom' then return false end
    local charGender = data.gender or (IsPedMale(ped) and 'Male' or 'Female')
    Appearance.ApplyAll(ped, data.skin or {}, charGender)
    Clothing.ApplyAll(ped, data.comps or {}, data.compTints or {})
    return true
end)
local currentGender = "Male"
local genderStates = { Male = nil, Female = nil }
local teethPreviewRevision = 0
local genderSwitchRevision = 0

-- Creator state mirrors JS creatorState exactly (PascalCase skin keys for ApplyAll compat)
local characterState = {
    firstname = "",
    lastname  = "",
    gender    = "Male",
    age       = 25,
    nation    = "Американец",
    skin = {
        -- PascalCase keys to match Appearance.ApplyAll expectations
        Head        = 0,   -- joaat hash of current head component
        HeadIndex   = 8,   -- sparse MetaPed head component index
        ToneId      = 1,   -- 1..6 skin tone index
        Eyes        = 0,   -- joaat hash
        BodyType    = 0,   -- upper body hash
        LegsType    = 0,   -- lower body hash
        BuildIndex  = 1,   -- 1..5 body build index
        Waist       = 0,   -- waist component hash
        Scale       = 1.0, -- height scale
        albedo      = 0,   -- albedo texture hash (lowercase: used internally)
        features    = {},  -- morphs { id = value }
        overlays    = {}   -- overlays { name = { visibility, tx_id, opacity } }
    },
    comps    = {},
    compTints = {}
}

-- =================================================================
-- Internal helpers
-- =================================================================

--- Wait for IPL hash to become active (max 3s)
local function WaitForIpl(hash)
    local t = GetGameTimer()
    while not IsIplActiveByHash(hash) and (GetGameTimer() - t < 3000) do
        Wait(50)
    end
end

--- Activate mirror entity sets based on gender
local function SetCreatorMirrors(isMale)
    local interior = GetInteriorAtCoords(-561.8157, -3780.966, 239.0805)
    if IsValidInterior(interior) ~= 1 then return end
    if IsInteriorReady(interior) ~= 1 then return end

    if isMale then
        if IsInteriorEntitySetValid(interior, "mp_char_female_mirror") == 1 and
           IsInteriorEntitySetActive(interior, "mp_char_female_mirror") then
            DeactivateInteriorEntitySet(interior, "mp_char_female_mirror", true)
        end
        if IsInteriorEntitySetValid(interior, "mp_char_male_mirror") == 1 and
           not IsInteriorEntitySetActive(interior, "mp_char_male_mirror") then
            ActivateInteriorEntitySet(interior, "mp_char_male_mirror", 0)
        end
    else
        if IsInteriorEntitySetValid(interior, "mp_char_male_mirror") == 1 and
           IsInteriorEntitySetActive(interior, "mp_char_male_mirror") then
            DeactivateInteriorEntitySet(interior, "mp_char_male_mirror", true)
        end
        if IsInteriorEntitySetValid(interior, "mp_char_female_mirror") == 1 and
           not IsInteriorEntitySetActive(interior, "mp_char_female_mirror") then
            ActivateInteriorEntitySet(interior, "mp_char_female_mirror", 0)
        end
    end
end

--- Load and set a new ped model, return true on success
--- @param modelHash number
--- @return boolean
local function LoadPedModel(modelHash)
    local oldPed = PlayerPedId()
    local oldCoords = GetEntityCoords(oldPed)
    local oldHeading = GetEntityHeading(oldPed)
    RequestModel(modelHash)
    local t = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        Wait(10)
        if GetGameTimer() - t > 6000 then
            print("[thehunt_character] ERROR: model failed to load within 6s")
            return false
        end
    end
    Appearance.ReleasePed(oldPed)
    SetPlayerModel(PlayerId(), modelHash, false)
    local newPed = PlayerPedId()
    SetEntityCoordsNoOffset(newPed, oldCoords.x, oldCoords.y, oldCoords.z, false, false, false)
    SetEntityHeading(newPed, oldHeading)
    SetEntityVisible(newPed, false)
    SetModelAsNoLongerNeeded(modelHash)
    Appearance.WaitForPedReady(newPed)
    Wait(100)
    return true
end

--- Apply base default skin meshes after model switch
--- @param gender string  "Male" | "Female"
local function ApplyDefaultMeshes(gender)
    local ped    = PlayerPedId()
    local isMale = (gender ~= "Female")
    local gL     = isMale and "M" or "F"
    local gKey   = isMale and "male" or "female"

    -- Reset exactly once for a newly switched model. No tab or clothing action
    -- is allowed to reset the MetaPed again after this point.
    Citizen.InvokeNative(0x8507BCB710FA6DC0, ped)
    Appearance.WaitForPedReady(ped)

    -- Match VORP's model repair, then materialize the MP slots. The preset must
    -- precede our selected body components; applying it last erases them.
    Appearance.PrepareCreatorPed(ped, not isMale)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, 3, true)
    Appearance.UpdatePedVariation(ped)

    -- Apply the standard build (index 1) unless the player has explicitly
    -- selected another valid build in this gender's saved draft.
    local toneIdx = characterState.skin.ToneId or 1
    local buildIdx = math.max(1, math.min(5, tonumber(characterState.skin.BuildIndex) or 1))
    characterState.skin.BuildIndex = buildIdx

    local headHash  = joaat(string.format("CLOTHING_ITEM_%s_HEAD_%03d_V_%03d", gL, characterState.skin.HeadIndex or 1, toneIdx))
    local upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gL, buildIdx, toneIdx))
    local lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gL, buildIdx, toneIdx))
    local eyesHash  = (AppearanceData.EyeColors[gKey] and AppearanceData.EyeColors[gKey][1] and AppearanceData.EyeColors[gKey][1].hash)
                      or joaat(string.format("CLOTHING_ITEM_%s_EYES_001_TINT_014", gL))
    local teethHash = joaat(string.format("CLOTHING_ITEM_%s_TEETH_000", gL))

    Appearance.ApplyShopItemRaw(ped, headHash)
    Appearance.ApplyBodyBase(ped, upperHash, lowerHash, false)
    Appearance.ApplyShopItemRaw(ped, eyesHash)
    Appearance.ApplyShopItemRaw(ped, teethHash)
    Appearance.UpdatePedVariation(ped)

    -- Update characterState skin keys
    characterState.skin.Head     = headHash
    characterState.skin.BodyType = upperHash
    characterState.skin.LegsType = lowerHash
    characterState.skin.Eyes     = eyesHash

    -- VORP creates a real eyebrow composite by default.  Keep the palette
    -- hash and the selected colour hash in their correct separate fields.
    if not characterState.skin.overlays.eyebrows then
        characterState.skin.overlays.eyebrows = {
            visibility = 1, tx_id = 1,
            tx_normal = 1, tx_material = 0, tx_color_type = 0,
            tx_opacity = 1.0, tx_unk = 0,
            palette = joaat("METAPED_TINT_MAKEUP"),
            palette_color_primary = 0x3F6E70FF,
            palette_color_secondary = 0, palette_color_tertiary = 0,
            var = 1, opacity = 1.0
        }
    end

    -- Store the matching skin tone albedo. Composite overlays are applied only
    -- after clothes/hair so their yielding renderer cannot delay model reveal.
    local tone = AppearanceData.SkinTones and AppearanceData.SkinTones[toneIdx]
    if tone then
        local albName = isMale and tone.albedoM or tone.albedoF
        local albHash = joaat(albName)
        characterState.skin.albedo = albHash
        AppearanceData.TextureTypes[gKey].albedo = albHash
    end

    Appearance.SetScale(ped, characterState.skin.Scale or 1.0)

    SetCreatorMirrors(isMale)
end

local function ApplyStarterOutfit(gender)
    local key = (gender == "Female") and "female" or "male"
    local outfit = ClothingData.DefaultOutfit and ClothingData.DefaultOutfit[key] or {}
    characterState.comps = Utils.DeepCopy(outfit)
    characterState.compTints = {}
    Clothing.ApplyAll(PlayerPedId(), characterState.comps, characterState.compTints)
end

-- The first model load must take the same complete route as pressing
-- "Standard" in the Body tab: materialise build #1, resolve it immediately,
-- then rebuild the outfit above it.  Merely setting the two body hashes before
-- the starter outfit leaves the lower mesh in an unresolved MetaPed state.
local function ApplyInitialStandardBuild(gender)
    local ped = PlayerPedId()
    local gL = (gender == "Female") and "F" or "M"
    local toneIdx = math.max(1, math.min(6, tonumber(characterState.skin.ToneId) or 1))
    local buildIdx = 1
    local upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gL, buildIdx, toneIdx))
    local lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gL, buildIdx, toneIdx))

    characterState.skin.BuildIndex = buildIdx
    characterState.skin.BodyType = upperHash
    characterState.skin.LegsType = lowerHash
    Appearance.ApplyBodyBase(ped, upperHash, lowerHash, true)
    Clothing.ApplyAll(ped, characterState.comps, characterState.compTints)

    -- Keep the same delayed refit used by the Body-tab button.  MetaPed can
    -- finalise a body variation one frame later, so this last pass closes the
    -- gap between trousers and boots on a freshly spawned model.
    local stateRef = characterState
    SetTimeout(120, function()
        if isCreating and characterState == stateRef then
            Clothing.ApplyAll(PlayerPedId(), characterState.comps, characterState.compTints)
        end
    end)
end

-- A new mp_male/mp_female model continues finalising its MetaPed components
-- for several frames. Applying the body only before that point is lost. This
-- repeats the exact Body-tab operation after the model has settled.
local function EnforceStandardBuildAfterGenderSwitch(gender, ped, revision)
    local stateRef = characterState
    local gL = (gender == "Female") and "F" or "M"

    CreateThread(function()
        local delays = { 0, 140, 420 }
        local elapsed = 0
        for _, targetDelay in ipairs(delays) do
            Wait(math.max(0, targetDelay - elapsed))
            elapsed = targetDelay

            if not isCreating or revision ~= genderSwitchRevision or characterState ~= stateRef
                or currentGender ~= gender or PlayerPedId() ~= ped or not DoesEntityExist(ped) then
                return
            end

            -- A manual selection made after the switch wins immediately and
            -- cancels the remaining Standard retries.
            if tonumber(characterState.skin.BuildIndex) ~= 1 then return end

            local toneIdx = math.max(1, math.min(6, tonumber(characterState.skin.ToneId) or 1))
            local upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_001_V_%03d", gL, toneIdx))
            local lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_001_V_%03d", gL, toneIdx))
            characterState.skin.BuildIndex = 1
            characterState.skin.BodyType = upperHash
            characterState.skin.LegsType = lowerHash

            Appearance.ApplyBodyBase(ped, upperHash, lowerHash, true)
            Clothing.ApplyAll(ped, characterState.comps, characterState.compTints)
        end
    end)
end

local function EnsureBareLowerBody()
    local ped = PlayerPedId()
    local skin = characterState.skin or {}
    local isFemale = (currentGender == "Female")
    local gL = isFemale and "F" or "M"
    local buildIdx = math.max(1, math.min(5, tonumber(skin.BuildIndex) or 1))
    local toneIdx = math.max(1, math.min(6, tonumber(skin.ToneId) or 1))

    local lowerHash = skin.LegsType
    if not lowerHash or lowerHash == 0 or lowerHash == -1 then
        lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gL, buildIdx, toneIdx))
        characterState.skin.LegsType = lowerHash
    end

    Appearance.SetBodyBaseCache(ped, skin.BodyType, lowerHash)
    Appearance.RestoreLowerBody(ped, false)

    -- If boots are equipped, keep them rendered over bare legs
    local bootsComp = characterState.comps and tonumber(characterState.comps.Boots)
    if bootsComp and bootsComp ~= 0 and bootsComp ~= -1 then
        Clothing.ApplyComponent(ped, bootsComp, "Boots", characterState.compTints and characterState.compTints.Boots, true)
    end

    Appearance.UpdatePedVariation(ped)
end

local function EnsureBareUpperBody()
    local ped = PlayerPedId()
    local skin = characterState.skin or {}
    local isFemale = (currentGender == "Female")
    local gL = isFemale and "F" or "M"
    local buildIdx = math.max(1, math.min(5, tonumber(skin.BuildIndex) or 1))
    local toneIdx = math.max(1, math.min(6, tonumber(skin.ToneId) or 1))

    local upperHash = skin.BodyType
    if not upperHash or upperHash == 0 or upperHash == -1 then
        upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gL, buildIdx, toneIdx))
        characterState.skin.BodyType = upperHash
    end

    Appearance.SetBodyBaseCache(ped, upperHash, skin.LegsType)
    Appearance.RestoreUpperBody(ped, false)

    -- Reassert vest/suspenders if worn
    if characterState.comps then
        if characterState.comps.Vest and characterState.comps.Vest ~= -1 then
            Clothing.ApplyComponent(ped, characterState.comps.Vest, "Vest", characterState.compTints and characterState.compTints.Vest, true)
        end
        if characterState.comps.Suspender and characterState.comps.Suspender ~= -1 then
            Clothing.ApplyComponent(ped, characterState.comps.Suspender, "Suspender", characterState.compTints and characterState.compTints.Suspender, true)
        end
    end

    Appearance.UpdatePedVariation(ped)
end

local function ApplyCreatorOverlaysAndFeatures(gender)
    local ped = PlayerPedId()
    local gKey = gender == "Female" and "female" or "male"
    local skin = characterState.skin or {}
    Appearance.ApplyOverlays(ped, skin.overlays, gKey, skin.albedo)
    for _, categoryList in pairs(AppearanceData.FaceFeatures or {}) do
        for _, feature in ipairs(categoryList) do
            local value = skin.features and skin.features[feature.id]
            if value ~= nil then
                Appearance.SetFaceExpression(ped, feature.hash, tonumber(value))
            end
        end
    end
end

local function ApplyDefaultHair(gender)
    local hairList = (gender == "Female") and HairsData.FemaleHairs or HairsData.MaleHairs
    for _, hair in ipairs(hairList or {}) do
        if hair.hash and hair.hash ~= 0 and hair.hash ~= -1 then
            local selectedHash = (hair.tints and hair.tints[1]) or hair.hash
            characterState.skin.Hair = selectedHash
            characterState.comps.Hair = selectedHash
            Appearance.ApplyShopItem(PlayerPedId(), selectedHash)
            Appearance.UpdatePedVariation(PlayerPedId())
            return
        end
    end
end

local bodyMorphFeatures = {
    ArmsS = true, ShouldersS = true, ShouldersT = true, ShouldersM = true,
    ChestS = true, WaistW = true, HipsS = true, LegsS = true, CalvesS = true,
}
local clothingRefitRevision = 0
local function ScheduleClothingRefit()
    clothingRefitRevision = clothingRefitRevision + 1
    local revision = clothingRefitRevision
    SetTimeout(120, function()
        if not isCreating or revision ~= clothingRefitRevision then return end
        -- MetaPed must receive body meshes first and the complete wardrobe
        -- last.  Re-applying BODIES_UPPER here after clothing used to rebuild
        -- the lower layers and produced the skin seams in trousers/boots.
        Clothing.ApplyAll(PlayerPedId(), characterState.comps, characterState.compTints)
    end)
end

local function KeepCreatorDaylight()
    CreateThread(function()
        while isCreating do
            pcall(function()
                NetworkClockTimeOverride(12, 0, 0, 0, true)
                Citizen.InvokeNative(0x59174F1AF63842E8, GetHashKey("sunny"), true, true, true, true, false)
            end)
            -- Main studio key light behind camera, to the right of the character
            DrawLightWithRange(-560.2, -3782.3, 238.85, 255, 250, 240, 8.0, 3.8)
            -- Soft fill light from the left
            DrawLightWithRange(-560.2, -3779.8, 238.85, 235, 245, 255, 6.5, 2.0)
            Wait(0)
        end
    end)
end

-- =================================================================
-- Public API
-- =================================================================

--- Open the Character Creator
--- @param data table
function Creator.Start(data)
    isCreating = true
    currentGender = "Male"
    genderStates = { Male = nil, Female = nil }

    -- Reset state for new character
    characterState = {
        firstname = "", lastname = "", gender = "Male", age = 25, nation = "Американец",
        skin = {
            Head = 0, HeadIndex = 8, ToneId = 1, Eyes = 0,
            BodyType = 0, LegsType = 0, BuildIndex = 1,
            Waist = 0, Scale = 1.0, albedo = 0,
            features = {}, overlays = {}
        },
        comps = {}, compTints = {}
    }

    -- 1. Fade out
    DoScreenFadeOut(400)
    Wait(400)

    -- 2. Suppress HUD
    pcall(function() TriggerEvent("thehunt_status:setVisible", false) end)

    -- 3. Load creator room IPLs and WAIT for them
    local IPLS = { 183712523, -1699673416, 1679934574 }
    for _, ipl in ipairs(IPLS) do
        if not IsIplActiveByHash(ipl) then RequestIplByHash(ipl) end
    end
    for _, ipl in ipairs(IPLS) do WaitForIpl(ipl) end

    -- 4. The character studio must be silent.  Explicitly keep its ambient
    -- zone disabled instead of activating Rockstar's creator music/ambience.
    Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area", false, true)
    SetTimecycleModifier("Online_Character_Editor")
    pcall(function() NetworkClockTimeOverride(12, 0, 0, 0, true) end)
    KeepCreatorDaylight()

    -- 5. Stream focus to creator room
    local spawnPos = vector4(-558.506, -3781.050, 237.60, 90.0)
    Citizen.InvokeNative(0x513F8AA5BF2F17CF, spawnPos.x, spawnPos.y, spawnPos.z, 50.0, 20)
    SetFocusPosAndVel(spawnPos.x, spawnPos.y, spawnPos.z, 0.0, 0.0, 0.0)

    -- 6. Teleport player, wait for collision
    StartPlayerTeleport(PlayerId(), spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, true, true, true)
    local t = GetGameTimer()
    while IsPlayerTeleportActive() and (GetGameTimer() - t < 4000) do Wait(10) end

    RequestCollisionAtCoord(spawnPos.x, spawnPos.y, spawnPos.z)
    t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - t < 3000) do Wait(10) end

    -- 7. Load default male ped model
    local modelHash = AppearanceData.Models.male
    if not LoadPedModel(modelHash) then
        -- Fallback: try string form
        LoadPedModel(`mp_male`)
    end

    -- 8. Position ped at spawn
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
    SetEntityHeading(ped, spawnPos.w)
    SetEntityAlpha(ped, 255, false)
    FreezeEntityPosition(ped, false)

    -- 9. Apply default meshes
    ApplyDefaultMeshes("Male")
    ApplyStarterOutfit("Male")
    ApplyInitialStandardBuild("Male")
    ApplyDefaultHair("Male")
    SetEntityVisible(ped, true)
    ApplyCreatorOverlaysAndFeatures("Male")

    -- 10. Create scripted camera
    Camera.Create(ped, "full")
    Camera.SetPedHeading(spawnPos.w)

    -- 11. Open NUI with full config
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCreator",
        isFirst = (data and (data.isFirst == true or data.isFirstCharacter == true or data.hasCharacters == false)) or false,
        hasCharacters = (data and data.hasCharacters ~= nil) and data.hasCharacters or (not (data and data.isFirstCharacter)),
        config = {
            minAge            = Config.MinAge,
            maxAge            = Config.MaxAge,
            worldYear         = Config.WorldYear,
            spawnLocations    = Config.FirstSpawnLocations,
            appearance        = AppearanceData,
            overlays          = OverlaysData,
            hairs             = HairsData,
            clothing          = ClothingData
        }
    })

    Wait(300)
    DoScreenFadeIn(600)
end

--- Switch gender — saves and restores per-gender state
--- @param gender string  "Male" | "Female"
function Creator.SetGender(gender)
    if gender == currentGender then return end
    if gender ~= "Male" and gender ~= "Female" then return end

    genderSwitchRevision = genderSwitchRevision + 1
    local switchRevision = genderSwitchRevision

    -- Keep each sex as an independent draft.  The NUI already restores its
    -- form values; preserving the Lua state as well keeps what is displayed,
    -- applied and finally persisted in sync.
    genderStates[currentGender] = Utils.DeepCopy(characterState)
    currentGender = gender
    local restoredState = genderStates[gender]
    characterState = restoredState or {
        firstname = "", lastname = "", gender = gender, age = 25, nation = "Американец",
        skin = {
            Head = 0, HeadIndex = (gender == "Female") and 1 or 8, ToneId = 1, Eyes = 0,
            BodyType = 0, LegsType = 0, BuildIndex = 1,
            Waist = 0, Scale = 1.0, albedo = 0,
            features = {}, overlays = {}
        },
        comps = {}, compTints = {}
    }
    characterState.gender = gender

    local preservedHeading = GetEntityHeading(PlayerPedId())
    local modelHash = (gender == "Female") and AppearanceData.Models.female or AppearanceData.Models.male
    if not LoadPedModel(modelHash) then return end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local spawnPos = worldEditor and vector4(pos.x, pos.y, pos.z, preservedHeading)
        or vector4(-558.506, -3781.050, 237.60, preservedHeading)
    SetEntityCoords(ped, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false, false)
    SetEntityHeading(ped, spawnPos.w)
    SetEntityAlpha(ped, 255, false)
    FreezeEntityPosition(ped, false)

    ApplyDefaultMeshes(gender)
    if restoredState then
        Clothing.ApplyAll(ped, characterState.comps, characterState.compTints)
    else
        ApplyStarterOutfit(gender)
        ApplyInitialStandardBuild(gender)
        ApplyDefaultHair(gender)
    end
    SetEntityVisible(ped, true)
    ApplyCreatorOverlaysAndFeatures(gender)
    EnforceStandardBuildAfterGenderSwitch(gender, ped, switchRevision)
    -- Camera.Create is intentionally not called here: the existing camera
    -- follows PlayerPedId and therefore remains perfectly still on model swap.
    Camera.SetPedHeading(preservedHeading)
end

--- Close Creator cleanly
function Creator.Close()
    -- RECEIVE_CHARACTERS is also used to refresh the already-open selection
    -- screen after a deletion. Do not steal its cursor/focus or destroy its
    -- scene camera when the creator was never active.
    if not isCreating then return end
    isCreating = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeCreator" })
    Camera.Destroy()
    if worldEditor then
        worldEditor = false
        return
    end
    ClearFocus()
    ClearTimecycleModifier()
    Citizen.InvokeNative(0x9748FA4DE50CCE3E, "AZL_RDRO_Character_Creation_Area", false, true)
    pcall(function() NetworkClearClockTimeOverride() end)
end

-- =================================================================
-- NUI Callbacks
-- =================================================================

RegisterNUICallback("creator:setGender", function(data, cb)
    if data and data.gender then
        Creator.SetGender(data.gender)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setScale", function(data, cb)
    local s = tonumber(data.scale)
    if s then
        -- Clamp: scale of 1.0 makes ped invisible bug — keep min 0.93
        -- 1.75m is the reference scale; this allows a real maximum of 2.20m.
        s = math.max(0.828571, math.min(1.257143, s))
        characterState.skin.Scale = s
        Appearance.SetScale(PlayerPedId(), s)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setBodyBuild", function(data, cb)
    local idx = math.floor(math.max(1, math.min(5, tonumber(data.buildIndex) or 1)))
    local gL  = (currentGender == "Female") and "F" or "M"
    local toneIdx = characterState.skin.ToneId or 1

    local upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gL, idx, toneIdx))
    local lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gL, idx, toneIdx))

    characterState.skin.BuildIndex = idx
    characterState.skin.BodyType   = upperHash
    characterState.skin.LegsType   = lowerHash

    local ped = PlayerPedId()
    Appearance.ApplyBodyBase(ped, upperHash, lowerHash, true)
    ScheduleClothingRefit()
    cb("ok")
end)

RegisterNUICallback("creator:setWaist", function(data, cb)
    local idx = math.floor(math.max(1, math.min(#(AppearanceData.Waist or {}), tonumber(data.waistIndex) or 1)))
    local waistHash = AppearanceData.Waist and AppearanceData.Waist[idx]
    if waistHash then
        characterState.skin.WaistIndex = idx
        characterState.skin.Waist = waistHash
        Citizen.InvokeNative(0x1902C4CFCC5BE57C, PlayerPedId(), tonumber(waistHash))
        Appearance.UpdatePedVariation(PlayerPedId())
        ScheduleClothingRefit()
    end
    cb("ok")
end)

RegisterNUICallback("creator:setSkinTone", function(data, cb)
    local toneIdx = math.floor(math.max(1, math.min(#(AppearanceData.SkinTones or {}), tonumber(data.toneId) or 1)))
    local gL      = (currentGender == "Female") and "F" or "M"
    local gKey    = (currentGender == "Female") and "female" or "male"
    local buildIdx = characterState.skin.BuildIndex or 1
    local headIdx  = characterState.skin.HeadIndex or 1

    local headHash  = joaat(string.format("CLOTHING_ITEM_%s_HEAD_%03d_V_%03d", gL, headIdx, toneIdx))
    local upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gL, buildIdx, toneIdx))
    local lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gL, buildIdx, toneIdx))

    characterState.skin.ToneId   = toneIdx
    characterState.skin.Head     = headHash
    characterState.skin.BodyType = upperHash
    characterState.skin.LegsType = lowerHash

    local ped = PlayerPedId()
    Appearance.ApplyShopItemRaw(ped, headHash)
    Appearance.ApplyBodyBase(ped, upperHash, lowerHash, false)

    -- Update albedo composite
    local tone = AppearanceData.SkinTones and AppearanceData.SkinTones[toneIdx]
    if tone then
        local albName = (currentGender == "Female") and tone.albedoF or tone.albedoM
        local albHash = joaat(albName)
        characterState.skin.albedo = albHash
        AppearanceData.TextureTypes[gKey].albedo = albHash
        Appearance.ApplyOverlays(ped, characterState.skin.overlays, gKey, albHash)
    end

    Appearance.UpdatePedVariation(ped)
    ScheduleClothingRefit()
    cb("ok")
end)

-- Accept the sparse native head component index, not a JS-serialized hash.
RegisterNUICallback("creator:setHead", function(data, cb)
    local headIdx = tonumber(data.headIndex) or 1
    local gL      = (currentGender == "Female") and "F" or "M"
    local toneIdx = characterState.skin.ToneId or 1

    -- Reject nonexistent gaps in the MetaPed head component range.
    local valid = false
    local genderKey = (currentGender == "Female") and "female" or "male"
    for _, head in ipairs(AppearanceData.Heads[genderKey] or {}) do
        if tonumber(head.id) == headIdx then valid = true break end
    end
    if not valid then cb("ok") return end

    local headHash = joaat(string.format("CLOTHING_ITEM_%s_HEAD_%03d_V_%03d", gL, headIdx, toneIdx))

    characterState.skin.HeadIndex = headIdx
    characterState.skin.Head      = headHash

    Appearance.ApplyShopItem(PlayerPedId(), headHash)
    Appearance.UpdatePedVariation(PlayerPedId())
    cb("ok")
end)

RegisterNUICallback("creator:setEyes", function(data, cb)
    local eyeHash = tonumber(data.eyeHash)
    local genderKey = currentGender == "Female" and "female" or "male"
    local valid = false
    for _, eye in ipairs((AppearanceData.EyeColors and AppearanceData.EyeColors[genderKey]) or {}) do
        if Utils.HashKey(eye.hash) == Utils.HashKey(eyeHash) then valid = true break end
    end
    if eyeHash and valid then
        characterState.skin.Eyes = eyeHash
        local ped = PlayerPedId()
        Appearance.ApplyShopItemRaw(ped, eyeHash)
        Appearance.UpdatePedVariation(ped)
    end
    cb("ok")
end)

RegisterNUICallback("creator:previewTeeth", function(data, cb)
    local active = (data and data.active == true)
    local ped = PlayerPedId()
    teethPreviewRevision = teethPreviewRevision + 1
    if active then
        Citizen.InvokeNative(0x5653AB26C82938CF, ped, 0x9321, 1.0)
        Citizen.InvokeNative(0x5653AB26C82938CF, ped, 0x8D0A, 1.0)
    else
        Citizen.InvokeNative(0x5653AB26C82938CF, ped, 0x9321, 0.0)
        local feats = (characterState.skin and characterState.skin.features) or {}
        Citizen.InvokeNative(0x5653AB26C82938CF, ped, 0x8D0A, tonumber(feats.JawH) or 0.0)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setTeeth", function(data, cb)
    local tHash = tonumber(data.teethHash)
    if tHash and tHash ~= -1 then
        characterState.comps.Teeth = tHash
        characterState.skin.Teeth = tHash
        local ped = PlayerPedId()
        Clothing.ApplyComponent(ped, tHash, "Teeth")
        teethPreviewRevision = teethPreviewRevision + 1
        Citizen.InvokeNative(0x5653AB26C82938CF, ped, 0x9321, 1.0)
        Citizen.InvokeNative(0x5653AB26C82938CF, ped, 0x8D0A, 1.0)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setOverlay", function(data, cb)
    if data.name and data.overlay and OverlaysData.Info[data.name] then
        characterState.skin.overlays[data.name] = data.overlay
        local gKey = (currentGender == "Female") and "female" or "male"
        Appearance.ApplyOverlays(PlayerPedId(), characterState.skin.overlays, gKey, characterState.skin.albedo)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setFeature", function(data, cb)
    local featId = data.featureId
    local val    = tonumber(data.value)
    if not featId or val == nil then cb("ok") return end

    val = math.max(-1.0, math.min(1.0, val))
    characterState.skin.features[featId] = val

    -- Find the feature hash from AppearanceData
    local featureHash = nil
    for _, categoryList in pairs(AppearanceData.FaceFeatures) do
        for _, feat in ipairs(categoryList) do
            if feat.id == featId then
                featureHash = feat.hash
                break
            end
        end
        if featureHash then break end
    end

    if featureHash then
        Appearance.SetFaceExpression(PlayerPedId(), featureHash, val)
        if bodyMorphFeatures[featId] then ScheduleClothingRefit() end
    end
    cb("ok")
end)

RegisterNUICallback("creator:setHair", function(data, cb)
    local compHash = tonumber(data.hash)
    if compHash and compHash ~= -1 then
        characterState.comps.Hair = compHash
        characterState.skin.Hair = compHash
        Clothing.ApplyComponent(PlayerPedId(), compHash, "Hair")
    elseif compHash == -1 then
        -- Bald: remove hair tag
        characterState.comps.Hair = -1
        characterState.skin.Hair = -1
        Clothing.RemoveTag(PlayerPedId(), ClothingData.Categories.Hair)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setBeard", function(data, cb)
    local compHash = tonumber(data.hash)
    if compHash and compHash ~= -1 then
        characterState.comps.Beard = compHash
        characterState.skin.Beard = compHash
        Clothing.ApplyComponent(PlayerPedId(), compHash, "Beard")
    elseif compHash == -1 then
        characterState.comps.Beard = -1
        characterState.skin.Beard = -1
        Clothing.RemoveTag(PlayerPedId(), ClothingData.Categories.Beard)
    end
    cb("ok")
end)

RegisterNUICallback("creator:setClothing", function(data, cb)
    local cat      = data.category
    local compHash = tonumber(data.hash)
    if cat and ClothingData.Categories[cat] and compHash then
        characterState.comps[cat] = compHash
        local ped = PlayerPedId()

        -- Sync body base cache with current creator build & tone
        local isFemale = (currentGender == "Female")
        local gL = isFemale and "F" or "M"
        local buildIdx = math.max(1, math.min(5, tonumber(characterState.skin.BuildIndex) or 1))
        local toneIdx = math.max(1, math.min(6, tonumber(characterState.skin.ToneId) or 1))
        local upperHash = characterState.skin.BodyType
        if not upperHash or upperHash == 0 or upperHash == -1 then
            upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gL, buildIdx, toneIdx))
            characterState.skin.BodyType = upperHash
        end
        local lowerHash = characterState.skin.LegsType
        if not lowerHash or lowerHash == 0 or lowerHash == -1 then
            lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gL, buildIdx, toneIdx))
            characterState.skin.LegsType = lowerHash
        end
        Appearance.SetBodyBaseCache(ped, upperHash, lowerHash)

        -- PANTS and SKIRTS are mutually exclusive
        if cat == "Pant" and compHash ~= -1 then
            characterState.comps.Skirt = -1
            Clothing.RemoveTagRaw(ped, ClothingData.Categories.Skirt)
            Appearance.ApplyShopItemRaw(ped, lowerHash)
        elseif cat == "Skirt" and compHash ~= -1 then
            characterState.comps.Pant = -1
            Clothing.RemoveTagRaw(ped, ClothingData.Categories.Pant)
            Appearance.ApplyShopItemRaw(ped, lowerHash)
        end

        local isLowerGarment = cat == "Pant" or cat == "Skirt"
        Clothing.ApplyComponent(ped, compHash, cat, nil, isLowerGarment)

        -- If neither lower garment remains, guarantee bare legs are visible
        if isLowerGarment and compHash ~= -1 then
            -- A lower garment makes the saved boots compatible again.
            local bootsComp = characterState.comps and tonumber(characterState.comps.Boots)
            if bootsComp and bootsComp ~= 0 and bootsComp ~= -1 then
                Clothing.ApplyComponent(ped, bootsComp, "Boots", characterState.compTints and characterState.compTints.Boots, true)
            end
            Appearance.UpdatePedVariation(ped)
        elseif isLowerGarment and compHash == -1 then
            local other = (cat == "Pant") and characterState.comps.Skirt or characterState.comps.Pant
            if not other or tonumber(other) == -1 then
                EnsureBareLowerBody()
            else
                Appearance.UpdatePedVariation(ped)
            end
        elseif cat == "Shirt" and compHash == -1 then
            EnsureBareUpperBody()
        elseif cat == "Boots" then
            local pantHash = tonumber(characterState.comps.Pant) or -1
            local skirtHash = tonumber(characterState.comps.Skirt) or -1
            if pantHash == -1 and skirtHash == -1 then
                EnsureBareLowerBody()
            end
        end
        -- Finish every direct clothing selection through the same complete,
        -- ordered assembly path as body/skin changes.  This prevents a stale
        -- base layer or previous item from surviving beneath the new garment.
        ScheduleClothingRefit()
    end
    cb("ok")
end)

RegisterNUICallback("creator:setBodyPreview", function(data, cb)
    -- Kept as a harmless compatibility endpoint for a cached NUI.  The Body
    -- tab no longer changes clothes: players take garments off themselves.
    cb("ok")
end)

RegisterNUICallback("creator:setCameraPreset", function(data, cb)
    if data.preset then
        CreateThread(function()
            Camera.SetPreset(data.preset, 500)
        end)
    end
    cb("ok")
end)

RegisterNUICallback("creator:rotatePed", function(data, cb)
    Camera.RotatePed(tonumber(data.delta) or 15.0)
    cb("ok")
end)

RegisterNUICallback("creator:moveCameraZ", function(data, cb)
    Camera.MoveZ(tonumber(data.delta) or 0.0)
    cb("ok")
end)

RegisterNUICallback("creator:orbitCamera", function(data, cb)
    Camera.Orbit(tonumber(data.delta) or 0.0)
    cb("ok")
end)

RegisterNUICallback("creator:zoomCamera", function(data, cb)
    Camera.Zoom(tonumber(data.delta) or 0.0)
    cb("ok")
end)

-- Build an authoritative snapshot at submit time. Individual preview NUI
-- callbacks are asynchronous, so their arrival order must not affect storage.
local function ClampSubmissionNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

local function IsKnownSubmissionHead(genderKey, index)
    for _, head in ipairs((AppearanceData.Heads and AppearanceData.Heads[genderKey]) or {}) do
        if tonumber(head.id) == index then return true end
    end
    return false
end

local function BuildSubmissionSnapshot(data)
    local gender = data.gender == "Female" and "Female" or "Male"
    local female = gender == "Female"
    local genderKey = female and "female" or "male"
    local genderLetter = female and "F" or "M"
    local uiSkin = type(data.skin) == "table" and data.skin or {}
    local fallbackHead = female and 1 or 8
    local headIndex = tonumber(uiSkin.headIndex) or fallbackHead
    if not IsKnownSubmissionHead(genderKey, headIndex) then headIndex = fallbackHead end
    local toneId = ClampSubmissionNumber(uiSkin.toneId, 1, #(AppearanceData.SkinTones or {}), 1)
    local buildIndex = ClampSubmissionNumber(uiSkin.buildIndex, 1, #((AppearanceData.BodyBuilds and AppearanceData.BodyBuilds[genderKey]) or {}), 1)
    local waistIndex = ClampSubmissionNumber(uiSkin.waistIndex, 1, #(AppearanceData.Waist or {}), 1)
    local scaleCfg = AppearanceData.Scale or {}
    local scale = ClampSubmissionNumber(uiSkin.scale, scaleCfg.min or 0.828571, scaleCfg.max or 1.257143, scaleCfg.default or 1.0)
    local firstEye = AppearanceData.EyeColors[genderKey] and AppearanceData.EyeColors[genderKey][1]
    local skinTone = AppearanceData.SkinTones[toneId]

    characterState.gender = gender
    characterState.skin = {
        Head = joaat(string.format("CLOTHING_ITEM_%s_HEAD_%03d_V_%03d", genderLetter, headIndex, toneId)),
        HeadIndex = headIndex, ToneId = toneId,
        Eyes = tonumber(uiSkin.eyes) or (firstEye and firstEye.hash) or 0,
        BodyType = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", genderLetter, buildIndex, toneId)),
        LegsType = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", genderLetter, buildIndex, toneId)),
        BuildIndex = buildIndex, Waist = (AppearanceData.Waist or {})[waistIndex] or 0, WaistIndex = waistIndex,
        Scale = scale,
        sex = female and "mp_female" or "mp_male",
        model = female and "mp_female" or "mp_male",
        AppearanceDataVersion = 2,
        albedo = skinTone and joaat(female and skinTone.albedoF or skinTone.albedoM) or 0,
        features = Utils.DeepCopy(type(uiSkin.features) == "table" and uiSkin.features or {}),
        overlays = Utils.DeepCopy(type(uiSkin.overlays) == "table" and uiSkin.overlays or {})
    }
    characterState.comps = Utils.DeepCopy(type(data.comps) == "table" and data.comps or {})
    characterState.compTints = Utils.DeepCopy(type(data.compTints) == "table" and data.compTints or {})
    local function StoredComp(category)
        local value = characterState.comps[category]
        if type(value) == "table" then value = value.comp or value.hash end
        return tonumber(value) or -1
    end
    characterState.skin.Hair = StoredComp("Hair")
    characterState.skin.Beard = StoredComp("Beard")
    characterState.skin.Teeth = StoredComp("Teeth")
    characterState.skin = Utils.NormalizeSkin(characterState.skin, gender)
end

RegisterNUICallback("creator:submitCharacter", function(data, cb)
    if worldEditor then
        BuildSubmissionSnapshot(data)
        local result = Utils.DeepCopy(characterState)
        Creator.Close()
        TriggerEvent('thehunt_pedcustom:editorResult', result)
        cb('ok')
        return
    end
    characterState.firstname = data.firstname or ""
    characterState.lastname  = data.lastname  or ""
    characterState.gender    = data.gender    or currentGender
    characterState.age       = tonumber(data.age) or 25
    characterState.birthdate = data.birthdate
    characterState.nation    = data.nation    or "Американец"

    BuildSubmissionSnapshot(data)
    genderStates[characterState.gender] = Utils.DeepCopy(characterState)

    TriggerServerEvent(Constants.Events.CREATE_CHARACTER, characterState)
    cb("ok")
end)

RegisterNUICallback("creator:cancel", function(data, cb)
    if worldEditor then
        Creator.Close()
        TriggerEvent('thehunt_pedcustom:editorResult', false)
        cb('ok')
        return
    end
    Creator.Close()
    TriggerServerEvent(Constants.Events.REQUEST_CHARACTERS)
    cb("ok")
end)

-- Separate in-world entry: no character creation, teleport or database save.
exports('OpenPedCustomEditor', function(data)
    if GetInvokingResource() ~= 'thehunt_pedcustom' or isCreating then return false end
    worldEditor = true
    isCreating = true
    currentGender = data.gender == 'Female' and 'Female' or 'Male'
    genderStates = { Male = nil, Female = nil }
    characterState = Utils.DeepCopy(data)
    characterState.skin = characterState.skin or { HeadIndex = 8, ToneId = 1, BuildIndex = 1, Scale = 1.0, features = {}, overlays = {} }
    characterState.comps = characterState.comps or {}
    characterState.compTints = characterState.compTints or {}
    characterState.skin.features = characterState.skin.features or {}
    characterState.skin.overlays = characterState.skin.overlays or {}
    local ped = PlayerPedId()
    if not next(characterState.skin) or not (characterState.skin.Head or characterState.skin.HeadIndex) then
        characterState.skin.HeadIndex = currentGender == 'Female' and 1 or 8
        ApplyDefaultMeshes(currentGender)
        ApplyStarterOutfit(currentGender)
        ApplyDefaultHair(currentGender)
    else
        Appearance.ApplyAll(ped, characterState.skin, currentGender)
        Clothing.ApplyAll(ped, characterState.comps, characterState.compTints)
    end
    Camera.Create(ped, 'full')
    Camera.SetPedHeading(GetEntityHeading(ped))
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'openCreator', pedCustom = true, initialState = characterState,
        config = { minAge = Config.MinAge, maxAge = Config.MaxAge, worldYear = Config.WorldYear,
            appearance = AppearanceData, overlays = OverlaysData, hairs = HairsData, clothing = ClothingData } })
    return true
end)

exports('ClosePedCustomEditor', function()
    if GetInvokingResource() == 'thehunt_pedcustom' and worldEditor then Creator.Close() end
end)
