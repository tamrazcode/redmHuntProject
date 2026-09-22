-- =================================================================
-- HUNT: Hard RP — RDR3 Ped Appearance & Customization Engine
-- Fully Compatible with VORP / RedM Native Pipeline
-- =================================================================

Appearance = {}
local BASE_WEARABLE_STATE = joaat("base")
local textureByPed = {}
local bodyBaseByPed = {}

local function ReleaseTexture(target)
    local textureId = textureByPed[target]
    if textureId and textureId ~= -1 then
        Citizen.InvokeNative(0xB63B9178D0F58D82, textureId)
        Citizen.InvokeNative(0x6BEFAA907B076859, textureId)
    end
    textureByPed[target] = nil
end

function Appearance.ReleasePed(ped)
    local target = ped or PlayerPedId()
    ReleaseTexture(target)
    bodyBaseByPed[target] = nil
end

--- Wait until ped is ready to render customization
--- @param ped number
function Appearance.WaitForPedReady(ped)
    local target = ped or PlayerPedId()
    local timer = GetGameTimer()
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, target) do
        Wait(10)
        if GetGameTimer() - timer > 3000 then break end
    end
end

--- Update Ped Variation
--- @param ped number
function Appearance.UpdatePedVariation(ped)
    local target = ped or PlayerPedId()
    Citizen.InvokeNative(0xCC8CA3E88256E58F, target, false, true, true, true, false)
    Citizen.InvokeNative(0xAAB86462966168CE, target, true)
end

--- Queue a shop item without resolving the MetaPed between individual layers.
--- VORP applies both native passes first and updates the variation only after
--- the complete body/outfit batch has been assembled.
--- @param ped number
--- @param compHash number
--- @return boolean
function Appearance.ApplyShopItemRaw(ped, compHash)
    local target = ped or PlayerPedId()
    local h = tonumber(compHash)
    if not h or h == 0 or h == -1 then return false end
    Citizen.InvokeNative(0xD3A7B003ED343FD9, target, h, false, false, false)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, target, h, false, true, false)
    return true
end

--- Apply Shop Item component to ped using double-flag native call
--- @param ped number
--- @param compHash number
function Appearance.ApplyShopItem(ped, compHash)
    local target = ped or PlayerPedId()
    if Appearance.ApplyShopItemRaw(target, compHash) then
        Appearance.UpdatePedVariation(target)
    end
end

--- Apply a base body mesh using the same two-pass pipeline as VORP creator.
function Appearance.ApplyBodyComponent(ped, compHash)
    local target = ped or PlayerPedId()
    if Appearance.ApplyShopItemRaw(target, compHash) then
        Appearance.UpdatePedVariation(target)
    end
end

function Appearance.SetBodyBaseCache(ped, upperHash, lowerHash)
    local target = ped or PlayerPedId()
    bodyBaseByPed[target] = {
        upper = tonumber(upperHash) or 0,
        lower = tonumber(lowerHash) or 0
    }
end

function Appearance.ApplyBodyBase(ped, upperHash, lowerHash, updateNow)
    local target = ped or PlayerPedId()
    Appearance.SetBodyBaseCache(target, upperHash, lowerHash)
    Clothing.RemoveTagRaw(target, ClothingData.Categories.BodiesUpper)
    Clothing.RemoveTagRaw(target, ClothingData.Categories.BodiesLower)
    Appearance.ApplyShopItemRaw(target, upperHash)
    Appearance.ApplyShopItemRaw(target, lowerHash)
    if upperHash and upperHash ~= 0 and upperHash ~= -1 then
        Appearance.UpdateShopItemWearableState(target, upperHash, BASE_WEARABLE_STATE)
    end
    if lowerHash and lowerHash ~= 0 and lowerHash ~= -1 then
        Appearance.UpdateShopItemWearableState(target, lowerHash, BASE_WEARABLE_STATE)
    end
    if updateNow ~= false then Appearance.UpdatePedVariation(target) end
