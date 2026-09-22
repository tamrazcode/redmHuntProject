-- Добавь предмет в БД (один раз). Имя должно совпадать с Config.Spells.*.item
-- Таблица: items (VORP)

INSERT INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
VALUES (
    'magic_spark_scroll',
    'Таро — Терновый пленник',
    3,
    1,
    'item_standard',
    1,
    'На карте изображён человек, окутанный терновым кустом.'
)
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`),
    `limit` = 3,
    `usable` = 1,
    `desc` = VALUES(`desc`);

INSERT INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
VALUES (
    'magic_necro_scroll',
    'Таро — Некромант',
    3,
    1,
    'item_standard',
    1,
    'На карте изображён злой мужик и скелеты. Поднимает труп на пять минут.'
)
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`),
    `limit` = 3,
    `usable` = 1,
    `desc` = VALUES(`desc`);
