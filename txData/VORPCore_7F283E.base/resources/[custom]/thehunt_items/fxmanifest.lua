fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'HUNT: Hard RP — Core Items & Drops System'
version '1.0.0'

shared_scripts {
    'shared/insulation.lua',
    'shared/items.lua',
    'shared/backpack.lua'
}

client_scripts {
    'client/main.lua',
    'client/campfire.lua',
    'client/waterpump.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/backpack_sync.lua',
    'server/main.lua',
    'server/campfire.lua',
    'server/waterpump.lua'
}

dependencies {
    'thehunt_interact',
    'oxmysql'
}

