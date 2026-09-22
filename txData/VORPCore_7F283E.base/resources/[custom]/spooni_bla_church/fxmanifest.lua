fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'
this_is_a_map 'yes'
use_experimental_fxv2_oal 'yes'

author 'Spooni'
description 'Blackwater Church'
version '2'

server_scripts {
  'server/*.lua',
}

client_scripts {
	'shared/int_bla_church.lua',
	'client/*.lua',
}

files {
  'timecycle_bla_church_1.xml',
}

data_file 'TIMECYCLEMOD_FILE' 'timecycle_bla_church_1.xml'

escrow_ignore {
  'stream/*.ydr',   -- Ignore all .ydr
  'shared/int_bla_church.lua',
}

dependency '/assetpacks'