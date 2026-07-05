--[[
===============================================================================
SCRIPT NAME:      countdown_timer.lua
DESCRIPTION:      Displays a customizable countdown to all players with:
                  - Configurable duration
                  - Formatted output message
                  - Automatic game state detection

FEATURES:
                  - Simple setup with minimal configuration
                  - Clears previous messages for better visibility
                  - Tracks game state (start/end)

CONFIGURATION:    Adjust these variables:
                  - delay: Countdown duration (seconds)
                  - output_msg: Display format string

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"
local delay = 5
local output_msg = "Game will begin in: %02d seconds"
local timer

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')

    OnStart() -- in case script is loaded mid-game
end

local function newTimer()
    return { start_time = os.time(), end_time = os.time() + delay }
end

function OnStart()
    timer = (get_var(0, '$gt') ~= 'n/a') and newTimer() or nil
end

function OnEnd()
    timer = nil
end

local function timeRemaining(seconds)
    return string.format(output_msg, seconds % 60)
end

local function Say(player_index, msg)
    for _ = 1, 25 do
        rprint(player_index, ' ')
    end
    rprint(player_index, msg)
end

function OnTick()
    if (timer) then
        if timer.start_time >= timer.end_time then
            timer = nil
        else
            for i = 1, 16 do
                if player_present(i) then
                    Say(i, timeRemaining(timer.end_time - os.time()))
                end
            end
        end
    end
end
