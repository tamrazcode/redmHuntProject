-- =================================================================
-- HUNT: Hard RP — The Corruption | Scene Text Placer Config
-- =================================================================

Config = {}

-- Максимальная дальность размещения сцены от персонажа (в метрах)
Config.RaycastDistance = 8.0

-- Максимальное общее количество активных сцен на сервере
Config.MaxGlobalScenes = 200

-- Лимит активных сцен на одного игрока (для защиты от спама)
Config.MaxPlayerScenes = 5

-- Максимальная длина текста сцены
Config.MaxTextLength = 250

-- Радиус взаимодействия для удаления сцены по клавише (метры)
Config.InteractDistance = 2.5

-- Доступные цвета для текста
Config.TextColors = {
    { id = 1, label = "Белый",      hex = "#FFFFFF", r = 255, g = 255, b = 255 },
    { id = 2, label = "Золотой",    hex = "#F59E0B", r = 245, g = 158, b = 11  },
    { id = 3, label = "Кровавый",   hex = "#EF4444", r = 239, g = 68,  b = 68  },
    { id = 4, label = "Зелёный",    hex = "#22C55E", r = 34,  g = 197, b = 94  },
    { id = 5, label = "Голубой",    hex = "#38BDF8", r = 56,  g = 189, b = 248 },
    { id = 6, label = "Фиолетовый", hex = "#A855F7", r = 168, g = 85,  b = 247 },
    { id = 7, label = "Пепельный",  hex = "#9CA3AF", r = 156, g = 163, b = 175 },
}

-- Доступные варианты времени жизни (секунды)
Config.DurationOptions = {
    { label = "15 мин",   value = 900   },
    { label = "30 мин",   value = 1800  },
    { label = "1 час",    value = 3600  },
    { label = "3 часа",   value = 10800 },
    { label = "6 часов",  value = 21600 },
    { label = "12 часов", value = 43200 },
    { label = "24 часа",  value = 86400 },
    { label = "Навсегда", value = 0     },
}

-- Варианты дистанции видимости текста (в метрах)
Config.DistanceOptions = {
    { label = "5 м",  value = 5.0  },
    { label = "10 м", value = 10.0 },
    { label = "15 м", value = 15.0 },
    { label = "25 м", value = 25.0 },
}

-- Значения по умолчанию
Config.DefaultDuration = 1800      -- 30 минут
Config.DefaultColorIndex = 2      -- Золотой
Config.DefaultDistance = 15.0     -- 15 метров
Config.DefaultTextScale = 0.35    -- Базовый размер шрифта
