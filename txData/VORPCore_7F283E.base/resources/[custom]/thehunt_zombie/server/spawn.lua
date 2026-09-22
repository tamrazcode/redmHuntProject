ZS = { zones={}, runtime={}, peds={}, tickets={}, retired={}, immune={}, info={}, debug={},
    ready=false, paused=false, sequence=0, epoch=tostring(os.time())..':'..tostring(GetGameTimer()) }
local C=ZombieConfig
function ZS.exists(r)
    if not r.entity or r.entity==0 or not DoesEntityExist(r.entity) then return false end
    return true
end
local function deleteTicketEntity(id,net)
    local e=net and NetworkGetEntityFromNetworkId(net) or 0
    if e==0 or not DoesEntityExist(e) then return end
    for _,player in ipairs(GetPlayers()) do if GetPlayerPed(tonumber(player))==e then return end end
    local tag=Entity(e).state.huntZombie
    if type(tag)=='table' and tag.id==id then DeleteEntity(e) end
end
function ZS.players()
    local out={}
    for _,s in ipairs(GetPlayers()) do
        local id=tonumber(s); local ped=GetPlayerPed(id)
        if ped~=0 and DoesEntityExist(ped) then
            local state=Player(id).state
            if not state.isSelectingChar and not state.isCreatingChar then
                local coords=GetEntityCoords(ped)
                if coords and (math.abs(coords.x)>0.1 or math.abs(coords.y)>0.1) then
                    out[#out+1]={id=id,ped=ped,pos=Zombie.coords(coords),bucket=GetPlayerRoutingBucket(id)}
                end
            end
        end
    end
    return out
end
function ZS.nearest(pos,bucket,players,range)
    local nearest,dist=nil,range
    for _,p in ipairs(players) do
        if p.bucket==bucket then local d=Zombie.distance(pos,p.pos); if d<dist then nearest,dist=p.id,d end end
    end
    return nearest,dist
end
function ZS.count(zone)
    local n=0
    for _,r in pairs(ZS.peds) do if not r.dead and (not zone or r.zone==zone or r.destination==zone) then n=n+1 end end
    for _,r in pairs(ZS.tickets) do if not zone or r.zone==zone then n=n+1 end end
    return n
end
function ZS.public(r)
    return {id=r.id,net=r.net,zone=r.zone,model=r.model,outfit=r.outfit,settings=r.settings,weapon=r.weapon,
        home=r.home,radius=r.radius,bucket=r.bucket,destination=r.destination,goal=r.goal,dead=r.dead}
end
function ZS.publish(r) TriggerClientEvent('thehunt_zombie:upsert',-1,ZS.public(r)) end
function ZS.cooldown(zone,seconds)
    local rt=ZS.runtime[zone]; if not rt then return end
    rt.nextSpawn=math.max(rt.nextSpawn or 0,os.time()+seconds)
    rt.dirty=true
end
function ZS.remove(id,reason)
    local r=ZS.peds[id]; if not r then return false end
    -- Remove from authority before notifying clients: stale attack/death reports cannot act.
    ZS.peds[id]=nil
    if reason ~= 'claimed' and ZS.exists(r) then DeleteEntity(r.entity) end
    ZS.retired[id]={untilTime=GetGameTimer()+60000,owner=r.creator}
    if ZS.removeCorpseLoot then
        ZS.removeCorpseLoot(id)
    elseif ZS.corpseLoot and ZS.corpseLoot[id] then
        ZS.corpseLoot[id] = nil
        TriggerClientEvent('thehunt_zombie:corpseLootRemoved', -1, id)
    end
    if reason ~= 'claimed' then
        TriggerClientEvent('thehunt_zombie:remove',-1,id,r.net)
    else
        TriggerClientEvent('thehunt_zombie:claimed',-1,id,r.net)
    end
    TriggerClientEvent('thehunt_zombie:stopAmbient',-1,id)
    TriggerEvent('thehunt_zombie:removed',id,reason)
    return true
end

function ZS.claim(id)
    local r=ZS.peds[id]
    if not r then return false end
    if ZS.exists(r) then
        ZS.servants = ZS.servants or {}
        ZS.servants[r.entity] = GetGameTimer() + 600000
        pcall(function()
            Entity(r.entity).state:set('huntNecroServant', true, true)
            Entity(r.entity).state:set('huntZombie', false, true)
            Entity(r.entity).state:set('isProtected', true, true)
        end)
    end
    return ZS.remove(id, 'claimed')
end

RegisterNetEvent('thehunt_zombie:claim', function(id)
    if type(id) ~= 'string' and type(id) ~= 'number' then return end
    ZS.claim(id)
end)
function ZS.cancel(id)
    local t=ZS.tickets[id]; if not t then return end
    ZS.tickets[id]=nil; ZS.retired[id]={untilTime=GetGameTimer()+60000,owner=t.owner}
    deleteTicketEntity(id,t.net)
    -- Unknown creations are swept within 10 s. Do not allocate a replacement before
    -- that quarantine ends when a client vanished before acknowledging its entity.
    ZS.cooldown(t.zone,12)
    TriggerClientEvent('thehunt_zombie:cancel',t.owner,id)
end
function ZS.clear(zone,reason)
    local ids={}; for id,r in pairs(ZS.peds) do if not zone or r.zone==zone or r.destination==zone then ids[#ids+1]=id end end
    for _,id in ipairs(ids) do ZS.remove(id,reason) end
    ids={}; for id,t in pairs(ZS.tickets) do if not zone or t.zone==zone then ids[#ids+1]=id end end
    for _,id in ipairs(ids) do ZS.cancel(id) end
end
function ZS.spawn(zone,owner,players)
    local z=ZS.zones[zone]; if not z or ZS.paused or not ZS.ready then return nil end
    if ZS.count()>=C.MaxAlive or ZS.count(zone)>=z.maxCount then return nil end
    local pending=0; for _ in pairs(ZS.tickets) do pending=pending+1 end
    local entities=pending; for _ in pairs(ZS.peds) do entities=entities+1 end
    if entities>=C.MaxEntities then return nil end
    if pending>=C.MaxPending then return nil end
    local settings=Zombie.settings(z)
    local chosenWeapon = nil
    local wType = settings.weaponType or 'none'
    local wChance = tonumber(settings.weaponChance) or 0
    if wType ~= 'none' and wChance > 0 and math.random(100) <= wChance then
        if wType == 'both' then
            chosenWeapon = (math.random(2) == 1) and 'WEAPON_MELEE_MACHETE' or 'WEAPON_MELEE_KNIFE'
        elseif wType == 'machete' then
            chosenWeapon = 'WEAPON_MELEE_MACHETE'
        elseif wType == 'knife' then
            chosenWeapon = 'WEAPON_MELEE_KNIFE'
        end
    end
    settings.chosenWeapon = chosenWeapon
    local chosenWalk = settings.walkStyle or 'MP_Style_drunk'
    if chosenWalk == 'random' then
        local zombieWalks = { 'MP_Style_drunk', 'zombie_very_drunk' }
        chosenWalk = zombieWalks[math.random(#zombieWalks)]
    end
    settings.chosenWalkStyle = chosenWalk
    local candidates={}
    local rt=ZS.runtime[zone]
    for _,m in ipairs(settings.models) do if not rt.badModels or not rt.badModels[m] then candidates[#candidates+1]=m end end
    if #candidates==0 then rt.error='Нет доступных ped-моделей'; return nil end
    local model=candidates[z.randomModel and math.random(#candidates) or 1]
    local pos
    local minDistance = math.min(C.MinSpawnDistance, math.max(1.5, z.spawnRadius * 0.4))
    for _=1,16 do
        local candidate=Zombie.point(z,z.spawnRadius)
        if not ZS.nearest(candidate,z.bucket,players,minDistance) then pos=candidate; break end
    end
    if not pos then pos=Zombie.point(z,z.spawnRadius) end
    ZS.sequence=ZS.sequence+1
    local id=ZS.epoch..':'..ZS.sequence
    local allowedOutfits = (z.modelOutfits and z.modelOutfits[model] and #z.modelOutfits[model] > 0) and z.modelOutfits[model] or ZombieModels[model]
    local outfit = (allowedOutfits and #allowedOutfits > 0) and allowedOutfits[math.random(#allowedOutfits)] or 0
    ZS.tickets[id]={id=id,zone=zone,owner=owner,pos=pos,model=model,spawnRadius=z.spawnRadius,
        outfit=outfit,settings=settings,weapon=chosenWeapon,expires=GetGameTimer()+C.SpawnTimeout,bucket=z.bucket}
    TriggerClientEvent('thehunt_zombie:spawn',owner,ZS.tickets[id])
    return id
end
RegisterNetEvent('thehunt_zombie:spawnResult',function(id,net,errorCode)
    local src=source
    if type(id)~='string' or #id>100 then return end
    local t=ZS.tickets[id]
    if not t or t.owner~=src then
        local retired=ZS.retired[id]
        if retired and retired.owner==src then
            if type(net)=='number' and net>0 and net%1==0 then deleteTicketEntity(id,net) end
            TriggerClientEvent('thehunt_zombie:cancel',src,id)
        end
        return
    end
    if errorCode then
        print(('[thehunt_zombie] Spawn retry for ticket %s in zone %s: %s'):format(id, t.zone, tostring(errorCode)))
        if errorCode=='model' then
            local rt=ZS.runtime[t.zone]; rt.badModels=rt.badModels or {}; rt.badModels[t.model]=true
            rt.error='Недоступная модель: '..t.model
        end
        ZS.cancel(id); ZS.cooldown(t.zone,3); return
    end
    net=tonumber(net)
    if not net or net%1~=0 or net<=0 then return end
    if t.committing then return end
    t.committing=true; t.net=net
    CreateThread(function()
        local e=0
        for _=1,30 do
            e=NetworkGetEntityFromNetworkId(net)
            if e~=0 and DoesEntityExist(e) then break end
            Wait(100)
        end
        if ZS.tickets[id]~=t then TriggerClientEvent('thehunt_zombie:cancel',src,id); return end
        local z=ZS.zones[t.zone]
        local isPlayer=false
        for _,player in ipairs(GetPlayers()) do if GetPlayerPed(tonumber(player))==e then isPlayer=true; break end end
        local coords=GetEntityCoords(e)
        for _=1,10 do
            if coords.x~=0.0 or coords.y~=0.0 then break end
            Wait(100)
            coords=GetEntityCoords(e)
        end
        local hasCoords = (coords.x~=0.0 or coords.y~=0.0)
        local dist2D = hasCoords and Zombie.distance2D(coords,t.pos) or 0.0
        local owner = NetworkGetEntityOwner(e)
        local ownerMatch = (owner == src or owner == -1 or owner == 128 or owner == 0)
        local entityModel = GetEntityModel(e)
        local modelMatch = (entityModel == 0 or (entityModel & 0xffffffff) == (GetHashKey(t.model) & 0xffffffff))
        local valid=e~=0 and DoesEntityExist(e) and GetEntityType(e)==1
            and not isPlayer
            and ownerMatch and modelMatch
            and (not hasCoords or dist2D<60.0) and GetPlayerRoutingBucket(src)==t.bucket
            and z and z.enabled and not ZS.paused and t.expires>=GetGameTimer()
            and ZS.nearest(t.pos,t.bucket,ZS.players(),math.max(z.activation, z.spawnRadius or 0)+60)
        if not valid then
            print(('[thehunt_zombie] Validation rejected ticket %s (entity %s, modelMatch=%s, dist2D=%.1f)'):format(id, e, tostring(modelMatch), dist2D))
            ZS.cancel(id); return
        end
        for _,r in pairs(ZS.peds) do if r.net==net then ZS.cancel(id); return end end
        ZS.tickets[id]=nil
        SetEntityRoutingBucket(e,t.bucket)
        if SetEntityOrphanMode then SetEntityOrphanMode(e,2) end
        local r={id=id,net=net,entity=e,zone=t.zone,creator=src,model=t.model,outfit=t.outfit,
            settings=t.settings,weapon=t.weapon,home=Zombie.coords(z),radius=z.radius,bucket=z.bucket,
            lastOwner=owner,
            lastNear=GetGameTimer(),lastAttack=0,lastReport=0,state='WANDER'}
        ZS.peds[id]=r
        Entity(e).state:set('huntZombie',{id=id,epoch=ZS.epoch,zone=r.zone,profile=z.profile,headshotOnly=r.settings.headshotOnly,weapon=t.weapon},true)
        Entity(e).state:set('isProtected',true,true)
        ZS.publish(r)
        TriggerClientEvent('thehunt_zombie:committed',src,id)
    end)
end)
function ZS.markDead(id, killerSrc, soundFile)
    local r=ZS.peds[id]
    -- RedM's server sync tree does not expose ped health (GetPedHealth=nullptr).
    -- Only the owning client's IsEntityDead report can enter this path.
    -- The client may still render the corpse for a short time after the server
    -- loses the network entity handle. The death report must still start the
    -- authoritative corpse lifetime in that case.
    if not r or r.dead then return end
    r.dead=true; r.diedAt=GetGameTimer(); r.lastNear=GetGameTimer(); r.state='DEAD'; r.target=nil
    ZS.cooldown(r.zone,(ZS.zones[r.zone] or {}).respawn or 120)
    ZS.publish(r)
    TriggerEvent('thehunt_zombie:died',id,r.net,r.zone)
    TriggerClientEvent('thehunt_zombie:stopAmbient',-1,id)

    local deathSounds = ZombieConfig.DeathSounds
    local chosenSound = soundFile or (deathSounds and #deathSounds > 0 and deathSounds[math.random(1, #deathSounds)])
    if chosenSound then
        local pos = r.position or (r.entity and DoesEntityExist(r.entity) and Zombie.coords(GetEntityCoords(r.entity)))
        if pos then
            local netId = r.net or (type(NetworkGetNetworkIdFromEntity)=='function' and NetworkGetNetworkIdFromEntity(r.entity)) or 0
            if type(GetPlayers) == 'function' then
                for _, target in ipairs(GetPlayers()) do
                    target = tonumber(target)
                    if target and target ~= killerSrc and (not GetPlayerRoutingBucket or GetPlayerRoutingBucket(target) == r.bucket) then
                        TriggerClientEvent('thehunt_zombie:ambient', target, r.id, netId, chosenSound, pos, ZombieConfig.AmbientSoundRange, 'death')
                    end
                end
            end
        end
    end
end
RegisterNetEvent('thehunt_zombie:pedDied',function(id, clientSound)
    local r=ZS.peds[id]
    if not r then return end
    local ownerMatches = r.creator == source or r.lastOwner == source
    if ZS.exists(r) then ownerMatches = NetworkGetEntityOwner(r.entity)==source end
    if ownerMatches then ZS.markDead(id, source, clientSound) end
end)
function ZS.tick()
    local now=GetGameTimer(); local players=ZS.players()
    for id,t in pairs(ZS.tickets) do if t.expires<now or not GetPlayerName(t.owner) then ZS.cancel(id) end end
    for id,r in pairs(ZS.retired) do if r.untilTime<now then ZS.retired[id]=nil end end
    local remove={}
    for id,r in pairs(ZS.peds) do
        local loot = ZS.corpseLoot and ZS.corpseLoot[id]
        local isSearching = loot and loot.activeSearchers and next(loot.activeSearchers) ~= nil
        if not ZS.exists(r) then
            if isSearching then
                -- Никогда не удаляем пока кто-то обыскивает
            elseif r.dead and (now - (r.diedAt or 0) <= C.CorpseLifetime) then
                -- Труп еще валиден в пределах времени жизни
            else
                remove[#remove+1]=id
            end
        else
            local currentOwner = NetworkGetEntityOwner(r.entity)
            if currentOwner and currentOwner > 0 then r.lastOwner=currentOwner end
            local pos=GetEntityCoords(r.entity)
            local hasValidCoords = (math.abs(pos.x)>0.1 or math.abs(pos.y)>0.1)
            if hasValidCoords then r.position=Zombie.coords(pos) end
            local checkPos = hasValidCoords and pos or r.home
            local z = ZS.zones[r.zone]
            local isPlayerNear = ZS.nearest(checkPos,r.bucket,players,C.EntityKeepDistance)
                or (z and ZS.nearest(z,r.bucket,players,(z.activation or 180)+50))
            if isPlayerNear then r.lastNear=now end
            
            if isSearching then
                -- Удерживаем труп пока идет обыск
                r.diedAt = now
            elseif r.dead then
                local isEmpty = not loot or not loot.items or #loot.items == 0
                local isAllSearched = (loot and loot.allSearched == true)
                local emptyExpired = isAllSearched and isEmpty and loot and loot.emptiedAt and (now - tonumber(loot.emptiedAt) >= 30000)
                local expired = (now - (r.diedAt or 0) > C.CorpseLifetime)
                if emptyExpired or expired then
                    remove[#remove+1]=id
                end
            elseif now-(r.lastNear or now)>C.DespawnGrace then
                remove[#remove+1]=id
            end
        end
    end
    for _,id in ipairs(remove) do ZS.remove(id,'stream') end
    if ZS.cleanupCorpseLoot then ZS.cleanupCorpseLoot(now) end
    if ZS.paused then return end
    local budget=C.SpawnPerTick
    for id,z in pairs(ZS.zones) do
        local rt=ZS.runtime[id]
        local owner=z.enabled and ZS.nearest(z,z.bucket,players,z.activation)
        if owner then
            if not rt.active then
                rt.active=true
                rt.desired=z.randomCount and math.random(z.minCount,z.maxCount) or z.count
            end
            if budget>0 and os.time()>=(rt.nextSpawn or 0) and ZS.count(id)<rt.desired then
                if ZS.spawn(id,owner,players) then budget=budget-1 end
            end
        else rt.active=false end
    end
    if ZS.migrate then ZS.migrate(now,players) end
end
AddEventHandler('playerDropped',function()
    local src=source; ZS.immune[src]=nil; TriggerClientEvent('thehunt_zombie:immunity',-1,src,false); ZS.info[src]=nil; ZS.debug[src]=nil
    for id,t in pairs(ZS.tickets) do if t.owner==src then ZS.cancel(id) end end
    -- Existing entities migrate through OneSync. Never spawn a replacement just because an owner left.
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    ZS.clear(nil,'stop')
    if ZS.clearCorpseLoot then ZS.clearCorpseLoot() end
    for src in pairs(ZS.immune) do if GetPlayerName(src) then Player(src).state:set('huntZombieImmune',false,true) end end
end)
