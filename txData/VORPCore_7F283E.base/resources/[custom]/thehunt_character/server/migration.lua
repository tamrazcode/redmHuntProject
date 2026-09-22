-- =================================================================
-- HUNT: Hard RP — Safe VORP Migration Runner (Auto & Manual Commands)
-- =================================================================

Migration = {}

--- Run automatic one-time migration on server startup
function Migration.AutoMigrateOnStartup()
    -- This function is called from Database.Init's already-yieldable startup
    -- thread. Keep it in that thread so Database.Ready cannot become true
    -- while the same rows are still being migrated in the background.
    -- Fetch unmigrated characters.
        local unmigrated = MySQL.query.await([[
            SELECT `charidentifier`, `identifier`, `firstname`, `lastname`, `unique_code` 
            FROM `characters` 
            WHERE `unique_code` IS NULL OR `unique_code` = ''
            ORDER BY `charidentifier` ASC
        ]]) or {}

        if #unmigrated > 0 then
            print("=================================================================")
            print(string.format("^3[thehunt_character] Обнаружено %d немигрированных персонажей. Запуск автоматической миграции...^7", #unmigrated))
            print("=================================================================")

            local count = 0
            for _, char in ipairs(unmigrated) do
                local code = CodeGenerator.GenerateAndReserve(char.charidentifier, char.identifier)
                if code then
                    pcall(function()
                        MySQL.update.await("UPDATE `characters` SET `legacy_vorp_id` = ? WHERE `charidentifier` = ? AND `legacy_vorp_id` IS NULL", {
                            char.charidentifier,
                            char.charidentifier
                        })
                    end)
                    count = count + 1
                    local fullName = (char.firstname or "Неизвестный") .. " " .. (char.lastname or "Странник")
                    print(string.format("^2[thehunt_character] [АВТО-МИГРАЦИЯ] ID %d (%s) -> Выдан код #%s^7", char.charidentifier, fullName, code))
                end
            end

            print("=================================================================")
            print(string.format("^2[thehunt_character] Автоматическая миграция успешно завершена! Мигрировано: %d персонажей.^7", count))
            print("=================================================================")
        else
            print("^2[thehunt_character] Все персонажи в базе данных имеют уникальные 5-значные коды.^7")
        end
end

--- Execute or simulate VORP character migration manually
--- @param isDryRun boolean
function Migration.Run(isDryRun)
    print("=================================================================")
    print(string.format("[thehunt_character] Starting VORP Characters Migration (%s)", isDryRun and "DRY RUN MODE" or "EXECUTE MODE"))
    print("=================================================================")

    -- 1. Ensure thehunt_character_codes table exists
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

    -- 2. Fetch all characters from DB
    local allCharacters = MySQL.query.await("SELECT `charidentifier`, `identifier`, `firstname`, `lastname`, `unique_code` FROM `characters` ORDER BY `charidentifier` ASC") or {}
    
    local totalFound = #allCharacters
    local alreadyMigrated = 0
    local toMigrate = 0
    local simulatedCodes = {}

    for _, char in ipairs(allCharacters) do
        if char.unique_code and char.unique_code ~= "" then
            alreadyMigrated = alreadyMigrated + 1
        else
            toMigrate = toMigrate + 1
            if not isDryRun then
                local code = CodeGenerator.GenerateAndReserve(char.charidentifier, char.identifier)
                if code then
                    pcall(function()
                        MySQL.update.await("UPDATE `characters` SET `legacy_vorp_id` = ? WHERE `charidentifier` = ? AND `legacy_vorp_id` IS NULL", {
                            char.charidentifier,
                            char.charidentifier
                        })
                    end)
                    print(string.format("[MIGRATED] ID %d: %s %s -> Code #%s", char.charidentifier, char.firstname or "", char.lastname or "", code))
                end
            else
                local simulatedCode = Utils.FormatCode(math.random(1, 99999))
                table.insert(simulatedCodes, { id = char.charidentifier, name = (char.firstname or "") .. " " .. (char.lastname or ""), code = simulatedCode })
            end
        end
    end

    print("-----------------------------------------------------------------")
    print(string.format("Всего персонажей в БД: %d", totalFound))
    print(string.format("Уже имеют 5-значный код: %d", alreadyMigrated))
    print(string.format("Требуют миграции: %d", toMigrate))
    
    if isDryRun then
        print("[DRY RUN] Персонажи, которые будут обновлены:")
        for _, sample in ipairs(simulatedCodes) do
            print(string.format(" - ID %d: %s -> [Будет выдан код]", sample.id, sample.name))
        end
        print("[DRY RUN ЗАВЕРШЕН] Для применения изменений выполните в консоли: hunt_migrate run")
    else
        print(string.format("[МИГРАЦИЯ УСПЕШНО ЗАВЕРШЕНА] Успешно мигрировано %d персонажей.", toMigrate))
    end
    print("=================================================================")
end

-- =================================================================
-- Console Commands for Server Administrators
-- =================================================================
RegisterCommand("hunt_migrate", function(source, args)
    if source ~= 0 and not Admin.IsAdmin(source) then
        print("Команда доступна только для администраторов сервера.")
        return
    end

    local mode = args[1] and args[1]:lower() or "dry"
    if mode == "run" or mode == "execute" then
        Migration.Run(false)
    else
        Migration.Run(true)
    end
end, true)
