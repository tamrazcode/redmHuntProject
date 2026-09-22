-- =================================================================
-- Клиентское админ-меню
-- Все UI показываются ТОЛЬКО после выбора персонажа
-- Камера не крутится при открытых UI (включая на лошади, повозке, лодке)
-- NoClip: F1/DEL-выход, Shift - след. скорость, Alt - пред. скорость
-- =================================================================

local isMenuOpen = false
TheHunt_IsAdminMenuOpen = false
local isMMBPressed = false
local noclipActive = false
local noclipStopRequested = false
local noclipCam = nil
local noclipCamCoords = vector3(0.0, 0.0, 0.0)
local noclipCamRotX = 0.0
local noclipCamRotZ = 0.0
local noclipEntity = nil
local lastNoclipHudPush = 0

local noclipSpeedModes = {
    { speed = 0.08, label = "Ювелирная" },
    { speed = 0.25, label = "Черепашья" },
    { speed = 0.80, label = "Шаг" },
    { speed = 2.20, label = "Бег" },
    { speed = 5.50, label = "Рысь" },
    { speed = 12.0, label = "Галоп" },
    { speed = 28.0, label = "Молния" },
    { speed = 65.0, label = "Сверхзвук" },
}
local noclipSpeedIndex = 4 -- По умолчанию "Бег" (2.20 м/с)

local godmodeActive = false
local invisActive = false
local emptyWorldState = true
local playerIDsActive = false
local superJumpActive = false
local isCoordLaserActive = false
local freezeHungerActive = false
local freezeThirstActive = false
local freezeStaminaActive = false
local lastCoordsPush = 0
local isCharacterSelected = false
local isInputFocused = false

-- Полный режим неуязвимости игрока. Одного SetEntityInvincible недостаточно:
-- отдельные источники урона и другие ресурсы могут менять защиты ped обратно.
local function ApplyGodmodeState(enabled)
    local state = enabled == true
    local ped = PlayerPedId()

    SetPlayerInvincible(PlayerId(), state)

    if not DoesEntityExist(ped) or ped == 0 then return end

    SetEntityInvincible(ped, state)
    SetEntityCanBeDamaged(ped, not state)
    SetEntityProofs(ped, state, state, state, state, state, state, state, state)
    SetPedCanRagdoll(ped, not state)
    SetPedCanRagdollFromPlayerImpact(ped, not state)
end

-- Поддерживаем защиты каждый кадр: это не даёт урону/скриптам снять
-- бессмертие во время активного режима, включая смену ped после респавна.
Citizen.CreateThread(function()
    while true do
        if godmodeActive then
            ApplyGodmodeState(true)
            Citizen.Wait(0)
        else
            Citizen.Wait(250)
        end
    end
end)

-- thehunt_status может на короткое время быть недоступен во время restart.
-- Вызовы из админского freeze-потока не должны ломать остальные HUD и меню.
local function UpdateStatusMetabolism(hunger, thirst)
    pcall(function()
        exports['thehunt_status']:UpdateMetabolism(hunger, thirst)
    end)
end

local function GetStatusValueSafe(exportName, fallback)
    if GetResourceState('thehunt_status') ~= 'started' then
        return fallback
    end

    local ok, value = pcall(function()
        if exportName == 'GetPlayerHunger' then
            return exports['thehunt_status']:GetPlayerHunger()
        elseif exportName == 'GetPlayerThirst' then
            return exports['thehunt_status']:GetPlayerThirst()
        end
        return nil
    end)
    if not ok or tonumber(value) == nil then
        return fallback
    end
    return tonumber(value)
end

-- Экспорты stamina могут быть недоступны во время restart ресурса.
-- В таком случае админские действия продолжают работать через native-вызовы,
-- а отсутствие временного экспорта не создаёт ошибку в консоли.
local function SetCurrentStaminaSafe(value)
    if GetResourceState('thehunt_stamina') ~= 'started' then return false end
    local ok = pcall(function()
        exports['thehunt_stamina']:SetCurrentStamina(value)
    end)
    return ok
end

local function SetFreezeStaminaSafe(frozen)
    if GetResourceState('thehunt_stamina') ~= 'started' then return false end
    local ok = pcall(function()
        exports['thehunt_stamina']:SetFreezeStamina(frozen)
    end)
    return ok
end

-- Эффекты статус-HUD передаются событиями: это безопасно даже если status
-- кратковременно перезапускается и его export API ещё не успел загрузиться.
local function AddStatusEffectSafe(effectData)
    if GetResourceState('thehunt_status') ~= 'started' then return false end
    TriggerEvent('thehunt_status:addEffect', effectData)
    return true
end

local function RemoveStatusEffectSafe(effectId)
    if GetResourceState('thehunt_status') ~= 'started' then return false end
    TriggerEvent('thehunt_status:removeEffect', effectId)
    return true
end

-- Проверка готовности персонажа
local function CheckAdminCharacterLoaded()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) and ped ~= 0 then
        isCharacterSelected = true
        SendNUIMessage({ type = 'CHARACTER_SELECTED' })
        return true
    end
    return false
end

RegisterNetEvent("vorp:SelectedCharacter", function()
    isCharacterSelected = true
    SendNUIMessage({ type = 'CHARACTER_SELECTED' })
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    isMenuOpen = false
    TheHunt_IsAdminMenuOpen = false
    isMMBPressed = false
    isInputFocused = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_ADMIN_MENU' })
    CheckAdminCharacterLoaded()
    TriggerServerEvent("thehunt_admin:requestEmptyWorldState")
end)

Citizen.CreateThread(function()
    while true do
        if not isCharacterSelected then
            if CheckAdminCharacterLoaded() then
                break
            end
            Citizen.Wait(500)
        else
            break
        end
    end
end)

-- Передаём админ-панели редкий снимок локальных показателей: hunger/thirst
-- существуют на клиенте status HUD и не доступны серверу напрямую.
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)

        local ped = PlayerPedId()
        if isCharacterSelected and DoesEntityExist(ped) and ped ~= 0 then
            local maxHealth = GetEntityMaxHealth(ped)
            if not maxHealth or maxHealth <= 0 then maxHealth = 100 end

            local health = math.max(0, tonumber(GetEntityHealth(ped)) or maxHealth)
            local healthPercent = math.max(0, math.min(100, (health / maxHealth) * 100))
            local hunger = math.max(0, math.min(100, GetStatusValueSafe('GetPlayerHunger', 100)))
            local thirst = math.max(0, math.min(100, GetStatusValueSafe('GetPlayerThirst', 100)))

            TriggerServerEvent('thehunt_admin:reportPlayerStats', {
                health = health,
                maxHealth = maxHealth,
                healthPercent = healthPercent,
                hunger = hunger,
                thirst = thirst
            })
        end
    end
end)

exports('isCharacterReady', function()
    return isCharacterSelected or (DoesEntityExist(PlayerPedId()) and PlayerPedId() ~= 0)
end)

-- Функция открытия / закрытия админ-панели
local lastToggleTime = 0
local function ToggleAdminMenu()
    local now = GetGameTimer()
    if now - lastToggleTime < 300 then return end
    lastToggleTime = now

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or ped == 0 then return end

    if isMenuOpen then
        isMenuOpen = false
        TheHunt_IsAdminMenuOpen = false
        isMMBPressed = false
        isInputFocused = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CLOSE_ADMIN_MENU' })
        return
    end
    TriggerServerEvent("thehunt_admin:checkPermissionAndOpen")
end

-- Forward declarations для функций NoClip (видимость во всём файле)
local StartNoClip = nil
local StopNoClip = nil

-- Функция переключения NoClip с серверной проверкой прав
local lastNoClipToggleTime = 0
local noclipTogglePending = false
local noclipTogglePendingUntil = 0
local function RequestToggleNoClip()
    -- Выключение должно срабатывать сразу, как Backspace, даже если F1
    -- нажали вскоре после включения режима.
    if noclipActive then
        noclipTogglePending = false
        noclipTogglePendingUntil = 0
        -- Backspace останавливает режим внутри его же цикла. F1 тоже
        -- передаём туда, чтобы цикл не успел повторно заморозить педа.
        noclipStopRequested = true
        return
    end

    local now = GetGameTimer()
    -- Не оставляем старый запрос на включение активным после повторного F1.
    -- Иначе запоздалый ответ сервера мог включить NoClip уже после выхода.
    if noclipTogglePending then
        if now <= noclipTogglePendingUntil then
            noclipTogglePending = false
            noclipTogglePendingUntil = 0
            return
        end
        noclipTogglePending = false
        noclipTogglePendingUntil = 0
    end

    if now - lastNoClipToggleTime < 350 then return end
    lastNoClipToggleTime = now

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or ped == 0 then return end

    noclipTogglePending = true
    noclipTogglePendingUntil = now + 1500
    TriggerServerEvent("thehunt_admin:checkPermissionAndToggleNoClip")
end

RegisterNetEvent("thehunt_admin:confirmToggleNoClip", function()
    local now = GetGameTimer()
    if not noclipTogglePending or now > noclipTogglePendingUntil then
        noclipTogglePending = false
        noclipTogglePendingUntil = 0
        return
    end

    noclipTogglePending = false
    noclipTogglePendingUntil = 0
    if not noclipActive then
        StartNoClip()
    end
end)

-- Регистрация команд
RegisterCommand("adminmenu", ToggleAdminMenu, false)
RegisterCommand("am", ToggleAdminMenu, false)
RegisterCommand("admin", ToggleAdminMenu, false)
RegisterCommand("adm", ToggleAdminMenu, false)
RegisterCommand("a", ToggleAdminMenu, false)
RegisterCommand("panel", ToggleAdminMenu, false)
RegisterCommand("noclip", function() RequestToggleNoClip() end, false)
RegisterCommand("nc", function() RequestToggleNoClip() end, false)
RegisterCommand("hunt_toggle_noclip", function() RequestToggleNoClip() end, false)

