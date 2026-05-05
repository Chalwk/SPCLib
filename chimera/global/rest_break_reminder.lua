--[[
=====================================================================================
SCRIPT NAME:      rest_break_reminder.lua
DESCRIPTION:      Gives a gentle reminder after extended play sessions.

                  Command: /breaks - Toggle break reminders on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local enabled = true
local custom_command = "breaks"
local reminder_minutes = 45
local hud_interval = 30
-- END CONFIG --

local ticks = 0
local warned = false
local reminder_ticks = reminder_minutes * 60 * 30

set_callback("tick", "OnTick")
set_callback("map load", "OnMapLoad")
set_callback("unload", "OnUnload")
set_callback("command", "OnCommand")

local function clear_hud()
    for _ = 1, 8 do hud_message(" ") end
end

local function draw_reminder()
    clear_hud()
    hud_message("Time for a short break.")
end

function OnMapLoad()
    ticks = 0
    warned = false
end

function OnUnload()
    ticks = 0
    warned = false
end

function OnTick()
    if not enabled then return end

    ticks = ticks + 1

    if ticks == reminder_ticks and not warned then
        warned = true
        console_out("Long session reminder: stand up, blink, and stretch.")
        draw_reminder()
        return
    end

    if ticks % hud_interval == 0 and warned then draw_reminder() end
end

function OnCommand(command)
    if command:lower() == custom_command then
        enabled = not enabled
        clear_hud()
        console_out("Break reminders " .. (enabled and "enabled" or "disabled") .. ".")
        return false
    end
end
