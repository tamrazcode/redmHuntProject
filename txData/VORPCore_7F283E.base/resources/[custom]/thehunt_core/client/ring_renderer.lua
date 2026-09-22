-- =================================================================
-- HUNT: Hard RP — The Corruption | Универсальный 3D Движок Отрисовки Колец
-- (3D Ring / Hoop Vector Line Renderer для войса, зон, ритуалов и магии)
-- =================================================================

local activeRings = {}
local ringIdCounter = 0

-- Функция получения точной высоты земли с кэшированием лучей
local function GetAccurateGroundZ(x, y, startZ)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, startZ + 1.0, false)
    if found then
        return groundZ
    end
    -- Запасная попытка через ShapeTest Raycast
    local ray = StartShapeTestRay(x, y, startZ + 2.0, x, y, startZ - 4.0, 1, 0, 0)
    local _, hit, hitCoords = GetShapeTestResult(ray)
    if hit == 1 then
        return hitCoords.z
    end
    return startZ
end

-- Публичная функция регистрации 3D-кольца для отрисовки
function Draw3DGroundRing(centerCoords, radius, r, g, b, a, durationMs)
    ringIdCounter = ringIdCounter + 1
    local curTime = GetGameTimer()
    local duration = tonumber(durationMs) or 2000

    table.insert(activeRings, {
        id        = ringIdCounter,
        coords    = centerCoords,
        radius    = tonumber(radius) or 5.0,
        color     = { r = r or 255, g = g or 255, b = b or 255, a = a or 220 },
        startTime = curTime,
        endTime   = curTime + duration,
        duration  = duration
    })
    return ringIdCounter
end

-- Экспорт для использования во всех других скриптах сервера
exports('DrawGroundRing', Draw3DGroundRing)

-- Главный поток отрисовки 3D векторных колец
Citizen.CreateThread(function()
    local segments = 48 -- 48 сегментов для идеального гладкого круга
    local angleStep = (2.0 * math.pi) / segments

    while true do
        local count = #activeRings
        if count > 0 then
            Citizen.Wait(0)
            local curTime = GetGameTimer()

            for i = count, 1, -1 do
                local ring = activeRings[i]

                if curTime >= ring.endTime then
                    table.remove(activeRings, i)
                else
                    -- Расчет затухания альфа-канала
                    local remaining = ring.endTime - curTime
                    local alphaMultiplier = 1.0
                    if remaining < 600 then
                        alphaMultiplier = remaining / 600.0
                    end

                    local r = ring.color.r
                    local g = ring.color.g
                    local b = ring.color.b
                    local a = math.floor(ring.color.a * alphaMultiplier)

                    local cx = ring.coords.x
                    local cy = ring.coords.y
                    local cz = ring.coords.z
                    local rad = ring.radius

                    -- Отрисовываем 48 сегментов полигонального обруча
                    for s = 0, segments - 1 do
                        local a1 = s * angleStep
                        local a2 = (s + 1) * angleStep

                        local x1 = cx + (rad * math.cos(a1))
                        local y1 = cy + (rad * math.sin(a1))
                        local z1 = GetAccurateGroundZ(x1, y1, cz)

                        local x2 = cx + (rad * math.cos(a2))
                        local y2 = cy + (rad * math.sin(a2))
                        local z2 = GetAccurateGroundZ(x2, y2, cz)

                        -- Рисуем несколько параллельных линий по высоте для толщины и четкости (обруч)
                        DrawLine(x1, y1, z1 + 0.04, x2, y2, z2 + 0.04, r, g, b, a)
                        DrawLine(x1, y1, z1 + 0.08, x2, y2, z2 + 0.08, r, g, b, a)
                        DrawLine(x1, y1, z1 + 0.12, x2, y2, z2 + 0.12, r, g, b, a)
                        DrawLine(x1, y1, z1 + 0.16, x2, y2, z2 + 0.16, r, g, b, a)

                        -- Тонкое внутреннее и внешнее кольцо для объема
                        local inX1 = cx + ((rad - 0.05) * math.cos(a1))
                        local inY1 = cy + ((rad - 0.05) * math.sin(a1))
                        local inX2 = cx + ((rad - 0.05) * math.cos(a2))
                        local inY2 = cy + ((rad - 0.05) * math.sin(a2))
                        DrawLine(inX1, inY1, z1 + 0.08, inX2, inY2, z2 + 0.08, 255, 255, 255, math.floor(a * 0.5))

                        local outX1 = cx + ((rad + 0.05) * math.cos(a1))
                        local outY1 = cy + ((rad + 0.05) * math.sin(a1))
                        local outX2 = cx + ((rad + 0.05) * math.cos(a2))
                        local outY2 = cy + ((rad + 0.05) * math.sin(a2))
                        DrawLine(outX1, outY1, z1 + 0.08, outX2, outY2, z2 + 0.08, 255, 255, 255, math.floor(a * 0.5))
                    end
                end
            end
        else
            Citizen.Wait(100)
        end
    end
end)
