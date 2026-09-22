Config = Config or {}

-- This is unconsciousness, not permanent-character death. Permanent death will
-- be a separate system later and must not reuse this automatic wake-up path.
Config.UnconsciousDuration = 5 * 60 -- seconds
Config.WakeHealthDefault = 10 -- % HP при естественном подъеме по истечению таймера (10%)
Config.WakeHealthAided = 25   -- % HP при подъеме после снятия таймера аптечкой (25%)
Config.WakeHealth = 10        -- fallback
Config.WakeKey = 0xD9D0E1C0 -- INPUT_JUMP / Space