end

function Appearance.RestoreLowerBody(ped, updateNow)
    local target = ped or PlayerPedId()
    local isFemale = not IsPedMale(target)
    local gL = isFemale and "F" or "M"
    local base = bodyBaseByPed[target]
    local lowerHash = base and base.lower
    if not lowerHash or lowerHash == 0 or lowerHash == -1 then
        lowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_001_V_001", gL))
    end
    Clothing.RemoveTagRaw(target, ClothingData.Categories.BodiesLower)
    Appearance.ApplyShopItemRaw(target, lowerHash)
    -- Bare legs need the same explicit base wearable state as the upper body.
    -- Without this state RedM can keep BODIES_LOWER hidden after trousers are
    -- removed, leaving boots detached below an invisible lower mesh.
    Appearance.UpdateShopItemWearableState(target, lowerHash, BASE_WEARABLE_STATE)
    if updateNow ~= false then Appearance.UpdatePedVariation(target) end
    return true
end

function Appearance.RestoreUpperBody(ped, updateNow)
    local target = ped or PlayerPedId()
    local isFemale = not IsPedMale(target)
    local gL = isFemale and "F" or "M"
    local base = bodyBaseByPed[target]
    local upperHash = base and base.upper
    if not upperHash or upperHash == 0 or upperHash == -1 then
        upperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_001_V_001", gL))
    end
    Clothing.RemoveTagRaw(target, ClothingData.Categories.BodiesUpper)
    Appearance.ApplyShopItemRaw(target, upperHash)
    Appearance.UpdateShopItemWearableState(target, upperHash, BASE_WEARABLE_STATE)
    if updateNow ~= false then Appearance.UpdatePedVariation(target) end
    return true
end

--- Force a shop component into a compatible wearable state.
--- This is the skin/body workaround used by VORP's own creator.
function Appearance.UpdateShopItemWearableState(ped, compHash, wearableHash)
    local target = ped or PlayerPedId()
    Citizen.InvokeNative(0x66B957AAC2EAAEAB, target, compHash, wearableHash, 0, 1, 1)
end

-- Female BODIES_UPPER has a compatible "chemise" state for covered torsos.
-- For male peds, BODIES_UPPER remains in "base" state so hands and wrists
-- are always visible through shirt cuffs.
function Appearance.ApplyBodyCoverageState(ped, upperCovered)
    local target = ped or PlayerPedId()
    local base = bodyBaseByPed[target]
    local upperHash = base and tonumber(base.upper)
    if not upperCovered then
        if upperHash and upperHash ~= 0 and upperHash ~= -1 then
            Appearance.UpdateShopItemWearableState(target, upperHash, BASE_WEARABLE_STATE)
        end
        return
    end
    if IsPedMale(target) then
        if upperHash and upperHash ~= 0 and upperHash ~= -1 then
            Appearance.UpdateShopItemWearableState(target, upperHash, BASE_WEARABLE_STATE)
        end
    else
        if upperHash and upperHash ~= 0 and upperHash ~= -1 then
            Appearance.UpdateShopItemWearableState(target, upperHash, joaat("chemise"))
        end
    end
end

--- Prepare the MP MetaPed base before applying body meshes and clothing.
--- Female peds need preset 7 first; male peds need two wearable-state repairs.
function Appearance.PrepareCreatorPed(ped, isFemale)
    local target = ped or PlayerPedId()
    Appearance.WaitForPedReady(target)

    if isFemale then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, target, 7, true)
        Appearance.UpdatePedVariation(target)
    else
        Appearance.UpdateShopItemWearableState(target, -457866027, -425834297)
        Appearance.ApplyShopItemRaw(target, -218859683)
        local temporaryGunbelt = joaat("CLOTHING_ITEM_M_GUNBELT_000_TINT_001")
        Appearance.ApplyShopItemRaw(target, temporaryGunbelt)
        Appearance.UpdateShopItemWearableState(target, -218859683, -2081918609)
        Appearance.UpdatePedVariation(target)
    end
