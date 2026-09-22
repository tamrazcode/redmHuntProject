local Core = exports.vorp_core:GetCore()

local pendingCast = {} -- [src] = { spellId, itemMainId, at }
local nextCastAt = {}
local servantUp = {}

local function spellByItem(itemName)
    if not Config.Spells then
        return nil, nil
    end
    for spellId, spell in pairs(Config.Spells) do
        if spell.item == itemName then
            return spellId, spell
        end
    end
    return nil, nil
end

local function notify(src, text, ms)
    if Core and Core.NotifyTip then
        Core.NotifyTip(src, text, ms or 3500)
    else
        TriggerClientEvent("vorp:TipRight", src, text, ms or 3500)
    end
end

local function startPendingCast(src, spellId, spell, itemMainId, huntDbId)
    local readyAt = (nextCastAt[src] and nextCastAt[src][spellId]) or 0
    if os.time() < readyAt then
        notify(src, spell.failCooldown or "Not ready.", 2500)
        return false
    end
    if spell.necro and servantUp[src] then
        notify(src, spell.failServant or "Пока слуга жив, карту нельзя использовать.", 2500)
        return false
    end
    if pendingCast[src] then
        notify(src, spell.failBusy or "Already casting.", 2500)
        return false
    end

    pendingCast[src] = {
        spellId = spellId,
        itemMainId = itemMainId,
        huntDbId = huntDbId,
        at = os.time(),
    }

    if GetResourceState("thehunt_inventory") == "started" then
        TriggerClientEvent("thehunt_inventory:forceClose", src)
    end
    TriggerClientEvent("hh_magic:client:beginAim", src, spellId)
    return true
end

exports("BeginFromItem", function(src, itemName, dbId)
    local spellId, spell = spellByItem(itemName)
    if not spellId or not spell then
        return false
    end
    return startPendingCast(src, spellId, spell, nil, tonumber(dbId))
end)

RegisterNetEvent("hh_magic:server:castResult", function(spellId, success, reason)
    local src = source
    local pending = pendingCast[src]
    pendingCast[src] = nil

    if not pending or pending.spellId ~= spellId then
        return
    end

    local spell = Config.Spells and Config.Spells[spellId]
    if not spell then
        return
    end

    if success then
        nextCastAt[src] = nextCastAt[src] or {}
        local untilAt = os.time() + math.ceil((spell.cooldownMs or 8000) / 1000)
        if untilAt > (nextCastAt[src][spellId] or 0) then
            nextCastAt[src][spellId] = untilAt
        end
        if spell.consumeItem and pending.huntDbId and GetResourceState("thehunt_items") == "started" then
            exports.thehunt_items:RemoveStackCount(src, pending.huntDbId, 1)
        end
    end

    if Config.Debug then
        print(("[hh_magic] %s cast %s success=%s reason=%s"):format(tostring(src), tostring(spellId), tostring(success), tostring(reason)))
    end
end)

AddEventHandler("playerDropped", function()
    pendingCast[source] = nil
    servantUp[source] = nil
end)

RegisterNetEvent("hh_magic:server:servant", function(up)
    if up then
        servantUp[source] = true
    else
        servantUp[source] = nil
    end
end)

local thornSeq = 0

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

RegisterNetEvent("hh_magic:server:aimCancel", function(spellId)
    local src = source
    local pending = pendingCast[src]
    if not pending or pending.spellId ~= spellId or pending.confirmed then
        return
    end
    pendingCast[src] = nil
end)

local function abortAim(src, spellId, text)
    pendingCast[src] = nil
    if text and text ~= "" then
        notify(src, text, 2500)
    end
    TriggerClientEvent("hh_magic:client:aimAborted", src, spellId)
end

