-- =================================================================
-- HUNT: Hard RP — Dynamic Interaction Engine | Client Module
-- =================================================================

local isCharacterReady = false
local currentTarget = nil
local isReticleVisible = false
local isMenuOpen = false
local isMMBPressed = false

local ModelTargets = {}
local ModelTargetLayers = {}
local EntityTargets = {}
local ZoneTargets = {}

-- Actions may be a static list (the public API contract) or a resolver function.
-- The resolver extension is used internally by the AWZ world-object bridge and
-- leaves all existing AddTarget* consumers unchanged.
local function ResolveTargetActions(targetData, entity)
    local actions
    if type(targetData.actions) == 'function' then
        local ok, resolved = pcall(targetData.actions, entity)
        if not ok then
            print(('[HUNT INTERACT] Dynamic target resolver failed: %s'):format(tostring(resolved)))
            actions = {}
        elseif type(resolved) ~= 'table' then
            print(('[HUNT INTERACT] Dynamic target resolver returned %s instead of an action table.'):format(type(resolved)))
            actions = {}
        else
            actions = resolved
        end
    else
        actions = targetData.actions or {}
    end

    if entity then
        local layers = ModelTargetLayers[GetEntityModel(entity)]
        if layers then
            local merged = {}
            for _, action in ipairs(actions) do merged[#merged + 1] = action end
            for _, layer in ipairs(layers) do
                local ok, layerActions = pcall(layer.provider, entity)
                if ok and type(layerActions) == 'table' then
                    for _, action in ipairs(layerActions) do merged[#merged + 1] = action end
                end
            end
            actions = merged
        end
    end
    return actions
end

-- Ожидание выбора персонажа VORP
RegisterNetEvent("thehunt:character:selected", function()
    isCharacterReady = true
    TriggerEvent("thehunt_interact:ready")
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Wait(500)
    isCharacterReady = true
    TriggerEvent("thehunt_interact:ready")
end)

Citizen.CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do
        Citizen.Wait(200)
    end
    isCharacterReady = true
    TriggerEvent("thehunt_interact:ready")
end)

-- =================================================================
-- EXPORTS: РЕГИСТРАЦИЯ ОБЪЕКТОВ И ЗОН ДЛЯ ВЗАИМОДЕЙСТВИЯ
-- =================================================================

--- Добавить интерактивные действия для модели
exports('AddTargetModel', function(models, actions, maxDist)
    if type(models) ~= 'table' then models = { models } end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and (GetHashKey(model) or joaat(model)) or model
        if hash then
            local data = {
                actions = actions,
                maxDist = maxDist or 1.7
            }
            ModelTargets[hash] = data
            local n = tonumber(hash)
            if n then
                if n < 0 then
                    ModelTargets[n + 4294967296] = data
                elseif n > 2147483647 then
                    ModelTargets[n - 4294967296] = data
                end
            end
        end
    end
end)

-- Adds a non-destructive action layer. Unlike AddTargetModel, it never replaces
-- the model owner registered by existing HUNT resources. `options.raycastOnly`
-- is opt-in and keeps the layer out of the proximity fallback; direct ray hits
-- still use the normal layer/provider path.
exports('AddTargetModelLayer', function(models, provider, maxDist, options)
    if type(models) ~= 'table' then models = { models } end
    options = type(options) == 'table' and options or {}
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and joaat(model) or model
        ModelTargetLayers[hash] = ModelTargetLayers[hash] or {}
        ModelTargetLayers[hash][#ModelTargetLayers[hash] + 1] = {
            provider = provider,
            maxDist = maxDist or 1.7,
            raycastOnly = options.raycastOnly == true
        }
    end
end)

-- Internal bootstrap channel: unlike a self-export it is available during the
-- complete resource start sequence, so bundled interaction packs can register
-- their models deterministically.
RegisterNetEvent('thehunt_interact:registerBundledModels', function(models, actions, maxDist)
    if type(models) ~= 'table' then return end
    for _, hash in ipairs(models) do
        ModelTargets[hash] = { actions = actions, maxDist = maxDist or 1.7 }
    end
end)

--- Удалить модель
exports('RemoveTargetModel', function(models)
    if type(models) ~= 'table' then models = { models } end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and joaat(model) or model
        ModelTargets[hash] = nil
    end
end)

--- Добавить интерактивные действия для конкретной сущности (entity handle)
exports('AddTargetEntity', function(entity, actions, maxDist, options)
    if not DoesEntityExist(entity) then return end
    options = type(options) == 'table' and options or {}
    EntityTargets[entity] = {
        actions = actions,
        maxDist = maxDist or 1.7,
        proximityFallback = options.proximityFallback == true,
        isCorpse = options.isCorpse == true
    }
end)

--- Удалить сущность
exports('RemoveTargetEntity', function(entity)
    EntityTargets[entity] = nil
end)

--- Добавить зону взаимодействия
exports('AddTargetZone', function(name, coords, radius, actions, maxDist)
    ZoneTargets[name] = {
        coords = coords,
        radius = radius or 1.3,
        actions = actions,
        maxDist = maxDist or 1.7
    }
end)

RegisterNetEvent('thehunt_interact:registerBundledZone', function(name, coords, radius, actions, maxDist)
    ZoneTargets[name] = {
        coords = coords, radius = radius or 1.3, actions = actions, maxDist = maxDist or 1.7
    }
end)

--- Удалить зону взаимодействия
exports('RemoveTargetZone', function(name)
    ZoneTargets[name] = nil
end)

--- Очистить зоны взаимодействия по префиксу или все
exports('ClearTargetZones', function(prefix)
    if prefix then
        for name in pairs(ZoneTargets) do
            if string.sub(name, 1, #prefix) == prefix then
                ZoneTargets[name] = nil
            end
        end
    else
        ZoneTargets = {}
    end
end)

-- =================================================================
-- RAYCAST & TARGET SCANNING (НЕВИДИМЫЙ ЛАЗЕР ИЗ КАМЕРЫ)
-- =================================================================

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function GetCameraRaycast(maxDistance)
    local camRot = GetGameplayCamRot(2)
    local camCoords = GetGameplayCamCoord()
    local dir = RotationToDirection(camRot)
    local destCoords = camCoords + (dir * maxDistance)

    -- Flag 287 = Everything (World, Objects, Peds, Vehicles)
    local ray = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        destCoords.x, destCoords.y, destCoords.z,
        287, PlayerPedId(), 4
    )
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)
    return (hit == 1 or hit == true), entityHit, endCoords, camCoords, dir
end

-- Static map furniture may not be returned as entityHit by a camera raycast.
-- Use RedM's nearby-object itemset only when ray-first detection found nothing.
-- Raycast-only layers still get a strict model-envelope check so static map
-- props continue to work without the old broad "aim near the center" cone.
local function IsRaycastOnModelSurface(entity, hitCoords)
    if not hitCoords or not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local ok, localHit = pcall(function()
        return GetOffsetFromEntityGivenWorldCoords(entity, hitCoords.x, hitCoords.y, hitCoords.z)
    end)
    if not ok or not localHit then return false end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(entity))
    if not minDim or not maxDim then return false end

    local padding = 0.06
    local span = math.max(
        math.abs(maxDim.x - minDim.x),
        math.abs(maxDim.y - minDim.y),
        math.abs(maxDim.z - minDim.z)
    )
    local surfaceTolerance = math.max(0.10, math.min(0.24, span * 0.06))

    local inside = localHit.x >= minDim.x - padding and localHit.x <= maxDim.x + padding
        and localHit.y >= minDim.y - padding and localHit.y <= maxDim.y + padding
        and localHit.z >= minDim.z - padding and localHit.z <= maxDim.z + padding
    if not inside then return false end

    return math.abs(localHit.x - minDim.x) <= surfaceTolerance
        or math.abs(localHit.x - maxDim.x) <= surfaceTolerance
        or math.abs(localHit.y - minDim.y) <= surfaceTolerance
        or math.abs(localHit.y - maxDim.y) <= surfaceTolerance
        or math.abs(localHit.z - minDim.z) <= surfaceTolerance
        or math.abs(localHit.z - maxDim.z) <= surfaceTolerance
