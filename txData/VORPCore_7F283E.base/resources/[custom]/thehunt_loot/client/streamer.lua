-- =================================================================
-- HUNT: Hard RP — The Corruption | Client Loot Prop Streamer
-- =================================================================

LootStreamer = {}

local ActiveSlots = {}      -- [slotId] = slotData (таблица всех слотов от сервера)
local SpawnedEntities = {}  -- [slotId] = entityHandle
local spawnCount = 0
local failedModels = {}
local LoadingModels = {}    -- [slotId] = true

local STREAM_TICK_MS = 500
local TEXT_DISTANCE  = 2.8

-- =================================================================
-- 1. СИНХРОНИЗАЦИЯ СЛОТОВ ОТ СЕРВЕРА
-- =================================================================

function LootStreamer.ReceiveAllSlots(slots)
    local newActive = {}
    if slots and type(slots) == "table" then
        for k, v in pairs(slots) do
            if v and v.id then
                local numId = tonumber(v.id)
                if numId then
                    newActive[numId] = v
                end
            end
        end
    end

    -- Очищаем сущности, которых больше нет в актуальном списке сервера
    for sId, ent in pairs(SpawnedEntities) do
        local numId = tonumber(sId)
        if not newActive[numId] then
            if DoesEntityExist(ent) then
                DeleteEntity(ent)
            end
            SpawnedEntities[sId] = nil
        end
    end

    ActiveSlots = newActive
    TriggerEvent("thehunt_inventory:refreshNearbyDrops")
end

function LootStreamer.AddSlot(slotData)
    if not slotData or not slotData.id then return end
    local sId = tonumber(slotData.id)
    if not sId then return end
    ActiveSlots[sId] = slotData
    TriggerEvent("thehunt_inventory:refreshNearbyDrops")
end

function LootStreamer.RemoveSlot(slotId)
    local sId = tonumber(slotId)
    if not sId then return end

    if SpawnedEntities[sId] and DoesEntityExist(SpawnedEntities[sId]) then
        if exports.thehunt_interact then
            pcall(function() exports.thehunt_interact:RemoveTargetEntity(SpawnedEntities[sId]) end)
        end
        DeleteEntity(SpawnedEntities[sId])
        SpawnedEntities[sId] = nil
    end

    ActiveSlots[sId] = nil
    LoadingModels[sId] = nil
    TriggerEvent("thehunt_inventory:refreshNearbyDrops")
end

function LootStreamer.UpdateSlotCount(slotId, newCount)
    local sId = tonumber(slotId)
    if not sId or not ActiveSlots[sId] then return end

    ActiveSlots[sId].count = tonumber(newCount) or 1
    TriggerEvent("thehunt_inventory:refreshNearbyDrops")
end

function LootStreamer.GetActiveSlots()
    return ActiveSlots
end

function LootStreamer.GetSpawnedEntities()
    return SpawnedEntities
end

-- =================================================================
-- 2. БЕЗОПАСНЫЙ СПАВН И УДАЛЕНИЕ ПРОП-МОДЕЛЕЙ
-- =================================================================

local function LoadModelSafely(modelHash)
    if not modelHash or modelHash == 0 then return false end
    if HasModelLoaded(modelHash) then return true end
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Citizen.Wait(40)
        timeout = timeout + 1
    end
    return HasModelLoaded(modelHash)
end

