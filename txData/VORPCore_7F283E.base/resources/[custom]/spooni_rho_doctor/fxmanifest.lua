fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'
this_is_a_map 'yes'
use_experimental_fxv2_oal 'yes'

author 'Spooni'
description 'Rhodes Doctor'
version '1'

server_scripts {
	'server/*.lua',
}

client_scripts {
	'shared/*.lua',
	"client/*.lua",
}

escrow_ignore {
	'stream/*.ydr',
	'stream/[props]/*.ydr',
	'shared/*.lua',
}

files {'timecycle_rho_doctor_1.xml'}

data_file "TIMECYCLEMOD_FILE" "timecycle_rho_doctor_1.xml"

dependency '/assetpacks'