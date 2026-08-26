fx_version 'cerulean'
game 'gta5'

name 'spz-vehicles'
description 'SPiceZ-Core — Vehicle registry, spawn, upgrades, customization'
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
  'server/freeroam_spawn.lua',
  'server/race_spawn.lua',
  'server/poll_pool.lua',
}

client_scripts {
  'client/main.lua',
  'client/classify.lua',
  'client/validate.lua',
  'client/spawn.lua',
  'client/despawn.lua',
  'client/upgrades.lua',
  'client/customization.lua',
  'client/commands.lua',
}

dependencies {
  'ox_lib',
  'spz-core',
  'spz-identity',
  'oxmysql',
}
