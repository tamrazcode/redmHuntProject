-- =================================================================
-- HUNT: Hard RP — The Corruption | 3D Shapes API & Manager
-- =================================================================

local PersistentShapes = {}
local hasActiveShapes = false

-- =================================================================
-- ПРЯМЫЕ ЭКСПОРТЫ ДЛЯ ПОКАДРОВОГО РЕНДЕРИНГА (Immediate Mode)
-- =================================================================

---Отрисовка 3D сферы (шара)
---@param x number
---@param y number
---@param z number
---@param radius number
---@param r number
---@param g number
---@param b number
---@param a number
exports('DrawSphere', function(x, y, z, radius, r, g, b, a, rings, segs)
    Shapes.DrawSphere(x, y, z, radius, r, g, b, a, rings, segs)
end)

---Отрисовка 3D диска/круга
exports('DrawDisk', function(x, y, z, radius, r, g, b, a, segs)
    Shapes.DrawDisk(x, y, z, radius, r, g, b, a, segs)
end)

---Draw a continuous volumetric 3D hoop without separate outline lines.
exports('DrawHoop', function(x, y, z, radius, tubeRadius, r, g, b, a, segs)
    Shapes.DrawHoop(x, y, z, radius, tubeRadius, r, g, b, a, segs)
end)

---Отрисовка 3D куба / коробки
exports('DrawBox', function(x, y, z, sx, sy, sz, rx, ry, rz, r, g, b, a)
    Shapes.DrawBox(x, y, z, sx, sy, sz, rx, ry, rz, r, g, b, a)
end)

---Отрисовка 3D цилиндра
exports('DrawCylinder', function(x, y, z, radius, height, r, g, b, a, segs)
    Shapes.DrawCylinder(x, y, z, radius, height, r, g, b, a, segs)
end)

---Отрисовка 3D осей координат
exports('DrawAxis', function(x, y, z, length)
    Shapes.DrawAxis(x, y, z, length)
end)

-- =================================================================
-- МЕНЕДЖЕР ПОСТОЯННЫХ ФИГУР (Persistent Shapes)
-- =================================================================

---Регистрация постоянной фигуры (автоматически рендерится в цикле)
---@param id string Уникальный идентификатор
---@param shapeType string 'sphere' | 'box' | 'disk' | 'cylinder' | 'axis'
---@param data table Параметры фигуры
exports('RegisterPersistentShape', function(id, shapeType, data)
    if not id or not shapeType or not data then return end
    PersistentShapes[id] = {
        type = string.lower(shapeType),
        data = data
    }
    hasActiveShapes = true
end)

---Обновление параметров или координат зарегистрированной фигуры
exports('UpdatePersistentShape', function(id, data)
    if not id or not PersistentShapes[id] then return end
    for k, v in pairs(data) do
        PersistentShapes[id].data[k] = v
    end
end)

---Удаление фигуры
exports('RemovePersistentShape', function(id)
    if id and PersistentShapes[id] then
        PersistentShapes[id] = nil
        hasActiveShapes = next(PersistentShapes) ~= nil
    end
end)

---Очистка всех постоянных фигур
exports('ClearAllPersistentShapes', function()
    PersistentShapes = {}
    hasActiveShapes = false
end)

-- =================================================================
-- ПОТОК АВТОМАТИЧЕСКОГО РЕНДЕРИНГА ЗАРЕГИСТРИРОВАННЫХ ФИГУР
-- =================================================================

Citizen.CreateThread(function()
    while true do
        if hasActiveShapes then
            for id, shape in pairs(PersistentShapes) do
                local d = shape.data
                if d and d.x and d.y and d.z then
                    if shape.type == 'sphere' then
                        Shapes.DrawSphere(d.x, d.y, d.z, d.radius, d.r, d.g, d.b, d.a, d.rings, d.segs)
                    elseif shape.type == 'disk' then
                        Shapes.DrawDisk(d.x, d.y, d.z, d.radius, d.r, d.g, d.b, d.a, d.segs)
                    elseif shape.type == 'box' then
                        Shapes.DrawBox(d.x, d.y, d.z, d.sx, d.sy, d.sz, d.rx, d.ry, d.rz, d.r, d.g, d.b, d.a)
                    elseif shape.type == 'cylinder' then
                        Shapes.DrawCylinder(d.x, d.y, d.z, d.radius, d.height, d.r, d.g, d.b, d.a, d.segs)
                    elseif shape.type == 'axis' then
                        Shapes.DrawAxis(d.x, d.y, d.z, d.length)
                    end
                end
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)
