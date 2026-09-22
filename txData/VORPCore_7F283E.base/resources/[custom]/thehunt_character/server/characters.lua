-- =================================================================
-- HUNT: Hard RP — Character Management & Lifecycle Handlers
-- =================================================================

Characters = {}
local creatingCharacters = {}
local selectingCharacters = {}
local loadingCharacters = {}

local function SyncAppearanceComponents(skin, comps)
    for _, category in ipairs({ "Hair", "Beard", "Teeth" }) do
        if comps[category] == nil and skin[category] ~= nil then comps[category] = skin[category] end
    end
end

local function GetIdentifier(src)
    return GetPlayerIdentifierByType(src, 'steam') or GetPlayerIdentifierByType(src, 'license')
end

local function BuildCoordsJson(coords)
    local x, y, z = tonumber(coords and coords.x), tonumber(coords and coords.y), tonumber(coords and coords.z)
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end -- reject NaN
    return json.encode({
        x = x,
        y = y,
        z = z,
        heading = tonumber(coords.heading or coords.h) or 0.0
    })
end

-- VORP writes the in-memory character object back to `characters` on its own
-- save/drop lifecycle. Keeping this value in sync prevents that later save
-- from restoring an older coords JSON over our newest position.
local function SyncVorpCharacterCoords(src, coordsJson)
    exports.thehunt_core:SyncCharacterCoords(src, coordsJson)
end

local function IsCreatorRoomCoords(coords)
    if not coords or not Config.CreatorRoom or not Config.CreatorRoom.coords then return false end
    local room = Config.CreatorRoom.coords
    local dx = (tonumber(coords.x) or 0.0) - room.x
    local dy = (tonumber(coords.y) or 0.0) - room.y
    local dz = (tonumber(coords.z) or 0.0) - room.z
    return (dx * dx + dy * dy + dz * dz) < (180.0 * 180.0)
end

local function IsFiniteInRange(value, minimum, maximum)
    value = tonumber(value)
    return value and value == value and value >= minimum and value <= maximum
end

local function NormalizeWorldState(state)
    if type(state) ~= "table" then return nil end
    local health, healthCore = tonumber(state.health), tonumber(state.healthCore)
    local stamina, staminaCore = tonumber(state.stamina), tonumber(state.staminaCore)
    local sprintStamina = tonumber(state.sprintStamina)
    if not IsFiniteInRange(health, 0, 1000) or not IsFiniteInRange(healthCore, 0, 100)
        or not IsFiniteInRange(stamina, 0, 1000) or not IsFiniteInRange(staminaCore, 0, 100)
        or not IsFiniteInRange(sprintStamina, 0, 100) then
        return nil
    end
    return {
        health = math.floor(health + 0.5), healthCore = math.floor(healthCore + 0.5),
        stamina = math.floor(stamina + 0.5), staminaCore = math.floor(staminaCore + 0.5),
        sprintStamina = math.floor(sprintStamina + 0.5)
    }
end

