-- =================================================================
-- HUNT: Логирование смертей и убийств игроков
-- =================================================================

local wasDead = false
local activeCharacterObserved = false
local deathReported = false
local observedPed = 0
local deathObservationId = 0

local DeathCauseInfo = {
    -- GetPedCauseOfDeath returns the weapon/damage cause, not the model hash.
    [3049642225] = { name = "Аллигатор", text = "Аллигатора", killerType = "mob" }, -- 0xB5C5D8F1
    [148160082] = { name = "Пума", text = "Пумы", killerType = "mob" }, -- 0x08D4BE52
    [4194021054] = { name = "Животное", text = "животного", killerType = "mob" }, -- 0xF9FBAEBE
    [3452007600] = { name = "Падение", text = "падения", killerType = "environment" }, -- 0xCDC174B0
}

local function NormalizeHash(value)
    local number = tonumber(value) or 0
    if number < 0 then
        number = number + 4294967296
    end
    return number
end

local function GetDeathCauseInfo(cause)
    return DeathCauseInfo[NormalizeHash(cause)]
end

local function IsCharacterActive()
    if LocalPlayer.state.isCreatingChar or LocalPlayer.state.isSelectingChar then
        return false
    end

    local ok, selected = pcall(function()
        return exports["thehunt_character"]:isCharacterSelected()
    end)

    if ok then
        return selected == true
    end

    return true
end

local function GetPlayerKillerData(ped, eventKillerPed, eventKillerServerId, eventCause, eventIsSuicide)
    local killerPed = eventKillerPed
    if not killerPed or killerPed == 0 or not DoesEntityExist(killerPed) then
        killerPed = GetPedSourceOfDeath(ped)
    end

    local killerId = tonumber(eventKillerServerId) or 0
    local killerType = "none"
    local killerModel = 0
    local killerModelName = ""
    local ownServerId = GetPlayerServerId(PlayerId()) or 0
    local cause = tonumber(eventCause) or tonumber(GetPedCauseOfDeath(ped)) or 0
    local causeInfo = GetDeathCauseInfo(cause)

    if eventIsSuicide then
        killerType = "suicide"
    end

    -- VORP передаёт server ID убийцы напрямую. Используем его как главный
    -- источник, потому что сетевой ped может быть уже пересоздан к моменту
    -- проверки смерти.
    if killerId > 0 then
        if killerId == ownServerId then
            killerId = 0
            killerType = "suicide"
        else
            killerType = "player"
            local killerPlayer = GetPlayerFromServerId(killerId)
            if killerPlayer and killerPlayer ~= -1 then
                local networkKillerPed = GetPlayerPed(killerPlayer)
                if networkKillerPed and networkKillerPed ~= 0 and DoesEntityExist(networkKillerPed) then
                    killerPed = networkKillerPed
                end
            end
        end
    end

    if killerType == "none" and killerPed and killerPed ~= 0 and DoesEntityExist(killerPed) then
        killerModel = GetEntityModel(killerPed) or 0

        if killerPed == ped then
            -- В некоторых случаях RedM указывает самого жертву источником
            -- урона при суициде. Это не убийство другого игрока.
            killerType = "suicide"
        elseif IsPedAPlayer(killerPed) then
            local playerIndex = NetworkGetPlayerIndexFromPed(killerPed)
            if playerIndex and playerIndex ~= -1 then
                killerId = GetPlayerServerId(playerIndex) or 0
            end

            if killerId > 0 then
                killerType = "player"
            else
                killerType = "unknown"
            end
        else
            killerType = "mob"
        end
    end

    -- When the game removes the attacker ped before our script can inspect it,
    -- the cause hash still identifies several animal attacks reliably.
    if killerType == "none" and causeInfo then
        killerType = causeInfo.killerType
        if causeInfo.killerType == "mob" then
            killerModelName = causeInfo.name
        end
    end

    if killerType == "mob" and killerPed and killerPed ~= 0 and DoesEntityExist(killerPed) then
        local knownModelNames = {
            [`a_c_alligator_01`] = "Аллигатор",
            [`a_c_alligator_02`] = "Аллигатор",
            [`a_c_alligator_03`] = "Аллигатор",
            [`a_c_bear_01`] = "Медведь",
            [`a_c_cougar_01`] = "Пума",
            [`a_c_wolf`] = "Волк",
            [`a_c_panther_01`] = "Пантера",
            [`a_c_coyote_01`] = "Койот",
            [`a_c_boar_01`] = "Кабан",
            [`a_c_snake_01`] = "Змея",
        }
        killerModelName = knownModelNames[killerModel] or killerModelName

        local ok, archetypeName = pcall(function()
            if type(GetEntityArchetypeName) ~= "function" then return "" end
            return GetEntityArchetypeName(killerPed) or ""
        end)

        if ok and type(archetypeName) == "string" and archetypeName ~= "" then
            local modelName = string.lower(archetypeName)
            local knownNames = {
                alligator = "Аллигатор",
                crocodile = "Крокодил",
                bear = "Медведь",
                cougar = "Пума",
                wolf = "Волк",
                panther = "Пантера",
                coyote = "Койот",
                boar = "Кабан",
                snake = "Змея",
                shark = "Акула",
            }

            for fragment, label in pairs(knownNames) do
                if string.find(modelName, fragment, 1, true) then
                    killerModelName = label
                    break
                end
            end

            if killerModelName == "" then
                killerModelName = archetypeName
            end
        end
    end

    return {
        killerId = tonumber(killerId) or 0,
        killerType = killerType,
        killerModel = tonumber(killerModel) or 0,
        killerModelName = killerModelName,
        cause = cause,
        causeName = causeInfo and causeInfo.name or "",
        isSuicide = killerType == "suicide",
    }
