-- atmdui: a DUI ATM (the ATM's own screen, a camera at the keypad) on WHIP's bank.
-- Ported to WHIP from osm-atmdui by osmfxmods.com (https://github.com/OsmFX-Mods/osm-atmdui), CC BY-NC-SA 4.0 (LICENSE.md):
-- this port is under the same licence, keeps the author's credit, and may not be sold.
-- Changes for WHIP are listed in README.md.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'atmdui'
description 'DUI ATM on the WHIP framework (port of osm-atmdui)'
author 'osmfxmods.com (original); WHIP port'
version '1.1.0-whip'
whip_updates 'fozenistaken/whip-atmdui'   -- whip_core checks GitHub's latest release and says when a newer one is out

dependency 'whip_core'
whip_requires '1.0'

shared_scripts {
    '@whip_core/lib/satellite.lua',   -- Whip.register, Whip.core, Whip.configPage
    'config.lua',
    'shared/settings.lua',            -- the money and PIN settings in /whip -> Settings -> ATM
}

client_scripts {
    'client/dui.lua',
    'client/camera.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- The ATM screen is a DUI page; the receipt view opens it as the NUI page too
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/*.ogg',
    'html/img/items/*.webp',
}
