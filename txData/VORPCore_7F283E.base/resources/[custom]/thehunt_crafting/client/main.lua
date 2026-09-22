-- =================================================================
-- HUNT: Hard RP — Crafting System | Client Controller & NUI Bridge
-- =================================================================

local isCraftingOpen = false
local currentStation = "field"
local workbenchEntity = nil
local workbenchCoords = nil
local isTypingFocus = false

local isCraftAnimPlaying = false
local craftPropEntity = nil

-- =================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ЗАГРУЗКИ АНИМАЦИЙ И МОДЕЛЕЙ
-- =================================================================

local function LoadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 25 do
            Citizen.Wait(50)
            timeout = timeout + 1
        end
    end
    return HasAnimDictLoaded(dict)
end

local function LoadModel(modelHash)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 25 do
            Citizen.Wait(50)
            timeout = timeout + 1
        end
    end
    return HasModelLoaded(modelHash)
end

-- Предварительная загрузка моделей и словарей анимаций для мгновенного старта и завершения крафта
Citizen.CreateThread(function()
    RequestAnimDict("amb_work@world_human_hammer@table@male_a@base")
    RequestAnimDict("amb_work@world_human_hammer@table@male_a@idle_a")
    RequestAnimDict("amb_work@world_human_hammer@table@male_a@stand_exit")
    RequestAnimDict("amb_work@world_human_crouch_inspect@male_a@idle_a")
    RequestAnimDict("amb_work@world_human_crouch_inspect@male_a@idle_b")
    RequestAnimDict("amb_work@world_human_crouch_inspect@male_a@stand_exit")
    RequestModel(joaat("p_hammer01x"))
end)

-- =================================================================
-- АНИМАЦИИ КРАФТА (ПОЛЕВОЙ / ВЕРСТАК)
-- =================================================================

local function StopCraftingAnimation(immediate)
    if not isCraftAnimPlaying and not craftPropEntity then return end
    isCraftAnimPlaying = false

    local ped = PlayerPedId()

    if immediate or IsPedDeadOrDying(ped, true) then
        ClearPedTasksImmediately(ped)
        ClearPedSecondaryTask(ped)
        if craftPropEntity and DoesEntityExist(craftPropEntity) then
            DeleteEntity(craftPropEntity)
            craftPropEntity = nil
        end
        return
    end

    -- Удаляем пропс молотка
    if craftPropEntity and DoesEntityExist(craftPropEntity) then
        DeleteEntity(craftPropEntity)
        craftPropEntity = nil
    end

    -- Плавное завершение: проигрываем естественную анимацию вставания/выхода из позы
    if currentStation == "workbench" or currentStation == "anvil" then
        local exitDict = "amb_work@world_human_hammer@table@male_a@stand_exit"
        if LoadAnimDict(exitDict) then
            TaskPlayAnim(ped, exitDict, "exit_front", 3.0, 3.0, 1500, 0, 0, false, false, false)
        else
            ClearPedTasks(ped)
        end
    else
        local exitDict = "amb_work@world_human_crouch_inspect@male_a@stand_exit"
        if LoadAnimDict(exitDict) then
            TaskPlayAnim(ped, exitDict, "exit_front", 3.0, 3.0, 1500, 0, 0, false, false, false)
        else
            ClearPedTasks(ped)
        end
    end
end

