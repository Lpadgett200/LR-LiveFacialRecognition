fx_version 'cerulean'
game 'gta5'

dependencies { 'ox_lib', 'ox_target', 'screenshot-basic' }

shared_scripts { 'config.lua' }
ui_page 'web/dist/index.html'
files { 'web/dist/**/*' }
client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }
