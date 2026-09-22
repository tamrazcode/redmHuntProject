-- =================================================================
-- HUNT: Hard RP — The Corruption | Grid Inventory Client (DayZ Style)
-- =================================================================

local isInventoryOpen = false
local isDirectTransferMode = false
local directTransferTargetId = nil
local directTransferTargetLabel = nil
local directMedicineKnockedTarget = false
local directTransferTargetPed = nil
local isMMBPressed = false
local isInputFocused = false
local isCharacterSelected_inv = false
local cachedPlayerItems = {}
local cachedGroundDrops = {}
local cachedZombieCorpses = {}
local nuiInventoryInitialized = false
local inventoryRequestSequence = 0
local refreshRequestScheduled = false
local lastClientMutationSequence = 0
local hasMapItem = false
local lastMapNoticeAt = 0
local isNotebookOpen = false
local notebookAnimPlaying = false
local inventoryItemAnimationDepth = 0
local notebookInventoryAnimationLocked = false
local notebookAnimationRequest = 0

local MAP_CONTROL <const> = `INPUT_MAP`
local MAP_APP_HASH <const> = `MAP`

local function NotifyMapRequired()
    local now = GetGameTimer()
    if now - lastMapNoticeAt < 1200 then return end
    lastMapNoticeAt = now
    TriggerEvent("thehunt_status:notify", "Карта", "Необходима карта", "error")
end

local function HasCarriedMap(items)
    for _, item in ipairs(items or {}) do
        local name = type(item) == "table" and tostring(item.name or ""):lower() or ""
        local container = type(item) == "table" and tostring(item.container or "main") or "main"
        local count = type(item) == "table" and (tonumber(item.count) or 0) or 0
        -- Container rows are part of the player's snapshot, while prop rows
        -- describe a world container and must not grant map access.
        if name == "map" and count > 0 and item.isGround ~= true and not container:match("^prop:") then
            return true
        end
    end
    return false
end

local function UpdateMapAccess(items)
    hasMapItem = HasCarriedMap(items)
end

local function IsMapUiActive()
    if not IsUiappActiveByHash then return false end
    local ok, active = pcall(IsUiappActiveByHash, MAP_APP_HASH)
    return ok and (active == true or active == 1)
end

local function CloseMapUi()
    -- Native UIAPPS close is used directly so a click on the pause-menu Map
    -- tab cannot leave the app open for even one frame.
    pcall(Citizen.InvokeNative, 0x2FF10C9C3F92277E, MAP_APP_HASH)
end

CreateThread(function()
    while true do
        if hasMapItem then
            Wait(250)
        else
            Wait(0)
            -- INPUT_MAP is the native M action.  Disable it on every pad so
            -- keyboard, controller and remapped bindings follow one rule.
            DisableControlAction(0, MAP_CONTROL, true)
            DisableControlAction(1, MAP_CONTROL, true)
            if IsControlJustPressed(0, MAP_CONTROL) or IsDisabledControlJustPressed(0, MAP_CONTROL)
                or IsControlJustPressed(1, MAP_CONTROL) or IsDisabledControlJustPressed(1, MAP_CONTROL) then
                NotifyMapRequired()
            end
            if IsMapUiActive() then
                CloseMapUi()
                NotifyMapRequired()
            end
        end
    end
end)

local function RememberInventoryMutation(data)
    local mutationSequence = tonumber(type(data) == "table" and data.mutationSequence or data) or 0
    if mutationSequence > lastClientMutationSequence then
        lastClientMutationSequence = mutationSequence
    end
end

-- A refresh is still server-authoritative, but every read gets a client-side
-- sequence number so an older SQL response cannot overwrite a newer drag.
local function RequestInventorySnapshot()
    inventoryRequestSequence = inventoryRequestSequence + 1
    TriggerServerEvent("thehunt_items:requestInventory", inventoryRequestSequence, lastClientMutationSequence)
end

local function ScheduleInventoryRefresh()
    if refreshRequestScheduled then return end
    refreshRequestScheduled = true
    SetTimeout(50, function()
        refreshRequestScheduled = false
        RequestInventorySnapshot()
    end)
end

-- Ожидание выбора персонажа VORP
RegisterNetEvent("thehunt:character:selected", function()
    isCharacterSelected_inv = true
    SetTimeout(1500, function()
        RequestInventorySnapshot()
    end)
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Wait(1000)
    isCharacterSelected_inv = true
    RequestInventorySnapshot()
end)

-- =================================================================
-- Анимации открытия инвентаря (копашение в сумке / за спиной)
-- =================================================================
local currentInvAnim = nil
local inventoryAnimRequest = 0
local inventoryAnimStarting = false

-- 31 is the same looping upper-body mode used by the animation menu. Keep
-- the loop and upper-body bits even when a custom flag is configured: the
-- inventory must never take control of the player's legs or horse seat task.
local function NormalizeInventoryAnimFlag(value)
    local flag = tonumber(value) or 31
    local function hasBit(bit)
        return math.floor(flag / bit) % 2 == 1
    end
    if not hasBit(1) then flag = flag + 1 end
    if not hasBit(16) then flag = flag + 16 end
    return flag
end

local function GetInventoryAnimationProfile(ped)
    local cfg = Config.InventoryAnimation
    if not cfg then return nil, false end

    local mountedState = IsPedOnMount(ped)
    local mounted = mountedState == true or mountedState == 1
    if not mounted and GetMount then
        local mount = GetMount(ped)
        mounted = mount ~= nil and mount ~= 0 and DoesEntityExist(mount)
    end
    local profile = mounted and type(cfg.mounted) == "table" and cfg.mounted or cfg
    return profile, mounted
end

local function LoadAnimDict(dict)
    if not dict or dict == "" then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Citizen.Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function ApplyInventoryAnimation(ped, dict, animCandidates, flag, blendIn, blendOut, mounted, reapplyDelay)
    if currentInvAnim then
        local oldPed = currentInvAnim.ped
        if oldPed and DoesEntityExist(oldPed) then
            StopAnimTask(oldPed, currentInvAnim.dict, currentInvAnim.anim, currentInvAnim.blendOut or -6.0)
        end
        currentInvAnim = nil
    end

    if mounted then
        ClearPedSecondaryTask(ped)
    end

    -- The configured first clip is verified in the local RDR3 animation
    -- catalogue. Start it immediately; waiting for an animation-state probe
    -- here was the source of the delayed first frame.
    local anim = animCandidates[1] or "idle"
    TaskPlayAnim(ped, dict, anim, blendIn, blendOut, -1, flag, 0.0, false, false, false, 0, true)

    local startedAt = GetGameTimer()
    currentInvAnim = {
        ped = ped,
        dict = dict,
        anim = anim,
        flag = flag,
        blendIn = blendIn,
        blendOut = blendOut,
        mounted = mounted,
        reapplyDelay = reapplyDelay,
        startedAt = startedAt,
        reapplyAfter = startedAt + reapplyDelay
    }
end

