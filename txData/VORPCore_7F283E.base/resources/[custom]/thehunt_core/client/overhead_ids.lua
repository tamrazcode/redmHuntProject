-- HUNT: global overhead IDs and nearby transfer badges.

local showPlayerIDs = false
local showTransferIDs = false
local adminBlipsActive = false
local cachedPlayers = {}

local OVERHEAD_MAX_DISTANCE = 9999999.0
local OVERHEAD_DATA_REFRESH_MS = 500

local function RequestPlayerSnapshot()
    TriggerServerEvent("thehunt_admin:requestPlayersData")
end

local function SetPlayerIDsVisible(enabled)
    showPlayerIDs = enabled == true
    if showPlayerIDs then
        RequestPlayerSnapshot()
    end
end

RegisterNetEvent("thehunt_admin:togglePlayerIDs", function()
    SetPlayerIDsVisible(not showPlayerIDs)
    print(string.format("^3[HUNT ADMIN] Overhead Player IDs: %s^7", showPlayerIDs and "ENABLED" or "DISABLED"))
end)

exports('togglePlayerIDs', function(state)
    SetPlayerIDsVisible(state == nil and not showPlayerIDs or state)
end)

exports('isPlayerIDsActive', function()
    return showPlayerIDs
end)

RegisterNetEvent("thehunt_core:showTransferNearbyIDs", function(state)
    showTransferIDs = state == true
end)

exports('showTransferNearbyIDs', function(state)
    showTransferIDs = state == true
end)

local function UpdatePlayerSnapshot(playersList)
    if type(playersList) ~= "table" then return end

    local nextSnapshot = {}
    for _, player in ipairs(playersList) do
        local playerId = tonumber(player.id)
        local coords = player.coords
        if playerId and coords then
            local maxHealth = tonumber(player.maxHealth) or 100
            local health = tonumber(player.health) or maxHealth
            local healthPercent = math.floor(math.max(0, math.min(100, (health / (maxHealth > 0 and maxHealth or 100)) * 100)))
            local hunger = math.floor(math.max(0, math.min(100, tonumber(player.hunger) or 100)))
            local thirst = math.floor(math.max(0, math.min(100, tonumber(player.thirst) or 100)))
            local redmName = player.redmName or ("Player " .. tostring(playerId))

            nextSnapshot[playerId] = {
                x = tonumber(coords.x) or 0.0,
                y = tonumber(coords.y) or 0.0,
                z = tonumber(coords.z) or 0.0,
                line1 = string.format("[%d] %s", playerId, redmName),
                line2 = player.rpName or "",
                line3 = string.format("HP: %d%%  |  Еда: %d%%  |  Вода: %d%%", healthPercent, hunger, thirst),
            }
        end
    end

    cachedPlayers = nextSnapshot
end

RegisterNetEvent("thehunt_admin:syncPlayersData", UpdatePlayerSnapshot)
-- Compatibility while clients finish a rolling core-resource restart.
RegisterNetEvent("thehunt_admin:syncOverheadNames", UpdatePlayerSnapshot)

AddEventHandler("thehunt_admin:adminBlipsStateChanged", function(enabled)
    adminBlipsActive = enabled == true
    if adminBlipsActive then
        RequestPlayerSnapshot()
    end
end)

local function DrawOverheadTag(screenX, screenY, line1, line2, line3, dist)
    local scaleFactor = 0.32 + math.min(0.06, math.max(0.0, dist - 20.0) * 0.00001)
    local subScale1 = scaleFactor * 0.72
    local subScale2 = scaleFactor * 0.65

    local textStr1 = VarString(10, "LITERAL_STRING", line1, Citizen.ResultAsLong())
    SetTextScale(scaleFactor, scaleFactor)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 245)
    SetTextCentre(1)
    SetTextDropshadow(2, 0, 0, 0, 255)
    DisplayText(textStr1, screenX, screenY)

    local currentYOffset = 0.022 * (scaleFactor / 0.32)
    if line2 ~= "" then
        local textStr2 = VarString(10, "LITERAL_STRING", line2, Citizen.ResultAsLong())
        SetTextScale(subScale1, subScale1)
        SetTextFontForCurrentCommand(1)
        SetTextColor(175, 185, 195, 225)
        SetTextCentre(1)
        SetTextDropshadow(2, 0, 0, 0, 255)
        DisplayText(textStr2, screenX, screenY + currentYOffset)
        currentYOffset = currentYOffset + (0.019 * (scaleFactor / 0.32))
    end

    local textStr3 = VarString(10, "LITERAL_STRING", line3, Citizen.ResultAsLong())
    SetTextScale(subScale2, subScale2)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 159, 67, 240)
    SetTextCentre(1)
    SetTextDropshadow(2, 0, 0, 0, 255)
    DisplayText(textStr3, screenX, screenY + currentYOffset)
