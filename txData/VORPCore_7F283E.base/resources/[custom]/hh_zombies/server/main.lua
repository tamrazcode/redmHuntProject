local zoneData = {}
local runtimeZones = {}
local disabledBuiltin = {}
local Core = exports.vorp_core:GetCore()

local function lingerSeconds()
    local linger = Config.Zombie and Config.Zombie.linger or {}
    local minTime = linger.min or 300
    local maxTime = math.max(minTime, linger.max or 600)
    return math.random(minTime, maxTime)
end

local function isAdmin(src)
    if not src or src == 0 then
        return true
    end

    local aces = (Config.Admin and Config.Admin.aces) or {
        "hh_zombies.admin",
        "hh_zombies.zones",
        "command",
        "group.admin",
    }
    for i = 1, #aces do
        if IsPlayerAceAllowed(src, aces[i]) then
            return true
        end
    end

    local user = Core.getUser(src)
    if not user then
        return false
    end

    local group = user.getGroup
    local groups = (Config.Admin and Config.Admin.groups) or { "admin", "superadmin" }
    for i = 1, #groups do
        if group == groups[i] then
            return true
        end
    end

    return false
end

local function isZoneAdmin(src)
    return isAdmin(src)
end

local function pushAdmin(src)
    if src and GetPlayerName(src) then
        TriggerClientEvent("hh_zombies:setAdmin", src, isAdmin(src))
    end
end

local function modelsFromKey(key)
    if key == "colter" then
        return Config.ColterModels
    end
    return Config.Models
end

local function sanitizeModels(raw)
    local list, seen = {}, {}
    if type(raw) ~= "table" then
        return list
    end
    for i = 1, #raw do
        local name = raw[i]
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            list[#list + 1] = name
            if #list >= 64 then
                break
            end
        end
    end
    return list
end

local function modelsFromRow(row)
    if row.models_json and row.models_json ~= "" then
        local ok, decoded = pcall(json.decode, row.models_json)
        if ok then
            local list = sanitizeModels(decoded)
            if #list > 0 then
                return list, "custom"
            end
        end
    end
    return modelsFromKey(row.models_key), row.models_key or "default"
end

local function serializeZone(zone)
    return {
        id = zone.id,
        label = zone.label,
        enabled = zone.enabled ~= false,
        x = zone.coords.x,
        y = zone.coords.y,
        z = zone.coords.z,
        radius = zone.radius,
        count = zone.count,
        spawnAcrossZone = zone.spawnAcrossZone ~= false,
        spread = zone.spread,
        maxSpawnHeightDiff = zone.maxSpawnHeightDiff or 6.0,
        models = zone.models,
        modelsKey = zone.modelsKey or "default",
        custom = zone.custom == true,
        builtin = zone.builtin == true,
    }
end

local function customZoneList()
    local list = {}
    for i = 1, #runtimeZones do
        local zone = runtimeZones[i]
        if zone.custom then
            list[#list + 1] = {
                id = zone.id,
                label = zone.label,
                radius = zone.radius,
                count = zone.count,
                x = zone.coords.x,
                y = zone.coords.y,
                z = zone.coords.z,
            }
        end
    end
    return list
end

local function pushZoneManager(src)
    if src and GetPlayerName(src) then
        TriggerClientEvent("hh_zombies:zoneManager", src, customZoneList())
    end
end

local function rebuildRuntimeZones()
    runtimeZones = {}

    for i = 1, #Config.Zones do
        local zone = Config.Zones[i]
        if zone.enabled ~= false and not disabledBuiltin[zone.id] then
            runtimeZones[#runtimeZones + 1] = {
                id = zone.id,
                label = zone.label,
                enabled = true,
                coords = zone.coords,
                radius = zone.radius,
                count = zone.count,
                spawnAcrossZone = zone.spawnAcrossZone,
                spread = zone.spread,
                maxSpawnHeightDiff = zone.maxSpawnHeightDiff,
                models = zone.models,
                modelsKey = zone.models == Config.ColterModels and "colter" or "default",
                builtin = true,
                custom = false,
            }
        end
    end
end

local function broadcastZones(target)
    local payload = {}
    for i = 1, #runtimeZones do
        payload[i] = serializeZone(runtimeZones[i])
    end

    if target then
        TriggerClientEvent("hh_zombies:syncZones", target, payload)
    else
        TriggerClientEvent("hh_zombies:syncZones", -1, payload)
    end
end

local function loadDatabaseZones()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS hh_zombie_zones (
            id VARCHAR(64) NOT NULL PRIMARY KEY,
            label VARCHAR(128) NOT NULL,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            radius DOUBLE NOT NULL,
            zombie_count INT NOT NULL DEFAULT 20,
            spread_min DOUBLE NOT NULL DEFAULT 5,
            spread_max DOUBLE NOT NULL,
            height_diff DOUBLE NOT NULL DEFAULT 6,
            models_key VARCHAR(32) NOT NULL DEFAULT 'default',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS hh_zombie_zone_disabled (
            id VARCHAR(64) NOT NULL PRIMARY KEY
        )
    ]])

    pcall(function()
        MySQL.query.await("ALTER TABLE hh_zombie_zones ADD COLUMN models_json TEXT NULL")
    end)

    disabledBuiltin = {}
    local disabled = MySQL.query.await("SELECT id FROM hh_zombie_zone_disabled") or {}
    for i = 1, #disabled do
        disabledBuiltin[disabled[i].id] = true
    end

    rebuildRuntimeZones()

    local rows = MySQL.query.await("SELECT * FROM hh_zombie_zones") or {}
    for i = 1, #rows do
        local row = rows[i]
        local models, modelsKey = modelsFromRow(row)
        runtimeZones[#runtimeZones + 1] = {
            id = row.id,
            label = row.label,
            enabled = true,
            coords = vector3(row.x + 0.0, row.y + 0.0, row.z + 0.0),
            radius = row.radius + 0.0,
            count = row.zombie_count,
            spawnAcrossZone = true,
            spread = { min = row.spread_min + 0.0, max = row.spread_max + 0.0 },
            maxSpawnHeightDiff = row.height_diff + 0.0,
            models = models,
            modelsKey = modelsKey,
            builtin = false,
            custom = true,
        }
    end
