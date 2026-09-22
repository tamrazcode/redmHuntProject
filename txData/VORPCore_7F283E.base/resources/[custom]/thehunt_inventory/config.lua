-- =================================================================
-- HUNT: Hard RP — The Corruption | Grid Inventory Configuration (DayZ)
-- =================================================================

Config = {}

-- Параметры сеток (7 в длину x 3 в высоту для базового инвентаря)
Config.Grids = {
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

-- Equipment is deliberately kept separate from the main grid.  `x` is the
-- stable equipment slot id stored in the database; it is never a free-form
-- inventory coordinate.
Config.Equipment = {
    label = "Одежда",
    cols = 2,
    rows = 15,
    slots = {
        "Hat", "Mask", "EyeWear", "NeckWear", "Shirt", "Vest", "Coat", "CoatClosed", "Poncho", "Cloak",
        "Pant", "Skirt", "Dress", "Boots", "Spurs", "Spats", "Chap", "Gunbelt", "Holster", "Belt",
        "Suspender", "Glove", "Gauntlets", "Accessories", "Bracelet", "RingLh", "RingRh", "Satchels"
    },
    -- Keep database slot IDs stable after removing Buckle (20) and Badge (25).
    slotIds = {
        Hat = 0, Mask = 1, EyeWear = 2, NeckWear = 3, Shirt = 4, Vest = 5,
        Coat = 6, CoatClosed = 7, Poncho = 8, Cloak = 9, Pant = 10, Skirt = 11,
        Dress = 12, Boots = 13, Spurs = 14, Spats = 15, Chap = 16, Gunbelt = 17,
        Holster = 18, Belt = 19, Suspender = 21, Glove = 22, Gauntlets = 23,
        Accessories = 24, Bracelet = 26, RingLh = 27, RingRh = 28, Satchels = 29
    }
}

-- Дистанция для отображения предметов рядом
Config.VicinityDistance = 1.5

-- Максимальная дистанция передачи предметов другому игроку
Config.TransferDistance = 1.0

-- =================================================================
-- Весовая система персонажа (DayZ Style)
-- =================================================================
-- Базовый максимальный переносимый вес (в килограммах)
Config.MaxWeight = 30.0

-- Максимальный допустимый перевес выше базового веса (в килограммах)
-- Предельный вес, который физически может нести персонаж: MaxWeight + MaxOverweightMargin = 35.0 кг
Config.MaxOverweightMargin = 5.0

-- =================================================================
-- =================================================================
-- Анимация открытия инвентаря (поворот торса влево и копашение в сумке)
-- =================================================================
Config.InventoryAnimation = {
    enabled = true,
    dict = "mech_loco_m@character@arthur@special@crafting@satchel",
    anim = "idle",
    -- The RDR3 dictionary contains only `idle`; trying made-up fallback
    -- clips resets the secondary task and causes a visible jerk while moving.
    anims = { "idle" },
    flag = 31,
    blendInSpeed = 2.0,
    blendOutSpeed = -2.0,
    reapplyDelay = 900,

    -- Native saddle-bag loop.  It is used only while mounted and is always
    -- played on the upper-body/secondary layer, so the legs remain in the
    -- horse-riding seat animation.
    mounted = {
        dict = "mech_inventory@horse@right@weapon@shortarms@saddle_bag@shortarms@d20cm",
        anim = "horse_base",
        anims = { "horse_base", "horse_base_no_offhand", "base", "base_no_offhand" },
        flag = 31,
        blendInSpeed = 2.0,
        blendOutSpeed = -2.0,
        reapplyDelay = 900
    }
}
