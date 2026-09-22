-- =================================================================
-- HUNT: Hard RP — Core Items System | Server Controller & Database
-- =================================================================

local ActiveDrops = {} -- [dropId] = { id, itemName, label, count, x, y, z, metadata, dropTime }
local dropIdCounter = 0
local PendingKnockAid = {} -- [healerSource] = targetSource
-- Used by helpers declared before its implementation below.
local SafeDecodeMeta
local EQUIPMENT_SLOT_IDS = {
    Hat = 0, Mask = 1, EyeWear = 2, NeckWear = 3, Shirt = 4, Vest = 5,
    Coat = 6, CoatClosed = 7, Poncho = 8, Cloak = 9, Pant = 10, Skirt = 11,
    Dress = 12, Boots = 13, Spurs = 14, Spats = 15, Chap = 16, Gunbelt = 17,
    Holster = 18, Belt = 19, Suspender = 21, Glove = 22, Gauntlets = 23,
    Accessories = 24, Bracelet = 26, RingLh = 27, RingRh = 28, Satchels = 29
}
local REMOVED_CLOTHING_ITEMS = { clothing_badge = true, clothing_buckle = true }

local function EquipmentSlotIndex(slot)
    return EQUIPMENT_SLOT_IDS[slot]
end

local function IsRemovedClothingItem(itemName)
    return REMOVED_CLOTHING_ITEMS[tostring(itemName or ""):lower()] == true
end

local function ClothingContainer(parentId) return "clothing:" .. tostring(parentId) end
local function IsClothing(def) return def and def.clothing == true end
local function CanonicalGender(value)
    return tostring(value or "Male"):lower():find("female", 1, true) and "Female" or "Male"
end

local function GetCharacterGender(src)
    local character = exports.thehunt_core:GetCharacter(src)
    if GetResourceState('thehunt_pedcustom')=='started' then
        local temporary=exports.thehunt_pedcustom:GetTemporaryAppearance(src)
        if temporary then return temporary.model=='mp_female' and 'Female' or 'Male' end
    end
    return CanonicalGender(character and character.gender)
end

local function ItemContainer(parentId) return "container:" .. tostring(parentId) end
local function IsItemContainer(def) return def and (def.isContainer == true or def.containerStorage ~= nil) end

-- Backpack contents are moved between `container:<backpack id>` and the
-- equipped clothing grid when the backpack is put on/taken off.  Never trust
-- a stale or forged client event that still references the hidden container:
-- walk its parent chain and allow access only when every backpack ancestor is
-- currently equipped.  Ordinary bags, pouches and placed containers keep
-- their existing behaviour.
local function IsInventoryStorageAccessible(identifier, charId, container)
    local current = tostring(container or "")
    local visited = {}
    while true do
        local parentId = tonumber(string.match(current, "^container:(%d+)$"))
        if not parentId then return true end
        if visited[parentId] then return false end
        visited[parentId] = true

        local parentRows = MySQL.query.await(
            "SELECT item_name, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
            { parentId, identifier, charId }
        ) or {}
        local parent = parentRows[1]
        if not parent then return false end

        local parentDef = Items.Get(parent.item_name)
        if parentDef and parentDef.isBackpack == true and tostring(parent.container or "") ~= "equipment" then
            return false
        end
        current = tostring(parent.container or "")
    end
end

local function IsKeyItem(itemDef, itemName)
    if not itemDef then return false end
    if itemDef.category == "key" or itemDef.isKey == true then return true end
    local name = tostring(itemName or ""):lower()
    return name == "house_key" or name:find("key", 1, true) ~= nil
end

local BASE_MAX_WEIGHT = 30.0
local MAX_OVERWEIGHT_MARGIN = 5.0
local HARD_WEIGHT_CAP = BASE_MAX_WEIGHT + MAX_OVERWEIGHT_MARGIN -- 35.0 kg

local function IsCarriedContainer(container, itemsByDbId, visited)
    if not container or container == "main" or container == "equipment" then
        return true
    end
    if string.sub(container, 1, 5) == "prop:" or container == "ground" then
        return false
    end
    visited = visited or {}
    local prefix, parentIdStr = string.match(container, "^([^:]+):(.+)$")
    if prefix and parentIdStr then
        local parentId = tonumber(parentIdStr)
        if parentId and not visited[parentId] then
            visited[parentId] = true
            local parent = itemsByDbId and itemsByDbId[parentId]
            if parent then
                return IsCarriedContainer(parent.container, itemsByDbId, visited)
            end
        end
    end
    return false
end

local function GetPlayerTotalCarriedWeight(steamId, charId)
    local rows = MySQL.query.await("SELECT id, item_name, count, container FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    local itemsByDbId = {}
    for _, row in ipairs(rows) do
        itemsByDbId[tonumber(row.id)] = row
    end

    local total = 0.0
    for _, row in ipairs(rows) do
        if IsCarriedContainer(row.container, itemsByDbId) then
            local itemDef = Items.Get(row.item_name)
            local isClothing = ((itemDef and (itemDef.clothing == true or itemDef.category == "clothing" or itemDef.clothingSlot ~= nil) and not itemDef.isBackpack)) or (string.sub(row.item_name, 1, 9) == "clothing_" and string.sub(row.item_name, 1, 18) ~= "clothing_satchels")
            local unitWeight = isClothing and 0.0 or ((itemDef and tonumber(itemDef.weight)) or 0.1)
            local count = tonumber(row.count) or 1
            total = total + (unitWeight * count)
        end
    end
    return math.floor(total * 10 + 0.5) / 10
end

exports('GetPlayerTotalCarriedWeight', function(src)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or not charId then return 0.0 end
    return GetPlayerTotalCarriedWeight(steamId, charId)
end)

local ActivePlayerPlacedContainers = {} -- [src] = propId
local PlacedContainerViewers = {}       -- [propId] = { [src] = true }

local function SyncPlacedPropSnapshot(propId)
    local pId = tonumber(propId)
    if not pId then return end
    Citizen.CreateThread(function()
        local rows = MySQL.query.await("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", {
            "prop:" .. tostring(pId)
        }) or {}
        local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(pId)
        local meta = propData and propData.metadata
        if type(meta) == "string" then
            meta = SafeDecodeMeta(meta)
        end
        meta = meta or {}
        meta.container_contents = rows
        if exports.thehunt_builder and exports.thehunt_builder.UpdatePlacedPropMetadata then
            exports.thehunt_builder:UpdatePlacedPropMetadata(pId, meta)
        end
    end)
end

local function RefreshPlacedContainerViewers(propId, excludeSrc)
    local pId = tonumber(propId)
    if not pId or not PlacedContainerViewers[pId] then return end
    for viewerSrc, _ in pairs(PlacedContainerViewers[pId]) do
        if viewerSrc ~= excludeSrc and GetPlayerPing(viewerSrc) > 0 then
            TriggerClientEvent("thehunt_items:refreshInventory", viewerSrc)
        end
    end
end

local function ClosePlacedContainerForAllViewers(propId)
    local pId = tonumber(propId)
    if not pId or not PlacedContainerViewers[pId] then return end
    for viewerSrc, _ in pairs(PlacedContainerViewers[pId]) do
        ActivePlayerPlacedContainers[viewerSrc] = nil
        TriggerClientEvent("thehunt_inventory:closePlacedContainerUI", viewerSrc)
        TriggerClientEvent("thehunt_items:refreshInventory", viewerSrc)
    end
    PlacedContainerViewers[pId] = nil
end

AddEventHandler('playerDropped', function()
    local src = source
    local pId = ActivePlayerPlacedContainers[src]
    if pId then
        ActivePlayerPlacedContainers[src] = nil
        if PlacedContainerViewers[pId] then
            PlacedContainerViewers[pId][src] = nil
            if not next(PlacedContainerViewers[pId]) then
                PlacedContainerViewers[pId] = nil
            end
        end
    end
end)

local function RestoreContainerContents(identifier, charId, parentId, metadata)
    local content = metadata and metadata.container_contents
    if type(content) ~= "table" or #content == 0 then return end

    for _, entry in ipairs(content) do
        if Items.Get(entry.item_name) then
            local contentRotation = (entry.is_rotated == true or entry.is_rotated == 1 or tonumber(entry.is_rotated) == 1) and 1 or 0
            local entryMeta = nil
            if entry.metadata then
                if type(entry.metadata) == "table" then
                    entryMeta = (next(entry.metadata) and json.encode(entry.metadata) or nil)
                else
                    entryMeta = tostring(entry.metadata)
                end
            end
            MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                identifier, charId, ItemContainer(parentId), tonumber(entry.slot_x) or 0, tonumber(entry.slot_y) or 0, contentRotation, entry.item_name, tonumber(entry.count) or 1, entryMeta
            })
        end
    end
    metadata.container_contents = nil
    local newMeta = (metadata and next(metadata)) and json.encode(metadata) or nil
    MySQL.update.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { newMeta, parentId })
end

local function RestoreClothingContents(identifier, charId, parentId, metadata)
    local content = metadata and metadata.clothing_contents
    if type(content) ~= "table" or #content == 0 then return end

    for _, entry in ipairs(content) do
        if Items.Get(entry.item_name) then
            local contentRotation = (entry.is_rotated == true or entry.is_rotated == 1 or tonumber(entry.is_rotated) == 1) and 1 or 0
            local entryMeta = nil
            if entry.metadata then
                if type(entry.metadata) == "table" then
                    entryMeta = (next(entry.metadata) and json.encode(entry.metadata) or nil)
                else
                    entryMeta = tostring(entry.metadata)
                end
            end
            local childId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                identifier, charId, ClothingContainer(parentId), tonumber(entry.slot_x) or 0, tonumber(entry.slot_y) or 0, contentRotation, entry.item_name, tonumber(entry.count) or 1, entryMeta
            })
            local childDef = Items.Get(entry.item_name)
            if childId and childDef and IsItemContainer(childDef) then
                local childMeta = SafeDecodeMeta(entry.metadata)
                if childMeta and childMeta.container_contents then
                    RestoreContainerContents(identifier, charId, childId, childMeta)
                end
            end
        end
    end
    metadata.clothing_contents = nil
    local newMeta = (metadata and next(metadata)) and json.encode(metadata) or nil
    MySQL.update.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { newMeta, parentId })
end

local function PackClothingContents(parentId, metadata, cb)
    MySQL.query("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", { ClothingContainer(parentId) }, function(rows)
        metadata = metadata or {}
        metadata.clothing_contents = rows or {}
        MySQL.query("DELETE FROM thehunt_inventories WHERE container = ?", { ClothingContainer(parentId) }, function() cb(metadata) end)
    end)
end

local function PackContainerContents(parentId, metadata, cb)
    MySQL.query("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", { ItemContainer(parentId) }, function(rows)
        metadata = metadata or {}
        metadata.container_contents = rows or {}
        MySQL.query("DELETE FROM thehunt_inventories WHERE container = ?", { ItemContainer(parentId) }, function() cb(metadata) end)
    end)
end

local BACKPACK_OUTERWEAR_SLOTS = {
    Coat = true, CoatClosed = true, CoatsHeavy = true,
    Poncho = true, Cloak = true, Armor = true,
}

local function SyncEquippedClothing(src, itemDef, metadata, equipped)
    if not IsClothing(itemDef) then return end
    local clothingMetadata = equipped and metadata or nil

    -- Apply the visual delta immediately from the inventory resource.  This
    -- is intentionally a single-component event: it never rebuilds the
    -- character and therefore cannot reset body build/morph state.
    TriggerClientEvent("thehunt_character:client:ApplySingleClothing", src,
        itemDef.clothingSlot,
        clothingMetadata and tonumber(clothingMetadata.component) or -1,
        clothingMetadata and clothingMetadata.tint or nil,
        nil)

    TriggerEvent('thehunt_pedcustom:inventoryClothingChanged',src,itemDef.clothingSlot,clothingMetadata)

    -- Keep the character resource as the authoritative persistence bridge.
    TriggerEvent("thehunt_character:server:syncInventoryClothing", src, itemDef.clothingSlot, clothingMetadata)

    -- A backpack is a physical client-side prop, not a MetaPed wearable. Send
    -- this only after the inventory mutation has been accepted by the server.
    if itemDef.isBackpack then
        local modelName = equipped and itemDef.propModel or nil
        local playerState = Player(src)
        if playerState then
            BackpackStateSet(src, 'attachedBackpackFit', equipped and {model=modelName, offset=BackpackFit.Normalize(clothingMetadata and clothingMetadata.backpackFit) or BackpackFit.Normalize({})} or false)
            BackpackStateSet(src, 'attachedBackpack', modelName or false)
        end
        TriggerClientEvent("thehunt_inventory:setEquippedBackpack", src, modelName or false)
    end
end
local DESPAWN_SECONDS = 3600 -- 1 час таймер жизни выброшенного предмета (3600 секунд)

