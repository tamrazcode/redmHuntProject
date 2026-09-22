-- =================================================================
-- HUNT: Hard RP — The Corruption | Админские метки на карте (/adminblips)
-- =================================================================

RegisterCommand("adminblips", function(source)
    if source == 0 or IsPlayerAdmin(source) then
        TriggerClientEvent("thehunt_admin:toggleBlips", source)
    else
        TriggerClientEvent("thehunt_rp:show3DText", source, source, "(( [Ошибка] У вас нет прав администратора ))", { 255, 50, 50 })
    end
end, false)

-- Отправка списка всех активных игроков админу
RegisterNetEvent("thehunt_admin:requestPlayersData", function()
    local src = source
    if not IsPlayerAdmin(src) then return end

    local playersData = {}
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local rpName = GetPlayerRPName(playerId)
            local redmName = GetPlayerRedMName(playerId)
            local label = string.format("[%s] %s (%s)", playerId, rpName, redmName)
            local health = tonumber(GetEntityHealth(ped)) or 100
            local maxHealth = tonumber(GetEntityMaxHealth(ped)) or 100

            local hunger = 100
            local thirst = 100
            pcall(function()
                if exports.vorp_core then
                    local user = exports.vorp_core:GetCore().getUser(playerId)
                    local char = user and user.getUsedCharacter
                    if char and char.status then
                        local s = (type(char.status) == "table") and char.status or json.decode(char.status)
                        if s then
                            hunger = math.floor((tonumber(s.Hunger or 1000) / 1000) * 100)
                            thirst = math.floor((tonumber(s.Thirst or 1000) / 1000) * 100)
                        end
                    end
                end
            end)

            table.insert(playersData, {
                id = tonumber(playerId),
                coords = coords,
                name = label,
                rpName = rpName,
                redmName = redmName,
                health = health,
                maxHealth = maxHealth,
                hunger = hunger,
                thirst = thirst
            })
        end
    end

    TriggerClientEvent("thehunt_admin:syncPlayersData", src, playersData)
end)
