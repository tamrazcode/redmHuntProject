-- =================================================================
-- HUNT: Hard RP — The Corruption | Admin Loot Editor Client Controller
-- =================================================================

Editor = {}

local isEditorOpen = false
local isInputFocused = false
local cachedZones = {}
local cachedCatalog = {}

function Editor.IsActive()
    return isEditorOpen
end

function Editor.IsInputFocused()
    return isInputFocused
end

function Editor.GetAllZones()
    return cachedZones
end

function Editor.GetActiveZone()
    return EditorZones.GetActiveZone()
end

function Editor.GetSelectedVertexIndex()
    return EditorZones.GetSelectedVertexIndex()
end

-- =================================================================
-- 1. ОТКРЫТИЕ И ЗАКРЫТИЕ РЕДАКТОРА
-- =================================================================

local function ToggleLootEditor()
    if isEditorOpen then
        Editor.Stop()
    else
        TriggerServerEvent("thehunt_loot:checkPermissionAndOpenEditor")
    end
end

RegisterCommand("looteditor", ToggleLootEditor, false)
RegisterCommand("lootzone", ToggleLootEditor, false)
RegisterCommand("lootzones", ToggleLootEditor, false)

local function NormalizeZones(zones)
    local normalized = {}
    if zones and type(zones) == "table" then
        for k, z in pairs(zones) do
            if z and z.id then
                local zId = tonumber(z.id)
                if zId then
                    normalized[zId] = z
                end
            end
        end
    end
    return normalized
end

local function RemoveZoneFromCache(zoneId)
    local zId = tonumber(zoneId)
    if not zId then return end
    cachedZones[zId] = nil
    cachedZones[tostring(zId)] = nil

    for k, v in pairs(cachedZones) do
        if v and tonumber(v.id) == zId then
            cachedZones[k] = nil
        end
    end

    local curActive = EditorZones.GetActiveZone()
    if curActive and (tonumber(curActive.id) == zId or curActive.id == nil or tonumber(curActive.id) == 0) then
        EditorZones.SetActiveZone(nil)
    end
end

RegisterNetEvent("thehunt_loot:openEditorClient", function(zonesList, catalog)
    cachedZones = NormalizeZones(zonesList)
    cachedCatalog = catalog or {}

    if isEditorOpen then return end
    local _, firstZone = next(cachedZones)
    EditorZones.SetActiveZone(firstZone)
    isEditorOpen = true
    isInputFocused = false

    -- Запуск свободной камеры и рендера фигур
    local ped = PlayerPedId()
    EditorCam.Start(GetEntityCoords(ped) + vector3(0, 0, 2.5))
    EditorShapes.StartRenderer()

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    SendNUIMessage({
        type = 'OPEN_EDITOR',
        zones = cachedZones,
        activeZone = EditorZones.GetActiveZone(),
        catalog = cachedCatalog,
        zoneTypes = Config.ZoneTypes,
        defaultConfig = Config
    })
end)

function Editor.Stop()
    if not isEditorOpen then return end
    isEditorOpen = false
    isInputFocused = false

    EditorCam.Stop()
    EditorShapes.StopRenderer()
    EditorZones.SetActiveZone(nil)
    EditorZones.ClearTestPreview()

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({ type = 'CLOSE_EDITOR' })
end

-- =================================================================
-- 2. СИНХРОНИЗАЦИЯ ЗОН В РЕДАКТОРЕ
-- =================================================================

RegisterNetEvent("thehunt_loot:onZoneSaved", function(savedZone)
    if not savedZone or not savedZone.id then return end
    local zId = tonumber(savedZone.id)
    if zId then
        cachedZones[zId] = savedZone
    end
    if not isEditorOpen then return end
    EditorZones.SetActiveZone(savedZone)
    SendNUIMessage({ type = 'ZONE_SAVED', zone = savedZone })

    SendNUIMessage({
        type = 'UPDATE_ZONES_LIST',
        zones = cachedZones,
        activeZone = savedZone
    })
end)

