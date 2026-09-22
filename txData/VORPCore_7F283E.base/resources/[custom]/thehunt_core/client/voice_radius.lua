-- =================================================================
-- Динамический 3D-обруч дальности войса
-- (3 режима: Шепот 1.8м, Обычный 6м, Крик 20м)
-- Кнопки: + увеличить, − уменьшить
-- Работает везде: пешком, на лошади, в повозке
-- Активируется ТОЛЬКО после выбора персонажа
-- =================================================================

local showVoiceCircle = false
local voiceCircleEndTime = 0
local activeRadius = 6.0
local currentVoiceMode = 2 -- 1=Шепот, 2=Обычный, 3=Крик
local isCharacterReady = false

-- Запасные значения используются только пока pma-voice ещё не отдал свои
-- voiceModes. После инициализации источником истины становится его state bag.
local VoiceRadiuses = {
    [1] = 1.8,  -- 1. Шепот (1.8м)
    [2] = 6.0,  -- 2. Обычный (6.0м)
    [3] = 20.0, -- 3. Крик (20.0м)
}

local VoiceLabels = {
    [1] = "Шепот",
    [2] = "Обычный",
    [3] = "Крик",
}

local function UsesNativeAudio()
    return GetConvar('voice_useNativeAudio', 'false') == 'true'
end

-- В pma-voice native audio исторически умножает расстояние на 3 при
-- построении списка целей. Для поддержания старых конфигураций учитываем это
-- только при чтении pma-значения; в RedM основной режим ниже — 3D audio.
local function GetEffectiveVoiceDistance(distance)
    distance = tonumber(distance)
    if not distance or distance <= 0 then return nil end
    return UsesNativeAudio() and (distance * 3.0) or distance
end

local function CachePmaVoiceModes(settings)
    if type(settings) ~= 'table' or type(settings.voiceModes) ~= 'table' then return end

    for index, voiceMode in ipairs(settings.voiceModes) do
        if type(voiceMode) == 'table' then
            local distance = tonumber(voiceMode[1])
            if distance and distance > 0 then
                VoiceRadiuses[index] = distance
            end
            if voiceMode[2] then
                VoiceLabels[index] = tostring(voiceMode[2])
            end
        end
    end
end

local function GetMaximumVoiceRadius()
    local maximum = 0.0

    for _, distance in pairs(VoiceRadiuses) do
        local effectiveDistance = GetEffectiveVoiceDistance(distance)
        if effectiveDistance and effectiveDistance > maximum then
            maximum = effectiveDistance
        end
    end

    -- Резерв только на самый короткий момент до получения voiceModes pma-voice.
    return maximum > 0.0 and maximum or 20.0
end

local function GetModeRadius(modeIndex, stateDistance)
    return GetEffectiveVoiceDistance(stateDistance)
        or GetEffectiveVoiceDistance(VoiceRadiuses[modeIndex])
        or 6.0
end

local function ApplyVoiceState(modeIndex, stateDistance, stateLabel, showCircle)
    modeIndex = tonumber(modeIndex) or currentVoiceMode or 2
    if modeIndex < 1 then modeIndex = 1 end

    currentVoiceMode = modeIndex
    if stateLabel then
        VoiceLabels[modeIndex] = tostring(stateLabel)
    end
    activeRadius = GetModeRadius(modeIndex, stateDistance)

    if showCircle then
        showVoiceCircle = true
        voiceCircleEndTime = GetGameTimer() + 2500
    end
end

local function SyncVoiceState(showCircle)
    local proximityState
    pcall(function()
        proximityState = LocalPlayer.state.proximity
    end)

    if type(proximityState) == 'table' then
        ApplyVoiceState(
            proximityState.index,
            proximityState.distance,
            proximityState.mode,
            showCircle
        )
    elseif type(proximityState) == 'number' then
        ApplyVoiceState(currentVoiceMode, proximityState, nil, showCircle)
    else
        ApplyVoiceState(currentVoiceMode, nil, nil, showCircle)
    end
end

local function RefreshPmaVoiceSettings()
    -- settingsCallback — штатный публичный API pma-voice, поэтому не трогаем
    -- его внутренние таблицы напрямую.
    pcall(function()
        TriggerEvent('pma-voice:settingsCallback', function(settings)
            CachePmaVoiceModes(settings)
        end)
    end)
    SyncVoiceState(false)
end

