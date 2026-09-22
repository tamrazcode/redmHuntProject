local FIRST_HUMAN <const> = "a_f_m_armcholeracorpse_01"
local LAST_HUMAN <const> = "u_m_y_shackstarvingkid_01"
local MARKER_TYPE <const> = 0x94FDAE17
local CLOSE_CONTROLS <const> = {
    0x156F7119,
    0x308588E6,
    0x4A903C11,
    0x3E89055A,
}

local wizard = {
    step = nil,
    center = nil,
    radius = 0,
    label = "Пользовательская зона",
}

local previewPed = nil
local previewGeneration = 0
local currentModel = nil
local catalogCache = nil
local managerOpen = false

local function nui(payload)
    SendNUIMessage(payload)
end

local function setFocus(hasFocus)
    SetNuiFocus(hasFocus, hasFocus)
end

local function hashText(name)
    return ("0x%08X"):format(joaat(name) & 0xFFFFFFFF)
end

local function recommendedList()
    local list = {}
    for i = 1, #(Config.Models or {}) do
        list[#list + 1] = {
            name = Config.Models[i],
            hash = hashText(Config.Models[i]),
            tag = "город",
        }
    end
    for i = 1, #(Config.ColterModels or {}) do
        list[#list + 1] = {
            name = Config.ColterModels[i],
            hash = hashText(Config.ColterModels[i]),
            tag = "зима",
        }
    end
    return list
end

local function humanCatalog()
    if catalogCache then
        return catalogCache
    end

    local list = {}
    local seen = {}
    local inside = false

    for i = 1, #(Peds or {}) do
        local model = Peds[i]
        if model == FIRST_HUMAN then
            inside = true
        end
        if inside and not seen[model] then
            seen[model] = true
            list[#list + 1] = {
                name = model,
                hash = hashText(model),
            }
        end
        if model == LAST_HUMAN then
            break
        end
    end

    if #list == 0 then
        list = recommendedList()
    end

    catalogCache = list
    return list
end

local function deletePreview()
    previewGeneration = previewGeneration + 1
    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
        DeletePed(previewPed)
        if DoesEntityExist(previewPed) then
            DeleteEntity(previewPed)
        end
    end
    previewPed = nil
    currentModel = nil
end

local function applyOutfit(ped, outfit)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfit or 0, true)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function playStandIdle(ped)
    local dict = "amb_misc@world_human_stand_impatient@male_a@idle_a"
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            return
        end
        Wait(0)
        RequestAnimDict(dict)
    end
    TaskPlayAnim(ped, dict, "idle_a", 2.0, 2.0, -1, 1, 0.0, false, false, false, "", false)
end

-- Хеш шоб мозги не ебал. Ничё тут не трогать
local function spawnPreview(name)
    if not name or name == currentModel then
        return
    end

    deletePreview()
    previewGeneration = previewGeneration + 1
    local generation = previewGeneration
    local hash = joaat(name)

    CreateThread(function()
        RequestModel(hash, false)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) do
            if generation ~= previewGeneration or GetGameTimer() >= timeout then
                return
            end
            Wait(0)
            RequestModel(hash, false)
        end

        if generation ~= previewGeneration then
            return
        end

        local playerPed = PlayerPedId()
        local heading = wizard.previewHeading or (GetEntityHeading(playerPed) + 180.0)
        local pos = wizard.previewPos
        if not pos then
            pos = GetOffsetFromEntityInWorldCoords(playerPed, 0.75, 3.4, 0.0)
        end

        local ped = CreatePed(hash, pos.x, pos.y, pos.z, heading, false, false, false, false)
        if generation ~= previewGeneration or not ped or ped == 0 or not DoesEntityExist(ped) then
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                DeletePed(ped)
            end
            SetModelAsNoLongerNeeded(hash)
            return
        end

        previewPed = ped
        currentModel = name

        SetEntityAsMissionEntity(ped, true, true)
        SetEntityInvincible(ped, true)
        SetEntityCollision(ped, false, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanBeTargetted(ped, false)
        pcall(SetPedCanRagdoll, ped, false)
        pcall(SetEntityHasGravity, ped, false)
        pcall(Citizen.InvokeNative, 0x25ACFC650B65C538, ped, 1.0)
        FreezeEntityPosition(ped, true)
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(ped, heading)
        applyOutfit(ped, 0)
        playStandIdle(ped)
        SetEntityHeading(ped, heading)
        FreezeEntityPosition(ped, true)
        SetModelAsNoLongerNeeded(hash)
    end)
