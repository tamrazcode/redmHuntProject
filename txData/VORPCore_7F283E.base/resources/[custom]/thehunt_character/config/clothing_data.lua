-- =================================================================
-- HUNT: Hard RP — Starter Clothing & Wardrobe Registry
-- =================================================================

ClothingData = {}

-- 1. Component Category Native Hashes
ClothingData.Categories = {
    Hat                 = `HATS`,
    Shirt               = `SHIRTS_FULL`,
    Vest                = `VESTS`,
    Pant                = `PANTS`,
    Skirt               = `SKIRTS`,
    Boots               = `BOOTS`,
    Coat                = `COATS`,
    CoatClosed          = `COATS_CLOSED`,
    NeckWear            = `NECKWEAR`,
    NeckTies            = `NECKTIES`,
    Glove               = `GLOVES`,
    Belt                = `BELTS`,
    Buckle              = `BELT_BUCKLES`,
    Gunbelt             = `GUNBELTS`,
    Holster             = `HOLSTERS_LEFT`,
    Suspender           = `SUSPENDERS`,
    Poncho              = `PONCHOS`,
    Cloak               = `CLOAKS`,
    Spats               = `SPATS`,
    Chap                = `CHAPS`,
    Spurs               = `BOOT_ACCESSORIES`,
    Mask                = `MASKS`,
    EyeWear             = `EYEWEAR`,
    Accessories         = `ACCESSORIES`,
    Dress               = `DRESSES`,
    Badge               = `BADGES`,
    Gauntlets           = `GAUNTLETS`,
    Bracelet            = `JEWELRY_BRACELETS`,
    RingLh              = `JEWELRY_RINGS_LEFT`,
    RingRh              = `JEWELRY_RINGS_RIGHT`,
    Satchels            = `SATCHELS`,
    BodiesUpper         = `BODIES_UPPER`,
    BodiesLower         = `BODIES_LOWER`,
    Heads               = `HEADS`,
    Eyes                = `EYES`,
    EyeBrows            = `EYEBROWS`,
    Teeth               = `TEETH`,
    Hair                = `HAIR`,
    Beard               = `BEARDS_COMPLETE`,
    BeardsMustache      = `BEARDS_MUSTACHE`,
    Blouses             = `BLOUSES`,
    TalismanHolster     = `TALISMAN_HOLSTER`,
    Scarves             = `SCARVES`,
    TalismanBelt        = `TALISMAN_BELT`,
    ShirtsFullOverpants = `SHIRTS_FULL_OVERPANTS`,
    CoatsHeavy          = `COATS_HEAVY`,
    TalismanWrist       = `TALISMAN_WRIST`,
    Stockings           = `STOCKINGS`,
    MaskLarge           = `MASKS_LARGE`,
    Apron               = `APRONS`,
    AmmoPistol          = `AMMO_PISTOLS`,
    AmmoRifle           = `AMMO_RIFLES`,
    Loadouts            = `LOADOUTS`,
    GunbeltAccs         = `GUNBELT_ACCS`,
    Armor               = `ARMOR`,
    Bow                 = `HAIR_ACCESSORIES`
}

-- 2. Clothing Tint Palettes
ClothingData.Palettes = {
    1090645383, 1064202495, -783849117, 864404955, 1669565057, -1952348042
}

-- Values emitted by the old starter registry.  They are overlay texture IDs,
-- not wearable shop-item hashes; keep them out of migrated characters so a
-- stale record cannot punch holes through the new model's clothing.
ClothingData.InvalidLegacyHashes = {
    [0x05E518E6] = true, [0x07844317] = true, [0x0A83CA6E] = true,
    [0x12DEE615] = true, [0x139A5CA3] = true, [0x15312368] = true,
    [0x18F67AE3] = true, [0x1E462719] = true, [0x217E6BC3] = true,
    [0x2897A446] = true, [0x2A145452] = true, [0x2BC04655] = true,
    [0x32470716] = true, [0x367F4F71] = true, [0x374F8B83] = true,
    [0x3841D6C5] = true, [0x3FD61F59] = true, [0x464A496E] = true,
    [0x47B4B707] = true, [0x51E28224] = true, [0x5462D4A1] = true,
    [0x5DF72F2B] = true, [0x60064C4D] = true, [0x6E4C4B59] = true,
    [0x71F02888] = true, [0x76B663F1] = true, [0x8B763C40] = true,
    [0x8C110C61] = true, [0x90B38914] = true, [0x981C0EB1] = true,
    [0x9B417A66] = true, [0x9EC05663] = true, [0xA223BECE] = true,
    [0xD74DC3C3] = true, [0xDE57827B] = true, [0xEE7E1854] = true,
    [0xF5414C80] = true,
}

local function IsLegacyHash(hash)
    return ClothingData.InvalidLegacyHashes[hash] == true
end

-- 3. Starter Clothing Lists
ClothingData.Male = {}
ClothingData.Female = {}
ClothingData.ComponentMeta = {}

local function IsUnsafeComponent(meta)
    return meta and (meta.showSkin or meta.needsFix)
end

