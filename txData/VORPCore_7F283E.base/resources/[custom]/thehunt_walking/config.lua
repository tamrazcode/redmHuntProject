Config = {}

-- =================================================================
-- HUNT: Hard RP — Настройки скоростей передвижения (из hex-walking)
-- =================================================================

Config.Movement = {
    MIN_SPEED       = 0.2,   -- Минимальная скорость (режим 1 без Shift)
    MAX_SPEED       = 2.0,   -- Максимальная скорость (режим 3 с Shift)
    SPEED_INCREMENT = 1,     -- Переключение между тремя режимами
    DEFAULT_SPEED   = 0.8,   -- Скорость по умолчанию (режим 2 без Shift)
    AUTO_RUN_SPEED  = 1.6    -- Скорость во время авто-бега (режим 2 с Shift)
}

-- Настройки визуальной индикации
Config.Display = {
    DISPLAY_TIME     = 2000, -- Время отображения текста скорости на экране (мс)
    SHOW_SCREEN_TEXT = false, -- Текстовая плашка по центру (false = используется круглый индикатор в thehunt_status)
    -- Пороги и текстовые индикаторы
    SPEED_INDICATORS = {
        { threshold = 0.34, text = "~COLOR_GREEN~+~COLOR_WHITE~++" },  -- Режим 1
        { threshold = 0.67, text = "~COLOR_YELLOW~++~COLOR_WHITE~+" }, -- Режим 2
        { threshold = 1.0,  text = "~COLOR_RED~+++" }                    -- Режим 3
    }
}

-- Настройки функции Авто-бега (Auto-Run)
Config.AutoRun = {
    ENABLED          = true,   -- Включена ли система авто-бега
    CHARGE_TIME      = 2000,   -- Время удержания клавиши для активации авто-бега (мс)
    FORWARD_DISTANCE = 20.0    -- Дистанция прокладывания вектора движения
}

-- Привязка клавиш управления
Config.Controls = {
    -- Модификаторы для вызова меню/регулировки
    ALT_HUD_SPECIAL  = 0x580C4473, -- Left Alt (RDR2 joaat hash INPUT_HUD_SPECIAL)
    ALT_FALLBACK     = 0x8AAA0DE4, -- Left Alt fallback
    SPRINT           = 0x8FFC75D6, -- Left Shift

    -- Клавиши изменения скорости
    INCREASE_SPEED   = 0x6319DB71, -- Up Arrow
    DECREASE_SPEED   = 0x05CA7C52, -- Down Arrow
    RESET_SPEED      = 0xE30CD707, -- R
    MAX_SPEED        = 0xDEB34313, -- Right Arrow
    MIN_SPEED        = 0xA65EBAB4, -- Left Arrow

    -- Авто-бег
    TOGGLE_AUTORUN   = 0x760A9C6F, -- G (удерживать во время спринта)
    CANCEL_AUTORUN   = 0x8CC9CD42, -- X (отмена авто-бега)
    LOCK_CAMERA      = 0x9959A6F0  -- C (удерживать для фиксации курса без следования за камерой)
}
