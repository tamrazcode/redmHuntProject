-- =================================================================
-- HUNT: Hard RP — Doors & Housing | Admin Tool Module
-- =================================================================

local isDoorToolActive = false
local isTargetingMode = false
local targetingMode = 'house' -- 'single' or 'house'
local stagedDoors = {}
local highlightedDoor = nil

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

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function GetDoorRaycast(maxDistance)
    local camRot = GetGameplayCamRot(2)
    local camCoords = GetGameplayCamCoord()
    local dir = RotationToDirection(camRot)
    local targetCoords = camCoords + (dir * maxDistance)

    -- Flag 287 = Everything (World, Objects, Doors)
    local ray = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        targetCoords.x, targetCoords.y, targetCoords.z,
        287, PlayerPedId(), 4
    )
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)
    return (hit == 1 or hit == true), entityHit, endCoords, camCoords
end

local function ToggleDoorTool()
    isDoorToolActive = not isDoorToolActive
    isTargetingMode = false
    stagedDoors = {}
    highlightedDoor = nil

    if isDoorToolActive then
        local houses, doors = {}, {}
        if exports["thehunt_doors"] and exports["thehunt_doors"].GetHousesAndDoors then
            houses, doors = exports["thehunt_doors"]:GetHousesAndDoors()
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            type = 'OPEN_DOOR_ADMIN',
            houses = houses or {},
            doors = doors or {}
        })
    else
        SetNuiFocus(false, false)
        SendNUIMessage({ type = 'CLOSE_DOOR_ADMIN' })
    end
end

RegisterCommand('dooradmin', ToggleDoorTool, false)
RegisterCommand('doors', ToggleDoorTool, false)

-- Синхронизация списка в открытой админке при изменениях
RegisterNetEvent("thehunt_doors:syncAllData", function(houses, doors)
    if isDoorToolActive then
        SendNUIMessage({
            type = 'UPDATE_ADMIN_LIST',
            houses = houses or {},
            doors = doors or {}
        })
    end
end)