end

local function IsRaycastInsideModel(entity, hitCoords)
    if not hitCoords or not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local ok, localHit = pcall(function()
        return GetOffsetFromEntityGivenWorldCoords(entity, hitCoords.x, hitCoords.y, hitCoords.z)
    end)
    if not ok or not localHit then return false end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(entity))
    if not minDim or not maxDim then return false end

    local padding = 0.08
    return localHit.x >= minDim.x - padding and localHit.x <= maxDim.x + padding
        and localHit.y >= minDim.y - padding and localHit.y <= maxDim.y + padding
        and localHit.z >= minDim.z - padding and localHit.z <= maxDim.z + padding
end

local function FindNearbyModelTarget(pedCoords, hitCoords, camCoords, camDir, hasRayHit)
    local itemset = CreateItemset(true)
    local size = Citizen.InvokeNative(0x59B57C4B06531E1E, pedCoords, 2.5, itemset, 3, Citizen.ResultAsInteger())
    local closest, closestDistance = nil, 999.0
    if size and size > 0 then
        for index = 0, size - 1 do
            local entity = GetIndexedItemInItemset(index, itemset)
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                local model = GetEntityModel(entity)
                local targetData = ModelTargets[model]
                if not targetData and type(model) == 'number' then
                    if model < 0 then
                        targetData = ModelTargets[model + 4294967296]
                    elseif model > 2147483647 then
                        targetData = ModelTargets[model - 4294967296]
                    end
                end
                local requiresSurfaceHit = false
                if not targetData and ModelTargetLayers[model] then
                    local hasProximityLayer = false
                    local hasRaycastOnlyLayer = false
                    for _, layer in ipairs(ModelTargetLayers[model]) do
                        if not layer.raycastOnly then
                            hasProximityLayer = true
                        else
                            hasRaycastOnlyLayer = true
                        end
                    end
                    if hasProximityLayer then
                        targetData = { actions = {}, maxDist = 2.0 }
                    elseif hasRaycastOnlyLayer and hasRayHit and IsRaycastOnModelSurface(entity, hitCoords) then
                        targetData = { actions = {}, maxDist = 2.0 }
                        requiresSurfaceHit = true
                    end
                end
                if targetData then
                    local coords = GetEntityCoords(entity)
                    local distance = #(pedCoords - coords)
                    local maxDist = targetData.maxDist or 1.7
                    if distance <= maxDist then
                        -- Прицел должен указывать строго на саму модельку пропа, а не за её пределы
                        local isAimedAt = hasRayHit and (IsRaycastInsideModel(entity, hitCoords) or (requiresSurfaceHit and IsRaycastOnModelSurface(entity, hitCoords)))
                        if isAimedAt and distance < closestDistance then
                            closest, closestDistance = { entity = entity, coords = hitCoords or coords, data = targetData }, distance
                        end
                    end
                end
            end
        end
    end
    if IsItemsetValid(itemset) then DestroyItemset(itemset) end
    return closest
end

local BURDOCK_MODEL_HASH = joaat("s_burdock01x")

-- Проверка режима перемещения / установки пропа (thehunt_builder)
local function IsPlacementModeActive()
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isPlacingProp then
        return true
    end
    if GetResourceState('thehunt_builder') == 'started' then
        local ok, isPlacing = pcall(function()
            return exports['thehunt_builder']:IsPlacing()
        end)
        if ok and isPlacing then return true end
    end
    return false
end

local function IsInventoryActive()
    if GetResourceState('thehunt_inventory') == 'started' then
        local ok, isOpen = pcall(function()
            return exports['thehunt_inventory']:isInventoryOpen()
        end)
        if ok and isOpen then return true end
    end
    return false
end