-- Привязка клавиши F4 для админ-панели
RegisterKeyMapping("adminmenu", "Админ-панель HUNT", "keyboard", "F4")

-- Привязка клавиши F1 для NoClip админ-панели
RegisterKeyMapping("hunt_toggle_noclip", "Включить/Выключить NoClip (HUNT Admin)", "keyboard", "F1")

RegisterNetEvent("thehunt_core:openAdminMenu", function()
    ToggleAdminMenu()
end)

-- Клавиши открытия панели: ТОЛЬКО F4
local AdminOpenControls = {
    0x1F6D95E5, -- F4
}

-- NUI колбэк для вращения камеры на СКМ
RegisterNUICallback('setCameraRotationState', function(data, cb)
    isMMBPressed = (data.active == true)
    if isMMBPressed then
        fixedCamHeading = GetGameplayCamRelativeHeading()
        fixedCamPitch = GetGameplayCamRelativePitch()
    end
    cb('ok')
end)

-- NUI колбэк фокуса в текстовых полях
RegisterNUICallback('setAdminInputFocus', function(data, cb)
    isInputFocused = (data and data.focused == true)
    if isMenuOpen then
        SetNuiFocusKeepInput(not isInputFocused)
    end
    cb('ok')
end)

-- Главный цикл: клавиши, камера, SuperJump
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local ped = PlayerPedId()
        local isReady = DoesEntityExist(ped) and ped ~= 0

        if not isCharacterSelected and isReady then
            isCharacterSelected = true
            SendNUIMessage({ type = 'CHARACTER_SELECTED' })
        end

        if isReady then
            -- Открытие админ-панели СТРОГО на клавишу F4
            if IsControlJustPressed(0, 0x1F6D95E5) or IsDisabledControlJustPressed(0, 0x1F6D95E5) then
                ToggleAdminMenu()
            end

            -- DEL (0x4AF4D473): если NoClip включён — безопасно выключить его
            if IsControlJustPressed(0, 0x4AF4D473) or IsDisabledControlJustPressed(0, 0x4AF4D473) then
                if noclipActive then
                    StopNoClip()
                end
            end

            -- SuperJump
            if superJumpActive then
                SetSuperJumpThisFrame(PlayerId())
            end

            -- Блокировка камеры и управления при открытом меню
            if isMenuOpen then
                DisableAllControlActions(0)
                DisableAllControlActions(1)
                DisableAllControlActions(2)

                local allowedControls = {
                    -- Войс-чат
                    `INPUT_PUSH_TO_TALK`,
                    0xF1301666,
                    0x05CA7C52,

                    -- Движение пешком (WASD, Shift, Space, Ctrl)
                    `INPUT_MOVE_LR`,
                    `INPUT_MOVE_UD`,
                    `INPUT_MOVE_UP_ONLY`,
                    `INPUT_MOVE_DOWN_ONLY`,
                    `INPUT_MOVE_LEFT_ONLY`,
                    `INPUT_MOVE_RIGHT_ONLY`,
                    `INPUT_SPRINT`,
                    `INPUT_JUMP`,
                    `INPUT_CLIMB`,
                    `INPUT_DUCK`,

                    -- Движение на лошади (WASD, Shift, Space, Ctrl)
                    `INPUT_HORSE_MOVE_UD`,
                    `INPUT_HORSE_MOVE_LR`,
                    `INPUT_HORSE_MOVE_UP_ONLY`,
                    `INPUT_HORSE_MOVE_DOWN_ONLY`,
                    `INPUT_HORSE_MOVE_LEFT_ONLY`,
                    `INPUT_HORSE_MOVE_RIGHT_ONLY`,
                    `INPUT_HORSE_SPRINT`,
                    `INPUT_HORSE_JUMP`,
                    `INPUT_HORSE_STOP`,

                    -- Управление повозками
                    `INPUT_VEH_ACCELERATE`,
                    `INPUT_VEH_BRAKE`,
                    `INPUT_VEH_MOVE_LR`,
                    `INPUT_VEH_HANDBRAKE`,

                    -- Числовые хэши RDR2 на случай нестандартных названий
                    0x4D8FB4C1, -- MOVE_LR
                    0xEDA4707E, -- MOVE_UD
                    0x8FD015D8, -- MOVE_UD (RDR2)
                    0xD27782E3, -- MOVE_UP_ONLY (W)
                    0x7065027D, -- MOVE_DOWN_ONLY (S)
                    0xB4E465B4, -- MOVE_LEFT_ONLY (A)
                    0x399C6619, -- MOVE_RIGHT_ONLY (D)
                    0x8FFC75D0, -- SPRINT (Shift)
                    0x2C4B7E05, -- SPRINT_ALT
                    0xD42E6C65, -- JUMP (Space)
                    0x9330C873, -- CLIMB (Space)
                    0xDB096B85, -- DUCK (Ctrl)
                    0x78564D7B, -- DUCK_ALT
                    0x82CA7BA9, -- HORSE_MOVE_UD
                    0x227DCC40, -- HORSE_MOVE_LR
                    0xE95F4F0C, -- HORSE_MOVE_UP_ONLY (W)
                    0x866B5DB8, -- HORSE_MOVE_DOWN_ONLY (S)
                    0x51E13F58, -- HORSE_MOVE_LEFT_ONLY (A)
                    0xC229CF67, -- HORSE_MOVE_RIGHT_ONLY (D)
                    0x54182BC1, -- HORSE_SPRINT (Shift)
                    0x63A38928, -- HORSE_JUMP (Space)
                    0xD2315E39, -- HORSE_CLIMB (Space)
                    0x153A478C  -- HORSE_STOP (Ctrl)
                }

                for pad = 0, 2 do
                    for i = 1, #allowedControls do
                        EnableControlAction(pad, allowedControls[i], true)
                    end
                end
            end
        else
            Citizen.Wait(250)
        end
    end
end)

-- Сервер подтвердил права и открывает меню
RegisterNetEvent("thehunt_admin:openMenuClient", function()
    isCharacterSelected = true
    isMenuOpen = true
    TheHunt_IsAdminMenuOpen = true
    isMMBPressed = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    local isBlipsOn = false
    if exports['thehunt_core'] and exports['thehunt_core'].isAdminBlipsActive then
        isBlipsOn = exports['thehunt_core']:isAdminBlipsActive()
    end

    SendNUIMessage({
        type = 'OPEN_ADMIN_MENU',
        state = {
            noclip = noclipActive,
            godmode = godmodeActive,
            invis = invisActive,
            adminBlips = isBlipsOn,
            emptyWorld = emptyWorldState,
            playerIDs = playerIDsActive,
            superJump = superJumpActive,
            coordLaser = isCoordLaserActive,
            freezeHunger = freezeHungerActive,
            freezeThirst = freezeThirstActive,
            freezeStamina = freezeStaminaActive
        }
    })
end)

-- Закрытие из NUI
RegisterNUICallback('closeAdminMenu', function(data, cb)
    isMenuOpen = false
    TheHunt_IsAdminMenuOpen = false
    isMMBPressed = false
    isInputFocused = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cb('ok')
end)

-- Запрос списка игроков
RegisterNUICallback('requestPlayersList', function(data, cb)
    TriggerServerEvent("thehunt_admin:getPlayersForMenu")
    cb('ok')
end)

-- Обновляем список игроков во время открытой панели, но без постоянного опроса.
Citizen.CreateThread(function()
    while true do
        if isMenuOpen then
            TriggerServerEvent("thehunt_admin:getPlayersForMenu")
            Citizen.Wait(2500)
        else
            Citizen.Wait(1000)
        end
    end
end)

-- Запрос истории конкретного игрока из панели администратора
RegisterNUICallback('requestPlayerLogs', function(data, cb)
    local targetId = tonumber(data and data.playerId)
    local query = data and data.query or ""
    local offset = tonumber(data and data.offset) or 0
    local limit = tonumber(data and data.limit) or 100
    local requestId = tonumber(data and data.requestId) or 0
    local snapshotId = tonumber(data and data.snapshotId) or 0
    local dateFrom = tostring(data and data.dateFrom or "")
    local dateTo = tostring(data and data.dateTo or "")
    if targetId then
        TriggerServerEvent("thehunt_admin:getPlayerLogs", targetId, tostring(query), offset, limit, requestId, snapshotId, dateFrom, dateTo)
    end
    cb('ok')
end)

RegisterNetEvent("thehunt_admin:receivePlayersForMenu", function(players)
    SendNUIMessage({
        type = 'SET_PLAYERS_LIST',
        players = players
    })
end)

RegisterNetEvent("thehunt_admin:receivePlayerLogs", function(payload)
    SendNUIMessage({
        type = 'SET_PLAYER_LOGS',
        data = payload or {}
    })
end)

RegisterNetEvent("thehunt_admin:refreshPlayersList", function()
    TriggerServerEvent("thehunt_admin:getPlayersForMenu")
end)

