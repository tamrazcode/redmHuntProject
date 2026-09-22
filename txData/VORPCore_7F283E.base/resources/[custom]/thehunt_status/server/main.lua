-- =================================================================
-- HUNT: Hard RP — The Corruption | Status & Buffs Server Main
-- =================================================================

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    DB.Init()
end)

-- Периодическая очистка просроченных дебаффов из БД (каждые 5 минут)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000)
        DB.CleanExpiredEffects()
    end
end)

-- Загрузка эффектов при выборе персонажа
AddEventHandler("thehunt:character:selected", function(src, charId)
    if not charId then return end

    DB.LoadPlayerEffects(charId, function(effects)
        for _, eff in ipairs(effects) do
            local remainingMs = 0
            if eff.expires_at > 0 then
                remainingMs = math.max(0, eff.expires_at - (os.time() * 1000))
            end

            local effectData = {
                id = eff.effect_id,
                label = eff.label,
                icon = eff.icon,
                color = eff.color,
                duration = remainingMs,
                isPersistent = true,
                metadata = eff.metadata and json.decode(eff.metadata) or nil
            }
            TriggerClientEvent("thehunt_status:addEffect", src, effectData)
        end
    end)
end)

-- Экспорт: Добавить эффект игроку с сервера
function AddPlayerEffect(targetSrc, effectData)
    if not targetSrc or not effectData or not effectData.id then return false end
    TriggerClientEvent("thehunt_status:addEffect", targetSrc, effectData)

    if effectData.isPersistent then
        local charId = exports.thehunt_core:GetCharacterId(targetSrc)
        if charId then
            local expiresAt = (effectData.duration and effectData.duration > 0) and ((os.time() * 1000) + effectData.duration) or 0
            effectData.expires_at = expiresAt
            DB.SavePersistentEffect(charId, effectData)
        end
    end
    return true
end

-- Экспорт: Удалить эффект у игрока с сервера
function RemovePlayerEffect(targetSrc, effectId)
    if not targetSrc or not effectId then return false end
    TriggerClientEvent("thehunt_status:removeEffect", targetSrc, effectId)

    local charId = exports.thehunt_core:GetCharacterId(targetSrc)
    if charId then
        DB.DeletePersistentEffect(charId, effectId)
    end
    return true
end
