ZC={peds={},byNet={},pending={},localPeds={},localPedsByNet={},cancelled={},immune={},players={},debugData={},epoch=nil,info=false,debug=false}
function ZC.entity(r)
    if not r then return nil end
    if r.ped and DoesEntityExist(r.ped) then
        local tag = Entity(r.ped).state.huntZombie
        if tag and tag.id == r.id then return r.ped end
    end
    r.ped = nil
    if r.id and ZC.localPeds[r.id] and DoesEntityExist(ZC.localPeds[r.id]) then
        local tag = Entity(ZC.localPeds[r.id]).state.huntZombie
        if tag and tag.id == r.id then
            r.ped = ZC.localPeds[r.id]
            return r.ped
        end
    end
    if r.net and ZC.localPedsByNet[r.net] and DoesEntityExist(ZC.localPedsByNet[r.net]) then
        local tag = Entity(ZC.localPedsByNet[r.net]).state.huntZombie
        if tag and tag.id == r.id then
            r.ped = ZC.localPedsByNet[r.net]
            return r.ped
        end
    end
    if r.net and r.net > 0 and NetworkDoesNetworkIdExist(r.net) then
        local ped = (type(NetToPed) == 'function') and NetToPed(r.net) or NetworkGetEntityFromNetworkId(r.net)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local tag = Entity(ped).state.huntZombie
            if tag and tag.id == r.id then
                r.ped = ped
                return ped
            end
        end
    end
    return nil
end
function ZC.applyWalkStyle(ped, style)
    if not ped or not DoesEntityExist(ped) then return end
    if type(IsEntityDead) == 'function' and IsEntityDead(ped) then return end
    local walk = style or 'MP_Style_drunk'
    if walk == 'none' or walk == 'default' then return end
    pcall(function()
        Citizen.InvokeNative(0xCB9401F918CB0F75, ped, walk, 1, -1)
    end)
