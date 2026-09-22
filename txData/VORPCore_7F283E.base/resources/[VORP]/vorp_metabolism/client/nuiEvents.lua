NUIEvents = {}

NUIEvents.UpdateHUD = function()
    local thirst = PlayerStatus["Thirst"] / 1000;
    local hunger = PlayerStatus["Hunger"] / 1000;

    -- HUNT core owns the compatibility boundary to the unified HUD.
    TriggerEvent("thehunt_core:client:updateMetabolismHud", hunger, thirst)
    -- Also notify the HUD directly.  vorp_metabolism starts before
    -- thehunt_core, so the bridge event can be missed during a resource restart.
    TriggerEvent("thehunt_status:updateMetabolism", hunger, thirst)

    -- Старый UI VORP отключаем, чтобы не дублировать
    SendNUIMessage({
        action = "hide"
    })
end

NUIEvents.ShowHUD = function(show)
    -- Скрыто в пользу единого HUD The Hunt
    SendNUIMessage({
        action = 'hide'
    })
end
