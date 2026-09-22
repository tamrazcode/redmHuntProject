-- HUNT client framework boundary.  VORP lifecycle events are translated once
-- here so custom resources never need to subscribe to framework event names.

local frameworkSessionRequestSent = false
local frameworkSessionConfirmed = false
local frameworkSessionAttempts = 0
local frameworkSessionStartRequested = false

local function RequestVorpPlayerSpawn()
    -- This is the only place in HUNT that is allowed to call the legacy
    -- VORP bootstrap event.  The server-side request remains the normal path;
    -- this direct retry covers a client that joined while the bridge resource
    -- was still starting and therefore never received the proxy callback.
    frameworkSessionStartRequested = true
    TriggerServerEvent('vorp:playerSpawn')
end

local function EnsureFrameworkSession()
    if frameworkSessionRequestSent then return end
    frameworkSessionRequestSent = true
    frameworkSessionAttempts = frameworkSessionAttempts + 1
    TriggerServerEvent('thehunt_core:server:ensureFrameworkSession')

    -- If the proxy callback does not arrive, do not leave the character UI in
    -- a permanent "session is not ready" state.  VORP's handler is idempotent
    -- before a character is selected, and the attempt is limited to one per
    -- bootstrap cycle.
    SetTimeout(750, function()
        if not frameworkSessionConfirmed and not frameworkSessionStartRequested then
            RequestVorpPlayerSpawn()
        end
    end)

    SetTimeout(4000, function()
        if not frameworkSessionConfirmed and frameworkSessionAttempts < 8 then
            frameworkSessionRequestSent = false
            frameworkSessionStartRequested = false
            EnsureFrameworkSession()
        elseif not frameworkSessionConfirmed then
            TriggerServerEvent('thehunt_core:server:sessionDiagnostics')
        end
    end)
end

RegisterNetEvent('thehunt_core:client:startFrameworkSession', function()
    RequestVorpPlayerSpawn()
end)

RegisterNetEvent('thehunt_core:client:frameworkSessionReady', function()
    frameworkSessionConfirmed = true
    frameworkSessionRequestSent = true
    frameworkSessionStartRequested = true
end)

RegisterNetEvent('thehunt_core:client:sessionDiagnostics', function()
    TriggerServerEvent('thehunt_core:server:sessionDiagnostics')
end)

RegisterNetEvent('thehunt_core:client:changeMetabolism', function(key, amount)
    TriggerEvent('vorpmetabolism:changeValue', key, amount)
end)

RegisterNetEvent('thehunt_core:client:updateMetabolismHud', function(hunger, thirst)
    TriggerEvent('thehunt_status:updateMetabolism', hunger, thirst)
end)

AddEventHandler('playerSpawned', function()
    SetTimeout(1000, EnsureFrameworkSession)
end)

CreateThread(function()
    -- Covers the case where this resource starts after the native spawn event.
    Wait(2000)
    EnsureFrameworkSession()
end)

RegisterNetEvent('thehunt_core:client:initializeCharacter', function(coords, heading, isDead)
    TriggerEvent('vorp:initCharacter', coords, heading, isDead)
end)

local function SetFrameworkMetabolismHud(visible)
    TriggerEvent('vorpmetabolism:setHud', visible)
end

local function SaveFrameworkMetabolism()
    TriggerEvent('vorpmetabolism:saveNow')
end

local function GetFrameworkMetabolismValue(key, callback)
    TriggerEvent('vorpmetabolism:getValue', key, callback)
end

local function SetFrameworkWalkStyle(walkStyle)
    TriggerEvent('vorp_walkanim:Server:setwalk', walkStyle)
end

exports('SetMetabolismHud', SetFrameworkMetabolismHud)
exports('SaveMetabolism', SaveFrameworkMetabolism)
exports('GetMetabolismValue', GetFrameworkMetabolismValue)
exports('SetFrameworkWalkStyle', SetFrameworkWalkStyle)

RegisterNetEvent('vorp:SelectedCharacter', function(charId)
    TriggerEvent('thehunt:character:selected', charId)
end)

AddEventHandler('vorp_core:Client:OnPlayerSpawned', function(...)
    TriggerEvent('thehunt:player:spawned', ...)
end)

RegisterNetEvent('vorpcharacter:updateCache', function(skin, comps, compTints)
    TriggerEvent('thehunt:character:frameworkCache', skin, comps, compTints)
end)

RegisterNetEvent('vorpcharacter:savenew', function(comps, skin)
    TriggerEvent('thehunt:character:frameworkSaveNew', comps, skin)
end)

RegisterNetEvent('vorpcharacter:reloadafterdeath', function()
    TriggerEvent('thehunt:character:frameworkReloadAfterDeath')
end)