local function RegisterComponentMeta(genderData)
    if not genderData then return end
    for _, catList in pairs(genderData) do
        for _, itemList in ipairs(catList) do
            for _, item in ipairs(itemList) do
                if item.hash and item.hash ~= 0 then
                    local metadata = {
                        remove = item.remove,
                        applyTo = item.applyTo,
                        showSkin = item.showSkin == true,
                        needsFix = item.needsFix == true,
                    }
                    ClothingData.ComponentMeta[item.hash] = metadata
                    ClothingData.ComponentMeta[Utils.HashKey(item.hash)] = metadata
                end
            end
        end
    end
end

local CategoryMapping = {
    Hat          = "Hat",          Hats        = "Hat",
    Mask         = "Mask",         Masks       = "Mask",
    EyeWear      = "EyeWear",      Eyewear     = "EyeWear",
    NeckWear     = "NeckWear",     Neckwear    = "NeckWear",
    NeckTies     = "NeckTies",     Neckties    = "NeckTies",
    Shirt        = "Shirt",        Shirts      = "Shirt",
    Vest         = "Vest",         Vests       = "Vest",
    Coat         = "Coat",         Coats       = "Coat",
    CoatClosed   = "CoatClosed",
    Poncho       = "Poncho",       Ponchos     = "Poncho",
    Cloak        = "Cloak",        Cloaks      = "Cloak",
    Dress        = "Dress",        Dresses     = "Dress",
    Skirt        = "Skirt",        Skirts      = "Skirt",
    Pant         = "Pant",         Pants       = "Pant",
    Suspender    = "Suspender",    Suspenders  = "Suspender",
    Belt         = "Belt",         Belts       = "Belt",
    Gunbelt      = "Gunbelt",      Gunbelts    = "Gunbelt",
    Holster      = "Holster",      Holsters    = "Holster",
    Glove        = "Glove",        Gloves      = "Glove",
    Gauntlets    = "Gauntlets",
    Boots        = "Boots",        Boot        = "Boots",
    Spurs        = "Spurs",
    Spats        = "Spats",
    Chap         = "Chap",         Chaps       = "Chap",
    Accessories  = "Accessories",
    Bracelet     = "Bracelet",     Bracelets   = "Bracelet",
    RingLh       = "RingLh",
    RingRh       = "RingRh",
    Satchels     = "Satchels",
    Armor        = "Armor",
    Loadouts     = "Loadouts"
}

-- 4. Populate Complete Catalog from Shared Clothing Database
if Data and Data.clothing then
    RegisterComponentMeta(Data.clothing.male)
    RegisterComponentMeta(Data.clothing.female)

    local function LoadGenderClothing(sourceTable, targetTable)
        if not sourceTable then return end
        for rawCat, catList in pairs(sourceTable) do
            local mappedCat = CategoryMapping[rawCat]
            if mappedCat and type(catList) == "table" and #catList > 0 then
                targetTable[mappedCat] = targetTable[mappedCat] or {}
                for itemIdx, itemList in ipairs(catList) do
                    if type(itemList) == "table" and #itemList > 0 then
                        local firstItem = itemList[1]
                        local meta = firstItem and ClothingData.ComponentMeta[firstItem.hash]
                        if firstItem and firstItem.hash and firstItem.hash ~= 0 and not IsUnsafeComponent(meta) then
                            local tints = {}
                            for _, t in ipairs(itemList) do
                                if t.hash and t.hash ~= 0 and not IsLegacyHash(t.hash) then
                                    table.insert(tints, t.hash)
                                end
                            end
                            table.insert(targetTable[mappedCat], {
                                id = itemIdx,
                                name = string.format("Модель %d", itemIdx),
                                hash = firstItem.hash,
                                hashname = firstItem.hashname or "",
                                tints = tints,
                                meta = meta
                            })
                        end
                    end
                end
            end
        end
    end

    LoadGenderClothing(Data.clothing.male, ClothingData.Male)
    LoadGenderClothing(Data.clothing.female, ClothingData.Female)
end

-- Build neutral starter outfits from the real VORP component catalogue.  The
-- first entry of every generated category is "none", so choose the first
-- actual shop item for shirt, trousers and boots for both models.
local function FirstWearable(catalog, category, ordinal)
    local list = catalog and catalog[category] or nil
    if not list then return -1 end
    local wanted = ordinal or 1
    local found = 0
    for _, item in ipairs(list) do
        if item.hash and item.hash ~= 0 and item.hash ~= -1 then
            found = found + 1
            if found == wanted then return item.hash end
        end
    end
    return -1
end

ClothingData.DefaultOutfit = {
    male = {
        Shirt = FirstWearable(ClothingData.Male, "Shirt", 2),
        Pant = FirstWearable(ClothingData.Male, "Pant"),
        Boots = FirstWearable(ClothingData.Male, "Boots"),
        Gunbelt = -1, Holster = -1, Hat = -1, Coat = -1, Vest = -1,
    },
    female = {
        Shirt = FirstWearable(ClothingData.Female, "Shirt"),
        Pant = FirstWearable(ClothingData.Female, "Pant"),
        Boots = FirstWearable(ClothingData.Female, "Boots"),
        Gunbelt = -1, Holster = -1, Hat = -1, Coat = -1, Vest = -1,
    },
}
