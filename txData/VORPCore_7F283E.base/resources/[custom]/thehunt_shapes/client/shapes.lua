-- =================================================================
-- HUNT: Hard RP — The Corruption | 3D Shape Geometry Engine (DrawPoly)
-- =================================================================

Shapes = {}

local pi = math.pi
local sin = math.sin
local cos = math.cos

-- Предварительно сгенерированная сетка единичной сферы (UV Sphere)
local UNIT_SPHERE_RINGS = 12
local UNIT_SPHERE_SEGS = 18
local SphereVertices = {}
local SphereTriangles = {}

local function BuildUnitSphereMesh()
    SphereVertices = {}
    SphereTriangles = {}

    -- Генерация вершин
    for i = 0, UNIT_SPHERE_RINGS do
        local phi = (i / UNIT_SPHERE_RINGS) * pi
        local sinPhi = sin(phi)
        local cosPhi = cos(phi)

        for j = 0, UNIT_SPHERE_SEGS do
            local theta = (j / UNIT_SPHERE_SEGS) * (2 * pi)
            local x = sinPhi * cos(theta)
            local y = sinPhi * sin(theta)
            local z = cosPhi
            table.insert(SphereVertices, { x = x, y = y, z = z })
        end
    end

    -- Генерация треугольников
    local segsPlusOne = UNIT_SPHERE_SEGS + 1
    for i = 0, UNIT_SPHERE_RINGS - 1 do
        for j = 0, UNIT_SPHERE_SEGS - 1 do
            local p1 = (i * segsPlusOne) + j + 1
            local p2 = p1 + segsPlusOne
            local p3 = p1 + 1
            local p4 = p2 + 1

            -- Треугольник 1
            table.insert(SphereTriangles, { p1, p2, p3 })
            -- Треугольник 2
            table.insert(SphereTriangles, { p3, p2, p4 })
        end
    end
end

BuildUnitSphereMesh()

-- =================================================================
-- 1. ОТРИСОВКА ЗАЛИВНОГО ПОЛУПРОЗРАЧНОГО 3D ШАРА (Solid Ghost Sphere)
-- =================================================================
function Shapes.DrawSphere(x, y, z, radius, r, g, b, a)
    local rad = radius or 0.22
    local red = r or 255
    local green = g or 255
    local blue = b or 255
    local alpha = a or 160

    -- Отрисовка всех полигонов сферы (двусторонние для идеальной видимости)
    for _, tri in ipairs(SphereTriangles) do
        local v1 = SphereVertices[tri[1]]
        local v2 = SphereVertices[tri[2]]
        local v3 = SphereVertices[tri[3]]

        local x1, y1, z1 = x + v1.x * rad, y + v1.y * rad, z + v1.z * rad
        local x2, y2, z2 = x + v2.x * rad, y + v2.y * rad, z + v2.z * rad
        local x3, y3, z3 = x + v3.x * rad, y + v3.y * rad, z + v3.z * rad

        -- Лицевая сторона
        DrawPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, red, green, blue, alpha)
        -- Обратная сторона (внутренний объем)
        DrawPoly(x3, y3, z3, x2, y2, z2, x1, y1, z1, red, green, blue, math.floor(alpha * 0.75))
    end

    -- Легкий светящийся контур экватора
    local segs = 20
    local step = (2 * pi) / segs
    local prevX = x + rad * cos(0)
    local prevY = y + rad * sin(0)
    for s = 1, segs do
        local theta = s * step
        local curX = x + rad * cos(theta)
        local curY = y + rad * sin(theta)
        DrawLine(prevX, prevY, z, curX, curY, z, red, green, blue, math.min(255, alpha + 50))
        prevX = curX
        prevY = curY
    end
end

-- Continuous volumetric hoop (single visual ring, no outline lines).
function Shapes.DrawHoop(x, y, z, radius, tubeRadius, r, g, b, a, segments)
    local rad = tonumber(radius) or 0.4
    local tube = math.max(tonumber(tubeRadius) or 0.16, 0.02)
    local red = r or 255
    local green = g or 255
    local blue = b or 255
    local alpha = a or 180
    local segs = math.max(tonumber(segments) or 48, 16)
    local majorStep = (2 * pi) / segs
    local crossSegments = 8
    local crossStep = pi / crossSegments

    local function point(theta, phi)
        local ringRadius = rad + tube * cos(phi)
        return x + ringRadius * cos(theta),
            y + ringRadius * sin(theta),
            z + tube * sin(phi)
    end

    local function drawTriangle(ax, ay, az, bx, by, bz, cx, cy, cz, faceAlpha, shade)
        local faceRed = math.floor(red * shade)
        local faceGreen = math.floor(green * shade)
        local faceBlue = math.floor(blue * shade)
        DrawPoly(ax, ay, az, bx, by, bz, cx, cy, cz, faceRed, faceGreen, faceBlue, faceAlpha)
    end

    -- Только верхняя половина сечения: единый округлый объёмный пояс без
    -- внутренних стенок, обратных прозрачных граней и з-файтинга.
    for i = 0, segs - 1 do
        local theta1 = i * majorStep
        local theta2 = (i + 1) * majorStep

        for j = 0, crossSegments - 1 do
            local phi1 = j * crossStep
            local phi2 = (j + 1) * crossStep
            local phiMid = (phi1 + phi2) * 0.5
            local shade = 0.78 + (0.22 * sin(phiMid))

            local a1x, a1y, a1z = point(theta1, phi1)
            local b1x, b1y, b1z = point(theta2, phi1)
            local c1x, c1y, c1z = point(theta2, phi2)
            local d1x, d1y, d1z = point(theta1, phi2)

            drawTriangle(a1x, a1y, a1z, b1x, b1y, b1z, c1x, c1y, c1z, alpha, shade)
            drawTriangle(a1x, a1y, a1z, c1x, c1y, c1z, d1x, d1y, d1z, alpha, shade)
        end
    end
