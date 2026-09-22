local _usersLoading = {}
_users = {}
_healthData = {}

local T = Translation[Lang].MessageOfSystem



function GetMaxCharactersAllowed(source)
    local identifier = GetPlayerIdentifierByType(source, 'steam')
    local user = _users[identifier]
    if not user then
        return
    end
    return user._charperm
end

local function savePlayer(_source, reason, identifier)
    local discordId = GetDiscordID(_source)
    local steamName = GetPlayerName(_source)

    if _users[identifier] and _users[identifier].GetUsedCharacter() then
        if Config.SavePlayersStatus then
            -- A player can disconnect before the first client heartbeat. Keep
            -- the character's current values rather than dereferencing nil.
            local cached = _healthData[identifier] or {}
            local character = _users[identifier].GetUsedCharacter()
            character.HealthOuter(cached.hOuter ~= nil and cached.hOuter or character.HealthOuter())
            character.HealthInner(cached.hInner ~= nil and cached.hInner or character.HealthInner())
            character.StaminaOuter(cached.sOuter ~= nil and cached.sOuter or character.StaminaOuter())
            character.StaminaInner(cached.sInner ~= nil and cached.sInner or character.StaminaInner())
        end
        _users[identifier].SaveUser()
        Player(_source).state:set('Character', nil, true)
        Player(_source).state:set('IsInSession', nil, true)
    end

    if Logs.EnableWebhookJoinleave then
        local finaltext = string.format(T.PlayerJoinLeave.Leave, steamName, identifier, reason and (T.PlayerJoinLeave.Reason .. reason) or "")
        TriggerEvent("vorp_core:addWebhook", T.PlayerJoinLeave.Leavetitle, Logs.LeaveWebhookURL, finaltext)
    end

    if Config.SaveDiscordId then --TODO this can de added as default
        MySQL.update('UPDATE characters SET `discordid` = ? WHERE `identifier` = ? ', { discordId, identifier })
    end
end

local function removePlayer(identifier, license)
    if not identifier or not license then
        return
    end

    if _usersLoading[license] then
        _usersLoading[license] = nil
    end

    local userid = Whitelist.Functions.GetUserId(identifier)
    if userid and WhiteListedUsers[userid] then
        WhiteListedUsers[userid] = nil
    end

    SetTimeout(6000, function()
        if _users[identifier] then
            _users[identifier] = nil
        end
    end)
end

local function ReportCrash(reason, _source)
    local _, _, errorMessage = reason:find("RAGE error:%s(.+)")
    if not errorMessage then
        _, _, errorMessage = reason:find("Game crashed:%s(.+)")
    end

    if errorMessage then
        local ped = GetPlayerPed(_source)
        local pcoords = GetEntityCoords(ped)
        local coords = {
            x = pcoords.x,
            y = pcoords.y,
            z = pcoords.z
        }
        local crash_id = string.lower(errorMessage:gsub("%b()", ""))
        PerformHttpRequest("http://api.polycode.pl:8080/api/crashes", function(code, data, _)
            if code ~= 200 then
                print("[Crash Reporter] Failed to send crash report: HTTP " .. tostring(code))
                if data then
                    local decoded = json.decode(data)
                    if decoded and decoded.error then
                        print("[Crash Reporter] Server error: " .. decoded.error)
                    else
                        print("[Crash Reporter] Response: " .. tostring(data))
                    end
                end
            end
        end, "POST", json.encode({
            apiKey = Config.API_KEY,
            crash_id = crash_id,
            server = GetConvar("sv_projectName", "Unknown"),
            coords = json.encode(coords)
        }), {
            ["Content-Type"] = "application/json"
        })
    end
end

if Config.ReportCrash and Config.API_KEY ~= "" then
    CreateThread(function()
        SetTimeout(5000, function()
            local resourceList = {}
            for i = 0, GetNumResources(), 1 do
                local resource_name = GetResourceByFindIndex(i)
                if resource_name and GetResourceState(resource_name) == "started" then
                    table.insert(resourceList, resource_name)
                end
            end
            PerformHttpRequest("http://api.polycode.pl:8080/api/resources", function(_, _, _)
            end, "POST", json.encode({
                apiKey = Config.API_KEY,
                server = GetConvar("sv_projectName", "Unknown"),
                resourceList = json.encode(resourceList)
            }), {
                ["Content-Type"] = "application/json"
            })
        end)
    end)
