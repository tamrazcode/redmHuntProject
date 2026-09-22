-- =================================================================
-- HUNT: Hard RP — Ped Appearance & Customization Registry
-- Complete VORP / RedM Multi-Heritage System
-- =================================================================

AppearanceData = {}

-- 1. Base Models
AppearanceData.Models = {
    male = `mp_male`,
    female = `mp_female`
}

-- 2. Head Model / Heritage Presets (20 valid sparse MetaPed heads)
AppearanceData.Heads = {
    male = {},
    female = {}
}

-- These are the only head component indices present in every VORP heritage
-- variant.  The numeric range is sparse; generating 001..028 created eight
-- dead choices which the MetaPed renderer silently ignored.
local validHeadIndices = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 18, 21, 22, 25, 28
}

for displayIndex, i in ipairs(validHeadIndices) do
    local numStr = string.format("%03d", i)
    table.insert(AppearanceData.Heads.male, {
        id = i,
        hash = joaat(string.format("CLOTHING_ITEM_M_HEAD_%s_V_001", numStr)),
        label = string.format("Лицо %d", displayIndex)
    })
    table.insert(AppearanceData.Heads.female, {
        id = i,
        hash = joaat(string.format("CLOTHING_ITEM_F_HEAD_%s_V_001", numStr)),
        label = string.format("Лицо %d", displayIndex)
    })
end

-- 3. Body Build Presets (Fullness)
AppearanceData.BodyBuilds = {
    male = {
        { id = 1, name = "Стандартное", upper = joaat("CLOTHING_ITEM_M_BODIES_UPPER_001_V_001"), lower = joaat("CLOTHING_ITEM_M_BODIES_LOWER_001_V_001"), waist = -2045421226 },
        { id = 2, name = "Худощавое", upper = joaat("CLOTHING_ITEM_M_BODIES_UPPER_002_V_001"), lower = joaat("CLOTHING_ITEM_M_BODIES_LOWER_002_V_001"), waist = -1745814259 },
        { id = 3, name = "Атлетичное", upper = joaat("CLOTHING_ITEM_M_BODIES_UPPER_003_V_001"), lower = joaat("CLOTHING_ITEM_M_BODIES_LOWER_003_V_001"), waist = -325933489 },
        { id = 4, name = "Крепкое", upper = joaat("CLOTHING_ITEM_M_BODIES_UPPER_004_V_001"), lower = joaat("CLOTHING_ITEM_M_BODIES_LOWER_004_V_001"), waist = -1065791927 },
        { id = 5, name = "Массивное", upper = joaat("CLOTHING_ITEM_M_BODIES_UPPER_005_V_001"), lower = joaat("CLOTHING_ITEM_M_BODIES_LOWER_005_V_001"), waist = -844699484 },
    },
    female = {
        { id = 1, name = "Стандартное", upper = joaat("CLOTHING_ITEM_F_BODIES_UPPER_001_V_001"), lower = joaat("CLOTHING_ITEM_F_BODIES_LOWER_001_V_001"), waist = -2045421226 },
        { id = 2, name = "Худощавое", upper = joaat("CLOTHING_ITEM_F_BODIES_UPPER_002_V_001"), lower = joaat("CLOTHING_ITEM_F_BODIES_LOWER_002_V_001"), waist = -1745814259 },
        { id = 3, name = "Атлетичное", upper = joaat("CLOTHING_ITEM_F_BODIES_UPPER_003_V_001"), lower = joaat("CLOTHING_ITEM_F_BODIES_LOWER_003_V_001"), waist = -325933489 },
        { id = 4, name = "Крепкое", upper = joaat("CLOTHING_ITEM_F_BODIES_UPPER_004_V_001"), lower = joaat("CLOTHING_ITEM_F_BODIES_LOWER_004_V_001"), waist = -1065791927 },
        { id = 5, name = "Пышное", upper = joaat("CLOTHING_ITEM_F_BODIES_UPPER_005_V_001"), lower = joaat("CLOTHING_ITEM_F_BODIES_LOWER_005_V_001"), waist = -844699484 },
    }
}

