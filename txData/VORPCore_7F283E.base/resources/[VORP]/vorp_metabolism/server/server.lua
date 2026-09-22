local VorpCore = exports.vorp_core:GetCore()
local T    = Translation.Langs[Config.Langs]

CreateThread(function()
    -- HUNT owns item use and forwards hunger/thirst changes to this retained
    -- metabolism authority.  Do not register a second set of handlers against
    -- the removed vorp_inventory resource.
    if GetConvar('hunt_inventory_owner', '0') == '1' then return end
    if GetResourceState('vorp_inventory') ~= 'started' then
        print('^3[vorp_metabolism] vorp_inventory is unavailable; HUNT item handlers remain authoritative.^7')
        return
    end

    for i = 1, #Config.ItemsToUse, 1 do
        exports.vorp_inventory:registerUsableItem(Config["ItemsToUse"][i]["Name"], function(data)
            local itemLabel = data.item.label
            local usedItems = Config["ItemsToUse"][i]
            local notification
            TriggerClientEvent("vorpmetabolism:useItem", data.source, i, itemLabel, usedItems.GiveBackItem, usedItems.GiveBackItemAmount)
            notification = string.format(T.OnUseItem, itemLabel)
            exports.vorp_inventory:subItemById(data.source, data.item.mainid)

            if usedItems.GiveBackItem and usedItems.GiveBackItem ~= "" then
                local giveBackItemAmount = tonumber(usedItems.GiveBackItemAmount)
                if exports.vorp_inventory:canCarryItem(data.source, usedItems.GiveBackItem, usedItems.GiveBackItemAmount) then
                    notification = string.format(T.OnUseItemWithReturn, itemLabel, usedItems.GiveBackItemLabel, giveBackItemAmount)
                    exports.vorp_inventory:addItem(data.source, usedItems.GiveBackItem, usedItems.GiveBackItemAmount)
                else
                    notification = string.format(T.CantCarry, itemLabel, giveBackItemAmount, usedItems.GiveBackItemLabel)
                end
            end
            VorpCore.NotifyTip(data.source, notification, 4000)
            exports.vorp_inventory:closeInventory(data.source)
        end)
    end
end)

RegisterNetEvent("vorpmetabolism:SaveLastStatus", function(status)
    local _source = source
    if type(status) ~= "string" or #status > 4096 then return end
    local ok, decoded = pcall(json.decode, status)
    if not ok or type(decoded) ~= "table" then return end
    local user = VorpCore.getUser(_source)
    local UserCharacter = user and user.getUsedCharacter or nil
    if not UserCharacter then return end

    local charIdentifier = tonumber(UserCharacter.charIdentifier)
    local identifier = UserCharacter.identifier
    if not charIdentifier or type(identifier) ~= "string" or identifier == "" then return end

    UserCharacter.setStatus(status)
    -- VORP's setter is in-memory; persist the same snapshot immediately.
    MySQL.update.await("UPDATE `characters` SET `status` = ? WHERE `charidentifier` = ? AND `identifier` = ?", {
        status, charIdentifier, identifier
    })
end)

RegisterNetEvent("vorpmetabolism:GetStatus", function()
    local _source = source
    local user = VorpCore.getUser(_source)
    local UserCharacter = user and user.getUsedCharacter or nil
    if not UserCharacter then return end

    local s_status = UserCharacter.status
    if type(s_status) == "string" and #s_status > 5 then
        TriggerClientEvent("vorpmetabolism:StartFunctions", _source, s_status)
    else
        local status = json.encode({
            ['Hunger'] = Config["FirstHungerStatus"],
            ['Thirst'] = Config["FirstThirstStatus"],
            ['Metabolism'] = Config["FirstMetabolismStatus"]
        })
        UserCharacter.setStatus(status)
        TriggerClientEvent("vorpmetabolism:StartFunctions", _source, status)
    end
end)