-- Инициализация и создание таблиц базы данных
Citizen.CreateThread(function()
    Citizen.Wait(500)
    if exports.oxmysql then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `thehunt_inventories` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `identifier` VARCHAR(64) NOT NULL,
                `charidentifier` INT NOT NULL DEFAULT 1,
                `container` VARCHAR(32) NOT NULL DEFAULT 'main',
                `slot_x` INT NOT NULL DEFAULT 0,
                `slot_y` INT NOT NULL DEFAULT 0,
                `is_rotated` TINYINT(1) NOT NULL DEFAULT 0,
                `item_name` VARCHAR(64) NOT NULL,
                `count` INT NOT NULL DEFAULT 1,
                `metadata` LONGTEXT DEFAULT NULL,
                INDEX `idx_owner` (`identifier`, `charidentifier`, `container`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {}, function()
            -- Авто-миграции для существующих таблиц
            local migrations = {
                "ALTER TABLE `thehunt_inventories` ADD COLUMN IF NOT EXISTS `is_rotated` TINYINT(1) NOT NULL DEFAULT 0;",
                "ALTER TABLE `thehunt_inventories` ADD COLUMN IF NOT EXISTS `slot_x` INT NOT NULL DEFAULT 0;",
                "ALTER TABLE `thehunt_inventories` ADD COLUMN IF NOT EXISTS `slot_y` INT NOT NULL DEFAULT 0;",
                "ALTER TABLE `thehunt_inventories` ADD COLUMN IF NOT EXISTS `container` VARCHAR(32) NOT NULL DEFAULT 'main';",
                "ALTER TABLE `thehunt_inventories` ADD COLUMN IF NOT EXISTS `count` INT NOT NULL DEFAULT 1;",
                "ALTER TABLE `thehunt_inventories` ADD COLUMN IF NOT EXISTS `metadata` LONGTEXT DEFAULT NULL;"
            }
            for _, q in ipairs(migrations) do
                pcall(function()
                    MySQL.query(q, {})
                end)
            end

            MySQL.query([[
                CREATE TABLE IF NOT EXISTS `thehunt_drops` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `item_name` VARCHAR(64) NOT NULL,
                    `count` INT NOT NULL DEFAULT 1,
                    `x` DOUBLE NOT NULL,
                    `y` DOUBLE NOT NULL,
                    `z` DOUBLE NOT NULL,
                    `metadata` LONGTEXT DEFAULT NULL,
                    `dropped_by` VARCHAR(64) DEFAULT NULL,
                    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]], {}, function()
                -- Загрузка существующих непросроченных дропов из БД
                MySQL.query("SELECT * FROM thehunt_drops WHERE created_at >= NOW() - INTERVAL 1 HOUR", {}, function(results)
                    if results then
                        for _, r in ipairs(results) do
                            local dId = tonumber(r.id)
                            local itemDef = Items.Get(r.item_name) or { label = r.item_name }
                            ActiveDrops[dId] = {
                                id = dId,
                                itemName = r.item_name,
                                label = itemDef.label or r.item_name,
                                count = tonumber(r.count) or 1,
                                x = tonumber(r.x),
                                y = tonumber(r.y),
                                z = tonumber(r.z),
                                metadata = r.metadata and json.decode(r.metadata) or {},
                                dropTime = os.time()
                            }
                            if dId > dropIdCounter then dropIdCounter = dId end
                        end
                        print(string.format("^2[HUNT ITEMS] Таблицы БД готовы. Загружено %d активных дропов.^7", #results))
                    end
                end)
            end)
        end)
    end
end)

-- Функция получения связки идентификаторов игрока VORP
local function GetPlayerIdentifiersVORP(src)
    local steamId = "unknown"
    local charId = 1

    local char = exports.thehunt_core:GetCharacter(src)
    if char then
        steamId = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src) or "unknown"
        charId = tonumber(char.charIdentifier or char.charid) or 1
    end

    if steamId == "unknown" then
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if string.find(id, "license:") or string.find(id, "steam:") then
                steamId = id
                break
            end
        end
    end

    return steamId, charId
end

-- Безопасное декодирование метаданных предмета (с защитой от двойного кодирования JSON)
exports('GetEquippedWarmth', function(src)
    local character = exports.thehunt_core:GetCharacter(src)
    if not character then return nil, nil end
    local identifier, charId = GetPlayerIdentifiersVORP(src)
    local rows = MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'equipment' AND count > 0", { identifier, charId })
    if not rows then return nil, nil end
    local seen, warmth = {}, 0.0
    for _, row in ipairs(rows) do
        local def = Items.Get(row.item_name)
        local slot = def and def.clothingSlot
        local rule = slot and HuntInsulation[slot]
        if rule and not seen[slot] then
            seen[slot] = true
            warmth = warmth + rule.warmth
        end
    end
    -- Discard an asynchronous result if the player switched characters.
    local currentIdentifier, currentChar = GetPlayerIdentifiersVORP(src)
    if currentIdentifier ~= identifier or currentChar ~= charId then return nil, nil end
    return warmth, charId
end)

SafeDecodeMeta = function(meta)
    if not meta then return {} end
    if type(meta) == "table" then return meta end
    if type(meta) == "string" then
        if meta == "" or meta == "null" or meta == "{}" then return {} end
        local success, decoded = pcall(json.decode, meta)
        if success and decoded then
            if type(decoded) == "string" then
                local success2, decoded2 = pcall(json.decode, decoded)
                if success2 and decoded2 and type(decoded2) == "table" then
                    return decoded2
                end
            elseif type(decoded) == "table" then
                return decoded
            end
        end
    end
    return {}
end

-- Безопасная очистка технических полей мира/билдера перед сравнением или записью в инвентарь
local function CleanItemMetadata(meta)
    if not meta then return {} end
    local metaObj = SafeDecodeMeta(meta)
    if not metaObj or type(metaObj) ~= "table" then return {} end
    local clean = {}
    for k, v in pairs(metaObj) do
        if k ~= "entity_type" and k ~= "scenario" and k ~= "model_name" and k ~= "model_hash" and k ~= "builder_id" and k ~= "temp" and k ~= "from_inventory" then
            clean[k] = v
        end
    end
    return clean
end

-- Вспомогательная функция поиска свободного места в сетке инвентаря
local NOTEBOOK_MAX_HTML_BYTES = 60000

local function NotebookCaseInsensitivePattern(word)
    local result = {}
    for i = 1, #word do
        local char = word:sub(i, i)
        if char:match("%a") then
            result[#result + 1] = "[" .. char:lower() .. char:upper() .. "]"
        else
            result[#result + 1] = char
        end
    end
    return table.concat(result)
end

local function IsSafeNotebookCssColor(value)
    local color = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if color:match("^#[%da-fA-F]+$") and (#color == 4 or #color == 7 or #color == 9) then
        return true
    end
    local lower = color:lower()
    if lower:match("^rgba?%([%d%s%.,]+%)$") or lower:match("^hsla?%([%d%s%.,%%]+%)$") then
        return true
    end
    return false
end

local function SanitizeNotebookStyle(styleValue)
    if type(styleValue) ~= "string" then return "" end
    local allowed = {
        ["color"] = true,
        ["background-color"] = true,
        ["text-align"] = true,
        ["font-size"] = true,
        ["font-weight"] = true,
        ["font-style"] = true,
        ["text-decoration"] = true,
        ["width"] = true,
        ["max-width"] = true,
        ["height"] = true,
        ["float"] = true,
        ["margin"] = true,
        ["margin-left"] = true,
        ["margin-right"] = true,
        ["margin-top"] = true,
        ["margin-bottom"] = true,
        ["display"] = true,
        ["clear"] = true,
        ["vertical-align"] = true,
        ["background"] = true
    }
    local declarations = {}
    for declaration in styleValue:gmatch("[^;]+") do
        local property, value = declaration:match("^%s*([%w%-]+)%s*:%s*(.-)%s*$")
        property = property and property:lower() or nil
        value = value and value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "") or ""
        local lowerValue = value:lower()
        if property and allowed[property]
            and not lowerValue:find("url%s*%(", 1, false)
            and not lowerValue:find("javascript", 1, true)
            and not lowerValue:find("expression", 1, true)
            and not value:find("[<>]") then
            local cleanBg = lowerValue:gsub("%s+", "")
            if (property == "background" or property == "background-color")
                and (cleanBg == "#fff" or cleanBg == "#ffffff" or cleanBg == "white"
                    or cleanBg == "rgb(255,255,255)" or cleanBg == "rgba(255,255,255,1)"
                    or cleanBg == "#fafafa" or cleanBg == "#f8f8f8") then
                -- пропускаем белый фон от сторонних сайтов
            else
                value = value:gsub("[^%w#%-%s%(%),%.%%]", "")
                if value ~= "" then
                    declarations[#declarations + 1] = property .. ":" .. value
                end
            end
        end
    end
    return table.concat(declarations, ";")
end

local function EscapeNotebookAttribute(value)
    local s = tostring(value or "")
    s = s:gsub("&amp;", "&"):gsub("&quot;", "\""):gsub("&lt;", "<"):gsub("&gt;", ">")
    return s:gsub("&", "&amp;"):gsub("\"", "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function SanitizeNotebookHtml(rawHtml)
    if type(rawHtml) ~= "string" then return "" end
    if #rawHtml > NOTEBOOK_MAX_HTML_BYTES then return nil end

    -- Remove dangerous element contents before processing the remaining tags.
    for _, tag in ipairs({ "script", "style", "iframe", "object", "embed", "svg", "math", "form" }) do
        local pattern = NotebookCaseInsensitivePattern(tag)
        rawHtml = rawHtml:gsub("<%s*" .. pattern .. "[^>]*>.-<%s*/%s*" .. pattern .. "%s*>", "")
        rawHtml = rawHtml:gsub("<%s*/?%s*" .. pattern .. "[^>]*>", "")
    end

    local allowedTags = {
        b = true, strong = true, i = true, em = true, u = true, s = true,
        strike = true, del = true, mark = true, small = true, sub = true,
        sup = true, p = true, div = true, h2 = true, h3 = true,
        blockquote = true, ul = true, ol = true, li = true, br = true,
        hr = true, font = true, span = true, img = true
    }
    local voidTags = { br = true, hr = true, img = true }

    return rawHtml:gsub("<([^>]-)>", function(rawTag)
        local isClosing = rawTag:match("^%s*/") ~= nil
        local tagName = rawTag:match("^%s*/?%s*([%a][%w%-]*)")
        if not tagName then return "" end
        tagName = tagName:lower()
        if not allowedTags[tagName] then return "" end
        if isClosing then
            return voidTags[tagName] and "" or "</" .. tagName .. ">"
        end

        if tagName == "img" then
            local imageUrl = rawTag:match("[Ss][Rr][Cc]%s*=%s*\"([^\"]+)\"")
                or rawTag:match("[Ss][Rr][Cc]%s*=%s*'([^']+)'")
                or rawTag:match("[Ss][Rr][Cc]%s*=%s*([^%s>]+)")
            imageUrl = imageUrl and imageUrl:gsub("^%s+", ""):gsub("%s+$", "") or ""
            local lowerUrl = imageUrl:lower()
            if imageUrl == "" or #imageUrl > 4096
                or (lowerUrl:sub(1, 8) ~= "https://" and lowerUrl:sub(1, 7) ~= "http://") then
                return ""
            end
            local imgStyle = rawTag:match("[Ss][Tt][Yy][Ll][Ee]%s*=%s*\"([^\"]*)\"")
                or rawTag:match("[Ss][Tt][Yy][Ll][Ee]%s*=%s*'([^']*)'")
            local safeImgStyle = SanitizeNotebookStyle(imgStyle)
            if safeImgStyle == "" then
                safeImgStyle = "max-width:100%;height:auto;background:transparent;"
            end
            return '<img src="' .. EscapeNotebookAttribute(imageUrl) .. '" referrerpolicy="no-referrer" style="' .. EscapeNotebookAttribute(safeImgStyle) .. '">'
        end

        local attributes = ""
        local style = rawTag:match("[Ss][Tt][Yy][Ll][Ee]%s*=%s*\"([^\"]*)\"")
            or rawTag:match("[Ss][Tt][Yy][Ll][Ee]%s*=%s*'([^']*)'")
        local safeStyle = SanitizeNotebookStyle(style)
        if safeStyle ~= "" then
            attributes = ' style="' .. EscapeNotebookAttribute(safeStyle) .. '"'
        end
        if tagName == "font" then
            local color = rawTag:match("[Cc][Oo][Ll][Oo][Rr]%s*=%s*\"([^\"]*)\"")
                or rawTag:match("[Cc][Oo][Ll][Oo][Rr]%s*=%s*'([^']*)'")
            if IsSafeNotebookCssColor(color) then
                attributes = attributes .. ' color="' .. EscapeNotebookAttribute(color) .. '"'
            end
        end
        return "<" .. tagName .. attributes .. ">"
    end)
end

local PAGE_MAX_LINES = 15
local PAGE_MAX_CHARS = 1200

local function TruncateHtmlToPageLimit(rawHtml, maxLines, maxChars)
    if type(rawHtml) ~= "string" or rawHtml == "" then return "" end
    maxLines = maxLines or PAGE_MAX_LINES
    maxChars = maxChars or PAGE_MAX_CHARS

    local clean = SanitizeNotebookHtml(rawHtml)
    if not clean or clean == "" then return "" end

    local result = {}
    local openTags = {}
    local lineCount = 1
    local charCount = 0
    local hitLimit = false

    local pos = 1
    local len = #clean

    while pos <= len do
        if hitLimit then break end

        local tagStart, tagEnd = clean:find("<[^>]+>", pos)
        local text = ""

        if tagStart then
            if tagStart > pos then
                text = clean:sub(pos, tagStart - 1)
            end
        else
            text = clean:sub(pos)
        end

        if text ~= "" then
            local truncatedText = ""
            for i = 1, #text do
                local c = text:sub(i, i)
                if c == "\n" then
                    if lineCount >= maxLines then
                        hitLimit = true
                        break
                    end
                    lineCount = lineCount + 1
                end
                if charCount >= maxChars then
                    hitLimit = true
                    break
                end
                charCount = charCount + 1
                truncatedText = truncatedText .. c
            end
            if truncatedText ~= "" then
                result[#result + 1] = truncatedText
            end
        end

        if hitLimit or not tagStart then break end

        local fullTag = clean:sub(tagStart, tagEnd)
        local isClosing, tagName = fullTag:match("^<%s*(/?)%s*([%w%-]+)")
        tagName = tagName and tagName:lower() or ""

        if fullTag:match("^<%s*img") then
            if lineCount >= maxLines then
                hitLimit = true
                break
            end
            lineCount = lineCount + 1
            result[#result + 1] = fullTag
        elseif fullTag:match("^<%s*br%s*/?>") then
            if lineCount >= maxLines then
                hitLimit = true
                break
            end
            lineCount = lineCount + 1
            result[#result + 1] = fullTag
        elseif isClosing == "/" then
            if #openTags > 0 and openTags[#openTags].tag == tagName then
                table.remove(openTags)
            end
            result[#result + 1] = fullTag

            if tagName == "p" or tagName == "div" or tagName == "li" or tagName == "h2" or tagName == "h3" or tagName == "blockquote" then
                if lineCount >= maxLines then
                    hitLimit = true
                    break
                end
                lineCount = lineCount + 1
            end
        else
            if not fullTag:match("/%s*>$") then
                openTags[#openTags + 1] = { tag = tagName, full = fullTag }
            end
            result[#result + 1] = fullTag
        end

        pos = tagEnd + 1
    end

    for i = #openTags, 1, -1 do
        result[#result + 1] = "</" .. openTags[i].tag .. ">"
    end

    return table.concat(result)
end

local function FindFreeInventorySlot(items, cols, rows, itemW, itemH)
    cols = cols or (Items.GetGridCols and Items.GetGridCols("main")) or 7
    rows = rows or (Items.GetGridRows and Items.GetGridRows("main")) or 4
    itemW = itemW or 1
    itemH = itemH or 1

    local matrix = {}
    for r = 0, rows - 1 do
        matrix[r] = {}
        for c = 0, cols - 1 do
            matrix[r][c] = false
        end
    end

    for _, it in ipairs(items) do
        local def = Items.Get(it.item_name)
        local rawW = def and def.width or 1
        local rawH = def and def.height or 1
        local isRot = (it.is_rotated == true or it.is_rotated == 1 or tonumber(it.is_rotated) == 1)
        local w = isRot and rawH or rawW
        local h = isRot and rawW or rawH
        local startX = tonumber(it.slot_x) or 0
        local startY = tonumber(it.slot_y) or 0

        for r = 0, h - 1 do
            for c = 0, w - 1 do
                if matrix[startY + r] and matrix[startY + r][startX + c] ~= nil then
                    matrix[startY + r][startX + c] = true
                end
            end
        end
    end

    -- 1. Сначала проверяем без поворота (сверху вниз r, слева направо c)
    for r = 0, rows - itemH do
        for c = 0, cols - itemW do
            local canFit = true
            for checkR = 0, itemH - 1 do
                for checkC = 0, itemW - 1 do
                    if matrix[r + checkR][c + checkC] then
                        canFit = false
                        break
                    end
                end
                if not canFit then break end
            end
            if canFit then
                return c, r, false
            end
        end
    end

    -- 2. Если не поместился, проверяем с поворотом 90 градусов (если ширина != высоты)
    if itemW ~= itemH then
        local rotW = itemH
        local rotH = itemW
        for r = 0, rows - rotH do
            for c = 0, cols - rotW do
                local canFit = true
                for checkR = 0, rotH - 1 do
                    for checkC = 0, rotW - 1 do
                        if matrix[r + checkR][c + checkC] then
                            canFit = false
                            break
                        end
                    end
                    if not canFit then break end
                end
                if canFit then
                    return c, r, true
                end
            end
        end
    end

    return nil, nil, false
end

-- MySQL drivers can return TINYINT values as numbers, booleans, or strings.
-- Keep rotation handling identical for normal and clothing-container rows.
local function IsRotatedValue(value)
    if value == true or value == 1 then return true end
    if type(value) == "string" then
        local normalized = value:lower()
        return normalized == "1" or normalized == "true" or normalized == "yes"
    end
    return tonumber(value) == 1
end

local function StorageAreaFits(storage, x, y, width, height)
    local cols = tonumber(storage and storage.cols) or 0
    local rows = tonumber(storage and storage.rows) or 0
    x, y, width, height = tonumber(x), tonumber(y), tonumber(width), tonumber(height)
    if not x or not y or not width or not height or width < 1 or height < 1 then return false end
    if x < 0 or y < 0 or x + width > cols or y + height > rows then return false end

    for row = y, y + height - 1 do
        local rowWidth = storage.rowWidths and tonumber(storage.rowWidths[row + 1]) or cols
        if x + width > rowWidth then return false end
    end
    return true
end

local function StorageAreaFree(storage, occupied, x, y, width, height)
    if not StorageAreaFits(storage, x, y, width, height) then return false end
    for row = y, y + height - 1 do
        for col = x, x + width - 1 do
            if occupied[row] and occupied[row][col] then return false end
        end
    end
    return true
end

local function MarkStorageArea(occupied, x, y, width, height)
    for row = y, y + height - 1 do
        occupied[row] = occupied[row] or {}
        for col = x, x + width - 1 do
            occupied[row][col] = true
        end
    end
end

local function FindFreeClothingSlot(storage, occupied, rawWidth, rawHeight, preferredRotation)
    local tried = {}
    local rotations = { preferredRotation == true, false, true }

    for _, rotated in ipairs(rotations) do
        if not tried[rotated] then
            tried[rotated] = true
            local width = rotated and rawHeight or rawWidth
            local height = rotated and rawWidth or rawHeight
            local cols = tonumber(storage.cols) or 0
            local rows = tonumber(storage.rows) or 0
            for y = 0, rows - height do
                for x = 0, cols - width do
                    if StorageAreaFree(storage, occupied, x, y, width, height) then
                        return x, y, rotated
                    end
                end
            end
        end
    end

    return nil, nil, false
end

-- Repair legacy/invalid child coordinates before they reach the NUI.  This
-- keeps a garment's saved orientation whenever it still fits, then repacks
-- only rows that overlap or fall outside the garment's actual pocket layout.
local function NormalizeClothingStorage(identifier, charId, parentId, storage)
    if not storage then return end

    local rows = MySQL.query.await(
        "SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ? ORDER BY id ASC",
        { identifier, charId, ClothingContainer(parentId) }
    ) or {}
    local occupied = {}

    for _, row in ipairs(rows) do
        local itemDef = Items.Get(row.item_name)
        if itemDef then
            local rawWidth = tonumber(itemDef.width) or 1
            local rawHeight = tonumber(itemDef.height) or 1
            local oldX = tonumber(row.slot_x) or 0
            local oldY = tonumber(row.slot_y) or 0
            local oldRotation = IsRotatedValue(row.is_rotated)
            local oldWidth = oldRotation and rawHeight or rawWidth
            local oldHeight = oldRotation and rawWidth or rawHeight
            local finalX, finalY, finalRotation

            -- Preserve a valid, non-overlapping placement exactly as saved.
            if StorageAreaFree(storage, occupied, oldX, oldY, oldWidth, oldHeight) then
                finalX, finalY, finalRotation = oldX, oldY, oldRotation
            else
                finalX, finalY, finalRotation = FindFreeClothingSlot(
                    storage, occupied, rawWidth, rawHeight, oldRotation
                )
            end

            if finalX ~= nil then
                MarkStorageArea(occupied, finalX, finalY,
                    finalRotation and rawHeight or rawWidth,
                    finalRotation and rawWidth or rawHeight)

                local normalizedRotation = finalRotation and 1 or 0
                if oldX ~= finalX or oldY ~= finalY or (oldRotation and 1 or 0) ~= normalizedRotation then
                    MySQL.update.await(
                        "UPDATE thehunt_inventories SET slot_x = ?, slot_y = ?, is_rotated = ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = ?",
                        { finalX, finalY, normalizedRotation, row.id, identifier, charId, ClothingContainer(parentId) }
                    )
                end
            end
        end
    end
end

-- Backpack fitting sessions: inventory ownership is checked on every network
-- mutation. Preview never writes SQL; final save only changes one metadata key.
local BackpackFitSessions, BackpackFitRequests = {}, {}
local backpackFitSerial = 0
local BackpackProfiles = {}
local profileFile = 'backpack_defaults.json'
do
    local raw = LoadResourceFile(GetCurrentResourceName(), profileFile)
    local ok, decoded = pcall(json.decode, raw or '{}')
    if ok and type(decoded) == 'table' then
        for model, value in pairs(decoded) do
            BackpackProfiles[model] = BackpackFit.Normalize(value, true, true)
        end
    end
    GlobalState.huntBackpackProfiles = BackpackProfiles
end
local function FitAdmin(src)
    local ok, allowed = pcall(function() return exports.thehunt_core:IsPlayerAdmin(src) end)
    if ok then return allowed == true end
    return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command')
        or IsPlayerAceAllowed(src, 'admin') or IsPlayerAceAllowed(src, 'txadmin')
end
local function FitCharacter(src)
    local char = exports.thehunt_core:GetCharacter(src)
    if not char then return end
    local identifier = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src)
    local charId = tonumber(char.charIdentifier or char.charid)
    if identifier and charId then return identifier, charId end
end
local function FitRow(src, dbId)
    local identifier, charId = FitCharacter(src)
    if not identifier then return end
    local row = MySQL.single.await([[SELECT id,item_name,metadata FROM thehunt_inventories
        WHERE id=? AND identifier=? AND charidentifier=? AND container='equipment' AND slot_x=? AND count>0]],
        {dbId, identifier, charId, EquipmentSlotIndex('Satchels')})
    local def = row and Items.Get(row.item_name)
    local currentIdentifier, currentChar = FitCharacter(src)
    if currentIdentifier ~= identifier or currentChar ~= charId then return end
    if row and def and def.isBackpack and def.propModel then return row, def, identifier, charId end
end
local function FitPacket(row, def, value)
    return {itemId=tonumber(row.id), model=def.propModel, offset=value or BackpackFit.Normalize(SafeDecodeMeta(row.metadata).backpackFit) or BackpackFit.Normalize({})}
end
local function EndBackpackFit(src, notify)
    local session = BackpackFitSessions[src]
    if not session then return end
    BackpackFitSessions[src] = nil
    local identifier, charId = FitCharacter(src)
    if identifier == session.identifier and charId == session.charId then
        BackpackStateSet(src, 'attachedBackpackFit', session.original)
    end
    if notify then TriggerClientEvent('thehunt_inventory:backpackFitEnded', src, session.token) end
end
RegisterNetEvent('thehunt_items:beginBackpackFit', function(dbId, admin)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    admin = admin == true
    if admin and not FitAdmin(src) then
        TriggerClientEvent('thehunt_status:notify', src, 'Рюкзак', 'Недостаточно прав для настройки стандарта.', 'error')
        return
    end
    dbId = tonumber(dbId)
    if not dbId or dbId % 1 ~= 0 then return end
    local now = GetGameTimer()
    if now < (BackpackFitRequests[src] or 0) then return end
    BackpackFitRequests[src] = now + 1000
    EndBackpackFit(src, true)
    local row, def, identifier, charId = FitRow(src, dbId)
    if not row then
        TriggerClientEvent('thehunt_status:notify', src, 'Рюкзак', 'Нужно надеть этот рюкзак.', 'error')
        return
    end
    backpackFitSerial = backpackFitSerial + 1
    local packet = FitPacket(row, def)
    local original = packet
    if admin then
        packet = FitPacket(row, def, BackpackFit.Normalize({}))
        packet.calibration = BackpackProfiles[def.propModel] or BackpackFit.Normalize({})
    end
    local session = {token=backpackFitSerial, dbId=dbId, identifier=identifier, charId=charId,
        model=def.propModel, admin=admin, original=original, current=packet, expires=now+30000, nextPreview=0}
    BackpackFitSessions[src] = session
    BackpackStateSet(src, 'attachedBackpackFit', packet)
    TriggerClientEvent('thehunt_inventory:backpackFitStarted', src, session.token, packet)
end)
RegisterNetEvent('thehunt_items:previewBackpackFit', function(token, value)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local session = BackpackFitSessions[src]
    local fit = BackpackFit.Normalize(value, true, session and session.admin)
    if not session or session.token ~= token or not fit or session.busy or session.saving or GetGameTimer() < session.nextPreview then return end
    session.nextPreview = GetGameTimer()+250
    session.busy = true
    local row, def, identifier, charId = FitRow(src, session.dbId)
    session.busy = false
    if BackpackFitSessions[src] ~= session then return end
    if not row or identifier ~= session.identifier or charId ~= session.charId or def.propModel ~= session.model then
        EndBackpackFit(src, true); return
    end
    session.expires = GetGameTimer()+30000
    session.current = FitPacket(row, def, fit)
    if session.admin then
        if not FitAdmin(src) then EndBackpackFit(src, true); return end
        session.current.offset = BackpackFit.Normalize({})
        session.current.calibration = fit
    end
    BackpackStateSet(src, 'attachedBackpackFit', session.current)
end)
RegisterNetEvent('thehunt_items:cancelBackpackFit', function(token)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    if BackpackFitSessions[src] and BackpackFitSessions[src].token == token then EndBackpackFit(src, false) end
end)
RegisterNetEvent('thehunt_items:saveBackpackFit', function(token, value)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local session = BackpackFitSessions[src]
    if not session or session.token ~= token or session.saving then return end
    local fit = BackpackFit.Normalize(value, true, session.admin)
    if not fit then EndBackpackFit(src, true); return end
    session.saving = true
    local ok, saved = pcall(function()
        local row, def, identifier, charId = FitRow(src, session.dbId)
        if BackpackFitSessions[src] ~= session or not row or identifier ~= session.identifier or charId ~= session.charId then return false end
        if session.admin then
            if not FitAdmin(src) or def.propModel ~= session.model then return false end
            local updated = {}
            for model, profile in pairs(BackpackProfiles) do updated[model] = profile end
            updated[session.model] = fit
            local encoded = json.encode(updated)
            if not SaveResourceFile(GetCurrentResourceName(), profileFile, encoded, #encoded) then
                error('Cannot write '..GetResourcePath(GetCurrentResourceName())..'/'..profileFile)
            end
            if LoadResourceFile(GetCurrentResourceName(), profileFile) ~= encoded then error('Backpack default readback failed') end
            BackpackProfiles = updated
            GlobalState.huntBackpackProfiles = updated
            TriggerClientEvent('thehunt_inventory:backpackProfiles', -1, updated)
            print(('[HUNT BACKPACK] Saved default model=%s file=%s'):format(session.model, profileFile))
            -- The calibrating item must show precisely the new standard on exit.
            -- Personal adjustments of all other items are left intact.
            fit = BackpackFit.Normalize({})
        end
        local affected = MySQL.update.await([[UPDATE thehunt_inventories
            SET metadata=JSON_SET(CASE WHEN JSON_VALID(metadata) AND JSON_TYPE(metadata)='OBJECT' THEN metadata ELSE '{}' END, '$.backpackFit', JSON_EXTRACT(?, '$'))
            WHERE id=? AND identifier=? AND charidentifier=? AND item_name=? AND container='equipment' AND slot_x=? AND count>0]],
            {json.encode(fit), session.dbId, identifier, charId, row.item_name, EquipmentSlotIndex('Satchels')})
        -- MariaDB may report zero changed rows for an identical fit. Re-read the
        -- authoritative row before acknowledging or replicating a successful save.
        local verified, verifiedDef, vi, vc = FitRow(src, session.dbId)
        if not verified or vi ~= identifier or vc ~= charId then return false end
        local stored = BackpackFit.Normalize(SafeDecodeMeta(verified.metadata).backpackFit, true)
        if not stored then return false end
        for _, key in ipairs(BackpackFit.Keys) do if math.abs(stored[key]-fit[key]) > 0.000001 then return false end end
        if BackpackFitSessions[src] ~= session then return false end
        session.original = FitPacket(verified, verifiedDef, stored)
        return true
    end)
    if BackpackFitSessions[src] ~= session then return end
    if not ok then print('[thehunt_items] Backpack fit save failed: '..tostring(saved)) end
    EndBackpackFit(src, false)
    TriggerClientEvent('thehunt_inventory:backpackFitSaved', src, token, ok and saved == true)
end)
AddEventHandler('playerDropped', function()
    BackpackFitSessions[source], BackpackFitRequests[source] = nil, nil
end)
AddEventHandler('thehunt:character:selected', function(src)
    src = tonumber(src)
    if not src then return end
    EndBackpackFit(src, true)
    local player = Player(src)
    BackpackStateSet(src, 'attachedBackpackFit', false)
    BackpackStateSet(src, 'attachedBackpack', false)
    BackpackStateSet(src, 'attachedBackpackOuterwear', false)
end)
CreateThread(function()
    while true do
        Wait(1000)
        for src, session in pairs(BackpackFitSessions) do
            if GetGameTimer() > session.expires then EndBackpackFit(src, true) end
        end
    end
end)

-- 1. Запрос полного инвентаря игрока
RegisterNetEvent("thehunt_items:requestInventory", function(clientRequestId, clientMutationSequence)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)

    local results = MySQL.query.await(
        "SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?",
        { steamId, charId }
    ) or {}

    -- Normalize every garment container before building the snapshot.  A
    -- second read is intentional: it makes the response reflect repaired
    -- coordinates in the same refresh instead of one refresh later.
    local needsRequery = false
    for _, row in ipairs(results) do
        local itemDef = Items.Get(row.item_name)
        if itemDef and itemDef.clothing and itemDef.storage then
            NormalizeClothingStorage(steamId, charId, row.id, itemDef.storage)
        end
        local meta = SafeDecodeMeta(row.metadata)
        if itemDef and IsItemContainer(itemDef) and meta and meta.container_contents and type(meta.container_contents) == "table" and #meta.container_contents > 0 then
            RestoreContainerContents(steamId, charId, row.id, meta)
            needsRequery = true
        elseif itemDef and IsClothing(itemDef) and meta and meta.clothing_contents and type(meta.clothing_contents) == "table" and #meta.clothing_contents > 0 then
            RestoreClothingContents(steamId, charId, row.id, meta)
            needsRequery = true
        end
    end
    if needsRequery then
        results = MySQL.query.await(
            "SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?",
            { steamId, charId }
        ) or results
    end

    -- Publish the authoritative possession bit for clients that gate native
    -- UI apps.  A map inside the player's own inventory or clothing storage
    -- counts; world/placed-container rows do not.
    local hasMap = false
    for _, row in ipairs(results) do
        local container = tostring(row.container or "main")
        if tostring(row.item_name or ""):lower() == "map"
            and (tonumber(row.count) or 0) > 0 and not container:match("^prop:") then
            hasMap = true
            break
        end
    end
    Player(src).state:set("huntHasMap", hasMap, true)

    local items = {}
    local equippedBackpackModel = nil
    local equippedBackpackFit = false
    local hasEquippedBackpackOuterwear = false
    for _, row in ipairs(results) do
        if not IsRemovedClothingItem(row.item_name) then
            local itemDef = Items.Get(row.item_name)
            local isRotated = IsRotatedValue(row.is_rotated)
            local meta = SafeDecodeMeta(row.metadata)
            if itemDef and itemDef.clothing and not itemDef.isBackpack and not (meta.gender or meta.sex) then
                -- Backfill garments created before gender metadata was
                -- introduced. Their owner is the only reliable source
                -- for legacy records.
                meta.gender = GetCharacterGender(src)
                MySQL.update("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), row.id })
            elseif itemDef and itemDef.isBackpack and meta and (meta.gender or meta.sex) then
                meta.gender = nil
                meta.sex = nil
                MySQL.update("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), row.id })
            end
            if itemDef and itemDef.isBackpack and row.container == "equipment"
                and tonumber(row.slot_x) == EquipmentSlotIndex("Satchels") then
                equippedBackpackModel = itemDef.propModel
                equippedBackpackFit = FitPacket(row, itemDef)
            end
            if itemDef and row.container == "equipment" and BACKPACK_OUTERWEAR_SLOTS[itemDef.clothingSlot] then
                hasEquippedBackpackOuterwear = true
            end
            table.insert(items, {
                dbId = tonumber(row.id),
                name = row.item_name,
                label = (meta and meta.label) or (itemDef and itemDef.label) or row.item_name,
                container = row.container or "main",
                x = tonumber(row.slot_x) or 0,
                y = tonumber(row.slot_y) or 0,
                isRotated = isRotated,
                count = tonumber(row.count) or 1,
                width = itemDef and itemDef.width or 1,
                height = itemDef and itemDef.height or 1,
                rarity = itemDef and itemDef.rarity or "white",
                category = itemDef and itemDef.category or "item",
                description = itemDef and itemDef.description or "",
                weight = (itemDef and (itemDef.clothing or itemDef.category == "clothing" or itemDef.clothingSlot ~= nil) and not itemDef.isBackpack and 0.0) or (itemDef and itemDef.weight) or 0.1,
                maxStack = itemDef and itemDef.maxStack or 1,
                canUse = itemDef and itemDef.canUse or false,
                actions = itemDef and itemDef.actions or { "place", "give", "drop" },
                image = itemDef and itemDef.image or nil,
                icon = itemDef and itemDef.icon or nil,
                clothing = itemDef and itemDef.clothing or false,
                clothingSlot = itemDef and itemDef.clothingSlot or nil,
                insulationLabel = itemDef and itemDef.insulationLabel or nil,
                storage = itemDef and itemDef.storage or nil,
                isContainer = itemDef and itemDef.isContainer or false,
                containerStorage = itemDef and itemDef.containerStorage or nil,
                isBackpack = itemDef and itemDef.isBackpack or false,
                propModel = itemDef and itemDef.propModel or nil,
                uses = (meta and tonumber(meta.uses)) or (itemDef and itemDef.uses) or nil,
                maxUses = (meta and tonumber(meta.maxUses)) or (itemDef and itemDef.maxUses) or nil,
                metadata = meta
            })
        end
    end

    local activePropId = ActivePlayerPlacedContainers[src]
    if activePropId then
        local propRows = MySQL.query.await(
            "SELECT * FROM thehunt_inventories WHERE container = ?",
            { "prop:" .. tostring(activePropId) }
        ) or {}
        for _, row in ipairs(propRows) do
            local itemDef = Items.Get(row.item_name)
            local isRotated = IsRotatedValue(row.is_rotated)
            local meta = SafeDecodeMeta(row.metadata)
            table.insert(items, {
                dbId = tonumber(row.id),
                name = row.item_name,
                label = (meta and meta.label) or (itemDef and itemDef.label) or row.item_name,
                container = "prop:" .. tostring(activePropId),
                x = tonumber(row.slot_x) or 0,
                y = tonumber(row.slot_y) or 0,
                isRotated = isRotated,
                count = tonumber(row.count) or 1,
                width = itemDef and itemDef.width or 1,
                height = itemDef and itemDef.height or 1,
                rarity = itemDef and itemDef.rarity or "white",
                category = itemDef and itemDef.category or "item",
                description = itemDef and itemDef.description or "",
                weight = (itemDef and (itemDef.clothing or itemDef.category == "clothing" or itemDef.clothingSlot ~= nil) and not itemDef.isBackpack and 0.0) or (itemDef and itemDef.weight) or 0.1,
                maxStack = itemDef and itemDef.maxStack or 1,
                canUse = false,
                actions = { "give", "drop" },
                image = itemDef and itemDef.image or nil,
                icon = itemDef and itemDef.icon or nil,
                clothing = itemDef and itemDef.clothing or false,
                clothingSlot = itemDef and itemDef.clothingSlot or nil,
                insulationLabel = itemDef and itemDef.insulationLabel or nil,
                storage = itemDef and itemDef.storage or nil,
                isContainer = itemDef and itemDef.isContainer or false,
                containerStorage = itemDef and itemDef.containerStorage or nil,
                isBackpack = itemDef and itemDef.isBackpack or false,
                propModel = itemDef and itemDef.propModel or nil,
                uses = (meta and tonumber(meta.uses)) or (itemDef and itemDef.uses) or nil,
                maxUses = (meta and tonumber(meta.maxUses)) or (itemDef and itemDef.maxUses) or nil,
                metadata = meta
            })
        end
    end

    local playerState = Player(src)
    if playerState then
        local fitSession = BackpackFitSessions[src]
        if fitSession then
            if equippedBackpackFit and equippedBackpackFit.itemId == fitSession.dbId
                and steamId == fitSession.identifier and charId == fitSession.charId then
                equippedBackpackFit = fitSession.current
            else
                EndBackpackFit(src, true)
            end
        end
        BackpackStateSet(src, 'attachedBackpackFit', equippedBackpackFit)
        BackpackStateSet(src, 'attachedBackpack', equippedBackpackModel)
        BackpackStateSet(src, 'attachedBackpackOuterwear', equippedBackpackModel and hasEquippedBackpackOuterwear or false)
    end
    TriggerClientEvent("thehunt_items:receiveInventory", src, items, ActiveDrops, GetCharacterGender(src), clientRequestId, clientMutationSequence)
end)

local function CanPackGarment(src, def, parentDef, metadata, dbId)
    if not IsClothing(def) then return true end
    local hasChildren = false
    if dbId then
        local children = MySQL.query.await("SELECT id FROM thehunt_inventories WHERE container IN (?, ?) LIMIT 1", {
            ClothingContainer(dbId), ItemContainer(dbId)
        })
        hasChildren = not children or children[1] ~= nil
    end
    if Items.CanPackClothing(def, parentDef, metadata, hasChildren) then return true end
    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В сумку или рюкзак можно убрать только одежду с пустыми карманами.", "warning")
    return false
end

-- 2. Сохранение перемещения / поворота предмета в инвентаре
RegisterNetEvent("thehunt_items:_legacySaveItemPlacement", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not data or not data.dbId then return end

    local dbId = tonumber(data.dbId)
    local container = data.container or "main"
    local slotX = tonumber(data.x) or 0
    local slotY = tonumber(data.y) or 0
    local isRotated = IsRotatedValue(data.isRotated) and 1 or 0

    MySQL.query("SELECT item_name, metadata, container, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { dbId, steamId, charId }, function(rows)
        local row = rows and rows[1]
        if not row then return end
        local def, oldContainer = Items.Get(row.item_name), row.container or "main"
        local metadata = SafeDecodeMeta(row.metadata)
        if IsClothing(def) and (container:match('^clothing:') or container:match('^container:')) then
            TriggerClientEvent("thehunt_items:refreshInventory", src); return
        end
        local oldSlotX = tonumber(row.slot_x) or 0
        local oldSlotY = tonumber(row.slot_y) or 0
        local oldIsRotated = IsRotatedValue(row.is_rotated) and 1 or 0
        if not IsInventoryStorageAccessible(steamId, charId, oldContainer)
            or not IsInventoryStorageAccessible(steamId, charId, container) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end
        if container == "equipment" then
            local expectedX = def and EquipmentSlotIndex(def.clothingSlot)
            local itemGender = metadata and (metadata.gender or metadata.sex)
            if not IsClothing(def) or expectedX == nil or slotX ~= expectedX or slotY ~= 0
                or (not def.isBackpack and itemGender and CanonicalGender(itemGender) ~= GetCharacterGender(src)) then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end
            slotX, slotY, isRotated = expectedX, 0, 0
        elseif string.sub(container, 1, 9) == "clothing:" then
            local parentId = tonumber(string.sub(container, 10))
            if IsClothing(def) or not parentId then TriggerClientEvent("thehunt_items:refreshInventory", src); return end
            MySQL.query("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", { parentId, steamId, charId }, function(parentRows)
                local parentDef = parentRows and parentRows[1] and Items.Get(parentRows[1].item_name)
                if not IsClothing(parentDef) or not parentDef.storage then TriggerClientEvent("thehunt_items:refreshInventory", src); return end
                local rawW, rawH = def.width or 1, def.height or 1
                local w, h = isRotated == 1 and rawH or rawW, isRotated == 1 and rawW or rawH
                if slotX < 0 or slotY < 0 or slotX + w > parentDef.storage.cols or slotY + h > parentDef.storage.rows then TriggerClientEvent("thehunt_items:refreshInventory", src); return end
                for row = slotY, slotY + h - 1 do
                    local rowWidth = parentDef.storage.rowWidths and parentDef.storage.rowWidths[row + 1] or parentDef.storage.cols
                    if slotX + w > rowWidth then TriggerClientEvent("thehunt_items:refreshInventory", src); return end
                end

                -- The client normally rejects overlaps, but the server must
                -- enforce this too.  Without this check a stale drag event
                -- could stack multiple child items at one coordinate; the
                -- next clothing refresh would then render them on top of one
                -- another.
                MySQL.query("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ? AND id <> ?", {
                    steamId, charId, container, dbId
                }, function(existingRows)
                    for _, existing in ipairs(existingRows or {}) do
                        local existingDef = Items.Get(existing.item_name)
                        local existingRotated = IsRotatedValue(existing.is_rotated)
                        local existingW = existingRotated and (existingDef and existingDef.height or 1) or (existingDef and existingDef.width or 1)
                        local existingH = existingRotated and (existingDef and existingDef.width or 1) or (existingDef and existingDef.height or 1)
                        local existingX = tonumber(existing.slot_x) or 0
                        local existingY = tonumber(existing.slot_y) or 0
                        local overlaps = not (slotX + w <= existingX or slotX >= existingX + existingW
                            or slotY + h <= existingY or slotY >= existingY + existingH)
                        if overlaps then
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                            return
                        end
                    end

                    if oldContainer == container and oldSlotX == slotX and oldSlotY == slotY and oldIsRotated == isRotated then
                        return
                    end
                    MySQL.update("UPDATE thehunt_inventories SET container = ?, slot_x = ?, slot_y = ?, is_rotated = ? WHERE id = ? AND identifier = ? AND charidentifier = ?", { container, slotX, slotY, isRotated, dbId, steamId, charId }, function() TriggerClientEvent("thehunt_items:refreshInventory", src) end)
                end)
            end)
            return
        elseif string.sub(container, 1, 10) == "container:" then
            local parentId = tonumber(string.sub(container, 11))
            if not parentId or parentId == dbId or IsItemContainer(def) then TriggerClientEvent("thehunt_items:refreshInventory", src); return end
            MySQL.query("SELECT item_name, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { parentId, steamId, charId }, function(parentRows)
                local parentDef = parentRows and parentRows[1] and Items.Get(parentRows[1].item_name)
                if not parentDef or not parentDef.containerStorage then TriggerClientEvent("thehunt_items:refreshInventory", src); return end
                if parentDef.containerStorage.keyOnly == true and not IsKeyItem(def, row.item_name) then
                    TriggerClientEvent("thehunt_status:notify", src, "Связка ключей", "В связку можно помещать только ключи!", "warning")
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end
                local rawW, rawH = def.width or 1, def.height or 1
                local w, h = isRotated == 1 and rawH or rawW, isRotated == 1 and rawW or rawH
                local cols = tonumber(parentDef.containerStorage.cols) or 2
                local rowsCount = tonumber(parentDef.containerStorage.rows) or 3
                if slotX < 0 or slotY < 0 or slotX + w > cols or slotY + h > rowsCount then TriggerClientEvent("thehunt_items:refreshInventory", src); return end

                MySQL.query("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ? AND id <> ?", {
                    steamId, charId, container, dbId
                }, function(existingRows)
                    for _, existing in ipairs(existingRows or {}) do
                        local existingDef = Items.Get(existing.item_name)
                        local existingRotated = IsRotatedValue(existing.is_rotated)
                        local existingW = existingRotated and (existingDef and existingDef.height or 1) or (existingDef and existingDef.width or 1)
                        local existingH = existingRotated and (existingDef and existingDef.width or 1) or (existingDef and existingDef.height or 1)
                        local existingX = tonumber(existing.slot_x) or 0
                        local existingY = tonumber(existing.slot_y) or 0
                        local overlaps = not (slotX + w <= existingX or slotX >= existingX + existingW
                            or slotY + h <= existingY or slotY >= existingY + existingH)
                        if overlaps then
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                            return
                        end
                    end

                    if oldContainer == container and oldSlotX == slotX and oldSlotY == slotY and oldIsRotated == isRotated then
                        return
                    end
                    MySQL.update("UPDATE thehunt_inventories SET container = ?, slot_x = ?, slot_y = ?, is_rotated = ? WHERE id = ? AND identifier = ? AND charidentifier = ?", { container, slotX, slotY, isRotated, dbId, steamId, charId }, function() TriggerClientEvent("thehunt_items:refreshInventory", src) end)
                end)
            end)
            return
        elseif oldContainer == "equipment" and IsClothing(def) then
            SyncEquippedClothing(src, def, metadata, false)
        end
        if oldContainer == container and oldSlotX == slotX and oldSlotY == slotY and oldIsRotated == isRotated then
            return
        end
        MySQL.update("UPDATE thehunt_inventories SET container = ?, slot_x = ?, slot_y = ?, is_rotated = ? WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            container, slotX, slotY, isRotated, dbId, steamId, charId
        }, function()
            if container == "equipment" then SyncEquippedClothing(src, def, metadata, true) end
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end)
    end)
end)

-- 2.1 Объединение стаков (Merge Stacks: Инвентарь <-> Земля <-> Инвентарь)
-- Server-authoritative placement path. The UI may predict the visual result,
-- but only this handler commits coordinates. A FIFO prevents two quick drags
-- from completing in reverse order.
local PlacementQueues = {}

local function ProcessItemPlacement(src, data, done)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local function reject()
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        done()
    end

    if type(data) ~= "table" or not data.dbId then done(); return end

    local dbId = tonumber(data.dbId)
    local container = tostring(data.container or "")
    local slotX = tonumber(data.x)
    local slotY = tonumber(data.y)
    if not dbId or dbId ~= dbId or math.abs(dbId) >= 1000000000 or not slotX or not slotY
        or slotX ~= slotX or slotY ~= slotY or math.abs(slotX) >= 1000000 or math.abs(slotY) >= 1000000
        or slotX ~= math.floor(slotX) or slotY ~= math.floor(slotY) then
        reject()
        return
    end

    local activePropId = ActivePlayerPlacedContainers[src]
    local rows
    if activePropId then
        rows = MySQL.query.await("SELECT item_name, metadata, container, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE id = ? AND ((identifier = ? AND charidentifier = ?) OR container = ?)", {
            dbId, steamId, charId, "prop:" .. tostring(activePropId)
        }) or {}
    else
        rows = MySQL.query.await("SELECT item_name, metadata, container, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            dbId, steamId, charId
        }) or {}
    end
    local row = rows[1]
    if not row then reject(); return end

    local def = Items.Get(row.item_name)
    if not def then reject(); return end

    local oldContainer = row.container or "main"
    local metadata = SafeDecodeMeta(row.metadata)
    local oldSlotX = tonumber(row.slot_x) or 0
    local oldSlotY = tonumber(row.slot_y) or 0
    local oldIsRotated = IsRotatedValue(row.is_rotated) and 1 or 0
    local isRotated = IsRotatedValue(data.isRotated) and 1 or 0

    if not IsInventoryStorageAccessible(steamId, charId, oldContainer)
        or not IsInventoryStorageAccessible(steamId, charId, container) then
        reject()
        return
    end

    local isOldProp = string.sub(oldContainer, 1, 5) == "prop:"
    local isNewProp = string.sub(container, 1, 5) == "prop:"
    if isOldProp and not isNewProp then
        local itemWeight = (def and tonumber(def.weight)) or 0.1
        local count = tonumber(row.count) or 1
        local addedWeight = itemWeight * count
        local curWeight = GetPlayerTotalCarriedWeight(steamId, charId)
        if curWeight + addedWeight > HARD_WEIGHT_CAP + 0.001 then
            reject(string.format("Слишком тяжело! Предел веса %.1f кг превышен.", HARD_WEIGHT_CAP), "error")
            return
        end
    end

    if container == "equipment" then
        local expectedX = EquipmentSlotIndex(def.clothingSlot)
        local itemGender = metadata and (metadata.gender or metadata.sex)
        if not IsClothing(def) or expectedX == nil or slotX ~= expectedX or slotY ~= 0
            or (not def.isBackpack and itemGender and CanonicalGender(itemGender) ~= GetCharacterGender(src)) then
            reject()
            return
        end

        local occupied = MySQL.query.await("SELECT id FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'equipment' AND slot_x = ? AND id <> ? LIMIT 1", {
            steamId, charId, expectedX, dbId
        }) or {}
        if occupied[1] then reject(); return end
        slotX, slotY, isRotated = expectedX, 0, 0
    elseif container == "main" then
        local rawW, rawH = tonumber(def.width) or 1, tonumber(def.height) or 1
        local width = isRotated == 1 and rawH or rawW
        local height = isRotated == 1 and rawW or rawH
        local cols, rowsCount = Items.GetGridCols("main"), Items.GetGridRows("main")
        if slotX < 0 or slotY < 0 or slotX + width > cols or slotY + height > rowsCount then
            reject()
            return
        end

        local existingRows = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main' AND id <> ?", {
            steamId, charId, dbId
        }) or {}
        for _, existing in ipairs(existingRows) do
            local existingDef = Items.Get(existing.item_name)
            if existingDef then
                local existingRotated = IsRotatedValue(existing.is_rotated)
                local existingW = existingRotated and (tonumber(existingDef.height) or 1) or (tonumber(existingDef.width) or 1)
                local existingH = existingRotated and (tonumber(existingDef.width) or 1) or (tonumber(existingDef.height) or 1)
                local existingX = tonumber(existing.slot_x) or 0
                local existingY = tonumber(existing.slot_y) or 0
                if not (slotX + width <= existingX or slotX >= existingX + existingW
                    or slotY + height <= existingY or slotY >= existingY + existingH) then
                    reject()
                    return
                end
            end
        end
    elseif string.sub(container, 1, 9) == "clothing:" then
        local parentId = tonumber(string.sub(container, 10))
        if not parentId or parentId == dbId then reject(); return end

        local parentRows = MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", {
            parentId, steamId, charId
        }) or {}
        local parentDef = parentRows[1] and Items.Get(parentRows[1].item_name)
        if not IsClothing(parentDef) or not parentDef.storage then reject(); return end
        if not CanPackGarment(src, def, parentDef, metadata, dbId) then reject(); return end

        local rawW, rawH = tonumber(def.width) or 1, tonumber(def.height) or 1
        local width = isRotated == 1 and rawH or rawW
        local height = isRotated == 1 and rawW or rawH
        if not StorageAreaFits(parentDef.storage, slotX, slotY, width, height) then
            reject()
            return
        end

        local existingRows = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ? AND id <> ?", {
            steamId, charId, container, dbId
        }) or {}
        for _, existing in ipairs(existingRows) do
            local existingDef = Items.Get(existing.item_name)
            if existingDef then
                local existingRotated = IsRotatedValue(existing.is_rotated)
                local existingW = existingRotated and (tonumber(existingDef.height) or 1) or (tonumber(existingDef.width) or 1)
                local existingH = existingRotated and (tonumber(existingDef.width) or 1) or (tonumber(existingDef.height) or 1)
                local existingX = tonumber(existing.slot_x) or 0
                local existingY = tonumber(existing.slot_y) or 0
                if not (slotX + width <= existingX or slotX >= existingX + existingW
                    or slotY + height <= existingY or slotY >= existingY + existingH) then
                    reject()
                    return
                end
            end
        end
    elseif string.sub(container, 1, 10) == "container:" then
        local parentId = tonumber(string.sub(container, 11))
        if not parentId or parentId == dbId or IsItemContainer(def) then reject(); return end

        local parentRows = MySQL.query.await("SELECT item_name, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            parentId, steamId, charId
        }) or {}
        local parentDef = parentRows[1] and Items.Get(parentRows[1].item_name)
        if not parentDef or not parentDef.containerStorage then reject(); return end
        if not CanPackGarment(src, def, parentDef, metadata, dbId) then reject(); return end

        if parentDef.containerStorage.keyOnly == true and not IsKeyItem(def, row.item_name) then
            TriggerClientEvent("thehunt_status:notify", src, "Связка ключей", "В связку можно помещать только ключи!", "warning")
            reject()
            return
        end

        local rawW, rawH = tonumber(def.width) or 1, tonumber(def.height) or 1
        local width = isRotated == 1 and rawH or rawW
        local height = isRotated == 1 and rawW or rawH
        local cols = tonumber(parentDef.containerStorage.cols) or 2
        local rowsCount = tonumber(parentDef.containerStorage.rows) or 3
        if slotX < 0 or slotY < 0 or slotX + width > cols or slotY + height > rowsCount then
            reject()
            return
        end

        local existingRows = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ? AND id <> ?", {
            steamId, charId, container, dbId
        }) or {}
        for _, existing in ipairs(existingRows) do
            local existingDef = Items.Get(existing.item_name)
            if existingDef then
                local existingRotated = IsRotatedValue(existing.is_rotated)
                local existingW = existingRotated and (tonumber(existingDef.height) or 1) or (tonumber(existingDef.width) or 1)
                local existingH = existingRotated and (tonumber(existingDef.width) or 1) or (tonumber(existingDef.height) or 1)
                local existingX = tonumber(existing.slot_x) or 0
                local existingY = tonumber(existing.slot_y) or 0
                if not (slotX + width <= existingX or slotX >= existingX + existingW
                    or slotY + height <= existingY or slotY >= existingY + existingH) then
                    reject()
                    return
                end
            end
        end
    elseif string.sub(container, 1, 5) == "prop:" then
        local propId = tonumber(string.sub(container, 6))
        if not propId or IsItemContainer(def) then reject(); return end
        if activePropId ~= propId then reject(); return end

        local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(propId)
        if not propData then reject(); return end

        -- Protection check
        local isProtected = (propData.is_protected == 1 or propData.is_protected == true)
        if isProtected and propData.owner and propData.owner ~= "ADMIN" and propData.owner ~= "UNKNOWN" then
            local isOwner = (propData.owner == steamId)
            local isAdmin = exports.thehunt_core and exports.thehunt_core.IsPlayerAdmin and exports.thehunt_core:IsPlayerAdmin(src)
            if not isOwner and not isAdmin then reject(); return end
        end

        local propItemDef = propData.item_name and Items.Get(propData.item_name)
        if not propItemDef and propData.model_hash then
            local resolvedName, defFound = Items.GetByPropModel(propData.model_hash)
            if resolvedName then propItemDef = defFound end
        end
        local containerStorage = propItemDef and propItemDef.containerStorage or { cols = 3, rows = 3 }

        if containerStorage.keyOnly == true and not IsKeyItem(def, row.item_name) then
            TriggerClientEvent("thehunt_status:notify", src, "Связка ключей", "В связку можно помещать только ключи!", "warning")
            reject()
            return
        end

        local rawW, rawH = tonumber(def.width) or 1, tonumber(def.height) or 1
        local width = isRotated == 1 and rawH or rawW
        local height = isRotated == 1 and rawW or rawH
        local cols = tonumber(containerStorage.cols) or 3
        local rowsCount = tonumber(containerStorage.rows) or 3
        if slotX < 0 or slotY < 0 or slotX + width > cols or slotY + height > rowsCount then
            reject()
            return
        end

        local existingRows = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE container = ? AND id <> ?", {
            container, dbId
        }) or {}
        for _, existing in ipairs(existingRows) do
            local existingDef = Items.Get(existing.item_name)
            if existingDef then
                local existingRotated = IsRotatedValue(existing.is_rotated)
                local existingW = existingRotated and (tonumber(existingDef.height) or 1) or (tonumber(existingDef.width) or 1)
                local existingH = existingRotated and (tonumber(existingDef.width) or 1) or (tonumber(existingDef.height) or 1)
                local existingX = tonumber(existing.slot_x) or 0
                local existingY = tonumber(existing.slot_y) or 0
                if not (slotX + width <= existingX or slotX >= existingX + existingW
                    or slotY + height <= existingY or slotY >= existingY + existingH) then
                    reject()
                    return
                end
            end
        end
    else
        reject()
        return
    end

    if oldContainer == container and oldSlotX == slotX and oldSlotY == slotY and oldIsRotated == isRotated then
        done()
        return
    end

    local newIdentifier = steamId
    local newCharId = charId
    if string.sub(container, 1, 5) == "prop:" then
        newIdentifier = "WORLD"
        newCharId = 0
    end

    if IsClothing(def) and (container:match('^clothing:') or container:match('^container:')) then
        local children = MySQL.query.await("SELECT id FROM thehunt_inventories WHERE container IN (?, ?) LIMIT 1", { ClothingContainer(dbId), ItemContainer(dbId) })
        if not children or children[1] then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Сначала освободите карманы одежды.", "warning")
            reject(); return
        end
    end
    local changed = MySQL.update.await("UPDATE thehunt_inventories SET identifier = ?, charidentifier = ?, container = ?, slot_x = ?, slot_y = ?, is_rotated = ? WHERE id = ?", {
        newIdentifier, newCharId, container, slotX, slotY, isRotated, dbId
    })
    if tonumber(changed) ~= 1 then reject(); return end

    if oldContainer == "equipment" and IsClothing(def) then
        SyncEquippedClothing(src, def, metadata, false)
    end
    if container == "equipment" then
        SyncEquippedClothing(src, def, metadata, true)
    end

    if def and def.isBackpack then
        if oldContainer == "equipment" and container ~= "equipment" then
            MySQL.update.await("UPDATE thehunt_inventories SET container = ? WHERE container = ?", { "container:" .. tostring(dbId), "clothing:" .. tostring(dbId) })
        elseif oldContainer ~= "equipment" and container == "equipment" then
            MySQL.update.await("UPDATE thehunt_inventories SET container = ? WHERE container = ?", { "clothing:" .. tostring(dbId), "container:" .. tostring(dbId) })
        end
    end

    local oldPropId = string.sub(oldContainer, 1, 5) == "prop:" and tonumber(string.sub(oldContainer, 6)) or nil
    local newPropId = string.sub(container, 1, 5) == "prop:" and tonumber(string.sub(container, 6)) or nil

    if oldPropId then
        SyncPlacedPropSnapshot(oldPropId)
        RefreshPlacedContainerViewers(oldPropId, src)
    end
    if newPropId and newPropId ~= oldPropId then
        SyncPlacedPropSnapshot(newPropId)
        RefreshPlacedContainerViewers(newPropId, src)
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    done()
end