-- 3.1 Waist Sizes (All 21 Native Variations)
AppearanceData.Waist = {
    -2045421226, -1745814259, -325933489, -1065791927, -844699484,
    -1273449080, 927185840, 149872391, 399015098, -644349862,
    1745919061, 1004225511, 1278600348, 502499352, -2093198664,
    -1837436619, 1736416063, 2040610690, -1173634986, -867801909, 1960266524
}

-- 3.2 Teeth Variations
AppearanceData.Teeth = {
    male = {},
    female = {}
}
for i = 0, 7 do
    table.insert(AppearanceData.Teeth.male, {
        id = i + 1,
        hash = joaat(string.format("CLOTHING_ITEM_M_TEETH_%03d", i)),
        label = string.format("Зубы %d", i + 1)
    })
    table.insert(AppearanceData.Teeth.female, {
        id = i + 1,
        hash = joaat(string.format("CLOTHING_ITEM_F_TEETH_%03d", i)),
        label = string.format("Зубы %d", i + 1)
    })
end

-- 3.3 Skin Tones (Albedo Palettes from VORP Config.DefaultChar)
AppearanceData.SkinTones = {
    { id = 1, label = "Европейский светлый", albedoM = "MP_HEAD_MR1_SC08_C0_000_AB", albedoF = "MP_HEAD_FR1_SC08_C0_000_AB" },
    { id = 2, label = "Смуглый", albedoM = "MP_HEAD_MR1_SC01_C0_000_AB", albedoF = "MP_HEAD_FR1_SC01_C0_000_AB" },
    { id = 3, label = "Загорелый", albedoM = "MP_HEAD_MR1_SC02_C0_000_AB", albedoF = "MP_HEAD_FR1_SC02_C0_000_AB" },
    { id = 4, label = "Азиатский", albedoM = "MP_HEAD_MR1_SC03_C0_000_AB", albedoF = "MP_HEAD_FR1_SC03_C0_000_AB" },
    { id = 5, label = "Индейский", albedoM = "MP_HEAD_MR1_SC04_C0_000_AB", albedoF = "MP_HEAD_FR1_SC04_C0_000_AB" },
    { id = 6, label = "Темный", albedoM = "MP_HEAD_MR1_SC05_C0_000_AB", albedoF = "MP_HEAD_FR1_SC05_C0_000_AB" }
}

-- 4. Skin Tone / Albedo Dictionaries
AppearanceData.TextureTypes = {
    male = {
        albedo = joaat("MP_HEAD_MR1_SC08_C0_000_AB"),
        normal = joaat("MP_HEAD_MR1_008_NM"),
        material = joaat("MP_HEAD_MR1_000_M")
    },
    female = {
        albedo = joaat("MP_HEAD_FR1_SC08_C0_000_AB"),
        normal = joaat("MP_HEAD_FR1_008_NM"),
        material = joaat("MP_HEAD_FR1_000_M")
    }
}

-- 5. Eye Color Palettes
AppearanceData.EyeColors = {
    male = {},
    female = {}
}

local eyeHexes = {
    -- TINT order is the native RDO eye-colour order, not a hue order.
    -- Keep every swatch paired with the same TINT hash below.
    "#c7ccca", "#4d7fab", "#294b78", "#8fcde7", "#c5dce5",
    "#75613b", "#2e7048", "#6e9d5e", "#b2c99a", "#80633b",
    "#b88a5b", "#d0b48d", "#80502f", "#3e281c"
}
local legacyEyeLabels = {
    "Темно-карие", "Карие", "Светло-карие", "Синие", "Голубые",
    "Зеленые", "Болотные", "Серые", "Светло-серые", "Стальные",
    "Графитовые", "Лазурные", "Бирюзовые", "Фиолетовые"
}

