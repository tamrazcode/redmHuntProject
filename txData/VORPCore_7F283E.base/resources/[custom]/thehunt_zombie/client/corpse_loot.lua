-- =================================================================
-- HUNT: Hard RP — Zombie Corpse Loot System (Decoupled Client)
-- Synchronized Server-Authoritative Proximity Looting & Auto-Despawn
-- =================================================================

ZC = ZC or {}
ZC.corpseLoot = ZC.corpseLoot or {}
ZC.necroServants = ZC.necroServants or {}

-- Key: pedHandle -> { id = zombieId, diedAt = GetGameTimer(), emptiedAt = nil }
local trackedCorpses = {}
local activelySearchingCorpses = {}
local allSearchedCorpses = {}

-- Кэш хэшей моделей зомби (поддерживает signed и unsigned)
local ZombieModelHashes = {}
local function CacheZombieModel(name)
    if not name or name == '' then return end
    local h1 = GetHashKey(name)
    local h2 = joaat(name)
    for _, h in ipairs({ h1, h2 }) do
        if h then
            ZombieModelHashes[h] = true
            local n = tonumber(h)
            if n then
                if n < 0 then ZombieModelHashes[n + 4294967296] = true end
                if n > 2147483647 then ZombieModelHashes[n - 4294967296] = true end
            end
        end
    end
end

if ZombieModels then
    for modelName, _ in pairs(ZombieModels) do
        CacheZombieModel(modelName)
    end
end

