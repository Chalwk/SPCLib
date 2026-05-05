--[[
===============================================================================
SCRIPT NAME:      clear_chat.lua
DESCRIPTION:      Provides admin command to clear in-game chat:
                  - Removes all visible chat messages
                  - Works with SAPP's message system
                  - Admin permission controls

CONFIGURATION:    Customize in config table:
                  - command: Clear chat trigger
                  - permission_level: Required admin level
                  - prefix: Server message prefix

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Configuration
local config = {
    -- Custom command used to clear chat
    command = "clear",

    -- Minimum permission level required to execute the custom command
    permission_level = 1,

    -- A message relay function temporarily removes the server prefix
    -- and restores it to this when finished
    prefix = "**ADMIN**"
}

function OnScriptLoad()
    register_callback(cb['EVENT_COMMAND'], "OnCommand")
end

local function send(playerId, msg)
    return (playerId == 0 and cprint(msg) or rprint(playerId, msg))
end

local function isAdmin(playerId)
    local playerLevel = tonumber(get_var(playerId, '$lvl'))
    return (playerId == 0 or playerLevel >= config.permission_level)
end

function OnCommand(playerId, cmd)
    local lowerCaseCmd = cmd:sub(1, config.command:len()):lower()
    if (lowerCaseCmd == config.command) then
        if isAdmin(playerId) then
            execute_command('msg_prefix ""')
            for _ = 1, 20 do
                say_all(" ")
            end
            execute_command('msg_prefix "' .. config.prefix .. '"')
            send(playerId, "Chat was cleared")
        else
            send(playerId, 'Insufficient Permission')
        end
        return false
    end
end

function OnScriptUnload()
    -- N/A
end
