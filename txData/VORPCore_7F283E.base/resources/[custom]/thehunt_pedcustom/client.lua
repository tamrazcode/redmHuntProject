local opened, typing, busy, editing = false, false, false, false
local pending, sequence, original, draft, beforeEditor = {}, 0, nil, nil, nil
local mine, applied = {}, {}
local sessionOwner, sessionCharacter
local activeData, captureCurrent
local equipmentConfirm
local isBirdFlying, wasBirdMode = false, false
local BIRD_KEYWORDS = {
    'eagle', 'hawk', 'owl', 'raven', 'vulture', 'duck', 'seagull', 'crow',
    'pigeon', 'pelican', 'cormorant', 'crane', 'egret', 'heron', 'loon',
    'pheasant', 'quail', 'robin', 'rooster', 'roseatespoonbill', 'songbird',
    'sparrow', 'turkey', 'woodpecker', 'cardinal', 'bluejay', 'cedarwaxwing',
    'condor', 'oriole', 'parrot', 'bat', 'carolinaparakeet', 'goosecanada', 'prairiechicken', 'redfootedbooby'
}

local PREDATOR_KEYWORDS = {
    'bear', 'wolf', 'cougar', 'panther', 'alligator', 'coyote', 'dog',
    'fox', 'boar', 'lion', 'bull', 'buffalo', 'buck', 'ram'
}

local hashToModel = {}
local function initModelMap()
    local content = LoadResourceFile(GetCurrentResourceName(), 'data/models.json')
    if content then
        local ok, list = pcall(json.decode, content)
        if ok and type(list) == 'table' then
            for _, item in ipairs(list) do
                if item.model then
                    local name = item.model
                    local h = joaat(name)
                    hashToModel[h] = name
                    local u = h & 0xFFFFFFFF
                    hashToModel[u] = name
                    if u >= 0x80000000 then
                        hashToModel[u - 0x100000000] = name
                    end
                end
            end
        end
    end
    hashToModel[joaat('mp_male')] = 'mp_male'
    hashToModel[joaat('mp_female')] = 'mp_female'
    hashToModel[joaat('mp_male') & 0xFFFFFFFF] = 'mp_male'
    hashToModel[joaat('mp_female') & 0xFFFFFFFF] = 'mp_female'
end
initModelMap()

local function getModelClassification(model)
    local m = string.lower(tostring(model or '')):gsub('^mp_a_c_', 'a_c_')
    if m == 'mp_male' or m == 'mp_female' or not string.find(m, '^a_c_') then
        return 'human'
    end
    if string.find(m, 'horse') or string.find(m, 'mule') or string.find(m, 'donkey') then
        return 'horse'
    end
    if string.find(m, 'fish') or string.find(m, 'shark') or string.find(m, 'crab') or string.find(m, 'crawfish') or string.find(m, 'turtle') then
        return 'aquatic'
    end
    for _, k in ipairs(BIRD_KEYWORDS) do
        if string.find(m, k) then return 'bird' end
    end
    for _, k in ipairs(PREDATOR_KEYWORDS) do
        if string.find(m, k) then return 'predator' end
    end
    return 'animal'
end

local function copy(value) return json.decode(json.encode(value)) end
local function notify(message, kind) TriggerEvent('thehunt_status:notify', 'Педы', message, kind or 'info') end

local function request(action, args)
    args=args or {}
    if action=='apply' or action=='restore' then
        sequence=sequence+1
        local planId,planPromise=sequence,promise.new();pending[planId]=planPromise
        TriggerServerEvent('thehunt_pedcustom:request',planId,'equipmentPlan',{data=args.data,restoring=action=='restore'})
        SetTimeout(15000,function()if pending[planId] then pending[planId]=nil;planPromise:resolve({ok=false,data='Сервер не ответил'})end end)
        local plan=Citizen.Await(planPromise);assert(plan.ok,plan.data)
        if plan.data.message then
            equipmentConfirm=promise.new()
            SetNuiFocus(true,true);SetNuiFocusKeepInput(false)
            SendNUIMessage({action='equipmentConfirm',message=plan.data.message})
            local waiting=equipmentConfirm
            SetTimeout(120000,function()if equipmentConfirm==waiting then waiting:resolve(false) end end)
            local accepted=Citizen.Await(waiting);equipmentConfirm=nil
            SetNuiFocus(opened,opened);SetNuiFocusKeepInput(opened)
            if not accepted then
                TriggerServerEvent('thehunt_pedcustom:request',-1,'equipmentCancel',{})
                error('Смена отменена: содержимое сохранено')
            end
        end
        args.equipmentToken=plan.data.token
    end
    sequence = sequence + 1
    local id, p = sequence, promise.new()
    pending[id] = p
    TriggerServerEvent('thehunt_pedcustom:request', id, action, args or {})
    SetTimeout(15000, function() if pending[id] then pending[id] = nil; p:resolve({ok=false, data='Сервер не ответил'}) end end)
    local result = Citizen.Await(p)
    if not result.ok then error(result.data) end
    return result.data
