local opened,inputFocused,preview=false,false,nil
local requests,sequence={},0
local nearby={}
local function notify(message,kind) TriggerEvent('thehunt_status:notify','Мёртвые',message,kind or 'info') end
local function request(action,args)
    sequence=sequence+1; local id=sequence; local p=promise.new(); requests[id]=p
    TriggerServerEvent('thehunt_zombie:request',id,action,args or {})
    SetTimeout(12000,function() if requests[id] then requests[id]=nil; p:resolve({ok=false,error='Сервер не ответил'}) end end)
    return Citizen.Await(p)
end
RegisterNetEvent('thehunt_zombie:reply',function(id,ok,data)
    if source~=65535 then return end
    local p=requests[id]; if not p then return end
    requests[id]=nil; p:resolve({ok=ok,data=ok and data or nil,error=not ok and data or nil})
end)
local function focus(value)
    opened=value; inputFocused=false
    SetNuiFocus(value,value); SetNuiFocusKeepInput(value)
    if not value then preview=nil; SendNUIMessage({action='close'}) end
end
AddEventHandler('thehunt_zombie:openEditor',function()
    CreateThread(function()
        local response=request('list')
        if not response.ok then notify(response.error,'error'); return end
        focus(true); SendNUIMessage({action='open',data=response.data,position=Zombie.coords(GetEntityCoords(PlayerPedId()))})
    end)
end)
RegisterCommand('zombieeditor',function() TriggerEvent('thehunt_zombie:openEditor') end,false)
AddEventHandler('thehunt_zombie:toggleInfo',function()
    CreateThread(function() local r=request('info'); if not r.ok then notify(r.error,'error') end end)
end)
AddEventHandler('thehunt_zombie:toggleImmunity',function()
    CreateThread(function()
        local r=request('immunity')
        if r.ok then notify(r.data.enabled and 'Мёртвые игнорируют вас' or 'Агрессия к вам включена')
        else notify(r.error,'error') end
    end)
end)
RegisterNetEvent('thehunt_zombie:adminFlags',function(info,debug)
    if source~=65535 then return end
    ZC.info=info; ZC.debug=debug
    TriggerEvent('thehunt_zombie:adminState',{zombieInfo=info})
end)
AddEventHandler('thehunt_zombie:immunity',function(id,enabled)
    if source~=65535 then return end
    if id==GetPlayerServerId(PlayerId()) then TriggerEvent('thehunt_zombie:adminState',{zombieImmune=enabled}) end
end)
RegisterNUICallback('close',function(_,cb) focus(false); cb({ok=true}) end)
RegisterNUICallback('setInputFocusState',function(data,cb)
    inputFocused=data.hasFocus==true; SetNuiFocusKeepInput(opened and not inputFocused); cb({ok=true})
end)
RegisterNUICallback('position',function(_,cb) cb(Zombie.coords(GetEntityCoords(PlayerPedId()))) end)
RegisterNUICallback('preview',function(data,cb)
    if type(data)=='table' and tonumber(data.x) and tonumber(data.y) and tonumber(data.z) then
        preview={x=tonumber(data.x),y=tonumber(data.y),z=tonumber(data.z),radius=math.min(500,math.max(1,tonumber(data.radius) or 40)),
            spawnRadius=math.min(200,math.max(0,tonumber(data.spawnRadius) or 30))}
    end
    cb({ok=true})
end)
RegisterNUICallback('request',function(data,cb)
    if not opened then cb({ok=false,error='Редактор закрыт'}); return end
    CreateThread(function()
        local response=request(data.action,data.args or {})
        if not response.ok then notify(response.error,'error') end
        cb(response)
    end)
end)
RegisterNetEvent('thehunt_zombie:teleport',function(pos)
    if source~=65535 then return end
    focus(false)
    CreateThread(function()
        local ped=PlayerPedId(); DoScreenFadeOut(200); Wait(250)
        RequestCollisionAtCoord(pos.x,pos.y,pos.z)
        FreezeEntityPosition(ped,true); SetEntityCoords(ped,pos.x,pos.y,pos.z+0.5,false,false,false,false)
        local deadline=GetGameTimer()+3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer()<deadline do Wait(50) end
        FreezeEntityPosition(ped,false); DoScreenFadeIn(200)
    end)
end)
CreateThread(function()
    local whitelist={0xF1301666,0x05CA7C52,GetHashKey('INPUT_PUSH_TO_TALK'),GetHashKey('INPUT_MOVE_LR'),GetHashKey('INPUT_MOVE_UD'),
        GetHashKey('INPUT_SPRINT'),GetHashKey('INPUT_JUMP'),GetHashKey('INPUT_DUCK')}
    while true do
        Wait(opened and 0 or 150)
        if opened then
            for pad=0,2 do
                DisableAllControlActions(pad)
                if not inputFocused then for _,control in ipairs(whitelist) do EnableControlAction(pad,control,true) end end
            end
            DisablePlayerFiring(PlayerPedId(),true)
            if preview and GetResourceState('thehunt_shapes')=='started' then
                exports.thehunt_shapes:DrawHoop(preview.x,preview.y,preview.z+0.2,preview.radius,0.08,56,189,248,180,48)
                exports.thehunt_shapes:DrawHoop(preview.x,preview.y,preview.z+0.25,preview.spawnRadius,0.06,34,197,94,180,32)
            end
        end
    end
end)
CreateThread(function()
    while true do
        Wait(400); nearby={}
        if ZC.info or ZC.debug then
            local me=GetEntityCoords(PlayerPedId())
            for _,r in pairs(ZC.peds) do
                local ped=ZC.entity(r)
                if ped then local dist=Zombie.distance(me,GetEntityCoords(ped))
                    if dist<ZombieConfig.InfoDistance then nearby[#nearby+1]={r=r,ped=ped,dist=dist} end
                end
            end
            table.sort(nearby,function(a,b)return a.dist<b.dist end)
            while #nearby>ZombieConfig.InfoLimit do table.remove(nearby) end
        end
    end
end)
CreateThread(function()
    while true do
        Wait((ZC.info or ZC.debug) and 0 or 500)
        if ZC.info or ZC.debug then
            for _,entry in ipairs(nearby) do
                local r,ped=entry.r,entry.ped
                if DoesEntityExist(ped) and ZC.peds[r.id]==r then
                    local head=GetPedBoneCoords(ped,21030,0.0,0.0,0.0)
                    local visible,x,y=GetScreenCoordFromWorldCoord(head.x,head.y,head.z+0.45)
                    if visible then
                        local hp,max=ZC.health(r,ped); local extra=''
                        if ZC.debug then
                            local d=ZC.debugData[r.id] or r
                            local last=d.last and ('%.0f,%.0f,%.0f'):format(d.last.x,d.last.y,d.last.z) or '-'
                            extra=('net:%s / zone:%s / %s / target:%s / %s / last:%s / to:%s'):format(
                                r.net,r.zone,d.state or '-',d.target or '-',d.reason or '-',last,r.destination or '-')
                        end
                        exports.thehunt_core:DrawOverheadTag(x,y,r.model..' · '..r.settings.name,('HP: %d / %d'):format(hp,max),extra,entry.dist)
                    end
                end
            end
        end
    end
end)
