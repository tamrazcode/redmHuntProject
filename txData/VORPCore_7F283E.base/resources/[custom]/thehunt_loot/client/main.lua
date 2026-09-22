-- =================================================================
-- HUNT: Hard RP — The Corruption | Main Client Initializer
-- =================================================================

local isCharacterReady = false
local lastRequestTime = 0

local function RequestInitialLootData()
    local now = GetGameTimer()
    if (now - lastRequestTime) < 1500 then return end
    lastRequestTime = now
    TriggerServerEvent("thehunt_loot:requestInitialData")
end

-- Ожидание выбора персонажа VORP
RegisterNetEvent("thehunt:character:selected", function()
    isCharacterReady = true
    RequestInitialLootData()
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Citizen.Wait(300)
    isCharacterReady = true
    RequestInitialLootData()
    Citizen.SetTimeout(1800, function()
        lastRequestTime = 0
        RequestInitialLootData()
    end)
end)

Citizen.CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do
        Citizen.Wait(200)
    end
    isCharacterReady = true
    RequestInitialLootData()
end)

-- =================================================================
-- ПРИЕМ ДАННЫХ ЛУТА ОТ СЕРВЕРА
-- =================================================================

RegisterNetEvent("thehunt_loot:receiveActiveSlots", function(slots)
    if LootStreamer then
        LootStreamer.ReceiveAllSlots(slots or {})
    end
end)

RegisterNetEvent("thehunt_loot:onSlotCreated", function(slotData)
    if LootStreamer then
        LootStreamer.AddSlot(slotData)
    end
end)

RegisterNetEvent("thehunt_loot:onSlotRemoved", function(slotId)
    if LootStreamer then
        LootStreamer.RemoveSlot(slotId)
    end
end)

RegisterNetEvent("thehunt_loot:onSlotUpdated", function(slotId, newCount)
    if LootStreamer then
        LootStreamer.UpdateSlotCount(slotId, newCount)
    end
end)
