-- spz-vehicles fxmanifest
fx_version 'cerulean'
game 'gta5'

description 'SPZ Vehicles'
version '1.0.0'

dependencies {
    'spz-lib',
    'spz-identity',
    'oxmysql'
}

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'data/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}
