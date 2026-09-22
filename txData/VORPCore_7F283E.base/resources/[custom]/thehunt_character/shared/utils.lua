-- =================================================================
-- HUNT: Hard RP — Shared Utilities
-- =================================================================

Utils = {}

--- Format a number as a 5-digit string with leading zeroes (e.g. 427 -> "00427")
--- @param codeNum number|string
--- @return string
function Utils.FormatCode(codeNum)
    local n = tonumber(codeNum) or 0
    return string.format("%05d", n)
end

--- Validate 5-digit code string strictly
--- @param code string
--- @return boolean
function Utils.IsValidCode(code)
    if type(code) ~= "string" then return false end
    return string.match(code, "^%d%d%d%d%d$") ~= nil
end

--- Sanitizes strings (trim whitespace, remove dangerous characters)
--- @param str string
--- @return string
function Utils.SanitizeString(str)
    if type(str) ~= "string" then return "" end
    local clean = str:gsub("^%s*(.-)%s*$", "%1")
    return clean
end

--- Build one comparison form for a character's full name.
--- This is deliberately separate from SanitizeString and from the creator's
--- formatting: it is used only for delete confirmation.
--- @param value any
--- @return string
function Utils.NormalizeCharacterName(value)
    if type(value) ~= "string" then return "" end

    -- NUI can send non-breaking / Unicode separator spaces even when they look
    -- like an ordinary space in the confirmation field. Convert only spacing
    -- characters here; the creator's original name formatting stays untouched.
    local normalized = value
        :gsub("\194\160", " ")              -- U+00A0
        :gsub("\226\128[\128-\138]", " ") -- U+2000..U+200A
        :gsub("\226\128\175", " ")       -- U+202F
        :gsub("\227\128\128", " ")       -- U+3000
        :gsub("\226\128[\139-\141]", "") -- zero-width characters
        :gsub("\239\187\191", "")       -- U+FEFF
        :gsub("%s+", " ")
        :gsub("^%s*(.-)%s*$", "%1")

    -- Lua's string.lower is ASCII-only in this runtime. Fold the supported
    -- Latin/Cyrillic alphabets explicitly so case-insensitive confirmation
    -- works for names such as "Аа Аа" as well as legacy Latin names.
    local ok, folded = pcall(function()
        local result = {}
        for _, codepoint in utf8.codes(normalized) do
            if codepoint >= 65 and codepoint <= 90 then
                codepoint = codepoint + 32
            elseif codepoint >= 1040 and codepoint <= 1071 then
                codepoint = codepoint + 32
            elseif codepoint == 1025 then
                codepoint = 1105
            end
            result[#result + 1] = utf8.char(codepoint)
        end
        return table.concat(result)
    end)

    return ok and folded or normalized:lower()
end

--- Deep copy a table without recursing forever on cyclic data.
--- @param orig table|any
--- @param seen table|nil
--- @return any
function Utils.DeepCopy(orig, seen)
    if type(orig) ~= 'table' then return orig end

    seen = seen or {}
    if seen[orig] then return seen[orig] end

    local copy = {}
    seen[orig] = copy
    for orig_key, orig_value in next, orig, nil do
        copy[Utils.DeepCopy(orig_key, seen)] = Utils.DeepCopy(orig_value, seen)
    end

    local metatable = getmetatable(orig)
    if metatable ~= nil then
        setmetatable(copy, Utils.DeepCopy(metatable, seen))
    end
    return copy
end

--- Check if table contains value
--- @param tbl table
--- @param val any
--- @return boolean
function Utils.TableContains(tbl, val)
    if type(tbl) ~= "table" then return false end
    for _, v in pairs(tbl) do
        if v == val then return true end
    end
    return false
end

--- Decode a JSON string without letting one damaged character row abort the
--- complete selection/spawn flow. Tables are returned unchanged.
--- @param value any
--- @param fallback any
--- @return any
function Utils.SafeJsonDecode(value, fallback)
    if type(value) == "table" then return value end
    if type(value) ~= "string" or value == "" then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == "table" then return decoded end
    return fallback
end

--- Canonical VORP gender used by this resource.
--- @param value any
--- @param skin table|nil
--- @return string
function Utils.NormalizeGender(value, skin)
    local raw = tostring(value or ""):lower()
    local skinSex = type(skin) == "table" and tostring(skin.sex or skin.gender or skin.model or ""):lower() or ""
    if raw == "female" or raw == "f" or raw == "mp_female" or raw == "woman" or raw == "1" then
        return "Female"
    end
    if raw == "male" or raw == "m" or raw == "mp_male" or raw == "man" or raw == "0" then return "Male" end
    if skinSex == "female" or skinSex == "f" or skinSex == "mp_female" or skinSex == "woman" or skinSex == "1" then return "Female" end
    return "Male"
end

--- Convert signed/unsigned representations of a 32-bit hash to one stable key.
--- @param value any
--- @return number|nil
function Utils.HashKey(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    number = math.floor(number)
    number = number % 4294967296
    if number < 0 then number = number + 4294967296 end
    return number
end

local LegacyOverlayPrefixes = {
    eyeliners = "eyeliner"
}

--- Convert legacy flat VORP skin fields to the nested representation used by
--- this resource, while retaining flat mirrors for other VORP resources.
function Utils.NormalizeSkin(skin, gender)
    local result = Utils.DeepCopy(type(skin) == "table" and skin or {})
    local canonicalGender = Utils.NormalizeGender(gender, result)
    result.sex = canonicalGender == "Female" and "mp_female" or "mp_male"
    result.model = result.sex
    result.AppearanceDataVersion = 2
    result.features = type(result.features) == "table" and result.features or {}
    result.overlays = type(result.overlays) == "table" and result.overlays or {}

    if AppearanceData and AppearanceData.FaceFeatures then
        for _, group in pairs(AppearanceData.FaceFeatures) do
            for _, feature in ipairs(group) do
                if result.features[feature.id] == nil and result[feature.id] ~= nil then
                    result.features[feature.id] = result[feature.id]
                elseif result.features[feature.id] ~= nil then
                    result[feature.id] = result.features[feature.id]
                end
            end
        end
    end

    if OverlaysData and OverlaysData.Info then
        for name in pairs(OverlaysData.Info) do
            local prefix = LegacyOverlayPrefixes[name] or name
            local existing = result.overlays[name]
            local legacyVisibility = result[prefix .. "_visibility"]
            if type(existing) ~= "table" and legacyVisibility ~= nil then
                existing = {
                    visibility = legacyVisibility,
                    tx_id = result[prefix .. "_tx_id"] or 1,
                    opacity = result[prefix .. "_opacity"] or 1.0,
                    var = result[prefix .. "_palette_id"] or result[prefix .. "_var"] or 0,
                    palette_color_primary = result[prefix .. "_palette_color_primary"]
                        or result[prefix .. "_color_primary"] or result[prefix .. "_color"] or 0,
                    palette_color_secondary = result[prefix .. "_palette_color_secondary"] or 0,
                    palette_color_tertiary = result[prefix .. "_palette_color_tertiary"] or 0
                }
                result.overlays[name] = existing
            end
            if type(existing) == "table" then
                result[prefix .. "_visibility"] = existing.visibility or 0
                result[prefix .. "_tx_id"] = existing.tx_id or 1
                result[prefix .. "_opacity"] = existing.opacity or 1.0
                result[prefix .. "_palette_id"] = existing.var or existing.palette_id or 0
                local primary = existing.palette_color_primary or 0
                result[prefix .. "_palette_color_primary"] = primary
                result[prefix .. "_color_primary"] = primary
                result[prefix .. "_color"] = primary
                result[prefix .. "_palette_color_secondary"] = existing.palette_color_secondary or 0
                result[prefix .. "_palette_color_tertiary"] = existing.palette_color_tertiary or 0
            end
        end
    end

    result.HeadType = result.HeadType or result.Head
    result.Head = result.Head or result.HeadType
    result.Scale = result.Scale or result.scale or 1.0
    result.scale = result.Scale
    return result, canonicalGender
end
