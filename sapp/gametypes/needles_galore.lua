--[[
=====================================================================================
SCRIPT NAME:      needles_galore.lua
DESCRIPTION:      Needles-only gameplay

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start -------------------------------------------------------

-- Set to false to disable infinite ammo:
local INFINITE_AMMO = true

-- Items in this list will have disabled interaction (except needler)
-- Remove an item to enable it.
local BLOCK_ITEMS = {
    'powerups\\health pack',
    'powerups\\over shield',
    'powerups\\active camouflage',

    'weapons\\frag grenade\\frag grenade',
    'weapons\\plasma grenade\\plasma grenade',

    'weapons\\pistol\\pistol',
    'weapons\\shotgun\\shotgun',
    'weapons\\sniper rifle\\sniper rifle',
    'weapons\\flamethrower\\flamethrower',
    'weapons\\plasma rifle\\plasma rifle',
    'weapons\\plasma_cannon\\plasma_cannon',
    'weapons\\assault rifle\\assault rifle',
    'weapons\\plasma pistol\\plasma pistol',
    'weapons\\rocket launcher\\rocket launcher',

    'vehicles\\ghost\\ghost_mp',
    'vehicles\\rwarthog\\rwarthog',
    'vehicles\\banshee\\banshee_mp',
    'vehicles\\warthog\\mp_warthog',
    'vehicles\\scorpion\\scorpion_mp',
    'vehicles\\c gun turret\\c gun turret_mp'
}
-- CONFIG end ---------------------------------------------------------

api_version = '1.12.0.0'

local needler

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function ManageMapObjects(enable)
    local cmd = enable and 'enable_object' or 'disable_object'
    for i = 1, #BLOCK_ITEMS do
        local tag_name = BLOCK_ITEMS[i]
        execute_command(cmd .. " '" .. tag_name .. "'")
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    needler = getTag('weap', 'weapons\\needler\\mp_needler')
    ManageMapObjects()
end

function OnEnd()
    ManageMapObjects(true)
end

function UpdateAmmo(id)
    if INFINITE_AMMO then
        execute_command('ammo ' .. id .. ' 999 5')
    end
end

function OnSpawn(id)
    execute_command('wdel ' .. id)
    assign_weapon(spawn_object('', '', 0, 0, 0, 0, needler), id)
end

function OnScriptLoad()
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_ALIVE, 'UpdateAmmo')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart() -- in case script is loaded mid-game
end

function OnScriptUnload()
    ManageMapObjects(true)
end
