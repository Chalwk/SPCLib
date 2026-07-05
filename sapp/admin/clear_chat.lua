--[[
===============================================================================
SCRIPT NAME:      clear_chat.lua
DESCRIPTION:      Provides admin command to clear in-game chat.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]
-- CONFIG START ----------------------
api_version = "1.12.0.0"

local COMMAND = "clear"
local PERMISSION_LEVEL = 1
-- CONFIG END ------------------------

local function send(id, msg)
    return (id == 0 and cprint(msg) or rprint(id, msg))
end

local function is_admin(id)
    local lvl = tonumber(get_var(id, '$lvl'))
    return id == 0 or lvl >= PERMISSION_LEVEL
end

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "OnCommand")
end

function OnCommand(id, cmd)
    if cmd:lower() == COMMAND then
        if is_admin(id) then
            for _ = 1, 20 do
                say_all(" ")
            end
            send(id, "Chat was cleared")
        else
            send(id, 'Insufficient Permission')
        end
        return false
    end
end

function OnScriptUnload() end