local function StartCraftingAnimation(station)
    StopCraftingAnimation()
    isCraftAnimPlaying = true

    local ped = PlayerPedId()

    if station == "workbench" or station == "anvil" then
        -- Анимация активного стукания молотком по верстаку/наковальне
        local hammerModel = joaat("p_hammer01x")
        if LoadModel(hammerModel) then
            local pCoords = GetEntityCoords(ped)
            craftPropEntity = CreateObject(hammerModel, pCoords.x, pCoords.y, pCoords.z, true, true, false, false, false)
            if DoesEntityExist(craftPropEntity) then
                local boneIdx = GetEntityBoneIndexByName(ped, "SKEL_R_Hand")
                if boneIdx == -1 then boneIdx = 7966 end
                AttachEntityToEntity(craftPropEntity, ped, boneIdx, 0.08, -0.02, -0.02, -80.0, 0.0, 0.0, true, true, false, true, 1, true)
            end
            SetModelAsNoLongerNeeded(hammerModel)
        end

        local dict = "amb_work@world_human_hammer@table@male_a@base"
        if LoadAnimDict(dict) then
            TaskPlayAnim(ped, dict, "base", 3.0, 3.0, -1, 1, 0, false, false, false)
        else
            local fallbackDict = "amb_work@world_human_hammer@table@male_a@idle_a"
            if LoadAnimDict(fallbackDict) then
                TaskPlayAnim(ped, fallbackDict, "idle_a", 3.0, 3.0, -1, 1, 0, false, false, false)
            else
                TaskStartScenarioInPlace(ped, joaat("WORLD_HUMAN_HAMMER_TABLE"), -1, true, false, false, false)
            end
        end
    elseif station == "med_table" then
        -- Анимация работы за медицинским столом
        local dict = "amb_work@world_human_crouch_inspect@male_a@idle_a"
        if LoadAnimDict(dict) then
            TaskPlayAnim(ped, dict, "idle_a", 3.0, 3.0, -1, 1, 0, false, false, false)
        else
            TaskStartScenarioInPlace(ped, joaat("WORLD_HUMAN_STAND_WAITING"), -1, true, false, false, false)
        end
    elseif station == "furnace" then
        -- Анимация работы у плавильной печи
        local dict = "amb_work@world_human_crouch_inspect@male_a@idle_a"
        if LoadAnimDict(dict) then
            TaskPlayAnim(ped, dict, "idle_a", 3.0, 3.0, -1, 1, 0, false, false, false)
        else
            TaskStartScenarioInPlace(ped, joaat("WORLD_HUMAN_STAND_WAITING"), -1, true, false, false, false)
        end
    else
        -- Анимация полевого крафта (крафт руками на корточках)
        local dict = "amb_work@world_human_crouch_inspect@male_a@idle_a"
        if LoadAnimDict(dict) then
            TaskPlayAnim(ped, dict, "idle_a", 3.0, 3.0, -1, 1, 0, false, false, false)
        else
            local fallbackDict = "amb_work@world_human_crouch_inspect@male_a@idle_b"
            if LoadAnimDict(fallbackDict) then
                TaskPlayAnim(ped, fallbackDict, "idle_b", 3.0, 3.0, -1, 1, 0, false, false, false)
            else
                TaskStartScenarioInPlace(ped, joaat("WORLD_HUMAN_CROUCH_INSPECT"), -1, true, false, false, false)
            end
        end
    end
end

-- =================================================================
-- ОТКРЫТИЕ И ЗАКРЫТИЕ МЕНЮ КРАФТА
-- =================================================================

local function OpenCraftingUI(station, target)
    if isCraftingOpen then return end
    currentStation = station or "field"
    workbenchEntity = target and target.entity or nil
    if workbenchEntity and DoesEntityExist(workbenchEntity) then
        workbenchCoords = GetEntityCoords(workbenchEntity)
    elseif target and target.coords then
        workbenchCoords = target.coords
    else
        workbenchCoords = nil
    end

    isCraftingOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    pcall(function()
        AnimpostfxPlay("OJDominoBlur")
        AnimpostfxSetStrength("OJDominoBlur", 0.55)
    end)

    local title = (currentStation == "workbench") and "Верстак"
        or (currentStation == "campfire") and "Костёр"
        or (currentStation == "med_table") and "Медицинский стол"
        or (currentStation == "furnace") and "Плавильная печь"
        or (currentStation == "anvil") and "Наковальня"
        or "Полевое создание"
    local recipes = Crafting.GetRecipesForStation(currentStation)
    local allRecipes = Crafting.GetAllRecipes()
    local categories = Crafting.GetCategoriesForStation(currentStation)

    local itemDefs = {}
    if Items and Items.Registry then
        for name, it in pairs(Items.Registry) do
            itemDefs[name] = {
                label = it.label or name,
                description = it.description or "",
                rarity = (it.rarity == "yellow" and "purple") or it.rarity or "white",
                weight = it.weight or 0.1,
                icon = it.icon or name
            }
        end
    end

    SendNUIMessage({
        type = 'OPEN_CRAFTING',
        title = title,
        station = currentStation,
        categories = categories,
        recipes = recipes,
        allRecipes = allRecipes,
        inventory = {},
        itemDefs = itemDefs
    })

    TriggerServerEvent("thehunt_crafting:requestData", currentStation)
