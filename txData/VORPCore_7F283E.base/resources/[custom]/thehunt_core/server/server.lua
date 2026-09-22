-- =================================================================
-- Главный серверный модуль (thehunt_core)
-- =================================================================

VorpCore = nil

local function InitVorpCore()
    if not VorpCore and exports.vorp_core then
        pcall(function()
            VorpCore = exports.vorp_core:GetCore()
        end)
    end
    return VorpCore
end

InitVorpCore()

-- VORP compatibility boundary.  HUNT resources must use the exports below
-- instead of importing vorp_core or retaining VORP user objects themselves.
-- Character values are returned only as a compatibility snapshot while legacy
-- domains are migrated; mutations remain explicit operations in this facade.
local function GetVorpUser(source)
    -- Use VORP's source-based snapshot first.  Its old public getUser() path
    -- is Steam-keyed and can miss a user that was correctly created through
    -- the server-side recovery path.
    if GetResourceState('vorp_core') == 'started' then
        local snapshotOk, snapshot = pcall(function()
            return exports.vorp_core:GetUserSnapshotForSource(source)
        end)
        if snapshotOk and snapshot then return snapshot end
    end

    local core = VorpCore or InitVorpCore()
    if not core then return nil end
    if type(core.getUser) == "function" then
        local ok, user = pcall(core.getUser, source)
        if ok and user then return user end
    end

    -- VORP's public getUser implementation resolves only by the current
    -- Steam identifier.  During a reconnect/resource restart that lookup can
    -- briefly miss even though the User object is already present in VORP's
    -- cache.  Resolve the same cache by its authoritative source value before
    -- reporting the HUNT session as unavailable.
    if type(core.getUsers) == "function" then
        local usersOk, users = pcall(core.getUsers)
        if usersOk and type(users) == "table" then
            for _, cachedUser in pairs(users) do
                if type(cachedUser) == "table" and type(cachedUser.Source) == "function" then
                    local sourceOk, cachedSource = pcall(cachedUser.Source)
                    if sourceOk and tonumber(cachedSource) == tonumber(source)
                        and type(cachedUser.GetUser) == "function" then
                        local userOk, resolvedUser = pcall(cachedUser.GetUser)
                        if userOk and resolvedUser then return resolvedUser end
                    end
                end
            end
        end
    end

    return nil
end

local function ReadUsedCharacter(user)
    if not user then return nil end
    if type(user.getUsedCharacter) == "table" then return user.getUsedCharacter end
    if type(user.getUsedCharacter) == "function" then return user.getUsedCharacter() end
    return nil
end

-- Returns two values: whether the source-based export was callable, and the
-- active-character snapshot (which is legitimately nil before selection).
-- A successful nil result must not fall through to GetUserSnapshotForSource:
-- that legacy snapshot serializes every character, including inventories and
-- status blobs, during the character-selection screen.
local function TryGetVorpCharacterForSource(source)
    if GetResourceState('vorp_core') ~= 'started' then return false, nil end

    local directOk, character = pcall(function()
        return exports.vorp_core:GetCharacterForSource(source)
    end)
    if directOk then return true, character end
    return false, nil
end

local function TryGetVorpCharacterIdForSource(source)
    if GetResourceState('vorp_core') ~= 'started' then return false, nil end

    local directOk, charId = pcall(function()
        return exports.vorp_core:GetCharacterIdForSource(source)
    end)
    if directOk then return true, tonumber(charId) end
    return false, nil
end

function GetHuntCharacter(source)
    -- The source-based VORP export returns only the active character.  The
    -- legacy snapshot fallback remains for older VORP builds or during a
    -- resource update where the new export is not available yet.
    local directAvailable, character = TryGetVorpCharacterForSource(source)
    if directAvailable then return character end

    return ReadUsedCharacter(GetVorpUser(source))
end

function IsHuntSessionReady(source)
    if GetResourceState('vorp_core') == 'started' then
        local directOk, ready = pcall(function()
            return exports.vorp_core:IsUserReadyForSource(source)
        end)
        -- nil means the source cannot be resolved through the current VORP
        -- index; keep the legacy resolver available for older/alternate
        -- identifier setups instead of changing their session semantics.
        if directOk and ready ~= nil then return ready == true end
    end

    return GetVorpUser(source) ~= nil
