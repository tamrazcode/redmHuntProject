-- =================================================================
-- HUNT: Hard RP — The Corruption | World Cleaner & Environment Controller
-- Удаление NPC-людей, повозок и брошенных осёдланных/привязанных NPC-лошадей
-- ПОЛНОСТЬЮ СОХРАНЯЕТ: диких животных, диких лошадей, птиц, хищников, оленей, рыб, аллигаторов, лодки
-- =================================================================

local emptyWorldEnabled = true
-- The character selector deliberately uses a local, non-networked preview
-- ped.  The cleaner operates on the local game pool (routing buckets do not
-- filter it), therefore it must be paused only for this client while that UI
-- is open.  Normal world cleaning remains untouched at every other time.
local characterSelectionMode = false

RegisterNetEvent("thehunt_core:worldCleaner:setCharacterSelectionMode", function(enabled)
    characterSelectionMode = enabled == true
end)

-- The event flag is only a hint: if the character resource is reloaded or a
-- selection transition is interrupted, the flag can outlive the actual UI.
-- Read the real local state as well, so a stale flag cannot disable NPC
-- cleanup for the rest of the session, while an actually open selector stays
-- protected from cleanup.
local function IsCharacterSelectionModeActive()
    local localSelectionActive = false

    pcall(function()
        local state = LocalPlayer and LocalPlayer.state
        if state and (state.isSelectingChar == true or state.isCreatingChar == true) then
            localSelectionActive = true
        end
    end)

    if localSelectionActive then return true end

    if GetResourceState('thehunt_character') == 'started' then
        local ok, menuOpen = pcall(function()
            return exports['thehunt_character']:isCharacterMenuOpen()
        end)
        if ok and menuOpen == true then return true end
    end

    -- Keep the event flag only while it agrees with a real selection UI.  This
    -- also recovers automatically after a missed cleanup event or resource
    -- restart without touching normal gameplay.
    if characterSelectionMode then
        characterSelectionMode = false
    end

    return false
end

-- Модели лодок, которые НЕ нужно удалять
local BoatModels = {
    [`rowboat`]         = true,
    [`rowboatSwamp`]    = true,
    [`rowboatSwamp02`]  = true,
    [`canoe`]           = true,
    [`canoeTreeTrunk`]  = true,
    [`boatsteam02x`]    = true,
    [`keelboat`]        = true,
    [`skiff`]           = true,
    [`pirogue`]         = true,
    [`pirogue2`]        = true,
    [`rcBoat`]          = true,
    [`smuggler02`]      = true,
}

-- Проверка: принадлежит ли лошадь или транспорт какому-либо игроку
local function BuildProtectedPlayerEntities()
    local protected = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local playerPed = GetPlayerPed(playerId)
        if DoesEntityExist(playerPed) then
            protected[playerPed] = true

            local mount = GetMount(playerPed)
            if mount and mount ~= 0 and DoesEntityExist(mount) then
                protected[mount] = true
            end

            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                protected[vehicle] = true
            end

            local lastVehicle = GetVehiclePedIsIn(playerPed, true)
            if lastVehicle and lastVehicle ~= 0 and DoesEntityExist(lastVehicle) then
                protected[lastVehicle] = true
            end
        end
    end

    return protected
end

local function IsProtectedPlayerEntity(entity, protectedEntities)
    return entity ~= nil and entity ~= 0 and protectedEntities[entity] == true
end

-- Проверка: является ли сущность животным (не человек)
local function IsAnimalEntity(ped)
    if not DoesEntityExist(ped) then return false end
    if not IsPedHuman(ped) then
        return true
    end
    local isAnimal = false
    pcall(function()
        if Citizen.InvokeNative(0x397C8348, ped) then -- _IS_ANIMAL
            isAnimal = true
        end
    end)
    return isAnimal
end

