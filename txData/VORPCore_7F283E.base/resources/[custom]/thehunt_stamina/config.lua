Config = {}

-- Множитель скорости восстановления выносливости
Config.RechargeMultiplier = 1.0

-- Скорость восстановления выносливости (% в секунду):
Config.RegenWalk = 2.5     -- На ходу: 2.5% в сек (с 0 до 100% за ~40 секунд)
Config.RegenRest = 5.5     -- Стоя на месте: 5.5% в сек (с 0 до 100% за ~18 секунд)

-- Интервал проверки (мс)
Config.UpdateInterval = 50

-- Порог минимальной физической скорости для фиксации движения (м/с)
Config.MovingSpeedThreshold = 0.3

-- Расход только при беге с зажатым Shift (% в секунду).
-- Режим 3: полный запас на 400 секунд (6 мин 40 сек), без прыжков.
-- Режим 4: полный запас на 125 секунд (2 мин 5 сек), без прыжков.
Config.DrainMode3 = 0.25
Config.DrainMode4 = 0.8

Config.SpeedDrain = {
    [0.2] = 0.0, [0.4] = 0.0, [0.6] = 0.0, [0.9] = 0.0,
    [1.0] = 0.0, [1.4] = 0.0, [1.5] = 0.0,
    [1.6] = Config.DrainMode3,
    [2.0] = Config.DrainMode4,
}

-- Включить режим отладки
Config.Debug = false

-- One cost per actual jump, with a short recovery delay after landing.
Config.JumpCost = 6.0
Config.JumpRecoveryDelay = 1500
