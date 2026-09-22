-- =================================================================
-- HUNT: Hard RP — The Corruption | Admin Editor Freecam Controller
-- =================================================================

EditorCam = {}

local isFreecamActive = false
local freecamHandle = nil
local camPos = vector3(0, 0, 0)
local camRot = vector3(0, 0, 0)
local originalPedCoords = nil
local lastFocusPos = vector3(0, 0, 0)

local MOVE_SPEED = 0.4
local FAST_MOVE_SPEED = 1.6
local SLOW_MOVE_SPEED = 0.1
local LOOK_SENSITIVITY = 4.0

function EditorCam.IsActive()
    return isFreecamActive
end

function EditorCam.GetCoords()
    if isFreecamActive and freecamHandle and DoesCamExist(freecamHandle) then
        return camPos
    end
    return GetGameplayCamCoord()
end

function EditorCam.GetRotation()
    if isFreecamActive and freecamHandle and DoesCamExist(freecamHandle) then
        return camRot
    end
    return GetGameplayCamRot(2)
end

function EditorCam.Teleport(coords)
    if not coords then return end
    camPos = vector3(coords.x, coords.y, coords.z + 2.5)
    if freecamHandle and DoesCamExist(freecamHandle) then
        SetCamCoord(freecamHandle, camPos.x, camPos.y, camPos.z)
    end

    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false)
        SetEntityInvincible(ped, true)
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    lastFocusPos = camPos
end

-- =================================================================
-- 1. СТАРТ И СТОП СВОБОДНОЙ КАМЕРЫ
-- =================================================================