end
function ZC.configure(ped,settings,initial,weapon)
    local zombieGroup = GetHashKey('HUNT_ZOMBIE')
    if not ZC.relationshipReady and type(AddRelationshipGroup) == 'function' then
        AddRelationshipGroup('HUNT_ZOMBIE')
        if type(SetRelationshipBetweenGroups) == 'function' then
            SetRelationshipBetweenGroups(0, zombieGroup, zombieGroup)
        end
        ZC.relationshipReady = true
    end
    SetPedRelationshipGroupHash(ped, zombieGroup)
    local playerGroup = (type(PlayerPedId) == 'function' and type(GetPedRelationshipGroupHash) == 'function') and GetPedRelationshipGroupHash(PlayerPedId()) or nil
    if type(SetRelationshipBetweenGroups) == 'function' then
        SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), zombieGroup)
        SetRelationshipBetweenGroups(5, zombieGroup, GetHashKey('PLAYER'))
        if playerGroup and playerGroup ~= 0 then
            SetRelationshipBetweenGroups(5, playerGroup, zombieGroup)
            SetRelationshipBetweenGroups(5, zombieGroup, playerGroup)
        end
    end

    -- Explicit combat tasks own aggression; neutral groups preserve stealth and immunity.
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedCanBeTargetted(ped, true)
    SetPedCanBeTargettedByPlayer(ped, PlayerId(), true)
    SetPedCanRagdoll(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, true)
    SetEntityCanBeDamaged(ped, true)
    SetEntityInvincible(ped, false)
    SetEntityProofs(ped, 0, false)
    SetEntityCollision(ped, true, true)

    local assignedWeapon = weapon or (settings and (settings.chosenWeapon or settings.weapon))
    if assignedWeapon and assignedWeapon ~= 'none' then
        local wHash = (type(assignedWeapon) == 'string') and GetHashKey(assignedWeapon) or assignedWeapon
        if wHash and wHash ~= 0 then
            pcall(function()
                RemoveAllPedWeapons(ped, true, true)
                Citizen.InvokeNative(0x5E3BDDBCB83F3D84, ped, wHash, 0, true, false, 0, false, 0.5, 1.0, 0, false, 0.0, false)
            end)
        end
    else
        pcall(RemoveAllPedWeapons, ped, true, true)
    end

    SetPedCombatAttributes(ped, 46, true) -- BF_CanFightArmedPedsWhenNotArmed
    SetPedCombatAttributes(ped, 5, true)  -- BF_AlwaysFight
    SetPedCombatAttributes(ped, 0, false) -- BF_CanUseCover = false
    SetPedCombatAttributes(ped, 13, false) -- CA_CAN_USE_DYNAMIC_STRAFE_DECISIONS = false (Prevents circling around target)
    SetPedCombatAttributes(ped, 14, false) -- CA_CAN_USE_TACTICAL_POINTS = false (Prevents tactical circling/angles)
    SetPedCombatAttributes(ped, 17, false) -- CA_ALWAYS_FLEE must be disabled
    SetPedCombatAttributes(ped, 21, true) -- CA_CAN_CHASE_TARGET_ON_FOOT
    SetPedCombatAttributes(ped, 22, true) -- CA_CAN_DRAG_PED_FROM_CAR (Allows pulling riders off mounts/vehicles)
    SetPedCombatAttributes(ped, 28, true) -- CA_CAN_USE_FRUSTRATED_ADVANCE
    SetPedCombatAttributes(ped, 31, false) -- Do not keep distance from a melee target
    SetPedCombatAttributes(ped, 52, false) -- CA_CAN_USE_PEEKING = false
    SetPedCombatAttributes(ped, 71, true)  -- CA_CAN_USE_MELEE_TAKEDOWNS = true
    SetPedCombatAttributes(ped, 93, true) -- CA_PREFER_MELEE
    SetPedCombatAttributes(ped, 114, false) -- No execution bypass of configured damage
    SetPedCombatMovement(ped, 3)          -- Suicidal Offensive (rushes into contact and attacks relentlessly)
    SetPedCombatRange(ped, 0)             -- Melee range
    SetPedCombatAbility(ped, 100)         -- Maximum combat ability
    SetPedFleeAttributes(ped, 0, false)   -- Never flee
    -- Allow 2 peds to simultaneously engage in active melee combat
    if type(SetPedMeleeCombatLimits) == 'function' then
        SetPedMeleeCombatLimits(2, 2, 2)
    else
        pcall(Citizen.InvokeNative, 0x8E51EC29, 2, 2, 2)
    end

    local targetDmg = tonumber((settings and settings.damage) or 18) or 18
    local hasWeapon = assignedWeapon and assignedWeapon ~= 'none' and assignedWeapon ~= 'WEAPON_UNARMED'
    local weaponDmg = nil
    if hasWeapon then
        if settings and tonumber(settings.weaponDamage) then
            weaponDmg = tonumber(settings.weaponDamage)
        elseif ZombieConfig.WeaponDamage then
            weaponDmg = ZombieConfig.WeaponDamage[assignedWeapon]
                or (type(assignedWeapon) == 'string' and ZombieConfig.WeaponDamage[string.lower(assignedWeapon)])
                or (type(assignedWeapon) == 'string' and ZombieConfig.WeaponDamage[string.upper(assignedWeapon)])
        end
    end
    if weaponDmg then targetDmg = tonumber(weaponDmg) or targetDmg end

    -- Base RedM fist damage is ~8-10 HP on a 600 HP player pool.
    -- Base RedM knife / melee weapon slash is ~25-30 HP on a 600 HP player pool.
    -- Scale modifier so configured damage matches the exact % of player health:
    -- e.g. unarmed: damage=18 -> 18% (108 HP), damage=40 -> 40% (240 HP), damage=100 -> 100% (600 HP)
    -- armed: knife targetDmg=10 -> 10% (60 HP), machete targetDmg=15 -> 15% (90 HP)
    local dmgMod = hasWeapon and math.max(0.5, targetDmg * 0.20) or math.max(1.0, targetDmg * 0.75)
    Citizen.InvokeNative(0xD77AE48611B7B10A, ped, dmgMod) -- SET_PED_TO_PLAYER_WEAPON_DAMAGE_MODIFIER
    if type(SetPedWeaponDamageModifier) == 'function' then SetPedWeaponDamageModifier(ped, dmgMod) end
    if type(SetPedDamageModifier) == 'function' then SetPedDamageModifier(ped, dmgMod) end
    pcall(Citizen.InvokeNative, 0xA60D104D1E7B2A2D, ped, dmgMod) -- SET_PED_DAMAGE_MODIFIER
    -- Optional natives vary by RedM artifact and must never stop AI setup.
    if type(SetCombatFloat) == 'function' then
        SetCombatFloat(ped, 42, 0.0)
        SetCombatFloat(ped, 43, 0.0)
    end
    if type(SetCurrentPedWeapon) == 'function' then
        local equipped = assignedWeapon
        if not equipped or equipped == 'none' then equipped = 'WEAPON_UNARMED' end
        local equippedHash = type(equipped) == 'number' and equipped or GetHashKey(equipped)
        SetCurrentPedWeapon(ped, equippedHash, true, 0, false, false)
    end
    SetPedSeeingRange(ped, (settings and settings.sight) or 40.0)
    SetPedHearingRange(ped, (settings and settings.hearingDistance) or 100.0)

    Citizen.InvokeNative(0x5240864E847C691C, ped, false) -- SetPedCanBeIncapacitated = false
    local max = (settings and settings.headshotOnly and ZombieConfig.HeadshotReserve) or (settings and settings.health) or 350
    SetPedMaxHealth(ped, max)
    if initial then SetEntityHealth(ped, max, 0) end
    local walkStyle = (settings and (settings.chosenWalkStyle or settings.walkStyle)) or 'MP_Style_drunk'
    ZC.applyWalkStyle(ped, walkStyle)
