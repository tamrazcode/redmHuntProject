games { 'rdr3' }
lua54 'yes'
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Dietrich'
description 'RedM Crash Logger'
version '1.0.0'

client_scripts {
    'bootstrap.lua',  
  }
  server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/crash_logger.lua',
    'server/*.lua'
  }
dependency '/assetpacks'