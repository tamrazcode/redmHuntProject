-- =================================================================
-- HUNT: Hard RP — Core Items System | Client World Drops & Streamer
-- =================================================================

local ActiveDrops = {} -- [dropId] = { id, itemName, label, count, x, y, z, entity = nil }
local STREAM_DISTANCE = 40.0
local TEXT_DISTANCE = 3.2

-- Вспомогательная функция безопасной загрузки модели
local function LoadModelSafely(modelHash)
    if not modelHash or modelHash == 0 then return false end
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 40 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    return HasModelLoaded(modelHash)
end

-- Отрисовка аккуратного компактного 3D-текста над объектом
local function Draw3DText(x, y, z, text)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    local textStr = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextScale(0.24, 0.24)
    SetTextFontForCurrentCommand(1)
    SetTextColor(245, 248, 250, 230)
    SetTextCentre(1)
    SetTextDropshadow(2, 0, 0, 0, 180)
    DisplayText(textStr, screenX, screenY)
end

-- Создание проп-модели для выброшенного предмета
local function SpawnDropProp(drop)
    if drop.entity and DoesEntityExist(drop.entity) then return end

    local itemDef = Items.Get(drop.itemName)
    local modelName = (itemDef and itemDef.dropModel) or "p_crate26x_b"
    local modelHash = joaat(modelName)

    if LoadModelSafely(modelHash) then
        local minDim, maxDim = GetModelDimensions(modelHash)
        local zOffset = 0.0
        if minDim and minDim.z then
            zOffset = math.abs(minDim.z)
        end

        local targetZ = drop.z + zOffset
        local obj = CreateObject(modelHash, drop.x, drop.y, targetZ, false, false, false, false, false)
        if DoesEntityExist(obj) then
            SetEntityCoords(obj, drop.x, drop.y, targetZ, false, false, false, false)
            local isBp = (itemDef and itemDef.isBackpack) or string.sub(tostring(drop.itemName or ""), 1, 9) == "backpack_"
            if isBp then
                SetEntityCollision(obj, true, true)
                pcall(function()
                    PlaceObjectOnGroundProperly(obj, true)
                end)
            else
                SetEntityCollision(obj, false, false)
            end
            FreezeEntityPosition(obj, true)
            SetEntityCanBeDamaged(obj, false)
            drop.entity = obj
        end
        SetModelAsNoLongerNeeded(modelHash)
    end
end

-- Удаление проп-модели
local function DeleteDropProp(drop)
    if drop.entity and DoesEntityExist(drop.entity) then
        DeleteEntity(drop.entity)
        drop.entity = nil
    end
end

-- Прием списка дропов от сервера
RegisterNetEvent("thehunt_items:receiveInventory", function(items, drops, serverGender, requestId, requestMutationSequence)
    if drops then
        -- Удаляем пропавшие
        for dId, d in pairs(ActiveDrops) do
            if not drops[dId] then
                DeleteDropProp(d)
                ActiveDrops[dId] = nil
            end
        end

        for dId, d in pairs(drops) do
            local numId = tonumber(dId)
            if not ActiveDrops[numId] then
                ActiveDrops[numId] = {
                    id = numId,
                    itemName = d.itemName,
                    label = d.label,
                    count = d.count,
                    x = d.x,
                    y = d.y,
                    z = d.z,
                    metadata = d.metadata or {},
                    entity = nil
                }
            else
                ActiveDrops[numId].count = d.count
            end
        end
    end

    -- Передаем обновленные данные в инвентарь
    TriggerEvent("thehunt_inventory:onItemsReceived", items, ActiveDrops, serverGender, requestId, requestMutationSequence)
end)

-- Создание нового дропа в реальном времени
RegisterNetEvent("thehunt_items:onDropCreated", function(dropData)
    if not dropData or not dropData.id then return end
    local dId = tonumber(dropData.id)

    ActiveDrops[dId] = {
        id = dId,
        itemName = dropData.itemName,
        label = dropData.label,
        count = dropData.count,
        x = dropData.x,
        y = dropData.y,
        z = dropData.z,
        metadata = dropData.metadata or {},
        entity = nil
    }

    TriggerEvent("thehunt_inventory:onDropsUpdated", ActiveDrops)
end)

-- Удаление дропа при подборе
RegisterNetEvent("thehunt_items:onDropRemoved", function(dropId)
    local dId = tonumber(dropId)
    if ActiveDrops[dId] then
        DeleteDropProp(ActiveDrops[dId])
        ActiveDrops[dId] = nil
        TriggerEvent("thehunt_inventory:onDropsUpdated", ActiveDrops)
    end
end)