RegisterNetEvent("hh_magic:server:aimConfirm", function(spellId, x, y, z)
    local src = source
    local pending = pendingCast[src]
    if not pending or pending.spellId ~= spellId or pending.confirmed then
        if not (pending and pending.confirmed and pending.spellId == spellId) then
            TriggerClientEvent("hh_magic:client:aimAborted", src, spellId)
        end
        return
    end

    local spell = Config.Spells and Config.Spells[spellId]
    local thorns = spell and spell.thorns
    if not spell or not thorns then
        abortAim(src, spellId, nil)
        return
    end

    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then
        abortAim(src, spellId, spell.failAim or "Сюда нельзя.")
        return
    end

    local coords = playerCoords(src)
    if not coords then
        abortAim(src, spellId, nil)
        return
    end

    local range = thorns.range or 20.0
    local dist = #(coords - vector3(x, y, z))
    if dist > range + 1.5 then
        abortAim(src, spellId, spell.failAim or "Сюда нельзя.")
        return
    end

    local readyAt = (nextCastAt[src] and nextCastAt[src][spellId]) or 0
    if os.time() < readyAt then
        abortAim(src, spellId, spell.failCooldown or "Not ready.")
        return
    end

    pending.confirmed = true
    pending.point = { x = x, y = y, z = z }
    TriggerClientEvent("hh_magic:client:tryCast", src, spellId)
end)

RegisterNetEvent("hh_magic:server:thornsRelease", function(spellId)
    local src = source
    local pending = pendingCast[src]
    if not pending or pending.spellId ~= spellId or not pending.confirmed or not pending.point or pending.released then
        return
    end
    pending.released = true

    local spell = Config.Spells and Config.Spells[spellId]
    local thorns = spell and spell.thorns
    if not thorns then
        return
    end

    nextCastAt[src] = nextCastAt[src] or {}
    nextCastAt[src][spellId] = os.time() + math.ceil((spell.cooldownMs or 8000) / 1000)

    thornSeq = thornSeq + 1
    TriggerClientEvent("hh_magic:client:thornsApply", -1, {
        id = thornSeq,
        x = pending.point.x,
        y = pending.point.y,
        z = pending.point.z,
        radius = thorns.radius or 4.0,
        durationMs = thorns.durationMs or 30000,
        maxHeightDiff = thorns.maxHeightDiff or 2.5,
    })
end)

RegisterNetEvent("hh_magic:server:giveCard", function(spellId)
    local src = source
    if type(spellId) ~= "string" or spellId == "" then
        return
    end

    local spell = Config.Spells and Config.Spells[spellId]
    if not spell or not spell.item or spell.item == "" then
        notify(src, "Unknown card.", 2500)
        return
    end

    local amount = (Config.DevMenu and Config.DevMenu.giveAmount) or 1
    if amount < 1 then
        amount = 1
    end

    if GetResourceState("thehunt_items") ~= "started" then
        notify(src, "Инвентарь сборки не запущен.", 3000)
        return
    end

    exports.thehunt_items:AddItem(src, spell.item, amount)
    notify(src, ("Received: %s"):format(spell.label or spell.item), 3000)
end)

local ravenSessions = {}
local ravenSeq = 0

local function ravenCfg(spell)
    return (spell and spell.raven) or {}
end

local function clearRaven(src, reason, tellClient)
    local row = ravenSessions[src]
    if not row or row.closing then
        return
    end
    row.closing = true
    if row.entity and row.entity ~= 0 and DoesEntityExist(row.entity) then
        local net = NetworkGetNetworkIdFromEntity(row.entity)
        if not row.net or net == row.net then
            DeleteEntity(row.entity)
        end
    end
    ravenSessions[src] = nil
    if pendingCast[src] and pendingCast[src].spellId == row.spellId and not row.consumed then
        pendingCast[src] = nil
    end
    if tellClient then
        TriggerClientEvent("hh_magic:raven:stop", src, row.id, reason or "end")
    end
end