RegisterNetEvent("thehunt_loot:syncZoneUpdated", function(updatedZone)
    if not updatedZone or not updatedZone.id then return end
    local zId = tonumber(updatedZone.id)
    if zId then
        cachedZones[zId] = updatedZone
    end

    local curActive = EditorZones.GetActiveZone()
    -- Keep the local working copy: another administrator's save must not
    -- silently overwrite edits currently being typed here.

    SendNUIMessage({
        type = 'UPDATE_ZONES_LIST',
        zones = cachedZones,
        preserveDraft = true,
        activeZone = EditorZones.GetActiveZone()
    })
end)

RegisterNetEvent("thehunt_loot:onZoneDeletedClient", function(zoneId)
    RemoveZoneFromCache(zoneId)

    SendNUIMessage({
        type = 'UPDATE_ZONES_LIST',
        zones = cachedZones,
        activeZone = EditorZones.GetActiveZone()
    })
end)

RegisterNetEvent("thehunt_loot:syncZoneDeleted", function(zoneId)
    RemoveZoneFromCache(zoneId)

    SendNUIMessage({
        type = 'UPDATE_ZONES_LIST',
        zones = cachedZones,
        activeZone = EditorZones.GetActiveZone()
    })
end)

RegisterNetEvent("thehunt_loot:receiveTestPreviewLoot", function(testSlots)
    EditorZones.SpawnTestPreview(testSlots)
end)

-- =================================================================
-- 3. NUI CALLBACKS
-- =================================================================

RegisterNUICallback('closeEditor', function(data, cb)
    Editor.Stop()
    cb('ok')
end)

RegisterNUICallback('setInputFocus', function(data, cb)
    isInputFocused = (data and data.focused == true)
    cb('ok')
end)

RegisterNUICallback('selectZone', function(data, cb)
    local zId = tonumber(data and data.zoneId)
    local zone = (zId and cachedZones[zId]) or (zId and cachedZones[tostring(zId)])
    if zone then
        EditorZones.SetActiveZone(zone)
        EditorCam.Teleport(zone.coords)
        SendNUIMessage({
            type = 'SET_ACTIVE_ZONE',
            activeZone = zone
        })
    end
    cb('ok')
end)

RegisterNUICallback('createNewZone', function(data, cb)
    local zType = data and data.zoneType or "circle"
    local ray = EditorCam.RaycastFromCamera(80.0)
    local spawnCoords = (ray and ray.hit) and ray.coords or (EditorCam.GetCoords() + vector3(0, 5.0, 0))

    local newZone = EditorZones.CreateNewZone(zType, spawnCoords)
    SendNUIMessage({
        type = 'SET_ACTIVE_ZONE',
        activeZone = newZone
    })
    cb(newZone)
end)

RegisterNUICallback('updateActiveZoneField', function(data, cb)
    local active = EditorZones.GetActiveZone()
    if active and data and data.field then
        active[data.field] = data.value
    end
    cb('ok')
end)

RegisterNUICallback('saveActiveZone', function(data, cb)
    local zoneToSave = data and data.zoneData or EditorZones.GetActiveZone()
    if zoneToSave then
        TriggerServerEvent("thehunt_loot:saveZone", zoneToSave)
    end
    cb('ok')
end)

RegisterNUICallback('deleteZone', function(data, cb)
    local zId = tonumber(data and data.zoneId) or 0
    if zId <= 0 then
        -- Черновая несохраненная зона
        EditorZones.SetActiveZone(nil)
        SendNUIMessage({
            type = 'SET_ACTIVE_ZONE',
            activeZone = nil
        })
    else
        TriggerServerEvent("thehunt_loot:deleteZone", zId)
    end
    cb('ok')
end)

RegisterNUICallback('duplicateZone', function(data, cb)
    local zId = tonumber(data and data.zoneId)
    if zId then
        TriggerServerEvent("thehunt_loot:duplicateZone", zId)
    end
    cb('ok')
end)

RegisterNUICallback('toggleZone', function(data, cb)
    local zId = tonumber(data and data.zoneId)
    local enabled = data and (data.enabled == true)
    if zId then
        TriggerServerEvent("thehunt_loot:toggleZone", zId, enabled)
    end
    cb('ok')
end)

