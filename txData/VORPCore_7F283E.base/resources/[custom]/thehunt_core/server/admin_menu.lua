-- =================================================================
-- Серверный обработчик админ-меню (thehunt_core)
-- Полное управление игроками, телепортация, арсенал, тогглы и модерация
-- =================================================================

local PlayerToggles = {}
local PlayerRuntimeStats = {}
local PlayerIdentifierCache = {}
local PlayerCharacterCodeCache = {}
local PlayerMenuNameCache = {}
local PlayerVorpUserCache = {}
local PlayerScaleCache = {}
local HUNT_WORLD_YEAR = 1907
local MENU_STATIC_CACHE_MS = 15000

local function GetFreshVorpCore()
    local ok, core = pcall(function()
        return exports.vorp_core:GetCore()
    end)
    if ok and type(core) == 'table' then
        VorpCore = core
        return core
    end
    return type(VorpCore) == 'table' and VorpCore or nil
end

local function RevivePlayerSafe(target)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        return false
    end

    -- Restore the saved HP/stamina capacity before VORP's normal revive/heal
    -- sequence. This keeps the existing revive behavior while preventing a
    -- temporary knocked/dead ped capacity from becoming the new maximum.
    TriggerClientEvent("thehunt_admin:prepareReviveClient", target)

    -- thehunt_death owns the knock record and delegates the actual revive to
    -- VORP. Using its export keeps the admin panel, Space and medic revive on
    -- one idempotent path.
    if GetResourceState('thehunt_death') == 'started' then
        local ok, result = pcall(function()
            return exports.thehunt_death:RevivePlayer(target)
        end)
        if ok and result then return true end
    end

    local core = GetFreshVorpCore()
    if core and core.Player and type(core.Player.Revive) == 'function' then
        local ok = pcall(function()
            core.Player.Revive(target)
        end)
        if ok then return true end
    end

    print(('[HUNT ADMIN] VORP revive API is unavailable for player %s'):format(tostring(target)))
    return false
end

local function ClampNumber(value, minValue, maxValue, fallback)
    local number = tonumber(value)
    if not number then return fallback end
    return math.max(minValue, math.min(maxValue, number))
end

local function GetOrCreatePlayerToggles(pid)
    if not PlayerToggles[pid] then
        PlayerToggles[pid] = {
            godmode = false,
            invis = false,
            superJump = false,
            frozen = false,
            freezeHunger = false,
            freezeThirst = false,
            freezeStamina = false
        }
    end
    return PlayerToggles[pid]
end

local function GetCachedPlayerIdentifiers(pid)
    local now = GetGameTimer()
    local cached = PlayerIdentifierCache[pid]
    if cached and (now - cached.updatedAt) < MENU_STATIC_CACHE_MS then
        return cached.values
    end

    local values = GetPlayerIdentifiers(pid) or {}
    PlayerIdentifierCache[pid] = { values = values, updatedAt = now }
    return values
end

local function GetCachedPlayerNames(pid)
    local now = GetGameTimer()
    local cached = PlayerMenuNameCache[pid]
    if cached and (now - cached.updatedAt) < MENU_STATIC_CACHE_MS then
        return cached.rpName, cached.redmName
    end

    local values = {
        rpName = GetPlayerRPName(pid),
        redmName = GetPlayerRedMName(pid),
        updatedAt = now,
    }
    PlayerMenuNameCache[pid] = values
    return values.rpName, values.redmName
end

local function GetCachedVorpUser(pid)
    local now = GetGameTimer()
    local cached = PlayerVorpUserCache[pid]
    if cached and (now - cached.updatedAt) < MENU_STATIC_CACHE_MS then
        return cached.user
    end

    local user = VorpCore and VorpCore.getUser(pid) or nil
    PlayerVorpUserCache[pid] = { user = user, updatedAt = now }
    return user
end

local function GetCachedCharacterCode(pid, charId)
    if charId <= 0 then return "N/A" end

    local now = GetGameTimer()
    local cached = PlayerCharacterCodeCache[pid]
    if cached and cached.charId == charId and (now - cached.updatedAt) < MENU_STATIC_CACHE_MS then
        return cached.value
    end

    local charCode = "N/A"
    pcall(function()
        charCode = exports['thehunt_character']:GetCharacterCodeById(charId) or "N/A"
    end)
    PlayerCharacterCodeCache[pid] = { charId = charId, value = charCode, updatedAt = now }
    return charCode