-- Поток 3D лазерного выбора дверей (свободное управление персонажем и камерой)
Citizen.CreateThread(function()
    while true do
        if isTargetingMode then
            Citizen.Wait(0)
            local ped = PlayerPedId()

            -- 1. Отрисовка циановых маркеров для всех уже выбранных дверей
            for _, staged in ipairs(stagedDoors) do
                DrawLine(staged.x, staged.y, staged.z - 0.2, staged.x, staged.y, staged.z + 1.8, 6, 182, 212, 255)
            end

            -- 2. Поиск двери лазерным лучом от камеры
            local hit, entity, hitCoords, camCoords = GetDoorRaycast(7.5)
            local detectedDoor = nil

            if hit and entity and DoesEntityExist(entity) and GetEntityType(entity) == 3 then
                local model = GetEntityModel(entity)
                local coords = GetEntityCoords(entity)
                local heading = GetEntityHeading(entity)
                local nativeDoorHash = GetNativeDoorHashAtCoords(coords.x, coords.y, coords.z, model)
                local finalHash = nativeDoorHash or ("door_%d_%d"):format(model, math.floor(coords.x + coords.y))

                detectedDoor = {
                    entity = entity,
                    modelHash = model,
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = heading,
                    doorHash = tostring(finalHash)
                }
            elseif hit then
                local objects = GetGamePool('CObject')
                local closestDist = 1.8
                for _, obj in ipairs(objects) do
                    if DoesEntityExist(obj) then
                        local objCoords = GetEntityCoords(obj)
                        local dist = #(hitCoords - objCoords)
                        if dist < closestDist then
                            closestDist = dist
                            local model = GetEntityModel(obj)
                            local heading = GetEntityHeading(obj)
                            local nativeDoorHash2 = GetNativeDoorHashAtCoords(objCoords.x, objCoords.y, objCoords.z, model)
                            local finalHash = nativeDoorHash2 or ("door_%d_%d"):format(model, math.floor(objCoords.x + objCoords.y))

                            detectedDoor = {
                                entity = obj,
                                modelHash = model,
                                x = objCoords.x,
                                y = objCoords.y,
                                z = objCoords.z,
                                heading = heading,
                                doorHash = tostring(finalHash)
                            }
                        end
                    end
                end
            end

            if detectedDoor then
                highlightedDoor = detectedDoor
                -- Зеленый лазер от камеры к двери
                DrawLine(camCoords.x, camCoords.y, camCoords.z - 0.2, highlightedDoor.x, highlightedDoor.y, highlightedDoor.z, 34, 197, 94, 220)
                DrawLine(highlightedDoor.x, highlightedDoor.y, highlightedDoor.z, highlightedDoor.x, highlightedDoor.y, highlightedDoor.z + 1.5, 34, 197, 94, 255)
            else
                highlightedDoor = nil
            end

            -- Блокировка стрельбы и боевых контролов во время выбора
            DisableControlAction(0, 0x07CE1E61, true) -- LMB Attack
            DisableControlAction(0, 0xF84FA74F, true) -- RMB Aim
            DisablePlayerFiring(ped, true)

            -- [ЛКМ] Выбрать наведённую дверь
            if IsControlJustPressed(0, 0x07CE1E61) or IsDisabledControlJustPressed(0, 0x07CE1E61) then
                if highlightedDoor then
                    -- Автоматическая калибровка закрытого положения перед сохранением
                    local dEnt = highlightedDoor.entity
                    if dEnt and DoesEntityExist(dEnt) then
                        SetEntityAsMissionEntity(dEnt, true, true)
                        FreezeEntityPosition(dEnt, false)

                        local model = highlightedDoor.modelHash
                        local curCoords = GetEntityCoords(dEnt)
                        local nativeHash = GetNativeDoorHashAtCoords(curCoords.x, curCoords.y, curCoords.z, model)

                        if nativeHash and nativeHash ~= 0 then
                            if not IsDoorRegisteredWithSystem(nativeHash) then
                                pcall(function()
                                    AddDoorToSystemNew(nativeHash, true, true, false, 0, 0, false)
                                end)
                                pcall(function()
                                    Citizen.InvokeNative(0x6F8838D03D1DC226, nativeHash, model, curCoords.x + 0.0, curCoords.y + 0.0, curCoords.z + 0.0, false, true, false)
                                end)
                            end
                            DoorSystemForceShut(nativeHash, true)
                            DoorSystemSetOpenRatio(nativeHash, 0.0, true)
                            DoorSystemSetDoorState(nativeHash, 1)
                            Citizen.Wait(120)
                        end

                        local closedCoords = GetEntityCoords(dEnt)
                        local closedHeading = GetEntityHeading(dEnt)

                        highlightedDoor.x = closedCoords.x
                        highlightedDoor.y = closedCoords.y
                        highlightedDoor.z = closedCoords.z
                        highlightedDoor.heading = closedHeading
                    end

                    if targetingMode == 'single' then
                        -- Одиночная дверь: сразу переводим в полностью физичное и открытое состояние
                        local dEnt = highlightedDoor.entity
                        local model = highlightedDoor.modelHash
                        local curCoords = vector3(highlightedDoor.x, highlightedDoor.y, highlightedDoor.z)
                        local nativeHash = GetNativeDoorHashAtCoords(curCoords.x, curCoords.y, curCoords.z, model)

                        if nativeHash and nativeHash ~= 0 then
                            if not IsDoorRegisteredWithSystem(nativeHash) then
                                pcall(function()
                                    AddDoorToSystemNew(nativeHash, true, true, false, 0, 0, false)
                                end)
                                pcall(function()
                                    Citizen.InvokeNative(0x6F8838D03D1DC226, nativeHash, model, curCoords.x + 0.0, curCoords.y + 0.0, curCoords.z + 0.0, false, true, false)
                                end)
                            end
                            DoorSystemForceShut(nativeHash, false)
                            DoorSystemSetOpenRatio(nativeHash, 0.0, false)
                            DoorSystemSetDoorState(nativeHash, 0)
                            pcall(function()
                                SetDoorAccelerationLimit(nativeHash, 12.0)
                                SetDoorMaxAngleLimit(nativeHash, 1.8)
                                SetDoorAjarAngle(nativeHash, 0.04)
                                Citizen.InvokeNative(0xC485E0720F501CEC, nativeHash, true)
                                Citizen.InvokeNative(0x9B128DC36C1F0A6B, nativeHash, false)
                            end)
                        end

                        if dEnt and DoesEntityExist(dEnt) then
                            SetEntityAsMissionEntity(dEnt, true, true)
                            SetEntityCanBeDamaged(dEnt, false)
                            FreezeEntityPosition(dEnt, false)
                            SetEntityDynamic(dEnt, true)
                            SetEntityCollision(dEnt, true, true)
                            SetEntityProofs(dEnt, false, false, false, false, false, false, false, false)
                            SetCanClimbOnEntity(dEnt, false)
                        end

                        -- Отправляем на сервер для сохранения в MySQL
                        TriggerServerEvent("thehunt_doors:adminSaveSingleDoor", highlightedDoor)
                        isTargetingMode = false
                        SendNUIMessage({ type = 'HIDE_TARGETING_HUD' })
                        Citizen.Wait(200)
                        ToggleDoorTool()
                    elseif targetingMode == 'single_lock' then
                        -- Блокировка двери обратно: переводим в намертво закрытое состояние
                        local dEnt = highlightedDoor.entity
                        local model = highlightedDoor.modelHash
                        local curCoords = vector3(highlightedDoor.x, highlightedDoor.y, highlightedDoor.z)
                        local nativeHash = GetNativeDoorHashAtCoords(curCoords.x, curCoords.y, curCoords.z, model)

                        if nativeHash and nativeHash ~= 0 then
                            if not IsDoorRegisteredWithSystem(nativeHash) then
                                pcall(function()
                                    AddDoorToSystemNew(nativeHash, true, true, false, 0, 0, false)
                                end)
                                pcall(function()
                                    Citizen.InvokeNative(0x6F8838D03D1DC226, nativeHash, model, curCoords.x + 0.0, curCoords.y + 0.0, curCoords.z + 0.0, false, true, false)
                                end)
                            end
                            DoorSystemForceShut(nativeHash, true)
                            DoorSystemSetOpenRatio(nativeHash, 0.0, true)
                            DoorSystemSetDoorState(nativeHash, 1)
                            DoorSystemSetAutomaticDistance(nativeHash, 0.0)
                            DoorSystemSetAutomaticRate(nativeHash, 0.0)
                        end

                        if dEnt and DoesEntityExist(dEnt) then
                            SetEntityAsMissionEntity(dEnt, true, true)
                            SetEntityCoords(dEnt, highlightedDoor.x, highlightedDoor.y, highlightedDoor.z, false, false, false, false)
                            if highlightedDoor.heading then
                                SetEntityHeading(dEnt, tonumber(highlightedDoor.heading) + 0.0)
                                SetEntityRotation(dEnt, 0.0, 0.0, tonumber(highlightedDoor.heading) + 0.0, 2, true)
                            end
                            SetEntityVelocity(dEnt, 0.0, 0.0, 0.0)
                            FreezeEntityPosition(dEnt, true)
                            SetEntityCollision(dEnt, true, true)
                        end

                        -- Отправляем на сервер для удаления/блокировки в MySQL
                        TriggerServerEvent("thehunt_doors:adminLockSingleDoor", highlightedDoor)
                        isTargetingMode = false
                        SendNUIMessage({ type = 'HIDE_TARGETING_HUD' })
                        Citizen.Wait(200)
                        ToggleDoorTool()
                    else
                        -- Дом (группа дверей): проверяем на дубликат и добавляем
                        local isDuplicate = false
                        for _, staged in ipairs(stagedDoors) do
                            local dist = #(vector3(staged.x, staged.y, staged.z) - vector3(highlightedDoor.x, highlightedDoor.y, highlightedDoor.z))
                            if staged.entity == highlightedDoor.entity or dist < 0.35 then
                                isDuplicate = true
                                break
                            end
                        end

                        if isDuplicate then
                            TriggerEvent("thehunt_status:notify", "Внимание", "Эта дверь уже выбрана в списке")
                        else
                            table.insert(stagedDoors, highlightedDoor)
                            PlaySoundFrontend("SELECT", "HUD_PLAYER_MENU", true, 0)
                            SendNUIMessage({ type = 'UPDATE_HUD_COUNT', count = #stagedDoors })
                            TriggerEvent("thehunt_status:notify", "Дверь откалибрована", ("Добавлена дверь #%d (зафиксирован закрытый проём)"):format(#stagedDoors))
                        end
                    end
                else
                    TriggerEvent("thehunt_status:notify", "Внимание", "Наведите лазер на дверь")
                end
                Citizen.Wait(200)
            end

            -- [ПКМ] Завершить выбор дверей для дома
            if targetingMode == 'house' and (IsControlJustPressed(0, 0xF84FA74F) or IsDisabledControlJustPressed(0, 0xF84FA74F)) then
                if #stagedDoors > 0 then
                    isTargetingMode = false
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        type = 'OPEN_HOUSE_NAMING_MODAL',
                        count = #stagedDoors
                    })
                else
                    TriggerEvent("thehunt_status:notify", "Внимание", "Сначала выберите хотя бы одну дверь (ЛКМ)")
                end
                Citizen.Wait(200)
            end

            -- [ESC / Backspace] Отмена режима выбора
            if IsControlJustPressed(0, 0x156F7136) or IsDisabledControlJustPressed(0, 0x156F7136)
            or IsControlJustPressed(0, 0x308588E6) or IsDisabledControlJustPressed(0, 0x308588E6) then
                isTargetingMode = false
                stagedDoors = {}
                SendNUIMessage({ type = 'HIDE_TARGETING_HUD' })
                Citizen.Wait(200)
                ToggleDoorTool()
            end
        else
            Citizen.Wait(180)
        end
    end
end)

-- =================================================================
-- NUI CALLBACKS
-- =================================================================

-- Старт 3D режима выбора
RegisterNUICallback('startTargeting', function(data, cb)
    isTargetingMode = true
    targetingMode = data.mode or 'house'
    stagedDoors = {}
    highlightedDoor = nil

    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'SHOW_TARGETING_HUD',
        mode = targetingMode,
        count = 0
    })
    cb('ok')
end)