end
local function deletePending(id)
    local p=ZC.pending[id]
    local ped=(p and p.ped) or ZC.localPeds[id]
    if ped and DoesEntityExist(ped) then
        local tag=Entity(ped).state.huntZombie
        if tag and tag.id==id and NetworkHasControlOfEntity(ped) then
            SetEntityAsMissionEntity(ped,true,true); DeleteEntity(ped)
        end
    end
    ZC.pending[id]=nil
    ZC.localPeds[id]=nil
end
RegisterNetEvent('thehunt_zombie:spawn',function(t)
    if source~=65535 then return end
    if ZC.pending[t.id] or ZC.cancelled[t.id] then return end
    local p={expires=GetGameTimer()+ZombieConfig.SpawnTimeout}; ZC.pending[t.id]=p
    CreateThread(function()
        local model=GetHashKey(t.model)
        if not IsModelValid(model) or not IsModelAPed(model) then
            TriggerServerEvent('thehunt_zombie:spawnResult',t.id,0,'model'); ZC.pending[t.id]=nil; return
        end
        RequestModel(model)
        local deadline=GetGameTimer()+7000
        while not HasModelLoaded(model) and GetGameTimer()<deadline and not ZC.cancelled[t.id] do Wait(50) end
        if not HasModelLoaded(model) or ZC.cancelled[t.id] then
            SetModelAsNoLongerNeeded(model); TriggerServerEvent('thehunt_zombie:spawnResult',t.id,0,'timeout'); deletePending(t.id); return
        end
        local function probeGround(x, y, baseZ)
            local found, ground = GetGroundZFor_3dCoord(x, y, baseZ + 45.0, false)
            if not found then found, ground = GetGroundZFor_3dCoord(x, y, baseZ + 15.0, false) end
            if not found then found, ground = GetGroundZFor_3dCoord(x, y, baseZ + 2.0, false) end
            return found, ground
        end
        RequestCollisionAtCoord(t.pos.x,t.pos.y,t.pos.z)
        local found,ground=probeGround(t.pos.x,t.pos.y,t.pos.z)
        local groundDeadline=GetGameTimer()+1500
        while not found and GetGameTimer()<groundDeadline and not ZC.cancelled[t.id] do
            Wait(100); RequestCollisionAtCoord(t.pos.x,t.pos.y,t.pos.z)
            found,ground=probeGround(t.pos.x,t.pos.y,t.pos.z)
        end
        if ZC.cancelled[t.id] then SetModelAsNoLongerNeeded(model); deletePending(t.id); return end
        if not found then
            TriggerServerEvent('thehunt_zombie:spawnResult',t.id,0,'ground'); SetModelAsNoLongerNeeded(model); deletePending(t.id); return
        end
        local pos={x=t.pos.x,y=t.pos.y,z=ground+0.15}
        local safe,safePos=GetSafeCoordForPed(pos.x,pos.y,pos.z,false,16)
        if safe and safePos and safePos.x~=0.0 and Zombie.distance2D(pos,safePos)<=12.0
            and (not t.home or Zombie.distance2D(safePos,t.home)<=t.spawnRadius) then
            pos=Zombie.coords(safePos)
        end
        local minSafeDist = math.min(ZombieConfig.MinSpawnDistance, math.max(1.5, (t.spawnRadius or 20) * 0.4))
        for _,player in ipairs(GetActivePlayers()) do
            local ped=GetPlayerPed(player)
            if DoesEntityExist(ped) and Zombie.distance(pos,GetEntityCoords(ped))<minSafeDist then
                TriggerServerEvent('thehunt_zombie:spawnResult',t.id,0,'near'); SetModelAsNoLongerNeeded(model); deletePending(t.id); return
            end
        end
        local ped=CreatePed(model,pos.x,pos.y,pos.z,math.random()*360,true,true,false,false)
        if not ped or ped==0 then TriggerServerEvent('thehunt_zombie:spawnResult',t.id,0,'create'); SetModelAsNoLongerNeeded(model); deletePending(t.id); return end
        p.ped=ped
        ZC.localPeds[t.id]=ped
        -- Set before the first yield: world_cleaner must never race initial appearance/network setup.
        Entity(ped).state:set('huntZombie',{id=t.id,pending=true},true)
        Entity(ped).state:set('isProtected',true,true)
        SetEntityAsMissionEntity(ped,true,true)
        FreezeEntityPosition(ped,false)
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4,ped,t.outfit,false)
        Citizen.InvokeNative(0xCC8CA3E88256E58F,ped,false,true,true,true,false)
        ZC.configure(ped,t.settings,true,t.weapon or (t.settings and t.settings.chosenWeapon))
        ZC.applyWalkStyle(ped, (t.settings and (t.settings.chosenWalkStyle or t.settings.walkStyle)) or 'MP_Style_drunk')
        ClearPedTasksImmediately(ped)
        TaskStandStill(ped, -1)
        SetModelAsNoLongerNeeded(model)
        local net=NetworkGetNetworkIdFromEntity(ped)
        if net and net>0 then
            ZC.localPedsByNet[net]=ped
        end
        TriggerServerEvent('thehunt_zombie:spawnResult',t.id,net)
        p.expires=GetGameTimer()+ZombieConfig.SpawnTimeout
    end)
end)
RegisterNetEvent('thehunt_zombie:committed',function(id)
    if source~=65535 then return end
    local p=ZC.pending[id]
    if p and p.ped and DoesEntityExist(p.ped) then
        FreezeEntityPosition(p.ped,false)
    end
    ZC.pending[id]=nil
end)
RegisterNetEvent('thehunt_zombie:cancel',function(id)
    if source~=65535 then return end
    ZC.cancelled[id]=GetGameTimer()+60000; deletePending(id)
end)
local function upsert(data)
    local pending = ZC.pending[data.id]
    if pending and pending.ped and DoesEntityExist(pending.ped) then
        FreezeEntityPosition(pending.ped, false)
    end
    local ped = (pending and pending.ped) or ZC.localPeds[data.id] or (data.net and ZC.localPedsByNet[data.net])
    if (not ped or not DoesEntityExist(ped)) and data.net and data.net>0 and NetworkDoesEntityExistWithNetworkId(data.net) then
        local netPed = NetworkGetEntityFromNetworkId(data.net)
        if netPed and netPed~=0 and DoesEntityExist(netPed) then
            ped = netPed
        end
    end
    if ped and DoesEntityExist(ped) then
        data.ped=ped
        ZC.localPeds[data.id]=ped
        if data.net then ZC.localPedsByNet[data.net]=ped end
        local walk = (data.settings and (data.settings.chosenWalkStyle or data.settings.walkStyle)) or 'MP_Style_drunk'
        ZC.applyWalkStyle(ped, walk)
    end
    ZC.pending[data.id]=nil
    if data.net then ZC.byNet[data.net]=data.id end
    local r=ZC.peds[data.id]
    if r then
        for k,v in pairs(data) do r[k]=v end
        r.destination=data.destination; r.goal=data.goal
        if data.weapon then r.weapon=data.weapon end
        if data.ped then r.ped=data.ped end
    else
        data.nextTick=GetGameTimer()+math.random(300)
        data.state='WANDER'
        data.since=GetGameTimer()
        data.variance=0.85+math.random()*0.3
        ZC.peds[data.id]=data
    end