end

RegisterNetEvent('thehunt_pedcustom:response', function(id, ok, data)
    if pending[id] then pending[id]:resolve({ok=ok, data=data}); pending[id] = nil end
end)

local function modelLoad(model)
    local hash = type(model) == 'number' and model or joaat(model)
    assert(IsModelValid(hash) and IsModelAPed(hash), 'Модель недоступна в этом игровом билде')
    RequestModel(hash)
    local deadline = GetGameTimer() + 6000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(20) end
    assert(HasModelLoaded(hash), 'Не удалось загрузить модель')
    return hash
end

local function appearance(ped, data, self)
    if not DoesEntityExist(ped) then return end
    local isSelf = (ped == PlayerPedId()) or (self == true)

    -- Wasvendel core: initialize ped components and variations
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)

    if data.spirit then
        PedCustomSpirit.Apply(ped,data.model)
    elseif data.appearance then
        assert(exports.thehunt_character:ApplyPedCustomAppearance(ped, data.appearance), 'Не удалось применить внешность')
    else
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, math.floor(data.outfit or 0), 0)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end
    for _, tag in ipairs(not data.spirit and data.tags or {}) do
        SetMetaPedTag(ped, tag.drawable, tag.albedo, tag.normal, tag.material, tag.palette,
            math.floor(tag.tint0), math.floor(tag.tint1), math.floor(tag.tint2))
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    PedCustomSpirit.Track(ped, data.spirit and data.model or nil)
    SetPedScale(ped, (data.scale or 1) + 0.0)

    local cls = getModelClassification(data.model)
    if cls == 'bird' then
        SetPedConfigFlag(ped, 43, true)
    end

    if isSelf or NetworkHasControlOfEntity(ped) then
        SetEntityInvincible(ped, data.invincible == true)
        SetPedCanRagdoll(ped, data.ragdoll ~= false)
        SetEntityCollision(ped, data.collision ~= false, true)
        local hp = math.max(1, math.floor(data.health or 200))
        SetEntityMaxHealth(ped, hp)
        SetEntityHealth(ped, hp, 0)
        if isSelf then
            FreezeEntityPosition(ped, false)
            SetBlockingOfNonTemporaryEvents(ped, false)
        else
            FreezeEntityPosition(ped, data.frozen == true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            ClearPedTasks(ped)
            if data.behavior == 'wander' and not data.frozen then TaskWanderStandard(ped, 10.0, 10) end
        end
    end
end

local function checkCanTransform(ped)
    if not DoesEntityExist(ped) then return false, 'Персонаж не найден' end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false, 'Персонаж мёртв или без сознания' end
    if IsPedRagdoll(ped) then return false, 'Персонаж сбит с ног' end

    local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, ped)
    local cuffed = Citizen.InvokeNative(0x74E559B3BC910685, ped)
    if hogtied or cuffed then return false, 'Персонаж связан или в наручниках' end

    if IsPedOnMount(ped) then
        TaskDismountAnimal(ped, 1, 0, 0, 0, 0)
        Wait(400)
        if IsPedOnMount(ped) then return false, 'Сначала спешьтесь с лошади' end
    end

    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveAnyVehicle(ped, 0, 0)
        Wait(400)
        if IsPedInAnyVehicle(ped, false) then return false, 'Сначала выйдите из транспорта' end
    end

    return true
end

