-- =================================================================
-- HUNT: Hard RP — The Corruption | Player to Player Interaction
-- =================================================================

local registeredPlayerEntities = {}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300)
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            local myCoords = GetEntityCoords(myPed)
            local currentActivePeds = {}

            local activePlayers = GetActivePlayers()
            for _, playerIndex in ipairs(activePlayers) do
                local targetPed = GetPlayerPed(playerIndex)
                if targetPed ~= myPed and DoesEntityExist(targetPed) then
                    local targetCoords = GetEntityCoords(targetPed)
                    local dist = #(myCoords - targetCoords)

                    if dist <= 3.0 then
                        currentActivePeds[targetPed] = true

                        if not registeredPlayerEntities[targetPed] then
                            registeredPlayerEntities[targetPed] = true
                            if exports['thehunt_interact'] then
                                exports['thehunt_interact']:AddTargetEntity(targetPed, Config.PlayerActions, Config.MaxDistance or 1.7)
                            end
                        end
                    end
                end
            end

            -- Очищаем ушедших игроков
            for ped, _ in pairs(registeredPlayerEntities) do
                if not currentActivePeds[ped] or not DoesEntityExist(ped) then
                    registeredPlayerEntities[ped] = nil
                    if exports['thehunt_interact'] then
                        exports['thehunt_interact']:RemoveTargetEntity(ped)
                    end
                end
            end
        end
    end
end)

-- Обработчик действия «Передать»
RegisterNetEvent("thehunt_playerinteraction:openTransferMode", function(data)
    local targetEntity = data and (data.entity or (data.targetInfo and data.targetInfo.entity))
    if not targetEntity or not DoesEntityExist(targetEntity) then return end

    local targetPlayerId = NetworkGetPlayerIndexFromPed(targetEntity)
    if targetPlayerId == -1 or not NetworkIsPlayerActive(targetPlayerId) then
        TriggerEvent("thehunt_status:notify", "Передача", "Игрок недоступен", "error")
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayerId)
    local isMale = IsPedMale(targetEntity)
    local targetStrangerLabel = string.format("[%d] %s", targetServerId, isMale and "Незнакомец" or "Незнакомка")
    local targetState = Player(targetServerId).state
    local targetIsKnocked = (targetState and (targetState.thehuntUnconscious == true or targetState.isDead == true)) or IsPedDeadOrDying(targetEntity, true)

    -- Открываем сеточный инвентарь в режиме прямой пакетной передачи
    TriggerEvent("thehunt_inventory:openDirectTransfer", targetServerId, targetStrangerLabel, targetIsKnocked, targetEntity)
end)

-- Обработчик действия «Медицина» (открытие инвентаря для применения медицины к игроку)
RegisterNetEvent("thehunt_playerinteraction:openMedicineMenu", function(data)
    local targetEntity = data and (data.entity or (data.targetInfo and data.targetInfo.entity))
    if not targetEntity or not DoesEntityExist(targetEntity) then return end

    local targetPlayerId = NetworkGetPlayerIndexFromPed(targetEntity)
    if targetPlayerId == -1 or not NetworkIsPlayerActive(targetPlayerId) then
        TriggerEvent("thehunt_status:notify", "Медицина", "Игрок недоступен", "error")
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayerId)
    local isMale = IsPedMale(targetEntity)
    local targetStrangerLabel = string.format("[%d] %s", targetServerId, isMale and "Незнакомец" or "Незнакомка")
    local targetState = Player(targetServerId).state
    local targetIsKnocked = (targetState and (targetState.thehuntUnconscious == true or targetState.isDead == true)) or IsPedDeadOrDying(targetEntity, true)

    -- Открываем сеточный инвентарь в режиме применения медицины
    TriggerEvent("thehunt_inventory:openMedicineTarget", targetServerId, targetStrangerLabel, targetIsKnocked, targetEntity)
end)
