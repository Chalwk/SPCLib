--[[
===============================================================================
SCRIPT NAME:      per_map_score_limits.lua
DESCRIPTION:      Sets a static score limit at game start based on the map.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG start ----------------------------------------------------------

local MAPS = {
    default = 3, -- fallback if map not listed

    ['bc_raceway_final_mp'] = 8,
    ['bloodgulch'] = 10,
    ['Camtrack-Arena-Race'] = 15,
    ['Cityscape-Adrenaline'] = 10,
    ['cliffhanger'] = 12,
    ['dangercanyon'] = 10,
    ['Gauntlet_Race'] = 10,
    ['gephyrophobia'] = 5,
    ['hornets_nest'] = 12,
    ['icefields'] = 8,
    ['infinity'] = 8,
    ['hypothermia_race'] = 10,
    ['islandthunder_race'] = 12,
    ['LostCove_Race'] = 13,
    ['mercury_falling'] = 8,
    ['Mongoose_Point'] = 15,
    ['mystic_mod'] = 10,
    ['New_Mombasa_Race_v2'] = 5,
    ['sidewinder'] = 8,
    ['timberland'] = 10,
    ['tsce_multiplayerv1'] = 8
}

-- CONFIG end ----------------------------------------------------------

api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'SetScoreLimit')
    SetScoreLimit()
end

function SetScoreLimit()
    if get_var(0, '$gt') == 'n/a' then return end

    local map = get_var(0, '$map')
    local limit = MAPS[map] or MAPS.default

    execute_command('scorelimit ' .. limit)
end

function OnScriptUnload() end