local eyeLabels = {
    "Бледно-серые", "Средне-синие", "Тёмно-синие", "Светло-голубые", "Бледно-голубые",
    "Зелёно-карие", "Тёмно-изумрудные", "Светло-зелёные", "Бледно-зелёные", "Карие",
    "Светло-карие", "Бледно-карие", "Средне-карие", "Тёмно-карие"
}

for i = 1, 14 do
    local tintStr = string.format("%03d", i)
    table.insert(AppearanceData.EyeColors.male, {
        id = i,
        hash = joaat(string.format("CLOTHING_ITEM_M_EYES_001_TINT_%s", tintStr)),
        label = eyeLabels[i] or string.format("Цвет %d", i),
        hex = eyeHexes[i] or "#3d2314"
    })
    table.insert(AppearanceData.EyeColors.female, {
        id = i,
        hash = joaat(string.format("CLOTHING_ITEM_F_EYES_001_TINT_%s", tintStr)),
        label = eyeLabels[i] or string.format("Цвет %d", i),
        hex = eyeHexes[i] or "#3d2314"
    })
end

-- 6. Height / Scale Limits
AppearanceData.Scale = {
    min = 0.828571, -- 1.45m with the 1.75m reference model
    max = 1.257143, -- 2.20m with the 1.75m reference model
    default = 1.0,
    step = 0.01
}