--- Точное определение поверхности (стол, кровать, полка, ящик, пол интерьера, земля) и защита от стен
local function GetAccurateSurfaceAndClearance(slot)
    local x, y, z = slot.x, slot.y, slot.z
    local zType = slot.zone_type or "circle"
    local myPed = PlayerPedId()

    -- 1. Для точечных зон (point / container) используем точную координату, куда прицелился админ
    if zType == "point" or zType == "container" or slot.is_exact_point then
        return vector3(x, y, z + 0.015)
    end

    local clearX, clearY = x, y
    local zCenterX = slot.zone_center_x or x
    local zCenterY = slot.zone_center_y or y
    local zCenterZ = slot.zone_center_z or z

    -- 2. Проверка проникновения сквозь стены (Interior Wall Penetration Guard)
    -- Если зона выходит за пределы комнаты/здания, луч от центра зоны к целевой точке обнаружит стену
    local centerDist = #(vector2(zCenterX, zCenterY) - vector2(clearX, clearY))
    if centerDist > 0.5 then
        local rayToTarget = StartShapeTestRay(zCenterX, zCenterY, z + 0.35, clearX, clearY, z + 0.35, 17, myPed, 7)
        local _, hitWall, wallCoords, wallNormal, _ = GetShapeTestResult(rayToTarget)
        if (hitWall == 1 or hitWall == true) and wallCoords and #(wallCoords - vector3(0, 0, 0)) > 2.0 then
            local wallDist = #(vector2(zCenterX, zCenterY) - vector2(wallCoords.x, wallCoords.y))
            if wallDist < centerDist - 0.15 then
                -- Точка оказалась ЗА СТЕНОЙ (снаружи комнаты / в пустоте)!
                -- Принудительно возвращаем точку внутрь комнаты с отступом 0.45м от внутренней стороны стены
                local nX = (wallNormal and wallNormal.x) or 0.0
                local nY = (wallNormal and wallNormal.y) or 0.0
                clearX = wallCoords.x + (nX * 0.45)
                clearY = wallCoords.y + (nY * 0.45)
            end
        end
    end

    -- 3. Горизонтальная проверка препятствий и стен в 4 направлениях (Anti-Wall Pushback)
    local offsets = {
        vector3(0.40, 0.0, 0.0),
        vector3(-0.40, 0.0, 0.0),
        vector3(0.0, 0.40, 0.0),
        vector3(0.0, -0.40, 0.0)
    }

    for _, off in ipairs(offsets) do
        local ray = StartShapeTestRay(clearX, clearY, z + 0.3, clearX + off.x, clearY + off.y, z + 0.3, 17, myPed, 7)
        local _, hit, hitCoords, normal, _ = GetShapeTestResult(ray)
        if (hit == 1 or hit == true) and normal and #(normal) > 0.1 then
            clearX = clearX + (normal.x * 0.30)
            clearY = clearY + (normal.y * 0.30)
        end
    end

    -- 4. Вертикальный луч сверху вниз (начиная с высоты 1.6м над полом)
    -- Это гарантирует попадание НА столы (0.8-1.0м), кровати (0.5-0.7м), ящики, полки и бочки, а не под них!
    local startPos = vector3(clearX, clearY, z + 1.6)
    local endPos   = vector3(clearX, clearY, z - 1.6)
    local shapeTest = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 287, myPed, 4)
    local retval, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(shapeTest)

    if (hit == 1 or hit == true) and #(hitCoords - vector3(0.0, 0.0, 0.0)) > 2.0 then
        return vector3(clearX, clearY, hitCoords.z + 0.025)
    end

    -- 5. Резервный поиск поверхности земли
    local foundGround, groundZ = GetGroundZFor_3dCoord(clearX, clearY, z + 0.5, false)
    if foundGround and math.abs(groundZ - z) < 3.0 then
        return vector3(clearX, clearY, groundZ + 0.025)
    end

    return vector3(clearX, clearY, z + 0.025)
end

function LootStreamer.SpawnSlotProp(slot)
    local sId = slot.id
    if SpawnedEntities[sId] and DoesEntityExist(SpawnedEntities[sId]) then return end
    if LoadingModels[sId] then return end
    if spawnCount >= (Config.MaxConcurrentSpawns or 8) then return end
    local model = slot.model_hash or joaat(slot.model_name or Config.DefaultLootPropModel)
    if failedModels[model] and GetGameTimer() < failedModels[model] then return end
    local ticket = {}
    LoadingModels[sId] = ticket
    spawnCount = spawnCount + 1

    Citizen.CreateThread(function()
        local hash = slot.model_hash or joaat(slot.model_name or Config.DefaultLootPropModel)
        if hash and LoadModelSafely(hash) then
            -- Если пока грузилась модель слот уже удалили
            if ActiveSlots[sId] ~= slot or LoadingModels[sId] ~= ticket then
                if LoadingModels[sId] == ticket then LoadingModels[sId] = nil end
                spawnCount = spawnCount - 1
                SetModelAsNoLongerNeeded(hash)
                return
            end

            -- Вычисляем точную координату на поверхности (на столе, кровати, полу)
            local targetPos = GetAccurateSurfaceAndClearance(slot)

            if ActiveSlots[sId] ~= slot or LoadingModels[sId] ~= ticket then
                if LoadingModels[sId] == ticket then LoadingModels[sId] = nil end
                spawnCount = spawnCount - 1
                SetModelAsNoLongerNeeded(hash)
                return
            end
            -- Surface correction must not move a prop far from its authoritative pickup position.
            if #(vector2(targetPos.x, targetPos.y) - vector2(slot.x, slot.y)) > 0.75 then
                targetPos = vector3(slot.x, slot.y, slot.z + 0.025)
            end
            local obj = CreateObject(hash, targetPos.x, targetPos.y, targetPos.z, false, false, false, false, false)
            if DoesEntityExist(obj) then
                SetEntityCoords(obj, targetPos.x, targetPos.y, targetPos.z, false, false, false, false)
                SetEntityRotation(obj, 0.0, 0.0, slot.heading or 0.0, 2, true)
                FreezeEntityPosition(obj, true)
                SetEntityCollision(obj, true, true)
                SetEntityCanBeDamaged(obj, false)
                SetEntityLodDist(obj, 100)

                SpawnedEntities[sId] = obj

                -- Интеграция с thehunt_interact при наличии
                if exports.thehunt_interact then
                    pcall(function()
                        local itemDef = nil
                        if Items and Items.Get then
                            itemDef = Items.Get(slot.item_name)
                        elseif exports.thehunt_items and exports.thehunt_items.GetItemData then
                            itemDef = exports.thehunt_items:GetItemData(slot.item_name)
                        end
                        local itemLabel = (type(slot.metadata) == "table" and slot.metadata.label) or (itemDef and itemDef.label) or slot.label or slot.item_name

                        exports.thehunt_interact:AddTargetEntity(obj, {
                            {
                                id = "pickup_loot",
                                label = string.format("Подобрать %s", itemLabel),
                                icon = "pickup",
                                event = "thehunt_loot:clientRequestPickup",
                                targetInfo = { slotId = sId }
                            }
                        }, Config.PickupDistance)
                    end)
                end
            end
            SetModelAsNoLongerNeeded(hash)
        else
            failedModels[model] = GetGameTimer() + 30000
        end
        if LoadingModels[sId] == ticket then LoadingModels[sId] = nil end
        spawnCount = spawnCount - 1
    end)
