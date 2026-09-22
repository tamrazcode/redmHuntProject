Zombie = {}
function Zombie.copy(t)
    local out = {}; for k,v in pairs(t or {}) do out[k] = type(v)=='table' and Zombie.copy(v) or v end
    return out
end
function Zombie.number(v, lo, hi, fallback)
    if v == nil then v = fallback end
    local n = tonumber(v)
    assert(n and n == n and n >= lo and n <= hi, 'Число вне диапазона: '..lo..'–'..hi)
    return n
end
function Zombie.distance(a,b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
function Zombie.distance2D(a,b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
end
function Zombie.coords(p)
    return { x=p.x, y=p.y, z=p.z }
end
function Zombie.point(p, radius)
    local a,r = math.random()*math.pi*2, math.sqrt(math.random())*radius
    return {x=p.x+math.cos(a)*r,y=p.y+math.sin(a)*r,z=p.z}
end
Zombie.defaults = {
    name='Новая зона', x=0,y=0,z=0, heading=0, radius=40, height=8, activation=180, spawnRadius=30,
    count=8, minCount=6, maxCount=10, randomCount=false, randomModel=true,
    respawn=120, replenish=30, profile='ordinary', enabled=true, bucket=0,
    migration=true, migrationChance=0.25, migrationSize=3, migrationInterval=180,
    aggression=1.0, sight=38, hearing=1.0, hearingDistance=220, health=350, damage=18,
    speed=2.3, attackRange=2.4, attackCooldown=600, reaction=900,
    headshotOnly=false, fov=110, searchTime=12, models={},
    weaponType='both', weaponChance=20, weaponDamage=25,
    walkStyle='MP_Style_drunk',
    modelOutfits={},
    lootEnabled=true, lootChanceMode='fixed', lootChance=40, lootChanceMin=20, lootChanceMax=60, lootMaxItems=2, lootItems={}
}
local limits = {
    x={-20000,20000},y={-20000,20000},z={-1000,3000},heading={-180,180},radius={1,500},height={1,100},activation={30,400},
    spawnRadius={0,200},count={0,500},minCount={0,500},maxCount={1,500},
    respawn={5,86400},replenish={1,3600},bucket={0,65535},
    migrationChance={0,1},migrationSize={1,20},migrationInterval={30,86400},
    aggression={0,5},sight={1,150},hearing={0.1,3},hearingDistance={1,500},health={100,3000},damage={0,100},
    speed={0.3,3},attackRange={0.8,3},attackCooldown={300,15000},reaction={100,5000},
    fov={30,180},searchTime={2,120},weaponChance={0,100},weaponDamage={0,100}
}
local integers = {count=true,minCount=true,maxCount=true,health=true,damage=true,bucket=true,
    migrationSize=true,attackCooldown=true,reaction=true,weaponChance=true,weaponDamage=true}
function Zombie.validate(input)
    assert(type(input)=='table', 'Некорректная зона')
    local z = {}
    for k,default in pairs(Zombie.defaults) do
        if limits[k] then
            z[k] = Zombie.number(input[k],limits[k][1],limits[k][2],default)
            if integers[k] then assert(z[k]%1==0,'Требуется целое: '..k) end
        elseif type(default)=='boolean' then
            assert(input[k]==nil or type(input[k])=='boolean','Требуется переключатель: '..k)
            if input[k]==nil then z[k]=default else z[k]=input[k] end
        end
    end
    assert(type(input.name)=='string' and #input.name>0 and #input.name<=160,'Название: 1–160 байт')
    z.name=input.name:gsub('[%c]',' ')
    assert(ZombieConfig.Profiles[input.profile], 'Неизвестный профиль'); z.profile=input.profile
    assert(z.minCount<=z.maxCount and z.count<=z.maxCount and z.maxCount<=ZombieConfig.MaxAlive,'Неверное количество')
    assert(z.spawnRadius<=z.radius and z.spawnRadius+20<=z.activation,'Радиус появления должен помещаться в зоне и активации')
    local allowedWeapons = { none=true, both=true, knife=true, machete=true }
    local wType = tostring(input.weaponType or 'none'):lower()
    z.weaponType = allowedWeapons[wType] and wType or 'both'
    local allowedWalkStyles = {
        MP_Style_drunk = true,
        zombie_very_drunk = true,
        MP_Style_Crazy = true,
        MP_Style_SilentType = true,
        MP_Style_EasyRider = true,
        MP_Style_Veteran = true,
        MP_Style_Greenhorn = true,
        random = true,
    }
    local wStyle = tostring(input.walkStyle or 'MP_Style_drunk')
    z.walkStyle = allowedWalkStyles[wStyle] and wStyle or 'MP_Style_drunk'
    z.models={}
    assert(input.models==nil or type(input.models)=='table','Некорректные модели')
    local seen={}
    for _,model in ipairs(input.models or {}) do
        assert(type(model)=='string' and ZombieModels[model],'Неизвестная модель')
        if not seen[model] then z.models[#z.models+1]=model; seen[model]=true end
        assert(#z.models<=32,'Слишком много моделей')
    end
    z.modelOutfits = {}
    if type(input.modelOutfits) == 'table' then
        for model, list in pairs(input.modelOutfits) do
            if ZombieModels[model] and type(list) == 'table' then
                local validSet = {}
                for _, o in ipairs(ZombieModels[model]) do validSet[o] = true end
                local picked = {}
                for _, o in ipairs(list) do
                    local num = tonumber(o)
                    if num and validSet[num] then picked[#picked + 1] = num end
                end
                if #picked > 0 then z.modelOutfits[model] = picked end
            end
        end
    end
    z.lootEnabled = input.lootEnabled == nil and true or (input.lootEnabled == true or input.lootEnabled == 1 or input.lootEnabled == 'true')
    z.lootChanceMode = (input.lootChanceMode == 'range') and 'range' or 'fixed'
    local lChance = tonumber(input.lootChance) or 40
    z.lootChance = math.max(0, math.min(100, lChance))
    local lMin = tonumber(input.lootChanceMin) or 20
    local lMax = tonumber(input.lootChanceMax) or 60
    z.lootChanceMin = math.max(0, math.min(100, lMin))
    z.lootChanceMax = math.max(z.lootChanceMin, math.min(100, lMax))
    local lMaxItems = tonumber(input.lootMaxItems) or 2
    z.lootMaxItems = math.max(1, math.min(5, lMaxItems))
    z.lootItems = {}
    if type(input.lootItems) == 'table' then
        for _, item in ipairs(input.lootItems) do
            if type(item) == 'table' and item.name and tostring(item.name) ~= '' then
                z.lootItems[#z.lootItems + 1] = {
                    name = tostring(item.name),
                    label = item.label and tostring(item.label) or nil,
                    minCount = math.max(1, tonumber(item.minCount) or 1),
                    maxCount = math.max(math.max(1, tonumber(item.minCount) or 1), tonumber(item.maxCount) or 1),
                    weight = math.max(1, tonumber(item.weight) or 10)
                }
            end
        end
    end
    return z
end
function Zombie.settings(z)
    local p=Zombie.copy(ZombieConfig.Profiles[z.profile])
    for _,k in ipairs({'health','damage','weaponDamage','speed','sight','hearing','hearingDistance','aggression','attackRange',
        'attackCooldown','reaction','headshotOnly','fov','searchTime','migration','weaponType','weaponChance','walkStyle',
        'lootEnabled','lootChanceMode','lootChance','lootChanceMin','lootChanceMax','lootMaxItems'}) do p[k]=z[k] end
    p.models = #z.models>0 and z.models or p.models
    p.modelOutfits = z.modelOutfits or {}
    p.lootItems = z.lootItems or {}
    p.walkStyle = p.walkStyle or 'MP_Style_drunk'
    p.weaponDamage = tonumber(p.weaponDamage) or 25
    return p
end
