local world, viewers, cooldown={}, {}, {}
local store={version=4,scenes={},presets={},reviews={}}
local serial,revision=0,0
local sequences={}
local playSequence,stopSequence
local sceneRuns={}
local readOnly=false
local function remember(record,previous)
    record.versions=FX.copy(previous and previous.versions or {})
    if previous then
        local version=FX.copy(previous);version.versions=nil;version.savedAt=os.date('!%Y-%m-%d %H:%M:%S')
        table.insert(record.versions,1,version)
        while #record.versions>8 do table.remove(record.versions) end
    end
end
local function admin(src)
    if src==0 then return true end
    local ok,allowed=pcall(function() return exports.thehunt_core:IsPlayerAdmin(src) end)
    return ok and allowed==true
end
local function reply(src,ok,message)
    TriggerClientEvent('thehunt_vfx:reply',src,ok,message)
end
local function save(nextStore)
    if readOnly then return false,'Файл повреждён: запись заблокирована, сохраните и исправьте его вручную' end
    local ok,data=pcall(json.encode,nextStore)
    if not ok then return false,'Ошибка сериализации' end
    local previous=LoadResourceFile(GetCurrentResourceName(),Config.Store)
    if previous and not SaveResourceFile(GetCurrentResourceName(),Config.Store..'.bak',previous,-1) then
        return false,'Ошибка резервной записи; изменения отменены'
    end
    if not SaveResourceFile(GetCurrentResourceName(),Config.Store,data,-1) then return false,'Ошибка записи '..Config.Store end
    store=nextStore; revision=revision+1
    TriggerClientEvent('thehunt_vfx:presets',-1,store.presets)
    return true
end
local function id(prefix) serial=serial+1; return prefix..':'..os.time()..':'..serial end
local function bucket(src) return GetPlayerRoutingBucket(src) end
local function canSee(src,e)
    if e.enabled==false then return false end
    if bucket(src)~=e.bucket then return false end
    return not e.onlyTarget or src==e.params.targetServerId
end
local function packet(e)
    local result=FX.copy(e)
    result.versions=nil
    if e.expires then result.params.lifetime=math.max(0.01,(e.expires-GetGameTimer())/1000) end
    if e.started then result.params.elapsed=math.max(0,(GetGameTimer()-e.started)/1000) end
    result.expires=nil; return result
end
local function stop(key,owner)
    local e=world[key]
    if not e or (owner and e.owner~=owner) then return false end
    world[key]=nil
    for src,seen in pairs(viewers) do
        if seen[key] then TriggerClientEvent('thehunt_vfx:remove',src,key); seen[key]=nil end
    end
    revision=revision+1
    return true
end
local function validateTarget(p,b)
    if p.targetServerId and (not GetPlayerName(p.targetServerId) or bucket(p.targetServerId)~=b) then return false end
    return true
end
local function create(effectId,params,options,owner)
    options=options or {}
    local p,err=FX.params(effectId,params or {},true)
    if not p then return false,err end
    if FX.count(world)>=Config.MaxWorld then return false,'Лимит эффектов мира' end
    local b=math.floor(FX.clamp(options.bucket,0,2147483647,0))
    if not validateTarget(p,b) then return false,'Игрок отсутствует или находится в другом измерении' end
    local key=id('world')
    local kind=FX.byId[effectId].kind
    local lifetime=p.lifetime
    if kind=='burst' and not p.trail then lifetime=(p.repeatCount*p.repeatInterval+5000)/1000 end
    local e={id=key,effectId=effectId,params=p,bucket=b,owner=owner,onlyTarget=options.onlyTarget==true,started=GetGameTimer(),
        expires=lifetime>0 and GetGameTimer()+lifetime*1000 or nil}
    world[key]=e; revision=revision+1
    return key