end

-- Shared visual style for resource-owned entity labels.
exports('DrawOverheadTag', DrawOverheadTag)

local function DrawTransferIDBadge(x, y, z, serverId)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    local text = string.format("[ID: %d]", serverId)
    local textStr = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextScale(0.38, 0.38)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 159, 67, 255)
    SetTextCentre(1)
    SetTextDropshadow(2, 0, 0, 0, 255)
    DisplayText(textStr, screenX, screenY)
end

Citizen.CreateThread(function()
    while true do
        if showPlayerIDs or adminBlipsActive then
            RequestPlayerSnapshot()
            Citizen.Wait(OVERHEAD_DATA_REFRESH_MS)
        else
            Citizen.Wait(3000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        if showPlayerIDs or showTransferIDs then
            Citizen.Wait(0)

            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local myPlayerId = PlayerId()

            if showTransferIDs then
                for _, playerIndex in ipairs(GetActivePlayers()) do
                    if playerIndex ~= myPlayerId then
                        local ped = GetPlayerPed(playerIndex)
                        if DoesEntityExist(ped) then
                            local coords = GetEntityCoords(ped)
                            local dx = myCoords.x - coords.x
                            local dy = myCoords.y - coords.y
                            local dz = myCoords.z - coords.z
                            local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
                            if distance <= 15.0 then
                                local headCoords = GetPedBoneCoords(ped, 21030, 0.0, 0.0, 0.0)
                                local tagZ = (headCoords and headCoords.z > 0) and (headCoords.z + 0.42) or (coords.z + 1.0)
                                DrawTransferIDBadge(headCoords.x, headCoords.y, tagZ, GetPlayerServerId(playerIndex))
                            end
                        end
                    end
                end
            end

            if showPlayerIDs then
                for serverId, info in pairs(cachedPlayers) do
                    -- Project server coordinates first. Off-screen players do
                    -- not need a local ped lookup, bone lookup, or distance work.
                    local preliminaryOnScreen = GetScreenCoordFromWorldCoord(info.x, info.y, info.z + 1.05)
                    if preliminaryOnScreen then
                        local playerIndex = GetPlayerFromServerId(serverId)
                        local ped = nil
                        if playerIndex and playerIndex ~= -1 then
                            local candidatePed = GetPlayerPed(playerIndex)
                            if DoesEntityExist(candidatePed) then
                                ped = candidatePed
                            end
                        end

                        local tagX, tagY, tagZ = info.x, info.y, info.z + 1.05
                        local worldX, worldY, worldZ = info.x, info.y, info.z
                        if ped then
                            local pedCoords = GetEntityCoords(ped)
                            worldX, worldY, worldZ = pedCoords.x, pedCoords.y, pedCoords.z
                            local headCoords = GetPedBoneCoords(ped, 21030, 0.0, 0.0, 0.0)
                            tagX = headCoords.x
                            tagY = headCoords.y
                            tagZ = (headCoords and headCoords.z > 0) and (headCoords.z + 0.46) or (pedCoords.z + 1.05)
                        end

                        local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(tagX, tagY, tagZ)
                        if onScreen then
                            local dx = myCoords.x - worldX
                            local dy = myCoords.y - worldY
                            local dz = myCoords.z - worldZ
                            local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
                            if distance <= OVERHEAD_MAX_DISTANCE then
                                DrawOverheadTag(screenX, screenY, info.line1, info.line2, info.line3, distance)
                            end
                        end
                    end
                end
            end
        else
            Citizen.Wait(600)
        end
    end
end)
