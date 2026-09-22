rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

fx_version "adamant"
games { "rdr3" }
lua54 "yes"
author "wasvendel"
version "1.0.1"
description "wasvendel_pedmenu - Ped selection menu with preview and outfit variations"

escrow_ignore {
    "config.lua",
    "client.lua",
    "server.lua",
    "data/peds_list.lua",
}

shared_scripts {
    "config.lua",
}

client_scripts {
    "data/peds_list.lua",
    "client.lua",
}

server_scripts {
    "server.lua",
}

ui_page "ui/index.html"

files {
    "ui/index.html",
    "ui/style.css",
    "ui/script.js",
    "ui/crock.ttf",
}

dependency '/assetpacks'
dependency '/assetpacks-redm'