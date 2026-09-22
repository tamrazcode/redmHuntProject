-- =================================================================
-- HUNT: Hard RP — Water Pump System | Server Controller
-- =================================================================

local function GetPlayerIdentifiersVORP(src)
    local steamId = "unknown"
    local charId = 1

    local char = exports.thehunt_core and exports.thehunt_core:GetCharacter(src)
    if char then
        steamId = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src) or "unknown"
        charId = tonumber(char.charIdentifier or char.charid) or 1
    end

    if steamId == "unknown" then
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if string.find(id, "steam:") or string.find(id, "license:") then
                steamId = id
                break
            end
        end
    end

    return steamId, charId
end

local function SafeDecode(str)
    if not str or str == "" then return {} end
    local ok, res = pcall(json.decode, str)
    return (ok and type(res) == "table") and res or {}
end

-- =================================================================
-- 1. НАПОЛНЕНИЕ БУТЫЛКИ
-- =================================================================

RegisterNetEvent("thehunt_items:serverCheckFillBottle", function()
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or steamId == "unknown" then return end

    local rows = MySQL.query.await("SELECT id, item_name, count, metadata FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    local hasEmptyBottle = false
    local hasWaterBottle = false

    for _, row in ipairs(rows) do
        if row.item_name == "bottle_empty" and (tonumber(row.count) or 0) > 0 then
            hasEmptyBottle = true
            break
        elseif row.item_name == "bottle_water" then
            hasWaterBottle = true
        end
    end

    if hasEmptyBottle then
        TriggerClientEvent("thehunt_items:clientStartFillBottle", src)
    else
        if hasWaterBottle then
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Все ваши бутылки уже полные", "info")
        else
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "У вас нет пустых бутылок для наполнения", "warning")
        end
    end
end)

RegisterNetEvent("thehunt_items:serverFinishFillBottle", function()
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or steamId == "unknown" then return end

    local rows = MySQL.query.await("SELECT id, item_name, count, metadata FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    local emptyRow = nil
    for _, row in ipairs(rows) do
        if row.item_name == "bottle_empty" and (tonumber(row.count) or 0) > 0 then
            emptyRow = row
            break
        end
    end

    if not emptyRow then
        TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Пустая бутылка не найдена", "error")
        return
    end

    local curCount = tonumber(emptyRow.count) or 1
    if curCount <= 1 then
        -- Трансформация текущей ячейки инвентаря в бутылку с водой (сохраняет координаты слота)
        MySQL.update.await("UPDATE thehunt_inventories SET item_name = 'bottle_water', count = 1, metadata = NULL WHERE id = ?", { emptyRow.id })
        TriggerClientEvent("thehunt_items:refreshInventory", src)
        TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Бутылка наполнена водой", "success")
    else
        -- Уменьшаем стак пустых бутылок на 1
        MySQL.update.await("UPDATE thehunt_inventories SET count = count - 1 WHERE id = ?", { emptyRow.id })
        if exports.thehunt_items and exports.thehunt_items.GiveItem then
            exports.thehunt_items:GiveItem(src, "bottle_water", 1, nil, function(success)
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Бутылка наполнена водой", "success")
            end)
        else
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Бутылка наполнена водой", "success")
        end
    end
end)

-- =================================================================
-- 2. НАПОЛНЕНИЕ ФЛЯГИ / БУРДЮКА
-- Проверяет по очереди: сначала флягу, потом бурдюк.
-- Наполняет полностью за 1 раз.
-- =================================================================

RegisterNetEvent("thehunt_items:serverCheckFillFlaskWaterskin", function()
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or steamId == "unknown" then return end

    local rows = MySQL.query.await("SELECT id, item_name, count, metadata FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    local targetFound = false
    local hasFullContainers = false

    -- 1. Сначала проверяем флягу (приоритет №1)
    for _, row in ipairs(rows) do
        if row.item_name == "flask" and (tonumber(row.count) or 0) > 0 then
            targetFound = true
            break
        elseif row.item_name == "flask_water" then
            local meta = SafeDecode(row.metadata)
            local curUses = tonumber(meta.uses)
            if curUses ~= nil and curUses < 3 then
                targetFound = true
                break
            else
                hasFullContainers = true
            end
        end
    end

    -- 2. Если фляга не требует наполнения — проверяем бурдюк (приоритет №2)
    if not targetFound then
        for _, row in ipairs(rows) do
            if row.item_name == "waterskin" and (tonumber(row.count) or 0) > 0 then
                targetFound = true
                break
            elseif row.item_name == "waterskin_water" then
                local meta = SafeDecode(row.metadata)
                local curUses = tonumber(meta.uses)
                if curUses ~= nil and curUses < 2 then
                    targetFound = true
                    break
                else
                    hasFullContainers = true
                end
            end
        end
    end

    if targetFound then
        TriggerClientEvent("thehunt_items:clientStartFillFlaskWaterskin", src)
    else
        if hasFullContainers then
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Ваша фляга / бурдюк уже полностью наполнены", "info")
        else
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "У вас нет фляги или бурдюка для наполнения", "warning")
        end
    end
end)

RegisterNetEvent("thehunt_items:serverFinishFillFlaskWaterskin", function()
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    if not steamId or steamId == "unknown" then return end

    local rows = MySQL.query.await("SELECT id, item_name, count, metadata FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ?", {
        steamId, charId
    }) or {}

    -- 1. Приоритет: Фляга
    for _, row in ipairs(rows) do
        if row.item_name == "flask" and (tonumber(row.count) or 0) > 0 then
            local fullMeta = json.encode({ uses = 3, maxUses = 3 })
            MySQL.update.await("UPDATE thehunt_inventories SET item_name = 'flask_water', metadata = ? WHERE id = ?", { fullMeta, row.id })
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Фляга полностью наполнена водой", "success")
            return
        elseif row.item_name == "flask_water" then
            local meta = SafeDecode(row.metadata)
            local curUses = tonumber(meta.uses)
            if curUses ~= nil and curUses < 3 then
                meta.uses = 3
                meta.maxUses = 3
                MySQL.update.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), row.id })
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Фляга полностью наполнена водой", "success")
                return
            end
        end
    end

    -- 2. Приоритет: Бурдюк
    for _, row in ipairs(rows) do
        if row.item_name == "waterskin" and (tonumber(row.count) or 0) > 0 then
            local fullMeta = json.encode({ uses = 2, maxUses = 2 })
            MySQL.update.await("UPDATE thehunt_inventories SET item_name = 'waterskin_water', metadata = ? WHERE id = ?", { fullMeta, row.id })
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Бурдюк полностью наполнен водой", "success")
            return
        elseif row.item_name == "waterskin_water" then
            local meta = SafeDecode(row.metadata)
            local curUses = tonumber(meta.uses)
            if curUses ~= nil and curUses < 2 then
                meta.uses = 2
                meta.maxUses = 2
                MySQL.update.await("UPDATE thehunt_inventories SET metadata = ? WHERE id = ?", { json.encode(meta), row.id })
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Бурдюк полностью наполнен водой", "success")
                return
            end
        end
    end

    TriggerClientEvent("thehunt_status:notify", src, "Колонка", "Нечего наполнять", "warning")
end)