-- Обновление количества дропа при объединении/разделении
RegisterNetEvent("thehunt_items:onDropUpdated", function(dropId, newCount)
    local dId = tonumber(dropId)
    if ActiveDrops[dId] then
        ActiveDrops[dId].count = tonumber(newCount) or ActiveDrops[dId].count
        TriggerEvent("thehunt_inventory:onDropsUpdated", ActiveDrops)
    end
end)

-- 1. Поток фонового стриминга проп-моделей в мире
Citizen.CreateThread(function()
    while true do
        local pedCoords = GetEntityCoords(PlayerPedId())
        for dId, drop in pairs(ActiveDrops) do
            local dropPos = vector3(drop.x, drop.y, drop.z)
            local dist = #(pedCoords - dropPos)

            if dist < STREAM_DISTANCE then
                if not drop.entity then
                    SpawnDropProp(drop)
                end
            else
                if drop.entity then
                    DeleteDropProp(drop)
                end
            end
        end
        Citizen.Wait(400)
    end
end)

-- 2. Высокочастотный поток плавной отрисовки 3D-текста над предметами (0ms без лагов)
Citizen.CreateThread(function()
    local TEXT_DISTANCE = 1.5

    while true do
        local pedCoords = GetEntityCoords(PlayerPedId())
        local hasNearbyText = false

        for dId, drop in pairs(ActiveDrops) do
            local posX = drop.x
            local posY = drop.y
            local posZ = drop.z

            if drop.entity and DoesEntityExist(drop.entity) then
                local entCoords = GetEntityCoords(drop.entity)
                posX = entCoords.x
                posY = entCoords.y
                posZ = entCoords.z
            end

            local dist = #(pedCoords - vector3(posX, posY, posZ))
            if dist < TEXT_DISTANCE then
                hasNearbyText = true
                local text = drop.label or drop.itemName
                Draw3DText(posX, posY, posZ + 0.25, text)
            end
        end

        Citizen.Wait(hasNearbyText and 0 or 200)
    end
end)

-- Экспорт списка предметов рядом для "Рядом" сетки инвентаря
exports('GetNearbyGroundDrops', function(maxDist)
    local pedCoords = GetEntityCoords(PlayerPedId())
    local nearby = {}
    local radius = maxDist or 1.5

    for dId, drop in pairs(ActiveDrops) do
        local dist = #(pedCoords - vector3(drop.x, drop.y, drop.z))
        if dist <= radius then
            local itemDef = Items.Get(drop.itemName)
            table.insert(nearby, {
                dropId = dId,
                name = drop.itemName,
                label = (drop.metadata and drop.metadata.label) or drop.label or (itemDef and itemDef.label) or drop.itemName,
                count = tonumber(drop.count) or 1,
                width = itemDef and itemDef.width or 1,
                height = itemDef and itemDef.height or 1,
                rarity = itemDef and itemDef.rarity or "white",
                category = itemDef and itemDef.category or "item",
                description = itemDef and itemDef.description or "",
                weight = itemDef and itemDef.weight or 0.1,
                maxStack = itemDef and itemDef.maxStack or 1,
                canUse = itemDef and itemDef.canUse or false,
                actions = itemDef and itemDef.actions or { "place", "give", "drop" },
                image = itemDef and itemDef.image or nil,
                clothing = itemDef and itemDef.clothing or false,
                clothingSlot = itemDef and itemDef.clothingSlot or nil,
                insulationLabel = itemDef and itemDef.insulationLabel or nil,
                storage = itemDef and itemDef.storage or nil,
                isContainer = itemDef and itemDef.isContainer or false,
                containerStorage = itemDef and itemDef.containerStorage or nil,
                uses = (drop.metadata and tonumber(drop.metadata.uses)) or (itemDef and itemDef.uses) or nil,
                maxUses = (drop.metadata and tonumber(drop.metadata.maxUses)) or (itemDef and itemDef.maxUses) or nil,
                metadata = drop.metadata or {}
            })
        end
    end
    return nearby
end)

-- Анимация питья из бутылки
local function StartInventoryItemAnimation(kind)
    TriggerEvent("thehunt_inventory:itemAnimationStarted", kind)
end

