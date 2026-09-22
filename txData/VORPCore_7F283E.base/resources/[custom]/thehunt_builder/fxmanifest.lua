fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'HUNT: Hard RP — The Corruption World Builder & Object Placer'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/raycast.lua',
    'client/preview.lua',
    'client/streamer.lua',
    'client/main.lua'
}

server_scripts {
    'server/db.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/catalogs_data.js',
    'html/app.js',
    'html/props_catalog.json',
    'html/peds_catalog.json',
    'html/vehicles_catalog.json',
    'html/scenarios_catalog.json'
}

dependencies {
    'oxmysql'
}