end

AddEventHandler('playerDropped', function(reason)
    local _source = source
    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local license = GetPlayerIdentifierByType(_source, 'license')
    savePlayer(_source, reason, identifier)
    removePlayer(identifier, license)
    if Config.ReportCrashes and Config.API_KEY ~= "" then
        ReportCrash(reason, _source)
    end
    GlobalState.PlayersInSession = GlobalState.PlayersInSession - 1
end)

-- todo: allow to save player when they are still in the server  example of usage is  not have to relog to select another character
--[[ AddEventHandler("vorp_core:playerRemove", function(source)
    local _source = source
    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    savePlayer(_source, nil, identifier)
end)

AddEventHandler("vorp:Server:playerLeave", function(source)     -- trigger this event when you have logic to remove player
    local _source = source
    TriggerEvent("vorp_core:playerRemove", _source)             -- save player
    TriggerClientEvent("vorp_core:Client:playerLeave", _source) -- let client know character left
end) ]]

-- On current FXServer builds playerJoining is delivered through the network
-- event path.  Register it before subscribing, otherwise this VORP loader can
-- be skipped even though Steam and license identifiers are already available.
RegisterNetEvent("playerJoining")
AddEventHandler("playerJoining", function()
    local _source = source
    local identifier <const> = GetPlayerIdentifierByType(_source, 'steam')
    local license <const> = GetPlayerIdentifierByType(_source, 'license')
    Player(_source).state:set('IsInSession', false, true)

    if not identifier or not license then
        return print("user cant load no identifier steam or license found")
    end

    if _usersLoading[license] then
        return DropPlayer(_source, "player with this license is already in game")
    end
    _usersLoading[license] = _source

    local user <const> = MySQL.single.await('SELECT `group`, `warnings`, `char`, `max_jobs` FROM users WHERE identifier = ?', { identifier })
    if user then
        _users[identifier] = User(_source, identifier, user.group, user.warnings, license, user.char, user.max_jobs)
        _users[identifier].LoadCharacters()
    else
        local count <const> = MySQL.scalar.await('SELECT COUNT(*) FROM users') or 0
        local defaultGroup <const> = count == 0 and "admin" or Config.initGroup

        MySQL.insert("INSERT INTO users VALUES(?,?,?,?,?,?,?)", { identifier, defaultGroup, 0, 0, 0, Config.MaxCharacters, Config.MaxCharacterJobs })
        _users[identifier] = User(_source, identifier, defaultGroup, 0, license, Config.MaxCharacters, Config.MaxCharacterJobs)
    end
end)

-- Some RedM/FXServer connection paths do not emit playerJoining to this
-- resource.  VORP must still create its authoritative User before the client
-- asks to open the character selector.  This is intentionally kept inside
-- vorp_core so HUNT never fabricates a VORP session.
local function EnsureUserForSpawn(_source, identifier, license)
    local existing = _users[identifier]
    if existing then
        existing.Source(_source)
        return existing
    end

    -- Do not race a normal playerJoining load for the same license.
    if _usersLoading[license] then
        local deadline = GetGameTimer() + 5000
        repeat
            Wait(50)
            existing = _users[identifier]
        until existing or GetGameTimer() >= deadline

        if existing then
            existing.Source(_source)
        end
        return existing
    end

    _usersLoading[license] = _source
    local row = MySQL.single.await('SELECT `group`, `warnings`, `char`, `max_jobs` FROM users WHERE identifier = ?', { identifier })
    if row then
        existing = User(_source, identifier, row.group, row.warnings, license, row.char, row.max_jobs)
    else
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM users') or 0
        local defaultGroup = count == 0 and "admin" or Config.initGroup
        MySQL.insert.await("INSERT INTO users VALUES(?,?,?,?,?,?,?)", { identifier, defaultGroup, 0, 0, 0, Config.MaxCharacters, Config.MaxCharacterJobs })
        existing = User(_source, identifier, defaultGroup, 0, license, Config.MaxCharacters, Config.MaxCharacterJobs)
    end

    _users[identifier] = existing
    existing.LoadCharacters()
    print(string.format('^2[vorp_core] Recovered missing user session for src %s.^7', tostring(_source)))
    return existing
