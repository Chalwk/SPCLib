--[[
=====================================================================================
SCRIPT NAME:      session_clock.lua
DESCRIPTION:      Shows a session timer for the current map.

                  Command: /session_clock - Toggle session clock on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local enabled = true
local custom_command = "session_clock"
local update_interval = 30 -- ticks
-- END CONFIG --

local ticks = 0

set_callback("tick", "OnTick")
set_callback("map load", "OnMapLoad")
set_callback("unload", "OnUnload")
set_callback("command", "OnCommand")

local floor = math.floor
local format = string.format

local function format_time(total_seconds)
    local h = floor(total_seconds / 3600)
    local m = floor((total_seconds % 3600) / 60)
    local s = total_seconds % 60
    return format("%02d:%02d:%02d", h, m, s)
end

local function clear_hud()
    for _ = 1, 8 do hud_message(" ") end
end

local function draw_clock()
    clear_hud()
    hud_message("Session time: " .. format_time(floor(ticks / 30)))
end

function OnMapLoad()
    ticks = 0
    if enabled then console_out("Session clock ready.") end
end

function OnUnload()
    ticks = 0
end

function OnTick()
    if not enabled then return end

    ticks = ticks + 1
    if ticks % update_interval ~= 0 then return end

    draw_clock()
end

function OnCommand(command)
    if command:lower() == custom_command then
        enabled = not enabled
        clear_hud()
        console_out("Session clock " .. (enabled and "enabled" or "disabled") .. ".")
        return false
    end
end
