fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'HUNT: Hard RP — The Corruption Core'
version '1.0.0'

ui_page 'html/admin_menu/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/framework_bridge.lua',
    'client/ring_renderer.lua',
    'client/world_cleaner.lua',
    'client/ui_blocker.lua',
    'client/voice_radius.lua',
    'client/testing_tools.lua',
    'client/admin_blips.lua',
    'client/overhead_ids.lua',
    'client/player_logs.lua',
    'client/admin_menu.lua',
    'client/chat_rp.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/admin_blips.lua',
    'server/player_logs.lua',
    'server/admin_menu.lua',
    'server/chat_rp.lua'
}

files {
    'html/admin_menu/index.html',
    'html/admin_menu/style.css',
    'html/admin_menu/app.js',
    'html/admin_menu/images/*.png'
}

dependencies {
    'oxmysql',
    'vorp_core',
    'chat'
}
