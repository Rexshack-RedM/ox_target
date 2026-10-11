fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

name 'ox_target'
author 'Overextended (RedM / RSG port)'
version '3.0.0'
description 'Third-eye targeting for RedM, with RSG-Core group and item checks'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
    'server/versionchecker.lua',
}

files {
    'web/**',
    'locales/*.json',
    'client/api.lua',
    'client/utils.lua',
    'client/state.lua',
    'client/debug.lua',
    'client/framework/rsg.lua',
    'client/compat/qtarget.lua',
}

provide 'qtarget'

dependency 'ox_lib'
