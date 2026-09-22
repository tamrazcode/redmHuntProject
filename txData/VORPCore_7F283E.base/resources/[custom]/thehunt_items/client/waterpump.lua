-- =================================================================
-- HUNT: Hard RP — Water Pump System | Client Controller
-- =================================================================

local isBusy = false

local waterPumpModels = {
    "p_waterpump01x",
    "p_wellpumpnbx01x",
    joaat("p_waterpump01x"),
    joaat("p_wellpumpnbx01x"),
    GetHashKey("p_waterpump01x"),
    GetHashKey("p_wellpumpnbx01x"),
    -40350080,
    4254617216,
    0xFD984E80,
    -717759843,
    3577207453,
    0xD537DA9D
}

-- Регистрация взаимодействия с колонками через thehunt_interact
local function RegisterWaterPumpInteractions()
    if exports.thehunt_interact then
        exports.thehunt_interact:AddTargetModel(waterPumpModels, {
            {
                id = "waterpump_fill_bottle",
                label = "Наполнить бутылку",
                icon = "bottle",
                event = "thehunt_items:clientFillBottlePump",
                action = function(target)
                    TriggerEvent("thehunt_items:clientFillBottlePump", target)
                end
            },
            {
                id = "waterpump_fill_flask",
                label = "Наполнить флягу / бурдюк",
                icon = "flask",
                event = "thehunt_items:clientFillFlaskWaterskinPump",
                action = function(target)
                    TriggerEvent("thehunt_items:clientFillFlaskWaterskinPump", target)
                end
            },
            {
                id = "waterpump_wash",
                label = "Умыться",
                icon = "wash",
                event = "thehunt_items:clientWashPump",
                action = function(target)
                    TriggerEvent("thehunt_items:clientWashPump", target)
                end
            }
        }, 1.8)
    end
end

RegisterNetEvent("thehunt_interact:ready", function()
    RegisterWaterPumpInteractions()
end)

RegisterNetEvent("thehunt:character:selected", function()
    Citizen.Wait(1000)
    RegisterWaterPumpInteractions()
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Citizen.Wait(500)
    RegisterWaterPumpInteractions()
end)

-- Keepalive для гарантии регистрации при перезапусках ресурсов
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2500)
        RegisterWaterPumpInteractions()
    end
end)

-- =================================================================
-- 1. НАПОЛНИТЬ БУТЫЛКУ
-- =================================================================

RegisterNetEvent("thehunt_items:clientFillBottlePump", function(targetInfo)
    local ped = PlayerPedId()
    if isBusy then
        TriggerEvent("thehunt_status:notify", "Колонка", "Вы уже заняты действием", "warning")
        return
    end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) then
        TriggerEvent("thehunt_status:notify", "Колонка", "Сначала спешьтесь", "warning")
        return
    end

    TriggerServerEvent("thehunt_items:serverCheckFillBottle")
end)

RegisterNetEvent("thehunt_items:clientStartFillBottle", function()
    local ped = PlayerPedId()
    if isBusy then return end
    isBusy = true

    local scenarioHash = GetHashKey("WORLD_HUMAN_CROUCH_INSPECT")
    TriggerEvent('thehunt_animations:client:setProtectedAction', true, 'waterpump_action', 8000)
    TaskStartScenarioInPlace(ped, scenarioHash, -1, true, false, false, false)

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 7000 do
            Citizen.Wait(100)
            if IsEntityDead(PlayerPedId()) then
                isBusy = false
                TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'waterpump_action')
                return
            end
        end

        local currentPed = PlayerPedId()
        ClearPedTasks(currentPed)
        TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'waterpump_action')
        Citizen.Wait(600)
        isBusy = false
        TriggerServerEvent("thehunt_items:serverFinishFillBottle")
    end)
end)

-- =================================================================
-- 2. НАПОЛНИТЬ ФЛЯГУ / БУРДЮК
-- =================================================================

