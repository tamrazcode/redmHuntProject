-- =================================================================
-- HUNT: Hard RP — Animations System Exports
-- =================================================================

-- Совместимость с экспортами rsg-animations
local function normalizeBodyOption(bodyOption)
    if type(bodyOption) == 'table' then
        bodyOption = bodyOption.body
    end
    if type(bodyOption) ~= 'string' or bodyOption == '' then
        return 'full'
    end
    bodyOption = string.lower(bodyOption)
    if bodyOption == 'upper' then
        return 'upper'
    end
    return 'full'
end

exports('playAnim', function(name, bodyOption)
    return exports['thehunt_animations']:PlayAnimation(name, normalizeBodyOption(bodyOption))
end)

exports('stopAnim', function()
    exports['thehunt_animations']:StopAnimation()
end)

exports('openAnimationMenu', function()
    exports['thehunt_animations']:OpenMenu()
end)
