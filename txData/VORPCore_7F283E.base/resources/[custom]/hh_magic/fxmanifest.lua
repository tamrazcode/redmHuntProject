fx_version "cerulean"
game "rdr3"
lua54 "yes"

rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."

author "HardHit"
description "Magic scaffold: cast spells from inventory items"

shared_script "config.lua"
shared_script "shared/roots_fx_config.lua"

client_script "client/roots_fx.lua"
client_script "client/main.lua"
client_script "client/thorns.lua"
client_script "client/necro.lua"
client_script "client/raven.lua"
client_script "client/oath.lua"

server_script "server/main.lua"

ui_page "html/index.html"

files {
    "html/index.html",
    "html/style.css",
    "html/app.js",
    "html/card.png",
    "html/necro.png",
    "html/voron.png",
    "html/obet.png",
}

dependencies {
    "vorp_core",
    "thehunt_items",
    "thehunt_inventory",
}