-- Безопасная посадка на землю (защита от проваливания под текстуры/карту)
function EnsureSafeGroundPosition(ped, coords)
    if not ped or not DoesEntityExist(ped) then return end
    local x = coords and coords.x or GetEntityCoords(ped).x
    local y = coords and coords.y or GetEntityCoords(ped).y
    local z = coords and coords.z or GetEntityCoords(ped).z

    RequestCollisionAtCoord(x, y, z)
    Citizen.Wait(50)

    -- Ищем только поверхность под текущей точкой. Поверхность выше игрока
    -- или дальше пяти метров не должна считаться местом посадки.
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 0.25, false)
    if not found or type(groundZ) ~= "number" then
        found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, z + 0.25)
    end

    local distanceToGround = type(groundZ) == "number" and (z - groundZ) or nil
    if found and type(groundZ) == "number" and distanceToGround >= 0.0 and distanceToGround <= 5.0 then
        SetEntityCoords(ped, x, y, groundZ + 0.95, false, false, false, false)
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        return true
    end
    return false
end

-- =================================================================
-- БЕЗОПАСНЫЙ СВОБОДНЫЙ ПОЛЁТ (NOCLIP) НА СКРИПТОВОЙ КАМЕРЕ
-- =================================================================
StartNoClip = function()
    if noclipActive then return end
    noclipStopRequested = false
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- Если админ-меню открыто — закрываем его и убираем NUI-фокус
    if isMenuOpen then
        isMenuOpen = false
        isMMBPressed = false
        isInputFocused = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CLOSE_ADMIN_MENU' })
    end

    -- Проверяем верхом ли админ на лошади или в повозке
    local mount = GetMount(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if mount and mount ~= 0 and DoesEntityExist(mount) then
        noclipEntity = mount
    elseif veh and veh ~= 0 and DoesEntityExist(veh) then
        noclipEntity = veh
    else
        noclipEntity = ped
    end

    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    noclipCamCoords = camCoords
    noclipCamRotX = camRot.x
    noclipCamRotZ = camRot.z

    noclipCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, camRot.x, 0.0, camRot.z, GetGameplayCamFov(), true, 2)
    SetCamActive(noclipCam, true)
    RenderScriptCams(true, false, 0, true, true)

    noclipActive = true

    FreezeEntityPosition(noclipEntity, true)
    SetEntityCollision(noclipEntity, false, false)
    SetEntityInvincible(noclipEntity, true)
    SetEntityVisible(noclipEntity, false)
    SetEveryoneIgnorePlayer(PlayerId(), true)
    SetPedCanRagdoll(ped, false)
    SetRagdollBlockingFlags(ped, 511)
    ClearPedTasksImmediately(ped)

    if noclipEntity ~= ped then
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        SetEntityVisible(ped, false)
    end

    SendNUIMessage({ type = 'UPDATE_STATE', state = { noclip = true } })
    SendNUIMessage({ type = 'SET_NOCLIP_VISIBLE', active = true })
    AddStatusEffectSafe({ id = 'admin_noclip' })
    print("^2[HUNT ADMIN] Режим NoClip успешно активирован!^7")
end

StopNoClip = function()
    if not noclipActive then return end
    noclipActive = false
    noclipStopRequested = false

    local finalCoords = noclipCamCoords
    local finalHeading = noclipCamRotZ

    -- 1. Сначала удаляем камеру и отдаём управление рендера геймплейной камере
    if noclipCam and DoesCamExist(noclipCam) then
        finalCoords = GetCamCoord(noclipCam)
        local rot = GetCamRot(noclipCam, 2)
        finalHeading = rot.z
        SetCamActive(noclipCam, false)
        DestroyCam(noclipCam, false)
        DestroyAllCams(true)
        noclipCam = nil
    end

    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()

    local ped = PlayerPedId()
    local entity = noclipEntity or ped

    -- 2. Размораживаем сущность и восстанавливаем коллизии и физику
    FreezeEntityPosition(entity, false)
    SetEntityCollision(entity, true, true)
    SetEntityInvincible(entity, godmodeActive)
    SetEntityVisible(entity, not invisActive, false)
    SetEntityAlpha(entity, invisActive and 0 or 255, false)
    SetEntityHasGravity(entity, true)
    SetPedCanRagdoll(ped, true)
    ClearRagdollBlockingFlags(ped, 511)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    ClearPedTasksImmediately(ped)

    if entity ~= ped then
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetEntityVisible(ped, not invisActive, false)
        SetEntityAlpha(ped, invisActive and 0 or 255, false)
    end

    SetEntityHeading(entity, finalHeading)
    SetFocusEntity(ped)

    -- Сбрасываем NUI-фокус
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    isMenuOpen = false
    isMMBPressed = false
    isInputFocused = false

    -- Гарантированное включение управления камерой
    for pad = 0, 2 do
        EnableControlAction(pad, 0xA987235F, true) -- INPUT_LOOK_LR
        EnableControlAction(pad, 0xD2047988, true) -- INPUT_LOOK_UD
        EnableControlAction(pad, `INPUT_LOOK_LR`, true)
        EnableControlAction(pad, `INPUT_LOOK_UD`, true)
    end

    -- NoClip завершается в точной точке камеры. Ниже будет выполнена
    -- ограниченная проверка земли: только строго снизу и не дальше 5 метров.
    SetEntityCoords(entity, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false, false)
    SetEntityVelocity(entity, 0.0, 0.0, 0.0)
    if entity ~= ped then
        SetEntityCoords(ped, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false, false)
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    end
    EnsureSafeGroundPosition(entity, finalCoords)
    noclipEntity = nil

    SendNUIMessage({ type = 'UPDATE_STATE', state = { noclip = false } })
    SendNUIMessage({ type = 'SET_NOCLIP_VISIBLE', active = false })
    RemoveStatusEffectSafe('admin_noclip')
    print("^3[HUNT ADMIN] Режим NoClip выключен, позиция персонажа сохранена.^7")
end

function ToggleNoClip()
    if not isCharacterSelected then return end
    if noclipActive then
        StopNoClip()
    else
        StartNoClip()
    end
end

exports('isNoClipActive', function() return noclipActive end)
exports('toggleNoClip', function() ToggleNoClip() end)

-- Спавн лошади
local function SpawnHorseDirectly(modelName)
    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end

    if HasModelLoaded(modelHash) then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        local horse = CreatePed(modelHash, coords.x + 1.5, coords.y + 1.5, coords.z, heading, true, false, false, false)
        Citizen.InvokeNative(0x283978A15512B2FE, horse, true)
        Citizen.InvokeNative(0xD4EEA104F4A59302, horse, GetHashKey("saddle_01"), 0, 0, 0, 0)
        SetEntityAsMissionEntity(horse, true, true)
        SetPedCanRagdoll(horse, true)
        TaskWarpPedIntoVehicle(ped, horse, -1)
        SetModelAsNoLongerNeeded(modelHash)
        print("^2[HUNT ADMIN] Лошадь успешно создана: " .. tostring(modelName) .. "^7")
    else
        print("^1[HUNT ADMIN] Ошибка загрузки модели лошади: " .. tostring(modelName) .. "^7")
    end
end

-- Спавн повозки/транспорта
local function SpawnWagonDirectly(modelName)
    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end

    if HasModelLoaded(modelHash) then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        local wagon = CreateVehicle(modelHash, coords.x + 3.0, coords.y + 3.0, coords.z, heading, true, false, false, false)
        SetEntityAsMissionEntity(wagon, true, true)
        TaskWarpPedIntoVehicle(ped, wagon, -1)
        SetModelAsNoLongerNeeded(modelHash)
        print("^2[HUNT ADMIN] Транспорт успешно создан: " .. tostring(modelName) .. "^7")
    else
        print("^1[HUNT ADMIN] Ошибка загрузки модели транспорта: " .. tostring(modelName) .. "^7")
    end
end

-- Спавн лодки
local function SpawnBoatDirectly(modelName)
    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end

    if HasModelLoaded(modelHash) then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        local boat = CreateVehicle(modelHash, coords.x + 3.0, coords.y + 3.0, coords.z, heading, true, false, false, false)
        SetEntityAsMissionEntity(boat, true, true)
        TaskWarpPedIntoVehicle(ped, boat, -1)
        SetModelAsNoLongerNeeded(modelHash)
        print("^2[HUNT ADMIN] Лодка успешно создана: " .. tostring(modelName) .. "^7")
    else
        print("^1[HUNT ADMIN] Ошибка загрузки модели лодки: " .. tostring(modelName) .. "^7")
    end
end

-- Отрисовка 2D HUD текста
local function Draw2DText(text, x, y, scale)
    local textStr = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextScale(scale or 0.35, scale or 0.35)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 235)
    SetTextDropshadow(2, 0, 0, 0, 255)
    DisplayText(textStr, x, y)
end

