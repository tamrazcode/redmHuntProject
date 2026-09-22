-- =================================================================
-- HUNT: Hard RP — Character Selection Menu Controller
-- =================================================================

Selection = {}
local isSelecting = false
local loadedCharacters = {}
local activePreviewIndex = nil

--- Open Character Selection UI with scene atmosphere and slot cards
--- @param data table
function Selection.Open(data)
    local alreadyOpen = isSelecting
    isSelecting = true
    loadedCharacters = data.characters or {}

    -- Hide status HUD during selection
    pcall(function()
        TriggerEvent("thehunt_status:setVisible", false)
    end)

    -- A refresh after deletion must only update cards: rebuilding the scene
    -- makes the camera visibly travel away and back again.
    if alreadyOpen then
        -- Creator.Close used to clear this focus during the refresh path.
        -- Reassert it here as a defensive invariant: an open selection screen
        -- must always own both keyboard and cursor input.
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openSelection",
            characters = loadedCharacters,
            maxSlots = data.maxSlots,
            isAdmin = data.isAdmin
        })
        if #loadedCharacters > 0 then
            -- NUI selects the first remaining card after a refresh; keep the
            -- scene preview on that same character.
            activePreviewIndex = 1
            Preview.ShowCharacter(loadedCharacters[activePreviewIndex])
        else
            Preview.ClearPed()
        end
        return
    end

    -- 1. Start streaming the landscape immediately; do not delay the menu.
    Preview.SetupScene(data.scene)

    -- 2. Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openSelection",
        characters = loadedCharacters,
        maxSlots = data.maxSlots,
        isAdmin = data.isAdmin
    })

    -- Do not hold the game fade while MetaPed/Clothing resolves a saved
    -- character.  Those natives can take several seconds after a resource or
    -- server restart; the selector NUI would otherwise be visible over a
    -- permanently dark world even though its camera scene is already ready.
    -- The preview has its own request id, so a later card click or closing the
    -- selector safely invalidates the background task.
    DoScreenFadeIn(800)
    if #loadedCharacters > 0 then
        activePreviewIndex = 1
        local firstCharacter = loadedCharacters[1]
        CreateThread(function()
            Preview.ShowCharacter(firstCharacter)
        end)
    end
end

--- Close selection interface
function Selection.Close()
    isSelecting = false
    activePreviewIndex = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeSelection" })
    Preview.Cleanup()
end

-- =================================================================
-- NUI Callbacks for Character Selection Actions
-- =================================================================

RegisterNUICallback("selection:selectSlot", function(data, cb)
    local charIndex = tonumber(data.index) or 1
    if loadedCharacters[charIndex] and charIndex ~= activePreviewIndex then
        activePreviewIndex = charIndex
        local character = loadedCharacters[charIndex]
        CreateThread(function()
            Preview.ShowCharacter(character)
        end)
    end
    cb("ok")
end)

RegisterNUICallback("selection:play", function(data, cb)
    local charId = tonumber(data.charIdentifier)
    if charId then
        TriggerServerEvent(Constants.Events.SELECT_CHARACTER, charId)
    end
    cb("ok")
end)

RegisterNUICallback("selection:create", function(data, cb)
    -- FIX #6: Never call Creator.Start() directly from client selection menu.
    -- Server must handle routing bucket isolation before opening creator.
    Selection.Close()
    DoScreenFadeOut(500)
    Wait(500)
    TriggerServerEvent("thehunt_character:server:requestNewCharacter")
    cb("ok")
end)

RegisterNUICallback("selection:delete", function(data, cb)
    local charId = tonumber(data.charIdentifier)
    local confirmName = data.confirmName
    if charId and confirmName then
        TriggerServerEvent(Constants.Events.DELETE_CHARACTER, {
            charIdentifier = charId,
            confirmName = confirmName
        })
    end
    cb("ok")
end)
