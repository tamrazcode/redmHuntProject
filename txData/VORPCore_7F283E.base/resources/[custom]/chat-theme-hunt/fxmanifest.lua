-- This is HUNT: Hard RP custom chat theme
-- Overrides the default chat-theme-gtao style

version '1.0.0'
author 'Hunt HardRP'
description 'Dark post-apocalyptic chat theme for Hunt: The Corruption'

file 'style.css'

chat_theme 'hunt' {
    styleSheet = 'style.css',
    msgTemplates = {
        default = '<b>{0}</b><span>{1}</span>'
    }
}

game 'common'
fx_version 'adamant'