-- Быстрый поток сканирования (35мс)
Citizen.CreateThread(function()
    while true do
        if isCharacterReady and not LocalPlayer.state.huntWorldInteractionActive and not isMenuOpen and not TheHuntAwzInteractionActive and not IsPauseMenuActive() and not IsPlacementModeActive() and not IsInventoryActive() then
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)

            local hit, entity, hitCoords, camCoords, camDir = GetCameraRaycast(6.5)
            local detectedTarget = nil

            -- 1. Прямое попадание луча в зарегистрированный объект/энтити/модель при близкой дистанции
            if hit and entity and DoesEntityExist(entity) then
                local entityCoords = GetEntityCoords(entity)
                local distToHit = #(pedCoords - hitCoords)
                local distToTargetPed = #(pedCoords - entityCoords)
                local model = GetEntityModel(entity)
                local targetData = EntityTargets[entity] or ModelTargets[model]
                if not targetData and type(model) == 'number' then
                    if model < 0 then
                        targetData = ModelTargets[model + 4294967296]
                    elseif model > 2147483647 then
                        targetData = ModelTargets[model - 4294967296]
                    end
                end
                if not targetData and ModelTargetLayers[model] then
                    targetData = { actions = {}, maxDist = 2.0 }
                end

                if targetData then
                    local maxDist = targetData.maxDist or 1.7
                    local isPed = IsEntityAPed(entity)

                    if isPed then
                        -- Для игрока/персонажа: луч движка точно попал в хитбокс/капсулу тела (голова, туловище, ноги)
                        if distToHit <= maxDist or distToTargetPed <= maxDist then
                            detectedTarget = {
                                type = 'entity',
                                entity = entity,
                                model = model,
                                coords = hitCoords,
                                actions = ResolveTargetActions(targetData, entity),
                                maxDist = maxDist
                            }
                        end
                    else
                        local hitOnEntityDist = #(hitCoords - entityCoords)
                        local maxHitOffset = 2.0

                        -- Для обычных объектов/пропов: луч должен попадать строго в хитбокс модели
                        if (distToHit <= maxDist or distToTargetPed <= maxDist) and hitOnEntityDist <= maxHitOffset then
                            detectedTarget = {
                                type = EntityTargets[entity] and 'entity' or 'model',
                                entity = entity,
                                model = model,
                                coords = hitCoords,
                                actions = ResolveTargetActions(targetData, entity),
                                maxDist = maxDist
                            }
                        end
                    end
                end
            end

            -- 1.1. Сканирование ИСКЛЮЧИТЕЛЬНО для модельки куста лопуха (s_burdock01x), так как у листвы нет монолитной коллизии
            if not detectedTarget and hit then
                local bestDist = 999.0
                for entHandle, targetData in pairs(EntityTargets) do
                    if DoesEntityExist(entHandle) and GetEntityModel(entHandle) == BURDOCK_MODEL_HASH then
                        local entCoords = GetEntityCoords(entHandle)
                        local distToPed = #(pedCoords - entCoords)
                        local maxDist = targetData.maxDist or 1.7
                        if distToPed <= maxDist then
                            local distToHit = #(hitCoords - entCoords)
                            if distToHit <= 0.85 and distToHit < bestDist then
                                bestDist = distToHit
                                detectedTarget = {
                                    type = 'entity',
                                    entity = entHandle,
                                    model = BURDOCK_MODEL_HASH,
                                    coords = entCoords,
                                    actions = targetData.actions,
                                    maxDist = maxDist
                                }
                            end
                        end
                    end
                end
            end

            -- 1.2. Сканирование для зарегистрированных педов (лежащих в ноке / рэгдолле игроков, трупов),
            -- если луч камеры ударился о землю рядом с телом или камера/прицел направлены на тело
            if not detectedTarget then
                local bestPedDist = 999.0
                for entHandle, targetData in pairs(EntityTargets) do
                    if DoesEntityExist(entHandle) and entHandle ~= ped then
                        local isPed = IsEntityAPed(entHandle)
                        local isCorpseOrRagdoll = targetData.proximityFallback or targetData.isCorpse or (isPed and (IsEntityDead(entHandle) or IsPedRagdoll(entHandle) or (GetEntityHealth(entHandle) <= 0)))

                        if isPed or isCorpseOrRagdoll then
                            local entCoords = GetEntityCoords(entHandle)
                            local maxDist = targetData.maxDist or 2.2

                            local pelvisCoords = nil
                            local headCoords = nil
                            if isCorpseOrRagdoll and isPed then
                                pelvisCoords = GetPedBoneCoords(entHandle, 14412, 0.0, 0.0, 0.0)
                                headCoords = GetPedBoneCoords(entHandle, 21030, 0.0, 0.0, 0.0)
                            end

                            local distToPed = #(pedCoords - entCoords)
                            if pelvisCoords and #(pelvisCoords - vector3(0, 0, 0)) > 1.0 then
                                local dPelvis = #(pedCoords - pelvisCoords)
                                if dPelvis < distToPed then distToPed = dPelvis end
                            end
                            if headCoords and #(headCoords - vector3(0, 0, 0)) > 1.0 then
                                local dHead = #(pedCoords - headCoords)
                                if dHead < distToPed then distToPed = dHead end
                            end

                            if distToPed <= maxDist then
                                local isAimNear = false

                                -- 1. Проекция на 2D экран (центр экрана направлен на тело / таз / голову)
                                if isCorpseOrRagdoll then
                                    local checkBones = { pelvisCoords, headCoords, entCoords }
                                    for _, bPos in ipairs(checkBones) do
                                        if bPos and #(bPos - vector3(0, 0, 0)) > 1.0 then
                                            local onScreen, sx, sy = GetScreenCoordFromWorldCoord(bPos.x, bPos.y, bPos.z)
                                            if onScreen then
                                                local dx = sx - 0.5
                                                local dy = sy - 0.5
                                                -- Радиус ~0.24 экрана от центра (0.058 в квадрате)
                                                if (dx * dx + dy * dy) <= 0.058 then
                                                    isAimNear = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end

                                -- 2. Попадание луча камеры в землю или объект рядом с телом
                                if not isAimNear and hit and hitCoords then
                                    if #(hitCoords - entCoords) <= 2.2 then
                                        isAimNear = true
                                    elseif pelvisCoords and #(hitCoords - pelvisCoords) <= 2.2 then
                                        isAimNear = true
                                    elseif headCoords and #(hitCoords - headCoords) <= 2.0 then
                                        isAimNear = true
                                    end
                                end

                                -- 3. Вектор взгляда камеры направлен в сторону тела
                                if not isAimNear and isCorpseOrRagdoll and camCoords and camDir then
                                    local checkTargets = { pelvisCoords, headCoords, entCoords }
                                    for _, tPos in ipairs(checkTargets) do
                                        if tPos and #(tPos - vector3(0, 0, 0)) > 1.0 then
                                            local toTarget = tPos - camCoords
                                            local len = #toTarget
                                            if len > 0.1 then
                                                local dot = (toTarget.x * camDir.x + toTarget.y * camDir.y + toTarget.z * camDir.z) / len
                                                if dot > 0.65 then
                                                    isAimNear = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end

                                if isAimNear and distToPed < bestPedDist then
                                    bestPedDist = distToPed
                                    local targetCoords = (pelvisCoords and #(pelvisCoords - vector3(0, 0, 0)) > 1.0) and pelvisCoords or entCoords
                                    detectedTarget = {
                                        type = 'entity',
                                        entity = entHandle,
                                        model = GetEntityModel(entHandle),
                                        coords = targetCoords,
                                        actions = ResolveTargetActions(targetData, entHandle),
                                        maxDist = maxDist
                                    }
                                end
                            end
                        end
                    end
                end
            end

            -- 2. Проверка попадания луча камеры по площади зарегистрированных дверей/зон при близкой дистанции
            if not detectedTarget and hit then
                local bestZoneDist = 999.0
                for id, zone in pairs(ZoneTargets) do
                    local zoneRadius = zone.radius or 1.4
                    local maxPedDist = zone.maxDist or 1.6
                    local distToPed = #(pedCoords - zone.coords)
                    local distToHit = #(hitCoords - zone.coords)

                    if (distToPed <= maxPedDist or #(pedCoords - hitCoords) <= maxPedDist) and distToHit <= zoneRadius and distToHit < bestZoneDist then
                        bestZoneDist = distToHit
                        detectedTarget = {
                            type = 'zone',
                            zoneId = id,
                            coords = hitCoords,
                            actions = ResolveTargetActions(zone, nil),
                            maxDist = maxPedDist
                        }
                    end
                end
            end

            -- 3. Применение обнаруженной цели
            if not detectedTarget then
                local nearby = FindNearbyModelTarget(pedCoords, hitCoords, camCoords, camDir, hit)
                if nearby then
                    detectedTarget = {
                        type = 'model', entity = nearby.entity, model = GetEntityModel(nearby.entity),
                        coords = nearby.coords, actions = ResolveTargetActions(nearby.data, nearby.entity),
                        maxDist = nearby.data.maxDist or 1.7
                    }
                end
            end

            if detectedTarget then
                currentTarget = detectedTarget
                if not isReticleVisible then
                    isReticleVisible = true
                    SendNUIMessage({ type = 'SHOW_RETICLE' })
                end
            else
                if isReticleVisible then
                    isReticleVisible = false
                    SendNUIMessage({ type = 'HIDE_RETICLE' })
                end
                currentTarget = nil
            end

            Citizen.Wait(35)
        else
            if isReticleVisible then
                isReticleVisible = false
                SendNUIMessage({ type = 'HIDE_RETICLE' })
            end
            currentTarget = nil
            Citizen.Wait(80)
        end
    end
end)

-- =================================================================
-- CONTROL & CAMERA BLOCKING WHILE INTERACTION MENU IS OPEN
-- =================================================================

local activeTargetActions = nil
local activeTargetEntity = nil
local activeTargetCoords = nil
local activeTargetMaxDist = 1.7
local activeTargetInfo = nil
local activeTargetActionStack = {}

local function OpenInteractionMenu()
    if not currentTarget or isMenuOpen or not isCharacterReady or IsPlacementModeActive() then return end

    isMenuOpen = true
    isMMBPressed = false
    activeTargetActions = currentTarget.actions
    activeTargetEntity = currentTarget.entity
    activeTargetInfo = {
        type = currentTarget.type,
        entity = currentTarget.entity,
        model = currentTarget.model,
        zoneId = currentTarget.zoneId
    }
    activeTargetActionStack = {}

    if currentTarget.coords then
        activeTargetCoords = currentTarget.coords
    elseif currentTarget.entity and DoesEntityExist(currentTarget.entity) then
        activeTargetCoords = GetEntityCoords(currentTarget.entity)
    else
        activeTargetCoords = GetEntityCoords(PlayerPedId())
    end
    activeTargetMaxDist = currentTarget.maxDist or 1.7

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        type = 'OPEN_INTERACTION_MENU',
        actions = currentTarget.actions,
        targetInfo = activeTargetInfo
    })
end

local function CloseInteractionMenu()
    if not isMenuOpen then return end
    TriggerEvent('thehunt_interact:previewClear')
    isMenuOpen = false
    isMMBPressed = false
    activeTargetActions = nil
    activeTargetEntity = nil
    activeTargetCoords = nil
    activeTargetInfo = nil
    activeTargetActionStack = {}
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_INTERACTION_MENU' })
end

