--[[
=====================================================================================
SCRIPT NAME:      restart_mapcycle.lua
DESCRIPTION:      Automatically restarts the map cycle when server becomes empty.

FEATURES:
                  - Restarts map cycle after configurable delay
                  - Cancels restart if players rejoin
                  - Resets timer on game end
                  - Lightweight and efficient implementation

CONFIGURATION:
                  delay:            Time (in seconds) to wait before restarting
                                    map cycle when empty (default: 120)

USAGE:
                  Simply load the script - no commands needed
                  Adjust the 'delay' variable to change wait time

BEHAVIOR:
                  - Triggers when last player leaves
                  - Counts down from specified delay
                  - Cancels if any player joins during countdown
                  - Executes 'mapcycle_begin' when timer completes

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--
-- Map cycle will restart after this many seconds when the server is empty:
--
local delay = 120

local timer
local time = os.time

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'Cancel')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_END, 'Cancel')
end

local function NewTimer()
    return {
        start = time,
        finish = time() + delay
    }
end

function OnTick()
    if (timer and timer.start() >= timer.finish) then
        execute_command('mapcycle_begin')
    end
end

function OnQuit()
    local total = tonumber(get_var(0, '$pn')) - 1
    timer = (total == 0) and NewTimer() or nil
end

function Cancel()
    timer = nil
end

function OnScriptUnload()
    -- N/A
end