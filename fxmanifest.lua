fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'YShop'
author 'TrolekGaming'
version '1.0'
description 'Skrypt integracyjny platformy YShop'

server_scripts {
    'config.lua',
    '@oxmysql/lib/MySQL.lua',
	'server/main.lua'
}

dependency "oxmysql"