end
RegisterNetEvent('thehunt_zombie:upsert',function(data) if source==65535 then upsert(data) end end)
RegisterNetEvent('thehunt_zombie:remove',function(id)
    if source~=65535 then return end
    local r=ZC.peds[id]; local ped=r and ZC.entity(r)
    if ped and DoesEntityExist(ped) and NetworkHasControlOfEntity(ped) then DeleteEntity(ped) end
    if r and ZC.byNet[r.net]==id then ZC.byNet[r.net]=nil end
    if r and r.net then ZC.localPedsByNet[r.net]=nil end
    ZC.peds[id]=nil; ZC.localPeds[id]=nil; ZC.cancelled[id]=GetGameTimer()+60000; deletePending(id)
end)
RegisterNetEvent('thehunt_zombie:snapshot',function(rows,immune,epoch)
    if source~=65535 then return end
    local alive={}; ZC.byNet={}
    for _,r in ipairs(rows) do upsert(r); alive[r.id]=true end
    for id,r in pairs(ZC.peds) do
        if not alive[id] then
            ZC.localPeds[id]=nil
            if r.net then ZC.localPedsByNet[r.net]=nil end
            ZC.peds[id]=nil
        end
    end
    ZC.immune={}; for id,value in pairs(immune) do ZC.immune[tonumber(id)]=value end
    ZC.epoch=epoch
end)
RegisterNetEvent('thehunt_zombie:reset',function(epoch)
    if source~=65535 then return end
    for id in pairs(ZC.pending) do deletePending(id) end
    ZC.peds={}; ZC.byNet={}; ZC.localPeds={}; ZC.localPedsByNet={}; ZC.immune={}; ZC.info=false; ZC.debug=false; ZC.epoch=epoch
    TriggerEvent('thehunt_zombie:adminState',{zombieInfo=false,zombieImmune=false})
    TriggerServerEvent('thehunt_zombie:sync')
end)
RegisterNetEvent('thehunt_zombie:immunity',function(src,enabled)
    if source~=65535 then return end
    ZC.immune[src]=enabled or nil
    if enabled then
        for _,r in pairs(ZC.peds) do
            if r.target==src then
                r.target=nil; r.targetPed=nil; r.pursuedPed=nil; r.moveGoal=nil; r.last=nil; r.seen=nil; r.sound=nil
                r.state=r.goal and 'MIGRATION' or 'IDLE'; r.since=GetGameTimer(); r.taskAt=0
                local ped=ZC.entity(r)
                if ped and NetworkHasControlOfEntity(ped) then ClearPedTasks(ped) end
            end
            if r.sound and r.sound.player==src then r.sound=nil end
        end
    end
end)
RegisterNetEvent('thehunt_zombie:debug',function(rows) if source==65535 then ZC.debugData=rows end end)
local hits={}
ZC.contacts={}
RegisterNetEvent('thehunt_zombie:hit',function(id,net,sequence,damage,range)
    if source~=65535 or sequence<=(hits[id] or 0) then return end
    hits[id]=sequence
    ZC.contacts[id]=nil
    local r=ZC.peds[id]
    local ped=r and ZC.entity(r)
    local me=PlayerPedId()
    if not r or r.net~=net or not ped then return end
    if IsEntityDead(me) or ZC.immune[GetPlayerServerId(PlayerId())] or LocalPlayer.state.huntZombieImmune then return end
    local curHp = GetEntityHealth(me)
    local maxHp = GetEntityMaxHealth(me)
    if not maxHp or maxHp <= 0 then maxHp = 600 end
    -- RedM player peds have a 600 HP base pool. Scale damage relative to 100 HP,
    -- so configuring 40 in the menu subtracts 40% of the player's life (240 HP),
    -- and 100 subtracts 100% (instant death).
    local scale = maxHp > 100 and (maxHp / 100.0) or 1.0
    local effectiveDamage = math.floor((damage * scale) + 0.5)
    if effectiveDamage < 1 then effectiveDamage = 1 end
    local newHp = math.max(0, curHp - effectiveDamage)
    SetEntityHealth(me, newHp, 0)
    if ped and DoesEntityExist(ped) then
        ApplyDamageToPed(me, 1, false, 0, ped)
    else
        ApplyDamageToPed(me, 1, false, 0, 0)
    end
end)
function ZC.health(r,ped)
    local hp=GetEntityHealth(ped)
    if r.settings.headshotOnly then return hp>0 and r.settings.health or 0,r.settings.health end
    return math.max(0,hp),r.settings.health
