-- =================================================================
-- HUNT: Hard RP — Player Settings Menu | Client Module
-- =================================================================

local isMenuOpen = false
local isCharacterSelected = false
local currentHudMode = "always_on" -- "always_on" | "dynamic" | "always_off"
local currentQuickSlotsMode = "always_on" -- "always_on" | "dynamic" | "always_off"
local currentHintsMode = "always_on" -- "always_on" | "always_off"
local currentWalkStyle = "MP_Style_Casual"
local positionSession = nil
-- Keep the ped close to the point where the editor was opened while leaving
-- enough room to position a seated or leaning animation.
local POSITION_LIMIT_XY = 2.50
local POSITION_LIMIT_Z = 1.25
local POSITION_LIMIT_RADIUS = 3.00
local POSITION_LIMIT_ROTATION = 45.0
local POSITION_LIMIT_HEADING = 180.0

local function IsCharacterPositionAvailable()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) or LocalPlayer.state.isCreatingChar
        or LocalPlayer.state.isSelectingChar or LocalPlayer.state.thehuntUnconscious then
        return false
    end
    return true
end

local function finiteNumber(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then return fallback end
    return number
end

local function ClampPositionOffset(value)
    if type(value) ~= 'table' then return {x=0,y=0,z=0,rx=0,ry=0,rz=0} end
    local x = math.max(-POSITION_LIMIT_XY, math.min(POSITION_LIMIT_XY, finiteNumber(value.x, 0.0)))
    local y = math.max(-POSITION_LIMIT_XY, math.min(POSITION_LIMIT_XY, finiteNumber(value.y, 0.0)))
    local z = math.max(-POSITION_LIMIT_Z, math.min(POSITION_LIMIT_Z, finiteNumber(value.z, 0.0)))
    local distance = math.sqrt(x*x + y*y + z*z)
    if distance > POSITION_LIMIT_RADIUS then
        local factor = POSITION_LIMIT_RADIUS / distance
        x, y, z = x * factor, y * factor, z * factor
    end
    local rx = math.max(-POSITION_LIMIT_ROTATION, math.min(POSITION_LIMIT_ROTATION, finiteNumber(value.rx, 0.0)))
    local ry = math.max(-POSITION_LIMIT_ROTATION, math.min(POSITION_LIMIT_ROTATION, finiteNumber(value.ry, 0.0)))
    local rz = math.max(-POSITION_LIMIT_HEADING, math.min(POSITION_LIMIT_HEADING, finiteNumber(value.rz, 0.0)))
    return {x=x,y=y,z=z,rx=rx,ry=ry,rz=rz}
end


local function StartCharacterPositionGizmo()
    if positionSession or GetResourceState('thehunt_gizmo') ~= 'started' then return false end
    if not IsCharacterPositionAvailable() then
        TriggerEvent('thehunt_status:notify', 'Позиция персонажа', 'Редактор недоступен в текущем состоянии.', 'warning', true)
        return false
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    local origin = GetEntityCoords(ped)
    local rotation = GetEntityRotation(ped, 2)
    local wasFrozen = false
    pcall(function() wasFrozen = IsEntityPositionFrozen(ped) == true end)
    local session = {
        ped = ped, origin = origin, rotation = rotation,
        wasFrozen = wasFrozen,
        value = ClampPositionOffset({}), applied = ClampPositionOffset({})
    }
    positionSession = session

    -- Use a temporary orbit camera while the editor is open. Its starting
    -- angle and distance are taken from the current gameplay camera, so opening
    -- the editor does not jump the player to a fixed view.
    local cameraState = { cam = nil, center = origin + vector3(0.0, 0.0, 0.85), yaw = 0.0, pitch = 0.22, distance = 4.0 }
    local function updateCamera()
        if not cameraState.cam or not DoesCamExist(cameraState.cam) then return end
        local horizontal = cameraState.distance * math.cos(cameraState.pitch)
        local position = vector3(
            cameraState.center.x + math.cos(cameraState.yaw) * horizontal,
            cameraState.center.y + math.sin(cameraState.yaw) * horizontal,
            cameraState.center.z + math.sin(cameraState.pitch) * cameraState.distance
        )
        SetCamCoord(cameraState.cam, position.x, position.y, position.z)
        PointCamAtCoord(cameraState.cam, cameraState.center.x, cameraState.center.y, cameraState.center.z)
    end
    local function destroyCamera()
        if not cameraState.cam then return end
        RenderScriptCams(false, false, 0, true, false)
        if DoesCamExist(cameraState.cam) then DestroyCam(cameraState.cam, false) end
        cameraState.cam = nil
    end
    do
        local center = cameraState.center
        local gameplay = GetGameplayCamCoord()
        local dx, dy, dz = gameplay.x - center.x, gameplay.y - center.y, gameplay.z - center.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance > 0.1 then
            cameraState.distance = math.max(2.5, math.min(7.0, distance))
            cameraState.yaw = math.atan(dy, dx)
            cameraState.pitch = math.max(-0.35, math.min(0.85, math.asin(math.max(-1.0, math.min(1.0, dz / distance)))))
        end
        cameraState.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        if cameraState.cam and DoesCamExist(cameraState.cam) then
            SetCamFov(cameraState.cam, 50.0)
            updateCamera()
            SetCamActive(cameraState.cam, true)
            RenderScriptCams(true, false, 0, true, false)
        else
            cameraState.cam = nil
        end
    end

    local anchor = nil
    local anchorModel = `p_cs_shotglass01x`
    RequestModel(anchorModel)
    local timeout = GetGameTimer() + 1500
    while not HasModelLoaded(anchorModel) and GetGameTimer() < timeout do Wait(10) end
    if HasModelLoaded(anchorModel) then
        anchor = CreateObject(anchorModel, origin.x, origin.y, origin.z, false, false, false)
        if DoesEntityExist(anchor) then
            SetEntityVisible(anchor, false, false)
            SetEntityCollision(anchor, false, false)
            FreezeEntityPosition(anchor, true)
            SetEntityAsMissionEntity(anchor, true, true)
            SetModelAsNoLongerNeeded(anchorModel)

            FreezeEntityPosition(ped, false)
            SetEntityNoCollisionEntity(ped, anchor, false)
            AttachEntityToEntity(ped, anchor, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
    end
    session.anchor = anchor

    local function cleanupAnchor()
        local currentPed = PlayerPedId()
        if session.anchor and DoesEntityExist(session.anchor) then
            if DoesEntityExist(currentPed) and IsEntityAttachedToEntity(currentPed, session.anchor) then
                DetachEntity(currentPed, true, false)
            end
            DeleteEntity(session.anchor)
            session.anchor = nil
        end
    end

    local function isValid()
        local valid = positionSession == session and PlayerPedId() == session.ped
            and DoesEntityExist(session.ped) and IsCharacterPositionAvailable()
            and not IsEntityDead(session.ped)
        if not valid then cleanupAnchor() end
        return valid
    end
    local function point(value)
        return vector3(session.origin.x + value.x, session.origin.y + value.y, session.origin.z + value.z)
    end
    local function apply(value)
        local currentPed = PlayerPedId()
        if not DoesEntityExist(currentPed) or IsEntityDead(currentPed) then return end
        local nextValue = ClampPositionOffset(value)
        session.value = nextValue
        local target = point(nextValue)
        cameraState.center = target + vector3(0.0, 0.0, 0.85)
        updateCamera()

        local wantedRotation = vector3(
            session.rotation.x + nextValue.rx,
            session.rotation.y + nextValue.ry,
            session.rotation.z + nextValue.rz
        )

        session.applied = nextValue

        if session.anchor and DoesEntityExist(session.anchor) then
            SetEntityCoordsNoOffset(session.anchor, target.x, target.y, target.z, false, false, false)
            SetEntityRotation(session.anchor, wantedRotation.x, wantedRotation.y, wantedRotation.z, 2, true)
            SetEntityHeading(session.anchor, wantedRotation.z)
            if not IsEntityAttachedToEntity(currentPed, session.anchor) then
                FreezeEntityPosition(currentPed, false)
                SetEntityNoCollisionEntity(currentPed, session.anchor, false)
                AttachEntityToEntity(currentPed, session.anchor, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            end
        else
            FreezeEntityPosition(currentPed, false)
            SetEntityCoordsNoOffset(currentPed, target.x, target.y, target.z, true, true, true)
            SetEntityRotation(currentPed, wantedRotation.x, wantedRotation.y, wantedRotation.z, 2, true)
            SetEntityHeading(currentPed, wantedRotation.z)
        end
    end

    local function restore()
        cleanupAnchor()
        local currentPed = PlayerPedId()
        if DoesEntityExist(currentPed) then
            FreezeEntityPosition(currentPed, false)
            local restored = false
            if GetResourceState('thehunt_worldinteractions') == 'started' then
                pcall(function()
                    if exports['thehunt_worldinteractions'].UpdateActivePosition then
                        restored = exports['thehunt_worldinteractions']:UpdateActivePosition(session.origin.x, session.origin.y, session.origin.z, session.rotation.z) == true
                    end
                end)
            end
            if not restored then
                SetEntityCoordsNoOffset(currentPed, session.origin.x, session.origin.y, session.origin.z, true, true, true)
                SetEntityRotation(currentPed, session.rotation.x, session.rotation.y, session.rotation.z, 2, true)
                SetEntityHeading(currentPed, session.rotation.z)
            end
            if session.wasFrozen then FreezeEntityPosition(currentPed, true) end
        end
    end

    local started = exports.thehunt_gizmo:Start({
        title = 'Позиция персонажа',
        value = session.value,
        defaults = {x=0,y=0,z=0,rx=0,ry=0,rz=0},
        limits = {
            x={-POSITION_LIMIT_XY, POSITION_LIMIT_XY}, y={-POSITION_LIMIT_XY, POSITION_LIMIT_XY},
            z={-POSITION_LIMIT_Z, POSITION_LIMIT_Z},
            rx={-POSITION_LIMIT_ROTATION, POSITION_LIMIT_ROTATION},
            ry={-POSITION_LIMIT_ROTATION, POSITION_LIMIT_ROTATION},
            rz={-POSITION_LIMIT_HEADING, POSITION_LIMIT_HEADING}
        },
        allowRotation = true,
        point = point,
        valid = isValid,
        apply = apply,
        tick = apply,
        camera = function(dx, dy)
            cameraState.yaw = cameraState.yaw + math.max(-100.0, math.min(100.0, tonumber(dx) or 0.0)) * 0.008
            cameraState.pitch = math.max(-0.35, math.min(0.85,
                cameraState.pitch - math.max(-100.0, math.min(100.0, tonumber(dy) or 0.0)) * 0.006))
            updateCamera()
        end,
        cancelAction = function()
            cleanupAnchor()
            ExecuteCommand('hunt_anim_cancel')
        end,
        finish = function(saved, value)
            if positionSession ~= session then return end
            destroyCamera()
            local currentPed = PlayerPedId()
            if saved and DoesEntityExist(currentPed) and not IsEntityDead(currentPed) then
                local nextValue = ClampPositionOffset(value or session.value)
                local target = point(nextValue)
                local wantedRotation = vector3(
                    session.rotation.x + nextValue.rx,
                    session.rotation.y + nextValue.ry,
                    session.rotation.z + nextValue.rz
                )
                cleanupAnchor()

                -- Keep worldinteractions internal tracking aligned with new coordinates.
                -- UpdateActivePosition restarts the scenario at the new position with teleport=true,
                -- which updates the OneSync-replicated task so all clients see the ped in the right place.
                local handledByWorldInteractions = false
                if GetResourceState('thehunt_worldinteractions') == 'started' then
                    pcall(function()
                        if exports['thehunt_worldinteractions'].UpdateActivePosition then
                            handledByWorldInteractions = exports['thehunt_worldinteractions']:UpdateActivePosition(
                                target.x, target.y, target.z, wantedRotation.z) == true
                        end
                    end)
                end

                if not handledByWorldInteractions then
                    -- No active worldinteractions scenario: just teleport and freeze in place.
                    -- FreezeEntityPosition replicates via OneSync so other clients see the new position.
                    SetEntityCoordsNoOffset(currentPed, target.x, target.y, target.z, false, false, false)
                    SetEntityRotation(currentPed, wantedRotation.x, wantedRotation.y, wantedRotation.z, 2, true)
                    SetEntityHeading(currentPed, wantedRotation.z)
                    FreezeEntityPosition(currentPed, true)
                end

                TriggerEvent('thehunt_status:notify', 'Позиция персонажа', 'Положение сохранено.', 'success', true)
            else
                restore()
            end
            positionSession = nil
        end
    })
    if not started then
        cleanupAnchor()
        destroyCamera()
        positionSession = nil
    end
    return started == true
end

local function IsDisplayMode(mode)
    return mode == "always_on" or mode == "dynamic" or mode == "always_off"
end

local function IsHintsDisplayMode(mode)
    return mode == "always_on" or mode == "always_off"
end

-- Код и стили походки полностью из vorp_walkanim
local old = nil

local function setAnim(animation)
    if old then
        Citizen.InvokeNative(0xA6F67BEC53379A32, PlayerPedId(), old)
    end
    Citizen.InvokeNative(0xCB9401F918CB0F75, PlayerPedId(), animation, 1, -1)
    old = animation
    currentWalkStyle = animation
    TriggerServerEvent("vorp_walkanim:setwalk", animation)
end

local function LoadDisplayModes()
    local savedHudMode = GetResourceKvpString("thehunt_status_hud_mode")
    currentHudMode = IsDisplayMode(savedHudMode) and savedHudMode or "always_on"

    local savedQuickSlotsMode = GetResourceKvpString("thehunt_status_quickslots_mode")
    currentQuickSlotsMode = IsDisplayMode(savedQuickSlotsMode) and savedQuickSlotsMode or "always_on"

    local savedHintsMode = GetResourceKvpString("thehunt_status_hints_mode")
    currentHintsMode = IsHintsDisplayMode(savedHintsMode) and savedHintsMode or "always_on"
    if savedHintsMode == "dynamic" then
        SetResourceKvp("thehunt_status_hints_mode", "always_on")
    end

    TriggerEvent("thehunt_status:setHudMode", currentHudMode)
    TriggerEvent("thehunt_status:setQuickSlotsMode", currentQuickSlotsMode)
    TriggerEvent("thehunt_status:setHintsMode", currentHintsMode)
end

-- Ожидание завершения выбора персонажа VORP
RegisterNetEvent("thehunt:character:selected", function()
    isCharacterSelected = true
    LoadDisplayModes()
    TriggerServerEvent("thehunt_menu:requestInitialWalkStyle")
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(1000)
        isCharacterSelected = true
        LoadDisplayModes()
        TriggerServerEvent("thehunt_menu:requestInitialWalkStyle")
        return
    end

    -- Если status перезапустили отдельно, повторно отправляем ему сохраненные режимы.
    if resourceName == "thehunt_status" and isCharacterSelected then
        Wait(100)
        LoadDisplayModes()
    end
end)

-- Функция открытия/закрытия меню
local function TogglePlayerMenu()
    if not isCharacterSelected then return end
    if IsPauseMenuActive() then return end

    isMenuOpen = not isMenuOpen

    if isMenuOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)

        SendNUIMessage({
            type = 'OPEN_PLAYER_MENU',
            hudMode = currentHudMode,
            quickSlotsMode = currentQuickSlotsMode,
            hintsMode = currentHintsMode,
            walkStyle = currentWalkStyle,
            positionEnabled = IsCharacterPositionAvailable()
        })
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'CLOSE_PLAYER_MENU' })
    end
