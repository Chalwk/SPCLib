--[[
===============================================================================
SCRIPT NAME:      dynamic_score_limit.lua
DESCRIPTION:      Automatically adjusts score limits based on player count with
                  cstom configurations for each game type, team vs FFA mode
                  differentiation and dynamic message formatting.

Copyright (c) 2022-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG start ---------------------------------------------------------------------

local config = {
    -- Messages can use the following variables:
    -- %s  = the new score limit
    -- %s  = pluralization character for laps/minutes

    -- Example format: { min_players, max_players, score_limit }

    -- Custom game mode score limits:
    game_modes = {
        ['example_game_mode'] = {
            { 1,  4,  25 },
            { 5,  8,  35 },
            { 9,  12, 45 },
            { 13, 16, 50 },
            'Score limit changed to: %s'
        },
        ['another_example_game_mode'] = {
            { 1,  4,  25 },
            { 5,  8,  35 },
            { 9,  12, 45 },
            { 13, 16, 50 },
            'Score limit changed to: %s'
        },
    },

    -- Default game type score limits:
    default_modes = {
        ctf = {
            { { 1, 4, 1 }, { 5, 8, 2 }, { 9, 12, 3 }, { 13, 16, 4 }, 'Score limit changed to: %s' }
        },
        slayer = {
            { -- Free-for-All:
                { 1, 4, 15 }, { 5, 8, 25 }, { 9, 12, 45 }, { 13, 16, 50 }, 'Score limit changed to: %s'
            },
            { -- Team Slayer:
                { 1, 4, 25 }, { 5, 8, 35 }, { 9, 12, 45 }, { 13, 16, 50 }, 'Score limit changed to: %s'
            }
        },
        king = {
            { -- Free-for-All:
                { 1, 4, 2 }, { 5, 8, 3 }, { 9, 12, 4 }, { 13, 16, 5 }, 'Score limit changed to: %s minute%s'
            },
            { -- Team King:
                { 1, 4, 3 }, { 5, 8, 4 }, { 9, 12, 5 }, { 13, 16, 6 }, 'Score limit changed to: %s minute%s'
            }
        },
        oddball = {
            { -- Free-for-All:
                { 1, 4, 2 }, { 5, 8, 3 }, { 9, 12, 4 }, { 13, 16, 5 }, 'Score limit changed to: %s minute%s'
            },
            { -- Team Oddball:
                { 1, 4, 3 }, { 5, 8, 4 }, { 9, 12, 5 }, { 13, 16, 6 }, 'Score limit changed to: %s minute%s'
            }
        },
        race = {
            { -- Free-for-All:
                { 1, 4, 4 }, { 5, 8, 4 }, { 9, 12, 5 }, { 13, 16, 6 }, 'Score limit changed to: %s lap%s'
            },
            { -- Team Race:
                { 1, 4, 4 }, { 5, 8, 5 }, { 9, 12, 6 }, { 13, 16, 7 }, 'Score limit changed to: %s lap%s'
            }
        }
    }
}

-- CONFIG end ---------------------------------------------------------------------

api_version = "1.12.0.0"

local fmt = string.format
local game_modes = config.game_modes
local default_modes = config.default_modes

local score_table, current_limit

local function announce_change(limit)
    local message = score_table and score_table[#score_table] or 'Score limit changed to: %s'

    local msg = fmt(message, limit, limit ~= 1 and 's' or '')
    say_all(msg); cprint(msg)
end

local function resolve_default_rules(game_type, ffa)
    local modes = default_modes[game_type]
    if not modes then return nil end

    return modes[2] and (ffa and modes[1] or modes[2]) or modes[1]
end

local function resolve_rules()
    local mode = get_var(0, '$mode')
    local rules = game_modes[mode]
    if rules then return rules end

    local game_type = get_var(0, '$gt')
    if game_type == 'n/a' then return nil end

    return resolve_default_rules(game_type, get_var(0, '$ffa') == '1')
end

local function get_player_count(quit_flag)
    local count = tonumber(get_var(0, '$pn')) or 0
    if quit_flag then count = count - 1 end
    return count > 0 and count or 0
end

local function find_limit(player_count)
    if not score_table then return nil end

    for i = 1, #score_table - 1 do
        local range = score_table[i]
        local min_players, max_players, limit = unpack(range)
        if player_count >= min_players and player_count <= max_players then
            return limit
        end
    end
end

local function change_score_limit(quit_flag)
    if not score_table then return end

    local player_count = get_player_count(quit_flag)
    local limit = find_limit(player_count)

    if limit and limit ~= current_limit then
        current_limit = limit
        execute_command('scorelimit ' .. limit)
        announce_change(limit)
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    score_table, current_limit = resolve_rules(), nil
    change_score_limit()
end

function OnEnd() score_table, current_limit = nil, nil end

function OnJoin() change_score_limit() end

function OnQuit() change_score_limit(true) end

function OnScriptUnload() end