end

-- VORP creates its User object only after the client-side `vorp:playerSpawn`
-- handshake.  The custom HUNT selector can appear before that handshake, so
-- the bridge owns one guarded request instead of making character resources
-- invoke the framework event themselves.
local FrameworkSessionAttempts = {}
local LastBridgedCharacter = {}
RegisterNetEvent('thehunt_core:server:ensureFrameworkSession', function()
    local src = source
    local ready = IsHuntSessionReady(src)
    print(string.format('^5[HUNT CORE] Session bootstrap requested for src %s (ready=%s)^7',
        tostring(src), ready and 'yes' or 'no'))
    if ready then
        TriggerClientEvent('thehunt_core:client:frameworkSessionReady', src)
        return
    end

    local now = GetGameTimer()
    if FrameworkSessionAttempts[src] and (now - FrameworkSessionAttempts[src]) < 10000 then
        return
    end
    FrameworkSessionAttempts[src] = now
    TriggerClientEvent('thehunt_core:client:startFrameworkSession', src)
end)

-- The VORP core indexes users by Steam identifier.  Keep a concise diagnostic
-- when its user cache is unavailable so a missing provider can be distinguished
-- from a delayed resource handshake in the server console.
RegisterNetEvent('thehunt_core:server:sessionDiagnostics', function()
    local src = source
    local steam = GetPlayerIdentifierByType(src, 'steam')
    local license = GetPlayerIdentifierByType(src, 'license')
    print(string.format(
        '^3[HUNT CORE] Session pending for src %s (steam=%s, license=%s, vorpUser=%s)^7',
        tostring(src), steam and 'yes' or 'no', license and 'yes' or 'no',
        IsHuntSessionReady(src) and 'yes' or 'no'
    ))
end)

-- Character actions may arrive during the short interval between the native
-- player spawn and VORP's asynchronous user load.  Waiting here keeps the
-- façade authoritative and avoids a misleading immediate failure toast.
function WaitForHuntSession(source, timeoutMs)
    source = tonumber(source) or source
    timeoutMs = math.max(0, tonumber(timeoutMs) or 5000)
    local deadline = GetGameTimer() + timeoutMs
    repeat
        if IsHuntSessionReady(source) then return true end
        Wait(100)
    until GetGameTimer() >= deadline
    return IsHuntSessionReady(source)
end

exports('WaitForSession', WaitForHuntSession)

-- Server-side session recovery.  The HUNT character flow calls this facade
-- rather than assuming a client-side VORP spawn event was delivered.
function EnsureHuntSession(source, timeoutMs)
    source = tonumber(source) or source
    if IsHuntSessionReady(source) then return true end

    -- Use VORP's explicit server export here.  A local event is not a reliable
    -- session boundary between resources on this FXServer build, while this
    -- export returns only after VORP has created and cached its User object.
    local recovered = false
    if GetResourceState('vorp_core') == 'started' then
        local ok, result = pcall(function()
            return exports.vorp_core:EnsureUserForSource(source)
        end)
        recovered = ok and result == true
        if not ok then
            print('^1[HUNT CORE] VORP user recovery export failed: ' .. tostring(result) .. '^7')
        end
    end
    print(string.format('^5[HUNT CORE] VORP user recovery for src %s: %s^7',
        tostring(source), recovered and 'ready' or 'failed'))

    return WaitForHuntSession(source, timeoutMs or 5000)
end

exports('EnsureSession', EnsureHuntSession)

AddEventHandler('playerDropped', function()
    FrameworkSessionAttempts[source] = nil
    LastBridgedCharacter[source] = nil
end)

function GetHuntCharacterId(source)
    local directAvailable, charId = TryGetVorpCharacterIdForSource(source)
    if directAvailable then return charId end

    local character = GetHuntCharacter(source)
    return character and tonumber(character.charIdentifier or character.charid) or nil
end

