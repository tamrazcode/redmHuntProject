-- =================================================================
-- HUNT: Hard RP — Zombie Corpse Loot System (Server Authority)
-- =================================================================
ZS = ZS or {}
ZS.corpseLoot = {}

local C = ZombieConfig

function ZS.removeCorpseLoot(id)
    if not ZS.corpseLoot or not ZS.corpseLoot[id] then return false end
    ZS.corpseLoot[id] = nil
    TriggerClientEvent('thehunt_zombie:corpseLootRemoved', -1, id)
    return true
end

function ZS.cleanupCorpseLoot(now)
    now = now or GetGameTimer()
    local removed = 0
    for id, loot in pairs(ZS.corpseLoot or {}) do
        if type(loot) ~= 'table' then
            if ZS.removeCorpseLoot(id) then removed = removed + 1 end
        else
            local isSearching = loot.activeSearchers and next(loot.activeSearchers) ~= nil
            if isSearching then
                loot.expires = now + (ZombieConfig.CorpseLifetime or 90000)
            else
                local isEmpty = not loot.items or #loot.items == 0
                local isAllSearched = (loot.allSearched == true)
                local emptyExpired = isAllSearched and isEmpty and loot.emptiedAt and (now - tonumber(loot.emptiedAt) >= 30000)
                local expired = loot.expires and tonumber(loot.expires) <= now
                if emptyExpired or expired then
                    if ZS.removeCorpseLoot(id) then removed = removed + 1 end
                end
            end
        end
    end
    return removed
end

function ZS.clearCorpseLoot()
    local removed = 0
    for id in pairs(ZS.corpseLoot or {}) do
        if ZS.removeCorpseLoot(id) then removed = removed + 1 end
    end
    return removed
end

