-- =================================================================
-- HUNT: Hard RP — The Corruption | Main Server Controller & Admin Events
-- =================================================================

local pendingSaves = {}
local function IsPlayerAdmin(source)
    if source == 0 then return true end

    -- 1. Централизованная проверка через thehunt_core
    if exports.thehunt_core and exports.thehunt_core.IsPlayerAdmin then
        return exports.thehunt_core:IsPlayerAdmin(source)
    end

    -- 2. Резервная проверка FiveM/RedM/txAdmin ACE-прав
    if IsPlayerAceAllowed(source, "group.admin") or IsPlayerAceAllowed(source, "command") 
    or IsPlayerAceAllowed(source, "admin") or IsPlayerAceAllowed(source, "txadmin") then
        return true
    end

    return false
end

-- =================================================================
-- 1. СТАРТ РЕСУРСА И ИНИЦИАЛИЗАЦИЯ
-- =================================================================

AddEventHandler("onResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Citizen.Wait(400)

    LootDB.Init(function()
        Zones.Init(function()
            LootSpawner.Init()
        end)
    end)
end)

-- =================================================================
-- 2. СИНХРОНИЗАЦИЯ ДАННЫХ ДЛЯ ОБЫЧНЫХ ИГРОКОВ
-- =================================================================

RegisterNetEvent("thehunt_loot:requestInitialData", function()
    local src = source
    local slots = LootSpawner.GetActiveSlots()
    TriggerClientEvent("thehunt_loot:receiveActiveSlots", src, slots)
end)

-- =================================================================
-- 3. АДМИНИСТРАТИВНЫЕ СОБЫТИЯ РЕДАКТОРА ЗОН
-- =================================================================

-- Проверка прав и открытие редактора
RegisterNetEvent("thehunt_loot:checkPermissionAndOpenEditor", function()
    local src = source
    if not IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_status:notify", src, "Доступ ограничен", "У вас нет прав администратора для редактирования лута", "error")
        return
    end

    local allZones = Zones.GetAll()
    local catalog = {}

    -- Загружаем каталог доступных предметов из thehunt_items
    if exports.thehunt_items and exports.thehunt_items.GetAllItems then
        catalog = exports.thehunt_items:GetAllItems()
    end

    TriggerClientEvent("thehunt_loot:openEditorClient", src, allZones, catalog)
end)