local function StartInventoryAnimation()
    if not Config.InventoryAnimation or not Config.InventoryAnimation.enabled then return end
    if isNotebookOpen or inventoryItemAnimationDepth > 0 then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedSwimming(ped) then
        return
    end

    local cfg, mounted = GetInventoryAnimationProfile(ped)
    if not cfg then return end

    -- Direct-transfer and placed-container events can arrive more than once
    -- while the NUI is already open.  Do not restart the task in that case.
    if currentInvAnim and currentInvAnim.ped == ped and currentInvAnim.mounted == mounted then
        return
    end

    if inventoryAnimStarting then return end

    local dict = cfg.dict or "mech_loco_m@character@arthur@special@crafting@satchel"
    local anim = cfg.anim or "idle"
    local animCandidates = cfg.anims or { anim }
    local flag = NormalizeInventoryAnimFlag(cfg.flag)
    local blendIn = tonumber(cfg.blendInSpeed) or 2.0
    local blendOut = tonumber(cfg.blendOutSpeed) or -2.0
    local reapplyDelay = tonumber(cfg.reapplyDelay) or 900

    -- Once the dictionary is warm, put the task on the same frame as the
    -- inventory toggle. This avoids the old one-tick/one-probe delay.
    if HasAnimDictLoaded(dict) then
        ApplyInventoryAnimation(ped, dict, animCandidates, flag, blendIn, blendOut, mounted, reapplyDelay)
        return
    end

    inventoryAnimRequest = inventoryAnimRequest + 1
    local requestId = inventoryAnimRequest
    inventoryAnimStarting = true

    -- Asset loading runs in its own thread. The NUI opens immediately and the
    -- game keeps its movement task while the first native request completes.
    Citizen.CreateThread(function()
        if not LoadAnimDict(dict) then
            if requestId == inventoryAnimRequest then inventoryAnimStarting = false end
            return
        end
        if requestId ~= inventoryAnimRequest or not isInventoryOpen then
            if requestId == inventoryAnimRequest then inventoryAnimStarting = false end
            return
        end

        local activePed = PlayerPedId()
        if activePed ~= ped or not DoesEntityExist(activePed)
            or IsPedDeadOrDying(activePed, true) or IsPedRagdoll(activePed) then
            if requestId == inventoryAnimRequest then inventoryAnimStarting = false end
            return
        end

        local _, activeMounted = GetInventoryAnimationProfile(activePed)
        if activeMounted ~= mounted then
            if requestId == inventoryAnimRequest then inventoryAnimStarting = false end
            StartInventoryAnimation()
            return
        end

        if requestId ~= inventoryAnimRequest or not isInventoryOpen then
            return
        end

        ApplyInventoryAnimation(activePed, dict, animCandidates, flag, blendIn, blendOut, mounted, reapplyDelay)
        inventoryAnimStarting = false
    end)
end

local function StopInventoryAnimation()
    inventoryAnimRequest = inventoryAnimRequest + 1
    inventoryAnimStarting = false
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        currentInvAnim = nil
        return
    end

    local playingInfo = currentInvAnim
    currentInvAnim = nil

    local taskPed = playingInfo and playingInfo.ped or ped
    if playingInfo and taskPed and DoesEntityExist(taskPed)
        and not IsPedDeadOrDying(taskPed, true) and not IsPedRagdoll(taskPed) then
        StopAnimTask(taskPed, playingInfo.dict, playingInfo.anim, playingInfo.blendOut or -2.0)
        ClearPedSecondaryTask(ped)
    else
        ClearPedSecondaryTask(ped)
    end
end

-- Поток непрерывного удержания анимации инвентаря на всё время, пока открыт инвентарь (защита от сброса движком RDR2)
-- Item-use animations have priority over the looping inventory pose.  The
-- event is intentionally scoped to inventory/item actions; animation-menu and
-- world-interaction animations keep their existing behavior.
local function BeginInventoryItemAnimation()
    inventoryItemAnimationDepth = inventoryItemAnimationDepth + 1
    if inventoryItemAnimationDepth == 1 then
        StopInventoryAnimation()
    end
end

local function EndInventoryItemAnimation()
    if inventoryItemAnimationDepth <= 0 then return end
    inventoryItemAnimationDepth = inventoryItemAnimationDepth - 1
    if inventoryItemAnimationDepth == 0 and isInventoryOpen and not isNotebookOpen then
        StartInventoryAnimation()
    end
end

RegisterNetEvent('thehunt_inventory:itemAnimationStarted', function()
    BeginInventoryItemAnimation()
end)

RegisterNetEvent('thehunt_inventory:itemAnimationFinished', function()
    EndInventoryItemAnimation()
end)

-- Warm both dictionaries in the background so the first inventory press does
-- not wait on a native asset request. The open callback stays responsive even
-- if the native dictionary is not ready yet.
Citizen.CreateThread(function()
    Citizen.Wait(0)
    local cfg = Config.InventoryAnimation
    if not cfg or not cfg.enabled then return end
    if cfg.dict then LoadAnimDict(cfg.dict) end
    if type(cfg.mounted) == "table" and cfg.mounted.dict then
        LoadAnimDict(cfg.mounted.dict)
    end
end)

Citizen.CreateThread(function()
    while true do
        if isInventoryOpen and not isNotebookOpen and inventoryItemAnimationDepth <= 0 then
            if not currentInvAnim then
                -- A dictionary can miss the first request during a heavy
                -- streaming tick. Retry from the keepalive loop instead of
                -- leaving the open inventory without its native animation.
                if not inventoryAnimStarting then StartInventoryAnimation() end
            else
                local ped = PlayerPedId()
                if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and not IsPedRagdoll(ped) and not IsPedSwimming(ped) and not IsPedClimbing(ped) then
                    local now = GetGameTimer()
                    -- IsEntityPlayingAnim can be false during the first blend
                    -- frames. Never restart inside that window: doing so was
                    -- the walking jerk. A later re-apply is only a recovery
                    -- for natives that cancel secondary tasks themselves.
                    if now >= (currentInvAnim.reapplyAfter or 0)
                        and not IsEntityPlayingAnim(ped, currentInvAnim.dict, currentInvAnim.anim, 3) then
                        TaskPlayAnim(
                            ped,
                            currentInvAnim.dict,
                            currentInvAnim.anim,
                            currentInvAnim.blendIn or 2.0,
                            currentInvAnim.blendOut or -2.0,
                            -1,
                            currentInvAnim.flag or 31,
                            0.0,
                            false,
                            false,
                            false,
                            0,
                            true
                        )
                        currentInvAnim.reapplyAfter = now + (currentInvAnim.reapplyDelay or 900)
                    end
                end
            end
            Citizen.Wait(250)
        else
            Citizen.Wait(600)
        end
    end
end)

-- Открытие / Закрытие инвентаря
local function ToggleInventory()
    -- Если сейчас открыт любой NUI интерфейс и идет ввод текста — игнорируем нажатие I
    if IsNuiFocused() and not isInventoryOpen then
        return
    end

    local ped = PlayerPedId()
    if IsPedDeadOrDying(ped, true) then
        if isInventoryOpen then
            isInventoryOpen = false
            StopInventoryAnimation()
            pcall(function() AnimpostfxStop("OJDominoBlur") end)
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            SendNUIMessage({ type = 'CLOSE_INVENTORY' })
        end
        return
    end

    if not isCharacterSelected_inv then
        if DoesEntityExist(ped) then
            isCharacterSelected_inv = true
        else
            return
        end
    end
    local openingInventory = not isInventoryOpen
    isDirectTransferMode = false
    directTransferTargetId = nil
    directTransferTargetLabel = nil
    directMedicineKnockedTarget = false
    directTransferTargetPed = nil

    if openingInventory then
        activeSearchedZombieId = nil
        nuiInventoryInitialized = false
        -- Mark the inventory open before scheduling the native task. The
        -- animation loader may yield immediately; setting this first prevents
        -- that task from seeing a stale closed state and aborting.
        isInventoryOpen = true
        StartInventoryAnimation()
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)

        -- Нативный кинематографичный блюр фона RedM (без бага CEF черного экрана)
        pcall(function()
            AnimpostfxPlay("OJDominoBlur")
            AnimpostfxSetStrength("OJDominoBlur", 0.55)
        end)


        -- Запрашиваем предметы с сервера
        RequestInventorySnapshot()
    else
        isInventoryOpen = false
        activePlacedContainerCoords = nil
        TriggerServerEvent("thehunt_items:closePlacedContainer")
        nuiInventoryInitialized = false
        isInputFocused = false
        StopInventoryAnimation()
        pcall(function()
            AnimpostfxStop("OJDominoBlur")
        end)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CLOSE_INVENTORY' })
    end
