-- =================================================================
-- HUNT: Hard RP — Server Lifecycle & Event Dispatcher
-- =================================================================

local selectionSaveRequested = {}

-- 1. Net Events for Character System
RegisterNetEvent(Constants.Events.REQUEST_CHARACTERS, function()
    local src = source
    Characters.RequestUserCharacters(src)
end)

RegisterNetEvent(Constants.Events.SELECT_CHARACTER, function(charIdentifier)
    local src = source
    Characters.SelectCharacter(src, tonumber(charIdentifier))
end)

RegisterNetEvent(Constants.Events.CREATE_CHARACTER, function(payload)
    local src = source
    Characters.CreateCharacter(src, payload)
end)

RegisterNetEvent(Constants.Events.DELETE_CHARACTER, function(data)
    local src = source
    if type(data) == "table" then
        Characters.DeleteCharacter(src, tonumber(data.charIdentifier), data.confirmName)
    end
end)

RegisterNetEvent(Constants.Events.SAVE_LAST_POSITION, function(coords)
    local src = source
    Characters.SaveLastPosition(src, coords)
end)

RegisterNetEvent(Constants.Events.SAVE_WORLD_STATE, function(coords, state)
    Characters.SaveWorldState(source, coords, state)
end)

RegisterNetEvent(Constants.Events.OPEN_SELECTION_AFTER_SAVE, function()
    local src = source
    if not selectionSaveRequested[src] then return end
    selectionSaveRequested[src] = nil
    Characters.RequestUserCharacters(src)
end)

RegisterNetEvent(Constants.Events.UPDATE_APPEARANCE, function(payload, comps, compTints)
    local src = source
    if GetResourceState('thehunt_pedcustom') == 'started' and exports.thehunt_pedcustom:IsTemporaryAppearanceActive(src) then return end
    -- Backward-compatible positional signature: (skin, comps, compTints).
    if comps ~= nil then
        payload = { skin = payload, comps = comps, compTints = compTints }
    end
    Characters.UpdateAppearance(src, payload)
end)

-- Handler for "Create New Character" button in Selection menu
-- Isolates player in their own routing bucket before opening Creator
RegisterNetEvent("thehunt_character:server:requestNewCharacter", function()
    local src = source
    -- Put player in private routing bucket
    Player(src).state:set('PlayerIsInCharacterShops', true, true)
    pcall(function()
        SetPlayerRoutingBucket(src, 1000 + src)
    end)
    TriggerClientEvent(Constants.Events.OPEN_CREATOR, src, { isFirstCharacter = false })
end)

-- Acknowledge only after the client has actually left the studio. VORP uses
-- this state flag to avoid overwriting the last world position with editor
-- coordinates during its own periodic save.
RegisterNetEvent("thehunt_character:server:spawnComplete", function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
    Player(src).state:set('PlayerIsInCharacterShops', false, true)
end)

-- 2. Framework compatibility arrives only from thehunt_core.
AddEventHandler("thehunt:framework:createCharacter", function(source)
    Player(source).state:set('PlayerIsInCharacterShops', true, true)
    SetPlayerRoutingBucket(source, 1000 + source)
    TriggerClientEvent(Constants.Events.OPEN_CREATOR, source, { isFirstCharacter = true })
end)

AddEventHandler("thehunt:framework:openCharacterSelection", function(source)
    Characters.RequestUserCharacters(source)
end)

AddEventHandler("thehunt:framework:saveCharacter", function(src, data)
    if type(data) == "table" then
        data.__legacyVorp = true
        data.description = data.description or data.charDescription or data.desc
        -- Older VORP creators only supplied an age. Preserve their public
        -- event contract with a deterministic migration date; the custom NUI
        -- continues to require and validate an exact DD/MM/YYYY value.
        if not data.birthdate and tonumber(data.age) then
            data.birthdate = string.format("01/01/%04d", (tonumber(Config.WorldYear) or 1907) - tonumber(data.age))
        end
    end
    Characters.CreateCharacter(src, data)
end)

AddEventHandler("thehunt:framework:deleteCharacter", function(src, selectedChar)
    if selectedChar and selectedChar.charIdentifier then
        Characters.DeleteCharacter(src, selectedChar.charIdentifier, selectedChar.firstname .. " " .. selectedChar.lastname)
    end
end)

AddEventHandler("thehunt:framework:selectCharacter", function(src, charid)
    Characters.SelectCharacter(src, tonumber(charid))
end)

AddEventHandler("thehunt:framework:appearanceChanged", function(src, skinValues, compsValues, compTints)
    Characters.UpdateAppearance(src, {
        skin = skinValues,
        comps = compsValues,
        compTints = compTints
    })
end)

-- 3. Auto-save on player disconnect / dropped
AddEventHandler('playerDropped', function(reason)
    local src = source
    if GetPlayerRoutingBucket(src) ~= 0 then return end
    local ped = GetPlayerPed(src)
    if DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        Characters.SaveLastPosition(src, { x = coords.x, y = coords.y, z = coords.z, heading = heading })
    end
end)

-- 4. Admin Command: Return to Character Selection Menu
RegisterCommand("characterselect", function(source, args)
    local src = source
    if src == 0 then
        print("[thehunt_character] Command only usable by in-game players.")
        return
    end

    if not Admin.IsAdmin(src) then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "У вас нет прав администратора.")
        return
    end

    -- The client owns core and HUNT sprint values. Ask it for an immediate
    -- snapshot first; opening the selector before that used to lose them.
    selectionSaveRequested[src] = true
    TriggerClientEvent(Constants.Events.PREPARE_SELECTION, src)
    -- Do not leave the admin in a locked world if a client resource is
    -- restarted exactly while the request is being sent.
    SetTimeout(2000, function()
        if selectionSaveRequested[src] then
            selectionSaveRequested[src] = nil
            Characters.RequestUserCharacters(src)
        end
    end)
end, false)

AddEventHandler('playerDropped', function()
    selectionSaveRequested[source] = nil
end)

-- 5. Initial Server Boot & Database Initialization
MySQL.ready(function()
    -- A manifest/cache reload may occasionally skip a sibling script while
    -- still executing main.lua. Recover deterministically and surface a
    -- useful error instead of crashing on a nil global.
    if type(Database) ~= "table" or type(Database.Init) ~= "function" then
        local resourceName = GetCurrentResourceName()
        local source = LoadResourceFile(resourceName, "server/database.lua")
        if not source then
            print("^1[thehunt_character] ERROR: server/database.lua could not be loaded.^7")
            return
        end

        local chunk, loadError = load(source, "@@" .. resourceName .. "/server/database.lua", "t", _ENV)
        if not chunk then
            print("^1[thehunt_character] ERROR: server/database.lua syntax error: " .. tostring(loadError) .. "^7")
            return
        end

        local ok, runtimeError = pcall(chunk)
        if not ok then
            print("^1[thehunt_character] ERROR: server/database.lua failed to initialize: " .. tostring(runtimeError) .. "^7")
            return
        end
    end

    if type(Database) ~= "table" or type(Database.Init) ~= "function" then
        print("^1[thehunt_character] ERROR: Database module is unavailable after recovery.^7")
        return
    end

    Database.Init()
    print("^2[thehunt_character] System initialized successfully. Ready for Hard RP character creation & selection.^7")
end)
