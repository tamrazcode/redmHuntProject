-- =================================================================
-- HUNT: Hard RP — The Corruption | Admin Zone Operations & Vertex Editor
-- =================================================================

EditorZones = {}

local activeEditingZone = nil
local selectedVertexIndex = nil
local testPreviewEntities = {}
local previewGeneration = 0

function EditorZones.GetActiveZone()
    return activeEditingZone
end

function EditorZones.SetActiveZone(zone)
    activeEditingZone = zone and json.decode(json.encode(zone)) or nil
    if activeEditingZone and activeEditingZone.coords then
        local c = activeEditingZone.coords
        activeEditingZone.coords = vector3(c.x, c.y, c.z)
    end
    selectedVertexIndex = nil
    EditorZones.ClearTestPreview()
end

function EditorZones.GetSelectedVertexIndex()
    return selectedVertexIndex
end

function EditorZones.SetSelectedVertexIndex(idx)
    selectedVertexIndex = idx
end

-- =================================================================
-- 1. ШАБЛОНЫ СОЗДАНИЯ НОВЫХ ЗОН
-- =================================================================

function EditorZones.CreateNewZone(zoneType, targetCoords)
    local c = targetCoords or EditorCam.GetCoords()
    local zType = zoneType or "circle"

    local newZone = {
        id = nil,
        name = "Новая зона " .. (Config.ZoneTypes[zType] and Config.ZoneTypes[zType].label or zType),
        zone_type = zType,
        coords = vector3(c.x, c.y, c.z),
        size_x = 12.0,
        size_y = 12.0,
        size_z = 4.0,
        radius = 12.0,
        height = 4.0,
        heading = 0.0,
        points = {},
        model_name = (zType == "container") and Config.DefaultContainerModel or nil,
        model_hash = (zType == "container") and joaat(Config.DefaultContainerModel) or nil,
        activation_radius = Config.DefaultActivationRadius,
        render_radius = Config.DefaultRenderRadius,
        max_active_items = Config.DefaultMaxItems,
        min_items = Config.DefaultMinItems,
        min_distance = Config.DefaultMinDistance,
        item_lifetime = Config.DefaultLifetime,
        min_respawn_time = Config.DefaultMinRespawn,
        max_respawn_time = Config.DefaultMaxRespawn,
        is_enabled = true,
        custom_rules = {},
        selected_items = {}
    }

    -- Если создается полигон — добавляем базовый треугольник вокруг точки
    if zType == "polygon" then
        newZone.points = {
            vector3(c.x - 6.0, c.y - 6.0, c.z),
            vector3(c.x + 6.0, c.y - 6.0, c.z),
            vector3(c.x, c.y + 7.0, c.z)
        }
    end

    EditorZones.SetActiveZone(newZone)
    return newZone
end

-- =================================================================
-- 2. ВЕРШИНЫ ПОЛИГОНА: ДОБАВЛЕНИЕ, УДАЛЕНИЕ, ВЫБОР
-- =================================================================

function EditorZones.AddPolygonVertexAtRaycast()
    if not activeEditingZone or activeEditingZone.zone_type ~= "polygon" then return false end
    local ray = EditorCam.RaycastFromCamera(100.0)
    if not ray or not ray.hit then return false end

    if not activeEditingZone.points then activeEditingZone.points = {} end
    table.insert(activeEditingZone.points, ray.coords)
    selectedVertexIndex = #activeEditingZone.points
    return true
end