-- Поток блокировки управления при открытом меню взаимодействия
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            Citizen.Wait(0)
            local ped = PlayerPedId()

            -- Автозакрытие меню, если отойти от объекта дальше допустимого расстояния (1.7м)
            local currentTargetPos = activeTargetCoords
            if activeTargetEntity and DoesEntityExist(activeTargetEntity) then
                local entPos = GetEntityCoords(activeTargetEntity)
                local pedPos = GetEntityCoords(ped)
                if activeTargetCoords and #(pedPos - activeTargetCoords) < #(pedPos - entPos) then
                    currentTargetPos = activeTargetCoords
                else
                    currentTargetPos = entPos
                end
            end

            if currentTargetPos then
                local dist = #(GetEntityCoords(ped) - currentTargetPos)
                local maxAllowedDist = (activeTargetMaxDist or 1.7) + 0.2
                if dist > maxAllowedDist then
                    CloseInteractionMenu()
                end
            end

            -- Отслеживание закрытия на повторное нажатие G
            if IsControlJustPressed(0, 0x5415BE48) or IsDisabledControlJustPressed(0, 0x5415BE48)
            or IsControlJustPressed(0, 0x760A9C6F) or IsDisabledControlJustPressed(0, 0x760A9C6F) then
                CloseInteractionMenu()
                Citizen.Wait(200)
            end

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
            Citizen.Wait(120)
        end
    end
end)

-- Перехват клавиши G для открытия меню (когда есть прицел)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isCharacterReady and not LocalPlayer.state.huntWorldInteractionActive and isReticleVisible and not isMenuOpen and not IsPauseMenuActive() and not IsPlacementModeActive() and not IsInventoryActive() then
            if IsControlJustPressed(0, 0x5415BE48) or IsDisabledControlJustPressed(0, 0x5415BE48)
            or IsControlJustPressed(0, 0x760A9C6F) or IsDisabledControlJustPressed(0, 0x760A9C6F) then
                OpenInteractionMenu()
                Citizen.Wait(200)
            end
        else
            Citizen.Wait(80)
        end
    end
end)

-- =================================================================
-- NUI CALLBACKS
-- =================================================================

local function HandleActionTrigger(data, cb)
    local actionsList = activeTargetActions
    local actionId = data.actionId
    local targetInfo = data.targetInfo or {}
    local eventName = data.event

    if actionsList then
        for _, act in ipairs(actionsList) do
            if act.id == actionId then
                if type(act.submenu) == 'table' then
                    activeTargetActionStack[#activeTargetActionStack + 1] = activeTargetActions
                    activeTargetActions = act.submenu
                    SendNUIMessage({
                        type = 'OPEN_INTERACTION_MENU',
                        actions = activeTargetActions,
                        targetInfo = activeTargetInfo or targetInfo
                    })
                    cb('ok')
                    return
                end

                CloseInteractionMenu()
                if type(act.action) == 'function' then
                    local ok, err = pcall(act.action, targetInfo)
                    if not ok then
                        print(string.format("^1[HUNT INTERACT] Ошибка выполнения действия '%s': %s^7", tostring(actionId), tostring(err)))
                    end
                    cb('ok')
                    return
                elseif act.awzAction then
                    TriggerEvent('thehunt_interact:awzStart', act.awzAction, targetInfo)
                    cb('ok')
                    return
                elseif act.event then
                    if act.isServer or act.isServerEvent then
                        TriggerServerEvent(act.event, targetInfo, actionId)
                    else
                        TriggerEvent(act.event, targetInfo, actionId)
                    end
                    cb('ok')
                    return
                end
            end
        end
    end

    CloseInteractionMenu()
    if eventName and eventName ~= "" then
        if data.isServer or data.isServerEvent then
            TriggerServerEvent(eventName, targetInfo, actionId)
        else
            TriggerEvent(eventName, targetInfo, actionId)
        end
    end
    cb('ok')
end

RegisterNUICallback('triggerAction', HandleActionTrigger)
RegisterNUICallback('executeAction', HandleActionTrigger)

RegisterNUICallback('previewAction', function(data, cb)
    -- Always clear the previous ghost first. Actions that opt in provide the
    -- preview event themselves; existing HUNT actions remain untouched.
    TriggerEvent('thehunt_interact:previewClear')
    local actionId = data and data.actionId
    local targetInfo = (data and data.targetInfo) or activeTargetInfo or {}
    if activeTargetActions and actionId then
        for _, act in ipairs(activeTargetActions) do
            if act.id == actionId and act.previewEvent then
                TriggerEvent(act.previewEvent, targetInfo, actionId)
                break
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeInteraction', function(data, cb)
    CloseInteractionMenu()
    cb('ok')
end)

RegisterNUICallback('backInteraction', function(data, cb)
    if not isMenuOpen then cb('ok') return end
    TriggerEvent('thehunt_interact:previewClear')
    local previousActions = table.remove(activeTargetActionStack)
    if previousActions then
        activeTargetActions = previousActions
        SendNUIMessage({
            type = 'OPEN_INTERACTION_MENU',
            actions = activeTargetActions,
            targetInfo = activeTargetInfo
        })
    else
        CloseInteractionMenu()
    end
    cb('ok')
end)

exports('isInteractOpen', function()
    return isMenuOpen == true
end)

local isInfoModalOpen = false
local infoModalCoords = nil

local function InternalCloseInfoModal()
    if not isInfoModalOpen then return end
    isInfoModalOpen = false
    infoModalCoords = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_INFO_MODAL' })
end

RegisterNUICallback('closeInfoModal', function(data, cb)
    InternalCloseInfoModal()
    cb('ok')
end)

exports('ShowInfoModal', function(data)
    if not data then return end
    isInfoModalOpen = true
    infoModalCoords = data.coords
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        type = 'SHOW_INFO_MODAL',
        title = data.title or 'Информация',
        rows = data.rows or {}
    })
end)

exports('CloseInfoModal', function()
    InternalCloseInfoModal()
end)

RegisterNetEvent('thehunt_interact:showInfoModal', function(data)
    exports['thehunt_interact']:ShowInfoModal(data)
end)

RegisterNetEvent('thehunt_interact:closeInfoModal', function()
    InternalCloseInfoModal()
end)

Citizen.CreateThread(function()
    while true do
        if isInfoModalOpen then
            Citizen.Wait(200)
            if infoModalCoords then
                local ped = PlayerPedId()
                local pCoords = GetEntityCoords(ped)
                local dist = #(pCoords - infoModalCoords)
                if dist > 2.6 then
                    InternalCloseInfoModal()
                end
            end
        else
            Citizen.Wait(600)
        end
    end
end)

-- AWZ integration is disabled pending an isolated rewrite. This keeps the
-- established interaction engine and all dependent resources operational.
if false then
-- =================================================================
-- Bundled AWZ world interactions (kept in this known-loaded client file)
-- =================================================================

--[[
  AWZ interaction definitions adapted for HUNT's existing interaction engine.
  Source: https://github.com/AWZ-Code/awz_interactions
  Copyright AWZ Code / kibook contributors. Original source is GPL-3.0-or-later.
  This adapted definitions file must be distributed under GPL-3.0-or-later with
  its corresponding source when the resource is conveyed.
]]
-- The upstream data uses these compatibility predicates. They must exist before
-- its tables are built so gender/age-specific actions remain filtered.
function IsPedChild(ped) return Citizen.InvokeNative(0x137772000DAF42C5, ped) end
function IsPedAdult(ped) return IsPedHuman(ped) and not IsPedChild(ped) end
function IsPedHumanMale(ped) return IsPedHuman(ped) and IsPedMale(ped) end
function IsPedHumanFemale(ped) return IsPedHuman(ped) and not IsPedMale(ped) end
function IsPedAdultMale(ped) return not IsPedChild(ped) and IsPedMale(ped) end
function IsPedAdultFemale(ped) return not IsPedChild(ped) and not IsPedMale(ped) end

