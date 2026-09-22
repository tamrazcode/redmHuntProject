-- =================================================================
-- HUNT: Hard RP — Doors & Housing | Client Module
-- =================================================================

local isCharacterReady = false
local LocalHouses = {}
local LocalDoors = {}
local RegisteredDoorHashes = {}
local ActiveRegisteredZones = {}
local ActiveRegisteredEntities = {}
local myCharId = nil

local isInfoModalOpen = false
local infoModalCoords = nil
local isMMBPressed = false

local UpdateInteractZones = nil

-- Ожидание выбора персонажа VORP
RegisterNetEvent("thehunt:character:selected", function(charData)
    isCharacterReady = true
    if type(charData) == "table" and (charData.charIdentifier or charData.charid) then
        myCharId = tonumber(charData.charIdentifier or charData.charid)
    elseif type(charData) == "number" then
        myCharId = charData
    end
    TriggerServerEvent("thehunt_doors:requestSync")
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Wait(500)
    isCharacterReady = true
    TriggerServerEvent("thehunt_doors:requestSync")
end)

Citizen.CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do
        Citizen.Wait(200)
    end
    isCharacterReady = true
    TriggerServerEvent("thehunt_doors:requestSync")
end)

RegisterNetEvent("thehunt_doors:setMyCharId", function(cId)
    if cId then
        myCharId = tonumber(cId)
        isCharacterReady = true
        if UpdateInteractZones then
            UpdateInteractZones()
        end
    end
end)

RegisterNetEvent("thehunt_interact:ready", function()
    if UpdateInteractZones then
        UpdateInteractZones()
    end
end)

-- Поиск всех связанных энтити двери/створок по координатам (строго по хэшу модели двери)
local function GetAllDoorEntitiesAtCoords(x, y, z, modelHash)
    local targetPos = vector3(x, y, z)
    local mHash = tonumber(modelHash) or 0
    local found = {}
    local seen = {}

    -- 1. Если хэш модели известен: ищем только объекты с этой моделью!
    if mHash ~= 0 then
        -- Сканирование пула CObject (находит все створки ворот и двери)
        local objects = GetGamePool('CObject')
        for _, obj in ipairs(objects) do
            if DoesEntityExist(obj) and not seen[obj] then
                local objModel = GetEntityModel(obj)
                if objModel == mHash or (objModel % 0x100000000) == (mHash % 0x100000000) then
                    local dist = #(targetPos - GetEntityCoords(obj))
                    if dist < 2.8 then
                        table.insert(found, obj)
                        seen[obj] = true
                    end
                end
            end
        end

        -- Нативный поиск по модели (если в пуле не найден)
        if #found == 0 then
            local nativeObj = GetClosestObjectOfType(x, y, z, 2.5, mHash, false, false, false)
            if nativeObj and nativeObj ~= 0 and DoesEntityExist(nativeObj) then
                table.insert(found, nativeObj)
                seen[nativeObj] = true
            end
        end
    else
        -- 2. Если хэш модели 0: ищем объект строго в пределах 0.8м (только сама дверь в проёме)
        local objects = GetGamePool('CObject')
        local closestEnt = nil
        local closestDist = 0.8
        for _, obj in ipairs(objects) do
            if DoesEntityExist(obj) then
                local dist = #(targetPos - GetEntityCoords(obj))
                if dist < closestDist then
                    closestDist = dist
                    closestEnt = obj
                end
            end
        end
        if closestEnt then
            table.insert(found, closestEnt)
        end
    end

    return found
end

local function GetDoorEntityAtCoords(x, y, z, modelHash)
    local list = GetAllDoorEntitiesAtCoords(x, y, z, modelHash)
    return list[1]
end

