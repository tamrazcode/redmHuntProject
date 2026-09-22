function ZS.migrate(now,players)
    local groups={}
    for _,r in pairs(ZS.peds) do
        if r.destination and not r.dead and ZS.exists(r) then
            groups[r.group]=true
            if Zombie.distance(GetEntityCoords(r.entity),r.goal)<8 then
                local z=ZS.zones[r.destination]
                if z then r.zone=r.destination; r.home=Zombie.coords(z); r.radius=z.radius end
                r.destination=nil; r.goal=nil; r.group=nil; ZS.publish(r)
            elseif now-r.migrationStarted>ZombieConfig.MigrationLifetime then
                r.destination=nil; r.goal=nil; r.group=nil; ZS.publish(r)
            end
        end
    end
    local count=0; for _ in pairs(groups) do count=count+1 end
    if count>=ZombieConfig.MaxMigrations then return end
    for id,z in pairs(ZS.zones) do
        local rt=ZS.runtime[id]
        if z.enabled and z.migration and rt.active and now>=(rt.nextMigration or 0) then
            rt.nextMigration=now+z.migrationInterval*1000+math.random(0,15000)
            if math.random()<z.migrationChance then
                local destinations={}
                for target,d in pairs(ZS.zones) do
                    if target~=id and d.enabled and d.bucket==z.bucket and d.migration
                        and Zombie.distance(z,d)<ZombieConfig.MaxMigrationDistance and ZS.count(target)<d.maxCount then
                        destinations[#destinations+1]=target
                    end
                end
                if #destinations>0 then
                    local target=destinations[math.random(#destinations)]; local dest=ZS.zones[target]
                    local size=math.min(z.migrationSize,dest.maxCount-ZS.count(target)); local sent=0
                    local group=id..':'..now
                    for _,r in pairs(ZS.peds) do
                        if sent>=size then break end
                        if r.zone==id and r.settings.migration and not r.dead and not r.destination
                            and r.state~='CHASE' and r.state~='ATTACK' and r.state~='ALERT' then
                            r.destination=target; r.goal=Zombie.point(dest,math.min(dest.radius,10))
                            r.group=group; r.migrationStarted=now; ZS.publish(r); sent=sent+1
                        end
                    end
                    if sent>0 then ZS.cooldown(id,z.replenish); count=count+1 end
                    if count>=ZombieConfig.MaxMigrations then return end
                end
            end
        end
    end
end
