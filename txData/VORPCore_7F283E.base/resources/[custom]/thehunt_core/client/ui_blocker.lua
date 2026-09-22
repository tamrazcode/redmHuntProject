-- =================================================================
-- HUNT: Hard RP — Universal UI Input Blocker
-- Автоматически и безопасно блокирует паразитные клавиши RDR2 (удары, свист, посадку на коня, прицеливание, колесо оружия),
-- когда открыт ЛЮБОЙ интерфейс NUI (инвентарь, админка, билдер, диалоги и т.д.),
-- оставляя игроку ТОЛЬКО передвижение персонажа (WASD, Space, Shift).
-- =================================================================

local isManualUIMode = false

RegisterNetEvent("thehunt_core:setUIMode", function(state)
    isManualUIMode = (state == true)
end)

exports('SetUIMode', function(state)
    isManualUIMode = (state == true)
end)

exports('IsUIMode', function()
    return isManualUIMode or IsNuiFocused()
end)

local allowedControls = {
    -- Войс-чат
    `INPUT_PUSH_TO_TALK`,
    0xF1301666,
    0x05CA7C52,

    -- Движение пешком (WASD, Shift, Space, Ctrl)
    `INPUT_MOVE_LR`,
    `INPUT_MOVE_UD`,
    `INPUT_MOVE_UP_ONLY`,
    `INPUT_MOVE_DOWN_ONLY`,
    `INPUT_MOVE_LEFT_ONLY`,
    `INPUT_MOVE_RIGHT_ONLY`,
    `INPUT_SPRINT`,
    `INPUT_JUMP`,
    `INPUT_CLIMB`,
    `INPUT_DUCK`,

    -- Движение на лошади (WASD, Shift, Space, Ctrl)
    `INPUT_HORSE_MOVE_UD`,
    `INPUT_HORSE_MOVE_LR`,
    `INPUT_HORSE_MOVE_UP_ONLY`,
    `INPUT_HORSE_MOVE_DOWN_ONLY`,
    `INPUT_HORSE_MOVE_LEFT_ONLY`,
    `INPUT_HORSE_MOVE_RIGHT_ONLY`,
    `INPUT_HORSE_SPRINT`,
    `INPUT_HORSE_JUMP`,
    `INPUT_HORSE_STOP`,

    -- Управление повозками
    `INPUT_VEH_ACCELERATE`,
    `INPUT_VEH_BRAKE`,
    `INPUT_VEH_MOVE_LR`,
    `INPUT_VEH_HANDBRAKE`,

    -- Числовые хэши RDR2 на случай нестандартных названий
    0x4D8FB4C1, -- MOVE_LR
    0xEDA4707E, -- MOVE_UD
    0x8FD015D8, -- MOVE_UD (RDR2)
    0xD27782E3, -- MOVE_UP_ONLY (W)
    0x7065027D, -- MOVE_DOWN_ONLY (S)
    0xB4E465B4, -- MOVE_LEFT_ONLY (A)
    0x399C6619, -- MOVE_RIGHT_ONLY (D)
    0x8FFC75D0, -- SPRINT (Shift)
    0x2C4B7E05, -- SPRINT_ALT
    0xD42E6C65, -- JUMP (Space)
    0x9330C873, -- CLIMB (Space)
    0xDB096B85, -- DUCK (Ctrl)
    0x78564D7B, -- DUCK_ALT
    0x82CA7BA9, -- HORSE_MOVE_UD
    0x227DCC40, -- HORSE_MOVE_LR
    0xE95F4F0C, -- HORSE_MOVE_UP_ONLY (W)
    0x866B5DB8, -- HORSE_MOVE_DOWN_ONLY (S)
    0x51E13F58, -- HORSE_MOVE_LEFT_ONLY (A)
    0xC229CF67, -- HORSE_MOVE_RIGHT_ONLY (D)
    0x54182BC1, -- HORSE_SPRINT (Shift)
    0x63A38928, -- HORSE_JUMP (Space)
    0xD2315E39, -- HORSE_CLIMB (Space)
    0x153A478C  -- HORSE_STOP (Ctrl)
}

Citizen.CreateThread(function()
    while true do
        local isNui = IsNuiFocused()
        if isNui or isManualUIMode then
            Citizen.Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)

            for pad = 0, 2 do
                for i = 1, #allowedControls do
                    EnableControlAction(pad, allowedControls[i], true)
                end
            end
        else
            Citizen.Wait(100)
        end
    end
end)
