-- HUNT AWZ-world-interactions bridge. Keeps thehunt_interact's exports and UI intact.
local AWZ_ACTION_PREFIX = 'hunt_awz_'
local awzActive = nil

local function IsPedChildHunt(ped)
    return Citizen.InvokeNative(0x137772000DAF42C5, ped)
end

local function IsPedAdult(ped) return IsPedHuman(ped) and not IsPedChildHunt(ped) end
local function IsPedHumanMale(ped) return IsPedHuman(ped) and IsPedMale(ped) end
local function IsPedHumanFemale(ped) return IsPedHuman(ped) and not IsPedMale(ped) end
local function IsPedAdultFemale(ped) return IsPedAdult(ped) and not IsPedMale(ped) end
local function IsCompatible(rule, ped) return not rule.isCompatible or rule.isCompatible(ped) end

local labels = {
    PROP_HUMAN_PIANO = 'Играть на пианино',
    PROP_HUMAN_ABIGAIL_PIANO = 'Играть на пианино',
    GENERIC_SEAT_BENCH_SCENARIO = 'Сесть',
    GENERIC_SEAT_CHAIR_SCENARIO = 'Сесть',
    GENERIC_SEAT_CHAIR_TABLE_SCENARIO = 'Сесть за стол',
    PROP_HUMAN_SEAT_CHAIR_DRINKING = 'Сесть и выпить',
    PROP_HUMAN_SEAT_BENCH_HARMONICA = 'Играть на губной гармошке',
    PROP_HUMAN_SEAT_CHAIR_FAN = 'Обмахиваться веером',
    WORLD_PLAYER_SLEEP_BEDROLL = 'Спать',
    WORLD_PLAYER_SLEEP_GROUND = 'Спать',
    WORLD_HUMAN_SIT_FALL_ASLEEP = 'Задремать',
}
local function LabelForScenario(name)
    return labels[name] or (name:gsub('^PROP_HUMAN_', ''):gsub('^MP_LOBBY_PROP_HUMAN_', ''):gsub('_', ' '):lower())
end
local function LabelForAnimation(animation)
    local label = { bath_idle = 'Расслабиться в ванне', bath_left_arm = 'Вымыть левую руку',
        bath_right_arm = 'Вымыть правую руку', bath_left_leg = 'Вымыть левую ногу',
        bath_right_leg = 'Вымыть правую ногу' }
    return label[animation.labelKey] or 'Принять ванну'
end

local function ResolveWorldPosition(entity, action)
    local objectCoords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    local r = math.rad(heading)
    local x, y = action.x or 0.0, action.y or 0.0
    return x * math.cos(r) - y * math.sin(r) + objectCoords.x,
        x * math.sin(r) + y * math.cos(r) + objectCoords.y,
        objectCoords.z + (action.z or 0.0),
        heading + (action.heading or 0.0)
end

local function StartAwzAction(action, target)
    local entity = target and target.entity
    local ped = PlayerPedId()
    local x, y, z, heading
    if entity and DoesEntityExist(entity) then
        x, y, z, heading = ResolveWorldPosition(entity, action)
    elseif action.world then
        x, y, z, heading = action.world.x, action.world.y, action.world.z, action.world.heading
    else
        return
    end
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    if action.scenario then
        TaskStartScenarioAtPosition(ped, GetHashKey(action.scenario), x, y, z, heading, -1, false, true)
    elseif action.animation and DoesAnimDictExist(action.animation.dict) then
        RequestAnimDict(action.animation.dict)
        local untilAt = GetGameTimer() + 5000
        while not HasAnimDictLoaded(action.animation.dict) and GetGameTimer() < untilAt do Wait(10) end
        if HasAnimDictLoaded(action.animation.dict) then
            SetEntityCoordsNoOffset(ped, x, y, z)
            SetEntityHeading(ped, heading)
            TaskPlayAnim(ped, action.animation.dict, action.animation.name, 0.0, 0.0, -1, 1, 1.0, false, false, false, '', false)
            RemoveAnimDict(action.animation.dict)
        end
    end
    if action.effect == 'clean' then
        ClearPedEnvDirt(ped)
        ClearPedDamageDecalByZone(ped, 10, 'ALL')
        ClearPedBloodDamage(ped)
    end
    awzActive = action
    TheHuntAwzInteractionActive = true
end

local function StopAwzAction()
    if not awzActive then return end
    ClearPedTasksImmediately(PlayerPedId())
    FreezeEntityPosition(PlayerPedId(), false)
    awzActive = nil
    TheHuntAwzInteractionActive = false
