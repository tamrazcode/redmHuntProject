-- =================================================================
-- HUNT: Hard RP — Crafting System | Server Controller & Inventory Sync
-- =================================================================

-- Получить VORP Steam/Char идентификаторы
local function GetPlayerIdentifiersVORP(src)
    local steamId = "unknown"
    local charId = 1

    local char = exports.thehunt_core:GetCharacter(src)
    if char then
        steamId = char.identifier or exports.thehunt_core:GetPlayerIdentifier(src) or "unknown"
        charId = tonumber(char.charIdentifier or char.charid) or 1
    end

    if steamId == "unknown" then
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if string.find(id, "license:") or string.find(id, "steam:") then
                steamId = id
                break
            end
        end
    end

    return steamId, charId
end

-- Поиск свободного слота в сетке инвентаря игрока
local function FindFreeSlot(items, cols, rows, itemW, itemH, rowWidths)
    cols = cols or 7
    rows = rows or 5
    itemW = itemW or 1
    itemH = itemH or 1

    local matrix = {}
    for r = 0, rows - 1 do
        matrix[r] = {}
        local rowWidth = (rowWidths and tonumber(rowWidths[r + 1])) or cols
        for c = 0, cols - 1 do
            matrix[r][c] = c >= rowWidth
        end
    end

    for _, it in ipairs(items) do
        if (tonumber(it.count) or 1) > 0 then
            local def = (Items and Items.Get and Items.Get(it.item_name)) or (exports.thehunt_items and exports.thehunt_items:GetItemData(it.item_name))
            local rawW = def and def.width or 1
            local rawH = def and def.height or 1
            local isRot = (it.is_rotated == true or it.is_rotated == 1 or tonumber(it.is_rotated) == 1)
            local w = isRot and rawH or rawW
            local h = isRot and rawW or rawH
            local startX = tonumber(it.slot_x) or 0
            local startY = tonumber(it.slot_y) or 0

            for r = 0, h - 1 do
                for c = 0, w - 1 do
                    if matrix[startY + r] and matrix[startY + r][startX + c] ~= nil then
                        matrix[startY + r][startX + c] = true
                    end
                end
            end
        end
    end

    -- 1. Сначала без поворота
    for r = 0, rows - itemH do
        for c = 0, cols - itemW do
            local canFit = true
            for checkR = 0, itemH - 1 do
                for checkC = 0, itemW - 1 do
                    if matrix[r + checkR][c + checkC] then
                        canFit = false
                        break
                    end
                end
                if not canFit then break end
            end
            if canFit then
                return c, r, false
            end
        end
    end

    -- 2. Если не поместился, с поворотом 90 градусов (если не квадрат)
    if itemW ~= itemH then
        local rotW = itemH
        local rotH = itemW
        for r = 0, rows - rotH do
            for c = 0, cols - rotW do
                local canFit = true
                for checkR = 0, rotH - 1 do
                    for checkC = 0, rotW - 1 do
                        if matrix[r + checkR][c + checkC] then
                            canFit = false
                            break
                        end
                    end
                    if not canFit then break end
                end
                if canFit then
                    return c, r, true
                end
            end
        end
    end

    return nil, nil, false
end

local function GetItemDefinition(itemName)
    if Items and Items.Get then
        return Items.Get(itemName)
    end
    return nil
end

local function BuildInventoryCounts(rows)
    local counts = {}
    for _, row in ipairs(rows or {}) do
        local itemName = row.item_name
        local count = tonumber(row.count) or 1
        if itemName and count > 0 then
            counts[itemName] = (counts[itemName] or 0) + count
        end
    end
    return counts
end