end

local function IsCharacterDead(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local ok, dead = pcall(function()
        return IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
    end)

    return ok and dead == true
end

local function ReportCharacterDeath(ped, eventKillerPed, fatalDamageEvent, eventKillerServerId, eventCause, eventIsSuicide)
    if deathReported or not activeCharacterObserved or not IsCharacterActive() then
        return false
    end

    -- Для фатального CEventNetworkEntityDamage доверяем флагу RedM: в этот
    -- момент IsEntityDead ещё может вернуть false или VORP уже начать revive.
    if not fatalDamageEvent and not IsCharacterDead(ped) then
        return false
    end

    deathReported = true
    TriggerServerEvent("thehunt_logs:playerDeath", GetPlayerKillerData(ped, eventKillerPed, eventKillerServerId, eventCause, eventIsSuicide))
    return true
end

-- Штатный VORP death handler уже надёжно знает момент смерти, ID убийцы и
-- причину. Это основной путь, а gameEventTriggered/polling ниже — резервы.
AddEventHandler("vorp_core:Client:OnPlayerDeath", function(killerServerId, deathCause)
    activeCharacterObserved = true
    local ped = PlayerPedId()
    local killerPed = GetPedSourceOfDeath(ped)

    Citizen.CreateThread(function()
        for _ = 1, 8 do
            if ReportCharacterDeath(ped, killerPed, true, killerServerId, deathCause) then
                return
            end
            Citizen.Wait(50)
        end
    end)
end)

-- Фатальный урон в RedM приходит через это событие раньше, чем ped всегда
-- успевает корректно отразить состояние IsEntityDead. Обрабатываем только
-- собственную жертву, чтобы один клиент не создавал чужие записи.
AddEventHandler("gameEventTriggered", function(eventName, args)
    if eventName ~= "CEventNetworkEntityDamage" or type(args) ~= "table" then
        return
    end

    local ped = PlayerPedId()
    local victim = args[1]
    -- RedM's CEventNetworkEntityDamage layout uses args[6] for the fatal
    -- flag and args[7] for the weapon/damage cause. Keep args[4]/args[5]
    -- as a fallback for older event layouts used by some builds/resources.
    local fatalFlag = args[6]
    local fatalFlagIsBoolean = fatalFlag == true or fatalFlag == false
    local fatalFlagIsNumber = tonumber(fatalFlag) == 0 or tonumber(fatalFlag) == 1
    if not fatalFlagIsBoolean and not fatalFlagIsNumber then
        fatalFlag = args[4]
    end
    local isFatal = tonumber(fatalFlag) == 1 or fatalFlag == true

    if victim and victim == ped and isFatal then
        local eventKillerPed = args[2]
        local eventCause = args[7]
        local eventIsSuicide = tonumber(args[32]) == 1 or args[32] == true
        -- В момент gameEventTriggered состояние педа ещё может быть живым.
        -- Делаем несколько коротких попыток, после чего polling ниже остаётся
        -- резервом для смертей без CEventNetworkEntityDamage.
        Citizen.CreateThread(function()
            Citizen.Wait(100)
            for _ = 1, 8 do
                if ReportCharacterDeath(ped, eventKillerPed, true, 0, eventCause, eventIsSuicide) then
                    return
                end
                Citizen.Wait(50)
            end
        end)
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(1500)

    while true do
        local ped = PlayerPedId()
        local pedExists = ped and ped ~= 0 and DoesEntityExist(ped)
        if ped ~= observedPed then
            observedPed = ped or 0
            deathReported = false
            wasDead = false
            activeCharacterObserved = false
            deathObservationId = deathObservationId + 1
        end

        local dead = pedExists and IsCharacterDead(ped) or false
        local characterActive = IsCharacterActive()

        if not characterActive then
            -- Не считаем труп/превью смертью во время выбора или создания персонажа.
            activeCharacterObserved = false
            wasDead = dead
        elseif not activeCharacterObserved then
            -- Первое наблюдение после спавна нужно пропустить: персонаж может
            -- загружаться уже мёртвым из базы данных.
            activeCharacterObserved = true
            wasDead = dead
        elseif dead and not wasDead then
            -- Polling is only a last resort. Delay it briefly so VORP's own
            -- death event (which contains killerServerId/deathCause) gets the
            -- first chance to send the detailed record.
            deathObservationId = deathObservationId + 1
            local observationId = deathObservationId
            local deathPed = ped
            local deathKillerPed = GetPedSourceOfDeath(deathPed)
            local deathCause = GetPedCauseOfDeath(deathPed)

            Citizen.CreateThread(function()
                Citizen.Wait(1500)
                if observationId ~= deathObservationId or observedPed ~= deathPed then
                    return
                end
                ReportCharacterDeath(deathPed, deathKillerPed, false, 0, deathCause)
            end)
        elseif not dead then
            -- После возрождения разрешаем следующую запись смерти.
            deathObservationId = deathObservationId + 1
            deathReported = false
        end

        wasDead = dead
        Citizen.Wait(250)
    end
end)