end

local ByModel = {}
for _, interaction in ipairs(Interactions) do
    if interaction.objects then
        for _, model in ipairs(interaction.objects) do
            local hash = joaat(model)
            ByModel[hash] = ByModel[hash] or {}
            table.insert(ByModel[hash], interaction)
        end
    end
end

local function BuildActions(entity)
    local ped, model = PlayerPedId(), GetEntityModel(entity)
    local actions, seen = {}, {}
    for _, interaction in ipairs(ByModel[model] or {}) do
        if IsCompatible(interaction, ped) then
            local entries, kind = interaction.scenarios or interaction.animations, interaction.scenarios and 'scenario' or 'animation'
            for _, entry in ipairs(entries or {}) do
                if IsCompatible(entry, ped) then
                    local name = kind == 'scenario' and entry.name or entry.labelKey
                    local id = AWZ_ACTION_PREFIX .. model .. '_' .. kind .. '_' .. name .. '_' .. tostring(interaction.x) .. '_' .. tostring(interaction.y)
                    if not seen[id] then
                        seen[id] = true
                        local action = {
                            id = id, label = kind == 'scenario' and LabelForScenario(entry.name) or LabelForAnimation(entry),
                            icon = interaction.category == 'bath' and 'medicine' or (interaction.category == 'piano' and 'interact' or 'interact'),
                            scenario = kind == 'scenario' and entry.name or nil,
                            animation = kind == 'animation' and entry or nil,
                            x = interaction.x, y = interaction.y, z = interaction.z, heading = interaction.heading,
                            effect = interaction.effect,
                        }
                        action.awzAction = {
                            scenario = action.scenario, animation = action.animation,
                            x = action.x, y = action.y, z = action.z, heading = action.heading,
                            effect = action.effect,
                        }
                        table.insert(actions, action)
                    end
                end
            end
        end
    end
    return actions
end

local function BuildBathPointActions(point)
    local actions = {}
    for _, animation in ipairs(BathingAnimations) do
        local action = {
            id = AWZ_ACTION_PREFIX .. 'bath_' .. animation.labelKey .. '_' .. point.id,
            label = LabelForAnimation(animation), icon = 'medicine', animation = animation,
            effect = 'clean', world = point,
        }
        action.awzAction = {
            animation = action.animation, effect = action.effect, world = action.world,
        }
        actions[#actions + 1] = action
    end
    return actions
end

CreateThread(function()
    Wait(1000)
    local models = {}
    for hash in pairs(ByModel) do models[#models + 1] = hash end
    TriggerEvent('thehunt_interact:registerBundledModels', models, function(entity) return BuildActions(entity) end, 2.0)

    local baths = {
        { id = 'valentine', x = -317.01651, y = 761.86, z = 117.45099, heading = 100.278 },
        { id = 'saintdenis', x = 2629.4099, y = -1223.7757, z = 59.6699, heading = 2.896 },
        { id = 'annesburg', x = -1812.46838, y = -373.23529, z = 166.64999, heading = 92.105 },
        { id = 'vanhorn', x = 2952.804199, y = 1335.031494, z = 44.496986, heading = 154.996 },
        { id = 'saintdenis2', x = 2365.649, y = -1211.780, z = 51.888, heading = 3.0 },
        { id = 'rhodes', x = 1336.350, y = -1377.972, z = 84.345, heading = -96.693 },
        { id = 'tumbleweed', x = -5513.196, y = -2972.139, z = -0.75, heading = 108.131 },
        { id = 'blackwater', x = 2987.698, y = 573.760, z = 47.920, heading = 171.942 },
        { id = 'strawberry', x = -823.362, y = -1318.832, z = 43.679, heading = 92.793 },
    }
    for _, bath in ipairs(baths) do
        TriggerEvent('thehunt_interact:registerBundledZone', 'hunt_awz_bath_' .. bath.id, vector3(bath.x, bath.y, bath.z), 2.0,
            function() return BuildBathPointActions(bath) end, 2.0)
    end
    print(('[HUNT INTERACT] AWZ world interactions loaded: %d models, %d bath zones.'):format(#models, #baths))
end)

RegisterNetEvent('thehunt_interact:awzStart', function(action, target)
    StartAwzAction(action, target)
end)

CreateThread(function()
    while true do
        if awzActive then
            Wait(0)
            if IsControlJustPressed(0, 0x5415BE48) or IsDisabledControlJustPressed(0, 0x5415BE48) then
                StopAwzAction()
                Wait(200)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then StopAwzAction() end
end)
