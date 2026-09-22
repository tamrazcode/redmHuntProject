fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'HUNT: Hard RP — Player to Player Interaction System'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'thehunt_interact',
    'thehunt_inventory'
}
