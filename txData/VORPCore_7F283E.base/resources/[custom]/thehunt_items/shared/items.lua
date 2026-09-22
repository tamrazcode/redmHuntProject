-- =================================================================
-- HUNT: Hard RP — Core Items System | Shared Items Registry
-- =================================================================

Items = {}
Items.Registry = {}

-- Таблица цветов редкости предметов
Items.RarityColors = {
    white  = { hex = "#ffffff", rgba = "rgba(255, 255, 255, 0.14)", border = "rgba(255, 255, 255, 0.48)", label = "Обычный" },
    green  = { hex = "#22c55e", rgba = "rgba(34, 197, 94, 0.12)",    border = "rgba(34, 197, 94, 0.52)",   label = "Необычный" },
    blue   = { hex = "#3b82f6", rgba = "rgba(59, 130, 246, 0.12)",   border = "rgba(59, 130, 246, 0.54)",  label = "Редкий" },
    purple = { hex = "#a855f7", rgba = "rgba(168, 85, 247, 0.14)",  border = "rgba(168, 85, 247, 0.54)",  label = "Эпический" },
    orange = { hex = "#f97316", rgba = "rgba(249, 115, 22, 0.12)",   border = "rgba(249, 115, 22, 0.54)",  label = "Легендарный" },
    red    = { hex = "#ef4444", rgba = "rgba(239, 68, 68, 0.12)",    border = "rgba(239, 68, 68, 0.54)",   label = "Мифический" }
}

-- Категории предметов проекта
Items.Categories = {
    food      = { id = "food",      label = "Съедобное",           icon = "food" },
    item      = { id = "item",      label = "Предмет",             icon = "item" },
    material  = { id = "material",  label = "Материалы",           icon = "material" },
    medical   = { id = "medical",   label = "Медицина",            icon = "medical" },
    survival  = { id = "survival",  label = "Выживание",           icon = "survival" },
    melee     = { id = "melee",     label = "Холодное оружие",     icon = "melee" },
    gun       = { id = "gun",       label = "Огнестрельное оружие", icon = "gun" },
    furniture = { id = "furniture", label = "Предметы интерьера",  icon = "furniture" },
    storage   = { id = "storage",   label = "Хранение",            icon = "storage" },
    clothing  = { id = "clothing",  label = "Одежда",              icon = "clothing" },
    key       = { id = "key",       label = "Ключи",               icon = "key" }
}

-- Only garments that can realistically carry equipment receive a child grid.
-- The irregular row layouts are intentional: a coat is not a rectangular
-- backpack and small garments only offer pockets.
Items.ClothingSlots = {
    Hat = { label = "Шляпа", icon = "clothing_hat", storage = { cols = 3, rows = 1, rowWidths = { 3 } }, weight = 0.0 },
    Shirt = { label = "Рубашка", icon = "clothing_shirt", storage = { cols = 4, rows = 2, rowWidths = { 4, 4 } }, weight = 0.0 },
    Vest = { label = "Жилет", icon = "clothing_vest", storage = { cols = 4, rows = 2, rowWidths = { 4, 4 } }, weight = 0.0 },
    Coat = { label = "Пальто", icon = "clothing_coat", storage = { cols = 6, rows = 3, rowWidths = { 6, 6, 6 } }, weight = 0.0 },
    Poncho = { label = "Пончо", icon = "clothing_poncho", storage = { cols = 4, rows = 2, rowWidths = { 4, 4 } }, weight = 0.0 },
    Pant = { label = "Штаны", icon = "clothing_pants", storage = { cols = 4, rows = 2, rowWidths = { 4, 4 } }, weight = 0.0 },
    Skirt = { label = "Юбка", icon = "clothing_skirt", storage = { cols = 2, rows = 1, rowWidths = { 2 } }, weight = 0.0 },
    Dress = { label = "Платье", icon = "clothing_dress", storage = { cols = 4, rows = 2, rowWidths = { 4, 4 } }, weight = 0.0 },
    Gunbelt = { label = "Оружейный пояс", icon = "clothing_gunbelt", storage = { cols = 2, rows = 1, rowWidths = { 2 } }, weight = 0.0 },
    Satchels = { label = "Сумка", icon = "clothing_satchels", storage = { cols = 4, rows = 4, rowWidths = { 4, 4, 4, 4 } }, weight = 0.0 },
}

-- Remaining creator wardrobe categories are wearable items too, but do not
-- create storage space.  Every item remains stack-size one and can be dropped.
local ClothingWearables = {
    "Hat", "Mask", "EyeWear", "NeckWear", "Shirt", "Vest", "Coat", "CoatClosed", "Poncho", "Cloak",
    "Pant", "Skirt", "Dress", "Boots", "Spurs", "Spats", "Chap", "Gunbelt", "Holster", "Belt",
    "Suspender", "Glove", "Gauntlets", "Accessories", "Bracelet", "RingLh", "RingRh", "Satchels"
}

Items.ClothingSizes = {
    -- Large garments
    Hat = { 2, 2 }, Shirt = { 2, 2 }, Vest = { 2, 2 }, Coat = { 2, 2 }, CoatClosed = { 2, 2 }, Poncho = { 2, 2 }, Cloak = { 2, 2 },
    Pant = { 2, 2 }, Skirt = { 2, 2 }, Dress = { 2, 2 }, Boots = { 2, 2 }, Chap = { 2, 2 }, Satchels = { 2, 2 },
    -- Medium garments and equipment
    NeckWear = { 2, 1 }, Gunbelt = { 2, 1 }, Holster = { 2, 1 }, Belt = { 2, 1 }, Suspender = { 2, 1 },
    Glove = { 2, 1 }, Gauntlets = { 2, 1 }, Accessories = { 2, 1 }, Spurs = { 2, 1 },
}

-- Базовый вес элементов одежды и носимой экипировки (в кг)
Items.ClothingWeights = {
    Hat = 0.0, Mask = 0.0, EyeWear = 0.0, NeckWear = 0.0, Shirt = 0.0, Vest = 0.0,
    Coat = 0.0, CoatClosed = 0.0, Poncho = 0.0, Cloak = 0.0, Pant = 0.0, Skirt = 0.0,
    Dress = 0.0, Boots = 0.0, Spurs = 0.0, Spats = 0.0, Chap = 0.0, Gunbelt = 0.0,
    Holster = 0.0, Belt = 0.0, Suspender = 0.0, Glove = 0.0, Gauntlets = 0.0,
    Accessories = 0.0, Bracelet = 0.0, RingLh = 0.0, RingRh = 0.0, Satchels = 0.0
}

-- Конфигурация размеров сеток инвентаря проекта
Items.Grids = {
    main = {
        label = "Основной",
        cols = 7,
        rows = 4
    },
    ground = {
        label = "Рядом",
        cols = 9,
        rows = 5
    }
}

function Items.GetGridCols(container)
    local c = container or "main"
    return (Items.Grids[c] and Items.Grids[c].cols) or 7
end

function Items.GetGridRows(container)
    local c = container or "main"
    return (Items.Grids[c] and Items.Grids[c].rows) or 4
end

-- Функция регистрации предмета в системе
function Items.Register(name, data)
    if not name or not data then return end
    data.name = name
    data.insulation = data.clothingSlot and HuntInsulation[data.clothingSlot] or nil
    data.insulationLabel = data.clothingSlot and HuntGetInsulationLabel(data.clothingSlot) or nil
    data.label = data.label or name
    data.category = data.category or "item"
    data.width = data.width or 1
    data.height = data.height or 1
    data.maxStack = data.maxStack or 1
    if data.rarity == "yellow" then data.rarity = "purple" end
    data.rarity = data.rarity or "white"
    data.weight = data.weight or 0.1
    data.propModel = data.propModel or "p_crate26x_b"
    data.dropModel = data.dropModel or "p_crate26x_b"
    data.actions = data.actions or { "place", "give", "drop" }
    if data.canUse ~= nil then
        data.canUse = data.canUse
    else
        data.canUse = false
        for _, a in ipairs(data.actions) do
            if a == "use" then data.canUse = true break end
        end
    end

    Items.Registry[name] = data
end

function Items.Get(name)
    return Items.Registry[name]
end

-- Empty garments may be packed in bags; ordinary garment pockets stay non-nesting.
function Items.CanPackClothing(def, parentDef, metadata, hasChildren)
    if not def or not def.clothing then return true end
    if def.isContainer or def.containerStorage or def.isBackpack then return false end
    if not parentDef or not (parentDef.isBackpack or parentDef.clothingSlot == 'Satchels'
        or (parentDef.containerStorage and not parentDef.containerStorage.keyOnly)) then return false end
    if hasChildren then return false end
    for _, key in ipairs({ 'clothing_contents', 'container_contents' }) do
        local contents = type(metadata) == 'table' and metadata[key]
        if contents ~= nil and (type(contents) ~= 'table' or next(contents) ~= nil) then return false end
    end
    return true
end

local ClothingLabels = {
    Hat = "Шляпа", Mask = "Маска", EyeWear = "Очки", NeckWear = "Шея", Shirt = "Рубашка", Vest = "Жилет",
    Coat = "Пальто", CoatClosed = "Закрытое пальто", Poncho = "Пончо", Cloak = "Плащ", Pant = "Штаны", Skirt = "Юбка",
    Dress = "Платье", Boots = "Сапоги", Spurs = "Шпоры", Spats = "Гамаши", Chap = "Чапсы", Gunbelt = "Оружейный пояс",
    Holster = "Кобура", Belt = "Ремень", Suspender = "Подтяжки", Glove = "Перчатки",
    Gauntlets = "Наручи", Accessories = "Аксессуары", Bracelet = "Браслет", RingLh = "Кольцо (Л)",
    RingRh = "Кольцо (П)", Satchels = "Сумка"
}

-- Register after Items.Register is available.  Variants are represented by
-- per-instance metadata (component hash, tint and creator button label), so
-- no two pieces can stack or lose their identity.
for _, slot in ipairs(ClothingWearables) do
    local storageDef = Items.ClothingSlots[slot]
    local size = Items.ClothingSizes[slot] or { 1, 1 }
    local slotLower = string.lower(slot)
    local itemName = "clothing_" .. slotLower
    Items.Register(itemName, {
        label = (storageDef and storageDef.label) or ClothingLabels[slot] or slot,
        description = "Элемент одежды персонажа.", category = "clothing", width = size[1], height = size[2],
        maxStack = 1, rarity = "white", weight = 0.0,
        propModel = "p_crate26x_b", dropModel = "p_crate26x_b", icon = itemName,
        clothing = true, clothingSlot = slot, storage = storageDef and storageDef.storage or nil,
        actions = { "give", "drop" }
    })
end

-- Алиас для pants
if Items.Registry["clothing_pant"] then
    Items.Register("clothing_pants", Items.Registry["clothing_pant"])
end

function Items.GetAll()
    return Items.Registry
end

function Items.GetCategory(catName)
    return Items.Categories[catName] or Items.Categories.item
end

function Items.GetRarity(rarityName)
    if rarityName == "yellow" then rarityName = "purple" end
    return Items.RarityColors[rarityName] or Items.RarityColors.white
