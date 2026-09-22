function FX.track(value)
    if type(value)~='table' or #value<1 or #value>32 then return nil,'От 1 до 32 ключевых кадров' end
    local result={}
    for _,key in ipairs(value) do
        if type(key)~='table' then return nil,'Некорректный кадр' end
        local offset=FX.vec(key.offset,{x=0.0,y=0.0,z=0.0})
        local rotation=FX.vec(key.rotation,{x=0.0,y=0.0,z=0.0})
        if not offset or not rotation then return nil,'Некорректная точка траектории' end
        result[#result+1]={at=FX.clamp(key.at,0,600,0),offset=offset,rotation=rotation,
            alpha=FX.clamp(key.alpha,0,1,1),scale=FX.clamp(key.scale,0.01,10,1),
            easing=key.easing=='smooth' and 'smooth' or key.easing=='hold' and 'hold' or 'linear'}
    end
    table.sort(result,function(a,b) return a.at<b.at end)
    for i=2,#result do if result[i].at==result[i-1].at then return nil,'Время кадров должно отличаться' end end
    return result
end
function FX.sampleTrack(keys,time)
    local a,b=keys[1],keys[#keys]
    if time<=a.at then b=a
    elseif time>=b.at then a=b
    else for i=2,#keys do if time<keys[i].at then a,b=keys[i-1],keys[i]; break end end end
    local t=a==b and 0.0 or (time-a.at)/(b.at-a.at)
    if a.easing=='smooth' then t=t*t*(3-2*t) elseif a.easing=='hold' then t=0.0 end
    local function lerp(x,y) return x+(y-x)*t end
    local offset,rotation={},{}
    for _,axis in ipairs({'x','y','z'}) do offset[axis]=lerp(a.offset[axis],b.offset[axis]);rotation[axis]=lerp(a.rotation[axis],b.rotation[axis]) end
    return offset,rotation,lerp(a.alpha,b.alpha),lerp(a.scale,b.scale)
end
function FX.rotate(v,r)
    local x,y,z=v.x,v.y,v.z
    local a,b,c=math.rad(r.x),math.rad(r.y),math.rad(r.z)
    y,z=y*math.cos(a)-z*math.sin(a),y*math.sin(a)+z*math.cos(a)
    x,z=x*math.cos(b)+z*math.sin(b),-x*math.sin(b)+z*math.cos(b)
    return {x=x*math.cos(c)-y*math.sin(c),y=x*math.sin(c)+y*math.cos(c),z=z}
end
function FX.transformParams(p,rotation,scale)
    local result=FX.copy(p)
    local function transform(v)
        local out=FX.rotate(v,rotation)
        for _,axis in ipairs({'x','y','z'}) do out[axis]=out[axis]*scale end
        return out
    end
    result.offset=transform(p.offset)
    for _,axis in ipairs({'x','y','z'}) do result.rotation[axis]=p.rotation[axis]+rotation[axis] end
    result.scale=FX.clamp(p.scale*scale,0.01,10,1)
    if result.animation then
        result.animation.radius=FX.clamp(result.animation.radius*scale,0,20,1)
        result.animation.velocity=transform(result.animation.velocity)
        result.animation.endScale=FX.clamp(result.animation.endScale*scale,0.01,10,1)
    end
    if result.keyframes then for _,key in ipairs(result.keyframes) do key.offset=transform(key.offset) end end
    return result
end
