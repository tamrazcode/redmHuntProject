-- HUNT character metadata migration.
-- Safe to run repeatedly; no character rows are deleted or rewritten.
SET @dbname = DATABASE();
SET @tablename = "characters";

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