end

function LootStreamer.DespawnSlotProp(sId)
    if SpawnedEntities[sId] and DoesEntityExist(SpawnedEntities[sId]) then
        if exports.thehunt_interact then
            pcall(function() exports.thehunt_interact:RemoveTargetEntity(SpawnedEntities[sId]) end)
        end
        DeleteEntity(SpawnedEntities[sId])
        SpawnedEntities[sId] = nil
    end
    LoadingModels[sId] = nil
end

-- =================================================================
-- 3. ЦИКЛ ДИСТАНЦИОННОГО СТРИМИНГА ПРОПОВ
-- =================================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.ClientStreamInterval or STREAM_TICK_MS)

        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local pCoords = GetEntityCoords(ped)

            for sId, slot in pairs(ActiveSlots) do
                local slotPos = vector3(slot.x, slot.y, slot.z)
                local dist = #(pCoords - slotPos)
                local renderDist = tonumber(slot.render_radius) or Config.DefaultRenderRadius

                if dist <= renderDist then
                    if not SpawnedEntities[sId] then
                        LootStreamer.SpawnSlotProp(slot)
                    end
                else
                    if SpawnedEntities[sId] then
                        LootStreamer.DespawnSlotProp(sId)
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- 4. ЭКСПОРТ ДЛЯ ОКНА ИНВЕНТАРЯ "РЯДОМ" (VICINITY / NEARBY)
-- =================================================================

exports('GetNearbyLootSlots', function(maxDist)
    local pedCoords = GetEntityCoords(PlayerPedId())
    local nearby = {}
    local radius = maxDist or 1.5

    for sId, slot in pairs(ActiveSlots) do
        local posX, posY, posZ = slot.x, slot.y, slot.z
        local ent = SpawnedEntities[sId]
        if ent and DoesEntityExist(ent) then
            local ec = GetEntityCoords(ent)
            posX, posY, posZ = ec.x, ec.y, ec.z
        end

        local dist = #(pedCoords - vector3(posX, posY, posZ))
        if dist <= radius then
            local itemDef = nil
            if Items and Items.Get then
                itemDef = Items.Get(slot.item_name)
            elseif exports.thehunt_items and exports.thehunt_items.GetItemData then
                itemDef = exports.thehunt_items:GetItemData(slot.item_name)
            end

            table.insert(nearby, {
                dropId = "loot_" .. tostring(sId),
                lootSlotId = tonumber(sId),
                isWorldLoot = true,
                name = slot.item_name,
                label = slot.label or (itemDef and itemDef.label) or slot.item_name,
                count = tonumber(slot.count) or 1,
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
                uses = (slot.metadata and tonumber(slot.metadata.uses)) or (itemDef and itemDef.uses) or nil,
                maxUses = (slot.metadata and tonumber(slot.metadata.maxUses)) or (itemDef and itemDef.maxUses) or nil,
                metadata = slot.metadata or {}
            })
        end
    end
    return nearby
end)

-- =================================================================
-- 5. ОЧИСТКА ПРИ ОСТАНОВКЕ РЕСУРСА
-- =================================================================

function LootStreamer.CleanupAll()
    for sId, ent in pairs(SpawnedEntities) do
        if DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    SpawnedEntities = {}
    ActiveSlots = {}
    LoadingModels = {}
end

AddEventHandler("onResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end
    LootStreamer.CleanupAll()
end)
