fx_version 'cerulean'
game 'gta5'

name 'spz-vehicles'
description 'SPiceZ-Core — Vehicle registry, spawn, upgrades, customization'
version '2.0.0'
author 'SPiceZ-Core'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/classes.lua',
  'shared/classify.lua',
  'shared/upgrades.lua',
  'shared/events.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config.lua',
  'data/vehicles.lua',
  'server/main.lua',
  'server/classify.lua',
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
  'client/classify.lua',
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
