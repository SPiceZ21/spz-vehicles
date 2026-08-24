-- spz-vehicles configuration
Config = {}

Config.SafeZoneCoords          = vector3(0.0, 0.0, 72.0)
Config.SafeZoneHeading         = 0.0

Config.FreeroamSpawnCooldown   = 10      -- seconds between freeroam spawns
Config.SpawnConfirmTimeout     = 15000   -- ms to wait for entity spawn confirm
Config.UpgradeConfirmTimeout   = 15000   -- ms to wait for upgrade confirm
Config.DespawnDelay            = 500     -- ms between despawn and next spawn

-- Model preload (client-side, before any server vehicle entity exists).
-- Right after connecting, a client's streaming/DLC metadata can still be
-- catching up, so IsModelInCdimage/IsModelAVehicle can transiently read
-- false for a perfectly valid model — ModelCheckGraceMs polls through that
-- instead of bailing on the first check. ModelLoadTimeoutMs caps how long
-- RequestModel is allowed to hang before giving up. Both used to fail
-- completely silently (a bare `return` / an unbounded wait loop), which is
-- what produced races that hung for the full world.lua spawn timeout with
-- no server-side explanation at all.
Config.ModelCheckGraceMs       = 3000
Config.ModelLoadTimeoutMs      = 15000
Config.FallbackVehicleModel    = "sultan"  -- always-valid base-game car; one
                                            -- automatic retry on this before
                                            -- surfacing the failure upward
Config.PollOptionsPerClass     = 2       -- vehicle options per poll
Config.MaxPlateLength          = 8       -- max chars in /savecustom plate
Config.RentalVehicles = {
    [0] = "sultan",     -- Class C: Street
    [1] = "sultanrs",   -- Class B: Sport
    [2] = "comet6",     -- Class A: Pro
    [3] = "zentorno",   -- Class S: Elite
}

Config.Debug                   = false
