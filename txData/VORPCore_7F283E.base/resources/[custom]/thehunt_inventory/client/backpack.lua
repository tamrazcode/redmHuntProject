-- HUNT physical backpacks: authoritative per-item fit and local streamed replicas.
local BACKPACK_MODELS = {
    ["kh_backpack1"]  = true,
    ["kh_backpack2"]  = true,
    ["kh_backpack3"]  = true,
    ["kh_backpack4"]  = true,
    ["kh_backpack5"]  = true,
    ["kh_backpack6"]  = true,
    ["kh_backpack7"]  = true,
    ["kh_backpack8"]  = true,
    ["kh_backpack9"]  = true,
    ["kh_backpack10"] = true,
    ["kh_backpack12"] = true,
    ["kh_backpack13"] = true,
    ["kh_backpack14"] = true,
    ["kh_backpack15"] = true,
    ["kh_backpack16"] = true,
    ["khbp1"]         = true,
    ["khbp2"]         = true,
    ["khbp3"]         = true,
    ["khbp4"]         = true,
    ["khbp5"]         = true,
}

local ITEM_TO_MODEL = {
    backpack_1  = "kh_backpack1",
    backpack_2  = "kh_backpack2",
    backpack_3  = "kh_backpack3",
    backpack_4  = "kh_backpack4",
    backpack_5  = "kh_backpack5",
    backpack_6  = "kh_backpack6",
    backpack_7  = "kh_backpack7",
    backpack_8  = "kh_backpack8",
    backpack_9  = "kh_backpack9",
    backpack_10 = "kh_backpack10",
    backpack_11 = "kh_backpack12",
    backpack_12 = "kh_backpack13",
    backpack_13 = "kh_backpack14",
    backpack_14 = "kh_backpack15",
    backpack_15 = "kh_backpack16",
    backpack_16 = "khbp1",
    backpack_17 = "khbp2",
    backpack_18 = "khbp3",
    backpack_19 = "khbp4",
    backpack_20 = "khbp5",
}

local replicas = {}
local serverBackpacks, serverProfiles = {}, nil
local function ownState()
    return serverBackpacks[GetPlayerServerId(PlayerId())] or LocalPlayer.state
end
local function modelProfiles()
    return serverProfiles or GlobalState.huntBackpackProfiles or {}
end
RegisterNetEvent('thehunt_inventory:backpackState', function(id, packet)
    id = tonumber(id)
    if id and type(packet) == 'table' then serverBackpacks[id] = packet end
end)
RegisterNetEvent('thehunt_inventory:backpackStates', function(packets, profiles)
    local nextStates = {}
    for id, packet in pairs(packets or {}) do nextStates[tonumber(id)] = packet end
    serverBackpacks, serverProfiles = nextStates, profiles or {}
end)
RegisterNetEvent('thehunt_inventory:backpackProfiles', function(profiles)
    serverProfiles = profiles
    for _, record in pairs(replicas) do record.signature = nil end
end)
CreateThread(function()
    while true do
        TriggerServerEvent('thehunt_items:requestBackpackStates')
        Wait(10000)
    end
end)
local localDesiredBackpack = nil
local editing, pendingEdit, awaitingSave = nil, nil, nil
local function notify(text, kind)
    TriggerEvent('thehunt_status:notify', 'Рюкзак', text, kind or 'info')
end
local function ownId() return GetPlayerServerId(PlayerId()) end
local function validModel(model)
    if type(model) == 'number' then
        for name in pairs(BACKPACK_MODELS) do if GetHashKey(name) == model then return name end end
    elseif type(model) == 'string' and BACKPACK_MODELS[model:lower()] then return model:lower() end
end
local function resolve(item)
    return item and (validModel(item.propModel) or ITEM_TO_MODEL[item.name] or validModel(item.name))
end
function GetBackpackBoneIndex(ped)
    -- Resolve by name first: this is the path that was already proven on the
    -- current male/female MetaPeds. The RDR bone ID is only a fallback.
    for _, name in ipairs({'SKEL_Spine2','skel_spine2','SKEL_Spine3','skel_spine3'}) do
        local index = GetEntityBoneIndexByName(ped, name)
        if index and index ~= -1 and index ~= 0 then return index end
    end
    return GetPedBoneIndex(ped, BackpackFit.BoneId)