-- Инициализация блокировки паразитных анимаций запертой двери у персонажа
Citizen.CreateThread(function()
    pcall(function()
        SetScenarioTypeEnabled("WORLD_HUMAN_DOOR_LOCKED", false)
        SetScenarioTypeEnabled("PROP_HUMAN_DOOR_LOCKED", false)
        SetScenarioTypeEnabled("WORLD_HUMAN_DOOR_KNOCK", false)
    end)
    while true do
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            Citizen.InvokeNative(0x1921DA32D0654D92, ped, false) -- SET_PED_CAN_PLAY_DOOR_RATTLE_ANIM
        end
        Citizen.Wait(2000)
    end
end)

-- Получение реального хэша двери из движка RDR3
local function GetNativeDoorHashAtCoords(x, y, z, modelHash)
    local m = tonumber(modelHash) or 0
    local h = nil
    pcall(function()
        h = Citizen.InvokeNative(0xC153E424911394D9, x + 0.0, y + 0.0, z + 0.0, m)
    end)
    if not h or h == 0 then
        pcall(function()
            h = Citizen.InvokeNative(0xC153E424911394D9, x + 0.0, y + 0.0, z + 0.0, 0)
        end)
    end
    return (h and h ~= 0) and h or nil
end

-- Применение физики к двери
local function ApplyDoorPhysics(door)
    local modelHash = tonumber(door.model_hash) or 0
    local nativeHash = GetNativeDoorHashAtCoords(door.x, door.y, door.z, modelHash)
    local rawHash = tonumber(door.door_hash) or joaat(tostring(door.door_hash))
    local doorHash = nativeHash or rawHash

    -- 1. Надежная регистрация в нативной системе DoorSystem RDR2
    local hashesToRegister = { doorHash }
    if nativeHash and nativeHash ~= 0 and nativeHash ~= doorHash then
        table.insert(hashesToRegister, nativeHash)
    end
    if rawHash and rawHash ~= 0 and rawHash ~= doorHash and rawHash ~= nativeHash then
        table.insert(hashesToRegister, rawHash)
    end

    for _, dHash in ipairs(hashesToRegister) do
        if not RegisteredDoorHashes[dHash] or not IsDoorRegisteredWithSystem(dHash) then
            pcall(function()
                AddDoorToSystemNew(dHash, true, true, false, 0, 0, false)
            end)
            pcall(function()
                Citizen.InvokeNative(0x6F8838D03D1DC226, dHash, modelHash, door.x + 0.0, door.y + 0.0, door.z + 0.0, false, true, false)
            end)
            pcall(function()
                SetDoorNetworked(dHash)
            end)
            RegisteredDoorHashes[dHash] = true
        end
    end

    local doorEntities = GetAllDoorEntitiesAtCoords(door.x, door.y, door.z, modelHash)

    -- 2. Применение состояния замка
    if door.state == 1 then
        -- Дверь заперта: принудительно доводим створку в проём и блокируем
        for _, dHash in ipairs(hashesToRegister) do
            DoorSystemForceShut(dHash, true)
            DoorSystemSetOpenRatio(dHash, 0.0, true)
            DoorSystemSetDoorState(dHash, 1)
            DoorSystemSetAutomaticDistance(dHash, 0.0)
            DoorSystemSetAutomaticRate(dHash, 0.0)
        end

        for _, ent in ipairs(doorEntities) do
            if DoesEntityExist(ent) then
                SetEntityAsMissionEntity(ent, true, true)
                SetEntityCanBeDamaged(ent, false)
                FreezeEntityPosition(ent, false)
                SetEntityCoords(ent, door.x, door.y, door.z, false, false, false, false)
                if door.heading then
                    SetEntityHeading(ent, tonumber(door.heading) + 0.0)
                    SetEntityRotation(ent, 0.0, 0.0, tonumber(door.heading) + 0.0, 2, true)
                end
                SetEntityVelocity(ent, 0.0, 0.0, 0.0)
                FreezeEntityPosition(ent, true)
                SetEntityCollision(ent, true, true)
            end
        end
    else
        -- Дверь отперта / полностью физична: снимаем замок и заморозку
        for _, dHash in ipairs(hashesToRegister) do
            DoorSystemSetDoorState(dHash, 0) -- 0 = Unlocked
            DoorSystemForceShut(dHash, false)
            DoorSystemSetOpenRatio(dHash, 0.0, false)
            DoorSystemSetAutomaticDistance(dHash, 0.0)
            DoorSystemSetAutomaticRate(dHash, 0.0)

            -- Снимаем ограничения ускорения и отключаем паразитный сценарий запертой ручки
            pcall(function()
                SetDoorAccelerationLimit(dHash, 12.0)
                SetDoorMaxAngleLimit(dHash, 1.8)
                SetDoorAjarAngle(dHash, 0.04)
                Citizen.InvokeNative(0xC485E0720F501CEC, dHash, true) -- _DOOR_SYSTEM_SET_DOOR_PENDING_FORCE
                Citizen.InvokeNative(0x9B128DC36C1F0A6B, dHash, false) -- _DOOR_SYSTEM_SET_DOOR_SHAKE_ANIM
            end)
        end

        for _, ent in ipairs(doorEntities) do
            if DoesEntityExist(ent) then
                SetEntityAsMissionEntity(ent, true, true)
                SetEntityCanBeDamaged(ent, false)
                FreezeEntityPosition(ent, false)
                SetEntityDynamic(ent, true)
                SetEntityCollision(ent, true, true)
                SetEntityProofs(ent, false, false, false, false, false, false, false, false)
                SetCanClimbOnEntity(ent, false)
            end
        end
    end
