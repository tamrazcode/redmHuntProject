Config = {}

Config.Commands = {
    open = "pedmenu",
    -- Command executed when Restore is clicked (without /)
    restore = "rc",
}

Config.CommandSuggestions = {
    open = {
        help = "Open the ped menu (admins: add player ID to open for someone else)",
        params = {
            { name = "id", help = "Target player server ID" },
        },
    },
}

-- Preview ped auto-delete (ms)
Config.PreviewDuration = 15000

-- Preview ped distance from player (meters)
Config.PreviewDistance = 2.5

-- Steam ID access lock
-- allowedSteamIds: can open the menu for themselves (/pedmenu)
-- openForOthersSteamIds: can open the menu for another player (/pedmenu [id])
-- Use full form: "steam:110000xxxxxxxx" or just the hex part.
Config.SteamLock = {
    enabled = false,
    allowedSteamIds = {
        -- "steam:110000103fd1bb1",
        -- "110000103fd1bb1",
    },
    openForOthersSteamIds = {
        -- "steam:110000103fd1bb1",
    },
    denyMessage = "You do not have access to the ped menu.",
    denyOpenForOthersMessage = "You do not have permission to open the ped menu for other players.",
    invalidTargetMessage = "Invalid player ID.",
    openedForTargetMessage = "Ped menu opened for player %s.",
    openedByAdminMessage = "An admin opened the ped menu for you.",
}

Config.Lang = {
    menuTitle = "Ped Menu",
    searchPlaceholder = "Search...",
    categoryLabel = "Category",
    allCategories = "All",
    outfit = "Outfit",
    preview = "Preview",
    apply = "Apply",
    restore = "Restore",
    copied = "Copied",
    copyTitle = "Copy",
}

Config.Categories = {
    { id = "all", label = "All" },
    { id = "player", label = "Player" },
    { id = "animal", label = "Animals" },
    { id = "ambient_male", label = "Ambient Male" },
    { id = "ambient_female", label = "Ambient Female" },
    { id = "unique", label = "Unique NPC" },
    { id = "gang", label = "Gang" },
    { id = "cutscene", label = "Cutscene" },
    { id = "mp", label = "Story / MP" },
    { id = "special", label = "Special" },
    { id = "other", label = "Other" },
}