end
local function getBackpackBoneCoords(ped, x, y, z)
    -- GetPedBoneCoords expects the RDR bone id (Spine2 = 14412), while
    -- AttachEntityToEntity expects the entity's resolved bone index.
    return GetPedBoneCoords(ped, BackpackFit.BoneId, x or 0.0, y or 0.0, z or 0.0)
end
local MODEL_BASE_FIT = {
    __default = {
        x = 0.0,
        y_female = -0.15,
        y_male = -0.17,
        z_female = 0.12,
        z_male = 0.10,
        rx = -90.0,
        ry = 0.0,
        rz = 0.0,
    },
}

local function profileFit(ped, fit, model, calibration)
    if calibration then return calibration end
    local profiles = modelProfiles()
    local base = profiles[model] or {}
    local result = {}
    for _, key in ipairs(BackpackFit.Keys) do result[key] = (base[key] or 0.0) + (fit[key] or 0.0) end
    return result
end
local function centre(ped, outerwear, fit, model, calibration)
    local female = IsPedMale(ped) == false or IsPedMale(ped) == 0
    fit = profileFit(ped, fit or {}, model, calibration)
    local mfit = (model and MODEL_BASE_FIT[model]) or MODEL_BASE_FIT.__default
    local baseY = female and mfit.y_female or mfit.y_male
    local baseZ = female and mfit.z_female or mfit.z_male
    return {
        x = (mfit.x or 0.0) + (fit.x or 0.0),
        y = baseY - (outerwear and 0.04 or 0.0) + (fit.y or 0.0),
        z = baseZ + (fit.z or 0.0),
    }
end
local function attach(record, fit)
    if not record or not record.entity or not DoesEntityExist(record.entity) then return end
    fit = fit or {}
    local calibration = editing and editing.admin and record.ped == editing.ped and fit or record.calibration
    local applied = profileFit(record.ped, fit, record.model, calibration)
    local mfit = (record.model and MODEL_BASE_FIT[record.model]) or MODEL_BASE_FIT.__default
    local c = centre(record.ped, record.outerwear, fit, record.model, calibration)
    local rx = (mfit.rx or -90.0) + applied.rx + 0.0
    local ry = (mfit.ry or 0.0) + applied.ry + 0.0
    local rz = (mfit.rz or 0.0) + applied.rz + 0.0
    AttachEntityToEntity(
        record.entity,
        record.ped,
        GetBackpackBoneIndex(record.ped),
        c.x, c.y, c.z,
        rx, ry, rz,
        false,
        false,
        false,
        false,
        2,
        true
    )
    FreezeEntityPosition(record.entity, false)
    SetEntityVisible(record.entity, true)
    ResetEntityAlpha(record.entity)
    SetEntityAlpha(record.entity, 255, false)
    SetEntityLodDist(record.entity, 250)
    record.fit = fit
end
local function deleteReplica(id)
    local record = replicas[id]
    if not record then return end
    replicas[id] = nil -- invalidates an in-flight model load before it can spawn
    if record.entity and DoesEntityExist(record.entity) then
        DetachEntity(record.entity, true, true)
        SetEntityAsMissionEntity(record.entity, true, true)
        DeleteEntity(record.entity)
    end
end
local function packetFit(packet, model)
    if type(packet) == 'table' and packet.model == model then
        return BackpackFit.Normalize(packet.offset) or BackpackFit.Normalize({})
    end
    return BackpackFit.Normalize({})