end

-- Explicit server export for compatibility layers. It loads only the VORP
-- User/cache; character selection remains owned by the caller's flow.
exports('EnsureUserForSource', function(playerSource)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return false end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local license = GetPlayerIdentifierByType(_source, 'license')
    if not identifier or not license then return false end

    return EnsureUserForSpawn(_source, identifier, license) ~= nil
end)

-- The legacy CoreFunctions.getUser lookup can miss a freshly recovered user
-- on this server build.  Resolve the same VORP-owned cache directly by source
-- and return the standard public User snapshot to compatibility layers.
exports('GetUserSnapshotForSource', function(playerSource)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return nil end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if not user then return nil end

    user.Source(_source)
    return user.GetUser()
end)

-- Lightweight source-based reads for compatibility facades.  Do not build a
-- complete GetUser() snapshot here: that also serializes every character and
-- their large inventory/status fields even when a caller only needs the
-- active character or the session state.
exports('IsUserReadyForSource', function(playerSource)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return false end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    if not identifier then return nil end
    return _users[identifier] ~= nil
end)

exports('GetCharacterForSource', function(playerSource)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return nil end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if not user then return nil end

    user.Source(_source)
    local active = type(user.GetUsedCharacter) == 'function' and user.GetUsedCharacter()
    if not active or type(active.getCharacter) ~= 'function' then return nil end
    return active.getCharacter()
end)

-- Identity-only read for compatibility facades.  Calling getCharacter()
-- serializes the active character's inventory/status blobs; lifecycle checks
-- only need the id and must not pay that cost on every selection callback.
exports('GetCharacterIdForSource', function(playerSource)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return nil end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if not user then return nil end

    user.Source(_source)
    if type(user.UsedCharacterId) ~= 'function' then return nil end
    local charId = tonumber(user.UsedCharacterId())
    return charId and charId > 0 and charId or nil
end)

exports('GetUserGroupForSource', function(playerSource)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return nil end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if not user then return nil end

    user.Source(_source)
    return type(user.Group) == 'function' and user.Group() or nil
end)

-- Explicit source-based character activation for compatibility facades. Do
-- not pass the mutable VORP User object through an export: a resource boundary
-- can turn its methods into an unreliable snapshot. The operation stays
-- inside VORP and returns a small, inspectable result instead.
exports('SelectCharacterForSource', function(playerSource, characterId, returnSnapshot)
    local _source = tonumber(playerSource)
    local charId = tonumber(characterId)
    if not _source or _source <= 0 or not charId then
        return false, 'invalid_character'
    end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if not user then
        return false, 'user_missing'
    end
    user.Source(_source)

    local cachedCharacter = type(user.GetUsedCharacter) == 'function' and user.GetUsedCharacter()
    local currentId = cachedCharacter and tonumber(cachedCharacter.CharIdentifier()) or nil
    if currentId == charId then
        return true, returnSnapshot == false and nil or cachedCharacter.getCharacter()
    end

    local ok, result = pcall(user.SetUsedCharacter, charId)
    if not ok then
        return false, 'activation_error:' .. tostring(result)
    end
    if result == false then
        return false, 'character_not_loaded'
    end

    local active = type(user.GetUsedCharacter) == 'function' and user.GetUsedCharacter()
    local activeId = active and tonumber(active.CharIdentifier()) or nil
    if not active or activeId ~= charId then
        return false, 'activation_failed'
    end

    return true, returnSnapshot == false and nil or active.getCharacter()
end)

