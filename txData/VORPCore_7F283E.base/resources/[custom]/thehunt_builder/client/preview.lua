-- =================================================================
-- HUNT: Hard RP — The Corruption | Builder 3D Preview & Placement Mode
-- Админ-режим: Свободная открепленная камера (Freecam / Spooner-style)
-- Игровой режим: Персонаж от 3-го лица (для предметов из инвентаря)
-- =================================================================

Preview = {}

local isWorldEditorActive = false
local isCatalogOpen = false
local isPreviewActive = false
local ghostEntity = nil
local currentPropInfo = nil
local originalMovingData = nil
local pendingWorldMove = nil
local initialTransform = nil
local isSnappingEnabled = true

local function DecodeMetadata(rawMetadata)
    if type(rawMetadata) == "table" then
        return rawMetadata
    end
    if type(rawMetadata) == "string" and rawMetadata ~= "" then
        local ok, decoded = pcall(json.decode, rawMetadata)
        if ok and type(decoded) == "table" then
            return decoded
        end
    end
    return {}
end

local function IsDoorLikeModel(modelName)
    local value = tostring(modelName or ""):lower()
    return value:find("door", 1, true) ~= nil or value:find("gate", 1, true) ~= nil
end

local function IsDynamicMetadata(metadata)
    return type(metadata) == "table" and (
        metadata.physics_mode == "dynamic"
        or metadata.dynamic == true
        or metadata.is_dynamic == true
        or tonumber(metadata.is_dynamic) == 1
    )
end

local function IsDoorProp(propData)
    if type(propData) == "table" then
        if IsDoorLikeModel(propData.model)
            or IsDoorLikeModel(propData.modelName)
            or IsDoorLikeModel(propData.model_name)
            or IsDoorLikeModel(propData.name) then
            return true
        end
    end
    return false
end

local function CreatePreviewObject(modelHash, coords, heading, doorFlag)
    local entity = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, doorFlag == true)
    if (not entity or entity == 0 or not DoesEntityExist(entity)) and doorFlag then
        -- Some prop models do not accept the door flag even though they are
        -- valid objects. Keep a safe fallback so the old placement path stays usable.
        entity = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
    end
    if entity and entity ~= 0 and DoesEntityExist(entity) and heading then
        SetEntityHeading(entity, heading + 0.0)
    end
    return entity
end

local function BuildPlacementMetadata()
    local info = currentPropInfo or {}
    local metadata = DecodeMetadata(info.metadata)

    if info.physicsMode == "dynamic" then
        metadata.physics_mode = "dynamic"
        metadata.dynamic = true
    else
        metadata.physics_mode = nil
        metadata.dynamic = nil
        metadata.is_dynamic = nil
    end

    if info.doorMode == true and IsDoorProp(info) then
        metadata.door_mode = true
    else
        metadata.door_mode = nil
    end

    local entityType = info.entityType or "object"
    if entityType ~= "object" then
        metadata.entity_type = entityType
    end
    if info.scenario and info.scenario ~= "" and info.scenario ~= "none" then
        metadata.scenario = info.scenario
    end
    return metadata
end

local function ConfigurePreviewObject(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityAlpha(entity, 165)
    SetEntityCollision(entity, false, false)
    SetEntityInvincible(entity, true)
    FreezeEntityPosition(entity, true)
end

local function RebuildGhostForPlacementMode()
    if not isPreviewActive or not ghostEntity or not DoesEntityExist(ghostEntity) then return end
    if not currentPropInfo or currentPropInfo.entityType ~= "object" then return end

    local coords = GetEntityCoords(ghostEntity)
    local rotation = GetEntityRotation(ghostEntity, 2)
    local modelHash = Raycast.NormalizeModelHash(GetEntityModel(ghostEntity))
    DeleteEntity(ghostEntity)
    ghostEntity = CreatePreviewObject(modelHash, coords, rotation.z, currentPropInfo.doorMode == true)
    if DoesEntityExist(ghostEntity) then
        ConfigurePreviewObject(ghostEntity)
        SetEntityRotation(ghostEntity, rotation.x, rotation.y, rotation.z, 2, true)
    end
end

-- Режим свободной камеры
local isFreecamMode = false
local isInspectorActive = false
local freecamHandle = nil
local freecamPos = vector3(0, 0, 0)
local freecamPitch = 0.0
local freecamYaw = 0.0

-- Параметры ориентации и положения объекта
local currentHeading = 0.0
local currentPitch = 0.0
local currentRoll = 0.0
local heightOffset = 0.0
local distanceOffset = 5.0

-- Лимиты дистанции размещения предметов для персонажа (максимально 2-3 метра)
local MIN_ITEM_DISTANCE = 0.8
local MAX_ITEM_DISTANCE = 2.5
local DEFAULT_ITEM_DISTANCE = 1.8

local isInputFocused = false

function Preview.IsActive()
    return isPreviewActive or isWorldEditorActive
end

function Preview.IsWorldEditorActive()
    return isWorldEditorActive
end

function Preview.IsFreecamActive()
    return (isWorldEditorActive or isFreecamMode) == true
end

function Preview.GetGhostEntity()
    return ghostEntity
end

function Preview.GetFreecamPos()
    if (isWorldEditorActive or isFreecamMode) and freecamHandle and DoesCamExist(freecamHandle) then
        return freecamPos
    end
    return GetGameplayCamCoord()
end

function Preview.GetCameraCoords()
    if (isWorldEditorActive or isFreecamMode) and freecamHandle and DoesCamExist(freecamHandle) then
        return freecamPos
    end
    return GetGameplayCamCoord()
end

function Preview.TeleportCamera(coords)
    if coords then
        freecamPos = coords
        if freecamHandle and DoesCamExist(freecamHandle) then
            SetCamCoord(freecamHandle, coords.x, coords.y, coords.z)
        end
    end
end

function Preview.SetInputFocus(focused)
    isInputFocused = (focused == true)
end

function Preview.OpenNearbyProps()
    if not isWorldEditorActive then return end
    isCatalogOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    local dbList = Streamer.GetAllDatabaseProps(freecamPos)
    SendNUIMessage({
        type = 'OPEN_CATALOG_PANEL',
        section = 'nearby',
        props = dbList
    })
end

-- Вспомогательная функция безопасной загрузки модели
local function LoadModelSafely(modelHash)
    if not modelHash or modelHash == 0 then return false end

    RequestModel(modelHash)
    if modelHash > 2147483647 then
        RequestModel(modelHash - 4294967296)
    end

    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 35 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) and modelHash > 2147483647 then
        local signedHash = modelHash - 4294967296
        while not HasModelLoaded(signedHash) and timeout < 60 do
            Citizen.Wait(50)
            timeout = timeout + 1
        end
        return HasModelLoaded(signedHash)
    end

    return HasModelLoaded(modelHash)
end

RegisterNetEvent("thehunt_builder:moveWorldStaticObjectConfirmed", function(propId)
    if not pendingWorldMove then return end

    local ghost = pendingWorldMove.ghostEntity
    if propId and ghost and DoesEntityExist(ghost) then
        Streamer.SetSpawnedEntity(propId, ghost)
        if Entity(ghost).state then
            Entity(ghost).state:set('builderPropId', tonumber(propId), false)
        end
    end

    local original = pendingWorldMove.originalEntity
    if original and DoesEntityExist(original) then
        SetEntityAsMissionEntity(original, true, true)
        DeleteEntity(original)
    end
    pendingWorldMove = nil
end)

RegisterNetEvent("thehunt_builder:moveWorldStaticObjectFailed", function(message)
    if pendingWorldMove then
        local ghost = pendingWorldMove.ghostEntity
        if ghost and DoesEntityExist(ghost) then
            SetEntityAsMissionEntity(ghost, true, true)
            DeleteEntity(ghost)
        end

        local original = pendingWorldMove.originalEntity
        if original and DoesEntityExist(original) then
            SetEntityAlpha(original, 255, false)
            SetEntityCollision(original, true, true)
            FreezeEntityPosition(original, true)
        end
        pendingWorldMove = nil
    end

    TriggerEvent("thehunt_status:notify", "Builder", message or "Не удалось сохранить перемещение", "error", 3500)
end)

-- =================================================================
-- Вспомогательные функции четкой заморозки и разморозки персонажа
-- =================================================================
local function FreezePedForFreecam(ped)
    ped = ped or PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end

    pcall(function() SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true) end)
    ClearPedTasksImmediately(ped)
    SetPlayerControl(PlayerId(), false, 0)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStandStill(ped, -1)
end

local function UnfreezePedFromFreecam(ped)
    ped = ped or PlayerPedId()
    if not ped or not DoesEntityExist(ped) then return end

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPedCanRagdoll(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    ClearPedTasksImmediately(ped)
    ClearPedTasks(ped)
    SetPlayerControl(PlayerId(), true, 0)
end

-- =================================================================
-- 1. СТАРТ РЕЖИМА РЕДАКТОРА МИРА (СВОБОДНАЯ КАМЕРА БЕЗ ОБЪЕКТА)
-- =================================================================
function Preview.StartWorldEditor()
    isWorldEditorActive = true
    isCatalogOpen = false
    isPreviewActive = false
    ghostEntity = nil
    currentPropInfo = nil
    originalMovingData = nil

    local myPed = PlayerPedId()
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    freecamPos = camCoords
    freecamPitch = camRot.x
    freecamYaw = camRot.z

    if not freecamHandle or not DoesCamExist(freecamHandle) then
        freecamHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    end
    SetCamCoord(freecamHandle, freecamPos.x, freecamPos.y, freecamPos.z)
    SetCamRot(freecamHandle, freecamPitch, 0.0, freecamYaw, 2)
    SetCamFov(freecamHandle, GetGameplayCamFov())
    RenderScriptCams(true, false, 0, true, true)

    FreezePedForFreecam(myPed)

    isInspectorActive = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        type = 'START_PREVIEW_MODE',
        prop = { name = "Редактор мира (Свободный полёт)" },
        isFreecam = true,
        isWorldEditorFreeMode = true,
        isInspectorActive = false
    })
