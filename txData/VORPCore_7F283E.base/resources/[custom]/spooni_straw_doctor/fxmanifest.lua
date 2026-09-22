fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'
this_is_a_map 'yes'
use_experimental_fxv2_oal 'yes'

author 'Spooni'
description 'Spooni Strawberry Doctor'

client_scripts {
	'shared/*.lua',
	"client/*.lua",
}

escrow_ignore {
	'shared/*.lua',
}


files {'timecycle_straw_doctor.xml'}

data_file "TIMECYCLEMOD_FILE" "timecycle_straw_doctor.xml"

dependency '/assetpacks'
dependency '/assetpacks-redm'