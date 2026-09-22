-- =================================================================
-- HUNT: Hard RP — The Corruption | World Builder Client Controller
-- =================================================================

local isCharacterReady = false
local hasRequestedInitialData = false

local function RequestInitialDataOnce()
    if hasRequestedInitialData then return end
    hasRequestedInitialData = true
    TriggerServerEvent("thehunt_builder:requestInitialData")
end

-- Ожидание готовности персонажа
RegisterNetEvent("thehunt:character:selected", function()
    isCharacterReady = true
    RequestInitialDataOnce()
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Wait(300)
    isCharacterReady = true
    RequestInitialDataOnce()
end)

Citizen.CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do
        Citizen.Wait(200)
    end
    isCharacterReady = true
    RequestInitialDataOnce()
end)

-- Функция переключения режима редактора мира
local function ToggleBuilderMenu()
    if Preview and Preview.IsWorldEditorActive() then
        Preview.StopWorldEditor()
    else
        TriggerServerEvent("thehunt_builder:checkPermissionAndOpen")
    end
end

RegisterCommand("builder", ToggleBuilderMenu, false)
RegisterCommand("mapping", ToggleBuilderMenu, false)
RegisterCommand("worldeditor", ToggleBuilderMenu, false)

-- Сервер подтвердил права и открывает редактор (сразу в режиме свободной камеры)
RegisterNetEvent("thehunt_builder:openBuilderClient", function()
    isCharacterReady = true
    if Preview then
        Preview.StartWorldEditor()
    end
end)

-- NUI: Закрытие панели каталога
RegisterNUICallback('closeCatalogPanel', function(data, cb)
    if Preview then
        Preview.CloseCatalog()
    end
    cb('ok')
end)

-- NUI: Закрытие всего редактора мира
RegisterNUICallback('closeBuilder', function(data, cb)
    if Preview then
        Preview.StopWorldEditor()
    end
    cb('ok')
end)

-- NUI: Возврат назад в админ-панель
RegisterNUICallback('returnToAdmin', function(data, cb)
    if Preview then
        Preview.StopWorldEditor()
    end
    TriggerEvent("thehunt_admin:openDirectly")
    cb('ok')
end)

-- NUI: Запуск 3D-предпросмотра выбранного пропа из каталога
RegisterNUICallback('startPropPreview', function(data, cb)
    if not data or not data.model then return cb('error') end
    if Preview then
        Preview.Start(data)
    end
    cb('ok')
end)

-- Запуск 3D-предпросмотра размещения предмета из инвентаря
RegisterNetEvent("thehunt_builder:startPropPreviewFromInventory", function(data)
    if data and data.model and Preview then
        Preview.Start({
            name = data.name or "Объект",
            model = data.model,
            fromInventory = true,
            itemName = data.itemName,
            dbId = data.dbId,
            metadata = data.metadata,
            isProtected = (data.isProtected == true)
        })
    end
end)

-- NUI: Отмена предпросмотра
RegisterNUICallback('cancelPreview', function(data, cb)
    if Preview then
        Preview.Stop()
    end
    cb('ok')
end)

-- NUI: Отслеживание фокуса на текстовых полях ввода
RegisterNUICallback('setInputFocusState', function(data, cb)
    if Preview then
        Preview.SetInputFocus(data.hasFocus == true)
    end
    cb('ok')
end)

-- NUI: Перемещение существующего объекта из списка
local function HandleMoveProp(data, cb)
    local propId = tonumber(data and data.id)
    if propId and Preview then
        local prop = Streamer.GetPropById(propId)
        local ent = Streamer.GetSpawnedEntity(propId)
        if ent and DoesEntityExist(ent) then
            Preview.StartMoving(ent, propId)
        elseif prop then
            Preview.Start({
                id = prop.id,
                name = prop.model_name or ("Объект #" .. prop.id),
                model = prop.model_hash,
                entityType = prop.entity_type or "object"
            })
        end
    end
    cb('ok')
end
RegisterNUICallback('movePropById', HandleMoveProp)
RegisterNUICallback('movePlacedProp', HandleMoveProp)

-- NUI: Быстрое удаление объекта (кастомного или скрытия из БД)
local function HandleDeleteProp(data, cb)
    local propId = tonumber(data and data.id)
    local dbType = data and data.dbType
    if propId then
        if dbType == "deleted" then
            TriggerServerEvent("thehunt_builder:restoreDeletedWorldObjectDirect", propId)
        else
            TriggerServerEvent("thehunt_builder:deletePlacedObject", propId)
        end
    end
    cb('ok')
end
RegisterNUICallback('deletePropById', HandleDeleteProp)
RegisterNUICallback('deletePlacedProp', HandleDeleteProp)

-- NUI: Восстановление объекта мира на исходное положение
local function HandleRestoreProp(data, cb)
    local propId = tonumber(data and data.id)
    local dbType = data and data.dbType
    if propId then
        if dbType == "deleted" then
            TriggerServerEvent("thehunt_builder:restoreDeletedWorldObjectDirect", propId)
        else
            TriggerServerEvent("thehunt_builder:restoreWorldObject", propId)
        end
    end
    cb('ok')
end
RegisterNUICallback('restorePropById', HandleRestoreProp)
RegisterNUICallback('restorePlacedProp', HandleRestoreProp)

-- NUI: Телепорт к объекту (камеры или персонажа)
local function HandleTeleport(data, cb)
    local x = tonumber(data and data.x)
    local y = tonumber(data and data.y)
    local z = tonumber(data and data.z)
    if x and y and z then
        if Preview and Preview.IsWorldEditorActive() then
            Preview.TeleportCamera(vector3(x, y, z + 2.0))
        else
            SetEntityCoords(PlayerPedId(), x, y, z + 0.5, false, false, false, false)
        end
    end
    cb('ok')
end
RegisterNUICallback('tpToProp', HandleTeleport)
RegisterNUICallback('teleportToProp', HandleTeleport)

-- NUI: Запрос всех объектов из базы данных (Установленные, Перемещенные, Удаленные)
local function HandleNearbyProps(data, cb)
    local center = (Preview and Preview.GetCameraCoords()) or GetEntityCoords(PlayerPedId())
    local dbList = Streamer.GetAllDatabaseProps(center)
    SendNUIMessage({
        type = 'SET_NEARBY_PROPS',
        props = dbList
    })
    cb(dbList)
end
RegisterNUICallback('requestNearbyProps', HandleNearbyProps)
RegisterNUICallback('getNearbyProps', HandleNearbyProps)
RegisterNUICallback('requestDatabaseProps', HandleNearbyProps)

RegisterNUICallback('backupBuilderDatabase', function(data, cb)
    TriggerServerEvent("thehunt_builder:backupDatabase")
    cb('ok')
end)

-- =================================================================
-- EXPORTS
-- =================================================================

exports('IsPlacing', function()
    return (Preview and Preview.IsActive and Preview.IsActive()) == true
end)

exports('IsActive', function()
    return (Preview and Preview.IsActive and Preview.IsActive()) == true
end)