end

local function GetCachedPlayerScale(pid, charId, char)
    local now = GetGameTimer()
    local cached = PlayerScaleCache[pid]
    if cached and cached.charId == charId and (now - cached.updatedAt) < MENU_STATIC_CACHE_MS then
        return cached.scale
    end

    local scale = 1.0
    local found = false

    -- 1. If transformed via thehunt_pedcustom, its active scale takes precedence
    if GetResourceState('thehunt_pedcustom') == 'started' then
        local okApp, pedCustomApp = pcall(function()
            return exports.thehunt_pedcustom:GetTemporaryAppearance(pid)
        end)
        if okApp and type(pedCustomApp) == 'table' and tonumber(pedCustomApp.scale) then
            scale = tonumber(pedCustomApp.scale) or 1.0
            found = true
        end
    end

    -- 2. State bag (set by thehunt_character on character select/create/update)
    if not found then
        local stateScale = Player(pid).state.thehuntScale
        if stateScale and tonumber(stateScale) then
            scale = tonumber(stateScale)
            found = true
        end
    end

    -- 3. Active VORP character in-memory object (skin / skinPlayer)
    if not found and char then
        pcall(function()
            local rawSkin = char.skin or (type(char.Skin) == 'function' and char.Skin())
            if type(rawSkin) == 'string' and rawSkin ~= '' then
                local decoded = json.decode(rawSkin)
                if decoded and (decoded.Scale or decoded.scale) then
                    scale = tonumber(decoded.Scale or decoded.scale) or 1.0
                    found = true
                end
            elseif type(rawSkin) == 'table' and (rawSkin.Scale or rawSkin.scale) then
                scale = tonumber(rawSkin.Scale or rawSkin.scale) or 1.0
                found = true
            end
        end)
    end

    -- 4. Database fallback by charIdentifier if not yet cached
    if not found and charId and charId > 0 then
        pcall(function()
            local row = MySQL.single.await('SELECT skinPlayer FROM characters WHERE charidentifier = ? LIMIT 1', { charId })
            if row and row.skinPlayer and row.skinPlayer ~= '' then
                local decoded = json.decode(row.skinPlayer)
                if decoded and (decoded.Scale or decoded.scale) then
                    scale = tonumber(decoded.Scale or decoded.scale) or 1.0
                    found = true
                end
            end
        end)
    end

    scale = ClampNumber(scale, 0.2, 3.0, 1.0)
    PlayerScaleCache[pid] = { charId = charId, scale = scale, updatedAt = now }
    Player(pid).state:set('thehuntScale', scale, true)
    return scale
end

AddEventHandler("playerDropped", function()
    local src = source
    PlayerToggles[src] = nil
    PlayerRuntimeStats[src] = nil
    PlayerIdentifierCache[src] = nil
    PlayerCharacterCodeCache[src] = nil
    PlayerMenuNameCache[src] = nil
    PlayerVorpUserCache[src] = nil
    PlayerScaleCache[src] = nil
end)

local globalEmptyWorld = true

RegisterNetEvent("thehunt_admin:toggleEmptyWorldServer", function(state)
    local src = source
    if not IsPlayerAdmin(src) then return end

    if state ~= nil then
        globalEmptyWorld = (state == true)
    else
        globalEmptyWorld = not globalEmptyWorld
    end

    TriggerClientEvent("thehunt_admin:syncEmptyWorld", -1, globalEmptyWorld)
    print(string.format("^3[HUNT WORLD] Admin #%d toggled empty world state to: %s^7", src, tostring(globalEmptyWorld)))
end)

RegisterNetEvent("thehunt_admin:requestEmptyWorldState", function()
    local src = source
    TriggerClientEvent("thehunt_admin:syncEmptyWorld", src, globalEmptyWorld)
end)

RegisterNetEvent("thehunt_admin:checkPermissionAndOpen", function()
    local src = source
    if IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_admin:openMenuClient", src)
    else
        TriggerClientEvent("thehunt_rp:show3DText", src, src, "(( У вас нет прав администратора ))", { 255, 60, 60 })
    end
end)

RegisterNetEvent("thehunt_admin:checkPermissionAndToggleNoClip", function()
    local src = source
    if IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_admin:confirmToggleNoClip", src)
    else
        TriggerClientEvent("thehunt_rp:show3DText", src, src, "(( У вас нет прав администратора ))", { 255, 60, 60 })
    end
end)

