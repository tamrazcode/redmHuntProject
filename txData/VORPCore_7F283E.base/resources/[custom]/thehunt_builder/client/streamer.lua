-- =================================================================
-- HUNT: Hard RP — The Corruption | Spatial Streamer for Placed Props
-- =================================================================

Streamer = {}

local allPlacedProps = {}
local allDeletedWorldProps = {}
local queuedProps = {}
local spawnQueueDirty = false
local appliedDeletedWorldProps = {}

-- Разносим создание объектов по небольшим порциям, чтобы вход и полет
-- в редакторе не создавали заметного скачка времени кадра.
local SPAWN_PROCESS_INTERVAL_MS = 50
local SPAWN_BATCH_PER_TICK = 2
local SPAWN_MAX_CHECKS_PER_TICK = 8
local spawnedEntities = {}     -- [propId] = entityHandle
local loadingProps = {}        -- [propId] = true
local pendingLiveEntities = {} -- { entity, coords, modelHash, time }
local despawnGraceUntil = 0    -- GetGameTimer() до которого запрещен деспавн объектов

-- ── Spawn Queue (throttle параллельных загрузок) ─────────────────────────────
-- spawnQueue: { propData, dist } — очередь ожидающих спавна, сортируется по dist
-- activeSpawns: счётчик текущих параллельных LoadModel-потоков
local spawnQueue   = {}
local activeSpawns = 0

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

local function IsDynamicMetadata(metadata)
    return type(metadata) == "table" and (
        metadata.physics_mode == "dynamic"
        or metadata.dynamic == true
        or metadata.is_dynamic == true
        or tonumber(metadata.is_dynamic) == 1
    )
end

local function IsDoorLikeModel(modelName)
    local value = tostring(modelName or ""):lower()
    return value:find("door", 1, true) ~= nil or value:find("gate", 1, true) ~= nil
end

local function IsDoorMetadata(metadata, propData)
    local hasDoorMetadata = type(metadata) == "table" and (
        metadata.door_mode == true
        or metadata.door_mode == 1
        or metadata.door_mode == "1"
    )
    if not hasDoorMetadata or type(propData) ~= "table" then return false end

    return IsDoorLikeModel(propData.model)
        or IsDoorLikeModel(propData.modelName)
        or IsDoorLikeModel(propData.model_name)
        or IsDoorLikeModel(propData.name)
end

function Streamer.ApplyPlacedEntityMode(entity, propOrMetadata)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local metadata = propOrMetadata
    local propData = nil
    if type(propOrMetadata) == "table" and propOrMetadata.metadata ~= nil then
        metadata = propOrMetadata.metadata
        propData = propOrMetadata
    end
    metadata = DecodeMetadata(metadata)

    SetEntityCollision(entity, true, true)
    if IsDynamicMetadata(metadata) then
        FreezeEntityPosition(entity, false)
        SetEntityDynamic(entity, true)
        pcall(function()
            ActivatePhysics(entity)
        end)
    else
        FreezeEntityPosition(entity, true)
    end

    if IsDoorMetadata(metadata, propData) then
        SetEntityCanBeDamaged(entity, false)
        pcall(function()
            SetCanClimbOnEntity(entity, false)
        end)
    end
end

local function CreatePlacedObject(modelHash, x, y, z, doorFlag)
    local entity = CreateObject(modelHash, x, y, z, false, false, doorFlag == true)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        -- Preserve the previous fallback for ordinary props. Door-like props
        -- are attempted with the native door flag first.
        entity = CreateObject(modelHash, x, y, z, false, false, doorFlag ~= true)
    end
    return entity
end

-- Вызывается при выходе из редактора мира — запрещает деспавн на 5 секунд
function Streamer.NotifyEditorExit()
    despawnGraceUntil = GetGameTimer() + 5000
end

-- Определение центральной точки для расчета стриминга (учитывает свободную камеру)
function Streamer.GetStreamingCenterCoords()
    if Preview and Preview.IsFreecamActive and Preview.IsFreecamActive() then
        local camPos = Preview.GetFreecamPos()
        if camPos and #(camPos - vector3(0, 0, 0)) > 2.0 then
            return camPos
        end
    end
    return GetEntityCoords(PlayerPedId())
end

-- Мгновенная фиксация установленного объекта: сразу регистрируем в стримере с временным ID
-- Это гарантирует, что стример НИКОГДА не потеряет объект, даже если ответ от сервера задержится
local tempIdCounter = 0
function Streamer.RegisterLivePlacedEntity(entity, coords, rot, modelHash, metadata)
    if not entity or not DoesEntityExist(entity) then return end
    SetEntityAlpha(entity, 255, false)
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityLodDist(entity, math.floor(tonumber(Config.EntityLodDistance) or 600))
    Streamer.ApplyPlacedEntityMode(entity, metadata)

    -- Немедленно регистрируем в стримере с временным отрицательным ID
    tempIdCounter = tempIdCounter - 1
    local tempId = tempIdCounter

    local tempProp = {
        id = tempId,
        model_name = "temp_placed",
        model_hash = tonumber(modelHash),
        x = coords.x,
        y = coords.y,
        z = coords.z,
        rot_x = rot.x or 0.0,
        rot_y = rot.y or 0.0,
        rot_z = rot.z or 0.0,
        metadata = next(DecodeMetadata(metadata)) and DecodeMetadata(metadata) or nil,
        _isTempLive = true -- флаг временной записи
    }

    table.insert(allPlacedProps, tempProp)
    spawnedEntities[tempId] = entity
    if Entity(entity).state then
        Entity(entity).state:set('builderPropId', tempId, false)
    end
end

