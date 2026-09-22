-- =================================================================
-- HUNT: Hard RP — Player Interaction Configuration
-- =================================================================

Config = {}

-- Максимальная дистанция для взаимодействия с другим игроком (1.7м)
Config.MaxDistance = 1.7

-- Список действий в радиальном G-меню при наведении на другого игрока
Config.PlayerActions = {
    {
        id = "player_transfer",
        label = "Передать",
        icon = "transfer",
        event = "thehunt_playerinteraction:openTransferMode",
        isServer = false
    },
    {
        id = "player_medicine",
        label = "Медицина",
        icon = "medicine",
        event = "thehunt_playerinteraction:openMedicineMenu",
        isServer = false
    }
}