end

local function drawPrettyZone(coords, radius, gold)
    local r, g, b = 215, 181, 106
    if not gold then
        r, g, b = 134, 168, 93
    end
    local diameter = radius * 2.0
    DrawMarker(MARKER_TYPE, coords.x, coords.y, coords.z + 0.08, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, diameter, diameter, 0.35, r, g, b, 90, false, false, 2, nil, nil, false, false)
    DrawMarker(MARKER_TYPE, coords.x, coords.y, coords.z + 0.08, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.8, r, g, b, 160, false, false, 2, nil, nil, false, false)

    local points = 42
    for i = 0, points - 1 do
        local a1 = (i / points) * math.pi * 2.0
        local a2 = ((i + 1) / points) * math.pi * 2.0
        local x1 = coords.x + math.cos(a1) * radius
        local y1 = coords.y + math.sin(a1) * radius
        local x2 = coords.x + math.cos(a2) * radius
        local y2 = coords.y + math.sin(a2) * radius
        pcall(DrawLine, x1, y1, coords.z + 0.2, x2, y2, coords.z + 0.2, r, g, b, 200)
        pcall(DrawLine, x1, y1, coords.z + 0.2, x1, y1, coords.z + 1.15, r, g, b, 70)
    end
end

local LOOK_LR <const> = 0xA987235F
local LOOK_UD <const> = 0xD2047988
local MOVE_LR <const> = 0x4D8FB4C1
local MOVE_UD <const> = 0xFDA83190
local ATTACK <const> = 0x07CE1E61
local AIM <const> = 0xF84FA6B5
local PREV_WEAPON <const> = 0x3076E97C
local NEXT_WEAPON <const> = 0xD08D0C15

local function groundAt(x, y, fromZ)
    RequestCollisionAtCoord(x, y, fromZ)
    local ok, found, ground = pcall(GetGroundZFor_3dCoord, x, y, fromZ, false)
    if ok and found and ground then
        return ground
    end
    return fromZ - 40.0
end

local function cursorWorld()
    local x = wizard.camX or 0.0
    local y = wizard.camY or 0.0
    local z = groundAt(x, y, (wizard.camZ or 80.0) + 20.0)
    return vector3(x, y, z)
end

local function dropCam(handle)
    if handle and DoesCamExist(handle) then
        SetCamActive(handle, false)
        DestroyCam(handle, false)
    end
end

local function stopAllCams()
    if wizard.cam or wizard.previewCam then
        RenderScriptCams(false, false, 0, true, true, 0)
    end
    dropCam(wizard.cam)
    dropCam(wizard.previewCam)
    wizard.cam = nil
    wizard.previewCam = nil
    DisplayRadar(true)
end

local function createEditorCam()
    dropCam(wizard.cam)
    wizard.cam = nil
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    wizard.camX, wizard.camY = coords.x, coords.y
    wizard.camZ = coords.z + 52.0
    wizard.startedAt = GetGameTimer()

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, wizard.camX, wizard.camY, wizard.camZ)
    SetCamRot(cam, -89.5, 0.0, 0.0, 2)
    SetCamFov(cam, 50.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true, 0)
    DisplayRadar(false)
    wizard.cam = cam
end

