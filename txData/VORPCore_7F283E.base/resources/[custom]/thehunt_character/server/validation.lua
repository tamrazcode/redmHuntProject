-- =================================================================
-- HUNT: Hard RP — Server-side Data Validation Layer
-- Robust UTF-8 Cyrillic & Latin Support
-- =================================================================

Validation = {}

local REMOVED_CREATOR_CATEGORIES = { Badge = true, Buckle = true }

local function Clamp(value, minimum, maximum, fallback)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then number = fallback end
    return math.max(minimum, math.min(maximum, number))
end

local function TrimTo(value, maximum)
    local text = Utils.SanitizeString(tostring(value or ""))
    if #text > maximum then text = text:sub(1, maximum) end
    return text
end

local function SameHash(left, right)
    local leftKey, rightKey = Utils.HashKey(left), Utils.HashKey(right)
    return leftKey ~= nil and rightKey ~= nil and leftKey == rightKey
end

local function CatalogContains(items, wantedHash)
    if tonumber(wantedHash) == -1 then return true end
    for _, item in ipairs(type(items) == "table" and items or {}) do
        if SameHash(item.hash, wantedHash) then return true end
        for _, tintHash in ipairs(type(item.tints) == "table" and item.tints or {}) do
            if SameHash(tintHash, wantedHash) then return true end
        end
    end
    return false
end

local function ComponentExistsInCatalog(category, wantedHash, genderKey)
    if tonumber(wantedHash) == -1 then return true end
    if category == "Hair" then
        return CatalogContains(genderKey == "female" and HairsData.FemaleHairs or HairsData.MaleHairs, wantedHash)
    end
    if category == "Beard" then
        return genderKey == "male" and CatalogContains(HairsData.MaleBeards, wantedHash)
    end
    if category == "Teeth" then
        return CatalogContains((AppearanceData.Teeth or {})[genderKey], wantedHash)
    end
    local clothing = genderKey == "female" and ClothingData.Female or ClothingData.Male
    return CatalogContains(clothing and clothing[category], wantedHash)
end

local function FindCatalogHash(items, wantedHash)
    for _, item in ipairs(type(items) == "table" and items or {}) do
        if SameHash(item.hash, wantedHash) then return item.hash end
    end
    return nil
end

local function StoredComponentHash(value)
    if type(value) == "table" then value = value.comp or value.hash end
    return tonumber(value)
end

local function NormalizeOverlayColor(name, value, strictCatalog)
    local submitted = tonumber(value) or 0
    if not strictCatalog or submitted == 0 then return submitted end
    for _, colorHash in ipairs((OverlaysData.ColorPalettes or {})[name] or {}) do
        if SameHash(colorHash, submitted) then return colorHash end
    end
    local colors = (OverlaysData.ColorPalettes or {})[name]
    return colors and colors[1] or 0
end