end

local function findRuntimeZone(zoneId)
    for i = 1, #runtimeZones do
        if runtimeZones[i].id == zoneId then
            return runtimeZones[i], i
        end
    end
    return nil
end

CreateThread(function()
    loadDatabaseZones()
    broadcastZones()
end)

AddEventHandler("playerJoining", function()
    local src = source
    SetTimeout(1500, function()
        if GetPlayerName(src) then
            broadcastZones(src)
            pushAdmin(src)
        end
    end)
end)

AddEventHandler("vorp:SelectedCharacter", function(src)
    SetTimeout(500, function()
        pushAdmin(src)
    end)
end)

RegisterNetEvent("hh_zombies:requestZones", function()
    local src = source
    broadcastZones(src)
    pushAdmin(src)
end)

RegisterNetEvent("hh_zombies:requestAdmin", function()
    pushAdmin(source)
end)

RegisterNetEvent("hh_zombies:saveZone", function(data)
    local src = source
    if not isZoneAdmin(src) then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Нет прав на создание зон.")
        return
    end

    if type(data) ~= "table" then
        return
    end

    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    local radius = tonumber(data.radius)
    if not x or not y or not z or not radius or radius < 10.0 then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Некорректная область.")
        return
    end

    local label = tostring(data.label or "Пользовательская зона"):sub(1, 80)
    local models = sanitizeModels(data.models)
    if #models == 0 then
        models = modelsFromKey(data.modelsKey)
    end
    if #models == 0 then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Выбери хотя бы одну модель.")
        return
    end

    local modelsKey = data.modelsKey == "colter" and "colter" or (#models > 0 and "custom" or "default")
    local id = ("custom_%d_%d"):format(os.time(), math.random(100, 999))
    local spreadMax = math.max(10.0, radius - 5.0)
    local count = math.floor(tonumber(data.count) or 0)
    if count < 1 then
        count = math.max(8, math.floor(radius / 3.0))
    end
    count = math.min(200, math.max(1, count))
    local modelsJson = json.encode(models)

    MySQL.insert.await([[
        INSERT INTO hh_zombie_zones
            (id, label, x, y, z, radius, zombie_count, spread_min, spread_max, height_diff, models_key, models_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        id, label, x, y, z, radius, count, 5.0, spreadMax, 6.0, modelsKey, modelsJson,
    })

    runtimeZones[#runtimeZones + 1] = {
        id = id,
        label = label,
        enabled = true,
        coords = vector3(x, y, z),
        radius = radius,
        count = count,
        spawnAcrossZone = true,
        spread = { min = 5.0, max = spreadMax },
        maxSpawnHeightDiff = 6.0,
        models = models,
        modelsKey = modelsKey,
        builtin = false,
        custom = true,
    }

    broadcastZones()
    TriggerClientEvent("hh_zombies:zoneEditorResult", src, true, ("Зона сохранена: %s (%s, %.0f м, %d зомби)"):format(label, id, radius, count), id)
end)

RegisterNetEvent("hh_zombies:deleteZone", function(zoneId)
    local src = source
    if not isZoneAdmin(src) then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Нет прав на удаление зон.")
        return
    end

    if type(zoneId) ~= "string" or zoneId == "" then
        return
    end

    local zone = findRuntimeZone(zoneId)
    if not zone then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Зона не найдена.")
        return
    end

    if zone.custom then
        MySQL.query.await("DELETE FROM hh_zombie_zones WHERE id = ?", { zoneId })
    else
        MySQL.insert.await("INSERT IGNORE INTO hh_zombie_zone_disabled (id) VALUES (?)", { zoneId })
        disabledBuiltin[zoneId] = true
    end

    loadDatabaseZones()
    TriggerClientEvent("hh_zombies:zoneRemoved", -1, zoneId)
    broadcastZones()
    TriggerClientEvent("hh_zombies:zoneEditorResult", src, true, ("Зона удалена: %s"):format(zoneId))
end)

RegisterNetEvent("hh_zombies:listZones", function()
    local src = source
    if not isZoneAdmin(src) then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Нет прав.")
        return
    end

    local lines = {}
    for i = 1, #runtimeZones do
        local zone = runtimeZones[i]
        lines[#lines + 1] = ("%s | %s | %.0f м | %s"):format(
            zone.id,
            zone.label,
            zone.radius,
            zone.custom and "БД" or "конфиг"
        )
    end

    TriggerClientEvent("hh_zombies:zoneList", src, lines)
end)

RegisterNetEvent("hh_zombies:requestZoneManager", function()
    local src = source
    if not isZoneAdmin(src) then
        TriggerClientEvent("hh_zombies:zoneEditorResult", src, false, "Нет прав.")
        return
    end
    pushZoneManager(src)
end)

--------------------------------------------------------------------------------
-- Occupancy / linger
--------------------------------------------------------------------------------

local function getZone(zoneId)
    if not zoneData[zoneId] then
        zoneData[zoneId] = {
            players = {},
            count = 0,
            owner = nil,
            populated = false,
            lingerUntil = 0,
        }
    end
    return zoneData[zoneId]
end

local function playerOnline(src)
    return src and GetPlayerName(src) ~= nil
end

local function freezeActive(zone)
    return (zone.lingerUntil or 0) > os.time()
end

local function authPayload(src, zoneId)
    local zone = getZone(zoneId)
    local freeze = freezeActive(zone)
    local ownerOk = playerOnline(zone.owner)

    if not ownerOk then
        zone.owner = nil
    end

    local canSpawn = false
    if not zone.populated or not zone.owner then
        canSpawn = true
        zone.owner = src
        zone.populated = true
    elseif zone.owner == src then
        canSpawn = true
    end

    return {
        canSpawn = canSpawn,
        freezeRestock = freeze,
        occupants = zone.count,
        lingerLeft = math.max(0, (zone.lingerUntil or 0) - os.time()),
        owner = zone.owner == src,
    }
end

local function pushAuth(src, zoneId)
    TriggerClientEvent("hh_zombies:zoneAuth", src, zoneId, authPayload(src, zoneId))
end

local function pushAuthAll(zoneId)
    local zone = getZone(zoneId)
    for src in pairs(zone.players) do
        if playerOnline(src) then
            pushAuth(src, zoneId)
        end
    end
    if zone.owner and not zone.players[zone.owner] and playerOnline(zone.owner) then
        pushAuth(zone.owner, zoneId)
    end
end

local function removePlayer(src, zoneId)
    local zone = zoneData[zoneId]
    if not zone or not zone.players[src] then
        return
    end

    zone.players[src] = nil
    zone.count = math.max(0, zone.count - 1)

    if zone.count == 0 then
        zone.lingerUntil = os.time() + lingerSeconds()
    end

    if playerOnline(src) then
        pushAuth(src, zoneId)
    end
    pushAuthAll(zoneId)
end

RegisterNetEvent("hh_zombies:enterZone", function(zoneId)
    local src = source
    if type(zoneId) ~= "string" then
        return
    end

    local zone = getZone(zoneId)
    if zone.players[src] then
        pushAuth(src, zoneId)
        return
    end

    zone.players[src] = true
    zone.count = zone.count + 1
    pushAuth(src, zoneId)
    pushAuthAll(zoneId)
end)

RegisterNetEvent("hh_zombies:leaveZone", function(zoneId)
    if type(zoneId) ~= "string" then
        return
    end
    removePlayer(source, zoneId)
end)

AddEventHandler("playerDropped", function()
    local src = source
    for zoneId in pairs(zoneData) do
        removePlayer(src, zoneId)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        for zoneId, zone in pairs(zoneData) do
            if (zone.lingerUntil or 0) > 0 and now >= zone.lingerUntil then
                zone.lingerUntil = 0

                if zone.count > 0 then
                    if not playerOnline(zone.owner) then
                        zone.owner = nil
                        for occupant in pairs(zone.players) do
                            zone.owner = occupant
                            break
                        end
                    end
                    pushAuthAll(zoneId)
                else
                    local owner = zone.owner
                    zone.populated = false
                    zone.owner = nil
                    if owner and playerOnline(owner) then
                        TriggerClientEvent("hh_zombies:despawnZone", owner, zoneId)
                    end
                end
            end
        end
    end
end)
