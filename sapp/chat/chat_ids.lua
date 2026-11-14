--[[
===============================================================================
SCRIPT NAME:      chat_ids.lua
DESCRIPTION:      Enhances chat visibility by displaying player slot numbers.

                  - Appends player IDs to all chat messages
                  - Works in both global, vehicle and team chat
                  - Preserves existing chat functionality

Copyright (c) 2014-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START ----------------------------------------------------------------------

-- Chat message format by chat type:
-- 0 = Global, 1 = Team, 2 = Vehicle
local CHAT_FORMATS = { [0] = "$name [$id]: $msg", [1] = "[$name] [$id]: $msg", [2] = "[$name] [$id]: $msg" }

-- The script temporarily removes the "msg_prefix" and restores
-- it to this when its broadcast relay is done:
local SERVER_PREFIX = "**SAPP**"

-- CONFIG END ------------------------------------------------------------------------

local function isChatCommand(message)
    local first = string.sub(message, 1, 1)
    return first == "/" or first == "\\"
end

local function formatMessage(template, values)
    return (string.gsub(template, "%$(%w+)", function (key)
        return values[key] or "$" .. key
    end))
end

local function broadcast(chat_type, message, team)
    if chat_type == 0 then
        say_all(message)
        return
    end

    for i = 1, 16 do
        if player_present(i) and get_var(i, "$team") == team then
            say(i, message)
        end
    end
end

function OnChat(player_id, message, chat_type)
    if isChatCommand(message) then return true end

    local template = CHAT_FORMATS[chat_type]
    if not template then return true end

    local formatted = formatMessage(template, {
        name = get_var(player_id, "$name"),
        id   = player_id,
        msg  = message
    })

    execute_command('msg_prefix ""')
    broadcast(chat_type, formatted, get_var(player_id, "$team"))
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')

    return false
end

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnChat")
end

function OnScriptUnload() end
