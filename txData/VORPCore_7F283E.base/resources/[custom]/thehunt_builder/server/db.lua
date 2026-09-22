-- =================================================================
-- HUNT: Hard RP — The Corruption | Builder Database Module (oxmysql)
-- =================================================================

DB = {}
local isDBReady = false

-- Инициализация структуры базы данных
function DB.Init(callback)
    if not exports.oxmysql then 
        if callback then callback() end
        return 
    end

    -- 1. Таблица кастомно установленных объектов
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS thehunt_placed_props (
            id INT AUTO_INCREMENT PRIMARY KEY,
            model_name VARCHAR(64) NOT NULL,
            model_hash BIGINT NOT NULL,
            item_name VARCHAR(64) DEFAULT NULL,
            metadata LONGTEXT DEFAULT NULL,
            x FLOAT NOT NULL,
            y FLOAT NOT NULL,
            z FLOAT NOT NULL,
            rot_x FLOAT DEFAULT 0.0,
            rot_y FLOAT DEFAULT 0.0,
            rot_z FLOAT DEFAULT 0.0,
            original_x FLOAT DEFAULT NULL,
            original_y FLOAT DEFAULT NULL,
            original_z FLOAT DEFAULT NULL,
            original_rx FLOAT DEFAULT NULL,
            original_ry FLOAT DEFAULT NULL,
            original_rz FLOAT DEFAULT NULL,
            owner_identifier VARCHAR(64) DEFAULT 'ADMIN',
            is_protected TINYINT DEFAULT 0,
            is_admin_prop TINYINT DEFAULT 1,
            move_token VARCHAR(64) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        exports.oxmysql:execute("ALTER TABLE thehunt_placed_props ADD COLUMN IF NOT EXISTS is_protected TINYINT DEFAULT 0;", {}, function()
            exports.oxmysql:execute("ALTER TABLE thehunt_placed_props ADD COLUMN IF NOT EXISTS move_token VARCHAR(64) DEFAULT NULL;", {}, function()
            -- 2. Таблица удаленных статических объектов мира
            exports.oxmysql:execute([[
                CREATE TABLE IF NOT EXISTS thehunt_deleted_props (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    model_hash BIGINT NOT NULL,
                    x FLOAT NOT NULL,
                    y FLOAT NOT NULL,
                    z FLOAT NOT NULL,
                    deleted_by VARCHAR(64) DEFAULT 'ADMIN',
                    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]], {}, function()
                isDBReady = true
                print("^2[HUNT BUILDER] База данных успешно инициализирована.^7")
                if callback then callback() end
            end)
            end)
        end)
    end)
end

-- Сохранение установленного объекта
function DB.SavePlacedProp(data, callback)
    if not exports.oxmysql then return end

    local query = [[
        INSERT INTO thehunt_placed_props 
        (model_name, model_hash, item_name, metadata, x, y, z, rot_x, rot_y, rot_z, original_x, original_y, original_z, original_rx, original_ry, original_rz, owner_identifier, is_protected, is_admin_prop) 
        VALUES (@name, @hash, @itemName, @meta, @x, @y, @z, @rx, @ry, @rz, @origX, @origY, @origZ, @origRx, @origRy, @origRz, @owner, @isProtected, @isAdmin)
    ]]
    exports.oxmysql:insert(query, {
        ['@name'] = data.model_name or 'unknown',
        ['@hash'] = data.model_hash,
        ['@itemName'] = data.item_name or nil,
        ['@meta'] = data.metadata and json.encode(data.metadata) or nil,
        ['@x'] = data.x,
        ['@y'] = data.y,
        ['@z'] = data.z,
        ['@rx'] = data.rot_x or 0.0,
        ['@ry'] = data.rot_y or 0.0,
        ['@rz'] = data.rot_z or 0.0,
        ['@origX'] = data.original_x or nil,
        ['@origY'] = data.original_y or nil,
        ['@origZ'] = data.original_z or nil,
        ['@origRx'] = data.original_rx or nil,
        ['@origRy'] = data.original_ry or nil,
        ['@origRz'] = data.original_rz or nil,
        ['@owner'] = data.owner or 'ADMIN',
        ['@isProtected'] = data.is_protected or 0,
        ['@isAdmin'] = data.is_admin_prop or 1
    }, function(insertId)
        if callback then callback(insertId) end
    end)
end

-- Обновление позиции установленного объекта (перемещение)
-- A moved map object has two linked facts: its replacement and a hidden
-- original. Commit them together so restarts cannot observe half a move.
function DB.MoveWorldProp(data, callback)
    if not exports.oxmysql then
        if callback then callback(nil) end
        return
    end

    local insertPlacedQuery = [[
        INSERT INTO thehunt_placed_props
        (model_name, model_hash, item_name, metadata, x, y, z, rot_x, rot_y, rot_z, original_x, original_y, original_z, original_rx, original_ry, original_rz, owner_identifier, is_protected, is_admin_prop, move_token)
        VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ADMIN', 0, 1, ?)
    ]]

    local hideOriginalQuery = [[
        INSERT INTO thehunt_deleted_props (model_hash, x, y, z, deleted_by)
        SELECT ?, ?, ?, ?, ?
        WHERE NOT EXISTS (
            SELECT 1 FROM thehunt_deleted_props
            WHERE model_hash = ?
              AND ABS(x - ?) < 0.35
              AND ABS(y - ?) < 0.35
              AND ABS(z - ?) < 0.35
        )
    ]]

    local queries = {
        {
            query = insertPlacedQuery,
            values = {
                data.model_name or 'Перемещенный объект', data.model_hash, data.metadata and json.encode(data.metadata) or nil,
                data.x, data.y, data.z, data.rot_x or 0.0, data.rot_y or 0.0, data.rot_z or 0.0,
                data.original_x, data.original_y, data.original_z,
                data.original_rx, data.original_ry, data.original_rz,
                data.move_token
            }
        },
        {
            query = hideOriginalQuery,
            values = {
                data.original_model_hash, data.original_x, data.original_y, data.original_z, data.deleted_by or 'ADMIN',
                data.original_model_hash, data.original_x, data.original_y, data.original_z
            }
        }
    }

    exports.oxmysql:transaction(queries, function(success)
        if not success then
            if callback then callback(nil) end
            return
        end

        -- oxmysql transactions return success/failure, not an insert id. This
        -- server-issued token identifies exactly the row that just committed.
        exports.oxmysql:execute(
            'SELECT id FROM thehunt_placed_props WHERE move_token = ? LIMIT 1',
            { data.move_token },
            function(rows)
                local row = rows and rows[1]
                local insertId = row and tonumber(row.id) or nil
                if not insertId then
                    if callback then callback(nil, nil) end
                    return
                end

                exports.oxmysql:execute([[
                    SELECT id FROM thehunt_deleted_props
                    WHERE model_hash = ?
                      AND ABS(x - ?) < 0.35
                      AND ABS(y - ?) < 0.35
                      AND ABS(z - ?) < 0.35
                    LIMIT 1
                ]], {
                    data.original_model_hash, data.original_x, data.original_y, data.original_z
                }, function(deletedRows)
                    local deletedRow = deletedRows and deletedRows[1]
                    if callback then callback(insertId, deletedRow and tonumber(deletedRow.id) or nil) end
                end)
            end
        )
    end)
end

function DB.UpdatePlacedProp(id, x, y, z, rx, ry, rz, callback)
    if not exports.oxmysql then return end
    local query = [[
        UPDATE thehunt_placed_props 
        SET x = @x, y = @y, z = @z, rot_x = @rx, rot_y = @ry, rot_z = @rz 
        WHERE id = @id
    ]]
    exports.oxmysql:execute(query, {
        ['@id'] = id,
        ['@x'] = x,
        ['@y'] = y,
        ['@z'] = z,
        ['@rx'] = rx or 0.0,
        ['@ry'] = ry or 0.0,
        ['@rz'] = rz or 0.0
    }, function(affectedRows)
        if callback then callback(affectedRows) end
    end)
end

-- Удаление кастомного объекта
function DB.UpdatePlacedPropMetadata(id, metadata, callback)
    if not exports.oxmysql then return end
    exports.oxmysql:execute(
        'UPDATE thehunt_placed_props SET metadata = ? WHERE id = ?',
        { metadata and json.encode(metadata) or nil, tonumber(id) },
        function(affectedRows)
            if callback then callback(affectedRows) end
        end
    )
end

function DB.DeletePlacedProp(id, callback)
    if not exports.oxmysql then return end
    exports.oxmysql:execute('DELETE FROM thehunt_placed_props WHERE id = ?', { id }, function(res)
        if callback then callback(res) end
    end)
end

-- Обновление статуса защиты предмета (запрет подбора)
function DB.UpdatePropProtection(id, isProtected, callback)
    if not exports.oxmysql then return end
    local query = [[
        UPDATE thehunt_placed_props 
        SET is_protected = @isProtected
        WHERE id = @id
    ]]
    exports.oxmysql:execute(query, {
        ['@isProtected'] = isProtected or 0,
        ['@id'] = tonumber(id)
    }, function(affectedRows)
        if callback then callback(affectedRows) end
    end)
end

-- Восстановление исходного статического объекта мира
function DB.RestoreWorldProp(modelHash, origX, origY, origZ, callback)
    if not exports.oxmysql or not modelHash then return end
    local query = [[
        DELETE FROM thehunt_deleted_props 
        WHERE model_hash = @hash 
        AND ABS(x - @x) < 2.5 AND ABS(y - @y) < 2.5 AND ABS(z - @z) < 2.5
    ]]
    exports.oxmysql:execute(query, {
        ['@hash'] = modelHash,
        ['@x'] = origX,
        ['@y'] = origY,
        ['@z'] = origZ
    }, function(res)
        if callback then callback(res) end
    end)
end

-- Сохранение удаленного статического объекта мира (с проверкой на дубликаты)
function DB.SaveDeletedWorldProp(modelHash, x, y, z, deletedBy, callback)
    if not exports.oxmysql or not modelHash or modelHash == 0 then return end

    -- Проверяем, не был ли этот объект уже удален в радиусе 0.35м
    local checkQuery = [[
        SELECT id FROM thehunt_deleted_props 
        WHERE model_hash = @hash 
        AND ABS(x - @x) < 0.35 AND ABS(y - @y) < 0.35 AND ABS(z - @z) < 0.35 
        LIMIT 1
    ]]
    exports.oxmysql:execute(checkQuery, {
        ['@hash'] = modelHash,
        ['@x'] = x,
        ['@y'] = y,
        ['@z'] = z
    }, function(rows)
        if rows and #rows > 0 then
            -- Уже существует в БД — возвращаем существующий ID
            if callback then callback(rows[1].id) end
        else
            local insertQuery = [[
                INSERT INTO thehunt_deleted_props (model_hash, x, y, z, deleted_by) 
                VALUES (@hash, @x, @y, @z, @by)
            ]]
            exports.oxmysql:insert(insertQuery, {
                ['@hash'] = modelHash,
                ['@x'] = x,
                ['@y'] = y,
                ['@z'] = z,
                ['@by'] = deletedBy or 'ADMIN'
            }, function(insertId)
                if callback then callback(insertId) end
            end)
        end
    end)
end

-- Загрузка всех установленных кастомных объектов
function DB.GetAllPlacedProps(callback)
    if not exports.oxmysql then return end
    exports.oxmysql:execute('SELECT * FROM thehunt_placed_props', {}, function(rows)
        local formatted = {}
        if rows then
            for _, r in ipairs(rows) do
                table.insert(formatted, {
                    id = tonumber(r.id),
                    model_name = r.model_name or "prop",
                    model_hash = tonumber(r.model_hash),
                    item_name = r.item_name,
                    metadata = r.metadata,
                    x = tonumber(r.x) + 0.0,
                    y = tonumber(r.y) + 0.0,
                    z = tonumber(r.z) + 0.0,
                    rot_x = tonumber(r.rot_x or 0.0) + 0.0,
                    rot_y = tonumber(r.rot_y or 0.0) + 0.0,
                    rot_z = tonumber(r.rot_z or 0.0) + 0.0,
                    original_x = r.original_x and (tonumber(r.original_x) + 0.0) or nil,
                    original_y = r.original_y and (tonumber(r.original_y) + 0.0) or nil,
                    original_z = r.original_z and (tonumber(r.original_z) + 0.0) or nil,
                    original_rx = r.original_rx and (tonumber(r.original_rx) + 0.0) or nil,
                    original_ry = r.original_ry and (tonumber(r.original_ry) + 0.0) or nil,
                    original_rz = r.original_rz and (tonumber(r.original_rz) + 0.0) or nil,
                    owner = r.owner_identifier or 'ADMIN',
                    is_protected = tonumber(r.is_protected or 0),
                    is_admin_prop = tonumber(r.is_admin_prop or 1)
                })
            end
        end
        if callback then callback(formatted) end
    end)
end

-- Загрузка всех удаленных статических объектов мира
function DB.GetAllDeletedWorldProps(callback)
    if not exports.oxmysql then return end
    exports.oxmysql:execute('SELECT * FROM thehunt_deleted_props', {}, function(rows)
        local formatted = {}
        if rows then
            for _, r in ipairs(rows) do
                table.insert(formatted, {
                    id = tonumber(r.id),
                    model_hash = tonumber(r.model_hash),
                    x = tonumber(r.x) + 0.0,
                    y = tonumber(r.y) + 0.0,
                    z = tonumber(r.z) + 0.0,
                    deleted_by = r.deleted_by or 'ADMIN'
                })
            end
        end
        if callback then callback(formatted) end
    end)
end

-- Read-only source for a builder database backup.
function DB.GetBackupRows(callback)
    if not exports.oxmysql then
        if callback then callback(nil, nil) end
        return
    end

    exports.oxmysql:execute('SELECT * FROM thehunt_placed_props ORDER BY id ASC', {}, function(placedRows)
        if not placedRows then
            if callback then callback(nil, nil) end
            return
        end

        exports.oxmysql:execute('SELECT * FROM thehunt_deleted_props ORDER BY id ASC', {}, function(deletedRows)
            if callback then callback(placedRows, deletedRows or {}) end
        end)
    end)
end