RegisterNetEvent("thehunt_items:clientFillFlaskWaterskinPump", function(targetInfo)
    local ped = PlayerPedId()
    if isBusy then
        TriggerEvent("thehunt_status:notify", "Колонка", "Вы уже заняты действием", "warning")
        return
    end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) then
        TriggerEvent("thehunt_status:notify", "Колонка", "Сначала спешьтесь", "warning")
        return
    end

    TriggerServerEvent("thehunt_items:serverCheckFillFlaskWaterskin")
end)

RegisterNetEvent("thehunt_items:clientStartFillFlaskWaterskin", function()
    local ped = PlayerPedId()
    if isBusy then return end
    isBusy = true

    local scenarioHash = GetHashKey("WORLD_HUMAN_CROUCH_INSPECT")
    TriggerEvent('thehunt_animations:client:setProtectedAction', true, 'waterpump_action', 8000)
    TaskStartScenarioInPlace(ped, scenarioHash, -1, true, false, false, false)

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 7000 do
            Citizen.Wait(100)
            if IsEntityDead(PlayerPedId()) then
                isBusy = false
                TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'waterpump_action')
                return
            end
        end

        local currentPed = PlayerPedId()
        ClearPedTasks(currentPed)
        TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'waterpump_action')
        Citizen.Wait(600)
        isBusy = false
        TriggerServerEvent("thehunt_items:serverFinishFillFlaskWaterskin")
    end)
end)

-- =================================================================
-- 3. УМЫТЬСЯ
-- =================================================================

RegisterNetEvent("thehunt_items:clientWashPump", function(targetInfo)
    local ped = PlayerPedId()
    if isBusy then
        TriggerEvent("thehunt_status:notify", "Колонка", "Вы уже заняты действием", "warning")
        return
    end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) then
        TriggerEvent("thehunt_status:notify", "Колонка", "Сначала спешьтесь", "warning")
        return
    end
    isBusy = true

    TriggerEvent('thehunt_animations:client:setProtectedAction', true, 'waterpump_wash', 10500)

    -- Запуск анимации "Умыться из ведра" из thehunt_animations
    local started = false
    if exports.thehunt_animations and exports.thehunt_animations.PlayAnimation then
        started = exports.thehunt_animations:PlayAnimation('Умыться из ведра')
    end
    if not started then
        TaskStartScenarioInPlace(ped, GetHashKey("WORLD_HUMAN_WASH_FACE_BUCKET_GROUND"), -1, true, false, false, false)
    end

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 8000 do
            Citizen.Wait(100)
            if IsEntityDead(PlayerPedId()) then
                isBusy = false
                TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'waterpump_wash')
                return
            end
        end

        -- 1. Сначала уведомление, что успешно умылись и освежились
        TriggerEvent("thehunt_status:notify", "Колонка", "Вы успешно умылись и освежились", "success")

        -- 2. Анимация отменяется плавно (ClearPedTasks запускает естественный выход)
        if exports.thehunt_animations and exports.thehunt_animations.StopAnimation then
            exports.thehunt_animations:StopAnimation()
        end
        ClearPedTasks(PlayerPedId())
        TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'waterpump_wash')

        -- Плавная пауза на время выхода из сценария перед смывом грязи
        Citizen.Wait(1200)

        -- 3. Смываем исключительно грязь и пыль с персонажа (не трогая раны и повреждения)
        local myPed = PlayerPedId()
        ClearPedEnvDirt(myPed)
        Citizen.InvokeNative(0xB6545CF858EECD5B, myPed) -- CLEAR_PED_ENV_DIRT (смывает окружающую грязь и пыль)
        Citizen.InvokeNative(0xE3144B932DFDFF65, myPed, 0.0, -1, 1, 1) -- _SET_PED_DIRT_CLEANED (сбрасывает уровень пыли и грязи на 0)
        Citizen.InvokeNative(0xD729577D7D9A4C0B, myPed) -- _CLEAR_PED_WETNESS

        isBusy = false
    end)
end)