-- Телепорт с лошадью/транспортом и гарантированной подгрузкой коллизии
local function TeleportWithVehicle(x, y, z)
    local ped = PlayerPedId()
    local mount = GetMount(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    local targetEntity = ped

    if mount ~= 0 and DoesEntityExist(mount) then
        targetEntity = mount
    elseif veh ~= 0 and DoesEntityExist(veh) then
        targetEntity = veh
    end

    RequestCollisionAtCoord(x, y, z)
    FreezeEntityPosition(targetEntity, true)
    SetEntityCoords(targetEntity, x, y, z + 0.3, false, false, false, false)

    Citizen.CreateThread(function()
        local timeout = 0
        while not HasCollisionLoadedAroundEntity(targetEntity) and timeout < 25 do
            Citizen.Wait(100)
            timeout = timeout + 1
        end
        FreezeEntityPosition(targetEntity, false)
        SetEntityCollision(targetEntity, true, true)
        ActivatePhysics(targetEntity)
        SetEntityVelocity(targetEntity, 0.0, 0.0, -0.05)
    end)
end

-- Обработка ВСЕХ действий админ-панели
RegisterNUICallback('adminAction', function(data, cb)
    local action = data.action
    local ped = PlayerPedId()

    if action == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        Citizen.InvokeNative(0xC6258F41D86676E0, PlayerId(), 0, 100)
        TriggerEvent("vorp_medic:heal")
        TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
        TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
        print("^2[HUNT ADMIN] Здоровье, ядра и выносливость восстановлены!^7")

    elseif action == 'metabolism' then
        TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
        TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
        print("^2[HUNT ADMIN] Метаболизм (голод и жажда) заполнен на 100%!^7")

    elseif action == 'toggleNoclip' then
        ToggleNoClip()

    elseif action == 'toggleGodmode' then
        godmodeActive = not godmodeActive
        ApplyGodmodeState(godmodeActive)
        SendNUIMessage({ type = 'UPDATE_STATE', state = { godmode = godmodeActive } })
        if godmodeActive then
            AddStatusEffectSafe({ id = 'admin_godmode' })
        else
            RemoveStatusEffectSafe('admin_godmode')
        end

    elseif action == 'toggleInvis' then
        invisActive = not invisActive
        SetEntityVisible(ped, not invisActive)
        SendNUIMessage({ type = 'UPDATE_STATE', state = { invis = invisActive } })
        if invisActive then
            AddStatusEffectSafe({ id = 'admin_invis' })
        else
            RemoveStatusEffectSafe('admin_invis')
        end

    elseif action == 'toggleSuperJump' then
        superJumpActive = not superJumpActive
        SendNUIMessage({ type = 'UPDATE_STATE', state = { superJump = superJumpActive } })
        if superJumpActive then
            AddStatusEffectSafe({ id = 'admin_superjump' })
        else
            RemoveStatusEffectSafe('admin_superjump')
        end

    elseif action == 'toggleFreezeHunger' then
        freezeHungerActive = not freezeHungerActive
        SendNUIMessage({ type = 'UPDATE_STATE', state = { freezeHunger = freezeHungerActive } })
        if freezeHungerActive then
            TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
            UpdateStatusMetabolism(1000, nil)
        end
        if freezeHungerActive then
            AddStatusEffectSafe({ id = 'admin_freeze_hunger' })
        else
            RemoveStatusEffectSafe('admin_freeze_hunger')
        end

    elseif action == 'toggleFreezeThirst' then
        freezeThirstActive = not freezeThirstActive
        SendNUIMessage({ type = 'UPDATE_STATE', state = { freezeThirst = freezeThirstActive } })
        if freezeThirstActive then
            TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
            UpdateStatusMetabolism(nil, 1000)
        end
        if freezeThirstActive then
            AddStatusEffectSafe({ id = 'admin_freeze_thirst' })
        else
            RemoveStatusEffectSafe('admin_freeze_thirst')
        end

    elseif action == 'toggleFreezeStamina' then
        freezeStaminaActive = not freezeStaminaActive
        SendNUIMessage({ type = 'UPDATE_STATE', state = { freezeStamina = freezeStaminaActive } })
        if freezeStaminaActive then
            RestorePlayerStamina(PlayerId(), 1.0)
            Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 1, 100.0)
            Citizen.InvokeNative(0xFE765D8B62B8C448, PlayerPedId(), 1, 100.0)
            Citizen.InvokeNative(0x675680D08A22FC21, PlayerPedId(), 100.0)
        end
        if freezeStaminaActive then
            AddStatusEffectSafe({ id = 'admin_freeze_stamina' })
        else
            RemoveStatusEffectSafe('admin_freeze_stamina')
        end
        SetFreezeStaminaSafe(freezeStaminaActive)

    elseif action == 'toggleEmptyWorld' then
        emptyWorldState = not emptyWorldState
        TriggerServerEvent("thehunt_admin:toggleEmptyWorldServer", emptyWorldState)
        TriggerEvent("thehunt_admin:togglePopulation", emptyWorldState)
        SendNUIMessage({ type = 'UPDATE_STATE', state = { emptyWorld = emptyWorldState } })

    elseif action == 'openZombieEditor' then
        if GetResourceState('thehunt_zombie') == 'started' then
            isMenuOpen = false
            isMMBPressed = false
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            SendNUIMessage({ type = 'CLOSE_ADMIN_MENU' })
            TriggerEvent('thehunt_zombie:openEditor')
        end
    elseif action == 'toggleZombieInfo' then
        TriggerEvent('thehunt_zombie:toggleInfo')
    elseif action == 'toggleZombieImmunity' then
        TriggerEvent('thehunt_zombie:toggleImmunity')

    elseif action == 'togglePlayerIDs' then
        playerIDsActive = not playerIDsActive
        TriggerEvent("thehunt_admin:togglePlayerIDs")
        SendNUIMessage({ type = 'UPDATE_STATE', state = { playerIDs = playerIDsActive } })
        if playerIDsActive then
            AddStatusEffectSafe({ id = 'admin_player_ids' })
        else
            RemoveStatusEffectSafe('admin_player_ids')
        end

    elseif action == 'toggleCoordLaser' then
        isCoordLaserActive = not isCoordLaserActive
        SendNUIMessage({
            type = 'SET_COORD_LASER_VISIBLE',
            active = isCoordLaserActive
        })
        SendNUIMessage({ type = 'UPDATE_STATE', state = { coordLaser = isCoordLaserActive } })
        if isCoordLaserActive then
            AddStatusEffectSafe({ id = 'admin_laser' })
        else
            RemoveStatusEffectSafe('admin_laser')
        end

    elseif action == 'reviveSelf' then
        -- vorp_admin is intentionally disabled on this server. Route self
        -- revive through the HUNT admin permission check and the same VORP /
        -- thehunt_death bridge used for a selected target.
        TriggerServerEvent("thehunt_admin:reviveTarget")

    elseif action == 'cleanArea' then
        local coords = GetEntityCoords(ped)
        local peds = GetGamePool('CPed')
        for _, p in ipairs(peds) do
            if DoesEntityExist(p) and not IsPedAPlayer(p) and p ~= ped then
                DeleteEntity(p)
            end
        end
        local vehs = GetGamePool('CVehicle')
        for _, v in ipairs(vehs) do
            if DoesEntityExist(v) and #(coords - GetEntityCoords(v)) < 50.0 then
                DeleteEntity(v)
            end
        end
        print("^2[HUNT ADMIN] Зона в радиусе 50м очищена!^7")

    -- Лошади
    elseif action == 'spawnHorseTurkoman' then
        SpawnHorseDirectly("a_c_horse_turkoman_gold")
    elseif action == 'spawnHorseArabian' then
        SpawnHorseDirectly("a_c_horse_arabian_white")
    elseif action == 'spawnHorseMustang' then
        SpawnHorseDirectly("a_c_horse_mustang_grullodun")
    elseif action == 'spawnHorseMissouri' then
        SpawnHorseDirectly("a_c_horse_missourifoxtrotter_dapplegrey")
    elseif action == 'spawnHorseAndalusian' then
        SpawnHorseDirectly("a_c_horse_andalusian_darkbay")
    elseif action == 'spawnHorseShire' then
        SpawnHorseDirectly("a_c_horse_shire_darkbay")
    elseif action == 'spawnHorseNokota' then
        SpawnHorseDirectly("a_c_horse_nokota_reversedappleroan")
    elseif action == 'spawnHorseAppaloosa' then
        SpawnHorseDirectly("a_c_horse_appaloosa_blanket")
    elseif action == 'spawnHorseKentucky' then
        SpawnHorseDirectly("a_c_horse_kentuckysaddle_grey")
    elseif action == 'spawnHorseThoroughbred' then
        SpawnHorseDirectly("a_c_horse_thoroughbred_brindle")

    -- Транспорт
    elseif action == 'spawnWagonHunting' then
        SpawnWagonDirectly("huntercart01")
    elseif action == 'spawnWagonCoach' then
        SpawnWagonDirectly("coach2")
    elseif action == 'spawnWagonOpen' then
        SpawnWagonDirectly("wagon02x")
    elseif action == 'spawnWagonPrison' then
        SpawnWagonDirectly("policewagon01x")
    elseif action == 'spawnWagonSupply' then
        SpawnWagonDirectly("ArmySupplyWagon")
    elseif action == 'spawnWagonChuckwagon' then
        SpawnWagonDirectly("chuckwagon000x")

    -- Лодки
    elseif action == 'spawnBoatRowboat' then
        SpawnBoatDirectly("rowboat")
    elseif action == 'spawnBoatCanoe' then
        SpawnBoatDirectly("canoe")
    elseif action == 'spawnBoatSteamboat' then
        SpawnBoatDirectly("boatsteam02x")
    elseif action == 'spawnBoatKeelboat' then
        SpawnBoatDirectly("keelboat")

    -- Восстановление выносливости
    elseif action == 'refillStamina' then
        RestorePlayerStamina(PlayerId(), 1.0)
        pcall(function()
            Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100) -- Stamina inner core
            Citizen.InvokeNative(0x675680D08A22FC21, ped, 100.0) -- Stamina outer tank
        end)
        SetCurrentStaminaSafe(100.0)
        print("^2[HUNT ADMIN] Выносливость полностью восстановлена на 100%!^7")

    -- Восстановление еды и воды (метаболизма)
    elseif action == 'refillMetabolism' then
        TriggerServerEvent("thehunt_admin:refillMetabolism")
        print("^2[HUNT ADMIN] Еда и вода восстановлены на 100%!^7")

    -- Редактор дверей и домов
    elseif action == 'openDoorAdmin' then
        ToggleAdminMenu()
        ExecuteCommand("dooradmin")

    -- Удалить текущий транспорт / лошадь под собой
    elseif action == 'deleteCurrentVehicle' then
        local mount = GetMount(ped)
        if DoesEntityExist(mount) then
            SetEntityAsMissionEntity(mount, true, true)
            ClearPedTasksImmediately(ped)
            DeleteEntity(mount)
            print("^2[HUNT ADMIN] Лошадь удалена!^7")
        else
            local veh = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(veh) then
                SetEntityAsMissionEntity(veh, true, true)
                ClearPedTasksImmediately(ped)
                DeleteVehicle(veh)
                DeleteEntity(veh)
                print("^2[HUNT ADMIN] Транспорт удален!^7")
            else
                local lastVeh = GetVehiclePedIsIn(ped, true)
                if DoesEntityExist(lastVeh) then
                    SetEntityAsMissionEntity(lastVeh, true, true)
                    DeleteVehicle(lastVeh)
                    DeleteEntity(lastVeh)
                    print("^2[HUNT ADMIN] Предыдущий транспорт удален!^7")
                else
                    print("^3[HUNT ADMIN] Вы не находитесь на лошади или в транспорте.^7")
                end
            end
        end

    -- Лечить лошадь/транспорт
    elseif action == 'healMount' then
        local mount = GetMount(ped)
        if DoesEntityExist(mount) then
            SetEntityHealth(mount, GetEntityMaxHealth(mount))
            Citizen.InvokeNative(0xC6258F41D86676E0, mount, 0, 100)
            Citizen.InvokeNative(0xC6258F41D86676E0, mount, 1, 100)
            print("^2[HUNT ADMIN] Лошадь полностью вылечена!^7")
        end

    -- Боезапас
    elseif action == 'giveAmmo' then
        local weapons = {
            "WEAPON_REVOLVER_CATTLEMAN",
            "WEAPON_REVOLVER_SCHOFIELD",
            "WEAPON_REPEATER_WINCHESTER",
            "WEAPON_SHOTGUN_DOUBLEBARREL",
            "WEAPON_SNIPERRIFLE_CARCANO",
            "WEAPON_BOW"
        }
        for _, wName in ipairs(weapons) do
            local wHash = GetHashKey(wName)
            SetPedAmmo(ped, wHash, 999)
        end
        print("^2[HUNT ADMIN] Боезапас пополнен!^7")

    elseif action == 'fireball' then
        ExecuteCommand("fireball")

    -- Метки на карте (синхронизация включения/выключения)
    elseif action == 'toggleAdminBlips' then
        TriggerEvent("thehunt_admin:toggleBlips")
        local isBlipsOn = false
        if exports['thehunt_core'] and exports['thehunt_core'].isAdminBlipsActive then
            isBlipsOn = exports['thehunt_core']:isAdminBlipsActive()
        end
        SendNUIMessage({ type = 'UPDATE_STATE', state = { adminBlips = isBlipsOn } })
        if isBlipsOn then
            AddStatusEffectSafe({ id = 'admin_blips' })
        else
            RemoveStatusEffectSafe('admin_blips')
        end

    -- Телепорт по метке на карте (через IsWaypointActive)
    elseif action == 'tpToWaypoint' then
        if IsWaypointActive() then
            local coords = GetWaypointCoords()
            local x, y = coords.x, coords.y
            local found, groundZ = GetGroundZFor_3dCoord(x, y, 600.0, false)
            if not found or groundZ == 0.0 then
                found, groundZ = GetGroundZAndNormalFor_3dCoord(x, y, 100.0)
            end
            local z = (found and groundZ > 0.0) and (groundZ + 0.5) or 100.0
            TeleportWithVehicle(x, y, z)
            print("^2[HUNT ADMIN] Телепортирован к метке на карте!^7")
        else
            print("^1[HUNT ADMIN] Метка на карте не найдена! Установите путевую точку на карте.^7")
        end

    -- Управление погодой (weathersync UI)
    elseif action == 'openWeatherUI' then
        ExecuteCommand("weatherui")

    -- Редактор мира (thehunt_builder)
    elseif action == 'openBuilder' then
        isMenuOpen = false
        isMMBPressed = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CLOSE_ADMIN_MENU' })
        TriggerServerEvent("thehunt_builder:checkPermissionAndOpen")
    end

    cb('ok')