end

-- Вспомогательная функция формирования списка действий двери
local function GetDoorActions(door)
    if not door or not door.house_id or not LocalHouses[door.house_id] then return nil end
    local house = LocalHouses[door.house_id]
    local hasOwner = (house.owner_charid ~= nil and house.owner_charid ~= 0 and house.owner_charid ~= "" and tostring(house.owner_charid) ~= "0")
    local isOwner = false
    if hasOwner and myCharId ~= nil then
        if tostring(house.owner_charid) == tostring(myCharId) or tonumber(house.owner_charid) == tonumber(myCharId) then
            isOwner = true
        end
    end

    local actions = {}
    if not hasOwner then
        -- Дом свободен: Кнопка Поселиться и Информация
        table.insert(actions, {
            id = 'claim',
            label = 'Поселиться',
            icon = 'house',
            event = 'thehunt_doors:onInteractClaim',
            targetInfo = { houseId = door.house_id, doorId = door.id, doorX = door.x, doorY = door.y, doorZ = door.z }
        })
        table.insert(actions, {
            id = 'info',
            label = 'Информация',
            icon = 'info',
            event = 'thehunt_doors:onInteractInfo',
            targetInfo = { houseId = door.house_id, doorId = door.id, doorX = door.x, doorY = door.y, doorZ = door.z }
        })
    else
        -- Дом занят: Открыть/Запереть ключом, Дубликат ключа, Освободить дом (если владелец), Информация
        local isDoorLocked = (door.state == 1)
        table.insert(actions, {
            id = 'lock',
            label = isDoorLocked and 'Открыть ключом' or 'Запереть ключом',
            icon = isDoorLocked and 'unlock' or 'lock',
            event = 'thehunt_doors:onInteractToggleLock',
            targetInfo = { houseId = door.house_id, doorId = door.id, doorX = door.x, doorY = door.y, doorZ = door.z }
        })
        table.insert(actions, {
            id = 'duplicate_key',
            label = 'Дубликат ключа',
            icon = 'key',
            event = 'thehunt_doors:onInteractDuplicateKey',
            targetInfo = { houseId = door.house_id, doorId = door.id, doorX = door.x, doorY = door.y, doorZ = door.z }
        })
        if isOwner then
            table.insert(actions, {
                id = 'unclaim',
                label = 'Освободить дом',
                icon = 'unclaim',
                event = 'thehunt_doors:onInteractUnclaim',
                targetInfo = { houseId = door.house_id, doorId = door.id, doorX = door.x, doorY = door.y, doorZ = door.z }
            })
        end
        table.insert(actions, {
            id = 'info',
            label = 'Информация',
            icon = 'info',
            event = 'thehunt_doors:onInteractInfo',
            targetInfo = { houseId = door.house_id, doorId = door.id, doorX = door.x, doorY = door.y, doorZ = door.z }
        })
    end
    return actions
