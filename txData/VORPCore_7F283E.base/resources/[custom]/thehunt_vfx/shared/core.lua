FX = { catalog = {}, byId = {} }
function FX.copy(v)
    if type(v) ~= 'table' then return v end
    local r = {}; for k,x in pairs(v) do r[k] = FX.copy(x) end; return r
end
function FX.number(v, fallback)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return fallback end
    return v
end
function FX.clamp(v, low, high, fallback)
    -- Cfx native float arguments must remain floats even when JSON contains 1 or 0.
    return math.max(low, math.min(high, FX.number(v, fallback or low))) + 0.0
end
function FX.vec(v, default)
    local kind = type(v)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return default end
    local x,y,z = FX.number(v.x),FX.number(v.y),FX.number(v.z)
    if not x or not y or not z or math.max(math.abs(x),math.abs(y),math.abs(z)) > 100000 then return nil end
    return {x=x+0.0,y=y+0.0,z=z+0.0}
end
local function add(kind, name, dict)
    local legacy = ({loop='ptfx_looped',burst='ptfx_non_looped',postfx='animpostfx'})[kind] or kind
    local id = legacy .. '|' .. (dict and (dict .. '|') or '') .. name
    if FX.byId[id] then return end
    local e = {id=id, kind=kind, name=name, dict=dict}
    FX.byId[id]=e; FX.catalog[#FX.catalog+1]=e
end
for _,kind in ipairs({'loop','burst'}) do
    for dict,names in pairs(VFXSources[kind]) do
        for _,name in ipairs(names) do add(kind,name,dict) end
    end
end
for _,kind in ipairs({'postfx','timecycle'}) do
    for _,name in ipairs(VFXSources[kind]) do add(kind,name) end
end
add('light','point')
for _,name in ipairs({'sphere','disk','hoop'}) do add('shape',name) end
table.sort(FX.catalog,function(a,b) return a.id < b.id end)

-- One schema on both sides. Network payloads never carry local entity handles.
function FX.params(id, p, network)
    local e=FX.byId[id]
    if not e or type(p)~='table' then return nil,'Неизвестный эффект или параметры' end
    if network and (e.kind=='postfx' or e.kind=='timecycle') then return nil,'Экранные эффекты доступны только локально' end
    if e.kind=='timecycle' and not Config.AllowTimecycle then return nil,'Timecycle отключён: общий канал с погодой и состоянием персонажа' end
    local zero={x=0.0,y=0.0,z=0.0}
    local v={
        coords=FX.vec(p.coords), offset=FX.vec(p.offset,zero), rotation=FX.vec(p.rotation,zero),
        scale=FX.clamp(p.scale,0.01,10,1), alpha=FX.clamp(p.alpha,0,1,1),
        lifetime=FX.clamp(p.lifetime,0,Config.MaxDuration,5),
        elapsed=FX.clamp(p.elapsed,0,Config.MaxDuration,0),
        range=FX.clamp(p.range,0.1,40,8), intensity=FX.clamp(p.intensity,0,30,3),
        attach=p.attach==true, targetServerId=FX.number(p.targetServerId),
        entity=not network and FX.number(p.entity) or nil,
        bone=type(p.bone)=='string' and #p.bone<=64 and p.bone~='' and p.bone or nil,
        repeatCount=math.floor(FX.clamp(p.repeatCount,1,12,1)),
        repeatInterval=math.floor(FX.clamp(p.repeatInterval,150,60000,500))
    }
    if type(p.bones)=='table' then
        v.bones={}
        for _,name in ipairs(p.bones) do
            if type(name)=='string' and #name<=64 and name~='' and #v.bones<4 then v.bones[#v.bones+1]=name end
        end
        if #v.bones>0 then v.bone=v.bone or v.bones[1] end
    elseif v.bone then v.bones={v.bone} end
    if not v.offset or not v.rotation or (p.coords~=nil and not v.coords) then return nil,'Некорректные координаты' end
    if p.animation~=nil then
        if type(p.animation)~='table' then return nil,'Некорректная анимация' end
        local a=p.animation
        v.animation={mode=a.mode=='orbit' and 'orbit' or a.mode=='linear' and 'linear' or 'static',
            radius=FX.clamp(a.radius,0,20,1),speed=FX.clamp(a.speed,-720,720,90),
            velocity=FX.vec(a.velocity,zero),spin=FX.vec(a.spin,zero),
            fadeIn=FX.clamp(a.fadeIn,0,30,0),fadeOut=FX.clamp(a.fadeOut,0,30,0),
            endScale=FX.clamp(a.endScale,0.01,10,v.scale)}
        if not v.animation.velocity or not v.animation.spin then return nil,'Некорректная траектория' end
        for _,axis in ipairs({'x','y','z'}) do
            v.animation.velocity[axis]=FX.clamp(v.animation.velocity[axis],-20,20,0)
            v.animation.spin[axis]=FX.clamp(v.animation.spin[axis],-720,720,0)
        end
        if e.kind=='postfx' or e.kind=='timecycle' then return nil,'Анимация слоёв доступна для частиц и света' end
    end
    if p.color~=nil then
        if type(p.color)~='table' then return nil,'Некорректный цвет' end
        v.color={r=FX.clamp(p.color.r,0,255,255),g=FX.clamp(p.color.g,0,255,255),b=FX.clamp(p.color.b,0,255,255)}
    end
    if v.targetServerId and (v.targetServerId<1 or v.targetServerId%1~=0) then return nil,'Некорректный ID игрока' end
    if p.keyframes~=nil then
        if e.kind=='postfx' or e.kind=='timecycle' then return nil,'Ключевые кадры доступны для частиц и света' end
        local err; v.keyframes,err=FX.track(p.keyframes)
        if not v.keyframes then return nil,err end
        v.trackLoop=p.trackLoop==true
    end
    if p.trail~=nil then
        if e.kind~='burst' or type(p.trail)~='table' then return nil,'След требует разовый PTFX' end
        v.trail={distance=FX.clamp(p.trail.distance,0.1,10,0.5),maxEmissions=math.floor(FX.clamp(p.trail.maxEmissions,1,120,60))}
        if v.lifetime<=0 then v.lifetime=30.0 end
    end
    if network and not v.coords and not v.targetServerId then return nil,'Нужны координаты или ID игрока' end
    if network and v.attach and not v.targetServerId then return nil,'Привязка требует ID игрока' end
    if (e.kind=='postfx' or e.kind=='timecycle') then v.lifetime=FX.clamp(v.lifetime,0.1,30,5) end
    return v
end
function FX.count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
-- Kept in the base shared file as well as shared/composition.lua so a stale
-- resource cache cannot leave the client without the composition validator.
if type(FX.composition)~='function' then
    function FX.composition(def)
        if type(def)~='table' or type(def.phases)~='table' or #def.phases<1 or #def.phases>Config.MaxLayers then return nil,'Неверное число слоёв' end
        local result={duration=FX.clamp(def.duration,0.1,Config.MaxDuration,10),phases={}}
        for _,phase in ipairs(def.phases) do
            if type(phase)~='table' then return nil,'Некорректный слой' end
            local p,err=FX.params(phase.effectId,phase.params or {},false)
            if not p then return nil,err end
            local at=FX.clamp(phase.at,0,result.duration,0)
            if at>=result.duration then return nil,'Слой начинается после конца композиции' end
            p.coords=nil; p.entity=nil; p.targetServerId=nil; p.elapsed=0.0
            p.lifetime=math.min(p.lifetime>0 and p.lifetime or result.duration,result.duration-at)
            result.phases[#result.phases+1]={effectId=phase.effectId,at=at,params=p,enabled=phase.enabled~=false}
        end
        return result
    end
end
if type(FX.enabledPhases)~='function' then
    function FX.enabledPhases(def)
        local result={}
        for _,phase in ipairs(def.phases) do if type(phase)~='table' or phase.enabled~=false then result[#result+1]=phase end end
        return result
    end
end
function FX.frame(p,elapsed)
    local a=p.animation
    local o={x=p.offset.x,y=p.offset.y,z=p.offset.z}
    local rot={x=p.rotation.x,y=p.rotation.y,z=p.rotation.z}
    if p.keyframes then
        local t=math.max(0,elapsed)+(p.elapsed or 0)
        local last=p.keyframes[#p.keyframes].at
        if p.trackLoop and last>0 then t=t%last end
        local ko,kr,alpha,scale=FX.sampleTrack(p.keyframes,t)
        for _,axis in ipairs({'x','y','z'}) do ko[axis]=ko[axis]+o[axis];kr[axis]=kr[axis]+rot[axis] end
        return ko,kr,alpha*p.alpha,math.min(10.0,scale*p.scale)
    end
    if not a then return o,rot,p.alpha,p.scale end
    local t=math.max(0,elapsed)+(p.elapsed or 0)
    local duration=p.lifetime>0 and p.lifetime+(p.elapsed or 0) or 0
    if a.mode=='orbit' then
        local angle=math.rad(a.speed*t)
        o.x=o.x+math.cos(angle)*a.radius; o.y=o.y+math.sin(angle)*a.radius
    elseif a.mode=='linear' then
        for _,k in ipairs({'x','y','z'}) do o[k]=o[k]+a.velocity[k]*t end
    end
    for _,k in ipairs({'x','y','z'}) do rot[k]=rot[k]+a.spin[k]*t end
    local opacity=1.0
    if a.fadeIn>0 then opacity=math.min(opacity,t/a.fadeIn) end
    if a.fadeOut>0 and duration>0 then opacity=math.min(opacity,math.max(0,(duration-t)/a.fadeOut)) end
    local progress=duration>0 and math.min(1,t/duration) or 0
    return o,rot,p.alpha*opacity,p.scale+(a.endScale-p.scale)*progress
end