--- Request player's character list from DB and send to NUI
--- @param src number
function Characters.RequestUserCharacters(src)
    -- VORP can notify the compatibility boundary more than once while its
    -- asynchronous user cache is settling. Do not run two identical list
    -- loads for the same source.
    if loadingCharacters[src] then return end
    loadingCharacters[src] = true
    local function finishCharacterListLoad()
        loadingCharacters[src] = nil
    end

    if not exports.thehunt_core:EnsureSession(src, 5000) then
        finishCharacterListLoad()
        print("[thehunt_character] HUNT session is not ready while loading characters for src " .. tostring(src))
        TriggerClientEvent('thehunt_core:client:sessionDiagnostics', src)
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Сессия VORP ещё не готова. Повторите попытку.")
        return
    end

    local identifier = GetPlayerIdentifierByType(src, 'steam')
    if not identifier then
        identifier = GetPlayerIdentifierByType(src, 'license')
    end
    if not identifier then
        finishCharacterListLoad()
        print("[thehunt_character] No identifier found for player " .. tostring(src))
        return
    end

    local charactersList = Database.GetPlayerCharacters(identifier)
    local isAdmin = Admin.IsAdmin(src)
    local maxSlots = isAdmin and -1 or (Config.CharacterSlots.default or 3)

    -- Put player in private routing bucket dimension during selection/creation
    Player(src).state:set('PlayerIsInCharacterShops', true, true)
    pcall(function()
        SetPlayerRoutingBucket(src, 1000 + src)
    end)

    -- Auto open creator if user has 0 characters
    if #charactersList == 0 then
        finishCharacterListLoad()
        TriggerClientEvent(Constants.Events.OPEN_CREATOR, src, { isFirstCharacter = true })
        return
    end

    -- Format character records for selection UI
    local formatted = {}
    for _, char in ipairs(charactersList) do
        local skinDecoded = Utils.SafeJsonDecode(char.skinPlayer, {})
        local compsDecoded = Utils.SafeJsonDecode(char.compPlayer, {})
        local compTintsDecoded = Utils.SafeJsonDecode(char.compTints, {})
        local coordsDecoded = Utils.SafeJsonDecode(char.coords, {})
        skinDecoded, char.gender = Utils.NormalizeSkin(skinDecoded, char.gender)
        SyncAppearanceComponents(skinDecoded, compsDecoded)

        -- If unique_code is missing for an unmigrated character, issue one immediately
        local code = char.unique_code
        if not code or code == "" then
            code = CodeGenerator.GenerateAndReserve(char.charidentifier, identifier)
        end

        table.insert(formatted, {
            charIdentifier = char.charidentifier,
            code = code or "00000",
            firstname = char.firstname or "Неизвестный",
            lastname = char.lastname or "Странник",
            gender = char.gender or "Male",
            nation = char.nation or "Американец",
            age = char.age or 25,
            birthdate = char.birthdate or "",
            nickname = char.nickname or "",
            job = char.joblabel or char.job or "Безработный",
            group = char.group or "user",
            money = char.money or 0,
            gold = char.gold or 0,
            coords = coordsDecoded,
            isDead = (char.isdead == 1 or char.isdead == true),
            skin = skinDecoded,
            comps = compsDecoded,
            compTints = compTintsDecoded
        })
    end

    -- Selection is a single deliberately authored scene, not a random backdrop.
    local sceneData = Config.SelectionScenes[1]

    finishCharacterListLoad()
    TriggerClientEvent(Constants.Events.RECEIVE_CHARACTERS, src, {
        characters = formatted,
        maxSlots = maxSlots,
        isAdmin = isAdmin,
        scene = sceneData
    })
end

