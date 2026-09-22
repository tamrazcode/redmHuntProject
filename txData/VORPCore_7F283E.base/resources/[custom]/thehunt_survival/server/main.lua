local requests = {}
RegisterNetEvent('thehunt_survival:requestClothing', function()
    local src = source
    local now = GetGameTimer()
    if requests[src] and now - requests[src] < 3000 then return end
    requests[src] = now
    -- Client cannot submit a warmth value, item list or another player's identity.
    local warmth, charId = exports.thehunt_items:GetEquippedWarmth(src)
    TriggerClientEvent('thehunt_survival:clothing', src, warmth, charId)
end)
AddEventHandler('playerDropped', function() requests[source] = nil end)
