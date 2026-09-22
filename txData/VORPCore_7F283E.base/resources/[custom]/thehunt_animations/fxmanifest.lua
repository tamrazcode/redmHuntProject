fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'thehunt_animations'
description 'HUNT: Hard RP — Obsidian Animations & Emotes System'
author 'HUNT Team'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/exports.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'oxmysql'
}