local function switch(data, rollback)
    if not rollback then
        local okCan, errCan = checkCanTransform(PlayerPedId())
        assert(okCan, errCan)
    end

    local hash = modelLoad(data.model)
    local ped = PlayerPedId()
    local pos, heading, health = GetEntityCoords(ped), GetEntityHeading(ped), GetEntityHealth(ped)
    local curModel = GetEntityModel(ped)
    local isHuman = (curModel == joaat('mp_male') or curModel == joaat('mp_female'))
    if not original and isHuman then
        original = { model=curModel, appearance=exports.thehunt_character:GetAppearanceState(), health=health,
            owner=sessionOwner, characterId=sessionCharacter }
        SetResourceKvp('pedcustom_recovery', json.encode(original))
    end
    LocalPlayer.state:set('huntPedCustomActive', true, false)
    SetPlayerModel(PlayerId(), hash, false)
    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, heading)
    local deadline = GetGameTimer() + 5000
    while not IsPedReadyToRender(ped) and GetGameTimer() < deadline do Wait(20) end
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetEntityCollision(ped, true, true)
    ClearPedTasksImmediately(ped)
    data.frozen = false
    appearance(ped, data, true)
    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255, false)
    SetModelAsNoLongerNeeded(hash)
    activeData = copy(data)
    draft = copy(data)
    SetResourceKvp('pedcustom_draft', json.encode(draft))

    local cls = getModelClassification(data.model)
    isBirdFlying, wasBirdMode = false, false
    Citizen.InvokeNative(0x2804658EB7D8A50B, 2, 0)

    if cls ~= 'human' then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end
end

local function commitAppearance(token)
    if token then
        -- Let the server observe the replacement network ped before committing equipment.
        Wait(300)
        request('commitAppearance',{token=token})
    end
    TriggerServerEvent('thehunt_pedcustom:publish')
end

local function restore(serverResult)

    -- 1. Resolve appearance data: prefer server authoritative DB data, with fallback to saved original
    local appearanceData = nil
    local gender = 'Male'
    local modelHash = nil

    if serverResult and serverResult.character and serverResult.character.skin then
        appearanceData = serverResult.character
        gender = appearanceData.gender or 'Male'
    elseif original and original.appearance then
        appearanceData = original.appearance
        gender = appearanceData.gender or 'Male'
    end

    if not appearanceData then
        local okState, liveState = pcall(function() return exports.thehunt_character:GetAppearanceState() end)
        if okState and liveState and liveState.skin then
            appearanceData = liveState
            gender = appearanceData.gender or 'Male'
        end
    end

    -- 2. Determine ped model hash
    local gLower = string.lower(tostring(gender or ''))
    if gLower == 'female' or gLower == 'mp_female' then
        modelHash = joaat('mp_female')
    else
        modelHash = joaat('mp_male')
    end
    -- 3. Clear state bag lockout immediately so thehunt_character is unblocked
    LocalPlayer.state:set('huntPedCustomActive', false, false)

    -- 4. Load the target human model
    local hash = modelLoad(modelHash)
    local ped = PlayerPedId()
    local pos, heading, health = GetEntityCoords(ped), GetEntityHeading(ped), GetEntityHealth(ped)

    -- 5. Set the model and wait properly until ped is ready to render
    SetPlayerModel(PlayerId(), hash, false)
    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, heading)

    local deadline = GetGameTimer() + 5000
    while not IsPedReadyToRender(ped) and GetGameTimer() < deadline do Wait(20) end
    ped = PlayerPedId()

    -- 6. Apply appearance via thehunt_character:ApplyDatabaseAppearance
    if appearanceData then
        local skin = appearanceData.skin or {}
        local comps = appearanceData.comps or {}
        local compTints = appearanceData.compTints or {}
        local charGender = (modelHash == joaat('mp_female')) and 'Female' or 'Male'
        if appearanceData.gender then charGender = appearanceData.gender end

        pcall(function()
            exports.thehunt_character:ApplyDatabaseAppearance(skin, comps, compTints, charGender)
        end)

        -- Secondary delayed passes to defeat any VORP delayed MetaPed preset setup
        SetTimeout(250, function()
            if not LocalPlayer.state.huntPedCustomActive then
                pcall(function()
                    exports.thehunt_character:ApplyDatabaseAppearance(skin, comps, compTints, charGender)
                end)
            end
        end)
        SetTimeout(700, function()
            if not LocalPlayer.state.huntPedCustomActive then
                pcall(function()
                    exports.thehunt_character:ApplyDatabaseAppearance(skin, comps, compTints, charGender)
                end)
            end
        end)
    end

    -- 7. Reset entity states
    isBirdFlying = false
    wasBirdMode = false
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
    SetPedCanRagdoll(ped, true)
    SetEntityProofs(ped, 0, false)
    FreezeEntityPosition(ped, false)
    SetEntityHealth(ped, math.max(100, health or 200), 0)
    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255, false)
    SetModelAsNoLongerNeeded(hash)

    -- 8. Restore walk style and speed
    if serverResult and serverResult.character and serverResult.character.walk then
        pcall(function()
            SetPedMovementClipset(ped, serverResult.character.walk, 0.25)
        end)
    end
    pcall(function()
        if exports.thehunt_walking and exports.thehunt_walking.ApplyCurrentSpeed then
            exports.thehunt_walking:ApplyCurrentSpeed()
        end
    end)

    Citizen.InvokeNative(0x2804658EB7D8A50B, 2, 0) -- Release bird control context

    commitAppearance(serverResult and serverResult._transition)
    original, draft, activeData = nil, nil, nil
    DeleteResourceKvp('pedcustom_recovery')
    DeleteResourceKvp('pedcustom_draft')
    notify('Облик персонажа успешно восстановлен', 'success')