end

-- Фоновый поток поддержки физики и динамической регистрации сущностей дверей в thehunt_interact
Citizen.CreateThread(function()
    while true do
        if isCharacterReady and next(LocalDoors) then
            local pedCoords = GetEntityCoords(PlayerPedId())
            for _, door in pairs(LocalDoors) do
                local dist = #(pedCoords - vector3(door.x, door.y, door.z))
                if dist < 35.0 then
                    ApplyDoorPhysics(door)

                    -- Если это зарегистрированный дом, регистрируем интеракты строго на 3D-энтити двери
                    if exports["thehunt_interact"] and door.house_id and LocalHouses[door.house_id] then
                        local actions = GetDoorActions(door)
                        if actions and #actions > 0 then
                            local modelHash = tonumber(door.model_hash) or 0
                            local doorEntities = GetAllDoorEntitiesAtCoords(door.x, door.y, door.z, modelHash)
                            if #doorEntities > 0 then
                                for _, doorEnt in ipairs(doorEntities) do
                                    if not ActiveRegisteredEntities[doorEnt] then
                                        exports["thehunt_interact"]:AddTargetEntity(doorEnt, actions, 2.0)
                                        ActiveRegisteredEntities[doorEnt] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            Citizen.Wait(500)
        else
            Citizen.Wait(1200)
        end
    end
end)

-- Обновление интерактивных действий для thehunt_interact (ТОЛЬКО ДЛЯ ЖИЛЫХ ДОМОВ!)
UpdateInteractZones = function()
    if not exports["thehunt_interact"] then return end

    if not myCharId and isCharacterReady then
        TriggerServerEvent("thehunt_doors:requestSync")
    end

    -- Очищаем ранее зарегистрированные энтити дверей
    for ent in pairs(ActiveRegisteredEntities) do
        if DoesEntityExist(ent) then
            exports["thehunt_interact"]:RemoveTargetEntity(ent)
        end
    end
    ActiveRegisteredEntities = {}

    -- Регистрируем интерактивные действия строго на 3D-моделях дверей активных домов
    for _, door in pairs(LocalDoors) do
        if door.house_id and LocalHouses[door.house_id] then
            local actions = GetDoorActions(door)
            if actions and #actions > 0 then
                local modelHash = tonumber(door.model_hash) or 0
                local doorEntities = GetAllDoorEntitiesAtCoords(door.x, door.y, door.z, modelHash)
                for _, doorEnt in ipairs(doorEntities) do
                    exports["thehunt_interact"]:AddTargetEntity(doorEnt, actions, 2.0)
                    ActiveRegisteredEntities[doorEnt] = true
                end
            end
        end
    end
end

