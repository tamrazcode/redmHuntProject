-- =================================================================
-- HUNT: Hard RP — The Corruption | World Loot Database & Migrations
-- =================================================================

LootDB = {}

local isDBReady = false

function LootDB.IsReady()
    return isDBReady
end

-- =================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ ТАБЛИЦ БАЗЫ ДАННЫХ
-- =================================================================

function LootDB.Init(callback)
    if not exports.oxmysql then
        print("^1[HUNT LOOT] Ошибка: oxmysql не найден!^7")
        return
    end

    -- Create missing tables without ever deleting existing server data.
    LootDB.CreateTables(callback)
end

function LootDB.CreateTables(callback)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `thehunt_loot_zones` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(128) NOT NULL DEFAULT 'Новая зона лута',
            `zone_type` VARCHAR(32) NOT NULL DEFAULT 'circle',
            `coords_x` DOUBLE NOT NULL DEFAULT 0.0,
            `coords_y` DOUBLE NOT NULL DEFAULT 0.0,
            `coords_z` DOUBLE NOT NULL DEFAULT 0.0,
            `size_x` DOUBLE NOT NULL DEFAULT 10.0,
            `size_y` DOUBLE NOT NULL DEFAULT 10.0,
            `size_z` DOUBLE NOT NULL DEFAULT 4.0,
            `radius` DOUBLE NOT NULL DEFAULT 10.0,
            `height` DOUBLE NOT NULL DEFAULT 4.0,
            `heading` DOUBLE NOT NULL DEFAULT 0.0,
            `points` LONGTEXT DEFAULT NULL,
            `model_name` VARCHAR(128) DEFAULT NULL,
            `model_hash` BIGINT DEFAULT NULL,
            `activation_radius` DOUBLE NOT NULL DEFAULT 90.0,
            `render_radius` DOUBLE NOT NULL DEFAULT 45.0,
            `max_active_items` INT NOT NULL DEFAULT 5,
            `min_items` INT NOT NULL DEFAULT 2,
            `min_distance` DOUBLE NOT NULL DEFAULT 2.0,
            `item_lifetime` INT NOT NULL DEFAULT 1800,
            `min_respawn_time` INT NOT NULL DEFAULT 300,
            `max_respawn_time` INT NOT NULL DEFAULT 900,
            `is_enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `custom_rules` LONGTEXT DEFAULT NULL,
            `created_by` VARCHAR(64) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_zone_coords` (`coords_x`, `coords_y`),
            INDEX `idx_zone_enabled` (`is_enabled`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `thehunt_loot_zone_items` (
                `zone_id` INT NOT NULL,
                `item_name` VARCHAR(64) NOT NULL,
                `weight` INT NOT NULL DEFAULT 100,
                `min_count` INT NOT NULL DEFAULT 1,
                `max_count` INT NOT NULL DEFAULT 1,
                `chance_override` DOUBLE DEFAULT NULL,
                `metadata` LONGTEXT DEFAULT NULL,
                INDEX `idx_zone_id` (`zone_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {}, function()
            MySQL.query([[
                CREATE TABLE IF NOT EXISTS `thehunt_loot_active_slots` (
                    `id` INT AUTO_INCREMENT PRIMARY KEY,
                    `zone_id` INT NOT NULL DEFAULT 0,
                    `item_name` VARCHAR(64) NOT NULL,
                    `count` INT NOT NULL DEFAULT 1,
                    `x` DOUBLE NOT NULL DEFAULT 0.0,
                    `y` DOUBLE NOT NULL DEFAULT 0.0,
                    `z` DOUBLE NOT NULL DEFAULT 0.0,
                    `heading` DOUBLE NOT NULL DEFAULT 0.0,
                    `model_name` VARCHAR(128) DEFAULT NULL,
                    `model_hash` BIGINT DEFAULT NULL,
                    `metadata` LONGTEXT DEFAULT NULL,
                    `spawned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    `expires_at` TIMESTAMP NULL DEFAULT NULL,
                    INDEX `idx_active_zone` (`zone_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]], {}, function()
                MySQL.query([[
                    CREATE TABLE IF NOT EXISTS `thehunt_loot_cooldowns` (
                        `zone_id` INT PRIMARY KEY,
                        `ready_at` BIGINT NOT NULL DEFAULT 0,
                        `last_spawned_at` BIGINT NOT NULL DEFAULT 0,
                        INDEX `idx_cooldown_zone` (`zone_id`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                ]], {}, function()
                    MySQL.query([[
                        CREATE TABLE IF NOT EXISTS `thehunt_loot_logs` (
                            `id` INT AUTO_INCREMENT PRIMARY KEY,
                            `log_type` VARCHAR(32) NOT NULL,
                            `player_identifier` VARCHAR(64) DEFAULT NULL,
                            `player_charid` INT DEFAULT NULL,
                            `zone_id` INT DEFAULT NULL,
                            `item_name` VARCHAR(64) DEFAULT NULL,
                            `count` INT DEFAULT 1,
                            `coords_x` DOUBLE DEFAULT NULL,
                            `coords_y` DOUBLE DEFAULT NULL,
                            `coords_z` DOUBLE DEFAULT NULL,
                            `details` TEXT DEFAULT NULL,
                            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            INDEX `idx_log_type` (`log_type`),
                            INDEX `idx_log_player` (`player_identifier`, `player_charid`)
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                    ]], {}, function()
                        isDBReady = true
                        print("^2[HUNT LOOT] База данных лута готова к работе.^7")
                        if callback then callback() end
                    end)
                end)
            end)
        end)
    end)
end

-- =================================================================
-- 2. ЗАГРУЗКА ВСЕХ ЗОН И ИХ ПРЕДМЕТОВ ИЗ БД
-- =================================================================

function LootDB.LoadAllZones(callback)
    MySQL.query("SELECT * FROM thehunt_loot_zones", {}, function(zoneRows)
        if not zoneRows then
            if callback then callback({}) end
            return
        end

        MySQL.query("SELECT * FROM thehunt_loot_zone_items", {}, function(itemRows)
            local itemsByZone = {}
            if itemRows and type(itemRows) == "table" then
                for _, r in ipairs(itemRows) do
                    if r and r.zone_id and r.item_name then
                        local zId = tonumber(r.zone_id)
                        if zId then
                            if not itemsByZone[zId] then itemsByZone[zId] = {} end
                            table.insert(itemsByZone[zId], {
                                item_name = r.item_name,
                                weight = tonumber(r.weight) or 100,
                                min_count = tonumber(r.min_count) or 1,
                                max_count = tonumber(r.max_count) or 1,
                                chance_override = r.chance_override and tonumber(r.chance_override) or nil,
                                metadata = (r.metadata and r.metadata ~= "") and json.decode(r.metadata) or nil
                            })
                        end
                    end
                end
            end

            local zones = {}
            for _, z in ipairs(zoneRows) do
                if z and z.id then
                    local zId = tonumber(z.id)
                    if zId then
                        local points = nil
                        if z.points and z.points ~= "" then
                            pcall(function() points = json.decode(z.points) end)
                        end
                        local customRules = nil
                        if z.custom_rules and z.custom_rules ~= "" then
                            pcall(function() customRules = json.decode(z.custom_rules) end)
                        end

                        zones[zId] = {
                            id = zId,
                            name = z.name or "Зона #" .. zId,
                            zone_type = z.zone_type or "circle",
                            coords = vector3(tonumber(z.coords_x) or 0.0, tonumber(z.coords_y) or 0.0, tonumber(z.coords_z) or 0.0),
                            size_x = tonumber(z.size_x) or 10.0,
                            size_y = tonumber(z.size_y) or 10.0,
                            size_z = tonumber(z.size_z) or 4.0,
                            radius = tonumber(z.radius) or 10.0,
                            height = tonumber(z.height) or 4.0,
                            heading = tonumber(z.heading) or 0.0,
                            points = points or {},
                            model_name = z.model_name,
                            model_hash = z.model_hash and tonumber(z.model_hash) or nil,
                            activation_radius = tonumber(z.activation_radius) or Config.DefaultActivationRadius,
                            render_radius = tonumber(z.render_radius) or Config.DefaultRenderRadius,
                            max_active_items = tonumber(z.max_active_items) or Config.DefaultMaxItems,
                            min_items = tonumber(z.min_items) or Config.DefaultMinItems,
                            min_distance = tonumber(z.min_distance) or Config.DefaultMinDistance,
                            item_lifetime = tonumber(z.item_lifetime) or Config.DefaultLifetime,
                            min_respawn_time = tonumber(z.min_respawn_time) or Config.DefaultMinRespawn,
                            max_respawn_time = tonumber(z.max_respawn_time) or Config.DefaultMaxRespawn,
                            is_enabled = (z.is_enabled == 1 or z.is_enabled == true),
                            custom_rules = customRules or {},
                            selected_items = itemsByZone[zId] or {}
                        }
                    end
                end
            end

            print(string.format("^2[HUNT LOOT] Загружено %d зон лута из базы данных.^7", #zoneRows))
            if callback then callback(zones) end
        end)
    end)
end

-- =================================================================
-- 3. СОХРАНЕНИЕ / ОБНОВЛЕНИЕ ЗОНЫ В БД
-- =================================================================

function LootDB.SaveZone(zoneData, adminIdentifier, callback)
    if not zoneData then return end

    local coords = zoneData.coords or vector3(0, 0, 0)
    local pointsJson = (zoneData.points and #zoneData.points > 0) and json.encode(zoneData.points) or nil
    local rulesJson = (zoneData.custom_rules and next(zoneData.custom_rules)) and json.encode(zoneData.custom_rules) or nil
    local isEnabled = (zoneData.is_enabled == true or zoneData.is_enabled == 1) and 1 or 0

    if zoneData.id and tonumber(zoneData.id) and tonumber(zoneData.id) > 0 then
        -- Обновление существующей зоны
        local zId = tonumber(zoneData.id)
        local query = [[
            UPDATE thehunt_loot_zones SET
                name = ?, zone_type = ?, coords_x = ?, coords_y = ?, coords_z = ?,
                size_x = ?, size_y = ?, size_z = ?, radius = ?, height = ?, heading = ?,
                points = ?, model_name = ?, model_hash = ?, activation_radius = ?,
                render_radius = ?, max_active_items = ?, min_items = ?, min_distance = ?,
                item_lifetime = ?, min_respawn_time = ?, max_respawn_time = ?,
                is_enabled = ?, custom_rules = ?
            WHERE id = ?
        ]]
        local params = {
            zoneData.name or "Зона #" .. zId,
            zoneData.zone_type or "circle",
            coords.x, coords.y, coords.z,
            tonumber(zoneData.size_x) or 10.0,
            tonumber(zoneData.size_y) or 10.0,
            tonumber(zoneData.size_z) or 4.0,
            tonumber(zoneData.radius) or 10.0,
            tonumber(zoneData.height) or 4.0,
            tonumber(zoneData.heading) or 0.0,
            pointsJson,
            zoneData.model_name or nil,
            zoneData.model_hash and tonumber(zoneData.model_hash) or nil,
            tonumber(zoneData.activation_radius) or Config.DefaultActivationRadius,
            tonumber(zoneData.render_radius) or Config.DefaultRenderRadius,
            tonumber(zoneData.max_active_items) or Config.DefaultMaxItems,
            tonumber(zoneData.min_items) or Config.DefaultMinItems,
            tonumber(zoneData.min_distance) or Config.DefaultMinDistance,
            tonumber(zoneData.item_lifetime) or Config.DefaultLifetime,
            tonumber(zoneData.min_respawn_time) or Config.DefaultMinRespawn,
            tonumber(zoneData.max_respawn_time) or Config.DefaultMaxRespawn,
            isEnabled,
            rulesJson,
            zId
        }
        local queries = LootDB.BuildZoneItemQueries(zId, zoneData.selected_items)
        table.insert(queries, 1, {query = query, values = params})
        MySQL.transaction(queries, function(success)
            if success then LootDB.LogAction("update_zone", adminIdentifier, nil, zId, nil, 0, coords.x, coords.y, coords.z, "Обновление зоны и пула") end
            if callback then callback(success and zId or nil) end
        end)
    else
        -- Создание новой зоны
        MySQL.insert([[
            INSERT INTO thehunt_loot_zones (
                name, zone_type, coords_x, coords_y, coords_z,
                size_x, size_y, size_z, radius, height, heading,
                points, model_name, model_hash, activation_radius,
                render_radius, max_active_items, min_items, min_distance,
                item_lifetime, min_respawn_time, max_respawn_time,
                is_enabled, custom_rules, created_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            zoneData.name or "Новая зона лута",
            zoneData.zone_type or "circle",
            coords.x, coords.y, coords.z,
            tonumber(zoneData.size_x) or 10.0,
            tonumber(zoneData.size_y) or 10.0,
            tonumber(zoneData.size_z) or 4.0,
            tonumber(zoneData.radius) or 10.0,
            tonumber(zoneData.height) or 4.0,
            tonumber(zoneData.heading) or 0.0,
            pointsJson,
            zoneData.model_name or nil,
            zoneData.model_hash and tonumber(zoneData.model_hash) or nil,
            tonumber(zoneData.activation_radius) or Config.DefaultActivationRadius,
            tonumber(zoneData.render_radius) or Config.DefaultRenderRadius,
            tonumber(zoneData.max_active_items) or Config.DefaultMaxItems,
            tonumber(zoneData.min_items) or Config.DefaultMinItems,
            tonumber(zoneData.min_distance) or Config.DefaultMinDistance,
            tonumber(zoneData.item_lifetime) or Config.DefaultLifetime,
            tonumber(zoneData.min_respawn_time) or Config.DefaultMinRespawn,
            tonumber(zoneData.max_respawn_time) or Config.DefaultMaxRespawn,
            isEnabled,
            rulesJson,
            adminIdentifier or "ADMIN"
        }, function(newId)
            local zId = tonumber(newId)
            if zId then
                LootDB.SaveZoneItems(zId, zoneData.selected_items, function(success)
                    if not success then
                        MySQL.update.await("DELETE FROM thehunt_loot_zones WHERE id = ?", {zId})
                        print(string.format("[HUNT LOOT] Failed zone creation rolled back: %d", zId))
                        if callback then callback(nil) end
                        return
                    end

                    LootDB.LogAction("create_zone", adminIdentifier, nil, zId, nil, 0, coords.x, coords.y, coords.z, "Создание новой зоны")
                    if callback then callback(zId) end
                end)
            else
                if callback then callback(nil) end
            end
        end)
    end
end

-- =================================================================
-- 4. СОХРАНЕНИЕ ВЫБРАННЫХ ПРЕДМЕТОВ ЗОНЫ В БД
-- =================================================================

function LootDB.SaveZoneItems(zoneId, itemsList, callback)
    local queries, count = LootDB.BuildZoneItemQueries(zoneId, itemsList)
    MySQL.transaction(queries, function(success)
        if callback then callback(success == true, count) end
    end)
end

function LootDB.BuildZoneItemQueries(zoneId, itemsList)
    local zId = tonumber(zoneId)
    if not zId then
        if callback then callback(false) end
        return
    end

    -- Не делаем DELETE отдельно от INSERT: при падении второго запроса старый
    -- пул должен остаться в базе. Это особенно важно при кратковременном
    -- обрыве соединения с MariaDB.
    local queries = {
        {
            query = "DELETE FROM thehunt_loot_zone_items WHERE zone_id = ?",
            values = { zId }
        }
    }

    local placeholders = {}
    local params = {}
    local savedCount = 0

    if itemsList and type(itemsList) == "table" then
        for _, it in ipairs(itemsList) do
            if it and type(it.item_name) == "string" and it.item_name ~= "" then
                local chance = tonumber(it.chance_override)
                local metaJson = nil

                if type(it.metadata) == "table" then
                    local encodedOk, encoded = pcall(json.encode, it.metadata)
                    if encodedOk then metaJson = encoded end
                elseif type(it.metadata) == "string" and it.metadata ~= "" then
                    metaJson = it.metadata
                end

                -- Нельзя класть nil в середину массива params: Lua схлопывает
                -- такой массив, и значения следующего предмета съезжают в
                -- chance_override/metadata предыдущего. NULL пишем в SQL,
                -- а в params добавляем только реальные значения.
                local chanceSql = chance and "?" or "NULL"
                local metadataSql = metaJson and "?" or "NULL"
                table.insert(placeholders, string.format("(?, ?, ?, ?, ?, %s, %s)", chanceSql, metadataSql))

                table.insert(params, zId)
                table.insert(params, it.item_name)
                table.insert(params, tonumber(it.weight) or 100)
                table.insert(params, tonumber(it.min_count) or 1)
                table.insert(params, tonumber(it.max_count) or 1)
                if chance then table.insert(params, chance) end
                if metaJson then table.insert(params, metaJson) end

                savedCount = savedCount + 1
            end
        end
    end

    if savedCount > 0 then
        table.insert(queries, {
            query = "INSERT INTO thehunt_loot_zone_items (zone_id, item_name, weight, min_count, max_count, chance_override, metadata) VALUES " .. table.concat(placeholders, ", "),
            values = params
        })
    end

    return queries, savedCount
end

-- =================================================================
-- 5. УДАЛЕНИЕ ЗОНЫ ИЗ БД
-- =================================================================

function LootDB.DeleteZone(zoneId, adminIdentifier, callback)
    local zId = tonumber(zoneId)
    if not zId then
        if callback then callback() end
        return
    end

    MySQL.transaction({
        { query = "DELETE FROM thehunt_loot_zone_items WHERE zone_id = ?", values = { zId } },
        { query = "DELETE FROM thehunt_loot_active_slots WHERE zone_id = ?", values = { zId } },
        { query = "DELETE FROM thehunt_loot_cooldowns WHERE zone_id = ?", values = { zId } },
        { query = "DELETE FROM thehunt_loot_zones WHERE id = ?", values = { zId } }
    }, function(success)
        if success then LootDB.LogAction("delete_zone", adminIdentifier, nil, zId, nil, 0, nil, nil, nil, "Удаление зоны") end
        if callback then callback(success == true) end
    end)
end

-- =================================================================
-- 6. ЛОГИРОВАНИЕ ДЕЙСТВИЙ (AUDIT LOGS)
-- =================================================================

function LootDB.LogAction(logType, identifier, charId, zoneId, itemName, count, x, y, z, details)
    MySQL.insert([[
        INSERT INTO thehunt_loot_logs (
            log_type, player_identifier, player_charid, zone_id, item_name, count,
            coords_x, coords_y, coords_z, details
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        logType or "info",
        identifier,
        charId,
        zoneId,
        itemName,
        count or 1,
        x, y, z,
        details
    })
end

-- =================================================================
-- 7. ПОЛНЫЙ СБРОС ТАБЛИЦ (RESET DATABASE)
-- =================================================================

function LootDB.ResetDatabase(callback)
    MySQL.query("DROP TABLE IF EXISTS `thehunt_loot_logs`, `thehunt_loot_cooldowns`, `thehunt_loot_active_slots`, `thehunt_loot_zone_items`, `thehunt_loot_zones`", {}, function()
        LootDB.CreateTables(callback)
    end)
end
