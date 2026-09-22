fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
version '4.0.0'
description 'HUNT VFX: server-owned scenes and cancellable visual effects'
shared_scripts { 'config.lua', 'data/sources.lua', 'shared/core.lua', 'shared/tracks.lua', 'shared/composition.lua' }
client_scripts { 'client/runtime.lua', 'client/preview.lua', 'client/studio.lua' }
server_scripts { 'server/main.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/workspace.js', 'html/workspace.css', 'html/bones.css', 'html/workflow.js', 'html/workflow.css', 'html/advanced.js', 'html/advanced.css' }
dependencies { 'thehunt_core', 'thehunt_status' }
