-- =================================================================
-- HUNT: Hard RP — Clothing & Components Customization Engine
-- =================================================================

Clothing = {}

local BASE_WEARABLE_STATE = joaat("base")

local function StoredHash(value)
    if type(value) == "table" then value = value.comp or value.hash end
    return tonumber(value) or -1
end

local function IsLegacyHash(hash)
    return ClothingData.InvalidLegacyHashes
        and (ClothingData.InvalidLegacyHashes[hash] == true or ClothingData.InvalidLegacyHashes[Utils.HashKey(hash)] == true)
end

local function GetComponentMeta(hash)
    return ClothingData.ComponentMeta
        and (ClothingData.ComponentMeta[hash] or ClothingData.ComponentMeta[Utils.HashKey(hash)])
end

local function IsUnsafeComponent(meta)
    return meta and (meta.showSkin or meta.needsFix)
end

local function GetStarterFallback(ped, category)
    local outfitKey = IsPedMale(ped or PlayerPedId()) and "male" or "female"
    local outfit = ClothingData.DefaultOutfit and ClothingData.DefaultOutfit[outfitKey] or nil
    local hash = outfit and tonumber(outfit[category]) or -1
    return (hash and hash ~= 0 and hash ~= -1 and not IsLegacyHash(hash)) and hash or -1
end

local function ResolveTintData(category, componentHash, inlineData, compTints)
    if type(inlineData) == "table" and tonumber(inlineData.palette) and tonumber(inlineData.palette) ~= 0 then
        return inlineData
    end
    local categoryTints = type(compTints) == "table" and compTints[category] or nil
    if type(categoryTints) ~= "table" then return inlineData end
    if tonumber(categoryTints.palette) then return categoryTints end
    local direct = categoryTints[componentHash] or categoryTints[tostring(componentHash)]
    if type(direct) == "table" then return direct end
    local wanted = Utils.HashKey(componentHash)
    for storedHash, tint in pairs(categoryTints) do
        if Utils.HashKey(storedHash) == wanted and type(tint) == "table" then return tint end
    end
    return inlineData
end

function Clothing.RemoveTagRaw(ped, categoryHash)
    local target = ped or PlayerPedId()
    if categoryHash then
        Citizen.InvokeNative(0xD710A5007C2AC539, target, categoryHash, 0)
    end
end

--- Remove category tag from ped
--- @param ped number
--- @param categoryHash number
function Clothing.RemoveTag(ped, categoryHash)
    local target = ped or PlayerPedId()
    Clothing.RemoveTagRaw(target, categoryHash)
    if categoryHash == ClothingData.Categories.Holster or categoryHash == `HOLSTERS` or categoryHash == `HOLSTERS_LEFT` then
        Clothing.RemoveTagRaw(target, `HOLSTERS`)
        Clothing.RemoveTagRaw(target, `HOLSTERS_LEFT`)
        Clothing.RemoveTagRaw(target, `HOLSTER_CROSSDRAW`)
        Clothing.RemoveTagRaw(target, `HOLSTER_LEFT`)
        Clothing.RemoveTagRaw(target, `TALISMAN_HOLSTER`)
    end
    Appearance.UpdatePedVariation(target)
end