end

-- Переключение панели каталога
local lastCatalogToggle = 0
function Preview.ToggleCatalog()
    local now = GetGameTimer()
    if now - lastCatalogToggle < 300 then return end
    lastCatalogToggle = now

    if not isWorldEditorActive then return end
    isCatalogOpen = not isCatalogOpen
    if isCatalogOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'OPEN_CATALOG_PANEL' })
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CLOSE_CATALOG_PANEL' })
    end
end

function Preview.CloseCatalog()
    isCatalogOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_CATALOG_PANEL' })
    if isWorldEditorActive and (not ghostEntity or not DoesEntityExist(ghostEntity)) then
        SendNUIMessage({
            type = 'START_PREVIEW_MODE',
            prop = { name = "Редактор мира (Свободный полёт)" },
            isFreecam = true,
            isWorldEditorFreeMode = true,
            isInspectorActive = isInspectorActive
        })
    end
end

-- =================================================================
-- 2. ЗАПУСК ПРЕДПРОСМОТРА ОБЪЕКТА (ИЗ КАТАЛОГА / ИНВЕНТАРЯ)
-- =================================================================
function Preview.Start(propData, initialRot)
    if isPreviewActive and ghostEntity and DoesEntityExist(ghostEntity) then
        DeleteEntity(ghostEntity)
        ghostEntity = nil
    end

    Preview.CloseCatalog()

    if type(propData) ~= "table" then
        propData = { model = propData, name = tostring(propData) }
    end

    local rawModel = tostring(propData.model or propData.modelName or propData.hash or ""):gsub("%s+", "")
    local modelHash = nil
    if rawModel:sub(1, 2):lower() == "0x" then
        modelHash = tonumber(rawModel)
    elseif tonumber(rawModel) and not rawModel:find("%a") then
        modelHash = tonumber(rawModel)
    else
        modelHash = GetHashKey(rawModel)
    end

    local isLoaded = LoadModelSafely(modelHash)

    if not isLoaded then
        print(string.format("^1[HUNT BUILDER] Ошибка: модель '%s' (0x%X) не найдена в файлах игры!^7", tostring(propData.model or propData.name), modelHash or 0))
        TriggerEvent("thehunt_status:notify", "Ошибка", "Модель не найдена в файлах игры", "error", 3500)
        return
    end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local myHeading = GetEntityHeading(myPed)
    local isFromInv = (propData and propData.fromInventory and propData.itemName) and true or false
    local propMetadata = DecodeMetadata(propData.metadata)
    local isDoorObject = IsDoorProp(propData)

    if IsDynamicMetadata(propMetadata) or propData.physicsMode == "dynamic" then
        propData.physicsMode = "dynamic"
    end
    if isDoorObject then
        propData.doorMode = true
    end

    local entityType = (propData and propData.entityType) or (IsModelAPed(modelHash) and "ped") or (IsModelAVehicle(modelHash) and "vehicle") or "object"

    local spawnCoords = (isWorldEditorActive or isFreecamMode) and freecamPos or myCoords
    local spawnHeading = (isWorldEditorActive or isFreecamMode) and freecamYaw or myHeading

    -- Создаем контролируемый призрак
    if entityType == "ped" or IsModelAPed(modelHash) then
        ghostEntity = CreatePed(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, false, false, false, false)
        if DoesEntityExist(ghostEntity) then
            SetEntityAlpha(ghostEntity, 165)
            SetEntityCollision(ghostEntity, false, false)
            SetEntityInvincible(ghostEntity, true)
            FreezeEntityPosition(ghostEntity, true)
            SetBlockingOfNonTemporaryEvents(ghostEntity, true)
            SetPedCanRagdoll(ghostEntity, false)
        end
    elseif entityType == "vehicle" or IsModelAVehicle(modelHash) then
        ghostEntity = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading, false, false)
        if DoesEntityExist(ghostEntity) then
            SetEntityAlpha(ghostEntity, 165)
            SetEntityCollision(ghostEntity, false, false)
            SetEntityInvincible(ghostEntity, true)
            FreezeEntityPosition(ghostEntity, true)
        end
    else
        ghostEntity = CreatePreviewObject(modelHash, spawnCoords, spawnHeading, isDoorObject)
        if DoesEntityExist(ghostEntity) then
            ConfigurePreviewObject(ghostEntity)
        end
    end

    if not DoesEntityExist(ghostEntity) then return end

    currentPropInfo = propData
    if initialRot then
        currentPitch = initialRot.x or 0.0
        currentRoll = initialRot.y or 0.0
        currentHeading = initialRot.z or spawnHeading
    else
        currentHeading = spawnHeading
        currentPitch = 0.0
        currentRoll = 0.0
    end
    heightOffset = 0.0
    distanceOffset = isFromInv and DEFAULT_ITEM_DISTANCE or 5.0
    originalMovingData = nil
    initialTransform = {
        heading = currentHeading,
        pitch = currentPitch,
        roll = currentRoll,
        heightOffset = 0.0,
        distanceOffset = distanceOffset
    }

    if not isFromInv then
        isFreecamMode = true
        if not freecamHandle or not DoesCamExist(freecamHandle) then
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            freecamPos = camCoords
            freecamPitch = camRot.x
            freecamYaw = camRot.z

            freecamHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamCoord(freecamHandle, freecamPos.x, freecamPos.y, freecamPos.z)
            SetCamRot(freecamHandle, freecamPitch, 0.0, freecamYaw, 2)
            SetCamFov(freecamHandle, GetGameplayCamFov())
            RenderScriptCams(true, false, 0, true, true)
        end
        FreezePedForFreecam(myPed)
    else
        isFreecamMode = false
    end

    isPreviewActive = true

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        type = 'START_PREVIEW_MODE',
        prop = propData,
        isFreecam = isFreecamMode or isWorldEditorActive,
        isWorldEditorFreeMode = false,
        isSnapping = isSnappingEnabled,
        isDynamic = currentPropInfo and currentPropInfo.physicsMode == "dynamic" or false
    })
end

-- 3. Запуск копирования объекта
function Preview.StartCopy(entity)
    if not DoesEntityExist(entity) then return end

    local modelHash = Raycast.NormalizeModelHash(GetEntityModel(entity))
    local rot = GetEntityRotation(entity, 2)
    local customProp = Streamer.GetPropInfoByEntity(entity)
    local name = customProp and customProp.name or "Копия объекта"

    local entityCoords = GetEntityCoords(entity)
    local metadata = DecodeMetadata(customProp and customProp.metadata)
    local copyData = {
        name = name,
        model = modelHash,
        modelName = customProp and customProp.model_name or nil,
        metadata = metadata,
        physicsMode = IsDynamicMetadata(metadata) and "dynamic" or nil,
        doorMode = IsDoorProp({
            modelName = customProp and customProp.model_name or nil,
            name = name,
            doorMode = metadata.door_mode == true
        })
    }

    originalMovingData = nil
    Preview.Start(copyData, rot)
end