-- Клиент знает актуальные значения локального status HUD лучше сервера.
-- Принимаем только собственный снимок source и используем его только для отображения в админ-панели.
RegisterNetEvent("thehunt_admin:reportPlayerStats", function(stats)
    local src = source
    if type(stats) ~= "table" then return end

    local maxHealth = ClampNumber(stats.maxHealth, 1, 10000, 100)
    local health = ClampNumber(stats.health, 0, maxHealth, maxHealth)
    local healthPercent = ClampNumber(stats.healthPercent, 0, 100, (health / maxHealth) * 100)

    PlayerRuntimeStats[src] = {
        health = health,
        maxHealth = maxHealth,
        healthPercent = healthPercent,
        hunger = ClampNumber(stats.hunger, 0, 100, 100),
        thirst = ClampNumber(stats.thirst, 0, 100, 100),
        updatedAt = GetGameTimer()
    }
end)

-- Запрос расширенного списка игроков для админ-меню со всеми RedM и VORP данными
RegisterNetEvent("thehunt_admin:getPlayersForMenu", function()
    local src = source
    if not IsPlayerAdmin(src) then return end

    if not VorpCore and exports.vorp_core then
        VorpCore = exports.vorp_core:GetCore()
    end

    local playersList = {}
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        local rpName, redmName = GetCachedPlayerNames(pid)
        local ping = GetPlayerPing(pid)
        local ped = GetPlayerPed(pid)

        local steamHex = "N/A"
        local discord = "N/A"
        local license = "N/A"
        for _, id in ipairs(GetCachedPlayerIdentifiers(pid)) do
            if string.sub(id, 1, 6) == "steam:" then
                steamHex = id
            elseif string.sub(id, 1, 8) == "discord:" then
                discord = id
            elseif string.sub(id, 1, 8) == "license:" then
                license = id
            end
        end

        local charId = 0
        local char = nil
        local group = "user"
        local isDead = false
        local nationality = Player(pid).state.thehuntNationality or "Американец"
        local age = 0
        local birthdate = ""

        if VorpCore then
            pcall(function()
                local user = GetCachedVorpUser(pid)
                if user then
                    if type(user.getGroup) == "function" then
                        group = user.getGroup()
                    elseif type(user.getGroup) == "string" then
                        group = user.getGroup
                    end

                    if type(user.getUsedCharacter) == "table" then
                        char = user.getUsedCharacter
                    elseif type(user.getUsedCharacter) == "function" then
                        char = user.getUsedCharacter()
                    end

                    if char then
                        charId = tonumber(char.charIdentifier or char.charid) or 0
                        if char.group and group == "user" then
                            group = tostring(char.group)
                        end
                        if char.firstname and char.lastname then
                            local fn = tostring(char.firstname):gsub("^%s*(.-)%s*$", "%1")
                            local ln = tostring(char.lastname):gsub("^%s*(.-)%s*$", "%1")
                            if fn ~= "" or ln ~= "" then
                                rpName = (fn .. " " .. ln):gsub("^%s*(.-)%s*$", "%1")
                            end
                        end
                        if char.isdead ~= nil then
                            isDead = (char.isdead == true or char.isdead == 1 or char.isdead == "1")
                        end
                        age = tonumber(char.age) or 0
                        birthdate = tostring(char.birthdate or "")
                    end
                end
            end)
        end

        local birthYear = tonumber(string.match(birthdate, "(%d%d%d%d)$"))
        if not birthYear and age > 0 then
            birthYear = HUNT_WORLD_YEAR - age
        end
        if birthYear and age <= 0 then
            age = HUNT_WORLD_YEAR - birthYear
        end

        local adminOverride = GetPlayerAdminOverride(pid)
        if adminOverride == false then
            -- The HUNT panel's explicit revoke must also be reflected in the
            -- list, even if a stale VORP/ACE group still says "admin".
            group = "user"
        elseif (group == "user" or not group or group == "") and IsPlayerAdmin(pid) then
            group = "admin"
        end

        local coords = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }
        local pedModel = 0
        local health = 100
        local maxHealth = 100
        local healthPercent = 100
        local food = 100
        local water = 100
        local inVehicle = false
        local onMount = false

        if DoesEntityExist(ped) then
            pcall(function()
                local c = GetEntityCoords(ped)
                if c then
                    coords = {
                        x = math.floor(c.x * 100) / 100,
                        y = math.floor(c.y * 100) / 100,
                        z = math.floor(c.z * 100) / 100,
                        h = math.floor(GetEntityHeading(ped) * 10) / 10
                    }
                end
                pedModel = GetEntityModel(ped) or 0
                local h = GetEntityHealth(ped)
                if h and h >= 0 then
                    health = h
                end
                local mh = GetEntityMaxHealth(ped)
                if mh and mh > 0 then
                    maxHealth = mh
                end
            end)
        end

        local runtimeStats = PlayerRuntimeStats[pid]
        if runtimeStats and runtimeStats.updatedAt and (GetGameTimer() - runtimeStats.updatedAt) <= 10000 then
            health = runtimeStats.health or health
            maxHealth = runtimeStats.maxHealth or maxHealth
            healthPercent = runtimeStats.healthPercent or healthPercent
            food = runtimeStats.hunger or food
            water = runtimeStats.thirst or water
        elseif maxHealth > 0 then
            healthPercent = (health / maxHealth) * 100
        end

        local toggles = GetOrCreatePlayerToggles(pid)
        local charCode = GetCachedCharacterCode(pid, charId)
        local scale = GetCachedPlayerScale(pid, charId, char)

        table.insert(playersList, {
            id = pid,
            name = tostring(rpName or ("Игрок #" .. tostring(pid))),
            redmName = tostring(redmName or ""),
            ping = tonumber(ping) or 0,
            charId = tonumber(charId) or 0,
            charCode = tostring(charCode or "N/A"),
            nationality = tostring(nationality or "Американец"),
            scale = tonumber(string.format("%.3f", scale)) or 1.0,
            steamHex = tostring(steamHex or "N/A"),
            discord = tostring(discord or "N/A"),
            license = tostring(license or "N/A"),
            group = tostring(group or "user"),
            coords = coords,
            pedModel = tonumber(pedModel) or 0,
            health = tonumber(health) or 100,
            maxHealth = tonumber(maxHealth) or 100,
            healthPercent = math.floor(ClampNumber(healthPercent, 0, 100, 100) + 0.5),
            food = math.floor(ClampNumber(food, 0, 100, 100) + 0.5),
            water = math.floor(ClampNumber(water, 0, 100, 100) + 0.5),
            birthYear = tonumber(birthYear) or 0,
            age = math.max(0, tonumber(age) or 0),
            birthdate = birthdate,
            isDead = not not isDead,
            inVehicle = not not inVehicle,
            onMount = not not onMount,
            toggles = {
                godmode = not not toggles.godmode,
                invis = not not toggles.invis,
                superJump = not not toggles.superJump,
                frozen = not not toggles.frozen,
                freezeHunger = not not toggles.freezeHunger,
                freezeThirst = not not toggles.freezeThirst,
                freezeStamina = not not toggles.freezeStamina
            }
        })
    end

    TriggerClientEvent("thehunt_admin:receivePlayersForMenu", src, playersList)