local function FinishInventoryItemAnimationAfter(durationMs)
    if not durationMs or durationMs <= 0 then
        TriggerEvent("thehunt_inventory:itemAnimationFinished")
        return
    end

    Citizen.CreateThread(function()
        Citizen.Wait(durationMs)
        TriggerEvent("thehunt_inventory:itemAnimationFinished")
    end)
end

RegisterNetEvent("thehunt_items:playDrinkAnimation", function()
    StartInventoryItemAnimation("drink")
    local ped = PlayerPedId()
    local animDict = "amb_rest_drunk@world_human_drinking@male_a@idle_a"
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 20 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "idle_a", 3.0, 3.0, 2500, 31, 0, false, false, false)
        FinishInventoryItemAnimationAfter(2500)
    else
        FinishInventoryItemAnimationAfter(0)
    end
end)

-- Анимация поедания еды (яблоко, апельсин, лимон)
RegisterNetEvent("thehunt_items:playEatAnimation", function()
    StartInventoryItemAnimation("eat")
    local ped = PlayerPedId()
    local animDict = "mech_inventory@eating@default"
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 20 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "eat_quick", 3.0, 3.0, 2200, 31, 0, false, false, false)
        FinishInventoryItemAnimationAfter(2200)
    else
        local fallbackDict = "amb_rest_drunk@world_human_drinking@male_a@idle_a"
        RequestAnimDict(fallbackDict)
        if HasAnimDictLoaded(fallbackDict) then
            TaskPlayAnim(ped, fallbackDict, "idle_a", 3.0, 3.0, 2000, 31, 0, false, false, false)
            FinishInventoryItemAnimationAfter(2000)
        else
            FinishInventoryItemAnimationAfter(0)
        end
    end
end)

-- =================================================================
-- ОЧЕРЕДЬ МЕДИЦИНСКОГО ЛЕЧЕНИЯ И ПРЕДВАРИТЕЛЬНЫЙ ПРОСМОТР ЗДОРОВЬЯ
-- =================================================================

local healingQueue = {}
local isHealingWorkerActive = false
local cumulativeTargetHp = nil

-- Экспорт для получения текущего прогнозируемого процента здоровья (с учетом очереди лечения)
local function GetPredictedHealthPct()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return 100 end
    local maxHp = GetEntityMaxHealth(ped)
    if maxHp <= 0 then maxHp = 100 end
    local curHp = GetEntityHealth(ped)

    if cumulativeTargetHp ~= nil and cumulativeTargetHp > curHp then
        local pct = math.min(100, math.floor((cumulativeTargetHp / maxHp) * 100))
        return pct
    end

    return math.min(100, math.floor((curHp / maxHp) * 100))
end

exports('GetPredictedHealthPct', GetPredictedHealthPct)
exports('GetPredictedHealth', GetPredictedHealthPct)

-- Постепенное последовательное лечение от медицины (бинт / повязка с лопухом) с кумулятивным превью в HUD
RegisterNetEvent("thehunt_items:applyBandageHeal", function(healAmount, durationSec, itemLabel)
    local ped = PlayerPedId()
    StartInventoryItemAnimation("bandage")

    -- 1. Анимация наложения повязки (всегда проигрывается сразу при использовании)
    local animDict = "mech_inventory@item@bandages"
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 15 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "use_quick", 3.0, 3.0, 2200, 31, 0, false, false, false)
        FinishInventoryItemAnimationAfter(2200)
    else
        FinishInventoryItemAnimationAfter(0)
    end

    local totalDuration = durationSec or 30
    local totalHeal = healAmount or 25

    local maxHp = GetEntityMaxHealth(ped)
    if maxHp <= 0 then maxHp = 100 end
    local curHp = GetEntityHealth(ped)

    -- 2. Расчет кумулятивной полоски превью (добавляется после предыдущего индикатора)
    local baselineHp = curHp
    if cumulativeTargetHp ~= nil and cumulativeTargetHp > curHp then
        baselineHp = cumulativeTargetHp
    end

    cumulativeTargetHp = math.min(maxHp, baselineHp + totalHeal)
    local ghostPct = math.min(100, math.floor((cumulativeTargetHp / maxHp) * 100))

    if ghostPct > math.floor((curHp / maxHp) * 100) then
        TriggerEvent("thehunt_status:setHealPreview", ghostPct)
    end

    -- 3. Добавление задачи в очередь лечения
    table.insert(healingQueue, {
        healAmount = totalHeal,
        durationSec = totalDuration,
        itemLabel = itemLabel
    })

    -- 4. Запуск рабочего потока очереди (если еще не запущен)
    if not isHealingWorkerActive then
        isHealingWorkerActive = true

        Citizen.CreateThread(function()
            while #healingQueue > 0 do
                local task = table.remove(healingQueue, 1)
                local taskDuration = task.durationSec or 30
                local taskHeal = task.healAmount or 25
                local steps = math.max(1, math.floor(taskDuration / 1.5))
                local healPerStep = taskHeal / steps

                for i = 1, steps do
                    Citizen.Wait(1500)

                    local currentPed = PlayerPedId()
                    if not DoesEntityExist(currentPed) or IsPedDeadOrDying(currentPed, true) then
                        healingQueue = {}
                        cumulativeTargetHp = nil
                        isHealingWorkerActive = false
                        TriggerEvent("thehunt_status:setHealPreview", nil)
                        return
                    end

                    local cHp = GetEntityHealth(currentPed)
                    local mHp = GetEntityMaxHealth(currentPed)
                    if mHp <= 0 then mHp = 100 end

                    if cHp < mHp then
                        local nextHp = math.min(mHp, math.floor(cHp + healPerStep + 0.5))
                        SetEntityHealth(currentPed, nextHp)
                        cHp = nextHp
                    end

                    if cHp >= mHp then
                        -- Если здоровье уже заполнено на 100%
                        healingQueue = {}
                        cumulativeTargetHp = nil
                        break
                    end
                end
            end

            -- Завершение всех задач в очереди
            isHealingWorkerActive = false
            cumulativeTargetHp = nil
            TriggerEvent("thehunt_status:setHealPreview", nil)
        end)
    end
