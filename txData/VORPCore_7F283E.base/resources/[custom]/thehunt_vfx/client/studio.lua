local open,typing,looking,placing=false,false,false,false
local remote,remoteState={},{}
local previewId=nil
local presetCache={}
local uiRevision=0
local gizmo=nil
local function message(action,data) SendNUIMessage({action=action,data=data}) end
local function stopTransport()
    if type(FXPreview)=='table' and type(FXPreview.stop)=='function' then FXPreview.stop() end
end
local function close()
    stopTransport()
    gizmo=nil
    uiRevision=uiRevision+1; open=false; typing=false; looking=false; placing=false
    SetNuiFocus(false,false); SetNuiFocusKeepInput(false)
    FXRuntime.stopOwner('studio'); message('close')
end
local function stopPreview()
    stopTransport()
    if previewId then FXRuntime.stop(previewId); previewId=nil end
    FXRuntime.stopOwner('studio')
end
local function openFocus()
    open=true; SetNuiFocus(true,true); SetNuiFocusKeepInput(true); message('show')
end
RegisterCommand(Config.Command,function() if open then close() else TriggerServerEvent('thehunt_vfx:open') end end,false)
RegisterCommand('hunt_vfx_toggle',function() ExecuteCommand(Config.Command) end,false)
RegisterKeyMapping('hunt_vfx_toggle','HUNT: открыть VFX Studio','keyboard',Config.Key)
RegisterNetEvent('thehunt_vfx:studio',function(data,show)
    if source~=65535 then return end
    presetCache=data.presets or presetCache
    if not open and not show then return end
    if not open then
        openFocus()
        message('catalog',FX.catalog)
    end
    message('studio',data)
end)
RegisterNetEvent('thehunt_vfx:reply',function(ok,text)
    if source~=65535 then return end
    message('status',{ok=ok,text=text})
    TriggerEvent('thehunt_status:notify','VFX',text,ok and 'success' or 'error')
end)
AddEventHandler('thehunt_vfx:result',function(id,ok,text)
    local r=FXRuntime.active[id]
    if r and r.owner=='studio' then message('status',{ok=ok,text=text}) end
end)
AddEventHandler('thehunt_vfx:sequenceError',function(id,err,owner)
    if owner=='studio' then message('status',{ok=false,text=tostring(err)}) end
end)
RegisterNetEvent('thehunt_vfx:add',function(e)
    if source~=65535 or type(e)~='table' then return end
    local p=FX.params(e.effectId,e.params,true); if not p then return end
    if remote[e.id] then FXRuntime.stop('net:'..e.id) end
    e.params=p; remote[e.id]=e; remoteState[e.id]={received=GetGameTimer()}
end)
RegisterNetEvent('thehunt_vfx:remove',function(id)
    if source~=65535 then return end
    remote[id]=nil; remoteState[id]=nil; FXRuntime.stop('net:'..id)
end)
CreateThread(function()
    Wait(1000); TriggerServerEvent('thehunt_vfx:subscribe')
    while true do
        local pos=GetEntityCoords(PlayerPedId())
        for id,e in pairs(remote) do
            local state=remoteState[id]
            local coords=e.params.coords
            if e.params.targetServerId then
                local player=GetPlayerFromServerId(e.params.targetServerId)
                coords=player~=-1 and GetEntityCoords(GetPlayerPed(player)) or nil
            end
            local d=coords and ((pos.x-coords.x)^2+(pos.y-coords.y)^2+(pos.z-coords.z)^2) or math.huge
            local key='net:'..id
            local record=FXRuntime.active[key]
            local limit=Config.StreamDistance+(record and 30 or 0)
            local hidden=LocalPlayer.state.isCreatingChar or LocalPlayer.state.isSelectingChar
            if not hidden and d<=limit^2 then
                if not record and not state.once and GetGameTimer()>=(state.retry or 0) then
                    local playback=FX.copy(e.params)
                    local age=math.max(0,(GetGameTimer()-state.received)/1000)
                    playback.elapsed=(playback.elapsed or 0)+age
                    if playback.lifetime>0 then playback.lifetime=playback.lifetime-age end
                    if e.params.lifetime>0 and playback.lifetime<=0 then state.once=true
                    else FXRuntime.play(e.effectId,playback,'network',key) end
                    state.retry=GetGameTimer()+10000
                    if FX.byId[e.effectId].kind=='burst' then state.once=true end
                end
            elseif record then FXRuntime.stop(key) end
        end
        if open then message('active',FXRuntime.snapshot()) end
        Wait(Config.StreamInterval)
    end
end)
local movement={'INPUT_MOVE_LR','INPUT_MOVE_UD','INPUT_SPRINT','INPUT_JUMP','INPUT_DUCK','INPUT_CLIMB',
    'INPUT_HORSE_MOVE_UD','INPUT_HORSE_MOVE_LR','INPUT_VEH_ACCELERATE','INPUT_VEH_BRAKE','INPUT_PUSH_TO_TALK'}