-- 2D Grid Collision Helper for 7x3 Zombie Inventory
local function packCorpseItems(pool, maxItems, cols, rows)
    cols = cols or 7
    rows = rows or 3
    local occupied = {}

    local function isFree(x, y, w, h)
        if x < 0 or y < 0 or (x + w) > cols or (y + h) > rows then return false end
        for r = 0, h - 1 do
            for c = 0, w - 1 do
                if occupied[(x + c) .. ',' .. (y + r)] then return false end
            end
        end
        return true
    end

    local function mark(x, y, w, h)
        for r = 0, h - 1 do
            for c = 0, w - 1 do
                occupied[(x + c) .. ',' .. (y + r)] = true
            end
        end
    end

    local function tryFit(w, h)
        if w > cols or h > rows then return nil, nil end
        for y = 0, rows - h do
            for x = 0, cols - w do
                if isFree(x, y, w, h) then
                    return x, y
                end
            end
        end
        return nil, nil
    end

    -- Поворот как при нажатии [R] в инвентаре:
    -- Ищет ячейку строго внутри границ [0, cols-1] x [0, rows-1]
    local function findSlotForItem(rawW, rawH)
        -- Для предметов, которые выше чем шире (rawH > rawW) или не влезают по высоте (rawH > rows),
        -- в приоритете пробуем повернуть на [R] горизонтально (w = rawH, h = rawW, rot = true)
        local preferRotated = (rawH > rawW and rawH > 1) or (rawH > rows)

        local orientations
        if preferRotated then
            orientations = {
                { w = rawH, h = rawW, rot = true },
                { w = rawW, h = rawH, rot = false }
            }
        else
            orientations = {
                { w = rawW, h = rawH, rot = false },
                { w = rawH, h = rawW, rot = true }
            }
        end

        for _, o in ipairs(orientations) do
            local px, py = tryFit(o.w, o.h)
            if px ~= nil and py ~= nil then
                return px, py, o.w, o.h, o.rot
            end
        end

        return nil, nil, nil, nil, false
    end

    local function getItemDef(name)
        local itemDef = nil
        if exports['thehunt_items'] and exports['thehunt_items'].GetItemData then
            itemDef = exports['thehunt_items']:GetItemData(name)
        end
        if not itemDef and Items and Items.Get then
            itemDef = Items.Get(name)
        end
        return itemDef
    end

    local totalWeight = 0
    local largePool = {}
    local largeWeight = 0

    for _, it in ipairs(pool) do
        local def = getItemDef(it.name)
        local rw = def and tonumber(def.width) or 1
        local rh = def and tonumber(def.height) or 1
        local fitsAtAll = (rw <= cols and rh <= rows) or (rh <= cols and rw <= rows)
        if fitsAtAll then
            local wgt = tonumber(it.weight) or 10
            totalWeight = totalWeight + wgt
            if (rw * rh >= 2) or rw >= 2 or rh >= 2 then
                largePool[#largePool + 1] = { item = it, def = def, rw = rw, rh = rh, weight = wgt }
                largeWeight = largeWeight + wgt
            end
        end
    end

    local candidates = {}
    local targetCount = math.min(maxItems or 3, 5)

    -- Если в пуле есть крупные предметы, даем 45% шанс гарантированно выбрать крупный предмет,
    -- чтобы не было постоянного засилья мелких 1x1 предметов
    if #largePool > 0 and math.random(1, 100) <= 45 then
        local rollL = math.random(1, math.max(1, largeWeight))
        local accL = 0
        local pickedL = largePool[1]
        for _, entry in ipairs(largePool) do
            accL = accL + entry.weight
            if rollL <= accL then
                pickedL = entry
                break
            end
        end
        candidates[#candidates + 1] = {
            chosen = pickedL.item,
            itemDef = pickedL.def,
            rawW = pickedL.rw,
            rawH = pickedL.rh,
            area = pickedL.rw * pickedL.rh
        }
    end

    -- Добираем оставшиеся предметы из общего пула
    local safetyAttempts = 0
    while #candidates < targetCount and safetyAttempts < 30 do
        safetyAttempts = safetyAttempts + 1
        local roll = math.random(1, math.max(1, totalWeight))
        local acc = 0
        local chosen = pool[1]
        for _, it in ipairs(pool) do
            acc = acc + (tonumber(it.weight) or 10)
            if roll <= acc then
                chosen = it
                break
            end
        end

        if chosen then
            local def = getItemDef(chosen.name)
            local rw = def and tonumber(def.width) or 1
            local rh = def and tonumber(def.height) or 1
            local fitsAtAll = (rw <= cols and rh <= rows) or (rh <= cols and rw <= rows)
            if fitsAtAll then
                candidates[#candidates + 1] = {
                    chosen = chosen,
                    itemDef = def,
                    rawW = rw,
                    rawH = rh,
                    area = rw * rh
                }
            end
        end
    end

    -- Сортируем кандидатов по площади: крупные предметы упаковываются ПЕРВЫМИ на пустую сетку,
    -- гарантируя свободное место для оружия/досок, а мелочь заполняет оставшиеся ячейки
    table.sort(candidates, function(a, b)
        return a.area > b.area
    end)

    local out = {}
    local slotCounter = 0

    for _, cand in ipairs(candidates) do
        local chosen = cand.chosen
        local itemDef = cand.itemDef
        local rawW = cand.rawW
        local rawH = cand.rawH

        local px, py, effW, effH, isRotated = findSlotForItem(rawW, rawH)
        if px ~= nil and py ~= nil then
            mark(px, py, effW, effH)
            slotCounter = slotCounter + 1
            local minC = tonumber(chosen.minCount) or 1
            local maxC = tonumber(chosen.maxCount) or minC
            local count = math.random(minC, math.max(minC, maxC))

            -- Сохраняем исходные rawW и rawH, флаг isRotated клиент использует точно так же,
            -- как при нажатии клавиши R (effW = isRotated ? height : width)
            out[#out + 1] = {
                slotId = slotCounter,
                name = chosen.name,
                label = chosen.label or (itemDef and itemDef.label) or chosen.name,
                count = count,
                x = px,
                y = py,
                width = rawW,
                height = rawH,
                isRotated = isRotated,
                category = itemDef and itemDef.category or "item",
                rarity = itemDef and itemDef.rarity or "white",
                weight = itemDef and itemDef.weight or 0.1,
                description = itemDef and itemDef.description or "",
                maxStack = itemDef and itemDef.maxStack or 1,
                isZombieLoot = true,
                isSearched = false
            }
        end
    end

    return out
end

function ZS.generateCorpseLoot(id, r)
    if not r then return end
    local z = r.zone and ZS.zones[r.zone] or nil

    local items = {}

    -- Chance roll. A corpse record is created even when this roll produces no
    -- items, so the corpse remains searchable and the client can show the G
    -- interaction instead of silently losing the target.
    local chance = tonumber(z and z.lootChance) or 40
    if z and z.lootEnabled ~= false and z.lootChanceMode == 'range' then
        local cMin = tonumber(z.lootChanceMin) or 20
        local cMax = tonumber(z.lootChanceMax) or 60
        chance = math.random(cMin, math.max(cMin, cMax))
    end

    local roll = math.random(1, 100)
    if z and z.lootEnabled ~= false and roll <= chance then
        local pool = (z.lootItems and #z.lootItems > 0) and z.lootItems or ZombieConfig.DefaultLootItems
        if pool and #pool > 0 then
            local maxItems = math.random(1, math.max(1, tonumber(z.lootMaxItems) or 3))
            items = packCorpseItems(pool, maxItems, 7, 3)
        end
    end

    local pos = r.position or (r.entity and DoesEntityExist(r.entity) and Zombie.coords(GetEntityCoords(r.entity))) or r.home
    if not pos then return end

    ZS.corpseLoot[id] = {
        id = id,
        zone = r.zone,
        pos = pos,
        cols = 7,
        rows = 3,
        items = items,
        diedAt = r.diedAt or GetGameTimer(),
        expires = (r.diedAt or GetGameTimer()) + (ZombieConfig.CorpseLifetime or 90000)
    }
    TriggerClientEvent('thehunt_zombie:corpseLootCreated', -1, ZS.corpseLoot[id])
end

-- Hook into death event
AddEventHandler('thehunt_zombie:died', function(id, net, zone)
    local r = ZS.peds[id]
    if r then
        ZS.generateCorpseLoot(id, r)
    end
end)

-- Initial sync requested by client
RegisterNetEvent('thehunt_zombie:requestCorpseLoot', function()
    local src = source
    ZS.cleanupCorpseLoot()
    TriggerClientEvent('thehunt_zombie:syncCorpseLoot', src, ZS.corpseLoot)
end)

-- Ensure corpse loot exists for a found corpse ped
RegisterNetEvent('thehunt_zombie:ensureCorpseLoot', function(id, pos, zone)
    local src = source
    if not id then return end
    if not ZS.corpseLoot[id] then
        local r = ZS.peds and ZS.peds[id]
        if not r then
            r = { id = id, zone = zone, position = pos, home = pos }
        end
        ZS.generateCorpseLoot(id, r)
    else
        TriggerClientEvent('thehunt_zombie:corpseLootCreated', src, ZS.corpseLoot[id])
    end
end)

-- Player takes an item from a zombie corpse
RegisterNetEvent('thehunt_zombie:takeCorpseItem', function(zombieId, slotId, targetContainer, targetX, targetY, isRotated)
    local src = source
    local loot = ZS.corpseLoot[zombieId]
    if not loot then return end

    local ped = GetPlayerPed(src)
    if not ped or not DoesEntityExist(ped) then return end

    local pCoords = GetEntityCoords(ped)
    if Zombie.distance(pCoords, loot.pos) > 6.0 then
        TriggerClientEvent('thehunt_status:notify', src, 'Труп зомби', 'Вы слишком далеко от тела', 'error')
        return
    end

    -- Find item in corpse
    local itemIndex, item = nil, nil
    for idx, it in ipairs(loot.items) do
        if it.slotId == tonumber(slotId) then
            itemIndex = idx
            item = it
            break
        end
    end

    if not item then
        TriggerClientEvent('thehunt_status:notify', src, 'Труп зомби', 'Предмет уже забран', 'warning')
        return
    end

    -- Atomically remove item from corpse
    table.remove(loot.items, itemIndex)
    TriggerClientEvent('thehunt_zombie:corpseLootItemRemoved', -1, zombieId, slotId)

    if #loot.items == 0 then
        loot.emptiedAt = GetGameTimer()
        -- Не удаляем лут сразу: труп лежит еще 25-30 секунд перед исчезновением
    end

    -- Helper to safely drop items into the world ("Рядом")
    local function dropToGround(count)
        if not count or count <= 0 then return end
        if exports['thehunt_items'] and exports['thehunt_items'].CreateWorldDrop then
            exports['thehunt_items']:CreateWorldDrop(item.name, count, pCoords, item.metadata or {}, 'corpse_' .. tostring(zombieId))
        elseif exports['thehunt_items'] and exports['thehunt_items'].CreateDrop then
            exports['thehunt_items']:CreateDrop(item.name, count, pCoords, item.metadata or {}, 'corpse_' .. tostring(zombieId))
        else
            TriggerEvent('thehunt_items:createDrop', item.name, count, item.metadata or {}, pCoords, 'corpse_' .. tostring(zombieId))
        end
    end

    -- Deliver item to player (preserving exact target container, slot coordinates, and rotation)
    if targetContainer == 'ground' then
        dropToGround(item.count)
    else
        if exports['thehunt_items'] and exports['thehunt_items'].AddItemToSlot then
            exports['thehunt_items']:AddItemToSlot(src, item.name, item.count, nil, targetContainer, targetX, targetY, isRotated, function(success, addedCount, remainder)
                if not success then
                    dropToGround(item.count)
                    TriggerClientEvent('thehunt_status:notify', src, 'Инвентарь', 'Инвентарь полон, предмет упал на землю', 'warning')
                elseif remainder and remainder > 0 then
                    -- Если в стак поместилась только часть, остаток выпадает в Рядом на землю
                    dropToGround(remainder)
                    TriggerClientEvent('thehunt_status:notify', src, 'Инвентарь', string.format('Остаток предметов (%d шт.) не поместился и упал на землю', remainder), 'warning')
                end
            end)
        elseif exports['thehunt_items'] and exports['thehunt_items'].AddItem then
            exports['thehunt_items']:AddItem(src, item.name, item.count, nil, function(success)
                if not success then
                    dropToGround(item.count)
                    TriggerClientEvent('thehunt_status:notify', src, 'Инвентарь', 'Инвентарь полон, предмет упал на землю', 'warning')
                end
            end)
        end
    end
end)

-- Клиент сообщил об истечении таймера трупа
RegisterNetEvent('thehunt_zombie:corpseExpired', function(id)
    if not id then return end
    ZS.removeCorpseLoot(id)
end)

-- Игрок начал или закончил обыск предметов в трупе
RegisterNetEvent('thehunt_zombie:setSearchingCorpse', function(id, isSearching)
    local src = source
    if not id then return end
    local loot = ZS.corpseLoot[id]
    if loot then
        loot.activeSearchers = loot.activeSearchers or {}
        if isSearching then
            loot.activeSearchers[src] = true
            loot.expires = GetGameTimer() + (ZombieConfig.CorpseLifetime or 90000)
        else
            loot.activeSearchers[src] = nil
        end
        local anySearching = (next(loot.activeSearchers) ~= nil)
        TriggerClientEvent('thehunt_zombie:setSearchingCorpse', -1, id, anySearching)
    end
end)

-- Синхронизированный обыск: предмет в трупе зомби успешно раскрыт/опознан
RegisterNetEvent('thehunt_zombie:itemSearched', function(zombieId, slotId)
    if not zombieId or not slotId then return end
    local loot = ZS.corpseLoot[zombieId]
    if not loot or not loot.items then return end

    local sId = tonumber(slotId)
    local allDone = true
    for _, it in ipairs(loot.items) do
        if it.slotId == sId then
            it.isSearched = true
        end
        if not it.isSearched then
            allDone = false
        end
    end

    -- Рассылаем всем игрокам обновление о раскрытии предмета
    TriggerClientEvent('thehunt_zombie:corpseItemSearched', -1, zombieId, sId)

    if allDone and #loot.items > 0 and not loot.allSearched then
        loot.allSearched = true
        TriggerClientEvent('thehunt_zombie:onCorpseAllSearched', -1, zombieId)
    end
end)

-- Все предметы в трупе зомби успешно распознаны
RegisterNetEvent('thehunt_zombie:onCorpseAllSearched', function(id)
    if not id then return end
    local loot = ZS.corpseLoot[id]
    if loot then
        loot.allSearched = true
        TriggerClientEvent('thehunt_zombie:onCorpseAllSearched', -1, id)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, loot in pairs(ZS.corpseLoot or {}) do
        if loot.activeSearchers and loot.activeSearchers[src] then
            loot.activeSearchers[src] = nil
            local anySearching = (next(loot.activeSearchers) ~= nil)
            TriggerClientEvent('thehunt_zombie:setSearchingCorpse', -1, id, anySearching)
        end
    end
end)

-- Exports
exports('GetCorpseLoot', function(id) return ZS.corpseLoot[id] end)
exports('GetAllCorpseLoot', function() return ZS.corpseLoot end)
