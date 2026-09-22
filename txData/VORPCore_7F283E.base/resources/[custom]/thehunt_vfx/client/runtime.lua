-- RedM PTFX assets use hash for request/loaded and string for selection.
FXRuntime = { active={}, serial=0, groups={} }
local R=FXRuntime
local function sample(r)
    local p=r.params
    if r.previewLifetime then p=FX.copy(p);p.lifetime=r.previewLifetime end
    return FX.frame(p,(GetGameTimer()-r.started)/1000*(r.previewSpeed or 1))
end
local emissionWindow,emissions=0,0
local function emissionAllowed()
    local now=GetGameTimer()
    if now-emissionWindow>=1000 then emissionWindow=now; emissions=0 end
    if emissions>=40 then return false end
    emissions=emissions+1; return true
end
local function fail(r,msg)
    r.state='failed'; r.error=tostring(msg)
    TriggerEvent('thehunt_vfx:result',r.id,false,r.error)
end
local function entityFor(p)
    if p.targetServerId then
        local player=GetPlayerFromServerId(p.targetServerId)
        if player == -1 then return nil end
        local ped=GetPlayerPed(player); return DoesEntityExist(ped) and ped or nil
    end
    if p.entity and DoesEntityExist(p.entity) then return p.entity end
end
local function boneIndices(p,entity)
    local result={}
    if not entity then return result end
    for _,name in ipairs(p.bones or (p.bone and {p.bone} or {})) do
        local index=GetEntityBoneIndexByName(entity,name)
        if index~=-1 then result[#result+1]=index end
    end
    return result
end
local function bonePosition(entity,index,offset)
    local c=GetWorldPositionOfEntityBone(entity,index)
    return {x=c.x+offset.x,y=c.y+offset.y,z=c.z+offset.z}
end
local function position(p,entity)
    if entity then
        local bones=boneIndices(p,entity)
        if #bones>0 then
            return bonePosition(entity,bones[1],p.offset)
        end
        return GetOffsetFromEntityInWorldCoords(entity,p.offset.x,p.offset.y,p.offset.z)
    end
    local c=p.coords
    return c and {x=c.x+p.offset.x,y=c.y+p.offset.y,z=c.z+p.offset.z}
end
function R.stop(id)
    local r=R.active[id]; if not r then return false end
    R.active[id]=nil
    if r.handles then for _,handle in ipairs(r.handles) do StopParticleFxLooped(handle,false) end
    elseif r.handle then StopParticleFxLooped(r.handle,false) end
    -- Stop only modifiers started by this resource, never global StopAll.
    if r.screen then
        if r.effect.kind=='postfx' then AnimpostfxStop(r.effect.name)
        elseif r.effect.kind=='timecycle' then ClearTimecycleModifier() end
    end
    return true
end
function R.stopOwner(owner)
    for id,r in pairs(R.active) do if r.owner==owner then R.stop(id) end end
    for id,g in pairs(R.groups) do if g.owner==owner then R.stopGroup(id) end end
end
function R.play(effectId,params,owner,forcedId)
    local p,err=FX.params(effectId,params or {},false)
    if not p then return false,err end
    if FX.count(R.active)>=Config.MaxLocal then return false,'Лимит локальных эффектов' end
    if not p.coords and not p.entity and not p.targetServerId then
        if p.attach then p.entity=PlayerPedId() else p.coords=FX.vec(GetEntityCoords(PlayerPedId())) end
    end
    R.serial=R.serial+1
    local id=forcedId or ('local:%d'):format(R.serial)
    R.stop(id)
    local r={id=id,effect=FX.byId[effectId],params=p,owner=owner,state='loading',started=GetGameTimer()}
    R.active[id]=r
    CreateThread(function()
        local ok,errorText=pcall(function()
            local e=r.effect
            if e.dict then
                local hash=GetHashKey(e.dict)
                Citizen.InvokeNative(0xF2B2353BBC0D4E8F,hash)
                local deadline=GetGameTimer()+Config.AssetTimeout
                while not Citizen.InvokeNative(0x65BB72F29138F5D6,hash) do
                    if R.active[id]~=r then return end
                    if GetGameTimer()>=deadline then error('Словарь не загрузился: '..e.dict) end
                    Wait(0)
                end
            end
            if R.active[id]~=r then return end
            local entity=entityFor(p)
            if (p.entity or p.targetServerId) and not entity then error('Объект не в зоне стриминга') end
            local bone=p.bone and entity and GetEntityBoneIndexByName(entity,p.bone) or -1
            local bones=boneIndices(p,entity)
            if p.attach and (p.bone or p.bones) and #bones==0 then error('Кость не найдена') end
            local c=position(p,entity)
            local o,t=p.offset,p.rotation
            if e.kind=='shape' then
                if GetResourceState('thehunt_shapes')~='started' then error('Для геометрических слоёв нужен запущенный thehunt_shapes') end
                r.state='playing'
            elseif e.kind=='light' then
                r.state='playing'
            elseif e.kind=='postfx' then
                if AnimpostfxIsRunning(e.name) then error('Этот экранный эффект уже занят другим ресурсом') end
                AnimpostfxPlay(e.name); r.screen=true; r.state='playing'
            elseif e.kind=='timecycle' then
                for otherId,other in pairs(R.active) do
                    if otherId~=id and other.screen and other.effect.kind=='timecycle' then error('Канал Timecycle уже занят VFX') end
                end
                SetTimecycleModifier(e.name); SetTimecycleModifierStrength(p.alpha)
                r.screen=true; r.state='playing'
            else
                local function emit()
                    local offset,rotation,alpha,scale=sample(r)
                    local moving=FX.copy(p); moving.offset=offset
                    o,t=offset,rotation
                    c=position(moving,entityFor(p)) or c
                    local function useAsset() Citizen.InvokeNative(0xA10DB07FC234DD12,e.dict) end
                    if e.kind=='loop' then
                        if entity and p.attach and #bones>0 then
                            local handles={}
                            for _,boneIndex in ipairs(bones) do
                                useAsset()
                                handles[#handles+1]=StartParticleFxLoopedOnEntityBone(e.name,entity,o.x,o.y,o.z,t.x,t.y,t.z,boneIndex,scale,false,false,false)
                            end
                            return handles
                        elseif entity and p.attach then
                            useAsset()
                            return StartParticleFxLoopedOnEntity(e.name,entity,o.x,o.y,o.z,t.x,t.y,t.z,p.scale,false,false,false)
                        else
                            useAsset()
                            return StartParticleFxLoopedAtCoord(e.name,c.x,c.y,c.z,t.x,t.y,t.z,p.scale,false,false,false,false)
                        end
                    else
                        if not emissionAllowed() then return true end
                        local rgb=p.color or {r=255,g=255,b=255}
                        -- Burst samples every selected bone position. It cannot be stopped after emission.
                        if entity and p.attach and #bones>0 then
                            local handles={}
                            for _,boneIndex in ipairs(bones) do
                                local bc=bonePosition(entity,boneIndex,o);useAsset();SetParticleFxNonLoopedColour(rgb.r/255,rgb.g/255,rgb.b/255);SetParticleFxNonLoopedAlpha(alpha)
                                handles[#handles+1]=StartParticleFxNonLoopedAtCoord(e.name,bc.x,bc.y,bc.z,t.x,t.y,t.z,scale,false,false,false)
                            end
                            return handles
                        end
                        useAsset();SetParticleFxNonLoopedColour(rgb.r/255,rgb.g/255,rgb.b/255);SetParticleFxNonLoopedAlpha(alpha)
                        return StartParticleFxNonLoopedAtCoord(e.name,c.x,c.y,c.z,t.x,t.y,t.z,scale,false,false,false)
                    end
                end
                local handle=emit()
                if handle==nil or handle==false or handle==0 or (type(handle)=='table' and #handle==0) then error('Движок отклонил запуск: '..e.name) end
                if e.kind=='loop' then
                    r.handles=type(handle)=='table' and handle or {handle};r.handle=r.handles[1]
                    for _,item in ipairs(r.handles) do
                        SetParticleFxLoopedAlpha(item,p.animation and p.animation.fadeIn>0 and 0.0 or p.alpha)
                        if p.color then SetParticleFxLoopedColour(item,p.color.r/255,p.color.g/255,p.color.b/255,false) end
                    end
                end
                r.state='playing'
                TriggerEvent('thehunt_vfx:result',id,true,'Запущен; видимость проверяется в игре')
                if e.kind=='burst' then
                    if p.trail then
                        local last=c; local count=1
                        while R.active[id]==r and GetGameTimer()-r.started<p.lifetime*1000 and count<p.trail.maxEmissions do
                            Wait(100)
                            if R.active[id]~=r then return end
                            local currentEntity=entityFor(p)
                            if (p.entity or p.targetServerId) and not currentEntity then R.stop(id);return end
                            local current=position(p,currentEntity)
                            if current and ((current.x-last.x)^2+(current.y-last.y)^2+(current.z-last.z)^2)>=p.trail.distance^2 then
                                emit();last=current;count=count+1
                            end
                        end
                        R.stop(id);return
                    end
                    for _=2,p.repeatCount do
                        Wait(p.repeatInterval)
                        if R.active[id]~=r then return end
                        if p.lifetime>0 and GetGameTimer()-r.started>=p.lifetime*1000 then R.stop(id); return end
                        emit()
                    end
                    R.stop(id); return
                end
            end
            if R.active[id]==r then
                r.started=GetGameTimer()
                if p.lifetime>0 then r.expires=r.started+p.lifetime*1000 end
                TriggerEvent('thehunt_vfx:result',id,true,'Запущен; видимость проверяется в игре')
            end
        end)
        if not ok and R.active[id]==r then
            if r.handles then for _,handle in ipairs(r.handles) do StopParticleFxLooped(handle,false) end;r.handles=nil;r.handle=nil
            elseif r.handle then StopParticleFxLooped(r.handle,false); r.handle=nil end
            fail(r,errorText)
            r.expires=GetGameTimer()+5000
        end
    end)
    return id
end
function R.snapshot(owner)
    local list={}
    for id,r in pairs(R.active) do
        if not owner or r.owner==owner then list[#list+1]={id=id,effectId=r.effect.id,params=FX.copy(r.params),state=r.state,error=r.error,owner=r.owner,handles=r.handles and #r.handles or 0} end
    end
    table.sort(list,function(a,b) return a.id<b.id end); return list
end
function R.stopGroup(id)
    local g=R.groups[id]; if not g then return false end
    R.groups[id]=nil
    for _,child in ipairs(g.children) do R.stop(child) end
    return true
end
function R.sequence(def,context,owner)
    if type(def)~='table' or type(def.phases)~='table' or #def.phases<1 or #def.phases>Config.MaxLayers then return false,'Нужен список phases' end
    context=context or {}
    local duration=FX.clamp(def.duration,0.1,Config.MaxDuration,10)
    local phases={}
    for _,phase in ipairs(FX.enabledPhases(def)) do
        if type(phase)~='table' then return false,'Некорректный слой' end
        local p=FX.copy(context)
        for k,v in pairs(phase.params or {}) do p[k]=v end
        local at=FX.clamp(phase.at or phase.delay,0,duration,0)
        if at>=duration then return false,'Слой начинается после конца композиции' end
        local requested=FX.number(p.lifetime,duration-at)
        p.lifetime=math.min(requested>0 and requested or duration-at,duration-at)
        local clean,err=FX.params(phase.effectId,p,false)
        if not clean then return false,err end
        phases[#phases+1]={at=at,effectId=phase.effectId,params=clean}
    end
    if FX.count(R.groups)>=16 or FX.count(R.active)+#phases>Config.MaxLocal then return false,'Лимит последовательностей или слоёв' end
    local requested={}
    for _,phase in ipairs(phases) do
        local dict=FX.byId[phase.effectId].dict
        if dict and not requested[dict] then requested[dict]=true;Citizen.InvokeNative(0xF2B2353BBC0D4E8F,GetHashKey(dict)) end
    end
    R.serial=R.serial+1; local id='sequence:'..R.serial
    local g={owner=owner,children={}}; R.groups[id]=g
    local start=GetGameTimer()
    for _,phase in ipairs(phases) do
        CreateThread(function()
            Wait(math.max(0,start+phase.at*1000-GetGameTimer()))
            if R.groups[id]~=g then return end
            local child,err=R.play(phase.effectId,phase.params,owner)
            if child then g.children[#g.children+1]=child
            else TriggerEvent('thehunt_vfx:sequenceError',id,err,owner) end
        end)
    end
    CreateThread(function()
        Wait(duration*1000)
        if R.groups[id]==g then R.stopGroup(id) end
    end)
    return id
end
CreateThread(function()
    while true do
        local lights=false
        local now=GetGameTimer()
        for id,r in pairs(R.active) do
            local p=r.params
            if r.expires and now>=r.expires then R.stop(id)
            elseif r.state=='playing' then
                local entity=entityFor(p)
                local offset,rotation,alpha,scale=sample(r)
                local moving=FX.copy(p); moving.offset=offset
                if r.handles and (p.animation or p.keyframes) then
                    lights=true
                    local bones=boneIndices(p,entity)
                    for index,handle in ipairs(r.handles) do
                        local c=(p.attach and bones[index] and bonePosition(entity,bones[index],offset)) or position(moving,entity)
                        if c then SetParticleFxLoopedOffsets(handle,c.x,c.y,c.z,rotation.x,rotation.y,rotation.z) end
                        SetParticleFxLoopedAlpha(handle,alpha);SetParticleFxLoopedScale(handle,scale)
                    end
                end
                if p.attach and (p.entity or p.targetServerId) and not entity then R.stop(id)
                elseif r.effect.kind=='shape' then
                    lights=true
                    local c=position(moving,entity);local rgb=p.color or {r=100,g=180,b=255}
                    if GetResourceState('thehunt_shapes')~='started' then R.stop(id)
                    elseif c then
                        local a=math.floor(alpha*255)
                        if r.effect.name=='sphere' then exports.thehunt_shapes:DrawSphere(c.x,c.y,c.z,scale,math.floor(rgb.r),math.floor(rgb.g),math.floor(rgb.b),a,8,16)
                        elseif r.effect.name=='disk' then exports.thehunt_shapes:DrawDisk(c.x,c.y,c.z,scale,math.floor(rgb.r),math.floor(rgb.g),math.floor(rgb.b),a,24)
                        else exports.thehunt_shapes:DrawHoop(c.x,c.y,c.z,scale,0.05,math.floor(rgb.r),math.floor(rgb.g),math.floor(rgb.b),a,24) end
                    end
                elseif r.effect.kind=='light' then
                    lights=true
                    local c=position(moving,entity); local rgb=p.color or {r=100,g=180,b=255}
                    if c then DrawLightWithRange(c.x,c.y,c.z,math.floor(rgb.r),math.floor(rgb.g),math.floor(rgb.b),p.range,p.intensity*alpha) end
                end
            end
        end
        Wait(lights and 0 or 100)
    end
end)
local function caller() return GetInvokingResource() or GetCurrentResourceName() end
exports('PlayEffect',function(id,p) return R.play(id,p,caller()) end)
exports('StopEffect',function(id)
    local r=R.active[id]; if not r or r.owner~=caller() then return false end
    return R.stop(id)
end)
exports('StopAllEffects',function() R.stopOwner(caller()); return true end)
exports('PlaySequence',function(def,context) return R.sequence(def,context,caller()) end)
exports('PlayMagic',function(def,context) return R.sequence(def,context,caller()) end)
exports('StopSequence',function(id)
    local g=R.groups[id]; return g and g.owner==caller() and R.stopGroup(id) or false
end)
exports('GetEffectInfo',function(id) return FX.copy(FX.byId[id]) end)
exports('GetCatalog',function() return FX.copy(FX.catalog) end)
exports('GetActiveEffects',function() return R.snapshot(caller()) end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then
        for id in pairs(R.active) do R.stop(id) end
        R.groups={}
    else R.stopOwner(name) end
end)