end

RegisterCommand("inventory", ToggleInventory, false)
RegisterCommand("inv", ToggleInventory, false)
RegisterCommand("i", ToggleInventory, false)
RegisterCommand("bag", ToggleInventory, false)

if RegisterKeyMapping then
    pcall(RegisterKeyMapping, "inventory", "Открыть / Закрыть инвентарь", "keyboard", "I")
end

local directTransferModeType = "transfer" -- "transfer" | "medicine"


-- Открытие инвентаря при обыске трупа зомби через thehunt_interact
RegisterNetEvent("thehunt_inventory:openZombieCorpseSearch", function(zombieId)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end

    if not isCharacterSelected_inv then
        isCharacterSelected_inv = true
    end

    activeSearchedZombieId = tonumber(zombieId) or zombieId
    cachedZombieCorpses = GetNearbyZombieCorpses()
    cachedGroundDrops = GetCombinedNearbyDrops(Config.VicinityDistance or 1.5)

    isInventoryOpen = true
    nuiInventoryInitialized = false
    isDirectTransferMode = false
    directTransferTargetId = nil
    directMedicineKnockedTarget = false

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    pcall(function()
        AnimpostfxPlay("OJDominoBlur")
        AnimpostfxSetStrength("OJDominoBlur", 0.55)
    end)

    RequestInventorySnapshot()
end)

-- Открытие инвентаря в режиме прямой пакетной передачи другому игроку
RegisterNetEvent("thehunt_inventory:openDirectTransfer", function(targetServerId, targetStrangerLabel, targetIsKnocked, targetEntity)
    if not isCharacterSelected_inv then
        if DoesEntityExist(PlayerPedId()) then
            isCharacterSelected_inv = true
        else
            return
        end
    end

    isInventoryOpen = true
    nuiInventoryInitialized = false
    isDirectTransferMode = true
    directTransferModeType = "transfer"
    directTransferTargetId = tonumber(targetServerId) or targetServerId
    directTransferTargetLabel = targetStrangerLabel
    directMedicineKnockedTarget = targetIsKnocked == true
    directTransferTargetPed = targetEntity

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    pcall(function()
        AnimpostfxPlay("OJDominoBlur")
        AnimpostfxSetStrength("OJDominoBlur", 0.55)
    end)

    if not directMedicineKnockedTarget then
        StartInventoryAnimation()
    end
    RequestInventorySnapshot()
end)

-- Открытие инвентаря в режиме применения медицины к другому игроку
RegisterNetEvent("thehunt_inventory:openMedicineTarget", function(targetServerId, targetStrangerLabel, targetIsKnocked, targetEntity)
    if not isCharacterSelected_inv then
        if DoesEntityExist(PlayerPedId()) then
            isCharacterSelected_inv = true
        else
            return
        end
    end

    isInventoryOpen = true
    nuiInventoryInitialized = false
    isDirectTransferMode = true
    directTransferModeType = "medicine"
    directTransferTargetId = tonumber(targetServerId) or targetServerId
    directTransferTargetLabel = targetStrangerLabel
    directMedicineKnockedTarget = targetIsKnocked == true
    directTransferTargetPed = targetEntity

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    pcall(function()
        AnimpostfxPlay("OJDominoBlur")
        AnimpostfxSetStrength("OJDominoBlur", 0.55)
    end)

    if not directMedicineKnockedTarget then
        StartInventoryAnimation()
    end
    RequestInventorySnapshot()
end)

local activePlacedContainerCoords = nil

-- Открытие интерфейса размещенного в мире контейнера
RegisterNetEvent("thehunt_inventory:openPlacedContainer", function(data)
    if not isCharacterSelected_inv then
        if DoesEntityExist(PlayerPedId()) then
            isCharacterSelected_inv = true
        else
            return
        end
    end

    activePlacedContainerCoords = data and data.coords and vector3(data.coords.x, data.coords.y, data.coords.z) or nil

    if not isInventoryOpen then
        isInventoryOpen = true
        isDirectTransferMode = false
        directTransferTargetId = nil
        directTransferTargetLabel = nil
        nuiInventoryInitialized = false
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        pcall(function()
            AnimpostfxPlay("OJDominoBlur")
            AnimpostfxSetStrength("OJDominoBlur", 0.55)
        end)
        StartInventoryAnimation()
        RequestInventorySnapshot()
    end

    SendNUIMessage({
        type = 'OPEN_PLACED_CONTAINER',
        data = data
    })

    -- Фоновый поток отслеживания дистанции до контейнера
    Citizen.CreateThread(function()
        local currentCoords = activePlacedContainerCoords
        while isInventoryOpen and activePlacedContainerCoords and activePlacedContainerCoords == currentCoords do
            Citizen.Wait(500)
            if not isInventoryOpen or not activePlacedContainerCoords then break end
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            if #(pCoords - activePlacedContainerCoords) > 4.0 then
                activePlacedContainerCoords = nil
                ToggleInventory()
                TriggerServerEvent("thehunt_items:closePlacedContainer")
                break
            end
        end
    end)
end)

RegisterNetEvent("thehunt_inventory:closePlacedContainerUI", function()
    activePlacedContainerCoords = nil
    SendNUIMessage({
        type = 'CLOSE_PLACED_CONTAINER'
    })
end)

local activePlacedNoteCoords = nil

-- Открытие интерфейса чтения размещенной в мире записки / листа бумаги
RegisterNetEvent("thehunt_inventory:openPlacedNoteReader", function(data)
    if not isCharacterSelected_inv then
        if DoesEntityExist(PlayerPedId()) then
            isCharacterSelected_inv = true
        else
            return
        end
    end

    activePlacedNoteCoords = data and data.coords and vector3(data.coords.x, data.coords.y, data.coords.z) or nil

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({
        type = 'OPEN_PLACED_NOTE_READER',
        item = {
            name = data and data.itemName or 'torn_page',
            label = data and data.label or 'Вырванная страница',
            metadata = data and data.metadata or {}
        }
    })

    -- Фоновый поток отслеживания дистанции до записки
    Citizen.CreateThread(function()
        local currentCoords = activePlacedNoteCoords
        while activePlacedNoteCoords and activePlacedNoteCoords == currentCoords do
            Citizen.Wait(500)
            if not activePlacedNoteCoords then break end
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                activePlacedNoteCoords = nil
                SendNUIMessage({ type = 'CLOSE_PLACED_NOTE_READER' })
                break
            end
            local pCoords = GetEntityCoords(ped)
            if #(pCoords - currentCoords) > 4.0 then
                activePlacedNoteCoords = nil
                SendNUIMessage({ type = 'CLOSE_PLACED_NOTE_READER' })
                break
            end
        end
    end)
end)

