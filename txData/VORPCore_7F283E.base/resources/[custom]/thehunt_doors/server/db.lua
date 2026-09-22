-- =================================================================
-- HUNT: Hard RP — Doors & Housing | Database Init
-- =================================================================

Citizen.CreateThread(function()
    Wait(500)

    -- Таблица домов
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `thehunt_houses` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(120) NOT NULL DEFAULT 'Жилой дом',
            `owner_identifier` VARCHAR(80) DEFAULT NULL,
            `owner_charid` INT(11) DEFAULT NULL,
            `owner_name` VARCHAR(100) DEFAULT NULL,
            `is_locked` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Таблица дверей
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `thehunt_doors` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `house_id` INT(11) DEFAULT NULL,
            `door_hash` VARCHAR(60) NOT NULL,
            `model_hash` BIGINT(20) NOT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0.0,
            `state` INT(11) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `door_hash_idx` (`door_hash`),
            KEY `house_id_idx` (`house_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    print("^2[HUNT DOORS] База данных дверей и домов успешно проверена и инициализирована.^7")
end)
