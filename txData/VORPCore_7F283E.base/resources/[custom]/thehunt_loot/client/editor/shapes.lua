-- =================================================================
-- HUNT: Hard RP — The Corruption | Admin Editor Shapes & 3D Visualizer
-- =================================================================

EditorShapes = {}

local isShapesRendererRunning = false

-- =================================================================
-- 1. ОТРИСОВКА ОДНОЙ ЗОНЫ В 3D МИРЕ
-- =================================================================

function EditorShapes.DrawZone(zone, isSelected, selectedVertexIndex)
    if not zone then return end

    local color = isSelected and Config.EditorColors.active or (zone.is_enabled and Config.EditorColors.normal or Config.EditorColors.disabled)
    local zType = zone.zone_type or "circle"
    local c = zone.coords or vector3(0, 0, 0)

    -- 1. КРУГ / ЦИЛИНДР (Объемный гладкий 3D-цилиндр без секущих артефактов на земле)
    if zType == "circle" then
        local radius = zone.radius or 10.0
        local height = zone.height or 4.0

        if exports.thehunt_shapes and exports.thehunt_shapes.DrawCylinder then
            exports.thehunt_shapes:DrawCylinder(c.x, c.y, c.z, radius, height, color.r, color.g, color.b, math.min(90, color.a or 60), 48)
        end

        -- Точный маркер центра круга на земле
        if exports.thehunt_shapes and exports.thehunt_shapes.DrawAxis then
            exports.thehunt_shapes:DrawAxis(c.x, c.y, c.z, 1.0)
        end
        if exports.thehunt_shapes and exports.thehunt_shapes.DrawDisk then
            exports.thehunt_shapes:DrawDisk(c.x, c.y, c.z, 0.4, color.r, color.g, color.b, 220, 16)
        end

    -- 2. ПРЯМОУГОЛЬНИК / 3D BOX
    elseif zType == "rectangle" then
        local sx = zone.size_x or 10.0
        local sy = zone.size_y or 10.0
        local sz = zone.size_z or 4.0
        local heading = zone.heading or 0.0

        if exports.thehunt_shapes and exports.thehunt_shapes.DrawBox then
            exports.thehunt_shapes:DrawBox(c.x, c.y, c.z + (sz * 0.5), sx, sy, sz, 0.0, 0.0, heading, color.r, color.g, color.b, color.a)
        end

    -- 3. МНОГОУГОЛЬНИК (ПОЛИГОН)
    elseif zType == "polygon" then
        local height = zone.height or 4.0
        local points = zone.points or {}

        if #points >= 2 then
            -- Рисуем ребра полигона внизу и вверху
            for i = 1, #points do
                local nextIdx = (i % #points) + 1
                local p1 = points[i]
                local p2 = points[nextIdx]

                -- Нижняя линия
                DrawLine(p1.x, p1.y, p1.z or c.z, p2.x, p2.y, p2.z or c.z, color.r, color.g, color.b, 255)
                -- Верхняя линия
                DrawLine(p1.x, p1.y, (p1.z or c.z) + height, p2.x, p2.y, (p2.z or c.z) + height, color.r, color.g, color.b, 200)
                -- Вертикальные стойки
                DrawLine(p1.x, p1.y, p1.z or c.z, p1.x, p1.y, (p1.z or c.z) + height, color.r, color.g, color.b, 180)
            end

            -- Отрисовка вершин (шариков) для редактирования
            if isSelected then
                for idx, pt in ipairs(points) do
                    local isVertSelected = (selectedVertexIndex == idx)
                    local vCol = isVertSelected and Config.EditorColors.selectedVertex or Config.EditorColors.vertex
                    local vRadius = isVertSelected and 0.35 or 0.22

                    if exports.thehunt_shapes and exports.thehunt_shapes.DrawSphere then
                        exports.thehunt_shapes:DrawSphere(pt.x, pt.y, pt.z or c.z, vRadius, vCol.r, vCol.g, vCol.b, vCol.a)
                    end
                end
            end
        end

    -- 4. ТОЧКА ИЛИ КОНТЕЙНЕР
    elseif zType == "point" or zType == "container" then
        if exports.thehunt_shapes and exports.thehunt_shapes.DrawAxis then
            exports.thehunt_shapes:DrawAxis(c.x, c.y, c.z, 0.8)
        end
        if exports.thehunt_shapes and exports.thehunt_shapes.DrawSphere then
            exports.thehunt_shapes:DrawSphere(c.x, c.y, c.z, 0.35, color.r, color.g, color.b, color.a)
        end
    end

    -- Название зоны над центром
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 1.2)
    if onScreen then
        local label = string.format("[%d] %s", zone.id or 0, zone.name or "Зона")
        local textStr = VarString(10, "LITERAL_STRING", label, Citizen.ResultAsLong())
        SetTextScale(0.24, 0.24)
        SetTextFontForCurrentCommand(1)
        SetTextColor(color.r, color.g, color.b, 240)
        SetTextCentre(1)
        SetTextDropshadow(2, 0, 0, 0, 200)
        DisplayText(textStr, screenX, screenY)
    end
end

-- =================================================================
-- 2. ЦИКЛ РЕНДЕРИНГА ВСЕХ ФИГУР В РЕЖИМЕ РЕДАКТОРА
-- =================================================================

function EditorShapes.StartRenderer()
    if isShapesRendererRunning then return end
    isShapesRendererRunning = true

    Citizen.CreateThread(function()
        while isShapesRendererRunning do
            Citizen.Wait(0)

            if Editor and Editor.IsActive and Editor.IsActive() then
                local allZones = Editor.GetAllZones()
                local activeZone = Editor.GetActiveZone()
                local activeZoneId = activeZone and tonumber(activeZone.id) or nil
                local selectedVertex = Editor.GetSelectedVertexIndex()

                local drawnZoneIds = {}

                -- 1. Сначала рисуем невыделенные зоны
                if allZones then
                    for zId, zone in pairs(allZones) do
                        if zone and zone.coords then
                            local zoneIdNum = tonumber(zone.id or zId)
                            if zoneIdNum and not drawnZoneIds[zoneIdNum] then
                                drawnZoneIds[zoneIdNum] = true
                                if not activeZoneId or zoneIdNum ~= activeZoneId then
                                    EditorShapes.DrawZone(zone, false, nil)
                                end
                            end
                        end
                    end
                end

                -- 2. Затем поверх рисуем активную зону
                if activeZone then
                    EditorShapes.DrawZone(activeZone, true, selectedVertex)
                end

                -- 3. Рисуем точку и луч курсора на земле
                local ray = EditorCam.RaycastFromCamera(100.0)
                if ray and ray.hit then
                    local pt = ray.coords
                    DrawLine(pt.x, pt.y, pt.z, pt.x, pt.y, pt.z + 0.6, 255, 255, 255, 220)
                    if exports.thehunt_shapes and exports.thehunt_shapes.DrawDisk then
                        exports.thehunt_shapes:DrawDisk(pt.x, pt.y, pt.z, 0.25, 255, 255, 255, 120, 16)
                    end
                end
            else
                Citizen.Wait(250)
            end
        end
    end)
end

function EditorShapes.StopRenderer()
    isShapesRendererRunning = false
end
