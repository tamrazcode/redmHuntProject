-- =================================================================
-- HUNT: Hard RP — Database Operations Layer
-- Fully Universal & Backward-Compatible with all VORP Schemas
-- =================================================================

Database = {}
Database.Columns = {}
Database.Ready = false

function Database.WaitUntilReady(timeoutMs)
    local deadline = GetGameTimer() + (tonumber(timeoutMs) or 15000)
    while not Database.Ready and GetGameTimer() < deadline do Wait(25) end
    return Database.Ready
end

function Database.RefreshColumns()
    local columns = MySQL.query.await([[
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters'
    ]]) or {}

    local existingCols = {}
    for _, col in ipairs(columns) do
        if col.COLUMN_NAME then
            existingCols[col.COLUMN_NAME:lower()] = true
        end
    end
    Database.Columns = existingCols
    return existingCols
end

--- Auto-initialize tables and schema on resource startup
function Database.Init()
    CreateThread(function()
        Database.Ready = false
        -- 1. Create permanent 5-digit character code reservation table
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `thehunt_character_codes` (
                `code` VARCHAR(5) NOT NULL PRIMARY KEY,
                `charidentifier` INT NOT NULL,
                `identifier` VARCHAR(64) NOT NULL,
                `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `is_active` TINYINT(1) NOT NULL DEFAULT 1,
                `deleted_at` TIMESTAMP NULL DEFAULT NULL,
                `deleted_by` VARCHAR(64) NULL DEFAULT NULL,
                `delete_reason` VARCHAR(255) NULL DEFAULT NULL,
                INDEX `idx_char_id` (`charidentifier`),
                INDEX `idx_identifier` (`identifier`),
                INDEX `idx_active` (`is_active`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])

        -- Exact native values cannot be faithfully represented by older VORP
        -- health columns (which mix outer bar and core values).  Keep a small,
        -- per-character snapshot alongside them without changing old rows.
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `thehunt_character_world_state` (
                `charidentifier` INT NOT NULL PRIMARY KEY,
                `health` SMALLINT UNSIGNED NOT NULL,
                `health_core` TINYINT UNSIGNED NOT NULL,
                `stamina` SMALLINT UNSIGNED NOT NULL,
                `stamina_core` TINYINT UNSIGNED NOT NULL,
                `sprint_stamina` TINYINT UNSIGNED NOT NULL DEFAULT 100,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                CONSTRAINT `fk_thehunt_character_world_state_character`
                    FOREIGN KEY (`charidentifier`) REFERENCES `characters` (`charidentifier`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])
        -- Existing installations may already have the snapshot table from an
        -- earlier resource version. Add the independent HUNT sprint meter
        -- without rewriting a single existing character row.
        local hasSprintStamina = MySQL.scalar.await([[SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'thehunt_character_world_state'
                AND COLUMN_NAME = 'sprint_stamina']])
        if (tonumber(hasSprintStamina) or 0) == 0 then
            pcall(function()
                MySQL.query.await([[ALTER TABLE `thehunt_character_world_state`
                    ADD COLUMN `sprint_stamina` TINYINT UNSIGNED NOT NULL DEFAULT 100 AFTER `stamina_core`]])
            end)
        end

        -- 2. Check if required columns exist in characters table
        local existingCols = Database.RefreshColumns()

        if not existingCols["unique_code"] then
            pcall(function()
                MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `unique_code` VARCHAR(5) NULL UNIQUE AFTER `charidentifier`")
                print("^2[thehunt_character] Added column 'unique_code' to 'characters' table.^7")
            end)
        end

        if not existingCols["nation"] then
            pcall(function()
                MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `nation` VARCHAR(64) NOT NULL DEFAULT 'Американец' AFTER `gender`")
                print("^2[thehunt_character] Added column 'nation' to 'characters' table.^7")
            end)
        end

        if not existingCols["birthdate"] then
            pcall(function()
                MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `birthdate` DATE NULL AFTER `age`")
                print("^2[thehunt_character] Added column 'birthdate' to 'characters'.^7")
            end)
        end

        if not existingCols["deleted_at"] then
            pcall(function()
                MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `deleted_at` TIMESTAMP NULL DEFAULT NULL AFTER `isdead`")
                print("^2[thehunt_character] Added column 'deleted_at' to 'characters' table.^7")
            end)
        end

        if not existingCols["legacy_vorp_id"] then
            pcall(function()
                MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `legacy_vorp_id` INT NULL DEFAULT NULL AFTER `charidentifier`")
                print("^2[thehunt_character] Added column 'legacy_vorp_id' to 'characters' table.^7")
            end)
        end

        Database.RefreshColumns()

        -- 3. Automatic one-time migration for existing VORP characters
        if Database.Columns["unique_code"] and Migration and type(Migration.AutoMigrateOnStartup) == "function" then
            local migrationOk, migrationError = pcall(Migration.AutoMigrateOnStartup)
            if not migrationOk then
                print("^1[thehunt_character] Automatic migration failed: " .. tostring(migrationError) .. "^7")
            end
        elseif not Database.Columns["unique_code"] then
            print("^1[thehunt_character] Migration skipped: characters.unique_code could not be created.^7")
        end
        Database.Ready = true
        print("^2[thehunt_character] Database schema and migrations are ready.^7")
    end)
end

--- Build SQL SELECT fragment that safely resolves column aliases across VORP versions
local function BuildSelectFields()
    local cols = Database.Columns
    local skinExpr = cols["skin"] and "c.`skin`" or (cols["skinplayer"] and "c.`skinPlayer`" or "'{}'")
    local compsExpr = cols["comps"] and "c.`comps`" or (cols["compplayer"] and "c.`compPlayer`" or "'{}'")
    local descExpr = cols["chardescription"] and "c.`charDescription`" or (cols["character_desc"] and "c.`character_desc`" or "''")
    local codeExpr = cols["unique_code"] and "c.`unique_code`" or "NULL"
    local birthdateExpr = cols["birthdate"] and "DATE_FORMAT(c.`birthdate`, '%d/%m/%Y')" or "NULL"
    local tintsExpr = cols["comptints"] and "c.`compTints`" or "'{}'"
    local nationExpr = cols["nation"] and "c.`nation`" or "'Американец'"

    return string.format([[
        c.`charidentifier`,
        %s AS `unique_code`,
        c.`firstname`,
        c.`lastname`,
        c.`gender`,
        %s AS `nation`,
        c.`age`,
        %s AS `birthdate`,
        c.`nickname`,
        %s AS `character_desc`,
        c.`job`,
        c.`joblabel`,
        c.`jobgrade`,
        c.`group`,
        c.`money`,
        c.`gold`,
        c.`coords`,
        c.`isdead`,
        %s AS `skinPlayer`,
        %s AS `compPlayer`,
        %s AS `compTints`
    ]], codeExpr, nationExpr, birthdateExpr, descExpr, skinExpr, compsExpr, tintsExpr)
end

--- Fetch all active (non-deleted) characters for a steam/license identifier
--- @param identifier string
--- @return table
function Database.GetPlayerCharacters(identifier)
    if not Database.WaitUntilReady() then return {} end
    local selectFields = BuildSelectFields()
    local whereDeleted = Database.Columns["deleted_at"] and "AND (c.`deleted_at` IS NULL)" or ""
    
    local query = string.format([[
        SELECT %s
        FROM `characters` c
        WHERE c.`identifier` = ? %s
        ORDER BY c.`charidentifier` ASC
    ]], selectFields, whereDeleted)

    local success, results = pcall(function()
        return MySQL.query.await(query, { identifier })
    end)

    if success and results then
        return results
    end

    -- Ultimate fallback: direct SELECT *
    local fallbackWhereDeleted = Database.Columns["deleted_at"] and " AND `deleted_at` IS NULL" or ""
    local fallback = MySQL.query.await(
        "SELECT * FROM `characters` WHERE `identifier` = ?" .. fallbackWhereDeleted .. " ORDER BY `charidentifier` ASC",
        { identifier }
    ) or {}
    for _, row in ipairs(fallback) do
        row.skinPlayer = row.skinPlayer or row.skin
        row.compPlayer = row.compPlayer or row.comps
        row.character_desc = row.character_desc or row.charDescription
    end
    return fallback
end

--- Fetch single character by charidentifier
--- @param charIdentifier number
--- @return table|nil
function Database.GetCharacterById(charIdentifier)
    if not Database.WaitUntilReady() then return nil end
    local selectFields = BuildSelectFields()
    local query = string.format("SELECT %s FROM `characters` c WHERE c.`charidentifier` = ? LIMIT 1", selectFields)
    
    local success, results = pcall(function()
        return MySQL.query.await(query, { charIdentifier })
    end)

    if success and results and results[1] then
        return results[1]
    end

    local fallback = MySQL.query.await("SELECT * FROM `characters` WHERE `charidentifier` = ? LIMIT 1", { charIdentifier })
    if fallback and fallback[1] then
        local row = fallback[1]
        row.skinPlayer = row.skinPlayer or row.skin
        row.compPlayer = row.compPlayer or row.comps
        row.character_desc = row.character_desc or row.charDescription
        return row
    end
    return nil
end

--- Verify character belongs to steam/license identifier
--- @param charIdentifier number
--- @param identifier string
--- @return boolean
function Database.VerifyCharacterOwnership(charIdentifier, identifier)
    if not Database.WaitUntilReady() then return false end
    local whereDeleted = Database.Columns["deleted_at"] and "AND `deleted_at` IS NULL" or ""
    local query = string.format([[ 
        SELECT COUNT(1) FROM `characters` 
        WHERE `charidentifier` = ? AND `identifier` = ? %s
    ]], whereDeleted)
    local res = MySQL.scalar.await(query, { charIdentifier, identifier })
    return (tonumber(res) or 0) > 0
end

--- Soft-delete character
--- @param charIdentifier number
--- @param deletedBy string
--- @param reason string
function Database.SoftDeleteCharacter(charIdentifier, identifier, deletedBy, reason)
    -- Never fall back to DELETE: inability to add the soft-delete column must
    -- not destroy a user's character row.
    if not Database.Columns["deleted_at"] then return false end
    local ok, affected = pcall(function()
        return MySQL.update.await([[
            UPDATE `characters`
            SET `deleted_at` = CURRENT_TIMESTAMP
            WHERE `charidentifier` = ? AND `identifier` = ? AND `deleted_at` IS NULL
        ]], { charIdentifier, identifier })
    end)
    if not ok or (tonumber(affected) or 0) < 1 then return false end

    pcall(function()
        MySQL.update.await([[
            UPDATE `thehunt_character_codes`
            SET `is_active` = 0, `deleted_at` = CURRENT_TIMESTAMP, `deleted_by` = ?, `delete_reason` = ?
            WHERE `charidentifier` = ? AND `identifier` = ?
        ]], { deletedBy, reason or "User deletion in selection menu", charIdentifier, identifier })
    end)
    return true
end

--- Update character last position
--- @param charIdentifier number
--- @param identifier string|nil
--- @param coordsJson string
--- @return boolean
function Database.UpdateLastCoords(charIdentifier, identifier, coordsJson)
    -- Backward-compatible two-argument form: (charIdentifier, coordsJson).
    if coordsJson == nil then
        coordsJson = identifier
        identifier = nil
    end
    if not charIdentifier or not coordsJson then return false end

    local ok, affected = pcall(function()
        if identifier and identifier ~= "" then
            return MySQL.update.await(
                "UPDATE `characters` SET `coords` = ? WHERE `charidentifier` = ? AND `identifier` = ?",
                { coordsJson, charIdentifier, identifier }
            )
        end
        return MySQL.update.await(
            "UPDATE `characters` SET `coords` = ? WHERE `charidentifier` = ?",
            { coordsJson, charIdentifier }
        )
    end)
    -- MySQL may report 0 affected rows when the JSON is already identical;
    -- that is still a successful overwrite/no-op, not a failed save.
    return ok
end

function Database.GetWorldState(charIdentifier)
    if not Database.WaitUntilReady() then return nil end
    local ok, rows = pcall(function()
        return MySQL.query.await([[SELECT `charidentifier`, `health`, `health_core`, `stamina`, `stamina_core`, `sprint_stamina`
            FROM `thehunt_character_world_state` WHERE `charidentifier` = ? LIMIT 1]], { charIdentifier })
    end)
    return ok and rows and rows[1] or nil
end

function Database.UpsertWorldState(charIdentifier, state)
    if not Database.WaitUntilReady() or not charIdentifier or type(state) ~= "table" then return false end
    local ok = pcall(function()
        MySQL.update.await([[
            INSERT INTO `thehunt_character_world_state`
                (`charidentifier`, `health`, `health_core`, `stamina`, `stamina_core`, `sprint_stamina`)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                `health` = VALUES(`health`), `health_core` = VALUES(`health_core`),
                `stamina` = VALUES(`stamina`), `stamina_core` = VALUES(`stamina_core`),
                `sprint_stamina` = VALUES(`sprint_stamina`)
        ]], { charIdentifier, state.health, state.healthCore, state.stamina, state.staminaCore, state.sprintStamina })
    end)
    return ok
end

--- Delete character (alias for SoftDeleteCharacter — used by characters.lua)
--- @param charIdentifier number
--- @param identifier string
--- @param deletedBy string
--- @param reason string
function Database.DeleteCharacter(charIdentifier, identifier, deletedBy, reason)
    return Database.SoftDeleteCharacter(charIdentifier, identifier, deletedBy, reason)
end

--- Persist all appearance columns for one owned character.
function Database.UpdateAppearance(charIdentifier, identifier, skinJson, compsJson, compTintsJson)
    if not Database.WaitUntilReady() then return false end
    local skinCol = Database.Columns["skin"] and "`skin`" or (Database.Columns["skinplayer"] and "`skinPlayer`" or nil)
    local compsCol = Database.Columns["comps"] and "`comps`" or (Database.Columns["compplayer"] and "`compPlayer`" or nil)
    local tintsCol = Database.Columns["comptints"] and "`compTints`" or nil
    if not skinCol or not compsCol then return false end

    local assignments = { skinCol .. " = ?", compsCol .. " = ?" }
    local params = { skinJson, compsJson }
    if tintsCol then
        assignments[#assignments + 1] = tintsCol .. " = ?"
        params[#params + 1] = compTintsJson
    end
    params[#params + 1] = charIdentifier
    params[#params + 1] = identifier
    local deletedGuard = Database.Columns["deleted_at"] and " AND `deleted_at` IS NULL" or ""
    local query = "UPDATE `characters` SET " .. table.concat(assignments, ", ")
        .. " WHERE `charidentifier` = ? AND `identifier` = ?" .. deletedGuard
    local ok = pcall(function() MySQL.update.await(query, params) end)
    return ok
end

function Database.UpdateCharacterMetadata(charIdentifier, identifier, nation, birthdateSql)
    if not Database.WaitUntilReady() then return false end
    local sets, params = {}, {}
    if Database.Columns["nation"] then
        sets[#sets + 1] = "`nation` = ?"
        params[#params + 1] = nation
    end
    if Database.Columns["birthdate"] and birthdateSql then
        sets[#sets + 1] = "`birthdate` = ?"
        params[#params + 1] = birthdateSql
    end
    if #sets == 0 then return true end
    params[#params + 1] = charIdentifier
    params[#params + 1] = identifier
    local ok = pcall(function()
        MySQL.update.await("UPDATE `characters` SET " .. table.concat(sets, ", ")
            .. " WHERE `charidentifier` = ? AND `identifier` = ?", params)
    end)
    return ok
end