function GetHuntPlayerIdentifier(source)
    local directAvailable, character = TryGetVorpCharacterForSource(source)
    if character and character.identifier then return character.identifier end

    -- With the source-based VORP export available, an absent active character
    -- is expected in the selector. Do not build the heavyweight legacy user
    -- snapshot just to obtain an identifier.
    if directAvailable then
        return GetPlayerIdentifierByType(source, 'steam')
            or GetPlayerIdentifierByType(source, 'license')
    end

    local user = GetVorpUser(source)
    if user and user.identifier then return user.identifier end

    return GetPlayerIdentifierByType(source, 'steam')
        or GetPlayerIdentifierByType(source, 'license')
end

function GetHuntPlayerGroup(source)
    if GetResourceState('vorp_core') == 'started' then
        local directOk, group = pcall(function()
            return exports.vorp_core:GetUserGroupForSource(source)
        end)
        -- A callable source-based export returning nil means that VORP has no
        -- group for this source yet. It is not a reason to serialize the full
        -- legacy user snapshot while the selector is opening.
        if directOk then return group end
    end

    local user = GetVorpUser(source)
    if user then
        if type(user.getGroup) == "function" then return user.getGroup() end
        if type(user.getGroup) == "string" then return user.getGroup end
    end

    local character = GetHuntCharacter(source)
    return character and character.group or nil
end

function SelectHuntCharacter(source, charIdentifier)
    charIdentifier = tonumber(charIdentifier)
    if not charIdentifier then return nil, "invalid_character" end

    -- Keep activation inside VORP, addressed by source. Passing a mutable
    -- User object through an export is not reliable on every FXServer build;
    -- this explicit adapter returns the activation result instead.
    if GetResourceState('vorp_core') == 'started' then
        local exportOk, activated, activationError = pcall(function()
            return exports.vorp_core:SelectCharacterForSource(source, charIdentifier, false)
        end)
        if exportOk then
            if not activated then
                return nil, activationError or "activation_failed"
            end
            return true
        end
    end

    local user = GetVorpUser(source)
    if not user or type(user.setUsedCharacter) ~= "function" then
        return nil, "session_unavailable"
    end

    local current = ReadUsedCharacter(user)
    if tonumber(current and (current.charIdentifier or current.charid)) ~= charIdentifier then
        local ok, result = pcall(user.setUsedCharacter, charIdentifier)
        if not ok then return nil, "activation_error:" .. tostring(result) end
    end

    local active = GetHuntCharacter(source)
    if active and tonumber(active.charIdentifier or active.charid) == charIdentifier then
        return active
    end
    return nil, "activation_failed"
end

function CreateHuntCharacter(source, characterData)
    -- Keep the mutation inside VORP, addressed by source. A public User
    -- snapshot is suitable for reads but its addCharacter closure can be
    -- stripped or detached when returned across a resource boundary.
    if GetResourceState('vorp_core') == 'started' then
        local exportOk, created, creationError = pcall(function()
            return exports.vorp_core:CreateCharacterForSource(source, characterData)
        end)
        if exportOk then
            return created, creationError
        end
    end

    local user = GetVorpUser(source)
    if not user or type(user.addCharacter) ~= "function" then
        return false, "session_unavailable"
    end

    local ok, result = pcall(user.addCharacter, characterData)
    if not ok then return false, tostring(result) end
    return true, result
end

function SyncHuntCharacterCoords(source, coordsJson)
    if GetResourceState('vorp_core') == 'started' then
        local exportOk, synced, syncError = pcall(function()
            return exports.vorp_core:SyncCharacterCoordsForSource(source, coordsJson)
        end)
        if exportOk then return synced, syncError end
    end

    local character = GetHuntCharacter(source)
    if not character or type(character.Coords) ~= "function" then return false end
    local ok = pcall(character.Coords, coordsJson)
    return ok
end

function SetHuntCharacterVitals(source, state)
    if GetResourceState('vorp_core') == 'started' then
        local exportOk, updated, updateError = pcall(function()
            return exports.vorp_core:SetCharacterVitalsForSource(source, state)
        end)
        if exportOk then return updated, updateError end
    end

    local character = GetHuntCharacter(source)
    if not character or type(state) ~= "table" then return false end

    local operations = {
        { "HealthOuter", state.healthOuter },
        { "HealthInner", state.healthInner },
        { "StaminaOuter", state.staminaOuter },
        { "StaminaInner", state.staminaInner }
    }
    for _, operation in ipairs(operations) do
        if operation[2] ~= nil and type(character[operation[1]]) == "function" then
            local ok = pcall(character[operation[1]], operation[2])
            if not ok then return false end
        end
    end
    return true