end

-- Регистрация команд
RegisterCommand('playermenu', TogglePlayerMenu, false)
RegisterCommand('pmenu', TogglePlayerMenu, false)
RegisterCommand('menu', TogglePlayerMenu, false)
RegisterCommand('m', TogglePlayerMenu, false)

-- Привязка клавиши Ё / ~ (VK_OEM_3 = 0xC0 / 192) через RegisterRawKeymap RedM
pcall(function()
    if RegisterRawKeymap then
        local KEY_TILDE = 0xC0 -- VK_OEM_3 (Клавиша ~ / Ё)
        RegisterRawKeymap("thehunt_playermenu_tilde", function()
            TogglePlayerMenu()
        end, function() end, KEY_TILDE, true)
    end
end)

-- Закрытие из NUI
RegisterNUICallback('closePlayerMenu', function(data, cb)
    isMenuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cb('ok')
end)

RegisterNUICallback('requestCharacterPosition', function(data, cb)
    isMenuOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'CLOSE_PLAYER_MENU' })
    -- CEF releases focus on the next frame. Starting immediately can make the
    -- shared gizmo reject the request as "NUI already focused".
    CreateThread(function()
        Wait(0)
        StartCharacterPositionGizmo()
    end)
    cb('ok')
end)

CreateThread(function()
    local lastPositionState = nil
    while true do
        Wait(250)
        if isMenuOpen then
            local available = IsCharacterPositionAvailable()
            if available ~= lastPositionState then
                lastPositionState = available
                SendNUIMessage({ type = 'UPDATE_CHARACTER_POSITION', enabled = available })
            end
        else
            lastPositionState = nil
        end
    end
end)

