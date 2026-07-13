-- spz-vehicles configuration
Config = {}

Config.SafeZoneCoords          = vector3(0.0, 0.0, 72.0)
Config.SafeZoneHeading         = 0.0

Config.FreeroamSpawnCooldown   = 10      -- seconds between freeroam spawns
Config.SpawnConfirmTimeout     = 15000   -- ms to wait for entity spawn confirm
Config.UpgradeConfirmTimeout   = 15000   -- ms to wait for upgrade confirm
Config.DespawnDelay            = 500     -- ms between despawn and next spawn
Config.PollOptionsPerClass     = 2       -- vehicle options per poll
Config.MaxPlateLength          = 8       -- max chars in /savecustom plate
Config.RentalVehicles = {
    [0] = "sultan",     -- Class C: Street
    [1] = "sultanrs",   -- Class B: Sport
    [2] = "comet6",     -- Class A: Pro
    [3] = "zentorno",   -- Class S: Elite
}

Config.Debug                   = false
