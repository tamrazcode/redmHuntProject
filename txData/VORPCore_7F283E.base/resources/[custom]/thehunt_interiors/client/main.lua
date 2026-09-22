-- ==============================================================================
-- HUNT: Hard RP — The Interiors & World States Engine
-- Стабильная динамическая загрузка интерьеров и мировых состояний без крашей RAGE
-- ==============================================================================

local isInitialized = false
local loadedInteriors = {}

-- Безопасная активация наборов сущностей интерьера (Interior Entity Sets)
local function LoadInteriorData(data)
    if not data then return false end

    local interior = 0
    if data.id and data.id ~= 0 then
        interior = data.id
    elseif data.coords then
        pcall(function()
            interior = GetInteriorAtCoords(data.coords.x, data.coords.y, data.coords.z)
        end)
    end

    if interior and interior ~= 0 then
        local isValid = false
        pcall(function()
            isValid = IsValidInterior(interior)
        end)

        if isValid then
            if data.sets then
                for _, setName in ipairs(data.sets) do
                    pcall(function()
                        if not IsInteriorEntitySetActive(interior, setName) then
                            ActivateInteriorEntitySet(interior, setName, 0)
                        end
                    end)
                end
            end
            return true
        end
    end

    return false
end

-- ==============================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ КАРТЫ (IMAP / IPL) — Плавная загрузка без перегрузки движка
-- ==============================================================================

local function InitializeWorldStates()
    if isInitialized then return end
    isInitialized = true

    print("^3[HUNT INTERIORS] Запуск плавной инициализации состояний мира...^7")

    CreateThread(function()
        -- 1. Отключение заколоченных досок, лесов и мусора
        if Config.Imaps and Config.Imaps.Disable then
            local count = 0
            for _, hash in ipairs(Config.Imaps.Disable) do
                pcall(function()
                    RemoveImap(hash)
                end)
                count = count + 1
                if count % 25 == 0 then
                    Wait(1) -- Дробление на кадры, чтобы не блокировать streaming-пайплайн RAGE
                end
            end
        end

        Wait(100)

        -- 2. Включение достроенных зданий (1907), вывесок, освещения и лагерей
        if Config.Imaps and Config.Imaps.Enable then
            local count = 0
            for _, hash in ipairs(Config.Imaps.Enable) do
                pcall(function()
                    RequestImap(hash)
                end)
                count = count + 1
                if count % 25 == 0 then
                    Wait(1)
                end
            end
        end

        print("^2[HUNT INTERIORS] Все IMAP и мировые состояния успешно применены!^7")
    end)
end

-- ==============================================================================
-- 2. ДИНАМИЧЕСКАЯ ЗАГРУЗКА ИНТЕРЬЕРОВ ПРИ ПРИБЛИЖЕНИИ ИЛИ ВХОДЕ
-- ==============================================================================

CreateThread(function()
    Wait(3000)
    InitializeWorldStates()

    while true do
        local playerPed = PlayerPedId()
        if DoesEntityExist(playerPed) then
            local pCoords = GetEntityCoords(playerPed)
            local currentInterior = 0
            pcall(function()
                currentInterior = GetInteriorFromEntity(playerPed)
            end)

            -- 1. Проверка стандартных интерьеров в радиусе 100 метров
            if Config.Interiors then
                for _, data in ipairs(Config.Interiors) do
                    local shouldLoad = false
                    if data.coords and #(pCoords - data.coords) < 100.0 then
                        shouldLoad = true
                    elseif currentInterior ~= 0 and (data.id == currentInterior or (data.interior and data.interior == currentInterior)) then
                        shouldLoad = true
                    end

                    if shouldLoad then
                        LoadInteriorData(data)
                    end
                end
            end

            -- 2. Проверка хижин самогонщиков
            if Config.MoonshineInteriors then
                for _, shack in ipairs(Config.MoonshineInteriors) do
                    local shouldLoad = false
                    if shack.coords and #(pCoords - shack.coords) < 100.0 then
                        shouldLoad = true
                    elseif currentInterior ~= 0 and shack.interior == currentInterior then
                        shouldLoad = true
                    end

                    if shouldLoad then
                        LoadInteriorData(shack)
                    end
                end
            end
        end

        Wait(1500)
    end
end)

-- Синхронизация при спавне персонажа
RegisterNetEvent("thehunt:character:selected", function()
    Wait(2000)
    InitializeWorldStates()
end)

AddEventHandler("thehunt:player:spawned", function()
    Wait(2000)
    InitializeWorldStates()
end)

-- ==============================================================================
-- 3. КОМАНДА ДЛЯ ТЕСТИРОВАНИЯ И ОТЛАДКИ ИНТЕРЬЕРОВ (/interior)
-- ==============================================================================

RegisterCommand("interior", function()
    local ped = PlayerPedId()
    local interior = 0
    pcall(function() interior = GetInteriorFromEntity(ped) end)
    local coords = GetEntityCoords(ped)
    local atCoords = 0
    pcall(function() atCoords = GetInteriorAtCoords(coords.x, coords.y, coords.z) end)
    local isValid = (interior ~= 0 and IsValidInterior(interior)) or (atCoords ~= 0 and IsValidInterior(atCoords))

    print(string.format("^3[HUNT INTERIORS DEBUG]^7 Interior: %s | AtCoords: %s | IsValid: %s | Coords: %s", tostring(interior), tostring(atCoords), tostring(isValid), tostring(coords)))
    TriggerEvent("thehunt_status:notify", "ИНТЕРЬЕР", string.format("ID: %s (У координат: %s) — Действителен: %s", tostring(interior), tostring(atCoords), isValid and "ДА" or "НЕТ"), isValid and "info" or "warning")
end, false)