RegisterNetEvent("thehunt_inventory:closePlacedNoteReaderUI", function()
    activePlacedNoteCoords = nil
    SendNUIMessage({
        type = 'CLOSE_PLACED_NOTE_READER'
    })
end)

-- Объединенный сбор всех предметов на земле (выброшенные игроками + заспавненный мировой лут)
local function GetCombinedNearbyDrops(maxDist)
    local radius = maxDist or Config.VicinityDistance or 2.8
    local combined = {}

    -- 1. Предметы, выброшенные игроками на землю (thehunt_items)
    if exports['thehunt_items'] and exports['thehunt_items'].GetNearbyGroundDrops then
        local itemDrops = exports['thehunt_items']:GetNearbyGroundDrops(radius)
        if itemDrops and type(itemDrops) == 'table' then
            for _, d in ipairs(itemDrops) do
                table.insert(combined, d)
            end
        end
    end

    -- 2. Заспавненный мировой лут в зоне (thehunt_loot)
    if exports['thehunt_loot'] and exports['thehunt_loot'].GetNearbyLootSlots then
        local lootDrops = exports['thehunt_loot']:GetNearbyLootSlots(radius)
        if lootDrops and type(lootDrops) == 'table' then
            for _, ld in ipairs(lootDrops) do
                table.insert(combined, ld)
            end
        end
    end

    return combined
end


local activeSearchedZombieId = nil

local function ClearActiveSearchedZombie()
    if activeSearchedZombieId then
        activeSearchedZombieId = nil
        cachedZombieCorpses = {}
        local p = PlayerPedId()
        if DoesEntityExist(p) and not IsPedDeadOrDying(p, true) then
            ClearPedTasks(p)
        end
    end
end

local function GetNearbyZombieCorpses()
    if GetResourceState('thehunt_zombie') ~= 'started' then return {} end

    local ok, corpses = pcall(function()
        return exports['thehunt_zombie']:GetNearbyZombieCorpses(3.5)
    end)
    if ok and corpses and type(corpses) == 'table' then
        return corpses
    end

    -- Запасной канал (event callback), если таблица экспортов RedM временно не подтянулась
    local eventCorpses = nil
    pcall(function()
        TriggerEvent('thehunt_zombie:getNearbyZombieCorpses', function(res)
            eventCorpses = res
        end, 3.5)
    end)
    if eventCorpses and type(eventCorpses) == 'table' then
        return eventCorpses
    end

    return {}
end

local currentCarriedWeight = 0.0

local function IsCarriedContainer(container, itemsByDbId, visited)
    if not container or container == "main" or container == "equipment" then
        return true
    end
    if string.sub(container, 1, 5) == "prop:" or container == "ground" then
        return false
    end
    visited = visited or {}
    local prefix, parentIdStr = string.match(container, "^([^:]+):(.+)$")
    if prefix and parentIdStr then
        local parentId = tonumber(parentIdStr) or parentIdStr
        if not visited[parentId] then
            visited[parentId] = true
            local parent = itemsByDbId[parentId]
            if parent then
                return IsCarriedContainer(parent.container, itemsByDbId, visited)
            end
        end
    end
    return false
end

local function CalculatePlayerCarriedWeight(itemList)
    if not itemList or type(itemList) ~= "table" then return 0.0 end
    local itemsByDbId = {}
    for _, item in ipairs(itemList) do
        if item.dbId then
            itemsByDbId[item.dbId] = item
            itemsByDbId[tostring(item.dbId)] = item
        end
    end

    local total = 0.0
    for _, item in ipairs(itemList) do
        if IsCarriedContainer(item.container, itemsByDbId) then
            local isClothing = ((item.clothing == true or item.category == "clothing" or item.clothingSlot ~= nil) and not item.isBackpack) or (type(item.name) == "string" and string.sub(item.name, 1, 9) == "clothing_" and string.sub(item.name, 1, 18) ~= "clothing_satchels")
            local w = isClothing and 0.0 or (tonumber(item.weight) or 0.1)
            local c = tonumber(item.count) or 1
            total = total + (w * c)
        end
    end
    return math.floor(total * 10 + 0.5) / 10
end

-- Прием актуальных данных от thehunt_items
RegisterNetEvent("thehunt_inventory:onItemsReceived", function(items, drops, serverGender, requestId, requestMutationSequence)
    cachedPlayerItems = items or {}
    UpdateMapAccess(cachedPlayerItems)
    currentCarriedWeight = CalculatePlayerCarriedWeight(cachedPlayerItems)
    local isOverweight = currentCarriedWeight > (Config.MaxWeight or 30.0)
    TriggerEvent("thehunt_walking:setOverweight", isOverweight)
    if CheckPlayerEquippedBackpack then
        CheckPlayerEquippedBackpack(cachedPlayerItems)
    end
    local inventoryGender = serverGender or "Male"
    pcall(function()
        if exports['thehunt_character'] and exports['thehunt_character'].GetAppearanceState then
            local _, _, _, savedGender = exports['thehunt_character']:GetAppearanceState()
            if savedGender then inventoryGender = savedGender end
        end
    end)

    if isInventoryOpen then
        cachedGroundDrops = GetCombinedNearbyDrops(Config.VicinityDistance or 1.5)
        cachedZombieCorpses = GetNearbyZombieCorpses()

        local isInitialOpen = not nuiInventoryInitialized
        nuiInventoryInitialized = true

        SendNUIMessage({
            type = isInitialOpen
                and (isDirectTransferMode and 'OPEN_DIRECT_TRANSFER' or 'OPEN_INVENTORY')
                or 'UPDATE_INVENTORY',
            modeType = directTransferModeType or 'transfer',
            config = Config,
            items = cachedPlayerItems,
            gender = inventoryGender,
            groundDrops = isDirectTransferMode and {} or cachedGroundDrops,
            zombieCorpses = isDirectTransferMode and {} or cachedZombieCorpses,
            targetId = directTransferTargetId,
            targetLabel = directTransferTargetLabel,
            targetKnocked = directMedicineKnockedTarget,
            requestId = requestId,
            mutationSequence = requestMutationSequence
        })
    end
end)



local function HaveZombieCorpsesChanged(oldCorpses, newCorpses)
    if not oldCorpses or not newCorpses then return true end
    if #oldCorpses ~= #newCorpses then return true end
    for i = 1, #newCorpses do
        local n = newCorpses[i]
        local o = oldCorpses[i]
        if not o or o.zombieId ~= n.zombieId or #(o.items or {}) ~= #(n.items or {}) then
            return true
        end
    end
    return false
end

-- Обновление списка дропов рядом в реальном времени
RegisterNetEvent("thehunt_inventory:onDropsUpdated", function(drops)
    if not isInventoryOpen then return end
    cachedGroundDrops = GetCombinedNearbyDrops(Config.VicinityDistance or 1.5)
    cachedZombieCorpses = GetNearbyZombieCorpses()

    SendNUIMessage({
        type = 'UPDATE_GROUND_DROPS',
        groundDrops = cachedGroundDrops,
        zombieCorpses = cachedZombieCorpses
    })
end)

-- Обновление списка мирового лута рядом при спавне/деспавне слотов
RegisterNetEvent("thehunt_inventory:refreshNearbyDrops", function()
    if not isInventoryOpen then return end
    cachedGroundDrops = GetCombinedNearbyDrops(Config.VicinityDistance or 1.5)
    cachedZombieCorpses = GetNearbyZombieCorpses()

    SendNUIMessage({
        type = 'UPDATE_GROUND_DROPS',
        groundDrops = cachedGroundDrops,
        zombieCorpses = cachedZombieCorpses
    })
end)

