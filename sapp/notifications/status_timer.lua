--[[
=====================================================================================
SCRIPT NAME:      status_timer.lua
DESCRIPTION:      Periodically displays current player count in server console.

FEATURES:
                  - Configurable update interval (default: 3 seconds)
                  - Displays current/max player count ratio
                  - Lightweight background operation
                  - Color-formatted console output

CONFIGURATION:
                  interval = 3  -- Update frequency in seconds

USAGE:
                  Simply load the script - no commands needed
                  Output format: "Players: X/Y" (current/max)

Copyright (c) 2024 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Specify the interval to print the number of players (in seconds)
local interval = 3
api_version = "1.12.0.0"

-- Event handlers
function OnScriptLoad()
    register_callback(cb["EVENT_GAME_START"], "OnStart")
    -- Call OnStart to initialize the script on load
    OnStart()
end

-- Prints the current number of players in the console
function StatusTimer()
    local currentPlayers = tonumber(get_var(0, "$pn"))
    local maxPlayers = read_word(0x4029CE88 + 0x28)
    cprint(string.format("Players: %d/%d", currentPlayers, maxPlayers), 10)
    return true
end

-- Starts the timer to periodically print the number of players
function OnStart()
    if (get_var(0, "$gt") ~= "n/a") then
        timer(interval * 1000, "StatusTimer")
    end
end

function OnScriptUnload()
    -- N/A
end