local function RunNextPlacement(src)
    local state = PlacementQueues[src]
    if not state or state.running then return end
    local data = table.remove(state.items, 1)
    if not data then PlacementQueues[src] = nil; return end

    state.running = true
    local finished = false
    local function done()
        if finished then return end
        finished = true
        state.running = false
        RunNextPlacement(src)
    end
    local ok, err = pcall(ProcessItemPlacement, src, data, done)
    if not ok then
        print(("^1[HUNT ITEMS] placement failed for %s: %s^7"):format(tostring(src), tostring(err)))
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        done()
    end
end

RegisterNetEvent("thehunt_items:saveItemPlacement", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local state = PlacementQueues[src]
    if not state then
        state = { items = {}, running = false }
        PlacementQueues[src] = state
    end
    state.items[#state.items + 1] = data
    RunNextPlacement(src)
end)

RegisterNetEvent("thehunt_items:_legacyMergeItems", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not data then return end

    local mergeCount = tonumber(data.count) or 1
    local srcDbId = data.sourceDbId and tonumber(data.sourceDbId) or nil
    local dstDbId = data.targetDbId and tonumber(data.targetDbId) or nil
    local srcDropId = data.sourceDropId and tonumber(data.sourceDropId) or nil
    local dstDropId = data.targetDropId and tonumber(data.targetDropId) or nil

    for _, inventoryId in ipairs({ srcDbId, dstDbId }) do
        if inventoryId then
            local rows = MySQL.query.await(
                "SELECT container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
                { inventoryId, steamId, charId }
            ) or {}
            if not rows[1] or not IsInventoryStorageAccessible(steamId, charId, rows[1].container) then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end
        end
    end

    -- 1. Земля -> Земля
    if srcDropId and dstDropId then
        if srcDropId == dstDropId then return end
        local srcDrop = ActiveDrops[srcDropId]
        local dstDrop = ActiveDrops[dstDropId]
        if srcDrop and dstDrop and srcDrop.itemName == dstDrop.itemName then
            local itemDef = Items.Get(srcDrop.itemName)
            local maxStack = itemDef and itemDef.maxStack or 1
            local curDst = tonumber(dstDrop.count) or 1
            local curSrc = tonumber(srcDrop.count) or 1
            local space = maxStack - curDst
            if space > 0 then
                local actualMerge = math.min(mergeCount, math.min(curSrc, space))
                if actualMerge > 0 then
                    dstDrop.count = curDst + actualMerge
                    MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { dstDrop.count, dstDropId })
                    TriggerClientEvent("thehunt_items:onDropUpdated", -1, dstDropId, dstDrop.count)

                    if curSrc <= actualMerge then
                        ActiveDrops[srcDropId] = nil
                        MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { srcDropId })
                        TriggerClientEvent("thehunt_items:onDropRemoved", -1, srcDropId)
                    else
                        srcDrop.count = curSrc - actualMerge
                        MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { srcDrop.count, srcDropId })
                        TriggerClientEvent("thehunt_items:onDropUpdated", -1, srcDropId, srcDrop.count)
                    end
                end
            end
        end
        return
    end

    -- 2. Инвентарь -> Земля
    if srcDbId and dstDropId then
        MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            srcDbId, steamId, charId
        }, function(rows)
            if rows and #rows > 0 then
                local srcItem = rows[1]
                local dstDrop = ActiveDrops[dstDropId]
                if dstDrop and srcItem.item_name == dstDrop.itemName then
                    local itemDef = Items.Get(srcItem.item_name)
                    local maxStack = itemDef and itemDef.maxStack or 1
                    local curDst = tonumber(dstDrop.count) or 1
                    local curSrc = tonumber(srcItem.count) or 1
                    local space = maxStack - curDst
                    if space > 0 then
                        local actualMerge = math.min(mergeCount, math.min(curSrc, space))
                        if actualMerge > 0 then
                            dstDrop.count = curDst + actualMerge
                            MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { dstDrop.count, dstDropId })
                            TriggerClientEvent("thehunt_items:onDropUpdated", -1, dstDropId, dstDrop.count)

                            if curSrc <= actualMerge then
                                MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { srcDbId })
                            else
                                MySQL.update("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { actualMerge, srcDbId })
                            end
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                        end
                    end
                end
            end
        end)
        return
    end

    -- 3. Земля -> Инвентарь
    if srcDropId and dstDbId then
        local srcDrop = ActiveDrops[srcDropId]
        if srcDrop then
            MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ?", {
                dstDbId
            }, function(rows)
                if rows and #rows > 0 then
                    local dstItem = rows[1]
                    if srcDrop.itemName == dstItem.item_name then
                        local itemDef = Items.Get(dstItem.item_name)
                        local maxStack = itemDef and itemDef.maxStack or 1
                        local curDst = tonumber(dstItem.count) or 1
                        local curSrc = tonumber(srcDrop.count) or 1
                        local space = maxStack - curDst
                        if space > 0 then
                            local actualMerge = math.min(mergeCount, math.min(curSrc, space))
                            if actualMerge > 0 then
                                MySQL.update("UPDATE thehunt_inventories SET count = count + ? WHERE id = ?", { actualMerge, dstDbId })
                                if curSrc <= actualMerge then
                                    ActiveDrops[srcDropId] = nil
                                    MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { srcDropId })
                                    TriggerClientEvent("thehunt_items:onDropRemoved", -1, srcDropId)
                                else
                                    srcDrop.count = curSrc - actualMerge
                                    MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { srcDrop.count, srcDropId })
                                    TriggerClientEvent("thehunt_items:onDropUpdated", -1, srcDropId, srcDrop.count)
                                end
                                TriggerClientEvent("thehunt_items:refreshInventory", src)
                            end
                        end
                    end
                end
            end)
        end
        return
    end

    -- 4. Инвентарь -> Инвентарь
    if srcDbId and dstDbId then
        if srcDbId == dstDbId then return end
        MySQL.query("SELECT * FROM thehunt_inventories WHERE id IN (?, ?) AND identifier = ? AND charidentifier = ?", {
            srcDbId, dstDbId, steamId, charId
        }, function(rows)
            if rows and #rows == 2 then
                local sourceItem = (rows[1].id == srcDbId) and rows[1] or rows[2]
                local targetItem = (rows[1].id == dstDbId) and rows[1] or rows[2]

                if sourceItem.item_name == targetItem.item_name then
                    local itemDef = Items.Get(sourceItem.item_name)
                    local maxStack = itemDef and itemDef.maxStack or 1
                    local curTargetCount = tonumber(targetItem.count) or 1
                    local curSourceCount = tonumber(sourceItem.count) or 1

                    local availableSpace = maxStack - curTargetCount
                    if availableSpace > 0 then
                        local actualMerge = math.min(mergeCount, math.min(curSourceCount, availableSpace))
                        if actualMerge > 0 then
                            MySQL.update("UPDATE thehunt_inventories SET count = count + ? WHERE id = ?", {
                                actualMerge, dstDbId
                            }, function()
                                if curSourceCount <= actualMerge then
                                    MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { srcDbId })
                                else
                                    MySQL.update("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", {
                                        actualMerge, srcDbId
                                    })
                                end
                                TriggerClientEvent("thehunt_items:refreshInventory", src)
                            end)
                        end
                    end
                end
            end
        end)
    end
end)

-- 2.2 Разделение стака (Split Stack: Инвентарь <-> Земля)
-- Secure stack merge path. The previous implementation trusted the target
-- inventory id in the ground -> inventory branch and used several unrelated
-- asynchronous writes, which made stale/repeated requests unsafe.
local MergeQueues = {}
local MergeDropLocks = {}

local function MergeMetadataEqual(left, right)
    local a, b = CleanItemMetadata(left), CleanItemMetadata(right)
    local aHas, bHas = next(a) ~= nil, next(b) ~= nil
    return (not aHas and not bHas) or (aHas and bHas and json.encode(a) == json.encode(b))
end

local function MergeDropNearPlayer(src, drop)
    if not drop then return false end
    local ped = GetPlayerPed(src)
    return #(GetEntityCoords(ped) - vector3(drop.x, drop.y, drop.z)) <= 6.0
end

local function MergeConsumeDrop(dropId, drop, amount)
    local take = tonumber(amount) or 0
    local current = tonumber(drop and drop.count) or 0
    if take < 1 or take > current then return false end
    if take == current then
        local deleted = MySQL.update.await("DELETE FROM thehunt_drops WHERE id = ? AND count = ?", { dropId, current })
        if tonumber(deleted) ~= 1 then return false end
        ActiveDrops[dropId] = nil
        TriggerClientEvent("thehunt_items:onDropRemoved", -1, dropId)
        return true
    end
    local changed = MySQL.update.await("UPDATE thehunt_drops SET count = count - ? WHERE id = ? AND count >= ?", {
        take, dropId, take
    })
    if tonumber(changed) ~= 1 then return false end
    drop.count = current - take
    TriggerClientEvent("thehunt_items:onDropUpdated", -1, dropId, drop.count)
    return true
end

local function MergeRollbackDrop(dropId, drop, previousCount, currentCount)
    local changed = MySQL.update.await("UPDATE thehunt_drops SET count = ? WHERE id = ? AND count = ?", {
        previousCount, dropId, currentCount
    })
    if tonumber(changed) == 1 then
        drop.count = previousCount
        TriggerClientEvent("thehunt_items:onDropUpdated", -1, dropId, previousCount)
        return true
    end
    return false
end