GenericChairs = {
    'mp005_s_posse_col_chair01x',
    'mp005_s_posse_foldingchair_01x',
    'mp005_s_posse_trad_chair01x',
    'p_ambchair01x',
    'p_ambchair02x',
    'p_armchair01x',
    'p_bistrochair01x',
    'p_bench20x',
    'p_benchpiano02x',
    'p_chair02x',
    'p_chair04x',
    'p_chair05x',
    'p_chair06x',
    'p_chair07x',
    'p_chair09x',
    'p_chair_10x',
    'p_chair11x',
    'p_chair12bx',
    'p_chair12x',
    'p_chair13x',
    'p_chair14x',
    'p_chair15x',
    'p_chair16x',
    'p_chair17x',
    'p_chair18x',
    'p_chair19x',
    'p_chair20x',
    'p_chair21x',
    'p_chair21x_fussar',
    'p_chair22x',
    'p_chair23x',
    'p_chair24x',
    'p_chair25x',
    'p_chair26x',
    'p_chair27x',
    'p_chair30x',
    'p_chair31x',
    'p_chair37x',
    'p_chair38x',
    'p_chair_barrel04b',
    'p_chaircomfy01x',
    'p_chaircomfy02',
    'p_chaircomfy03x',
    'p_chaircomfy04x',
    'p_chaircomfy05x',
    'p_chaircomfy06x',
    'p_chaircomfy07x',
    'p_chaircomfy08x',
    'p_chaircomfy09x',
    'p_chaircomfy10x',
    'p_chaircomfy11x',
    'p_chaircomfy12x',
    'p_chaircomfy14x',
    'p_chaircomfy17x',
    'p_chaircomfy18x',
    'p_chaircomfy22x',
    'p_chaircomfy23x',
    'p_chairdoctor01x',
    'p_chair_crate02x',
    'p_chair_crate15x',
    'p_chair_cs05x',
    'p_chairdesk01x',
    'p_chairdesk02x',
    'p_chairdining01x',
    'p_chairdining02x',
    'p_chairdining03x',
    'p_chaireagle01x',
    'p_chairfolding02x',
    'p_chairhob01x',
    'p_chairhob02x',
    'p_chairmed01x',
    'p_chairmed02x',
    'p_chairoffice02x',
    'p_chairpokerfancy01x',
    'p_chairporch01x',
    'p_chair_privatedining01x',
    'p_chairrocking02x',
    'p_chairrocking03x',
    'p_chairrocking04x',
    'p_chairrocking05x',
    'p_chairrocking06x',
    'p_chairrustic01x',
    'p_chairrustic02x',
    'p_chairrustic03x',
    'p_chairrustic04x',
    'p_chairrustic05x',
    'p_chairsalon01x',
    'p_chairvictorian01x',
    'p_chairwhite01x',
    'p_chairwicker01x',
    'p_chairwicker02x',
    'p_cs_electricchair01x',
    'p_diningchairs01x',
    'p_gen_chair07x',
    'p_oldarmchair01x',
    'p_pianochair01x',
    'p_privatelounge_chair01x',
    'p_rockingchair01x',
    'p_rockingchair02x',
    'p_rockingchair03x',
    'p_seatbench01x',
    'p_settee02bx',
    'p_settee03x',
    'p_settee03bx',
    'p_sit_chairwicker01b',
    'p_stool01x',
    'p_stool02x',
    'p_stool03x',
    'p_stool04x',
    'p_stool05x',
    'p_stool06x',
    'p_stool07x',
    'p_stool08x',
    'p_stool09x',
    'p_stool10x',
    'p_stool12x',
    'p_stool13x',
    'p_stool14x',
    'p_stoolcomfy01x',
    'p_stoolcomfy02x',
    'p_stoolfolding01bx',
    'p_stoolfolding01x',
    'p_stoolwinter01x',
    'o_stoolfoldingstatic01x',
    'p_theaterchair01b01x',
    'p_windsorchair01x',
    'p_windsorchair02x',
    'p_windsorchair03x',
    'p_woodbench02x',
    'p_woodendeskchair01x',
    's_bench01x',
}

GenericBenches = {
    'p_bench03x',
    'p_bench06x',
    'p_bench08bx',
    'p_bench09x',
    'p_bench15_mjr',
    'p_bench15x',
    'p_bench18x',
    'p_benchch01x',
    'p_benchironnbx01x',
    'p_bench_log01x',
    'p_bench_log02x',
    'p_bench_log03x',
    'p_bench_log04x',
    'p_bench_log05x',
    'p_bench_log06x',
    'p_bench_log07x',
    'p_bench_logsnow07x',
    'p_benchnbx02x',
    'p_benchnbx03x',
    'p_couch01x',
    'p_couch02x',
    'p_couch05x',
    'p_couch06x',
    'p_couch08x',
    'p_couch09x',
    'p_couch10x',
    'p_couch11x',
    'p_couchwicker01x',
    'p_hallbench01x',
    'p_loveseat01x',
    'p_settee01x',
    'p_settee04x',
    'p_settee_05x',
    'p_sit_chairwicker01a',
    'p_sofa02x',
    'p_windsorbench01x',
}