function EditorZones.RemoveSelectedVertex()
    if not activeEditingZone or activeEditingZone.zone_type ~= "polygon" then return false end
    if not selectedVertexIndex or not activeEditingZone.points or #activeEditingZone.points <= 3 then
        TriggerEvent("thehunt_status:notify", "Полигон", "Полигон должен иметь минимум 3 вершины", "warning")
        return false
    end

    table.remove(activeEditingZone.points, selectedVertexIndex)
    selectedVertexIndex = math.max(1, #activeEditingZone.points)
    return true
end

function EditorZones.SelectNearestVertex(rayCoords)
    if not activeEditingZone or activeEditingZone.zone_type ~= "polygon" or not activeEditingZone.points then
        return nil
    end

    local bestIdx = nil
    local bestDist = 4.0

    for idx, pt in ipairs(activeEditingZone.points) do
        local dist = #(rayCoords - pt)
        if dist < bestDist then
            bestDist = dist
            bestIdx = idx
        end
    end

    selectedVertexIndex = bestIdx
    return bestIdx
end

function EditorZones.MoveSelectedVertexToRaycast()
    if not activeEditingZone or activeEditingZone.zone_type ~= "polygon" or not selectedVertexIndex then
        return false
    end
    local ray = EditorCam.RaycastFromCamera(100.0)
    if not ray or not ray.hit then return false end

    activeEditingZone.points[selectedVertexIndex] = ray.coords
    return true
end

-- Перемещение центра всей зоны к курсору
function EditorZones.MoveZoneCenterToRaycast()
    if not activeEditingZone then return false end
    local ray = EditorCam.RaycastFromCamera(100.0)
    if not ray or not ray.hit then return false end

    local oldCenter = activeEditingZone.coords
    local newCenter = ray.coords
    local delta = newCenter - oldCenter

    activeEditingZone.coords = newCenter

    -- Если это полигон — сдвигаем все вершины
    if activeEditingZone.zone_type == "polygon" and activeEditingZone.points then
        for i = 1, #activeEditingZone.points do
            activeEditingZone.points[i] = activeEditingZone.points[i] + delta
        end
    end

    return true
end

-- Смещение центра зоны по высоте Z (Вверх / Вниз)
function EditorZones.AdjustZoneCenterZ(deltaZ)
    if not activeEditingZone then return false end
    local dZ = tonumber(deltaZ) or 0.0
    if dZ == 0.0 then return false end

    local c = activeEditingZone.coords or vector3(0, 0, 0)
    activeEditingZone.coords = vector3(c.x, c.y, c.z + dZ)

    if activeEditingZone.zone_type == "polygon" and activeEditingZone.points then
        for i = 1, #activeEditingZone.points do
            local p = activeEditingZone.points[i]
            activeEditingZone.points[i] = vector3(p.x, p.y, p.z + dZ)
        end
    end

    return true
end

-- =================================================================
-- 3. ТЕСТОВЫЙ ПРЕДПРОСМОТР ЛУТА (GHOST PROPS)
-- =================================================================

function EditorZones.SpawnTestPreview(slots)
    EditorZones.ClearTestPreview()
    local generation = previewGeneration
    if not slots then return end

    for _, slot in ipairs(slots) do
        local modelName = slot.model_name or Config.DefaultLootPropModel
        local hash = joaat(modelName)
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 25 do
            Citizen.Wait(40)
            timeout = timeout + 1
        end

        if generation ~= previewGeneration then SetModelAsNoLongerNeeded(hash); return end
        if HasModelLoaded(hash) then
            local activeZone = EditorZones.GetActiveZone()
            local zType = (activeZone and activeZone.zone_type) or slot.zone_type or "circle"
            local targetX, targetY, targetZ = slot.x, slot.y, slot.z + 0.015
            local zCenter = activeZone and activeZone.coords or vector3(slot.x, slot.y, slot.z)

            if zType ~= "point" and zType ~= "container" and not slot.is_exact_point then
                local myPed = PlayerPedId()

                -- Проверка стены между центром зоны и точкой
                local cDist = #(vector2(zCenter.x, zCenter.y) - vector2(targetX, targetY))
                if cDist > 0.5 then
                    local rWall = StartShapeTestRay(zCenter.x, zCenter.y, slot.z + 0.35, targetX, targetY, slot.z + 0.35, 17, myPed, 7)
                    local _, hitW, wCoords, wNorm, _ = GetShapeTestResult(rWall)
                    if (hitW == 1 or hitW == true) and wCoords and #(wCoords - vector3(0,0,0)) > 2.0 then
                        local wDist = #(vector2(zCenter.x, zCenter.y) - vector2(wCoords.x, wCoords.y))
                        if wDist < cDist - 0.15 then
                            local nX = (wNorm and wNorm.x) or 0.0
                            local nY = (wNorm and wNorm.y) or 0.0
                            targetX = wCoords.x + (nX * 0.45)
                            targetY = wCoords.y + (nY * 0.45)
                        end
                    end
                end

                local startPos = vector3(targetX, targetY, slot.z + 1.6)
                local endPos   = vector3(targetX, targetY, slot.z - 1.6)
                local shapeTest = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 287, myPed, 4)
                local _, hit, hitCoords, _, _ = GetShapeTestResult(shapeTest)
                if (hit == 1 or hit == true) and #(hitCoords - vector3(0.0, 0.0, 0.0)) > 2.0 then
                    targetZ = hitCoords.z + 0.025
                end
            end

            local obj = CreateObject(hash, targetX, targetY, targetZ, false, false, false, false, false)
            if DoesEntityExist(obj) then
                SetEntityCoords(obj, targetX, targetY, targetZ, false, false, false, false)
                SetEntityRotation(obj, 0.0, 0.0, slot.heading or 0.0, 2, true)
                FreezeEntityPosition(obj, true)
                SetEntityAlpha(obj, 200, false)
                table.insert(testPreviewEntities, obj)
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

function EditorZones.ClearTestPreview()
    previewGeneration = previewGeneration + 1
    for _, ent in ipairs(testPreviewEntities) do
        if DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    testPreviewEntities = {}
end
