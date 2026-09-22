local unconsciousPlayers = {}
local databaseReady = false

-- A resource restart can recreate thehunt_death after oxmysql has already
-- started without re-injecting @oxmysql/lib/MySQL.lua into this environment.
-- Keep the normal MySQL API when it is available, but use oxmysql's callback
-- exports as a local fallback so knock persistence and wake requests cannot
-- silently die with "global 'MySQL'".
local function makeOxmysqlFallback()
    local function await(method, query, parameters)
        local resultPromise = promise.new()
        local ok, invokeError = pcall(function()
            local callback = function(result, queryError)
                if queryError then
                    resultPromise:reject(queryError)
                else
                    resultPromise:resolve(result)
                end
            end

            if method == 'query' then
                exports.oxmysql:query(query, parameters or {}, callback)
            elseif method == 'scalar' then
                exports.oxmysql:scalar(query, parameters or {}, callback)
            elseif method == 'update' then
                exports.oxmysql:update(query, parameters or {}, callback)
            end
        end)
        if not ok then
            return nil, invokeError
        end

        local awaitOk, result = pcall(Citizen.Await, resultPromise)
        if not awaitOk then
            return nil, result
        end
        return result
    end

    local function awaitOrError(method, query, parameters)
        local result, err = await(method, query, parameters)
        if err then error(err, 0) end
        return result
    end

    return {
        query = { await = function(query, parameters) return awaitOrError('query', query, parameters) end },
        scalar = { await = function(query, parameters) return awaitOrError('scalar', query, parameters) end },
        update = { await = function(query, parameters) return awaitOrError('update', query, parameters) end },
    }
end

local DB = MySQL
if type(DB) ~= 'table' or type(DB.query) ~= 'table' then
    DB = makeOxmysqlFallback()
end

local function getCharacterId(source)
    if GetResourceState('thehunt_core') == 'started' then
        local ok, charId = pcall(function()
            return exports.thehunt_core:GetCharacterId(source)
        end)
        if ok and tonumber(charId) then
            return tonumber(charId)
        end
    end

    -- The source-based VORP export is the authoritative fallback during the
    -- short character-selection bridge window.
    if GetResourceState('vorp_core') == 'started' then
        local ok, charId = pcall(function()
            return exports.vorp_core:GetCharacterIdForSource(source)
        end)
        if ok and tonumber(charId) then
            return tonumber(charId)
        end
    end

    return nil
end

local function setUnconsciousState(source, value)
    local player = Player(source)
    if player then
        player.state:set('thehuntUnconscious', value, true)
        player.state:set('thehuntKnockReady', false, true)
    end
end

local function clearUnconscious(source, deletePersisted)
    local state = unconsciousPlayers[source]
    unconsciousPlayers[source] = nil
    setUnconsciousState(source, false)
    if deletePersisted and state and state.charId and databaseReady then
        local ok, err = pcall(function()
            DB.update.await('DELETE FROM `thehunt_death_unconscious` WHERE `charidentifier` = ?', { state.charId })
        end)
        if not ok then
            print(('[thehunt_death] Failed to clear persisted knock for %s: %s'):format(source, tostring(err)))
        end
    end
end

local function getVorpCore()
    local ok, core = pcall(function()
        return exports.vorp_core:GetCore()
    end)
    if ok and type(core) == 'table' then
        return core
    end
    return nil
end

local function revivePlayer(targetSource)
    local target = tonumber(targetSource)
    if not target or not GetPlayerName(target) then
        return false
    end

    -- Clear HUNT state first. VORP's own server revive event also calls this
    -- handler, so this remains idempotent for every revive entry point.
    clearUnconscious(target, true)

    local core = getVorpCore()
    if core and core.Player and type(core.Player.Revive) == 'function' then
        local ok, err = pcall(function()
            core.Player.Revive(target)
        end)
        if ok then
            return true
        end
        print(('[thehunt_death] VORP revive failed for player %s: %s'):format(target, tostring(err)))
    end

    -- Keep a controlled fallback for a transient GetCore/export race. This is
    -- still VORP's revive controller (not a second ResurrectPed implementation)
    -- and lets the client close the HUNT screen through the normal event.
    TriggerEvent('vorp_core:Server:OnPlayerRevive', target)
    TriggerClientEvent('vorp_core:Client:OnPlayerRevive', target, true)
    return true
end