end

function UpdateHuntCharacterAppearance(source, skinJson, compsJson, tintsJson)
    if GetResourceState('vorp_core') == 'started' then
        local exportOk, updated, updateError = pcall(function()
            return exports.vorp_core:UpdateCharacterAppearanceForSource(source, skinJson, compsJson, tintsJson)
        end)
        if exportOk then return updated, updateError end
    end

    local character = GetHuntCharacter(source)
    if not character then return false end

    local operations = {
        { "updateSkin", skinJson },
        { "updateComps", compsJson },
        { "updateCompTints", tintsJson }
    }
    for _, operation in ipairs(operations) do
        if operation[2] ~= nil and type(character[operation[1]]) == "function" then
            local ok = pcall(character[operation[1]], operation[2])
            if not ok then return false end
        end
    end
    return true
end

exports('GetCharacter', GetHuntCharacter)
exports('IsSessionReady', IsHuntSessionReady)
exports('GetCharacterId', GetHuntCharacterId)
exports('GetPlayerIdentifier', GetHuntPlayerIdentifier)
exports('GetPlayerGroup', GetHuntPlayerGroup)
exports('SelectCharacter', SelectHuntCharacter)
exports('CreateCharacter', CreateHuntCharacter)
exports('SyncCharacterCoords', SyncHuntCharacterCoords)
exports('SetCharacterVitals', SetHuntCharacterVitals)
exports('UpdateCharacterAppearance', UpdateHuntCharacterAppearance)

local function BridgeSelectedCharacter(playerSource, characterOrId)
    local charId = characterOrId
    if type(characterOrId) == 'table' then
        charId = characterOrId.charIdentifier or characterOrId.charid
    end

    local sourceNumber = tonumber(playerSource) or playerSource
    local charNumber = tonumber(charId) or charId
    if not sourceNumber or not charNumber then return end

    -- VORP can replay the local selection notification while the client
    -- handshake is settling.  Keep the framework event idempotent so status,
    -- loot and other listeners cannot repeat their database work for the
    -- same source/character pair.  A later real re-login is allowed through
    -- after this short lifecycle window.
    local now = GetGameTimer()
    local previous = LastBridgedCharacter[sourceNumber]
    if previous and previous.charId == charNumber and (now - previous.at) < 5000 then
        return
    end
    LastBridgedCharacter[sourceNumber] = { charId = charNumber, at = now }

    TriggerEvent('thehunt:character:selected', sourceNumber, charNumber)
end

-- VORP emits two notifications with the same name in different contexts:
-- server-local (source, character snapshot) and client-net (char id).  Only
-- the local event belongs here; the client event is handled by the client
-- bridge.  Registering both on the server makes one selection dispatch the
-- HUNT lifecycle twice and can duplicate database-backed listeners.
AddEventHandler('vorp:SelectedCharacter', function(playerSource, character)
    BridgeSelectedCharacter(playerSource, character)
end)

AddEventHandler('vorp_CreateNewCharacter', function(playerSource)
    TriggerClientEvent('thehunt_core:client:frameworkSessionReady', playerSource)
    TriggerEvent('thehunt:framework:createCharacter', playerSource)
end)

AddEventHandler('vorp_character:server:SpawnUniqueCharacter', function(playerSource)
    TriggerClientEvent('thehunt_core:client:frameworkSessionReady', playerSource)
    TriggerEvent('thehunt:framework:openCharacterSelection', playerSource)
end)

AddEventHandler('vorp_character:server:GoToSelectionMenu', function(playerSource)
    TriggerClientEvent('thehunt_core:client:frameworkSessionReady', playerSource or source)
    TriggerEvent('thehunt:framework:openCharacterSelection', playerSource or source)
end)

RegisterNetEvent('vorpcharacter:saveCharacter', function(data)
    TriggerEvent('thehunt:framework:saveCharacter', source, data)
end)

RegisterNetEvent('vorpcharacter:deleteCharacter', function(selectedCharacter)
    TriggerEvent('thehunt:framework:deleteCharacter', source, selectedCharacter)
end)

