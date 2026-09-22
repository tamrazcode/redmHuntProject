-- =================================================================
-- HUNT: Hard RP — Campfire System | Client Controller
-- =================================================================

-- 1. Разжечь костёр
RegisterNetEvent("thehunt_items:clientLightCampfire", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    TriggerServerEvent("thehunt_items:serverLightCampfire", tonumber(propId))
end)

-- Проигрывание анимации розжига (колено перед костром, 5 секунд)
RegisterNetEvent("thehunt_items:clientStartIgniteSequence", function(propId)
    local ped = PlayerPedId()
    local scenarioHash = GetHashKey("WORLD_HUMAN_CROUCH_INSPECT")

    -- Campfire ignition is a committed five-second action: F1 must not
    -- interrupt it, but the scenario still exits normally at the end.
    TriggerEvent('thehunt_animations:client:setProtectedAction', true, 'campfire_ignite', 5500)
    TaskStartScenarioInPlace(ped, scenarioHash, -1, true, false, false, false)

    Citizen.CreateThread(function()
        Citizen.Wait(5000)
        ClearPedTasks(ped)
        TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'campfire_ignite')
        TriggerServerEvent("thehunt_items:serverFinishLightCampfire", tonumber(propId))
    end)
end)

-- 2. Подкинуть древесину
RegisterNetEvent("thehunt_items:clientAddFuelWood", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    TriggerServerEvent("thehunt_items:serverAddFuelWood", tonumber(propId))
end)

-- 3. Подкинуть ветки
RegisterNetEvent("thehunt_items:clientAddFuelTwigs", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    TriggerServerEvent("thehunt_items:serverAddFuelTwigs", tonumber(propId))
end)

-- Анимация подкидывания дров / веток
RegisterNetEvent("thehunt_items:clientPlayFuelAnim", function()
    local ped = PlayerPedId()
    local animDict = "script_common@shared_scenarios@generic@door_lock@unarmed"
    RequestAnimDict(animDict)
    local count = 0
    while not HasAnimDictLoaded(animDict) and count < 10 do
        Citizen.Wait(30)
        count = count + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "action", 3.0, -3.0, 700, 0, 0, false, false, false)
    end
end)

-- 4. Информация о костре (модальное окно в стиле системы дверей)
RegisterNetEvent("thehunt_items:clientCampfireInfo", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    TriggerServerEvent("thehunt_items:serverRequestCampfireInfo", tonumber(propId))
end)

RegisterNetEvent("thehunt_items:clientShowCampfireInfo", function(propId, remainingSeconds, coords)
    local mins = math.floor(remainingSeconds / 60)
    local secs = remainingSeconds % 60
    local timeStr = string.format("%d мин %02d сек", mins, secs)

    if exports['thehunt_interact'] and exports['thehunt_interact'].ShowInfoModal then
        exports['thehunt_interact']:ShowInfoModal({
            title = "Костёр",
            rows = {
                { label = "Состояние:", value = "Горит", valueClass = "status-active" },
                { label = "Осталось времени:", value = timeStr }
            },
            coords = coords and vector3(coords.x, coords.y, coords.z) or GetEntityCoords(PlayerPedId())
        })
    end
end)

-- 5. Готовить на костре (открывает thehunt_crafting с фильтром станции 'campfire')
RegisterNetEvent("thehunt_items:clientCampfireCook", function(targetInfo)
    if exports['thehunt_crafting'] and exports['thehunt_crafting'].OpenCrafting then
        exports['thehunt_crafting']:OpenCrafting('campfire')
    else
        TriggerEvent("thehunt_crafting:openStation", "campfire")
    end
end)

-- 6. Потушить костёр
RegisterNetEvent("thehunt_items:clientExtinguishCampfire", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    TriggerServerEvent("thehunt_items:serverExtinguishCampfire", tonumber(propId))
end)

-- Анимация тушения
RegisterNetEvent("thehunt_items:clientPlayExtinguishAnim", function()
    local ped = PlayerPedId()
    local animDict = "script_common@shared_scenarios@generic@door_lock@unarmed"
    RequestAnimDict(animDict)
    local count = 0
    while not HasAnimDictLoaded(animDict) and count < 10 do
        Citizen.Wait(30)
        count = count + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "action", 3.0, -3.0, 1000, 0, 0, false, false, false)
    end
end)

-- 7. Собрать древесный уголь
RegisterNetEvent("thehunt_items:clientGatherCharcoal", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    local ped = PlayerPedId()
    local animDict = "script_common@shared_scenarios@generic@door_lock@unarmed"
    RequestAnimDict(animDict)
    local count = 0
    while not HasAnimDictLoaded(animDict) and count < 10 do
        Citizen.Wait(30)
        count = count + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "action", 3.0, -3.0, 700, 0, 0, false, false, false)
        Citizen.Wait(350)
    end

    TriggerServerEvent("thehunt_items:serverGatherCharcoal", tonumber(propId))
end)
