--[[
=====================================================================================
SCRIPT NAME:      auto_message.lua
DESCRIPTION:      Automaticlly broadcast messages to the chat.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/HALO-SCRIPT-PROJECTS/blob/master/LICENSE
=====================================================================================
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

local INTERVAL = 180   -- seconds (default: 180)
local CONSOLE = false  -- console output
-- CONFIG end -----------------------------------------

local index = 1
local message_timer

function GetRequiredVersion() return 200 end

function Broadcast()
    local messages = ANNOUNCEMENTS[index]
    if type(messages) == "string" then messages = { messages } end

    for i = 1, #messages do
        local msg = messages[i]
        if CONSOLE then respond(msg) end
        say(msg)
    end

    index = (index % #ANNOUNCEMENTS) + 1
    return true
end

local function remove_timer()
    if message_timer then
        removetimer(message_timer)
        message_timer = nil
    end
end

function OnScriptLoad()
    remove_timer()
    message_timer = registertimer(1000 * INTERVAL, "Broadcast")
end

function OnScriptUnload() remove_timer() end

function OnGameEnd() remove_timer() end