-- Прием полной синхронизации
RegisterNetEvent("thehunt_doors:syncAllData", function(houses, doors, serverCharId)
    local newDoors = doors or {}

    -- 1. Снимаем регистрацию со ВСЕХ старых энтити и зон в thehunt_interact
    if GetResourceState("thehunt_interact") == "started" then
        pcall(function()
            for ent in pairs(ActiveRegisteredEntities) do
                if DoesEntityExist(ent) then
                    exports["thehunt_interact"]:RemoveTargetEntity(ent)
                end
            end
            exports["thehunt_interact"]:ClearTargetZones("door_zone_")
        end)
    end
    ActiveRegisteredEntities = {}
    ActiveRegisteredZones = {}

    -- 2. Проверяем удаленные двери: если дом/дверь удалены из базы — полностью отпираем замки и делаем створки физичными
    if next(LocalDoors) then
        for oldId, oldDoor in pairs(LocalDoors) do
            if not newDoors[oldId] then
                local modelHash = tonumber(oldDoor.model_hash) or 0
                local nativeHash = GetNativeDoorHashAtCoords(oldDoor.x, oldDoor.y, oldDoor.z, modelHash)
                local doorHash = nativeHash or (tonumber(oldDoor.door_hash) or joaat(tostring(oldDoor.door_hash)))

                local hashesToUnlock = {}
                if doorHash and doorHash ~= 0 then table.insert(hashesToUnlock, doorHash) end
                if nativeHash and nativeHash ~= 0 and nativeHash ~= doorHash then table.insert(hashesToUnlock, nativeHash) end

                for _, dHash in ipairs(hashesToUnlock) do
                    pcall(function()
                        AddDoorToSystemNew(dHash, true, true, false, 0, 0, false)
                        DoorSystemSetDoorState(dHash, 0) -- 0 = Unlocked
                        DoorSystemForceShut(dHash, false)
                        DoorSystemSetOpenRatio(dHash, 0.0, false)
                        DoorSystemSetAutomaticDistance(dHash, 0.0)
                        DoorSystemSetAutomaticRate(dHash, 0.0)
                        SetDoorAccelerationLimit(dHash, 12.0)
                        SetDoorMaxAngleLimit(dHash, 1.8)
                        SetDoorAjarAngle(dHash, 0.04)
                        Citizen.InvokeNative(0xC485E0720F501CEC, dHash, true) -- _DOOR_SYSTEM_SET_DOOR_PENDING_FORCE
                        Citizen.InvokeNative(0x9B128DC36C1F0A6B, dHash, false) -- _DOOR_SYSTEM_SET_DOOR_SHAKE_ANIM
                    end)
                end

                local doorEntities = GetAllDoorEntitiesAtCoords(oldDoor.x, oldDoor.y, oldDoor.z, modelHash)
                for _, doorEnt in ipairs(doorEntities) do
                    if DoesEntityExist(doorEnt) then
                        SetEntityAsMissionEntity(doorEnt, true, true)
                        SetEntityCanBeDamaged(doorEnt, false)
                        FreezeEntityPosition(doorEnt, false)
                        SetEntityDynamic(doorEnt, true)
                        SetEntityCollision(doorEnt, true, true)
                        SetEntityProofs(doorEnt, false, false, false, false, false, false, false, false)
                        SetCanClimbOnEntity(doorEnt, false)
                    end
                end
            end
        end
    end

    LocalHouses = houses or {}
    LocalDoors = newDoors

    if serverCharId then
        myCharId = tonumber(serverCharId)
        isCharacterReady = true
    end

    for _, door in pairs(LocalDoors) do
        ApplyDoorPhysics(door)
    end

    UpdateInteractZones()
end)

-- Экспорт списка для админ-панели
exports('GetHousesAndDoors', function()
    return LocalHouses, LocalDoors
end)

-- =================================================================
-- ИНТЕРАКТИВНЫЕ ДЕЙСТВИЯ ИГРОКА
-- =================================================================

RegisterNetEvent("thehunt_doors:onInteractClaim", function(targetInfo)
    local hId = targetInfo and (targetInfo.houseId or (targetInfo.targetInfo and targetInfo.targetInfo.houseId))
    if not hId then return end
    TriggerServerEvent("thehunt_doors:claimHouse", tonumber(hId))
end)

RegisterNetEvent("thehunt_doors:onInteractUnclaim", function(targetInfo)
    local hId = targetInfo and (targetInfo.houseId or (targetInfo.targetInfo and targetInfo.targetInfo.houseId))
    if not hId then return end
    TriggerServerEvent("thehunt_doors:unclaimHouse", tonumber(hId))
end)