-- 4. Запуск перемещения существующего объекта
function Preview.StartMoving(entity, propId)
    if pendingWorldMove then
        TriggerEvent("thehunt_status:notify", "Builder", "Дождитесь сохранения предыдущего перемещения", "warning", 2500)
        return
    end
    if not DoesEntityExist(entity) then return end

    local modelHash = Raycast.NormalizeModelHash(GetEntityModel(entity))
    local coords = GetEntityCoords(entity)
    local rot = GetEntityRotation(entity, 2)
    -- Spatial similarity is not proof of ownership: a map prop beside an equal
    -- builder prop must follow the world-prop persistence path.
    local customProp = Streamer.GetPropInfoByEntity(entity, false)
    if customProp and customProp.id then
        propId = customProp.id
    end

    local propMetadata = DecodeMetadata(customProp and customProp.metadata)
    local propModelName = customProp and (customProp.model_name or customProp.name) or nil
    local isDoorObject = IsDoorProp({
        modelName = propModelName,
        doorMode = propMetadata.door_mode == true
    })
    local isDynamicObject = IsDynamicMetadata(propMetadata)

    Preview.CloseCatalog()
    Raycast.ClearHighlight()

    originalMovingData = {
        entity = entity,
        propId = propId,
        isCustom = (propId ~= nil),
        modelHash = modelHash,
        coords = coords,
        rot = rot,
        original_x = customProp and customProp.original_x or (propId == nil and coords.x or nil),
        original_y = customProp and customProp.original_y or (propId == nil and coords.y or nil),
        original_z = customProp and customProp.original_z or (propId == nil and coords.z or nil),
        original_rx = customProp and customProp.original_rx or (propId == nil and rot.x or nil),
        original_ry = customProp and customProp.original_ry or (propId == nil and rot.y or nil),
        original_rz = customProp and customProp.original_rz or (propId == nil and rot.z or nil),
        metadata = propMetadata,
        physicsMode = isDynamicObject and "dynamic" or nil,
        doorMode = isDoorObject
    }

    local isLoaded = LoadModelSafely(modelHash)
    if not isLoaded then
        print(string.format("^1[HUNT BUILDER] Ошибка: модель 0x%X не найдена в файлах игры!^7", modelHash or 0))
        originalMovingData = nil
        return
    end

    if propId then
        Streamer.SetPropMoving(propId, true)
        SetEntityAlpha(entity, 0, false)
        SetEntityCollision(entity, false, false)
    else
        SetEntityAsMissionEntity(entity, true, true)
        SetEntityAlpha(entity, 0, false)
        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)
    end

    local myPed = PlayerPedId()
    local camCoords = (isWorldEditorActive or isFreecamMode) and freecamPos or GetGameplayCamCoord()
    local camRot = (isWorldEditorActive or isFreecamMode) and vector3(freecamPitch, 0.0, freecamYaw) or GetGameplayCamRot(2)
    local initialDist = #(camCoords - coords)

    local entityType = (customProp and customProp.entity_type) or (IsModelAPed(modelHash) and "ped") or (IsModelAVehicle(modelHash) and "vehicle") or "object"

    if entityType == "ped" or IsModelAPed(modelHash) then
        ghostEntity = CreatePed(modelHash, coords.x, coords.y, coords.z, rot.z or 0.0, false, false, false, false)
        if DoesEntityExist(ghostEntity) then
            SetEntityAlpha(ghostEntity, 165)
            SetEntityCollision(ghostEntity, false, false)
            SetEntityInvincible(ghostEntity, true)
            FreezeEntityPosition(ghostEntity, true)
            SetBlockingOfNonTemporaryEvents(ghostEntity, true)
            SetPedCanRagdoll(ghostEntity, false)
        end
    elseif entityType == "vehicle" or IsModelAVehicle(modelHash) then
        ghostEntity = CreateVehicle(modelHash, coords.x, coords.y, coords.z, rot.z or 0.0, false, false)
        if DoesEntityExist(ghostEntity) then
            SetEntityAlpha(ghostEntity, 165)
            SetEntityCollision(ghostEntity, false, false)
            SetEntityInvincible(ghostEntity, true)
            FreezeEntityPosition(ghostEntity, true)
        end
    else
        ghostEntity = CreatePreviewObject(modelHash, coords, rot.z or 0.0, isDoorObject)
        if DoesEntityExist(ghostEntity) then
            ConfigurePreviewObject(ghostEntity)
        end
    end

    if not DoesEntityExist(ghostEntity) then
        if propId then Streamer.SetPropMoving(propId, false) end
        originalMovingData = nil
        return
    end

    local propLabel = propId and string.format("Объект #%s", tostring(propId)) or (customProp and customProp.name) or "Объект мира"
    currentPropInfo = {
        model = modelHash,
        modelName = propModelName,
        name = propLabel,
        entityType = entityType,
        metadata = propMetadata,
        physicsMode = isDynamicObject and "dynamic" or nil,
        doorMode = isDoorObject
    }
    currentHeading = rot.z
    currentPitch = rot.x
    currentRoll = rot.y
    heightOffset = 0.0
    distanceOffset = math.min(35.0, math.max(2.0, initialDist))
    initialTransform = {
        heading = currentHeading,
        pitch = currentPitch,
        roll = currentRoll,
        heightOffset = 0.0,
        distanceOffset = distanceOffset
    }

    isFreecamMode = true
    if not freecamHandle or not DoesCamExist(freecamHandle) then
        freecamPos = camCoords
        freecamPitch = camRot.x
        freecamYaw = camRot.z

        freecamHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(freecamHandle, freecamPos.x, freecamPos.y, freecamPos.z)
        SetCamRot(freecamHandle, freecamPitch, 0.0, freecamYaw, 2)
        SetCamFov(freecamHandle, GetGameplayCamFov())
        RenderScriptCams(true, false, 0, true, true)
    end

    FreezePedForFreecam(myPed)
    isPreviewActive = true

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        type = 'START_PREVIEW_MODE',
        prop = currentPropInfo,
        isFreecam = true,
        isWorldEditorFreeMode = false,
        isSnapping = isSnappingEnabled,
        isDynamic = currentPropInfo and currentPropInfo.physicsMode == "dynamic" or false
    })
end

-- 5. Отмена выбора пропа / сброс к режиму свободного полета
function Preview.Stop()
    Raycast.ClearHighlight()
    if isPreviewActive then
        if originalMovingData then
            if originalMovingData.isCustom then
                Streamer.SetPropMoving(originalMovingData.propId, false)
                if originalMovingData.entity and DoesEntityExist(originalMovingData.entity) then
                    SetEntityAlpha(originalMovingData.entity, 255, false)
                    SetEntityCollision(originalMovingData.entity, true, true)
                    if Streamer.ApplyPlacedEntityMode then
                        Streamer.ApplyPlacedEntityMode(originalMovingData.entity, originalMovingData.metadata)
                    else
                        FreezeEntityPosition(originalMovingData.entity, true)
                    end
                end
            else
                Streamer.RemoveTemporaryDeletedWorldProp(originalMovingData.coords, originalMovingData.modelHash)
                if originalMovingData.entity and DoesEntityExist(originalMovingData.entity) then
                    SetEntityAlpha(originalMovingData.entity, 255, false)
                    SetEntityCollision(originalMovingData.entity, true, true)
                    FreezeEntityPosition(originalMovingData.entity, true)
                else
                    local restored = CreatePreviewObject(
                        originalMovingData.modelHash,
                        originalMovingData.coords,
                        originalMovingData.rot.z,
                        originalMovingData.doorMode == true
                    )
                    if DoesEntityExist(restored) then
                        SetEntityRotation(restored, originalMovingData.rot.x, originalMovingData.rot.y, originalMovingData.rot.z, 2, true)
                        SetEntityCoordsNoOffset(restored, originalMovingData.coords.x, originalMovingData.coords.y, originalMovingData.coords.z, false, false, false)
                        FreezeEntityPosition(restored, true)
                    end
                end
            end
        end

        if ghostEntity and DoesEntityExist(ghostEntity) then
            DeleteEntity(ghostEntity)
        end

        ghostEntity = nil
        currentPropInfo = nil
        originalMovingData = nil
        isPreviewActive = false
        isKeyArrowUp = false
        isKeyArrowDown = false
        isKeyArrowLeft = false
        isKeyArrowRight = false

        if isWorldEditorActive then
            -- Возвращаемся в чистый режим свободной камеры редактора мира с сохранением состояния инспектора
            SendNUIMessage({
                type = 'START_PREVIEW_MODE',
                prop = { name = "Редактор мира (Свободный полёт)" },
                isFreecam = true,
                isWorldEditorFreeMode = true,
                isInspectorActive = isInspectorActive
            })
        else
            if isFreecamMode then
                if freecamHandle and DoesCamExist(freecamHandle) then
                    RenderScriptCams(false, false, 0, true, true)
                    SetCamActive(freecamHandle, false)
                    DestroyCam(freecamHandle, true)
                    freecamHandle = nil
                end
                isFreecamMode = false
                UnfreezePedFromFreecam(PlayerPedId())
            end
            SendNUIMessage({ type = 'STOP_PREVIEW_MODE' })
        end
    end
end

-- 6. Полный выход из режима Редактора мира
function Preview.StopWorldEditor()
    Streamer.NotifyEditorExit() -- Запрещаем стримеру деспавнить пропы 5 секунд
    Raycast.ClearHighlight()
    if ghostEntity and DoesEntityExist(ghostEntity) then
        DeleteEntity(ghostEntity)
    end
    ghostEntity = nil
    currentPropInfo = nil
    originalMovingData = nil
    isPreviewActive = false
    isCatalogOpen = false
    isInspectorActive = false

    -- Сохраняем позицию камеры ДО уничтожения, чтобы телепортировать педа
    local exitPos = freecamPos

    if freecamHandle and DoesCamExist(freecamHandle) then
        RenderScriptCams(false, false, 0, true, true)
        SetCamActive(freecamHandle, false)
        DestroyCam(freecamHandle, true)
        freecamHandle = nil
    end

    isFreecamMode = false
    isWorldEditorActive = false

    local myPed = PlayerPedId()

    -- КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: Телепортируем педа к позиции свободной камеры.
    -- Без этого стример считает расстояние от педа (который стоит на месте входа в редактор)
    -- и удаляет все пропы, установленные далеко от него.
    if exitPos and #(exitPos - vector3(0, 0, 0)) > 2.0 then
        -- Выполняем луч СТРОГО вниз от камеры, чтобы найти пол внутри дома/интерьера, а не крышу здания
        local rayStart = vector3(exitPos.x, exitPos.y, exitPos.z + 0.1)
        local rayEnd = vector3(exitPos.x, exitPos.y, exitPos.z - 4.5)
        local ray = Raycast.CastFromCoords(rayStart, rayEnd)

        local targetZ = exitPos.z - 0.95
        if ray.hit and ray.coords then
            targetZ = ray.coords.z + 0.05
        else
            -- Проверяем поверхность земли/пола строго НИЖЕ уровня камеры
            local groundFound, groundZ = GetGroundZFor_3dCoord(exitPos.x, exitPos.y, exitPos.z, false)
            if groundFound and groundZ <= (exitPos.z + 0.3) then
                targetZ = groundZ + 0.05
            end
        end

        SetEntityCoordsNoOffset(myPed, exitPos.x, exitPos.y, targetZ, false, false, false)
    end

    UnfreezePedFromFreecam(myPed)

    Streamer.NotifyEditorExit()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'STOP_WORLD_EDITOR' })