exports('RevivePlayer', function(targetSource)
    return revivePlayer(targetSource)
end)

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end

    local ok, err = pcall(function()
        DB.query.await([[ 
        CREATE TABLE IF NOT EXISTS `thehunt_death_unconscious` (
            `charidentifier` INT NOT NULL PRIMARY KEY,
            `expires_at` BIGINT UNSIGNED NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_expires_at` (`expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])
    end)
    if ok then
        databaseReady = true
        print('[thehunt_death] Database ready; knock persistence enabled.')
    else
        print(('[thehunt_death] Database initialization failed: %s'):format(tostring(err)))
    end
end)

RegisterNetEvent('thehunt_death:server:knocked', function(killerServerId, deathCause)
    local source = source
    if unconsciousPlayers[source] then return end
    unconsciousPlayers[source] = { pending = true }

    CreateThread(function()
        local charId
        while not charId do
            if not unconsciousPlayers[source] then return end
            if databaseReady then
                charId = getCharacterId(source)
            end
            Wait(250)
        end

        -- Covers a resource restart while a player is already unconscious:
        -- never replace an existing deadline with a new five-minute timer.
        local existingExpiresAt = tonumber(DB.scalar.await(
            'SELECT `expires_at` FROM `thehunt_death_unconscious` WHERE `charidentifier` = ? LIMIT 1', { charId }
        ))
        if existingExpiresAt and existingExpiresAt > os.time() then
            unconsciousPlayers[source] = { charId = charId, expiresAt = existingExpiresAt }
            setUnconsciousState(source, true)
            TriggerClientEvent('thehunt_death:client:started', source, existingExpiresAt - os.time())
            return
        end

        if existingExpiresAt then
            DB.update.await('DELETE FROM `thehunt_death_unconscious` WHERE `charidentifier` = ?', { charId })
        end

        local expiresAt = os.time() + Config.UnconsciousDuration
        unconsciousPlayers[source] = { charId = charId, expiresAt = expiresAt }
        setUnconsciousState(source, true)
        DB.update.await([[ 
            INSERT INTO `thehunt_death_unconscious` (`charidentifier`, `expires_at`)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE `expires_at` = VALUES(`expires_at`)
        ]], { charId, expiresAt })

        -- Preserve the detailed HUNT death log without VORP's respawn handler.
        TriggerClientEvent('vorp_core:Client:OnPlayerDeath', source, killerServerId or 0, deathCause or 0)
        TriggerClientEvent('thehunt_death:client:started', source, Config.UnconsciousDuration)
    end)
end)

RegisterNetEvent('thehunt_death:server:requestWake', function()
    local source = source
    local state = unconsciousPlayers[source]

    -- If the resource was restarted while the player remained connected, the
    -- in-memory entry is gone but the deadline is still authoritative in SQL.
    -- Rehydrate it here instead of making Space appear to do nothing.
    if (not state or state.pending) and databaseReady then
        local charId = getCharacterId(source)
        if charId then
            local ok, persistedExpiresAt = pcall(function()
                return tonumber(DB.scalar.await(
                    'SELECT `expires_at` FROM `thehunt_death_unconscious` WHERE `charidentifier` = ? LIMIT 1',
                    { charId }
                ))
            end)
            if ok and persistedExpiresAt then
                state = { charId = charId, expiresAt = persistedExpiresAt }
                unconsciousPlayers[source] = state
            end
        end
    end

    if not state or state.pending then return end
    if os.time() < state.expiresAt then
        TriggerClientEvent('thehunt_death:client:sync', source, math.max(0, state.expiresAt - os.time()))
        return
    end

    local wasAided = state.ready == true
    clearUnconscious(source, true)
    TriggerClientEvent('thehunt_death:client:wake', source, wasAided)
end)

RegisterNetEvent('thehunt_death:server:externalRevive', function()
    -- Sent after VORP's client revive event. Clear the persisted deadline so
    -- a later reconnect cannot restore an old knock.
    clearUnconscious(source, true)
end)

-- Every normal VORP revive (admin panel, vorp_admin and medic integrations)
-- uses this server event before notifying the target client. Keep HUNT's
-- database and replicated state in sync regardless of the initiator.
AddEventHandler('vorp_core:Server:OnPlayerRevive', function(targetSource)
    local target = tonumber(targetSource)
    if target then
        clearUnconscious(target, true)
    end
end)

exports('AidKnockedPlayer', function(_, targetSource, exportedTargetSource)
    -- The runtime normally forwards export arguments without a Lua self
    -- value; accepting the third slot as well keeps colon-style callers safe.
    local target = tonumber(exportedTargetSource or targetSource)
    local state = target and unconsciousPlayers[target]
    if not state or state.pending or state.ready then return false end

    -- Keep the replicated knock flag until the patient presses Space, but set
    -- the authoritative deadline to now. This makes reconnects safe and lets
    -- requestWake consume the ready state normally.
    state.expiresAt = os.time()
    state.ready = true
    setUnconsciousState(target, true)
    local targetPlayer = Player(target)
    if targetPlayer then targetPlayer.state:set('thehuntKnockReady', true, true) end
    if state.charId and databaseReady then
        DB.update.await('UPDATE `thehunt_death_unconscious` SET `expires_at` = ? WHERE `charidentifier` = ?', {
            state.expiresAt, state.charId
        })
    end
    TriggerClientEvent('thehunt_death:client:aidReady', target)
    return true
end)

AddEventHandler('thehunt:character:selected', function(source, characterId)
    local sourceNumber, charId = tonumber(source), tonumber(characterId)
    if not sourceNumber or not charId then return end

    CreateThread(function()
        while not databaseReady do Wait(50) end
        local expiresAt = tonumber(DB.scalar.await(
            'SELECT `expires_at` FROM `thehunt_death_unconscious` WHERE `charidentifier` = ? LIMIT 1', { charId }
        ))
        if not expiresAt then return end

        local remaining = expiresAt - os.time()
        if remaining <= 0 then
            DB.update.await('DELETE FROM `thehunt_death_unconscious` WHERE `charidentifier` = ?', { charId })
            return
        end

        unconsciousPlayers[sourceNumber] = { charId = charId, expiresAt = expiresAt }
        setUnconsciousState(sourceNumber, true)
        TriggerClientEvent('thehunt_death:client:restore', sourceNumber, remaining)
    end)
end)

AddEventHandler('playerDropped', function()
    -- Keep the database record: the countdown continues while offline.
    clearUnconscious(source, false)
end)
