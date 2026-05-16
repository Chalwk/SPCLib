--[[
=====================================================================================
SCRIPT NAME:      show_player_position.lua
DESCRIPTION:      Display your map coordinates with customizable output.

                  Command: /show_pos - Toggle coordinate display

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "show_pos"
local OUTPUT = "Player position is X={x}, Y={y}, Z={z}"
-- END CONFIG --

local fmt = string.format

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

function OnTick()
    if not ENABLED then return end

    local player = get_dynamic_player()
    if player then
        local x = read_float(player + 0x5C)
        local y = read_float(player + 0x60)
        local z = read_float(player + 0x64)

        local xs = fmt("%.2f", x)
        local ys = fmt("%.2f", y)
        local zs = fmt("%.2f", z)

        local message = OUTPUT
            :gsub("{x}", xs)
            :gsub("{y}", ys)
            :gsub("{z}", zs)

        execute_script("cls")
        console_out(message)
    end
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Position display " .. (ENABLED and "ENABLED." or "disabled."))
        return false
    end
end