local function ProcessMerge(src, data, done)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local locked = {}
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        for id in pairs(locked) do
            if MergeDropLocks[id] == src then MergeDropLocks[id] = nil end
        end
        done()
    end
    local function reject()
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
    end
    local function lockDrop(id)
        if not id then return true end
        if MergeDropLocks[id] then return false end
        MergeDropLocks[id] = src
        locked[id] = true
        return true
    end

    if type(data) ~= "table" then reject(); return end
    local mergeCount = tonumber(data.count)
    if not mergeCount or mergeCount ~= mergeCount then reject(); return end
    mergeCount = math.floor(mergeCount)
    if mergeCount < 1 then reject(); return end

    local srcDbId = tonumber(data.sourceDbId)
    local dstDbId = tonumber(data.targetDbId)
    local srcDropId = tonumber(data.sourceDropId)
    local dstDropId = tonumber(data.targetDropId)
    if srcDbId and dstDbId and srcDbId == dstDbId then reject(); return end
    if srcDropId and dstDropId and srcDropId == dstDropId then reject(); return end

    -- Ground -> ground.
    if srcDropId and dstDropId then
        local sourceDrop, targetDrop = ActiveDrops[srcDropId], ActiveDrops[dstDropId]
        if not sourceDrop or not targetDrop or not MergeDropNearPlayer(src, sourceDrop) or not MergeDropNearPlayer(src, targetDrop)
            or sourceDrop.itemName ~= targetDrop.itemName then reject(); return end
        local first, second = math.min(srcDropId, dstDropId), math.max(srcDropId, dstDropId)
        if not lockDrop(first) or not lockDrop(second) then reject(); return end
        local def = Items.Get(sourceDrop.itemName)
        local maxStack = tonumber(def and def.maxStack) or 1
        if not MergeMetadataEqual(sourceDrop.metadata, targetDrop.metadata) then reject(); return end
        local sourceCount, targetCount = tonumber(sourceDrop.count) or 0, tonumber(targetDrop.count) or 0
        local amount = math.min(mergeCount, math.min(sourceCount, maxStack - targetCount))
        if amount < 1 then reject(); return end
        local changed = MySQL.update.await("UPDATE thehunt_drops SET count = count + ? WHERE id = ? AND count = ? AND count + ? <= ?", {
            amount, dstDropId, targetCount, amount, maxStack
        })
        if tonumber(changed) ~= 1 then reject(); return end
        if not MergeConsumeDrop(srcDropId, sourceDrop, amount) then
            MergeRollbackDrop(dstDropId, targetDrop, targetCount, targetCount + amount)
            reject()
            return
        end
        targetDrop.count = targetCount + amount
        TriggerClientEvent("thehunt_items:onDropUpdated", -1, dstDropId, targetDrop.count)
        finish()
        return
    end

    -- Inventory -> ground.
    if srcDbId and dstDropId then
        local targetDrop = ActiveDrops[dstDropId]
        if not targetDrop or not MergeDropNearPlayer(src, targetDrop) or not lockDrop(dstDropId) then reject(); return end
        local sourceRows = MySQL.query.await("SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            srcDbId, steamId, charId
        }) or {}
        local sourceItem = sourceRows[1]
        if not sourceItem or not IsInventoryStorageAccessible(steamId, charId, sourceItem.container)
            or sourceItem.item_name ~= targetDrop.itemName
            or not MergeMetadataEqual(sourceItem.metadata, targetDrop.metadata) then reject(); return end
        local def = Items.Get(sourceItem.item_name)
        local maxStack = tonumber(def and def.maxStack) or 1
        local sourceCount, targetCount = tonumber(sourceItem.count) or 0, tonumber(targetDrop.count) or 0
        local amount = math.min(mergeCount, math.min(sourceCount, maxStack - targetCount))
        if amount < 1 then reject(); return end
        local changed = MySQL.update.await("UPDATE thehunt_drops SET count = count + ? WHERE id = ? AND count = ? AND count + ? <= ?", {
            amount, dstDropId, targetCount, amount, maxStack
        })
        if tonumber(changed) ~= 1 then reject(); return end
        local sourceChanged
        if sourceCount <= amount then
            sourceChanged = MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ?", {
                srcDbId, steamId, charId, sourceCount
            })
        else
            sourceChanged = MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ?", {
                amount, srcDbId, steamId, charId, sourceCount
            })
        end
        if tonumber(sourceChanged) ~= 1 then
            MergeRollbackDrop(dstDropId, targetDrop, targetCount, targetCount + amount)
            reject()
            return
        end
        targetDrop.count = targetCount + amount
        TriggerClientEvent("thehunt_items:onDropUpdated", -1, dstDropId, targetDrop.count)
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Ground -> inventory. Both inventory ids are checked against this
    -- player's owner/character before any count is changed.
    if srcDropId and dstDbId then
        local sourceDrop = ActiveDrops[srcDropId]
        if not sourceDrop or not MergeDropNearPlayer(src, sourceDrop) or not lockDrop(srcDropId) then reject(); return end
        local targetRows = MySQL.query.await("SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            dstDbId, steamId, charId
        }) or {}
        local targetItem = targetRows[1]
        if not targetItem or not IsInventoryStorageAccessible(steamId, charId, targetItem.container)
            or targetItem.item_name ~= sourceDrop.itemName
            or not MergeMetadataEqual(sourceDrop.metadata, targetItem.metadata) then reject(); return end
        local def = Items.Get(targetItem.item_name)
        local maxStack = tonumber(def and def.maxStack) or 1
        local sourceCount, targetCount = tonumber(sourceDrop.count) or 0, tonumber(targetItem.count) or 0
        local amount = math.min(mergeCount, math.min(sourceCount, maxStack - targetCount))
        if amount < 1 then reject(); return end

        local itemWeight = tonumber(def and def.weight) or 0.1
        local addedWeight = itemWeight * amount
        local curWeight = GetPlayerTotalCarriedWeight(steamId, charId)
        if curWeight + addedWeight > HARD_WEIGHT_CAP + 0.001 then
            reject(string.format("Слишком тяжело! Предел веса %.1f кг превышен.", HARD_WEIGHT_CAP))
            return
        end

        local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ? AND count + ? <= ?", {
            amount, dstDbId, steamId, charId, targetCount, amount, maxStack
        })
        if tonumber(changed) ~= 1 then reject(); return end
        if not MergeConsumeDrop(srcDropId, sourceDrop, amount) then
            MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ?", {
                amount, dstDbId, steamId, charId, targetCount + amount
            })
            reject()
            return
        end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Inventory -> inventory.
    if srcDbId and dstDbId then
        local rows = MySQL.query.await("SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE id IN (?, ?) AND identifier = ? AND charidentifier = ?", {
            srcDbId, dstDbId, steamId, charId
        }) or {}
        local sourceItem, targetItem
        for _, row in ipairs(rows) do
            if tonumber(row.id) == srcDbId then sourceItem = row end
            if tonumber(row.id) == dstDbId then targetItem = row end
        end
        if not sourceItem or not targetItem
            or not IsInventoryStorageAccessible(steamId, charId, sourceItem.container)
            or not IsInventoryStorageAccessible(steamId, charId, targetItem.container)
            or sourceItem.item_name ~= targetItem.item_name
            or not MergeMetadataEqual(sourceItem.metadata, targetItem.metadata) then reject(); return end
        local def = Items.Get(sourceItem.item_name)
        local maxStack = tonumber(def and def.maxStack) or 1
        local sourceCount, targetCount = tonumber(sourceItem.count) or 0, tonumber(targetItem.count) or 0
        local amount = math.min(mergeCount, math.min(sourceCount, maxStack - targetCount))
        if amount < 1 then reject(); return end
        local targetChanged = MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ? AND count + ? <= ?", {
            amount, dstDbId, steamId, charId, targetCount, amount, maxStack
        })
        if tonumber(targetChanged) ~= 1 then reject(); return end
        local sourceChanged
        if sourceCount <= amount then
            sourceChanged = MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ?", {
                srcDbId, steamId, charId, sourceCount
            })
        else
            sourceChanged = MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ?", {
                amount, srcDbId, steamId, charId, sourceCount
            })
        end
        if tonumber(sourceChanged) ~= 1 then
            MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ?", {
                amount, dstDbId, steamId, charId, targetCount + amount
            })
            reject()
            return
        end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    reject()
end

local function RunNextMerge(src)
    local state = MergeQueues[src]
    if not state or state.running then return end
    local data = table.remove(state.items, 1)
    if not data then MergeQueues[src] = nil; return end
    state.running = true
    local ok, err = pcall(ProcessMerge, src, data, function()
        state.running = false
        RunNextMerge(src)
    end)
    if not ok then
        print(("^1[HUNT ITEMS] merge failed for %s: %s^7"):format(tostring(src), tostring(err)))
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        state.running = false
        RunNextMerge(src)
    end
end

RegisterNetEvent("thehunt_items:mergeItems", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local state = MergeQueues[src]
    if not state then
        state = { items = {}, running = false }
        MergeQueues[src] = state
    end
    state.items[#state.items + 1] = data
    RunNextMerge(src)
end)

RegisterNetEvent("thehunt_items:splitItem", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not data then return end

    local splitCount = tonumber(data.count) or 1
    local srcDbId = data.sourceDbId and tonumber(data.sourceDbId) or nil
    local srcDropId = data.sourceDropId and tonumber(data.sourceDropId) or nil
    local targetContainer = data.targetContainer or "main"
    local targetX = tonumber(data.targetX) or 0
    local targetY = tonumber(data.targetY) or 0
    local isRotated = (data.isRotated == true or data.isRotated == 1 or tonumber(data.isRotated) == 1) and 1 or 0
    local isGroundTarget = (targetContainer == "ground" or data.isGround == true or data.isGroundSplit == true)

    -- 1. Разделение предмета с земли (Земля -> Земля или Земля -> Инвентарь)
    if srcDropId then
        if not isGroundTarget and not IsInventoryStorageAccessible(steamId, charId, targetContainer) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end
        local srcDrop = ActiveDrops[srcDropId]
        if srcDrop then
            local curCount = tonumber(srcDrop.count) or 1
            if curCount > 1 and splitCount >= 1 and splitCount < curCount then
                srcDrop.count = curCount - splitCount
                MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { srcDrop.count, srcDropId })
                TriggerClientEvent("thehunt_items:onDropUpdated", -1, srcDropId, srcDrop.count)

                if isGroundTarget then
                    -- Разделение на земле в новую стопку
                    local splitAngle = math.random() * 2.0 * math.pi
                    local splitDist = 0.15 + (math.random() * 0.20)
                    local splitX = srcDrop.x + (math.cos(splitAngle) * splitDist)
                    local splitY = srcDrop.y + (math.sin(splitAngle) * splitDist)
                    MySQL.insert("INSERT INTO thehunt_drops (item_name, count, metadata, x, y, z, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
                        srcDrop.itemName, splitCount, srcDrop.metadata and json.encode(srcDrop.metadata) or nil, splitX, splitY, srcDrop.z, steamId
                    }, function(newId)
                        local dId = tonumber(newId) or math.random(10000, 99999)
                        local newDrop = {
                            id = dId,
                            itemName = srcDrop.itemName,
                            label = srcDrop.label,
                            count = splitCount,
                            x = splitX,
                            y = splitY,
                            z = srcDrop.z,
                            metadata = srcDrop.metadata or {},
                            dropTime = os.time()
                        }
                        ActiveDrops[dId] = newDrop
                        TriggerClientEvent("thehunt_items:onDropCreated", -1, newDrop)
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                    end)
                else
                    -- Разделение с земли в инвентарь игрока
                    local itemDef = Items.Get(srcDrop.itemName)
                    local itemWeight = (itemDef and tonumber(itemDef.weight)) or 0.1
                    local addedWeight = itemWeight * splitCount
                    local curWeight = GetPlayerTotalCarriedWeight(steamId, charId)
                    if curWeight + addedWeight > HARD_WEIGHT_CAP + 0.001 then
                        TriggerClientEvent("thehunt_status:notify", src, "Слишком тяжело", string.format("Вы не можете нести больше %.1f кг!", HARD_WEIGHT_CAP), "error")
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        return
                    end

                    MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                        steamId, charId, targetContainer, targetX, targetY, isRotated, srcDrop.itemName, splitCount, srcDrop.metadata and json.encode(srcDrop.metadata) or nil
                    }, function()
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                    end)
                end
            end
        end
        return
    end

    -- 2. Разделение предмета из инвентаря игрока (Инвентарь -> Инвентарь или Инвентарь -> Земля)
    if srcDbId then
        if isGroundTarget then
            -- Инвентарь -> Земля (Shift + Drag на землю)
            MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
                srcDbId, steamId, charId
            }, function(rows)
                if rows and #rows > 0 then
                    local sourceItem = rows[1]
                    if not IsInventoryStorageAccessible(steamId, charId, sourceItem.container) then
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        return
                    end
                    local curCount = tonumber(sourceItem.count) or 1
                    if curCount > 1 and splitCount >= 1 and splitCount <= curCount then
                        if curCount == splitCount then
                            MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { srcDbId })
                        else
                            MySQL.update("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { splitCount, srcDbId })
                        end

                        local ped = GetPlayerPed(src)
                        local pedCoords = GetEntityCoords(ped)
                        local heading = GetEntityHeading(ped) or 0.0
                        local rad = math.rad(heading)
                        local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
                        local right = vector3(math.cos(rad), math.sin(rad), 0.0)
                        local forwardDist = 0.40 + (math.random() * 0.30)
                        local sideDist = (math.random() - 0.5) * 0.45
                        local dropPos = pedCoords + (forward * forwardDist) + (right * sideDist) - vector3(0.0, 0.0, 0.85)

                        MySQL.insert("INSERT INTO thehunt_drops (item_name, count, x, y, z, metadata, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
                            sourceItem.item_name, splitCount, dropPos.x, dropPos.y, dropPos.z, sourceItem.metadata, steamId
                        }, function(newId)
                            local dId = tonumber(newId) or math.random(10000, 99999)
                            local itemDef = Items.Get(sourceItem.item_name)
                            local newDrop = {
                                id = dId,
                                itemName = sourceItem.item_name,
                                label = itemDef and itemDef.label or sourceItem.item_name,
                                count = splitCount,
                                x = dropPos.x,
                                y = dropPos.y,
                                z = dropPos.z,
                                metadata = SafeDecodeMeta(sourceItem.metadata),
                                dropTime = os.time()
                            }
                            ActiveDrops[dId] = newDrop
                            TriggerClientEvent("thehunt_items:onDropCreated", -1, newDrop)
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                        end)
                    end
                end
            end)
            return
        end

        -- Инвентарь -> Инвентарь
        if not IsInventoryStorageAccessible(steamId, charId, targetContainer) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end
        MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
            steamId, charId, targetContainer
        }, function(rows)
            rows = rows or {}
            local sourceItem = nil
            for _, r in ipairs(rows) do
                if r.id == srcDbId then
                    sourceItem = r
                    break
                end
            end

            if sourceItem then
                local curCount = tonumber(sourceItem.count) or 1
                if curCount > 1 and splitCount >= 1 and splitCount < curCount then
                    local itemDef = Items.Get(sourceItem.item_name)
                    local origW = itemDef and itemDef.width or 1
                    local origH = itemDef and itemDef.height or 1
                    local effW = (isRotated == 1) and origH or origW
                    local effH = (isRotated == 1) and origW or origH

                    local isSlotOccupied = false
                    for _, r in ipairs(rows) do
                        local rW = itemDef and itemDef.width or 1
                        local rH = itemDef and itemDef.height or 1
                        local rRot = IsRotatedValue(r.is_rotated)
                        local rEffW = rRot and rH or rW
                        local rEffH = rRot and rW or rH

                        local rX = tonumber(r.slot_x) or 0
                        local rY = tonumber(r.slot_y) or 0

                        local overlap = not (targetX + effW <= rX or targetX >= rX + rEffW or targetY + effH <= rY or targetY >= rY + rEffH)
                        if overlap then
                            isSlotOccupied = true
                            break
                        end
                    end

                    local finalX = targetX
                    local finalY = targetY
                    local finalRot = isRotated

                    if isSlotOccupied then
                        local freeX, freeY, freeRot = FindFreeInventorySlot(rows, nil, nil, origW, origH)
                        if freeX then
                            finalX = freeX
                            finalY = freeY
                            finalRot = freeRot and 1 or 0
                        else
                            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Нет свободного места для разделения стака")
                            return
                        end
                    end

                    MySQL.update("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", {
                        splitCount, srcDbId
                    }, function()
                        MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                            steamId,
                            charId,
                            targetContainer,
                            finalX,
                            finalY,
                            finalRot,
                            sourceItem.item_name,
                            splitCount,
                            sourceItem.metadata
                        }, function()
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                        end)
                    end)
                end
            end
        end)
    end
end)

-- =================================================================
-- УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДОБАВЛЕНИЯ ПРЕДМЕТА:
-- 1. СНАЧАЛА ЗАПОЛНЯЕМ ВСЕ НЕПОЛНЫЕ СТАКИ ТОГО ЖЕ ПРЕДМЕТА
-- 2. ОСТАТОК (ИЛИ НОВЫЙ ПРЕДМЕТ) РАЗМЕЩАЕМ В СВОБОДНЫЕ ЯЧЕЙКИ СЕТКИ
-- =================================================================
local function AddOrStackItemToInventory(steamId, charId, itemName, count, metadata, cb)
    local itemDef = Items.Get(itemName)
    if not itemDef then
        if cb then cb(false, 0, 0) end
        return
    end

    local addCount = tonumber(count) or 1
    if addCount <= 0 then
        if cb then cb(true, 0, 0) end
        return
    end

    Citizen.CreateThread(function()
        local itemWeight = tonumber(itemDef.weight) or 0.1
        local curCarriedWeight = GetPlayerTotalCarriedWeight(steamId, charId)
        if curCarriedWeight >= HARD_WEIGHT_CAP then
            if cb then cb(false, 0, addCount) end
            return
        end
        local spaceWeight = (HARD_WEIGHT_CAP - curCarriedWeight)
        local maxAllowedToAdd = math.floor((spaceWeight + 0.001) / itemWeight)
        if maxAllowedToAdd <= 0 then
            if cb then cb(false, 0, addCount) end
            return
        end
        if addCount > maxAllowedToAdd then
            addCount = maxAllowedToAdd
        end

        local maxStack = itemDef.maxStack or 1
        local metaObj = CleanItemMetadata(metadata)
        local hasUniqueMeta = next(metaObj) ~= nil
        local metaJson = hasUniqueMeta and json.encode(metaObj) or nil

        local allRows = MySQL.query.await("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
            steamId, charId
        }) or {}

        local itemsByDbId = {}
        for _, row in ipairs(allRows) do
            itemsByDbId[tonumber(row.id)] = row
        end

        -- Automatic additions use every storage area that belongs to the
        -- character: the main grid first, then pockets on equipped clothing,
        -- then carried portable containers (like keyrings for keys, or bags).
        -- Only currently equipped garments can contribute space; stale or
        -- packed clothing:<id> rows are never treated as available inventory.
        local destinations = {
            {
                container = "main",
                items = {},
                cols = Items.GetGridCols("main"),
                rows = Items.GetGridRows("main")
            }
        }
        local rowsByContainer = {}
        local equippedStorage = {}

        for _, row in ipairs(allRows) do
            local rowContainer = tostring(row.container or "main")
            rowsByContainer[rowContainer] = rowsByContainer[rowContainer] or {}
            table.insert(rowsByContainer[rowContainer], row)

            if rowContainer == "equipment" then
                local equippedDef = Items.Get(row.item_name)
                if IsClothing(equippedDef) and equippedDef.storage then
                    table.insert(equippedStorage, {
                        id = tonumber(row.id),
                        slot = tonumber(row.slot_x) or 999,
                        definition = equippedDef,
                        storage = equippedDef.storage
                    })
                end
            end
        end
        destinations[1].items = rowsByContainer.main or {}

        -- Clothing cannot be put inside another garment, matching the manual
        -- drag/drop validation. Normal items and portable containers may use
        -- the pockets in the same stable equipment order shown by the NUI.
        if not IsClothing(itemDef) or Items.CanPackClothing(itemDef, { clothingSlot = 'Satchels' }, metaObj, false) then
            table.sort(equippedStorage, function(a, b)
                if a.slot == b.slot then return (a.id or 0) < (b.id or 0) end
                return a.slot < b.slot
            end)
            for _, equipped in ipairs(equippedStorage) do
                if equipped.id and Items.CanPackClothing(itemDef, equipped.definition, metaObj, false) then
                    local containerName = ClothingContainer(equipped.id)
                    table.insert(destinations, {
                        container = containerName,
                        items = rowsByContainer[containerName] or {},
                        storage = equipped.storage
                    })
                end
            end

            -- Portable containers carried by the player (e.g. keyrings, bags)
            if not IsItemContainer(itemDef) then
                for _, row in ipairs(allRows) do
                    local cDef = Items.Get(row.item_name)
                    if cDef and cDef.containerStorage and tonumber(row.id) then
                        local parentContainer = tostring(row.container or "main")
                        if IsCarriedContainer(parentContainer, itemsByDbId) then
                            local keyOnly = (cDef.containerStorage.keyOnly == true)
                            if (not keyOnly or IsKeyItem(itemDef, itemName)) and Items.CanPackClothing(itemDef, cDef, metaObj, false) then
                                local cName = ItemContainer(row.id)
                                table.insert(destinations, {
                                    container = cName,
                                    items = rowsByContainer[cName] or {},
                                    cols = tonumber(cDef.containerStorage.cols) or 2,
                                    rows = tonumber(cDef.containerStorage.rows) or 3
                                })
                            end
                        end
                    end
                end
            end
        end

        local remainingToAdd = addCount

        -- 1. Сначала проверяем существующие неполные стаки (если maxStack > 1 и мета совпадает)
        if maxStack > 1 and not IsItemContainer(itemDef) and not IsClothing(itemDef) then
            for _, destination in ipairs(destinations) do
                for _, row in ipairs(destination.items) do
                    if remainingToAdd <= 0 then break end
                    if row.item_name == itemName then
                        local rowMeta = CleanItemMetadata(row.metadata)
                        local rowHasMeta = next(rowMeta) ~= nil
                        local isMetaMatch = false
                        if not hasUniqueMeta and not rowHasMeta then
                            isMetaMatch = true
                        elseif hasUniqueMeta and rowHasMeta then
                            isMetaMatch = (json.encode(rowMeta) == metaJson)
                        end

                        if isMetaMatch then
                            local curCount = tonumber(row.count) or 1
                            local spaceLeft = maxStack - curCount
                            if spaceLeft > 0 then
                                local takeAmount = math.min(remainingToAdd, spaceLeft)
                                row.count = curCount + takeAmount
                                remainingToAdd = remainingToAdd - takeAmount
                                MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ?", {
                                    takeAmount, row.id
                                })
                            end
                        end
                    end
                end
                if remainingToAdd <= 0 then break end
            end
        end

        if remainingToAdd <= 0 then
            if cb then cb(true, addCount, 0) end
            return
        end

        -- 2. Для остатка последовательно ищем свободные слоты в сетке
        local itemW = itemDef.width or 1
        local itemH = itemDef.height or 1

        while remainingToAdd > 0 do
            local selectedDestination, freeX, freeY, isRot
            for _, destination in ipairs(destinations) do
                if destination.storage then
                    local occupied = {}
                    for _, row in ipairs(destination.items) do
                        local rowDef = Items.Get(row.item_name)
                        if rowDef then
                            local rowRotated = IsRotatedValue(row.is_rotated)
                            local rowWidth = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                            local rowHeight = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                            MarkStorageArea(occupied, tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0, rowWidth, rowHeight)
                        end
                    end
                    freeX, freeY, isRot = FindFreeClothingSlot(destination.storage, occupied, itemW, itemH, false)
                else
                    freeX, freeY, isRot = FindFreeInventorySlot(destination.items, destination.cols, destination.rows, itemW, itemH)
                end
                if freeX ~= nil then
                    selectedDestination = destination
                    break
                end
            end

            if freeX == nil then
                local addedSoFar = addCount - remainingToAdd
                if cb then cb(addedSoFar > 0, addedSoFar, remainingToAdd) end
                return
            end

            local thisSlotCount = math.min(remainingToAdd, maxStack)
            remainingToAdd = remainingToAdd - thisSlotCount

            local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                steamId, charId, selectedDestination.container, freeX, freeY, isRot and 1 or 0, itemName, thisSlotCount, metaJson
            })

            if insertId then
                if IsClothing(itemDef) then RestoreClothingContents(steamId, charId, insertId, metaObj) end
                if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, metaObj) end
                table.insert(selectedDestination.items, {
                    id = insertId,
                    container = selectedDestination.container,
                    item_name = itemName,
                    slot_x = freeX,
                    slot_y = freeY,
                    is_rotated = isRot and 1 or 0,
                    count = thisSlotCount,
                    metadata = metaJson
                })
            else
                local addedSoFar = addCount - remainingToAdd - thisSlotCount
                if cb then cb(addedSoFar > 0, addedSoFar, remainingToAdd + thisSlotCount) end
                return
            end
        end

        if cb then cb(true, addCount, 0) end
    end)
end

exports('GiveItem', function(source, itemName, count, metadata, cb)
    local src = tonumber(source)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    AddOrStackItemToInventory(steamId, charId, itemName, count, metadata, function(success, addedCount, remaining)
        if success then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end
        if cb then
            cb(success, addedCount, remaining)
        end
    end)
end)

exports('AddItem', function(source, itemName, count, metadata, cb)
    local src = tonumber(source)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    AddOrStackItemToInventory(steamId, charId, itemName, count, metadata, function(success, addedCount, remaining)
        if success then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end
        if cb then
            cb(success, addedCount, remaining)
        end
    end)
end)

exports('AddOrStackItem', AddOrStackItemToInventory)

