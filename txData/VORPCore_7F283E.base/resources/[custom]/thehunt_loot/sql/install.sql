-- =================================================================
-- HUNT: Hard RP — The Corruption | thehunt_loot Database Installation
-- =================================================================

DROP TABLE IF EXISTS `thehunt_loot_logs`;
DROP TABLE IF EXISTS `thehunt_loot_cooldowns`;
DROP TABLE IF EXISTS `thehunt_loot_active_slots`;
DROP TABLE IF EXISTS `thehunt_loot_zone_items`;
DROP TABLE IF EXISTS `thehunt_loot_zones`;

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

CREATE TABLE IF NOT EXISTS `thehunt_loot_cooldowns` (
    `zone_id` INT PRIMARY KEY,
    `ready_at` BIGINT NOT NULL DEFAULT 0,
    `last_spawned_at` BIGINT NOT NULL DEFAULT 0,
    INDEX `idx_cooldown_zone` (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