-- Загрузка модели с последовательным запросом и гарантированным ожиданием
function Streamer.LoadModel(modelHash)
    local hash = tonumber(modelHash)
    if not hash or hash == 0 then return nil end

    local model = hash > 2147483647 and (hash - 4294967296) or hash
    model = math.floor(model)

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 200 do
        Citizen.Wait(25)
        timeout = timeout + 1
    end

    if HasModelLoaded(model) then
        return model
    end

    -- Резервная попытка с беззнаковым вариантом
    local uModel = hash < 0 and (hash + 4294967296) or hash
    uModel = math.floor(uModel)
    if uModel ~= model then
        RequestModel(uModel)
        timeout = 0
        while not HasModelLoaded(uModel) and timeout < 100 do
            Citizen.Wait(25)
            timeout = timeout + 1
        end
        if HasModelLoaded(uModel) then
            return uModel
        end
    end

    return nil
end

-- Применение скрытия удаленного объекта мира (нативное сокрытие + поиск по GamePool CObject)
local function GetDeletedWorldPropKey(del)
    if not del then return nil end

    local id = del.id and tostring(del.id) or ''
    local model = tostring(del.model_hash or '')
    local x = math.floor((tonumber(del.x) or 0.0) * 100.0 + 0.5)
    local y = math.floor((tonumber(del.y) or 0.0) * 100.0 + 0.5)
    local z = math.floor((tonumber(del.z) or 0.0) * 100.0 + 0.5)
    return table.concat({ id, model, tostring(x), tostring(y), tostring(z) }, ':')
end

local function ClearDeletedWorldPropKey(del)
    local key = GetDeletedWorldPropKey(del)
    if key then appliedDeletedWorldProps[key] = nil end
end

function Streamer.ApplyDeletedWorldProp(del, objectPool)
    if not del or not del.model_hash or not del.x or not del.y or not del.z then return end

    -- Native model hiding is persistent for this resource lifetime. Avoid
    -- rescanning the entire CObject pool every streamer tick for the same
    -- deletion entry.
    local deletionKey = GetDeletedWorldPropKey(del)
    if deletionKey and appliedDeletedWorldProps[deletionKey] then return end
    if deletionKey then appliedDeletedWorldProps[deletionKey] = true end

    local hash = tonumber(del.model_hash)
    local signed = hash > 2147483647 and (hash - 4294967296) or hash
    local unsigned = hash < 0 and (hash + 4294967296) or hash

    local x = del.x + 0.0
    local y = del.y + 0.0
    local z = del.z + 0.0
    local targetPos = vector3(x, y, z)

    -- 1. Нативное сокрытие статического объекта движком RDR3 (исключая скриптовые объекты)
    pcall(function()
        CreateModelHideExcludingScriptObjects(x, y, z, 0.75, signed, true)
        CreateModelHideExcludingScriptObjects(x, y, z, 0.75, unsigned, true)
    end)

    -- 2. Гарантированный поиск и удаление через пул объектов игры (GetGamePool)
    local ghost = (Preview and Preview.GetGhostEntity and Preview.GetGhostEntity()) or nil
    local pool = objectPool or GetGamePool('CObject')
    for _, ent in ipairs(pool) do
        if DoesEntityExist(ent) and ent ~= ghost then
            local entModel = GetEntityModel(ent)
            if entModel == signed or entModel == unsigned or Raycast.NormalizeModelHash(entModel) == unsigned then
                local entCoords = GetEntityCoords(ent)
                if #(entCoords - targetPos) < 0.65 then
                    -- Проверяем, не является ли это нашим заспавненным кастомным объектом
                    local isCustom = false
                    for _, sEnt in pairs(spawnedEntities) do
                        if sEnt == ent then isCustom = true; break end
                    end
                    if not isCustom then
                        isCustom = (Streamer.GetPropInfoByEntity(ent) ~= nil)
                    end

                    if not isCustom and ent ~= ghost then
                        SetEntityAsMissionEntity(ent, true, true)
                        SetEntityAlpha(ent, 0, false)
                        SetEntityCollision(ent, false, false)
                        FreezeEntityPosition(ent, true)
                        SetEntityCoords(ent, 0.0, 0.0, -5000.0, false, false, false, false)
                        DeleteEntity(ent)
                    end
                end
            end
        end
    end
end

