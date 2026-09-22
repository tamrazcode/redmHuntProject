-- =================================================================
-- HUNT: Hard RP — Unique 5-Digit Character Code Generator
-- Guarantees historical uniqueness & permanent reservation
-- =================================================================

CodeGenerator = {}
local reservationsInProgress = {}

--- Generate a new cryptographically unique 5-digit code and reserve it in DB
--- @param charIdentifier number
--- @param identifier string
--- @return string|nil uniqueCode
function CodeGenerator.GenerateAndReserve(charIdentifier, identifier)
    local lockKey = tostring(tonumber(charIdentifier) or charIdentifier)
    local deadline = GetGameTimer() + 10000
    while reservationsInProgress[lockKey] and GetGameTimer() < deadline do Wait(10) end
    if reservationsInProgress[lockKey] then
        print(string.format("[thehunt_character] Timed out waiting for code reservation lock for Char ID %s", lockKey))
        return nil
    end
    reservationsInProgress[lockKey] = true

    local success, result = pcall(function()
        -- Creation, startup migration and list loading may meet on the same
        -- row. Serialize them, then reuse the first permanent reservation.
        local reserved = MySQL.scalar.await(
            "SELECT `code` FROM `thehunt_character_codes` WHERE `charidentifier` = ? ORDER BY `assigned_at` ASC LIMIT 1",
            { charIdentifier }
        )
        if reserved then
            MySQL.update.await("UPDATE `characters` SET `unique_code` = ? WHERE `charidentifier` = ?", { reserved, charIdentifier })
            return Utils.FormatCode(reserved)
        end

        local attempts = 0
        while attempts < Constants.MaxCodeAttempts do
            attempts = attempts + 1
            local rawNum = math.random(1, 99999)
            local codeCandidate = Utils.FormatCode(rawNum)

            -- The code itself is a primary key, so concurrent reservations
            -- for different characters remain atomic at the database layer.
            local existing = MySQL.scalar.await("SELECT `code` FROM `thehunt_character_codes` WHERE `code` = ?", { codeCandidate })
            if not existing then
                local inserted = pcall(function()
                    MySQL.insert.await("INSERT INTO `thehunt_character_codes` (`code`, `charidentifier`, `identifier`, `is_active`) VALUES (?, ?, ?, 1)", {
                        codeCandidate,
                        charIdentifier,
                        identifier
                    })
                end)

                if inserted then
                    MySQL.update.await("UPDATE `characters` SET `unique_code` = ? WHERE `charidentifier` = ?", {
                        codeCandidate,
                        charIdentifier
                    })
                    print(string.format("[thehunt_character] Issued unique 5-digit code #%s for Char ID %s (%s)", codeCandidate, charIdentifier, identifier))
                    return codeCandidate
                end
            end
        end
        return nil
    end)

    reservationsInProgress[lockKey] = nil
    if not success then
        print(string.format("[thehunt_character] [ERROR] Code reservation failed for Char ID %s: %s", lockKey, tostring(result)))
        return nil
    end
    if result then return result end

    print("[thehunt_character] [ERROR] Failed to generate unique code after maximum attempts!")
    return nil
end

--- Permanently mark code as inactive on character deletion
--- @param charIdentifier number
--- @param deletedBy string
--- @param reason string
function CodeGenerator.RetireCode(charIdentifier, deletedBy, reason)
    MySQL.update.await("UPDATE `thehunt_character_codes` SET `is_active` = 0, `deleted_at` = CURRENT_TIMESTAMP, `deleted_by` = ?, `delete_reason` = ? WHERE `charidentifier` = ?", {
        deletedBy or "SYSTEM",
        reason or "Player deleted character",
        charIdentifier
    })
    print(string.format("[thehunt_character] Retired code for Char ID %s (marked permanently non-reusable)", charIdentifier))
end

--- Get 5-digit code by player server ID (source)
--- @param src number
--- @return string|nil
function CodeGenerator.GetCharacterCode(src)
    local charId = exports.thehunt_core:GetCharacterId(src)
    if not charId or charId <= 0 then return nil end

    return CodeGenerator.GetCharacterCodeById(charId)
end

--- Get 5-digit code by character DB identifier
--- @param charIdentifier number
--- @return string|nil
function CodeGenerator.GetCharacterCodeById(charIdentifier)
    local code = MySQL.scalar.await("SELECT `code` FROM `thehunt_character_codes` WHERE `charidentifier` = ? AND `is_active` = 1 LIMIT 1", { charIdentifier })
    if not code then
        code = MySQL.scalar.await("SELECT `unique_code` FROM `characters` WHERE `charidentifier` = ? LIMIT 1", { charIdentifier })
    end
    return code
end

--- Get character info by 5-digit code
--- @param code string
--- @return table|nil
function CodeGenerator.GetCharacterByCode(code)
    local cleanCode = Utils.FormatCode(code)
    local deletedGuard = Database and Database.Columns and Database.Columns["deleted_at"] and " AND `deleted_at` IS NULL" or ""
    local row = MySQL.single.await("SELECT * FROM `characters` WHERE `unique_code` = ?" .. deletedGuard .. " LIMIT 1", { cleanCode })
    return row
end

-- =================================================================
-- Server Exports API
-- =================================================================
exports("GetCharacterCode", CodeGenerator.GetCharacterCode)
exports("GetCharacterCodeById", CodeGenerator.GetCharacterCodeById)
exports("GetCharacterByCode", CodeGenerator.GetCharacterByCode)