-- Уведомление об обновлении инвентаря
RegisterNetEvent("thehunt_items:refreshInventory", function()
    if isInventoryOpen then
        ScheduleInventoryRefresh()
    end
end)

local function HaveDropsChanged(oldDrops, newDrops)
    if not oldDrops or not newDrops then return true end
    if #oldDrops ~= #newDrops then return true end
    for i = 1, #newDrops do
        local n = newDrops[i]
        local o = oldDrops[i]
        if not o or o.dropId ~= n.dropId or o.count ~= n.count then
            return true
        end
    end
    return false
end

-- Поток непрерывного динамического отслеживания предметов "Рядом" и трупов зомби при передвижении с открытым инвентарем
Citizen.CreateThread(function()
    local lastPlayerCoords = vector3(0, 0, 0)
    local lastZombieCheck = 0

    while true do
        if isInventoryOpen then
            local ped = PlayerPedId()
            local curCoords = GetEntityCoords(ped)
            local now = GetGameTimer()

            -- Если персонаж сдвинулся более чем на 25 см или прошло время проверки трупов
            local moved = #(curCoords - lastPlayerCoords)
            local timeForZombieCheck = (now - lastZombieCheck > 300)

            if moved > 0.25 or timeForZombieCheck then
                if moved > 0.25 then
                    lastPlayerCoords = curCoords
                end
                lastZombieCheck = now

                local nearbyDrops = GetCombinedNearbyDrops(Config.VicinityDistance or 1.5)
                local nearbyZombies = GetNearbyZombieCorpses()
                local dropsChanged = HaveDropsChanged(cachedGroundDrops, nearbyDrops)
                local zombiesChanged = HaveZombieCorpsesChanged(cachedZombieCorpses, nearbyZombies)

                if dropsChanged or zombiesChanged then
                    cachedGroundDrops = nearbyDrops
                    cachedZombieCorpses = nearbyZombies

                    SendNUIMessage({
                        type = 'UPDATE_GROUND_DROPS',
                        groundDrops = cachedGroundDrops,
                        zombieCorpses = cachedZombieCorpses
                    })
                end
            end
            Citizen.Wait(150)
        else
            Citizen.Wait(600)
        end
    end
end)

-- Главный цикл блокировки действий и отслеживания клавиш
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if not isCharacterSelected_inv then
            Citizen.Wait(500)
        else
            -- Блокируем стандартную сумку RDR2 (клавиша B), чтобы не конфликтовала
            DisableControlAction(0, 0x4CC0E2FE, true) -- INPUT_OPEN_SATCHEL_MENU (B)
            DisableControlAction(0, 0x80F16E10, true) -- INPUT_OPEN_SATCHEL_HORSE_MENU (B)
            DisableControlAction(0, 0xD39392D0, true) -- INPUT_SATCHEL_MENU (B)

            if isInputFocused then
                local ped = PlayerPedId()
                DisableAllControlActions(0)
                DisableAllControlActions(1)
                DisableAllControlActions(2)
                DisablePlayerFiring(ped, true)
            elseif isInventoryOpen then
                local ped = PlayerPedId()
                if IsPedDeadOrDying(ped, true) then
                    ToggleInventory()
                end

                -- Полная блокировка всех действий, стрельбы и передвижения на ногах/лошади
                DisableAllControlActions(0)
                DisableAllControlActions(1)
                DisableAllControlActions(2)
                DisablePlayerFiring(ped, true)

                local allowedControls = {
                    -- Войс-чат
                    `INPUT_PUSH_TO_TALK`,
                    0xF1301666,
                    0x05CA7C52
                }

                for pad = 0, 2 do
                    for i = 1, #allowedControls do
                        EnableControlAction(pad, allowedControls[i], true)
                    end
                end
            end
        end
    end
end)

-- Команда смены стиля анимации инвентаря в реальном времени (/invanim [стиль])
RegisterCommand("invanim", function(source, args)
    local style = args[1] and string.lower(args[1])
    local cfg = Config.InventoryAnimation
    if not cfg or not cfg.styles then return end

    local aliasMap = {
        ["1"] = "satchel_rummage",
        ["rummage"] = "satchel_rummage",
        ["копашение"] = "satchel_rummage",
        ["2"] = "satchel_craft",
        ["craft"] = "satchel_craft",
        ["крафт"] = "satchel_craft",
        ["3"] = "satchel_hold",
        ["hold"] = "satchel_hold",
        ["удержание"] = "satchel_hold",
        ["4"] = "satchel_inspect",
        ["inspect"] = "satchel_inspect",
        ["осмотр"] = "satchel_inspect",
        ["5"] = "behind_back",
        ["behind"] = "behind_back",
        ["спина"] = "behind_back",
        ["6"] = "belt_hold",
        ["belt"] = "belt_hold",
        ["пояс"] = "belt_hold"
    }

    local targetKey = aliasMap[style] or style
    if targetKey and cfg.styles[targetKey] then
        cfg.style = targetKey
        local label = cfg.styles[targetKey].label or targetKey
        TriggerEvent("thehunt_status:notify", "Инвентарь", "Анимация: " .. label, "info")
    else
        local keys = { "satchel_rummage", "satchel_craft", "satchel_hold", "satchel_inspect", "behind_back", "belt_hold" }
        local cur = cfg.style or "satchel_rummage"
        local nextIdx = 1
        for i, k in ipairs(keys) do
            if k == cur then nextIdx = (i % #keys) + 1 break end
        end
        local newKey = keys[nextIdx]
        cfg.style = newKey
        local label = cfg.styles[newKey].label or newKey
        TriggerEvent("thehunt_status:notify", "Инвентарь", "Анимация переключена на: " .. label, "info")
    end
end, false)

-- Автозакрытие режима передачи, если отойти от игрока дальше 3.5м
Citizen.CreateThread(function()
    while true do
        if isInventoryOpen and isDirectTransferMode and directTransferTargetId then
            Citizen.Wait(200)
            local shouldClose = false

            local targetPed = nil
            if directTransferTargetPed and DoesEntityExist(directTransferTargetPed) then
                targetPed = directTransferTargetPed
            else
                local targetPlayer = GetPlayerFromServerId(tonumber(directTransferTargetId) or directTransferTargetId)
                if targetPlayer ~= -1 then
                    targetPed = GetPlayerPed(targetPlayer)
                end
            end

            if not targetPed or not DoesEntityExist(targetPed) then
                shouldClose = true
            else
                local myPed = PlayerPedId()
                local dist = #(GetEntityCoords(myPed) - GetEntityCoords(targetPed))
                if dist > 3.5 then
                    shouldClose = true
                end
            end

            if shouldClose then
                isInventoryOpen = false
                isInputFocused = false
                isDirectTransferMode = false
                directTransferTargetId = nil
                directTransferTargetLabel = nil
                directMedicineKnockedTarget = false
                directTransferTargetPed = nil
                StopInventoryAnimation()
                pcall(function()
                    AnimpostfxStop("OJDominoBlur")
                end)
                SetNuiFocus(false, false)
                SetNuiFocusKeepInput(false)
                SendNUIMessage({ type = 'CLOSE_INVENTORY' })
            end
        else
            Citizen.Wait(350)
        end
    end
end)

-- =================================================================
-- NUI CALLBACKS
-- =================================================================

local function CloseInventoryForEditor()
    isInventoryOpen = false
    isInputFocused = false
    nuiInventoryInitialized = false
    isDirectTransferMode = false
    directTransferTargetId = nil
    directTransferTargetLabel = nil
    directMedicineKnockedTarget = false
    directTransferTargetPed = nil
    isMMBPressed = false
    activePlacedContainerCoords = nil
    TriggerServerEvent("thehunt_items:closePlacedContainer")
    StopInventoryAnimation()
    if isNotebookOpen then
        isNotebookOpen = false
        StopNotebookAnimation()
    end
    AnimpostfxStop("OJDominoBlur")
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventoryForEditor()
    cb('ok')
end)