-- Подтверждение создания дома с введенным именем
RegisterNUICallback('confirmHouseSave', function(data, cb)
    local houseName = data.houseName or "Жилой дом"
    if #stagedDoors > 0 then
        TriggerServerEvent("thehunt_doors:adminSaveHouseAndDoors", houseName, stagedDoors)
        stagedDoors = {}
        Citizen.Wait(200)
        ToggleDoorTool()
    else
        ToggleDoorTool()
    end
    cb('ok')
end)

-- Отмена сохранения дома
RegisterNUICallback('cancelHouseNaming', function(data, cb)
    stagedDoors = {}
    ToggleDoorTool()
    cb('ok')
end)

-- Запрос обновления списка с сервера
RegisterNUICallback('adminRequestList', function(data, cb)
    local houses, doors = {}, {}
    if exports["thehunt_doors"] and exports["thehunt_doors"].GetHousesAndDoors then
        houses, doors = exports["thehunt_doors"]:GetHousesAndDoors()
    end
    cb({ houses = houses or {}, doors = doors or {} })
end)

-- Телепортация к дому
RegisterNUICallback('adminTeleportToHouse', function(data, cb)
    local houseId = tonumber(data.houseId)
    local houses, doors = {}, {}
    if exports["thehunt_doors"] and exports["thehunt_doors"].GetHousesAndDoors then
        houses, doors = exports["thehunt_doors"]:GetHousesAndDoors()
    end

    for _, door in pairs(doors) do
        if door.house_id == houseId then
            local ped = PlayerPedId()
            SetEntityCoords(ped, door.x, door.y, door.z + 0.2, true, false, false, false)
            ToggleDoorTool()
            cb({ success = true })
            return
        end
    end
    cb({ success = false, error = "Дверь не найдена" })
end)

-- Телепортация к двери
RegisterNUICallback('adminTeleportToDoor', function(data, cb)
    local doorId = tonumber(data.doorId)
    local houses, doors = {}, {}
    if exports["thehunt_doors"] and exports["thehunt_doors"].GetHousesAndDoors then
        houses, doors = exports["thehunt_doors"]:GetHousesAndDoors()
    end

    local door = doors[doorId]
    if door then
        local ped = PlayerPedId()
        SetEntityCoords(ped, door.x, door.y, door.z + 0.2, true, false, false, false)
        ToggleDoorTool()
        cb({ success = true })
    else
        cb({ success = false, error = "Дверь не найдена" })
    end
end)

-- Удаление дома
RegisterNUICallback('adminDeleteHouse', function(data, cb)
    local houseId = tonumber(data.houseId)
    if houseId then
        TriggerServerEvent("thehunt_doors:adminDeleteHouse", houseId)
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

-- Удаление двери
RegisterNUICallback('adminDeleteDoor', function(data, cb)
    local doorId = tonumber(data.doorId)
    if doorId then
        TriggerServerEvent("thehunt_doors:adminDeleteDoor", doorId)
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback('closeDoorAdmin', function(data, cb)
    ToggleDoorTool()
    cb('ok')
end)
