fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'HUNT Core Team'
description 'HUNT: Hard RP - Active Player Status, Buffs & Debuffs HUD System'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/db.lua',
    'server/main.lua'
}

exports {
    'AddEffect',
    'RemoveEffect',
    'HasEffect',
    'GetActiveEffects',
    'ClearAllEffects',
    'GetPlayerHealth',
    'GetPlayerStamina',
    'GetPlayerHunger',
    'GetPlayerThirst',
    'GetHorseHealth',
    'GetHorseStamina',
    'Notify',
    'notify'
}

server_exports {
    'AddPlayerEffect',
    'RemovePlayerEffect',
    'HasPlayerEffect'
}

dependencies {
    'oxmysql'
}