end

local function CloseCraftingUI()
    if not isCraftingOpen then return end
    isCraftingOpen = false
    workbenchEntity = nil
    workbenchCoords = nil
    isTypingFocus = false

    pcall(function()
        AnimpostfxStop("OJDominoBlur")
    end)

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_CRAFTING' })
end

local function ToggleCrafting(station)
    if IsNuiFocused() and not isCraftingOpen then
        return
    end

    if isCraftingOpen then
        CloseCraftingUI()
    else
        if not IsPauseMenuActive() then
            OpenCraftingUI(station or "field")
        end
    end
end

-- Регистрация команд и горячей клавиши J (Одиночное четкое нажатие)
RegisterCommand("thehunt_crafting_open", function() ToggleCrafting("field") end, false)
RegisterCommand("crafting", function() ToggleCrafting("field") end, false)
RegisterCommand("craft", function() ToggleCrafting("field") end, false)
RegisterCommand("craftmenu", function() ToggleCrafting("field") end, false)

if RegisterKeyMapping then
    pcall(RegisterKeyMapping, "thehunt_crafting_open", "Открыть / Закрыть полевое создание", "keyboard", "J")
end

-- =================================================================
-- ИНТЕГРАЦИЯ СО СТАНЦИЯМИ В МИРЕ (thehunt_interact)
-- =================================================================

local function RegisterCraftingInteractions()
    if not exports.thehunt_interact then return end

    -- 1. Верстаки (Workbench)
    local workbenchModels = {
        "p_workbench01x",
        "p_workbench02x",
        "p_workbenchdesk01x",
        joaat("p_workbench01x"),
        joaat("p_workbench02x"),
        -1283529219,
        0xB37EE5FD
    }

    exports.thehunt_interact:AddTargetModel(workbenchModels, {
        {
            id = "open_workbench_crafting",
            label = "Открыть",
            icon = "open",
            event = "thehunt_crafting:openWorkbench",
            action = function(target)
                OpenCraftingUI("workbench", target)
            end
        }
    }, 1.8)

    -- 2. Медицинский стол (s_desk01x)
    local medTableModels = {
        "s_desk01x",
        joaat("s_desk01x")
    }

    exports.thehunt_interact:AddTargetModel(medTableModels, {
        {
            id = "open_med_table_crafting",
            label = "Медицинский стол",
            icon = "medicine",
            event = "thehunt_crafting:openMedTable",
            action = function(target)
                OpenCraftingUI("med_table", target)
            end
        }
    }, 1.8)

    -- 3. Костёр (p_campfirecombined03x) - только одна кнопка: «Готовить»
    local campfireModels = {
        "p_campfirecombined03x",
        joaat("p_campfirecombined03x")
    }

    exports.thehunt_interact:AddTargetModel(campfireModels, {
        {
            id = "campfire_cook_combined",
            label = "Готовить",
            icon = "cook",
            event = "thehunt_crafting:openCampfire",
            action = function(target)
                OpenCraftingUI("campfire", target)
            end
        }
    }, 1.8)

    -- 4. Плавильная печь (p_breadoven01x)
    local furnaceModels = {
        "p_breadoven01x",
        joaat("p_breadoven01x")
    }

    exports.thehunt_interact:AddTargetModel(furnaceModels, {
        {
            id = "open_furnace_crafting",
            label = "Плавильная печь",
            icon = "ignite",
            event = "thehunt_crafting:openFurnace",
            action = function(target)
                OpenCraftingUI("furnace", target)
            end
        }
    }, 1.8)

    -- 5. Наковальня (p_anvil01x)
    local anvilModels = {
        "p_anvil01x",
        joaat("p_anvil01x")
    }

    exports.thehunt_interact:AddTargetModel(anvilModels, {
        {
            id = "open_anvil_crafting",
            label = "Наковальня",
            icon = "anvil",
            event = "thehunt_crafting:openAnvil",
            action = function(target)
                OpenCraftingUI("anvil", target)
            end
        }
    }, 1.8)
