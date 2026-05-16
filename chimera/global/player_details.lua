--[[
=====================================================================================
SCRIPT NAME:      player_details.lua
DESCRIPTION:      Shows detailed information about a specific player.

                  Command: /pinfo <player_index> - Displays player details.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local COMMAND = "pinfo"
local MAX_PLAYERS = 16
-- END CONFIG --

local floor = math.floor
local format = string.format
local char = string.char
local concat = table.concat

set_callback("command", "OnCommand")

local function read_string(addr)
    if not addr or addr == 0 or addr == 0xFFFFFFFF then return nil end
    local bytes = {}
    for i = 0, 127 do
        local b = read_byte(addr + i)
        if b == 0 then break end
        bytes[#bytes + 1] = char(b)
    end
    return concat(bytes)
end

local function get_object_name(obj)
    if not obj then return "N/A" end
    local tag = get_tag(read_dword(obj))
    if not tag then return "???" end
    local path = read_string(read_dword(tag + 0x10)) or "unknown"
    return path:match(".*\\([^\\]+)$") or path
end

function OnCommand(cmd)
    local lower = cmd:lower()
    local index = tonumber(lower:match("^" .. COMMAND .. " (%d+)$"))
    if not index then return end
    if index < 1 or index > MAX_PLAYERS then
        console_out("Invalid player index. Must be 1-" .. MAX_PLAYERS)
        return false
    end
    local i = index - 1
    local player_obj = get_dynamic_player(i)
    if not player_obj then
        console_out("Player " .. index .. " not found.")
        return false
    end
    local p = get_player(i)
    local team = read_byte(p + 0x20)
    local team_str = (team == 0) and "Red" or "Blue"
    local health = floor(read_float(player_obj + 0xE0) * 100)
    local shields = floor(read_float(player_obj + 0xE4) * 100)
    local weapon = get_object(read_dword(player_obj + 0x118))
    local wname = get_object_name(weapon)
    local ammo = weapon and read_word(weapon + 0x2B6) or 0
    local x = read_float(player_obj + 0x5C)
    local y = read_float(player_obj + 0x60)
    local z = read_float(player_obj + 0x64)
    local xs = format("%.2f", x)
    local ys = format("%.2f", y)
    local zs = format("%.2f", z)

    console_out("=== Player " .. index .. " ===")
    console_out("Team: " .. team_str)
    console_out("Health: " .. health .. "%")
    console_out("Shields: " .. shields .. "%")
    console_out("Weapon: " .. wname .. " (" .. ammo .. " ammo)")
    console_out("Position: X=" .. xs .. " Y=" .. ys .. " Z=" .. zs)
    return false
end