end
local function snapshot(src)
    local result={}
    for key,e in pairs(world) do
        if canSee(src,e) then result[#result+1]=packet(e) end
    end
    return result
end
local function bootstrap(src,show)
    local players={}
    for _,p in ipairs(GetPlayers()) do
        local n=tonumber(p)
        if bucket(n)==bucket(src) then players[#players+1]={id=n,name=GetPlayerName(n)} end
    end
    local compositions={}
    for key,e in pairs(store.compositions or {}) do if e.bucket==bucket(src) then compositions[key]=e end end
    local scenes={}
    for key,e in pairs(store.scenes) do if e.bucket==bucket(src) then scenes[key]=e end end
    TriggerClientEvent('thehunt_vfx:studio',src,{world=snapshot(src),presets=store.presets,reviews=store.reviews,players=players,ownId=src,revision=revision,compositions=compositions,scenes=scenes,annotations=store.annotations or {}},show==true)
end
RegisterNetEvent('thehunt_vfx:open',function()
    local src=source
    if not admin(src) then return reply(src,false,'Доступ только для администраторов') end
    bootstrap(src,true)
end)
RegisterNetEvent('thehunt_vfx:subscribe',function()
    -- Everyone receives world effects, including late joiners; no admin data here.
    local src=source
    if not viewers[src] then
        viewers[src]={}
        TriggerClientEvent('thehunt_vfx:presets',src,store.presets)
    end
end)
RegisterNetEvent('thehunt_vfx:action',function(action,data)
    local src=source
    if not admin(src) then return reply(src,false,'Нет доступа') end
    local now=GetGameTimer()
    if cooldown[src] and now-cooldown[src]<180 then return reply(src,false,'Повторите через мгновение') end
    cooldown[src]=now
    data=type(data)=='table' and data or {}
    local ok,err
    if action=='describePreset' then
        if type(data.name)~='string' or not store.presets[data.name] then return reply(src,false,'Пресет не найден') end
        local nextStore=FX.copy(store)
        nextStore.presets[data.name].description=type(data.description)=='string' and data.description:sub(1,2048) or ''
        nextStore.presets[data.name].verification=data.verified==true and {by=GetPlayerName(src),date=os.date('!%Y-%m-%d'),build=GetConvar('sv_enforceGameBuild','default')} or nil
        ok,err=save(nextStore)
    elseif action=='annotate' then
        if not FX.byId[data.effectId] then return reply(src,false,'Эффект не найден') end
        local nextStore=FX.copy(store);nextStore.annotations=nextStore.annotations or {}
        local tags={}
        if type(data.tags)=='table' then for i=1,math.min(#data.tags,12) do if type(data.tags[i])=='string' then tags[#tags+1]=data.tags[i]:sub(1,80) end end end
        nextStore.annotations[data.effectId]={note=type(data.note)=='string' and data.note:sub(1,2048) or '',tags=tags,by=GetPlayerName(src)}
        ok,err=save(nextStore)
    elseif action=='manageScene' then
        local field=data.kind=='composition' and 'compositions' or 'scenes'
        local previous=(store[field] or {})[data.id]
        if not previous or previous.bucket~=bucket(src) then return reply(src,false,'Сцена не найдена в вашем измерении') end
        local record=FX.copy(previous);local key=data.id
        if data.operation=='toggle' then record.enabled=previous.enabled==false
        elseif data.operation=='move' then
            local coords=FX.vec(data.coords);if not coords then return reply(src,false,'Некорректная точка') end
            if field=='compositions' then record.coords=coords else record.params.coords=coords end
        elseif data.operation=='duplicate' then
            if FX.count(store[field])>=(field=='compositions' and 8 or Config.MaxWorld) then return reply(src,false,'Лимит сохранённых сцен') end
            key=id(field=='compositions' and 'composition' or 'world');record.id=key;record.name=(record.name or 'Сцена')..' (копия)';record.enabled=false;record.versions={}
        elseif data.operation=='restore' then
            local index=FX.number(data.version)
            local version=index and previous.versions and previous.versions[index]
            if not version then return reply(src,false,'Версия не найдена') end
            record=FX.copy(version);record.savedAt=nil;record.id=field=='scenes' and key or nil
        else return reply(src,false,'Неизвестное действие') end
        if data.operation~='duplicate' then remember(record,previous) end
        local nextStore=FX.copy(store);nextStore[field]=nextStore[field] or {};nextStore[field][key]=record
        ok,err=save(nextStore)
        if ok then
            if field=='compositions' then
                if sceneRuns[key] then stopSequence(sceneRuns[key].id,'scene:'..key);sceneRuns[key]=nil end
            else
                stop(key);record.owner='persistent';record.expires=nil;record.params.lifetime=0;world[key]=FX.copy(record)
            end
        end
    elseif action=='saveWorldComposition' then
        local def; def,err=FX.composition(data.definition)
        local coords=FX.vec(data.coords)
        if not def or not coords then return reply(src,false,err or 'Укажите точку') end
        for _,phase in ipairs(def.phases) do
            local e=FX.byId[phase.effectId]
            if phase.params.attach or e.kind=='postfx' or e.kind=='timecycle' then return reply(src,false,'Постоянная композиция требует мировые слои без привязок и экранных эффектов') end
        end
        local previous=(store.compositions or {})[data.id]
        if data.id and (not previous or previous.bucket~=bucket(src)) then return reply(src,false,'Композиция не найдена') end
        if not previous and FX.count(store.compositions or {})>=8 then return reply(src,false,'Максимум 8 постоянных композиций') end
        local nextStore=FX.copy(store);nextStore.compositions=nextStore.compositions or {}
        local key=previous and data.id or id('composition')
        nextStore.compositions[key]={definition=def,coords=coords,bucket=bucket(src),name=tostring(data.name or 'Композиция'):sub(1,120)}
        nextStore.compositions[key].enabled=not previous or previous.enabled~=false
        remember(nextStore.compositions[key],previous)
        ok,err=save(nextStore)
        if ok and sceneRuns[key] then stopSequence(sceneRuns[key].id,'scene:'..key);sceneRuns[key]=nil end
    elseif action=='deleteWorldComposition' then
        local entry=(store.compositions or {})[data.id]
        if not entry or entry.bucket~=bucket(src) then return reply(src,false,'Композиция не найдена') end
        local nextStore=FX.copy(store);nextStore.compositions[data.id]=nil
        ok,err=save(nextStore)
        if ok and sceneRuns[data.id] then stopSequence(sceneRuns[data.id].id,'scene:'..data.id);sceneRuns[data.id]=nil end
    elseif action=='spawnComposition' then
        local def; def,err=FX.composition(data.definition)
        if def then
            local context={coords=FX.vec(data.coords)}
            if data.targetServerId then context.targetServerId=FX.number(data.targetServerId) end
            if data.self then context.targetServerId=src end
            ok,err=playSequence(def,context,{bucket=bucket(src)},'admin:'..src)
        end
    elseif action=='stopCompositions' then
        for key,g in pairs(sequences) do if g.owner=='admin:'..src then stopSequence(key,g.owner) end end
        ok=true
    elseif action=='spawn' then
        ok,err=create(data.effectId,data.params,{bucket=bucket(src),onlyTarget=data.onlyTarget},'admin:'..src)
    elseif action=='stop' then
        local e=world[data.id]
        if e and e.bucket==bucket(src) then
            if store.scenes[data.id] then
                local nextStore=FX.copy(store); nextStore.scenes[data.id]=nil
                ok,err=save(nextStore)
                if ok then stop(data.id) end
            else ok=stop(data.id) end
        end
    elseif action=='update' then
        local e=world[data.id]
        if not e or e.bucket~=bucket(src) then return reply(src,false,'Эффект не найден') end
        local p; p,err=FX.params(data.effectId,data.params or {},true)
        if p and validateTarget(p,e.bucket) then
            local record=FX.copy(e); record.effectId=data.effectId; record.params=p; record.sent=nil; record.started=GetGameTimer()
            local kind=FX.byId[data.effectId].kind
            if store.scenes[e.id] then
                if kind=='burst' or p.attach or p.targetServerId then return reply(src,false,'Сцена требует свет или цикл в точке') end
                p.lifetime=0; record.expires=nil
                local nextStore=FX.copy(store); nextStore.scenes[e.id]=record
                remember(record,store.scenes[e.id])
                ok,err=save(nextStore)
            else
                local lifetime=kind=='burst' and (p.repeatCount*p.repeatInterval+5000)/1000 or p.lifetime
                record.expires=lifetime>0 and GetGameTimer()+lifetime*1000 or nil
                ok=true
            end
            if ok then stop(e.id); world[e.id]=record end
        end
    elseif action=='clear' then
        for key,g in pairs(sequences) do if g.bucket==bucket(src) then stopSequence(key,g.owner) end end
        -- Clear transient effects in this bucket; saved scenes require explicit deletion.
        for key,e in pairs(world) do if e.bucket==bucket(src) and not store.scenes[key] then stop(key) end end
        ok=true
    elseif action=='saveScene' then
        local e=world[data.id]
        if not e or e.bucket~=bucket(src) then return reply(src,false,'Выберите эффект мира') end
        if FX.byId[e.effectId].kind=='burst' or e.params.attach or e.params.targetServerId then return reply(src,false,'Сохранить можно только свет или цикл в фиксированной точке') end
        local nextStore=FX.copy(store); local record=FX.copy(e)
        record.name=type(data.name)=='string' and data.name:sub(1,120) or e.effectId
        record.params.lifetime=0; record.expires=nil; record.owner='persistent'
        remember(record,store.scenes[e.id])
        nextStore.scenes[e.id]=record
        ok,err=save(nextStore)
        if ok then
            -- Replace recipient records so their former timers cannot remove a persistent scene.
            stop(e.id); world[e.id]=record
        end
    elseif action=='preset' then
        local name=type(data.name)=='string' and data.name:sub(1,120)
        if not name or name=='' then return reply(src,false,'Укажите имя пресета') end
        if FX.count(store.presets)>=Config.MaxPresets and not store.presets[name] then return reply(src,false,'Лимит пресетов') end
        local p; p,err=FX.params(data.effectId,data.params or {},false)
        if p then
            p.entity=nil; p.targetServerId=nil; p.coords=nil
            local nextStore=FX.copy(store); nextStore.presets[name]={effectId=data.effectId,params=p}
            ok,err=save(nextStore)
        end
    elseif action=='composition' then
        local name=type(data.name)=='string' and data.name:sub(1,120)
        if not name or name=='' then return reply(src,false,'Укажите имя композиции') end
        if FX.count(store.presets)>=Config.MaxPresets and not store.presets[name] then return reply(src,false,'Лимит пресетов') end
        local def; def,err=FX.composition(data.definition)
        if def then
            local nextStore=FX.copy(store); nextStore.presets[name]={definition=def}
            ok,err=save(nextStore)
        end
    elseif action=='deletePreset' then
        local nextStore=FX.copy(store); nextStore.presets[tostring(data.name)]=nil; ok,err=save(nextStore)
    elseif action=='review' then
        if not FX.byId[data.effectId] or (data.status~='visible' and data.status~='invisible' and data.status~='untested') then return end
        local nextStore=FX.copy(store)
        nextStore.reviews[data.effectId]={status=data.status,by=GetPlayerName(src),date=os.date('!%Y-%m-%d'),build=GetConvar('sv_enforceGameBuild','default')}
        ok,err=save(nextStore)
    elseif action=='refresh' then ok=true
    end
    reply(src,ok and true or false,ok and 'Готово' or err or 'Операция не выполнена')
    bootstrap(src)
end)
CreateThread(function()
    local raw=LoadResourceFile(GetCurrentResourceName(),Config.Store)
    if raw then
        local ok,decoded=pcall(json.decode,raw)
        if ok and type(decoded)=='table' and decoded.version==4 and type(decoded.scenes)=='table' and type(decoded.presets)=='table' and type(decoded.reviews)=='table' then
            store=decoded
            if store.annotations~=nil and type(store.annotations)~='table' then store.annotations={};readOnly=true;print('[thehunt_vfx] Invalid annotations; writes disabled') end
            if store.compositions~=nil and type(store.compositions)~='table' then store.compositions={};readOnly=true;print('[thehunt_vfx] Invalid composition store; writes disabled') end
            for key,e in pairs(store.scenes) do
                local p=type(e)=='table' and FX.params(e.effectId,e.params or {},true)
                if p and FX.byId[e.effectId].kind~='burst' and p.coords and not p.attach and not p.targetServerId and FX.count(world)<Config.MaxWorld then
                    p.lifetime=0
                    world[key]={id=key,effectId=e.effectId,params=p,bucket=math.floor(FX.clamp(e.bucket,0,2147483647,0)),owner='persistent',name=e.name,enabled=e.enabled}
                else print('[thehunt_vfx] Skipped invalid saved scene '..tostring(key)) end
            end
        else readOnly=true; print('[thehunt_vfx] Invalid store; writes disabled') end
    end
    print(('[thehunt_vfx] v4: %d catalog entries, %d saved effects'):format(#FX.catalog,FX.count(world)))
    while true do
        local now=GetGameTimer()
        for key,e in pairs(store.compositions or {}) do
            local running=sceneRuns[key]
            if e.enabled~=false and (not running or now>=running.next) then
                if running then stopSequence(running.id,'scene:'..key) end
                local def=type(e)=='table' and FX.composition(e.definition)
                if def and FX.vec(e.coords) then
                    local sequence=playSequence(def,{coords=e.coords},{bucket=e.bucket},'scene:'..key)
                    sceneRuns[key]={id=sequence,next=now+(sequence and def.duration*1000 or 5000)}
                else sceneRuns[key]={next=now+60000} end
            end
        end
        for key,e in pairs(world) do
            if (e.expires and now>=e.expires) or not validateTarget(e.params,e.bucket) then stop(key) end
        end
        for src,seen in pairs(viewers) do
            if GetPlayerName(src) then
                for key in pairs(seen) do
                    if not world[key] or not canSee(src,world[key]) then
                        TriggerClientEvent('thehunt_vfx:remove',src,key); seen[key]=nil
                    end
                end
                for key,e in pairs(world) do
                    if canSee(src,e) and not seen[key] then
                        -- Never replay an old one-shot for late subscribers.
                        local burst=FX.byId[e.effectId].kind=='burst'
                        if not burst or not e.sent then TriggerClientEvent('thehunt_vfx:add',src,packet(e)) end
                        seen[key]=true
                    end
                end
            end
        end
        for _,e in pairs(world) do e.sent=true end
        Wait(250)
    end
end)
AddEventHandler('playerDropped',function()
    local src=source
    for key,g in pairs(sequences) do if g.owner=='admin:'..src then stopSequence(key,g.owner) end end
    for key,e in pairs(world) do
        if e.owner=='admin:'..src or e.params.targetServerId==src then stop(key) end
    end
    viewers[src]=nil; cooldown[src]=nil
end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then return end
    for key,e in pairs(world) do if e.owner==name then stop(key) end end
    for key,g in pairs(sequences) do if g.owner==name then sequences[key]=nil end end
end)
stopSequence=function(key,owner)
    local g=sequences[key]
    if not g or g.owner~=owner then return false end
    sequences[key]=nil
    for _,child in ipairs(g.children) do stop(child,owner) end
    return true
end
playSequence=function(def,context,options,owner)
    if type(def)~='table' or type(def.phases)~='table' or #def.phases<1 or #def.phases>Config.MaxLayers then return false,'Invalid phases' end
    if FX.count(sequences)>=16 then return false,'Sequence limit' end
    local duration=FX.clamp(def.duration,0.1,Config.MaxDuration,10)
    local phases={}
    for _,phase in ipairs(FX.enabledPhases(def)) do
        if type(phase)~='table' then return false,'Некорректный слой' end
        local p=FX.copy(context or {})
        for k,v in pairs(phase.params or {}) do p[k]=v end
        local at=FX.clamp(phase.at or phase.delay,0,duration,0)
        if at>=duration then return false,'Слой начинается после конца композиции' end
        local requested=FX.number(p.lifetime,duration-at)
        p.lifetime=math.min(requested>0 and requested or duration-at,duration-at)
        local clean,err=FX.params(phase.effectId,p,true)
        if not clean then return false,err end
        phases[#phases+1]={at=at,effectId=phase.effectId,params=clean}
    end
    if FX.count(world)+#phases>Config.MaxWorld then return false,'Лимит эффектов мира' end
    local b=math.floor(FX.clamp(options and options.bucket,0,2147483647,0))
    for _,phase in ipairs(phases) do if not validateTarget(phase.params,b) then return false,'Игрок отсутствует или находится в другом измерении' end end
    local key=id('sequence'); local g={owner=owner,children={},bucket=b}; sequences[key]=g
    local start=GetGameTimer()
    for _,phase in ipairs(phases) do
        CreateThread(function()
            Wait(math.max(0,start+phase.at*1000-GetGameTimer()))
            if sequences[key]~=g then return end
            local child,err=create(phase.effectId,phase.params,options,owner)
            if child then g.children[#g.children+1]=child
            else TriggerEvent('thehunt_vfx:sequenceError',key,err,owner) end
        end)
    end
    CreateThread(function()
        Wait(duration*1000)
        if sequences[key]==g then stopSequence(key,owner) end
    end)
    return key
end
exports('PlaySequence',function(def,context,options) return playSequence(def,context,options,GetInvokingResource()) end)
exports('StopSequence',function(key) return stopSequence(key,GetInvokingResource()) end)
exports('CreateNetworkedEffect',function(payload,options)
    if type(payload)~='table' then return false,'Expected effectId and params' end
    return create(payload.effectId,payload.params or payload,type(options)=='table' and options or {},GetInvokingResource())
end)
exports('PlayEffect',function(effectId,params,options) return create(effectId,params,options,GetInvokingResource()) end)
exports('StopNetworkedEffect',function(key) return stop(key,GetInvokingResource()) end)
exports('StopEffect',function(key) return stop(key,GetInvokingResource()) end)
exports('GetCatalog',function() return FX.copy(FX.catalog) end)
exports('GetPersistentScenes',function() return FX.copy(store.scenes) end)
exports('GetPreset',function(name) return FX.copy(store.presets[name]) end)
exports('PlayPreset',function(name,context,options)
    local preset=store.presets[name]
    if not preset then return false,'Unknown preset' end
    if preset.definition then return playSequence(preset.definition,context,options,GetInvokingResource()) end
    local p=FX.copy(preset.params)
    for k,v in pairs(context or {}) do p[k]=v end
    return create(preset.effectId,p,options,GetInvokingResource())
end)
