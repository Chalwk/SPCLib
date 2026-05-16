--[[
=====================================================================================
SCRIPT NAME:      afk_monitor.lua
DESCRIPTION:      Warns when any player hasn't moved for a configurable time.
                  Displays a console message and an on-screen warning.

                  Commands:
                    /afk                - toggle monitoring
                    /afktime <seconds>  - set idle warning time (default 180)
                    /afkradius <units>  - movement tolerance (default 0.01)

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local IDLE_SECONDS = 2   -- 3 minutes
local MOVE_RADIUS = 0.01 -- movement below this is considered still
local AFK_NOTIFY_MESSAGE = "[AFK] %s [%d] has been idle for %d seconds"
-- END CONFIG --

local idle_ticks = IDLE_SECONDS * 30
local last_pos = {}
local timers = {}

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")
set_callback("map load", "OnMapLoad")

local fmt = string.format
local table_concat = table.concat
local string_char = string.char

function OnMapLoad()
    last_pos = {}
    timers = {}
end

local function get_player_name(index)
    local obj = get_player(index)
    local address = obj + 0x4
    local length = 12
    local bytes = {}
    for i = 1, length do
        local byte = read_byte(address + (i - 1) * 2)
        if byte == 0 then break end
        bytes[#bytes + 1] = string_char(byte)
    end

    return table_concat(bytes)
end

function OnTick()
    if not ENABLED then return end

    for i = 0, 16 - 1 do
        local dyn = get_dynamic_player(i)
        if dyn then
            local x = read_float(dyn + 0x5C)
            local y = read_float(dyn + 0x60)
            local z = read_float(dyn + 0x64)

            local prev = last_pos[i]
            if prev then
                local dx = x - prev[1]
                local dy = y - prev[2]
                local dz = z - prev[3]
                if dx * dx + dy * dy + dz * dz < MOVE_RADIUS * MOVE_RADIUS then
                    timers[i] = (timers[i] or 0) + 1
                    if timers[i] == idle_ticks then
                        local name = get_player_name(i)
                        console_out(fmt(AFK_NOTIFY_MESSAGE, name, i + 1, IDLE_SECONDS))
                    end
                else
                    timers[i] = 0
                end
            end
            last_pos[i] = { x, y, z }
        else
            last_pos[i] = nil
            timers[i] = nil
        end
    end
end

local function parseArgs(input, delimiter)
    local result = {}
    for substring in input:gmatch("([^" .. delimiter .. "]+)") do
        result[#result + 1] = substring
    end
    return result
end

function OnCommand(cmd)
    local args = parseArgs(cmd, " ")
    local command = (args[1] or ""):lower()

    if command == "afk" then
        ENABLED = not ENABLED
        console_out("AFK monitor " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end

    if command == "afktime" then
        local num = tonumber(args[2])
        if num and num > 0 then
            IDLE_SECONDS = num
            idle_ticks = num * 30
            console_out("AFK idle time set to " .. num .. " seconds.")
        else
            console_out("Usage: /afktime <seconds>")
        end
        return false
    end

    if command == "afkradius" then
        local num = tonumber(args[2])
        if num and num >= 0 then
            MOVE_RADIUS = num
            console_out("AFK movement radius set to " .. num .. ".")
        else
            console_out("Usage: /afkradius <units>")
        end
        return false
    end
end