end
local function signature(fit, outerwear)
    local values = {outerwear and 'coat' or 'shirt'}
    for _,key in ipairs(BackpackFit.Keys) do values[#values+1] = string.format('%.5f',fit[key]) end
    return table.concat(values, ':')
end
local function ensureReplica(id, ped, model, packet, outerwear)
    model = validModel(model)
    if not model or not ped or ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then deleteReplica(id); return end
    local fit = editing and id == ownId() and editing.value or packetFit(packet, model)
    local calibration = type(packet) == 'table' and packet.calibration or nil
    local sig = signature(fit, outerwear) .. json.encode(calibration or modelProfiles()[model] or {})
    local record = replicas[id]
    if record and (record.ped ~= ped or record.model ~= model
        or (record.entity and not DoesEntityExist(record.entity))) then deleteReplica(id); record=nil end
    if record then
        record.calibration = calibration
        record.outerwear, record.desiredFit = outerwear, fit
        if record.entity and DoesEntityExist(record.entity) then
            local needsAttach = record.signature ~= sig
                or GetEntityAttachedTo(record.entity) ~= ped
                or not IsEntityVisible(record.entity)
                or GetEntityAlpha(record.entity) < 255
            if needsAttach then attach(record, fit); record.signature=sig end
        end
        return
    end
    record = {ped=ped, model=model, hash=GetHashKey(model), calibration=calibration, outerwear=outerwear, desiredFit=fit, signature=sig, loading=true}
    replicas[id] = record
    CreateThread(function()
        RequestModel(record.hash)
        local deadline = GetGameTimer()+5000
        while not HasModelLoaded(record.hash) and GetGameTimer()<deadline and replicas[id]==record do Wait(25) end
        if replicas[id] ~= record then return end
        if not HasModelLoaded(record.hash) or not DoesEntityExist(ped) or IsEntityDead(ped) then
            deleteReplica(id); SetModelAsNoLongerNeeded(record.hash); return
        end
        local coords = GetEntityCoords(ped)
        local entity = CreateObject(record.hash,coords.x,coords.y,coords.z,false,false,false)
        if entity == 0 or not DoesEntityExist(entity) then deleteReplica(id); SetModelAsNoLongerNeeded(record.hash); return end
        record.entity = entity
        record.loading = false
        SetEntityAsMissionEntity(entity,true,true)
        SetEntityCollision(entity,false,false)
        SetEntityCompletelyDisableCollision(entity,true,true)
        attach(record, record.desiredFit)
        SetModelAsNoLongerNeeded(record.hash)

        -- Re-attach across consecutive frames to guarantee the first render drawable is in place
        CreateThread(function()
            local started = GetGameTimer()
            while replicas[id] == record and DoesEntityExist(entity)
                and GetGameTimer() - started < 1500 do
                local fit = record.desiredFit
                if editing and editing.record == record then fit = editing.value end
                attach(record, fit)
                Wait(100)
            end
        end)
    end)
end
function AttachLocalBackpack(model)
    local validated = validModel(model)
    if not validated then
        DetachLocalBackpack()
        return
    end
    localDesiredBackpack = validated
    local ped = PlayerPedId()
    ensureReplica(ownId(), ped, validated, ownState().attachedBackpackFit, ownState().attachedBackpackOuterwear == true)
end
function DetachLocalBackpack()
    localDesiredBackpack = nil
    deleteReplica(ownId())
end
function CheckPlayerEquippedBackpack(items)
    local foundModel = nil
    local satchelSlotId = (Config and Config.Equipment and Config.Equipment.slotIds and Config.Equipment.slotIds.Satchels) or 29
    if type(items) == 'table' then
        for _, item in pairs(items) do
            if item.container == "equipment" and (item.clothingSlot == "Satchels" or tonumber(item.x) == satchelSlotId) then
                foundModel = resolve(item)
                if foundModel then break end
            end
        end
    end
    if not foundModel then
        local stateModel = LocalPlayer.state.attachedBackpack
        if stateModel and stateModel ~= false and stateModel ~= '' then
            foundModel = validModel(stateModel)
        end
    end
    if foundModel then
        AttachLocalBackpack(foundModel)
    else
        DetachLocalBackpack()
    end
end
RegisterNetEvent('thehunt_inventory:onItemsReceived', CheckPlayerEquippedBackpack)
RegisterNetEvent('thehunt_inventory:attachBackpack', AttachLocalBackpack)
RegisterNetEvent('thehunt_inventory:detachBackpack', DetachLocalBackpack)
RegisterNetEvent('thehunt_inventory:setEquippedBackpack', function(model)
    if model then AttachLocalBackpack(model) else DetachLocalBackpack() end
end)

local function refreshPlayer(player)
    local id = GetPlayerServerId(player)
    local ped = GetPlayerPed(player)
    if id == ownId() then
        local state = ownState()
        local model = state.attachedBackpack
        if model == nil then model = localDesiredBackpack end
        local fitPacket = state.attachedBackpackFit
        local outerwear = state.attachedBackpackOuterwear == true
        ensureReplica(id, ped, model, fitPacket, outerwear)
    else
        local state = serverBackpacks[id] or Player(id).state
        ensureReplica(id, ped, state.attachedBackpack, state.attachedBackpackFit, state.attachedBackpackOuterwear == true)
    end
end
for _,key in ipairs({'attachedBackpack','attachedBackpackFit','attachedBackpackOuterwear'}) do
    AddStateBagChangeHandler(key,nil,function(bagName)
        local id = type(bagName)=='string' and tonumber(bagName:match('^player:(%d+)$'))
        if not id then return end
        -- State handlers can run before the new value is readable from the bag.
        SetTimeout(0,function()
            local player=GetPlayerFromServerId(id)
            if player ~= -1 then refreshPlayer(player) else deleteReplica(id) end
        end)
    end)
end
CreateThread(function()
    while true do
        local active = {}
        for _,player in ipairs(GetActivePlayers()) do
            active[GetPlayerServerId(player)] = true
            refreshPlayer(player)
        end
        for id in pairs(replicas) do
            if not active[id] and id ~= ownId() then
                deleteReplica(id)
            end
        end
        Wait(500)
    end
end)

local function canEdit(ped)
    return DoesEntityExist(ped) and not IsEntityDead(ped) and not IsPedRagdoll(ped)
        and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped,false)
        and not IsPedSwimming(ped) and not IsPedClimbing(ped)
