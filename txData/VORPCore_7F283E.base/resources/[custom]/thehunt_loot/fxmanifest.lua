fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'HUNT: Hard RP — The Corruption Autonomous World Loot System'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@thehunt_items/shared/insulation.lua',
    '@thehunt_items/shared/items.lua',
    'config.lua',
    'shared/types.lua'
}

client_scripts {
    'client/streamer.lua',
    'client/interaction.lua',
    'client/editor/camera.lua',
    'client/editor/shapes.lua',
    'client/editor/zones.lua',
    'client/editor/main.lua',
    'client/api.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/validation.lua',
    'server/db.lua',
    'server/zones.lua',
    'server/loot_spawner.lua',
    'server/pickup.lua',
    'server/api.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'oxmysql',
    'thehunt_items'
}
