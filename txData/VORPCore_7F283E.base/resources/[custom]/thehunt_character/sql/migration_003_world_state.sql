-- Exact world-vitals snapshot. Safe to run repeatedly; does not modify or
-- delete existing character data.
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

SET @has_sprint_stamina = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'thehunt_character_world_state'
      AND COLUMN_NAME = 'sprint_stamina');
SET @add_sprint_stamina = IF(@has_sprint_stamina = 0,
    'ALTER TABLE `thehunt_character_world_state` ADD COLUMN `sprint_stamina` TINYINT UNSIGNED NOT NULL DEFAULT 100 AFTER `stamina_core`',
    'SELECT 1');
PREPARE addSprintStamina FROM @add_sprint_stamina;
EXECUTE addSprintStamina;
DEALLOCATE PREPARE addSprintStamina;