end

--- Apply Face Expression Feature Slider Morph (-1.0 to 1.0)
--- @param ped number
--- @param featureHash number
--- @param value number
function Appearance.SetFaceExpression(ped, featureHash, value)
    local target = ped or PlayerPedId()
    local numVal = tonumber(value) or 0.0
    numVal = math.max(-1.0, math.min(1.0, numVal))
    Appearance.WaitForPedReady(target)
    -- Native order is ped, expression hash, value (same pipeline as VORP).
    Citizen.InvokeNative(0x5653AB26C82938CF, target, tonumber(featureHash), numVal)
    Appearance.UpdatePedVariation(target)
end

--- Apply Scale / Height to ped
--- @param ped number
--- @param scale number
function Appearance.SetScale(ped, scale)
    local target = ped or PlayerPedId()
    local s = tonumber(scale) or 1.0
    s = s + 0.0
    if s < 0.828571 then s = 0.828571 end
    -- 1.25714 × the 1.75m reference model = 2.20m.  Keep this in sync
    -- with creator.lua so the actual MetaPed is not shorter than the UI says.
    if s > 1.257143 then s = 1.257143 end
    SetPedScale(target, s)
    PlaceObjectOnGroundProperly(target)
end

--- Set Head Model / Heritage preset
--- @param ped number
--- @param headHash number
function Appearance.SetHead(ped, headHash)
    Appearance.ApplyShopItem(ped, headHash)
end

--- Set Eye Color
--- @param ped number
--- @param eyeHash number
function Appearance.SetEyeColor(ped, eyeHash)
    Appearance.ApplyShopItem(ped, eyeHash)
end

--- Apply Body Build Type (Upper & Lower)
--- @param ped number
--- @param upperHash number
--- @param lowerHash number
function Appearance.SetBodyBuild(ped, upperHash, lowerHash)
    local target = ped or PlayerPedId()
    if upperHash then Appearance.ApplyShopItem(target, upperHash) end
    if lowerHash then Appearance.ApplyShopItem(target, lowerHash) end
end