end
exports('IsZombie',function(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    if Entity(ped).state.huntZombie then return true end
    local net=NetworkGetNetworkIdFromEntity(ped)
    if ZC.byNet[net] then return true end
    for _,p in pairs(ZC.pending) do if p.ped==ped then return true end end
    return false
end)
exports('GetNearbyZombies',function(pos,radius)
    local out={}; for _,r in pairs(ZC.peds) do
        local ped=ZC.entity(r)
        if ped and Zombie.distance(pos,GetEntityCoords(ped))<=radius then out[#out+1]={ped=ped,id=r.id,net=r.net,profile=r.settings.name} end
    end; return out
end)
exports('RegisterNoise',function(kind) if ZombieConfig.Noise[kind] then TriggerServerEvent('thehunt_zombie:noise',kind) end end)
CreateThread(function()
    Wait(1500); TriggerServerEvent('thehunt_zombie:sync')
    while true do
        Wait(1000)
        local now=GetGameTimer()
        for id,p in pairs(ZC.pending) do if p.expires and now>p.expires then deletePending(id) end end
        for id,t in pairs(ZC.cancelled) do if now>t then ZC.cancelled[id]=nil; hits[id]=nil end end
    end
end)
-- Reconnect / missed-delta reconciliation is infrequent and capped by the server.
CreateThread(function() while true do Wait(30000); TriggerServerEvent('thehunt_zombie:sync') end end)
-- Mounted player dismount: when a mounted player is in physical contact range with an aggroed zombie (<= 1.8m),
-- the zombie strikes/grapples the rider, TaskDismountAnimal unseats the player with authentic animations,
-- and the panicked horse flees.
local lastDismountAt = 0
function ZC.dismountLocalPlayer(zombiePed, zombieId)
    local now = GetGameTimer()
    if now - lastDismountAt < 5000 then return end
    local me = PlayerPedId()
    if not me or not DoesEntityExist(me) or IsEntityDead(me) then return end
    if not IsPedOnMount(me) and not IsPedInAnyVehicle(me, false) then return end
    lastDismountAt = now

    local horse = (type(GetMount) == 'function') and GetMount(me) or 0

    -- 1. Attacking zombie turns to face rider and conducts direct melee attack/grapple
    if zombiePed and DoesEntityExist(zombiePed) then
        if type(TaskTurnPedToFaceEntity) == 'function' then
            TaskTurnPedToFaceEntity(zombiePed, me, 1000)
        end
        if type(TaskPutPedDirectlyIntoMelee) == 'function' then
            pcall(TaskPutPedDirectlyIntoMelee, zombiePed, me, 0.0, -1.0, 0.0, 0)
        end
    end

    -- 2. Native RDR2 emergency unseat/dismount animation instead of instant limp ragdoll.
    -- TaskDismountAnimal flag 1 triggers the forced unseat/tumble off the saddle to the ground.
    if type(TaskDismountAnimal) == 'function' then
        TaskDismountAnimal(me, 1, 0, 0, 0, horse or 0)
    else
        ClearPedTasks(me)
    end

    -- 3. Horse gets spooked by the melee confrontation and flees in panic
    if horse and horse ~= 0 and DoesEntityExist(horse) then
        if zombiePed and DoesEntityExist(zombiePed) and type(TaskSmartFleePed) == 'function' then
            TaskSmartFleePed(horse, zombiePed, 40.0, 8000, 0, 3.5, 0)
        else
            ClearPedTasks(horse)
        end
    end

    -- 4. Continue pursuit & combat against the unseated player
    if zombiePed and DoesEntityExist(zombiePed) and type(TaskCombatPed) == 'function' then
        SetTimeout(700, function()
            if DoesEntityExist(zombiePed) and not IsEntityDead(zombiePed) and DoesEntityExist(me) and not IsEntityDead(me) then
                TaskCombatPed(zombiePed, me, 0, 16)
            end
        end)
    end

    if zombieId then
        local myServerId = GetPlayerServerId(PlayerId())
        if not ZC.immune[myServerId] and not LocalPlayer.state.huntZombieImmune then
            TriggerServerEvent('thehunt_zombie:attack', zombieId, myServerId)
        end
    end
end

RegisterNetEvent('thehunt_zombie:forceDismount', function(zombieId)
    if source ~= 65535 then return end
    local r = ZC.peds[zombieId]
    local zPed = r and ZC.entity(r)
    ZC.dismountLocalPlayer(zPed, zombieId)
end)

CreateThread(function()
    while true do
        local me = PlayerPedId()
        if me and DoesEntityExist(me) and not IsEntityDead(me) and (IsPedOnMount(me) or IsPedInAnyVehicle(me, false)) then
            Wait(150)
            local myPos = GetEntityCoords(me)
            local myServerId = GetPlayerServerId(PlayerId())
            if not ZC.immune[myServerId] and not LocalPlayer.state.huntZombieImmune then
                for id, r in pairs(ZC.peds) do
                    if not r.dead and r.settings and r.settings.aggression and r.settings.aggression > 0 then
                        local zPed = ZC.entity(r)
                        if zPed and DoesEntityExist(zPed) and not IsEntityDead(zPed) then
                            local dist = Zombie.distance(myPos, GetEntityCoords(zPed))
                            if dist <= 1.8 then
                                ZC.dismountLocalPlayer(zPed, id)
                                break
                            end
                        end
                    end
                end
            end
        else
            Wait(800)
        end
    end
end)

AddEventHandler('onClientResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    for id in pairs(ZC.pending) do deletePending(id) end
    for _,r in pairs(ZC.peds) do local ped=ZC.entity(r); if ped and NetworkHasControlOfEntity(ped) then DeleteEntity(ped) end end
    SetNuiFocus(false,false); SetNuiFocusKeepInput(false)
end)
