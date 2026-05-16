--[[
=====================================================================================
SCRIPT NAME:      ctf_hud.lua
DESCRIPTION:      ...

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
=====================================================================================
]]

-- CONFIG START --
clua_version = 2.056

local RED_CARRIER_MSG = "Red flag carrier : %s"
local BLUE_CARRIER_MSG = "Blue flag carrier: %s"

local COLOR_RED = { 1.0, 0.35, 0.35 }
local COLOR_BLUE = { 0.35, 0.55, 1.0 }
-- CONFIG END --

set_callback("tick", "OnTick")
local table_concat = table.concat
local string_char = string.char
local format = string.format

local function get_object_name(obj)
    if not obj then return "N/A" end
    local tag = get_tag(read_dword(obj))
    if not tag then return "???" end
    local path = read_string(read_dword(tag + 0x10)) or "unknown"
    return path:match(".*\\([^\\]+)$") or path
end

local function get_player_name(id)
    local obj = get_player(id)
    if not obj then return "Unknown" end
    local addr = obj + 0x4
    local chars = {}
    for j = 1, 12 do
        local b = read_byte(addr + (j - 1) * 2)
        if b == 0 then break end
        chars[#chars + 1] = string_char(b)
    end
    return table_concat(chars)
end

function OnTick()
    if gametype ~= "ctf" then return end

    execute_script("cls")

    local red_carrier = "None"
    local blue_carrier = "None"

    for i = 0, 15 do
        local static = get_player(i)
        if not static then goto next_player end
        local team = read_byte(static + 0x20)

        local dyn = get_dynamic_player(i)
        if not dyn then goto next_player end

        local weapon_id = read_dword(dyn + 0x118)
        if weapon_id == 0xFFFFFFFF then goto next_player end
        local weapon = get_object(weapon_id)
        if not weapon then goto next_player end
        local object_name = get_object_name(weapon)
        if not object_name then goto next_player end

        if object_name:lower():find("flag") then
            local player_name = get_player_name(i)
            if team == 0 then
                red_carrier = player_name
            else
                blue_carrier = player_name
            end
        end
        ::next_player::
    end

    console_out(format(RED_CARRIER_MSG, red_carrier), table.unpack(COLOR_RED))
    console_out(format(BLUE_CARRIER_MSG, blue_carrier), table.unpack(COLOR_BLUE))
end