--- Select a character, load into VORP Core, and spawn in world
--- @param src number
--- @param charIdentifier number
function Characters.SelectCharacter(src, charIdentifier)
    local identifier = GetPlayerIdentifierByType(src, 'steam')
    if not identifier then
        identifier = GetPlayerIdentifierByType(src, 'license')
    end

    if not identifier then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Не удалось определить идентификатор игрока.")
        return
    end

    local validSelection, selectionError = Validation.ValidateCharacterSelection(src, charIdentifier)
    if not validSelection then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, selectionError)
        return
    end

    if not Database.VerifyCharacterOwnership(charIdentifier, identifier) then
        print(string.format("[thehunt_character] [EXPLOIT ATTEMPT] Player %s tried to select unowned char %s", src, charIdentifier))
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Ошибка доступа к персонажу.")
        return
    end

    if selectingCharacters[src] then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Выбор персонажа уже выполняется.")
        return
    end
    selectingCharacters[src] = true

    local function failSelection(message)
        selectingCharacters[src] = nil
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, message)
    end

    if not exports.thehunt_core:EnsureSession(src, 5000) then
        print("[thehunt_character] HUNT session is not ready for src " .. tostring(src))
        TriggerClientEvent('thehunt_core:client:sessionDiagnostics', src)
        failSelection("Сессия VORP ещё не готова. Повторите попытку.")
        return
    end

    local currentCharId = exports.thehunt_core:GetCharacterId(src)

    -- VORP exposes getUsedCharacter as a snapshot value. Avoid calling
    -- setUsedCharacter twice for the same id, then fetch a fresh snapshot.
    if currentCharId ~= charIdentifier then
        local activated, activationError = exports.thehunt_core:SelectCharacter(src, charIdentifier)
        if not activated then
            print(string.format("[thehunt_character] Character activation rejected for %s: %s", tostring(charIdentifier), tostring(activationError)))
            failSelection("Не удалось активировать выбранного персонажа.")
            return
        end
        Wait(0)
    end
    local activeCharId = exports.thehunt_core:GetCharacterId(src)
    if activeCharId ~= charIdentifier then
        print("[thehunt_character] Failed to activate character through HUNT session for " .. tostring(charIdentifier))
        failSelection("Не удалось активировать выбранного персонажа.")
        return
    end

    -- Parse spawn coordinates
    local spawnCoords = Config.DefaultSpawn
    local spawnHeading = 0.0
    local isDead = false

    local charData = Database.GetCharacterById(charIdentifier)
    local skinDecoded = {}
    local compsDecoded = {}
    local compTintsDecoded = {}

    if charData then
        skinDecoded = Utils.SafeJsonDecode(charData.skinPlayer, {})
        compsDecoded = Utils.SafeJsonDecode(charData.compPlayer, {})
        compTintsDecoded = Utils.SafeJsonDecode(charData.compTints, {})
        skinDecoded, charData.gender = Utils.NormalizeSkin(skinDecoded, charData.gender)
        SyncAppearanceComponents(skinDecoded, compsDecoded)

        if charData.coords and charData.coords ~= "" and charData.coords ~= "{}" then
            local rawCoords = Utils.SafeJsonDecode(charData.coords, nil)
            if rawCoords and rawCoords.x and rawCoords.y and rawCoords.z and not IsCreatorRoomCoords(rawCoords) then
                spawnCoords = vector3(tonumber(rawCoords.x), tonumber(rawCoords.y), tonumber(rawCoords.z))
                spawnHeading = tonumber(rawCoords.heading or rawCoords.h or 0.0)
            end
        end

        if charData.isdead ~= nil then
            isDead = (charData.isdead == true or charData.isdead == 1 or charData.isdead == "1")
        end

        -- VORP's compact Character state has no nation field; keep it in a
        -- replicated state bag for the online admin roster.
        Player(src).state:set('thehuntNationality', charData.nation or 'Американец', true)
        local charScale = tonumber(skinDecoded.Scale or skinDecoded.scale) or 1.0
        Player(src).state:set('thehuntScale', charScale, true)
    end

    local payloadData = {
        charIdentifier = charIdentifier,
        gender = (charData and charData.gender) or "Male",
        skin = skinDecoded,
        comps = compsDecoded,
        compTints = compTintsDecoded,
        coords = spawnCoords,
        heading = spawnHeading,
        isDead = isDead
    }
    payloadData.worldState = Database.GetWorldState(charIdentifier)

    -- Trigger client character spawn, appearance and clothing setup
    selectingCharacters[src] = nil
    TriggerClientEvent("thehunt_character:client:ApplyAndSpawn", src, payloadData)
end