local function IsValidNamePart(value)
    local count = 0
    local ok = pcall(function()
        for _, codepoint in utf8.codes(value) do
            local isLatin = (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
            local isCyrillic = (codepoint >= 1040 and codepoint <= 1103) or codepoint == 1025 or codepoint == 1105
            if codepoint ~= 45 and not isLatin and not isCyrillic then
                error("invalid character")
            end
            count = count + 1
        end
    end)
    return ok and count >= 2 and count <= 20
end

local function CapitaliseNamePart(value)
    for byteIndex, codepoint in utf8.codes(value) do
        local upperCodepoint = codepoint
        if codepoint >= 97 and codepoint <= 122 then
            upperCodepoint = codepoint - 32
        elseif codepoint >= 1072 and codepoint <= 1103 then
            upperCodepoint = codepoint - 32
        elseif codepoint == 1105 then
            upperCodepoint = 1025
        end
        return utf8.char(upperCodepoint) .. value:sub(byteIndex + #utf8.char(codepoint))
    end
    return value
end

--- Validate character creation input payload
--- @param src number
--- @param data table
--- @return boolean isValid, string errorMessage
function Validation.ValidateCharacterCreation(src, data)
    if type(data) ~= "table" then
        return false, "Некорректные данные персонажа."
    end

    -- 1. Name validation
    local firstname = Utils.SanitizeString(data.firstname or "")
    local lastname = Utils.SanitizeString(data.lastname or "")

    if not IsValidNamePart(firstname) then
        return false, "Имя должно содержать от 2 до 20 символов."
    end
    if not IsValidNamePart(lastname) then
        return false, "Фамилия должна содержать от 2 до 20 символов."
    end

    -- Check banned words
    local fullNameLower = (firstname .. " " .. lastname):lower()
    for _, bannedWord in ipairs(Config.BannedNames or {}) do
        if fullNameLower:find(bannedWord:lower(), 1, true) then
            return false, "Указанное имя недопустимо на сервере."
        end
    end

    -- 2. Gender validation
    local rawGender = tostring(data.gender or "Male"):lower()
    if rawGender ~= "male" and rawGender ~= "female" and rawGender ~= "mp_male" and rawGender ~= "mp_female" then
        return false, "Недопустимый пол персонажа."
    end
    data.gender = Utils.NormalizeGender(rawGender, data.skin)

    -- 3. Birth date and server-authoritative age calculation (DD/MM/YYYY).
    -- Character history is set in 1907; never use host machine os.time (fails on pre-1970 years on Windows).
    local day, month, year = tostring(data.birthdate or ""):match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    day, month, year = tonumber(day), tonumber(month), tonumber(year)
    if not day or not month or not year then
        return false, "Укажите дату рождения в формате ДД/ММ/ГГГГ."
    end
    if month < 1 or month > 12 or year < 1827 or year > 1894 then
        return false, "Указана несуществующая дата рождения."
    end
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    local isLeap = (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0))
    local maxDays = (month == 2 and isLeap) and 29 or daysInMonth[month]
    if day < 1 or day > maxDays then
        return false, "Указана несуществующая дата рождения."
    end

    local worldYear = tonumber(Config.WorldYear) or 1907
    local calculatedAge = worldYear - year
    data.age = calculatedAge

    -- 4. Age validation
    local age = tonumber(data.age) or 0
    if age < Config.MinAge or age > Config.MaxAge then
        return false, string.format("Возраст должен быть от %d до %d лет.", Config.MinAge, Config.MaxAge)
    end

    data.firstname = CapitaliseNamePart(firstname)
    data.lastname = CapitaliseNamePart(lastname)
    data.nation = TrimTo(data.nation ~= "" and data.nation or "Американец", 64)
    data.nickname = TrimTo(data.nickname, 64)
    data.description = TrimTo(data.description, 1024)
    return true, "OK"
end

--- Validate character selection payload
--- @param src number
--- @param charIdentifier number
--- @return boolean isValid, string errorMessage
function Validation.ValidateCharacterSelection(src, charIdentifier)
    local charId = tonumber(charIdentifier)
    if not charId or charId <= 0 then
        return false, "Некорректный идентификатор персонажа."
    end
    return true, "OK"
end

--- Server-authoritative character slot check.
function Validation.CanCreateMoreCharacters(src, currentCount)
    if Admin and Admin.IsAdmin(src) and Config.CharacterSlots.admin == -1 then
        return true
    end
    return (tonumber(currentCount) or 0) < (tonumber(Config.CharacterSlots.default) or 3)
end

--- Validate and canonicalize a complete appearance snapshot. The component
--- hashes come from the project catalog/client, while all scalar fields are
--- bounded before they can be persisted or passed to natives.
function Validation.SanitizeAppearance(skin, comps, compTints, gender, strictCatalog)
    local normalizedSkin, canonicalGender = Utils.NormalizeSkin(skin, gender)
    local genderKey = canonicalGender == "Female" and "female" or "male"
    local genderLetter = canonicalGender == "Female" and "F" or "M"

    normalizedSkin.HeadIndex = math.floor(Clamp(normalizedSkin.HeadIndex or normalizedSkin.headIndex, 1, 28, canonicalGender == "Female" and 1 or 8))
    normalizedSkin.ToneId = math.floor(Clamp(normalizedSkin.ToneId or normalizedSkin.toneId, 1, #(AppearanceData.SkinTones or {}), 1))
    normalizedSkin.BuildIndex = math.floor(Clamp(normalizedSkin.BuildIndex or normalizedSkin.buildIndex, 1, 5, 1))
    local submittedWaistIndex = normalizedSkin.WaistIndex or normalizedSkin.waistIndex
    if not submittedWaistIndex and tonumber(normalizedSkin.Waist or normalizedSkin.waist) then
        local submittedWaistKey = Utils.HashKey(normalizedSkin.Waist or normalizedSkin.waist)
        for index, waistHash in ipairs(AppearanceData.Waist or {}) do
            if Utils.HashKey(waistHash) == submittedWaistKey then submittedWaistIndex = index break end
        end
    end
    normalizedSkin.WaistIndex = math.floor(Clamp(submittedWaistIndex, 1, #(AppearanceData.Waist or {}), 1))
    normalizedSkin.Scale = Clamp(normalizedSkin.Scale or normalizedSkin.scale, AppearanceData.Scale.min, AppearanceData.Scale.max, AppearanceData.Scale.default)
    normalizedSkin.scale = normalizedSkin.Scale

    local validHead = false
    for _, entry in ipairs((AppearanceData.Heads and AppearanceData.Heads[genderKey]) or {}) do
        if tonumber(entry.id) == normalizedSkin.HeadIndex then validHead = true break end
    end
    if not validHead then normalizedSkin.HeadIndex = canonicalGender == "Female" and 1 or 8 end

    -- Body/head/albedo hashes are derived from the exact project registries,
    -- never trusted from a creator request or manufactured from arbitrary ids.
    local storedHead = tonumber(normalizedSkin.HeadType)
    if not storedHead or storedHead == 0 or (storedHead > -31 and storedHead < 31) then storedHead = tonumber(normalizedSkin.Head) end
    if strictCatalog or not storedHead or storedHead == 0 then
        normalizedSkin.Head = joaat(string.format("CLOTHING_ITEM_%s_HEAD_%03d_V_%03d", genderLetter, normalizedSkin.HeadIndex, normalizedSkin.ToneId))
    else
        normalizedSkin.Head = storedHead
    end
    normalizedSkin.HeadType = normalizedSkin.Head
    if strictCatalog or not tonumber(normalizedSkin.BodyType or normalizedSkin.bodyBuild) then
        normalizedSkin.BodyType = joaat(string.format("CLOTHING_ITEM_%s_BODIES_UPPER_%03d_V_%03d", genderLetter, normalizedSkin.BuildIndex, normalizedSkin.ToneId))
    end
    if strictCatalog or not tonumber(normalizedSkin.LegsType or normalizedSkin.bodyLower) then
        normalizedSkin.LegsType = joaat(string.format("CLOTHING_ITEM_%s_BODIES_LOWER_%03d_V_%03d", genderLetter, normalizedSkin.BuildIndex, normalizedSkin.ToneId))
    end
    if strictCatalog or not tonumber(normalizedSkin.Waist or normalizedSkin.waist) then
        normalizedSkin.Waist = (AppearanceData.Waist or {})[normalizedSkin.WaistIndex]
            or (AppearanceData.BodyBuilds[genderKey][normalizedSkin.BuildIndex] or {}).waist
    end
    local tone = AppearanceData.SkinTones[normalizedSkin.ToneId]
    if tone and (strictCatalog or not tonumber(normalizedSkin.albedo or normalizedSkin.Albedo)) then
        normalizedSkin.albedo = joaat(canonicalGender == "Female" and tone.albedoF or tone.albedoM)
    end

    local eyeList = (AppearanceData.EyeColors or {})[genderKey] or {}
    local submittedEyes = normalizedSkin.Eyes or normalizedSkin.eyes
    local catalogEyes = FindCatalogHash(eyeList, submittedEyes)
    if strictCatalog or not tonumber(submittedEyes) or tonumber(submittedEyes) == 0 or tonumber(submittedEyes) == -1 then
        normalizedSkin.Eyes = catalogEyes or (eyeList[1] and eyeList[1].hash) or 0
    else
        normalizedSkin.Eyes = tonumber(submittedEyes)
    end
    normalizedSkin.eyes = normalizedSkin.Eyes

    if strictCatalog then
        -- These are separate fields in old VORP snapshots. The current
        -- creator does not emit them, so never let an arbitrary NUI payload
        -- smuggle unregistered shop-item/outfit hashes into a new character.
        normalizedSkin.Torso = nil
        normalizedSkin.Legs = nil
        normalizedSkin.Body = nil
    end

    local validFeatures = {}
    for _, group in pairs(AppearanceData.FaceFeatures or {}) do
        for _, feature in ipairs(group) do
            local value = normalizedSkin.features[feature.id]
            if value == nil then value = normalizedSkin[feature.id] end
            value = Clamp(value, -1.0, 1.0, feature.default or 0.0)
            validFeatures[feature.id] = value
            normalizedSkin[feature.id] = value
        end
    end
    normalizedSkin.features = validFeatures

    local validOverlays = {}
    for name, infoList in pairs(OverlaysData.Info or {}) do
        local layer = normalizedSkin.overlays[name]
        if type(layer) == "table" then
            local txId = math.floor(Clamp(layer.tx_id, 0, #infoList, 0))
            local visible = (layer.visibility == true or tonumber(layer.visibility) == 1) and txId > 0 and 1 or 0
            local opacity = Clamp(layer.opacity or layer.tx_opacity, 0.0, 1.0, 1.0)
            local info = infoList[txId]
            local colorType = tonumber(layer.tx_color_type)
            if colorType == nil then colorType = (OverlaysData.RendererPalettes or {})[name] and 0 or 1 end
            validOverlays[name] = {
                visibility = visible,
                tx_id = txId,
                tx_normal = info and info.normal or 0,
                tx_material = info and info.ma or 0,
                tx_color_type = math.floor(Clamp(colorType, 0, 1, 1)),
                tx_opacity = Clamp(layer.tx_opacity, 0.0, 1.0, 1.0),
                tx_unk = 0,
                palette = (OverlaysData.RendererPalettes or {})[name] or 0,
                palette_color_primary = NormalizeOverlayColor(name, layer.palette_color_primary, strictCatalog),
                palette_color_secondary = NormalizeOverlayColor(name, layer.palette_color_secondary, strictCatalog),
                palette_color_tertiary = NormalizeOverlayColor(name, layer.palette_color_tertiary, strictCatalog),
                var = info and info.var or math.floor(Clamp(layer.var, 0, 255, 0)),
                opacity = opacity
            }
        end
    end
    normalizedSkin.overlays = validOverlays

    local validComps = {}
    for category, value in pairs(type(comps) == "table" and comps or {}) do
        if ClothingData.Categories[category] and not REMOVED_CREATOR_CATEGORIES[category] then
            local rawHash = type(value) == "table" and (value.comp or value.hash) or value
            local componentHash = tonumber(rawHash)
            if componentHash and componentHash == componentHash
                and (not strictCatalog or ComponentExistsInCatalog(category, componentHash, genderKey)) then
                if type(value) == "table" then
                    local clean = { comp = componentHash }
                    for _, key in ipairs({ "drawable", "albedo", "texture", "normal", "material", "palette", "tint0", "tint1", "tint2" }) do
                        if tonumber(value[key]) then clean[key] = tonumber(value[key]) end
                    end
                    if not clean.albedo and clean.texture then clean.albedo = clean.texture end
                    validComps[category] = clean
                else
                    validComps[category] = componentHash
                end
            end
        end
    end


    if strictCatalog then
        local defaultTeeth = ((AppearanceData.Teeth or {})[genderKey] or {})[1]
        normalizedSkin.Hair = StoredComponentHash(validComps.Hair) or -1
        normalizedSkin.Beard = StoredComponentHash(validComps.Beard) or -1
        normalizedSkin.Teeth = StoredComponentHash(validComps.Teeth) or (defaultTeeth and defaultTeeth.hash) or -1
    end

    local validTints = {}
    for category, value in pairs(type(compTints) == "table" and compTints or {}) do
        if ClothingData.Categories[category] and not REMOVED_CREATOR_CATEGORIES[category] and type(value) == "table" then
            validTints[category] = Utils.DeepCopy(value)
        end
    end

    normalizedSkin, canonicalGender = Utils.NormalizeSkin(normalizedSkin, canonicalGender)
    local skinJson, compsJson, tintsJson = json.encode(normalizedSkin), json.encode(validComps), json.encode(validTints)
    if #skinJson > 65535 or #compsJson > 131072 or #tintsJson > 131072 then
        return false, "Данные внешности превышают допустимый размер."
    end
    return true, normalizedSkin, validComps, validTints, canonicalGender
end