function EditorCam.Start(startCoords)
    if isFreecamActive then return end

    local ped = PlayerPedId()
    originalPedCoords = GetEntityCoords(ped)
    local gameplayCamRot = GetGameplayCamRot(2)

    camPos = startCoords or (originalPedCoords + vector3(0.0, 0.0, 3.0))
    camRot = gameplayCamRot

    freecamHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(freecamHandle, camPos.x, camPos.y, camPos.z)
    SetCamRot(freecamHandle, camRot.x, camRot.y, camRot.z, 2)
    SetCamActive(freecamHandle, true)
    RenderScriptCams(true, true, 400, true, false)

    -- Скрываем и защищаем игрока пока он в редакторе
    SetEntityVisible(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    RequestCollisionAtCoord(camPos.x, camPos.y, camPos.z)
    SetFocusPosAndVel(camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0)
    lastFocusPos = camPos

    isFreecamActive = true
    EditorCam.StartControlLoop()
end

function EditorCam.Stop()
    if not isFreecamActive then return end
    isFreecamActive = false

    if freecamHandle and DoesCamExist(freecamHandle) then
        SetCamActive(freecamHandle, false)
        DestroyCam(freecamHandle, true)
        freecamHandle = nil
    end

    RenderScriptCams(false, true, 400, true, false)
    ClearFocus()

    local ped = PlayerPedId()
    if DoesEntityExist(ped) and originalPedCoords then
        SetEntityCoords(ped, originalPedCoords.x, originalPedCoords.y, originalPedCoords.z, false, false, false, false)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        SetEntityInvincible(ped, false)
    end
    originalPedCoords = nil
end

-- =================================================================
-- 2. 3D RAYCAST ИЗ ЦЕНТРА КАМЕРЫ В МИР
-- =================================================================

function EditorCam.RaycastFromCamera(maxDistance)
    local dist = maxDistance or 120.0
    local curPos = EditorCam.GetCoords()
    local curRot = EditorCam.GetRotation()

    local radZ = math.rad(curRot.z)
    local radX = math.rad(curRot.x)

    local forward = vector3(
        -math.sin(radZ) * math.cos(radX),
        math.cos(radZ) * math.cos(radX),
        math.sin(radX)
    )

    local destCoords = curPos + (forward * dist)
    local shapeTest = StartShapeTestRay(curPos.x, curPos.y, curPos.z, destCoords.x, destCoords.y, destCoords.z, 287, PlayerPedId(), 4)
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(shapeTest)

    local isHit = (hit == 1 or hit == true) and #(endCoords - vector3(0, 0, 0)) > 2.0

    return {
        hit = isHit,
        coords = isHit and endCoords or destCoords,
        normal = surfaceNormal,
        entity = (entityHit ~= 0 and DoesEntityExist(entityHit)) and entityHit or nil
    }
end

-- =================================================================
-- 3. ЦИКЛ УПРАВЛЕНИЯ СВОБОДНОЙ КАМЕРОЙ
-- =================================================================

function EditorCam.StartControlLoop()
    Citizen.CreateThread(function()
        while isFreecamActive do
            Citizen.Wait(0)

            -- Блокируем управление камерой если открыто NUI окно с активным вводом текста
            if not Editor or not Editor.IsInputFocused or not Editor.IsInputFocused() then
                local speed = MOVE_SPEED

                -- Ускорение через Shift, замедление через Alt
                if IsDisabledControlPressed(0, 0x8FFC75D6) or IsControlPressed(0, 0x8FFC75D6) then -- Shift
                    speed = FAST_MOVE_SPEED
                elseif IsDisabledControlPressed(0, 0xDBCD0363) or IsControlPressed(0, 0xDBCD0363) then -- Alt
                    speed = SLOW_MOVE_SPEED
                end

                -- Вращение камеры мышью ТОЛЬКО при зажатой правой кнопке мыши (ПКМ / RMB)
                local isRMBPressed = IsDisabledControlPressed(0, 0xF84FA74F) or IsControlPressed(0, 0xF84FA74F) 
                                  or IsDisabledControlPressed(0, 0x07CE1E61) or IsControlPressed(0, 0x07CE1E61)
                                  or IsDisabledControlPressed(0, 0xA5D7C235) or IsControlPressed(0, 0xA5D7C235)

                if isRMBPressed then
                    local mouseX = GetDisabledControlNormal(0, 0xA987235F) * LOOK_SENSITIVITY
                    local mouseY = GetDisabledControlNormal(0, 0xD2047988) * LOOK_SENSITIVITY

                    camRot = vector3(
                        math.max(-85.0, math.min(85.0, camRot.x - (mouseY * 8.0))),
                        0.0,
                        camRot.z - (mouseX * 8.0)
                    )
                end

                local radZ = math.rad(camRot.z)
                local radX = math.rad(camRot.x)

                local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
                local right   = vector3(math.cos(radZ), math.sin(radZ), 0.0)
                local up      = vector3(0.0, 0.0, 1.0)

                -- Движение W/S
                if IsDisabledControlPressed(0, 0x8FD015D8) or IsControlPressed(0, 0x8FD015D8) then -- W
                    camPos = camPos + (forward * speed)
                end
                if IsDisabledControlPressed(0, 0xD27782E3) or IsControlPressed(0, 0xD27782E3) then -- S
                    camPos = camPos - (forward * speed)
                end

                -- Движение A/D
                if IsDisabledControlPressed(0, 0x7065027D) or IsControlPressed(0, 0x7065027D) then -- A
                    camPos = camPos - (right * speed)
                end
                if IsDisabledControlPressed(0, 0xB4E465B4) or IsControlPressed(0, 0xB4E465B4) then -- D
                    camPos = camPos + (right * speed)
                end

                -- Подъем/Спуск Q/E
                if IsDisabledControlPressed(0, 0xDE794E3E) or IsControlPressed(0, 0xDE794E3E) then -- Q (Вверх)
                    camPos = camPos + (up * speed)
                end
                if IsDisabledControlPressed(0, 0xCEFD9220) or IsControlPressed(0, 0xCEFD9220) then -- E (Вниз)
                    camPos = camPos - (up * speed)
                end

                -- Применяем позицию и поворот камеры
                if freecamHandle and DoesCamExist(freecamHandle) then
                    SetCamCoord(freecamHandle, camPos.x, camPos.y, camPos.z)
                    SetCamRot(freecamHandle, camRot.x, camRot.y, camRot.z, 2)
                end

                -- Динамическое обновление фокуса и коллизий мира при перемещении камеры
                if #(camPos - lastFocusPos) > 25.0 then
                    lastFocusPos = camPos
                    local ped = PlayerPedId()
                    if DoesEntityExist(ped) then
                        SetEntityCoords(ped, camPos.x, camPos.y, camPos.z, false, false, false, false)
                        FreezeEntityPosition(ped, true)
                        SetEntityVisible(ped, false)
                    end
                    RequestCollisionAtCoord(camPos.x, camPos.y, camPos.z)
                    SetFocusPosAndVel(camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0)
                end
            end
        end
    end)
end