CreateThread(function()
    while true do
        if open then
            for pad=0,2 do
                DisableAllControlActions(pad)
                if not typing then
                    for _,name in ipairs(movement) do EnableControlAction(pad,GetHashKey(name),true) end
                    if looking or placing then
                        EnableControlAction(pad,GetHashKey('INPUT_LOOK_LR'),true)
                        EnableControlAction(pad,GetHashKey('INPUT_LOOK_UD'),true)
                    end
                end
            end
            DisablePlayerFiring(PlayerPedId(),true)
            Wait(0)
        else Wait(150) end
    end
end)
local function cameraPoint()
    local c=GetGameplayCamCoord(); local rot=GetGameplayCamRot(2)
    local x,z=math.rad(rot.x),math.rad(rot.z)
    local target=c+vector3(-math.sin(z)*math.abs(math.cos(x)),math.cos(z)*math.abs(math.cos(x)),math.sin(x))*120
    local ray=StartShapeTestRay(c.x,c.y,c.z,target.x,target.y,target.z,287,PlayerPedId(),4)
    local deadline=GetGameTimer()+150
    repeat
        local status,hit,coords=GetShapeTestResult(ray)
        if status==2 then
            if hit==1 or hit==true then return FX.vec(coords) end
            return nil
        end
        if status==0 then return nil end
        Wait(0)
    until GetGameTimer()>deadline
end
local function callback(name,handler)
    RegisterNUICallback(name,function(data,cb)
        if not open and name~='close' then cb({ok=false,error='Studio closed'}); return end
        local ok,result=pcall(handler,type(data)=='table' and data or {})
        cb(ok and (result or {ok=true}) or {ok=false,error=tostring(result)})
    end)