-- Крафт видит основной инвентарь и хранилища надетой одежды.
-- Контейнер одежды принимается только если его родитель действительно лежит
-- в equipment и у предмета есть описание storage.
local function BuildCraftingInventory(mainRows, equipmentRows, childRows)
    local clothingContainers = {}
    local containersByName = {}
    local containerNames = {}

    for _, parent in ipairs(equipmentRows or {}) do
        local parentId = tonumber(parent.id)
        local parentDef = GetItemDefinition(parent.item_name)

        if parentId and parentDef and parentDef.clothing and parentDef.storage then
            local containerName = "clothing:" .. tostring(parentId)
            if not containersByName[containerName] then
                local container = {
                    id = parentId,
                    container = containerName,
                    storage = parentDef.storage,
                    rows = {}
                }

                clothingContainers[#clothingContainers + 1] = container
                containersByName[containerName] = container
                containerNames[#containerNames + 1] = containerName
            end
        end
    end

    for _, row in ipairs(childRows or {}) do
        local container = containersByName[row.container]
        if container then
            container.rows[#container.rows + 1] = row
        end
    end

    local allRows = {}
    for _, row in ipairs(mainRows or {}) do
        allRows[#allRows + 1] = row
    end
    for _, container in ipairs(clothingContainers) do
        for _, row in ipairs(container.rows) do
            allRows[#allRows + 1] = row
        end
    end

    return {
        main = mainRows or {},
        clothing = clothingContainers,
        all = allRows,
        containerNames = containerNames
    }
end

local function LoadCraftingInventory(identifier, charId)
    local mainRows = MySQL.query.await([[
        SELECT *
        FROM thehunt_inventories
        WHERE identifier = ? AND charidentifier = ? AND container = 'main'
        ORDER BY id
    ]], { identifier, charId }) or {}

    local equipmentRows = MySQL.query.await([[
        SELECT id, item_name, slot_x
        FROM thehunt_inventories
        WHERE identifier = ? AND charidentifier = ? AND container = 'equipment'
        ORDER BY slot_x, id
    ]], { identifier, charId }) or {}

    local inventory = BuildCraftingInventory(mainRows, equipmentRows, {})
    if #inventory.containerNames == 0 then
        return inventory
    end

    local placeholders = {}
    local params = { identifier, charId }
    for _, containerName in ipairs(inventory.containerNames) do
        placeholders[#placeholders + 1] = "?"
        params[#params + 1] = containerName
    end

    local childRows = MySQL.query.await(
        "SELECT * FROM thehunt_inventories " ..
        "WHERE identifier = ? AND charidentifier = ? " ..
        "AND container IN (" .. table.concat(placeholders, ",") .. ") " ..
        "ORDER BY container, slot_y, slot_x, id",
        params
    ) or {}

    return BuildCraftingInventory(mainRows, equipmentRows, childRows)
end

-- Nested rows remain part of the carried inventory even while a backpack is
-- unequipped and therefore hidden from the NUI.  Keep this calculation local
-- to crafting so recipes and free-slot allocation see the same ownership tree.
local function IsCarriedContainer(container, itemsById, visited)
    local current = tostring(container or "")
    if current == "main" or current == "equipment" then return true end
    if current == "ground" or current:sub(1, 5) == "prop:" then return false end

    local parentId = tonumber(current:match("^container:(%d+)$") or current:match("^clothing:(%d+)$"))
    if not parentId then return false end
    visited = visited or {}
    if visited[parentId] then return false end
    visited[parentId] = true
    local parent = itemsById and itemsById[parentId]
    return parent and IsCarriedContainer(parent.container, itemsById, visited) or false
end

local function IsContainerDefinition(def)
    return def and (def.isContainer == true or def.containerStorage ~= nil)
end

-- Replace the old clothing-only view with a complete carried tree.  This
-- keeps the existing UI-facing `clothing` field and adds `containers` for
-- portable bags/backpacks, including nested bags.
local function BuildCraftingInventory(mainRows, equipmentRows, allPlayerRows)
    local itemsById, allRows = {}, {}
    local clothingContainers, portableContainers = {}, {}
    local containersByName, containerNames = {}, {}

    for _, row in ipairs(allPlayerRows or {}) do
        local rowId = tonumber(row.id)
        if rowId then itemsById[rowId] = row end
    end

    for _, parent in ipairs(equipmentRows or {}) do
        local parentId = tonumber(parent.id)
        local parentDef = GetItemDefinition(parent.item_name)
        if parentId and parentDef and parentDef.clothing and parentDef.storage then
            local name = "clothing:" .. tostring(parentId)
            local destination = { id = parentId, container = name, storage = parentDef.storage, rows = {} }
            clothingContainers[#clothingContainers + 1] = destination
            containersByName[name] = destination
            containerNames[#containerNames + 1] = name
        end
    end

    for _, parent in ipairs(allPlayerRows or {}) do
        local parentId = tonumber(parent.id)
        local parentDef = GetItemDefinition(parent.item_name)
        local parentContainer = tostring(parent.container or "main")
        if parentId and parentDef and parentDef.containerStorage
            and IsCarriedContainer(parentContainer, itemsById)
            and not (parentDef.isBackpack == true and parentContainer == "equipment") then
            local name = "container:" .. tostring(parentId)
            local destination = {
                id = parentId,
                container = name,
                storage = parentDef.containerStorage,
                cols = tonumber(parentDef.containerStorage.cols) or 2,
                gridRows = tonumber(parentDef.containerStorage.rows) or 3,
                rows = {}
            }
            portableContainers[#portableContainers + 1] = destination
            containersByName[name] = destination
            containerNames[#containerNames + 1] = name
        end
    end

    for _, row in ipairs(allPlayerRows or {}) do
        local name = tostring(row.container or "main")
        if name ~= "main" and name ~= "equipment" and IsCarriedContainer(name, itemsById) then
            local destination = containersByName[name]
            if destination then destination.rows[#destination.rows + 1] = row end
        end
    end

    for _, row in ipairs(mainRows or {}) do allRows[#allRows + 1] = row end
    for _, row in ipairs(allPlayerRows or {}) do
        local name = tostring(row.container or "main")
        if name ~= "main" and name ~= "equipment" and IsCarriedContainer(name, itemsById) then
            allRows[#allRows + 1] = row
        end
    end

    return {
        main = mainRows or {},
        clothing = clothingContainers,
        containers = portableContainers,
        all = allRows,
        containerNames = containerNames
    }
end

local function LoadCraftingInventory(identifier, charId)
    local rows = MySQL.query.await([[
        SELECT *
        FROM thehunt_inventories
        WHERE identifier = ? AND charidentifier = ?
        ORDER BY id
    ]], { identifier, charId }) or {}

    local mainRows, equipmentRows = {}, {}
    for _, row in ipairs(rows) do
        local name = tostring(row.container or "main")
        if name == "main" then
            mainRows[#mainRows + 1] = row
        elseif name == "equipment" then
            equipmentRows[#equipmentRows + 1] = row
        end
    end
    table.sort(equipmentRows, function(a, b)
        local ax, bx = tonumber(a.slot_x) or 999, tonumber(b.slot_x) or 999
        if ax == bx then return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end
        return ax < bx
    end)
    return BuildCraftingInventory(mainRows, equipmentRows, rows)
end

local function WithCraftingInventory(identifier, charId, callback)
    Citizen.CreateThread(function()
        callback(LoadCraftingInventory(identifier, charId))
    end)
end

local function NotifyCrafting(src, message, notifyType)
    TriggerClientEvent(
        "thehunt_status:notify",
        src,
        "Создание",
        message,
        notifyType or "info"
    )
end

-- =================================================================
-- NET EVENTS
-- =================================================================

-- 1. Запрос снапшота инвентаря для меню крафта
RegisterNetEvent("thehunt_crafting:requestData", function(station)
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)

    WithCraftingInventory(steamId, charId, function(inventory)
        TriggerClientEvent(
            "thehunt_crafting:updateInventoryCounts",
            src,
            BuildInventoryCounts(inventory.all)
        )
    end)
end)

-- Проверка соответствия рецепта текущей крафт-станции
local function IsRecipeAllowedAtStation(recipe, station)
    if not recipe then return false end
    local recStation = recipe.station or "field"
    if station == "workbench" then
        return recStation == "workbench" or recStation == "field"
    elseif station == "field" then
        return recStation == "field"
    else
        return recStation == station
    end
end

local function GetStationDisplayName(stationKey)
    local stationNames = {
        workbench = "на верстаке",
        campfire = "на костре",
        med_table = "на медицинском столе",
        furnace = "в плавильной печи",
        anvil = "на наковальне",
        field = "в полевых условиях"
    }
    return stationNames[stationKey or "field"] or "на специальной станции"
end

-- 2. Проверка возможности начала крафта (хватает ли ресурсов и места)
RegisterNetEvent("thehunt_crafting:checkCanCraft", function(recipeId, amount, station, queueSlotIndex)
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local recipe = Crafting.GetRecipe(recipeId)
    local craftAmount = math.max(1, tonumber(amount) or 1)

    if not recipe then
        TriggerClientEvent("thehunt_crafting:craftCheckResult", src, false, "Рецепт не найден", queueSlotIndex)
        return
    end

    if not IsRecipeAllowedAtStation(recipe, station) then
        local requiredWhere = GetStationDisplayName(recipe.station)
        TriggerClientEvent("thehunt_crafting:craftCheckResult", src, false, string.format("Этот предмет можно создать только %s", requiredWhere), queueSlotIndex)
        return
    end

    WithCraftingInventory(steamId, charId, function(inventory)
        local inventoryCounts = BuildInventoryCounts(inventory.all)

        -- Проверка рецепта
        if recipe.requiredRecipeItem and (inventoryCounts[recipe.requiredRecipeItem] or 0) < 1 then
            TriggerClientEvent("thehunt_crafting:craftCheckResult", src, false, "У вас нет необходимого рецепта", queueSlotIndex)
            return
        end

        -- Проверка требуемого инструмента (не расходуется при крафте)
        if recipe.requiredTool and (inventoryCounts[recipe.requiredTool] or 0) < 1 then
            local toolDef = GetItemDefinition(recipe.requiredTool)
            local toolName = (toolDef and toolDef.label) or recipe.requiredTool
            TriggerClientEvent("thehunt_crafting:craftCheckResult", src, false, string.format("Требуется инструмент: %s", toolName), queueSlotIndex)
            return
        end

        -- Проверка ингредиентов
        for _, ing in ipairs(recipe.ingredients or {}) do
            local needed = (ing.count or 1) * craftAmount
            local have = inventoryCounts[ing.item] or 0
            if have < needed then
                TriggerClientEvent("thehunt_crafting:craftCheckResult", src, false, "Недостаточно ингредиентов для создания", queueSlotIndex)
                return
            end
        end

        -- Проверка места в инвентаре
        local resultDef = GetItemDefinition(recipe.resultItem)
        if not resultDef then
            TriggerClientEvent("thehunt_crafting:craftCheckResult", src, false, "Ошибка данных предмета", queueSlotIndex)
            return
        end

        local totalResultCount = (recipe.resultCount or 1) * craftAmount
        local maxStack = resultDef.maxStack or 1

        -- Разрешаем крафт: если места в инвентаре не хватит, предмет автоматически упадет на землю в дроп
        TriggerClientEvent("thehunt_crafting:craftCheckResult", src, true, nil, queueSlotIndex)
    end)
end)

-- 3. Завершение крафта (по окончании таймера): списание ресурсов и выдача предмета
if false then
RegisterNetEvent("thehunt_crafting:finishCraft_legacy", function(recipeId, amount, station)
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local recipe = Crafting.GetRecipe(recipeId)
    local craftAmount = math.max(1, tonumber(amount) or 1)

    if not recipe then
        TriggerClientEvent("thehunt_status:notify", src, "Создание", "Рецепт не найден", "error")
        return
    end

    if recipe.station == "workbench" and station ~= "workbench" then
        TriggerClientEvent("thehunt_status:notify", src, "Создание", "Этот предмет можно создать только на верстаке", "error")
        return
    elseif recipe.station == "campfire" and station ~= "campfire" then
        TriggerClientEvent("thehunt_status:notify", src, "Создание", "Этот предмет можно приготовить только на костре", "error")
        return
    elseif recipe.station == "med_table" and station ~= "med_table" then
        TriggerClientEvent("thehunt_status:notify", src, "Создание", "Этот предмет можно создать только на медицинском столе", "error")
        return
    elseif recipe.station == "furnace" and station ~= "furnace" then
        TriggerClientEvent("thehunt_status:notify", src, "Создание", "Этот предмет можно выплавить только в плавильной печи", "error")
        return
    elseif recipe.station == "anvil" and station ~= "anvil" then
        TriggerClientEvent("thehunt_status:notify", src, "Создание", "Этот предмет можно сковать только на наковальне", "error")
        return
    end

    WithCraftingInventory(steamId, charId, function(inventory)
        local rows = inventory.all
        local mainRows = inventory.main
        local inventoryCounts = BuildInventoryCounts(rows)

        -- 1. Проверка рецепта
        if recipe.requiredRecipeItem and (inventoryCounts[recipe.requiredRecipeItem] or 0) < 1 then
            TriggerClientEvent("thehunt_status:notify", src, "Создание", "У вас нет необходимого рецепта", "error")
            return
        end

        -- 2. Проверка ингредиентов
        for _, ing in ipairs(recipe.ingredients or {}) do
            local needed = (ing.count or 1) * craftAmount
            local have = inventoryCounts[ing.item] or 0
            if have < needed then
                TriggerClientEvent("thehunt_status:notify", src, "Создание", "Недостаточно ингредиентов для завершения создания", "error")
                return
            end
        end

        local resultDef = GetItemDefinition(recipe.resultItem)
        if not resultDef then
            TriggerClientEvent("thehunt_status:notify", src, "Создание", "Ошибка данных создаваемого предмета", "error")
            return
        end

        -- 3. Списание ингредиентов
        for _, ing in ipairs(recipe.ingredients or {}) do
            local needed = (ing.count or 1) * craftAmount
            for _, r in ipairs(rows) do
                if r.item_name == ing.item and needed > 0 then
                    local curCount = tonumber(r.count) or 1
                    if curCount <= needed then
                        needed = needed - curCount
                        r.count = 0
                        MySQL.query("DELETE FROM thehunt_inventories WHERE id = ?", { r.id })
                    else
                        r.count = curCount - needed
                        needed = 0
                        MySQL.update("UPDATE thehunt_inventories SET count = ? WHERE id = ?", { r.count, r.id })
                    end
                end
            end
        end

        -- 4. Выдача созданного предмета
        local totalResultCount = (recipe.resultCount or 1) * craftAmount
        local maxStack = resultDef.maxStack or 1
        local remainingToAdd = totalResultCount

        -- Добавляем в существующие стаки
        for _, r in ipairs(rows) do
            if r.item_name == recipe.resultItem and (tonumber(r.count) or 0) > 0 then
                local curCount = tonumber(r.count) or 1
                local canAdd = maxStack - curCount
                if canAdd > 0 then
                    local addNow = math.min(remainingToAdd, canAdd)
                    r.count = curCount + addNow
                    remainingToAdd = remainingToAdd - addNow
                    MySQL.update("UPDATE thehunt_inventories SET count = ? WHERE id = ?", { r.count, r.id })
                    if remainingToAdd <= 0 then break end
                end
            end
        end

        -- Добавляем в новые ячейки если еще осталось, либо выбрасываем на землю
        local function InsertNewStacks()
            if remainingToAdd <= 0 then
                TriggerClientEvent("thehunt_items:refreshInventory", src)
                TriggerClientEvent("thehunt_status:notify", src, "Создание", string.format("Вы успешно создали «%s» (x%d)", resultDef.label or recipe.label, totalResultCount), "success")
                TriggerEvent("thehunt_crafting:requestDataAfterCraft", src, station)
                return
            end

            MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
                steamId, charId
            }, function(freshRows)
                freshRows = freshRows or {}
                local stackSize = math.min(remainingToAdd, maxStack)
                local freeX, freeY, isRot = FindFreeSlot(freshRows, 7, 5, resultDef.width or 1, resultDef.height or 1)

                if freeX ~= nil and freeY ~= nil then
                    MySQL.insert("INSERT INTO thehunt_inventories (identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count) VALUES (?, ?, 'main', ?, ?, ?, ?, ?)", {
                        steamId, charId, freeX, freeY, isRot and 1 or 0, recipe.resultItem, stackSize
                    }, function()
                        remainingToAdd = remainingToAdd - stackSize
                        InsertNewStacks()
                    end)
                else
                    -- Если нет свободного места в сетке инвентаря, создаем дроп через централизованный thehunt_items
                    local ped = GetPlayerPed(src)
                    local pCoords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped) or 0.0
                    local rad = math.rad(heading)
                    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
                    local dropPos = pCoords + (forward * 0.45) - vector3(0.0, 0.0, 0.85)

                    if exports.thehunt_items and exports.thehunt_items.CreateWorldDrop then
                        exports.thehunt_items:CreateWorldDrop(recipe.resultItem, stackSize, dropPos, {}, steamId, function()
                            remainingToAdd = remainingToAdd - stackSize
                            TriggerClientEvent("thehunt_status:notify", src, "Создание", string.format("«%s» упал на землю, так как в инвентаре нет места", resultDef.label or recipe.label), "warning")
                            InsertNewStacks()
                        end)
                    else
                        TriggerEvent("thehunt_items:createWorldDrop", recipe.resultItem, stackSize, dropPos, {}, steamId)
                        remainingToAdd = remainingToAdd - stackSize
                        TriggerClientEvent("thehunt_status:notify", src, "Создание", string.format("«%s» упал на землю, так как в инвентаре нет места", resultDef.label or recipe.label), "warning")
                        InsertNewStacks()
                    end
                end
            end)
        end

        InsertNewStacks()
    end)
end)
end

-- Обновление данных после успешного создания
if false then
AddEventHandler("thehunt_crafting:requestDataAfterCraft_legacy", function(src, station)
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    MySQL.query("SELECT * FROM thehunt_inventories WHERE identifier = ? AND charidentifier = ? AND container = 'main'", {
        steamId, charId
    }, function(rows)
        rows = rows or {}
        local inventoryCounts = {}
        for _, r in ipairs(rows) do
            local name = r.item_name
            local count = tonumber(r.count) or 1
            inventoryCounts[name] = (inventoryCounts[name] or 0) + count
        end
        TriggerClientEvent("thehunt_crafting:updateInventoryCounts", src, inventoryCounts)
    end)
end)
end

-- Актуальный обработчик завершения крафта. Результат сначала заполняет
-- основной инвентарь, затем свободное место в контейнерах одежды.
RegisterNetEvent("thehunt_crafting:finishCraft", function(recipeId, amount, station)
    local src = source
    local steamId, charId = GetPlayerIdentifiersVORP(src)
    local recipe = Crafting.GetRecipe(recipeId)
    local craftAmount = math.max(1, tonumber(amount) or 1)

    if not recipe then
        NotifyCrafting(src, "Рецепт не найден", "error")
        return
    end

    if not IsRecipeAllowedAtStation(recipe, station) then
        local requiredWhere = GetStationDisplayName(recipe.station)
        NotifyCrafting(src, string.format("Этот предмет можно создать только %s", requiredWhere), "error")
        return
    end

    WithCraftingInventory(steamId, charId, function(inventory)
        local inventoryCounts = BuildInventoryCounts(inventory.all)

        if recipe.requiredRecipeItem and (inventoryCounts[recipe.requiredRecipeItem] or 0) < 1 then
            NotifyCrafting(src, "У вас нет необходимого рецепта", "error")
            return
        end

        -- Проверка требуемого инструмента (не расходуется при крафте)
        if recipe.requiredTool and (inventoryCounts[recipe.requiredTool] or 0) < 1 then
            local toolDef = GetItemDefinition(recipe.requiredTool)
            local toolName = (toolDef and toolDef.label) or recipe.requiredTool
            NotifyCrafting(src, string.format("Требуется инструмент: %s", toolName), "error")
            return
        end

        for _, ingredient in ipairs(recipe.ingredients or {}) do
            local needed = (ingredient.count or 1) * craftAmount
            if (inventoryCounts[ingredient.item] or 0) < needed then
                NotifyCrafting(src, "Недостаточно ингредиентов для завершения создания", "error")
                return
            end
        end

        local resultDef = GetItemDefinition(recipe.resultItem)
        if not resultDef then
            NotifyCrafting(src, "Ошибка данных создаваемого предмета", "error")
            return
        end

        local totalResultCount = (recipe.resultCount or 1) * craftAmount
        local maxStack = math.max(1, tonumber(resultDef.maxStack) or 1)
        local remainingToAdd = totalResultCount

        local function ConsumeIngredient(itemName, amountToConsume)
            local remaining = amountToConsume

            -- Ингредиенты забираются из main, затем из контейнеров одежды.
            for _, row in ipairs(inventory.all) do
                if row.item_name == itemName and remaining > 0 then
                    local current = tonumber(row.count) or 0
                    if current > 0 then
                        local take = math.min(current, remaining)
                        local newCount = current - take
                        local changed

                        if newCount > 0 then
                            changed = MySQL.update.await(
                                "UPDATE thehunt_inventories SET count = ? WHERE id = ? AND identifier = ? AND charidentifier = ?",
                                { newCount, row.id, steamId, charId }
                            )
                        else
                            changed = MySQL.update.await(
                                "DELETE FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ?",
                                { row.id, steamId, charId }
                            )
                        end

                        if changed and changed > 0 then
                            row.count = newCount
                            remaining = remaining - take
                        end
                    end
                end
            end

            return remaining <= 0
        end

        for _, ingredient in ipairs(recipe.ingredients or {}) do
            local needed = (ingredient.count or 1) * craftAmount
            if not ConsumeIngredient(ingredient.item, needed) then
                NotifyCrafting(src, "Не удалось списать ингредиенты, попробуйте ещё раз", "error")
                return
            end
        end

        local function AddToExistingStacks(rows)
            for _, row in ipairs(rows or {}) do
                if remainingToAdd <= 0 then
                    return
                end

                if row.item_name == recipe.resultItem then
                    local current = tonumber(row.count) or 0
                    local freeInStack = maxStack - current
                    if current > 0 and freeInStack > 0 then
                        local addNow = math.min(remainingToAdd, freeInStack)
                        local newCount = current + addNow
                        local changed = MySQL.update.await(
                            "UPDATE thehunt_inventories SET count = ? WHERE id = ? AND identifier = ? AND charidentifier = ?",
                            { newCount, row.id, steamId, charId }
                        )

                        if changed and changed > 0 then
                            row.count = newCount
                            remainingToAdd = remainingToAdd - addNow
                        end
                    end
                end
            end
        end

        local function AddNewStack(containerName, rows, cols, rowCount, rowWidths)
            if remainingToAdd <= 0 then
                return true
            end

            local itemW = math.max(1, tonumber(resultDef.width) or 1)
            local itemH = math.max(1, tonumber(resultDef.height) or 1)
            local freeX, freeY, isRotated = FindFreeSlot(
                rows,
                cols,
                rowCount,
                itemW,
                itemH,
                rowWidths
            )

            if freeX == nil or freeY == nil then
                return false
            end

            local stackSize = math.min(remainingToAdd, maxStack)
            local insertId = MySQL.insert.await(
                "INSERT INTO thehunt_inventories " ..
                "(identifier, charidentifier, container, slot_x, slot_y, is_rotated, item_name, count) " ..
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                {
                    steamId,
                    charId,
                    containerName,
                    freeX,
                    freeY,
                    isRotated and 1 or 0,
                    recipe.resultItem,
                    stackSize
                }
            )

            if not insertId then
                return false
            end

            local newRow = {
                id = insertId,
                identifier = steamId,
                charidentifier = charId,
                container = containerName,
                slot_x = freeX,
                slot_y = freeY,
                is_rotated = isRotated and 1 or 0,
                item_name = recipe.resultItem,
                count = stackSize
            }

            rows[#rows + 1] = newRow
            inventory.all[#inventory.all + 1] = newRow
            remainingToAdd = remainingToAdd - stackSize
            return true
        end

        -- Сначала полностью обслуживаем основной инвентарь.
        AddToExistingStacks(inventory.main)

        local mainCols = (Items.GetGridCols and Items.GetGridCols("main")) or 7
        local mainRowCount = (Items.GetGridRows and Items.GetGridRows("main")) or 4
        while remainingToAdd > 0 do
            if not AddNewStack("main", inventory.main, mainCols, mainRowCount) then
                break
            end
        end

        -- Только когда в main не осталось места, используем одежду.
        if remainingToAdd > 0 then
            for _, container in ipairs(inventory.clothing) do
                AddToExistingStacks(container.rows)

                while remainingToAdd > 0 do
                    local storage = container.storage or {}
                    local inserted = AddNewStack(
                        container.container,
                        container.rows,
                        tonumber(storage.cols) or 1,
                        tonumber(storage.rows) or 1,
                        storage.rowWidths
                    )
                    if not inserted then
                        break
                    end
                end

                if remainingToAdd <= 0 then
                    break
                end
            end
        end

        -- Carried portable containers are also valid destinations.  This is
        -- what keeps a backpack in main useful for capacity calculations:
        -- crafting can stack into or occupy its free cells without opening
        -- the backpack UI.
        if remainingToAdd > 0 and not IsContainerDefinition(resultDef) then
            for _, container in ipairs(inventory.containers or {}) do
                AddToExistingStacks(container.rows)
                while remainingToAdd > 0 do
                    local inserted = AddNewStack(
                        container.container,
                        container.rows,
                        container.cols or 1,
                        container.gridRows or 1
                    )
                    if not inserted then break end
                end
                if remainingToAdd <= 0 then break end
            end
        end

        local function CompleteCraft()
            TriggerClientEvent("thehunt_items:refreshInventory", src)
            NotifyCrafting(
                src,
                string.format(
                    "Вы успешно создали «%s» (x%d)",
                    resultDef.label or recipe.label or recipe.resultItem,
                    totalResultCount
                ),
                "success"
            )
            TriggerEvent("thehunt_crafting:requestDataAfterCraft", src, station)
        end

        if remainingToAdd <= 0 then
            CompleteCraft()
            return
        end

        -- Если все сетки заполнены, оставшийся результат падает на землю.
        local ped = GetPlayerPed(src)
        local pCoords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped) or 0.0
        local radians = math.rad(heading)
        local forward = vector3(-math.sin(radians), math.cos(radians), 0.0)
        local dropPos = pCoords + (forward * 0.45) - vector3(0.0, 0.0, 0.85)
        local warnedAboutDrop = false

        local function NotifyDrop()
            if not warnedAboutDrop then
                warnedAboutDrop = true
                NotifyCrafting(
                    src,
                    string.format(
                        "«%s» упал на землю: в инвентарях не хватило места",
                        resultDef.label or recipe.label or recipe.resultItem
                    ),
                    "warning"
                )
            end
        end

        local function DropRemaining()
            if remainingToAdd <= 0 then
                CompleteCraft()
                return
            end

            local stackSize = math.min(remainingToAdd, maxStack)
            if exports.thehunt_items and exports.thehunt_items.CreateWorldDrop then
                exports.thehunt_items:CreateWorldDrop(
                    recipe.resultItem,
                    stackSize,
                    dropPos,
                    {},
                    steamId,
                    function()
                        remainingToAdd = remainingToAdd - stackSize
                        NotifyDrop()
                        DropRemaining()
                    end
                )
            else
                TriggerEvent(
                    "thehunt_items:createWorldDrop",
                    recipe.resultItem,
                    stackSize,
                    dropPos,
                    {},
                    steamId
                )
                remainingToAdd = remainingToAdd - stackSize
                NotifyDrop()
                DropRemaining()
            end
        end

        DropRemaining()
    end)
end)

-- Обновление счётчиков после крафта с учётом одежды.
AddEventHandler("thehunt_crafting:requestDataAfterCraft", function(src, station)
    local steamId, charId = GetPlayerIdentifiersVORP(src)

    WithCraftingInventory(steamId, charId, function(inventory)
        TriggerClientEvent(
            "thehunt_crafting:updateInventoryCounts",
            src,
            BuildInventoryCounts(inventory.all)
        )
    end)
end)