-- Переключение замка выбранной двери (мгновенный запрос на сервер без задержек)
RegisterNetEvent("thehunt_doors:onInteractToggleLock", function(targetInfo)
    local doorId = targetInfo and (targetInfo.doorId or (targetInfo.targetInfo and targetInfo.targetInfo.doorId))
    if doorId then
        TriggerServerEvent("thehunt_doors:toggleDoorLock", tonumber(doorId))
    else
        local hId = targetInfo and (targetInfo.houseId or (targetInfo.targetInfo and targetInfo.targetInfo.houseId))
        if hId then
            TriggerServerEvent("thehunt_doors:toggleHouseLock", tonumber(hId))
        end
    end
end)

-- Анимация поворота ключа (только при подтверждении сервером наличия подходящего ключа)
RegisterNetEvent("thehunt_doors:playKeyAnimation", function()
    local ped = PlayerPedId()
    local animDict = "mech_interaction@door@lock"
    local animName = "lock_turn_key"

    RequestAnimDict(animDict)
    local count = 0
    while not HasAnimDictLoaded(animDict) and count < 10 do
        Citizen.Wait(20)
        count = count + 1
    end

    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 4.0, -4.0, 900, 31, 0, false, false, false)
    end
end)

RegisterNetEvent("thehunt_doors:onInteractDuplicateKey", function(targetInfo)
    local hId = targetInfo and (targetInfo.houseId or (targetInfo.targetInfo and targetInfo.targetInfo.houseId))
    if hId then
        TriggerServerEvent("thehunt_doors:duplicateHouseKey", tonumber(hId))
    end
end)

RegisterNetEvent("thehunt_doors:onInteractInfo", function(targetInfo)
    local hId = targetInfo and (targetInfo.houseId or (targetInfo.targetInfo and targetInfo.targetInfo.houseId))
    local doorId = targetInfo and (targetInfo.doorId or (targetInfo.targetInfo and targetInfo.targetInfo.doorId))

    local houseTitle = "Жилой дом"
    local ownerText = "Свободен"
    local lockText = "Открыто"

    if hId and LocalHouses[tonumber(hId)] then
        local house = LocalHouses[tonumber(hId)]
        houseTitle = house.name or "Жилой дом"
        if house.owner_charid ~= nil and house.owner_charid ~= 0 and house.owner_charid ~= "" then
            ownerText = "Занято"
        else
            ownerText = "Свободен"
        end
    end

    if doorId and LocalDoors[tonumber(doorId)] then
        local door = LocalDoors[tonumber(doorId)]
        lockText = (door.state == 1) and "Заперто" or "Открыто"
    elseif hId and LocalHouses[tonumber(hId)] then
        local house = LocalHouses[tonumber(hId)]
        lockText = house.is_locked and "Заперто" or "Открыто"
    end

    if targetInfo and targetInfo.doorX then
        infoModalCoords = vector3(targetInfo.doorX, targetInfo.doorY, targetInfo.doorZ)
    else
        infoModalCoords = GetEntityCoords(PlayerPedId())
    end

    isInfoModalOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        type = 'SHOW_HOUSE_INFO',
        title = houseTitle,
        owner = ownerText,
        status = lockText
    })
end)

