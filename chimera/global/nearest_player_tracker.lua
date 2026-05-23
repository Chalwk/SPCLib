--[[
=====================================================================================
SCRIPT NAME:      nearest_player_tracker.lua
DESCRIPTION:      Display nearest player name and distance.
                  Shows 'No nearby players found' when alone.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "nearest"
-- CONFIG END --

set_callback("unload", "OnScriptUnload")
set_callback("command", "OnCommand")

local timer_id = nil
local last_message = ""

local table_concat = table.concat
local string_char = string.char
local format = string.format
local math_huge = math.huge
local math_sqrt = math.sqrt

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

local function distance(ax, ay, az, bx, by, bz)
    local dx = ax - bx
    local dy = ay - by
    local dz = az - bz
    return math_sqrt(dx * dx + dy * dy + dz * dz)
end

function UpdateNearestPlayer()
    if not ENABLED then return true end

    local dynamic_player = get_dynamic_player()
    if not dynamic_player then return end

    local lx = read_float(dynamic_player + 0x5C) or 0
    local ly = read_float(dynamic_player + 0x60) or 0
    local lz = read_float(dynamic_player + 0x64) or 0

    local local_idx = local_player_index
    local best_id, best_dist = nil, math_huge

    for i = 0, 15 do
        if i ~= local_idx then
            dynamic_player = get_dynamic_player(i)
            local stat = get_player(i)
            if dynamic_player and stat then
                local x = read_float(dynamic_player + 0x5C) or 0
                local y = read_float(dynamic_player + 0x60) or 0
                local z = read_float(dynamic_player + 0x64) or 0
                local d = distance(lx, ly, lz, x, y, z)
                if d < best_dist then
                    best_dist = d
                    best_id = i
                end
            end
        end
    end

    local msg
    if best_id then
        msg = format("Nearest Player | %s | %.1f units away", get_player_name(best_id), best_dist)
    else
        msg = "Nearest Player | No nearby players found"
    end

    if msg ~= last_message then
        last_message = msg
        execute_script("cls")
        console_out(msg)
    end
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Nearest player tracker " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end

function OnScriptUnload()
    if timer_id then
        stop_timer(timer_id)
        timer_id = nil
    end
end

timer_id = set_timer(500, "UpdateNearestPlayer")