--- Apply a single clothing or hair component to ped
--- @param ped number
--- @param compHash number
--- @param category string
--- @param tintData table
function Clothing.ApplyComponent(ped, compHash, category, tintData, deferUpdate)
    local target = ped or PlayerPedId()
    local catHash = category and ClothingData.Categories[category]

    if not compHash or compHash == -1 or compHash == 0 then
        if catHash then
            Clothing.RemoveTagRaw(target, catHash)
            if category == "Holster" then
                Clothing.RemoveTagRaw(target, `HOLSTERS`)
                Clothing.RemoveTagRaw(target, `HOLSTERS_LEFT`)
                Clothing.RemoveTagRaw(target, `HOLSTER_CROSSDRAW`)
                Clothing.RemoveTagRaw(target, `HOLSTER_LEFT`)
                Clothing.RemoveTagRaw(target, `TALISMAN_HOLSTER`)
            elseif category == "Pant" or category == "Skirt" then
                Appearance.RestoreLowerBody(target, false)
            elseif category == "Shirt" then
                Appearance.RestoreUpperBody(target, false)
            end
            if not deferUpdate then Appearance.UpdatePedVariation(target) end
        end
        return
    end

    local h = tonumber(compHash)
    if not h or h == 0 or h == -1 then return end

    if IsLegacyHash(h) then
        -- Old releases persisted texture hashes as clothes. Clear only the
        -- affected category; never apply such a hash to a newly spawned ped.
        if catHash then
            Clothing.RemoveTagRaw(target, catHash)
            if category == "Holster" then
                Clothing.RemoveTagRaw(target, `HOLSTERS`)
                Clothing.RemoveTagRaw(target, `HOLSTERS_LEFT`)
                Clothing.RemoveTagRaw(target, `HOLSTER_CROSSDRAW`)
                Clothing.RemoveTagRaw(target, `HOLSTER_LEFT`)
                Clothing.RemoveTagRaw(target, `TALISMAN_HOLSTER`)
            elseif category == "Pant" or category == "Skirt" then
                Appearance.RestoreLowerBody(target, false)
            elseif category == "Shirt" then
                Appearance.RestoreUpperBody(target, false)
            end
            if not deferUpdate then Appearance.UpdatePedVariation(target) end
        end
        return
    end

    -- First remove existing item tag in this category so RedM updates immediately
    if catHash then
        Clothing.RemoveTagRaw(target, catHash)
        if category == "Holster" then
            Clothing.RemoveTagRaw(target, `HOLSTERS`)
            Clothing.RemoveTagRaw(target, `HOLSTERS_LEFT`)
            Clothing.RemoveTagRaw(target, `HOLSTER_CROSSDRAW`)
            Clothing.RemoveTagRaw(target, `HOLSTER_LEFT`)
            Clothing.RemoveTagRaw(target, `TALISMAN_HOLSTER`)
        end
    end

    -- Conflict resolution
    Clothing.ResolveConflicts(target, category)

    -- Match VORP's MetaPed pipeline exactly.  The old last boolean `true`
    -- forced an incompatible base layer on some items, causing underwear and
    -- body meshes to pierce trousers and shirts.
    Citizen.InvokeNative(0xD3A7B003ED343FD9, target, h, false, false, false)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, target, h, false, true, false)

    -- Match VORP's loader: garments normally use `base`, but BOOTS must keep
    -- the state selected by the MetaPed when the component is applied.  A
    -- forced boot state is capable of exposing the feet/calves through boots.
    if category ~= "Boots" then
        Appearance.UpdateShopItemWearableState(target, h, BASE_WEARABLE_STATE)
    end

    -- Preserve the complete MetaPed texture tuple when an outfit provider
    -- supplied it. This is the VORP format used for drawable/albedo/normal/
    -- material plus palette/tints and is more precise than category tinting.
    if tintData and tintData.palette and tintData.palette ~= 0 and category then
        local drawable, albedo = tonumber(tintData.drawable), tonumber(tintData.albedo or tintData.texture)
        local normal, material = tonumber(tintData.normal), tonumber(tintData.material)
        if drawable and albedo and normal and material then
            Citizen.InvokeNative(0xBC6DF00D7A4A6819, target, drawable, albedo, normal, material,
                tonumber(tintData.palette), tonumber(tintData.tint0) or 0,
                tonumber(tintData.tint1) or 0, tonumber(tintData.tint2) or 0)
        else
            Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, target, catHash or joaat(category), tonumber(tintData.palette),
                tonumber(tintData.tint0) or 0, tonumber(tintData.tint1) or 0, tonumber(tintData.tint2) or 0)
        end
    end

    if not deferUpdate then Appearance.UpdatePedVariation(target) end
end

--- Handle mutual exclusions (e.g. Coat vs CoatClosed vs Poncho, Pants vs Skirt)
--- @param ped number
--- @param category string
function Clothing.ResolveConflicts(ped, category)
    local target = ped or PlayerPedId()
    if category == "Coat" then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.CoatClosed)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Poncho)
    elseif category == "CoatClosed" then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Coat)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Vest)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Poncho)
    elseif category == "Poncho" then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Coat)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.CoatClosed)
    elseif category == "Skirt" then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Pant)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Dress)
    elseif category == "Pant" then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Skirt)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Dress)
    elseif category == "Dress" then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Pant)
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Skirt)
    end
end