end

function Items.GetByPropModel(modelHash)
    if not modelHash then return nil, nil end
    local numHash = tonumber(modelHash)
    local strModel = tostring(modelHash):lower():gsub("%s+", "")

    for name, def in pairs(Items.Registry) do
        if def.propModel then
            local pStr = tostring(def.propModel):lower():gsub("%s+", "")
            if pStr == strModel or name:lower() == strModel then
                return name, def
            end

            local defHash = tonumber(def.propModel) or (joaat and joaat(def.propModel)) or (GetHashKey and GetHashKey(def.propModel))
            if numHash and defHash then
                if defHash == numHash then
                    return name, def
                end
                -- Сравнение с учетом знака 32-битного числа
                local uDef = (defHash < 0) and (defHash + 0x100000000) or defHash
                local uNum = (numHash < 0) and (numHash + 0x100000000) or numHash
                if uDef == uNum or uDef == numHash or defHash == uNum then
                    return name, def
                end
            end
        end
    end
    return nil, nil
end

-- =================================================================
-- БАЗОВЫЙ РЕЕСТР ПРЕДМЕТОВ
-- =================================================================

-- 1. Пустая бутылка (1x2, белое качество, без использования)
Items.Register("bottle_empty", {
    label = "Пустая бутылка",
    description = "Стеклянная пустая бутылка без содержимого.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 0.3,
    propModel = "p_bottle01x",
    dropModel = "p_bottle01x",
    icon = "bottle_empty",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- Блокнот: уникальная запись хранится в metadata конкретного экземпляра.
Items.Register("notebook", {
    label = "Блокнот",
    description = "Личный блокнот для записей, заметок и найденных сведений.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.2,
    propModel = "s_lev_journal_book",
    dropModel = "s_lev_journal_book",
    icon = "notebook",
    canUse = false,
    actions = { "read", "write", "place", "give", "drop" }
})

-- Вырванная страница: аналогична блокноту, текст хранится в metadata экземпляра.
Items.Register("torn_page", {
    label = "Вырванная страница",
    description = "Вырванная страница для записей, заметок и найденных сведений.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.05,
    propModel = "p_cs_ripped_paper01cx",
    dropModel = "p_cs_ripped_paper01cx",
    icon = "torn_page",
    canUse = false,
    actions = { "read", "write", "place", "give", "drop" }
})

-- 2. Бутылка с водой (1x2, зеленое качество, утоляет 30% жажды, превращается в пустую бутылку)
Items.Register("bottle_water", {
    label = "Бутылка с водой",
    description = "Стеклянная бутылка, наполненная чистой питьевой водой. Утоляет жажду.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.8,
    propModel = "p_bottle01x",
    dropModel = "p_bottle01x",
    icon = "bottle_water",
    canUse = true,
    thirst = 300,
    actions = { "place", "give", "drop" }
})

-- 3. Яблоко (1x1, зеленое качество, макс. стак 6, вес 0.2 кг, восполняет 120 сытости)
Items.Register("apple", {
    label = "Яблоко",
    description = "Свежее сочное яблоко. Слегка утоляет голод.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 6,
    rarity = "green",
    weight = 0.2,
    propModel = "p_apple01x",
    dropModel = "p_apple01x",
    icon = "apple",
    canUse = true,
    hunger = 120,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 4. Манго (1x1, зеленое качество, макс. стак 6, вес 0.2 кг, восполняет 100 сытости и 50 жажды)
Items.Register("mango", {
    label = "Манго",
    description = "Спелый тропический манго. Отлично утоляет голод и жажду.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 6,
    rarity = "green",
    weight = 0.2,
    propModel = "p_mango01x",
    dropModel = "p_mango01x",
    icon = "mango",
    canUse = true,
    hunger = 100,
    thirst = 50,
    actions = { "use", "place", "give", "drop" }
})

-- 5. Груша (1x1, зеленое качество, макс. стак 6, вес 0.15 кг, восполняет 60 сытости и 40 жажды)
Items.Register("pear", {
    label = "Груша",
    description = "Сочная сладкая груша. Слегка утоляет голод и освежает.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 6,
    rarity = "green",
    weight = 0.15,
    propModel = "p_pear_01x",
    dropModel = "p_pear_01x",
    icon = "pear",
    canUse = true,
    hunger = 60,
    thirst = 40,
    actions = { "use", "place", "give", "drop" }
})

-- =================================================================
-- МАТЕРИАЛЫ И СТРОИТЕЛЬНЫЕ РЕСУРСЫ
-- =================================================================

-- 6. Древесина (2x3, белое качество, макс. стак 3, вес 4.5 кг)
Items.Register("wood_log", {
    label = "Древесина",
    description = "Тяжелое цельное бревно. Основной материал для строительства и растопки.",
    category = "material",
    width = 2,
    height = 3,
    maxStack = 3,
    rarity = "white",
    weight = 4.5,
    propModel = "p_woodpiece02x",
    dropModel = "p_woodpiece02x",
    icon = "wood_log",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 7. Доска (1x3, белое качество, макс. стак 5, вес 1.2 кг)
Items.Register("wood_plank", {
    label = "Доска",
    description = "Обработанная строительная доска из прочной древесины.",
    category = "material",
    width = 1,
    height = 3,
    maxStack = 5,
    rarity = "white",
    weight = 1.2,
    propModel = "p_debrisboard12x",
    dropModel = "p_debrisboard12x",
    icon = "wood_plank",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 8. Камень (2x2, белое качество, макс. стак 4, вес 3.0 кг)
Items.Register("stone", {
    label = "Камень",
    description = "Прочный природный булыжник, пригодный для кладки и фундамента.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "white",
    weight = 3.0,
    propModel = "hea_rock_scree_sim_01",
    dropModel = "hea_rock_scree_sim_01",
    icon = "stone",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 9. Железная руда (2x2, зеленое качество, макс. стак 4, вес 3.5 кг)
Items.Register("iron_ore", {
    label = "Железная руда",
    description = "Кусок неочищенной горной породы с богатыми прожилками железа.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "green",
    weight = 3.5,
    propModel = "mp006_p_xmas_coal01x",
    dropModel = "mp006_p_xmas_coal01x",
    icon = "iron_ore",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 10. Железный слиток (1x2, белое качество, макс. стак 5, вес 2.0 кг)
Items.Register("iron_ingot", {
    label = "Железный слиток",
    description = "Переплавленный и очищенный слиток железа для кузнечного дела и ковки ключей.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 2.0,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "iron_ingot",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 11. Стекло (1x2, белое качество, макс. стак 4, вес 0.8 кг)
Items.Register("glass", {
    label = "Стекло",
    description = "Лист закаленного прозрачного стекла для окон и емкостей.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 4,
    rarity = "white",
    weight = 0.8,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "glass",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 12. Ключ от двери (1x1, синее качество, макс. стак 1, вес 0.05 кг)
Items.Register("house_key", {
    label = "Ключ от двери",
    description = "Кованый ключ. Позволяет запирать и отпирать двери подходящего строения.",
    category = "key",
    width = 1,
    height = 1,
    maxStack = 1,
    rarity = "blue",
    weight = 0.05,
    propModel = "p_key02x",
    dropModel = "p_key02x",
    icon = "house_key",
    canUse = false,
    actions = { "give", "drop" }
})

-- =================================================================
-- МЯСО (СЫРОЕ И ЖАРЕНОЕ — ЗЕЛЕНОЕ КАЧЕСТВО)
-- =================================================================

-- 13. Мясо птицы
Items.Register("meat_bird_raw", {
    label = "Сырое мясо птицы",
    description = "Сырая разделанная птица. В сыром виде употреблять опасно для здоровья.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "green",
    weight = 0.3,
    propModel = "p_cs_duckmeat01x",
    dropModel = "p_cs_duckmeat01x",
    icon = "meat_bird_raw",
    canUse = true,
    hunger = -120,
    thirst = -100,
    actions = { "use", "place", "give", "drop" }
})
Items.Register("meat_bird_cooked", {
    label = "Жареное мясо птицы",
    description = "Аппетитно поджаренная птица с золотистой корочкой. Отлично насыщает.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "green",
    weight = 0.25,
    propModel = "p_wrappedmeat01x",
    dropModel = "p_wrappedmeat01x",
    icon = "meat_bird_cooked",
    canUse = true,
    hunger = 200,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 14. Крольчатина
Items.Register("meat_rabbit_raw", {
    label = "Сырая крольчатина",
    description = "Свежая сырая тушка кролика. Сырое мясо вызывает расстройство желудка.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "green",
    weight = 0.4,
    propModel = "p_cs_rabbitmeat01x",
    dropModel = "p_cs_rabbitmeat01x",
    icon = "meat_rabbit_raw",
    canUse = true,
    hunger = -120,
    thirst = -100,
    actions = { "use", "place", "give", "drop" }
})
Items.Register("meat_rabbit_cooked", {
    label = "Жареная крольчатина",
    description = "Нежное диетическое мясо кролика, запеченное на углях.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "green",
    weight = 0.35,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "meat_rabbit_cooked",
    canUse = true,
    hunger = 200,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 16. Свинина
Items.Register("meat_pork_raw", {
    label = "Сырая свинина",
    description = "Жирный кусок сырой свинины. Опасно употреблять без термической обработки.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.8,
    propModel = "s_wrappedpork01x",
    dropModel = "s_wrappedpork01x",
    icon = "meat_pork_raw",
    canUse = true,
    hunger = -150,
    thirst = -120,
    actions = { "use", "place", "give", "drop" }
})
Items.Register("meat_pork_cooked", {
    label = "Жареная свинина",
    description = "Питательный прожаренный свиной стейк.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.7,
    propModel = "s_wrappedpork01x",
    dropModel = "s_wrappedpork01x",
    icon = "meat_pork_cooked",
    canUse = true,
    hunger = 220,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 17. Говядина
Items.Register("meat_beef_raw", {
    label = "Сырая говядина",
    description = "Крупный кусок сырой мраморной говядины.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 1.0,
    propModel = "s_wrappedbeef01x",
    dropModel = "s_wrappedbeef01x",
    icon = "meat_beef_raw",
    canUse = true,
    hunger = -150,
    thirst = -120,
    actions = { "use", "place", "give", "drop" }
})
Items.Register("meat_beef_cooked", {
    label = "Жареная говядина",
    description = "Большой сытный стейк с дымком, быстро восстанавливающий силы.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.9,
    propModel = "s_wrappedpork01x",
    dropModel = "s_wrappedpork01x",
    icon = "meat_beef_cooked",
    canUse = true,
    hunger = 240,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 18. Оленина
Items.Register("meat_deer_raw", {
    label = "Сырая оленина",
    description = "Свежая вырезка дикого оленя.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.9,
    propModel = "s_wrappedvenison01x",
    dropModel = "s_wrappedvenison01x",
    icon = "meat_deer_raw",
    canUse = true,
    hunger = -150,
    thirst = -120,
    actions = { "use", "place", "give", "drop" }
})
Items.Register("meat_deer_cooked", {
    label = "Жареная оленина",
    description = "Превосходная прожаренная оленина, любимое блюдо охотников.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.8,
    propModel = "p_wrappedmeat01x",
    dropModel = "p_wrappedmeat01x",
    icon = "meat_deer_cooked",
    canUse = true,
    hunger = 230,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 19. Медвежатина
Items.Register("meat_bear_raw", {
    label = "Сырая медвежатина",
    description = "Огромный волокнистый кусок сырого мяса свирепого медведя.",
    category = "food",
    width = 2,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 1.8,
    propModel = "p_wrappedmeat01x",
    dropModel = "p_wrappedmeat01x",
    icon = "meat_bear_raw",
    canUse = true,
    hunger = -200,
    thirst = -160,
    actions = { "use", "place", "give", "drop" }
})
Items.Register("meat_bear_cooked", {
    label = "Жареная медвежатина",
    description = "Мощная запеченная порция медвежатины, дарующая колоссальный запас сытости.",
    category = "food",
    width = 2,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 1.6,
    propModel = "s_wrappedpork01x",
    dropModel = "s_wrappedpork01x",
    icon = "meat_bear_cooked",
    canUse = true,
    hunger = 260,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- =================================================================
-- МЕДИЦИНА, ВЫЖИВАНИЕ И КРАФТ-РЕСУРСЫ
-- =================================================================

-- 20. Бинт (1x1, белое качество, макс. стак 3, вес 0.1 кг, лечит 90 HP в течение 30 сек)
Items.Register("bandage", {
    label = "Бинт",
    description = "Плотная чистая повязка из ткани. Постепенно перевязывает раны и восстанавливает здоровье в течение 30 секунд.",
    category = "medical",
    width = 1,
    height = 1,
    maxStack = 3,
    rarity = "white",
    weight = 0.1,
    propModel = "p_cs_bandage01x",
    dropModel = "p_cs_bandage01x",
    icon = "bandage",
    canUse = true,
    healAmount = 90,
    healDuration = 30,
    actions = { "use", "place", "give", "drop" }
})

-- 21. Костёр (3x3, фиолетовое качество, макс. стак 1, вес 3.5 кг)
Items.Register("campfire", {
    label = "Костёр",
    description = "Сложенный походный костровой набор. Источник тепла, света и место для приготовления пищи в дикой глуши.",
    category = "survival",
    width = 3,
    height = 3,
    maxStack = 1,
    rarity = "purple",
    weight = 3.5,
    propModel = "p_campfire_win2_01x",
    dropModel = "p_campfire_win2_01x",
    icon = "campfire",
    canUse = false,
    actions = { "place", "give", "drop" }
})

Items.Register("campfire_lit", {
    label = "Горящий костёр",
    description = "Ярко горящий походный костёр. Даёт тепло, свет и позволяет приготовить еду.",
    category = "survival",
    width = 3,
    height = 3,
    maxStack = 1,
    rarity = "purple",
    weight = 3.5,
    propModel = "p_campfirefresh01x",
    dropModel = "p_campfirefresh01x",
    icon = "campfire",
    canUse = false,
    actions = {}
})

Items.Register("campfire_smolder", {
    label = "Потухший костёр",
    description = "Остывающие угли костра. В них можно найти древесный уголь.",
    category = "survival",
    width = 3,
    height = 3,
    maxStack = 1,
    rarity = "purple",
    weight = 3.5,
    propModel = "p_campfire_win2_smolder01x",
    dropModel = "p_campfire_win2_smolder01x",
    icon = "campfire",
    canUse = false,
    actions = {}
})

-- 22. Повязка с лопухом (1x2, зеленое качество, макс. стак 2, вес 0.15 кг, лечит в 3 раза больше за 1 минуту)
Items.Register("bandage_burdock", {
    label = "Повязка с лопухом",
    description = "Лечебная повязка с измельченными листьями лопуха. Оказывает мощный противовоспалительный эффект и восстанавливает втрое больше здоровья в течение 1 минуты.",
    category = "medical",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.15,
    propModel = "p_cs_bandage01x",
    dropModel = "p_cs_bandage01x",
    icon = "bandage_burdock",
    canUse = true,
    healAmount = 180,
    healDuration = 60,
    actions = { "use", "place", "give", "drop" }
})

-- 23. Ткань (1x2, белое качество, макс. стак 5, вес 0.25 кг)
Items.Register("cloth", {
    label = "Ткань",
    description = "Отрез плотной натуральной ткани. Незаменимый материал для создания повязок, одежды и походного снаряжения.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.25,
    propModel = "s_balledragcloth01x",
    dropModel = "s_balledragcloth01x",
    icon = "cloth",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 24. Ветка (1x3, белое качество, макс. стак 10, вес 0.4 кг)
Items.Register("twigs", {
    label = "Ветка",
    description = "Сухие древесные ветви и хворост. Отлично подходят для разведения костра и создания базовых инструментов.",
    category = "material",
    width = 1,
    height = 3,
    maxStack = 10,
    rarity = "white",
    weight = 0.4,
    propModel = "proc_stick_03",
    dropModel = "proc_stick_03",
    icon = "twigs",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 25. Лист лопуха (1x2, белое качество, макс. стак 10, вес 0.05 кг)
Items.Register("burdock_leaf", {
    label = "Лист лопуха",
    description = "Свежий целебный лист дикого лопуха. Применяется в народной медицине для заживления ран и ожогов.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.05,
    propModel = "p_cs_burdock01x",
    dropModel = "s_burdock01x",
    icon = "burdock_leaf",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- =================================================================
-- НОВЫЕ ПРЕДМЕТЫ ПРОЕКТА
-- =================================================================

-- 1. Зуб волка
Items.Register("wolf_tooth", {
    label = "Зуб волка",
    description = "Острый клык серого хищника. В глуши сойдет за талисман или наконечник для стрелы, если хватит смелости его выбить.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 30,
    rarity = "white",
    weight = 0.05,
    propModel = "s_inv_cougarfangtrinket01x",
    dropModel = "s_inv_cougarfangtrinket01x",
    icon = "wolf_tooth",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 2. Зуб аллигатора
Items.Register("alligator_tooth", {
    label = "Зуб аллигатора",
    description = "Массивный зазубренный зуб болотного каймана. Напоминание о том, что к болотам Байу лучше не подходить спиной.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 20,
    rarity = "white",
    weight = 0.08,
    propModel = "s_inv_cougarfangtrinket01x",
    dropModel = "s_inv_cougarfangtrinket01x",
    icon = "alligator_tooth",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 3. Плод опунции
Items.Register("prickly_pear", {
    label = "Плод опунции",
    description = "Колючий десерт засушливых пустошей Нью-Остина. Сладкий, если аккуратно счистить иголки и не проглотить их со злости.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.15,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "prickly_pear",
    canUse = true,
    hunger = 40,
    thirst = 30,
    actions = { "use", "place", "give", "drop" }
})

-- 4. Сок кактуса
Items.Register("cactus_juice", {
    label = "Сок кактуса",
    description = "Горьковатая густая жижа, выжатая из кактуса. На вкус как разочарование, но спасает от гибели под палящим солнцем.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_bottlemedicine01x",
    dropModel = "p_bottlemedicine01x",
    icon = "cactus_juice",
    canUse = true,
    hunger = 20,
    thirst = 200,
    actions = { "use", "place", "give", "drop" }
})

-- 5. Смола
Items.Register("resin", {
    label = "Смола",
    description = "Липкая смола хвойных деревьев. Отлично склеивает стрелы, герметизирует швы и намертво липнет к пальцам.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.2,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "resin",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 6. Кора
Items.Register("tree_bark", {
    label = "Кора",
    description = "Грубая древесная кора. Идет на растопку, простейшие навесы или примитивные дубильные растворы.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 4,
    rarity = "white",
    weight = 0.3,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "tree_bark",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 7. Шкура
Items.Register("pelt", {
    label = "Шкура",
    description = "Тяжелая свернутая шкура зверя с густым мехом. Спасает от промозглых горных ветров и ценится у трапперов.",
    category = "material",
    width = 2,
    height = 3,
    maxStack = 3,
    rarity = "white",
    weight = 2.5,
    propModel = "p_cs_pelt_wolf_roll",
    dropModel = "p_cs_pelt_wolf_roll",
    icon = "pelt",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 8. Кожа
Items.Register("leather", {
    label = "Кожа",
    description = "Качественно выделанный кусок прочной кожи для пошива портупей, сумок и заплаток на сапоги.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 1.0,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "leather",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 9. Репчатый лук
Items.Register("onion", {
    label = "Репчатый лук",
    description = "Крепкая белая луковица. Заставляет плакать даже бывалых головорезов, зато оживляет любую похлебку.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.1,
    propModel = "p_onionwhite_01x",
    dropModel = "p_onionwhite_01x",
    icon = "onion",
    canUse = true,
    hunger = 30,
    thirst = 10,
    actions = { "use", "place", "give", "drop" }
})

-- 10. Яйцо
Items.Register("egg", {
    label = "Яйцо",
    description = "Свежее птичье яйцо в хрупкой скорлупе. Донести до лагеря целым — испытание пострашнее перестрелки.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.06,
    propModel = "p_egg01x",
    dropModel = "p_egg01x",
    icon = "egg",
    canUse = true,
    hunger = -40,
    thirst = -20,
    actions = { "use", "place", "give", "drop" }
})

-- 11. Варёное яйцо
Items.Register("egg_boiled", {
    label = "Варёное яйцо",
    description = "Сваренное вкрутую яйцо. Быстрый и сытный перекус, который не разобьется в кармане при беге.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "green",
    weight = 0.06,
    propModel = "p_egg01x",
    dropModel = "p_egg01x",
    icon = "egg_boiled",
    canUse = true,
    hunger = 120,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 12. Яичница
Items.Register("egg_fried", {
    label = "Яичница",
    description = "Шкворчащая яичница на походной сковороде. Запах жареного желтка на углях поднимает боевой дух.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.2,
    propModel = "p_stewplate01bx",
    dropModel = "p_stewplate01bx",
    icon = "egg_fried",
    canUse = true,
    hunger = 220,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 13. Мёд
Items.Register("honey", {
    label = "Мёд",
    description = "Тягучий золотистый мёд диких пчел. Добыть его стоило десятка укусов, но сладость того стоит.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "green",
    weight = 0.5,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "honey",
    canUse = true,
    hunger = 140,
    thirst = 30,
    actions = { "use", "place", "give", "drop" }
})

-- 14. Картофель
Items.Register("potato", {
    label = "Картофель",
    description = "Грязный клубень прямиком из сырой земли. Основа рациона любого выживальщика на Фронтире.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.15,
    propModel = "p_potato01x",
    dropModel = "p_potato01x",
    icon = "potato",
    canUse = true,
    hunger = 20,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 15. Запечённый картофель
Items.Register("potato_baked", {
    label = "Запечённый картофель",
    description = "Картофелина с обугленной корочкой прямо из золы костра. Горячая, рассыпчатая и чертовски вкусная.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.15,
    propModel = "p_potato01x_burnt",
    dropModel = "p_potato01x_burnt",
    icon = "potato_baked",
    canUse = true,
    hunger = 130,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 16. Морковь
Items.Register("carrot", {
    label = "Морковь",
    description = "Хрустящая сладкая морковь. Полезна для зрения, что немаловажно, когда в тебя целятся из кустов.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.1,
    propModel = "p_carrot01x",
    dropModel = "p_carrot01x",
    icon = "carrot",
    canUse = true,
    hunger = 40,
    thirst = 20,
    actions = { "use", "place", "give", "drop" }
})

-- 17. Кукуруза
Items.Register("corn", {
    label = "Кукуруза",
    description = "Спелый кукурузный початок с золотистыми зернами. Классика фермерских полей.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.25,
    propModel = "p_corn02x",
    dropModel = "p_corn02x",
    icon = "corn",
    canUse = true,
    hunger = 40,
    thirst = 10,
    actions = { "use", "place", "give", "drop" }
})

-- 18. Варёная кукуруза
Items.Register("corn_boiled", {
    label = "Варёная кукуруза",
    description = "Горячий отварной початок, посыпанный солью. Простое, сытное и душевное походное блюдо.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "green",
    weight = 0.25,
    propModel = "p_corn01x",
    dropModel = "p_corn01x",
    icon = "corn_boiled",
    canUse = true,
    hunger = 180,
    thirst = 10,
    actions = { "use", "place", "give", "drop" }
})

-- 19. Наживка из кукурузы
Items.Register("corn_bait", {
    label = "Наживка из кукурузы",
    description = "Горсть размоченных зерен кукурузы. Местная озерная рыба клюет на них с превеликим удовольствием.",
    category = "survival",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.1,
    propModel = "p_baitcorn01x",
    dropModel = "p_baitcorn01x",
    icon = "corn_bait",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 20. Кукурузная мука
Items.Register("corn_flour", {
    label = "Кукурузная мука",
    description = "Мешок грубой желтоватой муки. Незаменима для выпечки лепешек и кукурузного хлеба.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 1.0,
    propModel = "p_cs_flourbag01x",
    dropModel = "p_cs_flourbag01x",
    icon = "corn_flour",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 21. Кукурузный хлеб
Items.Register("cornbread", {
    label = "Кукурузный хлеб",
    description = "Плотный пышный ломоть домашнего кукурузного хлеба с хрустящей корочкой.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_cornbread02x",
    dropModel = "p_cornbread02x",
    icon = "cornbread",
    canUse = true,
    hunger = 220,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 22. Сахар
Items.Register("sugar", {
    label = "Сахар",
    description = "Мешочек тростникового сахара. Редкая роскошь на Диком Западе, способная подсластить даже жизнь бродяги.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "white",
    weight = 0.5,
    propModel = "p_sugar02x",
    dropModel = "p_sugar02x",
    icon = "sugar",
    canUse = true,
    hunger = 30,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 23. Карамельное яблоко
Items.Register("candy_apple", {
    label = "Карамельное яблоко",
    description = "Сочное лесное яблоко в твердой сахарной глазури. Вкус беззаботной ярмарки посреди суровых пустошей.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "green",
    weight = 0.2,
    propModel = "p_apple02x",
    dropModel = "p_apple02x",
    icon = "candy_apple",
    canUse = true,
    hunger = 120,
    thirst = 20,
    actions = { "use", "place", "give", "drop" }
})

-- 24. Пшеничная мука
Items.Register("wheat_flour", {
    label = "Пшеничная мука",
    description = "Мелкая просеянная пшеничная мука из амбаров Валентайна. Годится для пышного хлеба.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 1.0,
    propModel = "p_cs_flourbag01x",
    dropModel = "p_cs_flourbag01x",
    icon = "wheat_flour",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 25. Пшеничный хлеб
Items.Register("wheat_bread", {
    label = "Пшеничный хлеб",
    description = "Буханка свежеиспеченного белого хлеба. С ней даже жидкая похлебка кажется сытным обедом.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.5,
    propModel = "p_bread01x",
    dropModel = "p_bread01x",
    icon = "wheat_bread",
    canUse = true,
    hunger = 220,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 26. Каменная соль
Items.Register("rock_salt", {
    label = "Каменная соль",
    description = "Крупный минеральный кристалл каменной соли. Необходим для засолки мяса и выделки шкур.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "green",
    weight = 2.0,
    propModel = "hea_rock_scree_sim_03",
    dropModel = "hea_rock_scree_sim_03",
    icon = "rock_salt",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 27. Соль
Items.Register("salt", {
    label = "Соль",
    description = "Измельченная поваренная соль в солонке. Превращает безвкусную полевую баланду в съедобную еду.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 0.3,
    propModel = "p_saltshaker01x",
    dropModel = "p_saltshaker01x",
    icon = "salt",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 28. Кофе
Items.Register("coffee", {
    label = "Кофе",
    description = "Банка молотых кофейных зерен темной обжарки. Единственное, что способно поднять вас на рассвете.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 0.4,
    propModel = "p_jar_coffee01x",
    dropModel = "p_jar_coffee01x",
    icon = "coffee",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 29. Чай
Items.Register("tea", {
    label = "Чай",
    description = "Жестянка с сушеными чайными листьями. Согревает нутро и успокаивает расшатанные нервы.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 0.3,
    propModel = "p_tin_tea01x",
    dropModel = "p_tin_tea01x",
    icon = "tea",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 30. Лимон
Items.Register("lemon", {
    label = "Лимон",
    description = "Кислый цитрус с южных плантаций. Лучшее средство от цинги и верный способ скривить лицо.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.1,
    propModel = "p_lemon01x",
    dropModel = "p_lemon01x",
    icon = "lemon",
    canUse = true,
    hunger = 30,
    thirst = 40,
    actions = { "use", "place", "give", "drop" }
})

-- 31. Животный жир
Items.Register("animal_fat", {
    label = "Животный жир",
    description = "Кусок вытопленного нутряного сала. Идет в мыло, оружейную смазку и рецепты взрывчатки.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 30,
    rarity = "white",
    weight = 0.1,
    propModel = "p_wrappedmeat01x",
    dropModel = "p_wrappedmeat01x",
    icon = "animal_fat",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 32. Верёвка
Items.Register("rope", {
    label = "Верёвка",
    description = "Крепкая пеньковая веревка. Пригодится связать груз, повесить сушиться мясо или усмирить буйного попутчика.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.8,
    propModel = "mp007_s_mp_ropehogtiehandslarge01x",
    dropModel = "mp007_s_mp_ropehogtiehandslarge01x",
    icon = "rope",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 33. Перо
Items.Register("feather", {
    label = "Перо",
    description = "Легкое птичье перо. Применяется для оперения стрел или украшения походной шляпы.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.02,
    propModel = "p_feather01x",
    dropModel = "p_feather01x",
    icon = "feather",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 34. Коготь ворона
Items.Register("raven_claw", {
    label = "Коготь ворона",
    description = "Изогнутый цепкий коготь черного ворона. Местные шаманы шепчутся о его защитных свойствах.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.03,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "raven_claw",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 35. Коготь волка
Items.Register("wolf_claw", {
    label = "Коготь волка",
    description = "Смертоносный коготь матерого волка. Добыча, за которую пришлось расплатиться патронами и кровью.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.04,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "wolf_claw",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 36. Помидор
Items.Register("tomato", {
    label = "Помидор",
    description = "Спелый упругий томат. Брызжет соком при укусе и делает любое мясное рагу вдвое вкуснее.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.12,
    propModel = "s_tomato01x",
    dropModel = "s_tomato01x",
    icon = "tomato",
    canUse = true,
    hunger = 40,
    thirst = 40,
    actions = { "use", "place", "give", "drop" }
})

-- 37. Сельдерей
Items.Register("celery", {
    label = "Сельдерей",
    description = "Хрустящий зеленый стебель сельдерея. Пряный, сочный и на удивление освежающий в пути.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.15,
    propModel = "s_bit_celery01x",
    dropModel = "s_bit_celery01x",
    icon = "celery",
    canUse = true,
    hunger = 30,
    thirst = 40,
    actions = { "use", "place", "give", "drop" }
})

-- 38. Консервированные персики
Items.Register("canned_peaches", {
    label = "Консервированные персики",
    description = "Банка сладких персиков в густом сиропе. Настоящий деликатес в дальнем походе.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_can02x",
    dropModel = "p_can02x",
    icon = "canned_peaches",
    canUse = true,
    hunger = 150,
    thirst = 50,
    actions = { "use", "place", "give", "drop" }
})

-- 39. Консервированные томаты
Items.Register("canned_tomatoes", {
    label = "Консервированные томаты",
    description = "Закатанные в жестяную банку спелые томаты. Долго хранятся и отлично идут в котел.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_vg_canister_04x",
    dropModel = "p_vg_canister_04x",
    icon = "canned_tomatoes",
    canUse = true,
    hunger = 140,
    thirst = 60,
    actions = { "use", "place", "give", "drop" }
})

-- 40. Консервированная клубника
Items.Register("canned_strawberries", {
    label = "Консервированная клубника",
    description = "Ягоды земляники в собственном соку. Напоминают о домашнем уюте посреди холодной ночи.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_can03x",
    dropModel = "p_can03x",
    icon = "canned_strawberries",
    canUse = true,
    hunger = 140,
    thirst = 50,
    actions = { "use", "place", "give", "drop" }
})

-- 41. Консервированный ананас
Items.Register("canned_pineapple", {
    label = "Консервированный ананас",
    description = "Заморский ананас кольцами из далеких тропиков. Роскошь, добравшаяся на пароходе.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_can08x",
    dropModel = "p_can08x",
    icon = "canned_pineapple",
    canUse = true,
    hunger = 150,
    thirst = 50,
    actions = { "use", "place", "give", "drop" }
})

-- 42. Консервированные моллюски
Items.Register("canned_clams", {
    label = "Консервированные моллюски",
    description = "Соленые моллюски в банке. Запах специфический, но питательность на высоте.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.35,
    propModel = "p_can07x",
    dropModel = "p_can07x",
    icon = "canned_clams",
    canUse = true,
    hunger = 180,
    thirst = 10,
    actions = { "use", "place", "give", "drop" }
})

-- 43. Консервированное мясо
Items.Register("canned_meat", {
    label = "Консервированное мясо",
    description = "Армейская тушенка в плотной банке. Сытно, надежно и не портится даже под палящим солнцем.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "proc_can01x",
    dropModel = "proc_can01x",
    icon = "canned_meat",
    canUse = true,
    hunger = 220,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 44. Консервированная рыба
Items.Register("canned_fish", {
    label = "Консервированная рыба",
    description = "Рыбные консервы в масле. Открывать осторожно, чтобы не привлечь окрестных медведей.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.35,
    propModel = "p_can10x",
    dropModel = "p_can10x",
    icon = "canned_fish",
    canUse = true,
    hunger = 200,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 45. Консервированная фасоль
Items.Register("canned_beans", {
    label = "Консервированная фасоль",
    description = "Классическая ковбойская фасоль в томате. Гарантирует сытость и... бурную реакцию организма.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "green",
    weight = 0.4,
    propModel = "p_can09x",
    dropModel = "p_can09x",
    icon = "canned_beans",
    canUse = true,
    hunger = 200,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 46. Кружка
Items.Register("mug", {
    label = "Кружка",
    description = "Походная оловянная кружка. Держит тепло кофе и выдерживает удары о камни.",
    category = "item",
    width = 1,
    height = 1,
    maxStack = 1,
    rarity = "white",
    weight = 0.25,
    propModel = "p_mugcoffee01x",
    dropModel = "p_mugcoffee01x",
    icon = "mug",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 47. Колба
Items.Register("flask_glass", {
    label = "Колба",
    description = "Химическая стеклянная колба с узким горлышком для перегонки и травяных настоек.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 4,
    rarity = "white",
    weight = 0.3,
    propModel = "p_bottle007x",
    dropModel = "p_bottle007x",
    icon = "flask_glass",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 48. Пузырёк
Items.Register("vial", {
    label = "Пузырёк",
    description = "Миниатюрный аптечный пузырек из темного стекла для ядов, феромонов и эссенций.",
    category = "item",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "white",
    weight = 0.1,
    propModel = "mp007_p_vial_pheromones01x",
    dropModel = "mp007_p_vial_pheromones01x",
    icon = "vial",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 49. Гвозди
Items.Register("nails", {
    label = "Гвозди",
    description = "Коробка кованых строительных гвоздей. Незаменимы для плотницкого дела и баррикад.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.3,
    propModel = "p_nailbox01x",
    dropModel = "p_nailbox01x",
    icon = "nails",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 50. Чешуя рептилии
Items.Register("reptile_scale", {
    label = "Чешуя рептилии",
    description = "Жесткая ороговевшая пластина чешуи. Обладает высокой прочностью и водостойкостью.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "white",
    weight = 0.05,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "reptile_scale",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 51. Кость животного
Items.Register("animal_bone", {
    label = "Кость животного",
    description = "Очищенная прочная берцовая кость. Пойдет на костяные иглы, наконечники или суповой навар.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.4,
    propModel = "p_dogbone01x",
    dropModel = "p_dogbone01x",
    icon = "animal_bone",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 52. Спирт
Items.Register("alcohol", {
    label = "Спирт",
    description = "Медицинский этиловый спирт высокой очистки. Обеззараживает раны и безжалостно щиплет.",
    category = "medical",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.5,
    propModel = "p_bottlemedicine07x",
    dropModel = "p_bottlemedicine07x",
    icon = "alcohol",
    canUse = true,
    healAmount = 20,
    healDuration = 5,
    actions = { "use", "place", "give", "drop" }
})

-- 53. Масло
Items.Register("oil", {
    label = "Масло",
    description = "Бутыль очищенного технического масла для чистки заклинивших механизмов и оружия.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.5,
    propModel = "p_oil01x",
    dropModel = "p_oil01x",
    icon = "oil",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 54. Глаз ворона
Items.Register("raven_eye", {
    label = "Глаз ворона",
    description = "Сушеный глаз птицы с мутным зрачком. Жутковатый трофей, глядящий словно прямо в душу.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "white",
    weight = 0.02,
    propModel = "p_moneybag01x",
    dropModel = "p_moneybag01x",
    icon = "raven_eye",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 55. Змеиный яд
Items.Register("snake_venom", {
    label = "Змеиный яд",
    description = "Стеклянка со смертоносным ядом гремучей змеи. Несколько капель на клинке решают любой спор.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.15,
    propModel = "mp006_s_cft_poisonbottle01",
    dropModel = "mp006_s_cft_poisonbottle01",
    icon = "snake_venom",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 56. Серебряная руда
Items.Register("silver_ore", {
    label = "Серебряная руда",
    description = "Тяжелый кусок скальной породы с благородным серебряным блеском.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "green",
    weight = 3.5,
    propModel = "gua_rock_wall_bb",
    dropModel = "gua_rock_wall_bb",
    icon = "silver_ore",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 57. Серебряный слиток
Items.Register("silver_ingot", {
    label = "Серебряный слиток",
    description = "Отлитый брусок чистого серебра с клеймом монетного двора. Универсальная валюта.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "green",
    weight = 2.0,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "silver_ingot",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 58. Золотая руда
Items.Register("gold_ore", {
    label = "Золотая руда",
    description = "Самородная жила золота в кварце. Ради таких камней люди шли на преступления и гибель.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "blue",
    weight = 4.0,
    propModel = "p_goldnugget01x",
    dropModel = "p_goldnugget01x",
    icon = "gold_ore",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 59. Золотой слиток
Items.Register("gold_ingot", {
    label = "Золотой слиток",
    description = "Увесистый слиток чистейшего золота. От его блеска кружится голова, а карманы тянет вниз.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "orange",
    weight = 5.0,
    propModel = "p_inv_treasuregoldbar01x",
    dropModel = "p_inv_treasuregoldbar01x",
    icon = "gold_ingot",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 60. Песчаник
Items.Register("sandstone", {
    label = "Песчаник",
    description = "Пористый природный песчаник. Легко раскалывается и подходит для постройки печей.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "white",
    weight = 2.8,
    propModel = "old_hen_rock_scree_sim_10",
    dropModel = "old_hen_rock_scree_sim_10",
    icon = "sandstone",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 61. Серная руда
Items.Register("sulfur_ore", {
    label = "Серная руда",
    description = "Кристаллическая порода с едким запахом серы, добытая близ термальных источников.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 4,
    rarity = "green",
    weight = 3.0,
    propModel = "cumb_rock_scree_sim_10",
    dropModel = "cumb_rock_scree_sim_10",
    icon = "sulfur_ore",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 62. Серный порошок
Items.Register("sulfur_powder", {
    label = "Серный порошок",
    description = "Мелкотертая желтая сера. Ключевой компонент для дымного пороха и спичечных головок.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.5,
    propModel = "p_moneybag01x",
    dropModel = "p_moneybag01x",
    icon = "sulfur_powder",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 63. Древесный уголь
Items.Register("charcoal", {
    label = "Древесный уголь",
    description = "Качественный прогоревший уголь. Горит жарко без копоти и служит топливом для плавки.",
    category = "material",
    width = 2,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 1.5,
    propModel = "p_coalpile01x",
    dropModel = "p_coalpile01x",
    icon = "charcoal",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 64. Селитра
Items.Register("saltpeter", {
    label = "Селитра",
    description = "Белый кристаллический порошок селитры. Второй важнейший ингредиент гремучих порохов.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.6,
    propModel = "p_moneybag01x",
    dropModel = "p_moneybag01x",
    icon = "saltpeter",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 65. Порох
Items.Register("gunpowder", {
    label = "Порох",
    description = "Черный дымный порох в промасленной колбе. Держите подальше от открытого огня и сигар.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "green",
    weight = 0.5,
    propModel = "p_gunpowder01x",
    dropModel = "p_gunpowder01x",
    icon = "gunpowder",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 66. Замок
Items.Register("padlock", {
    label = "Замок",
    description = "Массивный висячий замок из закаленной стали. Защитит припасы от излишне любопытных рук.",
    category = "item",
    width = 1,
    height = 1,
    maxStack = 1,
    rarity = "white",
    weight = 0.4,
    propModel = "mp005_s_mp_wildanimalcagelock01x",
    dropModel = "mp005_s_mp_wildanimalcagelock01x",
    icon = "padlock",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 67. Мешочек (Контейнер 2x3 = 6 слотов)
Items.Register("pouch", {
    label = "Мешочек",
    description = "Компактный кожаный мешочек на завязках.",
    category = "storage",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.3,
    propModel = "p_cs_dirtybag01x",
    dropModel = "p_cs_dirtybag01x",
    icon = "pouch",
    isContainer = true,
    containerStorage = { cols = 2, rows = 3 },
    canUse = false,
    actions = { "open", "place", "give", "drop" }
})

-- 68. Мешок (Контейнер 3x3 = 9 слотов)
Items.Register("bag", {
    label = "Мешок",
    description = "Вместительный холщовый мешок с ремнями.",
    category = "storage",
    width = 2,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 0.6,
    propModel = "p_rockbag01x_close",
    dropModel = "p_rockbag01x_close",
    icon = "bag",
    isContainer = true,
    containerStorage = { cols = 3, rows = 3 },
    canUse = false,
    actions = { "open", "place", "give", "drop" }
})

-- 69. Большой мешок (Контейнер 4x4 = 16 слотов)
Items.Register("bag_large", {
    label = "Большой мешок",
    description = "Огромный брезентовый походный баул.",
    category = "storage",
    width = 3,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 1.0,
    propModel = "s_hotairballoon_sandbag",
    dropModel = "s_hotairballoon_sandbag",
    icon = "bag_large",
    isContainer = true,
    containerStorage = { cols = 4, rows = 4 },
    canUse = false,
    actions = { "open", "place", "give", "drop" }
})

-- 70. Нитки с иглой
Items.Register("needle_thread", {
    label = "Нитки с иглой",
    description = "Костяная игла с мотком суровой нити. Спасает разорванную одежду и зашивает рваные раны.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.05,
    propModel = "p_string_bundle_001",
    dropModel = "p_string_bundle_001",
    icon = "needle_thread",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 71. Шерсть
Items.Register("wool", {
    label = "Шерсть",
    description = "Пучок мягкой овечьей шерсти. Идеальный утеплитель для подкладки курток и одеял.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.3,
    propModel = "mp007_p_nat_beartuftsfur01x",
    dropModel = "mp007_p_nat_beartuftsfur01x",
    icon = "wool",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 72. Рог
Items.Register("horn", {
    label = "Рог",
    description = "Крепкий витой рог дикого бизона. Идет на рукояти ножей, пороховницы и сигнальные рожки.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 4,
    rarity = "white",
    weight = 0.7,
    propModel = "p_buffalohorn03x",
    dropModel = "p_buffalohorn03x",
    icon = "horn",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 73. Карта
Items.Register("map", {
    label = "Карта",
    description = "Потрепанная топографическая карта фронтира с отметками рек, перевалов и опасных троп.",
    category = "item",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.1,
    propModel = "p_map02x",
    dropModel = "p_map02x",
    icon = "map",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 74. Молоток
Items.Register("hammer", {
    label = "Молоток",
    description = "Увесистый плотницкий молоток. Вбивает гвозди с одного удара и отлично дробит черепа.",
    category = "survival",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 1.2,
    propModel = "p_hammer04x",
    dropModel = "p_hammer04x",
    icon = "hammer",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 75. Топор
Items.Register("axe", {
    label = "Топор",
    description = "Остро заточенный колун на длинном топорище. Без него в лесу делать решительно нечего.",
    category = "melee",
    width = 1,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 1.8,
    propModel = "p_axe01x",
    dropModel = "p_axe01x",
    icon = "axe",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 76. Пила
Items.Register("saw", {
    label = "Пила",
    description = "Ручная ножовка с калеными зубьями. Позволяет распускать бревна на ровные доски.",
    category = "survival",
    width = 1,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 1.5,
    propModel = "p_sawhand01x",
    dropModel = "p_sawhand01x",
    icon = "saw",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 77. Охотничий нож
Items.Register("hunting_knife", {
    label = "Охотничий нож",
    description = "Классический боуи с широким клинком. Незаменим при разделке туш и в тесной поножовщине.",
    category = "melee",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.5,
    propModel = "p_knife03x",
    dropModel = "p_knife03x",
    icon = "hunting_knife",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 78. Лопата
Items.Register("shovel", {
    label = "Лопата",
    description = "Стальная штыковая лопата. Пригодится вырыть траншею, откопать клад или закопать свидетеля.",
    category = "survival",
    width = 1,
    height = 4,
    maxStack = 1,
    rarity = "white",
    weight = 2.2,
    propModel = "p_shovel01x",
    dropModel = "p_shovel01x",
    icon = "shovel",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 79. Кирка
Items.Register("pickaxe", {
    label = "Кирка",
    description = "Тяжелое шахтерское кайло. Дробит гранит, обнажая рудные жилы в темных забоях.",
    category = "survival",
    width = 2,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 2.5,
    propModel = "p_pickaxe01x",
    dropModel = "p_pickaxe01x",
    icon = "pickaxe",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 80. Точильный камень
Items.Register("sharpening_stone", {
    label = "Точильный камень",
    description = "Мелкозернистый брусок для правки затупившихся лезвий ножей, кос и топоров.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "white",
    weight = 0.6,
    propModel = "p_sharpeningstone01x",
    dropModel = "p_sharpeningstone01x",
    icon = "sharpening_stone",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 81. Швейный набор
Items.Register("sewing_kit", {
    label = "Швейный набор",
    description = "Футляр с набором стальных игл, дратвы, наперстком и ножницами для профессионального ремонта снаряжения.",
    category = "survival",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "green",
    weight = 0.5,
    propModel = "p_sewingkit01bx",
    dropModel = "p_sewingkit01bx",
    icon = "sewing_kit",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 82. Косметический набор
Items.Register("grooming_kit", {
    label = "Косметический набор",
    description = "Набор бритвенных принадлежностей, мыла и гребней. Даже на границе цивилизации стоит выглядеть человеком.",
    category = "survival",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "green",
    weight = 0.6,
    propModel = "p_firstaidkit01x",
    dropModel = "p_firstaidkit01x",
    icon = "grooming_kit",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 83. Пчелиный воск
Items.Register("beeswax", {
    label = "Пчелиный воск",
    description = "Брусок натурального воска. Защищает кожу от влаги, вощит тетиву и изолирует дерево.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "white",
    weight = 0.15,
    propModel = "p_package09",
    dropModel = "p_package09",
    icon = "beeswax",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 84. Спички
Items.Register("matches", {
    label = "Спички",
    description = "Коробок серных спичек. Берегите от сырости — огонь в глуши означает разницу между жизнью и смертью.",
    category = "survival",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "white",
    weight = 0.05,
    propModel = "p_matches01x",
    dropModel = "p_matches01x",
    icon = "matches",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 85. Факел
Items.Register("torch", {
    label = "Факел",
    description = "Осмоленный деревянный факел. Разгоняет ночную тьму и отпугивает диких хищников.",
    category = "survival",
    width = 1,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 0.7,
    propModel = "p_torch01x",
    dropModel = "p_torch01x",
    icon = "torch",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 86. Бурдюк
Items.Register("waterskin", {
    label = "Бурдюк",
    description = "Опустевший кожаный бурдюк со шнурком. Требует наполнения чистой водой у ручья или колонки.",
    category = "survival",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.3,
    propModel = "p_gourdwater01x",
    dropModel = "p_gourdwater01x",
    icon = "waterskin",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 87. Бурдюк с водой (2 использования, утоляет жажду как бутылка)
Items.Register("waterskin_water", {
    label = "Бурдюк с водой",
    description = "Бурдюк, полный свежей прохладной воды.",
    category = "food",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "green",
    weight = 1.3,
    propModel = "p_gourdwater01x",
    dropModel = "p_gourdwater01x",
    icon = "waterskin_water",
    canUse = true,
    uses = 2,
    maxUses = 2,
    thirst = 300,
    actions = { "use", "place", "give", "drop" }
})

-- 88. Фляга
Items.Register("flask", {
    label = "Фляга",
    description = "Пустая металлическая походная фляга с винтовой крышкой. Легкая и прочная.",
    category = "survival",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "white",
    weight = 0.4,
    propModel = "p_flask01xb",
    dropModel = "p_flask01xb",
    icon = "flask",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 89. Фляга с жидкостью (3 использования, утоляет жажду как бутылка)
Items.Register("flask_water", {
    label = "Фляга с жидкостью",
    description = "Армейская фляга с живительной влагой.",
    category = "food",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "green",
    weight = 1.4,
    propModel = "p_flask01xb",
    dropModel = "p_flask01xb",
    icon = "flask_water",
    canUse = true,
    uses = 3,
    maxUses = 3,
    thirst = 300,
    actions = { "use", "place", "give", "drop" }
})

-- 90. Американский сом
Items.Register("fish_bullhead_catfish", {
    label = "Американский сом",
    description = "Скользкий усатый сом из речного ила. Мясо сладковатое, но требует хорошей прожарки.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.8,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_bullhead_catfish",
    canUse = true,
    hunger = 70,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 91. Большеротый окунь
Items.Register("fish_largemouth_bass", {
    label = "Большеротый окунь",
    description = "Упитанный хищный окунь. Отличный трофей любого удачливого рыболова.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.9,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_largemouth_bass",
    canUse = true,
    hunger = 75,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 92. Длиннорыллый панцирник
Items.Register("fish_longnose_gar", {
    label = "Длиннорыллый панцирник",
    description = "Древняя костлявая рыба с клювовидной пастью. Чистить тяжело, но мяса на уху хватит.",
    category = "food",
    width = 1,
    height = 4,
    maxStack = 3,
    rarity = "white",
    weight = 2.2,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_longnose_gar",
    canUse = true,
    hunger = 100,
    thirst = -20,
    actions = { "use", "place", "give", "drop" }
})

-- 93. Желтый окунь
Items.Register("fish_yellow_perch", {
    label = "Желтый окунь",
    description = "Полосатый речной окунек с яркими плавниками. На один зубок, зато ловится десятками.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.5,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_yellow_perch",
    canUse = true,
    hunger = 50,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 94. Каменный окунь
Items.Register("fish_rock_bass", {
    label = "Каменный окунь",
    description = "Широкотелый окунь с красными глазами, обитающий среди прибрежных камней.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.6,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_rock_bass",
    canUse = true,
    hunger = 55,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 95. Канальный сом
Items.Register("fish_channel_catfish", {
    label = "Канальный сом",
    description = "Здоровенный пятнистый сом глубоких вод. Настоящее бревно, с трудом влезающее в садок.",
    category = "food",
    width = 2,
    height = 3,
    maxStack = 3,
    rarity = "white",
    weight = 2.8,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_channel_catfish",
    canUse = true,
    hunger = 120,
    thirst = -20,
    actions = { "use", "place", "give", "drop" }
})

-- 96. Краснопёрая щука
Items.Register("fish_redfin_pickerel", {
    label = "Краснопёрая щука",
    description = "Юркая щука с алыми перьями плавников. Остра на зуб и сопротивляется до последнего.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.7,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_redfin_pickerel",
    canUse = true,
    hunger = 65,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 97. Лосось
Items.Register("fish_salmon", {
    label = "Лосось",
    description = "Благородный лосось холодных горных рек. Нежнейшее розовое мясо, мечта гурмана.",
    category = "food",
    width = 1,
    height = 3,
    maxStack = 3,
    rarity = "white",
    weight = 1.5,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_salmon",
    canUse = true,
    hunger = 90,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 98. Малоротый окунь
Items.Register("fish_smallmouth_bass", {
    label = "Малоротый окунь",
    description = "Быстрый озерный окунь. Любит чистые проточные заводи и яростно бросается на наживку.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.7,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_smallmouth_bass",
    canUse = true,
    hunger = 60,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 99. Озёрный осётр
Items.Register("fish_lake_sturgeon", {
    label = "Озёрный осётр",
    description = "Гигантский реликтовый осетр. Редчайший улов, за который на рынке отвалят целое состояние.",
    category = "food",
    width = 2,
    height = 4,
    maxStack = 3,
    rarity = "white",
    weight = 4.0,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_lake_sturgeon",
    canUse = true,
    hunger = 160,
    thirst = -20,
    actions = { "use", "place", "give", "drop" }
})

-- 100. Полосатая щука
Items.Register("fish_chain_pickerel", {
    label = "Полосатая щука",
    description = "Длинная засадная щука с кольчужным узором на чешуе. Отличная добыча для костра.",
    category = "food",
    width = 1,
    height = 3,
    maxStack = 3,
    rarity = "white",
    weight = 1.2,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_chain_pickerel",
    canUse = true,
    hunger = 80,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 101. Радужная форель
Items.Register("fish_steelhead_trout", {
    label = "Радужная форель",
    description = "Переливающаяся всеми цветами радуги горная форель. Мясо тает во рту.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.9,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_steelhead_trout",
    canUse = true,
    hunger = 75,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 102. Синежаберник
Items.Register("fish_bluegill", {
    label = "Синежаберник",
    description = "Круглая ладошечная рыбка с синими жаберными крышками. Хватит на легкую закуску.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 0.4,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_bluegill",
    canUse = true,
    hunger = 45,
    thirst = -10,
    actions = { "use", "place", "give", "drop" }
})

-- 103. Щука
Items.Register("fish_northern_pike", {
    label = "Щука",
    description = "Зубастая хищница северных озер. Длинное прогонистое тело и пасть, полная бритвенных зубов.",
    category = "food",
    width = 1,
    height = 4,
    maxStack = 3,
    rarity = "white",
    weight = 2.0,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_northern_pike",
    canUse = true,
    hunger = 95,
    thirst = -15,
    actions = { "use", "place", "give", "drop" }
})

-- 104. Щука-маскинонг
Items.Register("fish_muskie", {
    label = "Щука-маскинонг",
    description = "Царь-щука невероятных размеров. Чтобы вытащить такую из воды, понадобится железная хватка.",
    category = "food",
    width = 2,
    height = 4,
    maxStack = 3,
    rarity = "white",
    weight = 3.8,
    propModel = "s_wrappedmeat01x",
    dropModel = "s_wrappedmeat01x",
    icon = "fish_muskie",
    canUse = true,
    hunger = 150,
    thirst = -20,
    actions = { "use", "place", "give", "drop" }
})

-- 105. Мухомор
Items.Register("mush_fly_agaric", {
    label = "Мухомор",
    description = "Ядовитый гриб в яркую белую крапинку. Есть его сырым равносильно встрече со святым Петром.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.1,
    propModel = "s_flyamush02x",
    dropModel = "s_flyamush02x",
    icon = "mush_fly_agaric",
    canUse = true,
    hunger = -100,
    thirst = -50,
    actions = { "use", "place", "give", "drop" }
})

-- 106. Каштановый моховик
Items.Register("mush_bay_bolete", {
    label = "Каштановый моховик",
    description = "Мясистый благородный моховик с темной бархатистой шляпкой. Прекрасен в жареном виде.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.12,
    propModel = "s_inv_baybolete",
    dropModel = "s_inv_baybolete",
    icon = "mush_bay_bolete",
    canUse = true,
    hunger = 40,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 107. Сумеречник
Items.Register("mush_parasol_twilight", {
    label = "Сумеречник",
    description = "Редкий ночной гриб с тускло светящейся шляпкой. Ценится в алхимических отварах.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.1,
    propModel = "s_amedmush",
    dropModel = "s_amedmush",
    icon = "mush_parasol_twilight",
    canUse = true,
    hunger = 35,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 108. Лисичка
Items.Register("mush_chanterelle", {
    label = "Лисичка",
    description = "Ярко-рыжий ароматный лесной гриб. В нем никогда не бывает червей, а суп получается золотым.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.08,
    propModel = "s_inv_chanterelles",
    dropModel = "s_inv_chanterelles",
    icon = "mush_chanterelle",
    canUse = true,
    hunger = 45,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 109. Гриб-зонтик
Items.Register("mush_parasol", {
    label = "Гриб-зонтик",
    description = "Высокий чешуйчатый гриб на тонкой ножке. Обжаренный в масле напоминает нежное филе птицы.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.1,
    propModel = "s_inv_parasol",
    dropModel = "s_inv_parasol",
    icon = "mush_parasol",
    canUse = true,
    hunger = 40,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 110. Гриб-баран
Items.Register("mush_rams_head", {
    label = "Гриб-баран",
    description = "Кустистый древесный гриб причудливой формы. Настоящая находка для лесного повара.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 5,
    rarity = "white",
    weight = 0.2,
    propModel = "s_inv_ramshead",
    dropModel = "s_inv_ramshead",
    icon = "mush_rams_head",
    canUse = true,
    hunger = 50,
    thirst = 0,
    actions = { "use", "place", "give", "drop" }
})

-- 111. Лист мяты
Items.Register("herb_mint", {
    label = "Лист мяты",
    description = "Свежий пахучий лист дикой мяты. Освежает дыхание и придает чаю бодрящий аромат.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.02,
    propModel = "s_inv_wildmint01bx",
    dropModel = "wildmint_p",
    icon = "herb_mint",
    canUse = true,
    hunger = 10,
    thirst = 15,
    actions = { "use", "place", "give", "drop" }
})

-- 112. Лист табака
Items.Register("herb_tobacco", {
    label = "Лист табака",
    description = "Широкий лист индейского табака. После сушки превращается в крепкую курительную смесь.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.03,
    propModel = "s_inv_indtobacco01bx",
    dropModel = "indtobacco_p",
    icon = "herb_tobacco",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 113. Лист шалфея колибри
Items.Register("herb_hummingbird_sage", {
    label = "Лист шалфея колибри",
    description = "Ароматный шалфей с фиолетовыми прожилками. Снимает жар и успокаивает ноющую боль.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.03,
    propModel = "s_inv_humbirdsage01bx",
    dropModel = "humbirdsage_p",
    icon = "herb_hummingbird_sage",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 114. Лист пустынного шалфея
Items.Register("herb_desert_sage", {
    label = "Лист пустынного шалфея",
    description = "Выносливый шалфей из каньонов Нью-Остина. Традиционное средство степных знахарей.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.03,
    propModel = "s_inv_desertsage01bx",
    dropModel = "desertsage_p",
    icon = "herb_desert_sage",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 115. Лист красного шалфея
Items.Register("herb_red_sage", {
    label = "Лист красного шалфея",
    description = "Пурпурно-красный шалфей скалистых предгорий. Применяется для укрепления сил.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.03,
    propModel = "s_inv_redsage01bx",
    dropModel = "redsage_p",
    icon = "herb_red_sage",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 116. Лист олеандра
Items.Register("herb_oleander", {
    label = "Лист олеандра",
    description = "Темно-зеленый лист олеандра. Чрезвычайно ядовит — подходит для варки смертоносных токсинов.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.03,
    propModel = "s_oleander01x",
    dropModel = "s_oleander01x",
    icon = "herb_oleander",
    canUse = true,
    hunger = -80,
    thirst = -50,
    actions = { "use", "place", "give", "drop" }
})

-- 117. Соцветие тысячелистника
Items.Register("herb_yarrow", {
    label = "Соцветие тысячелистника",
    description = "Щиток белых целебных цветов. Лучшее народное средство для остановки кровотечений.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.04,
    propModel = "s_inv_yarrow01cx",
    dropModel = "yarrow01_p",
    icon = "herb_yarrow",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 118. Корень американского женьшеня
Items.Register("herb_ginseng_american", {
    label = "Корень американского женьшеня",
    description = "Ветвистый корень долголетия. Возвращает бодрость уставшему телу и разгоняет кровь.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.05,
    propModel = "ginseng_p",
    dropModel = "s_inv_ginseng01x",
    icon = "herb_ginseng_american",
    canUse = true,
    hunger = 20,
    thirst = 20,
    actions = { "use", "place", "give", "drop" }
})

-- 119. Корень аляскинского женьшеня
Items.Register("herb_ginseng_alaskan", {
    label = "Корень аляскинского женьшеня",
    description = "Морозный северный женьшень. Обладает еще большей целебной силой, чем его южный собрат.",
    category = "material",
    width = 1,
    height = 2,
    maxStack = 10,
    rarity = "white",
    weight = 0.05,
    propModel = "alaskanginseng_p",
    dropModel = "s_inv_alaskanginseng01x",
    icon = "herb_ginseng_alaskan",
    canUse = true,
    hunger = 25,
    thirst = 25,
    actions = { "use", "place", "give", "drop" }
})

-- 120. Аптечка (оказание помощи игроку без сознания)
Items.Register("first_aid_kit", {
    label = "Аптечка",
    description = "Полевой медицинский саквояж для приведения потерявшего сознание игрока в чувство.",
    category = "medical",
    width = 2,
    height = 3,
    maxStack = 2,
    rarity = "purple",
    weight = 1.5,
    propModel = "mp001_s_healthpack01x",
    dropModel = "mp001_s_healthpack01x",
    icon = "first_aid_kit",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 121. Удочка
Items.Register("fishing_rod", {
    label = "Удочка",
    description = "Гибкое бамбуковое удилище с катушкой и прочной леской. Залог сытого вечера у костра.",
    category = "survival",
    width = 1,
    height = 4,
    maxStack = 1,
    rarity = "white",
    weight = 1.1,
    propModel = "p_cs_fishingpoleclps01x",
    dropModel = "p_cs_fishingpoleclps01x",
    icon = "fishing_rod",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 122. Червь
Items.Register("worm", {
    label = "Червь",
    description = "Извивающийся дождевой червь из жирной почвы. Простая, но безотказная наживка.",
    category = "survival",
    width = 1,
    height = 1,
    maxStack = 40,
    rarity = "white",
    weight = 0.01,
    propModel = "p_baitworm01x",
    dropModel = "p_baitworm01x",
    icon = "worm",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 123. Рыбий жир
Items.Register("fish_oil", {
    label = "Рыбий жир",
    description = "Флакон с густым очищенным рыбьим жиром. Вкус отвратительный, но иммунитет крепок как кремень.",
    category = "medical",
    width = 1,
    height = 1,
    maxStack = 2,
    rarity = "white",
    weight = 0.2,
    propModel = "p_bottlemedicine16x",
    dropModel = "p_bottlemedicine16x",
    icon = "fish_oil",
    canUse = true,
    hunger = 15,
    thirst = 10,
    actions = { "use", "place", "give", "drop" }
})

-- 124. Череп животного
Items.Register("animal_skull", {
    label = "Череп животного",
    description = "Выбеленный солнцем череп койота. Популярный атрибут дикарских тотемов и походного декора.",
    category = "item",
    width = 2,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 1.2,
    propModel = "p_skull_animal_small_002",
    dropModel = "p_skull_animal_small_002",
    icon = "animal_skull",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 125. Череп человека
Items.Register("human_skull", {
    label = "Череп человека",
    description = "Человеческий череп с пустыми глазницами. Безмолвный свидетель чьей-то неудачной партии в покер.",
    category = "item",
    width = 2,
    height = 2,
    maxStack = 3,
    rarity = "white",
    weight = 1.0,
    propModel = "p_humanskull01x",
    dropModel = "p_humanskull01x",
    icon = "human_skull",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 126. Неизвестная статуэтка
Items.Register("unknown_statue", {
    label = "Неизвестная статуэтка",
    description = "Древняя базальтовая фигурка неизвестного культа. От нее веет необъяснимым загробным холодом.",
    category = "item",
    width = 1,
    height = 4,
    maxStack = 1,
    rarity = "blue",
    weight = 2.0,
    propModel = "p_gen_statue03x",
    dropModel = "p_gen_statue03x",
    icon = "unknown_statue",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 127. Золотые карманные часы
Items.Register("gold_pocket_watch", {
    label = "Золотые карманные часы",
    description = "Изысканные швейцарские часы из червонного золота с гравировкой. Время на них давно застыло.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "purple",
    weight = 0.3,
    propModel = "mp007_s_pocketwatch_emote02x",
    dropModel = "mp007_s_pocketwatch_emote02x",
    icon = "gold_pocket_watch",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 128. Проклятая кость
Items.Register("cursed_bone", {
    label = "Проклятая кость",
    description = "Почерневшая кость исполинского существа. Воздух вокруг нее едва заметно дрожит и вибрирует.",
    category = "item",
    width = 1,
    height = 4,
    maxStack = 1,
    rarity = "purple",
    weight = 1.5,
    propModel = "p_dinobone01x",
    dropModel = "p_dinobone01x",
    icon = "cursed_bone",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 129. Золотой зуб
Items.Register("gold_tooth", {
    label = "Золотой зуб",
    description = "Выбитый золотой зуб с остатками корня. Чья-то былая улыбка теперь превратилась в звонкую монету.",
    category = "item",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "blue",
    weight = 0.05,
    propModel = "s_inv_goldtooth01x",
    dropModel = "s_inv_goldtooth01x",
    icon = "gold_tooth",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 130. Осквернённый орган
Items.Register("corrupted_organ", {
    label = "Осквернённый орган",
    description = "Изуродованный чумной нарост, пульсирующий темной сукровицей. Держать его в руках омерзительно.",
    category = "item",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "blue",
    weight = 0.8,
    propModel = "s_meatbit_organ_small01x",
    dropModel = "s_meatbit_organ_small01x",
    icon = "corrupted_organ",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 131. Споровый мешочек
Items.Register("spore_pouch", {
    label = "Споровый мешочек",
    description = "Кожистый нарост, источающий удушливые фиолетовые споры при малейшем нажатии.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "purple",
    weight = 0.3,
    propModel = "p_bag_voodoo01x",
    dropModel = "p_bag_voodoo01x",
    icon = "spore_pouch",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 132. Необычный шар
Items.Register("mysterious_orb", {
    label = "Необычный шар",
    description = "Стеклянная сфера, внутри которой кружится призрачный туман. Кажется, если вглядеться — увидишь бездну.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "orange",
    weight = 1.0,
    propModel = "mp005_p_mp_crystalball01x",
    dropModel = "mp005_p_mp_crystalball01x",
    icon = "mysterious_orb",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 133. Алый камень
Items.Register("scarlet_stone", {
    label = "Алый камень",
    description = "Мерцающий багровый самоцвет, теплый на ощупь. Словно застывшая капля крови древнего бога.",
    category = "item",
    width = 2,
    height = 2,
    maxStack = 1,
    rarity = "purple",
    weight = 2.0,
    propModel = "mp001_s_mp_stone_marker03a",
    dropModel = "mp001_s_mp_stone_marker03a",
    icon = "scarlet_stone",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 134. Чёрная пыльца
Items.Register("black_pollen", {
    label = "Чёрная пыльца",
    description = "Мешочек смолянистой пыльцы неведомого ночного цветка. Используется в оккультных ритуалах.",
    category = "item",
    width = 1,
    height = 1,
    maxStack = 1,
    rarity = "blue",
    weight = 0.05,
    propModel = "p_moneybag01x",
    dropModel = "p_moneybag01x",
    icon = "black_pollen",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 135. Глаз чудовища
Items.Register("monster_eye", {
    label = "Глаз чудовища",
    description = "Крупное склизкое яблоко с вертикальным зрачком, вырезанное из плоти болотной твари.",
    category = "material",
    width = 1,
    height = 1,
    maxStack = 4,
    rarity = "green",
    weight = 0.1,
    propModel = "p_moneybag01x",
    dropModel = "p_moneybag01x",
    icon = "monster_eye",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 136. Кукла вуду
Items.Register("voodoo_doll", {
    label = "Кукла вуду",
    description = "Тряпичная кукла из мешковины с торчащими ржавыми иглами. Лучше не шутить с теми, кто ее сшил.",
    category = "item",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "blue",
    weight = 0.2,
    propModel = "p_voodoodoll01x",
    dropModel = "p_voodoodoll01x",
    icon = "voodoo_doll",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 137. Фонарь
Items.Register("lantern", {
    label = "Фонарь",
    description = "Керосиновый подвесной фонарь с закопченным стеклом. Верный спутник в темных пещерах и ночном лесу.",
    category = "survival",
    width = 1,
    height = 3,
    maxStack = 1,
    rarity = "white",
    weight = 1.2,
    propModel = "p_lanternhang",
    dropModel = "p_lanternhang",
    icon = "lantern",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 138. Жевательный табак
Items.Register("chewing_tobacco", {
    label = "Жевательный табак",
    description = "Банка спрессованного жевательного табака. Прочищает мозги и окрашивает плевки в коричневый цвет.",
    category = "food",
    width = 1,
    height = 1,
    maxStack = 5,
    rarity = "green",
    weight = 0.1,
    propModel = "s_tobaccotin01x",
    dropModel = "s_tobaccotin01x",
    icon = "chewing_tobacco",
    canUse = true,
    hunger = -10,
    thirst = -20,
    actions = { "use", "place", "give", "drop" }
})

-- 139. Самогон
Items.Register("moonshine", {
    label = "Самогон",
    description = "Бутыль ядреного домашнего первача из тайного перегонного куба. Горит синим пламенем и валит с ног.",
    category = "food",
    width = 1,
    height = 2,
    maxStack = 2,
    rarity = "green",
    weight = 0.7,
    propModel = "s_inv_moonshine01x",
    dropModel = "s_inv_moonshine01x",
    icon = "moonshine",
    canUse = true,
    thirst = 150,
    hunger = -30,
    actions = { "use", "place", "give", "drop" }
})

-- 140. Подкова
Items.Register("horseshoe", {
    label = "Подкова",
    description = "Кованая железная подкова. На удачу или для хромающей лошади, потерявшей след на каменистой тропе.",
    category = "item",
    width = 1,
    height = 1,
    maxStack = 10,
    rarity = "white",
    weight = 0.4,
    propModel = "p_horseshoe01x",
    dropModel = "p_horseshoe01x",
    icon = "horseshoe",
    canUse = false,
    actions = { "place", "give", "drop" }
})

-- 141. Связка ключей (Контейнер 2x2 = 4 слота, ТОЛЬКО КЛЮЧИ)
Items.Register("key_ring", {
    label = "Связка ключей",
    description = "Звенящее металлическое кольцо для хранения ключей.",
    category = "storage",
    width = 1,
    height = 2,
    maxStack = 1,
    rarity = "blue",
    weight = 0.1,
    propModel = "p_keys01x",
    dropModel = "p_keys01x",
    icon = "key_ring",
    isContainer = true,
    containerStorage = { cols = 2, rows = 2, keyOnly = true },
    canUse = false,
    actions = { "open", "place", "give", "drop" }
})

-- =================================================================
-- 142. Походные рюкзаки (20 видов: Маленькие, Средние, Большие, Огромные)
-- Слот экипировки: Satchels (Сумка)
-- =================================================================
local BackpackSizes = {
    small = {
        cols = 4,
        rows = 2,
        rowWidths = { 4, 4 },
        weight = 0.8
    },
    medium = {
        cols = 4,
        rows = 3,
        rowWidths = { 4, 4, 4 },
        weight = 1.4
    },
    large = {
        cols = 4,
        rows = 4,
        rowWidths = { 4, 4, 4, 4 },
        weight = 2.0
    },
    huge = {
        cols = 4,
        rows = 5,
        rowWidths = { 4, 4, 4, 4, 4 },
        weight = 2.8
    }
}

local BackpackDefinitions = {
    { id = "backpack_1",  model = "kh_backpack1",  num = 1,  name = "Тканевый рюкзак с ремешками",  size = "medium", desc = "Вместительный тканевый рюкзак с прочными кожаными ремешками." },
    { id = "backpack_2",  model = "kh_backpack2",  num = 2,  name = "Рюкзак со всем необходимым",   size = "medium", desc = "Надежный спутник, готовый вместить все самое необходимое в дороге." },
    { id = "backpack_3",  model = "kh_backpack3",  num = 3,  name = "Потрёпанный рюкзак",           size = "small",  desc = "Потрёпанный временем компактный рюкзак для самого нужного снаряжения." },
    { id = "backpack_4",  model = "kh_backpack4",  num = 4,  name = "Прочный кожаный рюкзак",       size = "medium", desc = "Добротный рюкзак из толстой дубленой кожи, устойчивый к износу." },
    { id = "backpack_5",  model = "kh_backpack5",  num = 5,  name = "Кожаный рюкзак с ремешками",   size = "medium", desc = "Кожаный походный рюкзак с удобными регулируемыми ремнями." },
    { id = "backpack_6",  model = "kh_backpack6",  num = 6,  name = "Большой вместительный рюкзак", size = "large",  desc = "Большой вместительный рюкзак из плотного брезента для солидного запаса вещей." },
    { id = "backpack_7",  model = "kh_backpack7",  num = 7,  name = "Мешковатый рюкзак",            size = "medium", desc = "Просторный мешковатый рюкзак, удобный для быстрой укладки припасов." },
    { id = "backpack_8",  model = "kh_backpack8",  num = 8,  name = "Рюкзак со спальным мешком",    size = "large",  desc = "Экспедиционный рюкзак с притороченным теплым спальником для ночлега." },
    { id = "backpack_9",  model = "kh_backpack9",  num = 9,  name = "Рюкзак кладоискателя",         size = "huge",   desc = "Тяжелый рюкзак с усиленными лямками для переноски множества реликвий и находок." },
    { id = "backpack_10", model = "kh_backpack10", num = 10, name = "Тканевый рюкзак с пуговицами", size = "small",  desc = "Небольшой матерчатый рюкзак на костяных пуговицах для мелочей." },
    { id = "backpack_11", model = "kh_backpack12", num = 11, name = "Плотный рюкзак с кармашками",  size = "large",  desc = "Плотный походный рюкзак с множеством удобных внешних отделений." },
    { id = "backpack_12", model = "kh_backpack13", num = 12, name = "Походный рюкзак",             size = "large",  desc = "Классический походный рюкзак из просмоленной ткани для защиты от дождя." },
    { id = "backpack_13", model = "kh_backpack14", num = 13, name = "Мешок с пришитыми лямками",   size = "small",  desc = "Самодельный холщовый мешок с грубыми ременными лямками." },
    { id = "backpack_14", model = "kh_backpack15", num = 14, name = "Полевой рюкзак",              size = "medium", desc = "Практичный полевой рюкзак для длительных пеших переходов." },
    { id = "backpack_15", model = "kh_backpack16", num = 15, name = "Рюкзак путника",              size = "medium", desc = "Проверенный пыльными дорогами рюкзак, верный спутник любого бродяги." },
    { id = "backpack_16", model = "khbp1",         num = 16, name = "Затяжной рюкзак",             size = "small",  desc = "Компактный заплечный рюкзак на шнурке-затяжке для быстрого доступа." },
    { id = "backpack_17", model = "khbp2",         num = 17, name = "Рюкзак с розовыми ремешками",  size = "medium", desc = "Необычный рюкзак с выцветшими крашеными ремешками и застежками." },
    { id = "backpack_18", model = "khbp3",         num = 18, name = "Рюкзак с заклёпками",         size = "small",  desc = "Небольшой проклепанный медными заклепками мешок повышенной прочности." },
    { id = "backpack_19", model = "khbp4",         num = 19, name = "Тканевый рюкзак с ремешком",  size = "medium", desc = "Легкий матерчатый рюкзак с широким поперечным фиксирующим ремнем." },
    { id = "backpack_20", model = "khbp5",         num = 20, name = "Рюкзак великого шахтёра",     size = "huge",   desc = "Колоссальный горняцкий баул с коваными пряжками для тяжелой руды и инструмента." }
}

for _, bp in ipairs(BackpackDefinitions) do
    local sizeCfg = BackpackSizes[bp.size] or BackpackSizes.medium
    local bpDef = {
        label = bp.name,
        description = bp.desc or "",
        category = "storage",
        width = 3,
        height = 3,
        maxStack = 1,
        rarity = "white",
        weight = sizeCfg.weight,
        propModel = bp.model,
        dropModel = bp.model,
        icon = "clothing_satchels",
        clothing = true,
        clothingSlot = "Satchels",
        isBackpack = true,
        isUnisex = true,
        gender = false,
        storage = { cols = sizeCfg.cols, rows = sizeCfg.rows, rowWidths = sizeCfg.rowWidths },
        isContainer = true,
        containerStorage = { cols = sizeCfg.cols, rows = sizeCfg.rows },
        canUse = false,
        actions = { "open", "place", "give", "drop" }
    }
    Items.Register(bp.id, bpDef)
    Items.Register(bp.model, bpDef)
end

-- Экспорты
exports('GetItemData', function(name)
    return Items.Get(name)
end)

exports('GetAllItems', function()
    return Items.GetAll()
end)

exports('GetItemByPropModel', function(modelHash)
    return Items.GetByPropModel(modelHash)
end)

exports('GetRarityData', function(rarity)
    return Items.GetRarity(rarity)
end)