RegisterNetEvent('vorp_CharSelectedCharacter', function(charId)
    TriggerEvent('thehunt:framework:selectCharacter', source, charId)
end)

RegisterNetEvent('vorpcharacter:setPlayerCompChange', function(skinValues, compsValues, compTints)
    TriggerEvent('thehunt:framework:appearanceChanged', source, skinValues, compsValues, compTints)
end)

Citizen.CreateThread(function()
    InitVorpCore()
    if VorpCore then
        print("^2[HUNT CORE] Успешно подключено ядро VORP Core!^7")
    end
end)

-- Получение RP-имени персонажа
function GetPlayerRPName(source)
    if source == 0 then
        return "Сервер"
    end

    local char = GetHuntCharacter(source)
    if char then
        local firstName = char.firstname or ""
        local lastName = char.lastname or ""
        local fullName = (firstName .. " " .. lastName):gsub("^%s*(.-)%s*$", "%1")
        if fullName ~= "" then
            return fullName
        end
    end

    return GetPlayerName(source) or ("Неизвестный [" .. tostring(source) .. "]")
end

-- Получение ника RedM (Steam/FiveM)
function GetPlayerRedMName(source)
    if source == 0 then return "Сервер" end
    return GetPlayerName(source) or ("Player " .. tostring(source))
end

-- Получение пола персонажа: "male" или "female"
function GetPlayerGender(source)
    if source == 0 then return "male" end

    local char = GetHuntCharacter(source)
    if char and char.gender then
        local g = tostring(char.gender):lower()
        if g == "female" or g == "f" or g == "1" then
            return "female"
        end
    end

    return "male"
end

-- Получение метки "Незнакомец" / "Незнакомка" по полу
function GetStrangerName(source)
    local gender = GetPlayerGender(source)
    if gender == "female" then
        return "Незнакомка"
    end
    return "Незнакомец"
end

AdminIdentifiers = {
    ["12184966"] = true,           -- tamraz
    ["885049419366543360"] = true, -- tamraz discord
    ["14054765"] = true,           -- weeje
    ["233282815716753410"] = true, -- weeje discord
    ["672859450553401355"] = true, -- kittybar discord
}

-- Persistent HUNT permission overrides.
--
-- AdminIdentifiers and ACE/VORP groups are legacy/shared permission sources.
-- They cannot represent a revocation made from the HUNT panel: an identifier
-- may still be present in ACE or in the static allow-list after the resource
-- restarts.  This small table stores an explicit decision per player
-- identifier, so a revoke remains a revoke after restart and a grant remains
-- a grant even while VORP's in-memory user cache is still being rebuilt.
local AdminPermissionOverrides = {}
local AdminPermissionStorageReady = false
local AdminPermissionStorageLoading = false
local AdminPermissionStorageWarningShown = false
local AdminPermissionStorageNextRetryAt = 0
local AdminPermissionStorageRetryDelayMs = 1000
local ADMIN_PERMISSION_RETRY_MAX_MS = 60000

