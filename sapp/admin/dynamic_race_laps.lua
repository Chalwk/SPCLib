--[[
===============================================================================
SCRIPT NAME:      dynamic_race_laps.lua
DESCRIPTION:      Automatically adjusts lap score limit based on player count.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG start ----------------------------------------------------------

local SCORE_LIMIT_MESSAGE = 'Score limit changed to %s lap%s'

local MAPS = {
    default = {
        { 1,  4,  3 },
        { 5,  8,  6 },
        { 9,  12, 9 },
        { 13, 16, 12 }
    },

    -- Small technical tracks (high lap counts)
    ['bc_raceway_final_mp'] = {
        { 1,  4,  12 },
        { 5,  8,  15 },
        { 9,  12, 15 },
        { 13, 16, 15 }
    },

    ['Camtrack-Arena-Race'] = {
        { 1,  4,  12 },
        { 5,  8,  15 },
        { 9,  12, 15 },
        { 13, 16, 15 }
    },

    -- Medium-length tracks
    ['cliffhanger'] = {
        { 1,  4,  8 },
        { 5,  8,  12 },
        { 9,  12, 15 },
        { 13, 16, 15 }
    },

    ['islandthunder_race'] = {
        { 1,  4,  8 },
        { 5,  8,  12 },
        { 9,  12, 15 },
        { 13, 16, 15 }
    },

    ['LostCove_Race'] = {
        { 1,  4,  8 },
        { 5,  8,  12 },
        { 9,  12, 15 },
        { 13, 16, 15 }
    },

    -- Large/open maps (lower lap counts)
    ['bloodgulch'] = {
        { 1,  4,  5 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['sidewinder'] = {
        { 1,  4,  5 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['icefields'] = {
        { 1,  4,  5 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['infinity'] = {
        { 1,  4,  5 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    -- Very long tracks (minimal laps)
    ['gephyrophobia'] = {
        { 1,  4,  3 },
        { 5,  8,  5 },
        { 9,  12, 8 },
        { 13, 16, 10 }
    },

    ['New_Mombasa_Race_v2'] = {
        { 1,  4,  3 },
        { 5,  8,  5 },
        { 9,  12, 8 },
        { 13, 16, 10 }
    },

    -- Medium-to-long tracks
    ['dangercanyon'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['Gauntlet_Race'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['hypothermia_race'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['mercury_falling'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['Mongoose_Point'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['Cityscape-Adrenaline'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['mystic_mod'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['timberland'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    },

    ['tsce_multiplayerv1'] = {
        { 1,  4,  6 },
        { 5,  8,  8 },
        { 9,  12, 10 },
        { 13, 16, 12 }
    }
}

-- CONFIG end ----------------------------------------------------------

api_version = "1.12.0.0"

local score_table, current_limit

function OnScriptLoad()
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

local function announceChange(limit)
    say_all(string.format(SCORE_LIMIT_MESSAGE, limit, limit ~= 1 and 's' or ''))
end

local function changeScoreLimit(quitFlag)
    if not score_table then return end

    local player_count = tonumber(get_var(0, '$pn'))
    player_count = quitFlag and player_count - 1 or player_count

    for _, limit_data in ipairs(score_table) do
        local min, max, limit = unpack(limit_data)
        if player_count >= min and player_count <= max and limit ~= current_limit then
            current_limit = limit
            execute_command('scorelimit ' .. limit)
            announceChange(limit)
            return
        end
    end
end

function OnStart()
    current_limit = nil
    score_table = MAPS[get_var(0, '$map')] or MAPS.default
    changeScoreLimit()
end

function OnEnd() score_table, current_limit = nil, nil end

function OnJoin() changeScoreLimit() end

function OnQuit() changeScoreLimit(true) end

function OnScriptUnload() end
