GlobalState.PlayersInSession = 0

-- MariaDB/oxmysql may return BIGINT identifiers as strings while client/NUI
-- flows normally send numbers. Keep one canonical key type inside VORP so a
-- valid character cannot be missed because table["35"] ~= table[35].
local function NormalizeCharacterId(value)
    local numeric = tonumber(value)
    return numeric or value
end

local function FindCharacter(characters, value)
    if type(characters) ~= "table" then return nil end
    local normalized = NormalizeCharacterId(value)
    return characters[normalized] or characters[value] or characters[tostring(normalized)]
end

---@param source number
---@param identifier string
---@param group string
---@param playerwarnings number
---@param license string
---@param char number
---@return User
function User(source, identifier, group, playerwarnings, license, char, max_jobs)
    local self = {}
    self._identifier = identifier
    self._license = license
    self._group = group
    self._playerwarnings = playerwarnings
    self._charperm = char
    self._max_jobs = max_jobs
    self._usercharacters = {}
    self._numofcharacters = 0
    self.usedCharacterId = -1
    self.source = source
    self.steamname = GetPlayerName(source) or ""

    self.UsedCharacterId = function(value)
        if value ~= nil then
            local normalized = NormalizeCharacterId(value)
            local character = FindCharacter(self._usercharacters, normalized)
            if not character then return false end

            self.usedCharacterId = normalized
            character.source = self.source
            character.updateCharUi()
            local player = character.getCharacter()
            GlobalState.PlayersInSession = GlobalState.PlayersInSession + 1
            TriggerClientEvent("vorp:SelectedCharacter", self.source, self.usedCharacterId)
            TriggerEvent("vorp:SelectedCharacter", self.source, player)
            Player(self.source).state:set('IsInSession', true, true)
            Player(self.source).state:set('Character', {
                Group = player.group,
                FirstName = player.firstname,
                LastName = player.lastname,
                Job = player.job,
                JobLabel = player.jobLabel,
                Grade = player.jobGrade,
                Gender = player.gender,
                Age = player.age,
                CharDescription = player.charDescription,
                NickName = player.nickname,
                Money = player.money,
                Gold = player.gold,
                Rol = player.rol,
                CharId = self.usedCharacterId,
            }, true)
            return true
        end

        return self.usedCharacterId
    end


    self.Source = function(value)
        if value then
            self.source = value
        end
        return self.source
    end

    self.Numofcharacters = function(value)
        if value then
            self._numofcharacters = value
        end
        return self._numofcharacters
    end

    self.Identifier = function(value)
        if value then
            self._identifier = value
        end
        return self._identifier
    end

    self.License = function(value)
        if value then
            self._license = value
        end
        return self._license
    end

    self.Group = function(value)
        if value then
            self._group = value
            MySQL.update("UPDATE users SET `group` = ? WHERE `identifier` = ?", { self._group, self.Identifier() })
        end
        return self._group
    end

    self.Playerwarnings = function(value)
        if value then
            self._playerwarnings = value
            MySQL.update("UPDATE users SET `warnings` = ? WHERE `identifier` = ?", { self._playerwarnings, self.Identifier() })
        end

        return self._playerwarnings
    end

    self.Charperm = function(value)
        if value ~= nil then
            self._charperm = value
            MySQL.update("UPDATE users SET `char` = ? WHERE `identifier` = ?", { self._charperm, self.Identifier() })
        end

        return self._charperm
    end

    --set max jobs
    self.SetMaxJobs = function(value)
        if value then
            self._max_jobs = value
            MySQL.update("UPDATE users SET `max_jobs` = ? WHERE `identifier` = ?", { self._max_jobs, self.Identifier() })
        end
        return self._max_jobs
    end


    self.GetUser = function()
        local userData = {}
        userData.getCharperm = self.Charperm()
        userData.source = self.source
        userData.getGroup = self.Group()
        userData.getUsedCharacter = self.UsedCharacter()
        userData.getUserCharacters = self.UserCharacters()
        userData.maxJobsAllowed = tonumber(self._max_jobs)

        userData.getIdentifier = function()
            return self.Identifier()
        end

        userData.getPlayerwarnings = function()
            return self.Playerwarnings()
        end

        userData.setPlayerWarnings = function(value)
            self.Playerwarnings(value)
        end

        userData.setGroup = function(value)
            self.Group(value)
        end

        userData.setCharperm = function(value)
            self.Charperm(value)
        end

        userData.setMaxJobsAllowed = function(value)
            self.SetMaxJobs(value)
        end

        userData.getNumOfCharacters = function()
            return self._numofcharacters
        end

        userData.addCharacter = function(data)
            self._numofcharacters = self._numofcharacters + 1
            self.addCharacter(data)
        end

        userData.removeCharacter = function(charid)
            if self._usercharacters[charid] then
                self._numofcharacters = self._numofcharacters - 1
                self.delCharacter(charid)
            end
        end

        userData.setUsedCharacter = function(charid)
            self.SetUsedCharacter(charid)
        end

        return userData
    end

    self.UsedCharacter = function()
        local character = FindCharacter(self._usercharacters, self.usedCharacterId)
        if character then
            return character.getCharacter()
        end

        return {}
    end

    self.UserCharacters = function()
        local userCharacters = {}
        for _, v in pairs(self._usercharacters) do
            table.insert(userCharacters, v.getCharacter())
        end
        return userCharacters
    end

    self.LoadCharacters = function()
        -- A VORP user must not be exposed as ready until its character cache is
        -- populated.  The spawn fallback in loadusers.lua relies on this being
        -- synchronous from the caller's perspective.
        local usercharacters = MySQL.query.await("SELECT identifier, charidentifier, `group`, job, jobgrade, joblabel, firstname, lastname, inventory, status, coords, money, gold, rol, healthouter, healthinner, staminaouter, staminainner, xp, isdead, skinPlayer, compPlayer, compTints, age,gender, character_desc, nickname, slots,skills,multijobs FROM characters WHERE identifier = @identifier", { identifier = self._identifier }) or {}
        self.Numofcharacters(#usercharacters)
        if #usercharacters > 0 then
            for _, character in ipairs(usercharacters) do
                if character.identifier then
                    local data = {
                            identifier = character.identifier,
                            charIdentifier = NormalizeCharacterId(character.charidentifier),
                            group = character.group,
                            job = character.job,
                            jobgrade = character.jobgrade,
                            joblabel = character.joblabel,
                            firstname = character.firstname,
                            lastname = character.lastname,
                            inventory = character.inventory,
                            status = character.status,
                            coords = character.coords,
                            money = character.money,
                            gold = character.gold,
                            rol = character.rol,
                            healthOuter = character.healthouter,
                            healthInner = character.healthinner,
                            staminaOuter = character.staminaouter,
                            staminaInner = character.staminainner,
                            xp = character.xp,
                            isdead = character.isdead,
                            skin = character.skinPlayer,
                            comps = character.compPlayer,
                            source = self.source,
                            compTints = character.compTints,
                            age = character.age,
                            gender = character.gender,
                            charDescription = character.character_desc,
                            nickname = character.nickname,
                            steamname = self.steamname,
                            slots = character.slots or 200,
                            skills = character.skills and json.decode(character.skills) or {},
                            multiJobs = character.multijobs and json.decode(character.multijobs) or {},
                    }
                    local newCharacter = Character(data)
                    self._usercharacters[NormalizeCharacterId(newCharacter.CharIdentifier())] = newCharacter
                end
            end
        end
    end

    self.addCharacter = function(data)
        local info = {
            identifier = self._identifier,
            charIdentifier = -1,
            group = Config.initGroup,
            job = Config.initJob,
            jobgrade = Config.initJobGrade,
            joblabel = Config.initJobLabel,
            firstname = data.firstname,
            lastname = data.lastname,
            inventory = "{}",
            status = "{}",
            coords = "{}",
            money = Config.initMoney,
            gold = Config.initGold,
            rol = Config.initRol,
            healthOuter = 500,
            healthInner = 100,
            staminaOuter = 500,
            staminaInner = 100,
            xp = Config.initXp,
            isdead = false,
            skin = data.skin,
            comps = data.comps,
            source = self.source,
            compTints = data.compTints,
            age = data.age,
            gender = data.gender,
            charDescription = data.charDescription,
            nickname = data.nickname,
            steamname = self.steamname,
            slots = Config.initInvCapacity or 200,
            skills = {},
            multiJobs = {},
        }

        local newChar = Character(info)

        newChar.SaveNewCharacterInDb(function(id)
            local normalizedId = NormalizeCharacterId(id)
            newChar.CharIdentifier(normalizedId)
            self._usercharacters[normalizedId] = newChar
            self.UsedCharacterId(normalizedId)
        end)
    end

    self.delCharacter = function(charIdentifier)
        local normalized = NormalizeCharacterId(charIdentifier)
        local character = FindCharacter(self._usercharacters, normalized)
        if character then
            character.DeleteCharacter()
            self._usercharacters[normalized] = nil
        end
    end

    self.GetUsedCharacter = function()
        local character = FindCharacter(self._usercharacters, self.UsedCharacterId())
        if character then
            return character
        else
            return nil
        end
    end

    self.SetUsedCharacter = function(charid)
        local normalized = NormalizeCharacterId(charid)
        if FindCharacter(self._usercharacters, normalized) then
            if self.usedCharacterId == normalized then
                return print("character is already selected charid: ", charid, "this player tried to join twice with the same character possible exploit!!")
            end
            return self.UsedCharacterId(normalized)
        end
        return false
    end

    self.SaveUser = function()
        local character = FindCharacter(self._usercharacters, self.usedCharacterId)
        if self.usedCharacterId and character then
            if not Player(self.source).state.PlayerIsInCharacterShops then -- dont allow to save position if player is in character shops
                local player = self.source
                local ped = GetPlayerPed(player)
                local Pcoords = GetEntityCoords(ped)
                local Pheading = GetEntityHeading(ped)
                local characterCoords = json.encode({ x = Pcoords.x, y = Pcoords.y, z = Pcoords.z, heading = Pheading })
                character.Coords(characterCoords)
            end

            character.SaveCharacterInDb()
        end
    end

    return self
end
