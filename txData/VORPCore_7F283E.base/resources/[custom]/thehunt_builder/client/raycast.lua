-- =================================================================
-- HUNT: Hard RP — The Corruption | Raycast & Object Inspector
-- =================================================================

Raycast = {}

local lastHighlightedEntity = nil

function Raycast.NormalizeModelHash(hash)
    if not hash then return 0 end
    local h = tonumber(hash)
    if not h then return 0 end
    if h < 0 then
        h = h + 4294967296
    end
    return math.floor(h)
end

-- Сброс подсветки с предыдущего объекта
function Raycast.ClearHighlight()
    if lastHighlightedEntity and DoesEntityExist(lastHighlightedEntity) then
        pcall(function() SetEntityDrawOutline(lastHighlightedEntity, false) end)
    end
    lastHighlightedEntity = nil
end

-- 3D луч между двумя точками координат
function Raycast.CastFromCoords(startCoords, destCoords)
    local shapeTest = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, destCoords.x, destCoords.y, destCoords.z, 287, PlayerPedId(), 4)
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(shapeTest)

    local isHit = (hit == 1 or hit == true) and #(endCoords - vector3(0.0, 0.0, 0.0)) > 2.0

    return {
        hit = isHit,
        coords = isHit and endCoords or destCoords,
        normal = surfaceNormal,
        entity = (entityHit ~= 0 and DoesEntityExist(entityHit)) and entityHit or nil
    }
end

-- 3D луч из камеры игрока в направлении взгляда / курсора
function Raycast.CastFromCamera(maxDistance)
    local dist = maxDistance or Config.RaycastDistance
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    local radZ = math.rad(camRot.z)
    local radX = math.rad(camRot.x)

    local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
    local destCoords = camCoords + (forward * dist)

    return Raycast.CastFromCoords(camCoords, destCoords)
end

-- Отрисовка 3D wireframe bounding box вокруг объекта
local function Draw3DBoundingBox(coords, rot, minDim, maxDim, r, g, b, a)
    local radZ = math.rad(rot.z)
    local radX = math.rad(rot.x)
    local radY = math.rad(rot.y)

    local cosZ, sinZ = math.cos(radZ), math.sin(radZ)
    local cosX, sinX = math.cos(radX), math.sin(radX)
    local cosY, sinY = math.cos(radY), math.sin(radY)

    local function rotatePoint(p)
        -- Euler ZYX rotation
        local x1 = p.x * cosY + p.z * sinY
        local y1 = p.y
        local z1 = -p.x * sinY + p.z * cosY

        local x2 = x1
        local y2 = y1 * cosX - z1 * sinX
        local z2 = y1 * sinX + z1 * cosX

        local x3 = x2 * cosZ - y2 * sinZ
        local y3 = x2 * sinZ + y2 * cosZ
        local z3 = z2

        return vector3(coords.x + x3, coords.y + y3, coords.z + z3)
    end

    local corners = {
        rotatePoint(vector3(minDim.x, minDim.y, minDim.z)),
        rotatePoint(vector3(maxDim.x, minDim.y, minDim.z)),
        rotatePoint(vector3(maxDim.x, maxDim.y, minDim.z)),
        rotatePoint(vector3(minDim.x, maxDim.y, minDim.z)),
        rotatePoint(vector3(minDim.x, minDim.y, maxDim.z)),
        rotatePoint(vector3(maxDim.x, minDim.y, maxDim.z)),
        rotatePoint(vector3(maxDim.x, maxDim.y, maxDim.z)),
        rotatePoint(vector3(minDim.x, maxDim.y, maxDim.z))
    }

    local edges = {
        {1, 2}, {2, 3}, {3, 4}, {4, 1},
        {5, 6}, {6, 7}, {7, 8}, {8, 5},
        {1, 5}, {2, 6}, {3, 7}, {4, 8}
    }

    for _, edge in ipairs(edges) do
        local c1 = corners[edge[1]]
        local c2 = corners[edge[2]]
        DrawLine(c1.x, c1.y, c1.z, c2.x, c2.y, c2.z, r, g, b, a)
    end
end

