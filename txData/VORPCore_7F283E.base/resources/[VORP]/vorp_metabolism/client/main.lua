PlayerStatus = {}
local loaded = false
local metabolismActive = false

local function SaveStatusNow()
    if loaded and type(PlayerStatus) == "table" and next(PlayerStatus) then
        TriggerServerEvent("vorpmetabolism:SaveLastStatus", json.encode(PlayerStatus))
    end
end

-- thehunt_character requests this immediately with each world snapshot.
RegisterNetEvent("vorpmetabolism:saveNow", SaveStatusNow)

local waistTypes = {
    -2045421226, -- Skinny
    -1745814259,
    -325933489,
    -1065791927,
    -844699484,
    -1273449080,
    927185840,
    149872391,
    399015098,
    -644349862,
    1745919061, -- Normal
    1004225511,
    1278600348,
    502499352,
    -2093198664,
    -1837436619,
    1736416063,
    2040610690,
    -1173634986,
    -867801909,
    1960266524, -- Fat
}

-- [ EVENTS ] --
RegisterNetEvent('vorpmetabolism:StartFunctions', function(status)
    if type(status) ~= 'string' or #status < 2 then
        return
    end

    local decoded = json.decode(status)
    if type(decoded) ~= 'table' then return end

    PlayerStatus = decoded
    PlayerStatus.Hunger = math.max(0, math.min(1000,
        tonumber(PlayerStatus.Hunger) or Config["FirstHungerStatus"] or 1000))
    PlayerStatus.Thirst = math.max(0, math.min(1000,
        tonumber(PlayerStatus.Thirst) or Config["FirstThirstStatus"] or 1000))
    PlayerStatus.Metabolism = math.max(-10000, math.min(10000,
        tonumber(PlayerStatus.Metabolism) or Config["FirstMetabolismStatus"] or 0))

    if (PlayerStatus["Thirst"] and PlayerStatus["Hunger"]) then
        Wait(1000)

        NUIEvents.UpdateHUD()

        if loaded then return end -- keep exactly one set of timers across character selections
        loaded = true
        StartMetabolismThread()
        StartMetabolismUpdatersThread()
        StartMetabolismSaveDBThread()
        StartRadarControlHudThread()
        StartMetabolismSetThread()
    end
    loaded = true
end)

RegisterNetEvent('vorp:PlayerForceRespawn', function(status)
    PlayerStatus["Thirst"] = Config["OnRespawnThirstStatus"];
    PlayerStatus["Hunger"] = Config["OnRespawnHungerStatus"];
    NUIEvents.UpdateHUD();
end)

RegisterNetEvent('vorp:SelectedCharacter', function(charId)
    TriggerServerEvent("vorpmetabolism:GetStatus")
end)

-- on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    SaveStatusNow()
    ClearPedTasks(PlayerPedId(), true, true)
    AnimpostfxStopAll()

    for _, prop in ipairs(PROPS) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
end)

--onclient resource start
AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    -- Resource restarts do not replay vorp:SelectedCharacter.  Re-request the
    -- active character's status so the normal StartFunctions path recreates
    -- the metabolism timers and refreshes the unified HUD.
    CreateThread(function()
        Wait(1000)
        for _ = 1, 10 do
            if not LocalPlayer.state.isCreatingChar and not LocalPlayer.state.isSelectingChar then
                local selectedOk, selected = pcall(function()
                    return exports.thehunt_character:isCharacterSelected()
                end)
                local coreOk, coreReady = false, false
                if GetResourceState('thehunt_core') == 'started' then
                    coreOk, coreReady = pcall(function()
                        return exports.thehunt_core:isCharacterReady()
                    end)
                end
                if (selectedOk and selected == true) or (coreOk and coreReady == true) then
                    TriggerServerEvent("vorpmetabolism:GetStatus")
                    return
                end
            end
            Wait(1000)
        end
    end)
end)

--show body only after player has fully spawned
AddEventHandler("vorp_core:Client:OnPlayerSpawned", function()
    SendNUIMessage({ action = "show_body" })
end)

-- [ THREADS ] --
function StartMetabolismThread()
    CreateThread(function()
        while (true) do
            if (not loaded) then return end

            Wait(3000);

            -- The character selector and creator are presentation-only scenes.
            -- Do not apply starvation/dehydration damage or update the survival
            -- state while the player is isolated in either of them.
            if not LocalPlayer.state.isCreatingChar and not LocalPlayer.state.isSelectingChar then
                if (PlayerStatus["Thirst"] <= 0 and not IsPlayerDead(PlayerId())) then
                    local newHealth = GetEntityHealth(PlayerPedId()) - 20;
                    if (newHealth < 1) then
                        ApplyDamageToPed(PlayerPedId(), 500000, false, 0, 0);
                    end
                    SetEntityHealth(PlayerPedId(), newHealth, 0);
                end
                if (PlayerStatus["Hunger"] <= 0 and not IsPlayerDead(PlayerId())) then
                    local newHealth = GetEntityHealth(PlayerPedId()) - 20;
                    if (newHealth < 1) then
                        ApplyDamageToPed(PlayerPedId(), 500000, false, 0, 0);
                    end
                    SetEntityHealth(PlayerPedId(), newHealth, 0);
                end

                NUIEvents.UpdateHUD()
            end
        end
    end)
end