local function updateEditorCam()
    if wizard.step == "picker" or not wizard.cam or not DoesCamExist(wizard.cam) then
        return
    end

    DisableAllControlActions(0)
    EnableControlAction(0, LOOK_LR, true)
    EnableControlAction(0, LOOK_UD, true)

    local lookX = GetDisabledControlNormal(0, LOOK_LR)
    local lookY = GetDisabledControlNormal(0, LOOK_UD)
    local moveX = GetDisabledControlNormal(0, MOVE_LR)
    local moveY = GetDisabledControlNormal(0, MOVE_UD)
    local speed = (wizard.camZ or 50.0) * 0.045

    wizard.camX = wizard.camX + ((lookX * 1.35) + moveX) * speed
    wizard.camY = wizard.camY - ((lookY * 1.35) + moveY) * speed

    if IsDisabledControlPressed(0, PREV_WEAPON) then
        wizard.camZ = math.min(180.0, wizard.camZ + 1.6)
    elseif IsDisabledControlPressed(0, NEXT_WEAPON) then
        wizard.camZ = math.max(18.0, wizard.camZ - 1.6)
    end

    local ground = groundAt(wizard.camX, wizard.camY, wizard.camZ)
    if wizard.camZ < ground + 16.0 then
        wizard.camZ = ground + 16.0
    end

    SetCamCoord(wizard.cam, wizard.camX, wizard.camY, wizard.camZ)
    SetCamRot(wizard.cam, -89.5, 0.0, 0.0, 2)
end

local function restorePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    ResetEntityAlpha(ped)
    SetLocalPlayerInvisibleLocally(false)
    pcall(SetPlayerInvisibleLocally, PlayerId(), false)

    local coords = GetEntityCoords(ped)
    local ground = groundAt(coords.x, coords.y, coords.z + 40.0)
    if ground and coords.z < ground - 2.0 then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, ground + 0.1, false, false, false)
    end
end

local function keepPreviewCam()
    if wizard.previewCam and DoesCamExist(wizard.previewCam) then
        SetCamActive(wizard.previewCam, true)
        RenderScriptCams(true, false, 0, true, true, 0)
    end
end

local function createPreviewScene()
    local player = PlayerPedId()
    FreezeEntityPosition(player, true)
    SetEntityCollision(player, true, true)

    local heading = GetEntityHeading(player)
    local pedPos = GetOffsetFromEntityInWorldCoords(player, 0.75, 3.4, 0.0)
    local ground = groundAt(pedPos.x, pedPos.y, pedPos.z + 3.0)
    if math.abs(ground - pedPos.z) > 6.0 then
        ground = pedPos.z
    end

    wizard.previewPos = vector3(pedPos.x, pedPos.y, ground + 1.05)
    wizard.previewHeading = heading + 180.0

    local camPos = GetOffsetFromEntityInWorldCoords(player, 0.75, 0.55, 0.0)
    dropCam(wizard.previewCam)
    dropCam(wizard.cam)
    wizard.cam = nil

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camPos.x, camPos.y, wizard.previewPos.z + 0.55)
    PointCamAtCoord(cam, wizard.previewPos.x, wizard.previewPos.y, wizard.previewPos.z + 0.35)
    SetCamFov(cam, 48.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true, 0)
    DisplayRadar(false)
    wizard.previewCam = cam
    SetEntityVisible(player, false, false)
end

local function closeManager()
    if not managerOpen then
        return
    end
    managerOpen = false
    nui({ action = "hideManager" })
    if not wizard.step then
        setFocus(false)
    end
end

local function closeWizard()
    wizard.step = nil
    wizard.center = nil
    wizard.radius = 0
    wizard.previewPos = nil
    deletePreview()
    stopAllCams()
    restorePlayer()
    if not managerOpen then
        setFocus(false)
        nui({ action = "hide" })
    end
end