RegisterNUICallback('forceRespawn', function(data, cb)
    local zId = tonumber(data and data.zoneId)
    if zId then
        TriggerServerEvent("thehunt_loot:forceRespawn", zId)
    end
    cb('ok')
end)

RegisterNUICallback('testGenerateLoot', function(data, cb)
    local active = data and data.zoneData or EditorZones.GetActiveZone()
    if active then
        TriggerServerEvent("thehunt_loot:testGenerateLoot", active)
    end
    cb('ok')
end)

RegisterNUICallback('teleportToZone', function(data, cb)
    local zId = tonumber(data and data.zoneId)
    local zone = (zId and cachedZones[zId]) or (zId and cachedZones[tostring(zId)])
    if zone and zone.coords then
        EditorCam.Teleport(zone.coords)
    end
    cb('ok')
end)

RegisterNUICallback('moveZoneCenterToRaycast', function(data, cb)
    local moved = EditorZones.MoveZoneCenterToRaycast()
    if moved then
        SendNUIMessage({
            type = 'SET_ACTIVE_ZONE',
            activeZone = EditorZones.GetActiveZone()
        })
    end
    cb('ok')
end)

RegisterNUICallback('addPolygonVertex', function(data, cb)
    local added = EditorZones.AddPolygonVertexAtRaycast()
    if added then
        SendNUIMessage({
            type = 'SET_ACTIVE_ZONE',
            activeZone = EditorZones.GetActiveZone()
        })
    end
    cb('ok')
end)

RegisterNUICallback('removeSelectedVertex', function(data, cb)
    local removed = EditorZones.RemoveSelectedVertex()
    if removed then
        SendNUIMessage({
            type = 'SET_ACTIVE_ZONE',
            activeZone = EditorZones.GetActiveZone()
        })
    end
    cb('ok')
end)

RegisterNUICallback('adjustZoneZ', function(data, cb)
    local delta = tonumber(data and data.delta) or 0.5
    local adjusted = EditorZones.AdjustZoneCenterZ(delta)
    if adjusted then
        SendNUIMessage({
            type = 'SET_ACTIVE_ZONE',
            activeZone = EditorZones.GetActiveZone()
        })
    end
    cb('ok')
end)

-- =================================================================
-- 4. ГОРЯЧИЕ КЛАВИШИ В РЕЖИМЕ РЕДАКТОРА
-- =================================================================