-- Запрос перезагрузки персонажа
RegisterNUICallback('requestCharacterReload', function(data, cb)
    TriggerServerEvent("thehunt_menu:reloadCharacter")
    cb('ok')
end)

-- Смена режима статус-худа
RegisterNUICallback('setHudMode', function(data, cb)
    local mode = data.mode
    if IsDisplayMode(mode) then
        currentHudMode = mode
        SetResourceKvp("thehunt_status_hud_mode", mode)
        TriggerEvent("thehunt_status:setHudMode", mode)
    end
    cb('ok')
end)

-- Смена режима HUD подсказок
RegisterNUICallback('setQuickSlotsMode', function(data, cb)
    local mode = data.mode
    if IsDisplayMode(mode) then
        currentQuickSlotsMode = mode
        SetResourceKvp("thehunt_status_quickslots_mode", mode)
        TriggerEvent("thehunt_status:setQuickSlotsMode", mode)
    end
    cb('ok')
end)

RegisterNUICallback('setHintsMode', function(data, cb)
    local mode = data.mode
    if IsHintsDisplayMode(mode) then
        currentHintsMode = mode
        SetResourceKvp("thehunt_status_hints_mode", mode)
        TriggerEvent("thehunt_status:setHintsMode", mode)
        pcall(function()
            exports["thehunt_status"]:SetHintsMode(mode)
        end)
    end
    cb('ok')
end)