RegisterNUICallback('positionBackpack', function(data, cb)
    local item
    for _, candidate in pairs(cachedPlayerItems or {}) do
        if tonumber(candidate.dbId) == tonumber(data.dbId) then item = candidate; break end
    end
    if not item or not item.isBackpack or item.container ~= 'equipment' then
        TriggerEvent('thehunt_status:notify', 'Рюкзак', 'Сначала наденьте этот рюкзак.', 'info')
        cb({ok=false}); return
    end
    if GetResourceState('thehunt_gizmo') ~= 'started' then cb({ok=false}); return end
    CloseInventoryForEditor()
    SendNUIMessage({type='CLOSE_INVENTORY'})
    TriggerEvent('thehunt_inventory:beginBackpackFit', item.dbId)
    cb({ok=true})
end)

RegisterNUICallback('closePlacedContainer', function(data, cb)
    activePlacedContainerCoords = nil
    TriggerServerEvent("thehunt_items:closePlacedContainer")
    cb('ok')
end)

RegisterNUICallback('setInputFocusState', function(data, cb)
    isInputFocused = data and data.hasFocus == true
    cb('ok')
end)

RegisterNUICallback('setCameraRotationState', function(data, cb)
    isMMBPressed = (data.active == true)
    cb('ok')
end)

-- Пакетная передача группы предметов напрямую игроку
RegisterNUICallback('transferBatch', function(data, cb)
    TriggerServerEvent("thehunt_items:transferBatch", data)
    cb('ok')
end)

-- Применение медицины к выбранному игроку
RegisterNUICallback('applyMedicineToTarget', function(data, cb)
    TriggerServerEvent("thehunt_items:applyMedicineToPlayer", data)
    cb('ok')
end)

-- Сохранение положения предмета в сетке
RegisterNUICallback('saveItemPlacement', function(data, cb)
    RememberInventoryMutation(data)
    -- Give the local ped an immediate visual removal when a garment leaves an
    -- equipment slot. The server remains authoritative for persistence, but
    -- this avoids waiting for the inventory refresh/character bridge.
    -- A garment cannot be placed inside another garment's storage grid. That
    -- destination is rejected by the server and the item is returned to its
    -- equipment slot, so do not remove its visual component optimistically in
    -- this case.
    local destination = tostring(data and data.container or '')
    local isClothingStorage = string.sub(destination, 1, 9) == 'clothing:'
    if data and data.previousContainer == 'equipment' and data.container ~= 'equipment'
        and not isClothingStorage then
        if data.clothingSlot == 'Satchels' or tonumber(data.x) == 29 then
            if DetachLocalBackpack then DetachLocalBackpack() end
        elseif type(data.clothingSlot) == 'string' then
            local applied = pcall(function()
                exports['thehunt_character']:ApplySingleClothing(data.clothingSlot, -1, nil, nil)
            end)
            if not applied then
                TriggerEvent('thehunt_character:client:ApplySingleClothing', data.clothingSlot, -1, nil, nil)
            end
        end
    end

    if data and data.container == 'equipment' and (data.clothingSlot == 'Satchels' or tonumber(data.x) == 29) then
        local targetDbId = tonumber(data.dbId)
        local bpModel = nil
        if cachedPlayerItems then
            for _, it in ipairs(cachedPlayerItems) do
                if tonumber(it.dbId) == targetDbId then
                    bpModel = it.propModel or it.dropModel or it.name
                    break
                end
            end
        end
        if bpModel and AttachLocalBackpack then
            AttachLocalBackpack(bpModel)
        end
    end

    TriggerServerEvent("thehunt_items:saveItemPlacement", data)
    cb('ok')
end)

-- Выбрасывание предмета в мир (с точным Raycast поиском поверхности: сено, телега, пол, стол, земля)
RegisterNUICallback('dropItem', function(data, cb)
    RememberInventoryMutation(data)
    if data then
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local pHeading = GetEntityHeading(ped)
        local rad = math.rad(pHeading)
        local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local right = vector3(math.cos(rad), math.sin(rad), 0.0)

        -- Аккуратный разброс предметов рядом друг с другом на поверхности перед игроком
        local forwardDist = 0.40 + (math.random() * 0.30)
        local sideDist = (math.random() - 0.5) * 0.45
        local targetGroundPos = pCoords + (forward * forwardDist) + (right * sideDist)

        local startPos = targetGroundPos + vector3(0.0, 0.0, 0.6)
        local endPos = targetGroundPos - vector3(0.0, 0.0, 3.2)

        -- Флаги луча: 1 (Terrain/World) + 16 (Objects/Static floors)
        local rayHandle = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 17, ped, 0)
        local _, hit, hitCoords, _, _ = GetShapeTestResult(rayHandle)

        local finalZ = pCoords.z - 0.85
        if hit == 1 then
            finalZ = hitCoords.z
        else
            local foundGround, gZ = GetGroundZFor_3dCoord(targetGroundPos.x, targetGroundPos.y, targetGroundPos.z + 1.0, false)
            if foundGround then
                finalZ = gZ
            end
        end

        data.coords = {
            x = targetGroundPos.x,
            y = targetGroundPos.y,
            z = finalZ + 0.015
        }

        TriggerServerEvent("thehunt_items:dropItem", data)
    end
    cb('ok')
end)

-- Подбор предмета из сетки "Рядом" в сетку игрока
RegisterNUICallback('pickupDrop', function(data, cb)
    RememberInventoryMutation(data)
    local dropIdStr = tostring(data.dropId or '')
    if string.sub(dropIdStr, 1, 5) == "loot_" then
        local slotId = tonumber(string.sub(dropIdStr, 6))
        TriggerServerEvent("thehunt_loot:requestPickupToInventory", slotId, data.container, data.x, data.y, data.isRotated, data.mutationSequence)
    else
        TriggerServerEvent("thehunt_items:pickupDrop", data.dropId, data.container, data.x, data.y, data.isRotated, data.mutationSequence)
    end
    cb('ok')
end)

-- Забор лута из трупа зомби
RegisterNUICallback('takeZombieLoot', function(data, cb)
    RememberInventoryMutation(data)
    if data and data.zombieId and data.slotId then
        TriggerServerEvent("thehunt_zombie:takeCorpseItem", data.zombieId, data.slotId, data.container, data.x, data.y, data.isRotated)
    end
    cb('ok')
end)

-- Уведомление о начале/конце обыска (распознавания) предметов в трупе зомби
RegisterNUICallback('setZombieSearchingState', function(data, cb)
    if data and data.zombieId then
        TriggerEvent("thehunt_zombie:setSearchingCorpse", data.zombieId, data.isSearching == true)
        TriggerServerEvent("thehunt_zombie:setSearchingCorpse", data.zombieId, data.isSearching == true)
    end
    cb('ok')
end)