Citizen.CreateThread(function()
    while true do
        if isEditorOpen and not isInputFocused then
            -- Клавиша E: Выбрать зону под прицелом
            if IsDisabledControlJustPressed(0, 0xCEFD9220) or IsControlJustPressed(0, 0xCEFD9220) then -- E
                local ray = EditorCam.RaycastFromCamera(100.0)
                if ray and ray.hit then
                    local targetPt = ray.coords
                    local foundZone = nil
                    local bestDist = 999.0

                    for _, zone in pairs(cachedZones) do
                        if zone and zone.coords then
                            local zType = zone.zone_type or "circle"
                            local inZone = false
                            if zType == "circle" then
                                inZone = LootMath.IsPointInCircle(targetPt, zone.coords, tonumber(zone.radius) or 10.0)
                            elseif zType == "rectangle" then
                                inZone = LootMath.IsPointInBox(targetPt, zone.coords, tonumber(zone.size_x) or 10.0, tonumber(zone.size_y) or 10.0, tonumber(zone.size_z) or 4.0, tonumber(zone.heading) or 0.0)
                            elseif zType == "polygon" and zone.points and #zone.points >= 3 then
                                inZone = LootMath.IsPointInPolygon(targetPt, zone.points)
                            end

                            local d = #(targetPt - zone.coords)
                            if (inZone or d < 8.0) and d < bestDist then
                                bestDist = d
                                foundZone = zone
                            end
                        end
                    end

                    if foundZone then
                        EditorZones.SetActiveZone(foundZone)
                        SendNUIMessage({
                            type = 'SET_ACTIVE_ZONE',
                            activeZone = foundZone
                        })
                        TriggerEvent("thehunt_status:notify", "Редактор", string.format("Выбрана зона «%s» [#%s]", foundZone.name, tostring(foundZone.id or 0)), "info")
                    end
                end
            end

            -- Клавиша G: переместить центр зоны к прицелу
            if IsDisabledControlJustPressed(0, 0x760A9C6F) or IsControlJustPressed(0, 0x760A9C6F) then -- G
                EditorZones.MoveZoneCenterToRaycast()
                SendNUIMessage({
                    type = 'SET_ACTIVE_ZONE',
                    activeZone = EditorZones.GetActiveZone()
                })
            end

            -- Клавиша PageUp / Стрелка вверх: поднять центр зоны по Z (+0.5м)
            if IsDisabledControlJustPressed(0, 0x446258B6) or IsControlJustPressed(0, 0x446258B6) or IsDisabledControlJustPressed(0, 0x6319DB71) or IsControlJustPressed(0, 0x6319DB71) then
                if EditorZones.AdjustZoneCenterZ(0.5) then
                    SendNUIMessage({
                        type = 'SET_ACTIVE_ZONE',
                        activeZone = EditorZones.GetActiveZone()
                    })
                end
            end

            -- Клавиша PageDown / Стрелка вниз: опустить центр зоны по Z (-0.5м)
            if IsDisabledControlJustPressed(0, 0x3C3DD37A) or IsControlJustPressed(0, 0x3C3DD37A) or IsDisabledControlJustPressed(0, 0x05CA7C52) or IsControlJustPressed(0, 0x05CA7C52) then
                if EditorZones.AdjustZoneCenterZ(-0.5) then
                    SendNUIMessage({
                        type = 'SET_ACTIVE_ZONE',
                        activeZone = EditorZones.GetActiveZone()
                    })
                end
            end

            -- Клавиша V: добавить вершину полигона к прицелу
            if IsDisabledControlJustPressed(0, 0x7F8D09B8) or IsControlJustPressed(0, 0x7F8D09B8) then -- V
                local active = EditorZones.GetActiveZone()
                if active and active.zone_type == "polygon" then
                    EditorZones.AddPolygonVertexAtRaycast()
                    SendNUIMessage({
                        type = 'SET_ACTIVE_ZONE',
                        activeZone = EditorZones.GetActiveZone()
                    })
                end
            end

            -- Клавиша X / Del: удалить выбранную вершину
            if IsDisabledControlJustPressed(0, 0x8CC9CD42) or IsControlJustPressed(0, 0x8CC9CD42) then -- X
                local active = EditorZones.GetActiveZone()
                if active and active.zone_type == "polygon" then
                    EditorZones.RemoveSelectedVertex()
                    SendNUIMessage({
                        type = 'SET_ACTIVE_ZONE',
                        activeZone = EditorZones.GetActiveZone()
                    })
                end
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(200)
        end
    end
end)

RegisterNetEvent('thehunt_loot:saveFailed', function()
    SendNUIMessage({type = 'SAVE_FAILED'})
end)

RegisterNUICallback('clearTestPreview', function(_, cb)
    EditorZones.ClearTestPreview()
    cb('ok')
end)

-- Free camera reads disabled controls. No gameplay action may leak through NUI.
Citizen.CreateThread(function()
    while true do
        if isEditorOpen then
            Citizen.Wait(0)
            for pad = 0, 2 do
                DisableAllControlActions(pad)
                if not isInputFocused then
                    EnableControlAction(pad, 0xF1301666, true)
                    EnableControlAction(pad, 0x05CA7C52, true)
                end
            end
            DisablePlayerFiring(PlayerId(), true)
        else Citizen.Wait(150) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Editor.Stop() end
end)

RegisterNetEvent('thehunt_loot:zoneStatus', function(states)
    if isEditorOpen then SendNUIMessage({type = 'ZONE_STATUS', states = states}) end
end)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)
        if isEditorOpen then TriggerServerEvent('thehunt_loot:requestZoneStatus') end
    end
end)
