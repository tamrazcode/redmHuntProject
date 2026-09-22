local isNuiOpen = false
local previewPed = nil
local previewDeleteAt = 0
local previewModel = nil

local function Notify(message, notifyType)
    if not message or message == "" then
        return
    end

    local color = { 220, 80, 80 }
    if notifyType == "success" then
        color = { 143, 196, 110 }
    end

    TriggerEvent("chat:addMessage", {
        color = color,
        multiline = true,
        args = { "Ped Menu", message },
    })
end

local function LoadModel(modelName)
    local model = type(modelName) == "number" and modelName or GetHashKey(modelName)
    if not IsModelValid(model) then
        return nil
    end

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 200 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        return nil
    end

    return model
end

local function GetSpawnCoordsInFrontOfPlayer(distance)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local rad = math.rad(heading)
    local x = coords.x - math.sin(rad) * distance
    local y = coords.y + math.cos(rad) * distance
    local z = coords.z
    local found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 1.0)
    if found then
        z = groundZ
    end
    return x, y, z, heading + 180.0
end

local function ApplyOutfit(ped, outfitIndex)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return
    end
    outfitIndex = tonumber(outfitIndex) or 0
    if outfitIndex < 0 then
        outfitIndex = 0
    end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfitIndex, 0)
end

local function DeletePreviewPed()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
    previewModel = nil
    previewDeleteAt = 0
end

local function SchedulePreviewCleanup()
    previewDeleteAt = GetGameTimer() + (Config.PreviewDuration or 15000)
end

local function SpawnPreviewPed(modelName, outfitIndex)
    DeletePreviewPed()

    local model = LoadModel(modelName)
    if not model then
        return false
    end

    local distance = Config.PreviewDistance or 2.5
    local x, y, z, heading = GetSpawnCoordsInFrontOfPlayer(distance)
    local ped = CreatePed(model, x, y, z, heading, false, false, false, false)

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return false
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    ApplyOutfit(ped, outfitIndex)

    previewPed = ped
    previewModel = modelName
    SetModelAsNoLongerNeeded(model)
    SchedulePreviewCleanup()
    return true
end

local function ApplyPedToPlayer(modelName, outfitIndex)
    local model = LoadModel(modelName)
    if not model then
        return false
    end

    local player = PlayerId()
    Citizen.InvokeNative(0xED40380076A31506, player, model, false)
    Wait(100)

    local ped = PlayerPedId()
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    ApplyOutfit(ped, outfitIndex)

    SetModelAsNoLongerNeeded(model)
    return true
end

local function RunRestoreCommand()
    DeletePreviewPed()

    local restoreCommand = Config.Commands and Config.Commands.restore or ""
    restoreCommand = string.gsub(restoreCommand, "^/", "")

    if restoreCommand == "" then
        return
    end

    ExecuteCommand(restoreCommand)
end

local function GetPedCategory(model)
    local lower = string.lower(model)

    if lower == "mp_male" or lower == "mp_female" then
        return "player"
    end

    if string.sub(lower, 1, 4) == "a_c_" then
        return "animal"
    end

    if string.sub(lower, 1, 4) == "a_m_" then
        return "ambient_male"
    end

    if string.sub(lower, 1, 4) == "a_f_" then
        return "ambient_female"
    end

    if string.sub(lower, 1, 4) == "u_m_" or string.sub(lower, 1, 4) == "u_f_" then
        return "unique"
    end

    if string.sub(lower, 1, 4) == "g_m_" or string.sub(lower, 1, 4) == "g_f_" then
        return "gang"
    end

    if string.sub(lower, 1, 3) == "cs_" then
        return "cutscene"
    end

    if string.sub(lower, 1, 4) == "s_m_" or string.sub(lower, 1, 4) == "s_f_" then
        return "special"
    end

    if string.sub(lower, 1, 3) == "mp_" then
        return "mp"
    end

    return "other"
end

local function BuildMenuPayload()
    local peds = {}
    local lang = Config.Lang or {}

    for _, entry in ipairs(PedsList) do
        peds[#peds + 1] = {
            model = entry[2],
            outfits = entry[3] or 1,
            category = GetPedCategory(entry[2]),
        }
    end

    return {
        action = "open",
        peds = peds,
        categories = Config.Categories or {},
        lang = lang,
        previewDuration = Config.PreviewDuration or 15000,
    }
end

local function OpenPedMenuInternal()
    if isNuiOpen then
        return
    end
    isNuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage(BuildMenuPayload())
end

local function RequestOpenPedMenu(targetId)
    TriggerServerEvent("wasvendel_pedmenu:requestOpen", targetId)
end

local function ClosePedMenu()
    if not isNuiOpen then
        return
    end
    DeletePreviewPed()
    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

RegisterNetEvent("wasvendel_pedmenu:openMenu", function()
    OpenPedMenuInternal()
end)

RegisterNetEvent("wasvendel_pedmenu:accessDenied", function(message)
    Notify(message or (Config.SteamLock and Config.SteamLock.denyMessage) or "Access denied.", "error")
end)

RegisterNetEvent("wasvendel_pedmenu:notify", function(message, notifyType)
    Notify(message, notifyType)
end)

local cmdOpen = Config.Commands and Config.Commands.open or "pedmenu"
if cmdOpen ~= "" then
    RegisterCommand(cmdOpen, function(_, args)
        local targetId = args[1] and tonumber(args[1]) or nil
        RequestOpenPedMenu(targetId)
    end, false)
    local sugg = Config.CommandSuggestions and Config.CommandSuggestions.open
    if sugg then
        TriggerEvent("chat:addSuggestion", "/" .. cmdOpen, sugg.help or "", sugg.params or {})
    end
end

RegisterNUICallback("close", function(_, cb)
    ClosePedMenu()
    cb("ok")
end)

RegisterNUICallback("clearPreview", function(_, cb)
    DeletePreviewPed()
    cb("ok")
end)

RegisterNUICallback("preview", function(data, cb)
    if data and data.model then
        SpawnPreviewPed(data.model, data.outfit or 0)
    end
    cb("ok")
end)

RegisterNUICallback("setOutfit", function(data, cb)
    if data and data.model and data.outfit ~= nil then
        if previewModel == data.model and previewPed and DoesEntityExist(previewPed) then
            SpawnPreviewPed(data.model, data.outfit)
        end
    end
    cb("ok")
end)

RegisterNUICallback("apply", function(data, cb)
    if data and data.model then
        DeletePreviewPed()
        ApplyPedToPlayer(data.model, data.outfit or 0)
    end
    cb("ok")
end)

RegisterNUICallback("applyOutfit", function(data, cb)
    if data and data.outfit ~= nil then
        ApplyOutfit(PlayerPedId(), data.outfit)
    end
    cb("ok")
end)

RegisterNUICallback("restore", function(_, cb)
    RunRestoreCommand()
    cb("ok")
end)

CreateThread(function()
    while true do
        if previewPed and previewDeleteAt > 0 and GetGameTimer() >= previewDeleteAt then
            DeletePreviewPed()
        end
        Wait(500)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    DeletePreviewPed()
    ClosePedMenu()
end)
