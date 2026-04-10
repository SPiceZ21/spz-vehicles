fx_version 'cerulean'
game 'gta5'

name 'spz-vehicles'
description 'SPiceZ-Core — Vehicle registry, spawn, upgrades, customization'
version '1.0.0'
author 'SPiceZ-Core'

shared_scripts {
  '@spz-lib/shared/main.lua',
  '@spz-lib/shared/callbacks.lua',
  '@spz-lib/shared/notify.lua',
  '@spz-lib/shared/timer.lua',
  '@spz-lib/shared/logger.lua',
  '@spz-lib/shared/math.lua',
  '@spz-lib/shared/table.lua',
  '@spz-lib/shared/string.lua',
  'shared/classes.lua',
  'shared/upgrades.lua',
  'shared/events.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config.lua',
  'data/vehicles.lua',
  'server/main.lua',
  'server/registry.lua',
  'server/spawn.lua',
  'server/upgrades.lua',
  'server/customization.lua',
  'server/freeroam_spawn.lua',
  'server/race_spawn.lua',
  'server/poll_pool.lua',
}

client_scripts {
  'client/main.lua',
  'client/spawn.lua',
  'client/despawn.lua',
  'client/upgrades.lua',
  'client/customization.lua',
  'client/commands.lua',
}

dependencies {
  'spz-lib',
  'spz-core',
  'spz-identity',
  'oxmysql',
}
