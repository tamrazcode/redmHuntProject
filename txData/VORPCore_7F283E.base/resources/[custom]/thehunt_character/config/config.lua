-- =================================================================
-- HUNT: Hard RP — Character System Configuration
-- =================================================================

Config = {}

-- DevMode: enables hot-reloading commands and debug logs
Config.DevMode = false

-- 1. Character Slot Rules
Config.CharacterSlots = {
    default = 3,  -- Regular player max slots
    admin = -1    -- -1 = Unlimited slots for admins
}

-- 2. 5-Digit Unique Code Rules
Config.UniqueCode = {
    length = 5,          -- Strictly 5 digits (00001 - 99999)
    numbersOnly = true,  -- No letters
    neverReuse = true    -- Permanently reserved even upon character deletion
}

-- 3. Age Restrictions. The RP timeline is fixed to 1907, not the real date.
Config.WorldYear = 1907
Config.MinAge = 13
Config.MaxAge = 80

-- 4. Banned Names Filter (Blacklist)
Config.BannedNames = {
    "admin", "administrator", "moderator", "mod", "owner", "developer", "server", "system",
    "hitler", "stalin", "nazi", "nigga", "nigger", "fuck", "dick", "cunt", "bitch", "whore",
    "arthur morgan", "john marston", "dutch van der linde", "micah bell", "sadie adler"
}

-- 5. Command to Reload Character Appearance / Ped
Config.ReloadCharCommand = "rc"

-- World state is intentionally persisted more often than VORP's legacy
-- five-minute core save.  This is the maximum loss window for an ungraceful
-- client crash; normal world/selection transitions save immediately as well.
Config.WorldStateSaveInterval = 5000

-- 6. Initial Spawns for Newly Created Characters
Config.FirstSpawnLocations = {
    {
        name = "Валентайн",
        description = "Шумный скотоводческий городок в сердце Нью-Ганновера.",
        coords = vector4(-174.3, 621.18, 114.08, 240.38),
    },
    {
        name = "Блэкуотер",
        description = "Развивающийся портовый город на берегу озера Плоскогорье.",
        coords = vector4(-687.3, -1242.25, 43.10, 90.58),
    },
    {
        name = "Роудс",
        description = "Южный город с красной пылью и богатыми плантациями.",
        coords = vector4(1227.77, -1304.70, 76.95, 140.49),
    },
    {
        name = "Строберри",
        description = "Уютное горное поселение среди сосновых лесов Большой Долины.",
        coords = vector4(-1789.44, -387.87, 156.40, 65.20),
    },
    {
        name = "Сен-Дени",
        description = "Крупнейший индустриальный мегаполис на восточном побережье.",
        coords = vector4(2638.12, -1224.50, 53.38, 180.00),
    }
}

-- Default starting spawn if none selected
Config.DefaultSpawn = vector4(3288.4211, -1321.1857, 42.6463, 0.7)

-- 7. Character Selection Scenes (Background, Atmosphere, Camera)
Config.SelectionScenes = {
    {
        name = "CotorraSprings",
        timecycle = { name = "finale2_campMoonPos", strength = 1.0 },
        weather = "clouds",
        -- This clock override is re-applied while selection is open, so the
        -- preview remains night regardless of the world's current time.
        time = { hour = 21, minute = 0 },
        spawn = vector4(241.28, 1963.65, 205.71, 180.0),
        camera = { x = 241.15, y = 1966.50, z = 206.50, rotx = 0.0, roty = 0.0, rotz = 180.0, fov = 38.0 },
        idleScenario = "MP_COOP_LOBBY_STANDING_A"
    }
}

-- 8. Creator Room Settings (Isolated Routing Bucket Room)
Config.CreatorRoom = {
    coords = vector4(-558.506, -3781.050, 237.60, 90.0),
    camera = { x = -561.82, y = -3780.97, z = 239.08, rotx = -4.21, roty = 0.0, rotz = -87.88, fov = 30.0 },
    timecycle = { name = "Online_Character_Editor", strength = 1.0 },
    weather = "clouds",
    time = { hour = 10, minute = 0 }
}

-- 9. Camera Presets in Creator (Relative to Ped Base)
Config.CameraPresets = {
    full = { offset = vector3(0.0, 2.3, 0.0), zTarget = 0.65, fov = 45.0 },
    torso = { offset = vector3(0.0, 1.4, 0.0), zTarget = 0.85, fov = 34.0 },
    face = { offset = vector3(0.0, 0.85, 0.0), zTarget = 1.05, fov = 26.0 },
    hair = { offset = vector3(0.0, 0.95, 0.0), zTarget = 1.15, fov = 26.0 },
    boots = { offset = vector3(0.0, 1.3, 0.0), zTarget = 0.15, fov = 35.0 }
}