end)

-- Выдача оружия через серверные события VORP
RegisterNetEvent("thehunt_admin:giveWeaponServer", function(weaponName, targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local target = tonumber(targetId) or src
    if exports.vorp_weaponsv2 then
        pcall(function()
            exports.vorp_weaponsv2:giveWeapon(target, weaponName, 500, {})
        end)
    end
    TriggerClientEvent("thehunt_admin:applyWeaponClient", target, weaponName)
end)

-- Восстановление метаболизма
RegisterNetEvent("thehunt_admin:refillMetabolism", function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local target = tonumber(targetId) or src
    TriggerClientEvent("vorpmetabolism:changeValue", target, "Hunger", 1000)
    TriggerClientEvent("vorpmetabolism:changeValue", target, "Thirst", 1000)
    TriggerClientEvent("thehunt_status:updateMetabolism", target, 1000, 1000)
    TriggerClientEvent("thehunt_admin:applyMetabolismClient", target)
end)

-- Воскрешение цели
RegisterNetEvent("thehunt_admin:reviveTarget", function(targetId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local target = tonumber(targetId) or src
    RevivePlayerSafe(target)
end)

-- Прямая выдача предметов из админ-панели (вкладка Предметы)
RegisterNetEvent("thehunt_items:adminGiveItem", function(itemName, count, targetPlayerId)
    local src = source
    if not IsPlayerAdmin(src) then return end

    local normalizedItemName = string.lower(tostring(itemName or ""))
    if normalizedItemName == "clothing_badge" or normalizedItemName == "clothing_buckle" then return end

    local target = tonumber(targetPlayerId)
    if not target or target == 0 then
        target = src
    end

    local cnt = math.max(1, tonumber(count) or 1)
    if GetResourceState('thehunt_items') == 'started' then
        exports.thehunt_items:GiveItem(target, itemName, cnt)
    else
        print(string.format('^1[HUNT ADMIN] Cannot give item %s: thehunt_items is not started.^7', tostring(itemName)))
    end

    if target ~= src then
        local itemDef = exports.thehunt_items and exports.thehunt_items.GetItemData and exports.thehunt_items:GetItemData(itemName)
        local itemLabel = itemDef and (itemDef.label or itemName) or itemName
        local countSuffix = cnt > 1 and string.format(" (x%d)", cnt) or ""
        TriggerClientEvent("thehunt_status:notify", target, "Инвентарь", string.format("Администратор выдал вам «%s»%s", itemLabel, countSuffix), "info")
    end
end)

-- Обратный ответ клиентских координат для телепортации админа
RegisterNetEvent("thehunt_admin:reportCoordsForAdminTp", function(adminSrc, x, y, z)
    if not IsPlayerAdmin(adminSrc) then return end
    if x and y and z then
        TriggerClientEvent("thehunt_admin:tpToCoords", adminSrc, x, y, z + 0.5)
    end
end)

-- Комплексные действия над игроками из админ-меню (синхронизация тогглов и эффектов)
RegisterNetEvent("thehunt_admin:playerAction", function(targetId, action, extraData)
    local src = source
    if not IsPlayerAdmin(src) then
        print(string.format("^1[HUNT ADMIN ACTION] DENIED: Source #%d is not admin!^7", src))
        return
    end

    local target = tonumber(targetId)
    if not target then return end

    if LogPlayerActivity then
        local targetName = "Неизвестный"
        pcall(function()
            targetName = GetPlayerRPName(target) or targetName
        end)
        LogPlayerActivity(src, "admin_action", string.format(
            "Администратор выполнил действие «%s» над игроком #%d (%s)",
            tostring(action),
            target,
            tostring(targetName or "Неизвестный")
        ), {
            action = tostring(action),
            targetSourceId = target,
            targetCharacterName = tostring(targetName or "Неизвестный"),
        })
    end

    print(string.format("^2[HUNT ADMIN ACTION] Admin #%d -> Target #%d | Action: %s^7", src, target, tostring(action)))

    local adminPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    local toggles = GetOrCreatePlayerToggles(target)

    if action == 'tpTo' then
        local coords = nil
        if DoesEntityExist(targetPed) then
            coords = GetEntityCoords(targetPed)
        end
        if coords and (coords.x ~= 0 or coords.y ~= 0 or coords.z ~= 0) then
            TriggerClientEvent("thehunt_admin:tpToCoords", src, coords.x, coords.y, coords.z + 0.5)
        else
            TriggerClientEvent("thehunt_admin:requestCoordsForAdminTp", target, src)
        end

    elseif action == 'tpHere' then
        local coords = nil
        if DoesEntityExist(adminPed) then
            coords = GetEntityCoords(adminPed)
        end
        if coords and (coords.x ~= 0 or coords.y ~= 0 or coords.z ~= 0) then
            TriggerClientEvent("thehunt_admin:tpToCoords", target, coords.x, coords.y, coords.z + 0.5)
        end

    elseif action == 'tpLocation' and extraData then
        local x = tonumber(extraData.x)
        local y = tonumber(extraData.y)
        local z = tonumber(extraData.z)
        if x and y and z then
            TriggerClientEvent("thehunt_admin:tpToCoords", target, x, y, z + 0.5)
        end

    elseif action == 'heal' then
        TriggerClientEvent("vorp_medic:heal", target)
        TriggerClientEvent("vorp:healPlayer", target)
        TriggerClientEvent("vorpmetabolism:changeValue", target, "Hunger", 1000)
        TriggerClientEvent("vorpmetabolism:changeValue", target, "Thirst", 1000)
        TriggerClientEvent("thehunt_status:updateMetabolism", target, 1000, 1000)
        TriggerClientEvent("thehunt_admin:applyHealClient", target)

    elseif action == 'metabolism' then
        TriggerClientEvent("vorpmetabolism:changeValue", target, "Hunger", 1000)
        TriggerClientEvent("vorpmetabolism:changeValue", target, "Thirst", 1000)
        TriggerClientEvent("thehunt_status:updateMetabolism", target, 1000, 1000)
        TriggerClientEvent("thehunt_admin:applyMetabolismClient", target)

    elseif action == 'setStats' and type(extraData) == 'table' then
        local requestedStats = {}
        local runtimeStats = PlayerRuntimeStats[target] or {
            health = 100,
            maxHealth = 100,
            healthPercent = 100,
            hunger = 100,
            thirst = 100
        }

        if extraData.health ~= nil then
            requestedStats.health = math.floor(ClampNumber(extraData.health, 0, 100, runtimeStats.healthPercent or 100) + 0.5)
            runtimeStats.healthPercent = requestedStats.health
            runtimeStats.health = (runtimeStats.maxHealth or 100) * requestedStats.health / 100
        end
        if extraData.hunger ~= nil then
            requestedStats.hunger = math.floor(ClampNumber(extraData.hunger, 0, 100, runtimeStats.hunger or 100) + 0.5)
            runtimeStats.hunger = requestedStats.hunger
        end
        if extraData.thirst ~= nil then
            requestedStats.thirst = math.floor(ClampNumber(extraData.thirst, 0, 100, runtimeStats.thirst or 100) + 0.5)
            runtimeStats.thirst = requestedStats.thirst
        end

        if next(requestedStats) then
            runtimeStats.updatedAt = GetGameTimer()
            PlayerRuntimeStats[target] = runtimeStats
            TriggerClientEvent("thehunt_admin:setPlayerStatsClient", target, requestedStats)
        end

    elseif action == 'refillStamina' then
        TriggerClientEvent("thehunt_admin:applyStaminaClient", target)

    elseif action == 'revive' then
        RevivePlayerSafe(target)

    elseif action == 'kill' then
        TriggerClientEvent("thehunt_admin:applyKillClient", target)

    elseif action == 'toggleGodmode' then
        toggles.godmode = not toggles.godmode
        TriggerClientEvent("thehunt_admin:toggleGodmodeClient", target, toggles.godmode)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'toggleInvis' then
        toggles.invis = not toggles.invis
        TriggerClientEvent("thehunt_admin:toggleInvisClient", target, toggles.invis)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'toggleSuperJump' then
        toggles.superJump = not toggles.superJump
        TriggerClientEvent("thehunt_admin:toggleSuperJumpClient", target, toggles.superJump)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'freeze' then
        toggles.frozen = not toggles.frozen
        TriggerClientEvent("thehunt_admin:toggleFreezeClient", target, toggles.frozen)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'cleanPed' then
        TriggerClientEvent("thehunt_admin:cleanPedClient", target)

    elseif action == 'toggleFreezeHunger' then
        toggles.freezeHunger = not toggles.freezeHunger
        TriggerClientEvent("thehunt_admin:toggleFreezeHungerClient", target, toggles.freezeHunger)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'toggleFreezeThirst' then
        toggles.freezeThirst = not toggles.freezeThirst
        TriggerClientEvent("thehunt_admin:toggleFreezeThirstClient", target, toggles.freezeThirst)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'toggleFreezeStamina' then
        toggles.freezeStamina = not toggles.freezeStamina
        TriggerClientEvent("thehunt_admin:toggleFreezeStaminaClient", target, toggles.freezeStamina)
        TriggerClientEvent("thehunt_admin:updatePlayerToggles", -1, target, toggles)

    elseif action == 'giveAmmo' then
        TriggerClientEvent("thehunt_admin:applyAmmoClient", target)

    elseif action == 'disarm' then
        TriggerClientEvent("thehunt_admin:disarmClient", target)

    elseif action == 'giveWeapon' and extraData and extraData.weapon then
        local weaponName = tostring(extraData.weapon)
        if exports.vorp_weaponsv2 then
            pcall(function()
                exports.vorp_weaponsv2:giveWeapon(target, weaponName, 500, {})
            end)
        end
        TriggerClientEvent("thehunt_admin:applyWeaponClient", target, weaponName)

    elseif action == 'giveItem' and extraData and extraData.item then
        local itemName = tostring(extraData.item)
        local normalizedItemName = string.lower(itemName)
        if normalizedItemName == "clothing_badge" or normalizedItemName == "clothing_buckle" then return end
        local count = math.max(1, tonumber(extraData.count) or 1)
        if GetResourceState('thehunt_items') == 'started' then
            exports.thehunt_items:GiveItem(target, itemName, count)
        else
            print(string.format('^1[HUNT ADMIN] Cannot give item %s: thehunt_items is not started.^7', tostring(itemName)))
        end

        if target ~= src then
            local itemDef = exports.thehunt_items and exports.thehunt_items.GetItemData and exports.thehunt_items:GetItemData(itemName)
            local itemLabel = itemDef and (itemDef.label or itemName) or itemName
            local countSuffix = count > 1 and string.format(" (x%d)", count) or ""
            TriggerClientEvent("thehunt_status:notify", target, "Инвентарь", string.format("Администратор выдал вам «%s»%s", itemLabel, countSuffix), "info")
        end

    elseif action == 'spawnHorse' and extraData and extraData.model then
        TriggerClientEvent("thehunt_admin:spawnHorseForPlayerClient", target, extraData.model)

    elseif action == 'spawnWagon' and extraData and extraData.model then
        TriggerClientEvent("thehunt_admin:spawnWagonForPlayerClient", target, extraData.model)

    elseif action == 'healMount' then
        TriggerClientEvent("thehunt_admin:healMountClient", target)

    elseif action == 'deleteVehicle' then
        TriggerClientEvent("thehunt_admin:deleteVehicleClient", target)

    elseif action == 'toggleAdminGroup' then
        PlayerVorpUserCache[target] = nil
        PlayerCharacterCodeCache[target] = nil
        local core = VorpCore or (exports.vorp_core and exports.vorp_core:GetCore())
        local currentOverride = GetPlayerAdminOverride(target)
        local curIsAdmin = currentOverride
        if curIsAdmin == nil then
            curIsAdmin = IsPlayerAdmin(target)
        end
        local newGroup = curIsAdmin and "user" or "admin"
        if extraData and extraData.group then
            newGroup = tostring(extraData.group):lower()
        end
        local isNewAdmin = false
        if Config and Config.AdminGroups then
            for _, adminGroup in ipairs(Config.AdminGroups) do
                if newGroup == string.lower(tostring(adminGroup)) then
                    isNewAdmin = true
                    break
                end
            end
        end
        if newGroup == "admin" or newGroup == "superadmin" or newGroup == "mod" or newGroup == "moderator" or newGroup == "owner" or newGroup == "developer" then
            isNewAdmin = true
        end

        -- 1. Persist an explicit HUNT decision for every current identifier.
        -- This is the authoritative layer for both grant and revoke.
        local permissionSaved, permissionError = SetPlayerAdminOverride(target, isNewAdmin, newGroup)

        -- Keep the legacy runtime table in sync for older integrations that
        -- read AdminIdentifiers directly. Persistent overrides still win on
        -- the next resource restart.
        local targetIdentifiers = GetPlayerIdentifiers(target) or {}
        for _, id in ipairs(targetIdentifiers) do
            local idStr = string.lower(tostring(id))
            local cleanId = idStr:gsub("discord:", ""):gsub("steam:", ""):gsub("license2:", ""):gsub("license:", "")
            if isNewAdmin then
                if AdminIdentifiers then
                    AdminIdentifiers[idStr] = true
                    AdminIdentifiers[cleanId] = true
                end
            else
                if AdminIdentifiers then
                    AdminIdentifiers[idStr] = nil
                    AdminIdentifiers[cleanId] = nil
                end
            end
        end

        -- 2. Update VORP Core in memory (user and current character).
        local coreUpdateOk, coreUpdateError = true, nil
        if core then
            coreUpdateOk, coreUpdateError = pcall(function()
                local user = core.getUser(target)
                if user then
                    if type(user.setGroup) == "function" then
                        user.setGroup(newGroup)
                    end
                    local char = nil
                    if type(user.getUsedCharacter) == "table" then
                        char = user.getUsedCharacter
                    elseif type(user.getUsedCharacter) == "function" then
                        char = user.getUsedCharacter()
                    end

                    local function applyGroupToCharacter(character)
                        if not character then return end
                        if type(character.setGroup) == "function" then
                            character.setGroup(newGroup)
                        else
                            character.group = newGroup
                        end
                    end

                    -- Update the current character and every cached VORP
                    -- character, not only the one currently selected.
                    applyGroupToCharacter(char)
                    local cachedCharacters = user.getUserCharacters
                    if type(cachedCharacters) == "function" then
                        cachedCharacters = cachedCharacters()
                    end
                    if type(cachedCharacters) == "table" then
                        for _, cachedCharacter in pairs(cachedCharacters) do
                            if cachedCharacter ~= char then
                                applyGroupToCharacter(cachedCharacter)
                            end
                        end
                    end
                end
            end)
        end

        -- 3. Directly update the same VORP records used during login.
        -- VORP identifies users and all their characters by the Steam ID.
        local dbUpdateOk, dbUpdateError = pcall(function()
            local steamIdentifier = GetPlayerIdentifierByType(target, "steam")
            if not steamIdentifier then
                error("steam identifier is unavailable")
            end

            MySQL.update.await("UPDATE users SET `group` = ? WHERE `identifier` = ?", { newGroup, steamIdentifier })
            MySQL.update.await("UPDATE characters SET `group` = ? WHERE `identifier` = ?", { newGroup, steamIdentifier })

            local user = core and core.getUser(target)
            if user then
                local char = type(user.getUsedCharacter) == "table" and user.getUsedCharacter or (type(user.getUsedCharacter) == "function" and user.getUsedCharacter() or nil)
                if char and (char.charIdentifier or char.charid) then
                    local cid = tonumber(char.charIdentifier or char.charid)
                    MySQL.update.await("UPDATE characters SET `group` = ? WHERE `charidentifier` = ?", { newGroup, cid })
                end
            end
        end)

        -- 4. Keep the legacy VORP event/state path in sync.
        TriggerEvent("vorp:setGroup", target, newGroup)

        print(string.format("^2[HUNT ADMIN] Admin #%d (%s) changed group of player #%d (%s) to: %s (persistent=%s)^7", 
            src, GetPlayerName(src) or "Admin", target, GetPlayerName(target) or "Player", newGroup, tostring(permissionSaved)))

        if not permissionSaved or not coreUpdateOk or not dbUpdateOk then
            print(string.format("^1[HUNT ADMIN] Permission update completed with warnings: storage=%s core=%s db=%s (%s; %s; %s)^7",
                tostring(permissionSaved), tostring(coreUpdateOk), tostring(dbUpdateOk), tostring(permissionError), tostring(coreUpdateError), tostring(dbUpdateError)))
            TriggerClientEvent("thehunt_status:notify", src, "Права администратора", "Изменение применено в памяти, но сохранение завершилось с предупреждением. Проверьте консоль сервера.", "warning")
        end

        -- 5. Refresh the admin list and notify the target.
        Citizen.SetTimeout(100, function()
            TriggerClientEvent("thehunt_admin:refreshPlayersList", src)
            if target ~= src then
                TriggerClientEvent("thehunt_status:notify", target, "Права администратора", 
                    isNewAdmin and "Вам выданы права администратора (F4)" or "С вас сняты права администратора", 
                    isNewAdmin and "success" or "warning")
            end
        end)

    elseif action == 'kick' and extraData and extraData.reason then
        local reason = tostring(extraData.reason or "Исключен администратором")
        DropPlayer(tostring(target), reason)

    elseif action == 'sendToast' and extraData and extraData.message then
        local msg = tostring(extraData.message):sub(1, 500)
        local durationSeconds = math.floor(ClampNumber(extraData.duration, 1, 60, 15) + 0.5)
        TriggerClientEvent("thehunt_status:adminNotification", target, msg, durationSeconds * 1000)
    end
end)

-- Выполнение команд тестирования с проверкой прав админа
RegisterNetEvent("thehunt_admin:executeTestingCommand", function(cmdType, arg1)
    local src = source
    if not IsPlayerAdmin(src) then
        TriggerClientEvent("thehunt_rp:show3DText", src, src, "(( Команда доступна только администраторам ))", { 255, 60, 60 })
        return
    end

    if cmdType == "weapon" then
        TriggerClientEvent("thehunt_admin:applyWeaponClient", src, arg1)
    elseif cmdType == "ammo" then
        TriggerClientEvent("thehunt_admin:applyAmmoClient", src)
    elseif cmdType == "fireball" then
        TriggerClientEvent("thehunt_admin:castFireballClient", src)
    end
end)
