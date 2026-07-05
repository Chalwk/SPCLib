--[[
=====================================================================================
SCRIPT NAME:      idle_reminder.lua
DESCRIPTION:      Displays a reminder if you haven't moved for a while.

                  Command: /idle - Toggle idle reminder

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "idle"
local IDLE_TICKS = 500
-- END CONFIG --

local last_x, last_y, last_z
local timer = 0

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

function OnTick()
    if not ENABLED then return end

    local player = get_dynamic_player()
    if not player then return end

    local x = read_float(player + 0x5C)
    local y = read_float(player + 0x60)
    local z = read_float(player + 0x64)

    if x == last_x and y == last_y and z == last_z then
        timer = timer + 1
    else
        timer = 0
    end

    last_x, last_y, last_z = x, y, z

    if timer >= IDLE_TICKS then
        hud_message("You there?")
        timer = 0
    end
end

function OnCommand(cmd)
    if cmd:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Idle reminder " .. (ENABLED and "ENABLED." or "disabled."))
        return false
    end
end