end
callback('close',function() close() end)
callback('transport',function(d)
    if type(FXPreview)~='table' or type(FXPreview.control)~='function' then
        return {ok=false,error='Модуль предпросмотра не загружен. Выполните refresh и restart thehunt_vfx в консоли сервера.'}
    end
    return FXPreview.control(d)
end)
callback('focus',function(d) typing=d.value==true end)
callback('look',function(d) looking=d.value==true end)
callback('gizmoStart',function(d)
    local coords=FX.vec(d.coords);if not coords then return {ok=false,error='Некорректная точка'} end
    local def=d.definition and FX.composition(d.definition)
    gizmo={coords=coords,definition=def,rotation={x=0.0,y=0.0,z=0.0},scale=1.0,bases={}}
    for id,r in pairs(FXRuntime.active) do if r.owner=='studio' and not r.params.attach then gizmo.bases[id]=FX.copy(r.params) end end
    typing=true;message('gizmoShow')
end)
callback('gizmoMove',function(d)
    if not gizmo then return end
    local coords=FX.vec(d.coords) or gizmo.coords
    if d.rotation then gizmo.rotation=FX.vec(d.rotation) or gizmo.rotation end
    if d.scale then gizmo.scale=FX.clamp(d.scale,0.01,10,1) end
    gizmo.coords=coords
    for id,r in pairs(FXRuntime.active) do
        if r.owner=='studio' and not r.params.attach then
            if gizmo.bases[id] then r.params=FX.transformParams(gizmo.bases[id],gizmo.rotation,gizmo.scale) end
            r.params.coords=coords
            if r.handle then
                local o,t=FX.frame(r.params,(GetGameTimer()-r.started)/1000)
                SetParticleFxLoopedOffsets(r.handle,coords.x+o.x,coords.y+o.y,coords.z+o.z,t.x,t.y,t.z)
                SetParticleFxLoopedScale(r.handle,r.params.scale)
            end
        end
    end
end)
callback('gizmoEnd',function(d)
    if gizmo and not d.cancel then message('coords',gizmo.coords) end
    if gizmo and not d.cancel and gizmo.definition then
        for _,phase in ipairs(gizmo.definition.phases) do phase.params=FX.transformParams(phase.params,gizmo.rotation,gizmo.scale) end
        message('gizmoDefinition',gizmo.definition)
    end
    if d.cancel then FXRuntime.stopOwner('studio') end
    gizmo=nil;typing=false;message('show')
end)
CreateThread(function()
    while true do
        if gizmo and open then
            local c=gizmo.coords
            local points={}
            for _,axis in ipairs({'x','y','z'}) do
                local endpoint={x=c.x,y=c.y,z=c.z};endpoint[axis]=endpoint[axis]+1.0
                local red,green,blue=axis=='x' and 255 or 60,axis=='y' and 220 or 60,axis=='z' and 255 or 60
                DrawLine(c.x,c.y,c.z,endpoint.x,endpoint.y,endpoint.z,red,green,blue,255)
                local visible,x,y=GetScreenCoordFromWorldCoord(endpoint.x,endpoint.y,endpoint.z)
                if visible then points[axis]={x=x,y=y} end
            end
            local visible,x,y=GetScreenCoordFromWorldCoord(c.x,c.y,c.z)
            if GetGameTimer()>=(gizmo.nextMessage or 0) then
                message('gizmoAxes',{axes=points,origin=visible and {x=x,y=y} or nil,coords=c});gizmo.nextMessage=GetGameTimer()+50
            end
            Wait(0)
        else Wait(150) end
    end
end)
callback('coords',function() return {ok=true,coords=FX.vec(GetEntityCoords(PlayerPedId()))} end)
callback('aim',function()
    if placing then return end
    placing=true; typing=false; stopPreview()
    local revision=uiRevision
    SetNuiFocus(false,false); message('placing')
    CreateThread(function()
        Wait(200)
        while placing and open and revision==uiRevision do
            local c=cameraPoint()
            if c then
                DrawLine(c.x-0.2,c.y,c.z,c.x+0.2,c.y,c.z,56,189,248,255)
                DrawLine(c.x,c.y-0.2,c.z,c.x,c.y+0.2,c.z,56,189,248,255)
                if IsDisabledControlJustPressed(0,GetHashKey('INPUT_ATTACK')) then message('coords',c); break end
            end
            if IsDisabledControlJustPressed(0,GetHashKey('INPUT_AIM')) or IsDisabledControlJustPressed(0,GetHashKey('INPUT_FRONTEND_CANCEL')) then break end
            Wait(0)
        end
        placing=false
        if open and revision==uiRevision then openFocus() end
    end)
end)
callback('preview',function(d)
    stopPreview()
    local p=d.params or {}
    if d.self then p.entity=PlayerPedId(); p.attach=true; p.targetServerId=nil end
    p.lifetime=FX.clamp(p.lifetime,0.1,30,5)
    local id,err=FXRuntime.play(d.effectId,p,'studio')
    previewId=id
    return {ok=id~=false,id=id,error=err}
end)
callback('stopPreview',function() stopPreview() end)
callback('previewComposition',function(d)
    stopTransport()
    local def,err=FX.composition(d.definition)
    if not def then return {ok=false,error=err} end
    if def.duration>30 then return {ok=false,error='Локальный тест ограничен 30 секундами'} end
    FXRuntime.stopOwner('studio')
    local context={coords=FX.vec(d.coords)}
    if d.targetServerId then context.targetServerId=FX.number(d.targetServerId) end
    if d.self then context.entity=PlayerPedId() end
    local id; id,err=FXRuntime.sequence(def,context,'studio')
    return {ok=id~=false,id=id,error=err}
end)
callback('action',function(d)
    TriggerServerEvent('thehunt_vfx:action',d.action,d.data)
end)
callback('stopLocal',function(d)
    local r=FXRuntime.active[d.id]
    if r and r.owner=='studio' then FXRuntime.stop(d.id) end
end)
exports('PlayPreset',function(name,context)
    local preset=presetCache[name]
    if not preset then return false,'Unknown preset or initial sync pending' end
    if preset.definition then return FXRuntime.sequence(preset.definition,context,GetInvokingResource()) end
    local p=FX.copy(preset.params)
    for k,v in pairs(context or {}) do p[k]=v end
    return FXRuntime.play(preset.effectId,p,GetInvokingResource())
end)
RegisterNetEvent('thehunt_vfx:presets',function(data)
    if source==65535 and type(data)=='table' then presetCache=data end
end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then close() end
end)