exports('AddItemToSlot', function(source, itemName, count, metadata, targetContainer, targetX, targetY, isRotated, cb)
    local src = tonumber(source)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or not charId then
        if cb then cb(false, 0, count) end
        return
    end

    local itemDef = Items.Get(itemName)
    if not itemDef then
        if cb then cb(false, 0, count) end
        return
    end

    local addCount = tonumber(count) or 1
    if addCount < 1 then
        if cb then cb(false, 0, 0) end
        return
    end

    local dropMeta = CleanItemMetadata(metadata)
    local metaJson = next(dropMeta) and json.encode(dropMeta) or nil
    local targetXNum = tonumber(targetX)
    local targetYNum = tonumber(targetY)
    local targetHasCoords = targetXNum and targetYNum and targetXNum == targetXNum and targetYNum == targetYNum
        and math.abs(targetXNum) < 1000000 and math.abs(targetYNum) < 1000000
        and targetXNum == math.floor(targetXNum) and targetYNum == math.floor(targetYNum)
    local rotation = IsRotatedValue(isRotated)

    -- Проверка перегруза
    local itemWeight = tonumber(itemDef.weight) or 0.1
    local totalAddWeight = itemWeight * addCount
    local curCarriedWeight = GetPlayerTotalCarriedWeight(steamId, charId)
    if curCarriedWeight + totalAddWeight > HARD_WEIGHT_CAP + 0.001 then
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Слишком тяжело! Предел веса %.1f кг превышен.", HARD_WEIGHT_CAP), "error")
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        if cb then cb(false, 0, addCount) end
        return
    end

    -- 1. Слот экипировки
    if targetContainer == "equipment" and targetHasCoords then
        local expectedX = EquipmentSlotIndex(itemDef.clothingSlot)
        local itemGender = dropMeta.gender or dropMeta.sex
        if itemGender and CanonicalGender(itemGender) ~= GetCharacterGender(src) then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Эта одежда предназначена для другого пола", "error")
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            if cb then cb(false, 0, addCount) end
            return
        end
        if IsClothing(itemDef) and expectedX ~= nil and targetXNum == expectedX and targetYNum == 0 then
            local occupied = MySQL.query.await("SELECT id FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'equipment' AND slot_x = ? LIMIT 1", {
                steamId, charId, expectedX
            }) or {}
            if not occupied[1] then
                if not itemGender then
                    dropMeta.gender = GetCharacterGender(src)
                    metaJson = json.encode(dropMeta)
                end
                local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'equipment', ?, 0, 0, ?, 1, ?)", {
                    steamId, charId, expectedX, itemName, metaJson
                })
                if insertId then
                    RestoreClothingContents(steamId, charId, insertId, dropMeta)
                    if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
                    SyncEquippedClothing(src, itemDef, dropMeta, true)
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    if cb then cb(true, 1, 0) end
                    return
                end
            end
        end
    end

    -- 2. Карманы одежды
    if type(targetContainer) == "string" and string.sub(targetContainer, 1, 9) == "clothing:" and targetHasCoords then
        local parentId = tonumber(string.sub(targetContainer, 10))
        local parentRows = parentId and MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", {
            parentId, steamId, charId
        }) or {}
        local parentDef = parentRows[1] and Items.Get(parentRows[1].item_name)
        if parentDef and IsClothing(parentDef) and parentDef.storage and CanPackGarment(src, itemDef, parentDef, dropMeta) then
            local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
            local width = rotation and rawH or rawW
            local height = rotation and rawW or rawH
            local existing = MySQL.query.await("SELECT id, item_name, count, metadata, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
                steamId, charId, targetContainer
            }) or {}

            -- Проверка слияния со стаком в кармане
            local targetItem = nil
            for _, row in ipairs(existing) do
                local rowDef = Items.Get(row.item_name)
                if rowDef then
                    local rowRotated = IsRotatedValue(row.is_rotated)
                    local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                    local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                    local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                    if targetXNum >= rowX and targetXNum < rowX + rowW and targetYNum >= rowY and targetYNum < rowY + rowH then
                        targetItem = row
                        break
                    end
                end
            end

            if targetItem then
                local targetMeta = CleanItemMetadata(targetItem.metadata)
                local sameMeta = (not next(dropMeta) and not next(targetMeta))
                    or (next(dropMeta) and next(targetMeta) and json.encode(dropMeta) == json.encode(targetMeta))
                local targetCount = tonumber(targetItem.count) or 0
                local maxStack = tonumber(itemDef.maxStack) or 1
                if targetItem.item_name == itemName and maxStack > 1 and sameMeta and targetCount < maxStack then
                    local mergeAmount = math.min(addCount, maxStack - targetCount)
                    local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ? AND count + ? <= ?", {
                        mergeAmount, targetItem.id, steamId, charId, targetCount, mergeAmount, maxStack
                    })
                    if tonumber(changed) == 1 then
                        local rem = addCount - mergeAmount
                        if rem > 0 then
                            AddOrStackItemToInventory(steamId, charId, itemName, rem, dropMeta, function(s, ac, r)
                                TriggerClientEvent("thehunt_items:refreshInventory", src)
                                if cb then cb(true, mergeAmount + (ac or 0), r or 0) end
                            end)
                        else
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                            if cb then cb(true, mergeAmount, 0) end
                        end
                        return
                    end
                end
            elseif addCount <= (tonumber(itemDef.maxStack) or 1) and StorageAreaFits(parentDef.storage, targetXNum, targetYNum, width, height) then
                local overlaps = false
                for _, row in ipairs(existing) do
                    local rowDef = Items.Get(row.item_name)
                    if rowDef then
                        local rowRotated = IsRotatedValue(row.is_rotated)
                        local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                        local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                        local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                        if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                            overlaps = true
                            break
                        end
                    end
                end
                if not overlaps then
                    local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                        steamId, charId, targetContainer, targetXNum, targetYNum, rotation and 1 or 0, itemName, addCount, metaJson
                    })
                    if insertId then
                        if IsClothing(itemDef) then RestoreClothingContents(steamId, charId, insertId, dropMeta) end
                        if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        if cb then cb(true, addCount, 0) end
                        return
                    end
                end
            end
        end
    end

    -- 3. Сетка контейнера
    if type(targetContainer) == "string" and string.sub(targetContainer, 1, 10) == "container:" and targetHasCoords then
        if IsInventoryStorageAccessible(steamId, charId, targetContainer) then
            local parentId = tonumber(string.sub(targetContainer, 11))
            if parentId and not IsItemContainer(itemDef) then
                local parentRows = MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
                    parentId, steamId, charId
                }) or {}
                local parentDef = parentRows[1] and Items.Get(parentRows[1].item_name)
                if parentDef and parentDef.containerStorage and CanPackGarment(src, itemDef, parentDef, dropMeta) then
                    local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
                    local width = rotation and rawH or rawW
                    local height = rotation and rawW or rawH
                    local cols = tonumber(parentDef.containerStorage.cols) or 2
                    local rowsCount = tonumber(parentDef.containerStorage.rows) or 3
                    local existing = MySQL.query.await("SELECT id, item_name, count, metadata, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
                        steamId, charId, targetContainer
                    }) or {}

                    -- Проверка слияния со стаком в контейнере
                    local targetItem = nil
                    for _, row in ipairs(existing) do
                        local rowDef = Items.Get(row.item_name)
                        if rowDef then
                            local rowRotated = IsRotatedValue(row.is_rotated)
                            local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                            local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                            local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                            if targetXNum >= rowX and targetXNum < rowX + rowW and targetYNum >= rowY and targetYNum < rowY + rowH then
                                targetItem = row
                                break
                            end
                        end
                    end

                    if targetItem then
                        local targetMeta = CleanItemMetadata(targetItem.metadata)
                        local sameMeta = (not next(dropMeta) and not next(targetMeta))
                            or (next(dropMeta) and next(targetMeta) and json.encode(dropMeta) == json.encode(targetMeta))
                        local targetCount = tonumber(targetItem.count) or 0
                        local maxStack = tonumber(itemDef.maxStack) or 1
                        if targetItem.item_name == itemName and maxStack > 1 and sameMeta and targetCount < maxStack then
                            local mergeAmount = math.min(addCount, maxStack - targetCount)
                            local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ? AND count + ? <= ?", {
                                mergeAmount, targetItem.id, steamId, charId, targetCount, mergeAmount, maxStack
                            })
                            if tonumber(changed) == 1 then
                                local rem = addCount - mergeAmount
                                if rem > 0 then
                                    AddOrStackItemToInventory(steamId, charId, itemName, rem, dropMeta, function(s, ac, r)
                                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                                        if cb then cb(true, mergeAmount + (ac or 0), r or 0) end
                                    end)
                                else
                                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                                    if cb then cb(true, mergeAmount, 0) end
                                end
                                return
                            end
                        end
                    elseif addCount <= (tonumber(itemDef.maxStack) or 1) and targetXNum >= 0 and targetYNum >= 0 and targetXNum + width <= cols and targetYNum + height <= rowsCount then
                        local overlaps = false
                        for _, row in ipairs(existing) do
                            local rowDef = Items.Get(row.item_name)
                            if rowDef then
                                local rowRotated = IsRotatedValue(row.is_rotated)
                                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                                if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                                    overlaps = true
                                    break
                                end
                            end
                        end
                        if not overlaps then
                            local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                                steamId, charId, targetContainer, targetXNum, targetYNum, rotation and 1 or 0, itemName, addCount, metaJson
                            })
                            if insertId then
                                TriggerClientEvent("thehunt_items:refreshInventory", src)
                                if cb then cb(true, addCount, 0) end
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- 4. Основная сетка инвентаря
    if (targetContainer == "main" or not targetContainer) and targetHasCoords then
        local mainRows = MySQL.query.await("SELECT id, item_name, count, metadata, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
            steamId, charId
        }) or {}

        -- Проверка слияния со стаком
        local targetItem = nil
        for _, row in ipairs(mainRows) do
            local rowDef = Items.Get(row.item_name)
            if rowDef then
                local rowRotated = IsRotatedValue(row.is_rotated)
                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                if targetXNum >= rowX and targetXNum < rowX + rowW and targetYNum >= rowY and targetYNum < rowY + rowH then
                    targetItem = row
                    break
                end
            end
        end

        if targetItem then
            local targetMeta = CleanItemMetadata(targetItem.metadata)
            local sameMeta = (not next(dropMeta) and not next(targetMeta))
                or (next(dropMeta) and next(targetMeta) and json.encode(dropMeta) == json.encode(targetMeta))
            local targetCount = tonumber(targetItem.count) or 0
            local maxStack = tonumber(itemDef.maxStack) or 1
            if targetItem.item_name == itemName and maxStack > 1 and sameMeta and targetCount < maxStack then
                local mergeAmount = math.min(addCount, maxStack - targetCount)
                local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ? AND count + ? <= ?", {
                    mergeAmount, targetItem.id, steamId, charId, targetCount, mergeAmount, maxStack
                })
                if tonumber(changed) == 1 then
                    local rem = addCount - mergeAmount
                    if rem > 0 then
                        AddOrStackItemToInventory(steamId, charId, itemName, rem, dropMeta, function(s, ac, r)
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                            if cb then cb(true, mergeAmount + (ac or 0), r or 0) end
                        end)
                    else
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        if cb then cb(true, mergeAmount, 0) end
                    end
                    return
                end
            end
        else
            -- Пустая ячейка в сетке
            local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
            local width = rotation and rawH or rawW
            local height = rotation and rawW or rawH
            local cols, rowsCount = Items.GetGridCols("main"), Items.GetGridRows("main")
            if addCount <= (tonumber(itemDef.maxStack) or 1) and targetXNum >= 0 and targetYNum >= 0
                and targetXNum + width <= cols and targetYNum + height <= rowsCount then
                local overlaps = false
                for _, row in ipairs(mainRows) do
                    local rowDef = Items.Get(row.item_name)
                    if rowDef then
                        local rowRotated = IsRotatedValue(row.is_rotated)
                        local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                        local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                        local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                        if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW
                            or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                            overlaps = true
                            break
                        end
                    end
                end
                if not overlaps then
                    local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', ?, ?, ?, ?, ?, ?)", {
                        steamId, charId, targetXNum, targetYNum, rotation and 1 or 0, itemName, addCount, metaJson
                    })
                    if insertId then
                        if IsClothing(itemDef) then RestoreClothingContents(steamId, charId, insertId, dropMeta) end
                        if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        if cb then cb(true, addCount, 0) end
                        return
                    end
                end
            end
        end
    end

    -- Фоллбек: автоматическое размещение в первый свободный слот
    AddOrStackItemToInventory(steamId, charId, itemName, addCount, dropMeta, function(success, addedCount, remaining)
        if success then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end
        if cb then cb(success, addedCount, remaining) end
    end)
end)

-- Called exactly once by character creation.  The wardrobe selected in the
-- creator becomes normal equipment items rather than a second appearance
-- system.  The component hash/tint stays with the individual item.
exports('CreateCharacterClothing', function(src, comps, compTints, variantLabels)
    local identifier, charId = GetPlayerIdentifiersVORP(src)
    if not identifier or not charId or type(comps) ~= "table" then return false end
    local characterGender = GetCharacterGender(src)
    for category, value in pairs(comps) do
        local component = type(value) == "table" and (value.comp or value.hash) or value
        local itemName = "clothing_" .. string.lower(tostring(category))
        local def, slotIndex = Items.Get(itemName), EquipmentSlotIndex(category)
        if def and slotIndex ~= nil and tonumber(component) and tonumber(component) ~= -1 and tonumber(component) ~= 0 then
            local variant = type(variantLabels) == "table" and variantLabels[category] or "Вариант"
            local metadata = { component = tonumber(component), category = category, gender = characterGender, tint = type(compTints) == "table" and compTints[category] or nil, label = def.label .. " — " .. tostring(variant) }
            MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'equipment', ?, 0, 0, ?, 1, ?)", {
                identifier, charId, slotIndex, itemName, json.encode(metadata)
            })
        end
    end
    return true
end)

-- 3. Выбрасывание предмета на землю (Drop to World)
RegisterNetEvent("thehunt_items:_legacyDropItem", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not data or not data.name then return end

    local itemName = data.name
    if IsRemovedClothingItem(itemName) then return end
    local dropCount = tonumber(data.count) or 1
    local dbId = data.dbId and tonumber(data.dbId) or nil
    local itemDef = Items.Get(itemName) or { label = itemName }

    local dropPos = nil
    if data.coords and data.coords.x and data.coords.y and data.coords.z then
        dropPos = vector3(tonumber(data.coords.x), tonumber(data.coords.y), tonumber(data.coords.z))
    else
        local ped = GetPlayerPed(src)
        local pedCoords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped) or 0.0
        local rad = math.rad(heading)
        local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local right = vector3(math.cos(rad), math.sin(rad), 0.0)
        local forwardDist = 0.40 + (math.random() * 0.30)
        local sideDist = (math.random() - 0.5) * 0.45
        dropPos = pedCoords + (forward * forwardDist) + (right * sideDist) - vector3(0.0, 0.0, 0.85)
    end

    -- Удаляем/уменьшаем из инвентаря игрока и считываем точные метаданные из строки БД
    if dbId then
        MySQL.query("SELECT id, count, metadata, item_name, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            dbId,
            steamId,
            charId
        }, function(res)
            if res and res[1] then
                if not IsInventoryStorageAccessible(steamId, charId, res[1].container) then
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end
                local currentCount = tonumber(res[1].count) or 1
                if currentCount <= 0 then
                    -- Clean up rows left by older versions of the handler;
                    -- they are not real inventory items and must not spawn a
                    -- phantom world copy when clicked.
                    MySQL.query.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { dbId, steamId, charId })
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end
                -- The client can be stale while a refresh is in flight. Never
                -- create more items on the ground than the authoritative row.
                dropCount = math.max(1, math.min(dropCount, currentCount))
                local rowMeta = SafeDecodeMeta(res[1].metadata)
                if not next(rowMeta) and data.metadata then
                    rowMeta = SafeDecodeMeta(data.metadata)
                end
                local metaJson = (rowMeta and next(rowMeta)) and json.encode(rowMeta) or nil

                if currentCount <= dropCount then
                    -- A complete drop must remove the source row. Previously
                    -- ordinary items fell through to `count = count - ?`,
                    -- leaving a zero-count source that reappeared on refresh.
                    if IsClothing(itemDef) then
                        -- Keep nested contents with the world item before
                        -- removing its parent row. Awaited calls preserve the
                        -- order inside this server event.
                        local contents = MySQL.query.await("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", { ClothingContainer(dbId) }) or {}
                        rowMeta.clothing_contents = contents
                        metaJson = json.encode(rowMeta)
                        MySQL.query.await("DELETE FROM thehunt_inventories WHERE container = ?", { ClothingContainer(dbId) })
                        if res[1].container == "equipment" then SyncEquippedClothing(src, itemDef, rowMeta, false) end
                    end
                    if IsItemContainer(itemDef) then
                        local contents = MySQL.query.await("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", { ItemContainer(dbId) }) or {}
                        rowMeta.container_contents = contents
                        metaJson = json.encode(rowMeta)
                        MySQL.query.await("DELETE FROM thehunt_inventories WHERE container = ?", { ItemContainer(dbId) })
                    end
                    MySQL.query.await("DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", { dbId, steamId, charId })
                else
                    MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND identifier = ? AND charidentifier = ?", { dropCount, dbId, steamId, charId })
                end

                -- Создаем запись дропа в БД и кэше
                MySQL.insert("INSERT INTO thehunt_drops (item_name, count, x, y, z, metadata, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
                    itemName,
                    dropCount,
                    dropPos.x,
                    dropPos.y,
                    dropPos.z,
                    metaJson,
                    steamId
                }, function(insertId)
                    local dId = tonumber(insertId) or math.random(10000, 99999)
                    local dropData = {
                        id = dId,
                        itemName = itemName,
                        label = (rowMeta and rowMeta.label) or itemDef.label or itemName,
                        count = dropCount,
                        x = dropPos.x,
                        y = dropPos.y,
                        z = dropPos.z,
                        metadata = rowMeta or {},
                        dropTime = os.time()
                    }
                    ActiveDrops[dId] = dropData

                    TriggerClientEvent("thehunt_items:onDropCreated", -1, dropData)
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                end)
            end
        end)
    end
end)

-- 4. Подбор предмета из мира / ячейки "Рядом"
local DropQueues = {}

local function ProcessDropItem(src, data, done)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local function reject()
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        done()
    end

    if type(data) ~= "table" or not data.dbId then reject(); return end
    local dbId = tonumber(data.dbId)
    local requestedCount = tonumber(data.count)
    if not dbId or dbId ~= dbId or not requestedCount or requestedCount ~= requestedCount then reject(); return end
    requestedCount = math.floor(requestedCount)
    if requestedCount < 1 then reject(); return end

    local activePropId = ActivePlayerPlacedContainers[src]
    local rows
    if activePropId then
        rows = MySQL.query.await("SELECT id, item_name, count, metadata, container, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE id = ? AND ((identifier = ? AND charidentifier = ?) OR container = ?)", {
            dbId, steamId, charId, "prop:" .. tostring(activePropId)
        }) or {}
    else
        rows = MySQL.query.await("SELECT id, item_name, count, metadata, container, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            dbId, steamId, charId
        }) or {}
    end
    local row = rows[1]
    if not row then reject(); return end

    if not IsInventoryStorageAccessible(steamId, charId, row.container) then
        reject()
        return
    end

    local itemName = row.item_name
    local itemDef = Items.Get(itemName)
    if not itemDef or IsRemovedClothingItem(itemName) then reject(); return end

    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped) or 0.0
    local rad = math.rad(heading)
    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0)
    local forwardDist = 0.40 + (math.random() * 0.30)
    local sideDist = (math.random() - 0.5) * 0.45
    local fallbackPos = pedCoords + (forward * forwardDist) + (right * sideDist) - vector3(0.0, 0.0, 0.85)
    local dropPos = fallbackPos

    -- Keep the client's raycast surface placement, but never accept a remote
    -- coordinate that could create a world drop anywhere on the map.
    local x = data.coords and tonumber(data.coords.x)
    local y = data.coords and tonumber(data.coords.y)
    local z = data.coords and tonumber(data.coords.z)
    if x and y and z and x == x and y == y and z == z
        and math.abs(x) < 1000000 and math.abs(y) < 1000000 and math.abs(z) < 1000000 then
        local candidate = vector3(x, y, z)
        if #(pedCoords - candidate) <= 6.0 then
            dropPos = candidate
        end
    end

    local currentCount = tonumber(row.count) or 0
    if currentCount < 1 then reject(); return end
    local dropCount = math.min(requestedCount, currentCount)
    local rowMeta = SafeDecodeMeta(row.metadata)
    local metaJson = next(rowMeta) and json.encode(rowMeta) or nil
    local clothingContents = nil
    local containerContents = nil

    if currentCount <= dropCount then
        if IsClothing(itemDef) then
            clothingContents = MySQL.query.await("SELECT id, item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", {
                ClothingContainer(dbId)
            }) or {}
            for _, cEntry in ipairs(clothingContents) do
                local cDef = Items.Get(cEntry.item_name)
                if cDef and IsItemContainer(cDef) then
                    local nested = MySQL.query.await("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", {
                        ItemContainer(cEntry.id)
                    }) or {}
                    local cMeta = SafeDecodeMeta(cEntry.metadata)
                    cMeta.container_contents = nested
                    cEntry.metadata = cMeta
                    MySQL.update.await("DELETE FROM thehunt_inventories WHERE container = ?", { ItemContainer(cEntry.id) })
                end
            end
            rowMeta.clothing_contents = clothingContents
            metaJson = json.encode(rowMeta)
        end
        if IsItemContainer(itemDef) then
            containerContents = MySQL.query.await("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", {
                ItemContainer(dbId)
            }) or {}
            rowMeta.container_contents = containerContents
            metaJson = json.encode(rowMeta)
        end

        local deleted = MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND count = ?", {
            dbId, currentCount
        })
        if tonumber(deleted) ~= 1 then reject(); return end
        if IsClothing(itemDef) then
            MySQL.update.await("DELETE FROM thehunt_inventories WHERE container = ?", { ClothingContainer(dbId) })
            if row.container == "equipment" then SyncEquippedClothing(src, itemDef, rowMeta, false) end
        end
        if IsItemContainer(itemDef) then
            MySQL.update.await("DELETE FROM thehunt_inventories WHERE container = ?", { ItemContainer(dbId) })
        end
    else
        local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ? AND count >= ?", {
            dropCount, dbId, dropCount
        })
        if tonumber(changed) ~= 1 then reject(); return end
    end

    local insertId = MySQL.insert.await("INSERT INTO thehunt_drops (item_name, count, x, y, z, metadata, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
        itemName, dropCount, dropPos.x, dropPos.y, dropPos.z, metaJson, steamId
    })
    if not insertId then
        -- Do not leave a successful inventory debit without a world drop if
        -- the insert fails. Restore the authoritative source row.
        if currentCount <= dropCount then
            local restoredId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                steamId, charId, row.container or "main", tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0,
                IsRotatedValue(row.is_rotated) and 1 or 0, itemName, currentCount, row.metadata
            })
            if restoredId and clothingContents then
                for _, entry in ipairs(clothingContents) do
                    MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                        steamId, charId, ClothingContainer(restoredId), tonumber(entry.slot_x) or 0, tonumber(entry.slot_y) or 0,
                        IsRotatedValue(entry.is_rotated) and 1 or 0, entry.item_name, tonumber(entry.count) or 1, entry.metadata
                    })
                end
            end
            if restoredId and containerContents then
                for _, entry in ipairs(containerContents) do
                    MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                        steamId, charId, ItemContainer(restoredId), tonumber(entry.slot_x) or 0, tonumber(entry.slot_y) or 0,
                        IsRotatedValue(entry.is_rotated) and 1 or 0, entry.item_name, tonumber(entry.count) or 1, entry.metadata
                    })
                end
            end
        else
            MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ?", {
                dropCount, dbId, steamId, charId
            })
        end
        reject()
        return
    end

    local dId = tonumber(insertId)
    local dropData = {
        id = dId,
        itemName = itemName,
        label = (rowMeta and rowMeta.label) or itemDef.label or itemName,
        count = dropCount,
        x = dropPos.x,
        y = dropPos.y,
        z = dropPos.z,
        metadata = rowMeta or {},
        dropTime = os.time()
    }
    ActiveDrops[dId] = dropData
    TriggerClientEvent("thehunt_items:onDropCreated", -1, dropData)

    if string.sub(row.container or "", 1, 5) == "prop:" then
        local propId = tonumber(string.sub(row.container, 6))
        SyncPlacedPropSnapshot(propId)
        RefreshPlacedContainerViewers(propId, src)
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    done()
end

local function RunNextDrop(src)
    local state = DropQueues[src]
    if not state or state.running then return end
    local data = table.remove(state.items, 1)
    if not data then DropQueues[src] = nil; return end

    state.running = true
    local finished = false
    local function done()
        if finished then return end
        finished = true
        state.running = false
        RunNextDrop(src)
    end
    local ok, err = pcall(ProcessDropItem, src, data, done)
    if not ok then
        print(("^1[HUNT ITEMS] drop failed for %s: %s^7"):format(tostring(src), tostring(err)))
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        done()
    end
end

RegisterNetEvent("thehunt_items:dropItem", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local state = DropQueues[src]
    if not state then
        state = { items = {}, running = false }
        DropQueues[src] = state
    end
    state.items[#state.items + 1] = data
    RunNextDrop(src)
end)

RegisterNetEvent("thehunt_items:_legacyPickupDrop", function(dropId, targetContainer, targetX, targetY, isRotated)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local dId = tonumber(dropId)
    if not dId or not ActiveDrops[dId] then return end

    local drop = ActiveDrops[dId]
    if IsRemovedClothingItem(drop.itemName) then return end
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    local dist = #(pedCoords - vector3(drop.x, drop.y, drop.z))

    if dist > 6.0 then
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Предмет слишком далеко")
        return
    end

    local itemDef = Items.Get(drop.itemName)
    local maxStack = itemDef and itemDef.maxStack or 1
    local itemW = itemDef and itemDef.width or 1
    local itemH = itemDef and itemDef.height or 1
    local dropCount = tonumber(drop.count) or 1
    local dropMeta = CleanItemMetadata(drop.metadata)
    local hasUniqueMeta = next(dropMeta) ~= nil
    local metaJson = hasUniqueMeta and json.encode(dropMeta) or nil

    local targetXNum = targetX and tonumber(targetX) or nil
    local targetYNum = targetY and tonumber(targetY) or nil

    -- Allow a garment found on the ground to be equipped directly.
    if targetContainer == 'equipment' and targetXNum and targetYNum then
        local expectedX = itemDef and EquipmentSlotIndex(itemDef.clothingSlot)
        local currentGender = GetCharacterGender(src)
        local itemGender = dropMeta and (dropMeta.gender or dropMeta.sex)
        if itemGender and CanonicalGender(itemGender) ~= currentGender then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Эта одежда предназначена для другого пола", "error")
            return
        end
        if not IsClothing(itemDef) or expectedX == nil or targetXNum ~= expectedX or targetYNum ~= 0 then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end

        if not itemGender then
            dropMeta.gender = currentGender
            metaJson = json.encode(dropMeta)
        end

        MySQL.query("SELECT id FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'equipment' AND slot_x = ? LIMIT 1", {
            steamId, charId, expectedX
        }, function(existing)
            if existing and existing[1] then
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот слот одежды уже занят", "warning")
                return
            end

            ActiveDrops[dId] = nil
            MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
            TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)

            MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'equipment', ?, 0, 0, ?, 1, ?)", {
                steamId, charId, expectedX, drop.itemName, metaJson
            }, function(insertId)
                RestoreClothingContents(steamId, charId, insertId, dropMeta)
                SyncEquippedClothing(src, itemDef, dropMeta, true)
                TriggerClientEvent("thehunt_items:refreshInventory", src)
            end)
        end)
        return
    end

    -- Items from the ground can also be placed directly into the storage grid
    -- of an equipped garment (clothing:<parent inventory id>).
    if type(targetContainer) == 'string' and string.sub(targetContainer, 1, 9) == 'clothing:' and targetXNum and targetYNum then
        local parentId = tonumber(string.sub(targetContainer, 10))
        if not parentId or IsClothing(itemDef) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end

        local rotState = (isRotated == true or isRotated == 1 or tonumber(isRotated) == 1)
        local effW = rotState and itemH or itemW
        local effH = rotState and itemW or itemH
        MySQL.query("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", {
            parentId, steamId, charId
        }, function(parentRows)
            local parentDef = parentRows and parentRows[1] and Items.Get(parentRows[1].item_name)
            local storage = IsClothing(parentDef) and parentDef.storage or nil
            local validBounds = storage and targetXNum >= 0 and targetYNum >= 0
                and targetXNum + effW <= storage.cols and targetYNum + effH <= storage.rows
            if validBounds and storage.rowWidths then
                for row = targetYNum, targetYNum + effH - 1 do
                    local rowWidth = storage.rowWidths[row + 1] or storage.cols
                    if targetXNum + effW > rowWidth then validBounds = false break end
                end
            end
            if not validBounds then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end

            MySQL.query("SELECT id, item_name, count, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
                steamId, charId, targetContainer
            }, function(existing)
                existing = existing or {}
                local overlaps = false
                for _, row in ipairs(existing) do
                    local rowDef = Items.Get(row.item_name)
                    local rowRot = IsRotatedValue(row.is_rotated)
                    local rowW = rowRot and (rowDef and rowDef.height or 1) or (rowDef and rowDef.width or 1)
                    local rowH = rowRot and (rowDef and rowDef.width or 1) or (rowDef and rowDef.height or 1)
                    local rowX = tonumber(row.slot_x) or 0
                    local rowY = tonumber(row.slot_y) or 0
                    if not (targetXNum + effW <= rowX or targetXNum >= rowX + rowW
                        or targetYNum + effH <= rowY or targetYNum >= rowY + rowH) then
                        overlaps = true
                        break
                    end
                end
                if overlaps then
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end

                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
                MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
                    steamId, charId, targetContainer, targetXNum, targetYNum, rotState and 1 or 0, drop.itemName, dropCount, metaJson
                }, function()
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                end)
            end)
        end)
        return
    end

    -- А) Если игрок перетащил дроп мышью на конкретную ячейку в инвентаре
    if targetXNum and targetYNum and targetContainer ~= 'ground' then
        MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
            steamId, charId
        }, function(existing)
            existing = existing or {}
            local rotState = (isRotated == true or isRotated == 1)
            local effW = rotState and itemH or itemW
            local effH = rotState and itemW or itemH

            -- Проверяем, перетащили ли на существующий предмет того же типа (объединение в стак)
            local targetItem = nil
            for _, row in ipairs(existing) do
                local rX = tonumber(row.slot_x) or 0
                local rY = tonumber(row.slot_y) or 0
                local rDef = Items.Get(row.item_name)
                local isRot = IsRotatedValue(row.is_rotated)
                local rW = isRot and (rDef and rDef.height or 1) or (rDef and rDef.width or 1)
                local rH = isRot and (rDef and rDef.width or 1) or (rDef and rDef.height or 1)

                if targetXNum >= rX and targetXNum < (rX + rW) and targetYNum >= rY and targetYNum < (rY + rH) then
                    targetItem = row
                    break
                end
            end

            if targetItem and targetItem.item_name == drop.itemName and maxStack > 1 then
                local rowMeta = CleanItemMetadata(targetItem.metadata)
                local rowHasMeta = next(rowMeta) ~= nil
                local isMetaMatch = (not hasUniqueMeta and not rowHasMeta) or (hasUniqueMeta and rowHasMeta and json.encode(rowMeta) == metaJson)
                if isMetaMatch then
                    local curTargetCount = tonumber(targetItem.count) or 1
                    local spaceLeft = maxStack - curTargetCount
                    if spaceLeft > 0 then
                        local mergeAmount = math.min(dropCount, spaceLeft)
                        MySQL.update("UPDATE thehunt_inventories SET count = count + ? WHERE id = ?", {
                            mergeAmount, targetItem.id
                        }, function()
                            if mergeAmount >= dropCount then
                                ActiveDrops[dId] = nil
                                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
                            else
                                drop.count = dropCount - mergeAmount
                                MySQL.update("UPDATE thehunt_drops SET count = count - ? WHERE id = ?", { drop.count, dId })
                            end
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                        end)
                        return
                    end
                end
            end

            -- Проверяем, свободен ли целевой слот
            local isValidSlot = false
            local mainCols, mainRows = Items.GetGridCols("main"), Items.GetGridRows("main")
            if (targetXNum >= 0) and (targetYNum >= 0) and (targetXNum + effW <= mainCols) and (targetYNum + effH <= mainRows) then
                local overlaps = false
                for _, row in ipairs(existing) do
                    local rX = tonumber(row.slot_x) or 0
                    local rY = tonumber(row.slot_y) or 0
                    local rDef = Items.Get(row.item_name)
                    local isRot = IsRotatedValue(row.is_rotated)
                    local rW = isRot and (rDef and rDef.height or 1) or (rDef and rDef.width or 1)
                    local rH = isRot and (rDef and rDef.width or 1) or (rDef and rDef.height or 1)

                    if not (targetXNum + effW <= rX or targetXNum >= rX + rW or targetYNum + effH <= rY or targetYNum >= rY + rH) then
                        overlaps = true
                        break
                    end
                end
                if not overlaps then
                    isValidSlot = true
                end
            end

            if isValidSlot then
                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)

                MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', ?, ?, ?, ?, ?, ?)", {
                    steamId, charId, targetXNum, targetYNum, rotState and 1 or 0, drop.itemName, dropCount, metaJson
                }, function(insertId)
                    if IsClothing(itemDef) then RestoreClothingContents(steamId, charId, insertId, dropMeta) end
                    if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                end)
                return
            end

            -- Если целевой слот был занят, подбираем через умное объединение в стаки
            AddOrStackItemToInventory(steamId, charId, drop.itemName, dropCount, drop.metadata, function(success, addedCount, remainder)
                if not success or addedCount <= 0 then
                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!")
                    return
                end

                if remainder <= 0 then
                    ActiveDrops[dId] = nil
                    MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                    TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
                else
                    drop.count = remainder
                    MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { remainder, dId })
                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Часть предметов не поместилась!")
                end
                TriggerClientEvent("thehunt_items:refreshInventory", src)
            end)
        end)
    else
        -- Б) Подбор через кнопку ПКМ -> "Подобрать" или без конкретных координат ячейки:
        -- Всегда в первую очередь заполняем существующие неполные стаки, а остаток кладем в свободный слот!
        AddOrStackItemToInventory(steamId, charId, drop.itemName, dropCount, drop.metadata, function(success, addedCount, remainder)
            if not success or addedCount <= 0 then
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!")
                return
            end

            if remainder <= 0 then
                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
            else
                drop.count = remainder
                MySQL.update("UPDATE thehunt_drops SET count = ? WHERE id = ?", { remainder, dId })
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Часть предметов не поместилась!")
            end
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end)
    end
