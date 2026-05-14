--[[
===============================================================================
SCRIPT NAME:      delay_skip.lua
DESCRIPTION:      Prevents premature map skipping by enforcing:
                  - A configurable minimum wait time before skipping a map.
                  - Level-based immunity for admins and staff.
                  - Feedback message for players attempting to skip too early.

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config start --------------------------------------------------------

-- Minimum delay (in seconds) before players are allowed to use 'skip'.
-- For example, if SKIP_DELAY = 300, players must wait 5 minutes.
local SKIP_DELAY = 300

-- Message displayed when a player tries to skip too early.
-- %s placeholders are replaced with the remaining time and plural suffix.
local DELAY_MESSAGE = 'Please wait %s second%s before skipping the map.'

-- Player levels that are immune to the skip delay restriction.
-- Keys correspond to admin levels (1-4 = admins).
local IMMUNE_LEVELS = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true
}
-- Config ends ---------------------------------------------------------

api_version = "1.12.0.0"

local start_time
local format = string.format
local os_time, math_ceil = os.time, math.ceil

local function plural(n)
    return n > 1 and 's' or ''
end

local function immune(id)
    return IMMUNE_LEVELS[tonumber(get_var(id, '$lvl'))]
end

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, 'OnChat')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
end

function OnChat(id, msg)
    if start_time and msg:lower() == 'skip' then
        if immune(id) then return true end

        local remaining = math_ceil(start_time + SKIP_DELAY - os_time())
        if remaining > 0 then
            rprint(id, format(DELAY_MESSAGE, remaining, plural(remaining)))
            return false
        end
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    start_time = os_time()
end

function OnEnd()
    start_time = nil
end

function OnScriptUnload() end
