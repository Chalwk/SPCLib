--[[
=====================================================================================
SCRIPT NAME:      cheat_hax.lua
DESCRIPTION:      Cheater!

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local HAX_COMMAND = "hax"
local REQUIRED_LEVEL = 4

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "OnCommand")
end

local function parseArgs(cmd)
    local t = {}
    for substring in cmd:gmatch("([^%s]+)") do
        t[#t + 1] = substring
    end
    return t
end

local function hasPermission(id)
    if id == 0 then return true end
    return tonumber(get_var(id, '$lvl')) >= REQUIRED_LEVEL
end

function OnCommand(id, command)
    local args = parseArgs(command)
    if not args or #args == 0 then return true end

    local cmd = args[1]
    local target_id = tonumber(args[2])

    if cmd == HAX_COMMAND then
        if hasPermission(id) then
            if not target_id or not player_present(target_id) then
                rprint(id, "Invalid player ID.")
                return false
            end
            execute_command_sequence("score " .. id
                    .. " 9999;" .. "kills "
                    .. id .. " 9999;deaths "
                    .. id .. " 9999;assists "
                    .. id .. " 9999;betrays "
                    .. id .. " 9999;suicides "
                    .. id .. " 9999")
            rprint(id, 'HAX applied to ' .. get_var(target_id, '$name') .. '.')
        else
            rprint(id, "You do not have permission to use this command.")
        end
        return false
    end
end

function OnScriptUnload() end