end

-- =================================================================
-- 2. ОТРИСОВКА 3D ДИСКА / КРУГА
-- =================================================================
function Shapes.DrawDisk(x, y, z, radius, r, g, b, a, segments)
    local rad = radius or 0.4
    local red = r or 255
    local green = g or 255
    local blue = b or 255
    local alpha = a or 160
    local segs = segments or 48

    local step = (2 * pi) / segs
    local prevX = x + rad * cos(0)
    local prevY = y + rad * sin(0)

    for i = 1, segs do
        local theta = i * step
        local curX = x + rad * cos(theta)
        local curY = y + rad * sin(theta)

        DrawPoly(x, y, z, prevX, prevY, z, curX, curY, z, red, green, blue, alpha)
        DrawPoly(x, y, z, curX, curY, z, prevX, prevY, z, red, green, blue, alpha)
        DrawLine(prevX, prevY, z, curX, curY, z, red, green, blue, math.min(255, alpha + 80))

        prevX = curX
        prevY = curY
    end
end

-- =================================================================
-- 3. ОТРИСОВКА 3D КУБА / БОКСА (Solid/Wireframe)
-- =================================================================
function Shapes.DrawBox(x, y, z, sx, sy, sz, rx, ry, rz, r, g, b, a)
    local hx = (sx or 1.0) / 2
    local hy = (sy or 1.0) / 2
    local hz = (sz or 1.0) / 2

    local red = r or 255
    local green = g or 255
    local blue = b or 255
    local alpha = a or 160

    local rotZ = math.rad(rz or 0.0)
    local cosZ = math.cos(rotZ)
    local sinZ = math.sin(rotZ)

    local function rotatePoint(px, py, pz)
        local nx = px * cosZ - py * sinZ
        local ny = px * sinZ + py * cosZ
        return x + nx, y + ny, z + pz
    end

    local c1x, c1y, c1z = rotatePoint(-hx, -hy, -hz)
    local c2x, c2y, c2z = rotatePoint( hx, -hy, -hz)
    local c3x, c3y, c3z = rotatePoint( hx,  hy, -hz)
    local c4x, c4y, c4z = rotatePoint(-hx,  hy, -hz)

    local c5x, c5y, c5z = rotatePoint(-hx, -hy,  hz)
    local c6x, c6y, c6z = rotatePoint( hx, -hy,  hz)
    local c7x, c7y, c7z = rotatePoint( hx,  hy,  hz)
    local c8x, c8y, c8z = rotatePoint(-hx,  hy,  hz)

    -- Грани куба (двусторонние)
    DrawPoly(c1x, c1y, c1z, c2x, c2y, c2z, c3x, c3y, c3z, red, green, blue, alpha)
    DrawPoly(c1x, c1y, c1z, c3x, c3y, c3z, c2x, c2y, c2z, red, green, blue, alpha)
    DrawPoly(c1x, c1y, c1z, c3x, c3y, c3z, c4x, c4y, c4z, red, green, blue, alpha)
    DrawPoly(c1x, c1y, c1z, c4x, c4y, c4z, c3x, c3y, c3z, red, green, blue, alpha)

    DrawPoly(c5x, c5y, c5z, c7x, c7y, c7z, c6x, c6y, c6z, red, green, blue, alpha)
    DrawPoly(c5x, c5y, c5z, c6x, c6y, c6z, c7x, c7y, c7z, red, green, blue, alpha)
    DrawPoly(c5x, c5y, c5z, c8x, c8y, c8z, c7x, c7y, c7z, red, green, blue, alpha)
    DrawPoly(c5x, c5y, c5z, c7x, c7y, c7z, c8x, c8y, c8z, red, green, blue, alpha)

    -- Боковые грани
    DrawPoly(c1x, c1y, c1z, c5x, c5y, c5z, c6x, c6y, c6z, red, green, blue, alpha)
    DrawPoly(c1x, c1y, c1z, c6x, c6y, c6z, c2x, c2y, c2z, red, green, blue, alpha)

    DrawPoly(c2x, c2y, c2z, c6x, c6y, c6z, c7x, c7y, c7z, red, green, blue, alpha)
    DrawPoly(c2x, c2y, c2z, c7x, c7y, c7z, c3x, c3y, c3z, red, green, blue, alpha)

    DrawPoly(c3x, c3y, c3z, c7x, c7y, c7z, c8x, c8y, c8z, red, green, blue, alpha)
    DrawPoly(c3x, c3y, c3z, c8x, c8y, c8z, c4x, c4y, c4z, red, green, blue, alpha)

    DrawPoly(c4x, c4y, c4z, c8x, c8y, c8z, c5x, c5y, c5z, red, green, blue, alpha)
    DrawPoly(c4x, c4y, c4z, c5x, c5y, c5z, c1x, c1y, c1z, red, green, blue, alpha)

    -- Контуры куба
    DrawLine(c1x, c1y, c1z, c2x, c2y, c2z, red, green, blue, 255)
    DrawLine(c2x, c2y, c2z, c3x, c3y, c3z, red, green, blue, 255)
    DrawLine(c3x, c3y, c3z, c4x, c4y, c4z, red, green, blue, 255)
    DrawLine(c4x, c4y, c4z, c1x, c1y, c1z, red, green, blue, 255)

    DrawLine(c5x, c5y, c5z, c6x, c6y, c6z, red, green, blue, 255)
    DrawLine(c6x, c6y, c6z, c7x, c7y, c7z, red, green, blue, 255)
    DrawLine(c7x, c7y, c7z, c8x, c8y, c8z, red, green, blue, 255)
    DrawLine(c8x, c8y, c8z, c5x, c5y, c5z, red, green, blue, 255)

    DrawLine(c1x, c1y, c1z, c5x, c5y, c5z, red, green, blue, 255)
    DrawLine(c2x, c2y, c2z, c6x, c6y, c6z, red, green, blue, 255)
    DrawLine(c3x, c3y, c3z, c7x, c7y, c7z, red, green, blue, 255)
    DrawLine(c4x, c4y, c4z, c8x, c8y, c8z, red, green, blue, 255)
