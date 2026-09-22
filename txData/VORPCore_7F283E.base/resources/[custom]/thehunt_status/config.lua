-- =================================================================
-- HUNT: Hard RP — The Corruption | Status, Buffs & Debuffs Config
-- =================================================================

Config = {}

Config.Debug = false
Config.SavePersistentToDatabase = true

-- Native injured locomotion. It deliberately does not replace the player's
-- selected walk style from thehunt_menu/vorp_walkanim.
Config.LowHealthInjury = {
    enabled = true,
    threshold = 30, -- apply at 30% health or lower, but never while dead
    pedConfigFlag = 336 -- Force Injured Movement (RedM)
}

-- Предустановленные шаблоны системных и RP эффектов
Config.EffectTemplates = {
    -- 1. Админские индикаторы (бессрочные переключаемые режимы)
    ['admin_godmode'] = {
        label = "Бессмертие",
        color = "#f59e0b",       -- Золотой / Amber
        icon = "shield",
        duration = 0             -- 0 = без таймера (постоянный статус)
    },
    ['admin_superjump'] = {
        label = "Суперпрыжок",
        color = "#06b6d4",       -- Cyan / Электрический синий
        icon = "zap",
        duration = 0
    },
    ['admin_invis'] = {
        label = "Невидимость",
        color = "#a855f7",       -- Аметистовый / Фиолетовый
        icon = "eye-off",
        duration = 0
    },
    ['admin_player_ids'] = {
        label = "ID игроков",
        color = "#22c55e",       -- Изумрудный зелёный
        icon = "user-check",
        duration = 0
    },
    ['admin_blips'] = {
        label = "Метки на карте",
        color = "#ef4444",       -- Рубиновый / Красный
        icon = "map-pin",
        duration = 0
    },
    ['admin_noclip'] = {
        label = "No-Clip",
        color = "#ec4899",       -- Розовый
        icon = "navigation",
        duration = 0
    },
    ['admin_laser'] = {
        label = "3D Лазер",
        color = "#f43f5e",       -- Коралловый
        icon = "crosshair",
        duration = 0
    },
    ['admin_freeze_ped'] = {
        label = "Заморозка",
        color = "#64748b",       -- Серый
        icon = "pause",
        duration = 0
    },
    ['admin_freeze_hunger'] = {
        label = "Заморозка еды",
        color = "#10b981",       -- Изумрудный
        icon = "coffee",
        duration = 0
    },
    ['admin_freeze_thirst'] = {
        label = "Заморозка жажды",
        color = "#38bdf8",       -- Голубой
        icon = "droplet",
        duration = 0
    },
    ['admin_freeze_stamina'] = {
        label = "Заморозка энергии",
        color = "#eab308",       -- Желтый
        icon = "zap",
        duration = 0
    },

    -- 2. Шаблоны для RP-дебаффов и травм
    ['poison_snake'] = {
        label = "Яд змеи",
        color = "#8b5cf6",       -- Ядовитый фиолетовый
        icon = "flame",
        duration = 60000         -- 60 секунд
    },
    ['injury_bleed'] = {
        label = "Кровотечение",
        color = "#dc2626",       -- Кровяной красный
        icon = "heart-crack",
        duration = 45000         -- 45 секунд
    },
    ['injury_fracture'] = {
        label = "Перелом ноги",
        color = "#f97316",       -- Оранжевый
        icon = "activity",
        duration = 180000        -- 3 минуты
    },
    ['buff_stamina'] = {
        label = "Бодрость",
        color = "#eab308",       -- Золотистый
        icon = "wind",
        duration = 120000        -- 2 минуты
    },
    ['buff_well_fed'] = {
        label = "Сытость",
        color = "#10b981",       -- Свежий зеленый
        icon = "coffee",
        duration = 300000        -- 5 минут
    }
}
