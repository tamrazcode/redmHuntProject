local isBirdMode = false
local savedPlayerModel = 0

local function SetControlContext(pad, context)
    Citizen.InvokeNative(0x2804658EB7D8A50B, pad, context)
end

local function BecomeBird(birdModel)
    birdModel = birdModel or Config.DefaultBird
    local ped = PlayerPedId()
    if not isBirdMode then
        savedPlayerModel = GetEntityModel(ped)
    end

    local modelHash = GetHashKey(birdModel)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(50)
        RequestModel(modelHash)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        return false
    end

    SetPlayerModel(PlayerId(), modelHash)
    Wait(100)

    local birdPed = PlayerPedId()
    Citizen.InvokeNative(0x283978A15512B2FE, birdPed, true)
    SetPedConfigFlag(birdPed, 43, true)

    SetModelAsNoLongerNeeded(modelHash)

    if Config.GodModeWhenBird then
        SetEntityInvincible(birdPed, true)
    end

    isBirdMode = true

    return true
end

local function LeaveBird()
    if not isBirdMode then return false end

    isBirdMode = false
    SetControlContext(2, 0)

    if Config.GodModeWhenBird then
        local ped = PlayerPedId()
        SetEntityInvincible(ped, false)
    end

    RequestModel(savedPlayerModel)
    local timeout = 0
    while not HasModelLoaded(savedPlayerModel) and timeout < 100 do
        Wait(50)
        RequestModel(savedPlayerModel)
        timeout = timeout + 1
    end

    if HasModelLoaded(savedPlayerModel) then
        SetPlayerModel(PlayerId(), savedPlayerModel)
        Wait(100)
        Citizen.InvokeNative(0x283978A15512B2FE, PlayerPedId(), true)
        SetModelAsNoLongerNeeded(savedPlayerModel)
        return true
    else
        local fallback = GetHashKey("mp_male")
        RequestModel(fallback)
        while not HasModelLoaded(fallback) do Wait(50) end
        SetPlayerModel(PlayerId(), fallback)
        Wait(100)
        Citizen.InvokeNative(0x283978A15512B2FE, PlayerPedId(), true)
        SetModelAsNoLongerNeeded(fallback)
        return true
    end
end

local function ToggleBird(birdModel)
    if isBirdMode then
        LeaveBird()
    else
        BecomeBird(birdModel)
    end
end

local cmdBird = Config.Commands and Config.Commands.bird or "bird"
if cmdBird ~= "" then
    RegisterCommand(cmdBird, function(_, args)
        local model = args[1] or nil
        ToggleBird(model)
    end, false)
    local suggBird = Config.CommandSuggestions and Config.CommandSuggestions.bird
    if suggBird then
        TriggerEvent('chat:addSuggestion', '/' .. cmdBird, suggBird.help or "", suggBird.params or {})
    end
end

local isNuiOpen = false

local function OpenBirdsMenu()
    if isNuiOpen then return end
    isNuiOpen = true
    SetNuiFocus(true, true)
    local birds = {}
    for _, model in ipairs(Config.BirdModels) do
        local info = Config.BirdNames and Config.BirdNames[model]
        table.insert(birds, {
            model = model,
            name = info and info.name or model,
            icon = info and info.icon or "img/bird_default.png"
        })
    end
    SendNUIMessage({ action = "open", birds = birds })
end

local function CloseBirdsMenu()
    if isNuiOpen then
        isNuiOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
    end
end

local cmdBirdsList = Config.Commands and Config.Commands.birdslist or "birdslist"
if cmdBirdsList ~= "" then
    RegisterCommand(cmdBirdsList, OpenBirdsMenu, false)
    local suggBirdsList = Config.CommandSuggestions and Config.CommandSuggestions.birdslist
    if suggBirdsList then
        TriggerEvent('chat:addSuggestion', '/' .. cmdBirdsList, suggBirdsList.help or "", suggBirdsList.params or {})
    end
end

RegisterNUICallback('select', function(data, cb)
    CloseBirdsMenu()
    if data.model then
        BecomeBird(data.model)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseBirdsMenu()
    cb('ok')
end)

CreateThread(function()
    while true do
        if isBirdMode then
            SetControlContext(2, `OnMount`)
            DisableFirstPersonCamThisFrame()
        end
        Wait(0)
    end
end)