end

local RegisterWorkbenchInteractions = RegisterCraftingInteractions

RegisterNetEvent("thehunt_crafting:openWorkbench", function(targetInfo)
    OpenCraftingUI("workbench", targetInfo)
end)

RegisterNetEvent("thehunt_crafting:openMedTable", function(targetInfo)
    OpenCraftingUI("med_table", targetInfo)
end)

RegisterNetEvent("thehunt_crafting:openFurnace", function(targetInfo)
    OpenCraftingUI("furnace", targetInfo)
end)

RegisterNetEvent("thehunt_crafting:openAnvil", function(targetInfo)
    OpenCraftingUI("anvil", targetInfo)
end)

RegisterNetEvent("thehunt_crafting:openCampfire", function(targetInfo)
    OpenCraftingUI("campfire", targetInfo)
end)

RegisterNetEvent("thehunt_crafting:openStation", function(station, targetInfo)
    OpenCraftingUI(station or "field", targetInfo)
end)

RegisterNetEvent("thehunt_crafting:openFromInteract", function(targetInfo)
    OpenCraftingUI("workbench", targetInfo)
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    Citizen.Wait(500)
    RegisterCraftingInteractions()
end)

RegisterNetEvent("thehunt_interact:ready", function()
    RegisterCraftingInteractions()
end)

RegisterNetEvent("thehunt:character:selected", function()
    Citizen.Wait(1000)
    RegisterCraftingInteractions()
end)

-- =================================================================
-- NET EVENTS И NUI CALLBACKS
-- =================================================================

RegisterNetEvent("thehunt_crafting:updateInventoryCounts", function(inventoryCounts)
    if isCraftingOpen then
        SendNUIMessage({
            type = 'UPDATE_INVENTORY',
            inventory = inventoryCounts or {}
        })
    end
end)

RegisterNetEvent("thehunt_crafting:craftCheckResult", function(canCraft, errorMsg, queueSlotIndex)
    if not canCraft and errorMsg then
        TriggerEvent("thehunt_status:notify", "Создание", errorMsg, "warning")
    end
    if isCraftingOpen then
        SendNUIMessage({
            type = 'CRAFT_CHECK_RESULT',
            canCraft = canCraft,
            errorMsg = errorMsg,
            queueSlotIndex = queueSlotIndex
        })
    end
end)

RegisterNUICallback("close", function(data, cb)
    CloseCraftingUI()
    cb("ok")
end)

RegisterNUICallback("checkCanCraft", function(data, cb)
    TriggerServerEvent("thehunt_crafting:checkCanCraft", data.recipeId, data.amount, currentStation, data.queueSlotIndex)
    cb("ok")
end)

RegisterNUICallback("finishCraft", function(data, cb)
    TriggerServerEvent("thehunt_crafting:finishCraft", data.recipeId, data.amount, data.station or currentStation)
    cb("ok")
end)

RegisterNUICallback("setInputFocus", function(data, cb)
    isTypingFocus = data and data.focused == true
    cb("ok")
end)

RegisterNUICallback("startCraftingAnim", function(data, cb)
    StartCraftingAnimation(data.station or currentStation or "field")
    cb("ok")
end)

