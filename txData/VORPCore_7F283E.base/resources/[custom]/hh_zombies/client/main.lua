local ZOMBIE_GROUP <const> = `hh_zombie`
local AGGRO_GROUP <const> = `hh_zombie_aggro`
local PLAYER_GROUP <const> = `PLAYER`

local active = {} -- [zoneId] = { { ped = ..., blip = ... }, ... }
local lastGunshotAt = 0
local ignoreLocalPlayerAggro = false
local modelBags = {}
local outfitBags = {}
local soundFiles = { alive = {}, death = {} }
local audioReady = false
local xsounds = {} -- [soundId] = { ped = ped, expiresAt = ms }
local soundCounter = 0
local zoneState = {} -- [zoneId] = { enteredAt, lastRestockAt, initialDone, inside, lingerEndsAt }
local zoneAuth = {} -- [zoneId] = { canSpawn, freezeRestock, occupants }
local Zones = {}
local zoneBlips = {}
local lastCreatedZoneId = nil
local adminAccess = false
local adminSuggestionsAdded = false

function IsZombieAdmin()
    return adminAccess == true
end

local function denyAdmin()
    TriggerEvent("chat:addMessage", { args = { "hh_zombies", "Нет прав." } })
end

local function requireAdmin()
    if adminAccess then
        return true
    end
    TriggerServerEvent("hh_zombies:requestAdmin")
    denyAdmin()
    return false
end

local function addAdminSuggestions()
    if adminSuggestionsAdded then
        return
    end
    adminSuggestionsAdded = true
    TriggerEvent("chat:addSuggestion", "/zpeace", "Снять/вернуть агр зомби с локального игрока, сохранив реакцию на шум")
    TriggerEvent("chat:addSuggestion", "/zinfo", "Показать модель и outfit ближайшего зомби для чёрного списка")
    TriggerEvent("chat:addSuggestion", "/zsound", "Проверить звук зомби: /zsound или /zsound dead")
    TriggerEvent("chat:addSuggestion", "/zzone", "Текущие координаты точки")
    TriggerEvent("chat:addSuggestion", "/zonelist", "Список зомби-зон")
    TriggerEvent("chat:addSuggestion", "/zonedel", "Удалить зону по id из /zonelist")
    TriggerEvent("chat:addSuggestion", "/zarea", "F11: вид сверху, мышью центр и размер зоны")
    TriggerEvent("chat:addSuggestion", "/zzones", "F12: список созданных зон и удаление")
end

RegisterNetEvent("hh_zombies:setAdmin", function(allowed)
    adminAccess = allowed == true
    if adminAccess then
        addAdminSuggestions()
    end
end)

RegisterNetEvent("vorp:SelectedCharacter", function()
    TriggerServerEvent("hh_zombies:requestAdmin")
end)