-- Explicit source-based character creation for the HUNT facade. The public
-- GetUser() snapshot contains a compatibility closure, but that closure is
-- not a safe mutation boundary between resources on every FXServer build.
exports('CreateCharacterForSource', function(playerSource, characterData)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 or type(characterData) ~= 'table' then
        return false, 'invalid_character_data'
    end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if not user then
        return false, 'user_missing'
    end
    user.Source(_source)
    if type(user.addCharacter) ~= 'function' then
        return false, 'create_unavailable'
    end

    -- Match VORP's public addCharacter contract: reserve the slot in the
    -- in-memory user immediately, then let the Character object complete its
    -- asynchronous INSERT and activate the new character from its callback.
    local previousCount = tonumber(user.Numofcharacters()) or 0
    user.Numofcharacters(previousCount + 1)
    local ok, result = pcall(user.addCharacter, characterData)
    if not ok then
        user.Numofcharacters(previousCount)
        return false, 'creation_error:' .. tostring(result)
    end

    return true, result
end)

-- Character mutations below are also source-addressed so HUNT never depends
-- on setter closures embedded in a cross-resource snapshot.
exports('SyncCharacterCoordsForSource', function(playerSource, coordsJson)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 or type(coordsJson) ~= 'string' then
        return false, 'invalid_coords'
    end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if user then user.Source(_source) end
    local character = user and type(user.GetUsedCharacter) == 'function' and user.GetUsedCharacter()
    if not character or type(character.Coords) ~= 'function' then
        return false, 'character_missing'
    end

    local ok, result = pcall(character.Coords, coordsJson)
    if not ok then return false, 'coords_error:' .. tostring(result) end
    return true
end)

exports('SetCharacterVitalsForSource', function(playerSource, state)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 or type(state) ~= 'table' then
        return false, 'invalid_vitals'
    end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if user then user.Source(_source) end
    local character = user and type(user.GetUsedCharacter) == 'function' and user.GetUsedCharacter()
    if not character then return false, 'character_missing' end

    local operations = {
        { 'HealthOuter', state.healthOuter },
        { 'HealthInner', state.healthInner },
        { 'StaminaOuter', state.staminaOuter },
        { 'StaminaInner', state.staminaInner }
    }
    for _, operation in ipairs(operations) do
        if operation[2] ~= nil then
            if type(character[operation[1]]) ~= 'function' then
                return false, 'vitals_unavailable'
            end
            local ok, result = pcall(character[operation[1]], operation[2])
            if not ok then return false, 'vitals_error:' .. tostring(result) end
        end
    end
    return true
end)

exports('UpdateCharacterAppearanceForSource', function(playerSource, skinJson, compsJson, tintsJson)
    local _source = tonumber(playerSource)
    if not _source or _source <= 0 then return false, 'invalid_source' end

    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = identifier and _users[identifier] or nil
    if user then user.Source(_source) end
    local character = user and type(user.GetUsedCharacter) == 'function' and user.GetUsedCharacter()
    if not character then return false, 'character_missing' end

    local operations = {
        { 'Skin', skinJson },
        { 'Comps', compsJson },
        { 'CompTints', tintsJson }
    }
    for _, operation in ipairs(operations) do
        if operation[2] ~= nil then
            if type(character[operation[1]]) ~= 'function' then
                return false, 'appearance_unavailable'
            end
            local ok, result = pcall(character[operation[1]], operation[2])
            if not ok then return false, 'appearance_error:' .. tostring(result) end
        end
    end
    return true
end)


-- incremental room so its never the same
local roomId = 0
local openingSessions = {}