-- Вспомогательная функция гарантированного спавна кастомного объекта.
-- onDone (опционально) — вызывается после завершения загрузки (используется очередью).
function Streamer.SpawnProp(p, onDone)
    if not p or not p.id or p._isBeingMoved then
        if onDone then onDone() end
        return
    end
    local pId = tonumber(p.id)
    if not pId then
        if onDone then onDone() end
        return
    end

    -- Прямые вызовы из событий редактора идут через ту же ограниченную
    -- очередь. Рабочий очереди передает onDone и продолжает загрузчик.
    if not onDone and Preview and Preview.IsWorldEditorActive and Preview.IsWorldEditorActive() then
        local center = Streamer.GetStreamingCenterCoords()
        Streamer.EnqueueSpawn(p, #(center - vector3(p.x, p.y, p.z)))
        return
    end

    if spawnedEntities[pId] and DoesEntityExist(spawnedEntities[pId]) then
        if onDone then onDone() end
        return
    end
    if loadingProps[pId] then
        if onDone then onDone() end
        return -- Блокировка от повторного параллельного спавна
    end
    loadingProps[pId] = true

    local rawHash = tonumber(p.model_hash)
    if not rawHash or rawHash == 0 then
        loadingProps[pId] = nil
        if onDone then onDone() end
        return
    end

    -- Парсим metadata если есть
    local meta = p.metadata
    if type(meta) == "string" and meta ~= "" then
        pcall(function() meta = json.decode(meta) end)
    end
    if type(meta) ~= "table" then meta = {} end

    local entityType = meta.entity_type or (IsModelAPed(rawHash) and "ped") or (IsModelAVehicle(rawHash) and "vehicle") or "object"
    local isDoorObject = IsDoorMetadata(meta, p)

    Citizen.CreateThread(function()
        local readyModelHash = Streamer.LoadModel(rawHash)
        loadingProps[pId] = nil

        if readyModelHash then
            -- Проверяем наличие в массиве или добавляем
            local exists = false
            for _, prop in ipairs(allPlacedProps) do
                if tonumber(prop.id) == pId then exists = true; break end
            end
            if not exists then
                table.insert(allPlacedProps, p)
            end

            if not spawnedEntities[pId] or not DoesEntityExist(spawnedEntities[pId]) then
                local ent = nil

                if entityType == "ped" or IsModelAPed(readyModelHash) then
                    ent = CreatePed(readyModelHash, p.x, p.y, p.z, p.rot_z or 0.0, false, false, false, false)
                    if ent and ent ~= 0 and DoesEntityExist(ent) then
                        SetEntityAsMissionEntity(ent, true, true)
                        SetEntityRotation(ent, p.rot_x or 0.0, p.rot_y or 0.0, p.rot_z or 0.0, 2, true)
                        SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, false, false, false)
                        FreezeEntityPosition(ent, true)
                        SetEntityInvincible(ent, true)
                        SetBlockingOfNonTemporaryEvents(ent, true)
                        SetPedCanRagdoll(ent, false)

                        -- Применяем RP-сценарий, если он был задан
                        if meta.scenario and meta.scenario ~= "" and meta.scenario ~= "none" then
                            TaskStartScenarioInPlace(ent, GetHashKey(meta.scenario), -1, true, false, false, false)
                        end
                    end
                elseif entityType == "vehicle" or IsModelAVehicle(readyModelHash) then
                    ent = CreateVehicle(readyModelHash, p.x, p.y, p.z, p.rot_z or 0.0, false, false)
                    if ent and ent ~= 0 and DoesEntityExist(ent) then
                        SetEntityAsMissionEntity(ent, true, true)
                        SetEntityRotation(ent, p.rot_x or 0.0, p.rot_y or 0.0, p.rot_z or 0.0, 2, true)
                        SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, false, false, false)
                        FreezeEntityPosition(ent, true)
                        SetVehicleOnGroundProperly(ent)
                    end
                else
                    ent = CreatePlacedObject(readyModelHash, p.x, p.y, p.z, isDoorObject)
                    if ent and ent ~= 0 and DoesEntityExist(ent) then
                        SetEntityAsMissionEntity(ent, true, true)
                        SetEntityRotation(ent, p.rot_x or 0.0, p.rot_y or 0.0, p.rot_z or 0.0, 2, true)
                        SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, false, false, false)
                        Streamer.ApplyPlacedEntityMode(ent, meta)
                        SetEntityLodDist(ent, math.floor(tonumber(Config.EntityLodDistance) or 600))
                    end
                end

                if ent and ent ~= 0 and DoesEntityExist(ent) then
                    spawnedEntities[pId] = ent
                    if Entity(ent).state then
                        Entity(ent).state:set('builderPropId', pId, false)
                    end
                    Streamer.RegisterPropInteraction(ent, p)
                end
            end
        end

        -- Сообщаем очереди что слот освободился
        if onDone then onDone() end
    end)
end

-- =============================================================================
-- SPAWN QUEUE — throttled concurrent loader
-- =============================================================================
-- Добавляет проп в очередь приоритетного спавна (если он ещё не заспавнен и
-- не загружается). Очередь обрабатывается отдельным коротким тиком.
function Streamer.EnqueueSpawn(p, dist)
    local pId = tonumber(p.id)
    if not pId then return end
    if spawnedEntities[pId] and DoesEntityExist(spawnedEntities[pId]) then return end
    if loadingProps[pId] then return end

    local queued = queuedProps[pId]
    if queued then
        queued.p = p
        queued.dist = dist
        spawnQueueDirty = true
        return
    end

    -- Дубликаты проверяются через queuedProps за O(1).
    local entry = { p = p, dist = dist }
    queuedProps[pId] = entry
    table.insert(spawnQueue, entry)
    spawnQueueDirty = true
end

-- Убирает проп из очереди (вызывается при выходе за радиус деспавна)
function Streamer.DequeueSpawn(propId)
    local pId = tonumber(propId)
    if not pId then return end
    if not queuedProps[pId] then return end
    queuedProps[pId] = nil
    for i = #spawnQueue, 1, -1 do
        if tonumber(spawnQueue[i].p.id) == pId then
            table.remove(spawnQueue, i)
            spawnQueueDirty = true
            break
        end
    end
end

-- Обрабатывает очередь: запускает до Config.MaxConcurrentSpawns параллельных
-- загрузок небольшими порциями, чтобы не создавать всплески нагрузки.
local function ProcessSpawnQueue()
    if #spawnQueue == 0 or activeSpawns >= (Config.MaxConcurrentSpawns or 12) then return end

    local limit = Config.MaxConcurrentSpawns or 12

    -- Сортируем по убыванию: ближайший объект окажется в конце и будет
    -- извлекаться без сдвига всего массива (table.remove(..., 1) здесь дорогой).
    if spawnQueueDirty and #spawnQueue > 1 then
        table.sort(spawnQueue, function(a, b) return (a.dist or 0) > (b.dist or 0) end)
    end
    spawnQueueDirty = false

    -- Запускаем столько спавнов сколько позволяет лимит
    local started = 0
    local checked = 0
    local center = Streamer.GetStreamingCenterCoords()
    while activeSpawns < limit and #spawnQueue > 0
        and started < SPAWN_BATCH_PER_TICK
        and checked < SPAWN_MAX_CHECKS_PER_TICK do
        local item = table.remove(spawnQueue)
        checked = checked + 1
        local pId = item and item.p and tonumber(item.p.id) or nil
        if pId then queuedProps[pId] = nil end
        if item and item.p then
            local pId = tonumber(item.p.id)
            -- Финальная проверка: вдруг уже заспавнен пока ждал в очереди
            local stillInRange = not center or #(center - vector3(item.p.x, item.p.y, item.p.z)) <= (Config.StreamDistance or 600.0)
            if pId and stillInRange and (not spawnedEntities[pId] or not DoesEntityExist(spawnedEntities[pId])) and not loadingProps[pId] then
                activeSpawns = activeSpawns + 1
                started = started + 1
                Streamer.SpawnProp(item.p, function()
                    activeSpawns = activeSpawns - 1
                end)
            end
        end
    end
