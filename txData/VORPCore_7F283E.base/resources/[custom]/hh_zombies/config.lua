Config = {}

--------------------------------------------------------------------------------
-- КУДА СМОТРЕТЬ ХЕШИ (скопируй понравившееся в этот файл)
--------------------------------------------------------------------------------
-- Педы и число комплектов одежды:
--   https://github.com/femga/rdr3_discoveries/blob/master/peds/peds_list.lua
-- Анимации (словарь + клип):
--   https://github.com/femga/rdr3_discoveries/blob/master/animations/ingameanims/ingameanims_list.lua
-- Сценарии (стоять / есть / копать — не локомоция):
--   https://github.com/femga/rdr3_discoveries/tree/master/animations/scenarios
-- Клипсеты ходьбы (пьяная / раненая походка под зомби):
--   https://github.com/femga/rdr3_discoveries/tree/master/animations/clip_sets
-- Оружие:
--   https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapons.lua
-- Нативы RedM:
--   https://alloc8or.re/rdr3/nativedb/
-- Блипы карты:
--   https://github.com/femga/rdr3_discoveries/tree/master/useful_info_from_rpfs/textures/blips
--
-- В игре (только админ: группа admin/superadmin или ACE hh_zombies.admin):
--   F11              — вид сверху: мышью центр и размер, затем модели
--   F12              — список созданных зон и удаление
--   /zonelist        — список зон
--   /zonedel <id>    — удалить зону
--   /zzone           — текущая точка

Config.Admin = {
    groups = { "admin", "superadmin" },
    aces = {
        "hh_zombies.admin",
        "hh_zombies.zones",
        "command",
        "group.admin",
    },
}

Config.Debug = false -- метки зомби на карте и сообщения в F8
Config.Tick = 1000  -- как часто проверяем, внутри ли игрок зоны
Config.AITick = 500 -- частота обновления ИИ
Config.SpawnPerTick = 6 -- большую толпу создаём порциями, без фриза клиента
Config.SpawnAttempts = 25 -- попытки найти navmesh и свободную точку

Config.ZoneEditor = {
    showNearby = false,
    nearbyPadding = 90.0,
    markerAlpha = 70,
    previewAlpha = 110,
    hotkey = "F11",
    listHotkey = "F12",
}

Config.Sound = {
    enabled = true,
    -- Основной путь — xsound: настоящий 3D-звук от позиции педа.
    -- Если ресурс не запущен, автоматически используется NUI-резерв.
    useXSound = true,
    -- Файлы лежат в xsound/html/sounds/. Если добавишь новый .ogg —
    -- скопируй его туда же, иначе xsound его не увидит.
    xsoundRelativePath = true,
    positionTick = 150, -- как часто двигать источник звука за зомби
    aliveLifetime = 12000,
    deathLifetime = 9000,
    aliveFiles = {
        "defolt.ogg",
        "defolt2.ogg",
    },
    deathFiles = {
        "dead.ogg",
        "dead2.ogg",
    },
    -- Живые рыки: не больше пары рядом, иначе defolt наслаивается в кашу.
    deathChance = 0.35,
    minInterval = 1800,
    maxInterval = 4200,
    aliveMinGap = 1500, -- пауза между стартом двух рыков
    maxAliveSimultaneous = 2,
    aliveDistance = 12.0,
    deathDistance = 22.0,
    maxDistance = 22.0,
    maxVolume = 0.09,
    deathVolume = 0.11,
    maxSimultaneous = 2,
}

