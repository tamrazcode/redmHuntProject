-- =================================================================
-- HUNT: Hard RP — The Corruption | World Loot Configuration
-- =================================================================

Config = {}

-- Радиус по умолчанию (метры)
Config.DefaultActivationRadius = 90.0  -- Радиус активации симуляции зоны сервером (когда игрок рядом)
Config.DefaultRenderRadius     = 45.0  -- Радиус стриминга клиентских visual prop-моделей
Config.DefaultMinDistance      = 2.0   -- Минимальное расстояние между точками лута внутри зоны (метры)
Config.DefaultLifetime         = 1800  -- Время жизни нетронутого предмета (секунды, 30 минут; 0 = бесконечно)
Config.DefaultMinRespawn       = 300   -- Минимальный кулдаун респавна зоны (5 минут)
Config.DefaultMaxRespawn       = 900   -- Максимальный кулдаун респавна зоны (15 минут)
Config.DefaultMaxItems         = 5     -- Максимум активных слотов в зоне по умолчанию
Config.DefaultMinItems         = 2     -- Минимум предметов при генерации

-- Частота тиков
Config.ServerSimulationInterval = 3000 -- Интервал проверки зон сервером (мс)
Config.ClientStreamInterval     = 600  -- Интервал стриминга пропов клиентом (мс)
Config.MaxConcurrentSpawns      = 8    -- Максимум параллельных спавнов моделей на клиенте

-- Дистанция подбора
Config.PickupDistance = 2.2 -- Максимальная дистанция для подбора предмета
Config.PickupKey = 0xCEFD9220 -- Клавиша E (RedM Control)

-- Дефолтные безопасные проп-модели для контейнеров и лута (если у предмета нет модели)
Config.DefaultContainerModel = "p_crate26x_b"
Config.DefaultLootPropModel  = "p_crate26x_b"

-- Доступные типы зон
Config.ZoneTypes = {
    circle = {
        label = "Круг / Цилиндр",
        icon = "circle",
        description = "Улицы, дворы, поляны, лагеря, открытые развалины"
    },
    rectangle = {
        label = "Прямоугольник (Box)",
        icon = "square",
        description = "Здания, комнаты, коридоры, кварталы"
    },
    polygon = {
        label = "Многоугольник",
        icon = "polygon",
        description = "Сложные территории с произвольными углами и вершинами"
    },
    point = {
        label = "Фиксированная точка",
        icon = "map-pin",
        description = "Полки, столы, кровати, шкафы, подоконники"
    },
    container = {
        label = "Контейнер / Тайник",
        icon = "box",
        description = "Сундуки, бочки, ящики, трупы, шкафчики с кастомным пропом"
    }
}

-- Цвета отображения фигур для thehunt_shapes в редакторе (RGBA)
Config.EditorColors = {
    active = { r = 255, g = 159, b = 67, a = 140 },      -- Теплый оранжевый/акцентный для выделенной зоны
    normal = { r = 56, g = 189, b = 248, a = 100 },      -- Голубой (Steel Blue) для обычных зон
    disabled = { r = 239, g = 68, b = 68, a = 80 },      -- Красный для выключенных
    vertex = { r = 34, g = 197, b = 94, a = 220 },       -- Зеленый для вершин полигона
    selectedVertex = { r = 255, g = 255, b = 255, a = 255 }, -- Белый для выбранной вершины
    groundRay = { r = 255, g = 255, b = 255, a = 200 }   -- Белый луч
}
