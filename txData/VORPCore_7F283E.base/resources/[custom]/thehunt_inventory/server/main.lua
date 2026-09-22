-- =================================================================

local QUICK_SLOT_COUNT = 4
local quickSlotTableReady = false

local function GetPlayerIdentifiersVORP(src)
    local identifier = "unknown"
    local charIdentifier = 1

    local character = exports.thehunt_core:GetCharacter(src)
    if character then
        identifier = character.identifier or exports.thehunt_core:GetPlayerIdentifier(src) or "unknown"
        charIdentifier = tonumber(character.charIdentifier or character.charid) or 1
    end

    if identifier == "unknown" then
        for _, playerIdentifier in ipairs(GetPlayerIdentifiers(src)) do
            if string.find(playerIdentifier, "license:") or string.find(playerIdentifier, "steam:") then
                identifier = playerIdentifier
                break
            end
        end
    end

    return identifier, charIdentifier
end

local function IsQuickSlotItemDefinition(itemDefinition)
    if type(itemDefinition) ~= "table" then return false end
    if itemDefinition.canUse == true then return true end

    -- Notebook-like items intentionally expose an action rather than the
    -- generic canUse flag. They still have a meaningful quick-slot action.
    for _, action in ipairs(itemDefinition.actions or {}) do
        if action == "read" or action == "write" then return true end
    end
    return false
end

local function IsCarriedQuickSlotItem(row)
    if type(row) ~= "table" then return false end
    if (tonumber(row.count) or 0) <= 0 then return false end
    local container = tostring(row.container or "main")
    return not container:match("^prop:")
end

local function EnsureQuickSlotTable()
    if quickSlotTableReady then return true end
    local ok = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `thehunt_inventory_quickslots` (
                `identifier` VARCHAR(64) NOT NULL,
                `charidentifier` INT NOT NULL DEFAULT 1,
                `slot` TINYINT UNSIGNED NOT NULL,
                `item_id` INT NOT NULL,
                PRIMARY KEY (`identifier`, `charidentifier`, `slot`),
                UNIQUE KEY `uq_quick_item` (`identifier`, `charidentifier`, `item_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
    quickSlotTableReady = ok
    return ok
end

local function SendQuickSlotSnapshot(src)
    if not EnsureQuickSlotTable() then return end
    local identifier, charIdentifier = GetPlayerIdentifiersVORP(src)
    local rows = MySQL.query.await(
        "SELECT slot, item_id FROM thehunt_inventory_quickslots WHERE identifier = ? AND charidentifier = ? ORDER BY slot",
        { identifier, charIdentifier }
    ) or {}

    local result = {}
    for _, binding in ipairs(rows) do
        local slot = tonumber(binding.slot)
        local itemId = tonumber(binding.item_id)
        if slot and slot >= 1 and slot <= QUICK_SLOT_COUNT and itemId then
            local itemRow = MySQL.single.await(
                "SELECT id, item_name, count, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? LIMIT 1",
                { itemId, identifier, charIdentifier }
            )
            local itemDefinition = itemRow and exports['thehunt_items']:GetItemData(itemRow.item_name)
            if itemRow and IsCarriedQuickSlotItem(itemRow) and IsQuickSlotItemDefinition(itemDefinition) then
                result[#result + 1] = {
                    slot = slot,
                    dbId = itemId,
                    name = itemRow.item_name,
                    count = tonumber(itemRow.count) or 0
                }
            else
                MySQL.update.await(
                    "DELETE FROM thehunt_inventory_quickslots WHERE identifier = ? AND charidentifier = ? AND slot = ?",
                    { identifier, charIdentifier, slot }
                )
            end
        end
    end

    TriggerClientEvent("thehunt_inventory:receiveQuickSlots", src, result)
end

CreateThread(function()
    Wait(500)
    EnsureQuickSlotTable()
end)

RegisterNetEvent("thehunt_inventory:requestQuickSlots", function()
    SendQuickSlotSnapshot(source)
end)

RegisterNetEvent("thehunt_inventory:setQuickSlot", function(slot, itemId)
    local src = source
    slot = tonumber(slot)
    itemId = tonumber(itemId)
    if not slot or slot < 1 or slot > QUICK_SLOT_COUNT then return end
    if not EnsureQuickSlotTable() then return end

    local identifier, charIdentifier = GetPlayerIdentifiersVORP(src)
    if not itemId or itemId <= 0 then
        MySQL.update.await(
            "DELETE FROM thehunt_inventory_quickslots WHERE identifier = ? AND charidentifier = ? AND slot = ?",
            { identifier, charIdentifier, slot }
        )
        SendQuickSlotSnapshot(src)
        return
    end

    local itemRow = MySQL.single.await(
        "SELECT id, item_name, count, container FROM thehunt_inventories WHERE id = ? AND identifier = ? AND charidentifier = ? LIMIT 1",
        { itemId, identifier, charIdentifier }
    )
    local itemDefinition = itemRow and exports['thehunt_items']:GetItemData(itemRow.item_name)
    if not itemRow or not IsCarriedQuickSlotItem(itemRow) or not IsQuickSlotItemDefinition(itemDefinition) then
        TriggerClientEvent("thehunt_status:notify", src, "Быстрый слот", "Этот предмет нельзя назначить в быстрый слот.", "error")
        SendQuickSlotSnapshot(src)
        return
    end

    -- One inventory row can be bound to only one slot. This also makes a
    -- drag from one slot to another an atomic rebinding from the player's
    -- perspective, while the inventory remains server-authoritative.
    MySQL.transaction.await({
        {
            query = "DELETE FROM thehunt_inventory_quickslots WHERE identifier = ? AND charidentifier = ? AND item_id = ?",
            values = { identifier, charIdentifier, itemId }
        },
        {
            query = "DELETE FROM thehunt_inventory_quickslots WHERE identifier = ? AND charidentifier = ? AND slot = ?",
            values = { identifier, charIdentifier, slot }
        },
        {
            query = "INSERT INTO thehunt_inventory_quickslots (identifier, charidentifier, slot, item_id) VALUES (?, ?, ?, ?)",
            values = { identifier, charIdentifier, slot, itemId }
        }
    })
    SendQuickSlotSnapshot(src)
end)
-- HUNT: Hard RP — The Corruption | Server Inventory Bridge
-- =================================================================

-- Все операции с базой данных, дропами и предметами обрабатываются ядром thehunt_items