end)

-- Прямое открытие админ-меню (например, при возврате из редактора мира)
RegisterNetEvent("thehunt_admin:openDirectly", function()
    ToggleAdminMenu()
end)

-- Выдача оружия напрямую
RegisterNUICallback('giveWeapon', function(data, cb)
    if data.weapon then
        local ped = PlayerPedId()
        local wHash = GetHashKey(data.weapon)

        Citizen.InvokeNative(0xB282DC6EBD803C75, ped, wHash, 500, true, 0)
        Citizen.InvokeNative(0x5E3BDDBCB83F3D3D, ped, wHash, 500, true, true, 0, false, 0.5, 1.0, 0, 0, 0, 0)
        SetPedAmmo(ped, wHash, 500)
        SetCurrentPedWeapon(ped, wHash, true)

        TriggerServerEvent("thehunt_admin:giveWeaponServer", data.weapon)
        print(string.format("^2[HUNT ADMIN] Выдано оружие: %s^7", data.weapon))
    end
    cb('ok')
end)

-- Телепорт по координатам (с лошадью/транспортом)
RegisterNUICallback('tpLocation', function(data, cb)
    if data.x and data.y and data.z then
        TeleportWithVehicle(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    cb('ok')
end)

-- Прием телепорта от сервера (с лошадью/транспортом)
RegisterNetEvent("thehunt_admin:tpToCoords", function(x, y, z)
    TeleportWithVehicle(x, y, z)
end)

-- Телепорт к игроку по ID
RegisterNUICallback('tpToPlayerById', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent("thehunt_admin:playerAction", targetId, "tpTo")
    end
    cb('ok')
end)

-- Телепорт игрока к себе по ID
RegisterNUICallback('tpPlayerHereById', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent("thehunt_admin:playerAction", targetId, "tpHere")
    end
    cb('ok')
end)

-- Действия над игроками
RegisterNUICallback('adminPlayerAction', function(data, cb)
    local targetId = tonumber(data.targetId)
    local act = data.action
    local extra = data.extraData or {}

    if targetId and act then
        TriggerServerEvent("thehunt_admin:playerAction", targetId, act, extra)
    end
    cb('ok')
end)

-- Клиентские обработчики для целевых игроков
RegisterNetEvent("thehunt_admin:requestCoordsForAdminTp", function(adminSrc)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent("thehunt_admin:reportCoordsForAdminTp", adminSrc, coords.x, coords.y, coords.z)
end)

RegisterNetEvent("thehunt_admin:applyHealClient", function()
    local ped = PlayerPedId()
    local maxH = GetEntityMaxHealth(ped)
    if maxH < 100 then maxH = 600 end
    SetEntityHealth(ped, maxH)
    RestorePlayerStamina(PlayerId(), 1.0)
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, 100) -- Health core
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100) -- Stamina core
    Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 0, 100.0) -- Health ring
    Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, 100.0) -- Stamina ring
    TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
    TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
    TriggerEvent("thehunt_status:updateMetabolism", 1000, 1000)
    TriggerEvent("vorp_medic:heal")
    TriggerEvent("vorp:healPlayer")
end)

RegisterNetEvent("thehunt_admin:applyMetabolismClient", function()
    TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
    TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
    TriggerEvent("thehunt_status:updateMetabolism", 1000, 1000)
end)

RegisterNetEvent("thehunt_admin:setPlayerStatsClient", function(stats)
    if type(stats) ~= "table" then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or ped == 0 then return end
    local metabolismChanged = false

    if stats.health ~= nil then
        local maxHealth = GetEntityMaxHealth(ped)
        if not maxHealth or maxHealth < 100 then maxHealth = 600 end
        local healthPercent = math.max(0, math.min(100, tonumber(stats.health) or 100))
        SetEntityHealth(ped, math.floor(maxHealth * healthPercent / 100 + 0.5))
        Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, healthPercent)
        Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 0, healthPercent + 0.0)
    end

    if stats.hunger ~= nil then
        local hunger = math.max(0, math.min(100, tonumber(stats.hunger) or 100))
        -- Для точной админской установки нужен setValue: changeValue прибавляет
        -- значение к текущему и после следующего тика VORP возвращает старое состояние.
        TriggerEvent("vorpmetabolism:setValue", "Hunger", hunger * 10)
        TriggerEvent("thehunt_status:updateMetabolism", hunger * 10, nil)
        metabolismChanged = true
    end

    if stats.thirst ~= nil then
        local thirst = math.max(0, math.min(100, tonumber(stats.thirst) or 100))
        TriggerEvent("vorpmetabolism:setValue", "Thirst", thirst * 10)
        TriggerEvent("thehunt_status:updateMetabolism", nil, thirst * 10)
        metabolismChanged = true
    end

    -- Сохраняем только результат этого админского изменения, не затрагивая
    -- обычные действия еды/воды и остальную логику метаболизма.
    if metabolismChanged then
        TriggerEvent("vorpmetabolism:saveNow")
    end
end)

RegisterNetEvent("thehunt_admin:applyStaminaClient", function()
    local ped = PlayerPedId()
    RestorePlayerStamina(PlayerId(), 1.0)
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100) -- Stamina core
    Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, 100.0) -- Stamina ring
    SetCurrentStaminaSafe(100.0)
end)

RegisterNetEvent("thehunt_admin:applyReviveClient", function()
    -- Compatibility bridge for any older HUNT UI callback. Route it through
    -- VORP's current controller so the death resource receives the same
    -- authoritative revive event and removes its screen/state.
    TriggerEvent("vorp_core:Client:OnPlayerRevive", true)
end)