-- 7. Face Feature Expression Morphs (Exact Native Hashes)
AppearanceData.FaceFeatures = {
    head = {
        { id = "HeadSize", hash = 0x84D6, label = "Ширина головы", default = 0.0 },
        { id = "FaceW", hash = 41396, label = "Ширина лица", default = 0.0 },
        { id = "FaceD", hash = 12281, label = "Глубина лица", default = 0.0 },
        { id = "FaceS", hash = 13059, label = "Размер лба", default = 0.0 },
        { id = "NeckW", hash = 36277, label = "Ширина шеи", default = 0.0 },
        { id = "NeckD", hash = 60890, label = "Глубина шеи", default = 0.0 }
    },
    eyesandbrows = {
        { id = "EyeBrowH", hash = 0x3303, label = "Высота бровей", default = 0.0 },
        { id = "EyeBrowW", hash = 0x2FF9, label = "Ширина бровей", default = 0.0 },
        { id = "EyeBrowD", hash = 0x4AD1, label = "Глубина бровей", default = 0.0 },
        { id = "EyeD", hash = 0xEE44, label = "Глубина глаз", default = 0.0 },
        { id = "EyeAng", hash = 0xD266, label = "Угол глаз", default = 0.0 },
        { id = "EyeDis", hash = 0xA54E, label = "Расстояние между глазами", default = 0.0 },
        { id = "EyeH", hash = 0xDDFB, label = "Высота глаз", default = 0.0 },
        { id = "EyeLidH", hash = 0x8B2B, label = "Высота век", default = 0.0 },
        { id = "EyeLidW", hash = 0x1B6B, label = "Ширина век", default = 0.0 },
        { id = "EyeLidL", hash = 52902, label = "Открытие левого века", default = 0.0 },
        { id = "EyeLidR", hash = 22421, label = "Открытие правого века", default = 0.0 }
    },
    ears = {
        { id = "EarsW", hash = 0xC04F, label = "Ширина ушей", default = 0.0 },
        { id = "EarsA", hash = 0xB6CE, label = "Угол ушей", default = 0.0 },
        { id = "EarsH", hash = 0x2844, label = "Высота ушей", default = 0.0 },
        { id = "EarsD", hash = 0xED30, label = "Глубина ушей", default = 0.0 }
    },
    cheek = {
        { id = "CheekBonesH", hash = 0x6A0B, label = "Высота скул", default = 0.0 },
        { id = "CheekBonesW", hash = 0xABCF, label = "Ширина скул", default = 0.0 },
        { id = "CheekBonesD", hash = 0x358D, label = "Глубина скул", default = 0.0 }
    },
    jaw = {
        { id = "JawH", hash = 0x8D0A, label = "Высота челюсти", default = 0.0 },
        { id = "JawW", hash = 0xEBAE, label = "Ширина челюсти", default = 0.0 },
        { id = "JawD", hash = 0x1DF6, label = "Глубина челюсти", default = 0.0 }
    },
    chin = {
        { id = "ChinH", hash = 0x3C0F, label = "Высота подбородка", default = 0.0 },
        { id = "ChinW", hash = 0xC3B2, label = "Ширина подбородка", default = 0.0 },
        { id = "ChinD", hash = 0xE323, label = "Глубина подбородка", default = 0.0 }
    },
    nose = {
        { id = "NoseW", hash = 0x6E7F, label = "Ширина носа", default = 0.0 },
        { id = "NoseS", hash = 0x3471, label = "Размер носа", default = 0.0 },
        { id = "NoseH", hash = 0x03F5, label = "Высота носа", default = 0.0 },
        { id = "NoseAng", hash = 0x34B1, label = "Угол носа", default = 0.0 },
        { id = "NoseC", hash = 0xF156, label = "Искривление носа", default = 0.0 },
        { id = "NoseDis", hash = 0x561E, label = "Переносица", default = 0.0 }
    },
    mouthandlips = {
        { id = "MouthW", hash = 0xF065, label = "Ширина рта", default = 0.0 },
        { id = "MouthD", hash = 0xAA69, label = "Глубина рта", default = 0.0 },
        { id = "MouthX", hash = 0x7AC3, label = "Смещение рта X", default = 0.0 },
        { id = "MouthY", hash = 0x410D, label = "Смещение рта Y", default = 0.0 },
        { id = "ULiphH", hash = 0x1A00, label = "Высота верхней губы", default = 0.0 },
        { id = "ULiphW", hash = 0x91C1, label = "Ширина верхней губы", default = 0.0 },
        { id = "ULiphD", hash = 0xC375, label = "Толщина верхней губы", default = 0.0 },
        { id = "LLiphH", hash = 0xBB4D, label = "Высота нижней губы", default = 0.0 },
        { id = "LLiphW", hash = 0xB0B0, label = "Ширина нижней губы", default = 0.0 },
        { id = "LLiphD", hash = 0x5D16, label = "Толщина нижней губы", default = 0.0 },
        { id = "MouthCLW", hash = 57350, label = "Левый угол рта — ширина", default = 0.0 },
        { id = "MouthCRW", hash = 60292, label = "Правый угол рта — ширина", default = 0.0 },
        { id = "MouthCLD", hash = 40950, label = "Левый угол рта — глубина", default = 0.0 },
        { id = "MouthCRD", hash = 49299, label = "Правый угол рта — глубина", default = 0.0 },
        { id = "MouthCLH", hash = 46661, label = "Левый угол рта — высота", default = 0.0 },
        { id = "MouthCRH", hash = 55718, label = "Правый угол рта — высота", default = 0.0 },
        { id = "MouthCLLD", hash = 22344, label = "Левый угол рта — расстояние губ", default = 0.0 },
        { id = "MouthCRLD", hash = 9423, label = "Правый угол рта — расстояние губ", default = 0.0 }
    },
    upperbody = {
        { id = "ArmsS", hash = 46032, label = "Мускулатура рук", default = 0.0 },
        { id = "ShouldersS", hash = 50039, label = "Ширина плеч", default = 0.0 },
        { id = "ShouldersT", hash = 7010, label = "Толщина спины", default = 0.0 },
        { id = "ShouldersM", hash = 18046, label = "Мускулатура спины", default = 0.0 },
        { id = "ChestS", hash = 27779, label = "Размер груди", default = 0.0 },
        { id = "WaistW", hash = 50460, label = "Талия", default = 0.0 },
        { id = "HipsS", hash = 49787, label = "Бедра", default = 0.0 }
    },
    lowerbody = {
        { id = "LegsS", hash = 64834, label = "Объем бедер", default = 0.0 },
        { id = "CalvesS", hash = 42067, label = "Объем икр", default = 0.0 }
    }
}
