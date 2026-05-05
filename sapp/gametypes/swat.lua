--[[
=====================================================================================
SCRIPT NAME:      swat.lua
DESCRIPTION:      Tactical SWAT game mode featuring:
                  - Precision-based headshot-only kills
                  - Restricted weapon loadout (pistol + sniper rifle)
                  - Competitive 25-kill victory condition (configurable)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start -------------------------------------------------------

-- Set to false to disable infinite ammo:
local INFINITE_AMMO = true

-- Set to false to disable bottomless clip:
local BOTTOMLESS_CLIP = true

-- Set to false to enable grenades:
local DISABLE_GRENADES = true

-- Set the default score limit:
local SCORE_LIMIT = 25

-- Items in this list will have disabled interaction (except pistol and sniper rifle)
-- Remove an item to enable it.
local BLOCK_ITEMS = {
    'powerups\\health pack',
    'powerups\\over shield',
    'powerups\\active camouflage',

    'weapons\\frag grenade\\frag grenade',
    'weapons\\plasma grenade\\plasma grenade',

    'weapons\\shotgun\\shotgun',
    'weapons\\needler\\mp_needler',
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

local pistol, sniper

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
    pistol = getTag('weap', 'weapons\\pistol\\pistol')
    sniper = getTag('weap', 'weapons\\sniper rifle\\sniper rifle')
    execute_command('scorelimit ' .. SCORE_LIMIT)
    ManageMapObjects()
end

function OnEnd()
    ManageMapObjects(true)
end

function UpdateAmmo(id)
    if INFINITE_AMMO then
        execute_command('ammo ' .. id .. ' 999 5')
    end
    if BOTTOMLESS_CLIP then
        execute_command('mag ' .. id .. ' 999 5')
    end
    if DISABLE_GRENADES then
        execute_command('nades ' .. id .. ' 0')
    end
end

function OnSpawn(id)
    if pistol and sniper then
        execute_command('wdel ' .. id)
        assign_weapon(spawn_object('', '', 0, 0, 0, 0, pistol), id)
        assign_weapon(spawn_object('', '', 0, 0, 0, 0, sniper), id)
        UpdateAmmo(id)
    end
end

function OnDamage(victim_id, killer_id, _, damage, hit_string)
    killer_id = tonumber(killer_id)
    victim_id = tonumber(victim_id)

    if killer_id > 0 and killer_id ~= victim_id and hit_string == 'head' then
        return true, damage * 100
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_ALIVE'], 'UpdateAmmo')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDamage')
    OnStart() -- in case script is loaded mid-game
end

function OnScriptUnload()
    ManageMapObjects(true)
end