-- Стиль боя, походки и другая хуйня.
Config.Zombie = {
    health = 250,
    accuracy = 5,
    melee = true,
    weapon = "WEAPON_UNARMED", -- или WEAPON_MELEE_KNIFE
    fightRange = 80.0,
    detectionDistance = 15.0, -- бег / открытая позиция
    idleRetask = 10000,      -- как часто обновлять спокойное блуждание
    -- Убитые НЕ появляются сразу. Недостающие досыпаются только после того,
    -- как игрок непрерывно провёл в зоне это время. Затем отсчёт начинается снова.
    restockDelay = 900000,   -- 15 минут
    initialFillTimeout = 60000, -- сколько даём на первичное заполнение зоны
    -- С края зоны зомби уже должны быть в центре, а не вылезать у ног.
    approachPadding = 45.0,  -- начинаем наполнять, пока игрок ещё на подходе
    initialCoreRatio = 0.36, -- первая волна живёт во внутренней части зоны
    minSpawnDistance = 22.0, -- не спавнить вплотную к игроку
    spawnFadeMs = 750,
    -- После выхода из радиуса зомби и трупы ещё бродят, без респавна.
    -- Если за это время зайдёт другой игрок — толпа не обновляется.
    linger = {
        min = 300, -- секунды = 5 минут
        max = 600, -- 10 минут
    },
    -- Погоня сбрасывается, если цель сьебалась далеко.
    deaggroDistance = 42.0,
    deaggroTime = 2500,
    stealth = {
        enabled = true,
        crouchDistance = 2.4,
        stillDistance = 3.8,
        walkDistance = 8.0,
        runDistance = 15.0,
        stillSpeed = 0.35,
        walkSpeed = 2.3,
        touchDistance = 1.4, -- в упор видят даже из-за угла
        requireLos = true,
    },
    noise = {
        enabled = true,
        hearDistance = 140.0, -- выстрел
        meleeHearDistance = 8.0, -- нож / топор / рукопашная. 0 = ближний бой не создаёт шум
        investigateTime = 25000,
        retaskTime = 5000,
        stopDistance = 2.5,
        turnTime = 700, -- сначала плавно повернуться, затем начать идти, шоб особо не дёргались гандончики
        speed = 1.05,
        maxBlend = 0.90,
        style = "moderate_drunk",
    },

    locomotion = {
        base = "default",
        walkStyles = {
            "dehydrated_unarmed",
            "moderate_drunk",
        },
        runStyle = "very_drunk",
        walkMaxBlend = 0.55,
        runMaxBlend = 1.65,
        moveRate = 0.95,
        chaseSpeed = 1.65,   -- заметно быстрее, но всё ещё ниже полного спринта
        chaseStopDistance = 1.15, -- иначе останавливаются в 2–3 м и только смотрят
        attackDistance = 3.6,
        attackLeaveDistance = 5.2, -- гистерезис, чтобы не мигать погоня/удар
    },

    armsRun = {
        enabled = false, -- временно отключено, да и пока нахуй не нужно
    },

    corpses = {
        timedChance = 0.60, -- 60% исчезнут через случайное время
        minLifetime = 45,   -- секунды
        maxLifetime = 150,
        -- Остальные 40% лежат, пока зона не очистится после linger.
    },

    -- Тип выбирается один раз при спавне и сохраняется до смерти.
    speedProfiles = {
        {
            id = "walker",
            chance = 0.35,
            label = "Ходок",
            style = "dehydrated_unarmed",
            chaseSpeed = 0.80,
            maxBlend = 0.75,
            moveRate = 0.70,
            combatChase = false,
        },
        {
            id = "shambler",
            chance = 0.40,
            label = "Средний",
            style = "very_drunk",
            chaseSpeed = 1.65,
            maxBlend = 1.65,
            moveRate = 0.95,
            combatChase = false,
        },
        {
            id = "runner",
            chance = 0.25,
            label = "Бегун",
            -- very_drunk сам по себе медленный. action даёт нормальный бег для бегущих по лезвию гандончиков
            base = "default",
            style = "action",
            chaseSpeed = 3.0,
            minBlend = 2.6,
            maxBlend = 3.0,
            moveRate = 3.0,
            combatChase = false,
        },
    },
}

-- Модели которые типа зомбэ
Config.Models = {
    "a_f_m_armcholeracorpse_01",          -- 0x53367A8A
    "u_m_m_vhtstationclerk_01",           -- 0xC606A445
    "u_m_m_apfdeadman_01",                -- 0x0717C9F9
    "re_savageaftermath_females_01",      -- 0xA8D0FBF7
    "re_savageaftermath_males_01",        -- 0xF7C4FD8C
    "re_savagewarning_males_01",          -- 0x6461654D
    "re_voice_females_01",                -- 0x6A5B1E21
    "re_corpsecart_males_01",             -- 0x5220FFBE
}

-- Отдельный зимний пул для Колтера.
Config.ColterModels = {
    "re_frozentodeath_females_01",        -- 0x8755FDCB
    "re_frozentodeath_males_01",          -- 0xC9CFCE6D
    "re_boatattack_males_01",             -- 0xFB4137F2
}

-- подхеши хешей не трогать!
Config.ModelOutfitCounts = {
    a_f_m_armcholeracorpse_01 = 40,
    a_f_m_unicorpse_01 = 49,
    a_m_m_armcholeracorpse_01 = 38,
    u_m_m_vhtstationclerk_01 = 9,
    u_m_m_apfdeadman_01 = 1,
    shack_ontherun_males_01 = 3,
    re_savageaftermath_females_01 = 2,
    re_savageaftermath_males_01 = 5,
    re_savagewarning_males_01 = 7,
    re_townburial_males_01 = 18,
    re_voice_females_01 = 1,
    re_corpsecart_males_01 = 3,
    rcsp_dutch1_males_01 = 8,
    re_frozentodeath_females_01 = 1,
    re_frozentodeath_males_01 = 1,
    re_lostfriend_males_01 = 5,
    re_boatattack_males_01 = 3,
}

-- Сюда добавляются только плохие варианты конкретной модели.
-- Пример: ["re_townburial_males_01"] = { [2] = true, [7] = true }
Config.ModelOutfitBlacklist = {
}

Config.Appearance = {
    minScale = 0.94,
    maxScale = 1.06,
}

-- Готовые зоны городов: config_zones.lua
-- Зоны с F11 хранятся в БД и в этот список не пишутся.
