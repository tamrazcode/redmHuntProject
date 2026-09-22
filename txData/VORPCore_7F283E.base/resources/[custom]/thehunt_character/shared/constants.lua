-- =================================================================
-- HUNT: Hard RP — Shared Constants
-- =================================================================

Constants = {}

Constants.Events = {
    -- Client -> Server
    REQUEST_CHARACTERS = "thehunt_character:server:requestCharacters",
    SELECT_CHARACTER   = "thehunt_character:server:selectCharacter",
    CREATE_CHARACTER   = "thehunt_character:server:createCharacter",
    DELETE_CHARACTER   = "thehunt_character:server:deleteCharacter",
    UPDATE_APPEARANCE  = "thehunt_character:server:updateAppearance",
    SAVE_LAST_POSITION = "thehunt_character:server:saveLastPosition",
    SAVE_WORLD_STATE   = "thehunt_character:server:saveWorldState",
    OPEN_SELECTION_AFTER_SAVE = "thehunt_character:server:openSelectionAfterSave",

    -- Server -> Client
    RECEIVE_CHARACTERS = "thehunt_character:client:receiveCharacters",
    OPEN_CREATOR       = "thehunt_character:client:openCreator",
    OPEN_SELECTION     = "thehunt_character:client:openSelection",
    CHARACTER_SPAWNED  = "thehunt_character:client:onCharacterSpawned",
    NOTIFY_ERROR       = "thehunt_character:client:notifyError",
    NOTIFY_SUCCESS     = "thehunt_character:client:notifySuccess",
    CREATION_FAILED    = "thehunt_character:client:creationFailed",
    APPEARANCE_SAVED   = "thehunt_character:client:appearanceSaved",
    PREPARE_SELECTION   = "thehunt_character:client:prepareSelection",

    -- Legacy VORP Forwarding Events
    VORP_INIT_CHARACTER = "vorp:initCharacter",
    VORP_SELECTED_CHAR  = "vorp:SelectedCharacter",
    VORP_CORE_SPAWNED   = "vorp_core:Client:OnPlayerSpawned",
}

Constants.MaxCodeAttempts = 50
Constants.CharacterCreateTimeout = 30000