local function pickerPayload()
    local names = {}
    for i = 1, #(Config.Models or {}) do
        names[#names + 1] = Config.Models[i]
    end
    return {
        action = "picker",
        label = wizard.label,
        radius = wizard.radius,
        count = math.max(8, math.floor((wizard.radius or 0) / 3.0)),
        recommended = recommendedList(),
        catalog = {},
        selected = names,
    }
end

local function openPicker()
    wizard.step = "picker"

    dropCam(wizard.cam)
    wizard.cam = nil
    RenderScriptCams(false, false, 0, true, true, 0)

    nui(pickerPayload())
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    CreateThread(function()
        Wait(200)
        if wizard.step ~= "picker" then
            return
        end
        createPreviewScene()
        nui(pickerPayload())
        keepPreviewCam()
        local first = Config.Models and Config.Models[1]
        if first then
            spawnPreview(first)
        end
    end)
end

local function beginWizard()
    closeManager()
    wizard.step = "center"
    wizard.center = nil
    wizard.radius = 0
    wizard.label = "Пользовательская зона"
    deletePreview()
    FreezeEntityPosition(PlayerPedId(), true)
    setFocus(false)
    createEditorCam()
    nui({
        action = "hud",
        step = 1,
        title = "Центр",
        lead = "ЛКМ — точка",
    })
end

local function handleMapClick()
    if GetGameTimer() - (wizard.startedAt or 0) < 400 then
        return
    end

    local cursor = cursorWorld()

    if wizard.step == "center" then
        wizard.center = cursor
        wizard.step = "stretch"
        nui({
            action = "hud",
            step = 2,
            title = "Размер",
            lead = "ЛКМ — готово",
            radius = 0,
        })
        return
    end

    if wizard.step == "stretch" then
        wizard.radius = #(cursor - wizard.center)
        if wizard.radius < 10.0 then
            nui({
                action = "hud",
                step = 2,
                title = "Шире",
                lead = "минимум 10 м",
                radius = wizard.radius,
            })
            return
        end
        openPicker()
    end
end

local function editorStep()
    if wizard.step == "picker" then
        return
    end
    if wizard.step == "center" or wizard.step == "stretch" then
        return
    end
    beginWizard()
end

RegisterCommand("zarea", function(_, args)
    if not IsZombieAdmin() then
        TriggerServerEvent("hh_zombies:requestAdmin")
        return
    end
    local action = args[1] and string.lower(args[1]) or ""
    if action == "reset" or action == "clear" or action == "cancel" then
        closeWizard()
        TriggerEvent("chat:addMessage", { args = { "hh_zombies", "Разметка зоны отменена." } })
        return
    end
    if action ~= "" and action ~= "winter" and action ~= "colter" then
        wizard.label = table.concat(args, " ")
    end
    editorStep()
end, false)

RegisterKeyMapping("zarea", "Разметить зомби-зону", "keyboard", (Config.ZoneEditor and Config.ZoneEditor.hotkey) or "F11")

RegisterCommand("zzones", function()
    if not IsZombieAdmin() then
        TriggerServerEvent("hh_zombies:requestAdmin")
        return
    end
    if managerOpen then
        closeManager()
        return
    end
    if wizard.step then
        closeWizard()
    end
    TriggerServerEvent("hh_zombies:requestZoneManager")
end, false)

RegisterKeyMapping("zzones", "Список зомби-зон", "keyboard", (Config.ZoneEditor and Config.ZoneEditor.listHotkey) or "F12")

RegisterNetEvent("hh_zombies:zoneManager", function(zones)
    if not IsZombieAdmin() then
        return
    end
    if not managerOpen then
        if wizard.step then
            closeWizard()
        end
        managerOpen = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
    nui({
        action = "manager",
        zones = zones or {},
    })
end)

RegisterNetEvent("hh_zombies:zoneEditorResult", function(ok)
    if managerOpen and ok then
        TriggerServerEvent("hh_zombies:requestZoneManager")
    end
end)

RegisterNUICallback("zoneEditorReady", function(_, cb)
    cb("ok")
end)

RegisterNUICallback("zoneEditorPreview", function(data, cb)
    cb("ok")
    if not IsZombieAdmin() then
        return
    end
    spawnPreview(data and data.name)
end)

RegisterNUICallback("zoneEditorSearch", function(data, cb)
    cb("ok")
    if not IsZombieAdmin() then
        return
    end
    local query = tostring(data and data.query or ""):lower()
    local matches = {}
    if query ~= "" and #query >= 2 then
        local source = humanCatalog()
        for i = 1, #source do
            local entry = source[i]
            if entry.name:lower():find(query, 1, true) then
                matches[#matches + 1] = entry
                if #matches >= 80 then
                    break
                end
            end
        end
    end
    nui({ action = "catalog", catalog = matches })
end)

RegisterNUICallback("zoneEditorCancel", function(_, cb)
    closeWizard()
    cb("ok")
end)

RegisterNUICallback("zoneEditorSave", function(data, cb)
    cb("ok")
    if not IsZombieAdmin() then
        closeWizard()
        return
    end
    if not wizard.center or wizard.radius < 10.0 then
        closeWizard()
        return
    end

    local models = {}
    for i = 1, #(data and data.models or {}) do
        local name = data.models[i]
        if type(name) == "string" and name ~= "" then
            models[#models + 1] = name
        end
    end

    TriggerServerEvent("hh_zombies:saveZone", {
        x = wizard.center.x,
        y = wizard.center.y,
        z = wizard.center.z,
        radius = wizard.radius,
        label = (data and data.label ~= "" and data.label) or wizard.label,
        count = tonumber(data and data.count),
        models = models,
        modelsKey = "custom",
    })
    closeWizard()
end)

RegisterNUICallback("zoneManagerClose", function(_, cb)
    closeManager()
    cb("ok")
end)

RegisterNUICallback("zoneManagerDelete", function(data, cb)
    cb("ok")
    if not IsZombieAdmin() then
        closeManager()
        return
    end
    local zoneId = data and data.id
    if type(zoneId) ~= "string" or zoneId == "" then
        return
    end
    TriggerServerEvent("hh_zombies:deleteZone", zoneId)
end)

CreateThread(function()
    while true do
        if wizard.step == "center" or wizard.step == "stretch" then
            Wait(0)
            updateEditorCam()

            local cursor = cursorWorld()
            drawPrettyZone(cursor, 1.4, true)

            if wizard.step == "stretch" and wizard.center then
                local radius = #(cursor - wizard.center)
                wizard.radius = radius
                drawPrettyZone(wizard.center, math.max(2.0, radius), true)
                if GetFrameCount() % 6 == 0 then
                    nui({ action = "radius", radius = radius })
                end
            end

            if IsDisabledControlJustPressed(0, ATTACK) then
                handleMapClick()
            elseif IsDisabledControlJustPressed(0, AIM) then
                if wizard.center then
                    wizard.center = nil
                    wizard.radius = 0
                    wizard.step = "center"
                    nui({
                        action = "hud",
                        step = 1,
                        title = "Центр",
                        lead = "ЛКМ — точка",
                    })
                else
                    closeWizard()
                end
            end

            for i = 1, #CLOSE_CONTROLS do
                DisableControlAction(0, CLOSE_CONTROLS[i], true)
                if IsDisabledControlJustPressed(0, CLOSE_CONTROLS[i]) then
                    closeWizard()
                end
            end
        elseif wizard.step == "picker" then
            Wait(0)
            keepPreviewCam()
            if previewPed and DoesEntityExist(previewPed) then
                FreezeEntityPosition(previewPed, true)
                local pos = wizard.previewPos
                if pos then
                    local coords = GetEntityCoords(previewPed)
                    if coords.z < pos.z - 0.2 then
                        SetEntityCoordsNoOffset(previewPed, pos.x, pos.y, pos.z, false, false, false)
                    end
                end
            end
        else
            Wait(200)
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        deletePreview()
        stopAllCams()
        SetNuiFocus(false, false)
        restorePlayer()
    end
end)

CreateThread(function()
    Wait(300)
    restorePlayer()
end)
