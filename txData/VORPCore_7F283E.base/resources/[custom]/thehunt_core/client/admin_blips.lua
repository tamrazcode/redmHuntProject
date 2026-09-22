-- =================================================================
-- HUNT: Hard RP — The Corruption | Клиентские админские метки (/adminblips)
-- =================================================================

local adminBlipsActive = false
local playerBlips = {}

local function ToggleBlips()
    adminBlipsActive = not adminBlipsActive
    TriggerEvent("thehunt_admin:adminBlipsStateChanged", adminBlipsActive)

    if adminBlipsActive then
        print("^2[HUNT ADMIN] Админские метки игроков: ВКЛЮЧЕНЫ^7")
    else
        -- Удаляем все метки при выключении
        for id, blip in pairs(playerBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        playerBlips = {}
        print("^1[HUNT ADMIN] Админские метки игроков: ВЫКЛЮЧЕНЫ^7")
    end
    return adminBlipsActive
end

RegisterNetEvent("thehunt_admin:toggleBlips", function()
    ToggleBlips()
end)

exports('isAdminBlipsActive', function()
    return adminBlipsActive
end)

exports('toggleBlips', function()
    return ToggleBlips()
end)

-- Прием данных игроков от сервера и обновление меток
local function UpdatePlayerBlips(playersList)
    if not adminBlipsActive then return end

    local myServerId = GetPlayerServerId(PlayerId())
    local activeBlips = {}

    for _, p in ipairs(playersList) do
        -- Не создаем метку на самого себя
        if p.id ~= myServerId then
            local blip = playerBlips[p.id]

            if not blip or not DoesBlipExist(blip) then
                -- Создаем новую метку (хэш стиля метки игрока)
                blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, p.coords.x, p.coords.y, p.coords.z)
                SetBlipScale(blip, 0.8)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, p.name) -- Устанавливаем имя метки
                playerBlips[p.id] = blip
            else
                -- Обновляем координаты существующей метки
                SetBlipCoords(blip, p.coords.x, p.coords.y, p.coords.z)
            end
            activeBlips[p.id] = true
        end
    end

    for playerId, blip in pairs(playerBlips) do
        if not activeBlips[playerId] then
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
            playerBlips[playerId] = nil
        end
    end
end

RegisterNetEvent("thehunt_admin:syncPlayersData", UpdatePlayerBlips)
RegisterNetEvent("thehunt_admin:receivePlayersData", UpdatePlayerBlips)

-- Постоянный цикл опроса позиций (каждые 800мс)
