fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
description 'HUNT — native ambient temperature and clothing thermal comfort'
version '1.0.0'
shared_scripts { 'config.lua', 'shared/thermal.lua' }
client_script 'client/main.lua'
server_script 'server/main.lua'
dependencies { 'thehunt_items', 'thehunt_status', 'thehunt_animations', 'thehunt_character' }