-- Конкретный предмет в трупе зомби успешно раскрыт
RegisterNUICallback('onZombieItemSearched', function(data, cb)
    if data and data.zombieId and data.slotId then
        TriggerServerEvent("thehunt_zombie:itemSearched", data.zombieId, data.slotId)
    end
    cb('ok')
end)

-- Сервер сообщил о раскрытии предмета в трупе (общее раскрытие для всех)
RegisterNetEvent('thehunt_inventory:zombieItemSearched', function(zombieId, slotId)
    SendNUIMessage({
        type = 'ZOMBIE_ITEM_SEARCHED',
        zombieId = zombieId,
        slotId = slotId
    })
end)
AddEventHandler('thehunt_inventory:zombieItemSearched', function(zombieId, slotId)
    SendNUIMessage({
        type = 'ZOMBIE_ITEM_SEARCHED',
        zombieId = zombieId,
        slotId = slotId
    })
end)

-- Все предметы в трупе зомби успешно распознаны
RegisterNUICallback('onZombieAllItemsSearched', function(data, cb)
    if data and data.zombieId then
        TriggerEvent("thehunt_zombie:onCorpseAllSearched", data.zombieId)
        TriggerServerEvent("thehunt_zombie:onCorpseAllSearched", data.zombieId)
    end
    cb('ok')
end)

-- Получение списка игроков рядом (в радиусе 2.5м) для передачи предмета
RegisterNUICallback('getNearbyPlayers', function(data, cb)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local nearbyPlayers = {}

    local activePlayers = GetActivePlayers()
    for _, p in ipairs(activePlayers) do
        local targetPed = GetPlayerPed(p)
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local dist = #(myCoords - GetEntityCoords(targetPed))
            if dist <= (Config.TransferDistance or 1.0) then
                local sId = GetPlayerServerId(p)
                local isMale = IsPedMale(targetPed)
                local strangerLabel = isMale and "Незнакомец" or "Незнакомка"

                table.insert(nearbyPlayers, {
                    id = sId,
                    label = strangerLabel,
                    distance = string.format("%.1fm", dist)
                })
            end
        end
    end

    cb({ players = nearbyPlayers })
end)

-- Передача предмета другому игроку
RegisterNUICallback('transferItem', function(data, cb)
    TriggerServerEvent("thehunt_items:transferItem", data)
    cb('ok')
end)

-- Включение / выключение подсветки ID над головами рядом при передаче
RegisterNUICallback('toggleTransferIDs', function(data, cb)
    if exports['thehunt_core'] and exports['thehunt_core'].showTransferNearbyIDs then
        exports['thehunt_core']:showTransferNearbyIDs(data.active == true)
    else
        TriggerEvent("thehunt_core:showTransferNearbyIDs", data.active == true)
    end
    cb('ok')
end)

-- Размещение предмета в мире (Разместить)
RegisterNUICallback('placeItem', function(data, cb)
    isInventoryOpen = false
    isInputFocused = false
    StopInventoryAnimation()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_INVENTORY' })

    if data and data.name then
        local itemDef = exports['thehunt_items'] and exports['thehunt_items']:GetItemData(data.name)
        local propModel = (itemDef and itemDef.propModel) or "p_crate26x_b"

        -- Запускаем 3D-предпросмотр размещения через thehunt_builder
        TriggerEvent("thehunt_builder:startPropPreviewFromInventory", {
            name = itemDef and itemDef.label or "Предмет",
            model = propModel,
            itemName = data.name,
            dbId = data.dbId,
            metadata = data.metadata,
            isProtected = (data.isProtected == true)
        })
    end
    cb('ok')
end)

-- Объединение стаков предметов (Инвентарь <-> Земля <-> Мировой лут)
RegisterNUICallback('mergeItems', function(data, cb)
    RememberInventoryMutation(data)
    local srcDropStr = tostring(data.sourceDropId or '')
    local dstDropStr = tostring(data.targetDropId or '')

    local isSrcLoot = string.sub(srcDropStr, 1, 5) == "loot_"
    local isDstLoot = string.sub(dstDropStr, 1, 5) == "loot_"

    if isSrcLoot and isDstLoot then
        -- 1. Мировой лут -> Мировой лут на земле
        local srcSlotId = tonumber(string.sub(srcDropStr, 6))
        local dstSlotId = tonumber(string.sub(dstDropStr, 6))
        TriggerServerEvent("thehunt_loot:mergeLootIntoLoot", srcSlotId, dstSlotId, data.count)
    elseif isSrcLoot and data.targetDropId ~= nil then
        -- 2. Мировой лут -> Дроп игрока на земле
        local srcSlotId = tonumber(string.sub(srcDropStr, 6))
        TriggerServerEvent("thehunt_loot:mergeLootIntoDrop", srcSlotId, data.targetDropId, data.count)
    elseif data.sourceDropId ~= nil and isDstLoot then
        -- 3. Дроп игрока -> Мировой лут на земле
        local dstSlotId = tonumber(string.sub(dstDropStr, 6))
        TriggerServerEvent("thehunt_loot:mergeDropIntoLoot", data.sourceDropId, dstSlotId, data.count)
    elseif isSrcLoot and data.targetDbId ~= nil then
        -- 4. Мировой лут с земли -> В инвентарь игрока
        local slotId = tonumber(string.sub(srcDropStr, 6))
        TriggerServerEvent("thehunt_loot:mergeLootIntoInventory", slotId, data.targetDbId, data.count)
    elseif data.sourceDbId ~= nil and isDstLoot then
        -- 5. Из инвентаря игрока -> В мировой лут на земле
        local slotId = tonumber(string.sub(dstDropStr, 6))
        TriggerServerEvent("thehunt_loot:mergeInventoryIntoLoot", data.sourceDbId, slotId, data.count)
    else
        -- 6. Обычные дропы игроков и инвентарь (thehunt_items)
        TriggerServerEvent("thehunt_items:mergeItems", data)
    end
    cb('ok')
end)

-- Разделение стака предметов
RegisterNUICallback('splitItem', function(data, cb)
    RememberInventoryMutation(data)
    local srcDropStr = tostring(data.sourceDropId or '')
    if string.sub(srcDropStr, 1, 5) == "loot_" then
        local slotId = tonumber(string.sub(srcDropStr, 6))
        TriggerServerEvent("thehunt_loot:splitLootToInventory", slotId, data.count, data.targetContainer, data.targetX, data.targetY, data.isRotated)
    else
        TriggerServerEvent("thehunt_items:splitItem", data)
    end
    cb('ok')
end)