GenericChairAndBenchScenarios = {
    { name = 'GENERIC_SEAT_BENCH_SCENARIO' },
    { name = 'GENERIC_SEAT_CHAIR_SCENARIO',                   isCompatible = IsPedHumanMale },
    { name = 'GENERIC_SEAT_CHAIR_TABLE_SCENARIO' },
    { name = 'MP_LOBBY_PROP_HUMAN_SEAT_BENCH_PORCH_DRINKING' },
    { name = 'MP_LOBBY_PROP_HUMAN_SEAT_BENCH_PORCH_SMOKING' },
    { name = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR' },
    { name = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS' },
    { name = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR_WHITTLE' },
    { name = 'PROP_CAMP_FIRE_SEAT_CHAIR' },
    { name = 'PROP_HUMAN_CAMP_FIRE_SEAT_BOX' },
    { name = 'PROP_HUMAN_SEAT_BENCH_CONCERTINA',               isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_BENCH_FIDDLE',                   isCompatible = IsPedHumanFemale },
    { name = 'PROP_HUMAN_SEAT_BENCH_JAW_HARP',                 isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_BENCH_MANDOLIN',                 isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR' },
    { name = 'PROP_HUMAN_SEAT_CHAIR_BANJO',                    isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_CLEAN_RIFLE' },
    { name = 'PROP_HUMAN_SEAT_CHAIR_CLEAN_SADDLE' },
    { name = 'PROP_HUMAN_SEAT_CHAIR_CRAB_TRAP',                isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_CIGAR',                    isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_GROOMING_GROSS',           isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_GROOMING_POSH',            isCompatible = IsPedHumanFemale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_GUITAR',                   isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS',             isCompatible = IsPedHumanMale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_KNITTING',                 isCompatible = IsPedHumanFemale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_PORCH' },
    { name = 'PROP_HUMAN_SEAT_CHAIR_READING',                  isCompatible = IsPedHumanFemale },
    { name = 'PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING' },
}

BedScenarios = {
    { name = 'PROP_HUMAN_SLEEP_BED_PILLOW' },
    { name = 'PROP_HUMAN_SLEEP_BED_PILLOW_HIGH', isCompatible = IsPedHumanMale },
    { name = 'WORLD_HUMAN_SLEEP_GROUND_ARM' },
    { name = 'WORLD_HUMAN_SLEEP_GROUND_PILLOW' },
    { name = 'WORLD_HUMAN_SIT_FALL_ASLEEP' },
    { name = 'WORLD_PLAYER_SLEEP_BEDROLL' },
    { name = 'WORLD_PLAYER_SLEEP_GROUND' },
}

BathingAnimations = {
    { labelKey = 'bath_idle',      dict = 'mini_games@bathing@regular@arthur', name = 'bathing_idle_02' },
    { labelKey = 'bath_left_arm',  dict = 'mini_games@bathing@regular@arthur', name = 'left_arm_scrub_medium' },
    { labelKey = 'bath_right_arm', dict = 'mini_games@bathing@regular@arthur', name = 'right_arm_scrub_medium' },
    { labelKey = 'bath_left_leg',  dict = 'mini_games@bathing@regular@arthur', name = 'left_leg_scrub_medium' },
    { labelKey = 'bath_right_leg', dict = 'mini_games@bathing@regular@arthur', name = 'right_leg_scrub_medium' },
}


Interactions = {

    {
        category    = 'piano',
        isCompatible = IsPedHuman,
        objects     = { 'p_piano03x' },
        radius      = 2.0,
        scenarios   = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
        x = 0.0, y = -0.70, z = 0.5, heading = 0.0,
    },
    {
        category    = 'piano',
        isCompatible = IsPedHuman,
        objects     = { 'p_piano02x' },
        radius      = 2.0,
        scenarios   = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
        x = 0.0, y = -0.70, z = 0.5, heading = 0.0,
    },
    {
        category    = 'piano',
        isCompatible = IsPedHuman,
        objects     = { 'p_nbxpiano01x' },
        radius      = 2.0,
        scenarios   = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
        x = -0.1, y = -0.75, z = 0.5, heading = 0.0,
    },
    {
        category    = 'piano',
        isCompatible = IsPedHuman,
        objects     = { 'p_nbmpiano01x' },
        radius      = 2.0,
        scenarios   = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
        x = 0.0, y = -0.77, z = 0.5, heading = 0.0,
    },
    {
        category  = 'piano',
        objects   = { 'sha_man_piano01' },
        radius    = 2.0,
        scenarios = {
            { name = 'PROP_HUMAN_PIANO',         isCompatible = IsPedHumanMale },
            { name = 'PROP_HUMAN_ABIGAIL_PIANO', isCompatible = IsPedHumanFemale },
        },
        x = 0.0, y = -0.75, z = 0.5, heading = 0.0,
    },

    {
        category     = 'chair',
        isCompatible = IsPedAdult,
        objects      = GenericChairs,
        radius       = 1.5,
        scenarios    = GenericChairAndBenchScenarios,
        x = 0.0, y = 0.0, z = 0.5, heading = 180.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedAdult,
        objects      = GenericChairs,
        radius       = 1.5,
        scenarios    = { { name = 'PROP_HUMAN_SEAT_CHAIR_DRINKING' } },
        x = 0.0, y = 0.05, z = -0.1, heading = 180.0,
    },
    {
        category     = 'bench',
        isCompatible = IsPedAdult,
        objects      = GenericBenches,
        radius       = 1.5,
        scenarios    = { { name = 'PROP_HUMAN_SEAT_CHAIR_DRINKING' } },
        label        = 'left',
        x = 0.4, y = -0.05, z = -0.1, heading = 180.0,
    },
    {
        category     = 'bench',
        isCompatible = IsPedAdult,
        objects      = GenericBenches,
        radius       = 1.5,
        scenarios    = { { name = 'PROP_HUMAN_SEAT_CHAIR_DRINKING' } },
        label        = 'right',
        x = -0.4, y = -0.05, z = -0.1, heading = 180.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedHumanMale,
        objects      = GenericChairs,
        radius       = 1.5,
        scenarios    = { { name = 'PROP_HUMAN_SEAT_BENCH_HARMONICA' } },
        x = 0.0, y = -0.3, z = 0.5, heading = 180.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedAdultFemale,
        objects      = GenericChairs,
        radius       = 1.5,
        scenarios    = { { name = 'PROP_HUMAN_SEAT_CHAIR_FAN' } },
        x = 0.0, y = 0.0, z = 0.5, heading = 240.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedAdult,
        objects      = { 'p_chairrusticsav01x' },
        radius       = 1.5,
        scenarios    = GenericChairAndBenchScenarios,
        x = 0.0, y = -0.1, z = 0.5, heading = 180.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedAdult,
        objects      = { 'p_chairtall01x' },
        radius       = 1.5,
        scenarios    = GenericChairAndBenchScenarios,
        x = 0.0, y = 0.0, z = 0.8, heading = 180.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedHuman,
        objects      = { 'p_barstool01x' },
        radius       = 1.5,
        scenarios    = GenericChairAndBenchScenarios,
        x = 0.0, y = 0.0, z = 0.8, heading = 0.0,
    },
    {
        category     = 'chair',
        isCompatible = IsPedChild,
        objects      = GenericChairs,
        radius       = 1.5,
        scenarios    = GenericChairAndBenchScenarios,
        x = 0.0, y = 0.0, z = 0.4, heading = 180.0,
    },
    {
        category     = 'bench',
        isCompatible = IsPedHuman,
        objects      = GenericBenches,
        label        = 'right',
        radius       = 2.0,
        scenarios    = GenericChairAndBenchScenarios,
        x = -0.5, y = 0.0, z = 0.5, heading = 180.0,
    },
    {
        category     = 'bench',
        isCompatible = IsPedHuman,
        objects      = GenericBenches,
        label        = 'left',
        radius       = 2.0,
        scenarios    = GenericChairAndBenchScenarios,
        x = 0.5, y = 0.0, z = 0.5, heading = 180.0,
    },
    {
        category     = 'bench',
        isCompatible = IsPedHuman,
        objects      = { 'p_bench17x', 'p_benchbear01x' },
        label        = 'right',
        radius       = 1.5,
        scenarios    = GenericChairAndBenchScenarios,
        x = -0.3, y = 0.0, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bench',
        objects   = { 'p_bench17x', 'p_benchbear01x' },
        label     = 'left',
        radius    = 1.5,
        scenarios = GenericChairAndBenchScenarios,
        x = 0.3, y = 0.0, z = 0.5, heading = 180.0,
    },

    {
        category  = 'bed',
        objects   = { 'p_bed14x', 'p_bed17x', 'p_bed21x', 'p_bedbunk03x', 'p_bedindian02x', 'p_cot01x' },
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.0, y = 0.0, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bed20madex', 'p_cs_pro_bed_unmade', 'p_cs_bed20madex' },
        label     = 'right',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = -0.3, y = -0.2, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bed20madex', 'p_cs_pro_bed_unmade', 'p_cs_bed20madex' },
        label     = 'left',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.3, y = -0.2, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_ambbed01x', 'p_bed03x', 'p_bed09x', 'p_bedindian01x' },
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.0, y = 0.0, z = 0.5, heading = 270.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bed05x' },
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.0, y = -0.5, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bed10x', 'p_bed12x', 'p_bed13x', 'p_bed22x' },
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.0, y = -0.3, z = 0.8, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bed20x' },
        label     = 'right',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = -0.3, y = -0.2, z = 0.8, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bed20x' },
        label     = 'left',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.3, y = -0.2, z = 0.8, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bedking02x' },
        label     = 'left',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = -0.5, y = 0.5, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_bedking02x' },
        label     = 'right',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.5, y = 0.5, z = 0.5, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = {
            'p_bedrollopen01x', 'p_bedrollopen03x', 'p_re_bedrollopen01x',
            's_bedrollfurlined01x', 's_bedrollopen01x',
            'p_amb_mattress04x', 'p_mattress04x', 'p_mattress07x', 'p_mattresscombined01x',
        },
        radius    = 1.5,
        scenarios = BedScenarios,
        x = 0.0, y = 0.0, z = 0.0, heading = 180.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_cs_ann_wrkr_bed01x', 'p_cs_roc_hse_bed', 'p_medbed01x' },
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.1, y = 0.0, z = 0.85, heading = 270.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_cs_bedsleptinbed08x' },
        label     = 'left',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.3, y = -0.3, z = 0.5, heading = 270.0,
    },
    {
        category  = 'bed',
        objects   = { 'p_cs_bedsleptinbed08x' },
        label     = 'right',
        radius    = 2.0,
        scenarios = BedScenarios,
        x = 0.3, y = 0.3, z = 0.5, heading = 270.0,
    },

    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = -317.01651,  y = 761.86,      z = 117.45099, heading = 100.278, effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = 2629.4099,   y = -1223.7757,  z = 59.6699,   heading = 2.896,   effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = -1812.46838, y = -373.23529,  z = 166.64999, heading = 92.105,  effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = 2952.804199, y = 1335.031494, z = 44.496986, heading = 154.996, effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = 2365.649,    y = -1211.780,   z = 51.888,    heading = 3.0,     effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = 1336.350,    y = -1377.972,   z = 84.345,    heading = -96.693, effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = -5513.196,   y = -2972.139,   z = -0.75,     heading = 108.131, effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = 2987.698,    y = 573.760,     z = 47.920,    heading = 171.942, effect = 'clean' },
    { category = 'bath', radius = 2.0, animations = BathingAnimations, x = -823.362,    y = -1318.832,   z = 43.679,    heading = 92.793,  effect = 'clean' },
    {
        category     = 'bath',
        isCompatible = IsPedHuman,
        objects      = { 'p_bath03x' },
        radius       = 2.0,
        animations   = BathingAnimations,
        x = -0.5, y = 0.0, z = 0.65, heading = 270.0,
        effect       = 'clean',
    },
}

-- Enabled entries from AWZ's default config_custom_models.lua.
table.insert(Interactions, { category = 'chair', objects = { 'sdchurchchair' }, radius = 1.5,
    scenarios = GenericChairAndBenchScenarios, x = 0.0, y = -0.1, z = -0.1, heading = 180.0 })
table.insert(Interactions, { category = 'bench', objects = { 'sdchurchbench' }, radius = 2.0,
    label = 'left', scenarios = GenericChairAndBenchScenarios, x = 0.5, y = -0.3, z = -0.375, heading = 180.0 })
table.insert(Interactions, { category = 'bench', objects = { 'sdchurchbench' }, radius = 2.0,
    label = 'right', scenarios = GenericChairAndBenchScenarios, x = -0.5, y = -0.3, z = -0.375, heading = 180.0 })
table.insert(Interactions, { category = 'bench', objects = { 'p_shoeshinestand01x' }, radius = 2.0,
    label = 'right', scenarios = GenericChairAndBenchScenarios, x = -0.45, y = 0.25, z = 1.2, heading = 180.0 })
table.insert(Interactions, { category = 'bench', objects = { 'p_shoeshinestand01x' }, radius = 2.0,
    label = 'left', scenarios = GenericChairAndBenchScenarios, x = 0.45, y = 0.25, z = 1.2, heading = 180.0 })
for _, model in ipairs({ 'churchbench1', 'churchbench2' }) do
    table.insert(Interactions, { category = 'bench', objects = { model }, radius = 2.0,
        label = 'left', scenarios = GenericChairAndBenchScenarios,
        x = model == 'churchbench1' and -1.5 or 0.0, y = 0.0, z = -0.3, heading = 180.0 })
    table.insert(Interactions, { category = 'bench', objects = { model }, radius = 2.0,
        label = 'right', scenarios = GenericChairAndBenchScenarios,
        x = model == 'churchbench1' and 0.0 or 1.5, y = 0.0, z = -0.3, heading = 180.0 })
end
table.insert(Interactions, { category = 'bath', objects = { 'p_bath02x' }, radius = 1.5,
    animations = BathingAnimations, x = 0.0, y = 0.5, z = 1.0, heading = 180.0, effect = 'clean' })
table.insert(Interactions, { category = 'piano', objects = { 'pipeorgan' }, radius = 2.0,
    isCompatible = IsPedHumanMale, scenarios = { { name = 'PROP_HUMAN_PIANO' } }, x = 0.0, y = -0.70, z = -0.65, heading = 0.0 })
table.insert(Interactions, { category = 'piano', objects = { 'pipeorgan' }, radius = 2.0,
    isCompatible = IsPedHumanFemale, scenarios = { { name = 'PROP_HUMAN_ABIGAIL_PIANO' } }, x = 0.0, y = -0.70, z = -0.625, heading = 0.0 })


-- HUNT AWZ-world-interactions bridge. Keeps thehunt_interact's exports and UI intact.
local AWZ_ACTION_PREFIX = 'hunt_awz_'
local awzActive = nil
local awzDiagnosedModels = {}

local function IsPedChildHunt(ped)
    return Citizen.InvokeNative(0x137772000DAF42C5, ped)
end

local function IsPedAdult(ped) return IsPedHuman(ped) and not IsPedChildHunt(ped) end
local function IsPedHumanMale(ped) return IsPedHuman(ped) and IsPedMale(ped) end
local function IsPedHumanFemale(ped) return IsPedHuman(ped) and not IsPedMale(ped) end
local function IsPedAdultFemale(ped) return IsPedAdult(ped) and not IsPedMale(ped) end
local function IsCompatible(rule, ped) return not rule.isCompatible or rule.isCompatible(ped) end

local labels = {
    PROP_HUMAN_PIANO = 'РРіСЂР°С‚СЊ РЅР° РїРёР°РЅРёРЅРѕ',
    PROP_HUMAN_ABIGAIL_PIANO = 'РРіСЂР°С‚СЊ РЅР° РїРёР°РЅРёРЅРѕ',
    GENERIC_SEAT_BENCH_SCENARIO = 'РЎРµСЃС‚СЊ',
    GENERIC_SEAT_CHAIR_SCENARIO = 'РЎРµСЃС‚СЊ',
    GENERIC_SEAT_CHAIR_TABLE_SCENARIO = 'РЎРµСЃС‚СЊ Р·Р° СЃС‚РѕР»',
    PROP_HUMAN_SEAT_CHAIR_DRINKING = 'РЎРµСЃС‚СЊ Рё РІС‹РїРёС‚СЊ',
    PROP_HUMAN_SEAT_BENCH_HARMONICA = 'РРіСЂР°С‚СЊ РЅР° РіСѓР±РЅРѕР№ РіР°СЂРјРѕС€РєРµ',
    PROP_HUMAN_SEAT_CHAIR_FAN = 'РћР±РјР°С…РёРІР°С‚СЊСЃСЏ РІРµРµСЂРѕРј',
    WORLD_PLAYER_SLEEP_BEDROLL = 'РЎРїР°С‚СЊ',
    WORLD_PLAYER_SLEEP_GROUND = 'РЎРїР°С‚СЊ',
    WORLD_HUMAN_SIT_FALL_ASLEEP = 'Р—Р°РґСЂРµРјР°С‚СЊ',
}
local function LabelForScenario(name)
    return labels[name] or (name:gsub('^PROP_HUMAN_', ''):gsub('^MP_LOBBY_PROP_HUMAN_', ''):gsub('_', ' '):lower())
end
local function LabelForAnimation(animation)
    local label = { bath_idle = 'Р Р°СЃСЃР»Р°Р±РёС‚СЊСЃСЏ РІ РІР°РЅРЅРµ', bath_left_arm = 'Р’С‹РјС‹С‚СЊ Р»РµРІСѓСЋ СЂСѓРєСѓ',
        bath_right_arm = 'Р’С‹РјС‹С‚СЊ РїСЂР°РІСѓСЋ СЂСѓРєСѓ', bath_left_leg = 'Р’С‹РјС‹С‚СЊ Р»РµРІСѓСЋ РЅРѕРіСѓ',
        bath_right_leg = 'Р’С‹РјС‹С‚СЊ РїСЂР°РІСѓСЋ РЅРѕРіСѓ' }
    return label[animation.labelKey] or 'РџСЂРёРЅСЏС‚СЊ РІР°РЅРЅСѓ'
end

local function ResolveWorldPosition(entity, action)
    local objectCoords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    local r = math.rad(heading)
    local x, y = action.x or 0.0, action.y or 0.0
    return x * math.cos(r) - y * math.sin(r) + objectCoords.x,
        x * math.sin(r) + y * math.cos(r) + objectCoords.y,
        objectCoords.z + (action.z or 0.0),
        heading + (action.heading or 0.0)
end

local function StartAwzAction(action, target)
    local entity = target and target.entity
    local ped = PlayerPedId()
    local x, y, z, heading
    if entity and DoesEntityExist(entity) then
        x, y, z, heading = ResolveWorldPosition(entity, action)
    elseif action.world then
        x, y, z, heading = action.world.x, action.world.y, action.world.z, action.world.heading
    else
        return
    end
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    if action.scenario then
        TaskStartScenarioAtPosition(ped, GetHashKey(action.scenario), x, y, z, heading, -1, false, true)
    elseif action.animation and DoesAnimDictExist(action.animation.dict) then
        RequestAnimDict(action.animation.dict)
        local untilAt = GetGameTimer() + 5000
        while not HasAnimDictLoaded(action.animation.dict) and GetGameTimer() < untilAt do Wait(10) end
        if HasAnimDictLoaded(action.animation.dict) then
            SetEntityCoordsNoOffset(ped, x, y, z)
            SetEntityHeading(ped, heading)
            TaskPlayAnim(ped, action.animation.dict, action.animation.name, 0.0, 0.0, -1, 1, 1.0, false, false, false, '', false)
            RemoveAnimDict(action.animation.dict)
        end
    end
    if action.effect == 'clean' then
        ClearPedEnvDirt(ped)
        ClearPedDamageDecalByZone(ped, 10, 'ALL')
        ClearPedBloodDamage(ped)
    end
    awzActive = action
    TheHuntAwzInteractionActive = true
    LocalPlayer.state:set('huntWorldInteractionActive', true, false)
end

local function StopAwzAction()
    if not awzActive then
        TheHuntAwzInteractionActive = false
        return
    end

    local ped = PlayerPedId()
    local hadScenario = IsPedUsingAnyScenario(ped)

    TriggerEvent('thehunt_animations:client:cleanupLocalProps', 'worldinteractions')
    FreezeEntityPosition(ped, false)

    if hadScenario then
        ClearPedTasks(ped)

        local moveControls = {
            0x8FD015D8, 0x7065027D, 0xD9D0F1C0, 0x8FFC75D6, 0x4D8FB4C1, 0xFDA83190
        }

        CreateThread(function()
            local startTime = GetGameTimer()
            local myPed = PlayerPedId()
            local wantMove = false

            while IsPedUsingAnyScenario(myPed) and (GetGameTimer() - startTime < 3200) do
                Wait(50)
                myPed = PlayerPedId()
                for i = 1, #moveControls do
                    if IsControlJustPressed(0, moveControls[i]) or IsDisabledControlJustPressed(0, moveControls[i]) then
                        wantMove = true
                        break
                    end
                end
                if wantMove then break end
            end

            ClearPedTasksImmediately(myPed)
            FreezeEntityPosition(myPed, false)
            ClearPedSecondaryTask(myPed)
            SetPedCanRagdoll(myPed, true)
            SetBlockingOfNonTemporaryEvents(myPed, false)
            pcall(function()
                if exports['thehunt_walking'] and exports['thehunt_walking'].ApplyCurrentSpeed then
                    exports['thehunt_walking']:ApplyCurrentSpeed()
                end
            end)
        end)
    else
        ClearPedTasksImmediately(ped)
        ClearPedSecondaryTask(ped)
        FreezeEntityPosition(ped, false)
        SetPedCanRagdoll(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, false)
        pcall(function()
            if exports['thehunt_walking'] and exports['thehunt_walking'].ApplyCurrentSpeed then
                exports['thehunt_walking']:ApplyCurrentSpeed()
            end
        end)
    end

    awzActive = nil
    TheHuntAwzInteractionActive = false
    LocalPlayer.state:set('huntWorldInteractionActive', false, false)
end

local ByModel = {}
for _, interaction in ipairs(Interactions) do
    if interaction.objects then
        for _, model in ipairs(interaction.objects) do
            local hash = joaat(model)
            ByModel[hash] = ByModel[hash] or {}
            table.insert(ByModel[hash], interaction)
        end
    end
end

local function BuildActions(entity)
    local ped, model = PlayerPedId(), GetEntityModel(entity)
    local actions, seen = {}, {}
    local modelInteractions = ByModel[model] or {}
    for _, interaction in ipairs(modelInteractions) do
        if IsCompatible(interaction, ped) then
            local entries, kind = interaction.scenarios or interaction.animations, interaction.scenarios and 'scenario' or 'animation'
            for _, entry in ipairs(entries or {}) do
                if IsCompatible(entry, ped) then
                    local name = kind == 'scenario' and entry.name or entry.labelKey
                    local id = AWZ_ACTION_PREFIX .. model .. '_' .. kind .. '_' .. name .. '_' .. tostring(interaction.x) .. '_' .. tostring(interaction.y)
                    if not seen[id] then
                        seen[id] = true
                        local action = {
                            id = id, label = kind == 'scenario' and LabelForScenario(entry.name) or LabelForAnimation(entry),
                            icon = interaction.category == 'bath' and 'medicine' or (interaction.category == 'piano' and 'interact' or 'interact'),
                            scenario = kind == 'scenario' and entry.name or nil,
                            animation = kind == 'animation' and entry or nil,
                            x = interaction.x, y = interaction.y, z = interaction.z, heading = interaction.heading,
                            effect = interaction.effect,
                        }
                        action.awzAction = {
                            scenario = action.scenario, animation = action.animation,
                            x = action.x, y = action.y, z = action.z, heading = action.heading,
                            effect = action.effect,
                        }
                        table.insert(actions, action)
                    end
                end
            end
        end
    end
    if not awzDiagnosedModels[model] then
        awzDiagnosedModels[model] = true
        print(('[HUNT INTERACT] AWZ target model %s: %d definitions, %d available actions.'):format(model, #modelInteractions, #actions))
    end
    return actions
end

local function BuildBathPointActions(point)
    local actions = {}
    for _, animation in ipairs(BathingAnimations) do
        local action = {
            id = AWZ_ACTION_PREFIX .. 'bath_' .. animation.labelKey .. '_' .. point.id,
            label = LabelForAnimation(animation), icon = 'medicine', animation = animation,
            effect = 'clean', world = point,
        }
        action.awzAction = {
            animation = action.animation, effect = action.effect, world = action.world,
        }
        actions[#actions + 1] = action
    end
    return actions
end

TheHuntAwzBuildActions = BuildActions

CreateThread(function()
    Wait(1000)
    local models = {}
    for hash in pairs(ByModel) do models[#models + 1] = hash end
    TriggerEvent('thehunt_interact:registerBundledModels', models, function(entity) return BuildActions(entity) end, 2.0)

    local baths = {
        { id = 'valentine', x = -317.01651, y = 761.86, z = 117.45099, heading = 100.278 },
        { id = 'saintdenis', x = 2629.4099, y = -1223.7757, z = 59.6699, heading = 2.896 },
        { id = 'annesburg', x = -1812.46838, y = -373.23529, z = 166.64999, heading = 92.105 },
        { id = 'vanhorn', x = 2952.804199, y = 1335.031494, z = 44.496986, heading = 154.996 },
        { id = 'saintdenis2', x = 2365.649, y = -1211.780, z = 51.888, heading = 3.0 },
        { id = 'rhodes', x = 1336.350, y = -1377.972, z = 84.345, heading = -96.693 },
        { id = 'tumbleweed', x = -5513.196, y = -2972.139, z = -0.75, heading = 108.131 },
        { id = 'blackwater', x = 2987.698, y = 573.760, z = 47.920, heading = 171.942 },
        { id = 'strawberry', x = -823.362, y = -1318.832, z = 43.679, heading = 92.793 },
    }
    for _, bath in ipairs(baths) do
        TriggerEvent('thehunt_interact:registerBundledZone', 'hunt_awz_bath_' .. bath.id, vector3(bath.x, bath.y, bath.z), 2.0,
            function() return BuildBathPointActions(bath) end, 2.0)
    end
    print(('[HUNT INTERACT] AWZ world interactions loaded: %d models, %d bath zones.'):format(#models, #baths))
end)

RegisterNetEvent('thehunt_interact:awzStart', function(action, target)
    StartAwzAction(action, target)
end)

-- The shared F1 handler dispatches this event. Keep cancellation in one place
-- so both world-interaction implementations follow the same control policy.
RegisterNetEvent('thehunt_worldinteractions:cancel', StopAwzAction)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then StopAwzAction() end
end)
end