end
AddEventHandler('thehunt_inventory:beginBackpackFit', function(dbId, admin)
    if editing or pendingEdit or awaitingSave then return end
    if not canEdit(PlayerPedId()) then notify('Настройка доступна стоя на земле.'); return end
    pendingEdit = {dbId=tonumber(dbId), expires=GetGameTimer()+8000}
    TriggerServerEvent('thehunt_items:beginBackpackFit', dbId, admin == true)
    SetTimeout(8000,function()
        if pendingEdit and GetGameTimer() >= pendingEdit.expires then pendingEdit=nil; notify('Не удалось открыть настройку. Попробуйте ещё раз.','error') end
    end)
end)
local function destroyCamera(s)
    if s.cam then RenderScriptCams(false,false,0,true,false); DestroyCam(s.cam,false); s.cam=nil end
end
local function updateCamera(s)
    local base = GetEntityCoords(s.ped)
    local a = math.rad(GetEntityHeading(s.ped)) + s.orbit
    SetCamCoord(s.cam, base.x + math.sin(a) * 1.85, base.y - math.cos(a) * 1.85, base.z + s.height)
    local c = centre(s.ped, s.record.outerwear, s.value, s.record.model, s.admin and s.value or nil)
    local target = getBackpackBoneCoords(s.ped, c.x, c.y, c.z)
    PointCamAtCoord(s.cam, target.x, target.y, target.z)