end)

-- 5. Передача предмета другому игроку (Player-to-Player Transfer)
-- Nearby pickup is also serialized per player and locked per world drop. The
-- source drop is removed/updated only after its authoritative count is known;
-- a second pickup request therefore cannot mint the same item twice.
local PickupQueues = {}
local PickupDropLocks = {}

local function RestoreWorldDrop(drop, count, metadata)
    local amount = tonumber(count) or 0
    if amount <= 0 then return nil end
    local meta = metadata or drop.metadata or {}
    local insertId = MySQL.insert.await("INSERT INTO thehunt_drops (item_name, count, x, y, z, metadata, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
        drop.itemName, amount, drop.x, drop.y, drop.z, next(meta) and json.encode(meta) or nil, drop.droppedBy
    })
    local dId = insertId and tonumber(insertId)
    if not dId then return nil end
    local restored = {
        id = dId,
        itemName = drop.itemName,
        label = drop.label,
        count = amount,
        x = drop.x,
        y = drop.y,
        z = drop.z,
        metadata = meta,
        dropTime = os.time()
    }
    ActiveDrops[dId] = restored
    TriggerClientEvent("thehunt_items:onDropCreated", -1, restored)
    return dId
end

local function TakeWorldDrop(dropId, drop, amount)
    local take = tonumber(amount) or 0
    local current = tonumber(drop.count) or 0
    if take < 1 or take > current then return false end

    if take == current then
        local deleted = MySQL.update.await("DELETE FROM thehunt_drops WHERE id = ? AND count = ?", { dropId, current })
        if tonumber(deleted) ~= 1 then return false end
        ActiveDrops[dropId] = nil
        TriggerClientEvent("thehunt_items:onDropRemoved", -1, dropId)
        return true
    end

    local changed = MySQL.update.await("UPDATE thehunt_drops SET count = count - ? WHERE id = ? AND count >= ?", {
        take, dropId, take
    })
    if tonumber(changed) ~= 1 then return false end
    drop.count = current - take
    TriggerClientEvent("thehunt_items:onDropUpdated", -1, dropId, drop.count)
    return true
end

local function ProcessPickupDrop(src, task, done)
    local dropId, targetContainer, targetX, targetY, isRotated = table.unpack(task)
    local dId = tonumber(dropId)
    if not dId or not ActiveDrops[dId] then done(); return end
    if PickupDropLocks[dId] then done(); return end
    PickupDropLocks[dId] = src

    local finished = false
    local function finish()
        if finished then return end
        finished = true
        PickupDropLocks[dId] = nil
        done()
    end
    local function reject(message, kind)
        if message then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", message, kind or "error")
        end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
    end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local drop = ActiveDrops[dId]
    if IsRemovedClothingItem(drop.itemName) then reject(); return end

    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    if #(pedCoords - vector3(drop.x, drop.y, drop.z)) > 6.0 then
        reject("Предмет слишком далеко")
        return
    end

    local itemDef = Items.Get(drop.itemName)
    if not itemDef then reject(); return end
    local dropCount = tonumber(drop.count) or 0
    if dropCount < 1 then reject(); return end
    local dropMeta = CleanItemMetadata(drop.metadata)
    local metaJson = next(dropMeta) and json.encode(dropMeta) or nil
    local targetXNum = tonumber(targetX)
    local targetYNum = tonumber(targetY)
    local targetHasCoords = targetXNum and targetYNum and targetXNum == targetXNum and targetYNum == targetYNum
        and math.abs(targetXNum) < 1000000 and math.abs(targetYNum) < 1000000
        and targetXNum == math.floor(targetXNum) and targetYNum == math.floor(targetYNum)
    local rotation = IsRotatedValue(isRotated)

    -- Проверка перегруза (жесткий лимит веса 25.0 кг)
    local itemWeight = tonumber(itemDef.weight) or 0.1
    local totalAddWeight = itemWeight * dropCount
    local curCarriedWeight = GetPlayerTotalCarriedWeight(steamId, charId)
    if curCarriedWeight + totalAddWeight > HARD_WEIGHT_CAP + 0.001 then
        reject(string.format("Слишком тяжело! Предел веса %.1f кг превышен.", HARD_WEIGHT_CAP), "error")
        return
    end

    -- Ground -> equipment slot.
    if targetContainer == "equipment" and targetHasCoords then
        local expectedX = EquipmentSlotIndex(itemDef.clothingSlot)
        local itemGender = dropMeta.gender or dropMeta.sex
        if itemGender and CanonicalGender(itemGender) ~= GetCharacterGender(src) then
            reject("Эта одежда предназначена для другого пола")
            return
        end
        if not IsClothing(itemDef) or expectedX == nil or targetXNum ~= expectedX or targetYNum ~= 0 then
            reject()
            return
        end

        local occupied = MySQL.query.await("SELECT id FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'equipment' AND slot_x = ? LIMIT 1", {
            steamId, charId, expectedX
        }) or {}
        if occupied[1] then reject("Этот слот одежды уже занят", "warning"); return end

        if not itemGender then
            dropMeta.gender = GetCharacterGender(src)
            metaJson = json.encode(dropMeta)
        end
        if not TakeWorldDrop(dId, drop, 1) then reject(); return end

        local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'equipment', ?, 0, 0, ?, 1, ?)", {
            steamId, charId, expectedX, drop.itemName, metaJson
        })
        if not insertId then
            RestoreWorldDrop(drop, 1, dropMeta)
            reject()
            return
        end
        RestoreClothingContents(steamId, charId, insertId, dropMeta)
        if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
        SyncEquippedClothing(src, itemDef, dropMeta, true)
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Ground -> an equipped garment's pocket grid.
    if type(targetContainer) == "string" and string.sub(targetContainer, 1, 9) == "clothing:" and targetHasCoords then
        local parentId = tonumber(string.sub(targetContainer, 10))
        if not parentId then reject(); return end
        local parentRows = MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND container = 'equipment'", {
            parentId, steamId, charId
        }) or {}
        local parentDef = parentRows[1] and Items.Get(parentRows[1].item_name)
        if not IsClothing(parentDef) or not parentDef.storage then reject(); return end
        if not CanPackGarment(src, itemDef, parentDef, dropMeta) then reject(); return end

        local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
        local width = rotation and rawH or rawW
        local height = rotation and rawW or rawH
        if dropCount > (tonumber(itemDef.maxStack) or 1) or not StorageAreaFits(parentDef.storage, targetXNum, targetYNum, width, height) then
            reject()
            return
        end
        local existing = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
            steamId, charId, targetContainer
        }) or {}
        for _, row in ipairs(existing) do
            local rowDef = Items.Get(row.item_name)
            if rowDef then
                local rowRotated = IsRotatedValue(row.is_rotated)
                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW
                    or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                    reject()
                    return
                end
            end
        end
        if not TakeWorldDrop(dId, drop, dropCount) then reject(); return end
        local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
            steamId, charId, targetContainer, targetXNum, targetYNum, rotation and 1 or 0, drop.itemName, dropCount, metaJson
        })
        if not insertId then
            RestoreWorldDrop(drop, dropCount, dropMeta)
            reject()
            return
        end
        if IsClothing(itemDef) then RestoreClothingContents(steamId, charId, insertId, dropMeta) end
        if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Ground -> container item grid.
    if type(targetContainer) == "string" and string.sub(targetContainer, 1, 10) == "container:" and targetHasCoords then
        if not IsInventoryStorageAccessible(steamId, charId, targetContainer) then
            reject()
            return
        end
        local parentId = tonumber(string.sub(targetContainer, 11))
        if not parentId or IsItemContainer(itemDef) then reject(); return end
        local parentRows = MySQL.query.await("SELECT item_name FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
            parentId, steamId, charId
        }) or {}
        local parentDef = parentRows[1] and Items.Get(parentRows[1].item_name)
        if not parentDef or not parentDef.containerStorage then reject(); return end
        if not CanPackGarment(src, itemDef, parentDef, dropMeta) then reject(); return end

        if parentDef.containerStorage.keyOnly == true and not IsKeyItem(itemDef, drop.itemName) then
            reject("В связку можно класть только ключи!", "warning")
            return
        end

        local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
        local width = rotation and rawH or rawW
        local height = rotation and rawW or rawH
        local cols = tonumber(parentDef.containerStorage.cols) or 2
        local rowsCount = tonumber(parentDef.containerStorage.rows) or 3
        if dropCount > (tonumber(itemDef.maxStack) or 1) or targetXNum < 0 or targetYNum < 0
            or targetXNum + width > cols or targetYNum + height > rowsCount then
            reject()
            return
        end
        local existing = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = ?", {
            steamId, charId, targetContainer
        }) or {}
        for _, row in ipairs(existing) do
            local rowDef = Items.Get(row.item_name)
            if rowDef then
                local rowRotated = IsRotatedValue(row.is_rotated)
                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW
                    or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                    reject()
                    return
                end
            end
        end
        if not TakeWorldDrop(dId, drop, dropCount) then reject(); return end
        local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", {
            steamId, charId, targetContainer, targetXNum, targetYNum, rotation and 1 or 0, drop.itemName, dropCount, metaJson
        })
        if not insertId then
            RestoreWorldDrop(drop, dropCount, dropMeta)
            reject()
            return
        end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Ground -> placed container grid.
    if type(targetContainer) == "string" and string.sub(targetContainer, 1, 5) == "prop:" and targetHasCoords then
        local propId = tonumber(string.sub(targetContainer, 6))
        local activePropId = ActivePlayerPlacedContainers[src]
        if not propId or activePropId ~= propId or IsItemContainer(itemDef) then reject(); return end

        local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(propId)
        if not propData then reject(); return end

        -- Protection check
        local isProtected = (propData.is_protected == 1 or propData.is_protected == true)
        if isProtected and propData.owner and propData.owner ~= "ADMIN" and propData.owner ~= "UNKNOWN" then
            local isOwner = (propData.owner == steamId)
            local isAdmin = exports.thehunt_core and exports.thehunt_core.IsPlayerAdmin and exports.thehunt_core:IsPlayerAdmin(src)
            if not isOwner and not isAdmin then reject(); return end
        end

        local propItemDef = propData.item_name and Items.Get(propData.item_name)
        if not propItemDef and propData.model_hash then
            local resolvedName, defFound = Items.GetByPropModel(propData.model_hash)
            if resolvedName then propItemDef = defFound end
        end
        local containerStorage = propItemDef and propItemDef.containerStorage or { cols = 3, rows = 3 }

        if containerStorage.keyOnly == true and not IsKeyItem(itemDef, drop.itemName) then
            reject("В связку можно класть только ключи!", "warning")
            return
        end

        local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
        local width = rotation and rawH or rawW
        local height = rotation and rawW or rawH
        local cols = tonumber(containerStorage.cols) or 3
        local rowsCount = tonumber(containerStorage.rows) or 3
        if dropCount > (tonumber(itemDef.maxStack) or 1) or targetXNum < 0 or targetYNum < 0
            or targetXNum + width > cols or targetYNum + height > rowsCount then
            reject()
            return
        end

        local existing = MySQL.query.await("SELECT id, item_name, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE container = ?", {
            targetContainer
        }) or {}
        for _, row in ipairs(existing) do
            local rowDef = Items.Get(row.item_name)
            if rowDef then
                local rowRotated = IsRotatedValue(row.is_rotated)
                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW
                    or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                    reject()
                    return
                end
            end
        end

        if not TakeWorldDrop(dId, drop, dropCount) then reject(); return end
        local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES ('WORLD', 0, ?, ?, ?, ?, ?, ?, ?)", {
            targetContainer, targetXNum, targetYNum, rotation and 1 or 0, drop.itemName, dropCount, metaJson
        })
        if not insertId then
            RestoreWorldDrop(drop, dropCount, dropMeta)
            reject()
            return
        end
        SyncPlacedPropSnapshot(propId)
        RefreshPlacedContainerViewers(propId, src)
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Ground -> an explicit main-grid cell (merge or new stack).
    if targetContainer == "main" and targetHasCoords then
        local mainRows = MySQL.query.await("SELECT id, item_name, count, metadata, slot_x, slot_y, is_rotated FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
            steamId, charId
        }) or {}
        local targetItem = nil
        for _, row in ipairs(mainRows) do
            local rowDef = Items.Get(row.item_name)
            if rowDef then
                local rowRotated = IsRotatedValue(row.is_rotated)
                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                if targetXNum >= rowX and targetXNum < rowX + rowW and targetYNum >= rowY and targetYNum < rowY + rowH then
                    targetItem = row
                    break
                end
            end
        end

        if targetItem then
            local targetMeta = CleanItemMetadata(targetItem.metadata)
            local sameMeta = (not next(dropMeta) and not next(targetMeta))
                or (next(dropMeta) and next(targetMeta) and json.encode(dropMeta) == json.encode(targetMeta))
            local targetCount = tonumber(targetItem.count) or 0
            local maxStack = tonumber(itemDef.maxStack) or 1
            if targetItem.item_name == drop.itemName and maxStack > 1 and sameMeta and targetCount < maxStack then
                local mergeAmount = math.min(dropCount, maxStack - targetCount)
                if not TakeWorldDrop(dId, drop, mergeAmount) then reject(); return end
                local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count + ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND count = ? AND count + ? <= ?", {
                    mergeAmount, targetItem.id, steamId, charId, targetCount, mergeAmount, maxStack
                })
                if tonumber(changed) ~= 1 then
                    RestoreWorldDrop(drop, mergeAmount, dropMeta)
                    reject()
                    return
                end
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                finish()
                return
            end
            reject()
            return
        end

        local rawW, rawH = tonumber(itemDef.width) or 1, tonumber(itemDef.height) or 1
        local width = rotation and rawH or rawW
        local height = rotation and rawW or rawH
        local cols, rowsCount = Items.GetGridCols("main"), Items.GetGridRows("main")
        if dropCount > (tonumber(itemDef.maxStack) or 1) or targetXNum < 0 or targetYNum < 0
            or targetXNum + width > cols or targetYNum + height > rowsCount then
            reject()
            return
        end
        for _, row in ipairs(mainRows) do
            local rowDef = Items.Get(row.item_name)
            if rowDef then
                local rowRotated = IsRotatedValue(row.is_rotated)
                local rowW = rowRotated and (tonumber(rowDef.height) or 1) or (tonumber(rowDef.width) or 1)
                local rowH = rowRotated and (tonumber(rowDef.width) or 1) or (tonumber(rowDef.height) or 1)
                local rowX, rowY = tonumber(row.slot_x) or 0, tonumber(row.slot_y) or 0
                if not (targetXNum + width <= rowX or targetXNum >= rowX + rowW
                    or targetYNum + height <= rowY or targetYNum >= rowY + rowH) then
                    reject()
                    return
                end
            end
        end
        if not TakeWorldDrop(dId, drop, dropCount) then reject(); return end
        local insertId = MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', ?, ?, ?, ?, ?, ?)", {
            steamId, charId, targetXNum, targetYNum, rotation and 1 or 0, drop.itemName, dropCount, metaJson
        })
        if not insertId then
            RestoreWorldDrop(drop, dropCount, dropMeta)
            reject()
            return
        end
        if IsClothing(itemDef) then RestoreClothingContents(steamId, charId, insertId, dropMeta) end
        if IsItemContainer(itemDef) then RestoreContainerContents(steamId, charId, insertId, dropMeta) end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        finish()
        return
    end

    -- Context-menu pickup: the server finds the first valid stack/slot.
    if targetContainer == "ground" then reject(); return end
    -- Debit the world drop before adding to the inventory. If the inventory
    -- cannot accept it, the exact item is restored as a new server drop.
    if not TakeWorldDrop(dId, drop, dropCount) then reject(); return end

    local resultPromise = promise.new()
    AddOrStackItemToInventory(steamId, charId, drop.itemName, dropCount, dropMeta, function(success, addedCount, remainder)
        resultPromise:resolve({ success = success, addedCount = tonumber(addedCount) or 0, remainder = tonumber(remainder) or dropCount })
    end)
    local result = Citizen.Await(resultPromise)
    if not result.success or result.addedCount <= 0 then
        RestoreWorldDrop(drop, dropCount, dropMeta)
        reject("В инвентаре нет свободного места")
        return
    end
    if result.remainder > 0 then
        -- AddOrStack placed only part of the stack. The remainder stays on
        -- the ground as a new authoritative drop.
        RestoreWorldDrop(drop, result.remainder, dropMeta)
    end
    TriggerClientEvent("thehunt_items:refreshInventory", src)
    finish()
end

local function RunNextPickup(src)
    local state = PickupQueues[src]
    if not state or state.running then return end
    local task = table.remove(state.items, 1)
    if not task then PickupQueues[src] = nil; return end
    state.running = true
    local ok, err = pcall(ProcessPickupDrop, src, task, function()
        state.running = false
        RunNextPickup(src)
    end)
    if not ok then
        local dId = tonumber(task[1])
        PickupDropLocks[dId] = nil
        print(("^1[HUNT ITEMS] pickup failed for %s: %s^7"):format(tostring(src), tostring(err)))
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        state.running = false
        RunNextPickup(src)
    end
end

RegisterNetEvent("thehunt_items:pickupDrop", function(dropId, targetContainer, targetX, targetY, isRotated)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local state = PickupQueues[src]
    if not state then
        state = { items = {}, running = false }
        PickupQueues[src] = state
    end
    state.items[#state.items + 1] = { dropId, targetContainer, targetX, targetY, isRotated }
    RunNextPickup(src)
end)

RegisterNetEvent("thehunt_items:transferItem", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)

    if not data or not data.targetPlayerId or not data.dbId then return end
    local targetSrc = tonumber(data.targetPlayerId)
    local transferCount = tonumber(data.count) or 1
    local dbId = tonumber(data.dbId)

    if targetSrc == src then return end
    local targetPed = GetPlayerPed(targetSrc)
    if not DoesEntityExist(targetPed) then
        TriggerClientEvent("thehunt_status:notify", src, "Передача", "Игрок не найден")
        return
    end

    local srcPed = GetPlayerPed(src)
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Передача", "Игрок слишком далеко", "error")
        return
    end

    local targetSteamId, targetCharId = GetPlayerIdentifiersVORP(targetSrc)

    MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
        dbId,
        steamId,
        charId
    }, function(res)
        if res and res[1] then
            local currentItem = res[1]
            if not IsInventoryStorageAccessible(steamId, charId, currentItem.container) then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end
            local curCount = tonumber(currentItem.count) or 1
            if curCount < transferCount then transferCount = curCount end
            local itemDef = Items.Get(currentItem.item_name)
            local transferMeta = SafeDecodeMeta(currentItem.metadata)

            local function doTransfer(finalMeta)
                local itemWeight = (itemDef and tonumber(itemDef.weight)) or 0.1
                local addedWeight = itemWeight * transferCount
                local targetWeight = GetPlayerTotalCarriedWeight(targetSteamId, targetCharId)
                if targetWeight + addedWeight > HARD_WEIGHT_CAP + 0.001 then
                    TriggerClientEvent("thehunt_status:notify", src, "Передача", "Получатель не может нести такой вес! Перегрузка.", "error")
                    TriggerClientEvent("thehunt_status:notify", targetSrc, "Слишком тяжело", string.format("Вы не можете нести больше %.1f кг!", HARD_WEIGHT_CAP), "error")
                    return
                end

                -- Добавляем получателю (с приоритетом объединения в существующие неполные стаки!)
                AddOrStackItemToInventory(targetSteamId, targetCharId, currentItem.item_name, transferCount, finalMeta, function(success, addedCount, remainder)
                    if not success or addedCount <= 0 then
                        if IsClothing(itemDef) and finalMeta and finalMeta.clothing_contents then
                            RestoreClothingContents(steamId, charId, dbId, finalMeta)
                        end
                        if IsItemContainer(itemDef) and finalMeta and finalMeta.container_contents then
                            RestoreContainerContents(steamId, charId, dbId, finalMeta)
                        end
                        TriggerClientEvent("thehunt_status:notify", src, "Передача", "У получателя нет места в инвентаре!", "error")
                        return
                    end

                    -- Списываем у отправителя фактически переданное количество
                    if curCount <= addedCount then
                        MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { dbId })
                    else
                        MySQL.update("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { addedCount, dbId })
                    end

                    local itemMeta = SafeDecodeMeta(finalMeta)
                    local itemLabel = (itemMeta and itemMeta.label) or (itemDef and itemDef.label) or currentItem.item_name
                    local countSuffix = string.format(" (%d шт.)", addedCount)

                    local senderMsg = string.format("Вы передали «%s»%s игроку [#%d]", itemLabel, countSuffix, targetSrc)
                    local receiverMsg = string.format("Вы получили «%s»%s от игрока [#%d]", itemLabel, countSuffix, src)

                    TriggerClientEvent("thehunt_status:notify", src, "Передача", senderMsg, "success")
                    TriggerClientEvent("thehunt_status:notify", targetSrc, "Передача", receiverMsg, "success")

                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    TriggerClientEvent("thehunt_items:refreshInventory", targetSrc)
                end)
            end

            if IsClothing(itemDef) and curCount <= transferCount then
                PackClothingContents(dbId, transferMeta, function(packed)
                    doTransfer(packed)
                end)
            elseif IsItemContainer(itemDef) and curCount <= transferCount then
                PackContainerContents(dbId, transferMeta, function(packed)
                    doTransfer(packed)
                end)
            else
                doTransfer(transferMeta)
            end
        end
    end)
end)

-- 5.1 Пакетная передача группы предметов (Batch Player-to-Player Transfer)
RegisterNetEvent("thehunt_items:transferBatch", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)

    if not data or not data.targetPlayerId or not data.items or #data.items == 0 then return end
    local targetSrc = tonumber(data.targetPlayerId)
    if targetSrc == src then return end

    local targetPed = GetPlayerPed(targetSrc)
    if not DoesEntityExist(targetPed) then
        TriggerClientEvent("thehunt_status:notify", src, "Передача", "Игрок не найден", "error")
        return
    end

    local srcPed = GetPlayerPed(src)
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Передача", "Игрок слишком далеко", "error")
        return
    end

    local targetSteamId, targetCharId = GetPlayerIdentifiersVORP(targetSrc)
    if not targetSteamId or not targetCharId then
        TriggerClientEvent("thehunt_status:notify", src, "Передача", "Ошибка персонажа получателя", "error")
        return
    end

    local dbIds = {}
    for _, req in ipairs(data.items) do
        if req.dbId then
            table.insert(dbIds, tonumber(req.dbId))
        end
    end

    if #dbIds == 0 then return end

    local inQuery = table.concat(dbIds, ",")
    MySQL.query(string.format("SELECT * FROM thehunt_inventories WHERE id IN (%s) AND identifier = ? AND charidentifier = ?", inQuery), {
        steamId, charId
    }, function(senderItems)
        if not senderItems or #senderItems == 0 then return end

        local senderItemMap = {}
        for _, item in ipairs(senderItems) do
            if not IsInventoryStorageAccessible(steamId, charId, item.container) then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end
            senderItemMap[tonumber(item.id)] = item
        end

        local totalTransferredTypes = 0
        local totalTransferredCount = 0
        local transferredList = {}

        local itemsQueue = {}
        for _, req in ipairs(data.items) do
            local dbId = tonumber(req.dbId)
            local reqCount = tonumber(req.count) or 1
            local item = senderItemMap[dbId]
            if item then
                local curCount = tonumber(item.count) or 1
                if reqCount > curCount then reqCount = curCount end
                table.insert(itemsQueue, {
                    dbId = dbId,
                    item = item,
                    count = reqCount,
                    curCount = curCount
                })
            end
        end

        if #itemsQueue == 0 then return end

        local function ProcessNextBatchItem(index)
            if index > #itemsQueue then
                if totalTransferredTypes > 0 then
                    local itemsStr = table.concat(transferredList, ", ")
                    local senderMsg = string.format("Вы передали %s игроку [#%d]", itemsStr, targetSrc)
                    local receiverMsg = string.format("Вы получили %s от игрока [#%d]", itemsStr, src)

                    TriggerClientEvent("thehunt_status:notify", src, "Передача", senderMsg, "success")
                    TriggerClientEvent("thehunt_status:notify", targetSrc, "Передача", receiverMsg, "success")

                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    TriggerClientEvent("thehunt_items:refreshInventory", targetSrc)
                else
                    TriggerClientEvent("thehunt_status:notify", src, "Передача", "У получателя нет места в инвентаре!", "error")
                end
                return
            end

            local entry = itemsQueue[index]
            local itDef = Items.Get(entry.item.item_name)
            local itemMeta = SafeDecodeMeta(entry.item.metadata)

            local function doBatchAdd(finalMeta)
                AddOrStackItemToInventory(targetSteamId, targetCharId, entry.item.item_name, entry.count, finalMeta, function(success, addedCount)
                    if success and addedCount > 0 then
                        if entry.curCount <= addedCount then
                            MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { entry.dbId })
                        else
                            MySQL.update("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { addedCount, entry.dbId })
                        end

                        local itLabel = (finalMeta and finalMeta.label) or (itDef and itDef.label) or entry.item.item_name
                        table.insert(transferredList, string.format("«%s» (%d шт.)", itLabel, addedCount))

                        totalTransferredTypes = totalTransferredTypes + 1
                        totalTransferredCount = totalTransferredCount + addedCount
                    else
                        if IsClothing(itDef) and finalMeta and finalMeta.clothing_contents then
                            RestoreClothingContents(steamId, charId, entry.dbId, finalMeta)
                        end
                        if IsItemContainer(itDef) and finalMeta and finalMeta.container_contents then
                            RestoreContainerContents(steamId, charId, entry.dbId, finalMeta)
                        end
                    end
                    ProcessNextBatchItem(index + 1)
                end)
            end

            if IsClothing(itDef) and entry.curCount <= entry.count then
                PackClothingContents(entry.dbId, itemMeta, doBatchAdd)
            elseif IsItemContainer(itDef) and entry.curCount <= entry.count then
                PackContainerContents(entry.dbId, itemMeta, doBatchAdd)
            else
                doBatchAdd(itemMeta)
            end
        end

        ProcessNextBatchItem(1)
    end)