-- Проверка: является ли лошадь ТОЛЬКО осёдланной/привязанной NPC-лошадью (дикие лошади сохраняются!)
local function IsNpcSaddledOrDomesticHorse(ped, protectedEntities)
    if not DoesEntityExist(ped) then return false end
    if IsPedAPlayer(ped) then return false end
    if IsProtectedPlayerEntity(ped, protectedEntities) then return false end

    local model = GetEntityModel(ped)
    local isHorse = false
    pcall(function()
        if Citizen.InvokeNative(0x7704F110, model) then -- _IS_MODEL_A_HORSE
            isHorse = true
        end
    end)
    if not isHorse then
        if IsPedModel(ped, `A_C_Horse_Mule_01`) or IsPedModel(ped, `A_C_Donkey_01`) then
            isHorse = true
        end
    end

    -- Если это не лошадь (олень, волк, аллигатор, птица, медведь и т.д.) — не трогаем!
    if not isHorse then return false end

    -- Проверяем СТРОГО наличие седла или привязи у NPC-лошади
    local hasSaddleOrHitch = false
    pcall(function()
        -- _IS_HORSE_SADDLED (проверка наличия седла)
        if Citizen.InvokeNative(0x61914209DAF5DE30, ped) then
            hasSaddleOrHitch = true
        end
        -- _GET_HORSE_SADDLE (получение энтити седла)
        local saddle = Citizen.InvokeNative(0x9068095C, ped)
        if saddle and saddle ~= 0 and DoesEntityExist(saddle) then
            hasSaddleOrHitch = true
        end
        -- _IS_PED_HITCHED (привязана ли лошадь к столбу)
        if Citizen.InvokeNative(0x2963B5C454923842, ped) or Citizen.InvokeNative(0xB8B6430EAD2D2437, ped) then
            hasSaddleOrHitch = true
        end
    end)

    -- Если есть седло или привязь — это брошенная NPC-лошадь
    -- Если седла НЕТ — это дикая лошадь, её оставляем в живых!
    return hasSaddleOrHitch
end

-- Проверка: является ли транспорт лодкой
local function IsBoat(vehicle)
    local model = GetEntityModel(vehicle)
    if BoatModels[model] == true then return true end
    local isBoatNative = false
    pcall(function()
        if IsThisModelABoat(model) then isBoatNative = true end
    end)
    return isBoatNative
end

-- Экспорт и события для переключения из админ-панели
RegisterNetEvent("thehunt_admin:syncEmptyWorld", function(state)
    if state ~= nil then
        emptyWorldEnabled = (state == true)
    end
end)

