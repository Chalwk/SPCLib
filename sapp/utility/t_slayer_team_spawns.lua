--[[
=====================================================================================
SCRIPT NAME:      t_slayer_team_spawns.lua
DESCRIPTION:      Enforces team-specific spawning in Team Slayer game modes by
                  restricting players to their team's designated spawn points.

FEATURES:
                  - Loads spawn points from scenario tag data
                  - Automatically activates only in Team Slayer games
                  - Randomly selects valid spawn points for each team
                  - Supports both Red and Blue team spawns

BEHAVIOR:
                  - Only activates in Team Slayer (non-FFA) games
                  - Players spawn at random locations from their team's spawn pool
                  - Automatically disables in non-team game modes

USAGE:
                  Simply load the script - no commands needed
                  Works automatically when Team Slayer is detected

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local spawns = {}
local insert = table.insert

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

local function load_spawns()
    spawns = { [0] = {}, [1] = {} }

    local tag_array = read_dword(0x40440000)
    local scenario_tag_index = read_word(0x40440004)
    local scenario_tag = tag_array + scenario_tag_index * 0x20
    local scenario_tag_data = read_dword(scenario_tag + 0x14)

    local starting_location_reflexive = scenario_tag_data + 0x354
    local starting_location_count = read_dword(starting_location_reflexive)
    local starting_location_address = read_dword(starting_location_reflexive + 0x4)

    for i = 0, starting_location_count do
        local starting_location = starting_location_address + 52 * i
        local x, y, z = read_vector3d(starting_location)
        local team = read_word(starting_location + 0x10)
        insert(spawns[team], { x = x, y = y, z = z })
    end
end

function OnStart()
    local gametype = get_var(0, '$gt')
    local ffa = get_var(0, '$ffa') == '1'

    if gametype == 'n/a' or ffa then
        unregister_callback(cb['EVENT_PRESPAWN'])
        return
    end

    load_spawns()
    register_callback(cb['EVENT_PRESPAWN'], 'PreSpawn')
end

function PreSpawn(id)
    local dyn = get_dynamic_player(id)
    if (dyn == 0) then return end

    local team = get_var(id, '$team') == 'red' and 0 or 1
    local pos = spawns[team][rand(1, #spawns[team] + 1)]
    write_vector3d(dyn + 0x5C, pos.x, pos.y, pos.z)
end

function OnScriptUnload() end