local function StartPlayerSession(_source)
    _source = tonumber(_source)
    if not _source or _source <= 0 then return end
    if openingSessions[_source] then return end
    openingSessions[_source] = true
    Player(_source).state:set('IsInSession', false, true)
    SetTimeout(10000, function()
        openingSessions[_source] = nil
    end)

    local identifier <const> = GetPlayerIdentifierByType(_source, 'steam')
    local license <const> = GetPlayerIdentifierByType(_source, 'license')
    if not identifier then
        return print("user cant load no identifier steam found", identifier)
    end
    if not license then
        return print("user cant load no identifier license found")
    end

    local user <const> = _users[identifier] or EnsureUserForSpawn(_source, identifier, license)
    if not user then
        return print("user not found with identifier", identifier)
    end

    roomId = roomId + 1
    SetPlayerRoutingBucket(_source, roomId)

    user.Source(_source)
    local numCharacters <const> = user.Numofcharacters()
    if numCharacters <= 0 then
        return TriggerEvent("vorp_CreateNewCharacter", _source)
    end

    local eventName <const> = tonumber(user._charperm) > 1 and "GoToSelectionMenu" or "SpawnUniqueCharacter"
    TriggerEvent(("vorp_character:server:%s"):format(eventName), _source)
    -- set the default density multipliers for the player
    TriggerClientEvent("vorp_lib:Client:SetDefaultDensityMultiplier", _source, Config.Multipliers)
end

-- Native client bootstrap path retained for normal VORP clients.
RegisterNetEvent('vorp:playerSpawn', function()
    StartPlayerSession(source)
end)

-- Server-side compatibility path used by the HUNT facade. It is intentionally
-- a local event, so external clients cannot manufacture a session for another
-- player.
AddEventHandler('vorp_core:server:ensurePlayerSession', function(playerSource)
    StartPlayerSession(playerSource)
end)

AddEventHandler('playerDropped', function()
    openingSessions[source] = nil
end)


RegisterNetEvent('vorp:SaveHealth', function(healthOuter, healthInner)
    local _source = source
    local identifier = GetPlayerIdentifierByType(_source, 'steam')

    if healthInner and healthOuter then
        local user = _users[identifier] or nil

        if user then
            local used_char = user.GetUsedCharacter() or nil

            if used_char then
                used_char.HealthOuter(healthOuter - healthInner)
                used_char.HealthInner(healthInner)
            end
        end
    end
end)

RegisterNetEvent('vorp:SaveStamina', function(staminaOuter, staminaInner)
    local _source = source
    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    if staminaOuter and staminaInner then
        local user = _users[identifier] or nil
        if user then
            local used_char = user.GetUsedCharacter() or nil
            if used_char then
                used_char.StaminaOuter(staminaOuter)
                used_char.StaminaInner(staminaInner)
            end
        end
    end
end)

RegisterNetEvent('vorp:HealthCached', function(healthOuter, healthInner, staminaOuter, staminaInner)
    local _source = source
    local identifier = GetPlayerIdentifierByType(_source, 'steam')

    if not identifier then
        return
    end

    if not _healthData[identifier] then
        _healthData[identifier] = {}
    end

    _healthData[identifier].hOuter = healthOuter
    _healthData[identifier].hInner = healthInner
    _healthData[identifier].sOuter = staminaOuter
    _healthData[identifier].sInner = staminaInner
end)

RegisterNetEvent("vorp:GetValues", function()
    local _source = source
    local healthData = { hOuter = 10, hInner = 10, sOuter = 10, sInner = 10 }
    local identifier = GetPlayerIdentifierByType(_source, 'steam')
    local user = _users[identifier]

    -- Only if the player exists in online table...
    if user and user.GetUsedCharacter then
        local used_char = user.GetUsedCharacter()

        -- Only there is an character...
        if used_char then
            healthData.hOuter = used_char.HealthOuter() or 10
            healthData.hInner = used_char.HealthInner() or 10
            healthData.sOuter = used_char.StaminaOuter() or 10
            healthData.sInner = used_char.StaminaInner() or 10
        end
    end

    TriggerClientEvent("vorp:GetHealthFromCore", _source, healthData)
end)

-- clean up users table if character is deleted
if Config.DeleteFromUsersTable and not Config.Whitelist then
    MySQL.ready(function()
        local query = "DELETE FROM users WHERE NOT EXISTS (SELECT 1 FROM characters WHERE characters.identifier = users.identifier);"
        MySQL.query(query, {})
    end)
end
