-- Portable compositions contain no world coordinates or player/entity handles.
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
        result.phases[#result.phases+1]={effectId=phase.effectId,at=at,params=p,enabled=phase.enabled~=false,
            group=type(phase.group)=='string' and phase.group:sub(1,80) or nil,
            name=type(phase.name)=='string' and phase.name:sub(1,120) or nil}
    end
    return result
end
function FX.enabledPhases(def)
    local result={}
    for _,phase in ipairs(def.phases) do if type(phase)~='table' or phase.enabled~=false then result[#result+1]=phase end end
    return result
end
