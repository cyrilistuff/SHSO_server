-- Idempotent migration for existing SHSO revival databases.
SET @add_gold = IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA='shso' AND TABLE_NAME='user' AND COLUMN_NAME='Gold') = 0,
  'ALTER TABLE shso.`user` ADD COLUMN `Gold` INT NOT NULL DEFAULT 0 AFTER `Paid`',
  'SELECT 1');
PREPARE economy_stmt FROM @add_gold;
EXECUTE economy_stmt;
DEALLOCATE PREPARE economy_stmt;

SET @add_balance = IF(
  (SELECT COUNT(*) FROM information_schema.COLUMNS
   WHERE TABLE_SCHEMA='shso' AND TABLE_NAME='pending_rtc_notifications' AND COLUMN_NAME='Balance') = 0,
  'ALTER TABLE shso.pending_rtc_notifications ADD COLUMN `Balance` BIGINT NULL AFTER `ErrorCode`',
  'SELECT 1');
PREPARE economy_stmt FROM @add_balance;
EXECUTE economy_stmt;
DEALLOCATE PREPARE economy_stmt;