end

-- 7. Фиксация и сохранение объекта в базу данных
function Preview.PlaceAndSave()
    Raycast.ClearHighlight()
    if not isPreviewActive or not ghostEntity or not DoesEntityExist(ghostEntity) then
        Preview.Stop()
        return
    end
    isPreviewActive = false

    local coords = GetEntityCoords(ghostEntity)
    local rot = GetEntityRotation(ghostEntity, 2)
    local modelHash = Raycast.NormalizeModelHash(GetEntityModel(ghostEntity))
    local placementMeta = BuildPlacementMetadata()

    if coords.z < -200.0 or modelHash == 0 then
        print("^1[HUNT BUILDER] Ошибка: недопустимые координаты или модель! Размещение отменено.^7")
        Preview.Stop()
        return
    end

    if originalMovingData then
        if originalMovingData.isCustom then
            Streamer.SetPropMoving(originalMovingData.propId, false)
            if originalMovingData.entity and DoesEntityExist(originalMovingData.entity) and originalMovingData.entity ~= ghostEntity then
                DeleteEntity(originalMovingData.entity)
            end

            SetEntityAlpha(ghostEntity, 255, false)
            SetEntityCollision(ghostEntity, true, true)
            if Streamer.ApplyPlacedEntityMode then
                Streamer.ApplyPlacedEntityMode(ghostEntity, placementMeta)
            else
                FreezeEntityPosition(ghostEntity, true)
            end
            SetEntityAsMissionEntity(ghostEntity, true, true)
            SetEntityLodDist(ghostEntity, math.floor(tonumber(Config.EntityLodDistance) or 600))
            Streamer.SetSpawnedEntity(originalMovingData.propId, ghostEntity)
            Streamer.UpdateLocalPropPos(originalMovingData.propId, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z)

            TriggerServerEvent("thehunt_builder:updateObjectPos", originalMovingData.propId, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, placementMeta)
            ghostEntity = nil
        else
            local hideX = originalMovingData.original_x or originalMovingData.coords.x
            local hideY = originalMovingData.original_y or originalMovingData.coords.y
            local hideZ = originalMovingData.original_z or originalMovingData.coords.z

            -- Keep the source hidden locally until the server confirms the
            -- transaction. A failed save can then roll back cleanly.
            SetEntityAlpha(ghostEntity, 255, false)
            SetEntityCollision(ghostEntity, true, true)
            FreezeEntityPosition(ghostEntity, true)
            SetEntityAsMissionEntity(ghostEntity, true, true)
            pendingWorldMove = {
                originalEntity = originalMovingData.entity,
                ghostEntity = ghostEntity
            }

            TriggerServerEvent("thehunt_builder:moveWorldStaticObject", {
                model_name = "Перемещенный объект",
                model_hash = modelHash,
                original_model_hash = originalMovingData.modelHash,
                x = coords.x,
                y = coords.y,
                z = coords.z,
                rot_x = rot.x,
                rot_y = rot.y,
                rot_z = rot.z,
                original_x = hideX,
                original_y = hideY,
                original_z = hideZ,
                original_rx = originalMovingData.original_rx,
                original_ry = originalMovingData.original_ry,
                original_rz = originalMovingData.original_rz,
                metadata = next(placementMeta) and placementMeta or nil
            })
            ghostEntity = nil
        end
    else
        local isFromInv = (currentPropInfo and currentPropInfo.fromInventory and currentPropInfo.itemName) and true or false
        if isFromInv then
            local myPed = PlayerPedId()
            local pedCoords = GetEntityCoords(myPed)
            local placeDist = #(coords - pedCoords)
            if placeDist > (MAX_ITEM_DISTANCE + 0.8) then
                TriggerEvent("thehunt_status:notify", "Ошибка", "Слишком далеко от персонажа!", "error", 2500)
                Preview.Stop()
                return
            end
        end
        local entityType = (currentPropInfo and currentPropInfo.entityType) or (IsModelAPed(modelHash) and "ped") or (IsModelAVehicle(modelHash) and "vehicle") or "object"
        local scenario = currentPropInfo and currentPropInfo.scenario
        local metaObj = placementMeta
        if isFromInv and currentPropInfo and currentPropInfo.metadata and type(currentPropInfo.metadata) == "table" then
            for k, v in pairs(currentPropInfo.metadata) do
                if metaObj[k] == nil then
                    metaObj[k] = v
                end
            end
        end
        if entityType ~= "object" and not metaObj.entity_type then
            metaObj.entity_type = entityType
        end
        if scenario and scenario ~= "" and scenario ~= "none" and not metaObj.scenario then
            metaObj.scenario = scenario
        end
        local hasMeta = next(metaObj) ~= nil

        TriggerServerEvent("thehunt_builder:placeObject", {
            model_name = currentPropInfo and currentPropInfo.name or (entityType == "ped" and "NPC" or (entityType == "vehicle" and "Транспорт" or "Объект")),
            model_hash = modelHash,
            item_name = isFromInv and currentPropInfo.itemName or nil,
            dbId = isFromInv and currentPropInfo.dbId or nil,
            metadata = hasMeta and metaObj or nil,
            is_player_item = isFromInv and 1 or 0,
            is_protected = (currentPropInfo and currentPropInfo.isProtected == true) and 1 or 0,
            from_inventory = isFromInv,
            x = coords.x,
            y = coords.y,
            z = coords.z,
            rot_x = rot.x,
            rot_y = rot.y,
            rot_z = rot.z
        })

        Streamer.RegisterLivePlacedEntity(ghostEntity, coords, rot, modelHash, metaObj)
        ghostEntity = nil
    end

    currentPropInfo = nil
    originalMovingData = nil
    isPreviewActive = false
    isKeyArrowUp = false
    isKeyArrowDown = false
    isKeyArrowLeft = false
    isKeyArrowRight = false

    if isWorldEditorActive then
        -- Возвращаемся в режим свободной камеры редактора мира с сохранением состояния инспектора
        SendNUIMessage({
            type = 'START_PREVIEW_MODE',
            prop = { name = "Редактор мира (Свободный полёт)" },
            isFreecam = true,
            isWorldEditorFreeMode = true,
            isInspectorActive = isInspectorActive
        })
    else
        if isFreecamMode then
            Streamer.NotifyEditorExit() -- Grace period для деспавна при выходе из камеры
            if freecamHandle and DoesCamExist(freecamHandle) then
                RenderScriptCams(false, false, 0, true, true)
                SetCamActive(freecamHandle, false)
                DestroyCam(freecamHandle, true)
                freecamHandle = nil
            end
            isFreecamMode = false
            UnfreezePedFromFreecam(PlayerPedId())
        end
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'STOP_PREVIEW_MODE' })
    end
end

-- =================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ОПРОСА ВВОДА
-- =================================================================
local function IsKeyActive(hash)
    if not hash then return false end
    return IsControlPressed(0, hash) or IsDisabledControlPressed(0, hash)
        or IsControlPressed(1, hash) or IsDisabledControlPressed(1, hash)
        or IsControlPressed(2, hash) or IsDisabledControlPressed(2, hash)
end

function Preview.TogglePlacementPhysics()
    if not isPreviewActive or not currentPropInfo then return end
    if currentPropInfo.entityType and currentPropInfo.entityType ~= "object" then
        TriggerEvent("thehunt_status:notify", "Builder", "Physics mode is available for objects only", "warning", 2500)
        return
    end

    local enablePhysics = currentPropInfo.physicsMode ~= "dynamic"
    currentPropInfo.physicsMode = enablePhysics and "dynamic" or nil

    -- Recreate door-like ghosts so the native CreateObject door flag is also
    -- applied when a map door was picked from the world editor.
    if currentPropInfo.doorMode == true then
        RebuildGhostForPlacementMode()
    end

    SendNUIMessage({
        type = 'UPDATE_PHYSICS_STATE',
        isDynamic = enablePhysics
    })
    TriggerEvent(
        "thehunt_status:notify",
        "Builder",
        enablePhysics and "Active physics enabled" or "Static mode enabled",
        "info",
        2200
    )
end

RegisterCommand('+builder_toggle_physics', function()
    Preview.TogglePlacementPhysics()
end, false)
RegisterCommand('-builder_toggle_physics', function() end, false)

local isKeyArrowUp = false
local isKeyArrowDown = false
local isKeyArrowLeft = false
local isKeyArrowRight = false
local isKeyUpActive = false
local isKeyDownActive = false

RegisterCommand('+builder_cam_up', function()
    if isWorldEditorActive or isFreecamMode then isKeyUpActive = true end
end, false)
RegisterCommand('-builder_cam_up', function()
    isKeyUpActive = false
end, false)

RegisterCommand('+builder_cam_down', function()
    if isWorldEditorActive or isFreecamMode then isKeyDownActive = true end
end, false)
RegisterCommand('-builder_cam_down', function()
    isKeyDownActive = false
end, false)

