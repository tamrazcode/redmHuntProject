fx_version "cerulean"
game "rdr3"
lua54 "yes"

rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."

author "HardHit"
description "Мозгэ хочетца зомбэ. Зомби скрипт, даёт задавать зоны или использовать уже готовые для спавна зомбей"

shared_scripts {
    "config.lua",
    "config_zones.lua",
}

dependency "oxmysql"
dependency "xsound"
dependency "vorp_core"
dependency "vorp_admin"

client_scripts {
    "@vorp_admin/client/datapeds.lua",
    "client/main.lua",
    "client/editor.lua",
}
server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/main.lua",
}

ui_page "html/index.html"

files {
    "html/index.html",
    "html/audio.js",
    "html/editor.css",
    "html/editor.js",
    "sound/dead.ogg",
    "sound/dead2.ogg",
    "sound/defolt.ogg",
    "sound/defolt2.ogg",
}
