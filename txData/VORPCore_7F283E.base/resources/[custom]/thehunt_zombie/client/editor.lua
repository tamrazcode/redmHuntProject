local opened,inputFocused,preview=false,false,nil
local requests,sequence={},0
local nearby={}
local zoneCam={active=false,handle=nil,pos=nil,rot=nil,original=nil,focus=nil}

local function stopZoneCamera()
    if not zoneCam.active then return end
    zoneCam.active=false
    if zoneCam.handle and DoesCamExist(zoneCam.handle) then
        SetCamActive(zoneCam.handle,false)
        DestroyCam(zoneCam.handle,true)
    end
    zoneCam.handle=nil
    RenderScriptCams(false,true,300,true,false)
    ClearFocus()
    local ped=PlayerPedId()
    if zoneCam.original and DoesEntityExist(ped) then
        SetEntityCoords(ped,zoneCam.original.x,zoneCam.original.y,zoneCam.original.z,false,false,false,false)
        FreezeEntityPosition(ped,false)
        SetEntityVisible(ped,true)
        SetEntityInvincible(ped,false)
    end
    zoneCam.original=nil
end

local function startZoneCamera()
    if zoneCam.active then return true end
    local ped=PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    zoneCam.original=Zombie.coords(GetEntityCoords(ped))
    zoneCam.pos=GetGameplayCamCoord()
    zoneCam.rot=GetGameplayCamRot(2)
    zoneCam.focus=zoneCam.pos
    zoneCam.handle=CreateCam('DEFAULT_SCRIPTED_CAMERA',true)
    if not zoneCam.handle or not DoesCamExist(zoneCam.handle) then zoneCam.handle=nil; return false end
    SetCamCoord(zoneCam.handle,zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z)
    SetCamRot(zoneCam.handle,zoneCam.rot.x,zoneCam.rot.y,zoneCam.rot.z,2)
    SetCamActive(zoneCam.handle,true)
    RenderScriptCams(true,true,300,true,false)
    SetEntityVisible(ped,false)
    SetEntityInvincible(ped,true)
    FreezeEntityPosition(ped,true)
    RequestCollisionAtCoord(zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z)
    SetFocusPosAndVel(zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z,0.0,0.0,0.0)
    zoneCam.active=true
    CreateThread(function()
        while zoneCam.active do
            Wait(0)
            local speed=0.4
            if IsDisabledControlPressed(0,0x8FFC75D6) then speed=1.6
            elseif IsDisabledControlPressed(0,0xDBCD0363) then speed=0.1 end
            -- The free camera must never claim LMB: the gizmo receives that
            -- button to grab an axis or ring.  Camera look is RMB only.
            local rightMouse=IsDisabledControlPressed(0,0xF84FA74F)
            if rightMouse then
                local mouseX=GetDisabledControlNormal(0,0xA987235F)*4.0
                local mouseY=GetDisabledControlNormal(0,0xD2047988)*4.0
                zoneCam.rot=vector3(math.max(-85.0,math.min(85.0,zoneCam.rot.x-(mouseY*8.0))),0.0,zoneCam.rot.z-(mouseX*8.0))
            end
            local rz,rx=math.rad(zoneCam.rot.z),math.rad(zoneCam.rot.x)
            local forward=vector3(-math.sin(rz)*math.cos(rx),math.cos(rz)*math.cos(rx),math.sin(rx))
            local right=vector3(math.cos(rz),math.sin(rz),0.0)
            if IsDisabledControlPressed(0,0x8FD015D8) then zoneCam.pos=zoneCam.pos+forward*speed end -- W
            if IsDisabledControlPressed(0,0xD27782E3) then zoneCam.pos=zoneCam.pos-forward*speed end -- S
            if IsDisabledControlPressed(0,0x7065027D) then zoneCam.pos=zoneCam.pos-right*speed end -- A
            if IsDisabledControlPressed(0,0xB4E465B4) then zoneCam.pos=zoneCam.pos+right*speed end -- D
            if IsDisabledControlPressed(0,0xDE794E3E) then zoneCam.pos=zoneCam.pos+vector3(0,0,speed) end -- Q
            if IsDisabledControlPressed(0,0xCEFD9220) then zoneCam.pos=zoneCam.pos-vector3(0,0,speed) end -- E
            if zoneCam.handle and DoesCamExist(zoneCam.handle) then
                SetCamCoord(zoneCam.handle,zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z)
                SetCamRot(zoneCam.handle,zoneCam.rot.x,zoneCam.rot.y,zoneCam.rot.z,2)
            end
            if Zombie.distance(zoneCam.pos,zoneCam.focus)>25.0 then
                zoneCam.focus=zoneCam.pos
                local player=PlayerPedId()
                SetEntityCoords(player,zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z,false,false,false,false)
                RequestCollisionAtCoord(zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z)
                SetFocusPosAndVel(zoneCam.pos.x,zoneCam.pos.y,zoneCam.pos.z,0.0,0.0,0.0)
            end
        end
    end)
    return true