end)

-- Анимация оказания медицинской помощи другому игроку
RegisterNetEvent("thehunt_items:playMedicalAnimHealer", function()
    local ped = PlayerPedId()
    StartInventoryItemAnimation("medical")
    local animDict = "mech_inventory@item@bandages"
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 15 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "use_quick", 3.0, 3.0, 2200, 31, 0, false, false, false)
        FinishInventoryItemAnimationAfter(2200)
    else
        FinishInventoryItemAnimationAfter(0)
    end
end)

local knockAidAnimationActive = false

RegisterNetEvent("thehunt_items:playKnockAidAnimation", function(targetServerId)
    local ped = PlayerPedId()
    local targetPlayer = GetPlayerFromServerId(tonumber(targetServerId) or -1)
    local targetPed = targetPlayer ~= -1 and GetPlayerPed(targetPlayer) or 0
    if targetPed ~= 0 and DoesEntityExist(targetPed) then
        TaskTurnPedToFaceEntity(ped, targetPed, 700)
    end

    knockAidAnimationActive = true
    -- Use the same kneeling scenario as campfire ignition. The server keeps
    -- the treatment open for ten seconds; the scenario is stopped smoothly by
    -- finishKnockAidAnimation when that authoritative window ends.
    TriggerEvent('thehunt_animations:client:setProtectedAction', true, 'knock_aid', 11000)
    TaskStartScenarioInPlace(ped, GetHashKey("WORLD_HUMAN_CROUCH_INSPECT"), -1, true, false, false, false)
end)

RegisterNetEvent("thehunt_items:finishKnockAidAnimation", function(success)
    if not knockAidAnimationActive then return end
    knockAidAnimationActive = false
    ClearPedTasks(PlayerPedId())
    TriggerEvent('thehunt_animations:client:setProtectedAction', false, 'knock_aid')
end)

-- Открытие размещенного в мире контейнера (мешок, сумка, связка ключей) через меню G
RegisterNetEvent("thehunt_items:clientOpenPlacedContainer", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    local ped = PlayerPedId()
    local animDict = "script_common@shared_scenarios@generic@door_lock@unarmed"
    RequestAnimDict(animDict)
    local count = 0
    while not HasAnimDictLoaded(animDict) and count < 10 do
        Citizen.Wait(30)
        count = count + 1
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, "action", 3.0, -3.0, 700, 0, 0, false, false, false)
        Citizen.Wait(300)
    end

    TriggerServerEvent("thehunt_items:openPlacedContainer", tonumber(propId))
end)

-- Открытие интерфейса чтения размещенной в мире страницы / блокнота через меню G
RegisterNetEvent("thehunt_items:clientReadPlacedNote", function(targetInfo)
    local propId = targetInfo and (targetInfo.propId or (targetInfo.targetInfo and targetInfo.targetInfo.propId))
    if not propId then return end

    TriggerServerEvent("thehunt_items:readPlacedNote", tonumber(propId))
end)
