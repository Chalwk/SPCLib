--[[
=====================================================================================
SCRIPT NAME:      current_weapon_info.lua
DESCRIPTION:      Displays the current weapon name, primary ammo, and (if present)
                  secondary ammo in the upper-left corner of the HUD.

                  Command: /wpninfo - Toggle the display

                  TODO: Add support for battery powered weapons

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "wpninfo"
local UPDATE_INTERVAL = 5 -- ticks between refreshes
-- END CONFIG --

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

local timer = 0

function OnTick()
    if not ENABLED then return end

    timer = timer + 1
    if timer < UPDATE_INTERVAL then return end
    timer = 0

    local player = get_dynamic_player()
    if not player then return end

    local weapon = get_object(read_dword(player + 0x118))
    if not weapon then return end

    -- Primary ammo: magazine (0x2B6) and reserve (0x2B8)
    local clip1   = read_word(weapon + 0x2B6)
    local total1  = read_word(weapon + 0x2B8)

    -- Get short weapon name from tag path
    local tag_addr = get_tag(read_dword(weapon))
    local full_path = read_string(read_dword(tag_addr + 0x10))
    local short_name = full_path:match(".*\\([^\\]+)$") or full_path

    -- Build the message
    local msg = string.format("%s | %d / %d", short_name, clip1, total1)

    -- Clear old HUD spam and show
    for _ = 1, 10 do hud_message(" ") end
    hud_message(msg)
end

function OnCommand(cmd)
    if cmd:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Weapon info display " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end