end

local function drawWireCircle(cx, cy, cz, radius, r, g, b, a, segs)
    local segments = segs or 64
    local step = (math.pi * 2.0) / segments
    local prevX = cx + math.cos(0) * radius
    local prevY = cy + math.sin(0) * radius
    for i = 1, segments do
        local angle = i * step
        local curX = cx + math.cos(angle) * radius
        local curY = cy + math.sin(angle) * radius
        DrawLine(prevX, prevY, cz, curX, curY, cz, r, g, b, a)
        prevX = curX
        prevY = curY
    end
end

local function drawZoneVolume(zone, alpha)
    if not zone then return end
    local radius = math.max(0, tonumber(zone.radius) or 40)
    local height = math.min(100, math.max(1, tonumber(zone.height) or 8))
    local spawnRad = math.max(0, tonumber(zone.spawnRadius) or math.floor(radius * 0.75))
    local cz = tonumber(zone.z) or 0
    local bottom = cz - (height * 0.5)
    local top = cz + (height * 0.5)
    local x = tonumber(zone.x) or 0
    local y = tonumber(zone.y) or 0
    local a = math.min(255, math.max(50, tonumber(alpha) or 220))

    -- 1. Native sharp wire circles (always visible at any distance/angle)
    -- Main zone boundary ring (Blue #38bdf8 / RGB 56, 189, 248)
    drawWireCircle(x, y, cz + 0.15, radius, 56, 189, 248, a, 64)
    drawWireCircle(x, y, bottom, radius, 56, 189, 248, math.floor(a * 0.75), 48)
    drawWireCircle(x, y, top, radius, 56, 189, 248, math.floor(a * 0.75), 48)

    -- Vertical boundary ribs
    for i = 0, 11 do
        local angle = (math.pi * 2.0 * i) / 12
        local px = x + math.cos(angle) * radius
        local py = y + math.sin(angle) * radius
        DrawLine(px, py, bottom, px, py, top, 56, 189, 248, math.floor(a * 0.7))
    end

    -- Inner spawn radius ring (Green #22c55e / RGB 34, 197, 94)
    if spawnRad > 0 then
        drawWireCircle(x, y, cz + 0.20, spawnRad, 34, 197, 94, a, 64)
    end

    -- 2. Enhanced volumetric shapes via thehunt_shapes if available
    if GetResourceState('thehunt_shapes') == 'started' and exports.thehunt_shapes then
        pcall(function()
            -- Thick glowing 3D hoops
            exports.thehunt_shapes:DrawHoop(x, y, cz + 0.15, radius, 0.30, 56, 189, 248, a, 64)
            if spawnRad > 0 then
                exports.thehunt_shapes:DrawHoop(x, y, cz + 0.20, spawnRad, 0.22, 34, 197, 94, a, 48)
            end
            -- Translucent cylindrical volume
            if exports.thehunt_shapes.DrawCylinder then
                exports.thehunt_shapes:DrawCylinder(x, y, cz, radius, height, 56, 189, 248, 45, 48, true)
            end
        end)
    end
end

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
        local catalog = {}
        if exports['thehunt_items'] and exports['thehunt_items'].GetAllItems then
            local ok, cat = pcall(function() return exports['thehunt_items']:GetAllItems() end)
            if ok and cat then catalog = cat end
        end
        focus(true); SendNUIMessage({action='open',data=response.data,catalog=catalog,position=Zombie.coords(GetEntityCoords(PlayerPedId()))})
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
        preview={x=tonumber(data.x),y=tonumber(data.y),z=tonumber(data.z),radius=math.max(0,tonumber(data.radius) or 40),height=math.min(100,math.max(1,tonumber(data.height) or 8)),
            spawnRadius=math.max(0,tonumber(data.spawnRadius) or 30)}
    end
    cb({ok=true})
end)
RegisterNUICallback('gizmo',function(data,cb)
    local zone=data and data.zone
    if not opened or type(zone)~='table' then cb({ok=false,error='Редактор закрыт'}); return end
    if GetResourceState('thehunt_gizmo')~='started' then cb({ok=false,error='thehunt_gizmo не запущен'}); return end
    local origin={x=tonumber(zone.x) or 0,y=tonumber(zone.y) or 0,z=tonumber(zone.z) or 0}
    local originalRadius=math.max(0,tonumber(zone.radius) or 40)
    local originalHeight=math.min(100,math.max(1,tonumber(zone.height) or 8))
    local originalHeading=math.min(180,math.max(-180,tonumber(zone.heading) or 0))
    local working=Zombie.copy(zone)
    local function apply(value)
        working.x=origin.x+value.x; working.y=origin.y+value.y; working.z=origin.z+value.z
        working.heading=value.rz
        -- A zombie zone is round, so X/Y scale together as its radius.
        working.radius=math.max(0,(value.sx+value.sy)*0.5)
        working.height=math.min(100,math.max(1,value.sz))
    end
    focus(false)
    if not startZoneCamera() then
        focus(true)
        SendNUIMessage({action='gizmoZone',zone=working,saved=false})
        cb({ok=false,error='Не удалось запустить свободную камеру редактора'})
        return
    end
    local started=exports.thehunt_gizmo:Start({
        title='Зона мёртвых: положение, размер и поворот',
        value={x=0,y=0,z=0,rx=0,ry=0,rz=originalHeading,sx=originalRadius,sy=originalRadius,sz=originalHeight},
        defaults={x=0,y=0,z=0,rx=0,ry=0,rz=originalHeading,sx=originalRadius,sy=originalRadius,sz=originalHeight},
        limits={x={-500,500},y={-500,500},z={-100,100},rx={-180,180},ry={-180,180},rz={-180,180},sx={0,100000},sy={0,100000},sz={1,100}},
        allowScale=true,
        point=function(value) return vector3(origin.x+value.x,origin.y+value.y,origin.z+value.z) end,
        cameraPoint=function() return zoneCam.pos end,
        apply=apply,
        valid=function() return zoneCam.active and GetResourceState('thehunt_gizmo')=='started' end,
        tick=function(value)
            apply(value)
            drawZoneVolume(working,220)
        end,
        finish=function(saved,value)
            apply(value)
            stopZoneCamera()
            focus(true)
            SendNUIMessage({action='gizmoZone',zone=working,saved=saved==true})
        end,
    })
    if not started then
        stopZoneCamera()
        focus(true)
        SendNUIMessage({action='gizmoZone',zone=working,saved=false})
        cb({ok=false,error='Gizmo уже занят или интерфейс не освобождён'})
        return
    end
    cb({ok=true})
end)
RegisterNUICallback('previewOutfit',function(data,cb)
    local model = data and data.model
    local outfit = tonumber(data and data.outfit) or 0
    if not model or not ZombieModels[model] then cb({ok=false,error='Неизвестная модель'}); return end
    CreateThread(function()
        local hash = GetHashKey(model)
        if not IsModelValid(hash) or not IsModelAPed(hash) then cb({ok=false,error='Недопустимая модель'}); return end
        RequestModel(hash)
        local deadline = GetGameTimer() + 4000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(50) end
        if not HasModelLoaded(hash) then cb({ok=false,error='Таймаут загрузки модели'}); return end
        local pPed = PlayerPedId()
        local fwd = GetEntityForwardVector(pPed)
        local pCoords = GetEntityCoords(pPed)
        local spawnPos = pCoords + fwd * 2.5
        local ped = CreatePed(hash, spawnPos.x, spawnPos.y, spawnPos.z, (GetEntityHeading(pPed) + 180.0) % 360.0, false, false, false, false)
        if ped and ped ~= 0 then
            SetEntityAsMissionEntity(ped, true, true)
            Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfit, false)
            Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(hash)
            notify(('Тест разновидности #%s модели %s'):format(outfit, model), 'info')
            cb({ok=true})
            Wait(6000)
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        else
            SetModelAsNoLongerNeeded(hash)
            cb({ok=false,error='Не удалось создать педа'})
        end
    end)
end)
RegisterNUICallback('getCatalog', function(_, cb)
    local catalog = {}
    if exports['thehunt_items'] and exports['thehunt_items'].GetAllItems then
        local ok, cat = pcall(function() return exports['thehunt_items']:GetAllItems() end)
        if ok and cat then catalog = cat end
    end
    cb(catalog)
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
            if preview then
                drawZoneVolume(preview, 220)
            end
        end
    end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource==GetCurrentResourceName() then stopZoneCamera() end
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
local stateRu = {
    IDLE = 'ПОКОЙ (IDLE)',
    WANDER = 'БРОЖЕНИЕ (WANDER)',
    ALERT = 'ТРЕВОГА (ALERT)',
    CHASE = 'ПОГОНЯ (CHASE)',
    ATTACK = 'АТАКА (ATTACK)',
    SEARCH = 'ПОИСК (SEARCH)',
    INVESTIGATE_SOUND = 'ПРОВЕРКА ЗВУКА',
    RETURN = 'ВОЗВРАТ (RETURN)',
    MIGRATION = 'МИГРАЦИЯ',
    DEAD = 'МЁРТВ'
}

CreateThread(function()
    while true do
        Wait((ZC.info or ZC.debug) and 0 or 500)
        if ZC.info or ZC.debug then
            for _,entry in ipairs(nearby) do
                local r,ped=entry.r,entry.ped
                if DoesEntityExist(ped) and ZC.peds[r.id]==r then
                    local head=GetPedBoneCoords(ped,21030,0.0,0.0,0.0)
                    local visible,x,y=GetScreenCoordFromWorldCoord(head.x,head.y,head.z+0.55)
                    if visible then
                        local hp,max=ZC.health(r,ped)
                        local d=ZC.debugData[r.id] or r
                        local currentState = d.state or r.state or 'IDLE'
                        if currentState == 'CHASE' and entry.dist and entry.dist <= 2.4 then
                            currentState = 'ATTACK'
                        end
                        local stateLabel = stateRu[currentState] or currentState
                        local aggLevel = math.floor(tonumber(r.settings and r.settings.aggression) or 1)

                        local genderStr = 'М'
                        if type(IsPedMale) == 'function' then
                            genderStr = IsPedMale(ped) and 'М' or 'Ж'
                        else
                            local m = string.lower(tostring(r.model or ''))
                            if m:find('_f_') or m:find('female') or m:find('prostitute') then genderStr = 'Ж' end
                        end

                        local walk = (r.settings and (r.settings.chosenWalkStyle or r.settings.walkStyle)) or 'MP_Style_drunk'
                        local targetId = r.target or d.target
                        local topInfo = ('[%s | АГР: %d] · ПОЛ: %s · ПОХОДКА: %s'):format(stateLabel, aggLevel, genderStr, walk)
                        if targetId then
                            topInfo = ('[%s | АГР: %d] · ПОЛ: %s · ЦЕЛЬ: ID %s'):format(stateLabel, aggLevel, genderStr, tostring(targetId))
                        end

                        local line2 = r.model .. ' · ' .. (r.settings and r.settings.name or 'Мёртвый')
                        local line3 = ('HP: %d / %d  |  ДИСТ: %.1fм'):format(hp, max, entry.dist)
                        if ZC.debug then
                            local last = d.last and ('%.0f,%.0f,%.0f'):format(d.last.x,d.last.y,d.last.z) or '-'
                            line3 = ('HP: %d/%d | zone:%s | net:%s | last:%s'):format(hp, max, tostring(r.zone or '-'), tostring(r.net or '-'), last)
                        end

                        exports.thehunt_core:DrawOverheadTag(x, y, topInfo, line2, line3, entry.dist)
                    end
                end
            end
        end
    end
end)