-- Смена стиля походки из меню (прямой вызов vorp_walkanim)
RegisterNUICallback('setWalkStyle', function(data, cb)
    local animation = data.style
    if animation and type(animation) == "string" then
        TriggerEvent("vorp_walkanim:Client:setAnim", animation)
        setAnim(animation)
        -- Persist the menu selection for the active character. The server
        -- validates the style against the menu's fixed whitelist.
        TriggerServerEvent("thehunt_menu:saveWalkStyle", animation)
    end
    cb('ok')
end)

-- Синхронизация стиля походки с сервера
RegisterNetEvent("thehunt_menu:setWalkStyle", function(walk)
    if walk and walk ~= "" then
        setAnim(walk)
    end
end)

RegisterNetEvent("vorp_walkanim:Server:setwalk", function(walk)
    local animation = walk
    local player = PlayerPedId()
    if animation == "noanim" then
        Citizen.InvokeNative(0xA6F67BEC53379A32, PlayerPedId(), "MP_Style_Casual")
        return
    end
    Citizen.InvokeNative(0xCB9401F918CB0F75, player, animation, 1, -1)
    currentWalkStyle = animation
    old = animation
end)

-- Мгновенная перезагрузка персонажа прямо на месте (без затемнений и телепортов)
RegisterNetEvent("thehunt_menu:applyCharacterReload", function(charSkin, charComps, charCompTints, savedWalkStyle)
    local ped = PlayerPedId()

    -- 1. Сброс залипших тасков, рэгдолла, анимаций, коллизий и заморозки
    ClearPedTasksImmediately(ped)
    ClearPedSecondaryTask(ped)
    SetPedToRagdoll(ped, 0, 0, 0, false, false, false)
    SetEntityAlpha(ped, 255, false)
    SetEntityVisible(ped, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityCanBeDamaged(ped, true)

    -- 2. Rebuild the saved body/face state, while retaining the clothes that
    -- are currently equipped through the inventory.  The old implementation
    -- executed `rc` and then sent a full VORP cache update, which re-applied
    -- stale clothing from the character row over the equipment inventory.
    if charSkin then
        local ok, appearance = pcall(function()
            return exports["thehunt_character"]:GetAppearanceState()
        end)
        local current = ok and type(appearance) == "table" and appearance or {}
        local currentComps = current.comps or {}
        local currentTints = current.compTints or {}
        local mergedComps, mergedTints = {}, {}
        for category, value in pairs(charComps or {}) do
            mergedComps[category] = value
        end
        for category, value in pairs(charCompTints or {}) do
            mergedTints[category] = value
        end
        -- Inventory clothing is authoritative at runtime. Keep those live
        -- tags when restoring the rest of the database appearance.
        local inventoryCategories = {
            Hat=true, Mask=true, EyeWear=true, NeckWear=true, Shirt=true,
            Vest=true, Coat=true, CoatClosed=true, Poncho=true, Cloak=true,
            Pant=true, Skirt=true, Dress=true, Boots=true, Spurs=true,
            Spats=true, Chap=true, Gunbelt=true, Holster=true, Belt=true,
            Buckle=true, Suspender=true, Glove=true, Gauntlets=true,
            Accessories=true, Badge=true, Bracelet=true, RingLh=true,
            RingRh=true, Satchels=true
        }
        for category in pairs(inventoryCategories) do
            if currentComps[category] ~= nil then mergedComps[category] = currentComps[category] end
            if currentTints[category] ~= nil then mergedTints[category] = currentTints[category] end
        end
        local applied = pcall(function()
            exports['thehunt_character']:ApplyDatabaseAppearance(charSkin, mergedComps, mergedTints, current.gender)
        end)
        if not applied then
            TriggerEvent("thehunt_character:client:ApplyDatabaseAppearance", charSkin, mergedComps, mergedTints, current.gender)
        end
    end

    -- 3. Восстановление стандартно выбранной походки / анимации движения
    pcall(function()
        local walkAnim = savedWalkStyle or "MP_Style_Casual"
        setAnim(walkAnim)
    end)

    -- 4. Восстановление скорости походки
    pcall(function()
        if exports["thehunt_walking"] and exports["thehunt_walking"].ApplyCurrentSpeed then
            exports["thehunt_walking"]:ApplyCurrentSpeed()
        end
    end)

    -- 5. Единое уведомление через thehunt_status
    TriggerEvent("thehunt_status:notify", "Персонаж", "Внешний вид и походка обновлены", "success", true)
end)

exports('isPlayerMenuOpen', function()
    return isMenuOpen == true
end)

exports('isMenuOpen', function()
    return isMenuOpen == true
end)
