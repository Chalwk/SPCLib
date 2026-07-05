--[[
===============================================================================
SCRIPT NAME:      weapon_assigner.lua
DESCRIPTION:      Custom weapon assignment system that automatically gives players
                  specific weapon loadouts based on map, game mode, and team.
                  - Configurable per map and game mode
                  - Team-specific weapon sets (Red, Blue, FFA)
                  - Supports both stock and custom game modes

LAST UPDATED:     7/10/2025

Copyright (c) 2024-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Configuration start --------------------------------------------------------
local weapon_tags = {
    -- stock weapon tags
    assault_rifle = 'weapons\\assault rifle\\assault rifle',
    flamethrower = 'weapons\\flamethrower\\flamethrower',
    gravity_rifle = 'weapons\\gravity rifle\\gravity rifle',
    needler = 'weapons\\needler\\mp_needler',
    pistol = 'weapons\\pistol\\pistol',
    plasma_cannon = 'weapons\\plasma_cannon\\plasma_cannon',
    plasma_pistol = 'weapons\\plasma pistol\\plasma pistol',
    plasma_rifle = 'weapons\\plasma rifle\\plasma rifle',
    rocket_launcher = 'weapons\\rocket launcher\\rocket launcher',
    shotgun = 'weapons\\shotgun\\shotgun',
    sniper = 'weapons\\sniper rifle\\sniper rifle',

    -- rev_sanctuary_cavebeta
    rev_assault_rifle = 'revolution\\weapons\\assault rifle\\revolution assault rifle',
    rev_battle_rifle = 'revolution\\weapons\\battle rifle\\battle_rifle',
    rev_carbine = 'revolution\\weapons\\carbine\\carbine',
    rev_grenade_launcher = 'revolution\\weapons\\grenade launcher\\nade_launcher',
    rev_needler = 'revolution\\weapons\\needler\\needler',
    rev_pistol = 'revolution\\weapons\\pistol\\rev pistol',
    rev_plasma_cannon = 'revolution\\weapons\\plasma cannon\\plasma_cannon',
    rev_plasma_pistol = 'revolution\\weapons\\plasma pistol\\plasma pistol',
    rev_plasma_rifle = 'revolution\\weapons\\plasma rifle\\plasma rifle',
    rev_rocket_launcher = 'revolution\\weapons\\rocket launcher\\rocket launcher',
    rev_shotgun = 'revolution\\weapons\\shotgun\\revolution shotgun',
    rev_smg = 'revolution\\weapons\\smg\\smg',
    rev_sniper = 'revolution\\weapons\\sniper\\revolution sniper',

    -- ivory_tower_final
    ivory_sniper = 'weapons\\sniper rifle\\cyclotron sniper rifle'
}

-- Format: maps[map_name][game_mode][team] = { { weapon1, weapon2, weapon3, weapon4 }, { frag_grenades, plasma_grenades } }
local maps = {
    ['destiny'] = {
        ['MOSH_PIT_FFA_SLAYER'] = {
            ffa = { { 'pistol', 'sniper' }, { 1, 1 } }
        }
    },
    ['graveyard'] = {
        ['MOSH_PIT_CTF'] = {
            red = { { 'pistol', 'sniper' }, { 1, 1 } },
            blue = { { 'pistol', 'sniper' }, { 1, 1 } }
        }
    },
    ['immure'] = {
        ['MOSH_PIT_CTF'] = {
            red = { { 'pistol', 'sniper' }, { 1, 1 } },
            blue = { { 'pistol', 'sniper' }, { 1, 1 } }
        }
    },
    ['ivory_tower_final'] = {
        ['MOSH_PIT_FFA_SLAYER'] = {
            ffa = { { 'pistol', 'ivory_sniper' }, { 1, 1 } }
        }
    },
    ['rev_sanctuary_cavebeta'] = {
        ['MOSH_PIT_TEAM_SLAYER'] = {
            red = { { 'rev_battle_rifle', 'rev_shotgun', 'rev_pistol', 'rev_rocket_launcher' }, { 2, 1 } },
            blue = { { 'rev_carbine', 'rev_sniper', 'rev_smg', 'rev_plasma_rifle' }, { 1, 2 } }
        }
    }
}
-- Configuration end ----------------------------------------------------------

api_version = '1.12.0.0'

local current_loadout = {}
local map_name, game_mode, is_ffa

local table_insert = table.insert
local pairs, ipairs = pairs, ipairs

local function getTagID(tag_path)
    local tag = lookup_tag('weap', tag_path)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function initialize()
    current_loadout = {}
    local config = maps[map_name]

    local mode_config = config and config[game_mode]
    if not mode_config then
        cprint(
            "Weapon Assigner: No configuration found for map '" .. map_name .. "' and mode '" .. game_mode .. "'", 12
        )
        return false
    end

    for team, loadout in pairs(mode_config) do
        local weapons = loadout[1]
        local grenades = loadout[2]

        current_loadout[team] = { weapons = {}, grenades = { frags = grenades[1], plasmas = grenades[2] } }

        for _, weapon_name in ipairs(weapons) do
            local tag_path = weapon_tags[weapon_name]
            if not tag_path then
                cprint("Weapon Assigner: Weapon '" .. weapon_name .. "' not found in weapon_tags table", 12)
                return false
            end

            local tag_id = getTagID(tag_path)
            if not tag_id then
                cprint(
                    "Weapon Assigner: Invalid weapon tag '" .. tag_path .. "' for weapon '" .. weapon_name .. "'", 12
                )
                return false
            end
            table_insert(current_loadout[team].weapons, tag_id)
        end
    end

    return true
end

function OnSpawn(id)
    if not player_alive(id) then return end -- just in case

    local team = is_ffa and 'ffa' or get_var(id, '$team')
    local loadout = current_loadout[team]
    if not loadout then return end

    execute_command("wdel " .. id)

    for i, tag_id in ipairs(loadout.weapons) do
        if i <= 4 then
            local weapon = spawn_object('', '', 0, 0, 0, 0, tag_id)
            if i <= 2 then
                assign_weapon(weapon, id)
            else
                timer(250, 'assign_weapon', weapon, id)
            end
        end
    end

    local grenades = loadout.grenades
    execute_command('nades ' .. id .. ' ' .. grenades.frags .. ' 1')
    execute_command('nades ' .. id .. ' ' .. grenades.plasmas .. ' 2')
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    map_name, game_mode, is_ffa = get_var(0, '$map'), get_var(0, '$mode'), get_var(0, '$ffa') == '1'

    if initialize() then
        register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    else
        unregister_callback(cb.EVENT_SPAWN)
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnScriptUnload() end
