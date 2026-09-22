local function NormalizeSteamId(value)
    if not value or value == "" then
        return nil
    end
    value = string.lower(tostring(value))
    value = string.gsub(value, "^steam:", "")
    return value
end

local function GetPlayerSteamId(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(identifier, 1, 6) == "steam:" then
            return NormalizeSteamId(identifier)
        end
    end
    return nil
end

local function BuildSteamLookup(list)
    local lookup = {}
    for _, steamId in ipairs(list or {}) do
        local normalized = NormalizeSteamId(steamId)
        if normalized then
            lookup[normalized] = true
        end
    end
    return lookup
end

local allowedSteamLookup = BuildSteamLookup((Config.SteamLock or {}).allowedSteamIds)
local openForOthersSteamLookup = BuildSteamLookup((Config.SteamLock or {}).openForOthersSteamIds)

local function RefreshSteamLookups()
    allowedSteamLookup = BuildSteamLookup((Config.SteamLock or {}).allowedSteamIds)
    openForOthersSteamLookup = BuildSteamLookup((Config.SteamLock or {}).openForOthersSteamIds)
end

local function IsPlayerAllowed(source)
    local lock = Config.SteamLock or {}
    if not lock.enabled then
        return true
    end

    local steamId = GetPlayerSteamId(source)
    if not steamId then
        return false
    end

    return allowedSteamLookup[steamId] == true
end

local function IsPlayerAllowedToOpenForOthers(source)
    local lock = Config.SteamLock or {}
    local steamId = GetPlayerSteamId(source)
    if not steamId then
        return false
    end

    if not lock.openForOthersSteamIds or #lock.openForOthersSteamIds == 0 then
        return false
    end

    return openForOthersSteamLookup[steamId] == true
end

local function NotifyPlayer(source, message, notifyType)
    if not message or message == "" then
        return
    end
    TriggerClientEvent("wasvendel_pedmenu:notify", source, message, notifyType or "error")
end

local function IsValidPlayerId(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then
        return false
    end
    return GetPlayerName(playerId) ~= nil
end

RegisterNetEvent("wasvendel_pedmenu:requestOpen", function(targetId)
    local src = source
    local lock = Config.SteamLock or {}
    targetId = tonumber(targetId)

    if targetId and targetId ~= src then
        if not IsPlayerAllowedToOpenForOthers(src) then
            NotifyPlayer(src, lock.denyOpenForOthersMessage or "You do not have permission to open the ped menu for other players.", "error")
            return
        end

        if not IsValidPlayerId(targetId) then
            NotifyPlayer(src, lock.invalidTargetMessage or "Invalid player ID.", "error")
            return
        end

        TriggerClientEvent("wasvendel_pedmenu:openMenu", targetId)
        NotifyPlayer(targetId, lock.openedByAdminMessage or "An admin opened the ped menu for you.", "success")

        local targetName = GetPlayerName(targetId) or tostring(targetId)
        local successMessage = lock.openedForTargetMessage or "Ped menu opened for player %s."
        NotifyPlayer(src, string.format(successMessage, targetName), "success")
        return
    end

    if not IsPlayerAllowed(src) then
        NotifyPlayer(src, lock.denyMessage or "You do not have access to the ped menu.", "error")
        return
    end

    TriggerClientEvent("wasvendel_pedmenu:openMenu", src)
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    RefreshSteamLookups()
end)