RegisterNetEvent("thehunt_admin:applyKillClient", function()
    local ped = PlayerPedId()
    ApplyDamageToPed(ped, 50000.0, false)
    SetEntityHealth(ped, 0)
end)

RegisterNetEvent("thehunt_admin:updatePlayerToggles", function(targetId, toggles)
    SendNUIMessage({
        type = 'UPDATE_PLAYER_TOGGLES',
        targetId = tonumber(targetId),
        toggles = toggles
    })
end)

RegisterNetEvent("thehunt_admin:toggleGodmodeClient", function(explicitState)
    if explicitState ~= nil then
        godmodeActive = explicitState
    else
        godmodeActive = not godmodeActive
    end
    ApplyGodmodeState(godmodeActive)
    SendNUIMessage({ type = 'UPDATE_STATE', state = { godmode = godmodeActive } })
    if godmodeActive then
        AddStatusEffectSafe({ id = 'admin_godmode' })
    else
        RemoveStatusEffectSafe('admin_godmode')
    end
end)

RegisterNetEvent("thehunt_admin:toggleInvisClient", function(explicitState)
    if explicitState ~= nil then
        invisActive = explicitState
    else
        invisActive = not invisActive
    end
    local ped = PlayerPedId()
    SetEntityVisible(ped, not invisActive)
    SetEntityAlpha(ped, invisActive and 0 or 255, false)
    SendNUIMessage({ type = 'UPDATE_STATE', state = { invis = invisActive } })
    if invisActive then
        AddStatusEffectSafe({ id = 'admin_invis' })
    else
        RemoveStatusEffectSafe('admin_invis')
    end
end)

RegisterNetEvent("thehunt_admin:toggleSuperJumpClient", function(explicitState)
    if explicitState ~= nil then
        superJumpActive = explicitState
    else
        superJumpActive = not superJumpActive
    end
    SendNUIMessage({ type = 'UPDATE_STATE', state = { superJump = superJumpActive } })
    if superJumpActive then
        AddStatusEffectSafe({ id = 'admin_superjump' })
    else
        RemoveStatusEffectSafe('admin_superjump')
    end
end)

RegisterNetEvent("thehunt_admin:toggleFreezeClient", function(explicitState)
    local ped = PlayerPedId()
    local isFrozen = false
    if explicitState ~= nil then
        isFrozen = explicitState
    else
        isFrozen = not IsEntityPositionFrozen(ped)
    end
    FreezeEntityPosition(ped, isFrozen)
    if isFrozen then
        AddStatusEffectSafe({ id = 'admin_freeze_ped' })
    else
        RemoveStatusEffectSafe('admin_freeze_ped')
    end
end)

RegisterNetEvent("thehunt_admin:cleanPedClient", function()
    local ped = PlayerPedId()
    ClearPedEnvDirt(ped)
    ClearPedBloodDamage(ped)
    ClearPedWetness(ped)
    Citizen.InvokeNative(0x27C442A002061099, ped) -- ClearPedDamageDecals
end)

RegisterNetEvent("thehunt_admin:disarmClient", function()
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end)

RegisterNetEvent("thehunt_admin:applyWeaponClient", function(weaponName)
    if not weaponName then return end
    local ped = PlayerPedId()
    local wHash = GetHashKey(weaponName)
    Citizen.InvokeNative(0x5E3BDDBCB83F3D3D, ped, wHash, 500, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false) -- GiveWeaponToPed_2
    Citizen.InvokeNative(0xB282DC6EBD803C75, ped, wHash, 500, true, 0) -- GiveWeaponToPed
    SetPedAmmo(ped, wHash, 500)
    SetCurrentPedWeapon(ped, wHash, true)
end)

RegisterNetEvent("thehunt_admin:applyAmmoClient", function()
    local ped = PlayerPedId()
    local cur = GetCurrentPedWeapon(ped)
    if cur and cur ~= 0 and cur ~= `WEAPON_UNARMED` then
        SetPedAmmo(ped, cur, 999)
    end
    local commonWeapons = {
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_SCHOFIELD",
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_SHOTGUN_DOUBLEBARREL",
        "WEAPON_SNIPERRIFLE_CARCANO",
        "WEAPON_BOW"
    }
    for _, wName in ipairs(commonWeapons) do
        SetPedAmmo(ped, GetHashKey(wName), 999)
    end
end)

RegisterNetEvent("thehunt_admin:healMountClient", function()
    local ped = PlayerPedId()
    local mount = GetMount(ped)
    if mount and mount ~= 0 and DoesEntityExist(mount) then
        SetEntityHealth(mount, GetEntityMaxHealth(mount))
        Citizen.InvokeNative(0xC6258F41D86676E0, mount, 0, 100.0)
        Citizen.InvokeNative(0xC6258F41D86676E0, mount, 1, 100.0)
    end
end)

RegisterNetEvent("thehunt_admin:deleteVehicleClient", function()
    local ped = PlayerPedId()
    local mount = GetMount(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if mount and mount ~= 0 and DoesEntityExist(mount) then
        DeleteEntity(mount)
    elseif veh and veh ~= 0 and DoesEntityExist(veh) then
        DeleteVehicle(veh)
    end
end)

RegisterNetEvent("thehunt_admin:spawnHorseForPlayerClient", function(modelName)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local hHash = GetHashKey(modelName or "A_C_Horse_Turkoman_Gold")
    RequestModel(hHash)
    local timeout = 0
    while not HasModelLoaded(hHash) and timeout < 50 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    if HasModelLoaded(hHash) then
        local horse = CreatePed(hHash, coords.x + 1.2, coords.y + 1.2, coords.z, heading, true, false, false, false)
        Citizen.InvokeNative(0x283978A15512B2FE, horse, true)
        SetPedPromptName(horse, "Лошадь")
        SetModelAsNoLongerNeeded(hHash)
    end
end)

RegisterNetEvent("thehunt_admin:toggleFreezeHungerClient", function(explicitState)
    if explicitState ~= nil then
        freezeHungerActive = explicitState
    else
        freezeHungerActive = not freezeHungerActive
    end
    SendNUIMessage({ type = 'UPDATE_STATE', state = { freezeHunger = freezeHungerActive } })
    if freezeHungerActive then
        TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
        UpdateStatusMetabolism(1000, nil)
    end
    if freezeHungerActive then
        AddStatusEffectSafe({ id = 'admin_freeze_hunger' })
    else
        RemoveStatusEffectSafe('admin_freeze_hunger')
    end
end)

RegisterNetEvent("thehunt_admin:toggleFreezeThirstClient", function(explicitState)
    if explicitState ~= nil then
        freezeThirstActive = explicitState
    else
        freezeThirstActive = not freezeThirstActive
    end
    SendNUIMessage({ type = 'UPDATE_STATE', state = { freezeThirst = freezeThirstActive } })
    if freezeThirstActive then
        TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
        UpdateStatusMetabolism(nil, 1000)
    end
    if freezeThirstActive then
        AddStatusEffectSafe({ id = 'admin_freeze_thirst' })
    else
        RemoveStatusEffectSafe('admin_freeze_thirst')
    end
end)

RegisterNetEvent("thehunt_admin:toggleFreezeStaminaClient", function(explicitState)
    if explicitState ~= nil then
        freezeStaminaActive = explicitState
    else
        freezeStaminaActive = not freezeStaminaActive
    end
    SendNUIMessage({ type = 'UPDATE_STATE', state = { freezeStamina = freezeStaminaActive } })
    if freezeStaminaActive then
        RestorePlayerStamina(PlayerId(), 1.0)
        Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 1, 100.0)
        Citizen.InvokeNative(0xFE765D8B62B8C448, PlayerPedId(), 1, 100.0)
        Citizen.InvokeNative(0x675680D08A22FC21, PlayerPedId(), 100.0)
    end
    if freezeStaminaActive then
        AddStatusEffectSafe({ id = 'admin_freeze_stamina' })
    else
        RemoveStatusEffectSafe('admin_freeze_stamina')
    end
    SetFreezeStaminaSafe(freezeStaminaActive)
end)

-- Поток непрерывного удержания замороженных показателей (еда, жажда, выносливость)
Citizen.CreateThread(function()
    while true do
        if freezeThirstActive or freezeHungerActive or freezeStaminaActive then
            local ped = PlayerPedId()
            if freezeThirstActive then
                TriggerEvent("vorpmetabolism:changeValue", "Thirst", 1000)
                UpdateStatusMetabolism(nil, 1000)
            end
            if freezeHungerActive then
                TriggerEvent("vorpmetabolism:changeValue", "Hunger", 1000)
                UpdateStatusMetabolism(1000, nil)
            end
            if freezeStaminaActive then
                RestorePlayerStamina(PlayerId(), 1.0)
                Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100.0) -- Stamina Core
                Citizen.InvokeNative(0xFE765D8B62B8C448, ped, 1, 100.0) -- Stamina Ring
                Citizen.InvokeNative(0x675680D08A22FC21, ped, 100.0) -- _SET_PED_STAMINA
                SetCurrentStaminaSafe(100.0)
                local mount = GetMount(ped)
                if mount and mount ~= 0 and DoesEntityExist(mount) then
                    Citizen.InvokeNative(0xC6258F41D86676E0, mount, 1, 100.0)
                    Citizen.InvokeNative(0xFE765D8B62B8C448, mount, 1, 100.0)
                end
            end
            Citizen.Wait(50)
        else
            Citizen.Wait(500)
        end
    end
end)

