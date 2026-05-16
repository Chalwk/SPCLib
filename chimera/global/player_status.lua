--[[
=====================================================================================
SCRIPT NAME:      player_status.lua
DESCRIPTION:      Displays a HUD overlay of all players with their team,
                  health, shields, weapon, and ammo.
                  Updates every 15 ticks.

                  Command: /pstatus - Toggles display

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "pstatus"
local INTERVAL = 15
local MAX_PLAYERS = 16
-- END CONFIG --

local timer = 0
local floor = math.floor
local concat = table.concat
local char, format = string.char, string.format

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

local function get_object_name(obj)
    if not obj then return "N/A" end
    local tag = get_tag(read_dword(obj))
    if not tag then return "???" end
    local path = read_string(read_dword(tag + 0x10)) or "unknown"
    return path:match(".*\\([^\\]+)$") or path
end

local function get_player_name(index)
    local obj = get_player(index)
    local address = obj + 0x4
    local length = 12

    local bytes = {}

    for i = 1, length do
        local byte = read_byte(address + (i - 1) * 2)
        if byte == 0 then break end
        bytes[#bytes + 1] = char(byte)
    end

    return concat(bytes)
end

function OnTick()
    if not ENABLED then return end

    timer = timer + 1
    if timer < INTERVAL then return end
    timer = 0

    execute_script("cls")
    console_out("PLAYER STATUS:")

    for i = 0, MAX_PLAYERS - 1 do
        local player_obj = get_dynamic_player(i)
        if player_obj then
            local p = get_player(i)

            local team = read_byte(p + 0x20)
            local team_str = (team == 0) and "R" or "B"

            local health = read_float(player_obj + 0xE0) or 0
            local shields = read_float(player_obj + 0xE4) or 0

            local hp = floor(health * 100)
            local sh = floor(shields * 100)

            local weapon = get_object(read_dword(player_obj + 0x118))
            local wname = get_object_name(weapon)
            local ammo = weapon and read_word(weapon + 0x2B6) or 0

            local name = get_player_name(i)

            console_out(format(
                "[%s] %s (%d) | HP:%d SH:%i | %s (%d)",
                team_str,
                name,
                i + 1,
                hp,
                sh,
                wname or "none",
                ammo or 0
            ))
        end
    end
end

function OnCommand(cmd)
    if cmd:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Player status monitor " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end