RegisterNetEvent("thehunt_admin:togglePopulation", function(enableEmpty)
    if enableEmpty ~= nil then
        emptyWorldEnabled = enableEmpty
    else
        emptyWorldEnabled = not emptyWorldEnabled
    end
    print(string.format("^3[HUNT WORLD] Режим пустого мира: %s^7", emptyWorldEnabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"))
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    TriggerServerEvent("thehunt_admin:requestEmptyWorldState")
end)

exports('togglePopulation', function(state)
    emptyWorldEnabled = (state == true)
end)

exports('isPopulationDisabled', function()
    return emptyWorldEnabled
end)

-- Список городских аудио-зон для полного отключения шума цивилизации
local MutedTownAudioZones = {
    "VALENTINE_AMBIENCE",
    "SAINTDENIS_TOWN_AMBIENCE",
    "RHODES_AMBIENCE",
    "BLACKWATER_AMBIENCE",
    "STRAWBERRY_AMBIENCE",
    "ANNESBURG_AMBIENCE",
    "VAN_HORN_AMBIENCE",
    "ARMADILLO_AMBIENCE",
    "TUMBLEWEED_AMBIENCE",
    "EMERALD_RANCH_AMBIENCE",
    "CALIGA_HALL_AMBIENCE",
    "BRAITHWAITE_MANOR_AMBIENCE",
    "LAGRAS_AMBIENCE",
    "BUTCHER_CREEK_AMBIENCE",
    "COLTER_AMBIENCE",
    "WAPITI_AMBIENCE",
    "CORNWALL_KEROSENE_TAR_AMBIENCE",
    "MANZANITA_POST_AMBIENCE",
    "PRONGHORN_RANCH_AMBIENCE",
    "MACFARLANES_RANCH_AMBIENCE",
    "THIEVES_LANDING_AMBIENCE"
}

-- Инициализация глушителя городских звуков
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    pcall(function()
        SetAmbientZoneListState("AZL_TOWNS", false, true)
        SetAmbientZoneListState("AZL_SETTLEMENTS", false, true)
        SetAmbientZoneListState("AZL_CAMPS", false, true)

        for _, zoneName in ipairs(MutedTownAudioZones) do
            SetAmbientZoneStatePersistent(zoneName, false, true)
        end

        Citizen.InvokeNative(0x9D741274D73C5479, "TRAFFIC_TOWN")
        Citizen.InvokeNative(0x9D741274D73C5479, "TOWN_CROWD")
    end)
    print("^2[HUNT ENVIRONMENT] Городские звуки успешно заглушены (дикая природа активна).^7")
end)

-- ГЛАВНЫЙ ПОТОК: АППАРАТНОЕ ВЫРЕЗАНИЕ ОРЛИНОГО ЗРЕНИЯ И ПОДАВЛЕНИЕ ТОЛЬКО ЧЕЛОВЕЧЕСКОГО ТРАФИКА
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerId = PlayerId()

        -- 1. Полный аппаратный запрет Орлиного зрения и Меткого глаза
        pcall(function()
            Citizen.InvokeNative(0xA63FCAD3A6FEC6D2, playerId, false)
            Citizen.InvokeNative(0xA63FCB3B895D1A07, playerId, false)
            Citizen.InvokeNative(0x6275203D270CE3D2, false)
            Citizen.InvokeNative(0x56E05FE5, playerId, false)
        end)

        -- 2. Очиститель мира (отключает только людей и повозки, дикая природа и лодки остаются):
        if emptyWorldEnabled then
            pcall(function()
                -- Отключаем ТОЛЬКО людей и повозки (НЕ трогая общие Ped-нативы, блокирующие животных):
                SetAmbientHumanDensityMultiplierThisFrame(0.0)
                SetScenarioHumanDensityMultiplierThisFrame(0.0)
                SetVehicleDensityMultiplierThisFrame(0.0)
                SetParkedVehicleDensityMultiplierThisFrame(0.0)
                SetRandomVehicleDensityMultiplierThisFrame(0.0)
                SetAmbientVehicleRange(0.0)
                SetRandomTrains(false)

                -- Лодки и каноэ РАЗРЕШЕНЫ:
                SetRandomBoats(true)

                -- ВСЯ ДИКАЯ ПРИРОДА (животные, птицы, хищники, дикие лошади, аллигаторы, рыбы) ВКЛЮЧЕНА НА 100%:
                SetScenarioAnimalDensityMultiplierThisFrame(1.0, 1.0)
                SetAmbientAnimalDensityMultiplierThisFrame(1.0)
            end)
        end
    end
end)

-- Фоновая зачистка NPC (людей, всадников, повозок, осёдланных лошадей) без задержек (100мс)
local CLEANER_SCAN_IDLE_MS = 400
local CLEANER_SCAN_NORMAL_MS = 250
local CLEANER_SCAN_BUSY_MS = 100
local CLEANER_BUSY_ENTITY_THRESHOLD = 150