-- Высота голосового круга берётся с костей голеней самого педа, а не с земли.
-- Так круг не «прыгает» по склонам и остаётся на персонаже в воде/на объектах.
local function GetVoiceCircleHeight(ped, fallbackCoords)
    if GetEntityBoneIndexByName and GetWorldPositionOfEntityBone then
        local totalZ = 0.0
        local bonesFound = 0

        for _, boneName in ipairs({ 'SKEL_L_Calf', 'SKEL_R_Calf' }) do
            local boneIndex = GetEntityBoneIndexByName(ped, boneName)
            if boneIndex and boneIndex ~= -1 then
                local boneCoords = GetWorldPositionOfEntityBone(ped, boneIndex)
                if boneCoords and boneCoords.z then
                    totalZ = totalZ + boneCoords.z
                    bonesFound = bonesFound + 1
                end
            end
        end

        if bonesFound > 0 then
            -- Центр голени находится чуть ниже колена; небольшой подъём даёт
            -- визуальный уровень коленей и не зависит от поверхности.
            return (totalZ / bonesFound) + 0.05
        end
    end

    -- Резерв для педов/скелетов без именованных костей.
    return fallbackCoords.z + 0.45
end

-- Ожидание выбора персонажа VORP
local function CheckCharacterLoaded()
    if DoesEntityExist(PlayerPedId()) and PlayerPedId() ~= 0 then
        isCharacterReady = true
    end
end

RegisterNetEvent("vorp:SelectedCharacter", function()
    isCharacterReady = true
end)

AddEventHandler("onClientResourceStart", function(res)
    if GetCurrentResourceName() == res then
        Wait(500)
        CheckCharacterLoaded()
        RefreshPmaVoiceSettings()
    elseif res == 'pma-voice' then
        Wait(0)
        RefreshPmaVoiceSettings()
    end
end)

Citizen.CreateThread(function()
    Wait(1000)
    CheckCharacterLoaded()
    RefreshPmaVoiceSettings()
end)

-- Активация показа динамического обруча
local function TriggerVoiceCircle(modeIndex, stateDistance, stateLabel)
    ApplyVoiceState(modeIndex, stateDistance, stateLabel, true)
end

-- Слушаем событие переключения pma-voice (для синхронизации и показа круга)
RegisterNetEvent("pma-voice:setTalkingMode", function(mode)
    local modeIndex = tonumber(mode) or 2
    -- pma-voice updates the state bag before emitting this event. Reading it
    -- here keeps the ring tied to the exact active distance (including custom
    -- ranges and future mode changes).
    local proximityState
    pcall(function() proximityState = LocalPlayer.state.proximity end)
    if type(proximityState) == 'table' then
        TriggerVoiceCircle(modeIndex, proximityState.distance, proximityState.mode)
    else
        TriggerVoiceCircle(modeIndex)
    end
end)

-- Слушаем LocalPlayer state proximity
AddStateBagChangeHandler('proximity', nil, function(bagName, key, value, _unused, _replicated)
    local plyId = PlayerId()
    if bagName == ('player:%s'):format(GetPlayerServerId(plyId)) then
        if type(value) == 'table' and value.index then
            TriggerVoiceCircle(value.index, value.distance, value.mode)
        end
    end
end)

-- pma-voice по умолчанию строит список слышимых игроков от режима самого
-- слушателя. Это делает крик слушателя слышимым слишком далеко, а шёпот —
-- слишком тихим/коротким. Официальный overrideProximityCheck позволяет
-- выбирать цель по replicated proximity говорящего, не вмешиваясь в Mumble
-- natives и радиоканалы.
-- Поток отрисовки динамического 3D-обруча (привязан к персонажу, движется вместе с ним)
Citizen.CreateThread(function()
    -- Один объёмный 3D-обруч вместо нескольких параллельных линий.
    local hoopTubeRadius = 0.20
    local hoopSegments = 64

    while true do
        if showVoiceCircle and isCharacterReady then
            Citizen.Wait(0)
            local curTime = GetGameTimer()

            if curTime < voiceCircleEndTime then
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local hoopZ = GetVoiceCircleHeight(ped, coords)

                -- Плавное затухание в конце
                local remaining = voiceCircleEndTime - curTime
                local alpha = 190
                if remaining < 500 then
                    alpha = math.floor((remaining / 500) * 190)
                end

                -- Костяной белый
                local r, g, b = 240, 235, 225

                -- Радиус обруча совпадает с реальной дальностью голоса.
                if GetResourceState('thehunt_shapes') == 'started' then
                    exports.thehunt_shapes:DrawHoop(
                        coords.x, coords.y, hoopZ,
                        activeRadius, hoopTubeRadius,
                        r, g, b, alpha, hoopSegments
                    )
                end
            else
                showVoiceCircle = false
            end
        else
            Citizen.Wait(120)
        end
    end
end)

-- Экспорт для других скриптов
exports('getCurrentVoiceMode', function() return currentVoiceMode end)
exports('getVoiceModeLabel', function() return VoiceLabels[currentVoiceMode] or "Обычный" end)
