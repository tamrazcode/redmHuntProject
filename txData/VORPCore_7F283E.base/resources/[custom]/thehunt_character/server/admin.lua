-- =================================================================
-- HUNT: Hard RP — Admin Permissions & Integration
-- =================================================================

Admin = {}

--- Check if player is server administrator
--- @param src number
--- @return boolean
function Admin.IsAdmin(src)
    if src <= 0 then return true end -- Console

    -- 1. Check custom thehunt_core export
    local success, result = pcall(function()
        return exports['thehunt_core']:IsPlayerAdmin(src)
    end)
    local denyCheckOk, explicitlyDenied = pcall(function()
        return exports['thehunt_core']:IsPlayerAdminOverrideDenied(src)
    end)
    if denyCheckOk and explicitlyDenied == true then
        return false
    end
    if success and result == true then
        return true
    end

    -- 2. Check ACE permissions
    if IsPlayerAceAllowed(src, "command") or IsPlayerAceAllowed(src, "group.admin") or IsPlayerAceAllowed(src, "thehunt.admin") then
        return true
    end

    return false
end
