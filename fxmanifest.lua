fx_version 'cerulean'
game 'gta5'

name 'spz-vehicles'
description 'SPiceZ-Core — Vehicles: registry, spawn, upgrades, customization, garage, tuner, vehicle functions'
version '2.0.0'
author 'SPiceZ-Core'

shared_scripts {
  '@ox_lib/init.lua',
  -- Shared, not server-only: client/spawn.lua reads the model pre-load timings
  -- from here. As a server script it left Config nil on the client, so the very
  -- first line of the pre-load handler threw — the server then waited out its
  -- whole spawn timeout for an answer that could never come, and cancelled the
  -- race. Nothing in here is server-private.
  'config.lua',
  'shared/classes.lua',
  'shared/classify.lua',
  'shared/upgrades.lua',
  'shared/events.lua',
  -- Tuner (merged from spz-tunners)
  'config_tuner.lua',
  'shared/tuner_colors.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'data/vehicles.lua',
  'server/main.lua',
  'server/classify.lua',
  'server/registry.lua',
  'server/validate.lua',
  'server/spawn.lua',
  'server/upgrades.lua',
  'server/customization.lua',
  'server/race_spawn.lua',
  'server/poll_pool.lua',
  -- After data/vehicles.lua (it registers INTO SPZ.VehicleRegistry) and after
  -- classify.lua (whose sweep then picks the new models up).
  'server/addons.lua',
  -- Garage and tuner (merged from spz-carspawner, spz-tunners)
  'server/garage.lua',
  'server/tuner.lua',
}

client_scripts {
  'client/main.lua',
  'client/addon_scan.lua',
  'client/classify.lua',
  'client/validate.lua',
  'client/spawn.lua',
  'client/despawn.lua',
  'client/upgrades.lua',
  'client/customization.lua',
  'client/commands.lua',

  -- Garage, tuner and vehicle functions (merged from spz-carspawner,
  -- spz-tunners and spz-vehfunc). The garage and tuner pages are spz-hud apps;
  -- app.lua binds each file to its page.
  '@spz-hud/app.lua',
  'client/garage.lua',
  'client/tuner_cam.lua',
  'client/tuner_menu.lua',
  'client/tuner.lua',
  'client/vehfunc/main.lua',
  'client/vehfunc/godmode.lua',
  'client/vehfunc/taunts.lua',
  'client/vehfunc/idlecam.lua',
}

-- Tuner paints: Fubuki-jo chameleon paints (223-242); stream/vehicle_paint_ramps.ytd
-- holds their colour ramps.
files {
  'data/carcols_gen9.meta',
  'data/carmodcols_gen9.meta',
}
data_file 'CARCOLS_GEN9_FILE' 'data/carcols_gen9.meta'
data_file 'CARMODCOLS_GEN9_FILE' 'data/carmodcols_gen9.meta'

dependencies {
  'ox_lib',
  'spz-core',
  'spz-hud',        -- draws the garage and tuner pages
  'oxmysql',
}
