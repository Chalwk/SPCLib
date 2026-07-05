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

local ENABLED = true
local COMMAND = "breaks"
local REMINDER_MINUTES = 45
local HUD_INTERVAL = 30
-- END CONFIG --

local ticks = 0
local warned = false
local reminder_ticks = REMINDER_MINUTES * 60 * 30

set_callback("tick", "OnTick")
set_callback("map load", "OnMapLoad")
set_callback("unload", "OnUnload")
set_callback("command", "OnCommand")

local function clear_hud()
    for _ = 1, 8 do
        hud_message(" ")
    end
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
    if not ENABLED then return end

    ticks = ticks + 1

    if ticks == reminder_ticks and not warned then
        warned = true
        console_out("Long session reminder: stand up, blink, and stretch.")
        draw_reminder()
        return
    end

    if ticks % HUD_INTERVAL == 0 and warned then draw_reminder() end
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        clear_hud()
        console_out("Break reminders " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end