local function consumeRaven(src, row)
    if row.consumed then
        return
    end
    local pending = pendingCast[src]
    local spell = Config.Spells and Config.Spells[row.spellId]
    if not pending or pending.spellId ~= row.spellId or not spell then
        return
    end
    row.consumed = true
    pendingCast[src] = nil
    nextCastAt[src] = nextCastAt[src] or {}
    nextCastAt[src][row.spellId] = os.time() + math.ceil((spell.cooldownMs or 15000) / 1000)
        if spell.consumeItem and pending.huntDbId and GetResourceState("thehunt_items") == "started" then
            exports.thehunt_items:RemoveStackCount(src, pending.huntDbId, 1)
        end
end

RegisterNetEvent("hh_magic:raven:request", function(spellId)
    local src = source
    local pending = pendingCast[src]
    local spell = Config.Spells and Config.Spells[spellId]
    if not pending or pending.spellId ~= spellId or not spell or not spell.raven then
        TriggerClientEvent("hh_magic:raven:denied", src, spell and spell.failBusy or "Сейчас нельзя.")
        return
    end
    if ravenSessions[src] then
        TriggerClientEvent("hh_magic:raven:denied", src, spell.failBusy or "Сейчас нельзя.")
        return
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        TriggerClientEvent("hh_magic:raven:denied", src, spell.failBird or "Ворон не откликнулся.")
        return
    end
    ravenSeq = ravenSeq + 1
    local id = ("raven_%s_%s"):format(src, ravenSeq)
    ravenSessions[src] = {
        id = id,
        spellId = spellId,
        stage = "approved",
        started = os.time(),
        deadline = os.time() + 20,
        origin = GetEntityCoords(ped),
        consumed = false,
        closing = false,
    }
    TriggerClientEvent("hh_magic:raven:approved", src, { id = id, spellId = spellId })
end)

RegisterNetEvent("hh_magic:raven:spawned", function(id, netId, x, y, z)
    local src = source
    local row = ravenSessions[src]
    if not row or row.id ~= id or row.stage ~= "approved" or row.closing then
        return
    end
    netId = tonumber(netId)
    if not netId or netId == 0 then
        clearRaven(src, "spawn", true)
        return
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local tries = 0
    while (not entity or entity == 0 or not DoesEntityExist(entity)) and tries < 20 do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
        tries = tries + 1
        if ravenSessions[src] ~= row or row.closing then
            return
        end
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        clearRaven(src, "spawn", true)
        return
    end
    if GetEntityModel(entity) ~= 0xDDB5012B and GetEntityModel(entity) ~= joaat("a_c_raven_01") then
        clearRaven(src, "spawn", true)
        return
    end
    local pos = GetEntityCoords(entity)
    if row.origin and #(pos - row.origin) > 20.0 then
        clearRaven(src, "spawn", true)
        return
    end
    row.stage = "spawned"
    row.net = netId
    row.entity = entity
    row.deadline = os.time() + 12
    TriggerClientEvent("hh_magic:raven:registered", src, id)
end)

RegisterNetEvent("hh_magic:raven:ready", function(id)
    local src = source
    local row = ravenSessions[src]
    if not row or row.id ~= id or row.stage ~= "spawned" or row.closing then
        return
    end
    local spell = Config.Spells and Config.Spells[row.spellId]
    local lifeMs = ravenCfg(spell).lifeMs or 60000
    row.stage = "active"
    row.deadline = os.time() + math.ceil(lifeMs / 1000) + 2
    consumeRaven(src, row)
    TriggerClientEvent("hh_magic:raven:active", src, id, lifeMs)
end)

RegisterNetEvent("hh_magic:raven:stop", function(id, reason)
    local src = source
    local row = ravenSessions[src]
    if not row or row.id ~= id then
        return
    end
    clearRaven(src, reason or "end", false)
end)

AddEventHandler("playerDropped", function()
    clearRaven(source, "dropped", false)
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    for src in pairs(ravenSessions) do
        clearRaven(src, "resource_stop", false)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for src, row in pairs(ravenSessions) do
            if not row.closing and row.deadline and now > row.deadline then
                clearRaven(src, "time", true)
            end
        end
    end
end)

local oaths = {}
local oathByTarget = {}
local oathSeq = 0

local function oathRules(spell)
    return (spell and spell.oath) or {}