--- Create a new character with server validation and atomic code reservation
--- @param src number
--- @param payload table
function Characters.CreateCharacter(src, payload)
    local identifier = GetIdentifier(src)
    if not identifier then
        TriggerClientEvent(Constants.Events.CREATION_FAILED, src, "Не удалось определить идентификатор игрока.")
        return
    end

    if creatingCharacters[src] then
        TriggerClientEvent(Constants.Events.CREATION_FAILED, src, "Создание персонажа уже выполняется.")
        return
    end
    creatingCharacters[src] = true

    local function fail(message)
        creatingCharacters[src] = nil
        TriggerClientEvent(Constants.Events.CREATION_FAILED, src, message)
    end

    -- 1. Validate payload
    local isValid, errMessage = Validation.ValidateCharacterCreation(src, payload)
    if not isValid then
        fail(errMessage)
        return
    end

    -- 2. Validate slot limits
    local currentChars = Database.GetPlayerCharacters(identifier)
    if not Validation.CanCreateMoreCharacters(src, #currentChars) then
        fail("Достигнут лимит персонажей.")
        return
    end

    -- 3. Prepare default VORP character dataset
    if not exports.thehunt_core:EnsureSession(src, 5000) then
        fail("Ошибка сессии сервера.")
        return
    end

    local activeSessionCharacter = exports.thehunt_core:GetCharacter(src)

    local submittedSkin = Utils.SafeJsonDecode(payload.skin, {})
    local submittedComps = Utils.SafeJsonDecode(payload.comps, {})
    local submittedTints = Utils.SafeJsonDecode(payload.compTints, {})
    local appearanceValid, skin, comps, compTints, canonicalGender = Validation.SanitizeAppearance(
        submittedSkin, submittedComps, submittedTints, payload.gender, payload.__legacyVorp ~= true
    )
    if not appearanceValid then
        fail(skin)
        return
    end
    payload.gender = canonicalGender
    payload.skin, payload.comps, payload.compTints = skin, comps, compTints
    if comps.Hair ~= nil then skin.Hair = type(comps.Hair) == "table" and comps.Hair.comp or comps.Hair end
    if comps.Beard ~= nil then skin.Beard = type(comps.Beard) == "table" and comps.Beard.comp or comps.Beard end
    if comps.Teeth ~= nil then skin.Teeth = type(comps.Teeth) == "table" and comps.Teeth.comp or comps.Teeth end
    skin = Utils.NormalizeSkin(skin, canonicalGender)
    payload.skin = skin
    local skinJson = json.encode(skin)
    local compsJson = json.encode(comps)
    local compTintsJson = json.encode(compTints)

    local selectedSpawn = Config.DefaultSpawn

    local coordsJson = json.encode({
        x = selectedSpawn.x,
        y = selectedSpawn.y,
        z = selectedSpawn.z,
        heading = selectedSpawn.w or 0.0
    })

    local newCharData = {
        firstname = Utils.SanitizeString(payload.firstname),
        lastname = Utils.SanitizeString(payload.lastname),
        gender = canonicalGender,
        age = tonumber(payload.age) or 25,
        nickname = Utils.SanitizeString(payload.nickname or ""),
        charDescription = Utils.SanitizeString(payload.description or ""),
        skin = skinJson,
        comps = compsJson,
        compTints = compTintsJson
    }

    -- 4. Insert into VORP Core. Keep the previous id so an existing
    -- character can never be mistaken for the newly created one.
    local previousChar = activeSessionCharacter
    local previousCharId = previousChar and tonumber(previousChar.charIdentifier) or nil
    local existingCharacterIds = {}
    for _, existing in ipairs(currentChars) do
        existingCharacterIds[tonumber(existing.charidentifier)] = true
    end
    local created, createError = exports.thehunt_core:CreateCharacter(src, newCharData)
    if not created then
        print(string.format("[thehunt_character] Character creation rejected for src %s: %s", tostring(src), tostring(createError or "unknown")))
        fail("Не удалось создать персонажа: " .. tostring(createError or "unknown"))
        return
    end

    CreateThread(function()
        local activeChar = nil
        local newDatabaseId = nil
        local deadline = GetGameTimer() + Constants.CharacterCreateTimeout
        repeat
            -- getUser() must be called again: getUsedCharacter on the old
            -- proxy is immutable and was the reason every creation timed out.
            activeChar = exports.thehunt_core:GetCharacter(src)
            local activeId = activeChar and tonumber(activeChar.charIdentifier) or nil

            local latestCharacters = Database.GetPlayerCharacters(identifier)
            for _, row in ipairs(latestCharacters) do
                local rowId = tonumber(row.charidentifier)
                if rowId and not existingCharacterIds[rowId] then
                    newDatabaseId = rowId
                    break
                end
            end

            if activeId and activeId ~= previousCharId and newDatabaseId == activeId then break end
            -- addCharacter завершает INSERT асинхронно; частый опрос только
            -- создаёт лишнюю очередь запросов при высокой нагрузке.
            Wait(150)
        until GetGameTimer() >= deadline

        if activeChar and tonumber(activeChar.charIdentifier) ~= previousCharId and newDatabaseId == tonumber(activeChar.charIdentifier) then
            local charId = tonumber(activeChar.charIdentifier)
            local code = CodeGenerator.GenerateAndReserve(charId, identifier)

            -- Persist the validated creator snapshot explicitly.  This makes
            -- BuildIndex durable for every newly created character, including
            -- the implicit Standard build (index 1), independently of the
            -- appearance-field aliases used by the installed VORP version.
            if not Database.UpdateAppearance(charId, identifier, skinJson, compsJson, compTintsJson) then
                fail("Не удалось сохранить внешность персонажа.")
                return
            end
            -- Keep the framework cache on the same snapshot through the
            -- HUNT facade, preventing a later autosave from restoring an
            -- older default skin.
            exports.thehunt_core:UpdateCharacterAppearance(src, skinJson, compsJson, compTintsJson)

            -- Update character initial spawn coordinates and nation
            SyncVorpCharacterCoords(src, coordsJson)
            Database.UpdateLastCoords(charId, identifier, coordsJson)
            Player(src).state:set('thehuntNationality', payload.nation or 'Американец', true)
            local charScale = tonumber(skin.Scale or skin.scale) or 1.0
            Player(src).state:set('thehuntScale', charScale, true)
            local d, m, y = tostring(payload.birthdate or ""):match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
            local birthdateSql = d and string.format("%s-%s-%s", y, m, d) or nil
            Database.UpdateCharacterMetadata(charId, identifier, payload.nation or 'Американец', birthdateSql)

            -- Persist creator garments as normal, equipped inventory items.
            -- This runs only after VORP has supplied the final character id.
            if exports['thehunt_items'] and exports['thehunt_items'].CreateCharacterClothing then
                local variantLabels = {}
                local wardrobe = canonicalGender == "Female" and ClothingData.Female or ClothingData.Male
                for category, value in pairs(comps) do
                    local hash = type(value) == "table" and (value.comp or value.hash) or value
                    for index, option in ipairs((wardrobe and wardrobe[category]) or {}) do
                        if tonumber(option.hash) == tonumber(hash) then
                            variantLabels[category] = option.name or ("Вариант " .. tostring(index))
                            break
                        end
                    end
                end
                exports['thehunt_items']:CreateCharacterClothing(src, comps, compTints, variantLabels)
            end

            local newPayloadData = {
                charIdentifier = charId,
                gender = canonicalGender,
                skin = skin,
                comps = comps,
                compTints = compTints,
                coords = vector3(selectedSpawn.x, selectedSpawn.y, selectedSpawn.z),
                heading = selectedSpawn.w or 0.0,
                isDead = false
            }

            TriggerClientEvent("thehunt_character:client:ApplyAndSpawn", src, newPayloadData)
            creatingCharacters[src] = nil
        else
            print(string.format("[thehunt_character] Character creation timeout src=%s previous=%s dbNew=%s active=%s",
                tostring(src), tostring(previousCharId), tostring(newDatabaseId),
                tostring(activeChar and activeChar.charIdentifier)))
            fail("Не удалось завершить создание персонажа.")
        end
    end)
end

--- Delete a character safely with name confirmation
--- @param src number
--- @param charIdentifier number
--- @param confirmationName string
function Characters.DeleteCharacter(src, charIdentifier, confirmationName)
    local identifier = GetPlayerIdentifierByType(src, 'steam')
    if not identifier then
        identifier = GetPlayerIdentifierByType(src, 'license')
    end

    if not identifier then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Не удалось определить идентификатор игрока.")
        return
    end

    if not Database.VerifyCharacterOwnership(charIdentifier, identifier) then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Ошибка прав на удаление персонажа.")
        return
    end

    local charData = Database.GetCharacterById(charIdentifier)

    if not charData then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Персонаж не найден.")
        return
    end

    -- Use the same case/whitespace normalization as the selection UI. This
    -- fixes Cyrillic case-insensitive checks (Lua string.lower is ASCII-only)
    -- without changing how names are formatted or stored during creation.
    local expectedName = Utils.NormalizeCharacterName(
        tostring(charData.firstname or "") .. " " .. tostring(charData.lastname or "")
    )
    local providedName = Utils.NormalizeCharacterName(confirmationName)

    if expectedName == "" or providedName == "" or expectedName ~= providedName then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Имя подтверждения не совпадает.")
        return
    end

    -- Soft delete in DB & Retire 5-digit code forever
    if not Database.DeleteCharacter(charIdentifier, identifier, GetPlayerName(src), "Deleted by player with name verification") then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Не удалось безопасно удалить персонажа.")
        return
    end

    TriggerClientEvent(Constants.Events.NOTIFY_SUCCESS, src, "Персонаж успешно удален.")
    
    -- Refresh character list for selection menu
    Characters.RequestUserCharacters(src)
end

--- Save current player coordinates
--- @param src number
--- @param coords table
function Characters.SaveLastPosition(src, coords)
    -- Character selection and the creator use a private bucket.  Saving there
    -- would permanently turn the studio into the character's last spawn.
    if GetPlayerRoutingBucket(src) ~= 0 then return end

    local char = exports.thehunt_core:GetCharacter(src)
    if not char then return end

    local charId = tonumber(char.charIdentifier)
    local identifier = GetIdentifier(src)
    local coordsJson = BuildCoordsJson(coords)
    if not charId or charId <= 0 or not identifier or not coordsJson then return end

    -- Never allow a delayed client/engine event to turn the creator room into
    -- a world spawn, even if it arrives after the routing bucket changed.
    local decoded = Utils.SafeJsonDecode(coordsJson, {})
    if IsCreatorRoomCoords(decoded) then return end

    -- Update VORP's in-memory source first, then overwrite the one `coords`
    -- field of this exact character row.  There is no position history table
    -- or INSERT here: every save replaces the previous JSON value.
    SyncVorpCharacterCoords(src, coordsJson)
    local saved = Database.UpdateLastCoords(charId, identifier, coordsJson)
    if not saved then
        print(string.format("[thehunt_character] Failed to save last position char=%s", tostring(charId)))
    end
end

--- Persist an active world character's location and exact native vital values.
--- The private selector/creator bucket is deliberately rejected by
--- SaveLastPosition, preserving the last actual world snapshot.
function Characters.SaveWorldState(src, coords, state)
    if GetPlayerRoutingBucket(src) ~= 0 then return false end
    local char = exports.thehunt_core:GetCharacter(src)
    local charId, identifier = char and tonumber(char.charIdentifier), GetIdentifier(src)
    local cleanState = NormalizeWorldState(state)
    if not charId or charId <= 0 or not identifier or not cleanState then return false end

    Characters.SaveLastPosition(src, coords)
    if not Database.UpsertWorldState(charId, cleanState) then return false end

    -- Keep VORP's own cache/source in step for resources that read it.  Its
    -- legacy HealthOuter convention is entity health minus the health core.
    exports.thehunt_core:SetCharacterVitals(src, {
        healthOuter = cleanState.health - cleanState.healthCore,
        healthInner = cleanState.healthCore,
        staminaOuter = cleanState.stamina,
        staminaInner = cleanState.staminaCore
    })
    return true
end

local function MergeTables(base, changes)
    local result = Utils.DeepCopy(type(base) == "table" and base or {})
    for key, value in pairs(type(changes) == "table" and changes or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = MergeTables(result[key], value)
        else
            result[key] = Utils.DeepCopy(value)
        end
    end
    return result
end

--- Save the active character's complete/partial appearance and synchronize the
--- VORP in-memory object so its later autosave cannot restore stale JSON.
function Characters.UpdateAppearance(src, payload)
    if type(payload) ~= "table" then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Некорректные данные внешности.")
        return false
    end
    local identifier = GetIdentifier(src)
    local character = exports.thehunt_core:GetCharacter(src)
    local charId = character and tonumber(character.charIdentifier) or nil
    if not identifier or not charId or not Database.VerifyCharacterOwnership(charId, identifier) then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Активный персонаж не найден.")
        return false
    end

    local row = Database.GetCharacterById(charId)
    if not row then return false end
    local currentSkin = Utils.SafeJsonDecode(row.skinPlayer, {})
    local currentComps = Utils.SafeJsonDecode(row.compPlayer, {})
    local currentTints = Utils.SafeJsonDecode(row.compTints, {})
    local skin = payload.fullSnapshot and payload.skin or MergeTables(currentSkin, payload.skin)
    local comps = payload.fullSnapshot and payload.comps or MergeTables(currentComps, payload.comps)
    local tints = payload.fullSnapshot and payload.compTints or MergeTables(currentTints, payload.compTints)

    local ok, cleanSkin, cleanComps, cleanTints, canonicalGender = Validation.SanitizeAppearance(
        skin, comps, tints, row.gender
    )
    if not ok then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, cleanSkin)
        return false
    end
    if cleanComps.Hair ~= nil then cleanSkin.Hair = type(cleanComps.Hair) == "table" and cleanComps.Hair.comp or cleanComps.Hair end
    if cleanComps.Beard ~= nil then cleanSkin.Beard = type(cleanComps.Beard) == "table" and cleanComps.Beard.comp or cleanComps.Beard end
    if cleanComps.Teeth ~= nil then cleanSkin.Teeth = type(cleanComps.Teeth) == "table" and cleanComps.Teeth.comp or cleanComps.Teeth end
    cleanSkin = Utils.NormalizeSkin(cleanSkin, canonicalGender)

    local skinJson, compsJson, tintsJson = json.encode(cleanSkin), json.encode(cleanComps), json.encode(cleanTints)
    if not Database.UpdateAppearance(charId, identifier, skinJson, compsJson, tintsJson) then
        TriggerClientEvent(Constants.Events.NOTIFY_ERROR, src, "Не удалось сохранить внешность.")
        return false
    end
    exports.thehunt_core:UpdateCharacterAppearance(src, skinJson, compsJson, tintsJson)
    local charScale = tonumber(cleanSkin.Scale or cleanSkin.scale) or 1.0
    Player(src).state:set('thehuntScale', charScale, true)
    TriggerClientEvent(Constants.Events.APPEARANCE_SAVED, src, {
        skin = cleanSkin, comps = cleanComps, compTints = cleanTints, gender = canonicalGender
    })
    return true
end

--- Persist one inventory clothing component without broadcasting a full
--- appearance snapshot.  The old path sent APPEARANCE_SAVED, which rebuilt
--- the complete MetaPed and could reset the selected body build.
function Characters.UpdateInventoryClothing(src, category, component, tint)
    if type(category) ~= "string" then return false end
    local identifier = GetIdentifier(src)
    local character = exports.thehunt_core:GetCharacter(src)
    local charId = character and tonumber(character.charIdentifier) or nil
    if not identifier or not charId or not Database.VerifyCharacterOwnership(charId, identifier) then return false end

    local row = Database.GetCharacterById(charId)
    if not row then return false end
    local skin = Utils.SafeJsonDecode(row.skinPlayer, {})
    local comps = Utils.SafeJsonDecode(row.compPlayer, {})
    local tints = Utils.SafeJsonDecode(row.compTints, {})
    comps[category] = tonumber(component) or -1
    if type(tint) == "table" then tints[category] = tint else tints[category] = nil end
    local ok, cleanSkin, cleanComps, cleanTints, gender = Validation.SanitizeAppearance(skin, comps, tints, row.gender)
    if not ok then return false end
    local skinJson, compsJson, tintsJson = json.encode(cleanSkin), json.encode(cleanComps), json.encode(cleanTints)
    if not Database.UpdateAppearance(charId, identifier, skinJson, compsJson, tintsJson) then return false end
    exports.thehunt_core:UpdateCharacterAppearance(src, nil, compsJson, tintsJson)
    TriggerClientEvent("thehunt_character:client:ApplySingleClothing", src, category, tonumber(cleanComps[category]) or -1, cleanTints[category], gender)
    return true
end

AddEventHandler('playerDropped', function()
    creatingCharacters[source] = nil
    selectingCharacters[source] = nil
    loadingCharacters[source] = nil
end)

-- Inventory owns whether a garment is equipped; this bridge only applies the
-- already validated component stored in that garment's metadata.
AddEventHandler('thehunt_character:server:syncInventoryClothing', function(src, category, metadata)
    if type(src) ~= 'number' or type(category) ~= 'string' then return end
    local component = metadata and tonumber(metadata.component) or -1
    if component == 0 then component = -1 end
    local tints = metadata and type(metadata.tint) == 'table' and { [category] = metadata.tint } or {}
    Characters.UpdateInventoryClothing(src, category, component, tints[category])
end)