end

local function focus(value)
    opened, typing = value, false
    SetNuiFocus(value, value)
    SetNuiFocusKeepInput(value)
    SendNUIMessage({action=value and 'open' or 'close'})
end

local function changeAppearance(args, returning)
    local previous={data=captureCurrent(),active=LocalPlayer.state.huntPedCustomActive==true,
        original=original and copy(original),draft=draft and copy(draft),maxHealth=GetEntityMaxHealth(PlayerPedId())}
    local changed=false
    local ok,result=pcall(function()
        if returning then local response=request('restore');changed=true;restore(response);return true end
        modelLoad(args.data.model)
        local allowed,why=checkCanTransform(PlayerPedId());assert(allowed,why)
        local accepted=request('apply',args)
        changed=true
        switch(accepted)
        commitAppearance(accepted._transition)
        activeData._transition=nil;draft._transition=nil
        return accepted
    end)
    if not ok then
        pcall(request,'abortAppearance')
        -- No equipment is committed when native appearance application fails.
        local recovered=true
        if changed then recovered=pcall(switch,previous.data,true);SetEntityMaxHealth(PlayerPedId(),previous.maxHealth) end
        original=previous.original;draft=previous.draft
        activeData=previous.active and previous.data or nil
        LocalPlayer.state:set('huntPedCustomActive',previous.active,false)
        if original then SetResourceKvp('pedcustom_recovery',json.encode(original)) else DeleteResourceKvp('pedcustom_recovery') end
        if draft then SetResourceKvp('pedcustom_draft',json.encode(draft)) else DeleteResourceKvp('pedcustom_draft') end
        if not recovered then notify('Не удалось вернуть внешний вид. Используйте /pedrestore.', 'error') end
        error(result)
    end
    return result
end

RegisterCommand('pedcustom', function()
    if busy or editing then return end
    CreateThread(function()
        local ok, result = pcall(request, 'list')
        if not ok then notify(tostring(result), 'error'); return end
        sessionOwner, sessionCharacter = result.owner, result.characterId
        if original and (original.owner ~= sessionOwner or original.characterId ~= sessionCharacter) then
            original, draft, activeData = nil, nil, nil
            DeleteResourceKvp('pedcustom_recovery')
            DeleteResourceKvp('pedcustom_draft')
        end
        mine = result.spawned or {}
        focus(true)
        SendNUIMessage({action='library', data=result, draft=draft, spawned=mine})
    end)
end, false)

RegisterCommand('pedrestore', function()
    if busy or editing then return end
    local currentModel = GetEntityModel(PlayerPedId())
    local isHuman = (currentModel == joaat('mp_male') or currentModel == joaat('mp_female'))
    CreateThread(function()
        busy = true
        local ok, err = pcall(function() changeAppearance({},true) end)
        busy = false
        if not ok then notify(tostring(err), 'error') end
    end)
end, false)