end

local function pedOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return nil
    end
    return ped
end

local function clearOath(id, reason, text)
    local row = oaths[id]
    if not row or row.closing then
        return
    end
    row.closing = true
    oaths[id] = nil
    if row.target then
        oathByTarget[row.target] = nil
    end
    if pendingCast[row.caster] and pendingCast[row.caster].spellId == row.spellId and not row.consumed then
        pendingCast[row.caster] = nil
    end
    TriggerClientEvent("hh_magic:oath:visualStop", -1, id)
    TriggerClientEvent("hh_magic:oath:end", row.caster, id, false, text or reason)
end

local function consumeOath(row)
    if row.consumed then
        return
    end
    local pending = pendingCast[row.caster]
    local spell = Config.Spells and Config.Spells[row.spellId]
    if not pending or not spell then
        return
    end
    row.consumed = true
    pendingCast[row.caster] = nil
    nextCastAt[row.caster] = nextCastAt[row.caster] or {}
    nextCastAt[row.caster][row.spellId] = os.time() + math.ceil((spell.cooldownMs or 90000) / 1000)
        if spell.consumeItem and pending.huntDbId and GetResourceState("thehunt_items") == "started" then
            exports.thehunt_items:RemoveStackCount(row.caster, pending.huntDbId, 1)
        end
end

RegisterNetEvent("hh_magic:oath:begin", function(spellId, target)
    local src = source
    local pending = pendingCast[src]
    local spell = Config.Spells and Config.Spells[spellId]
    local rules = oathRules(spell)
    target = tonumber(target)
    if not pending or pending.spellId ~= spellId or not spell or not spell.oath or not target or target == src then
        TriggerClientEvent("hh_magic:oath:deny", src, spell and spell.failTarget or "Некого поднять.")
        return
    end
    if oathByTarget[target] then
        TriggerClientEvent("hh_magic:oath:deny", src, "Этот человек уже принимает обет.")
        return
    end
    for _, row in pairs(oaths) do
        if row.caster == src then
            TriggerClientEvent("hh_magic:oath:deny", src, spell.failBusy or "Вы уже творите заклинание.")
            return
        end
    end
    local casterPed = pedOf(src)
    local targetPed = pedOf(target)
    if not casterPed or not targetPed then
        TriggerClientEvent("hh_magic:oath:deny", src, spell.failTarget or "Некого поднять.")
        return
    end
    if #(GetEntityCoords(casterPed) - GetEntityCoords(targetPed)) > (rules.selectRange or 2.5) + 0.6 then
        TriggerClientEvent("hh_magic:oath:deny", src, spell.failRange or "Слишком далеко.")
        return
    end
    local knocked = false
    if GetResourceState("thehunt_death") == "started" then
        knocked = exports.thehunt_death:IsKnocked(target) == true
    end
    local state = Player(target).state
    if not knocked and not (state and (state.isDead or state.thehuntUnconscious)) then
        TriggerClientEvent("hh_magic:oath:deny", src, spell.failTarget or "Его нельзя поднять из нока.")
        return
    end
    oathSeq = oathSeq + 1
    local id = ("oath_%s_%s"):format(src, oathSeq)
    local duration = rules.durationMs or 20000
    oaths[id] = {
        id = id,
        caster = src,
        target = target,
        spellId = spellId,
        stage = "channeling",
        ends = GetGameTimer() + duration,
        closing = false,
        consumed = false,
        paid = false,
    }
    oathByTarget[target] = id
    TriggerClientEvent("hh_magic:oath:visual", -1, {
        id = id,
        caster = src,
        target = target,
        duration = duration,
    })
    TriggerClientEvent("hh_magic:oath:begin", src, {
        id = id,
        target = target,
        transfer = 0,
        after = 0,
        remain = duration,
    })
end)