end)

-- 5.2 Применение медицины к другому игроку (Player-to-Player Medical Aid)
RegisterNetEvent("thehunt_items:applyMedicineToPlayer", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)

    if not data or not data.targetPlayerId or not data.dbId then return end
    local targetSrc = tonumber(data.targetPlayerId)
    local dbId = tonumber(data.dbId)

    if targetSrc == src then return end
    local targetPed = GetPlayerPed(targetSrc)
    if not DoesEntityExist(targetPed) then
        TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Игрок не найден", "error")
        return
    end

    local srcPed = GetPlayerPed(src)
    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > 3.5 then
        TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Игрок слишком далеко", "error")
        return
    end

    MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
        dbId, steamId, charId
    }, function(res)
        if not res or not res[1] then return end

        local currentItem = res[1]
        if not IsInventoryStorageAccessible(steamId, charId, currentItem.container) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end
        local curCount = tonumber(currentItem.count) or 1
        if curCount < 1 then return end

        local itemDef = Items.Get(currentItem.item_name)
        if not itemDef or (itemDef.category ~= "medical" and not itemDef.healAmount) then
            TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Этот предмет не является медициной", "error")
            return
        end

        local targetState = Player(targetSrc) and Player(targetSrc).state
        local targetIsKnocked = targetState and targetState.thehuntUnconscious == true
        local targetAlreadyReady = targetState and targetState.thehuntKnockReady == true
        local itemMeta = SafeDecodeMeta(currentItem.metadata)
        local itemLabel = (itemMeta and itemMeta.label) or itemDef.label or currentItem.item_name

        -- Аптечка — единственный предмет для игрока без сознания. Она не
        -- лечит HP: после десятисекундной помощи лишь открывает ему подъём.
        if currentItem.item_name == "first_aid_kit" then
            if not targetIsKnocked then
                TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Аптечку можно применять только к игроку без сознания", "error")
                return
            end
            if targetAlreadyReady then
                TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Игрок уже может подняться самостоятельно", "info")
                return
            end
            if PendingKnockAid[src] then
                TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Вы уже оказываете помощь", "warning")
                return
            end

            PendingKnockAid[src] = targetSrc
            TriggerClientEvent("thehunt_items:playKnockAidAnimation", src, targetSrc)
            TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Оказываем помощь. Не отходите от игрока 10 секунд", "info")

            CreateThread(function()
                Wait(10000)

                local pendingTarget = PendingKnockAid[src]
                PendingKnockAid[src] = nil
                if pendingTarget ~= targetSrc or GetPlayerPing(src) <= 0 or GetPlayerPing(targetSrc) <= 0 then
                    TriggerClientEvent("thehunt_items:finishKnockAidAnimation", src, false)
                    return
                end

                local healerPed = GetPlayerPed(src)
                local patientPed = GetPlayerPed(targetSrc)
                local patientState = Player(targetSrc) and Player(targetSrc).state
                local stillKnocked = patientState and patientState.thehuntUnconscious == true
                local near = DoesEntityExist(healerPed) and DoesEntityExist(patientPed)
                    and #(GetEntityCoords(healerPed) - GetEntityCoords(patientPed)) <= 3.5
                if not stillKnocked or not near then
                    TriggerClientEvent("thehunt_items:finishKnockAidAnimation", src, false)
                    TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Помощь прервана: игрок слишком далеко или уже пришёл в себя", "error")
                    return
                end

                local rows = MySQL.query.await("SELECT count FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? AND item_name = ? LIMIT 1", {
                    dbId, steamId, charId, "first_aid_kit"
                })
                local available = rows and rows[1] and tonumber(rows[1].count) or 0
                if available < 1 then
                    TriggerClientEvent("thehunt_items:finishKnockAidAnimation", src, false)
                    TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Аптечка больше недоступна", "error")
                    return
                end

                local changed = MySQL.update.await("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ? AND identifier = ? AND charidentifier = ? AND item_name = ? AND count >= 1", {
                    dbId, steamId, charId, "first_aid_kit"
                })
                if (tonumber(changed) or 0) < 1 then
                    TriggerClientEvent("thehunt_items:finishKnockAidAnimation", src, false)
                    return
                end
                MySQL.update.await("DELETE FROM thehunt_inventories WHERE id = ? AND count <= 0", { dbId })

                local deathResource = GetResourceState("thehunt_death") == "started"
                local opened = deathResource and exports.thehunt_death:AidKnockedPlayer(src, targetSrc)
                if not opened then
                    -- The target state changed between validation and commit;
                    -- return the reserved item rather than consuming it.
                    AddOrStackItemToInventory(steamId, charId, "first_aid_kit", 1, nil)
                    TriggerClientEvent("thehunt_items:finishKnockAidAnimation", src, false)
                    TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Помощь не удалась: игрок уже не в ноке", "error")
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    return
                end

                TriggerClientEvent("thehunt_items:finishKnockAidAnimation", src, true)
                TriggerClientEvent("thehunt_status:notify", src, "Медицина", string.format("Вы привели игрока [#%d] в чувство", targetSrc), "success")
                TriggerClientEvent("thehunt_status:notify", targetSrc, "Медицина", string.format("Игрок [#%d] оказал вам помощь. Нажмите Space, чтобы подняться", src), "success")
                TriggerClientEvent("thehunt_items:refreshInventory", src)
            end)
            return
        end

        if targetIsKnocked then
            TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Игрок без сознания: нужна именно аптечка", "error")
            return
        end

        local targetPed = GetPlayerPed(targetSrc)
        local targetHp = GetEntityHealth(targetPed)
        local targetMaxHp = GetEntityMaxHealth(targetPed)
        if targetMaxHp <= 0 then targetMaxHp = 100 end
        if targetHp >= targetMaxHp then
            TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Игрок полностью здоров — перевязка не требуется", "error")
            return
        end

        -- Обычная медицина продолжает работать только вне нока.
        if curCount <= 1 then
            MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { dbId })
        else
            MySQL.update("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { dbId })
        end
        TriggerClientEvent("thehunt_items:playMedicalAnimHealer", src)

        local healAmount = itemDef.healAmount or 60
        local healDuration = itemDef.healDuration or 30
        TriggerClientEvent("thehunt_items:applyBandageHeal", targetSrc, healAmount, healDuration, itemLabel)
        TriggerClientEvent("thehunt_status:notify", src, "Медицина", string.format("Вы перевязали игрока [#%d] («%s»)", targetSrc, itemLabel), "success")
        TriggerClientEvent("thehunt_status:notify", targetSrc, "Медицина", string.format("Игрок [#%d] наложил вам «%s»", src, itemLabel), "success")
        TriggerClientEvent("thehunt_items:refreshInventory", src)
    end)
end)

-- 6. Размещение предмета в мире (Миграция содержимого контейнера и списание предмета)
local function OnItemPlacedInWorldInternal(src, itemName, dbId, propId)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local pId = tonumber(propId)
    local numDbId = tonumber(dbId)
    if not numDbId then return end

    MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
        numDbId, steamId, charId
    }, function(res)
        if not res or not res[1] then return end
        if not IsInventoryStorageAccessible(steamId, charId, res[1].container) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end
        local parentRow = res[1]
        local itemDef = Items.Get(parentRow.item_name)
        local curCount = tonumber(parentRow.count) or 1

        if itemDef and (IsItemContainer(itemDef) or IsClothing(itemDef)) and pId then
            -- Переносим все вложенные предметы из container:<dbId> / clothing:<dbId> в prop:<propId>
            MySQL.query("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ? OR container = ?", {
                ItemContainer(numDbId), ClothingContainer(numDbId)
            }, function(childRows)
                childRows = childRows or {}
                if #childRows > 0 then
                    MySQL.update("UPDATE thehunt_inventories SET identifier = 'WORLD', charidentifier = 0, container = ? WHERE container = ? OR container = ?", {
                        "prop:" .. tostring(pId), ItemContainer(numDbId), ClothingContainer(numDbId)
                    })
                end

                -- Сохраняем снимок содержимого в метаданные объекта на случай рестарта
                local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(pId)
                local meta = propData and propData.metadata
                if type(meta) == "string" then meta = SafeDecodeMeta(meta) end
                meta = meta or {}
                meta.container_contents = childRows
                if exports.thehunt_builder and exports.thehunt_builder.UpdatePlacedPropMetadata then
                    exports.thehunt_builder:UpdatePlacedPropMetadata(pId, meta)
                end
            end)
        end

        if curCount <= 1 then
            MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { numDbId })
        else
            MySQL.update("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { numDbId })
        end
        TriggerClientEvent("thehunt_items:refreshInventory", src)
    end)
end

RegisterNetEvent("thehunt_items:onItemPlacedInWorld", OnItemPlacedInWorldInternal)
AddEventHandler("thehunt_items:onItemPlacedInWorld", OnItemPlacedInWorldInternal)
exports('OnItemPlacedInWorld', OnItemPlacedInWorldInternal)

-- Устаревший резервный вызов для обычных предметов без привязки к propId
RegisterNetEvent("thehunt_items:onItemPlaced", function(itemName, dbId)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not itemName or not dbId then return end

    MySQL.query("SELECT count, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
        dbId, steamId, charId
    }, function(res)
        if res and res[1] then
            if not IsInventoryStorageAccessible(steamId, charId, res[1].container) then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                return
            end
            local curCount = tonumber(res[1].count) or 1
            if curCount <= 1 then
                MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { dbId })
            else
                MySQL.update("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { dbId })
            end
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        end
    end)
end)

-- 7. Подбор размещенного объекта обратно в инвентарь через радиальное меню G
RegisterNetEvent("thehunt_items:pickupPlacedObject", function(objectId, itemName)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local objId = tonumber(objectId)
    if not objId then return end

    local propData = nil
    if exports.thehunt_builder and exports.thehunt_builder.GetPropById then
        propData = exports.thehunt_builder:GetPropById(objId)
    end

    if (not itemName or itemName == "") and propData and propData.item_name then
        itemName = propData.item_name
    end

    local itemDef = itemName and Items.Get(itemName) or nil
    if not itemDef and itemName then
        local resolvedName, def = Items.GetByPropModel(itemName)
        if resolvedName then
            itemName = resolvedName
            itemDef = def
        end
    end

    if not itemDef and propData and propData.model_hash then
        local resolvedName, def = Items.GetByPropModel(propData.model_hash)
        if resolvedName then
            itemName = resolvedName
            itemDef = def
        end
    end

    if not itemDef then
        print(string.format("^1[HUNT ITEMS] Не удалось определить предмет для объекта #%s (%s)^7", tostring(objectId), tostring(itemName)))
        return
    end

    if itemName == "campfire_lit" or itemName == "campfire_smolder" then
        TriggerClientEvent("thehunt_status:notify", src, "Костёр", "Этот костёр нельзя подобрать!", "error")
        return
    end

    -- Проверка дистанции
    if propData and propData.x then
        local pCoords = GetEntityCoords(GetPlayerPed(src))
        local dist = #(pCoords - vector3(propData.x, propData.y, propData.z))
        if dist > 4.0 then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы слишком далеко!", "error")
            return
        end
    end

    -- Проверка права на подбор: если предмет защищен (is_protected = 1), только владелец (или админ) может его забрать
    local isProtected = (propData and (propData.is_protected == 1 or propData.is_protected == true))
    if isProtected and propData.owner and propData.owner ~= "ADMIN" and propData.owner ~= "UNKNOWN" then
        local isOwner = (propData.owner == steamId)
        local isAdmin = false
        if exports.thehunt_core and exports.thehunt_core.IsPlayerAdmin then
            isAdmin = exports.thehunt_core:IsPlayerAdmin(src)
        end
        if not isOwner and not isAdmin then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот предмет защищен владельцем!", "error")
            return
        end
    end

    local cleanMeta = CleanItemMetadata(propData and propData.metadata)

    -- Если это контейнер (мешок, сумка, связка ключей), восстанавливаем все его содержимое!
    if IsItemContainer(itemDef) then
        local containerRows = MySQL.query.await("SELECT item_name, count, slot_x, slot_y, is_rotated, metadata FROM thehunt_inventories WHERE container = ?", {
            "prop:" .. tostring(objId)
        }) or {}
        if #containerRows > 0 then
            cleanMeta.container_contents = containerRows
            MySQL.query.await("DELETE FROM thehunt_inventories WHERE container = ?", { "prop:" .. tostring(objId) })
        elseif propData and propData.metadata and propData.metadata.container_contents and #propData.metadata.container_contents > 0 then
            cleanMeta.container_contents = propData.metadata.container_contents
        end
    end

    local hasCleanMeta = next(cleanMeta) ~= nil
    local finalMeta = hasCleanMeta and cleanMeta or nil

    AddOrStackItemToInventory(steamId, charId, itemName, 1, finalMeta, function(success)
        if not success then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места!", "error")
            return
        end

        ClosePlacedContainerForAllViewers(objId)
        TriggerEvent("thehunt_builder:deletePlacedObjectDirectly", objId)
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы подобрали: " .. (itemDef.label or itemName))
        print(string.format("^2[HUNT ITEMS] Игрок #%d успешно подобрал объект #%d (%s).^7", src, objId, itemName))
    end)
end)

-- 8. Открытие размещенного контейнера через радиальное меню G
RegisterNetEvent("thehunt_items:openPlacedContainer", function(propId)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local pId = tonumber(propId)
    if not pId then return end

    local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(pId)
    if not propData then return end

    -- Distance check (max 3.8m)
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    local propCoords = vector3(propData.x, propData.y, propData.z)
    if #(pedCoords - propCoords) > 3.8 then
        TriggerClientEvent("thehunt_status:notify", src, "Хранилище", "Вы слишком далеко!", "error")
        return
    end

    -- Protection check
    local isProtected = (propData.is_protected == 1 or propData.is_protected == true)
    if isProtected and propData.owner and propData.owner ~= "ADMIN" and propData.owner ~= "UNKNOWN" then
        local isOwner = (propData.owner == steamId)
        local isAdmin = false
        if exports.thehunt_core and exports.thehunt_core.IsPlayerAdmin then
            isAdmin = exports.thehunt_core:IsPlayerAdmin(src)
        end
        if not isOwner and not isAdmin then
            TriggerClientEvent("thehunt_status:notify", src, "Хранилище", "Этот предмет защищен владельцем!", "error")
            return
        end
    end

    local itemName = propData.item_name
    local itemDef = itemName and Items.Get(itemName)
    if not itemDef and propData.model_hash then
        local resolvedName, def = Items.GetByPropModel(propData.model_hash)
        if resolvedName then
            itemName = resolvedName
            itemDef = def
        end
    end

    local storage = itemDef and itemDef.containerStorage or { cols = 3, rows = 3 }

    -- Самовосстановление из снимка метаданных, если строки в БД отсутствуют
    local count = MySQL.scalar.await("SELECT COUNT(*) FROM thehunt_inventories WHERE container = ?", { "prop:" .. tostring(pId) })
    if (tonumber(count) or 0) == 0 and propData.metadata then
        local m = propData.metadata
        if type(m) == "string" then m = SafeDecodeMeta(m) end
        if m and m.container_contents and type(m.container_contents) == "table" and #m.container_contents > 0 then
            for _, entry in ipairs(m.container_contents) do
                local entryMeta = entry.metadata
                if type(entryMeta) == "table" then
                    entryMeta = next(entryMeta) and json.encode(entryMeta) or nil
                elseif type(entryMeta) == "string" and entryMeta ~= "" then
                    entryMeta = entryMeta
                else
                    entryMeta = nil
                end
                MySQL.insert.await("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES ('WORLD', 0, ?, ?, ?, ?, ?, ?, ?)", {
                    "prop:" .. tostring(pId),
                    tonumber(entry.slot_x) or 0,
                    tonumber(entry.slot_y) or 0,
                    (entry.is_rotated == true or entry.is_rotated == 1 or tonumber(entry.is_rotated) == 1) and 1 or 0,
                    entry.item_name,
                    tonumber(entry.count) or 1,
                    entryMeta
                })
            end
        end
    end

    ActivePlayerPlacedContainers[src] = pId
    PlacedContainerViewers[pId] = PlacedContainerViewers[pId] or {}
    PlacedContainerViewers[pId][src] = true

    TriggerClientEvent("thehunt_inventory:openPlacedContainer", src, {
        propId = pId,
        itemName = itemName or "container",
        label = itemDef and itemDef.label or "Контейнер",
        storage = storage,
        coords = { x = propData.x, y = propData.y, z = propData.z }
    })
    TriggerClientEvent("thehunt_items:refreshInventory", src)
end)

RegisterNetEvent("thehunt_items:closePlacedContainer", function()
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local pId = ActivePlayerPlacedContainers[src]
    if pId then
        ActivePlayerPlacedContainers[src] = nil
        if PlacedContainerViewers[pId] then
            PlacedContainerViewers[pId][src] = nil
            if not next(PlacedContainerViewers[pId]) then
                PlacedContainerViewers[pId] = nil
            end
        end
    end
end)

-- 9. Чтение размещенной в мире записки / блокнота через меню G
RegisterNetEvent("thehunt_items:readPlacedNote", function(propId)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local pId = tonumber(propId)
    if not pId then return end

    local propData = exports.thehunt_builder and exports.thehunt_builder:GetPropById(pId)
    if not propData then return end

    -- Distance check (max 3.8m)
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    local propCoords = vector3(propData.x, propData.y, propData.z)
    if #(pedCoords - propCoords) > 3.8 then
        TriggerClientEvent("thehunt_status:notify", src, "Записка", "Вы слишком далеко!", "error")
        return
    end

    local itemName = propData.item_name
    local itemDef = itemName and Items.Get(itemName)
    if not itemDef and propData.model_hash then
        local resolvedName, def = Items.GetByPropModel(propData.model_hash)
        if resolvedName then
            itemName = resolvedName
            itemDef = def
        end
    end

    local metadata = propData.metadata
    if type(metadata) == "string" then
        metadata = SafeDecodeMeta(metadata)
    end
    if type(metadata) ~= "table" then
        metadata = {}
    end

    TriggerClientEvent("thehunt_inventory:openPlacedNoteReader", src, {
        propId = pId,
        itemName = itemName or "torn_page",
        label = itemDef and itemDef.label or "Вырванная страница",
        metadata = metadata,
        coords = { x = propData.x, y = propData.y, z = propData.z }
    })
end)

-- 6. Фоновый поток очистки просроченных выброшенных предметов (1 минута)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        local now = os.time()
        for dId, drop in pairs(ActiveDrops) do
            -- Управляемый серверной системой лут живёт по собственному таймеру.
            -- Обычные выброшенные игроками предметы сохраняют прежние 60 секунд.
            if not (drop.metadata and drop.metadata.thehuntLoot == true) and (now - drop.dropTime) > DESPAWN_SECONDS then
                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
            end
        end
    end
end)


-- Сохранение содержимого конкретного экземпляра блокнота.
-- Проверяем владельца и item_name здесь, а не доверяем dbId/name из NUI.
RegisterNetEvent("thehunt_items:saveNotebook", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    if type(data) ~= "table" or not data.dbId then return end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local dbId = tonumber(data.dbId)
    local rawHtml = type(data.html) == "string" and data.html or ""
    if #rawHtml > NOTEBOOK_MAX_HTML_BYTES then
        TriggerClientEvent("thehunt_status:notify", src, "Блокнот", "Запись слишком большая для этой страницы", "error")
        return
    end

    local cleanHtml = SanitizeNotebookHtml(rawHtml)
    if cleanHtml == nil then
        TriggerClientEvent("thehunt_status:notify", src, "Блокнот", "Не удалось проверить содержимое записи", "error")
        return
    end

    local title = type(data.title) == "string" and data.title or ""
    title = title:gsub("<[^>]*>", ""):gsub("[<>]", "")
    if #title > 240 then title = title:sub(1, 240) end

    local rows = MySQL.query.await(
        "SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
        { dbId, steamId, charId }
    ) or {}
    local itemRow = rows[1]
    if itemRow and not IsInventoryStorageAccessible(steamId, charId, itemRow.container) then
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        return
    end
    if not itemRow or (itemRow.item_name ~= "notebook" and itemRow.item_name ~= "torn_page") or (tonumber(itemRow.count) or 0) < 1 then
        TriggerClientEvent("thehunt_status:notify", src, "Запись", "Этот предмет больше не находится у вас", "error")
        return
    end

    local itemDef = Items.Get(itemRow.item_name)
    local itemLabel = (itemDef and itemDef.label) or "Запись"

    if itemRow.item_name == "torn_page" then
        cleanHtml = TruncateHtmlToPageLimit(cleanHtml, PAGE_MAX_LINES, PAGE_MAX_CHARS)
    end

    local metadata = SafeDecodeMeta(itemRow.metadata)
    metadata.notebook_html = cleanHtml
    metadata.notebook_title = title
    metadata.notebook_updated_at = os.time()

    local changed = MySQL.update.await(
        "UPDATE thehunt_inventories SET metadata = ? WHERE id = ? AND identifier = ? AND charidentifier = ? AND item_name = ?",
        { json.encode(metadata), dbId, steamId, charId, itemRow.item_name }
    )
    if (tonumber(changed) or 0) < 1 then
        TriggerClientEvent("thehunt_status:notify", src, itemLabel, "Не удалось сохранить запись", "error")
        return
    end

    TriggerClientEvent("thehunt_items:refreshInventory", src)
    TriggerClientEvent("thehunt_status:notify", src, itemLabel, "Запись сохранена", "success")
end)

-- Вырывание листа из блокнота (ПКМ -> Вырвать лист)
RegisterNetEvent("thehunt_items:tearNotebookPage", function(data)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    if type(data) ~= "table" or not data.dbId then return end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local dbId = tonumber(data.dbId)

    local rows = MySQL.query.await(
        "SELECT id, item_name, count, metadata, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
        { dbId, steamId, charId }
    ) or {}
    local itemRow = rows[1]
    if itemRow and not IsInventoryStorageAccessible(steamId, charId, itemRow.container) then
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        return
    end
    if not itemRow or itemRow.item_name ~= "notebook" or (tonumber(itemRow.count) or 0) < 1 then
        TriggerClientEvent("thehunt_status:notify", src, "Блокнот", "Этот блокнот больше не находится у вас", "error")
        return
    end

    local meta = SafeDecodeMeta(itemRow.metadata)
    local pagesLeft = tonumber(meta.pages_left)
    if pagesLeft == nil then pagesLeft = 5 end

    if pagesLeft <= 0 then
        TriggerClientEvent("thehunt_status:notify", src, "Блокнот", "В блокноте больше не осталось страниц", "warning")
        return
    end

    -- Проверяем наличие текста в блокноте для переноса на вырванный лист
    local notebookHtml = type(meta.notebook_html) == "string" and meta.notebook_html or ""
    local pageHtml = ""
    local hasTransferredText = false

    if notebookHtml ~= "" and notebookHtml:match("%S") then
        pageHtml = TruncateHtmlToPageLimit(notebookHtml, PAGE_MAX_LINES, PAGE_MAX_CHARS)
        hasTransferredText = true
    end

    local pageMeta = {
        notebook_html = pageHtml,
        notebook_title = type(meta.notebook_title) == "string" and meta.notebook_title or "",
        notebook_updated_at = os.time()
    }

    -- Добавляем вырванный лист в инвентарь игрока
    AddOrStackItemToInventory(steamId, charId, "torn_page", 1, pageMeta, function(success, addedCount, remaining)
        if not success or (tonumber(addedCount) or 0) < 1 then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "В инвентаре нет свободного места для страницы (нужно 1x2)", "warning")
            return
        end

        pagesLeft = pagesLeft - 1

        if pagesLeft <= 0 then
            -- 5 страниц вырвано -> блокнот полностью израсходован и удаляется
            MySQL.query.await(
                "DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
                { dbId, steamId, charId }
            )
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            TriggerClientEvent("thehunt_status:notify", src, "Блокнот", "Вы вырвали последний лист. Блокнот закончился", "info")
        else
            meta.pages_left = pagesLeft
            if hasTransferredText then
                meta.notebook_html = ""
                meta.notebook_title = ""
            end

            MySQL.update.await(
                "UPDATE thehunt_inventories SET metadata = ? WHERE id = ? AND identifier = ? AND charidentifier = ?",
                { json.encode(meta), dbId, steamId, charId }
            )
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            TriggerClientEvent("thehunt_status:notify", src, "Блокнот", string.format("Лист вырван. Осталось страниц: %d из 5", pagesLeft), "success")
        end
    end)
end)

