--[[
=====================================================================================
SCRIPT NAME:      vehicle_speedometer.lua
DESCRIPTION:      Displays the player's current vehicle speed in km/h on the HUD.
                  The script calculates speed using the vehicle's velocity vector
                  and updates it at a configurable INTERVAL.

                  Command: /speedo - Toggle speed display on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true     -- enable the script
local COMMAND = "speedo" -- command to toggle the script
local INTERVAL = 15      -- update every 15 ticks (~0.25 sec)
local FACTOR = 30 * 3.6  -- 108: ticks/sec * world_units_to_kmh
-- END CONFIG --

local timer = 0

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

function OnTick()
    if not ENABLED then return end
    timer = timer + 1
    if timer < INTERVAL then return end
    timer = 0

    local player = get_dynamic_player()
    if not player then return end

    local vehicle_id = read_dword(player + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return end -- not in a vehicle

    local vehicle = get_object(vehicle_id)
    if not vehicle then return end

    local vx = read_float(vehicle + 0x68)
    local vy = read_float(vehicle + 0x6C)
    local vz = read_float(vehicle + 0x70)

    local raw_speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    local kmh = raw_speed * FACTOR

    -- Clear previous HUD messages (prevents spam)
    for _ = 1, 10 do
        hud_message(" ")
    end

    hud_message(string.format("Speed: %.0f km/h", kmh))
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED -- set to the opposite of current state
        console_out("Speedometer " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end