RegisterNetEvent("hh_magic:oath:cancel", function(id, reason)
    local src = source
    local row = oaths[id]
    if not row or row.caster ~= src or row.stage ~= "channeling" or row.paid then
        return
    end
    local spell = Config.Spells and Config.Spells[row.spellId]
    local text = (spell and spell.failCancel) or "Вы прервали обет."
    if reason == "range" then
        text = (spell and spell.failRange) or text
    elseif reason == "hurt" then
        text = (spell and spell.failHurt) or text
    end
    if spell then
        nextCastAt[src] = nextCastAt[src] or {}
        local lock = math.ceil((oathRules(spell).cancelCooldownMs or 2000) / 1000)
        nextCastAt[src][row.spellId] = math.max(nextCastAt[src][row.spellId] or 0, os.time() + lock)
    end
    clearOath(id, reason or "cancel", text)
end)

RegisterNetEvent("hh_magic:oath:paid", function(id, success, amount)
    local src = source
    local row = oaths[id]
    if not row or row.caster ~= src or row.stage ~= "paying" then
        return
    end
    amount = math.floor(tonumber(amount) or 0)
    if not success or amount < 1 or amount > 2500 then
        local spell = Config.Spells and Config.Spells[row.spellId]
        clearOath(id, "health", (spell and spell.failHealth) or "Недостаточно здоровья для обета.")
        return
    end
    row.paid = true
    row.transfer = amount
    row.stage = "revive_started"
    local woke = false
    if GetResourceState("thehunt_death") == "started" then
        woke = exports.thehunt_death:WakeWithHealth(row.target, row.transfer) == true
    end
    if not woke then
        TriggerClientEvent("hh_magic:oath:refund", src, row.transfer or 0)
        clearOath(id, "revive", "Обет не смог поднять союзника. Кровь возвращена.")
        return
    end
    consumeOath(row)
    local spell = Config.Spells and Config.Spells[row.spellId]
    TriggerClientEvent("hh_magic:oath:end", src, id, true, (spell and spell.notifyRaised) or "Кровь принята. Союзник возвращается.")
    TriggerClientEvent("hh_magic:oath:visualStop", -1, id)
    oaths[id] = nil
    oathByTarget[row.target] = nil
end)

CreateThread(function()
    while true do
        Wait(120)
        local now = GetGameTimer()
        for id, row in pairs(oaths) do
            if row.stage == "channeling" and not row.closing then
                local casterPed = pedOf(row.caster)
                local targetPed = pedOf(row.target)
                local spell = Config.Spells and Config.Spells[row.spellId]
                local rules = oathRules(spell)
                if not casterPed or not targetPed then
                    clearOath(id, "lost", (spell and spell.failHurt) or "Обет прервался.")
                elseif #(GetEntityCoords(casterPed) - GetEntityCoords(targetPed)) > (rules.breakRange or 3.0) + 0.4 then
                    clearOath(id, "range", (spell and spell.failRange) or "Обет прервался: вы отошли слишком далеко.")
                elseif now >= row.ends then
                    row.stage = "paying"
                    local casterMax = 600
                    pcall(function()
                        casterMax = GetEntityMaxHealth(casterPed)
                    end)
                    if not casterMax or casterMax <= 0 then
                        casterMax = 600
                    end
                    local targetMax = 600
                    pcall(function()
                        targetMax = GetEntityMaxHealth(targetPed)
                    end)
                    if not targetMax or targetMax <= 0 then
                        targetMax = casterMax
                    end
                    local floor = rules.aliveFloor or 15
                    local transfer = math.min(math.floor(casterMax * (rules.transferRatio or 0.30)), targetMax)
                    local reserve = math.max(math.ceil(casterMax * (rules.reserveRatio or 0.20)), floor)
                    if transfer < floor then
                        clearOath(id, "blood", (spell and spell.failBlood) or "Недостаточно крови для возвращения.")
                    else
                        row.transfer = transfer
                        row.reserve = reserve
                        TriggerClientEvent("hh_magic:oath:pay", row.caster, id, rules.transferRatio or 0.30, rules.reserveRatio or 0.20, floor)
                    end
                end
            end
        end
    end
end)