end
RegisterNetEvent('thehunt_inventory:backpackFitStarted',function(token,packet)
    if not pendingEdit or type(packet) ~= 'table' or packet.itemId ~= pendingEdit.dbId
        or editing or not canEdit(PlayerPedId()) then TriggerServerEvent('thehunt_items:cancelBackpackFit',token); return end
    pendingEdit=nil
    local ped=PlayerPedId()
    AttachLocalBackpack(packet.model)
    local deadline=GetGameTimer()+5500
    while replicas[ownId()] and not replicas[ownId()].entity and GetGameTimer()<deadline do Wait(25) end
    local record=replicas[ownId()]
    if not record or not record.entity or not canEdit(ped) or PlayerPedId() ~= ped then
        TriggerServerEvent('thehunt_items:cancelBackpackFit',token); notify('Модель рюкзака недоступна.','error'); return
    end
    local value=packet.calibration or packetFit(packet,packet.model)
    local s={admin=packet.calibration ~= nil,token=token,itemId=packet.itemId,model=packet.model,ped=ped,record=record,value=value,
        nextPreview=0,lastPreview='',orbit=0.0,height=0.85,start=GetEntityCoords(ped)}
    editing=s
    s.cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true)
    SetCamFov(s.cam,45.0)
    updateCamera(s)
    RenderScriptCams(true,false,0,true,false)
    attach(record,value)
    local ok, started=pcall(function() return exports.thehunt_gizmo:Start({
        title=s.admin and ('Стандарт рюкзака: '..s.model) or 'Расположение рюкзака',
        value=value, defaults=BackpackFit.Normalize({}), limits=s.admin and {} or BackpackFit.Limits,
        point=function(v)
            local c=centre(ped,record.outerwear,v,record.model,s.admin and v or nil)
            return getBackpackBoneCoords(ped,c.x,c.y,c.z)
        end,
        apply=function(v) s.value=v; record.desiredFit=v; attach(record,v) end,
        valid=function()
            local state=ownState()
            local fit=state.attachedBackpackFit
            return editing==s and replicas[ownId()]==record and DoesEntityExist(record.entity)
                and PlayerPedId()==ped and canEdit(ped) and #(GetEntityCoords(ped)-s.start)<0.5
                and state.attachedBackpack==s.model and type(fit)=='table' and fit.itemId==s.itemId
        end,
        camera=function(dx,dy)
            s.orbit=s.orbit+dx*0.008
            s.height=math.max(0.2,math.min(1.7,s.height-dy*0.006))
            updateCamera(s)
        end,
        tick=function(v)
            local now=GetGameTimer()
            local sig=signature(v,record.outerwear)
            if now>=s.nextPreview and (sig~=s.lastPreview or now>=(s.heartbeat or 0)) then
                s.nextPreview=now+300; s.heartbeat=now+5000; s.lastPreview=sig
                TriggerServerEvent('thehunt_items:previewBackpackFit',token,v)
            end
        end,
        finish=function(save,v)
            editing=nil; destroyCamera(s)
            record.signature=nil -- force reconciliation with authoritative state
            if save then
                awaitingSave=token
                TriggerServerEvent('thehunt_items:saveBackpackFit',token,v)
                SetTimeout(10000,function()
                    if awaitingSave==token then awaitingSave=nil; notify('Сервер не подтвердил сохранение. Проверьте расположение.','error') end
                end)
            else TriggerServerEvent('thehunt_items:cancelBackpackFit',token) end
        end,
    }) end)
    if not ok or not started then
        editing=nil; destroyCamera(s); TriggerServerEvent('thehunt_items:cancelBackpackFit',token)
        notify('Не удалось открыть редактор расположения.','error')
    end
