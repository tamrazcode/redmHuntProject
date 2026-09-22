fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'thehunt_character'
description 'HUNT: Hard RP — Standalone Character Creation & Selection System'
author 'DeepMind & HUNT Team'
version '1.0.0'

dependencies {
    'oxmysql',
    'thehunt_core'
}

shared_scripts {
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/hairs.lua',
    'shared/clothing.lua',
    'config/config.lua',
    'config/appearance_data.lua',
    'config/overlays_data.lua',
    'config/hairs_data.lua',
    'config/clothing_data.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/admin.lua',
    'server/code_generator.lua',
    'server/migration.lua',
    'server/validation.lua',
    'server/characters.lua',
    'server/main.lua'
}

client_scripts {
    'client/camera.lua',
    'client/appearance.lua',
    'client/clothing.lua',
    'client/preview.lua',
    'client/creator.lua',
    'client/selection.lua',
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/css/creator.css',
    'html/css/selection.css',
    'html/js/controls.js',
    'html/js/creator.js',
    'html/js/selection.js',
    'html/js/app.js'
}
