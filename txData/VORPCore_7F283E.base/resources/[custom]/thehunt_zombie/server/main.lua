local requests,noiseRate,syncRate,busy,ambientRate={},{},{},{},{}
local function admin(src) return exports.thehunt_core:IsPlayerAdmin(src)==true end
local function reply(src,request,ok,data) TriggerClientEvent('thehunt_zombie:reply',src,request,ok,data) end
local function setImmune(src,value)
    if not GetPlayerName(src) then return false end
    ZS.immune[src]=value==true or nil
    Player(src).state:set('huntZombieImmune',value==true,true)
    TriggerClientEvent('thehunt_zombie:immunity',-1,src,value==true)
    return true
end
local function zoneList()
    local out={}
    for id,z in pairs(ZS.zones) do
        local row=Zombie.copy(z); row.id=id; row.revision=z.revision
        row.alive=ZS.count(id); row.active=ZS.runtime[id].active or false
        row.error=ZS.runtime[id].error; row.cooldown=math.max(0,(ZS.runtime[id].nextSpawn or 0)-os.time())
        out[#out+1]=row
    end
    table.sort(out,function(a,b)return a.id<b.id end); return out
end
local function snapshot(src)
    local peds={}; for _,r in pairs(ZS.peds) do peds[#peds+1]=ZS.public(r) end
    TriggerClientEvent('thehunt_zombie:snapshot',src,peds,ZS.immune,ZS.epoch)
end
RegisterNetEvent('thehunt_zombie:sync',function()
    local src=source; local now=GetGameTimer()
    if not ZS.ready or now<(syncRate[src] or 0) then return end
    syncRate[src]=now+3000; snapshot(src)
end)
RegisterNetEvent('thehunt_zombie:request',function(request,action,args)
    local src=source; local now=GetGameTimer()
    if type(request)~='number' or type(action)~='string' or type(args)~='table' then return end
    if not admin(src) then reply(src,request,false,'Недостаточно прав'); return end
    local rate=requests[src]
    if not rate or now-rate.at>1000 then rate={at=now,count=0}; requests[src]=rate end
    rate.count=rate.count+1
    if rate.count>10 then reply(src,request,false,'Слишком часто'); return end
    local ok,result=pcall(function()
        assert(ZS.ready,'База данных ещё не готова')
        if action=='list' then
            return {zones=zoneList(),profiles=ZombieConfig.Profiles,models=ZombieModels,
                defaults=Zombie.defaults,paused=ZS.paused,immune=ZS.immune[src]==true,
                info=ZS.info[src]==true,debug=ZS.debug[src]==true,total=ZS.count()}
        elseif action=='info' or action=='debug' then
            local registry=action=='info' and ZS.info or ZS.debug
            registry[src]=not registry[src] or nil
            TriggerClientEvent('thehunt_zombie:adminFlags',src,ZS.info[src]==true,ZS.debug[src]==true)
            return {enabled=registry[src]==true}
        elseif action=='immunity' then
            local target=args.target and math.floor(Zombie.number(args.target,1,65535)) or src
            local value=args.enabled
            if value==nil then value=not ZS.immune[target] end
            assert(type(value)=='boolean','Некорректное значение')
            assert(setImmune(target,value),'Игрок не найден')
            return {target=target,enabled=ZS.immune[target]==true}
        elseif action=='pause' then
            ZS.paused=not ZS.paused
            if ZS.paused then ZS.clear(nil,'pause') end
            return {paused=ZS.paused}
        elseif action=='save' then
            local z=Zombie.validate(args.zone)
            local id=args.id and math.floor(Zombie.number(args.id,1,2147483647)) or nil
            if id then
                local old=ZS.zones[id]; assert(old,'Зона не найдена')
                assert(not busy[id],'Зона уже сохраняется')
                assert(args.revision==old.revision,'Зона изменена другим администратором. Обновите список')
                busy[id]=true
                local success,changed=pcall(MySQL.update.await,
                    'UPDATE thehunt_zombie_zones SET data=?, revision=revision+1 WHERE id=? AND revision=?',
                    {json.encode(z),id,args.revision})
                busy[id]=nil; assert(success and changed==1,'Не удалось сохранить: конфликт или ошибка БД')
                z.revision=old.revision+1; ZS.clear(id,'edit')
            else
                local count=0; for _ in pairs(ZS.zones) do count=count+1 end
                assert(count<ZombieConfig.MaxZones,'Лимит зон')
                id=MySQL.insert.await('INSERT INTO thehunt_zombie_zones (data) VALUES (?)',{json.encode(z)})
                assert(id,'Ошибка сохранения'); z.revision=1
            end
            ZS.zones[id]=z
            ZS.runtime[id]=ZS.runtime[id] or {nextSpawn=0}
            local players=ZS.players()
            local owner=z.enabled and ZS.nearest(z,z.bucket,players,z.activation)
            ZS.runtime[id].active=owner~=nil
            ZS.runtime[id].desired=z.randomCount and math.random(z.minCount,z.maxCount) or z.count
            ZS.runtime[id].badModels=nil; ZS.runtime[id].error=nil
            ZS.runtime[id].nextSpawn=0; ZS.runtime[id].dirty=true
            ZS.runtime[id].nextMigration=GetGameTimer()+z.migrationInterval*1000
            return {id=id,revision=z.revision}
        else
            local id=math.floor(Zombie.number(args.id,1,2147483647)); local z=ZS.zones[id]
            assert(z,'Зона не найдена')
            if action=='delete' then
                assert(not busy[id] and args.revision==z.revision,'Зона изменена. Обновите список')
                busy[id]=true
                local success,changed=pcall(MySQL.update.await,'DELETE FROM thehunt_zombie_zones WHERE id=? AND revision=?',{id,z.revision})
                busy[id]=nil; assert(success and changed==1,'Не удалось удалить зону')
                ZS.clear(id,'delete'); ZS.zones[id]=nil; ZS.runtime[id]=nil
            elseif action=='clear' then ZS.clear(id,'admin'); ZS.cooldown(id,z.respawn)
            elseif action=='spawn' then
                assert(not ZS.paused,'Система остановлена')
                assert(z.enabled,'Зона выключена')
                local ped=GetPlayerPed(src)
                assert(ped~=0 and GetPlayerRoutingBucket(src)==z.bucket and Zombie.distance(GetEntityCoords(ped),z)<z.activation,'Подойдите к зоне')
                local rt=ZS.runtime[id]; rt.active=true; rt.desired=z.randomCount and math.random(z.minCount,z.maxCount) or z.count
                rt.nextSpawn=0; rt.dirty=true
                local players=ZS.players()
                local ticket=ZS.spawn(id,src,players)
                assert(ticket,'Спавн отложен: лимит населения/заявок или нет безопасной точки')
            elseif action=='teleport' then
                assert(GetPlayerRoutingBucket(src)==z.bucket,'Зона в другом измерении')
                TriggerClientEvent('thehunt_zombie:teleport',src,Zombie.coords(z))
            else error('Неизвестное действие') end
            return {ok=true}
        end
    end)
    reply(src,request,ok,ok and result or tostring(result))
end)

RegisterNetEvent('thehunt_zombie:report',function(batch)
    local src=source
    if type(batch)~='table' or #batch>ZombieConfig.MaxAlive then return end
    local now=GetGameTimer()
    local states={IDLE=true,WANDER=true,INVESTIGATE_SOUND=true,ALERT=true,CHASE=true,SEARCH=true,ATTACK=true,MIGRATION=true,RETURN=true}
    for _,data in ipairs(batch) do
        local r=type(data)=='table' and ZS.peds[data.id]
        if r and ZS.exists(r) and NetworkGetEntityOwner(r.entity)==src and now-r.lastReport>=1500 then
            r.lastReport=now; r.state=states[data.state] and data.state or 'IDLE'; r.target=tonumber(data.target)
            -- Debug never feeds perception or player tracking.
            local last
            if type(data.last)=='table' then
                local ok,pos=pcall(function() return {x=Zombie.number(data.last.x,-20000,20000),
                    y=Zombie.number(data.last.y,-20000,20000),z=Zombie.number(data.last.z,-1000,3000)} end)
                if ok then last=pos end
            end
            r.debug={state=r.state,target=r.target,reason=tostring(data.reason or ''):sub(1,40),last=last}
        end
    end
end)

function ZS.noise(pos,radius,bucket,kind,player)
    radius=math.min(radius,ZombieConfig.MaxNoiseDistance)
    local owners={}
    for _,r in pairs(ZS.peds) do
        if not r.dead and r.bucket==bucket and ZS.exists(r)
            and Zombie.distance(r.position or GetEntityCoords(r.entity),pos)<=math.min(radius*r.settings.hearing*1.15,r.settings.hearingDistance)+3 then
            local owner=NetworkGetEntityOwner(r.entity); if owner and owner>0 then owners[owner]=true end
        end
    end
    for owner in pairs(owners) do TriggerClientEvent('thehunt_zombie:noise',owner,pos,radius,kind,player) end
end

RegisterNetEvent('thehunt_zombie:noise',function(kind,weapon)
    local src=source; local now=GetGameTimer()
    -- Immunity suppresses hostile targeting, not the physical sound a player
    -- creates. Zombies may still investigate a gunshot from an immune player.
    if not ZS.ready or ZS.paused or not ZombieConfig.Noise[kind] then return end
    if ZS.immune[src] and kind~='shot' then return end
    local key=src..':'..kind; if now<(noiseRate[key] or 0) then return end
    noiseRate[key]=now+(kind=='shot' and 250 or 900)
    local ped=GetPlayerPed(src); if ped==0 or not DoesEntityExist(ped) then return end
    local radius=ZombieConfig.Noise[kind]
    if kind=='shot' and type(weapon)=='number' then
        for name,mult in pairs(ZombieConfig.WeaponNoise) do if GetHashKey(name)==weapon then radius=radius*mult; break end end
    elseif kind=='voice' then
        local prox=Player(src).state.proximity
        local d=type(prox)=='table' and tonumber(prox.distance) or nil
        if d and d==d then radius=math.max(2,math.min(40,d))*ZombieConfig.VoiceMultiplier end
    end
    ZS.noise(Zombie.coords(GetEntityCoords(ped)),radius,GetPlayerRoutingBucket(src),kind,src)
end)
local function ambientFileAllowed(file)
    if type(file) ~= 'string' or not file:find('%.mp3$') then return false end
    for _,gender in pairs(ZombieConfig.AmbientSounds or {}) do
        for _,sounds in pairs(gender) do
            for _,candidate in ipairs(sounds) do if candidate==file then return true end end
        end
    end
    return true
end
RegisterNetEvent('thehunt_zombie:ambient',function(id,file,stage)
    local src=source; local now=GetGameTimer(); local r=ZS.peds[tostring(id)] or ZS.peds[id]
    if not r or r.dead or not ZS.exists(r) or not ambientFileAllowed(file) then return end
    if now<(ambientRate[r.id] or 0) then return end
    ambientRate[r.id]=now+900
    local pos=Zombie.coords(GetEntityCoords(r.entity))
    local netId=r.net or (type(NetworkGetNetworkIdFromEntity)=='function' and NetworkGetNetworkIdFromEntity(r.entity)) or 0
    for _,target in ipairs(GetPlayers()) do
        target=tonumber(target)
        if target and target~=src and GetPlayerRoutingBucket(target)==r.bucket then
            TriggerClientEvent('thehunt_zombie:ambient',target,r.id,netId,file,pos,ZombieConfig.AmbientSoundRange,stage)
        end
    end
end)

exports('IsZombie',function(entity)
    for _,r in pairs(ZS.peds) do if r.entity==entity and ZS.exists(r) then return true,r.id end end; return false
end)
exports('GetProfile',function(id) local r=ZS.peds[id]; return r and Zombie.copy(r.settings) end)
exports('SpawnZombie',function(zone)
    local z=ZS.zones[tonumber(zone)]; if not z or not z.enabled then return nil end
    local players=ZS.players(); local owner=ZS.nearest(z,z.bucket,players,z.activation)
    if owner then return ZS.spawn(tonumber(zone),owner,players) end
end)
exports('RemoveZombie',ZS.remove)
exports('SetPlayerAggression',function(src,enabled) return setImmune(tonumber(src),enabled==false) end)
exports('RegisterNoise',function(pos,radius,bucket)
    assert(type(pos)=='table','coords required')
    local p={x=Zombie.number(pos.x,-20000,20000),y=Zombie.number(pos.y,-20000,20000),z=Zombie.number(pos.z,-1000,3000)}
    ZS.noise(p,Zombie.number(radius,0,300),tonumber(bucket) or 0,'action')
end)
exports('GetNearbyZombies',function(pos,radius,bucket)
    local out={}; for _,r in pairs(ZS.peds) do
        if not r.dead and r.bucket==(bucket or 0) and ZS.exists(r) and Zombie.distance(pos,GetEntityCoords(r.entity))<=radius then out[#out+1]=ZS.public(r) end
    end; return out
end)

MySQL.ready(function()
    local ok,err=pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS thehunt_zombie_zones (
            id INT AUTO_INCREMENT PRIMARY KEY, data LONGTEXT NOT NULL,
            revision INT NOT NULL DEFAULT 1, cooldown_until BIGINT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        for _,row in ipairs(MySQL.query.await('SELECT * FROM thehunt_zombie_zones')) do
            local valid,z=pcall(function() return Zombie.validate(json.decode(row.data)) end)
            if valid then
                z.revision=row.revision; ZS.zones[row.id]=z
                ZS.runtime[row.id]={nextSpawn=tonumber(row.cooldown_until) or 0,nextMigration=GetGameTimer()+z.migrationInterval*1000+math.random(15000)}
            else print(('[thehunt_zombie] Invalid stored zone %s: %s'):format(row.id,z)) end
        end
        -- Crash/restart recovery: only tagged entities from this resource, never model-based deletion.
        local playerPeds={}; for _,src in ipairs(GetPlayers()) do playerPeds[GetPlayerPed(tonumber(src))]=true end
        for _,ped in ipairs(GetAllPeds()) do
            if not playerPeds[ped] and Entity(ped).state.huntZombie then DeleteEntity(ped) end
        end
        for _,src in ipairs(GetPlayers()) do Player(tonumber(src)).state:set('huntZombieImmune',false,true) end
        ZS.ready=true; TriggerClientEvent('thehunt_zombie:reset',-1,ZS.epoch)
        print(('[thehunt_zombie] Ready; population cap %d'):format(ZombieConfig.MaxAlive))
    end)
    if not ok then print('[thehunt_zombie] Startup failed: '..tostring(err)) end
end)

CreateThread(function()
    while true do
        Wait(ZombieConfig.ServerTick)
        local ok,err=pcall(ZS.tick)
        if not ok then print('[thehunt_zombie] Population error: '..tostring(err)); Wait(5000) end
        for id,rt in pairs(ZS.runtime) do
            if rt.dirty then
                rt.dirty=false
                local success=pcall(MySQL.update.await,'UPDATE thehunt_zombie_zones SET cooldown_until=? WHERE id=?',{rt.nextSpawn or 0,id})
                if not success then rt.dirty=true end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        for src in pairs(ZS.debug) do
            if not admin(src) then ZS.debug[src]=nil; ZS.info[src]=nil; TriggerClientEvent('thehunt_zombie:adminFlags',src,false,false)
            else
                local list={}; for id,r in pairs(ZS.peds) do list[id]=r.debug or {state=r.state} end
                TriggerClientEvent('thehunt_zombie:debug',src,list)
            end
        end
        for src in pairs(ZS.info) do if not admin(src) then ZS.info[src]=nil; TriggerClientEvent('thehunt_zombie:adminFlags',src,false,false) end end
    end
end)

AddEventHandler('playerDropped',function()
    local src=source; requests[src]=nil; syncRate[src]=nil
    for kind in pairs(ZombieConfig.Noise) do noiseRate[src..':'..kind]=nil end
end)

-- Recover unacknowledged creations after an owner crash and retry failed engine deletion.
-- A slow server-only sweep; normal AI never enumerates the world ped pool.
CreateThread(function()
    while true do
        Wait(10000)
        if ZS.ready then
            local playerPeds={}; for _,src in ipairs(GetPlayers()) do playerPeds[GetPlayerPed(tonumber(src))]=true end
            for _,ped in ipairs(GetAllPeds()) do
                if DoesEntityExist(ped) and not playerPeds[ped] then
                    if Entity(ped).state.huntNecroServant or (ZS.servants and ZS.servants[ped]) then
                        -- Поднят некромантом: больше не числится в популяции, педа не трогаем.
                    else
                    local tag=Entity(ped).state.huntZombie
                    if type(tag)=='table' and type(tag.id)=='string' then
                        local r,t=ZS.peds[tag.id],ZS.tickets[tag.id]
                        if (not r or r.entity~=ped) and not t then DeleteEntity(ped) end
                    end
                    end
                end
            end
        end
    end
end)