end)
RegisterNetEvent('thehunt_inventory:backpackFitEnded',function(token)
    if editing and editing.token==token then exports.thehunt_gizmo:Cancel() end
end)
RegisterNetEvent('thehunt_inventory:backpackFitSaved',function(token,ok)
    if awaitingSave~=token then return end
    awaitingSave=nil
    notify(ok and 'Расположение сохранено.' or 'Не удалось сохранить расположение.',ok and 'success' or 'error')
    TriggerServerEvent('thehunt_items:requestInventory')
end)
AddEventHandler('thehunt:character:selected',function()
    pendingEdit, awaitingSave = nil, nil
    if editing and GetResourceState('thehunt_gizmo')=='started' then exports.thehunt_gizmo:Cancel() end
    DetachLocalBackpack()
end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    if editing then
        local s=editing
        if GetResourceState('thehunt_gizmo')=='started' then exports.thehunt_gizmo:Cancel() end
        destroyCamera(s)
        TriggerServerEvent('thehunt_items:cancelBackpackFit',s.token)
    end
    for id in pairs(replicas) do deleteReplica(id) end
end)
-- Clean orphaned local props left by older networked revisions once on start.
CreateThread(function()
    Wait(0)
    local ped=PlayerPedId()
    for _,entity in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(entity) and validModel(GetEntityModel(entity)) and GetEntityAttachedTo(entity)==ped
            and (not replicas[ownId()] or replicas[ownId()].entity~=entity) then
            SetEntityAsMissionEntity(entity,true,true); DeleteEntity(entity)
        end
    end
end)
-- Legacy calibration names now enter the same bounded, synchronized editor.
RegisterCommand('bpdefault', function()
    local packet = ownState().attachedBackpackFit
    if IsNuiFocused() then notify('Закройте инвентарь перед настройкой стандарта.'); return end
    if type(packet) ~= 'table' or not packet.itemId then notify('Сначала наденьте рюкзак.'); return end
    TriggerEvent('thehunt_inventory:beginBackpackFit', packet.itemId, true)
end, false)
local function openFitCommand()
    local fit=LocalPlayer.state.attachedBackpackFit
    if type(fit)=='table' and fit.itemId then TriggerEvent('thehunt_inventory:beginBackpackFit',fit.itemId)
    else notify('Сначала наденьте рюкзак.') end
end
RegisterCommand('bpoffset', function(_, args)
    if #args == 0 then
        openFitCommand()
        return
    end
    local rec = replicas[ownId()]
    if not rec or not rec.entity or not DoesEntityExist(rec.entity) then
        notify('Сначала наденьте рюкзак.', 'error')
        return
    end
    local ped = PlayerPedId()
    local female = IsPedMale(ped) == false or IsPedMale(ped) == 0
    local mfit = (rec.model and MODEL_BASE_FIT[rec.model]) or MODEL_BASE_FIT.__default
    local x = tonumber(args[1]) or mfit.x or 0.0
    local y = tonumber(args[2]) or (female and mfit.y_female or mfit.y_male)
    local z = tonumber(args[3]) or (female and mfit.z_female or mfit.z_male)
    local rx = tonumber(args[4]) or mfit.rx or -90.0
    local ry = tonumber(args[5]) or mfit.ry or 0.0
    local rz = tonumber(args[6]) or mfit.rz or 0.0
    AttachEntityToEntity(
        rec.entity,
        ped,
        GetBackpackBoneIndex(ped),
        x, y, z,
        rx, ry, rz,
        false, false, false, false, 2, true
    )
    notify(string.format("Офсет: x=%.2f y=%.2f z=%.2f rx=%.1f rz=%.1f", x, y, z, rx, rz), "success")
    print(string.format("[HUNT BACKPACK] live offset: x=%.3f, y=%.3f, z=%.3f, rx=%.1f, ry=%.1f, rz=%.1f", x, y, z, rx, ry, rz))
end, false)
RegisterCommand('bprot', openFitCommand, false)
RegisterCommand('bpreset', function()
    local rec = replicas[ownId()]
    if rec and rec.entity and DoesEntityExist(rec.entity) then
        attach(rec, {x=0, y=0, z=0, rx=0, ry=0, rz=0})
        notify("Смещение сброшено по умолчанию", "info")
    end
end, false)
RegisterCommand('bpinfo', function()
    local ped = PlayerPedId()
    local boneIdx = GetBackpackBoneIndex(ped)
    local rec = replicas[ownId()]
    local attached = rec and rec.entity and DoesEntityExist(rec.entity)
    print(string.format("[HUNT BACKPACK] ped=%s bone=%s entity=%s fit=%s",
        tostring(ped), tostring(boneIdx), tostring(rec and rec.entity), json.encode(LocalPlayer.state.attachedBackpackFit or {})))
    notify(string.format("Рюкзак: bone=%s model=%s", tostring(boneIdx), tostring(rec and rec.model)), "info")
end, false)
exports('AttachLocalBackpack',AttachLocalBackpack)
exports('DetachLocalBackpack',DetachLocalBackpack)
exports('GetAttachedBackpackModel',function() return LocalPlayer.state.attachedBackpack end)

