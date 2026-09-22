fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'HUNT Core Team'
description 'HUNT character unconsciousness system'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_script 'config.lua'

client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'oxmysql',
    'vorp_core'
}