RegisterNetEvent("thehunt_admin:spawnWagonForPlayerClient", function(modelName)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local vHash = GetHashKey(modelName or "wagon02x")
    RequestModel(vHash)
    local timeout = 0
    while not HasModelLoaded(vHash) and timeout < 50 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    if HasModelLoaded(vHash) then
        local wagon = CreateVehicle(vHash, coords.x + 2.0, coords.y + 2.0, coords.z, heading, true, false)
        SetVehicleOnGroundProperly(wagon)
        SetModelAsNoLongerNeeded(vHash)
        TriggerEvent("thehunt_status:notify", "Повозка", "Вам заспавнена повозка", "success")
    end
end)

-- Изменение времени через weathersync
RegisterNUICallback('setTime', function(data, cb)
    if data.time then
        local timeStr = tostring(data.time)
        local h, m = 12, 0

        if string.find(timeStr, ":") then
            local parts = {}
            for part in string.gmatch(timeStr, "[^:]+") do
                table.insert(parts, tonumber(part) or 0)
            end
            h = parts[1] or 12
            m = parts[2] or 0
        else
            h = tonumber(timeStr) or 12
            m = 0
        end

        -- Используем команду weathersync /time
        ExecuteCommand(string.format("time 0 %d %d 0 0 1", h, m))
        print(string.format("^2[HUNT ADMIN] Время установлено: %02d:%02d^7", h, m))
    end
    cb('ok')
end)


-- =================================================================
-- ПОТОК NO-CLIP С МАКСИМАЛЬНОЙ ПЛАВНОСТЬЮ, КОЛЕСОМ МЫШИ И 3D-УПРАВЛЕНИЕМ
-- =================================================================
Citizen.CreateThread(function()
    while true do
        if noclipStopRequested then
            noclipStopRequested = false
            StopNoClip()
        elseif noclipActive and noclipCam and DoesCamExist(noclipCam) then
            Citizen.Wait(0)

            local ped = PlayerPedId()

            -- Блокируем игровые действия, мешающие свободному полёту (стрельба, удары, оружие, посадка на коня)
            DisablePlayerFiring(ped, true)
            DisableControlAction(0, 0x07CE1E61, true) -- ATTACK
            DisableControlAction(0, 0xF84FA74F, true) -- AIM
            DisableControlAction(0, 0xCEFD9220, true) -- CONTEXT_E / MOUNT
            DisableControlAction(0, 0x54182BC1, true) -- HORSE_SPRINT
            DisableControlAction(0, 0x227DCC40, true) -- HORSE_MOVE
            DisableControlAction(0, 0xAC4BD4F3, true) -- WEAPON_WHEEL
            DisableControlAction(0, 0x4CC0E2FE, true) -- WEAPON_SELECT
            DisableControlAction(0, 0x2491A936, true) -- WHEEL_NEXT
            DisableControlAction(0, 0x05CA7C52, true) -- WHEEL_PREV
            DisableControlAction(0, 0x4883C7E3, true) -- NEXT_WEAPON
            DisableControlAction(0, 0x68CD9E63, true) -- PREV_WEAPON
            DisableControlAction(0, 0xD42E6C65, true) -- JUMP
            DisableControlAction(0, 0xDB096B85, true) -- DUCK
            DisableControlAction(0, 0x156F7119, true) -- BACKSPACE / FRONTEND_CANCEL
            DisableControlAction(0, 0x4AF4D473, true) -- DEL

            -- 1. Выход из NoClip через Backspace (0x156F7119 / 0x308588E6 / 0x8AAA0DF4 / 0x046D33D6) или DEL (0x4AF4D473).
            -- F1 обрабатывается только RegisterKeyMapping("hunt_toggle_noclip"), чтобы одно нажатие не переключало режим дважды.
            if IsControlJustPressed(0, 0x156F7119) or IsDisabledControlJustPressed(0, 0x156F7119)
                or IsControlJustPressed(0, 0x308588E6) or IsDisabledControlJustPressed(0, 0x308588E6)
                or IsControlJustPressed(0, 0x8AAA0DF4) or IsDisabledControlJustPressed(0, 0x8AAA0DF4)
                or IsControlJustPressed(0, 0x046D33D6) or IsDisabledControlJustPressed(0, 0x046D33D6)
                or IsControlJustPressed(0, 0x4AF4D473) or IsDisabledControlJustPressed(0, 0x4AF4D473) then
                StopNoClip()
                goto continue_loop
            end

            -- 2. Вращение камеры (Мышь / правый стик)
            local lookX = GetControlNormal(0, 0xA987235F) -- INPUT_LOOK_LR
            local lookY = GetControlNormal(0, 0xD2047988) -- INPUT_LOOK_UD (RedM)
            if lookX == 0.0 then lookX = GetDisabledControlNormal(0, 0xA987235F) end
            if lookY == 0.0 then lookY = GetDisabledControlNormal(0, 0xD2047988) end

            local mouseSensitivity = 7.5
            noclipCamRotX = math.max(-89.0, math.min(89.0, noclipCamRotX + (-lookY * mouseSensitivity)))
            noclipCamRotZ = (noclipCamRotZ + (-lookX * mouseSensitivity)) % 360.0

            SetCamRot(noclipCam, noclipCamRotX, 0.0, noclipCamRotZ, 2)

            -- 3. Переключение ступеней скорости (Shift - Быстрее, Alt - Медленнее)
            if IsControlJustPressed(0, 0x8FFC75D6) or IsDisabledControlJustPressed(0, 0x8FFC75D6)
                or IsControlJustPressed(0, 0x8FFC75D0) or IsDisabledControlJustPressed(0, 0x8FFC75D0) then
                if noclipSpeedIndex < #noclipSpeedModes then
                    noclipSpeedIndex = noclipSpeedIndex + 1
                end
            end

            if IsControlJustPressed(0, 0x8AAA0AD4) or IsDisabledControlJustPressed(0, 0x8AAA0AD4)
                or IsControlJustPressed(0, 0x580C4473) or IsDisabledControlJustPressed(0, 0x580C4473)
                or IsControlJustPressed(0, 0x7B174549) or IsDisabledControlJustPressed(0, 0x7B174549) then
                if noclipSpeedIndex > 1 then
                    noclipSpeedIndex = noclipSpeedIndex - 1
                end
            end

            local speedInfo = noclipSpeedModes[noclipSpeedIndex]
            local currentSpeed = speedInfo.speed

            -- 4. Векторы направлений в 3D (Строгая декартова матрица)
            local radZ = math.rad(noclipCamRotZ)
            local radX = math.rad(noclipCamRotX)
            local cosX = math.cos(radX)
            local sinX = math.sin(radX)
            local cosZ = math.cos(radZ)
            local sinZ = math.sin(radZ)

            local vecX = vector3(cosZ, sinZ, 0.0) -- Вектор вправо
            local vecY = vector3(-sinZ * cosX, cosZ * cosX, sinX) -- Вектор взгляда в 3D (вперёд)
            local vecZ = vector3(0.0, 0.0, 1.0) -- Вектор вверх

            -- 5. Точный опрос осей перемещения
            local moveX = GetDisabledControlNormal(0, 0x4D8FB4C1) -- Left (-1.0) / Right (+1.0)
            if moveX == 0.0 then moveX = GetControlNormal(0, 0x4D8FB4C1) end

            local moveY = GetDisabledControlNormal(0, 0xFDA83190) -- Forward (-1.0) / Back (+1.0)
            if moveY == 0.0 then moveY = GetControlNormal(0, 0xFDA83190) end

            -- Вертикальное перемещение (Up / Down)
            local upNormal = GetDisabledControlNormal(0, 0x06052D11)
            if upNormal == 0.0 then upNormal = GetControlNormal(0, 0x06052D11) end
            if upNormal == 0.0 and (IsControlPressed(0, 0xD42E6C65) or IsDisabledControlPressed(0, 0xD42E6C65) or IsControlPressed(0, 0xD9D0E1C0) or IsDisabledControlPressed(0, 0xD9D0E1C0) or IsControlPressed(0, 0xCEFD9220) or IsDisabledControlPressed(0, 0xCEFD9220) or IsControlPressed(0, 0x446258B6) or IsDisabledControlPressed(0, 0x446258B6)) then
                upNormal = 1.0
            end

            local downNormal = GetDisabledControlNormal(0, 0xD51B784F)
            if downNormal == 0.0 then downNormal = GetControlNormal(0, 0xD51B784F) end
            if downNormal == 0.0 and (IsControlPressed(0, 0xDB096B85) or IsDisabledControlPressed(0, 0xDB096B85) or IsControlPressed(0, 0xDE794E3E) or IsDisabledControlPressed(0, 0xDE794E3E) or IsControlPressed(0, 0x9959A6F0) or IsDisabledControlPressed(0, 0x9959A6F0) or IsControlPressed(0, 0x3C3DD371) or IsDisabledControlPressed(0, 0x3C3DD371)) then
                downNormal = 1.0
            end

            local moveZ = upNormal - downNormal

            -- 6. Применение перемещения к камере (W = вперёд, S = назад, A = влево, D = вправо, Space = вверх, Ctrl = вниз)
            if math.abs(moveX) > 0.02 or math.abs(moveY) > 0.02 or math.abs(moveZ) > 0.02 then
                noclipCamCoords = noclipCamCoords + (vecX * (moveX * currentSpeed)) + (vecY * (-moveY * currentSpeed)) + (vecZ * (moveZ * currentSpeed))
                SetCamCoord(noclipCam, noclipCamCoords.x, noclipCamCoords.y, noclipCamCoords.z)
            end

            -- 7. Синхронизация сущности игрока/транспорта с камерой
            -- Если F1 остановил режим во время этого кадра, не возвращаем
            -- старые freeze/collision/visibility обратно.
            if noclipActive and noclipCam and DoesCamExist(noclipCam) then
                local entity = noclipEntity or ped
                SetEntityCoords(entity, noclipCamCoords.x, noclipCamCoords.y, noclipCamCoords.z, false, false, false, false)
                SetEntityHeading(entity, noclipCamRotZ)
                FreezeEntityPosition(entity, true)
                SetEntityCollision(entity, false, false)
                SetEntityVisible(entity, false)

                if entity ~= ped then
                    SetEntityCoords(ped, noclipCamCoords.x, noclipCamCoords.y, noclipCamCoords.z, false, false, false, false)
                    SetEntityHeading(ped, noclipCamRotZ)
                    SetEntityVisible(ped, false)
                end
            end

            -- Загрузка чанков мира и интерьеров вокруг текущей точки полёта
            SetFocusPosAndVel(noclipCamCoords.x, noclipCamCoords.y, noclipCamCoords.z, 0.0, 0.0, 0.0)

            -- 8. Передача данных в экранный HUD NoClip (каждые 50мс)
            local now = GetGameTimer()
            if (now - lastNoclipHudPush) > 50 then
                lastNoclipHudPush = now
                SendNUIMessage({
                    type = 'UPDATE_NOCLIP_DATA',
                    speedIndex = noclipSpeedIndex,
                    maxSpeedIndex = #noclipSpeedModes,
                    speedLabel = speedInfo.label,
                    speedValue = string.format("%.2f", currentSpeed),
                    x = noclipCamCoords.x,
                    y = noclipCamCoords.y,
                    z = noclipCamCoords.z,
                    h = noclipCamRotZ
                })
            end

            ::continue_loop::
        else
            Citizen.Wait(200)
        end
    end
end)

