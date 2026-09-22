fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
description 'HUNT — Мёртвые: network population, perception and zone editor'
version '1.0.0'
shared_scripts { 'shared/models.lua', 'config.lua', 'shared/definitions.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/spawn.lua', 'server/migration.lua', 'server/main.lua' }
client_scripts { 'client/runtime.lua', 'client/detection.lua', 'client/ai.lua', 'client/contact.lua', 'client/editor.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
dependencies { 'oxmysql', 'thehunt_core', '/onesync' }
