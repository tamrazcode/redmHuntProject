Config = {
    Command = 'vfx', Key = 'F6',
    AssetTimeout = 5000, MaxLocal = 64, MaxWorld = 80,
    MaxLayers = 24, MaxPresets = 128, MaxDuration = 600,
    StreamDistance = 150.0, StreamInterval = 500,
    Store = 'data/studio.json',
    -- Screen modifiers share engine state with death/weather/character scripts.
    -- Explicitly opt in only after checking those resources.
    AllowTimecycle = false
}