Citizen.CreateThread(function()
    local nextScanDelay = CLEANER_SCAN_NORMAL_MS

    while true do
        if emptyWorldEnabled and not IsCharacterSelectionModeActive() then
            Citizen.Wait(nextScanDelay)
            local playerPed = PlayerPedId()

            local animPreviewPed = nil
            if GetResourceState('thehunt_animations') == 'started' then
                pcall(function()
                    animPreviewPed = exports['thehunt_animations']:GetPreviewPed()
                end)
            end

            local worldPreviewPed = nil
            if GetResourceState('thehunt_worldinteractions') == 'started' then
                pcall(function()
                    worldPreviewPed = exports['thehunt_worldinteractions']:GetPreviewPed()
                end)
            end

            -- 1. Проверяем всех педов через Game Pool
            local peds = GetGamePool('CPed')
            local vehicles = GetGamePool('CVehicle')
            local protectedEntities = BuildProtectedPlayerEntities()
            local entityCount = #peds + #vehicles

            if entityCount >= CLEANER_BUSY_ENTITY_THRESHOLD then
                nextScanDelay = CLEANER_SCAN_BUSY_MS
            elseif entityCount <= 50 then
                nextScanDelay = CLEANER_SCAN_IDLE_MS
            else
                nextScanDelay = CLEANER_SCAN_NORMAL_MS
            end
            for _, ped in ipairs(peds) do
                if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
                    local isGhost = (animPreviewPed and ped == animPreviewPed) or (worldPreviewPed and ped == worldPreviewPed) or (Entity(ped).state and (Entity(ped).state.isGhostPreview or Entity(ped).state.isProtected))
                    if not isGhost then
                        if not IsAnimalEntity(ped) then
                            -- NPC Человек: удаляем
                            if not IsProtectedPlayerEntity(ped, protectedEntities) then
                                local mount = GetMount(ped)
                                if mount ~= 0 and not IsProtectedPlayerEntity(mount, protectedEntities) then
                                    SetEntityAsMissionEntity(mount, true, true)
                                    SetEntityCoords(mount, 0.0, 0.0, -2000.0, false, false, false, false)
                                    DeleteEntity(mount)
                                end
                                SetEntityAsMissionEntity(ped, true, true)
                                SetEntityCoords(ped, 0.0, 0.0, -2000.0, false, false, false, false)
                                DeleteEntity(ped)
                            end
                        else
                            -- Животное: удаляем ТОЛЬКО если это осёдланная / привязанная NPC-лошадь
                            -- Дикие животные, аллигаторы, птицы, дикие табуны лошадей НЕ трогаются
                            if IsNpcSaddledOrDomesticHorse(ped, protectedEntities) then
                                SetEntityAsMissionEntity(ped, true, true)
                                SetEntityCoords(ped, 0.0, 0.0, -2000.0, false, false, false, false)
                                DeleteEntity(ped)
                            end
                        end
                    end
                end
            end

            -- 2. Проверяем повозки через Game Pool
            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) then
                    local shouldDelete = true

                    -- Лодки и каноэ НЕ трогаем
                    if IsBoat(veh) then
                        shouldDelete = false
                    end

                    -- Транспорт игроков не трогаем
                    if shouldDelete and IsProtectedPlayerEntity(veh, protectedEntities) then
                        shouldDelete = false
                    end

                    -- Проверяем наличие живого игрока внутри
                    if shouldDelete then
                        for seat = -1, 10 do
                            local occupant = GetPedInVehicleSeat(veh, seat)
                            if occupant ~= 0 and IsPedAPlayer(occupant) then
                                shouldDelete = false
                                break
                            end
                        end
                    end

                    if shouldDelete then
                        -- Удаляем упряжных лошадей этой NPC-повозки (до 6 лошадей)
                        for horseIdx = 0, 5 do
                            local draftHorse = nil
                            pcall(function()
                                draftHorse = Citizen.InvokeNative(0xA70C6D2766867320, veh, horseIdx)
                            end)
                            if draftHorse and draftHorse ~= 0 and DoesEntityExist(draftHorse) and not IsProtectedPlayerEntity(draftHorse, protectedEntities) then
                                SetEntityAsMissionEntity(draftHorse, true, true)
                                SetEntityCoords(draftHorse, 0.0, 0.0, -2000.0, false, false, false, false)
                                DeleteEntity(draftHorse)
                            end
                        end
                        SetEntityAsMissionEntity(veh, true, true)
                        SetEntityCoords(veh, 0.0, 0.0, -2000.0, false, false, false, false)
                        DeleteEntity(veh)
                    end
                end
            end
        else
            nextScanDelay = CLEANER_SCAN_NORMAL_MS
            Citizen.Wait(1000)
        end
    end
end)
