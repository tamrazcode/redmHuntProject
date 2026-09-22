local actionsById = {}
local byModel = {}
local activeAction = nil
local previewPed = nil
local previewKey = nil
local stopActiveAction = nil
local restorePlayerMovement = nil
local BATH_INTERACTIONS_ENABLED = false
local bathZones = {
    'hunt_world_bath_valentine', 'hunt_world_bath_saintdenis', 'hunt_world_bath_annesburg',
    'hunt_world_bath_vanhorn', 'hunt_world_bath_saintdenis2', 'hunt_world_bath_rhodes',
    'hunt_world_bath_tumbleweed', 'hunt_world_bath_blackwater', 'hunt_world_bath_strawberry',
    -- Legacy names from the earlier bridge version.
    'hunt_awz_bath_valentine', 'hunt_awz_bath_saintdenis', 'hunt_awz_bath_annesburg',
    'hunt_awz_bath_vanhorn', 'hunt_awz_bath_saintdenis2', 'hunt_awz_bath_rhodes',
    'hunt_awz_bath_tumbleweed', 'hunt_awz_bath_blackwater', 'hunt_awz_bath_strawberry'
}

local function compatible(rule, ped)
    return not rule.isCompatible or rule.isCompatible(ped)
end

local function title(value)
    return value:gsub('^PROP_HUMAN_', ''):gsub('^MP_LOBBY_PROP_HUMAN_', ''):gsub('^WORLD_PLAYER_', ''):gsub('_', ' '):lower()
end

local function scenarioLabel(name)
    local labels = {
        GENERIC_SEAT_BENCH_SCENARIO = 'Сесть',
        GENERIC_SEAT_CHAIR_SCENARIO = 'Сесть',
        GENERIC_SEAT_CHAIR_TABLE_SCENARIO = 'Сесть за стол',
        PROP_HUMAN_SEAT_CHAIR_DRINKING = 'Выпить',
        PROP_HUMAN_PIANO = 'Играть на пианино',
        PROP_HUMAN_ABIGAIL_PIANO = 'Играть на пианино',
        WORLD_PLAYER_SLEEP_BEDROLL = 'Спать',
        WORLD_PLAYER_SLEEP_GROUND = 'Спать',
        WORLD_HUMAN_SIT_FALL_ASLEEP = 'Задремать',
    }
    return labels[name] or title(name)
end

local function categoryIcon(category)
    if category == 'bath' or category == 'bed' then return 'rest' end
    if category == 'piano' then return 'activity' end
    return 'seat'
end

