fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'HUNT: Hard RP — DayZ Grid Inventory'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    '@thehunt_items/shared/backpack.lua'
}

client_scripts {
    'client/main.lua',
    'client/backpack.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png',
    'html/fonts/*'
}

dependencies {
    'oxmysql',
    'thehunt_items',
    'thehunt_gizmo',
    'thehunt_status'
}
