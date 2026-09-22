-- Explicit server snapshots complement player state bags for streamed replicas.
local snapshots, requests = {}, {}
function BackpackStateSet(src, key, value)
    Player(src).state:set(key, value, true)
    local packet = snapshots[src] or {}
    snapshots[src] = packet
    if value == nil then value = false end
    packet[key] = value
    TriggerClientEvent('thehunt_inventory:backpackState', -1, src, packet)
end
RegisterNetEvent('thehunt_items:requestBackpackStates', function()
    local src, now = source, GetGameTimer()
    if now < (requests[src] or 0) then return end
    requests[src] = now + 2000
    TriggerClientEvent('thehunt_inventory:backpackStates', src, snapshots, GlobalState.huntBackpackProfiles or {})
end)
AddEventHandler('playerDropped', function()
    snapshots[source], requests[source] = nil, nil
    TriggerClientEvent('thehunt_inventory:backpackState', -1, source, {attachedBackpack=false})
end)