local function paginate(actions, pageSize)
    if #actions <= pageSize then return actions end
    local pages = {}
    for startAt = 1, #actions, pageSize do
        local page = {}
        for index = startAt, math.min(startAt + pageSize - 1, #actions) do
            page[#page + 1] = actions[index]
        end
        pages[#pages + 1] = page
    end
    for index, page in ipairs(pages) do
        if pages[index + 1] then
            page[#page + 1] = {
                id = 'hunt_world_page_' .. index,
                label = 'Следующая страница',
                icon = 'next',
                submenu = pages[index + 1]
            }
        end
    end
    return pages[1]
end

local function addAction(entity, interaction, entry, kind, actions, seen)
    local name = kind == 'scenario' and entry.name or entry.labelKey
    local id = ('hunt_world_%s_%s_%s_%s_%s'):format(GetEntityModel(entity), kind, name, interaction.x or 0, interaction.y or 0)
    if seen[id] then return end
    seen[id] = true

    local stored = {
        scenario = kind == 'scenario' and entry.name or nil,
        animation = kind == 'animation' and entry or nil,
        x = interaction.x or 0.0, y = interaction.y or 0.0, z = interaction.z or 0.0,
        heading = interaction.heading or 0.0, effect = interaction.effect
    }
    actionsById[id] = stored
    actions[#actions + 1] = {
        id = id,
        label = kind == 'scenario' and scenarioLabel(entry.name) or 'Принять ванну',
        icon = categoryIcon(interaction.category),
        event = 'thehunt_worldinteractions:execute',
        scenarioName = kind == 'scenario' and entry.name or '',
        previewEvent = kind == 'scenario' and 'thehunt_worldinteractions:preview' or nil
    }
end

local function buildActions(entity)
    local actions, seen = {}, {}
    local ped = PlayerPedId()
    for _, interaction in ipairs(byModel[GetEntityModel(entity)] or {}) do
        if compatible(interaction, ped) then
            if interaction.category == 'bath' then
                -- Baths are intentionally excluded from the HUNT interaction
                -- layer (including all prop and fixed-point variants).
            elseif interaction.scenarios then
                for _, scenario in ipairs(interaction.scenarios) do
                    if compatible(scenario, ped) then addAction(entity, interaction, scenario, 'scenario', actions, seen) end
                end
            elseif interaction.animations then
                for _, animation in ipairs(interaction.animations) do
                    if compatible(animation, ped) then addAction(entity, interaction, animation, 'animation', actions, seen) end
                end
            end
        end
    end
    if #actions <= 6 then return actions end

    local seating, rest, activity = {}, {}, {}
    for _, action in ipairs(actions) do
        local name = action.scenarioName or ''
        if name:find('GENERIC_SEAT') or name == 'PROP_HUMAN_SEAT_CHAIR' or name == 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR' then
            action.icon = 'seat'
            seating[#seating + 1] = action
        elseif name:find('BANJO') or name:find('GUITAR') or name:find('FIDDLE') or name:find('MANDOLIN')
            or name:find('CONCERTINA') or name:find('HARMONICA') or name:find('JAW_HARP') then
            action.icon = 'activity'
            activity[#activity + 1] = action
        else
            action.icon = 'rest'
            rest[#rest + 1] = action
        end
    end

    local categories = {}
    if #seating > 0 then categories[#categories + 1] = { id = 'hunt_world_seat', label = 'Сесть', icon = 'seat', submenu = paginate(seating, 5) } end
    if #rest > 0 then categories[#categories + 1] = { id = 'hunt_world_rest', label = 'Отдых', icon = 'rest', submenu = paginate(rest, 5) } end
    if #activity > 0 then categories[#categories + 1] = { id = 'hunt_world_activity', label = 'Развлечения', icon = 'activity', submenu = paginate(activity, 5) } end
    return categories
end

local function resolvePosition(entity, action)
    local heading = GetEntityHeading(entity)
    -- Use the engine's local-offset transform instead of adding Z in world
    -- space. This preserves the actual prop height (and pitch/roll) for
    -- chairs, benches and beds placed on uneven or raised surfaces.
    local offset = GetOffsetFromEntityInWorldCoords(entity, action.x or 0.0, action.y or 0.0, action.z or 0.0)
    return offset.x, offset.y, offset.z, heading + (action.heading or 0.0)
end

-- The original AWZ picker shows a local, translucent clone while an item is
-- highlighted. Keep this preview completely client-side: it never freezes or
-- moves the real player and it is limited to the stable scenario actions.
local function stopPreview()
    previewKey = nil
    if previewPed and DoesEntityExist(previewPed) then
        ClearPedTasksImmediately(previewPed)
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

exports('GetPreviewPed', function()
    return previewPed
end)

local function startPreview(target, actionId)
    local action = actionsById[actionId]
    if not action or not action.scenario then
        stopPreview()
        return
    end

    local entity = target and target.entity
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        stopPreview()
        return
    end

    local key = tostring(entity) .. ':' .. tostring(actionId)
    if previewKey == key and previewPed and DoesEntityExist(previewPed) then return end
    stopPreview()

    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) or IsPedDeadOrDying(playerPed) then return end
    local x, y, z, heading = resolvePosition(entity, action)

    -- RedM CLONE_PED signature: ClonePed(ped, isNetwork, bScriptHostPed, copyHeadBlendFlag)
    -- All boolean flags MUST be false so that the clone is strictly local to this client and never synchronized over the network.
    local ok, ghost = pcall(ClonePed, playerPed, false, false, false, false)
    if not ok or not ghost or ghost == 0 or ghost == playerPed or not DoesEntityExist(ghost) then
        local model = GetEntityModel(playerPed)
        ghost = CreatePed(model, x, y, z, heading, false, false, false, false)
        if not ghost or ghost == 0 or not DoesEntityExist(ghost) then return end
    end

    previewKey = key
    previewPed = ghost
    SetEntityCoordsNoOffset(ghost, x, y, z, false, false, false)
    SetEntityHeading(ghost, heading)
    SetEntityVisible(ghost, true)
    -- Keep the clone invisible until its scenario task is actually active;
    -- otherwise ClonePed briefly renders the default T-pose.
    SetEntityAlpha(ghost, 0, false)
    SetEntityCollision(ghost, false, false)
    SetEntityNoCollisionEntity(playerPed, ghost, false)
    SetEntityNoCollisionEntity(ghost, playerPed, false)
    SetEntityInvincible(ghost, true)
    SetPedCanRagdoll(ghost, false)
    SetPedCanRagdollFromPlayerImpact(ghost, false)
    SetEntityCanBeDamaged(ghost, false)
    SetBlockingOfNonTemporaryEvents(ghost, true)
    SetEntityAsMissionEntity(ghost, true, false)

    -- Match player scale if customized in thehunt_character
    local gotAppearance, skin = pcall(function()
        return exports['thehunt_character']:GetCachedAppearance()
    end)
    local playerScale = gotAppearance and skin and tonumber(skin.Scale or skin.scale)
    if playerScale then
        SetPedScale(ghost, playerScale + 0.0)
    end

    -- Mark preview state locally so world cleaner leaves it alone,
    -- and ensure the native network visibility flag is explicitly set to invisible.
    pcall(function()
        Entity(ghost).state:set('isGhostPreview', true, false)
        Entity(ghost).state:set('isProtected', true, false)
        Citizen.InvokeNative(0xF1CA12B18AEF5298, ghost, true) -- _NETWORK_SET_ENTITY_INVISIBLE_TO_NETWORK
    end)
    RemoveAllPedWeapons(ghost, true, true)

    local scenarioHash = GetHashKey(action.scenario)
    ClearPedTasksImmediately(ghost)
    Wait(50)
    TaskStartScenarioAtPosition(ghost, scenarioHash, x, y, z, heading, -1, false, true)

    CreateThread(function()
        local deadline = GetGameTimer() + 1200
        local earliestReveal = GetGameTimer() + 150
        local active = false
        while previewPed == ghost and previewKey == key and DoesEntityExist(ghost) and GetGameTimer() < deadline do
            local ok, usingScenario = pcall(function()
                return Citizen.InvokeNative(0x34D6AC1157C8226C, ghost, scenarioHash)
            end)
            -- Citizen.InvokeNative may return either a Lua boolean or an
            -- integer 0/1 depending on the game build; Lua treats numeric 0
            -- as truthy, so check both forms explicitly.
            if GetGameTimer() >= earliestReveal and ok and (usingScenario == true or usingScenario == 1) then
                active = true
                break
            end
            Wait(10)
        end
        if previewPed == ghost and previewKey == key and DoesEntityExist(ghost) then
            if active then Wait(80) end
            -- Reveal once active; the timeout fallback prevents a missing
            -- scenario status native from leaving the preview invisible.
            SetEntityAlpha(ghost, 115, false)
            if not active then
                ClearPedTasksImmediately(ghost)
                TaskStartScenarioAtPosition(ghost, scenarioHash, x, y, z, heading, -1, false, true)
            end
        end
    end)
end

RegisterNetEvent('thehunt_worldinteractions:preview', function(target, actionId)
    startPreview(target, actionId)
end)

RegisterNetEvent('thehunt_interact:previewClear', stopPreview)

local isStoppingAction = false

local moveControls = {
    `INPUT_MOVE_LR`,
    `INPUT_MOVE_UD`,
    `INPUT_MOVE_UP_ONLY`,
    `INPUT_MOVE_DOWN_ONLY`,
    `INPUT_MOVE_LEFT_ONLY`,
    `INPUT_MOVE_RIGHT_ONLY`,
    `INPUT_SPRINT`,
    `INPUT_JUMP`
}

restorePlayerMovement = function(ped, entity)
    ped = ped or PlayerPedId()
    if not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, false)
    ClearPedSecondaryTask(ped)
    SetPedCanRagdoll(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)

    -- Disable collision with the furniture prop so the ped can step away freely.
    if entity and DoesEntityExist(entity) then
        SetEntityNoCollisionEntity(ped, entity, false)
        SetEntityNoCollisionEntity(entity, ped, false)
    end

    pcall(function()
        if exports['thehunt_walking'] and exports['thehunt_walking'].ApplyCurrentSpeed then
            exports['thehunt_walking']:ApplyCurrentSpeed()
        end
    end)
end

stopActiveAction = function(force)
    if not activeAction or isStoppingAction then return false end
    isStoppingAction = true

    local ped = PlayerPedId()
    local hadScenario = IsPedUsingAnyScenario(ped)
    local entity = activeAction.entity

    -- Cleanup props from hands
    TriggerEvent('thehunt_animations:client:cleanupLocalProps', 'worldinteractions')
    FreezeEntityPosition(ped, false)

    -- Immediately disable collision with furniture prop so the capsule doesn't get stuck
    if entity and DoesEntityExist(entity) then
        SetEntityNoCollisionEntity(ped, entity, false)
        SetEntityNoCollisionEntity(entity, ped, false)
    end

    if force or not hadScenario then
        ClearPedTasksImmediately(ped)
        restorePlayerMovement(ped, entity)
        activeAction = nil
        LocalPlayer.state:set('huntWorldInteractionActive', false, false)
        isStoppingAction = false
        return true
    end

    -- Smooth exit: Native RDR2 stand-up transition from scenario (identical to thehunt_animations)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    CreateThread(function()
        local startTime = GetGameTimer()
        local myPed = PlayerPedId()
        local wantMove = false

        while IsPedUsingAnyScenario(myPed) and (GetGameTimer() - startTime < 3200) do
            Wait(50)
            myPed = PlayerPedId()

            for i = 1, #moveControls do
                if IsControlJustPressed(0, moveControls[i]) or IsDisabledControlJustPressed(0, moveControls[i]) then
                    wantMove = true
                    break
                end
            end
            if wantMove then break end
        end

        ClearPedTasksImmediately(myPed)
        restorePlayerMovement(myPed, entity)

        activeAction = nil
        LocalPlayer.state:set('huntWorldInteractionActive', false, false)
        isStoppingAction = false
    end)

    return true
end

exports('GetActiveAction', function()
    return activeAction
end)

exports('UpdateActivePosition', function(x, y, z, heading)
    if not activeAction then return false end
    activeAction.x = x
    activeAction.y = y
    activeAction.z = z
    activeAction.heading = heading
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return false end
    if activeAction.scenario then
        -- Restart scenario at new coords with teleport=true (no entry anim).
        -- This updates the OneSync-replicated scenario position so other clients see the ped at the right place.
        TaskStartScenarioAtPosition(ped, GetHashKey(activeAction.scenario), x, y, z, heading, -1, false, true)
    else
        -- For plain animations: teleport ped, freeze in place.
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, heading)
        FreezeEntityPosition(ped, true)
    end
    return true
end)

RegisterNetEvent('thehunt_worldinteractions:execute', function(target, actionId)
    local action, entity = actionsById[actionId], target and target.entity
    if not action then return end
    if action.bath then return end
    local ped = PlayerPedId()
    local x, y, z, heading
    if entity and DoesEntityExist(entity) then
        x, y, z, heading = resolvePosition(entity, action)
    elseif action.world then
        x, y, z, heading = action.world.x, action.world.y, action.world.z, action.world.heading
    else
        return
    end

    if activeAction then
        stopActiveAction(true)
        Wait(100)
    end

    ClearPedTasksImmediately(ped)
    -- Не замораживаем педа намертво: сценарии RDR2 сами позиционируют персонажа.
    -- Заморозка ломает физику, выходные переходы и сбрасывает скорость передвижения.
    FreezeEntityPosition(ped, false)

    if action.scenario then
        TaskStartScenarioAtPosition(ped, GetHashKey(action.scenario), x, y, z, heading, -1, false, true)
    elseif action.animation and DoesAnimDictExist(action.animation.dict) then
        RequestAnimDict(action.animation.dict)
        local expires = GetGameTimer() + 5000
        while not HasAnimDictLoaded(action.animation.dict) and GetGameTimer() < expires do Wait(10) end
        if HasAnimDictLoaded(action.animation.dict) then
            SetEntityCoordsNoOffset(ped, x, y, z)
            SetEntityHeading(ped, heading)
            TaskPlayAnim(ped, action.animation.dict, action.animation.name, 1.0, 1.0, -1, 1, 0.0, false, false, false, '', false)
        end
    end
    if action.effect == 'clean' then ClearPedEnvDirt(ped); ClearPedBloodDamage(ped) end
    activeAction = {
        scenario = action.scenario,
        animation = action.animation,
        entity = entity,
        startedAt = GetGameTimer()
    }
    LocalPlayer.state:set('huntWorldInteractionActive', true, false)
end)

CreateThread(function()
    Wait(1200)
    -- Remove zones registered by an earlier resource version before continuing.
    for _, zoneName in ipairs(bathZones) do
        exports['thehunt_interact']:RemoveTargetZone(zoneName)
    end
    local models = {}
    for _, interaction in ipairs(Interactions) do
        if interaction.objects and (BATH_INTERACTIONS_ENABLED or interaction.category ~= 'bath') then
            for _, model in ipairs(interaction.objects) do
                local hash = joaat(model)
                byModel[hash] = byModel[hash] or {}
                byModel[hash][#byModel[hash] + 1] = interaction
            end
        end
    end
    for hash in pairs(byModel) do models[#models + 1] = hash end
    -- World furniture animations use direct camera hits. The optional layer flag
    -- disables the broad proximity fallback while retaining a strict model-surface
    -- fallback for static map props whose raycast has no entity handle.
    exports['thehunt_interact']:AddTargetModelLayer(models, buildActions, 2.0, {
        raycastOnly = true
    })

    -- Bath interactions are intentionally disabled. Keep removing the known
    -- zone ids above so an older resource version cannot leave stale zones.
    local baths = {}
    if BATH_INTERACTIONS_ENABLED then
        for _, bath in ipairs(baths) do
            local bathActions = {}
            local id = 'hunt_world_bath_' .. bath.id
            actionsById[id] = { bath = true, effect = 'clean', world = bath }
            bathActions[1] = {
                id = id, label = 'Принять ванну', icon = 'rest',
                event = 'thehunt_worldinteractions:execute'
            }
            exports['thehunt_interact']:AddTargetZone('hunt_world_bath_' .. bath.id,
                vector3(bath.x, bath.y, bath.z), 2.0, bathActions, 2.0)
        end
    end
    print(('[HUNT WORLD] Registered %d furniture models and %d bath zones.'):format(#models, #baths))
end)

RegisterNetEvent('thehunt_worldinteractions:cancel', function()
    -- Use smooth (non-force) exit so the player gets the same graceful
    -- stand-up animation that thehunt_animations provides on F1 cancel.
    stopActiveAction(false)
    LocalPlayer.state:set('huntWorldInteractionActive', false, false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopPreview()
    stopActiveAction(true)
    for _, zoneName in ipairs(bathZones) do
        exports['thehunt_interact']:RemoveTargetZone(zoneName)
    end
end)

CreateThread(function()
    while true do
        if activeAction and not isStoppingAction then
            Wait(0)
            local currentAction = activeAction
            if not currentAction or isStoppingAction then
                goto continueLoop
            end
            local ped = PlayerPedId()

            -- 1. Проверка естественного завершения анимации или сценария:
            -- если сценарий или анимация завершились сами по себе, автоматически освобождаем движение
            if currentAction.startedAt and (GetGameTimer() - currentAction.startedAt > 1200) then
                local isStillActive = false
                if currentAction.scenario then
                    isStillActive = IsPedUsingAnyScenario(ped)
                elseif currentAction.animation and currentAction.animation.dict then
                    isStillActive = IsEntityPlayingAnim(ped, currentAction.animation.dict, currentAction.animation.name, 3)
                end

                if not isStillActive then
                    stopActiveAction(false)
                    Wait(300)
                    goto continueLoop
                end
            end

            -- 2. Если персонаж умер, потерял сознание или упал в рэгдолл
            if IsPedDeadOrDying(ped) or IsPedRagdoll(ped) then
                stopActiveAction(true)
                Wait(300)
                goto continueLoop
            end

            -- Manual cancellation belongs exclusively to the shared F1 handler
            -- in thehunt_animations. G and movement keys do not cancel it.
        else
            Wait(300)
        end
        ::continueLoop::
    end
end)
