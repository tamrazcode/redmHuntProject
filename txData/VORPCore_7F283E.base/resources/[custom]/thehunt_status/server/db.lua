-- =================================================================
-- HUNT: Hard RP — The Corruption | Status & Buffs Database Layer
-- =================================================================

DB = {}

function DB.Init()
    local sql = [[
        CREATE TABLE IF NOT EXISTS `thehunt_player_effects` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `char_id` INT NOT NULL,
            `effect_id` VARCHAR(64) NOT NULL,
            `label` VARCHAR(64) NOT NULL,
            `icon` VARCHAR(64) NOT NULL,
            `color` VARCHAR(32) NOT NULL,
            `expires_at` BIGINT NOT NULL,
            `metadata` TEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX (`char_id`),
            INDEX (`effect_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]
    MySQL.query(sql, {}, function(res)
        print("^2[HUNT STATUS] Таблица thehunt_player_effects успешно инициализирована!^7")
    end)
end

-- Сохранить стойкий эффект
function DB.SavePersistentEffect(charId, effectData, cb)
    local sql = [[
        INSERT INTO `thehunt_player_effects` (`char_id`, `effect_id`, `label`, `icon`, `color`, `expires_at`, `metadata`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `expires_at` = VALUES(`expires_at`), `metadata` = VALUES(`metadata`)
    ]]
    local metaStr = effectData.metadata and json.encode(effectData.metadata) or nil
    MySQL.insert(sql, {
        charId,
        effectData.id,
        effectData.label or "Эффект",
        effectData.icon or "activity",
        effectData.color or "#ffffff",
        effectData.expires_at or 0,
        metaStr
    }, function(insertId)
        if cb then cb(insertId) end
    end)
end

-- Удалить эффект персонажа
function DB.DeletePersistentEffect(charId, effectId, cb)
    local sql = "DELETE FROM `thehunt_player_effects` WHERE `char_id` = ? AND `effect_id` = ?"
    MySQL.execute(sql, { charId, effectId }, function(affected)
        if cb then cb(affected > 0) end
    end)
end

-- Получить все активные эффекты персонажа
function DB.LoadPlayerEffects(charId, cb)
    local now = os.time() * 1000
    local sql = "SELECT * FROM `thehunt_player_effects` WHERE `char_id` = ? AND (`expires_at` = 0 OR `expires_at` > ?)"
    MySQL.query(sql, { charId, now }, function(rows)
        if cb then cb(rows or {}) end
    end)
end

-- Очистка истекших эффектов
function DB.CleanExpiredEffects()
    local now = os.time() * 1000
    local sql = "DELETE FROM `thehunt_player_effects` WHERE `expires_at` > 0 AND `expires_at` <= ?"
    MySQL.execute(sql, { now })
end
