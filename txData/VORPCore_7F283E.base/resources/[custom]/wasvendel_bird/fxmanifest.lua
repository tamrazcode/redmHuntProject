rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

fx_version "adamant"
games {"rdr3"}
lua54 'yes'
author 'wasvendel'

description 'wasvendel_bird'

escrow_ignore {
  'config.lua',
  'client.lua',
}

client_scripts {
  'config.lua',
  'client.lua',
}

ui_page 'ui/index.html'

files {
  'ui/index.html',
  'ui/style.css',
  'ui/script.js',
  'ui/crock.ttf',
  'ui/img/bird_default.png',
  'ui/img/animals/*.png',
}

dependency '/assetpacks'