RegisterNUICallback('equipmentConfirm',function(data,cb)if equipmentConfirm then equipmentConfirm:resolve(data.accepted==true) end;cb({ok=true})end)
RegisterNUICallback('setInputFocusState', function(data, cb) typing=data.hasFocus==true; cb({ok=true}) end)
RegisterNUICallback('action', function(input, cb)
    if busy then cb({ok=false,error='Дождитесь завершения действия'}); return end
    busy = true
    CreateThread(function()
        local ok, result = pcall(function()
            local action, args = input.action, input.args or {}
            if action == 'close' then focus(false); return true end
            if action == 'restore' then
                changeAppearance({},true)
                focus(false)
                return true
            end
            if action == 'apply' then
                local data = changeAppearance(args,false)
                focus(false)
                return data
            end
            if action == 'applyKeepOpen' then
                local data = changeAppearance(args,false)
                return data
            end
            if action == 'diagnostics' then
                request('list')
                local ped = PlayerPedId()
                return {model=hashToModel[GetEntityModel(ped)] or tostring(GetEntityModel(ped)),
                    active=LocalPlayer.state.huntPedCustomActive == true, editable=IsPedHuman(ped) and activeData and activeData.appearance ~= nil,
                    health=GetEntityHealth(ped), network=NetworkGetNetworkIdFromEntity(ped),
                    flight=isBirdFlying, height=GetEntityHeightAboveGround(ped),
                    combatMelee=Citizen.InvokeNative(0x1C1993824A396603,ped,12),
                    combatCharge=Citizen.InvokeNative(0x1C1993824A396603,ped,9),
                    character=GetResourceState('thehunt_character'), nativeOutfit=activeData and activeData.outfit}
            end
            if action == 'capture' then
                request('list')
                draft = captureCurrent()
                draft.equipment=request('captureEquipment')
                SetResourceKvp('pedcustom_draft', json.encode(draft))
                return draft
            end
            if action == 'edit' then
                assert(args.data.model == 'mp_male' or args.data.model == 'mp_female', 'Полный редактор доступен mp_male и mp_female')
                if not args.data.appearance and activeData and activeData.model == args.data.model then
                    args.data.appearance = copy(activeData.appearance)
                end
                local data = request('edit', args)
                beforeEditor = LocalPlayer.state.huntPedCustomActive and captureCurrent() or nil
                local editorOk,editorError=pcall(function()
                    switch(data)
                    focus(false)
                    editing=true
                    local app=data.appearance or {gender=data.model=='mp_female' and 'Female' or 'Male',skin={},comps={},compTints={}}
                    assert(exports.thehunt_character:OpenPedCustomEditor(app),'???????? ??? ?????')
                end)
                if not editorOk then
                    editing=false
                    local previous=request('cancelEdit')
                    if beforeEditor then switch(beforeEditor,true) else restore(previous) end
                    focus(true);error(editorError)
                end
                return true
            end
            if action == 'tags' then
                request('list')
                assert(draft and draft.model == args.model, 'Сначала примените выбранный облик к себе')
                local ped, tags = PlayerPedId(), {}
                for i=0, GetNumComponentsInPed(ped)-1 do
                    local _, drawable, albedo, normal, material = GetMetaPedAssetGuids(ped, i)
                    local _, palette, t0, t1, t2 = GetMetaPedAssetTint(ped, i)
                    if drawable and palette then tags[#tags+1] = {drawable=drawable,albedo=albedo,normal=normal,material=material,palette=palette,tint0=t0,tint1=t1,tint2=t2} end
                end
                return tags
            end
            if action == 'spawn' then
                local ticket = request('spawn', args)
                local hash = modelLoad(ticket.data.model)
                local pos = ticket.position
                local ped = CreatePed(hash, pos.x, pos.y, pos.z, pos.heading, true, true, false, false)
                SetModelAsNoLongerNeeded(hash)
                assert(ped and ped ~= 0 and DoesEntityExist(ped), 'Не удалось создать NPC')
                SetEntityAsMissionEntity(ped, true, true)
                Entity(ped).state:set('isProtected', true, true)
                local net = NetworkGetNetworkIdFromEntity(ped)
                Wait(250)
                local registered, res = pcall(request, 'registerSpawn', {net=net})
                if not registered then DeleteEntity(ped); error(res) end
                appearance(ped, ticket.data, false)
                mine[#mine+1] = {net=net, model=ticket.data.model}
                return {net=net, spawned=mine}
            end
            if action == 'updateSpawn' then
                local res = request('updateSpawn', args)
                if res and args.net then
                    local ent = NetworkGetEntityFromNetworkId(tonumber(args.net))
                    if DoesEntityExist(ent) then
                        appearance(ent, args.data, false)
                    end
                end
                return res
            end
            if action == 'teleportSpawn' then
                local coords = request('teleportSpawn', args)
                local ped = PlayerPedId()
                if DoesEntityExist(ped) and coords then
                    SetEntityCoords(ped, coords.x + 1.0, coords.y, coords.z, false, false, false, false)
                    notify('Телепортирован к созданному NPC', 'info')
                end
                return true
            end
            if action == 'removeAllSpawn' then
                request('removeAllSpawn')
                mine = {}
                notify('Все ваши созданные NPC удалены', 'info')
                return { spawned = {} }
            end
            local res = request(action, args)
            if action == 'removeSpawn' then
                for i=#mine,1,-1 do if mine[i].net==args.net then table.remove(mine,i) end end
            end
            return res
        end)
        busy = false
        if not ok then
            -- Failed model loads leave the inventory untouched; recovery is explicit via /pedrestore.
            notify(tostring(result),'error')
        end
        cb({ok=ok, data=ok and result or nil, error=not ok and tostring(result) or nil})
    end)
end)

RegisterNetEvent('thehunt_character:client:prepareSelection', function()
    if editing then exports.thehunt_character:ClosePedCustomEditor() end
    editing=false
    focus(false)
    original,draft,activeData=nil,nil,nil
    DeleteResourceKvp('pedcustom_recovery')
    DeleteResourceKvp('pedcustom_draft')
    LocalPlayer.state:set('huntPedCustomActive',false,false)
    TriggerServerEvent('thehunt_pedcustom:clearSession')
end)

AddEventHandler('thehunt_pedcustom:editorResult', function(result)
    if not editing then return end
    editing = false
    busy=true
    CreateThread(function()
        local ok, err = pcall(function()
            if result then
                draft.appearance = result
                draft.tags = nil -- previous MetaPed tags must not overwrite the editor's new clothing
                draft.model = result.gender == 'Female' and 'mp_female' or 'mp_male'
                draft.scale = result.skin.Scale or 1
                draft.equipment = activeData and activeData.equipment or {}
                local accepted=request('apply', {data=draft})
                commitAppearance(accepted._transition)
                activeData = copy(draft)
                SetResourceKvp('pedcustom_draft', json.encode(draft))
                TriggerServerEvent('thehunt_pedcustom:publish')
            else
                local previous=request('cancelEdit')
                if beforeEditor then switch(beforeEditor);TriggerServerEvent('thehunt_pedcustom:publish') else restore(previous) end
            end
            focus(true)
            SendNUIMessage({action='draft', data=draft})
        end)
        busy=false
        if not ok then
            pcall(request,'abortAppearance')
            local cancelled,previous=pcall(request,'cancelEdit')
            if cancelled then
                if beforeEditor then pcall(switch,beforeEditor,true) else pcall(restore,previous) end
            end
            notify(tostring(err),'error'); focus(true)
        end
    end)
end)

-- State bags replay appearance for newly streamed entities
AddStateBagChangeHandler('huntPedCustom', nil, function(bag, _, value)
    if not value then local ent=GetEntityFromStateBagName(bag);if ent~=0 then PedCustomSpirit.Track(ent,nil) end;return end
    CreateThread(function()
        local entity, deadline = 0, GetGameTimer()+10000
        repeat
            entity = GetEntityFromStateBagName(bag)
            if entity == 0 then Wait(100) end
        until entity ~= 0 or GetGameTimer() > deadline
        if entity ~= 0 and DoesEntityExist(entity) then
            local isSelf = (entity == PlayerPedId())
            if (GetEntityModel(entity) & 0xffffffff) ~= (joaat(value.model) & 0xffffffff) then return end
            if not isSelf then appearance(entity, value, false) end
        end
    end)
end)

-- Read the selected player's actual snapshot. Temporary forms do not touch the real character cache.
captureCurrent = function()
    assert(not editing, 'Игрок сейчас редактирует внешность')
    local ped = PlayerPedId()
    local model = hashToModel[GetEntityModel(ped)]
    assert(model, 'Текущая модель отсутствует в каталоге')
    local current = LocalPlayer.state.huntPedCustomActive and activeData and activeData.model == model and copy(activeData) or {}
    current.model = model
    current.health = math.max(1, GetEntityHealth(ped))
    current.scale = current.scale or 1
    current.outfit = current.outfit or 0
    current.frozen, current.collision = false, current.collision ~= false
    current.ragdoll = current.ragdoll ~= false
    local inv = GetPlayerInvincible(PlayerId())
    current.invincible = inv == true or inv == 1
    if model == 'mp_male' or model == 'mp_female' then
        current.appearance = current.appearance or exports.thehunt_character:GetAppearanceState()
        current.scale = current.appearance.skin.Scale or current.scale
    end
    current.tags = {}
    for i=0,GetNumComponentsInPed(ped)-1 do
        local _,drawable,albedo,normal,material = GetMetaPedAssetGuids(ped,i)
        local _,palette,t0,t1,t2 = GetMetaPedAssetTint(ped,i)
        if drawable and palette then current.tags[#current.tags+1] = {
            drawable=drawable,albedo=albedo,normal=normal,material=material,palette=palette,tint0=t0,tint1=t1,tint2=t2} end
    end
    return current
end
RegisterNetEvent('thehunt_pedcustom:captureRequested', function(token)
    if source ~= 65535 then return end
    local ok, data = pcall(captureCurrent)
    TriggerServerEvent('thehunt_pedcustom:captureResponse', token, ok and data or nil, not ok and tostring(data) or nil)
end)

-- Native tasks own collision, animation and damage. No scripted damage or forced impulse.
local flightTarget, nextFlightTask, landingDeadline, combatUntil = nil, 0, 0, 0
local controlledPed = 0
local function attackTarget(ped)
    local pos, forward, nearest, best = GetEntityCoords(ped), GetEntityForwardVector(ped), nil, 4.0
    for _, target in ipairs(GetGamePool('CPed')) do
        if target ~= ped and DoesEntityExist(target) and not IsEntityDead(target) then
            local delta = GetEntityCoords(target)-pos
            local distance = #delta
            if distance > 0.01 and distance < best and math.abs(delta.z) < 2.0
                and (delta.x*forward.x+delta.y*forward.y)/distance > 0.35
                and HasEntityClearLosToEntity(ped,target,17) then nearest,best=target,distance end
        end
    end
    return nearest
end
local function animalHint(text)
    SendNUIMessage({action='animalHint',text=text})
end
CreateThread(function()
    local lastVocal, lastHint, lastAttack, lastJump = 0, 0, 0, 0
    local lastText = ''
    while true do
        local ped, now = PlayerPedId(), GetGameTimer()
        local enabled = LocalPlayer.state.huntPedCustomActive and not IsPedHuman(ped) and not IsEntityDead(ped)
        if ped ~= controlledPed then
            controlledPed=ped; isBirdFlying=false; flightTarget=nil; combatUntil=0
        end
        if enabled and not opened and not editing and not typing and not IsNuiFocused() then
            DisableControlAction(0,0xC13A5C50,true)
            local cls = getModelClassification(hashToModel[GetEntityModel(ped)])
            if Citizen.InvokeNative(0xC346A546612C49A9,ped) then cls='bird' end
            local jump = IsControlJustPressed(0,0xD9D0E1C0)
            local land = IsControlJustPressed(0,0xDB096B85)
            local attack = IsControlJustPressed(0,0x07CE1E61) or IsControlJustPressed(0,0xB2F377E8)
            if cls == 'bird' then
                if jump then
                    flightTarget=nil; isBirdFlying=true; nextFlightTask=0
                end
                if land and isBirdFlying then
                    local target = GetOffsetFromEntityInWorldCoords(ped,0.0,5.0,0.0)
                    local found,ground = GetGroundZFor_3dCoord(target.x,target.y,target.z+10.0,false)
                    if found then
                        flightTarget={x=target.x,y=target.y,z=ground}; landingDeadline=now+15000
                        -- p5/p6 retain Rockstar's flight task; final ground handoff below.
                        Citizen.InvokeNative(0xD6CFC2D59DA72042,ped,1.0,target.x,target.y,ground+0.25,true,false)
                    else notify('Земля впереди не загружена. Подлетите ближе к суше.', 'warning') end
                end
                if flightTarget then
                    if GetEntityHeightAboveGround(ped)<0.65 and math.abs(GetEntityVelocity(ped).z)<1.5 then
                        ClearPedTasks(ped); isBirdFlying=false; flightTarget=nil
                    elseif now>landingDeadline then
                        flightTarget=nil; nextFlightTask=0
                        notify('Место посадки недоступно. Выберите открытую площадку.', 'warning')
                    end
                elseif isBirdFlying and now>=nextFlightTask then
                    nextFlightTask=now+650
                    local pos,rotation = GetEntityCoords(ped),GetGameplayCamRot(2)
                    local yaw,pitch=math.rad(rotation.z),math.rad(math.max(-35,math.min(35,rotation.x)))
                    local distance=IsControlPressed(0,0x8FFC75D6) and 25.0 or 14.0
                    Citizen.InvokeNative(0xD6CFC2D59DA72042,ped,2.0,
                        pos.x-math.sin(yaw)*distance,pos.y+math.cos(yaw)*distance,
                        pos.z+math.sin(pitch)*distance+(GetEntityHeightAboveGround(ped)<2 and 3.0 or 0.0),true,false)
                end
            end
            if attack and now-lastAttack>1000 and not isBirdFlying then
                lastAttack=now
                local target=attackTarget(ped)
                if target then
                    -- R* combat decision maker selects bite, claw, kick or charge for this species.
                    Citizen.InvokeNative(0x944F30DCB7096BDE,ped,target,1600,0)
                    combatUntil=now+1800
                else notify('Для атаки повернитесь к ближайшей цели.', 'info') end
            end
            if jump and cls~='bird' and now-lastJump>800 and GetEntityHeightAboveGround(ped)<1.0 and not IsPedSwimming(ped) then
                lastJump=now
                Citizen.InvokeNative(0x0AE4086104E067B1,ped,false)
            end
            if combatUntil>0 and (now>combatUntil or IsControlJustPressed(0,0x8CC9CD42)) then
                ClearPedTasks(ped); combatUntil=0
            end
            if IsControlJustPressed(0,0x760A9C6F) and now-lastVocal>1500 then
                lastVocal=now
                Citizen.InvokeNative(0xEE066C7006C49C0A,ped,'CALLOUT',true)
            end
            local hint=cls=='bird' and (flightTarget and 'ПТИЦА · Посадка… | Пробел: отменить посадку' or
                'ПТИЦА · Пробел: взлёт | Мышь: направление | Shift: дальний полёт | Ctrl: посадка') or
                'ЖИВОТНОЕ · ЛКМ / F: нативная атака | G: голос | Backspace: прекратить бой'
            hint=hint..' | /pedcustom · /pedrestore'
            if now-lastHint>1000 or lastText~=hint then animalHint(hint); lastHint=now; lastText=hint end
            Wait(0)
        else
            if lastText~='' then animalHint(''); lastText='' end
            if not enabled and (isBirdFlying or combatUntil>0) then
                ClearPedTasks(ped); isBirdFlying=false; flightTarget=nil; combatUntil=0
            elseif (opened or editing) and combatUntil>0 then
                ClearPedTasks(ped);combatUntil=0
            end
            Wait(100)
        end
    end
end)

CreateThread(function()
    local whitelist = {0x4D8FB4C1,0xFDA83190,0x8FD015D8,0xD27782E3,0x7065027D,0xB4E465B4,
        0x8FFC75D6,0xD9D0E1C0,0xDB096B85,0xF1301666,0x05CA7C52}
    while true do
        if opened or editing then
            for pad=0,2 do
                DisableAllControlActions(pad)
                if opened and not typing then
                    for _, key in ipairs(whitelist) do EnableControlAction(pad, key, true) end
                end
                -- Полная блокировка вращения камеры при открытом меню
                DisableControlAction(pad, 0xA987235F, true) -- Look Left/Right
                DisableControlAction(pad, 0xD2047988, true) -- Look Up/Down
            end
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else
            Wait(150)
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    Citizen.InvokeNative(0x2804658EB7D8A50B, 2, 0)
    if editing then exports.thehunt_character:ClosePedCustomEditor() end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    LocalPlayer.state:set('huntPedCustomActive', false, false)
end)

CreateThread(function()
    local saved = GetResourceKvpString('pedcustom_recovery')
    if saved then original=json.decode(saved); notify('Есть сохранённый исходный облик: /pedcustom → Вернуть персонажа или /pedrestore') end
    local savedDraft = GetResourceKvpString('pedcustom_draft')
    if savedDraft then
        pcall(function() draft = json.decode(savedDraft) end)
    end
end)


RegisterNetEvent('thehunt_pedcustom:confirmationExpired',function()
    if equipmentConfirm then equipmentConfirm:resolve(false) end
    SendNUIMessage({action='confirmationExpired'})
end)
RegisterNetEvent('thehunt_pedcustom:inventoryAppearance',function(data)
    if not LocalPlayer.state.huntPedCustomActive or editing or busy then return end
    activeData=copy(data);draft=copy(data)
    exports.thehunt_character:ApplyPedCustomAppearance(PlayerPedId(),data.appearance)
    SetResourceKvp('pedcustom_draft',json.encode(draft))
    SendNUIMessage({action='draft',data=draft})
end)