-- Проверка, мертв ли пед по нативным проверкам RedM
local function IsPedDead(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    if type(GetEntityHealth) == 'function' and GetEntityHealth(ped) <= 0 then return true end
    if type(IsEntityDead) == 'function' and IsEntityDead(ped) then return true end
    return type(IsPedDeadOrDying) == 'function' and IsPedDeadOrDying(ped, true)
end

-- Проверка зомби на мертвое состояние (включая флаги ZC.peds и ZC.debugData)
local function IsZombieCorpse(zombieId, ped)
    if not ped or not DoesEntityExist(ped) then return false end
    if ZC.necroServants[ped] or Entity(ped).state.huntNecroServant then return false end
    -- Живой пед со здоровьем > 0 ни при каких условиях не является трупом
    if not IsPedDead(ped) and type(GetEntityHealth) == 'function' and GetEntityHealth(ped) > 0 then
        return false
    end
    if IsPedDead(ped) then return true end

    local r = ZC.peds and ZC.peds[zombieId]
    if r then
        if r.dead == true or r.state == 'DEAD' then return true end
        if ZC.health then
            local hp = ZC.health(r, ped)
            if hp <= 0 then return true end
        end
    end

    local d = ZC.debugData and ZC.debugData[zombieId]
    if d and (d.state == 'DEAD' or d.dead == true) then return true end

    return false
end

-- Вычисление минимальной дистанции до тела с учетом костей головы и таза (лежачий ragdoll)
local function GetAccurateDistance(myPos, ped)
    if not ped or not DoesEntityExist(ped) then return 999.0 end
    local pos = GetEntityCoords(ped)
    local d = #(myPos - pos)

    local pelvis = GetPedBoneCoords(ped, 14412, 0.0, 0.0, 0.0)
    if pelvis and #(pelvis - vector3(0, 0, 0)) > 1.0 then
        local dp = #(myPos - pelvis)
        if dp < d then d = dp end
    end

    local head = GetPedBoneCoords(ped, 21030, 0.0, 0.0, 0.0)
    if head and #(head - vector3(0, 0, 0)) > 1.0 then
        local dh = #(myPos - head)
        if dh < d then d = dh end
    end

    return d
end

-- Поиск педа зомби по ID или локальной записи
local function ResolveCorpsePed(zombieId, r)
    if r then
        if r.corpsePed and DoesEntityExist(r.corpsePed) then return r.corpsePed end
        if r.ped and DoesEntityExist(r.ped) then
            r.corpsePed = r.ped
            return r.ped
        end
        local ent = ZC.entity and ZC.entity(r)
        if ent and DoesEntityExist(ent) then
            r.corpsePed = ent
            return ent
        end
    end

    if ZC.localPeds and ZC.localPeds[zombieId] and DoesEntityExist(ZC.localPeds[zombieId]) then
        return ZC.localPeds[zombieId]
    end

    for pedHandle, data in pairs(trackedCorpses) do
        if data.id == zombieId and DoesEntityExist(pedHandle) then
            return pedHandle
        end
    end

    return nil
end

-- Определение, является ли пед зомби (через state bag, локальные таблицы, модель)
local function IdentifyZombiePed(ped)
    if not ped or not DoesEntityExist(ped) then return false, nil end

    -- 1. State bag huntZombie
    local tag = nil
    pcall(function() tag = Entity(ped).state.huntZombie end)
    if type(tag) == 'table' and tag.id then
        return true, tag.id
    end

    -- 2. Локальные таблицы ZC.peds / ZC.localPeds
    if ZC.peds then
        for id, r in pairs(ZC.peds) do
            if r.ped == ped or r.corpsePed == ped then
                return true, id
            end
        end
    end
    if ZC.localPeds then
        for id, lPed in pairs(ZC.localPeds) do
            if lPed == ped then
                return true, id
            end
        end
    end

    -- 3. Хэш модели зомби
    local model = GetEntityModel(ped)
    if ZombieModelHashes[model] then
        if ZC.peds then
            local pedCoords = GetEntityCoords(ped)
            for id, r in pairs(ZC.peds) do
                local rPos = r.position or r.home
                if rPos and #(pedCoords - vector3(rPos.x, rPos.y, rPos.z)) <= 4.0 then
                    return true, id
                end
            end
        end
        return true, nil
    end

    return false, nil
end

-- Гарантированное удаление педа трупа из игрового мира
local function ForceDeleteCorpse(ped)
    if not ped or not DoesEntityExist(ped) then return end
    if ZC.necroServants[ped] or Entity(ped).state.huntNecroServant then return end
    -- Защита: ни в коем случае не удаляем живого педа
    if not IsPedDead(ped) and type(GetEntityHealth) == 'function' and GetEntityHealth(ped) > 0 then
        return
    end
    pcall(function()
        Entity(ped).state:set('isProtected', false, false)
        SetEntityAsMissionEntity(ped, false, true)
        SetPedKeepTask(ped, false)
        SetEntityAsNoLongerNeeded(ped)
        ClearPedTasksImmediately(ped)
        DeleteEntity(ped)
    end)
    if DoesEntityExist(ped) then
        pcall(function()
            NetworkRequestControlOfEntity(ped)
            DeletePed(ped)
            DeleteEntity(ped)
        end)
    end
end

-- Запрос лута у сервера, если он еще не сформирован локально
local function EnsureCorpseRecord(zombieId, r, ped)
    local existing = ZC.corpseLoot[zombieId]
    if existing and existing.items and #existing.items > 0 then
        return existing
    end

    local pos = (ped and DoesEntityExist(ped) and GetEntityCoords(ped)) or (r and (r.position or r.home)) or vector3(0, 0, 0)
    local fallback = existing or {
        id = zombieId,
        zone = r and r.zone,
        pos = pos,
        cols = 7,
        rows = 3,
        items = {},
        localFallback = true
    }
    ZC.corpseLoot[zombieId] = fallback

    -- Авторитетный запрос лута с сервера
    TriggerServerEvent('thehunt_zombie:ensureCorpseLoot', zombieId, pos, r and r.zone)
    return fallback
end

-- =================================================================
-- СЕТЕВЫЕ СОБЫТИЯ СИНХРОНИЗАЦИИ ЛУТА С СЕРВЕРА
-- =================================================================

-- Сервер прислал создание лута трупа
RegisterNetEvent('thehunt_zombie:corpseLootCreated', function(data)
    if not data or not data.id then return end
    ZC.corpseLoot[data.id] = data
    if data.allSearched then
        allSearchedCorpses[data.id] = true
        for ped, cdata in pairs(trackedCorpses) do
            if cdata.id == data.id then
                cdata.allSearched = true
                break
            end
        end
    end
    TriggerEvent('thehunt_inventory:refreshNearbyDrops')
end)

-- Предмет взят из трупа любым игроком (полная синхронизация)
RegisterNetEvent('thehunt_zombie:corpseLootItemRemoved', function(zombieId, slotId)
    local loot = ZC.corpseLoot[zombieId]
    if not loot or not loot.items then return end
    local targetSlot = tonumber(slotId)
    for idx, it in ipairs(loot.items) do
        if it.slotId == targetSlot then
            table.remove(loot.items, idx)
            break
        end
    end

    if #loot.items == 0 then
        for ped, data in pairs(trackedCorpses) do
            if data.id == zombieId then
                data.emptiedAt = GetGameTimer()
                break
            end
        end
    end

    TriggerEvent('thehunt_inventory:refreshNearbyDrops')
end)

-- Лут трупа удален (таймер / деспавн)
RegisterNetEvent('thehunt_zombie:corpseLootRemoved', function(id)
    if not id then return end
    ZC.corpseLoot[id] = nil
    for ped, data in pairs(trackedCorpses) do
        if data.id == id then
            ForceDeleteCorpse(ped)
            trackedCorpses[ped] = nil
            break
        end
    end
    TriggerEvent('thehunt_inventory:refreshNearbyDrops')
end)

-- Состояние активного обыска и полного распознавания
local function SetCorpseSearchingInternal(zombieId, isSearching)
    if not zombieId then return end
    activelySearchingCorpses[zombieId] = isSearching and true or nil
    for ped, data in pairs(trackedCorpses) do
        if data.id == zombieId then
            data.isSearching = isSearching and true or nil
            if isSearching then
                data.diedAt = GetGameTimer()
            end
            break
        end
    end
end

RegisterNetEvent('thehunt_zombie:setSearchingCorpse', SetCorpseSearchingInternal)
AddEventHandler('thehunt_zombie:setSearchingCorpse', SetCorpseSearchingInternal)

local function SetCorpseAllSearchedInternal(zombieId)
    if not zombieId then return end
    allSearchedCorpses[zombieId] = true
    for ped, data in pairs(trackedCorpses) do
        if data.id == zombieId then
            data.allSearched = true
            break
        end
    end
end

RegisterNetEvent('thehunt_zombie:onCorpseAllSearched', SetCorpseAllSearchedInternal)
AddEventHandler('thehunt_zombie:onCorpseAllSearched', SetCorpseAllSearchedInternal)

-- Полный синк всей карты трупов
RegisterNetEvent('thehunt_zombie:syncCorpseLoot', function(map)
    ZC.corpseLoot = map or {}
    for id, loot in pairs(ZC.corpseLoot) do
        if loot and loot.allSearched then
            allSearchedCorpses[id] = true
            for ped, cdata in pairs(trackedCorpses) do
                if cdata.id == id then
                    cdata.allSearched = true
                    break
                end
            end
        end
    end
    TriggerEvent('thehunt_inventory:refreshNearbyDrops')
end)

-- Синхронизация раскрытия предмета от сервера (общее распознавание для всех)
RegisterNetEvent('thehunt_zombie:corpseItemSearched', function(zombieId, slotId)
    if not zombieId or not slotId then return end
    local loot = ZC.corpseLoot[zombieId]
    if loot and loot.items then
        for _, it in ipairs(loot.items) do
            if it.slotId == tonumber(slotId) then
                it.isSearched = true
                break
            end
        end
    end
    TriggerEvent('thehunt_inventory:zombieItemSearched', zombieId, tonumber(slotId))
    TriggerEvent('thehunt_inventory:refreshNearbyDrops')
end)

-- Первичный запрос карты лута трупов при запуске клиента
CreateThread(function()
    Wait(1500)
    TriggerServerEvent('thehunt_zombie:requestCorpseLoot')
end)

-- =================================================================
-- ПОТОК ОТСЛЕЖИВАНИЯ ТРУПОВ И АВТО-ДЕСПАВНА
-- =================================================================
CreateThread(function()
    while true do
        Wait(400)
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            local myPos = GetEntityCoords(myPed)
            local now = GetGameTimer()
            local lifetime = (ZombieConfig and ZombieConfig.CorpseLifetime) or 90000

            -- 1. Сканируем активный пул педов в радиусе 16м
            if type(GetGamePool) == 'function' then
                local peds = GetGamePool('CPed')
                for _, ped in ipairs(peds) do
                    if ped ~= myPed and DoesEntityExist(ped) and IsPedDead(ped) and not ZC.necroServants[ped] and not Entity(ped).state.huntNecroServant then
                        local d = #(myPos - GetEntityCoords(ped))
                        if d <= 16.0 then
                            local isZ, zId = IdentifyZombiePed(ped)
                            if isZ then
                                zId = zId or ('corpse_' .. tostring(ped))
                                if not trackedCorpses[ped] then
                                    pcall(function()
                                        SetEntityAsMissionEntity(ped, true, true)
                                        SetPedKeepTask(ped, true)
                                    end)
                                    trackedCorpses[ped] = { id = zId, diedAt = now, ped = ped }
                                end
                                EnsureCorpseRecord(zId, ZC.peds and ZC.peds[zId], ped)
                            end
                        end
                    end
                end
            end

            -- 2. Сканируем записи ZC.peds
            if ZC.peds then
                for id, r in pairs(ZC.peds) do
                    local ped = ResolveCorpsePed(id, r)
                    if ped and DoesEntityExist(ped) and IsZombieCorpse(id, ped) then
                        local d = #(myPos - GetEntityCoords(ped))
                        if d <= 16.0 then
                            if not trackedCorpses[ped] then
                                pcall(function()
                                    SetEntityAsMissionEntity(ped, true, true)
                                    SetPedKeepTask(ped, true)
                                end)
                                trackedCorpses[ped] = { id = id, diedAt = now, ped = ped }
                            end
                            EnsureCorpseRecord(id, r, ped)
                        end
                    end
                end
            end

            -- 3. Авто-деспавн трупов
            for ped, data in pairs(trackedCorpses) do
                if not DoesEntityExist(ped) then
                    trackedCorpses[ped] = nil
                elseif ZC.necroServants[ped] or Entity(ped).state.huntNecroServant or (not IsPedDead(ped) and type(GetEntityHealth) == 'function' and GetEntityHealth(ped) > 0) then
                    -- Поднят некромантом или ещё жив — не деспавнить
                    trackedCorpses[ped] = nil
                else
                    local pedPos = GetEntityCoords(ped)
                    local isExtremeFar = #(myPos - pedPos) > 120.0 and (now - data.diedAt >= 60000)

                    -- 1. Пока кто-то именно раскрывает (опознаёт) предметы — труп зомби НЕ ПРОПАДАЕТ!
                    local isCurrentlySearching = data.isSearching or activelySearchingCorpses[data.id]
                    if isCurrentlySearching then
                        data.diedAt = now -- удерживаем труп от деспавна
                    else
                        local loot = ZC.corpseLoot[data.id]
                        local isEmpty = (not loot or not loot.items or #loot.items == 0)
                        local isAllSearched = (data.allSearched == true or allSearchedCorpses[data.id] == true)

                        -- 2. Если ВСЕ предметы распознаны И в зомби НЕТ лута внутри — запускаем таймер 30 секунд
                        local isEmptyExpired = false
                        if isAllSearched and isEmpty then
                            if not data.emptiedAt then
                                data.emptiedAt = now
                            end
                            isEmptyExpired = (now - data.emptiedAt >= 30000)
                        end

                        -- 3. Если зомби ещё не распознавали, или не распознали до конца, или забрали часть и ушли — лежит 90 секунд
                        local isExpired = (now - data.diedAt >= lifetime)

                        if isEmptyExpired or isExpired or isExtremeFar then
                            ForceDeleteCorpse(ped)
                            trackedCorpses[ped] = nil
                            if isEmptyExpired or isExpired then
                                ZC.corpseLoot[data.id] = nil
                                TriggerServerEvent('thehunt_zombie:corpseExpired', data.id)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- ГЛАВНЫЙ API EXPORT ДЛЯ ЛЮБОГО ИНВЕНТАРЯ / СТОРОННИХ СКРИПТОВ
-- =================================================================

--- Возвращает все трупы зомби рядом с игроком с их лутом и расстоянием
---@param maxDist number|nil Максимальный радиус поиска (по умолчанию 3.5м)
---@return table Список трупов [{ zombieId, label, distance, cols, rows, items }, ...]
function GetNearbyZombieCorpses(maxDist)
    local myPed = PlayerPedId()
    if not DoesEntityExist(myPed) then return {} end
    local myPos = GetEntityCoords(myPed)
    local distLimit = maxDist or 3.5
    local nearby = {}
    local seen = {}

    -- 1. Сканируем ZC.peds
    if ZC.peds then
        for id, r in pairs(ZC.peds) do
            local ped = ResolveCorpsePed(id, r)
            if ped and DoesEntityExist(ped) and IsZombieCorpse(id, ped) then
                local d = GetAccurateDistance(myPos, ped)
                if d <= distLimit and not seen[id] then
                    seen[id] = true
                    local loot = EnsureCorpseRecord(id, r, ped)
                    local items = (loot and loot.items) or {}
                    local label = (r.settings and r.settings.name) or 'Труп зомби'
                    nearby[#nearby + 1] = {
                        zombieId = id,
                        label = label,
                        distance = d,
                        cols = (loot and loot.cols) or 7,
                        rows = (loot and loot.rows) or 3,
                        items = items
                    }
                end
            end
        end
    end

    -- 2. Сканируем локально отслеженные трупы (trackedCorpses)
    for ped, data in pairs(trackedCorpses) do
        if ped and DoesEntityExist(ped) and IsZombieCorpse(data.id, ped) then
            local id = data.id
            if not seen[id] then
                local d = GetAccurateDistance(myPos, ped)
                if d <= distLimit then
                    seen[id] = true
                    local r = ZC.peds and ZC.peds[id]
                    local loot = EnsureCorpseRecord(id, r, ped)
                    nearby[#nearby + 1] = {
                        zombieId = id,
                        label = (r and r.settings and r.settings.name) or 'Труп зомби',
                        distance = d,
                        cols = (loot and loot.cols) or 7,
                        rows = (loot and loot.rows) or 3,
                        items = (loot and loot.items) or {}
                    }
                end
            end
        end
    end

    -- ИСКЛЮЧЕНО: Сканирование "без педа". Если трупа нет в мире, инвентарь не показывается!

    -- Сортировка по возрастанию дистанции (ближайший труп первый)
    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    return nearby
end

-- Экспорт для внешних ресурсов (thehunt_inventory и др.)
exports('GetNearbyZombieCorpses', GetNearbyZombieCorpses)

-- Локальное событие для прямого опроса без зависимости от таблицы экспортов
AddEventHandler('thehunt_zombie:getNearbyZombieCorpses', function(cb, maxDist)
    if type(cb) == 'function' then
        cb(GetNearbyZombieCorpses(maxDist))
    end
end)

-- Экспорт для точечного запроса конкретного трупа по ID
function GetZombieCorpseById(targetId)
    if not targetId then return nil end
    local loot = ZC.corpseLoot[targetId]
    local r = ZC.peds and ZC.peds[targetId]
    local ped = (r and ResolveCorpsePed(targetId, r))
    if not ped then
        for pHandle, data in pairs(trackedCorpses) do
            if data.id == targetId then
                ped = pHandle
                break
            end
        end
    end

    local myPed = PlayerPedId()
    local myPos = DoesEntityExist(myPed) and GetEntityCoords(myPed)
    local pos = (ped and DoesEntityExist(ped) and GetEntityCoords(ped)) or (loot and loot.pos) or myPos
    local d = (myPos and pos) and #(myPos - pos) or 0.0

    return {
        zombieId = targetId,
        label = (r and r.settings and r.settings.name) or 'Труп зомби',
        distance = d,
        cols = (loot and loot.cols) or 7,
        rows = (loot and loot.rows) or 3,
        items = (loot and loot.items) or {}
    }
end

function ZC.untrackCorpse(ped)
    if ped then trackedCorpses[ped] = nil end
end

function ZC.markNecroServant(ped)
    if not ped then return end
    ZC.necroServants[ped] = true
    trackedCorpses[ped] = nil
end

exports('GetZombieCorpseById', GetZombieCorpseById)