end

Citizen.CreateThread(function()
    while true do
        if #spawnQueue > 0 then
            ProcessSpawnQueue()
        end
        Citizen.Wait(#spawnQueue > 0 and SPAWN_PROCESS_INTERVAL_MS or 200)
    end
end)

local myPlayerIdentifier = nil

-- Регистрация взаимодействия для кастомного объекта в thehunt_interact
function Streamer.RegisterPropInteraction(obj, p)
    if not DoesEntityExist(obj) or not p or not p.id then return end
    
    -- Взаимодействие через G доступно для всех предметов, установленных из инвентаря (где есть item_name)
    if not p.item_name or p.item_name == "" then
        return
    end

    local propId = tonumber(p.id)
    local itemName = p.item_name
    local isProtected = (p.is_protected == 1 or p.is_protected == true)
    local isOwner = (p.owner and myPlayerIdentifier and p.owner == myPlayerIdentifier) or (p.owner == "ADMIN")

    local isNote = (itemName == "torn_page" or itemName == "notebook")
    local isLitCampfire = (itemName == "campfire_lit" or p.model_name == "p_campfirefresh01x" or p.model_hash == GetHashKey("p_campfirefresh01x"))
    local isSmolderCampfire = (itemName == "campfire_smolder" or p.model_name == "p_campfire_win2_smolder01x" or p.model_hash == GetHashKey("p_campfire_win2_smolder01x"))
    local isUnlitCampfire = (itemName == "campfire" or p.model_name == "p_campfire_win2_01x" or p.model_hash == GetHashKey("p_campfire_win2_01x"))

    -- Если предмет защищен (is_protected = 1), а текущий игрок НЕ является владельцем:
    -- для обычных предметов полностью скрываем взаимодействие из thehunt_interact,
    -- но для записок/вырванных страниц и костров оставляем возможность взаимодействия!
    if isProtected and not isOwner and not isNote and not isLitCampfire and not isSmolderCampfire then
        if GetResourceState('thehunt_interact') == 'started' then
            pcall(function()
                exports['thehunt_interact']:RemoveTargetEntity(obj)
            end)
        end
        return
    end

    if GetResourceState('thehunt_interact') == 'started' then
        pcall(function()
            local itemDef = exports['thehunt_items'] and exports['thehunt_items']:GetItemData(itemName)
            if not itemDef and exports['thehunt_items'] and exports['thehunt_items'].GetItemByPropModel then
                local resolvedName, def = exports['thehunt_items']:GetItemByPropModel(p.model_hash)
                if resolvedName then
                    itemName = resolvedName
                    itemDef = def
                end
            end
            local category = itemDef and itemDef.category or "item"
            local isContainer = itemDef and (itemDef.isContainer == true or itemDef.containerStorage ~= nil or category == "storage")
            local actions = {}

            if isLitCampfire then
                -- Горящий костёр: нет подбора и защиты, специализированные действия
                table.insert(actions, {
                    id = "fuel_wood",
                    label = "Подкинуть древесину",
                    icon = "wood",
                    event = "thehunt_items:clientAddFuelWood",
                    targetInfo = { propId = propId, itemName = itemName }
                })
                table.insert(actions, {
                    id = "fuel_twigs",
                    label = "Подкинуть ветки",
                    icon = "twigs",
                    event = "thehunt_items:clientAddFuelTwigs",
                    targetInfo = { propId = propId, itemName = itemName }
                })
                table.insert(actions, {
                    id = "campfire_info",
                    label = "Информация",
                    icon = "info",
                    event = "thehunt_items:clientCampfireInfo",
                    targetInfo = { propId = propId, itemName = itemName }
                })
                table.insert(actions, {
                    id = "campfire_cook",
                    label = "Готовить",
                    icon = "cook",
                    event = "thehunt_items:clientCampfireCook",
                    targetInfo = { propId = propId, itemName = itemName }
                })
                table.insert(actions, {
                    id = "extinguish",
                    label = "Потушить",
                    icon = "extinguish",
                    event = "thehunt_items:clientExtinguishCampfire",
                    targetInfo = { propId = propId, itemName = itemName }
                })
            elseif isSmolderCampfire then
                -- Потухший костёр: только сбор угля в течение 5 минут
                table.insert(actions, {
                    id = "gather_charcoal",
                    label = "Собрать древесный уголь",
                    icon = "charcoal",
                    event = "thehunt_items:clientGatherCharcoal",
                    targetInfo = { propId = propId, itemName = itemName }
                })
            else
                -- Обычные предметы и неподожженный костёр
                -- 1. Кнопка «Подобрать» (доступна если не защищен, либо если игрок - владелец)
                if not isProtected or isOwner then
                    table.insert(actions, {
                        id = "pickup",
                        label = "Подобрать",
                        icon = "pickup",
                        event = "thehunt_builder:onInteractPickup",
                        targetInfo = { propId = propId, itemName = itemName }
                    })
                end

                -- 2. Если открыл ВЛАДЕЛЕЦ предмета: добавляем переключатель запрета подбора
                if isOwner then
                    if isProtected then
                        table.insert(actions, {
                            id = "toggle_protection",
                            label = "Разрешить подбирать",
                            icon = "pickup_unlock",
                            event = "thehunt_builder:onInteractToggleProtection",
                            targetInfo = { propId = propId, setProtected = false }
                        })
                    else
                        table.insert(actions, {
                            id = "toggle_protection",
                            label = "Запретить подбирать",
                            icon = "pickup_lock",
                            event = "thehunt_builder:onInteractToggleProtection",
                            targetInfo = { propId = propId, setProtected = true }
                        })
                    end
                end

                -- 3. Если это хранилище / контейнер
                if isContainer and (not isProtected or isOwner) then
                    table.insert(actions, {
                        id = "open_container",
                        label = "Открыть",
                        icon = "open",
                        event = "thehunt_items:clientOpenPlacedContainer",
                        targetInfo = { propId = propId, itemName = itemName }
                    })
                end

                -- 4. Если это записка / вырванная страница / блокнот
                if isNote then
                    table.insert(actions, {
                        id = "read_page",
                        label = "Прочитать",
                        icon = "read",
                        event = "thehunt_items:clientReadPlacedNote",
                        targetInfo = { propId = propId, itemName = itemName }
                    })
                end

                -- 5. Если это костёр (p_campfire_win2_01x): кнопка «Разжечь»
                if isUnlitCampfire then
                    table.insert(actions, {
                        id = "ignite",
                        label = "Разжечь",
                        icon = "ignite",
                        event = "thehunt_items:clientLightCampfire",
                        targetInfo = { propId = propId, itemName = itemName }
                    })
                end
            end

            if #actions > 0 then
                exports['thehunt_interact']:AddTargetEntity(obj, actions, 1.7)
            end
        end)
    end
end

-- Обработка действия «Запретить / Разрешить подбирать» из меню G
RegisterNetEvent("thehunt_builder:onInteractToggleProtection", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    local setProtected = targetInfo and (targetInfo.setProtected ~= nil and targetInfo.setProtected or (targetInfo.targetInfo and targetInfo.targetInfo.setProtected))
    if not propId then return end

    TriggerServerEvent("thehunt_builder:togglePropProtection", tonumber(propId), setProtected == true)
end)

-- Синхронизация изменения статуса защиты объекта
RegisterNetEvent("thehunt_builder:syncPropProtection", function(propId, isProtected)
    local pId = tonumber(propId)
    local newProt = tonumber(isProtected) or 0
    for _, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            p.is_protected = newProt
            local ent = spawnedEntities[pId]
            if ent and DoesEntityExist(ent) then
                Streamer.RegisterPropInteraction(ent, p)
            end
            break
        end
    end
end)

-- Обработка действия «Подобрать» из меню G
RegisterNetEvent("thehunt_builder:onInteractPickup", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    local itemName = targetInfo and (targetInfo.itemName or (targetInfo.targetInfo and targetInfo.targetInfo.itemName))
    if not propId then return end

    local ped = PlayerPedId()
    -- Анимация подбора предмета
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

    TriggerServerEvent("thehunt_items:pickupPlacedObject", tonumber(propId), itemName)
end)

-- Повторная регистрация всех заспавненных объектов при перезапуске thehunt_interact
RegisterNetEvent("thehunt_interact:ready", function()
    for propId, ent in pairs(spawnedEntities) do
        if DoesEntityExist(ent) then
            for _, p in ipairs(allPlacedProps) do
                if p.id == propId then
                    Streamer.RegisterPropInteraction(ent, p)
                    break
                end
            end
        end
    end
end)

-- Прием всех данных от сервера при входе
RegisterNetEvent("thehunt_builder:receiveAllData", function(placedList, deletedList, myOwnerIdentifier)
    allPlacedProps = placedList or {}
    allDeletedWorldProps = deletedList or {}
    appliedDeletedWorldProps = {}
    local deletedObjectPool = (#allDeletedWorldProps > 0) and GetGamePool('CObject') or nil
    if myOwnerIdentifier then
        myPlayerIdentifier = myOwnerIdentifier
    end
    print(string.format("^2[HUNT BUILDER] Клиент получил %d кастомных объектов и %d удаленных объектов мира.^7", #allPlacedProps, #allDeletedWorldProps))

    -- 1. Ставим все ближайшие пропы в очередь приоритетного спавна
    --    (очередь обрабатывается в тик-цикле: 12 параллельных загрузок, ближние первые)
    local myCoords = Streamer.GetStreamingCenterCoords()
    local nearbyProps = {}
    for _, p in ipairs(allPlacedProps) do
        local dist = #(myCoords - vector3(p.x, p.y, p.z))
        if not p._isBeingMoved and not p._isTempLive and dist <= (Config.StreamDistance or 600.0) then
            nearbyProps[#nearbyProps + 1] = { prop = p, dist = dist }
        end
    end
    table.sort(nearbyProps, function(a, b) return a.dist < b.dist end)
    for index = 1, math.min(#nearbyProps, math.max(1, tonumber(Config.MaxStreamedProps) or 500)) do
        local entry = nearbyProps[index]
        Streamer.EnqueueSpawn(entry.prop, entry.dist)
    end

    -- 2. Применяем скрытие удаленных объектов мира
    for _, del in ipairs(allDeletedWorldProps) do
        Streamer.ApplyDeletedWorldProp(del, deletedObjectPool)
    end
end)

-- Синхронизация нового созданного объекта (МГНОВЕННЫЙ СПАВН)
RegisterNetEvent("thehunt_builder:syncNewProp", function(propData)
    local pId = tonumber(propData.id)
    if not pId then return end

    local propHash = Raycast.NormalizeModelHash(propData.model_hash)
    local targetPos = vector3(tonumber(propData.x) + 0.0, tonumber(propData.y) + 0.0, tonumber(propData.z) + 0.0)

    -- 1. Ищем временную запись (от RegisterLivePlacedEntity) с тем же хэшем и координатами
    local matchedTempIdx = nil
    local matchedTempId = nil
    local bestDist = 0.5

    for idx, p in ipairs(allPlacedProps) do
        if p._isTempLive and Raycast.NormalizeModelHash(p.model_hash) == propHash then
            local dist = #(vector3(p.x, p.y, p.z) - targetPos)
            if dist < bestDist then
                bestDist = dist
                matchedTempIdx = idx
                matchedTempId = tonumber(p.id)
            end
        end
    end

    if matchedTempIdx and matchedTempId then
        -- Нашли временную запись — заменяем её на настоящую из БД
        allPlacedProps[matchedTempIdx] = propData

        -- Переносим entity handle с временного ID на реальный
        local entity = spawnedEntities[matchedTempId]
        spawnedEntities[matchedTempId] = nil
        if entity and DoesEntityExist(entity) then
            spawnedEntities[pId] = entity
            if Entity(entity).state then
                Entity(entity).state:set('builderPropId', pId, false)
            end
            Streamer.ApplyPlacedEntityMode(entity, propData)
            Streamer.RegisterPropInteraction(entity, propData)
        else
            -- Объект пропал — пересоздаём
            Streamer.EnqueueSpawn(propData, #(Streamer.GetStreamingCenterCoords() - targetPos))
        end
        return
    end

    -- 2. Нет временной записи — это объект другого игрока или из стримера
    -- Проверяем, нет ли уже в локальном массиве
    local found = false
    for idx, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            allPlacedProps[idx] = propData
            found = true
            break
        end
    end
    if not found then
        table.insert(allPlacedProps, propData)
    end

    -- Если уже заспавнен — пропускаем
    if spawnedEntities[pId] and DoesEntityExist(spawnedEntities[pId]) then
        return
    end

    -- Резервный поиск по пулу игровых объектов в мире
    local pool = GetGamePool('CObject')
    for _, ent in ipairs(pool) do
        if DoesEntityExist(ent) and Raycast.NormalizeModelHash(GetEntityModel(ent)) == propHash then
            local entCoords = GetEntityCoords(ent)
            if #(entCoords - targetPos) < 0.35 then
                spawnedEntities[pId] = ent
                SetEntityAsMissionEntity(ent, true, true)
                SetEntityAlpha(ent, 255, false)
                Streamer.ApplyPlacedEntityMode(ent, propData)
                SetEntityLodDist(ent, math.floor(tonumber(Config.EntityLodDistance) or 600))
                Streamer.RegisterPropInteraction(ent, propData)
                return
            end
        end
    end

    -- 3. Ничего не нашли — спавним новый
    local myCoords = Streamer.GetStreamingCenterCoords()
    local dist = #(myCoords - targetPos)
    if dist <= (Config.StreamDistance or 600.0) then
        Streamer.EnqueueSpawn(propData, dist)
    end
end)

-- Синхронизация перемещения
RegisterNetEvent("thehunt_builder:syncUpdateProp", function(propId, x, y, z, rx, ry, rz, metadata)
    local pId = tonumber(propId)
    if not pId then return end

    local targetProp = nil
    for _, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            p.x = x
            p.y = y
            p.z = z
            p.rot_x = rx
            p.rot_y = ry
            p.rot_z = rz
            if metadata ~= nil then
                p.metadata = metadata
            end
            p._isBeingMoved = nil
            targetProp = p
            break
        end
    end

    -- Если объект заспавнен в мире — обновляем его позицию
    local entity = spawnedEntities[pId]
    if entity and DoesEntityExist(entity) then
        SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
        SetEntityRotation(entity, rx or 0.0, ry or 0.0, rz or 0.0, 2, true)
        Streamer.ApplyPlacedEntityMode(entity, targetProp or metadata)
    else
        if targetProp then
            local myCoords = Streamer.GetStreamingCenterCoords()
            local dist = #(myCoords - vector3(x, y, z))
            if dist <= (Config.StreamDistance or 600.0) then
                Streamer.EnqueueSpawn(targetProp, dist)
            end
        end
    end
end)

-- Синхронизация удаления кастомного объекта
RegisterNetEvent("thehunt_builder:syncDeleteProp", function(propId)
    local pId = tonumber(propId)
    if not pId then return end
    Streamer.DequeueSpawn(pId)

    for idx, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            table.remove(allPlacedProps, idx)
            break
        end
    end

    for id, ent in pairs(spawnedEntities) do
        if tonumber(id) == pId then
            if DoesEntityExist(ent) then
                if exports['thehunt_interact'] then
                    exports['thehunt_interact']:RemoveTargetEntity(ent)
                end
                SetEntityAsMissionEntity(ent, true, true)
                DeleteEntity(ent)
            end
            spawnedEntities[id] = nil
        end
    end
end)

-- Синхронизация удаления статического объекта мира (нативное скрытие)
RegisterNetEvent("thehunt_builder:syncDeleteWorldProp", function(deletedData)
    table.insert(allDeletedWorldProps, deletedData)
    Streamer.ApplyDeletedWorldProp(deletedData)
end)

-- Синхронизация восстановления статического объекта мира (нативное снятие скрытия)
RegisterNetEvent("thehunt_builder:syncRestoreWorldProp", function(modelHash, origX, origY, origZ)
    local hash = tonumber(modelHash)
    local signed = hash > 2147483647 and (hash - 4294967296) or hash
    local unsigned = hash < 0 and (hash + 4294967296) or hash

    for idx, del in ipairs(allDeletedWorldProps) do
        if (tonumber(del.model_hash) == signed or tonumber(del.model_hash) == unsigned) and math.abs(del.x - origX) < 2.0 and math.abs(del.y - origY) < 2.0 then
            ClearDeletedWorldPropKey(del)
            table.remove(allDeletedWorldProps, idx)
            break
        end
    end
    pcall(function()
        RemoveModelHide(origX + 0.0, origY + 0.0, origZ + 0.0, 2.5, signed, true)
        RemoveModelHide(origX + 0.0, origY + 0.0, origZ + 0.0, 2.5, unsigned, true)
    end)
end)

-- Добавить временное удаление мира (при перемещении через инспектор)
function Streamer.AddTemporaryDeletedWorldProp(deletedData)
    if not deletedData or not deletedData.model_hash then return end
    table.insert(allDeletedWorldProps, deletedData)
    Streamer.ApplyDeletedWorldProp(deletedData)
end

-- Удалить временное удаление мира (при отмене перемещения)
function Streamer.RemoveTemporaryDeletedWorldProp(coords, modelHash)
    for idx, del in ipairs(allDeletedWorldProps) do
        if del.model_hash == modelHash and #(vector3(del.x, del.y, del.z) - coords) < 3.0 then
            ClearDeletedWorldPropKey(del)
            table.remove(allDeletedWorldProps, idx)
            break
        end
    end
    pcall(function()
        RemoveModelHide(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, 0.75, tonumber(modelHash), true)
    end)
end

-- Очистить и удалить сущность из таблицы стримера (при перемещении)
function Streamer.ClearSpawnedEntity(propId)
    local pId = tonumber(propId)
    if not pId then return end

    for id, ent in pairs(spawnedEntities) do
        if tonumber(id) == pId then
            if DoesEntityExist(ent) then
                if GetResourceState('thehunt_interact') == 'started' then
                    pcall(function() exports['thehunt_interact']:RemoveTargetEntity(ent) end)
                end
                SetEntityAsMissionEntity(ent, true, true)
                SetEntityAlpha(ent, 0, false)
                SetEntityCollision(ent, false, false)
                FreezeEntityPosition(ent, true)
                SetEntityCoords(ent, 0.0, 0.0, -5000.0, false, false, false, false)
                DeleteEntity(ent)
            end
            spawnedEntities[id] = nil
        end
    end
end

-- Установить флаг перемещения объекта (чтобы фоновый стример не пересоздавал его на старом месте)
function Streamer.SetPropMoving(propId, isMoving)
    if not propId then return end
    local pId = tonumber(propId)
    for _, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            p._isBeingMoved = isMoving or nil
            break
        end
    end
end

-- Получить кастомный объект по его ID
function Streamer.GetPropById(propId)
    local pId = tonumber(propId)
    if not pId then return nil end
    for _, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            return p
        end
    end
    return nil
end

-- Получить entity handle заспавненного объекта
function Streamer.GetSpawnedEntity(propId)
    local pId = tonumber(propId)
    return pId and spawnedEntities[pId] or nil
end

-- Задать entity handle для кастомного объекта
function Streamer.SetSpawnedEntity(propId, entity)
    local pId = tonumber(propId)
    if not pId then return end
    spawnedEntities[pId] = entity
end

-- Мгновенно обновить координаты кастомного объекта в локальном кэше клиента
function Streamer.UpdateLocalPropPos(propId, x, y, z, rx, ry, rz)
    local pId = tonumber(propId)
    if not pId then return end
    for _, p in ipairs(allPlacedProps) do
        if tonumber(p.id) == pId then
            p.x = x
            p.y = y
            p.z = z
            p.rot_x = rx
            p.rot_y = ry
            p.rot_z = rz
            p._isBeingMoved = nil
            break
        end
    end
end

-- Проверка является ли сущность кастомным созданным объектом
function Streamer.IsCustomEntity(entity)
    if not entity or not DoesEntityExist(entity) then return false end
    return Streamer.GetPropInfoByEntity(entity) ~= nil
end

-- Получить кастомный объект по его сущности в игре (по statebag, handle или координатам/хэшу)
function Streamer.GetPropInfoByEntity(entity, allowSpatialFallback)
    if not entity or not DoesEntityExist(entity) then return nil end

    -- 1. Проверка через StateBag сущности
    local stateBagId = Entity(entity).state and Entity(entity).state.builderPropId or nil
    if stateBagId then
        local targetId = tonumber(stateBagId)
        for _, p in ipairs(allPlacedProps) do
            if tonumber(p.id) == targetId then
                return p
            end
        end
    end

    -- 2. Прямой поиск по таблице spawnedEntities
    for propId, ent in pairs(spawnedEntities) do
        if ent == entity then
            for _, p in ipairs(allPlacedProps) do
                if tonumber(p.id) == tonumber(propId) then
                    return p
                end
            end
        end
    end

    -- 3. Fallback: поиск по совпадению модели и ближайшим координатам (в радиусе до 3.5м)
    -- World-editor moves must not classify a native map prop by proximity to
    -- another equal model: only a statebag or a registered handle is exact.
    if allowSpatialFallback == false then return nil end

    local modelHash = Raycast.NormalizeModelHash(GetEntityModel(entity))
    local coords = GetEntityCoords(entity)
    local bestMatch = nil
    local minDistance = 3.5

    for _, p in ipairs(allPlacedProps) do
        local pHash = Raycast.NormalizeModelHash(p.model_hash)
        if pHash == modelHash then
            local dist = #(coords - vector3(p.x, p.y, p.z))
            if dist < minDistance then
                minDistance = dist
                bestMatch = p
            end
        end
    end

    return bestMatch
end

-- Получить полный список всех размещенных объектов
function Streamer.GetAllPlacedProps()
    return allPlacedProps or {}
end

-- Получить все кастомные объекты в радиусе вокруг координат (или игрока)
function Streamer.GetPropsInArea(maxDist, centerCoords)
    local myCoords = centerCoords or Streamer.GetStreamingCenterCoords()
    local result = {}
    for _, p in ipairs(allPlacedProps) do
        local dist = #(myCoords - vector3(p.x, p.y, p.z))
        if dist <= (maxDist or 120.0) then
            table.insert(result, {
                id = p.id,
                name = p.model_name,
                model_hash = p.model_hash,
                x = p.x,
                y = p.y,
                z = p.z,
                dist = math.floor(dist)
            })
        end
    end
    return result
end

local function DespawnBuilderProp(pId)
    local entity = spawnedEntities[pId]
    if entity and DoesEntityExist(entity) then
        if GetResourceState('thehunt_interact') == 'started' then
            pcall(function() exports['thehunt_interact']:RemoveTargetEntity(entity) end)
        end
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
    spawnedEntities[pId] = nil
end

-- Получить ВСЕ объекты из базы данных (Установленные, Перемещённые и Удалённые из мира)
function Streamer.GetAllDatabaseProps(centerCoords)
    local myCoords = centerCoords or Streamer.GetStreamingCenterCoords()
    local result = {}

    -- 1. Установленные и перемещенные пропы
    for _, p in ipairs(allPlacedProps) do
        local isMoved = (p.original_x ~= nil)
        local dist = #(myCoords - vector3(p.x, p.y, p.z))
        table.insert(result, {
            id = p.id,
            db_type = isMoved and "moved" or "placed",
            status_text = isMoved and "Перемещён" or "Установлен",
            name = p.model_name or "Объект",
            model_hash = p.model_hash,
            x = math.floor(p.x * 100) / 100,
            y = math.floor(p.y * 100) / 100,
            z = math.floor(p.z * 100) / 100,
            rot_x = p.rot_x or 0.0,
            rot_y = p.rot_y or 0.0,
            rot_z = p.rot_z or 0.0,
            original_x = p.original_x,
            original_y = p.original_y,
            original_z = p.original_z,
            dist = math.floor(dist),
            can_move = true,
            can_delete = true,
            can_restore = isMoved
        })
    end

    -- 2. Удаленные объекты мира
    for _, del in ipairs(allDeletedWorldProps) do
        local dist = #(myCoords - vector3(del.x, del.y, del.z))
        table.insert(result, {
            id = del.id or 0,
            db_type = "deleted",
            status_text = "Удалён из мира",
            name = string.format("Объект мира (0x%X)", del.model_hash or 0),
            model_hash = del.model_hash,
            x = math.floor(del.x * 100) / 100,
            y = math.floor(del.y * 100) / 100,
            z = math.floor(del.z * 100) / 100,
            dist = math.floor(dist),
            can_move = false,
            can_delete = true,
            can_restore = true
        })
    end

    -- Сортировка по возрастанию дистанции от камеры/игрока
    table.sort(result, function(a, b) return (a.dist or 0) < (b.dist or 0) end)

    return result
end

-- Главный цикл пространственного стриминга (каждые 800мс)
-- Пропы в радиусе попадают в приоритетную очередь; очередь обрабатывается
-- параллельно с лимитом Config.MaxConcurrentSpawns (throttle от фризов).
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(800)

        local myCoords = Streamer.GetStreamingCenterCoords()
        local inGracePeriod = (GetGameTimer() < despawnGraceUntil)

        local maxStreamedProps = math.max(1, tonumber(Config.MaxStreamedProps) or 500)
        local candidates = {}
        local allowedProps = {}
        local distances = {}

        for _, p in ipairs(allPlacedProps) do
            local pId = tonumber(p.id)
            if pId and not p._isBeingMoved and not p._isTempLive then
                local dist = #(myCoords - vector3(p.x, p.y, p.z))
                distances[pId] = dist
                if dist <= (Config.StreamDistance or 600.0) then
                    candidates[#candidates + 1] = { id = pId, prop = p, dist = dist }
                end
            end
        end

        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        for index = 1, math.min(#candidates, maxStreamedProps) do
            local candidate = candidates[index]
            allowedProps[candidate.id] = candidate
            -- Enqueue once below, after the allowed set is complete.
        end

        -- 1. Стриминг кастомно установленных объектов
        for _, p in ipairs(allPlacedProps) do
            local pId = tonumber(p.id)
            if pId and not p._isBeingMoved then

                -- Временные записи (ожидающие syncNewProp) НИКОГДА не удаляем
                if p._isTempLive then
                    if not spawnedEntities[pId] or not DoesEntityExist(spawnedEntities[pId]) then
                        -- Временные пропы спавним напрямую (без очереди — они уже видны игроку)
                        Streamer.EnqueueSpawn(p, #(myCoords - vector3(p.x, p.y, p.z)))
                    end
                else
                    local dist = distances[pId]

                    if allowedProps[pId] then
                        -- В радиусе стриминга: если ещё не заспавнен — в очередь
                        if not spawnedEntities[pId] or not DoesEntityExist(spawnedEntities[pId]) then
                            -- Даже после выхода из редактора сохраняем мягкий throttle.
                            -- Grace-период запрещает деспавн, но не должен обходить очередь.
                            Streamer.EnqueueSpawn(p, dist)
                        end
                    else
                        -- Вышел за радиус: убираем из очереди и деспавним
                        Streamer.DequeueSpawn(pId)
                        if not inGracePeriod then
                            DespawnBuilderProp(pId)
                        end
                    end
                end
            end
        end

        -- 2. Очередь спавна обрабатывается отдельным ограниченным потоком выше.

        -- Share one pool snapshot for newly reached deletion records only.
        local deletionPool
        -- 3. Скрытие удаленных объектов мира в радиусе стриминга
        for _, del in ipairs(allDeletedWorldProps) do
            local dist = #(myCoords - vector3(del.x, del.y, del.z))
            if dist <= (Config.StreamDistance or 600.0) and not appliedDeletedWorldProps[GetDeletedWorldPropKey(del)] then
                deletionPool = deletionPool or GetGamePool('CObject')
                Streamer.ApplyDeletedWorldProp(del, deletionPool)
            end
        end
    end
end)

-- Полная очистка всех заспавненных сущностей при остановке/перезапуске скрипта
local function CleanupAllBuilderEntities()
    -- Сбрасываем очередь и счётчик параллельных загрузок
    spawnQueue   = {}
    activeSpawns = 0
    queuedProps  = {}
    spawnQueueDirty = false

    for propId, ent in pairs(spawnedEntities) do
        if DoesEntityExist(ent) then
            if GetResourceState('thehunt_interact') == 'started' then
                pcall(function() exports['thehunt_interact']:RemoveTargetEntity(ent) end)
            end
            SetEntityAsMissionEntity(ent, true, true)
            SetEntityCollision(ent, false, false)
            DeleteEntity(ent)
        end
    end
    spawnedEntities = {}
    loadingProps = {}

    local ghost = Preview and Preview.GetGhostEntity() or nil
    if ghost and DoesEntityExist(ghost) then
        DeleteEntity(ghost)
    end
end

AddEventHandler("onResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end
    CleanupAllBuilderEntities()
end)

AddEventHandler("onClientResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end
    CleanupAllBuilderEntities()
end)
