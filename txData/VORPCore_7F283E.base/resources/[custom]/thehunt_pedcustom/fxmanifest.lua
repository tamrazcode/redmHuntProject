fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
description 'HUNT admin ped library and in-world customization'
dependencies { 'thehunt_core', 'thehunt_character', 'thehunt_items', 'oxmysql' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'equipment.lua', 'server.lua' }
client_scripts {'spirits.lua', 'client.lua'}
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'data/models.json' }