local function discoverSoundFiles()
    local function addFiles(source, target)
        for i = 1, #(source or {}) do
            local name = source[i]
            target[#target + 1] = name:match("^sound/") and name or ("sound/" .. name)
        end
    end

    local settings = Config.Sound or {}
    addFiles(settings.aliveFiles, soundFiles.alive)
    addFiles(settings.deathFiles, soundFiles.death)
end

local lastAliveAt = 0
local aliveFileIndex = 0

local function nextSoundDelay()
    local settings = Config.Sound or {}
    local minDelay = settings.minInterval or 5000
    local maxDelay = math.max(minDelay, settings.maxInterval or 15000)
    return math.random(minDelay, maxDelay)
end

local function soundUrl(file)
    -- xsoundRelativePath ждёт файлы внутри xsound/html/sounds/
    if Config.Sound and Config.Sound.xsoundRelativePath then
        return "./sounds/" .. (file:match("([^/]+)$") or file)
    end

    return ("https://cfx-nui-%s/%s"):format(GetCurrentResourceName(), file)
end

local function xsoundReady()
    local settings = Config.Sound or {}
    return settings.useXSound ~= false and GetResourceState("xsound") == "started"
end

local function destroyXSound(soundId)
    if not soundId then
        return
    end

    pcall(function()
        if exports.xsound:soundExists(soundId) then
            exports.xsound:Destroy(soundId)
        end
    end)
    xsounds[soundId] = nil
end

local function xsoundStillPlaying(soundId)
    if not soundId then
        return false
    end

    local playing = false
    pcall(function()
        playing = exports.xsound:soundExists(soundId) and exports.xsound:isPlaying(soundId)
    end)
    return playing
end

local function pickSoundFile(category)
    local files = soundFiles[category]
    if not files or #files == 0 then
        return nil
    end

    if category == "alive" then
        aliveFileIndex = (aliveFileIndex % #files) + 1
        return files[aliveFileIndex]
    end

    return files[math.random(#files)]
end

-- xsound даёт позиционный звук от самого педа. Дистанцией управляет он сам,
-- поэтому громкость тут не затухает вручную.
local function playViaXSound(entry, category, file, baseVolume, maxDistance)
    soundCounter = soundCounter + 1
    local soundId = ("hh_zombie_%d"):format(soundCounter)
    local settings = Config.Sound or {}
    local lifetime = category == "death"
        and (settings.deathLifetime or 9000)
        or (settings.aliveLifetime or 6000)

    local ok = pcall(function()
        exports.xsound:PlayUrlPos(
            soundId,
            soundUrl(file),
            baseVolume,
            GetEntityCoords(entry.ped),
            false
        )
        exports.xsound:Distance(soundId, math.floor(maxDistance))
    end)

    if not ok then
        return false
    end

    xsounds[soundId] = {
        ped = entry.ped,
        category = category,
        expiresAt = GetGameTimer() + lifetime,
    }
    entry.soundId = soundId
    return true
end

local function activeAliveSoundCount()
    local count = 0
    for _, data in pairs(xsounds) do
        if data.category ~= "death" then
            count = count + 1
        end
    end
    return count
end

local function playZombieSound(entry, category)
    local settings = Config.Sound
    local files = soundFiles[category]

    if not settings or not settings.enabled or not files or #files == 0 then
        return false, "off"
    end
    if not entry.ped or not DoesEntityExist(entry.ped) then
        return false, "missing"
    end

    local maxDistance = category == "death"
        and (settings.deathDistance or settings.maxDistance or 22.0)
        or (settings.aliveDistance or 12.0)
    local distance = #(GetEntityCoords(entry.ped) - GetEntityCoords(PlayerPedId()))
    if distance > maxDistance then
        return false, "far"
    end

    local limit = category == "death"
        and 4
        or (settings.maxAliveSimultaneous or settings.maxSimultaneous or 2)
    if category ~= "death" then
        if activeAliveSoundCount() >= limit then
            return false, "busy"
        end
        local gap = settings.aliveMinGap or 1500
        if GetGameTimer() - lastAliveAt < gap then
            return false, "busy"
        end
    end

    -- Живой рык доигрывает до конца. Смерть может перебить текущий звук.
    if entry.soundId then
        if category ~= "death" and xsoundStillPlaying(entry.soundId) then
            return false, "busy"
        end
        destroyXSound(entry.soundId)
        entry.soundId = nil
    end

    local file = pickSoundFile(category)
    if not file then
        return false, "off"
    end

    local baseVolume = category == "death"
        and (settings.deathVolume or 0.11)
        or (settings.maxVolume or 0.09)

    if category ~= "death" and activeAliveSoundCount() >= 1 then
        baseVolume = baseVolume * 0.7
    end

    if xsoundReady() and playViaXSound(entry, category, file, baseVolume, maxDistance) then
        if category ~= "death" then
            lastAliveAt = GetGameTimer()
        end
        return true, "ok"
    end

    -- Резерв: обычный NUI-плеер с ручным затуханием по дистанции.
    SendNUIMessage({
        action = "playZombieSound",
        file = file,
        volume = (1.0 - distance / maxDistance) * baseVolume,
        priority = category == "death",
        maxSimultaneous = limit,
    })
    if category ~= "death" then
        lastAliveAt = GetGameTimer()
    end
    return true, "ok"
end

local function shuffle(values)
    for i = #values, 2, -1 do
        local j = math.random(i)
        values[i], values[j] = values[j], values[i]
    end
    return values
end

local function nextModel(zoneId, models)
    local bag = modelBags[zoneId]
    if not bag or #bag == 0 then
        bag = {}
        for i = 1, #models do
            bag[i] = models[i]
        end
        modelBags[zoneId] = shuffle(bag)
    end
    return table.remove(bag)
end

local function nextOutfit(model)
    local key = model:lower()
    local count = (Config.ModelOutfitCounts and Config.ModelOutfitCounts[key]) or 1
    local blocked = Config.ModelOutfitBlacklist and Config.ModelOutfitBlacklist[key] or {}
    local bag = outfitBags[key]

    if not bag or #bag == 0 then
        bag = {}
        for outfit = 0, count - 1 do
            if not blocked[outfit] then
                bag[#bag + 1] = outfit
            end
        end
        if #bag == 0 then
            bag[1] = 0
        end
        outfitBags[key] = shuffle(bag)
    end

    return table.remove(bag)
end

local function dbg(...)
    if Config.Debug then
        print("[hh_zombies]", ...)
    end
end

RegisterNUICallback("audioReady", function(_, cb)
    audioReady = true
    cb("ok")
end)

RegisterNUICallback("audioPlayed", function(_, cb)
    cb("ok")
end)

RegisterNUICallback("audioError", function(_, cb)
    cb("ok")
end)

local function setupRelationships()
    AddRelationshipGroup("hh_zombie")
    AddRelationshipGroup("hh_zombie_aggro")
    -- Шоб когда одного пиздишь, на тебя не бежала вся толпа хуяриться насмерть
    SetRelationshipBetweenGroups(3, ZOMBIE_GROUP, PLAYER_GROUP)
    SetRelationshipBetweenGroups(3, PLAYER_GROUP, ZOMBIE_GROUP)
    SetRelationshipBetweenGroups(5, AGGRO_GROUP, PLAYER_GROUP)
    SetRelationshipBetweenGroups(5, PLAYER_GROUP, AGGRO_GROUP)
end

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) then
        return nil
    end

    RequestModel(hash, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            return nil
        end
        Wait(0)
        RequestModel(hash, false)
    end

    return hash
end

local function groundAt(x, y, fromZ)
    local ok, found, ground = pcall(GetGroundZFor_3dCoord, x, y, fromZ, false)
    if ok and found and ground and ground ~= 0.0 then
        return ground
    end
    return nil
end

local function spawnPoint(origin, minDistance, maxDistance, maxHeightDiff, avoidCoords, avoidDistance)
    for _ = 1, (Config.SpawnAttempts or 25) do
        local distance = minDistance + math.random() * math.max(0.0, maxDistance - minDistance)
        local angle = math.random() * math.pi * 2.0
        local x = origin.x + math.cos(angle) * distance
        local y = origin.y + math.sin(angle) * distance

        RequestCollisionAtCoord(x, y, origin.z)
        Wait(20)

        local ground = groundAt(x, y, origin.z + 4.0) or groundAt(x, y, origin.z + 20.0)
        if ground and math.abs(ground - origin.z) < (maxHeightDiff or 8.0) then
            -- 28 отсекает interior/water и требует пригодный плоский navmesh.
            local ok, found, safe = pcall(GetSafeCoordForPed, x, y, ground + 0.5, false, 28)

            if ok
                and found
                and safe
                and safe.x
                and math.abs(safe.z - origin.z) < (maxHeightDiff or 8.0)
                and not IsAnyPedNearPoint(safe.x, safe.y, safe.z, 1.5) then
                if not avoidCoords
                    or not avoidDistance
                    or avoidDistance <= 0.0
                    or #(vector3(safe.x, safe.y, safe.z) - avoidCoords) >= avoidDistance then
                    return safe.x, safe.y, safe.z
                end
            end
        end
        Wait(0)
    end

    -- Шоб в текстуры гады не лезли
    return nil
end

local function fadeInPed(ped)
    local fadeMs = (Config.Zombie and Config.Zombie.spawnFadeMs) or 0
    if fadeMs <= 0 or not DoesEntityExist(ped) then
        return
    end

    SetEntityAlpha(ped, 0, false)
    CreateThread(function()
        local started = GetGameTimer()
        while DoesEntityExist(ped) do
            local progress = (GetGameTimer() - started) / fadeMs
            if progress >= 1.0 then
                ResetEntityAlpha(ped)
                return
            end
            SetEntityAlpha(ped, math.floor(progress * 255), false)
            Wait(30)
        end
    end)
end

-- CS / corpse модели часто спавнятся «пустым» пресетом 0
local function applyOutfit(ped, preset)
    if preset then
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, preset, true)
    else
        Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    end
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    SetEntityVisible(ped, true, false)
end

local function applyLocomotion(ped, style, base)
    local locomotion = Config.Zombie.locomotion
    if not locomotion or not style then
        return
    end

    Citizen.InvokeNative(0x923583741DC87BCE, ped, base or locomotion.base or "default")
    Citizen.InvokeNative(0x89F5E7ADECCCB49C, ped, style)
end

local function limitSpeed(ped, movementMode, entry)
    local locomotion = Config.Zombie.locomotion
    if not locomotion then
        return
    end

    local profile = entry and entry.speedProfile
    local maxBlend
    local moveRate

    local minBlend = 0.0

    if movementMode == "run" and profile then
        maxBlend = profile.maxBlend or locomotion.runMaxBlend or 1.25
        moveRate = profile.moveRate or locomotion.moveRate or 0.72
        minBlend = profile.minBlend or 0.0
    else
        maxBlend = movementMode == "run"
            and (locomotion.runMaxBlend or 1.25)
            or (locomotion.walkMaxBlend or 0.75)
        moveRate = locomotion.moveRate or 0.72
    end

    SetPedMaxMoveBlendRatio(ped, maxBlend)
    if SetPedMinMoveBlendRatio then
        SetPedMinMoveBlendRatio(ped, minBlend)
    end

    -- Есть не во всех сборках RedM, поэтому вызов безопасный.
    if SetPedMoveRateOverride then
        SetPedMoveRateOverride(ped, moveRate)
    end
end

local function releaseSpeedLimit(ped)
    SetPedMaxMoveBlendRatio(ped, 3.0)
    if SetPedMinMoveBlendRatio then
        SetPedMinMoveBlendRatio(ped, 0.0)
    end
    if SetPedMoveRateOverride then
        SetPedMoveRateOverride(ped, 1.0)
    end
end

local function chasePlayer(ped, playerPed, entry)
    local locomotion = Config.Zombie.locomotion
    local stopDistance = locomotion and locomotion.chaseStopDistance or 1.2
    local speed = locomotion and locomotion.chaseSpeed or 0.55
    local arms = Config.Zombie.armsRun

    if entry and entry.speedProfile then
        speed = entry.speedProfile.chaseSpeed or speed
    elseif entry and entry.armsRunner and arms then
        speed = arms.speed or 0.75
    end

    TaskGoToEntity(ped, playerPed, -1, stopDistance, speed, 1073741824, 0)
end

local function goToPoint(ped, coords, speed, stopDistance)
    -- Это для шоб зомби ходить могли, типа крутые
    if TaskGoToCoordAnyMeans then
        local ok = pcall(
            TaskGoToCoordAnyMeans,
            ped,
            coords.x, coords.y, coords.z,
            speed,
            0,
            true,
            0,
            0.5
        )
        if ok then
            return
        end
    end

    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, speed, -1, 0.0, 0.5)
end

local MELEE_GROUPS <const> = {
    [`GROUP_MELEE`] = true,
    [`GROUP_UNARMED`] = true,
    [`GROUP_LASSO`] = true,
}

local MELEE_WEAPONS <const> = {
    [`WEAPON_UNARMED`] = true,
    [`WEAPON_LASSO`] = true,
    [`WEAPON_LASSO_REINFORCED`] = true,
    [`WEAPON_MELEE_KNIFE`] = true,
    [`WEAPON_MELEE_KNIFE_BEAR`] = true,
    [`WEAPON_MELEE_KNIFE_CIVIL_WAR`] = true,
    [`WEAPON_MELEE_KNIFE_JAWBONE`] = true,
    [`WEAPON_MELEE_KNIFE_JOHN`] = true,
    [`WEAPON_MELEE_KNIFE_MINER`] = true,
    [`WEAPON_MELEE_KNIFE_VAMPIRE`] = true,
    [`WEAPON_MELEE_KNIFE_TRADER`] = true,
    [`WEAPON_MELEE_MACHETE`] = true,
    [`WEAPON_MELEE_MACHETE_COLLECTOR`] = true,
    [`WEAPON_MELEE_CLEAVER`] = true,
    [`WEAPON_MELEE_HATCHET`] = true,
    [`WEAPON_MELEE_HATCHET_HUNTER`] = true,
    [`WEAPON_MELEE_HATCHET_DOUBLE_BIT`] = true,
    [`WEAPON_MELEE_HATCHET_HEWING`] = true,
    [`WEAPON_MELEE_HATCHET_VIKING`] = true,
    [`WEAPON_MELEE_HATCHET_HUNTER_RUSTED`] = true,
    [`WEAPON_MELEE_HATCHET_DOUBLE_BIT_RUSTED`] = true,
    [`WEAPON_MELEE_ANCIENT_HATCHET`] = true,
    [`WEAPON_MELEE_HAMMER`] = true,
    [`WEAPON_MELEE_TORCH`] = true,
    [`WEAPON_MELEE_LANTERN`] = true,
    [`WEAPON_MELEE_DAVY_LANTERN`] = true,
    [`WEAPON_MELEE_BROKEN_SWORD`] = true,
}

local function isMeleeWeapon(weapon)
    if not weapon or weapon == 0 or MELEE_WEAPONS[weapon] then
        return true
    end

    local group
    if GetWeapontypeGroup then
        local ok, value = pcall(GetWeapontypeGroup, weapon)
        if ok then
            group = value
        end
    end
    if not group then
        local ok, value = pcall(Citizen.InvokeNative, 0xEDCA14CA5199FF25, weapon)
        if ok then
            group = value
        end
    end

    return group and MELEE_GROUPS[group] == true
end

local function sendZombiesToNoise(coords, hearDistance)
    local noise = Config.Zombie.noise
    if not noise or not noise.enabled then
        return
    end

    local range = hearDistance or noise.hearDistance
    local now = GetGameTimer()
    local affected = 0

    for _, list in pairs(active) do
        for i = 1, #list do
            local entry = list[i]
            local ped = entry.ped

            if not entry.aggro
                and DoesEntityExist(ped)
                and not IsPedDeadOrDying(ped, true)
                and #(GetEntityCoords(ped) - coords) <= range then
                entry.investigate = {
                    coords = vector3(coords.x, coords.y, coords.z),
                    expiresAt = now + noise.investigateTime,
                    moveAt = now + (noise.turnTime or 700),
                    phase = "turning",
                }
                entry.behaviorMode = "investigate"
                entry.lastTaskAt = now
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedFleeAttributes(ped, 0, false)
                TaskTurnPedToFaceCoord(
                    ped,
                    coords.x, coords.y, coords.z,
                    noise.turnTime or 700
                )
                affected = affected + 1
            end
        end
    end

    dbg("выстрел услышали зомби:", affected)
end

local function damagedByPlayer(ped, playerPed)
    if not HasEntityBeenDamagedByEntity then
        return false
    end

    local ok, damaged = pcall(HasEntityBeenDamagedByEntity, ped, playerPed, true, true)
    return ok and not not damaged
end

local function isPlayerCrouched(playerPed)
    local ok, crouched = pcall(function()
        return Citizen.InvokeNative(0xD5FE956C70FF370B, playerPed)
    end)
    return ok and crouched and crouched ~= false and crouched ~= 0
end

local function detectionRangeFor(playerPed)
    local stealth = Config.Zombie.stealth or {}
    if stealth.enabled == false then
        return Config.Zombie.detectionDistance or 15.0
    end

    if isPlayerCrouched(playerPed) then
        return stealth.crouchDistance or 2.4
    end

    local speed = GetEntitySpeed(playerPed)
    if speed <= (stealth.stillSpeed or 0.35) then
        return stealth.stillDistance or 3.8
    end
    if speed <= (stealth.walkSpeed or 2.3) then
        return stealth.walkDistance or 8.0
    end

    return stealth.runDistance or Config.Zombie.detectionDistance or 15.0
end

local function canDetectPlayer(ped, playerPed, distance)
    local range = detectionRangeFor(playerPed)
    if distance > range then
        return false
    end

    local stealth = Config.Zombie.stealth or {}
    if stealth.requireLos == false then
        return true
    end

    local ok, los = pcall(HasEntityClearLosToEntity, ped, playerPed, 17)
    if ok and los == false then
        return distance <= (stealth.touchDistance or 1.4)
    end

    return true
end

local function getZoneState(zoneId)
    local state = zoneState[zoneId]
    if not state then
        state = {
            enteredAt = GetGameTimer(),
            lastRestockAt = GetGameTimer(),
            initialDone = false,
            inside = false,
            lingerEndsAt = 0,
        }
        zoneState[zoneId] = state
    end
    return state
end

local function stopArmsRun(entry)
    local arms = Config.Zombie.armsRun
    if not arms or not entry.armsRunner or not DoesEntityExist(entry.ped) then
        return
    end

    if entry.armsPoseApplied then
        applyLocomotion(entry.ped, entry.walkStyle or "moderate_drunk")
        entry.armsPoseApplied = false
    end
end

local function ensureArmsRun(entry)
    local arms = Config.Zombie.armsRun

    if not arms or not arms.enabled or not entry.armsRunner or entry.armsPoseApplied then
        return
    end

    applyLocomotion(entry.ped, arms.style or "moderate_drunk", arms.base or "primate")
    entry.armsPoseApplied = true
end

local function applyEntryLocomotion(entry, style)
    if entry.armsRunner then
        entry.armsPoseApplied = false
        ensureArmsRun(entry)
    else
        applyLocomotion(entry.ped, style)
    end
end

local function limitArmsSpeed(entry)
    local arms = Config.Zombie.armsRun
    if not arms or not entry.armsRunner then
        return
    end

    SetPedMaxMoveBlendRatio(entry.ped, arms.maxBlend or 0.65)
    if SetPedMoveRateOverride then
        SetPedMoveRateOverride(entry.ped, arms.speed or 0.75)
    end
end

local function makeZombie(ped)
    local health = Config.Zombie.health
    SetPedRelationshipGroupHash(ped, ZOMBIE_GROUP)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedMaxHealth(ped, health)
    SetEntityHealth(ped, health, 0)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 5, true)   -- CA_ALWAYS_FIGHT
    SetPedCombatAttributes(ped, 46, true)  -- драться с вооружённым игроком без оружия
    SetPedCombatAttributes(ped, 50, true)  -- CA_CAN_CHARGE: идти в лоб, а не фланкировать
    SetPedCombatAttributes(ped, 58, true)  -- CA_DISABLE_FLEE_FROM_COMBAT
    SetPedCombatAttributes(ped, 0, false)  -- CA_USE_COVER выключен, иначе кружат вокруг
    SetPedCombatAttributes(ped, 1, false)  -- без транспорта
    SetPedCombatAttributes(ped, 2, false)
    SetPedCombatAttributes(ped, 4, false)  -- без strafe-решений: не пляшут на месте
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 0)
    SetPedCombatMovement(ped, 2)           -- 2 = наступать. 3 = обход и кружение
    SetPedAccuracy(ped, Config.Zombie.accuracy)
    -- Глушим часть ИИ, где у гандончиков страх от выстрела, шоб они не стояли и не фоткали по пару секунд, а сразу шли на выстрел
    SetPedSeeingRange(ped, 0.0)
    SetPedHearingRange(ped, 0.0)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    if SetPedCanEvasiveDive then
        SetPedCanEvasiveDive(ped, false)
    end
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedCanBeTargetted(ped, true)

    local weapon = joaat(Config.Zombie.weapon or "WEAPON_UNARMED")
    GiveWeaponToPed(ped, weapon, 1, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    SetCurrentPedWeapon(ped, weapon, true, 0, false, false)
end

local function addBlip(ped)
    if not Config.Debug then
        return nil
    end
    return BlipAddForEntity(Config.Zombie.blipSprite or 953018525, ped)
end

local function deletePed(entry)
    if entry.blip and DoesBlipExist(entry.blip) then
        RemoveBlip(entry.blip)
    end
    if entry.ped and DoesEntityExist(entry.ped) then
        SetEntityAsMissionEntity(entry.ped, false, true)
        DeletePed(entry.ped)
        if DoesEntityExist(entry.ped) then
            DeleteEntity(entry.ped)
        end
    end
end

local function clearZone(zoneId)
    local list = active[zoneId]
    if not list then
        return
    end
    for i = 1, #list do
        deletePed(list[i])
    end
    active[zoneId] = nil
    -- Выход из зоны сбрасывает и таймер доспавна: отсчёт 15 минут пойдёт заново.
    zoneState[zoneId] = nil
    dbg("зона очищена", zoneId)
end

local function livingCount(zoneId)
    local list = active[zoneId]
    if not list then
        return 0
    end

    local kept, count = {}, 0
    local now = GetGameTimer()

    for i = 1, #list do
        local entry = list[i]

        if entry.ped and DoesEntityExist(entry.ped) and not IsPedDeadOrDying(entry.ped, true) then
            kept[#kept + 1] = entry
            count = count + 1
        elseif entry.ped and DoesEntityExist(entry.ped) then
            if not entry.diedAt then
                entry.diedAt = now
                if math.random() < ((Config.Sound and Config.Sound.deathChance) or 0.35) then
                    playZombieSound(entry, "death")
                end
                if entry.blip and DoesBlipExist(entry.blip) then
                    RemoveBlip(entry.blip)
                    entry.blip = nil
                end
            end

            local shouldDelete = entry.corpseMode == "timed"
                and now - entry.diedAt >= (entry.corpseLifetime or 60000)

            if shouldDelete then
                deletePed(entry)
            else
                kept[#kept + 1] = entry
            end
        end
    end
    active[zoneId] = kept
    return count
end

local function chooseSpeedProfile()
    local profiles = Config.Zombie.speedProfiles or {}
    if #profiles == 0 then
        return nil
    end

    local roll = math.random()
    local total = 0.0

    for i = 1, #profiles do
        total = total + (profiles[i].chance or 0.0)
        if roll <= total then
            return profiles[i]
        end
    end

    return profiles[#profiles]
end

local function spawnOne(zone, origin, opts)
    opts = opts or {}
    local models = zone.models or Config.Models
    local name = nextModel(zone.id, models)
    local hash = loadModel(name)
    if not hash then
        dbg("модель не загрузилась", name)
        return nil
    end

    local minDistance = opts.min or (zone.spread and zone.spread.min) or 5.0
    local maxDistance = opts.max or (zone.spread and zone.spread.max) or 20.0
    local x, y, z = spawnPoint(
        origin,
        minDistance,
        maxDistance,
        zone.maxSpawnHeightDiff,
        opts.avoid,
        opts.avoidDistance
    )
    if not x and opts.avoid then
        x, y, z = spawnPoint(origin, minDistance, maxDistance, zone.maxSpawnHeightDiff)
    end
    if not x then
        SetModelAsNoLongerNeeded(hash)
        dbg("не найдена безопасная точка spawn в зоне", zone.id)
        return nil
    end

    local ped = CreatePed(hash, x, y, z, math.random(0, 359) + 0.0, true, false, false, false)
    local timeout = GetGameTimer() + 3000
    while not DoesEntityExist(ped) do
        if GetGameTimer() > timeout then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
        Wait(0)
    end

    RequestCollisionAtCoord(x, y, z)
    local collisionTimeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionTimeout do
        Wait(0)
    end

    if not HasCollisionLoadedAroundEntity(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
        SetModelAsNoLongerNeeded(hash)
        dbg("коллизия не загрузилась для spawn в зоне", zone.id)
        return nil
    end

    local locomotion = Config.Zombie.locomotion
    local walkStyles = locomotion and locomotion.walkStyles or { "default" }
    local walkStyle = walkStyles[math.random(#walkStyles)]
    local speedProfile = chooseSpeedProfile()
    local corpseConfig = Config.Zombie.corpses or {}
    local timedCorpse = math.random() < (corpseConfig.timedChance or 0.60)
    local minLifetime = corpseConfig.minLifetime or 45
    local maxLifetime = math.max(minLifetime, corpseConfig.maxLifetime or 150)
    local outfit = zone.outfit
    if outfit == nil then
        outfit = nextOutfit(name)
    end

    applyOutfit(ped, outfit)
    makeZombie(ped)

    local appearance = Config.Appearance or {}
    local minScale = appearance.minScale or 1.0
    local maxScale = math.max(minScale, appearance.maxScale or 1.0)
    local scale = minScale + math.random() * (maxScale - minScale)
    Citizen.InvokeNative(0x25ACFC650B65C538, ped, scale)

    applyLocomotion(ped, walkStyle)
    limitSpeed(ped, "walk")
    TaskWanderStandard(ped, 10.0, 10)
    fadeInPed(ped)
    SetModelAsNoLongerNeeded(hash)

    return {
        ped = ped,
        model = name,
        blip = addBlip(ped),
        walkStyle = walkStyle,
        outfit = outfit,
        scale = scale,
        speedProfile = speedProfile,
        corpseMode = timedCorpse and "timed" or "zone",
        corpseLifetime = math.random(minLifetime, maxLifetime) * 1000,
        movementMode = "walk",
        behaviorMode = "idle",
        aggro = false,
        armsRunner = Config.Zombie.armsRun
            and Config.Zombie.armsRun.enabled
            and math.random() < (Config.Zombie.armsRun.chance or 0.35),
        armsPoseApplied = false,
        lastTaskAt = GetGameTimer(),
        nextIdleStyleAt = GetGameTimer() + math.random(6000, 14000),
        nextSoundAt = GetGameTimer() + math.random(400, nextSoundDelay()),
    }
end

local function fillZone(zone)
    local now = GetGameTimer()
    local state = getZoneState(zone.id)
    local auth = zoneAuth[zone.id]

    if state.awaitingAuth then
        if now - (state.authAt or now) < 2000 then
            livingCount(zone.id)
            return
        end
        state.awaitingAuth = false
        zoneAuth[zone.id] = zoneAuth[zone.id] or {
            canSpawn = true,
            freezeRestock = false,
            occupants = 1,
        }
    end

    if auth and auth.canSpawn == false then
        livingCount(zone.id)
        return
    end

    if (auth and auth.freezeRestock) or now < (state.lingerEndsAt or 0) then
        livingCount(zone.id)
        return
    end

    active[zone.id] = active[zone.id] or {}

    local alive = livingCount(zone.id)
    local need = zone.count - alive

    if need <= 0 then
        if not state.initialDone then
            state.initialDone = true
            dbg("зона заполнена:", zone.id)
        end
        state.lastRestockAt = now
        return
    end

    -- Первичное заполнение при входе идёт сразу.
    if not state.initialDone then
        if now - state.enteredAt > (Config.Zombie.initialFillTimeout or 60000) then
            state.initialDone = true
            state.lastRestockAt = now
            dbg("первичное заполнение завершено по таймауту:", zone.id)
        end
    else
        -- Дальше убитые не возвращаются, пока игрок не пробудет в зоне restockDelay.
        local delay = Config.Zombie.restockDelay or 900000
        if now - state.lastRestockAt < delay then
            return
        end
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local initial = not state.initialDone
    local origin = zone.coords
    local spreadMin = (zone.spread and zone.spread.min) or 5.0
    local spreadMax = (zone.spread and zone.spread.max) or math.max(10.0, (zone.radius or 20.0) - 5.0)

    if initial then
        local core = math.max(10.0, (zone.radius or 40.0) * (Config.Zombie.initialCoreRatio or 0.36))
        spreadMin = 0.0
        spreadMax = math.min(spreadMax, core)
        origin = zone.coords
    elseif zone.spawnAcrossZone == false then
        origin = playerCoords
    end

    local batch = math.min(need, Config.SpawnPerTick or need)
    local avoidDistance = Config.Zombie.minSpawnDistance or 22.0

    for _ = 1, batch do
        local entry = spawnOne(zone, origin, {
            min = spreadMin,
            max = spreadMax,
            avoid = playerCoords,
            avoidDistance = avoidDistance,
        })
        if entry then
            active[zone.id][#active[zone.id] + 1] = entry
        end
    end

    dbg("в зоне", zone.id, "зомби:", livingCount(zone.id))
end

local function playerInZone(coords, zone)
    return #(coords - zone.coords) <= zone.radius
end

local function playerNearZone(coords, zone)
    local padding = Config.Zombie.approachPadding or 0.0
    return #(coords - zone.coords) <= ((zone.radius or 0.0) + padding)
end

RegisterNetEvent("hh_zombies:zoneAuth", function(zoneId, auth)
    zoneAuth[zoneId] = auth or {}
    local state = getZoneState(zoneId)
    state.awaitingAuth = false

    local lingerLeft = tonumber(auth and auth.lingerLeft) or 0
    if lingerLeft > 0 then
        state.lingerEndsAt = GetGameTimer() + (lingerLeft * 1000)
    elseif state.inside then
        state.lingerEndsAt = 0
    end
end)

RegisterNetEvent("hh_zombies:despawnZone", function(zoneId)
    local state = zoneState[zoneId]
    if state and state.inside then
        return
    end
    if active[zoneId] then
        clearZone(zoneId)
    end
end)

CreateThread(function()
    discoverSoundFiles()
    setupRelationships()

    for i = 1, #Config.Zones do
        if Config.Zones[i].enabled ~= false then
            Zones[#Zones + 1] = Config.Zones[i]
        end
    end
    TriggerServerEvent("hh_zombies:requestZones")
    TriggerServerEvent("hh_zombies:requestAdmin")

    while true do
        Wait(Config.Tick)

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
            goto continue
        end

        local coords = GetEntityCoords(ped)
        local now = GetGameTimer()

        for i = 1, #Zones do
            local zone = Zones[i]
            if zone.enabled then
                local state = getZoneState(zone.id)
                local inside = playerInZone(coords, zone)
                local near = inside or playerNearZone(coords, zone)

                if near then
                    if not state.inside then
                        state.inside = true
                        state.awaitingAuth = true
                        state.authAt = now
                        state.lingerEndsAt = 0
                        TriggerServerEvent("hh_zombies:enterZone", zone.id)
                    end
                    fillZone(zone)
                else
                    if state.inside then
                        state.inside = false
                        local linger = Config.Zombie.linger or {}
                        local minTime = (linger.min or 300) * 1000
                        local maxTime = math.max(minTime, (linger.max or 600) * 1000)
                        state.lingerEndsAt = now + math.random(minTime, maxTime)
                        TriggerServerEvent("hh_zombies:leaveZone", zone.id)
                    end

                    if active[zone.id] then
                        livingCount(zone.id)
                        local auth = zoneAuth[zone.id]
                        local lingerOver = now >= (state.lingerEndsAt or 0)
                        local empty = not auth or (auth.occupants or 0) == 0
                        if lingerOver and empty then
                            clearZone(zone.id)
                        end
                    end
                end
            elseif active[zone.id] then
                clearZone(zone.id)
            end
        end

        local stale = {}
        for zoneId in pairs(active) do
            local stillExists = false
            for i = 1, #Zones do
                if Zones[i].id == zoneId and Zones[i].enabled ~= false then
                    stillExists = true
                    break
                end
            end
            if not stillExists then
                stale[#stale + 1] = zoneId
            end
        end
        for i = 1, #stale do
            clearZone(stale[i])
        end

        ::continue::
    end
end)

-- Защита от перегруза кастом звуков зомбей
CreateThread(function()
    while true do
        Wait(200)

        local settings = Config.Sound
        if not settings or not settings.enabled or #soundFiles.alive == 0 then
            goto continue
        end

        local now = GetGameTimer()
        local playerCoords = GetEntityCoords(PlayerPedId())
        local ready = {}

        for _, list in pairs(active) do
            for i = 1, #list do
                local entry = list[i]
                local ped = entry.ped

                if ped
                    and DoesEntityExist(ped)
                    and not IsPedDeadOrDying(ped, true)
                    and now >= (entry.nextSoundAt or 0) then
                    ready[#ready + 1] = {
                        entry = entry,
                        dist = #(GetEntityCoords(ped) - playerCoords),
                    }
                end
            end
        end

        table.sort(ready, function(a, b)
            return a.dist < b.dist
        end)

        local started = false
        for i = 1, #ready do
            local entry = ready[i].entry
            local stillPlaying = xsoundStillPlaying(entry.soundId) or (entry.soundId and xsounds[entry.soundId])

            if stillPlaying then
                entry.nextSoundAt = now + 400
            elseif started then
                entry.nextSoundAt = now + 800 + (i * 350)
            else
                local ok, reason = playZombieSound(entry, "alive")
                if ok then
                    started = true
                    entry.nextSoundAt = now + nextSoundDelay()
                elseif reason == "busy" then
                    entry.nextSoundAt = now + math.random(700, 1200)
                else
                    entry.nextSoundAt = now + math.random(800, 1400)
                end
            end
        end

        ::continue::
    end
end)

-- Любой выстрел сетевого игрока создаёт точку шума. Неагрессивные зомби
-- получают собственную задачу идти именно к этим координатам.
CreateThread(function()
    while true do
        
        Wait(0)

        local now = GetGameTimer()
        if now - lastGunshotAt < 400 then
            goto continue
        end

        local players = GetActivePlayers()
        for i = 1, #players do
            local shooter = GetPlayerPed(players[i])
            if DoesEntityExist(shooter) then
                local shooting = IsPedShooting(shooter)
                local meleeSwing = false
                local _, weapon = GetCurrentPedWeapon(shooter, true, 0, true)

                -- Запасной способ для локального игрока: некоторые сборки RedM
                -- пропускают IsPedShooting на одиночных выстрелах из револьвера.
                -- Нож и топор сюда больше не попадают — у них свой короткий радиус.
                if shooter == PlayerPedId() and not shooting then
                    local attackPressed = IsControlPressed(0, `INPUT_ATTACK`)
                        or IsDisabledControlPressed(0, `INPUT_ATTACK`)
                    if attackPressed and weapon and weapon ~= 0 then
                        if isMeleeWeapon(weapon) then
                            meleeSwing = weapon ~= `WEAPON_UNARMED`
                        else
                            shooting = true
                        end
                    end
                elseif shooting and isMeleeWeapon(weapon) then
                    shooting = false
                    meleeSwing = weapon ~= `WEAPON_UNARMED`
                end

                if shooting then
                    lastGunshotAt = now
                    sendZombiesToNoise(GetEntityCoords(shooter), Config.Zombie.noise.hearDistance)
                    break
                elseif meleeSwing then
                    lastGunshotAt = now
                    local meleeRange = (Config.Zombie.noise and Config.Zombie.noise.meleeHearDistance) or 8.0
                    if meleeRange > 0 then
                        sendZombiesToNoise(GetEntityCoords(shooter), meleeRange)
                    end
                    break
                end
            end
        end

        ::continue::
    end
end)

-- Вторая фаза реакции на шум: даём закончиться плавному развороту и только
-- затем назначаем движение. Так locomotion не обрывается в кадр выстрела.
CreateThread(function()
    while true do
        Wait(100)

        local now = GetGameTimer()
        local noise = Config.Zombie.noise

        if noise and noise.enabled then
            for _, list in pairs(active) do
                for i = 1, #list do
                    local entry = list[i]
                    local ped = entry.ped
                    local investigate = entry.investigate

                    if investigate
                        and investigate.phase == "turning"
                        and now >= investigate.moveAt
                        and not entry.aggro
                        and DoesEntityExist(ped)
                        and not IsPedDeadOrDying(ped, true) then
                        investigate.phase = "moving"
                        entry.lastTaskAt = now
                        goToPoint(ped, investigate.coords, noise.speed, noise.stopDistance)
                        applyEntryLocomotion(entry, noise.style or entry.walkStyle)
                        if entry.armsRunner then
                            ensureArmsRun(entry)
                            limitArmsSpeed(entry)
                        else
                            SetPedMaxMoveBlendRatio(ped, noise.maxBlend or 0.90)
                        end
                    end
                end
            end
        end
    end
end)

local function calmZombie(entry)
    local ped = entry.ped
    if not ped or not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
        return
    end

    local now = GetGameTimer()
    local locomotion = Config.Zombie.locomotion
    local styles = locomotion and locomotion.walkStyles or { "default" }

    entry.aggro = false
    entry.investigate = nil
    entry.lostTargetAt = nil
    entry.behaviorMode = "idle"
    entry.lastTaskAt = now
    entry.walkStyle = styles[math.random(#styles)]
    entry.nextIdleStyleAt = now + math.random(6000, 14000)

    SetPedRelationshipGroupHash(ped, ZOMBIE_GROUP)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedSeeingRange(ped, 0.0)
    SetPedHearingRange(ped, 0.0)
    stopArmsRun(entry)
    ClearPedTasksImmediately(ped, true, true)
    if ClearEntityLastDamageEntity then
        ClearEntityLastDamageEntity(ped)
    end
    applyLocomotion(ped, entry.walkStyle)
    limitSpeed(ped, "walk")
    TaskWanderStandard(ped, 10.0, 10)
end

-- Всё преследование использует только very_drunk. Случайные анимации можно
-- добавлять отдельно, но они не имеют права заменять locomotion погони.
CreateThread(function()
    while true do
        Wait(Config.AITick or 500)

        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then
            goto continue
        end

        local playerCoords = GetEntityCoords(playerPed)

        for _, list in pairs(active) do
            for i = 1, #list do
                local entry = list[i]
                local ped = entry.ped
                if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                    local distance = #(GetEntityCoords(ped) - playerCoords)
                    local locomotion = Config.Zombie.locomotion
                    local now = GetGameTimer()

                    if entry.armsRunner and entry.behaviorMode ~= "attack" then
                        ensureArmsRun(entry)
                        limitArmsSpeed(entry)
                    end

                    if not entry.aggro then
                        if not ignoreLocalPlayerAggro
                            and (canDetectPlayer(ped, playerPed, distance) or damagedByPlayer(ped, playerPed)) then
                            entry.aggro = true
                            entry.investigate = nil
                            entry.behaviorMode = nil
                            entry.lastTaskAt = 0
                            SetPedRelationshipGroupHash(ped, AGGRO_GROUP)
                            SetPedCombatAbility(ped, 2)
                            SetPedCombatMovement(ped, 2)
                            SetPedCombatRange(ped, 0)
                            SetPedCombatAttributes(ped, 50, true)
                            SetPedCombatAttributes(ped, 58, true)
                            SetPedCombatAttributes(ped, 0, false)
                            -- Боевому ИИ нужно «видеть» цель, иначе он топчется
                            -- рядом вместо удара. В покое чувства снова обнуляем.
                            SetPedSeeingRange(ped, Config.Zombie.fightRange or 80.0)
                            SetPedHearingRange(ped, Config.Zombie.fightRange or 80.0)
                            if ClearEntityLastDamageEntity then
                                ClearEntityLastDamageEntity(ped)
                            end
                        elseif entry.investigate and now < entry.investigate.expiresAt then
                            local noise = Config.Zombie.noise
                            local noiseDistance = #(GetEntityCoords(ped) - entry.investigate.coords)

                            if noiseDistance <= noise.stopDistance then
                                entry.investigate = nil
                                entry.behaviorMode = "idle"
                                entry.lastTaskAt = now
                                TaskWanderStandard(ped, 4.0, 10)
                            elseif entry.investigate.phase == "moving"
                                and now - (entry.lastTaskAt or 0) >= noise.retaskTime then
                                entry.behaviorMode = "investigate"
                                entry.lastTaskAt = now
                                goToPoint(ped, entry.investigate.coords, noise.speed, noise.stopDistance)
                            end

                            if entry.investigate and entry.investigate.phase == "moving" then
                                applyEntryLocomotion(entry, noise.style or entry.walkStyle)
                                if entry.armsRunner then
                                    limitArmsSpeed(entry)
                                else
                                    SetPedMaxMoveBlendRatio(ped, noise.maxBlend or 0.90)
                                end
                            end
                        else
                            if entry.investigate then
                                entry.investigate = nil
                                entry.behaviorMode = "idle"
                                entry.lastTaskAt = 0
                            end

                            -- Пока игрок не замечен, каждый зомби живёт отдельно:
                            -- бродит и время от времени меняет одну из выбранных походок.
                            if now >= (entry.nextIdleStyleAt or 0) then
                                local styles = locomotion and locomotion.walkStyles or { "default" }
                                entry.walkStyle = styles[math.random(#styles)]
                                entry.nextIdleStyleAt = now + math.random(6000, 14000)
                                applyEntryLocomotion(entry, entry.walkStyle)
                            end

                            if now - (entry.lastTaskAt or 0) >= (Config.Zombie.idleRetask or 10000) then
                                entry.lastTaskAt = now
                                TaskWanderStandard(ped, 10.0, 10)
                                applyEntryLocomotion(entry, entry.walkStyle)
                            end

                            if entry.armsRunner then
                                limitArmsSpeed(entry)
                            else
                                limitSpeed(ped, "walk")
                            end
                        end
                    end

                    if entry.aggro then
                        local dropDistance = Config.Zombie.deaggroDistance or 42.0
                        if distance > dropDistance then
                            entry.lostTargetAt = entry.lostTargetAt or now
                            if now - entry.lostTargetAt >= (Config.Zombie.deaggroTime or 2500) then
                                calmZombie(entry)
                            end
                        else
                            entry.lostTargetAt = nil
                        end
                    end

                    if entry.aggro then
                        local attackDistance = locomotion and locomotion.attackDistance or 3.6
                        local leaveAttack = locomotion and locomotion.attackLeaveDistance or (attackDistance + 1.6)
                        local profile = entry.speedProfile
                        local behaviorMode
                        if entry.behaviorMode == "attack" then
                            behaviorMode = distance <= leaveAttack and "attack" or "chase"
                        else
                            behaviorMode = distance <= attackDistance and "attack" or "chase"
                        end

                        if behaviorMode == "attack" then
                            stopArmsRun(entry)
                            releaseSpeedLimit(ped)

                            -- Пока бегут, события заблокированы — иначе срывает GoTo.
                            -- Для удара блок надо снять, иначе TaskCombatPed только смотрит.
                            if entry.behaviorMode ~= "attack" then
                                entry.behaviorMode = "attack"
                                entry.lastTaskAt = now
                                SetBlockingOfNonTemporaryEvents(ped, false)
                                SetPedKeepTask(ped, false)
                                SetPedCombatMovement(ped, 2)
                                applyLocomotion(ped, "default", "default")
                                ClearPedTasks(ped, true, true)
                                TaskCombatPed(ped, playerPed, 0, 16)
                            elseif not IsPedInCombat(ped, playerPed)
                                and now - (entry.lastTaskAt or 0) > 1200 then
                                entry.lastTaskAt = now
                                TaskCombatPed(ped, playerPed, 0, 16)
                            end
                        elseif profile and profile.combatChase then
                            if entry.behaviorMode ~= "combat_chase"
                                or not IsPedInCombat(ped, playerPed) then
                                entry.behaviorMode = "combat_chase"
                                entry.lastTaskAt = now
                                TaskCombatPed(ped, playerPed, 0, 16)
                            end

                            applyLocomotion(ped, profile.style or "very_drunk", profile.base)
                            limitSpeed(ped, "run", entry)
                        else
                            local retaskMs = distance < 8.0 and 1800 or 6000
                            if entry.behaviorMode ~= "chase" or now - (entry.lastTaskAt or 0) > retaskMs then
                                if entry.behaviorMode == "attack" then
                                    SetBlockingOfNonTemporaryEvents(ped, true)
                                    SetPedKeepTask(ped, true)
                                end
                                entry.behaviorMode = "chase"
                                entry.lastTaskAt = now
                                chasePlayer(ped, playerPed, entry)
                            end

                            if entry.armsRunner then
                                applyEntryLocomotion(entry, entry.walkStyle)
                                limitArmsSpeed(entry)
                                ensureArmsRun(entry)
                            else
                                local style = profile and profile.style
                                    or (locomotion and locomotion.runStyle)
                                    or "very_drunk"
                                applyLocomotion(ped, style, profile and profile.base)
                                limitSpeed(ped, "run", entry)
                            end
                        end
                    end
                end
            end
        end

        ::continue::
    end
end)

local function resetAggroFromLocalPlayer()
    for _, list in pairs(active) do
        for i = 1, #list do
            calmZombie(list[i])
        end
    end
end

RegisterCommand("zpeace", function()
    if not requireAdmin() then
        return
    end

    ignoreLocalPlayerAggro = not ignoreLocalPlayerAggro

    if ignoreLocalPlayerAggro then
        resetAggroFromLocalPlayer()
        TriggerEvent("chat:addMessage", {
            args = { "hh_zombies", "Челы в чиле, но слышат" },
        })
        dbg("тестовый режим: личный агр отключён")
    else
        TriggerEvent("chat:addMessage", {
            args = { "hh_zombies", "Личный агр включён обратно." },
        })
        dbg("тестовый режим: личный агр включён")
    end
end, false)

RegisterCommand("zinfo", function()
    if not requireAdmin() then
        return
    end
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDistance = nil, 20.0

    for _, list in pairs(active) do
        for i = 1, #list do
            local entry = list[i]
            if entry.ped and DoesEntityExist(entry.ped) then
                local distance = #(GetEntityCoords(entry.ped) - playerCoords)
                if distance < nearestDistance then
                    nearest = entry
                    nearestDistance = distance
                end
            end
        end
    end

    if not nearest then
        TriggerEvent("chat:addMessage", {
            args = { "hh_zombies", "Рядом до 20 метров нет зомби." },
        })
        return
    end

    local text = ("%s · outfit %d · %.1f м"):format(
        nearest.model or "unknown",
        nearest.outfit or 0,
        nearestDistance
    )
    TriggerEvent("chat:addMessage", { args = { "hh_zombies", text } })
    print(("[hh_zombies] blacklist: [%q] = { [%d] = true }"):format(
        (nearest.model or "unknown"):lower(),
        nearest.outfit or 0
    ))
end, false)

RegisterCommand("zsound", function(_, args)
    if not requireAdmin() then
        return
    end
    local category = args[1] == "dead" and "death" or "alive"
    local files = soundFiles[category]

    if not files or #files == 0 then
        TriggerEvent("chat:addMessage", {
            args = { "hh_zombies", "Нет файлов категории " .. category },
        })
        return
    end

    local file = files[math.random(#files)]
    local backend

    if xsoundReady() then
        backend = "xsound"
        local playerEntry = { ped = PlayerPedId() }
        local volume = category == "death"
            and (Config.Sound.deathVolume or 0.11)
            or (Config.Sound.maxVolume or 0.11)
        local distance = category == "death"
            and (Config.Sound.deathDistance or 22.0)
            or (Config.Sound.aliveDistance or 12.0)
        playViaXSound(playerEntry, category, file, volume, distance)
    else
        backend = audioReady and "nui" or "nui (не готов)"
        SendNUIMessage({
            action = "playZombieSound",
            file = file,
            volume = 1.0,
            priority = true,
            maxSimultaneous = 20,
        })
    end

    local text = ("Тест: %s · движок: %s · xsound: %s"):format(
        file,
        backend,
        GetResourceState("xsound")
    )
    TriggerEvent("chat:addMessage", { args = { "hh_zombies", text } })
    print("[hh_zombies] " .. text)
    print("[hh_zombies] url = " .. soundUrl(file))
end, false)

-- Источник звука едет за зомби, пока тот жив и звук не закончился.
CreateThread(function()
    while true do
        Wait((Config.Sound and Config.Sound.positionTick) or 150)

        if next(xsounds) == nil then
            goto continue
        end

        local now = GetGameTimer()

        for soundId, data in pairs(xsounds) do
            local alive = data.ped and DoesEntityExist(data.ped)
            local playing = xsoundStillPlaying(soundId)

            if not alive or not playing then
                destroyXSound(soundId)
            elseif now >= data.expiresAt then
                -- Только если xsound завис и так и не сообщил о конце.
                destroyXSound(soundId)
            else
                pcall(function()
                    if exports.xsound:soundExists(soundId) then
                        exports.xsound:Position(soundId, GetEntityCoords(data.ped))
                    else
                        xsounds[soundId] = nil
                    end
                end)
            end
        end

        ::continue::
    end
end)

local MARKER_TYPE <const> = 0x94FDAE17

local function chatZone(text)
    TriggerEvent("chat:addMessage", { args = { "hh_zombies", text } })
end

local function clearZoneBlips()
    for _, blip in pairs(zoneBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    zoneBlips = {}
end

local function nameZoneBlip(blip, name)
    if CreateVarString then
        local ok = pcall(function()
            Citizen.InvokeNative(0x9CB1A162, blip, CreateVarString(10, "LITERAL_STRING", name))
        end)
        if ok then
            return
        end
    end
    if SetBlipName then
        pcall(SetBlipName, blip, name)
    end
end

local function addZoneBlip(zone)
    local style = zone.custom and `BLIP_STYLE_DEBUG_GREEN` or `BLIP_STYLE_DEBUG_YELLOW`
    local blip
    if BlipAddForRadius then
        local ok, handle = pcall(BlipAddForRadius, style, zone.coords.x, zone.coords.y, zone.coords.z, zone.radius + 0.0)
        if ok then
            blip = handle
        end
    end
    if not blip then
        local ok, handle = pcall(Citizen.InvokeNative, 0x45F13B7E0A15C880, style, zone.coords.x, zone.coords.y, zone.coords.z, zone.radius + 0.0)
        if ok then
            blip = handle
        end
    end
    if blip then
        nameZoneBlip(blip, zone.label or zone.id)
        zoneBlips[zone.id] = blip
    end
end

local function refreshZoneBlips()
    clearZoneBlips()
    for i = 1, #Zones do
        addZoneBlip(Zones[i])
    end
end

local function drawZoneMarker(coords, radius, r, g, b, a)
    local diameter = radius * 2.0
    DrawMarker(
        MARKER_TYPE,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        diameter, diameter, 4.0,
        r, g, b, a,
        false, false, 2, nil, nil, false, false
    )
    DrawMarker(
        MARKER_TYPE,
        coords.x, coords.y, -320.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        diameter, diameter, 400.0,
        r, g, b, math.floor(a * 0.55),
        false, false, 2, nil, nil, false, false
    )
end

local function deserializeZones(payload)
    local nextZones = {}
    for i = 1, #(payload or {}) do
        local data = payload[i]
        nextZones[#nextZones + 1] = {
            id = data.id,
            label = data.label,
            enabled = data.enabled ~= false,
            coords = vector3(data.x, data.y, data.z),
            radius = data.radius,
            count = data.count,
            spawnAcrossZone = data.spawnAcrossZone ~= false,
            spread = data.spread or { min = 5.0, max = math.max(10.0, data.radius - 5.0) },
            maxSpawnHeightDiff = data.maxSpawnHeightDiff or 6.0,
            models = (type(data.models) == "table" and #data.models > 0)
                and data.models
                or (data.modelsKey == "colter" and Config.ColterModels or Config.Models),
            modelsKey = data.modelsKey,
            custom = data.custom == true,
            builtin = data.builtin == true,
        }
    end
    Zones = nextZones
    refreshZoneBlips()
end

RegisterNetEvent("hh_zombies:syncZones", function(payload)
    deserializeZones(payload)
end)

RegisterNetEvent("hh_zombies:zoneRemoved", function(zoneId)
    if active[zoneId] then
        clearZone(zoneId)
    end
    zoneState[zoneId] = nil
    zoneAuth[zoneId] = nil
end)

RegisterNetEvent("hh_zombies:zoneEditorResult", function(_, message, zoneId)
    if zoneId then
        lastCreatedZoneId = zoneId
    end
    if message then
        chatZone(message)
    end
end)

RegisterNetEvent("hh_zombies:zoneList", function(lines)
    if not lines or #lines == 0 then
        chatZone("Зон нет.")
        return
    end
    chatZone("Зоны:")
    for i = 1, #lines do
        chatZone(lines[i])
    end
end)

RegisterCommand("zzone", function()
    if not requireAdmin() then
        return
    end
    local c = GetEntityCoords(PlayerPedId())
    local line = ("vector3(%.2f, %.2f, %.2f)"):format(c.x, c.y, c.z)
    print("[hh_zombies] точка:", line)
    chatZone(line)
end, false)

RegisterCommand("zonelist", function()
    if not requireAdmin() then
        return
    end
    TriggerServerEvent("hh_zombies:listZones")
end, false)

RegisterCommand("zonedel", function(_, args)
    if not requireAdmin() then
        return
    end
    local zoneId = args[1]
    if not zoneId then
        chatZone("Укажи id зоны. Список: /zonelist")
        return
    end
    TriggerServerEvent("hh_zombies:deleteZone", zoneId)
end, false)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    for soundId in pairs(xsounds) do
        destroyXSound(soundId)
    end
    for zoneId in pairs(active) do
        clearZone(zoneId)
    end
    clearZoneBlips()
end)