--- Apply Overlays Compositing
--- @param ped number
--- @param overlays table
--- @param gender string
--- @param albedoHash number
function Appearance.ApplyOverlays(ped, overlays, gender, albedoHash)
    local target = ped or PlayerPedId()
    local gen = gender or (IsPedMale(target) and "male" or "female")
    local textureSettings = AppearanceData.TextureTypes[gen] or AppearanceData.TextureTypes.male
    local chosenAlbedo = (albedoHash and albedoHash ~= 0) and albedoHash or textureSettings.albedo

    ReleaseTexture(target)

    -- Create new texture composite
    local currentTextureId = Citizen.InvokeNative(0xC5E7204F322E49EB, chosenAlbedo, textureSettings.normal, textureSettings.material)
    if not currentTextureId or currentTextureId == -1 then return end
    textureByPed[target] = currentTextureId

    if overlays and type(overlays) == "table" then
        local overlayOrder, included = {}, {}
        for _, layer in ipairs(OverlaysData.Layers or {}) do
            overlayOrder[#overlayOrder + 1] = layer.name
            included[layer.name] = true
        end
        for _, layerName in ipairs({ "eyebrows", "beardstabble", "hair", "foundation" }) do
            if not included[layerName] then overlayOrder[#overlayOrder + 1] = layerName end
            included[layerName] = true
        end
        for layerName in pairs(overlays) do
            if not included[layerName] then overlayOrder[#overlayOrder + 1] = layerName end
        end

        for _, layerName in ipairs(overlayOrder) do
            local layerData = overlays[layerName]
            if layerData and layerData.visibility and layerData.visibility ~= 0 and layerData.tx_id and layerData.tx_id ~= 0 then
                local overlayInfoList = OverlaysData.Info[layerName]
                local info = overlayInfoList and overlayInfoList[layerData.tx_id]
                
                -- Determine if layer uses color palette tints or untinted decal
                local isTinted = (layerName == "eyebrows" or layerName == "beardstabble" or layerName == "hair" 
                    or layerName == "lipsticks" or layerName == "blush" or layerName == "shadows" 
                    or layerName == "eyeliners" or layerName == "paintedmasks" or layerName == "grime"
                    or layerName == "foundation")
                
                local tx_id = 0
                local varIndex = 0
                if layerName == "shadows" or layerName == "eyeliners" or layerName == "lipsticks" then
                    tx_id = (overlayInfoList and overlayInfoList[1] and overlayInfoList[1].id) or (info and info.id) or layerData.tx_id
                    varIndex = (info and info.var) or (layerData.tx_id - 1)
                else
                    tx_id = (info and info.id) or layerData.tx_id
                    varIndex = (info and info.var) or layerData.var or 0
                end

                local tx_normal = (info and info.normal) or tonumber(layerData.tx_normal) or 0
                local tx_material = (info and info.ma) or tonumber(layerData.tx_material) or 0
                local tx_color_type = tonumber(layerData.tx_color_type)
                if tx_color_type == nil then tx_color_type = isTinted and 0 or 1 end
                local tx_opacity = tonumber(layerData.tx_opacity) or 1.0
                local tx_unk = tonumber(layerData.tx_unk) or 0

                local opacity = tonumber(layerData.opacity) or 1.0
                if opacity > 1.0 then opacity = opacity / 100.0 end
                opacity = math.max(0.0, math.min(1.0, opacity))

                local overlay_id = Citizen.InvokeNative(0x86BB5FF45F193A02, currentTextureId, tx_id, tx_normal, tx_material, tx_color_type, tx_opacity, tx_unk)
                
                if isTinted then
                    local rendererPalette = (OverlaysData.RendererPalettes and OverlaysData.RendererPalettes[layerName]) or joaat("METAPED_TINT_MAKEUP")
                    local colorPrimary = layerData.palette_color_primary
                    if not colorPrimary or colorPrimary == 0 then
                        local swatches = (OverlaysData.LayerSwatches and OverlaysData.LayerSwatches[layerName])
                        colorPrimary = (swatches and swatches[1] and swatches[1].hash) or 0x3F6E70FF
                    end
                    local colorSecondary = layerData.palette_color_secondary
                    if not colorSecondary or colorSecondary == 0 then
                        colorSecondary = colorPrimary
                    end
                    local colorTertiary = layerData.palette_color_tertiary
                    if not colorTertiary or colorTertiary == 0 then
                        colorTertiary = colorPrimary
                    end

                    Citizen.InvokeNative(0x1ED8588524AC9BE1, currentTextureId, overlay_id, rendererPalette)
                    Citizen.InvokeNative(0x2DF59FFE6FFD6044, currentTextureId, overlay_id, colorPrimary, colorSecondary, colorTertiary)
                end

                Citizen.InvokeNative(0x3329AAE2882FC8E4, currentTextureId, overlay_id, varIndex)
                Citizen.InvokeNative(0x6C76BC24F8BB709A, currentTextureId, overlay_id, opacity)
            end
        end
    end

    local deadline = GetGameTimer() + 3000
    while not Citizen.InvokeNative(0x31DC8D3F216D8509, currentTextureId) and GetGameTimer() < deadline do
        Wait(0)
    end

    -- Same order as VORP's compositor: attach, then finalise. This prevents
    -- changed eyebrow overlays from being discarded by the renderer.
    Citizen.InvokeNative(0x0B46E25761519058, target, `heads`, currentTextureId)
    Citizen.InvokeNative(0x92DAABA2C1C10B0E, currentTextureId)
    Appearance.UpdatePedVariation(target)
end

--- Complete Character Appearance Loader (Loads on Login / Selection)
--- @param ped number
--- @param skinData table
--- @param gender string
function Appearance.ApplySkin(ped, skinData, gender)
    local target = ped or PlayerPedId()
    if not skinData or type(skinData) ~= "table" then return end

    skinData, gender = Utils.NormalizeSkin(skinData, gender)
    local gKey = gender and string.lower(gender) or (IsPedMale(target) and "male" or "female")
    local isFemale = (gKey == "female")
    local gLetter = isFemale and "F" or "M"

    Appearance.WaitForPedReady(target)

    -- 1. Initialize ped preset base & wearable states
    Appearance.PrepareCreatorPed(target, isFemale)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, target, 3, true)
    Appearance.UpdatePedVariation(target)

    -- 2. Scale / Height
    local scaleVal = (skinData and (skinData.scale or skinData.Scale)) or 1.0
    Appearance.SetScale(target, scaleVal)

    -- 3. Resolve Build and Skin Tone
    local buildIndex = tonumber(skinData and (skinData.BuildIndex or skinData.buildIndex)) or 1
    local toneId = tonumber(skinData and (skinData.ToneId or skinData.toneId)) or 1
    buildIndex = math.max(1, math.min(5, buildIndex))
    toneId = math.max(1, math.min(6, toneId))

    -- 4. Head & Heritage (Ensures head mesh is never missing)
    local headHash = (skinData and (skinData.head or skinData.HeadType or skinData.Head))
    if not headHash or headHash == 0 or headHash == -1 or (type(headHash) == "number" and headHash > -31 and headHash < 31) then
        local headIdx = tonumber(skinData and (skinData.HeadIndex or skinData.headIndex)) or 1
        headHash = joaat(string.format("CLOTHING_ITEM_%s_HEAD_%03d_V_%03d", gLetter, headIdx, toneId))
    end
    Appearance.ApplyShopItemRaw(target, headHash)

    -- 5. Upper Body (Chest / Arms / Neck / Torso)
    local bodyUpperHash = (skinData and (skinData.BodyType or skinData.bodyBuild))
    if not bodyUpperHash or bodyUpperHash == 0 or bodyUpperHash == -1 or (type(bodyUpperHash) == "number" and bodyUpperHash > -11 and bodyUpperHash < 11) then
        bodyUpperHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", gLetter, buildIndex, toneId))
    end
    -- 6. Lower Body (Legs / Waist)
    local bodyLowerHash = (skinData and (skinData.LegsType or skinData.bodyLower))
    if not bodyLowerHash or bodyLowerHash == 0 or bodyLowerHash == -1 or (type(bodyLowerHash) == "number" and bodyLowerHash > -11 and bodyLowerHash < 11) then
        bodyLowerHash = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", gLetter, buildIndex, toneId))
    end
    Appearance.ApplyBodyBase(target, bodyUpperHash, bodyLowerHash, false)

    -- Old VORP snapshots store an additional legs and torso shop item apart
    -- from the base BodyType/LegsType meshes.  They must not be used as base
    -- fallbacks: doing so loses one of the layers on migrated characters.
    local legacyLegsHash = skinData and tonumber(skinData.Legs)
    if legacyLegsHash and legacyLegsHash ~= 0 and legacyLegsHash ~= -1
        and legacyLegsHash ~= tonumber(bodyLowerHash) then
        Appearance.ApplyShopItemRaw(target, legacyLegsHash)
    end
    local legacyTorsoHash = skinData and tonumber(skinData.Torso)
    if legacyTorsoHash and legacyTorsoHash ~= 0 and legacyTorsoHash ~= -1
        and legacyTorsoHash ~= tonumber(bodyUpperHash) then
        Appearance.ApplyShopItemRaw(target, legacyTorsoHash)
    end

    -- 7. Waist shape component native
    local waistHash = skinData and (skinData.Waist or skinData.waist)
    if not waistHash or waistHash == 0 or waistHash == -1 or (type(waistHash) == "number" and waistHash > -26 and waistHash < 26) then
        local waistIdx = tonumber(skinData and (skinData.waistIndex or skinData.WaistIndex)) or 1
        waistHash = (AppearanceData.Waist or {})[waistIdx] or (AppearanceData.BodyBuilds and AppearanceData.BodyBuilds[gKey] and AppearanceData.BodyBuilds[gKey][buildIndex] and AppearanceData.BodyBuilds[gKey][buildIndex].waist) or -2045421226
    end
    Citizen.InvokeNative(0x1902C4CFCC5BE57C, target, tonumber(waistHash))

    -- Body is a MetaPed outfit hash in the stock VORP schema, not the upper
    -- body mesh.  Keep it as a separate outfit pass for old saved skins.
    local legacyBodyOutfit = skinData and tonumber(skinData.Body)
    if legacyBodyOutfit and legacyBodyOutfit ~= 0 and legacyBodyOutfit ~= -1 then
        Citizen.InvokeNative(0x1902C4CFCC5BE57C, target, legacyBodyOutfit)
    end

    -- 8. Eyes
    local eyesHash = (skinData and (skinData.eyes or skinData.Eyes))
    if not eyesHash or eyesHash == 0 or eyesHash == -1 then
        eyesHash = (AppearanceData.EyeColors[gKey] and AppearanceData.EyeColors[gKey][1] and AppearanceData.EyeColors[gKey][1].hash) or joaat(string.format("CLOTHING_ITEM_%s_EYES_001_TINT_014", gLetter))
    end
    Appearance.ApplyShopItemRaw(target, eyesHash)

    -- 9. Hair & Beard
    if skinData and skinData.Hair and skinData.Hair ~= 0 and skinData.Hair ~= -1 then
        Appearance.ApplyShopItemRaw(target, skinData.Hair)
    end
    if skinData and skinData.Beard and skinData.Beard ~= 0 and skinData.Beard ~= -1 then
        Appearance.ApplyShopItemRaw(target, skinData.Beard)
    end
    if skinData and skinData.Teeth and skinData.Teeth ~= 0 and skinData.Teeth ~= -1 then
        Appearance.ApplyShopItemRaw(target, skinData.Teeth)
    end

    -- Resolve the complete base once. Per-component updates in the middle of
    -- this sequence let MetaPed discard BODIES_LOWER before trousers existed.
    Appearance.UpdatePedVariation(target)
    Appearance.ApplyFaceDetails(target, skinData, gender)
end

-- Final pass after clothing/body rebuilds, shared by spawn and menu reload.
function Appearance.ApplyFaceDetails(target, skinData, gender)
    local gKey = string.lower(gender or (IsPedMale(target) and "Male" or "Female"))
    Appearance.ApplyOverlays(target, skinData.overlays, gKey, skinData.albedo or skinData.Albedo)

    -- Preset finalisation can reset expression morphs. Reapply saved values
    -- after it so creator previews and selected characters use the same face.
    local featureValues = skinData and skinData.features
    if type(featureValues) ~= "table" then featureValues = skinData end
    if type(featureValues) == "table" then
        local morphApplied = false
        for _, categoryList in pairs(AppearanceData.FaceFeatures) do
            for _, feature in ipairs(categoryList) do
                local val = featureValues[feature.id]
                if val == nil and featureValues[tostring(feature.id)] ~= nil then
                    val = featureValues[tostring(feature.id)]
                end
                if val ~= nil then
                    local numVal = tonumber(val) or 0.0
                    numVal = math.max(-1.0, math.min(1.0, numVal))
                    Citizen.InvokeNative(0x5653AB26C82938CF, target, tonumber(feature.hash), numVal)
                    morphApplied = true
                end
            end
        end
        if morphApplied then
            Appearance.UpdatePedVariation(target)
        end
    end
end

Appearance.ApplyAll = Appearance.ApplySkin