RegisterCommand('+builder_pitch_up', function()
    if isPreviewActive then isKeyArrowUp = true end
end, false)
RegisterCommand('-builder_pitch_up', function()
    isKeyArrowUp = false
end, false)

RegisterCommand('+builder_pitch_down', function()
    if isPreviewActive then isKeyArrowDown = true end
end, false)
RegisterCommand('-builder_pitch_down', function()
    isKeyArrowDown = false
end, false)

RegisterCommand('+builder_roll_left', function()
    if isPreviewActive then isKeyArrowLeft = true end
end, false)
RegisterCommand('-builder_roll_left', function()
    isKeyArrowLeft = false
end, false)

RegisterCommand('+builder_roll_right', function()
    if isPreviewActive then isKeyArrowRight = true end
end, false)
RegisterCommand('-builder_roll_right', function()
    isKeyArrowRight = false
end, false)

local lastCatalogToggle = 0
local function ToggleCatalogDebounced()
    local now = GetGameTimer()
    if now - lastCatalogToggle < 300 then return end
    lastCatalogToggle = now
    if isWorldEditorActive then
        Preview.ToggleCatalog()
    end
end

RegisterCommand('+builder_catalog_toggle', ToggleCatalogDebounced, false)
RegisterCommand('-builder_catalog_toggle', function() end, false)

local lastInspectorToggle = 0
local function ToggleInspectorMode()
    local now = GetGameTimer()
    if now - lastInspectorToggle < 300 then return end
    lastInspectorToggle = now

    if isWorldEditorActive and (not ghostEntity or not DoesEntityExist(ghostEntity)) then
        isInspectorActive = not isInspectorActive
        if not isInspectorActive then
            Raycast.ClearHighlight()
        end
        SendNUIMessage({
            type = 'UPDATE_INSPECTOR_STATE',
            isInspectorActive = isInspectorActive
        })
    end
end

RegisterCommand('+builder_inspector_toggle', ToggleInspectorMode, false)
RegisterCommand('-builder_inspector_toggle', function() end, false)

local lastNearbyToggle = 0
RegisterCommand('+builder_nearby_toggle', function()
    local now = GetGameTimer()
    if now - lastNearbyToggle < 300 then return end
    lastNearbyToggle = now
    if isWorldEditorActive and not isCatalogOpen then
        Preview.OpenNearbyProps()
    end
end, false)
RegisterCommand('-builder_nearby_toggle', function() end, false)

-- Функция удаления объекта, наведенного в инспекторе (вызывается ТОЛЬКО по Backspace / Delete)
local lastDeleteTargetTime = 0
function Preview.DeleteCurrentInspectorTarget()
    -- СТРОЖАЙШАЯ ЗАЩИТА: Если нажат ESC, ни в коем случае НЕ удаляем объект!
    if IsControlPressed(0, 0xD82E0BD2) or IsDisabledControlPressed(0, 0xD82E0BD2)
    or IsControlPressed(2, 0xD82E0BD2) or IsDisabledControlPressed(2, 0xD82E0BD2)
    or IsControlJustPressed(0, 0xD82E0BD2) or IsDisabledControlJustPressed(0, 0xD82E0BD2)
    or IsControlJustPressed(2, 0xD82E0BD2) or IsDisabledControlJustPressed(2, 0xD82E0BD2) then
        return
    end

    if not isWorldEditorActive or not isInspectorActive or isPreviewActive or isCatalogOpen then return end

    local now = GetGameTimer()
    if now - lastDeleteTargetTime < 400 then return end
    lastDeleteTargetTime = now

    local myPed = PlayerPedId()
    local radZ = math.rad(freecamYaw)
    local radX = math.rad(freecamPitch)
    local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
    local targetEntity = Raycast.GetTargetEntityFromRay(freecamPos, forward, 60.0)

    if targetEntity and DoesEntityExist(targetEntity) and targetEntity ~= myPed then
        local customProp = Streamer.GetPropInfoByEntity(targetEntity)
        if customProp then
            TriggerServerEvent("thehunt_builder:deletePlacedObject", customProp.id)
        else
            local mHash = GetEntityModel(targetEntity)
            local entC = GetEntityCoords(targetEntity)
            SetEntityAsMissionEntity(targetEntity, true, true)
            SetEntityAlpha(targetEntity, 0, false)
            SetEntityCollision(targetEntity, false, false)
            FreezeEntityPosition(targetEntity, true)
            SetEntityCoords(targetEntity, 0.0, 0.0, -2000.0, false, false, false, false)
            DeleteEntity(targetEntity)
            Streamer.AddTemporaryDeletedWorldProp({
                model_hash = mHash,
                x = entC.x,
                y = entC.y,
                z = entC.z
            })
            TriggerServerEvent("thehunt_builder:deleteWorldStaticObject", mHash, entC.x, entC.y, entC.z)
        end
        Raycast.ClearHighlight()
    end
end

RegisterCommand('+builder_delete_prop', Preview.DeleteCurrentInspectorTarget, false)
RegisterCommand('-builder_delete_prop', function() end, false)

local lastExitPress = 0
local function HandleBuilderExit()
    local now = GetGameTimer()
    if now - lastExitPress < 300 then return end
    lastExitPress = now

    if isCatalogOpen then
        Preview.CloseCatalog()
    elseif isPreviewActive and ghostEntity and DoesEntityExist(ghostEntity) then
        Preview.Stop()
    elseif isWorldEditorActive or isFreecamMode then
        Preview.StopWorldEditor()
    end
end

RegisterCommand('+builder_exit', HandleBuilderExit, false)
RegisterCommand('-builder_exit', function() end, false)

if RegisterKeyMapping then
    pcall(RegisterKeyMapping, '+builder_toggle_physics', 'Builder: toggle active physics / door mode', 'keyboard', 'O')
    pcall(RegisterKeyMapping, '+builder_exit', 'Строитель: Выход / Отмена', 'keyboard', 'ESCAPE')
    pcall(RegisterKeyMapping, '+builder_delete_prop', 'Строитель: Удалить объект под прицелом (Del)', 'keyboard', 'DELETE')
    pcall(RegisterKeyMapping, '+builder_catalog_toggle', 'Строитель: Каталог спавна', 'keyboard', 'B')
    pcall(RegisterKeyMapping, '+builder_inspector_toggle', 'Строитель: Инспектор объектов', 'keyboard', 'T')
    pcall(RegisterKeyMapping, '+builder_nearby_toggle', 'Строитель: Объекты в базе', 'keyboard', 'N')
    pcall(RegisterKeyMapping, '+builder_cam_up', 'Строитель: Подъем камеры', 'keyboard', 'SPACE')
    pcall(RegisterKeyMapping, '+builder_cam_down', 'Строитель: Спуск камеры', 'keyboard', 'LCONTROL')
    pcall(RegisterKeyMapping, '+builder_pitch_up', 'Строитель: Наклон вверх', 'keyboard', 'UP')
    pcall(RegisterKeyMapping, '+builder_pitch_down', 'Строитель: Наклон вниз', 'keyboard', 'DOWN')
    pcall(RegisterKeyMapping, '+builder_roll_left', 'Строитель: Крен влево', 'keyboard', 'LEFT')
    pcall(RegisterKeyMapping, '+builder_roll_right', 'Строитель: Крен вправо', 'keyboard', 'RIGHT')
end

local function GetSpeedMultiplier(ticks)
    if ticks <= 30 then
        return 1.0
    elseif ticks <= 80 then
        local progress = (ticks - 30) / 50.0
        return 1.0 + (progress * 2.5)
    else
        return 3.5
    end
end