RegisterNUICallback("stopCraftingAnim", function(data, cb)
    StopCraftingAnimation()
    cb("ok")
end)

-- =================================================================
-- ПОТОК БЛОКИРОВКИ УПРАВЛЕНИЯ И АВТОЗАКРЫТИЯ
-- =================================================================

Citizen.CreateThread(function()
    while true do
        if isCraftingOpen or isCraftAnimPlaying then
            Citizen.Wait(0)
            local ped = PlayerPedId()

            -- Автозакрытие при гибели игрока
            if IsPedDeadOrDying(ped, true) then
                StopCraftingAnimation()
                CloseCraftingUI()
            end

            -- Автозакрытие станции при отдалении более 2.4 метров
            if currentStation ~= "field" and workbenchCoords then
                local dist = #(GetEntityCoords(ped) - workbenchCoords)
                if dist > 2.4 then
                    CloseCraftingUI()
                end
            end

            if isTypingFocus then
                -- 1. Фокус в поле ввода (например, ввод количества): полная блокировка всех клавиш
                for pad = 0, 2 do
                    DisableAllControlActions(pad)
                end
                DisablePlayerFiring(ped, true)

            elseif isCraftingOpen then
                -- 2. Меню крафта открыто (курсор в NUI):
                -- Камера игры зафиксирована и не крутится за мышкой, кнопки действий заблокированы
                for pad = 0, 2 do
                    DisableAllControlActions(pad)

                    -- Разрешаем голосовой чат
                    EnableControlAction(pad, 0xF1301666, true)
                    EnableControlAction(pad, 0x05CA7C52, true)
                    EnableControlAction(pad, 0x499D7970, true) -- INPUT_PUSH_TO_TALK
                end
                DisablePlayerFiring(ped, true)

            elseif isCraftAnimPlaying then
                -- 3. Меню ЗАКРЫТО, но крафт в процессе (непрерывная анимация):
                -- Персонаж выполняет анимацию (движение и удары заблокированы).
                -- Камеру разрешаем крутить ТОЛЬКО если курсор мыши не активен в интерфейсах (инвентарь, меню и т.д.)
                for pad = 0, 2 do
                    DisableAllControlActions(pad)

                    if not IsNuiFocused() then
                        -- Разрешаем управление камерой только когда никакой NUI-интерфейс (инвентарь и т.д.) не открыт
                        EnableControlAction(pad, 0xA987235F, true) -- INPUT_LOOK_LR
                        EnableControlAction(pad, 0xD2047988, true) -- INPUT_LOOK_UD
                        EnableControlAction(pad, 0x031B4D2B, true) -- INPUT_LOOK_UP_ONLY
                        EnableControlAction(pad, 0xFD2F56CE, true) -- INPUT_LOOK_DOWN_ONLY
                        EnableControlAction(pad, 0x2CD1A7B1, true) -- INPUT_LOOK_LEFT_ONLY
                        EnableControlAction(pad, 0x4296996F, true) -- INPUT_LOOK_RIGHT_ONLY
                    end

                    -- Разрешаем голосовой чат
                    EnableControlAction(pad, 0xF1301666, true)
                    EnableControlAction(pad, 0x05CA7C52, true)
                    EnableControlAction(pad, 0x499D7970, true) -- INPUT_PUSH_TO_TALK
                end
                DisablePlayerFiring(ped, true)
            end
        else
            Citizen.Wait(150)
        end
    end
end)

-- Очистка при остановке ресурса или выходе игрока
AddEventHandler("onResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end
    StopCraftingAnimation()
end)

AddEventHandler("onClientResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end
    StopCraftingAnimation()
end)

AddEventHandler("playerDropped", function()
    StopCraftingAnimation()
end)

-- Экспорты
exports('OpenCrafting', function(station)
    OpenCraftingUI(station)
end)

exports('CloseCrafting', function()
    CloseCraftingUI()
end)

exports('IsCraftingOpen', function()
    return isCraftingOpen
end)
