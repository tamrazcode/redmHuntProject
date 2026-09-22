fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'HUNT: Hard RP — 3D Shape & Geometric Rendering Engine'
version '1.0.0'

client_scripts {
    'client/shapes.lua',
    'client/api.lua'
}

exports {
    'DrawSphere',
    'DrawDisk',
    'DrawHoop',
    'DrawBox',
    'DrawCylinder',
    'DrawAxis',
    'RegisterPersistentShape',
    'UpdatePersistentShape',
    'RemovePersistentShape',
    'ClearAllPersistentShapes'
}