-- Сохранение зоны (создание или обновление)
RegisterNetEvent("thehunt_loot:saveZone", function(zoneData)
    local src = source
    if not IsPlayerAdmin(src) then return end
    if type(zoneData) ~= 'table' or pendingSaves[src] then return end
    pendingSaves[src] = true
    Zones.Save(zoneData, src, function(savedId, savedZone)
        pendingSaves[src] = nil
        if savedId then
            TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", string.format("Зона «%s» [#%d] сохранена", savedZone.name, savedId), "success")
            TriggerClientEvent("thehunt_loot:onZoneSaved", src, savedZone)
        else
            TriggerClientEvent("thehunt_loot:saveFailed", src)
            TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", "Зона не сохранена: проверьте параметры или повторите после завершения операции", "error")
        end
    end)
end)

-- Удаление зоны
RegisterNetEvent("thehunt_loot:deleteZone", function(zoneId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local zId = tonumber(zoneId)
    if not zId then return end

    Zones.Delete(zId, src, function(success)
        if success then
            TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", string.format("Зона [#%d] успешно удалена", zId), "info")
            TriggerClientEvent("thehunt_loot:onZoneDeletedClient", src, zId)
        else
            TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", "Не удалось удалить зону: операция ещё выполняется или база недоступна", "error")
        end
    end)
end)

-- Дублирование зоны
RegisterNetEvent("thehunt_loot:duplicateZone", function(zoneId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local zId = tonumber(zoneId)
    if not zId then return end

    Zones.Duplicate(zId, src, function(newId, savedZone)
        if newId then
            TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", string.format("Создана копия зоны [#%d]", newId), "success")
            TriggerClientEvent("thehunt_loot:onZoneSaved", src, savedZone)
        end
    end)
end)

-- Переключение активности зоны (Вкл / Выкл)
RegisterNetEvent("thehunt_loot:toggleZone", function(zoneId, enabled)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local zId = tonumber(zoneId)
    if not zId then return end

    Zones.Toggle(zId, enabled, src, function(success)
        TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", success and "Состояние зоны сохранено" or "Не удалось изменить зону", success and "success" or "error")
    end)
end)

-- Принудительный респавн лута в зоне
RegisterNetEvent("thehunt_loot:forceRespawn", function(zoneId)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local zId = tonumber(zoneId)
    if not zId then return end

    local accepted = LootSpawner.ForceRespawnZone(zId)
    TriggerClientEvent("thehunt_status:notify", src, "Редактор зон", accepted and "Запущена генерация лута" or "Зона выключена или занята операцией", accepted and "info" or "warning")
end)

-- Тестовая генерация лута для локального предпросмотра админом
RegisterNetEvent("thehunt_loot:testGenerateLoot", function(zoneData)
    local src = source
    if not IsPlayerAdmin(src) then return end
    local validated, reason = LootValidation.Zone(zoneData)
    if not validated then
        TriggerClientEvent("thehunt_status:notify", src, "Тест лута", reason, "error")
        return
    end
    zoneData = validated
    if not zoneData or not zoneData.selected_items or #zoneData.selected_items == 0 then
        TriggerClientEvent("thehunt_status:notify", src, "Тест лута", "В зоне нет выбранных предметов для генерации", "warning")
        return
    end

    local testSlots = {}
    local pool = {}
    for _, item in ipairs(zoneData.selected_items) do pool[#pool + 1] = item end
    local count = math.random(zoneData.min_items or 2, zoneData.max_active_items or 5)
    zoneData.id = 0
    local existingCoords = {}

    for i = 1, count do
        local pt = LootSpawner.GenerateValidSlotPoint(zoneData, existingCoords)
        if pt then
            local selected = LootMath.SelectWeightedItem(pool)
            if selected and zoneData.custom_rules.unique_items then
                for index, item in ipairs(pool) do
                    if item.item_name == selected.item_name then table.remove(pool, index); break end
                end
            end
            if selected then
                local itemDef = exports.thehunt_items and exports.thehunt_items.GetItemData and exports.thehunt_items:GetItemData(selected.item_name)
                table.insert(testSlots, {
                    id = -i,
                    item_name = selected.item_name,
                    label = (itemDef and itemDef.label) or selected.item_name,
                    count = selected.count,
                    x = pt.x,
                    y = pt.y,
                    z = pt.z,
                    heading = math.random(0, 360) + 0.0,
                    model_name = zoneData.model_name or (itemDef and (itemDef.dropModel or itemDef.propModel)) or Config.DefaultLootPropModel
                })
                table.insert(existingCoords, pt)
            end
        end
    end

    TriggerClientEvent("thehunt_loot:receiveTestPreviewLoot", src, testSlots)
    TriggerClientEvent("thehunt_status:notify", src, "Тест лута", string.format("Сгенерировано %d тестовых предметов", #testSlots), "info")
end)

-- Команда для чистого сброса базы данных лута (Консоль сервера или админ)
RegisterCommand("loot_reset_db", function(source, args)
    if source ~= 0 and not IsPlayerAdmin(source) then return end

    print("^3[HUNT LOOT] Выполняется чистый сброс таблиц базы данных лута...^7")
    LootDB.ResetDatabase(function()
        Zones.Init(function() LootSpawner.Init() end)
        print("^2[HUNT LOOT] Таблицы базы данных успешно пересозданы с чистой схемой!^7")
        if source ~= 0 then
            TriggerClientEvent("thehunt_status:notify", source, "База данных", "Таблицы лута успешно пересозданы с чистой схемой", "success")
        end
    end)
end, true)

-- Команда для принудительного удаления зоны по ID
RegisterCommand("loot_delete", function(source, args)
    if source ~= 0 and not IsPlayerAdmin(source) then return end
    local zId = tonumber(args[1])
    if not zId then
        print("^1[HUNT LOOT] Использование: loot_delete [id_зоны]^7")
        if source ~= 0 then
            TriggerClientEvent("thehunt_status:notify", source, "Редактор зон", "Использование: /loot_delete [id_зоны]", "error")
        end
        return
    end

    Zones.Delete(zId, source, function(success)
        if success then
            print(string.format("^2[HUNT LOOT] Зона [#%d] успешно удалена через команду.^7", zId))
            if source ~= 0 then
                TriggerClientEvent("thehunt_status:notify", source, "Редактор зон", string.format("Зона [#%d] успешно удалена", zId), "success")
                TriggerClientEvent("thehunt_loot:onZoneDeletedClient", source, zId)
            end
        else
            print(string.format("^1[HUNT LOOT] Не удалось удалить зону [#%d].^7", zId))
        end
    end)
end, false)

-- Команда для принудительного респавна всех или конкретной зоны
RegisterCommand("loot_respawn", function(source, args)
    if source ~= 0 and not IsPlayerAdmin(source) then return end
    local zId = tonumber(args[1])
    if zId then
        LootSpawner.ForceRespawnZone(zId)
        print(string.format("^2[HUNT LOOT] Зона [#%d] принудительно переспавнена.^7", zId))
        if source ~= 0 then
            TriggerClientEvent("thehunt_status:notify", source, "Респавн лута", string.format("Зона [#%d] переспавнена", zId), "success")
        end
    else
        local all = Zones.GetAll()
        local count = 0
        for id, _ in pairs(all) do
            LootSpawner.ForceRespawnZone(id)
            count = count + 1
        end
        print(string.format("^2[HUNT LOOT] Принудительно переспавнено %d зон.^7", count))
        if source ~= 0 then
            TriggerClientEvent("thehunt_status:notify", source, "Респавн лута", string.format("Все зоны (%d) успешно переспавнены", count), "success")
        end
    end
end, false)

local statusRequests = {}
RegisterNetEvent('thehunt_loot:requestZoneStatus', function()
    local src = source
    local now = GetGameTimer()
    if statusRequests[src] and now - statusRequests[src] < 1500 then return end
    statusRequests[src] = now
    if not IsPlayerAdmin(src) then return end
    TriggerClientEvent('thehunt_loot:zoneStatus', src, Zones.GetRuntimeState())
end)
AddEventHandler('playerDropped', function() statusRequests[source] = nil; pendingSaves[source] = nil end)
