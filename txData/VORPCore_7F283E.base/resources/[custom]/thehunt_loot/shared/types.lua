-- =================================================================
-- HUNT: Hard RP — The Corruption | Shared Types & Geometry Math
-- =================================================================

LootMath = {}

local sin = math.sin
local cos = math.cos
local rad = math.rad
local deg = math.deg
local sqrt = math.sqrt
local random = math.random

-- =================================================================
-- 1. ГЕОМЕТРИЯ: ПРОВЕРКА ПОПАДАНИЯ ТОЧКИ В ЗОНУ
-- =================================================================

--- Проверка попадания точки в круглый цилиндр
function LootMath.IsPointInCircle(point, center, radius, minZ, maxZ)
    if not point or not center or not radius then return false end
    if minZ and point.z < minZ then return false end
    if maxZ and point.z > maxZ then return false end

    local dx = point.x - center.x
    local dy = point.y - center.y
    return (dx * dx + dy * dy) <= (radius * radius)
end

--- Проверка попадания точки в ориентированный 3D-прямоугольник (OBB Box)
function LootMath.IsPointInBox(point, center, sizeX, sizeY, sizeZ, heading)
    if not point or not center then return false end

    local halfZ = (sizeZ or 3.0) * 0.5
    if point.z < (center.z - halfZ) or point.z > (center.z + halfZ) then
        return false
    end

    local hRad = -rad(heading or 0.0)
    local cosH = cos(hRad)
    local sinH = sin(hRad)

    local dx = point.x - center.x
    local dy = point.y - center.y

    -- Поворот в локальные координаты коробки
    local localX = dx * cosH - dy * sinH
    local localY = dx * sinH + dy * cosH

    local halfX = (sizeX or 2.0) * 0.5
    local halfY = (sizeY or 2.0) * 0.5

    return math.abs(localX) <= halfX and math.abs(localY) <= halfY
end

--- Проверка попадания точки в 2D-полигон (Ray-casting Algorithm)
function LootMath.IsPointInPolygon(point, vertices, minZ, maxZ)
    if not point or not vertices or #vertices < 3 then return false end
    if minZ and point.z < minZ then return false end
    if maxZ and point.z > maxZ then return false end

    local x = point.x
    local y = point.y
    local inside = false
    local n = #vertices

    local j = n
    for i = 1, n do
        local xi = vertices[i].x
        local yi = vertices[i].y
        local xj = vertices[j].x
        local yj = vertices[j].y

        local intersect = ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        if intersect then
            inside = not inside
        end
        j = i
    end

    return inside
end

-- =================================================================
-- 2. ГЕНЕРАЦИЯ СЛУЧАЙНЫХ ТОЧЕК ВНУТРИ ФИГУР
-- =================================================================

--- Случайная точка внутри круга с внутренним отступом от краев
function LootMath.GetRandomPointInCircle(center, radius)
    local rad = math.max(0.0, (radius or 5.0) - 0.5)
    local r = rad * sqrt(random())
    local theta = random() * 2 * math.pi
    return vector3(
        center.x + r * cos(theta),
        center.y + r * sin(theta),
        center.z
    )
end

--- Случайная точка внутри повернутого прямоугольника с внутренним отступом от стен
function LootMath.GetRandomPointInBox(center, sizeX, sizeY, heading)
    local margin = 0.5
    local halfX = math.max(0.0, ((sizeX or 4.0) * 0.5) - margin)
    local halfY = math.max(0.0, ((sizeY or 4.0) * 0.5) - margin)

    local localX = (random() * 2 - 1) * halfX
    local localY = (random() * 2 - 1) * halfY

    local hRad = rad(heading or 0.0)
    local cosH = cos(hRad)
    local sinH = sin(hRad)

    local worldX = center.x + (localX * cosH - localY * sinH)
    local worldY = center.y + (localX * sinH + localY * cosH)

    return vector3(worldX, worldY, center.z)
end

--- Вычисление Bounding Box полигона для быстрого семплирования
function LootMath.GetPolygonBoundingBox(vertices)
    if not vertices or #vertices == 0 then return 0, 0, 0, 0 end
    local minX, maxX = vertices[1].x, vertices[1].x
    local minY, maxY = vertices[1].y, vertices[1].y

    for i = 2, #vertices do
        local v = vertices[i]
        if v.x < minX then minX = v.x end
        if v.x > maxX then maxX = v.x end
        if v.y < minY then minY = v.y end
        if v.y > maxY then maxY = v.y end
    end
    return minX, maxX, minY, maxY
