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

-- ── Add-on car packs ────────────────────────────────────────────────────────
-- Cars from external packs are DISCOVERED, not listed.
--
-- data/vehicles.lua is the curated base-game roster. An add-on pack is a
-- separate resource that ships its own vehicles.meta, and nothing here knew
-- those models existed: the registry has a dynamic-registration fallback, but
-- it is LAZY — it only fires when something asks about one specific model by
-- name. The poll iterates the registry directly, so a pack nobody had driven
-- was invisible to it forever.
--
-- server/addons.lua closes that: it reads every started resource's declared
-- VEHICLE_METADATA_FILE, pulls the model names out, and registers the ones the
-- registry does not already have. From there the existing pipeline takes over —
-- server/classify.lua probes each model's REAL performance on a client, puts it
-- in the right class, and server/validate.lua drops any model a client cannot
-- actually load, so a broken pack cannot win a poll and cancel a race.
Config.Addons = {
  AutoDiscover = true,   -- false = only data/vehicles.lua, as before

  Race         = true,   -- offer discovered cars in the race poll
  Freeroam     = true,   -- allow them to be spawned in freeroam

  -- How much more often an add-on shows up than a base-game car of the SAME
  -- class. 1.0 = no preference. The point of adding a pack is usually to see
  -- it, and a pack of 20 cars spread across four classes is otherwise heavily
  -- outnumbered by the curated roster in every one of them.
  PollBoost    = 2.0,

  -- Which declared <type> values are registered. A pack that ships bikes,
  -- boats or helicopters alongside its cars is the normal case, and without
  -- this "car pack support" quietly means a boat in the race poll. Add
  -- VEHICLE_TYPE_BIKE here if bike races are wanted.
  AllowTypes   = { VEHICLE_TYPE_CAR = true },

  -- Model names to never register. Plain names, or Lua patterns — a pack that
  -- ships emergency or utility vehicles alongside its cars is the normal case.
  -- Matched case-insensitively against the model name.
  Exclude      = {
    "^police", "^sheriff", "^ambulance", "^firetruk", "^fbi",
    "^riot", "^pbus", "^taxi",
  },
}

Config.Debug                   = false