end

-- =================================================================
-- 4. ОТРИСОВКА 3D ЦИЛИНДРА (Идеально круглый, объемный, без артефактов)
-- =================================================================
function Shapes.DrawCylinder(x, y, z, radius, height, r, g, b, a, segments, isCentered)
    local rad = radius or 0.4
    local h = height or 1.0
    local red = r or 255
    local green = g or 255
    local blue = b or 255
    local alpha = a or 160
    local segs = segments or 48

    local zBottom = isCentered and (z - (h / 2)) or z
    local zTop = zBottom + h
    local zMid = zBottom + (h / 2)

    local step = (2 * pi) / segs
    local prevBX = x + rad * cos(0)
    local prevBY = y + rad * sin(0)

    for i = 1, segs do
        local theta = i * step
        local curBX = x + rad * cos(theta)
        local curBY = y + rad * sin(theta)

        -- Двусторонняя полупрозрачная боковая поверхность (DrawPoly)
        DrawPoly(prevBX, prevBY, zBottom, curBX, curBY, zBottom, curBX, curBY, zTop, red, green, blue, alpha)
        DrawPoly(curBX, curBY, zTop, curBX, curBY, zBottom, prevBX, prevBY, zBottom, red, green, blue, alpha)

        DrawPoly(prevBX, prevBY, zBottom, curBX, curBY, zTop, prevBX, prevBY, zTop, red, green, blue, alpha)
        DrawPoly(prevBX, prevBY, zTop, curBX, curBY, zTop, prevBX, prevBY, zBottom, red, green, blue, alpha)

        -- Яркие плавные кольца контуров (низ, середина, верх)
        DrawLine(prevBX, prevBY, zBottom, curBX, curBY, zBottom, red, green, blue, 255)
        DrawLine(prevBX, prevBY, zTop, curBX, curBY, zTop, red, green, blue, 255)
        if h > 2.0 then
            DrawLine(prevBX, prevBY, zMid, curBX, curBY, zMid, red, green, blue, math.min(255, alpha + 40))
        end

        -- Вертикальные ребра через каждые 4 сегмента для стильной 3D-сетки
        if (i % 4 == 0) then
            DrawLine(curBX, curBY, zBottom, curBX, curBY, zTop, red, green, blue, math.min(255, alpha + 60))
        end

        prevBX = curBX
        prevBY = curBY
    end
end

-- =================================================================
-- 5. ОТРИСОВКА 3D КООРДИНАТНЫХ ОСЕЙ
-- =================================================================
function Shapes.DrawAxis(x, y, z, length)
    local len = length or 0.5
    DrawLine(x, y, z, x + len, y, z, 255, 0, 0, 255)
    DrawLine(x, y, z, x, y + len, z, 0, 255, 0, 255)
    DrawLine(x, y, z, x, y, z + len, 0, 150, 255, 255)
end