RegisterNUICallback('saveNotebook', function(data, cb)
    if data and data.dbId then
        TriggerServerEvent("thehunt_items:saveNotebook", {
            dbId = data.dbId,
            title = data.title,
            html = data.html
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('tearNotebookPage', function(data, cb)
    if data and data.dbId then
        TriggerServerEvent("thehunt_items:tearNotebookPage", { dbId = data.dbId })
    end
    cb({ ok = true })
end)

local function CleanupHandProps(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local boneR = GetEntityBoneIndexByName(ped, "SKEL_R_Hand")
    local boneL = GetEntityBoneIndexByName(ped, "SKEL_L_Hand")
    local handR = (boneR ~= -1) and GetWorldPositionOfEntityBone(ped, boneR) or nil
    local handL = (boneL ~= -1) and GetWorldPositionOfEntityBone(ped, boneL) or nil
    if not handR and not handL then return end

    local handle, obj = FindFirstObject()
    local success = true
    while success do
        if DoesEntityExist(obj) and not IsPedAPlayer(obj) then
            local coords = GetEntityCoords(obj)
            local dR = handR and #(coords - handR) or 999.0
            local dL = handL and #(coords - handL) or 999.0
            if dR <= 0.4 or dL <= 0.4 then
                SetEntityAsMissionEntity(obj, true, true)
                DeleteEntity(obj)
            end
        end
        success, obj = FindNextObject(handle)
    end
    EndFindObject(handle)
end

local function StopNotebookAnimation()
    if not notebookAnimPlaying then return end
    notebookAnimPlaying = false
    local ped = PlayerPedId()

    if exports['thehunt_animations'] and exports['thehunt_animations'].StopAnimation then
        pcall(function() exports['thehunt_animations']:StopAnimation() end)
    else
        ClearPedTasks(ped)
    end

    FreezeEntityPosition(ped, false)

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

    -- Плавное завершение: даем педу отыграть анимацию закрытия блокнота и уборки карандаша,
    -- а после её окончания гарантированно возвращаем полный контроль над движением
    Citizen.CreateThread(function()
        local myPed = PlayerPedId()
        local startTime = GetGameTimer()
        local wantMove = false

        while IsPedUsingAnyScenario(myPed) and (GetGameTimer() - startTime < 3200) do
            Citizen.Wait(50)
            myPed = PlayerPedId()

            -- Если игрок после закрытия сразу нажал WASD/бег — моментально освобождаем
            for i = 1, #moveControls do
                if IsControlJustPressed(0, moveControls[i]) or IsDisabledControlJustPressed(0, moveControls[i]) then
                    wantMove = true
                    break
                end
            end
            if wantMove then break end
        end

        ClearPedTasksImmediately(myPed)
        ClearPedSecondaryTask(myPed)
        FreezeEntityPosition(myPed, false)
        CleanupHandProps(myPed)
    end)
end

local function StartNotebookAnimation()
    if notebookAnimPlaying then return end
    local ped = PlayerPedId()

    -- Если персонаж верхом на лошади (или в повозке), анимацию блокнота не проигрываем
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, true) then
        return
    end

    notebookAnimPlaying = true
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    -- Не вызываем FreezeEntityPosition, чтобы движок RDR3 мог запустить
    -- нативный сценарий и прикрепить проп блокнота и карандаша в руки.
    -- Полная блокировка персонажа осуществляется через DisableAllControlActions.
    local started = false
    if exports['thehunt_animations'] and exports['thehunt_animations'].PlayAnimation then
        local ok, res = pcall(function()
            return exports['thehunt_animations']:PlayAnimation('Записывать в блокнот')
        end)
        if ok and res then started = true end
    end
    if not started then
        ClearPedTasksImmediately(ped)
        Citizen.Wait(50)
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_WRITE_NOTEBOOK`, -1, true, false, false, false)
    end
end

RegisterNUICallback('notebookOpened', function(data, cb)
    StopInventoryAnimation()
    isNotebookOpen = true
    isInputFocused = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    if not (data and data.isPlaced) then
        BeginInventoryItemAnimation()
        notebookInventoryAnimationLocked = true
        notebookAnimationRequest = notebookAnimationRequest + 1
        local requestId = notebookAnimationRequest
        Citizen.CreateThread(function()
            local deadline = GetGameTimer() + 5000
            while isNotebookOpen and notebookInventoryAnimationLocked
                and requestId == notebookAnimationRequest
                and inventoryItemAnimationDepth > 1
                and GetGameTimer() < deadline do
                Citizen.Wait(50)
            end

            if isNotebookOpen and notebookInventoryAnimationLocked
                and requestId == notebookAnimationRequest
                and inventoryItemAnimationDepth <= 1 then
                StartNotebookAnimation()
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('notebookClosed', function(data, cb)
    isNotebookOpen = false
    isInputFocused = false
    activePlacedNoteCoords = nil
    notebookAnimationRequest = notebookAnimationRequest + 1
    StopNotebookAnimation()
    if notebookInventoryAnimationLocked then
        notebookInventoryAnimationLocked = false
        EndInventoryItemAnimation()
    end
    if isInventoryOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        if inventoryItemAnimationDepth <= 0 then StartInventoryAnimation() end
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    cb('ok')
end)

-- Поток полной блокировки управления персонажем во время чтения/записи в блокнот
Citizen.CreateThread(function()
    while true do
        if isNotebookOpen then
            DisableAllControlActions(0)
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)

-- Использование предмета (Использовать)
RegisterNUICallback('useItem', function(data, cb)
    if data and data.name then
        local thirstVal = nil
        local hungerVal = nil
        local curHpVal = nil
        local predHpVal = nil

        exports.thehunt_core:GetMetabolismValue("Thirst", function(val)
            thirstVal = val
        end)
        exports.thehunt_core:GetMetabolismValue("Hunger", function(val)
            hungerVal = val
        end)

        pcall(function()
            local ped = PlayerPedId()
            local curHp = GetEntityHealth(ped)
            local maxHp = GetEntityMaxHealth(ped)
            if maxHp <= 0 then maxHp = 100 end
            curHpVal = math.floor((curHp / maxHp) * 100)

            if exports['thehunt_items'] and exports['thehunt_items'].GetPredictedHealthPct then
                predHpVal = exports['thehunt_items']:GetPredictedHealthPct()
            else
                predHpVal = curHpVal
            end
        end)

        TriggerServerEvent("thehunt_items:useItem", data.name, data.dbId, {
            thirst = thirstVal,
            hunger = hungerVal,
            health = curHpVal,
            predictedHealth = predHpVal
        }, data.dropId)
    end
    cb('ok')
end)

RegisterNUICallback('onWeightUpdated', function(data, cb)
    if data and data.weight ~= nil then
        currentCarriedWeight = tonumber(data.weight) or currentCarriedWeight
        local isOverweight = currentCarriedWeight > (Config.MaxWeight or 20.0)
        TriggerEvent("thehunt_walking:setOverweight", isOverweight)
    end
    cb('ok')
end)

RegisterNUICallback('notifyOverweightExceeded', function(data, cb)
    local maxLim = data and tonumber(data.maxWeight) or ((Config.MaxWeight or 30.0) + (Config.MaxOverweightMargin or 5.0))
    TriggerEvent("thehunt_status:notify", "Слишком тяжело", string.format("Вы не можете нести больше %.1f кг!", maxLim), "error", 4000)
    cb('ok')
end)

exports('isInventoryOpen', function()
    return isInventoryOpen == true
end)

exports('GetCarriedWeight', function()
    return currentCarriedWeight or 0.0
end)

exports('GetMaxWeight', function()
    return Config.MaxWeight or 30.0
end)

exports('GetMaxOverweightLimit', function()
    return (Config.MaxWeight or 30.0) + (Config.MaxOverweightMargin or 5.0)
end)

exports('IsOverweight', function()
    return (currentCarriedWeight or 0.0) > (Config.MaxWeight or 30.0)
end)

exports('IsHardOverweight', function()
    return (currentCarriedWeight or 0.0) >= ((Config.MaxWeight or 30.0) + (Config.MaxOverweightMargin or 5.0))
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    StopInventoryAnimation()
    pcall(function()
        AnimpostfxStop("OJDominoBlur")
    end)
end)