end

--- Случайная точка внутри полигона (Rejection sampling с ограничением попыток)
function LootMath.GetRandomPointInPolygon(vertices, centerZ, maxTries)
    if not vertices or #vertices < 3 then return nil end
    local minX, maxX, minY, maxY = LootMath.GetPolygonBoundingBox(vertices)
    local tries = maxTries or 30

    for _ = 1, tries do
        local rx = minX + random() * (maxX - minX)
        local ry = minY + random() * (maxY - minY)
        local pt = vector3(rx, ry, centerZ or 0.0)
        if LootMath.IsPointInPolygon(pt, vertices) then
            return pt
        end
    end

    return nil -- A concave polygon centroid may lie outside the zone.
end

--- Универсальное получение случайной точки в зависимости от типа зоны
function LootMath.GetRandomPointInZone(zone)
    if not zone then return nil end
    local zType = zone.zone_type or "circle"
    local center = zone.coords or vector3(0, 0, 0)

    if zType == "circle" then
        return LootMath.GetRandomPointInCircle(center, tonumber(zone.radius) or 10.0)
    elseif zType == "rectangle" then
        return LootMath.GetRandomPointInBox(center, tonumber(zone.size_x) or 10.0, tonumber(zone.size_y) or 10.0, tonumber(zone.heading) or 0.0)
    elseif zType == "polygon" then
        if zone.points and #zone.points >= 3 then
            return LootMath.GetRandomPointInPolygon(zone.points, center.z, 20)
        else
            return center
        end
    elseif zType == "point" or zType == "container" then
        return center
    end

    return center
end

-- =================================================================
-- 3. ВЫБОР ПРЕДМЕТА ИЗ ПУЛА ЗОНЫ ПО ВЕСУ / ШАНСУ
-- =================================================================

--- Взвешенный случайный выбор предмета из таблицы zoneItems
--- zoneItems: array of { item_name, weight, min_count, max_count, ... }
function LootMath.SelectWeightedItem(zoneItems)
    if not zoneItems or #zoneItems == 0 then return nil end

    local totalWeight = 0
    for _, it in ipairs(zoneItems) do
        local w = tonumber(it.weight) or 100
        if w < 1 then w = 1 end
        totalWeight = totalWeight + w
    end

    if totalWeight <= 0 then
        local fallback = zoneItems[1]
        local minC = math.max(1, tonumber(fallback.min_count) or 1)
        local maxC = math.max(minC, tonumber(fallback.max_count) or minC)
        return {
            item_name = fallback.item_name,
            min_count = minC,
            max_count = maxC,
            count = (maxC == minC) and minC or math.random(minC, maxC),
            weight = fallback.weight,
            metadata = fallback.metadata
        }
    end

    local roll = math.random(1, math.floor(totalWeight))
    local current = 0

    for _, it in ipairs(zoneItems) do
        local w = tonumber(it.weight) or 100
        if w < 1 then w = 1 end
        current = current + w
        if roll <= current then
            local minC = math.max(1, tonumber(it.min_count or it.count) or 1)
            local maxC = math.max(minC, tonumber(it.max_count or it.count) or minC)
            local count = (maxC == minC) and minC or math.random(minC, maxC)

            return {
                item_name = it.item_name,
                min_count = minC,
                max_count = maxC,
                count = count,
                weight = it.weight,
                metadata = it.metadata
            }
        end
    end

    local fallback = zoneItems[1]
    local minC = math.max(1, tonumber(fallback.min_count) or 1)
    local maxC = math.max(minC, tonumber(fallback.max_count) or minC)
    return {
        item_name = fallback.item_name,
        min_count = minC,
        max_count = maxC,
        count = minC,
        weight = fallback.weight,
        metadata = fallback.metadata
    }
end

-- =================================================================
-- 4. ВСПОМОГАТЕЛЬНЫЕ МАТЕМАТИЧЕСКИЕ ФУНКЦИИ
-- =================================================================

function LootMath.GetDistance2D(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    return sqrt(dx * dx + dy * dy)
end

function LootMath.GetDistance3D(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = (p1.z or 0) - (p2.z or 0)
    return sqrt(dx * dx + dy * dy + dz * dz)
end