--- Apply entire clothing wardrobe & hair set to ped
--- @param ped number
--- @param comps table
--- @param compTints table
function Clothing.ApplyAll(ped, comps, compTints)
    local target = ped or PlayerPedId()
    if not comps or type(comps) ~= "table" then return end

    Appearance.WaitForPedReady(target)
    local workingComps = Utils.DeepCopy(comps)

    -- A full outfit snapshot treats an absent optional slot as empty. Clear
    -- stale tags left by an earlier outfit, but never touch the skin/body tags
    -- assembled by Appearance.ApplySkin just before this function.
    local skinCategories = {
        BodiesUpper = true, BodiesLower = true, Heads = true, Eyes = true, EyeBrows = true
    }
    for categoryName, categoryHash in pairs(ClothingData.Categories or {}) do
        if not skinCategories[categoryName] and workingComps[categoryName] == nil then
            Clothing.RemoveTagRaw(target, categoryHash)
        end
    end

    -- Migrate old texture/overlay IDs in place.  They are not shop items and
    -- are the source of the torn trousers/shoulders in existing characters.
    -- A valid neutral component replaces only the affected base garment;
    -- accessory slots are safely cleared.
    for categoryName, value in pairs(workingComps) do
        local hash = StoredHash(value)
        local meta = GetComponentMeta(hash)
        if IsLegacyHash(hash) or IsUnsafeComponent(meta) then
            workingComps[categoryName] = GetStarterFallback(target, categoryName)
        end
    end

    -- Respect the compatibility rules shipped with VORP's clothing catalogue.
    -- If an item says another layer must be removed, persist that removal in
    -- this outfit so the incompatible layer cannot reappear on the next refit.
    local removals = {}
    for _, value in pairs(workingComps) do
        local meta = GetComponentMeta(StoredHash(value))
        for _, categoryName in ipairs(meta and meta.remove or {}) do
            removals[categoryName] = true
        end
    end
    for categoryName in pairs(removals) do
        workingComps[categoryName] = -1
    end

    -- Keep the selected lower-body base active even when trousers/skirt are
    -- removed. Boots are valid on bare legs and must not be deleted as a side
    -- effect of rebuilding the outfit.
    local hasUpperGarment = StoredHash(workingComps.Shirt) ~= -1
        or StoredHash(workingComps.Blouses) ~= -1
        or StoredHash(workingComps.ShirtsFullOverpants) ~= -1
        or StoredHash(workingComps.Vest) ~= -1
        or StoredHash(workingComps.Coat) ~= -1
        or StoredHash(workingComps.CoatsHeavy) ~= -1
        or StoredHash(workingComps.CoatClosed) ~= -1
        or StoredHash(workingComps.Poncho) ~= -1
        or StoredHash(workingComps.Dress) ~= -1
        or StoredHash(workingComps.Apron) ~= -1
    Appearance.ApplyBodyCoverageState(target, hasUpperGarment)

    local hasLowerGarment = StoredHash(workingComps.Pant) ~= -1
        or StoredHash(workingComps.Skirt) ~= -1
        or StoredHash(workingComps.Dress) ~= -1

    -- RDR2's boot assets require a lower garment layer. Keep boots stored in
    -- the inventory/equipment slot, but hide the native layer when no pants,
    -- skirt or dress exists; otherwise the model renders detached boots.
    if not hasLowerGarment then
        Clothing.RemoveTagRaw(target, ClothingData.Categories.Boots)
    end

    -- MetaPed layers are order-sensitive.  Applying a Lua table with pairs()
    -- produces a different order between sessions and leaves body/clothing
    -- seams.  Dress the base layers first and the outer/accessory layers last.
    local order = {
        "Pant", "Skirt", "Stockings", "Dress", "Boots", "Spurs", "Spats",
        "Shirt", "Blouses", "ShirtsFullOverpants", "Vest", "Suspender",
        "NeckWear", "NeckTies", "Scarves", "Glove", "Gauntlets",
        "Belt", "Buckle", "TalismanBelt", "Gunbelt", "GunbeltAccs",
        "Holster", "TalismanHolster", "AmmoPistol", "AmmoRifle", "Loadouts",
        "Coat", "CoatsHeavy", "CoatClosed", "Poncho", "Cloak", "Chap", "Apron", "Armor",
        "Hat", "EyeWear", "Mask", "MaskLarge", "Accessories", "Badge", "Bracelet", "TalismanWrist",
        "RingLh", "RingRh", "Satchels", "Bow", "Hair", "Beard", "BeardsMustache", "Teeth"
    }
    local applied = {}
    local function applyCategory(categoryName, val)
        if categoryName == "Boots" and not hasLowerGarment then
            Clothing.RemoveTagRaw(target, ClothingData.Categories.Boots)
            applied[categoryName] = true
            return
        end
        local compHash = val
        local inlineTint = type(val) == "table" and val or nil
        if type(val) == "table" then
            compHash = val.comp or val.hash or -1
        end
        local tint = ResolveTintData(categoryName, tonumber(compHash) or -1, inlineTint, compTints)
        -- Explicitly stored "none" values must remove the old tag.  Without
        -- this, a gunbelt/holster or an incompatible piece from the previous
        -- model survives a gender switch and can tear holes in the outfit.
        Clothing.ApplyComponent(target, tonumber(compHash) or -1, categoryName, tint, true)
        applied[categoryName] = true
    end

    for _, categoryName in ipairs(order) do
        if workingComps[categoryName] ~= nil then
            applyCategory(categoryName, workingComps[categoryName])
        end
    end
    for categoryName, val in pairs(workingComps) do
        if not applied[categoryName] then
            applyCategory(categoryName, val)
        end
    end


    -- Some coats and vests declare a non-base wearable state for the shirt
    -- below them.  Apply those declarations only after both layers exist.
    for _, value in pairs(workingComps) do
        local meta = GetComponentMeta(StoredHash(value))
        local rule = meta and meta.applyTo
        if rule and rule[1] and rule[2] then
            local underHash = StoredHash(workingComps[rule[1]])
            if underHash ~= -1 and not IsLegacyHash(underHash) then
                Appearance.UpdateShopItemWearableState(target, underHash, rule[2])
            end
        end
    end

    if StoredHash(workingComps.Pant) == -1 and StoredHash(workingComps.Skirt) == -1 and StoredHash(workingComps.Dress) == -1 then
        Appearance.RestoreLowerBody(target, false)
    end
    if StoredHash(workingComps.Shirt) == -1 then
        Appearance.RestoreUpperBody(target, false)
    end

    Appearance.UpdatePedVariation(target)
end
