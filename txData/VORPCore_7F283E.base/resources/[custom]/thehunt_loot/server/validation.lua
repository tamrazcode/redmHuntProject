LootValidation = {}

local function number(value, fallback, low, high, integer)
    local n = tonumber(value == nil and fallback or value)
    if not n or n ~= n or n < low or n > high or (integer and n ~= math.floor(n)) then return nil end
    return n
end

function LootValidation.Zone(input)
    if type(input) ~= "table" then return nil, "Некорректные данные зоны" end
    local ok, zone = pcall(function() return json.decode(json.encode(input)) end)
    if not ok or type(zone) ~= "table" then return nil, "Некорректные данные зоны" end
    zone.id = number(zone.id, 0, 0, 2147483647, true)
    if not zone.id then return nil, "Некорректный ID зоны" end
    if type(zone.name) ~= "string" or not zone.name:find("%S") or #zone.name > 200 then
        return nil, "Укажите название зоны (до 200 байт)"
    end
    if not Config.ZoneTypes[zone.zone_type] then return nil, "Неизвестный тип зоны" end
    if type(zone.coords) ~= "table" then return nil, "Укажите координаты зоны" end
    for _, axis in ipairs({ "x", "y", "z" }) do
        local value = number(zone.coords[axis], nil, -20000, 20000)
        if not value then return nil, "Некорректные координаты зоны" end
        zone.coords[axis] = value
    end
    local fields = {
        radius = {10, 0.5, 1000}, height = {4, 0.1, 500},
        size_x = {10, 0.5, 2000}, size_y = {10, 0.5, 2000}, size_z = {4, 0.1, 500},
        heading = {0, -360, 360}, activation_radius = {Config.DefaultActivationRadius, 1, 2000},
        render_radius = {Config.DefaultRenderRadius, 1, 300}, min_distance = {Config.DefaultMinDistance, 0.8, 100},
        min_items = {Config.DefaultMinItems, 1, 100, true}, max_active_items = {Config.DefaultMaxItems, 1, 100, true},
        item_lifetime = {Config.DefaultLifetime, 0, 2592000, true},
        min_respawn_time = {Config.DefaultMinRespawn, 0, 2592000, true},
        max_respawn_time = {Config.DefaultMaxRespawn, 0, 2592000, true}
    }
    for key, limits in pairs(fields) do
        zone[key] = number(zone[key], table.unpack(limits))
        if not zone[key] then return nil, "Недопустимое значение: " .. key end
    end
    if zone.min_items > zone.max_active_items then return nil, "Минимум предметов превышает максимум" end
    if zone.min_respawn_time > zone.max_respawn_time then return nil, "Минимальный респавн превышает максимальный" end
    if zone.zone_type == "point" or zone.zone_type == "container" then zone.min_items = 1; zone.max_active_items = 1 end
    zone.is_enabled = zone.is_enabled == true or zone.is_enabled == 1
    zone.model_name = type(zone.model_name) == "string" and zone.model_name:match("^%s*(.-)%s*$") or nil
    if zone.model_name == "" then zone.model_name = nil end
    if zone.model_name and (#zone.model_name > 100 or not zone.model_name:match("^[%w_]+$")) then return nil, "Некорректное имя модели" end
    zone.model_hash = zone.model_name and GetHashKey(zone.model_name) or nil
    if zone.custom_rules ~= nil and type(zone.custom_rules) ~= "table" then return nil, "Некорректные правила зоны" end
    zone.custom_rules = zone.custom_rules or {}
    zone.custom_rules.unique_items = zone.custom_rules.unique_items == true
    zone.custom_rules.respawn_after_exit = zone.custom_rules.respawn_after_exit == true
    zone.points = zone.points or {}
    if type(zone.points) ~= "table" or #zone.points > 64 then return nil, "Допустимо до 64 вершин" end
    for _, point in ipairs(zone.points) do
        if type(point) ~= "table" then return nil, "Некорректная вершина" end
        for _, axis in ipairs({"x", "y", "z"}) do
            point[axis] = number(point[axis], zone.coords[axis], -20000, 20000)
            if not point[axis] then return nil, "Некорректная вершина" end
        end
    end
    if zone.zone_type == "polygon" then
        if #zone.points < 3 then return nil, "Полигону нужны минимум 3 вершины" end
        local area = 0
        for i, point in ipairs(zone.points) do
            local nextPoint = zone.points[i % #zone.points + 1]
            area = area + point.x * nextPoint.y - nextPoint.x * point.y
        end
        if math.abs(area) < 0.1 then return nil, "Полигон имеет нулевую площадь" end
    end
    if type(zone.selected_items) ~= "table" or #zone.selected_items > 500 then return nil, "Некорректный пул предметов" end
    local seen = {}
    for _, item in ipairs(zone.selected_items) do
        if type(item) ~= "table" or type(item.item_name) ~= "string" then return nil, "Некорректный предмет" end
        local def = Items.Get(item.item_name)
        if not def or seen[item.item_name] then return nil, "Неизвестный или повторяющийся предмет: " .. item.item_name end
        seen[item.item_name] = true
        item.weight = number(item.weight, 100, 1, 100000, true)
        item.min_count = number(item.min_count, 1, 1, def.maxStack or 1, true)
        item.max_count = number(item.max_count, 1, 1, def.maxStack or 1, true)
        if not item.weight or not item.min_count or not item.max_count or item.min_count > item.max_count then
            return nil, "Проверьте вес и размер стака: " .. item.item_name
        end
        if item.metadata ~= nil and type(item.metadata) ~= "table" then return nil, "Некорректные метаданные предмета" end
    end
    if zone.is_enabled and #zone.selected_items == 0 then return nil, "Выберите предметы или выключите пустую зону" end
    return zone
end
