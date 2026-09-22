fx_version "cerulean"
game "rdr3"
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."

author "Emistery"
description "Strawberry Blue House"
version "1.0.0"
lua54 "yes"
this_is_a_map "yes"


client_scripts {'load_unload_interior.lua'}

files {'blue_house_timecycle.xml'}

data_file "TIMECYCLEMOD_FILE" "blue_house_timecycle.xml"
dependency '/assetpacks'
dependency '/assetpacks-redm'