-- 9. Использование предмета игроком (ПКМ -> Использовать)
RegisterNetEvent("thehunt_items:useItem", function(itemName, dbId, clientStatus, dropId)
    local src = source
    if Player(src).state.huntPedEquipmentLocked then return end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local itemDef = Items.Get(itemName)

    if not itemDef or itemDef.canUse == false then
        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Этот предмет нельзя использовать")
        return
    end

    -- Проверка на переполненность (жажда / голод / здоровье)
    if itemName == "first_aid_kit" then
        TriggerClientEvent("thehunt_status:notify", src, "Медицина", "Аптечку можно использовать только через G на игроке без сознания", "info")
        return
    end

    if clientStatus and type(clientStatus) == "table" then
        local restoresThirst = (itemDef.thirst and itemDef.thirst > 0)
        local restoresHunger = (itemDef.hunger and itemDef.hunger > 0)
        local restoresHealth = (itemDef.healAmount and itemDef.healAmount > 0)

        local curThirst = clientStatus.thirst and tonumber(clientStatus.thirst) or 0
        local curHunger = clientStatus.hunger and tonumber(clientStatus.hunger) or 0
        local curHealth = clientStatus.health and tonumber(clientStatus.health) or 100
        local predHealth = clientStatus.predictedHealth and tonumber(clientStatus.predictedHealth) or curHealth

        -- Блокировка медицины, если здоровье уже 100% или уже прогнозируется на 100% в очереди
        if restoresHealth and (predHealth >= 100 or curHealth >= 100) then
            if predHealth >= 100 and curHealth < 100 then
                TriggerClientEvent("thehunt_status:notify", src, "Организм", "Здоровье уже восстанавливается до максимума", "error")
            else
                TriggerClientEvent("thehunt_status:notify", src, "Организм", "Вы полностью здоровы — перевязка не требуется", "error")
            end
            return
        end

        local thirstFull = (not restoresThirst) or (curThirst >= 1000)
        local hungerFull = (not restoresHunger) or (curHunger >= 1000)

        -- Если предмет восстанавливает еду/воду и ВСЕ восстанавливаемые параметры уже на максимуме (1000)
        if (restoresThirst or restoresHunger) and thirstFull and hungerFull then
            if restoresThirst and not restoresHunger then
                TriggerClientEvent("thehunt_status:notify", src, "Организм", "Вы не испытываете жажду — желудок полон", "error")
            elseif restoresHunger and not restoresThirst then
                TriggerClientEvent("thehunt_status:notify", src, "Организм", "Вы не испытываете голод — желудок полон", "error")
            else
                TriggerClientEvent("thehunt_status:notify", src, "Организм", "Вы не испытываете голод и жажду — желудок полон", "error")
            end
            return
        end
    end

    local dId = dropId and tonumber(dropId) or nil

    -- ИСПОЛЬЗОВАНИЕ ПРЕДМЕТА С ЗЕМЛИ (ИЗ СЕТКИ "РЯДОМ")
    if dId and ActiveDrops[dId] then
        local drop = ActiveDrops[dId]
        if drop.itemName ~= itemName then return end

        local ped = GetPlayerPed(src)
        local pedCoords = GetEntityCoords(ped)
        local dist = #(pedCoords - vector3(drop.x, drop.y, drop.z))
        if dist > 6.0 then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Предмет слишком далеко")
            return
        end

        local curCount = tonumber(drop.count) or 1

        if itemName == "bottle_water" then
            local thirstAmount = itemDef.thirst or 300
            TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Thirst", thirstAmount)
            TriggerClientEvent("thehunt_items:playDrinkAnimation", src)

            if curCount <= 1 then
                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
            else
                ActiveDrops[dId].count = curCount - 1
                MySQL.update("UPDATE thehunt_drops SET count = count - 1 WHERE id = ?", { dId })
            end

            -- Выдаем пустую бутылку в инвентарь игрока (или на землю если нет места)
            MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
                steamId, charId
            }, function(invRows)
                invRows = invRows or {}
                local emptyDef = Items.Get("bottle_empty") or { width = 1, height = 2, maxStack = 2 }
                local emptyMaxStack = emptyDef.maxStack or 2
                local addedToStack = false

                for _, r in ipairs(invRows) do
                    if r.item_name == "bottle_empty" and (tonumber(r.count) or 1) < emptyMaxStack then
                        MySQL.update("UPDATE thehunt_inventories SET count = count + 1 WHERE id = ?", { r.id }, function()
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду", "success")
                        end)
                        addedToStack = true
                        break
                    end
                end

                if not addedToStack then
                    local freeX, freeY, isRot = FindFreeInventorySlot(invRows, nil, nil, emptyDef.width or 1, emptyDef.height or 2)
                    if freeX then
                        MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count) VALUES (?, ?, 'main', ?, ?, ?, 'bottle_empty', 1)", {
                            steamId, charId, freeX, freeY, isRot and 1 or 0
                        }, function()
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду", "success")
                        end)
                    else
                        dropIdCounter = dropIdCounter + 1
                        local newDropId = dropIdCounter
                        ActiveDrops[newDropId] = {
                            id = newDropId,
                            itemName = "bottle_empty",
                            label = "Пустая бутылка",
                            count = 1,
                            x = drop.x,
                            y = drop.y,
                            z = drop.z,
                            metadata = {},
                            dropTime = os.time()
                        }
                        MySQL.insert("INSERT INTO thehunt_drops (id, item_name, count, x, y, z, dropped_by) VALUES (?, 'bottle_empty', 1, ?, ?, ?, ?)", {
                            newDropId, drop.x, drop.y, drop.z, steamId
                        })
                        TriggerClientEvent("thehunt_items:onDropCreated", -1, ActiveDrops[newDropId])
                        TriggerClientEvent("thehunt_items:refreshInventory", src)
                        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду. Пустая бутылка осталась на месте", "warning")
                    end
                end
            end)
        elseif itemName == "waterskin_water" or itemName == "flask_water" then
            local thirstAmount = itemDef.thirst or 300
            TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Thirst", thirstAmount)
            TriggerClientEvent("thehunt_items:playDrinkAnimation", src)

            local maxUses = (itemName == "waterskin_water" and 2 or 3)
            local emptyItem = (itemName == "waterskin_water" and "waterskin" or "flask")
            local emptyDef = Items.Get(emptyItem)
            local dropMeta = SafeDecodeMeta(drop.metadata)
            local curUses = tonumber(dropMeta.uses) or maxUses
            curUses = curUses - 1

            if curUses <= 0 then
                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)

                dropIdCounter = dropIdCounter + 1
                local newDropId = dropIdCounter
                local newDrop = {
                    id = newDropId,
                    itemName = emptyItem,
                    label = emptyDef and emptyDef.label or emptyItem,
                    count = 1,
                    x = drop.x,
                    y = drop.y,
                    z = drop.z,
                    metadata = {},
                    dropTime = os.time()
                }
                ActiveDrops[newDropId] = newDrop
                MySQL.insert("INSERT INTO thehunt_drops (id, item_name, count, x, y, z, dropped_by) VALUES (?, ?, 1, ?, ?, ?, ?)", {
                    newDropId, emptyItem, drop.x, drop.y, drop.z, steamId
                })
                TriggerClientEvent("thehunt_items:onDropCreated", -1, newDrop)
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы сделали последний глоток. %s опустел(-а)", itemDef.label or itemName), "success")
            else
                dropMeta.uses = curUses
                ActiveDrops[dId].metadata = dropMeta
                MySQL.update("UPDATE thehunt_drops SET metadata = ? WHERE id = ?", { json.encode(dropMeta), dId })
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы сделали глоток воды (осталось: %d из %d)", curUses, maxUses), "success")
            end
            TriggerClientEvent("thehunt_items:refreshInventory", src)
        else
            -- Потребление еды или расходуемых предметов с земли
            if itemDef.hunger and itemDef.hunger ~= 0 then
                TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Hunger", itemDef.hunger)
            end
            if itemDef.thirst and itemDef.thirst ~= 0 then
                TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Thirst", itemDef.thirst)
            end
            if itemDef.category == "food" or itemDef.hunger or itemDef.thirst then
                TriggerClientEvent("thehunt_items:playEatAnimation", src)
            end

            if curCount <= 1 then
                ActiveDrops[dId] = nil
                MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { dId })
                TriggerClientEvent("thehunt_items:onDropRemoved", -1, dId)
            else
                ActiveDrops[dId].count = curCount - 1
                MySQL.update("UPDATE thehunt_drops SET count = count - 1 WHERE id = ?", { dId })
            end
            TriggerClientEvent("thehunt_items:refreshInventory", src)

            if itemDef.hunger and itemDef.hunger < 0 then
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы съели «%s». Вам стало нехорошо...", itemDef.label or itemName), "warning")
            else
                local actionWord = (itemDef.category == "food" or itemDef.hunger) and "съели" or "использовали"
                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы %s «%s»", actionWord, itemDef.label or itemName), "success")
            end
        end
        return
    end

    -- ИСПОЛЬЗОВАНИЕ ПРЕДМЕТА ИЗ ИНВЕНТАРЯ ИГРОКА
    if not dbId then return end

    MySQL.query("SELECT * FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?", {
        tonumber(dbId), steamId, charId
    }, function(results)
        if not results or #results == 0 then
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Предмет не найден")
            return
        end

        local itemRow = results[1]
        if itemRow.item_name ~= itemName then return end
        if not IsInventoryStorageAccessible(steamId, charId, itemRow.container) then
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            return
        end

        local curCount = tonumber(itemRow.count) or 1

        if itemDef.externalUse and GetResourceState("hh_magic") == "started" then
            exports.hh_magic:BeginFromItem(src, itemName, tonumber(itemRow.id))
            return
        end

        -- Обработка бутылки с водой (bottle_water)
        if itemName == "bottle_water" then
            local thirstAmount = itemDef.thirst or 300
            -- Добавляем жажду (+300 из 1000)
            TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Thirst", thirstAmount)

            -- Запускаем анимацию питья у персонажа
            TriggerClientEvent("thehunt_items:playDrinkAnimation", src)

            if curCount <= 1 then
                -- Превращаем эту же ячейку в пустую бутылку
                MySQL.update("UPDATE thehunt_inventories SET item_name = 'bottle_empty', count = 1 WHERE id = ?", { itemRow.id }, function()
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду", "success")
                end)
            else
                -- Уменьшаем количество бутылок с водой на 1
                MySQL.update("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { itemRow.id }, function()
                    -- Ищем свободный слот или неполный стак пустых бутылок
                    MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
                        steamId, charId
                    }, function(invRows)
                        invRows = invRows or {}
                        local emptyDef = Items.Get("bottle_empty") or { width = 1, height = 2, maxStack = 2 }
                        local emptyMaxStack = emptyDef.maxStack or 2
                        local addedToStack = false

                        for _, r in ipairs(invRows) do
                            if r.item_name == "bottle_empty" and (tonumber(r.count) or 1) < emptyMaxStack then
                                MySQL.update("UPDATE thehunt_inventories SET count = count + 1 WHERE id = ?", { r.id }, function()
                                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду", "success")
                                end)
                                addedToStack = true
                                break
                            end
                        end

                        if not addedToStack then
                            local freeX, freeY, isRot = FindFreeInventorySlot(invRows, nil, nil, emptyDef.width or 1, emptyDef.height or 2)
                            if freeX then
                                MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count) VALUES (?, ?, 'main', ?, ?, ?, 'bottle_empty', 1)", {
                                    steamId, charId, freeX, freeY, isRot and 1 or 0
                                }, function()
                                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду", "success")
                                end)
                            else
                                -- Если нет места, дропаем на землю
                                local pPed = GetPlayerPed(src)
                                local pCoords = GetEntityCoords(pPed)
                                dropIdCounter = dropIdCounter + 1
                                local newDropId = dropIdCounter
                                ActiveDrops[newDropId] = {
                                    id = newDropId,
                                    itemName = "bottle_empty",
                                    label = "Пустая бутылка",
                                    count = 1,
                                    x = pCoords.x,
                                    y = pCoords.y,
                                    z = pCoords.z,
                                    metadata = {},
                                    dropTime = os.time()
                                }
                                MySQL.insert("INSERT INTO thehunt_drops (id, item_name, count, x, y, z, dropped_by) VALUES (?, 'bottle_empty', 1, ?, ?, ?, ?)", {
                                    newDropId, pCoords.x, pCoords.y, pCoords.z, steamId
                                })
                                TriggerClientEvent("thehunt_items:onDropCreated", -1, ActiveDrops[newDropId])
                                TriggerClientEvent("thehunt_items:refreshInventory", src)
                                TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Вы выпили воду. Пустая бутылка упала на землю", "warning")
                            end
                        end
                    end)
                end)
            end
        elseif itemName == "waterskin_water" or itemName == "flask_water" then
            local thirstAmount = itemDef.thirst or 300
            TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Thirst", thirstAmount)
            TriggerClientEvent("thehunt_items:playDrinkAnimation", src)

            local maxUses = (itemName == "waterskin_water" and 2 or 3)
            local emptyItem = (itemName == "waterskin_water" and "waterskin" or "flask")
            local itemMeta = SafeDecodeMeta(itemRow.metadata)
            local curUses = tonumber(itemMeta.uses) or maxUses
            curUses = curUses - 1

            if curUses <= 0 then
                MySQL.update("UPDATE thehunt_inventories SET item_name = ?, metadata = NULL WHERE id = ?", { emptyItem, itemRow.id }, function()
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы сделали последний глоток. %s опустел(-а)", itemDef.label or itemName), "success")
                end)
            else
                itemMeta.uses = curUses
                MySQL.update("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(itemMeta), itemRow.id }, function()
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы сделали глоток воды (осталось: %d из %d)", curUses, maxUses), "success")
                end)
            end
        else
            -- Потребление еды или расходуемых предметов из инвентаря
            if itemDef.healAmount and itemDef.healAmount > 0 then
                TriggerClientEvent("thehunt_items:applyBandageHeal", src, itemDef.healAmount, itemDef.healDuration or 30, itemDef.label or itemName)
            end
            if itemDef.hunger and itemDef.hunger ~= 0 then
                TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Hunger", itemDef.hunger)
            end
            if itemDef.thirst and itemDef.thirst ~= 0 then
                TriggerClientEvent("thehunt_core:client:changeMetabolism", src, "Thirst", itemDef.thirst)
            end
            if itemDef.category == "food" or itemDef.hunger or itemDef.thirst then
                TriggerClientEvent("thehunt_items:playEatAnimation", src)
            end

            if curCount <= 1 then
                MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { itemRow.id }, function()
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    if itemDef.hunger and itemDef.hunger < 0 then
                        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы съели «%s». Вам стало нехорошо...", itemDef.label or itemName), "warning")
                    elseif itemDef.healAmount and itemDef.healAmount > 0 then
                        TriggerClientEvent("thehunt_status:notify", src, "Медицина", string.format("Вы наложили «%s». Здоровье восстанавливается...", itemDef.label or itemName), "success")
                    else
                        local actionWord = (itemDef.category == "food" or itemDef.hunger) and "съели" or "использовали"
                        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы %s «%s»", actionWord, itemDef.label or itemName), "success")
                    end
                end)
            else
                MySQL.update("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { itemRow.id }, function()
                    TriggerClientEvent("thehunt_items:refreshInventory", src)
                    if itemDef.hunger and itemDef.hunger < 0 then
                        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы съели «%s». Вам стало нехорошо...", itemDef.label or itemName), "warning")
                    elseif itemDef.healAmount and itemDef.healAmount > 0 then
                        TriggerClientEvent("thehunt_status:notify", src, "Медицина", string.format("Вы наложили «%s». Здоровье восстанавливается...", itemDef.label or itemName), "success")
                    else
                        local actionWord = (itemDef.category == "food" or itemDef.hunger) and "съели" or "использовали"
                        TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", string.format("Вы %s «%s»", actionWord, itemDef.label or itemName), "success")
                    end
                end)
            end
        end
    end)
end)

-- =================================================================
-- ЭКСПОРТЫ API ДЛЯ ВСЕГО ПРОЕКТА
-- =================================================================

exports('FindFreeSlot', function(items, itemW, itemH, cols, rows)
    return FindFreeInventorySlot(items or {}, cols, rows, itemW or 1, itemH or 1)
end)

exports('CanFitItem', function(items, itemName, count)
    local itemDef = Items.Get(itemName)
    if not itemDef then return false end
    local w = itemDef.width or 1
    local h = itemDef.height or 1
    local freeX, freeY, isRot = FindFreeInventorySlot(items or {}, nil, nil, w, h)
    return freeX ~= nil, freeX, freeY, isRot
end)

exports('GiveItem', function(src, itemName, count, metadata, cb)
    do
        local steamId, charId = GetPlayerIdentifiersVORP(src)
        if not Items.Get(itemName) then return false end
        AddOrStackItemToInventory(steamId, charId, itemName, count, metadata, function(success, addedCount, remaining)
            if success then TriggerClientEvent("thehunt_items:refreshInventory", src) end
            if cb then cb(success, addedCount, remaining) end
        end)
        return true
    end

    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local itemDef = Items.Get(itemName)
    if not itemDef then return false end

    MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
        steamId, charId
    }, function(invRows)
        invRows = invRows or {}
        local itemW = itemDef.width or 1
        local itemH = itemDef.height or 1
        local maxStack = itemDef.maxStack or 1
        local givenCount = count or 1

        -- 1. Пробуем добавить в неполный стак
        if maxStack > 1 then
            for _, r in ipairs(invRows) do
                if r.item_name == itemName and (tonumber(r.count) or 1) < maxStack then
                    local cur = tonumber(r.count) or 1
                    local canAdd = math.min(givenCount, maxStack - cur)
                    if canAdd > 0 then
                        MySQL.update("UPDATE thehunt_inventories SET count = count + ? WHERE id = ?", { canAdd, r.id }, function()
                            TriggerClientEvent("thehunt_items:refreshInventory", src)
                        end)
                        givenCount = givenCount - canAdd
                        if givenCount <= 0 then return end
                    end
                end
            end
        end

        -- 2. Ищем свободный слот
        local freeX, freeY, isRot = FindFreeInventorySlot(invRows, nil, nil, itemW, itemH)
        if freeX then
            MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', ?, ?, ?, ?, ?, ?)", {
                steamId, charId, freeX, freeY, isRot and 1 or 0, itemName, givenCount, json.encode(metadata or {})
            }, function()
                TriggerClientEvent("thehunt_items:refreshInventory", src)
            end)
        else
            -- 3. Если инвентарь полон — спавним дроп под ногами
            local ped = GetPlayerPed(src)
            local pCoords = GetEntityCoords(ped)
            dropIdCounter = dropIdCounter + 1
            local newDropId = dropIdCounter
            ActiveDrops[newDropId] = {
                id = newDropId,
                itemName = itemName,
                label = (metadata and metadata.label) or itemDef.label or itemName,
                count = givenCount,
                x = pCoords.x,
                y = pCoords.y,
                z = pCoords.z,
                metadata = metadata or {},
                dropTime = os.time()
            }
            MySQL.insert("INSERT INTO thehunt_drops (id, item_name, count, x, y, z, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
                newDropId, itemName, givenCount, pCoords.x, pCoords.y, pCoords.z, steamId
            })
            TriggerClientEvent("thehunt_items:onDropCreated", -1, ActiveDrops[newDropId])
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            TriggerClientEvent("thehunt_status:notify", src, "Инвентарь", "Инвентарь полон. Предмет упал на землю", "warning")
        end
    end)
    return true
end)

-- Экспорт: Полное удаление всех ключей от указанного дома (из инвентарей, мира и построек)
exports('DeleteHouseKeys', function(houseId)
    local targetHouseId = tonumber(houseId)
    if not targetHouseId then return end

    -- 1. Удаление из всех инвентарей (thehunt_inventories)
    MySQL.query("SELECT id, identifier, charidentifier, metadata FROM thehunt_inventories WHERE item_name = 'house_key'", {}, function(invRows)
        if invRows and #invRows > 0 then
            local affectedIdentifiers = {}
            for _, r in ipairs(invRows) do
                local meta = r.metadata
                if type(meta) == "string" then meta = json.decode(meta) end
                if meta and (tonumber(meta.house_id) == targetHouseId or tonumber(meta.houseId) == targetHouseId) then
                    MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { r.id })
                    affectedIdentifiers[r.identifier] = true
                end
            end

            -- Обновляем инвентарь для всех онлайн игроков, у кого был изъят ключ
            local players = GetPlayers()
            for _, pId in ipairs(players) do
                local pSrc = tonumber(pId)
                if pSrc then
                    local ch = exports.thehunt_core:GetCharacter(pSrc)
                    local identifier = ch and ch.identifier or exports.thehunt_core:GetPlayerIdentifier(pSrc)
                    if identifier and affectedIdentifiers[identifier] then
                        TriggerClientEvent("thehunt_items:refreshInventory", pSrc)
                    end
                end
            end
        end
    end)

    -- 2. Удаление из активных дропов на земле (thehunt_drops и ActiveDrops)
    local dropsChanged = false
    for dId, drop in pairs(ActiveDrops) do
        if drop.itemName == 'house_key' then
            local meta = drop.metadata
            if type(meta) == "string" then meta = json.decode(meta) end
            if meta and (tonumber(meta.house_id) == targetHouseId or tonumber(meta.houseId) == targetHouseId) then
                ActiveDrops[dId] = nil
                dropsChanged = true
            end
        end
    end
    MySQL.query("SELECT id, metadata FROM thehunt_drops WHERE item_name = 'house_key'", {}, function(dropRows)
        if dropRows and #dropRows > 0 then
            for _, r in ipairs(dropRows) do
                local meta = r.metadata
                if type(meta) == "string" then meta = json.decode(meta) end
                if meta and (tonumber(meta.house_id) == targetHouseId or tonumber(meta.houseId) == targetHouseId) then
                    MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { r.id })
                end
            end
        end
    end)
    if dropsChanged then
        TriggerClientEvent("thehunt_items:syncGroundDrops", -1, ActiveDrops)
    end

    -- 3. Удаление из размещенных в мире объектов (thehunt_placed_props)
    MySQL.query("SELECT id, metadata FROM thehunt_placed_props WHERE item_name = 'house_key'", {}, function(placedRows)
        if placedRows and #placedRows > 0 then
            for _, r in ipairs(placedRows) do
                local meta = r.metadata
                if type(meta) == "string" then meta = json.decode(meta) end
                if meta and (tonumber(meta.house_id) == targetHouseId or tonumber(meta.houseId) == targetHouseId) then
                    TriggerEvent("thehunt_builder:deletePlacedObjectDirectly", tonumber(r.id))
                end
            end
        end
    end)
end)

-- Экспорт прямой выдачи предмета игроку (с поддержкой метаданных)
exports("GiveItem", function(targetSrc, itemName, count, metadata, cb)
    do
        local src = tonumber(targetSrc)
        if not src or src <= 0 then return false end
        local targetPed = GetPlayerPed(src)
        if not DoesEntityExist(targetPed) or not Items.Get(itemName) then return false end
        local targetSteamId, targetCharId = GetPlayerIdentifiersVORP(src)
        if not targetSteamId or not targetCharId then return false end
        AddOrStackItemToInventory(targetSteamId, targetCharId, itemName, count, metadata, function(success, addedCount, remaining)
            if success then TriggerClientEvent("thehunt_items:refreshInventory", src) end
            if cb then cb(success, addedCount, remaining) end
        end)
        return true
    end

    local src = tonumber(targetSrc)
    if not src or src <= 0 then return false end

    local targetPed = GetPlayerPed(src)
    if not DoesEntityExist(targetPed) then return false end

    local itemDef = Items.Get(itemName)
    if not itemDef then return false end

    local targetSteamId, targetCharId = GetPlayerIdentifiersVORP(src)
    if not targetSteamId or not targetCharId then return false end

    local totalRequested = tonumber(count) or 1
    local maxStack = itemDef.maxStack or 1
    local itemW = itemDef.width or 1
    local itemH = itemDef.height or 1
    local metaObj = CleanItemMetadata(metadata)
    local hasMeta = next(metaObj) ~= nil
    local metaJson = hasMeta and json.encode(metaObj) or nil

    MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
        targetSteamId, targetCharId
    }, function(existing)
        existing = existing or {}
        local remaining = totalRequested

        -- Если предмет стакается и не имеет уникальной меты — заполняем существующие слоты
        if maxStack > 1 and not hasMeta then
            for _, row in ipairs(existing) do
                if remaining <= 0 then break end
                local rMeta = CleanItemMetadata(row.metadata)
                if row.item_name == itemName and not next(rMeta) then
                    local curCount = tonumber(row.count) or 1
                    local space = maxStack - curCount
                    if space > 0 then
                        local addPortion = math.min(remaining, space)
                        row.count = curCount + addPortion
                        MySQL.update("UPDATE thehunt_inventories SET count = ? WHERE id = ?", { row.count, row.id })
                        remaining = remaining - addPortion
                    end
                end
            end
        end

        -- Оставшиеся предметы (или уникальные предметы/ключи) кладем в новые слоты
        while remaining > 0 do
            local portion = math.min(remaining, maxStack)
            local freeX, freeY, isRot = FindFreeInventorySlot(existing, nil, nil, itemW, itemH)
            if not freeX then
                break
            end

            table.insert(existing, {
                item_name = itemName,
                slot_x = freeX,
                slot_y = freeY,
                is_rotated = isRot and 1 or 0,
                count = portion,
                metadata = metaJson
            })

            MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count, metadata) VALUES (?, ?, 'main', ?, ?, ?, ?, ?, ?)", {
                targetSteamId,
                targetCharId,
                freeX,
                freeY,
                isRot and 1 or 0,
                itemName,
                portion,
                metaJson
            })

            remaining = remaining - portion
        end

        TriggerClientEvent("thehunt_items:refreshInventory", src)
    end)
    return true
end)

-- =================================================================
-- ЦЕНТРАЛИЗОВАННЫЙ ЭКСПОРТ И СОБЫТИЕ ДЛЯ СОЗДАНИЯ ДРОПА В МИРЕ
-- (С автоматическим таймером жизни 1 минута и полной синхронизацией)
-- =================================================================
local function InternalCreateWorldDrop(itemName, count, coords, metadata, droppedBy, cb)
    local itemDef = Items.Get(itemName) or { label = itemName }
    local dropCount = tonumber(count) or 1
    local metaObj = CleanItemMetadata(metadata)
    local metaJson = next(metaObj) and json.encode(metaObj) or nil

    local x = tonumber(coords.x) or 0.0
    local y = tonumber(coords.y) or 0.0
    local z = tonumber(coords.z) or 0.0

    MySQL.insert("INSERT INTO thehunt_drops (item_name, count, x, y, z, metadata, dropped_by) VALUES (?, ?, ?, ?, ?, ?, ?)", {
        itemName,
        dropCount,
        x, y, z,
        metaJson,
        droppedBy or "world"
    }, function(insertId)
        local dId = tonumber(insertId) or math.random(10000, 99999)
        local dropData = {
            id = dId,
            itemName = itemName,
            label = (metaObj and metaObj.label) or itemDef.label or itemName,
            count = dropCount,
            x = x,
            y = y,
            z = z,
            metadata = metaObj or {},
            dropTime = os.time()
        }
        ActiveDrops[dId] = dropData

        TriggerClientEvent("thehunt_items:onDropCreated", -1, dropData)
        if cb then cb(dId, dropData) end
    end)
end

exports("CreateWorldDrop", function(itemName, count, coords, metadata, droppedBy, cb)
    InternalCreateWorldDrop(itemName, count, coords, metadata, droppedBy, cb)
end)

exports("CreateDrop", function(itemName, count, coords, metadata, droppedBy, cb)
    InternalCreateWorldDrop(itemName, count, coords, metadata, droppedBy, cb)
end)

AddEventHandler("thehunt_items:createDrop", function(itemName, count, metadata, coords, droppedBy, cb)
    InternalCreateWorldDrop(itemName, count, coords, metadata, droppedBy, cb)
end)

-- Удаляет drop тем же путём, что и обычный подбор: БД, серверный кэш и props
-- обновляются у всех клиентов. Добавочный export, существующую механику не меняет.
exports("RemoveWorldDrop", function(dropId)
    local id = tonumber(dropId)
    if not id or not ActiveDrops[id] then return false end
    ActiveDrops[id] = nil
    MySQL.query("DELETE FROM thehunt_drops WHERE id = ?", { id })
    TriggerClientEvent("thehunt_items:onDropRemoved", -1, id)
    return true
end)

-- Server-only bridge for atomic loot/drop stack transfers. Share the existing
-- pickup and merge locks and refresh ActiveDrops before releasing either lock.
exports("AcquireLootDropLock", function(dropId, token)
    local id = tonumber(dropId)
    if not id or not token or not ActiveDrops[id] or PickupDropLocks[id] or MergeDropLocks[id] then return nil end
    PickupDropLocks[id], MergeDropLocks[id] = token, token
    return ActiveDrops[id]
end)

exports("ReleaseLootDropLock", function(dropId, token)
    local id = tonumber(dropId)
    if not id or PickupDropLocks[id] ~= token or MergeDropLocks[id] ~= token then return false end
    local ok, err = pcall(function()
        local rows = MySQL.query.await("SELECT count FROM thehunt_drops WHERE id = ?", {id})
        local count = rows and rows[1] and tonumber(rows[1].count) or 0
        if count <= 0 then
            ActiveDrops[id] = nil
            TriggerClientEvent("thehunt_items:onDropRemoved", -1, id)
        elseif ActiveDrops[id] then
            ActiveDrops[id].count = count
            TriggerClientEvent("thehunt_items:onDropUpdated", -1, id, count)
        end
    end)
    if ok then
        PickupDropLocks[id], MergeDropLocks[id] = nil, nil
    else
        -- Retain the lock until the authoritative cache can be refreshed.
        print('[thehunt_items] Loot drop sync failed; drop remains locked: ' .. tostring(err))
    end
    return ok
end)

RegisterServerEvent("thehunt_items:createWorldDrop", function(itemName, count, coords, metadata, droppedBy)
    InternalCreateWorldDrop(itemName, count, coords, metadata, droppedBy)
end)

-- Автоматическая очистка удалённых из игры предметов (часы)
CreateThread(function()
    MySQL.query("DELETE FROM thehunt_inventories WHERE item_name IN ('clothing_watch', 'watch')")
    MySQL.query("DELETE FROM thehunt_drops WHERE item_name IN ('clothing_watch', 'watch')")
end)

exports("RemoveStackCount", function(src, dbId, amount)
    amount = tonumber(amount) or 1
    dbId = tonumber(dbId)
    src = tonumber(src)
    if not src or not dbId or amount < 1 then
        return false
    end
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or not charId then
        return false
    end
    local rows = MySQL.query.await(
        "SELECT count FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
        { dbId, steamId, charId }
    ) or {}
    local row = rows[1]
    if not row then
        return false
    end
    local count = tonumber(row.count) or 0
    if count <= amount then
        MySQL.query.await("DELETE FROM thehunt_inventories WHERE id = ?", { dbId })
    else
        MySQL.update.await("UPDATE thehunt_inventories SET count = count - ? WHERE id = ?", { amount, dbId })
    end
    TriggerClientEvent("thehunt_items:refreshInventory", src)
    return true
end)
