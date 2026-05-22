--[[
===============================================================================
SCRIPT NAME:      auto_message.lua
DESCRIPTION:      Automated rotating message system that broadcasts:
                  - Scheduled announcements to all players
                  - Multi-line messages
                  - Optional console output for monitoring
                  - Customizable interval

LAST UPDATED:     22 May 2026

Copyright (c) 2024-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG start -----------------------------------------
local ANNOUNCEMENTS = {
    { 'Multi-Line Support | Message 1, line 1', 'Message 2, line 2' },
    { 'Like us on Facebook | facebook.com/page_id' },
    { 'Follow us on Twitter | twitter.com/twitter_id' },
    { 'We are recruiting. Sign up on our website | website url' },
    { 'Rules / Server Information' },
    { 'Announcement 6' },
    { 'Other information here' },
}

local INTERVAL = 180      -- Interval in seconds
local CONSOLE = false     -- Console output
local PREFIX = ""         -- Message prefix
local START_OVER = true   -- Restart from beginning of ANNOUNCEMENTS when a new game begins (false to disable)
-- CONFIG end -----------------------------------------

api_version = '1.12.0.0'

local index = 1
local game_active = false

function OnScriptLoad()
    timer(1000 * INTERVAL, "BroadcastAnnouncement")
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart() -- in case script is loaded mid-game
end

function BroadcastAnnouncement()
    if game_active then
        local announcement = ANNOUNCEMENTS[index]
        execute_command('msg_prefix ""')
        for _, message in ipairs(announcement) do
            if CONSOLE then cprint(message) end
            say_all(message)
        end
        execute_command('msg_prefix "' .. PREFIX .. '"')
        index = (index % #ANNOUNCEMENTS) + 1
    end
    return true
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    index = START_OVER and 1 or index;
    game_active = true
end

function OnEnd() game_active = false end

function OnScriptUnload() end