-- =================================================================
-- 3D ЛАЗЕРНАЯ УКАЗКА, СИСТЕМА КООРДИНАТ И БЫСТРОЕ КОПИРОВАНИЕ
-- =================================================================

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function ToggleCoordLaserMode()
    isCoordLaserActive = not isCoordLaserActive
    SendNUIMessage({
        type = 'SET_COORD_LASER_VISIBLE',
        active = isCoordLaserActive
    })
    SendNUIMessage({ type = 'UPDATE_STATE', state = { coordLaser = isCoordLaserActive } })
    if isCoordLaserActive then
        AddStatusEffectSafe({ id = 'admin_laser' })
    else
        RemoveStatusEffectSafe('admin_laser')
    end
end

RegisterCommand("coords", ToggleCoordLaserMode, false)
RegisterCommand("laser", ToggleCoordLaserMode, false)
RegisterCommand("coordlaser", ToggleCoordLaserMode, false)

-- Поток 3D-лазера, отрисовки прицела и системы координат
Citizen.CreateThread(function()
    while true do
        if isCoordLaserActive or isMenuOpen then
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local pedHeading = GetEntityHeading(ped)

            local camRot = GetGameplayCamRot(2)
            local camCoords = GetGameplayCamCoord()
            local dir = RotationToDirection(camRot)
            local targetCoords = camCoords + (dir * 120.0)

            -- Raycast из камеры в мир
            local ray = StartShapeTestRay(
                camCoords.x, camCoords.y, camCoords.z,
                targetCoords.x, targetCoords.y, targetCoords.z,
                287, ped, 4
            )
            local _, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(ray)

            if not hit or #(hitCoords) < 0.1 then
                hitCoords = targetCoords
            end

            local hitDist = #(camCoords - hitCoords)
            local hitModel = 0
            if entityHit and DoesEntityExist(entityHit) then
                hitModel = GetEntityModel(entityHit)
            end

            -- Отрисовка 3D-лазера и маркеров (только когда включен режим лазера)
            if isCoordLaserActive then
                -- 1. Лазерный луч
                DrawLine(camCoords.x, camCoords.y, camCoords.z, hitCoords.x, hitCoords.y, hitCoords.z, 255, 255, 255, 200)

                -- 2. Светящаяся сфера в точке попадания луча
                DrawMarker(
                    28,
                    hitCoords.x, hitCoords.y, hitCoords.z,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.07, 0.07, 0.07,
                    255, 255, 255, 240,
                    false, false, 2, false, nil, nil, false
                )

                -- 3. 3D-оси прицела
                DrawLine(hitCoords.x, hitCoords.y, hitCoords.z - 0.15, hitCoords.x, hitCoords.y, hitCoords.z + 0.15, 0, 255, 180, 255)
                DrawLine(hitCoords.x - 0.15, hitCoords.y, hitCoords.z, hitCoords.x + 0.15, hitCoords.y, hitCoords.z, 0, 255, 180, 255)
                DrawLine(hitCoords.x, hitCoords.y - 0.15, hitCoords.z, hitCoords.x, hitCoords.y + 0.15, hitCoords.z, 0, 255, 180, 255)

                -- 4. Быстрые горячие клавиши копирования (когда админ-меню закрыто)
                if not isMenuOpen then
                    -- E (0xCEFD9220): Копировать прицел vector3
                    if IsControlJustPressed(0, 0xCEFD9220) then
                        local text = string.format("vector3(%.2f, %.2f, %.2f)", hitCoords.x, hitCoords.y, hitCoords.z)
                        SendNUIMessage({
                            type = 'COPY_TO_CLIPBOARD',
                            text = text,
                            label = 'Прицел (vector3)'
                        })
                    end

                    -- C (0x9959A6F0): Копировать игрока vector4
                    if IsControlJustPressed(0, 0x9959A6F0) then
                        local text = string.format("vector4(%.2f, %.2f, %.2f, %.2f)", pedCoords.x, pedCoords.y, pedCoords.z, pedHeading)
                        SendNUIMessage({
                            type = 'COPY_TO_CLIPBOARD',
                            text = text,
                            label = 'Игрок (vector4)'
                        })
                    end

                    -- X (0x8AAA0DE4): Копировать игрока vector3
                    if IsControlJustPressed(0, 0x8AAA0DE4) then
                        local text = string.format("vector3(%.2f, %.2f, %.2f)", pedCoords.x, pedCoords.y, pedCoords.z)
                        SendNUIMessage({
                            type = 'COPY_TO_CLIPBOARD',
                            text = text,
                            label = 'Игрок (vector3)'
                        })
                    end
                end
            end

            -- Отправка данных координат в NUI (каждые 60мс при активном лазере, каждые 250мс если открыто меню)
            local now = GetGameTimer()
            local coordsPushInterval = isCoordLaserActive and 60 or 250
            if (now - lastCoordsPush) > coordsPushInterval then
                lastCoordsPush = now
                SendNUIMessage({
                    type = 'UPDATE_COORDS_DATA',
                    pedX = pedCoords.x,
                    pedY = pedCoords.y,
                    pedZ = pedCoords.z,
                    pedH = pedHeading,
                    hitX = hitCoords.x,
                    hitY = hitCoords.y,
                    hitZ = hitCoords.z,
                    hitDist = hitDist,
                    hitEntity = (entityHit and DoesEntityExist(entityHit)) and entityHit or nil,
                    hitModel = hitModel
                })
            end

            if isCoordLaserActive then
                Citizen.Wait(0)
            else
                Citizen.Wait(120)
            end
        else
            Citizen.Wait(400)
        end
    end
end)

-- =================================================================
-- NUI CALLBACKS: ВКЛАДКА "ПРЕДМЕТЫ" В АДМИН-ПАНЕЛИ
-- =================================================================

RegisterNUICallback('getAdminItemsList', function(data, cb)
    local itemsList = {}
    local removedClothingItems = { clothing_badge = true, clothing_buckle = true }
    if exports['thehunt_items'] and exports['thehunt_items'].GetAllItems then
        local all = exports['thehunt_items']:GetAllItems()
        for k, v in pairs(all) do
            if not removedClothingItems[string.lower(tostring(k))] then
                table.insert(itemsList, {
                    name = k,
                    label = v.label or k,
                    category = v.category or "item",
                    rarity = v.rarity or "green",
                    icon = v.icon or k,
                    image = v.image,
                    width = v.width or 1,
                    height = v.height or 1
                })
            end
        end
    end
    SendNUIMessage({
        type = 'RECEIVE_ADMIN_ITEMS',
        items = itemsList
    })
    cb('ok')
end)

RegisterNUICallback('getNearbyPlayersList', function(data, cb)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local list = {}
    local activePlayers = GetActivePlayers()
    for _, p in ipairs(activePlayers) do
        local targetPed = GetPlayerPed(p)
        if DoesEntityExist(targetPed) then
            local dist = #(myCoords - GetEntityCoords(targetPed))
            if dist <= 60.0 then
                local sId = GetPlayerServerId(p)
                table.insert(list, {
                    id = sId,
                    name = GetPlayerName(p) or ("Player " .. tostring(sId)),
                    distance = string.format("%.1fm", dist)
                })
            end
        end
    end
    SendNUIMessage({
        type = 'RECEIVE_NEARBY_PLAYERS',
        players = list
    })
    cb('ok')
end)

RegisterNUICallback('giveAdminItem', function(data, cb)
    if data and data.name then
        TriggerServerEvent("thehunt_items:adminGiveItem", data.name, data.count or 1, data.targetPlayerId)
    end
    cb('ok')
end)

RegisterNUICallback('toggleAdminItemsNearbyIDs', function(data, cb)
    if exports['thehunt_core'] and exports['thehunt_core'].showTransferNearbyIDs then
        exports['thehunt_core']:showTransferNearbyIDs(data.active == true)
    end
    cb('ok')
end)

-- Zombie flags originate from server-authorized actions in thehunt_zombie.
AddEventHandler('thehunt_zombie:adminState', function(state)
    SendNUIMessage({ type = 'UPDATE_STATE', state = state })
end)
