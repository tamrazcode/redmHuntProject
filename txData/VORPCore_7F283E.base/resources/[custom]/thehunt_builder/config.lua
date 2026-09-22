-- =================================================================
-- HUNT: Hard RP — The Corruption | World Builder & Object Placer Config
-- Проверенные и 100% валидные модели RDR3 для строительства и обустройства
-- =================================================================

Config = {}

Config.StreamDistance      = 600.0  -- Радиус стриминга кастомных объектов (метры)
Config.MaxConcurrentSpawns = 12     -- Макс. параллельных загрузок моделей (throttle от фризов)
-- Hard cap for persistent builder props around the streaming center. The
-- streamer always selects the nearest props first before filling the queue.
Config.MaxStreamedProps    = 500
Config.EntityLodDistance   = 600    -- Integer required by SET_ENTITY_LOD_DIST; do not pass a Lua float.
Config.RaycastDistance     = 35.0   -- Максимальная дистанция луча инспектора

-- Категоризированный каталог объектов (100% существующие модели RDR3)
Config.PropCategories = {
    {
        id = "camp",
        label = "Лагерь и выживание",
        icon = "tent",
        props = {
            { name = "Большой шатёр банды", model = "mp005_s_posse_tent_bighorn01x" },
            { name = "Военная палатка", model = "mp005_s_posse_tent_military01x" },
            { name = "Брезентовая палатка", model = "p_tent_burlap01x" },
            { name = "Холщовая палатка", model = "p_tent_canvas01x" },
            { name = "Походный навес", model = "p_leanto01x" },
            { name = "Костер с камнями", model = "p_campfire05x" },
            { name = "Костер с вертелом", model = "p_campfire02x" },
            { name = "Свежий костер", model = "p_campfirefresh01x" },
            { name = "Разложенный спальник", model = "p_bedrollopen01x" },
            { name = "Свернутый спальник", model = "p_bedrollrolled01x" },
            { name = "Вязанка дров", model = "p_woodpile01x" },
            { name = "Большая поленница", model = "p_woodpile02x" },
            { name = "Походный чайник", model = "p_kettle01x" },
            { name = "Котелок для варки", model = "p_cookingpot01x" },
        }
    },
    {
        id = "barricades",
        label = "Баррикады и оборона",
        icon = "shield",
        props = {
            { name = "Мешки с песком (прямые)", model = "p_sandbag01x" },
            { name = "Мешки с песком (угол)", model = "p_sandbag02x" },
            { name = "Мешки с песком (высокие)", model = "p_sandbag03x" },
            { name = "Баррикада из досок", model = "p_barricade01x" },
            { name = "Баррикада с кольями", model = "p_barricade02x" },
            { name = "Тяжёлая баррикада", model = "p_barricade03x" },
            { name = "Защитные колья", model = "p_spikes01x" },
            { name = "Колесо повозки", model = "p_wagonwheel01x" },
            { name = "Старое колесо", model = "p_wagonwheel02x" },
            { name = "Остов повозки", model = "p_wagonwreck01x" },
            { name = "Разбитая повозка", model = "p_wagonwreck02x" },
        }
    },
    {
        id = "storage",
        label = "Хранилища и припасы",
        icon = "archive",
        props = {
            { name = "Деревянный ящик", model = "p_crate01x" },
            { name = "Малый ящик", model = "p_crate02x" },
            { name = "Штабель ящиков", model = "p_crate03x" },
            { name = "Прямоугольный ящик", model = "p_crate04x" },
            { name = "Открытый ящик", model = "p_crate05x" },
            { name = "Большой сундук", model = "p_chest01x" },
            { name = "Кованый сундук", model = "p_chest02x" },
            { name = "Дорожный сундук", model = "p_trunk01x" },
            { name = "Ящик с патронами", model = "p_ammocrate01x" },
            { name = "Дубовая бочка", model = "p_barrel01x" },
            { name = "Старая бочка", model = "p_barrel02x" },
            { name = "Малая бочка", model = "p_barrel03x" },
            { name = "Мешок с зерном", model = "p_sack01x" },
            { name = "Мешок с мукой", model = "p_sack02x" },
            { name = "Группа мешков", model = "p_sackgroup01x" },
            { name = "Кожаный чемодан", model = "p_suitcase01x" },
        }
    },
    {
        id = "furniture",
        label = "Мебель и освещение",
        icon = "home",
        props = {
            { name = "Деревянный стол", model = "p_table01x" },
            { name = "Круглый стол", model = "p_table02x" },
            { name = "Обеденный стол", model = "p_table03x" },
            { name = "Деревянный стул", model = "p_chair01x" },
            { name = "Походный стул", model = "p_chair02x" },
            { name = "Табурет", model = "p_chair04x" },
            { name = "Деревянная скамья", model = "p_bench01x" },
            { name = "Длинная лавка", model = "p_bench02x" },
            { name = "Грубая скамейка", model = "p_bench03x" },
            { name = "Керосиновая лампа", model = "p_lantern01x" },
            { name = "Масляный фонарь", model = "p_lantern02x" },
            { name = "Подвесной фонарь", model = "p_lanternhanging01x" },
            { name = "Настенный факел", model = "p_torch01x" },
            { name = "Стойка для винтовок", model = "p_gunrack01x" },
        }
    },
    {
        id = "nature",
        label = "Окружение и антураж",
        icon = "sun",
        props = {
            { name = "Поваленное бревно", model = "p_log01x" },
            { name = "Срубленное дерево", model = "p_log02x" },
            { name = "Большой валун", model = "p_rock01x" },
            { name = "Плоский камень", model = "p_rock02x" },
            { name = "Деревянный крест", model = "p_cross01x" },
            { name = "Могильный крест", model = "p_cross02x" },
            { name = "Надгробный камень", model = "p_gravestone01x" },
            { name = "Праздничная ель", model = "mp006_p_xmastree01x" },
        }
    }
}
