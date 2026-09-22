-- =================================================================
-- HUNT: Hard RP — The Corruption | Инструменты тестирования (Только для Админов)
-- =================================================================

-- =================================================================
-- 1. БЫСТРАЯ ВЫДАЧА ОРУЖИЯ ДЛЯ ТЕСТОВ (/weapon [название])
-- =================================================================
RegisterCommand("weapon", function(source, args)
    TriggerServerEvent("thehunt_admin:executeTestingCommand", "weapon", args[1])
end, false)

-- =================================================================
-- 2. ПОЛНОЕ ПОПОЛНЕНИЕ ПАТРОНОВ (/ammo)
-- =================================================================
RegisterCommand("ammo", function()
    TriggerServerEvent("thehunt_admin:executeTestingCommand", "ammo")
end, false)

-- =================================================================
-- 3. МАГИЯ: ТЕСТОВЫЙ ФАЕРБОЛ (/fireball)
-- =================================================================
local function GetCameraDirection()
    local rot = GetGameplayCamRot(2)
    local pitch = math.rad(rot.x)
    local yaw = math.rad(rot.z)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

RegisterCommand("fireball", function()
    TriggerServerEvent("thehunt_admin:executeTestingCommand", "fireball")
end, false)

RegisterNetEvent("thehunt_admin:applyWeaponClient", function(weaponName)
    local weaponHash = GetHashKey(weaponName or "WEAPON_REVOLVER_CATTLEMAN")
    local playerPed = PlayerPedId()
    Citizen.InvokeNative(0x5E3BDDBCB83F3D84, playerPed, weaponHash, 100, true, true, 0, false, 0.5, 1.0, 0, 0)
    print("^2[HUNT] Оружие выдано: " .. tostring(weaponName) .. "^7")
end)

RegisterNetEvent("thehunt_admin:applyAmmoClient", function()
    local playerPed = PlayerPedId()
    local _, currentWeapon = GetCurrentPedWeapon(playerPed, true)

    if currentWeapon and currentWeapon ~= 0 and currentWeapon ~= GetHashKey("WEAPON_UNARMED") then
        SetPedAmmo(playerPed, currentWeapon, 999)
        RefillAmmoInClip(playerPed, currentWeapon)
    else
        local commonWeapons = {
            GetHashKey("WEAPON_REVOLVER_CATTLEMAN"),
            GetHashKey("WEAPON_REVOLVER_SCHOFIELD"),
            GetHashKey("WEAPON_REPEATER_WINCHESTER"),
            GetHashKey("WEAPON_SHOTGUN_DOUBLEBARREL"),
            GetHashKey("WEAPON_RIFLE_SPRINGFIELD"),
            GetHashKey("WEAPON_SNIPERRIFLE_CARCANO"),
            GetHashKey("WEAPON_BOW")
        }
        for _, wep in ipairs(commonWeapons) do
            if HasPedGotWeapon(playerPed, wep, false) then
                SetPedAmmo(playerPed, wep, 999)
            end
        end
    end
    print("^2[HUNT] Патроны пополнены!^7")
end)

RegisterNetEvent("thehunt_admin:castFireballClient", function()
    local playerPed = PlayerPedId()

    -- 1. Анимация каста (взмах рукой вперед)
    TaskShootAtCoord(playerPed, 0.0, 0.0, 0.0, 100, GetHashKey("FIRING_PATTERN_FULL_AUTO"))
    Citizen.Wait(150)
    ClearPedTasks(playerPed)

    -- 2. Начальная точка фаербола (на уровне груди)
    local startCoords = GetEntityCoords(playerPed) + vector3(0.0, 0.0, 0.6)
    local forwardVec = GetCameraDirection()
    local currentCoords = startCoords + (forwardVec * 1.5)

    -- 3. Запускаем полет огненного шара
    Citizen.CreateThread(function()
        local speed = 1.8         -- Скорость полета шара
        local maxDistance = 60.0  -- Максимальная дальность (60 метров)
        local traveled = 0.0

        while traveled < maxDistance do
            Citizen.Wait(0)

            local nextCoords = currentCoords + (forwardVec * speed)
            traveled = traveled + speed

            -- Динамический оранжевый свет от летящего шара
            DrawLightWithRange(currentCoords.x, currentCoords.y, currentCoords.z, 255, 90, 10, 8.0, 25.0)

            -- Проверяем столкновение лучом (Raycast)
            local ray = StartShapeTestRay(
                currentCoords.x, currentCoords.y, currentCoords.z,
                nextCoords.x, nextCoords.y, nextCoords.z,
                -1, playerPed, 0
            )
            local _, hit, hitCoords, _, entityHit = GetShapeTestResult(ray)

            -- Если врезались во что-то (земля, стена, объект, игрок)
            if hit == 1 then
                AddExplosion(hitCoords.x, hitCoords.y, hitCoords.z, 25, 3.0, true, false, 1.5)
                AddExplosion(hitCoords.x, hitCoords.y, hitCoords.z, 0, 1.0, true, false, 2.0)
                StartScriptFire(hitCoords.x, hitCoords.y, hitCoords.z, 25, true)
                break
            end

            currentCoords = nextCoords
        end
    end)

    print("^1[MAGIC] Огненный шар запущен!^7")
end)