-- Точный поиск целевой сущности в направлении прицела свободной камеры (100% покрытие всех пропов)
function Raycast.GetTargetEntityFromRay(startCoords, forward, maxDistance)
    local myPed = PlayerPedId()
    local ghost = Preview and Preview.GetGhostEntity() or nil
    local dist = maxDistance or 60.0
    local destCoords = startCoords + (forward * dist)

    -- 1. Первичный ShapeTest Ray
    local shapeTest = StartShapeTestRay(startCoords.x, startCoords.y, startCoords.z, destCoords.x, destCoords.y, destCoords.z, 287, myPed, 4)
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(shapeTest)

    local rayHitEntity = nil
    if entityHit ~= 0 and DoesEntityExist(entityHit) and entityHit ~= myPed and entityHit ~= ghost then
        local mHash = GetEntityModel(entityHit)
        local entCoords = GetEntityCoords(entityHit)
        if mHash and mHash ~= 0 and #(entCoords - vector3(0.0, 0.0, 0.0)) > 2.0 then
            rayHitEntity = entityHit
        end
    end

    local maxRayDist = (hit == 1 or hit == true) and math.min(dist, #(endCoords - startCoords) + 1.2) or dist

    -- 2. Ищем все объекты в пуле CObject, CPed, CVehicle, которые пересекает луч
    local bestEntity = nil
    local bestScore = 9999.0

    local pools = { 'CObject', 'CPed', 'CVehicle' }
    for _, poolName in ipairs(pools) do
        local pool = GetGamePool(poolName)
        for _, ent in ipairs(pool) do
            if DoesEntityExist(ent) and ent ~= myPed and ent ~= ghost then
                local entCoords = GetEntityCoords(ent)
                if #(entCoords - vector3(0.0, 0.0, 0.0)) > 2.0 then
                    local mHash = GetEntityModel(ent)
                    local minDim, maxDim = GetModelDimensions(mHash)
                    local radius = 0.4
                    if minDim and maxDim then
                        radius = math.max(0.3, math.max(math.abs(maxDim.x - minDim.x), math.abs(maxDim.y - minDim.y), math.abs(maxDim.z - minDim.z)) * 0.5)
                    end

                    -- Проекция на луч камеры
                    local toEnt = entCoords - startCoords
                    local dot = (toEnt.x * forward.x) + (toEnt.y * forward.y) + (toEnt.z * forward.z)

                    if dot > 0.2 and dot <= maxRayDist then
                        local projPoint = startCoords + (forward * dot)
                        local perpDist = #(entCoords - projPoint)

                        if perpDist <= (radius + 0.25) then
                            local score = perpDist + (dot * 0.005)
                            if score < bestScore then
                                bestScore = score
                                bestEntity = ent
                            end
                        end
                    end
                end
            end
        end
    end

    if bestEntity then
        return bestEntity, GetEntityCoords(bestEntity)
    end

    if rayHitEntity then
        return rayHitEntity, endCoords
    end

    return nil, endCoords
end

-- Отрисовка 3D информационного маркера и подсветки над инспектируемым объектом
function Raycast.DrawObjectInspectorInfo(entity)
    if not entity or not DoesEntityExist(entity) then 
        Raycast.ClearHighlight()
        return 
    end

    local modelHash = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)

    -- Строгая фильтрация нулевых/фиктивных сущностей движка
    if not modelHash or modelHash == 0 or #(coords - vector3(0.0, 0.0, 0.0)) < 2.0 then
        Raycast.ClearHighlight()
        return
    end

    -- 1. Управление нативной подсветкой контура RedM
    if lastHighlightedEntity and lastHighlightedEntity ~= entity and DoesEntityExist(lastHighlightedEntity) then
        pcall(function() SetEntityDrawOutline(lastHighlightedEntity, false) end)
    end
    lastHighlightedEntity = entity
    pcall(function()
        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(56, 189, 248, 255)
    end)

    local rot = GetEntityRotation(entity, 2)
    local modelName = "Объект"
    local normHash = Raycast.NormalizeModelHash(modelHash)

    -- 2. Атмосферный неоновый свет под объектом (RDR2 Native Light)
    DrawLightWithRange(coords.x, coords.y, coords.z + 0.35, 56, 189, 248, 4.0, 4.0)

    -- 3. Отрисовка 3D Bounding Box (каркасной коробки точного размера объекта)
    local minDim, maxDim = GetModelDimensions(modelHash)
    if minDim and maxDim then
        Draw3DBoundingBox(coords, rot, minDim, maxDim, 56, 189, 248, 220)
    end

    -- 4. Отрисовка аккуратного круга подсветки на земле под объектом
    pcall(function()
        Citizen.InvokeNative(0x2A32C04EC6380D3D, 0x94FDAE17, coords.x, coords.y, coords.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.4, 1.4, 0.25, 56, 189, 248, 120, false, false, 2, false, 0, 0, false)
    end)

    -- Проверяем, известен ли объект в нашем каталоге
    for _, cat in ipairs(Config.PropCategories) do
        for _, p in ipairs(cat.props) do
            local catHash = Raycast.NormalizeModelHash(GetHashKey(p.model))
            if catHash == normHash then
                modelName = p.name
                break
            end
        end
    end

    -- Вычисляем высоту объекта для правильного расположения текста над его макушкой
    local heightOffset = (maxDim and maxDim.z) and math.max(0.45, maxDim.z + 0.35) or 0.75

    local textPos = vector3(coords.x, coords.y, coords.z + heightOffset)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(textPos.x, textPos.y, textPos.z)

    if onScreen then
        -- 1. Название и хэш (Hex + Dec)
        local line1 = string.format("%s [0x%X / %s]", modelName, normHash, tostring(modelHash))
        local textStr1 = VarString(10, "LITERAL_STRING", line1, Citizen.ResultAsLong())
        SetTextScale(0.30, 0.30)
        SetTextFontForCurrentCommand(1)
        SetTextColor(56, 189, 248, 255)
        SetTextCentre(1)
        SetTextDropshadow(2, 0, 0, 0, 255)
        DisplayText(textStr1, screenX, screenY)

        -- 2. Координаты и угол
        local line2 = string.format("X: %.1f | Y: %.1f | Z: %.1f | Heading: %.0f°", coords.x, coords.y, coords.z, rot.z)
        local textStr2 = VarString(10, "LITERAL_STRING", line2, Citizen.ResultAsLong())
        SetTextScale(0.22, 0.22)
        SetTextFontForCurrentCommand(1)
        SetTextColor(220, 230, 242, 230)
        SetTextCentre(1)
        SetTextDropshadow(2, 0, 0, 0, 255)
        DisplayText(textStr2, screenX, screenY + 0.022)

        -- 3. Подсказки действий
        local customProp = Streamer.GetPropInfoByEntity(entity)
        local isMovedWorldProp = customProp and customProp.original_x ~= nil
        local line3 = "[Del] Удалить | [E] Взять объект | [C] Клонировать"
        local textStr3 = VarString(10, "LITERAL_STRING", line3, Citizen.ResultAsLong())
        SetTextScale(0.20, 0.20)
        SetTextFontForCurrentCommand(1)
        SetTextColor(240, 180, 60, 240)
        SetTextCentre(1)
        SetTextDropshadow(2, 0, 0, 0, 255)
        DisplayText(textStr3, screenX, screenY + 0.042)
    end
end