function StartMetabolismUpdatersThread()
    CreateThread(function()
        while true do
            if (not loaded) then return end

            Wait(Config["EveryTimeStatusDown"])

            -- Character selection/creation are isolated presentation scenes,
            -- not world gameplay: never drain survival values there.
            if not IsPlayerDead(PlayerId())
                and not LocalPlayer.state.isCreatingChar and not LocalPlayer.state.isSelectingChar then
                local ped = PlayerPedId()
                local shift = IsControlPressed(0, 0x8FFC75D6) or IsDisabledControlPressed(0, 0x8FFC75D6)
                local running = IsPedOnFoot(ped) and shift
                    and (IsPedRunning(ped) or IsPedSprinting(ped) or GetEntitySpeed(ped) > 3.0)
                local food = Config[running and "HowAmountHungerWhileRunning" or "HowAmountHunger"]
                local water = Config[running and "HowAmountThirstWhileRunning" or "HowAmountThirst"]
                local stress = 0
                if GetResourceState('thehunt_survival') == 'started' then
                    local ok, state = pcall(function() return exports.thehunt_survival:GetThermalState() end)
                    if ok and type(state) == 'table' and state.valid then stress = tonumber(state.stress) or 0 end
                end
                local cold, heat = math.min(1, math.max(0, -stress)), math.min(1, math.max(0, stress))
                food = food * (1 + cold * ((Config.ColdHungerMultiplier or 1.5) - 1))
                water = water * (1 + heat * ((Config.HeatThirstMultiplier or 1.5) - 1))
                PlayerStatus["Hunger"] = math.max(0, PlayerStatus["Hunger"] - food)
                PlayerStatus["Thirst"] = math.max(0, PlayerStatus["Thirst"] - water)
                NUIEvents.UpdateHUD()
            end

            if (PlayerStatus["Metabolism"] < 10000 and PlayerStatus["Metabolism"] > -10000
                and not LocalPlayer.state.isCreatingChar and not LocalPlayer.state.isSelectingChar) then
                if (IsPedRunning(PlayerPedId())) then
                    PlayerStatus["Metabolism"] = PlayerStatus["Metabolism"] - Config["HowAmountMetabolismWhileRunning"];
                else
                    PlayerStatus["Metabolism"] = PlayerStatus["Metabolism"] - Config["HowAmountMetabolism"];
                end
            end
        end
    end)
end

function StartMetabolismSaveDBThread()
    CreateThread(function()
        while true do
            if (not loaded) then return end
            Wait(60000)
            if not LocalPlayer.state.isCreatingChar and not LocalPlayer.state.isSelectingChar then
                SaveStatusNow()
            end
        end
    end)
end

function StartRadarControlHudThread()
    CreateThread(function()
        while true do
            if (not loaded) then return end
            Wait(1000)
            if ((IsRadarHidden()) or (not ApiCalls.APIShowOn) or (NetworkIsInSpectatorMode()) or (IsHudHidden())) then
                NUIEvents.ShowHUD(false);
            else
                NUIEvents.ShowHUD(true);
            end
        end
    end)
end

function StartMetabolismSetThread()
    CreateThread(function()
        if (not loaded or not metabolismActive) then return; end

        Wait(10000);
        local pPedID = PlayerPedId();
        local metabolism = PlayerStatus["Metabolism"] and PlayerStatus["Metabolism"] / 1000 or 0

        if (metabolism == 10) then
            EquipMetaPedOutfit(pPedID, waistTypes[20]);
        elseif (metabolism == 9) then
            EquipMetaPedOutfit(pPedID, waistTypes[19]);
        elseif (metabolism == 8) then
            EquipMetaPedOutfit(pPedID, waistTypes[18]);
        elseif (metabolism == 7) then
            EquipMetaPedOutfit(pPedID, waistTypes[17]);
        elseif (metabolism == 6) then
            EquipMetaPedOutfit(pPedID, waistTypes[16]);
        elseif (metabolism == 5) then
            EquipMetaPedOutfit(pPedID, waistTypes[15]);
        elseif (metabolism == 4) then
            EquipMetaPedOutfit(pPedID, waistTypes[14]);
        elseif (metabolism == 3) then
            EquipMetaPedOutfit(pPedID, waistTypes[13]);
        elseif (metabolism == 2) then
            EquipMetaPedOutfit(pPedID, waistTypes[12]);
        elseif (metabolism == 1) then
            EquipMetaPedOutfit(pPedID, waistTypes[11]);
        elseif (metabolism == 0) then
            EquipMetaPedOutfit(pPedID, waistTypes[10]);
        elseif (metabolism == -1) then
            EquipMetaPedOutfit(pPedID, waistTypes[9]);
        elseif (metabolism == -2) then
            EquipMetaPedOutfit(pPedID, waistTypes[8]);
        elseif (metabolism == -3) then
            EquipMetaPedOutfit(pPedID, waistTypes[7]);
        elseif (metabolism == -4) then
            EquipMetaPedOutfit(pPedID, waistTypes[6]);
        elseif (metabolism == -5) then
            EquipMetaPedOutfit(pPedID, waistTypes[5]);
        elseif (metabolism == -6) then
            EquipMetaPedOutfit(pPedID, waistTypes[4]);
        elseif (metabolism == -7) then
            EquipMetaPedOutfit(pPedID, waistTypes[3]);
        elseif (metabolism == -8) then
            EquipMetaPedOutfit(pPedID, waistTypes[2]);
        elseif (metabolism == -9) then
            EquipMetaPedOutfit(pPedID, waistTypes[1]);
        elseif (metabolism == -10) then
            EquipMetaPedOutfit(pPedID, waistTypes[0]);
        end

        UpdatePedVariation(pPedID, false, true, true, true, false);
        Wait(300000);
    end)
end
