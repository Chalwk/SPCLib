--[[
=====================================================================================
SCRIPT NAME:      killstreak.lua
DESCRIPTION:      Announces when players reach kill streak milestones
                  (e.g., 3, 5, 10, 15+ kills).

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
=====================================================================================
]]

-- CONFIG START --
clua_version = 2.056

local milestones = { 3, 5, 10, 15, 20, 25, 30, 40, 50 }
local CONSOLE_COLOR = { 0, 1, 0 } -- green (r, g, b)
local MESSAGE_TEMPLATE = "%s reached a %d-kill streak!"
-- CONFIG END --

set_callback("tick", "OnTick")
local announced = {} -- announced[player_index][milestone] = true

local table_concat = table.concat
local string_char = string.char
local format = string.format
local ipairs = ipairs

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
    if server_type ~= "dedicated" and server_type ~= "local" then return end

    for i = 0, 15 do
        local static = get_player(i)
        if not static then goto continue end

        local kills = read_word(static + 0x9C)
        announced[i] = announced[i] or {}

        for _, milestone in ipairs(milestones) do
            if kills >= milestone and not announced[i][milestone] then
                announced[i][milestone] = true
                local name = get_player_name(i)
                local msg = format(MESSAGE_TEMPLATE, name, milestone)
                console_out(msg, table.unpack(CONSOLE_COLOR))
            end
        end

        ::continue::
    end
end