-- =================================================================
-- ГЛАВНЫЙ ПОТОК: РЕДАКТОР МИРА И РАЗМЕЩЕНИЕ ОБЪЕКТОВ
-- =================================================================
Citizen.CreateThread(function()
    local holdYawZ, holdYawX = 0, 0
    local holdPitchUp, holdPitchDown = 0, 0
    local holdRollLeft, holdRollRight = 0, 0
    local holdHeightQ, holdHeightE = 0, 0
    local holdDistR, holdDistF = 0, 0

    while true do
        if isWorldEditorActive or isPreviewActive then
            Citizen.Wait(0)

            local myPed = PlayerPedId()

            -- Блокируем ВСЕ контрольные действия движка для всех 3-х падов (0, 1, 2)
            for pad = 0, 2 do
                DisableAllControlActions(pad)
            end
            DisablePlayerFiring(myPed, true)

            -- Персонаж надежно зафиксирован на месте без дерганий и звуков поверхности
            if isWorldEditorActive or isFreecamMode then
                SetEntityVelocity(myPed, 0.0, 0.0, 0.0)
            end

            -- 1. Если идет ввод текста в input / textarea — полная блокировка
            if isInputFocused then
                -- Ничего не разблокируем, игрок печатает текст

            -- 2. Если открыта панель каталога / объектов
            elseif isCatalogOpen then
                -- Белый список для работы с UI и рацией
                EnableControlAction(0, 0xA987235F, true) -- Mouse X
                EnableControlAction(0, 0xD2047988, true) -- Mouse Y
                EnableControlAction(0, 0xF1301666, true) -- PTT
                EnableControlAction(0, 0x05CA7C52, true)
                EnableControlAction(0, `INPUT_PUSH_TO_TALK`, true)
                EnableControlAction(0, 0x07CE1E61, true) -- ЛКМ
                EnableControlAction(0, 0xD82E0BD2, true) -- Esc

                if IsControlJustPressed(0, 0xD82E0BD2) or IsDisabledControlJustPressed(0, 0xD82E0BD2) -- Esc
                or IsControlJustPressed(2, 0xD82E0BD2) or IsDisabledControlJustPressed(2, 0xD82E0BD2)
                or IsControlJustPressed(0, 0x4CC0E2FE) or IsDisabledControlJustPressed(0, 0x4CC0E2FE) -- B
                or IsControlJustPressed(0, 0x8AAA0AE4) or IsDisabledControlJustPressed(0, 0x8AAA0AE4) -- B
                or IsControlJustPressed(0, 0x4B3AA7D4) or IsDisabledControlJustPressed(0, 0x4B3AA7D4) then -- N
                    Preview.CloseCatalog()
                end
            else
                -- 3. Белый список для свободной камеры / предпросмотра
                EnableControlAction(0, 0xA987235F, true) -- Mouse X
                EnableControlAction(0, 0xD2047988, true) -- Mouse Y
                EnableControlAction(0, `INPUT_LOOK_LR`, true)
                EnableControlAction(0, `INPUT_LOOK_UD`, true)
                EnableControlAction(0, 0xF1301666, true) -- PTT
                EnableControlAction(0, 0x05CA7C52, true)
                EnableControlAction(0, `INPUT_PUSH_TO_TALK`, true)

                -- Для обычных игроков в режиме размещения предметов от 3-го лица: разрешаем движение персонажа
                if not isWorldEditorActive and not isFreecamMode then
                    EnableControlAction(0, 0x4D8FB4C1, true) -- INPUT_MOVE_LR (A/D)
                    EnableControlAction(0, 0xFDA83190, true) -- INPUT_MOVE_UD (W/S)
                    EnableControlAction(0, `INPUT_MOVE_LR`, true)
                    EnableControlAction(0, `INPUT_MOVE_UD`, true)
                    EnableControlAction(0, 0x8FD015D8, true) -- INPUT_SPRINT (Shift)
                    EnableControlAction(0, `INPUT_SPRINT`, true)
                    EnableControlAction(0, 0xCE736A2D, true) -- INPUT_DUCK (Ctrl / C)
                    EnableControlAction(0, `INPUT_DUCK`, true)
                    EnableControlAction(0, 0xD3939741, true) -- INPUT_JUMP (Space)
                    EnableControlAction(0, `INPUT_JUMP`, true)
                end
                -- -------------------------------------------------------------
                -- РЕЖИМ 1: СВОБОДНАЯ КАМЕРА (АДМИН / РЕДАКТОР МИРА)
                -- -------------------------------------------------------------
                if (isWorldEditorActive or isFreecamMode) and freecamHandle and DoesCamExist(freecamHandle) then
                    -- 1. Обзор мышью
                    local mouseX = GetDisabledControlNormal(0, 0xA987235F)
                    local mouseY = GetDisabledControlNormal(0, 0xD2047988)

                    if mouseX ~= 0.0 or mouseY ~= 0.0 then
                        freecamYaw = (freecamYaw - mouseX * 7.5) % 360.0
                        freecamPitch = math.max(math.min(88.0, freecamPitch - mouseY * 7.5), -88.0)
                    end

                    -- Векторы направления
                    local radZ = math.rad(freecamYaw)
                    local radX = math.rad(freecamPitch)
                    local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
                    local right = vector3(math.cos(radZ), math.sin(radZ), 0.0)
                    local up = vector3(0.0, 0.0, 1.0)

                    -- Скорость перемещения камеры (уменьшена в 2 раза)
                    local moveSpeed = 0.14
                    if IsControlPressed(0, 0x8FF9514F) or IsDisabledControlPressed(0, 0x8FF9514F) or IsControlPressed(1, 0x8FF9514F) then -- Shift (Быстрее)
                        moveSpeed = 0.42
                    elseif IsControlPressed(0, 0x8AAA0AE4) or IsDisabledControlPressed(0, 0x8AAA0AE4) or IsControlPressed(1, 0x8AAA0AE4) then -- Alt (Медленнее)
                        moveSpeed = 0.03
                    end

                    -- Управление полетом камеры (WASD)
                    local isW = IsControlPressed(0, 0x8FD015D8) or IsDisabledControlPressed(0, 0x8FD015D8) or IsControlPressed(1, 0x8FD015D8) or IsDisabledControlPressed(1, 0x8FD015D8)
                    local isS = IsControlPressed(0, 0xD27782E3) or IsDisabledControlPressed(0, 0xD27782E3) or IsControlPressed(1, 0xD27782E3) or IsDisabledControlPressed(1, 0xD27782E3)
                    local isA = IsControlPressed(0, 0x7065027D) or IsDisabledControlPressed(0, 0x7065027D) or IsControlPressed(1, 0x7065027D) or IsDisabledControlPressed(1, 0x7065027D)
                    local isD = IsControlPressed(0, 0xB4E465B4) or IsDisabledControlPressed(0, 0xB4E465B4) or IsControlPressed(1, 0xB4E465B4) or IsDisabledControlPressed(1, 0xB4E465B4)

                    if isW then
                        freecamPos = freecamPos + (forward * moveSpeed)
                    end
                    if isS then
                        freecamPos = freecamPos - (forward * moveSpeed)
                    end
                    if isA then
                        freecamPos = freecamPos - (right * moveSpeed)
                    end
                    if isD then
                        freecamPos = freecamPos + (right * moveSpeed)
                    end

                    -- Подъем (Space) и спуск (Ctrl)
                    local isUp = isKeyUpActive
                        or IsControlPressed(0, 0xD9D0E1C0) or IsDisabledControlPressed(0, 0xD9D0E1C0)
                        or IsControlPressed(0, 0xD9D0F1C8) or IsDisabledControlPressed(0, 0xD9D0F1C8)
                        or IsControlPressed(0, 22) or IsDisabledControlPressed(0, 22)
                        or IsControlPressed(1, 22) or IsDisabledControlPressed(1, 22)
                        or IsControlPressed(2, 22) or IsDisabledControlPressed(2, 22)
                        or IsControlPressed(0, 0x8AAA0AE4) or IsDisabledControlPressed(0, 0x8AAA0AE4)

                    local isDown = isKeyDownActive
                        or IsControlPressed(0, 0xDB096B85) or IsDisabledControlPressed(0, 0xDB096B85)
                        or IsControlPressed(0, 0xCE736A2D) or IsDisabledControlPressed(0, 0xCE736A2D)
                        or IsControlPressed(0, 36) or IsDisabledControlPressed(0, 36)
                        or IsControlPressed(1, 36) or IsDisabledControlPressed(1, 36)
                        or IsControlPressed(2, 36) or IsDisabledControlPressed(2, 36)

                    if isUp then
                        freecamPos = freecamPos + (up * moveSpeed)
                    end
                    if isDown then
                        freecamPos = freecamPos - (up * moveSpeed)
                    end

                    SetCamCoord(freecamHandle, freecamPos.x, freecamPos.y, freecamPos.z)
                    SetCamRot(freecamHandle, freecamPitch, 0.0, freecamYaw, 2)

                    -- Клавиша B (0x4CC0E2FE / 0x8AAA0AE4): Открыть каталог объектов
                    if IsControlJustPressed(0, 0x4CC0E2FE) or IsDisabledControlJustPressed(0, 0x4CC0E2FE)
                    or IsControlJustPressed(0, 0x8AAA0AE4) or IsDisabledControlJustPressed(0, 0x8AAA0AE4) then
                        ToggleCatalogDebounced()
                    end

                    -- Клавиша N (0x4B3AA7D4): Открыть объекты в зоне вокруг камеры
                    if IsControlJustPressed(0, 0x4B3AA7D4) or IsDisabledControlJustPressed(0, 0x4B3AA7D4) then
                        Preview.OpenNearbyProps()
                    end

                    -- ВАРИАНТ А: УДЕРЖАНИЕ И РАЗМЕЩЕНИЕ ВЫБРАННОГО ПРОПА
                    if ghostEntity and DoesEntityExist(ghostEntity) then
                        local targetPos = nil
                        if isSnappingEnabled then
                            local rayEnd = freecamPos + (forward * (distanceOffset + 8.0))
                            local ray = Raycast.CastFromCoords(freecamPos, rayEnd)
                            targetPos = ray.hit and ray.coords or (freecamPos + (forward * distanceOffset))
                        else
                            targetPos = freecamPos + (forward * distanceOffset)
                        end

                        local finalX = targetPos.x
                        local finalY = targetPos.y
                        local finalZ = targetPos.z + heightOffset

                        SetEntityCoords(ghostEntity, finalX, finalY, finalZ, false, false, false, false)
                        SetEntityRotation(ghostEntity, currentPitch, currentRoll, currentHeading, 2, true)

                        -- Переключение прилипания на G
                        if IsControlJustPressed(0, 0x760A9C6F) or IsDisabledControlJustPressed(0, 0x760A9C6F) then
                            isSnappingEnabled = not isSnappingEnabled
                            SendNUIMessage({
                                type = 'UPDATE_SNAP_STATE',
                                isSnapping = isSnappingEnabled
                            })
                        end

                        -- Вращение Yaw: Z / X
                        if IsKeyActive(0x26E9DC00) then -- Z
                            holdYawZ = holdYawZ + 1
                            currentHeading = (currentHeading + 0.8 * GetSpeedMultiplier(holdYawZ)) % 360.0
                        else
                            holdYawZ = 0
                        end
                        if IsKeyActive(0x8CC9CD42) then -- X
                            holdYawX = holdYawX + 1
                            currentHeading = (currentHeading - 0.8 * GetSpeedMultiplier(holdYawX)) % 360.0
                        else
                            holdYawX = 0
                        end

                        -- Наклон Pitch: Стрелки ↑ / ↓
                        local isPitchUp = isKeyArrowUp or IsKeyActive(0x911CB09E) or IsKeyActive(0x8C989523) or IsKeyActive(172)
                        local isPitchDown = isKeyArrowDown or IsKeyActive(0x4403F97F) or IsKeyActive(0x7DA973E3) or IsKeyActive(173)
                        if isPitchUp then
                            holdPitchUp = holdPitchUp + 1
                            currentPitch = (currentPitch + 0.5 * GetSpeedMultiplier(holdPitchUp)) % 360.0
                        else
                            holdPitchUp = 0
                        end
                        if isPitchDown then
                            holdPitchDown = holdPitchDown + 1
                            currentPitch = (currentPitch - 0.5 * GetSpeedMultiplier(holdPitchDown)) % 360.0
                        else
                            holdPitchDown = 0
                        end

                        -- Крен Roll: Стрелки ← / →
                        local isRollLeft = isKeyArrowLeft or IsKeyActive(0xAD7FE10D) or IsKeyActive(0xA652F503) or IsKeyActive(174)
                        local isRollRight = isKeyArrowRight or IsKeyActive(0x74AC8104) or IsKeyActive(0x1D06CD58) or IsKeyActive(175)
                        if isRollLeft then
                            holdRollLeft = holdRollLeft + 1
                            currentRoll = (currentRoll - 0.5 * GetSpeedMultiplier(holdRollLeft)) % 360.0
                        else
                            holdRollLeft = 0
                        end
                        if isRollRight then
                            holdRollRight = holdRollRight + 1
                            currentRoll = (currentRoll + 0.5 * GetSpeedMultiplier(holdRollRight)) % 360.0
                        else
                            holdRollRight = 0
                        end

                        -- Высота Z: Q / E
                        local isQ = IsControlPressed(0, 0xDE794E3E) or IsDisabledControlPressed(0, 0xDE794E3E)
                        local isE = IsControlPressed(0, 0xCEFD9220) or IsDisabledControlPressed(0, 0xCEFD9220)
                            or IsControlPressed(0, 0xCE6D099E) or IsDisabledControlPressed(0, 0xCE6D099E)
                        if isQ then
                            holdHeightQ = holdHeightQ + 1
                            heightOffset = heightOffset + (0.015 * GetSpeedMultiplier(holdHeightQ))
                        else
                            holdHeightQ = 0
                        end
                        if isE then
                            holdHeightE = holdHeightE + 1
                            heightOffset = heightOffset - (0.015 * GetSpeedMultiplier(holdHeightE))
                        else
                            holdHeightE = 0
                        end

                        -- Дистанция R / F
                        local isR = IsControlPressed(0, 0xE30CD707) or IsDisabledControlPressed(0, 0xE30CD707)
                            or IsControlPressed(0, 0x410CD45F) or IsDisabledControlPressed(0, 0x410CD45F)
                        local isF = IsControlPressed(0, 0xB2F377E8) or IsDisabledControlPressed(0, 0xB2F377E8)
                        if isR then
                            holdDistR = holdDistR + 1
                            distanceOffset = math.min(45.0, distanceOffset + (0.04 * GetSpeedMultiplier(holdDistR)))
                        else
                            holdDistR = 0
                        end
                        if isF then
                            holdDistF = holdDistF + 1
                            distanceOffset = math.max(1.0, distanceOffset - (0.04 * GetSpeedMultiplier(holdDistF)))
                        else
                            holdDistF = 0
                        end

                        -- ЛКМ / Enter -> Установить объект
                        if IsControlJustPressed(0, 0x07CE1E61) or IsDisabledControlJustPressed(0, 0x07CE1E61)
                        or IsControlJustPressed(0, 0xC7B5340A) or IsDisabledControlJustPressed(0, 0xC7B5340A) then
                            Preview.PlaceAndSave()
                        end

                        -- ПКМ / Esc -> Снять выбор пропа
                        if IsControlJustPressed(0, 0xF84FA74F) or IsDisabledControlJustPressed(0, 0xF84FA74F)
                        or IsControlJustPressed(0, 0xD82E0BD2) or IsDisabledControlJustPressed(0, 0xD82E0BD2)
                        or IsControlJustPressed(2, 0xD82E0BD2) or IsDisabledControlJustPressed(2, 0xD82E0BD2) then
                            Preview.Stop()
                        end

                    -- ВАРИАНТ Б: ЧИСТЫЙ РЕЖИМ СВОБОДНОЙ КАМЕРЫ
                    else
                        -- Переключение инспектора на клавишу T (0x20A91360 / 0x9720FCEE)
                        if IsControlJustPressed(0, 0x20A91360) or IsDisabledControlJustPressed(0, 0x20A91360)
                        or IsControlJustPressed(0, 0x9720FCEE) or IsDisabledControlJustPressed(0, 0x9720FCEE) then
                            ToggleInspectorMode()
                        end

                        -- Открытие объектов в зоне вокруг камеры на клавишу N
                        if IsControlJustPressed(0, 0x4B3AA7D4) or IsDisabledControlJustPressed(0, 0x4B3AA7D4) then
                            Preview.OpenNearbyProps()
                        end

                        if isInspectorActive then
                            local targetEntity = Raycast.GetTargetEntityFromRay(freecamPos, forward, 60.0)

                            if targetEntity and DoesEntityExist(targetEntity) and targetEntity ~= myPed then
                                Raycast.DrawObjectInspectorInfo(targetEntity)

                                -- E: Взять наведенный объект в режим перемещения
                                if IsControlJustPressed(0, 0xCE6D099E) or IsDisabledControlJustPressed(0, 0xCE6D099E)
                                or IsControlJustPressed(0, 0xCEFD9220) or IsDisabledControlJustPressed(0, 0xCEFD9220) then
                                    local customProp = Streamer.GetPropInfoByEntity(targetEntity)
                                    local propId = customProp and customProp.id or nil
                                    Preview.StartMoving(targetEntity, propId)
                                end

                                -- C: Клонировать наведенный объект
                                if IsControlJustPressed(0, 0x9959A6F0) or IsDisabledControlJustPressed(0, 0x9959A6F0)
                                or IsControlJustPressed(0, 0xCE73484A) or IsDisabledControlJustPressed(0, 0xCE73484A) then
                                    Preview.StartCopy(targetEntity)
                                end

                                -- Delete key (0x4AF4D473): Удалить объект под прицелом
                                if IsControlJustPressed(0, 0x4AF4D473) or IsDisabledControlJustPressed(0, 0x4AF4D473) then
                                    Preview.DeleteCurrentInspectorTarget()
                                end
                            end
                        end

                        -- Esc: Выйти из редактора мира полностью (ТОЛЬКО ESC)
                        if IsControlJustPressed(0, 0xD82E0BD2) or IsDisabledControlJustPressed(0, 0xD82E0BD2)
                        or IsControlJustPressed(2, 0xD82E0BD2) or IsDisabledControlJustPressed(2, 0xD82E0BD2) then
                            Preview.StopWorldEditor()
                        end
                    end
                else
                    -- -------------------------------------------------------------
                    -- РЕЖИМ 2: ПРЕДПРОСМОТР ПРЕДМЕТА ИЗ ИНВЕНТАРЯ (3-е лицо)
                    -- Ограничение дистанции: строго 0.8м .. 2.5м (макс. 2-3м)
                    -- -------------------------------------------------------------
                    if ghostEntity and DoesEntityExist(ghostEntity) then
                        local myPed = PlayerPedId()
                        local pedCoords = GetEntityCoords(myPed)
                        local camCoords = GetGameplayCamCoord()
                        local camRot = GetGameplayCamRot(2)
                        local radZ = math.rad(camRot.z)
                        local radX = math.rad(camRot.x)
                        local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
                        local flatForward = vector3(-math.sin(radZ), math.cos(radZ), 0.0)
                        local flatLen = #(flatForward)
                        if flatLen > 0.001 then
                            flatForward = flatForward / flatLen
                        else
                            flatForward = vector3(0.0, 1.0, 0.0)
                        end

                        -- Гарантируем, что текущая дистанция строго в пределах [MIN_ITEM_DISTANCE, MAX_ITEM_DISTANCE]
                        local clampedDist = math.max(MIN_ITEM_DISTANCE, math.min(MAX_ITEM_DISTANCE, distanceOffset))
                        distanceOffset = clampedDist

                        local targetPos = nil
                        if isSnappingEnabled then
                            local ray = Raycast.CastFromCamera(35.0)
                            local hitValid = false

                            if ray.hit and ray.coords then
                                local toHit2D = vector2(ray.coords.x - pedCoords.x, ray.coords.y - pedCoords.y)
                                local dist2D = #(toHit2D)
                                local dz = math.abs(ray.coords.z - pedCoords.z)

                                -- Если точка луча близко к игроку (в пределах дистанции clampedDist и перепада высоты до 2м)
                                if dist2D <= clampedDist and dz <= 2.0 then
                                    targetPos = ray.coords
                                    hitValid = true
                                else
                                    -- Если игрок смотрит вдаль (дальше clampedDist),
                                    -- проецируем точку строго на дистанцию clampedDist в направлении взгляда
                                    local dir2D = (dist2D > 0.05) and (toHit2D / dist2D) or vector2(flatForward.x, flatForward.y)
                                    local probeX = pedCoords.x + dir2D.x * clampedDist
                                    local probeY = pedCoords.y + dir2D.y * clampedDist

                                    local probeStart = vector3(probeX, probeY, pedCoords.z + 1.5)
                                    local probeEnd = vector3(probeX, probeY, pedCoords.z - 3.5)
                                    local groundRay = Raycast.CastFromCoords(probeStart, probeEnd)
                                    if groundRay.hit and groundRay.coords then
                                        targetPos = groundRay.coords
                                        hitValid = true
                                    else
                                        local foundGround, groundZ = GetGroundZFor_3dCoord(probeX, probeY, pedCoords.z + 2.0, false)
                                        if foundGround and groundZ >= (pedCoords.z - 3.0) and groundZ <= (pedCoords.z + 2.0) then
                                            targetPos = vector3(probeX, probeY, groundZ)
                                            hitValid = true
                                        end
                                    end
                                end
                            end

                            if not hitValid then
                                -- Запасной вариант: берем направление взгляда перед педом
                                local probeX = pedCoords.x + flatForward.x * clampedDist
                                local probeY = pedCoords.y + flatForward.y * clampedDist
                                local probeStart = vector3(probeX, probeY, pedCoords.z + 1.5)
                                local probeEnd = vector3(probeX, probeY, pedCoords.z - 3.5)
                                local groundRay = Raycast.CastFromCoords(probeStart, probeEnd)
                                if groundRay.hit and groundRay.coords then
                                    targetPos = groundRay.coords
                                else
                                    local foundGround, groundZ = GetGroundZFor_3dCoord(probeX, probeY, pedCoords.z + 2.0, false)
                                    if foundGround and groundZ >= (pedCoords.z - 3.0) and groundZ <= (pedCoords.z + 2.0) then
                                        targetPos = vector3(probeX, probeY, groundZ)
                                    else
                                        targetPos = vector3(probeX, probeY, pedCoords.z)
                                    end
                                end
                            end
                        else
                            -- Режим без прилипания к поверхности (ручное размещение на весу)
                            targetPos = pedCoords + (flatForward * clampedDist)
                        end

                        -- Переключение прилипания к поверхности на клавишу G
                        if IsControlJustPressed(0, 0x760A9C6F) or IsDisabledControlJustPressed(0, 0x760A9C6F)
                        or IsControlJustPressed(0, 0x5415BE48) or IsDisabledControlJustPressed(0, 0x5415BE48)
                        or IsControlJustPressed(0, 0x07B8BEAF) or IsDisabledControlJustPressed(0, 0x07B8BEAF) then
                            isSnappingEnabled = not isSnappingEnabled
                            SendNUIMessage({
                                type = 'UPDATE_SNAP_STATE',
                                isSnapping = isSnappingEnabled
                            })
                        end

                        local finalX = targetPos.x
                        local finalY = targetPos.y
                        local finalZ = targetPos.z + heightOffset

                        -- Финальный жесткий барьер: горизонтальное расстояние не более MAX_ITEM_DISTANCE (2.5 м)
                        local finalDiff2D = vector2(finalX - pedCoords.x, finalY - pedCoords.y)
                        local finalDist2D = #(finalDiff2D)
                        if finalDist2D > MAX_ITEM_DISTANCE then
                            local clampedDir = finalDiff2D / finalDist2D
                            finalX = pedCoords.x + clampedDir.x * MAX_ITEM_DISTANCE
                            finalY = pedCoords.y + clampedDir.y * MAX_ITEM_DISTANCE
                        end

                        -- Ограничение разницы по высоте от ног персонажа (-2.5м .. +2.0м)
                        if (finalZ - pedCoords.z) > 2.0 then
                            finalZ = pedCoords.z + 2.0
                        elseif (finalZ - pedCoords.z) < -2.5 then
                            finalZ = pedCoords.z - 2.5
                        end

                        SetEntityCoords(ghostEntity, finalX, finalY, finalZ, false, false, false, false)
                        SetEntityRotation(ghostEntity, currentPitch, currentRoll, currentHeading, 2, true)

                        -- Вращение Yaw: Z / X
                        if IsKeyActive(0x26E9DC00) then
                            holdYawZ = holdYawZ + 1
                            currentHeading = (currentHeading + 0.8 * GetSpeedMultiplier(holdYawZ)) % 360.0
                        else
                            holdYawZ = 0
                        end
                        if IsKeyActive(0x8CC9CD42) then
                            holdYawX = holdYawX + 1
                            currentHeading = (currentHeading - 0.8 * GetSpeedMultiplier(holdYawX)) % 360.0
                        else
                            holdYawX = 0
                        end

                        -- Наклон Pitch
                        local isPitchUp = isKeyArrowUp or IsKeyActive(0x911CB09E) or IsKeyActive(0x8C989523) or IsKeyActive(172)
                        local isPitchDown = isKeyArrowDown or IsKeyActive(0x4403F97F) or IsKeyActive(0x7DA973E3) or IsKeyActive(173)
                        if isPitchUp then
                            holdPitchUp = holdPitchUp + 1
                            currentPitch = (currentPitch + 0.5 * GetSpeedMultiplier(holdPitchUp)) % 360.0
                        else
                            holdPitchUp = 0
                        end
                        if isPitchDown then
                            holdPitchDown = holdPitchDown + 1
                            currentPitch = (currentPitch - 0.5 * GetSpeedMultiplier(holdPitchDown)) % 360.0
                        else
                            holdPitchDown = 0
                        end

                        -- Крен Roll
                        local isRollLeft = isKeyArrowLeft or IsKeyActive(0xAD7FE10D) or IsKeyActive(0xA652F503) or IsKeyActive(174)
                        local isRollRight = isKeyArrowRight or IsKeyActive(0x74AC8104) or IsKeyActive(0x1D06CD58) or IsKeyActive(175)
                        if isRollLeft then
                            holdRollLeft = holdRollLeft + 1
                            currentRoll = (currentRoll - 0.5 * GetSpeedMultiplier(holdRollLeft)) % 360.0
                        else
                            holdRollLeft = 0
                        end
                        if isRollRight then
                            holdRollRight = holdRollRight + 1
                            currentRoll = (currentRoll + 0.5 * GetSpeedMultiplier(holdRollRight)) % 360.0
                        else
                            holdRollRight = 0
                        end

                        -- Высота Z: Q / E (ограничение -1.5м .. +1.5м)
                        local isQ = IsControlPressed(0, 0xDE794E3E) or IsDisabledControlPressed(0, 0xDE794E3E)
                        local isE = IsControlPressed(0, 0xCEFD9220) or IsDisabledControlPressed(0, 0xCEFD9220)
                            or IsControlPressed(0, 0xCE6D099E) or IsDisabledControlPressed(0, 0xCE6D099E)
                        if isQ then
                            holdHeightQ = holdHeightQ + 1
                            heightOffset = math.min(1.5, heightOffset + (0.012 * GetSpeedMultiplier(holdHeightQ)))
                        else
                            holdHeightQ = 0
                        end
                        if isE then
                            holdHeightE = holdHeightE + 1
                            heightOffset = math.max(-1.5, heightOffset - (0.012 * GetSpeedMultiplier(holdHeightE)))
                        else
                            holdHeightE = 0
                        end

                        -- Дистанция: R / F (строго MIN_ITEM_DISTANCE .. MAX_ITEM_DISTANCE)
                        local isR = IsControlPressed(0, 0xE30CD707) or IsDisabledControlPressed(0, 0xE30CD707)
                            or IsControlPressed(0, 0x410CD45F) or IsDisabledControlPressed(0, 0x410CD45F)
                        local isF = IsControlPressed(0, 0xB2F377E8) or IsDisabledControlPressed(0, 0xB2F377E8)
                        if isR then
                            holdDistR = holdDistR + 1
                            distanceOffset = math.min(MAX_ITEM_DISTANCE, distanceOffset + (0.02 * GetSpeedMultiplier(holdDistR)))
                        else
                            holdDistR = 0
                        end
                        if isF then
                            holdDistF = holdDistF + 1
                            distanceOffset = math.max(MIN_ITEM_DISTANCE, distanceOffset - (0.02 * GetSpeedMultiplier(holdDistF)))
                        else
                            holdDistF = 0
                        end

                        -- Установка: ЛКМ / Enter
                        if IsControlJustPressed(0, 0x07CE1E61) or IsDisabledControlJustPressed(0, 0x07CE1E61)
                        or IsControlJustPressed(0, 0xC7B5340A) or IsDisabledControlJustPressed(0, 0xC7B5340A) then
                            Preview.PlaceAndSave()
                        end

                        -- Отмена: ПКМ / Esc
                        if IsControlJustPressed(0, 0xF84FA74F) or IsDisabledControlJustPressed(0, 0xF84FA74F)
                        or IsControlJustPressed(0, 0xD82E0BD2) or IsDisabledControlJustPressed(0, 0xD82E0BD2) then
                            Preview.Stop()
                        end
                    end
                end
            end
        else
            Citizen.Wait(200)
        end
    end
end)
