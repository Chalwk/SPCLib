--[[
=====================================================================================
SCRIPT NAME:      tip_rotator.lua
DESCRIPTION:      Cycles through short gameplay tips and reminders on the HUD.

                  Command: /tips - Toggle tip rotator on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "tips"
local UPDATE_INTERVAL = 600 -- ticks between tips
-- END CONFIG --

local ticks = 0
local tip_index = 0

local tips = {
    "Grenades are better at corner checks than ego.",
    "If the fight feels crowded, reposition instead of forcing it.",
    "A quiet reload before the push is worth more than a loud panic later.",
    "Use the terrain. Half the map is cover if you let it be.",
    "If a vehicle is stuck, stop accelerating for a moment and try a new angle.",
    "When a room goes quiet, expect company.",
    "Watch the choke points, not just the scoreboard.",
    "A fresh spawn is a good time to scan ammo, health, and exits.",
}

set_callback("tick", "OnTick")
set_callback("map load", "OnMapLoad")
set_callback("map_preload", "OnMapPreload")
set_callback("unload", "OnUnload")
set_callback("command", "OnCommand")

local function clear_hud()
    for _ = 1, 8 do hud_message(" ") end
end

local function next_tip()
    tip_index = tip_index + 1
    if tip_index > #tips then
        tip_index = 1
    end
    return tips[tip_index]
end

local function show_tip()
    clear_hud()
    hud_message(next_tip())
end

function OnMapPreload()
    if ENABLED then console_out("Tip rotator warming up.") end
end

function OnMapLoad()
    ticks = 0
    tip_index = 0
    if ENABLED then show_tip() end
end

function OnUnload()
    ticks = 0
    tip_index = 0
end

function OnTick()
    if not ENABLED then return end

    ticks = ticks + 1
    if ticks % UPDATE_INTERVAL ~= 0 then return end

    show_tip()
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        clear_hud()
        console_out("Tip rotator " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end
