-- =================================================================
-- HUNT: Hard RP — Character System Database Schema
-- Table: thehunt_character_codes & extensions to characters
-- =================================================================

-- 1. Table for historical permanent tracking of 5-digit character codes
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

-- 2. Ensure `unique_code` and `deleted_at` columns exist in `characters` table
SET @dbname = DATABASE();
SET @tablename = "characters";

-- unique_code column
SET @columnname = "unique_code";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD COLUMN `unique_code` VARCHAR(5) NULL UNIQUE AFTER `charidentifier`;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- nation column
SET @columnname = "nation";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_name = @tablename AND table_schema = @dbname AND column_name = @columnname) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD COLUMN `nation` VARCHAR(64) NOT NULL DEFAULT 'Американец' AFTER `gender`;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- birthdate column
SET @columnname = "birthdate";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE table_name = @tablename AND table_schema = @dbname AND column_name = @columnname) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD COLUMN `birthdate` DATE NULL AFTER `age`;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- deleted_at column
SET @columnname = "deleted_at";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD COLUMN `deleted_at` TIMESTAMP NULL DEFAULT NULL AFTER `isdead`;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- legacy_vorp_id column
SET @columnname = "legacy_vorp_id";
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  CONCAT("ALTER TABLE ", @tablename, " ADD COLUMN `legacy_vorp_id` INT NULL DEFAULT NULL AFTER `charidentifier`;")
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;
