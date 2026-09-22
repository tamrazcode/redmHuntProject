-- Complete the native-impact -> victim -> server -> hit path. Combat animations
-- and pursuit remain TaskCombatPed's responsibility; proximity is never a hit.
function ZC.contact(victim,attacker,now)
    local victimRecord,attackerRecord
    for _,r in pairs(ZC.peds) do
        local ped=ZC.entity(r)
        if ped==victim then victimRecord=r end
        if ped==attacker then attackerRecord=r end
    end
    if victimRecord and NetworkHasControlOfEntity(victim) then victimRecord.attacker=attacker end
    if victim~=PlayerPedId() or not attackerRecord or IsEntityDead(victim) then return end
    local r=attackerRecord; local id=GetPlayerServerId(PlayerId())
    if r.dead or IsEntityDead(attacker) or ZC.immune[id] or LocalPlayer.state.huntZombieImmune or r.settings.aggression<=0 then return end
    local maxDist = (r.settings.attackRange or 2.4) * 1.1 + 0.1
    if now<(r.contactAt or 0) or Zombie.distance(GetEntityCoords(victim),GetEntityCoords(attacker))>maxDist then return end
    if not HasEntityClearLosToEntity(attacker,victim,17) then return end
    r.contactAt=now+r.settings.attackCooldown
    ZC.contacts[r.id]=now
    TriggerServerEvent('thehunt_zombie:attack',r.id,id)
end

-- Primary RedM damage event channel: CEventNetworkEntityDamage
if type(AddEventHandler) == 'function' then
    AddEventHandler('gameEventTriggered', function(eventName, args)
        if eventName == 'CEventNetworkEntityDamage' and type(args) == 'table' then
            local victim = args[1]
            local attacker = args[2]
            if victim and attacker then
                ZC.contact(victim, attacker, GetGameTimer())
            end
        end
    end)
end

CreateThread(function()
    local damaged=GetHashKey('EVENT_ENTITY_DAMAGED')
    while true do
        Wait(next(ZC.peds) and 0 or 300)
        -- RedM data layout fallback: nine 8-byte script slots, victim=0, attacker=1.
        for i=0,GetNumberOfEvents(0)-1 do
            if GetEventAtIndex(0,i)==damaged then
                local buffer=string.rep('\0',72)
                if Citizen.InvokeNative(0x57EC5FA4D4D6AFCA,0,i,buffer,9) then
                    local victim=string.unpack('<i4',buffer,1)
                    local attacker=string.unpack('<i4',buffer,9)
                    ZC.contact(victim,attacker,GetGameTimer())
                end
            end
        end
    end
end)
