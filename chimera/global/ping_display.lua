--[[
=====================================================================================
SCRIPT NAME:      ping_display.lua
DESCRIPTION:      Displays your current ping in milliseconds on the HUD.

                  Command: /ping - Toggle ping display on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "ping"
local TEXT = "Ping: %s ms"
-- END CONFIG --

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

local function proceed(id)
    return ENABLED and id and server_type == "dedicated"
end

function OnTick()
    local id = get_player()
    if not proceed(id) then return end

    local ping = read_dword(id + 0xDC)

    for _ = 1, 10 do
        hud_message(" ")
    end
    hud_message(TEXT:format(ping))
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Ping display " .. (ENABLED and "enabled" or "disabled") .. ".")
        return false
    end
end