local function NormalizeAdminPermissionIdentifier(identifier)
    local value = tostring(identifier or ""):lower()
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function GetAdminPermissionIdentifiers(source)
    local identifiers = {}
    local seen = {}
    source = tonumber(source) or source

    for _, identifier in ipairs(GetPlayerIdentifiers(source) or {}) do
        local normalized = NormalizeAdminPermissionIdentifier(identifier)
        if normalized ~= "" and not seen[normalized] then
            seen[normalized] = true
            identifiers[#identifiers + 1] = normalized
        end
    end

    return identifiers
end

local function LoadAdminPermissionStorage()
    if AdminPermissionStorageReady then return true end
    if AdminPermissionStorageLoading then return false end

    local now = GetGameTimer()
    if now < AdminPermissionStorageNextRetryAt then
        return false
    end

    -- MySQL is provided by @oxmysql/lib/MySQL.lua.  A resource restart can
    -- briefly happen before oxmysql is ready; keep the legacy permission
    -- paths alive instead of indexing a nil global and flooding the console.
    if not MySQL or type(MySQL.query) ~= "table" or type(MySQL.query.await) ~= "function" then
        if not AdminPermissionStorageWarningShown then
            AdminPermissionStorageWarningShown = true
            print("^3[HUNT ADMIN] Persistent permissions are waiting for oxmysql; legacy admin permissions remain active.^7")
        end
        return false
    end

    AdminPermissionStorageLoading = true
    local ok, rowsOrError = pcall(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS `thehunt_core_admin_permissions` (
                `identifier` varchar(191) NOT NULL,
                `is_admin` tinyint(1) NOT NULL DEFAULT 0,
                `group_name` varchar(32) NOT NULL DEFAULT 'user',
                `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]))

        return MySQL.query.await(([[
            SELECT `identifier`, `is_admin`, `group_name`
            FROM `thehunt_core_admin_permissions`
        ]]))
    end)

    if ok then
        AdminPermissionOverrides = {}
        for _, row in ipairs(rowsOrError or {}) do
            local identifier = NormalizeAdminPermissionIdentifier(row.identifier)
            if identifier ~= "" then
                AdminPermissionOverrides[identifier] = (tonumber(row.is_admin) == 1 or row.is_admin == true)
            end
        end
        AdminPermissionStorageReady = true
        AdminPermissionStorageWarningShown = false
        AdminPermissionStorageNextRetryAt = 0
        AdminPermissionStorageRetryDelayMs = 1000
        print(string.format("^2[HUNT ADMIN] Persistent permission overrides loaded: %d^7", #((rowsOrError or {}))))
    else
        AdminPermissionStorageNextRetryAt = now + AdminPermissionStorageRetryDelayMs
        AdminPermissionStorageRetryDelayMs = math.min(AdminPermissionStorageRetryDelayMs * 2, ADMIN_PERMISSION_RETRY_MAX_MS)
        if not AdminPermissionStorageWarningShown then
            AdminPermissionStorageWarningShown = true
            print(string.format("^3[HUNT ADMIN] Persistent permissions are temporarily unavailable; legacy admin permissions remain active. Retry: %s^7", tostring(rowsOrError)))
        end
    end

    AdminPermissionStorageLoading = false
    return ok
end

local function EnsureAdminPermissionStorage()
    if not AdminPermissionStorageReady and not AdminPermissionStorageLoading then
        LoadAdminPermissionStorage()
    end

    -- A resource restart can receive F4/action events while the initial
    -- SELECT is still in progress.  Give that load a short chance to finish
    -- instead of falling through to the stale VORP cache.
    local attempts = 0
    while AdminPermissionStorageLoading and not AdminPermissionStorageReady and attempts < 500 do
        Citizen.Wait(10)
        attempts = attempts + 1
    end

    return AdminPermissionStorageReady
end

Citizen.CreateThread(function()
    while not AdminPermissionStorageReady do
        LoadAdminPermissionStorage()
        if not AdminPermissionStorageReady then
            Citizen.Wait(1000)
        end
    end
end)

function GetPlayerAdminOverride(source)
    source = tonumber(source) or source
    if source == 0 then return true end

    EnsureAdminPermissionStorage()

    local hasAllow = false
    for _, identifier in ipairs(GetAdminPermissionIdentifiers(source)) do
        local decision = AdminPermissionOverrides[identifier]
        -- A deny wins if stale rows for different identifiers disagree.
        if decision == false then return false end
        if decision == true then hasAllow = true end
    end

    if hasAllow then return true end
    return nil
end

function SetPlayerAdminOverride(source, state, groupName)
    source = tonumber(source) or source
    if not source or source == 0 then return false, "invalid_source" end

    local identifiers = GetAdminPermissionIdentifiers(source)
    if #identifiers == 0 then return false, "no_identifiers" end

    local isAdmin = state == true
    local group = tostring(groupName or (isAdmin and "admin" or "user")):lower()
    local storageOk = EnsureAdminPermissionStorage()

    -- Update memory first so the new decision is effective immediately.
    for _, identifier in ipairs(identifiers) do
        AdminPermissionOverrides[identifier] = isAdmin
    end

    if not storageOk then
        return false, "storage_unavailable"
    end

    local allWritesOk = true
    for _, identifier in ipairs(identifiers) do
        local ok, err = pcall(function()
            MySQL.update.await(([[
                INSERT INTO `thehunt_core_admin_permissions` (`identifier`, `is_admin`, `group_name`)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    `is_admin` = VALUES(`is_admin`),
                    `group_name` = VALUES(`group_name`),
                    `updated_at` = CURRENT_TIMESTAMP
            ]]), { identifier, isAdmin and 1 or 0, group })
        end)

        if not ok then
            allWritesOk = false
            print(string.format("^1[HUNT ADMIN] Failed to save override for %s: %s^7", identifier, tostring(err)))
        end
    end

    if allWritesOk then
        return true, nil
    end

    return false, "write_failed"
end

exports('GetPlayerAdminOverride', GetPlayerAdminOverride)
exports('IsPlayerAdminOverrideDenied', function(source)
    return GetPlayerAdminOverride(source) == false
end)
exports('SetPlayerAdminOverride', SetPlayerAdminOverride)

function SetAdminIdentifier(identifier, state)
    if not identifier then return end
    local idStr = tostring(identifier)
    if state then
        AdminIdentifiers[idStr] = true
    else
        AdminIdentifiers[idStr] = nil
    end
end
exports('SetAdminIdentifier', SetAdminIdentifier)

-- Надежная проверка прав администратора
function IsPlayerAdmin(source)
    if source == 0 then return true end

    -- An explicit persistent decision made in the HUNT panel has priority
    -- over legacy static identifiers, ACE and the VORP group cache.
    local override = GetPlayerAdminOverride(source)
    if override ~= nil then return override end

    -- 1. Проверка прямых идентификаторов администраторов (FiveM / Discord / Steam / License)
    local identifiers = GetPlayerIdentifiers(source) or {}
    for _, id in ipairs(identifiers) do
        local idStr = string.lower(tostring(id))
        for adminId, _ in pairs(AdminIdentifiers) do
            if string.find(idStr, string.lower(adminId), 1, true) then
                return true
            end
        end
    end

    -- 2. Проверка ACE-прав FiveM / RedM / txAdmin
    if IsPlayerAceAllowed(source, "command")
    or IsPlayerAceAllowed(source, "command.builder")
    or IsPlayerAceAllowed(source, "group.admin")
    or IsPlayerAceAllowed(source, "admin")
    or IsPlayerAceAllowed(source, "txadmin")
    or IsPlayerAceAllowed(source, "txadmin.menu")
    or IsPlayerAceAllowed(source, "thehunt.admin") then
        return true
    end

    -- 3. Проверка VORP Core User / Character Group
    local group = GetHuntPlayerGroup(source)
    if group then
        local gStr = string.lower(tostring(group))
        if Config and Config.AdminGroups then
            for _, adminGroup in ipairs(Config.AdminGroups) do
                if gStr == string.lower(adminGroup) then
                    return true
                end
            end
        end
        if gStr == "admin" or gStr == "superadmin" or gStr == "mod" or gStr == "moderator" or gStr == "owner" or gStr == "developer" then
            return true
        end
    end

    return false
end

exports('IsPlayerAdmin', IsPlayerAdmin)

-- Резервное подключение журнала активности. В штатном режиме файл уже
-- выполнен через server_scripts из fxmanifest. Отложенная проверка нужна для
-- старых/залипших ресурсных кэшей CFX: она не создаёт дубликатов благодаря
-- флагу HUNT_PLAYER_LOGS_LOADED в самом модуле логов.
Citizen.CreateThread(function()
    Citizen.Wait(0)
    if HUNT_PLAYER_LOGS_LOADED then return end

    local sourceCode = LoadResourceFile(GetCurrentResourceName(), "server/player_logs.lua")
    if not sourceCode then
        print("^1[HUNT LOGS] Не удалось найти server/player_logs.lua для резервной загрузки^7")
        return
    end

    local chunk, compileError = load(sourceCode, "@thehunt_core/server/player_logs.lua", "t", _ENV)
    if not chunk then
        print(string.format("^1[HUNT LOGS] Ошибка разбора server/player_logs.lua: %s^7", tostring(compileError)))
        return
    end

    local ok, runtimeError = pcall(chunk)
    if not ok then
        print(string.format("^1[HUNT LOGS] Ошибка резервного запуска журнала: %s^7", tostring(runtimeError)))
    end
end)