-- Поток контроля фокуса и автоматического закрытия модалки при отходе
Citizen.CreateThread(function()
    while true do
        if isInfoModalOpen then
            Citizen.Wait(0)
            local ped = PlayerPedId()

            -- Автозакрытие при отходе дальше 2.6 метров
            if infoModalCoords then
                local dist = #(GetEntityCoords(ped) - infoModalCoords)
                if dist > 2.6 then
                    isInfoModalOpen = false
                    SetNuiFocus(false, false)
                    SetNuiFocusKeepInput(false)
                    SendNUIMessage({ type = 'CLOSE_HOUSE_INFO' })
                end
            end

            -- Блокировка всего управления (как в VORP) для 100% фиксации камеры
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)

            local allowedControls = {
                -- Войс-чат
                `INPUT_PUSH_TO_TALK`,
                0xF1301666,
                0x05CA7C52,

                -- Движение пешком (WASD, Shift, Space, Ctrl)
                `INPUT_MOVE_LR`,
                `INPUT_MOVE_UD`,
                `INPUT_MOVE_UP_ONLY`,
                `INPUT_MOVE_DOWN_ONLY`,
                `INPUT_MOVE_LEFT_ONLY`,
                `INPUT_MOVE_RIGHT_ONLY`,
                `INPUT_SPRINT`,
                `INPUT_JUMP`,
                `INPUT_CLIMB`,
                `INPUT_DUCK`,

                -- Движение на лошади (WASD, Shift, Space, Ctrl)
                `INPUT_HORSE_MOVE_UD`,
                `INPUT_HORSE_MOVE_LR`,
                `INPUT_HORSE_MOVE_UP_ONLY`,
                `INPUT_HORSE_MOVE_DOWN_ONLY`,
                `INPUT_HORSE_MOVE_LEFT_ONLY`,
                `INPUT_HORSE_MOVE_RIGHT_ONLY`,
                `INPUT_HORSE_SPRINT`,
                `INPUT_HORSE_JUMP`,
                `INPUT_HORSE_STOP`,

                -- Управление повозками
                `INPUT_VEH_ACCELERATE`,
                `INPUT_VEH_BRAKE`,
                `INPUT_VEH_MOVE_LR`,
                `INPUT_VEH_HANDBRAKE`,

                -- Числовые хэши RDR2 на случай нестандартных названий
                0x4D8FB4C1, -- MOVE_LR
                0xEDA4707E, -- MOVE_UD
                0x8FD015D8, -- MOVE_UD (RDR2)
                0xD27782E3, -- MOVE_UP_ONLY (W)
                0x7065027D, -- MOVE_DOWN_ONLY (S)
                0xB4E465B4, -- MOVE_LEFT_ONLY (A)
                0x399C6619, -- MOVE_RIGHT_ONLY (D)
                0x8FFC75D0, -- SPRINT (Shift)
                0x2C4B7E05, -- SPRINT_ALT
                0xD42E6C65, -- JUMP (Space)
                0x9330C873, -- CLIMB (Space)
                0xDB096B85, -- DUCK (Ctrl)
                0x78564D7B, -- DUCK_ALT
                0x82CA7BA9, -- HORSE_MOVE_UD
                0x227DCC40, -- HORSE_MOVE_LR
                0xE95F4F0C, -- HORSE_MOVE_UP_ONLY (W)
                0x866B5DB8, -- HORSE_MOVE_DOWN_ONLY (S)
                0x51E13F58, -- HORSE_MOVE_LEFT_ONLY (A)
                0xC229CF67, -- HORSE_MOVE_RIGHT_ONLY (D)
                0x54182BC1, -- HORSE_SPRINT (Shift)
                0x63A38928, -- HORSE_JUMP (Space)
                0xD2315E39, -- HORSE_CLIMB (Space)
                0x153A478C  -- HORSE_STOP (Ctrl)
            }

            for pad = 0, 2 do
                for i = 1, #allowedControls do
                    EnableControlAction(pad, allowedControls[i], true)
                end
            end
        else
            Citizen.Wait(200)
        end
    end
end)

RegisterNUICallback('closeHouseInfoModal', function(data, cb)
    isInfoModalOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cb('ok')
end)

-- Системные звуки
RegisterNetEvent("thehunt_doors:playDoorSound", function(soundType)
    if soundType == "lock" then
        PlaySoundFrontend("DOOR_LOCK", "HUD_PLAYER_MENU", true, 0)
    else
        PlaySoundFrontend("DOOR_UNLOCK", "HUD_PLAYER_MENU", true, 0)
    end
end)

-- Уведомления (перенаправляются в thehunt_status)
RegisterNetEvent("thehunt_doors:notify", function(title, message, notifyType)
    TriggerEvent("thehunt_status:notify", title, message, notifyType)
end)

exports('isDoorMenuOpen', function()
    return isInfoModalOpen == true
end)
