-- Fresh-account progression restoration.
-- Existing player balances, memberships, heroes and mission ownership are not changed.

USE shso;

ALTER TABLE `user`
  MODIFY `Paid` int NOT NULL DEFAULT '0',
  MODIFY `Gold` int NOT NULL DEFAULT '0',
  MODIFY `Fractals` int NOT NULL DEFAULT '0';

DROP TRIGGER IF EXISTS `seed_restored_starter_content`;

DELIMITER $$
CREATE TRIGGER `seed_restored_starter_content`
AFTER INSERT ON `user`
FOR EACH ROW
BEGIN
  -- Original pre-Recharged starter quartet selected for this restoration.
  INSERT IGNORE INTO `heroes` (`UserID`, `Name`) VALUES
    (NEW.ID, 'ms_marvel'),
    (NEW.ID, 'thing'),
    (NEW.ID, 'cyclops'),
    (NEW.ID, 'falcon');

  -- Starter training missions. Kept explicit so this set can be revised later
  -- without changing the rest of mission ownership/progression.
  INSERT IGNORE INTO `inventory` (`UserID`, `type`, `category`, `subscriber_only`) VALUES
    (NEW.ID, 1288, 'm', 0),
    (NEW.ID, 1290, 'm', 0),
    (NEW.ID, 1296, 'm', 0),
    (NEW.ID, 12725, 'm', 0),
    (NEW.ID, 20549, 'm', 0);
END$$
DELIMITER ;
