--[[
=====================================================================================
SCRIPT NAME:      mini_compass.lua
DESCRIPTION:      Displays a compass on the HUD using cardinal and intercardinal points.

                  Command: /compass - Toggle compass display

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local enabled = true
local custom_command = "compass"    -- command to toggle
local update_interval = 10          -- ticks between refreshes
-- END CONFIG --

local timer = 0
local directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}

local math_pi, math_atan, math_deg = math.pi, math.atan, math.deg
local math_floor = math.floor

local function atan2(y, x)
    -- Handle vertical lines (x == 0) to avoid division by zero
    if x == 0 then
        if y > 0 then
            return math_pi / 2
        elseif y < 0 then
            return -math_pi / 2
        else
            return 0 -- (0,0) -> 0 (facing east, but this shouldn't happen)
        end
    end
    return math_atan(y / x) + ((x < 0) and math_pi or 0)
end

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

function OnTick()
    if not enabled then return end
    timer = timer + 1
    if timer < update_interval then return end
    timer = 0

    local player = get_dynamic_player()
    if not player then return end

    -- Read the two forward-vector components
    local forward_x = read_float(player + 0x230)  -- X component of forward
    local forward_y = read_float(player + 0x234)  -- Y component of forward

    -- Compute yaw angle in radians using atan2(y, x)
    local yaw_rad = atan2(forward_y, forward_x)

    -- Convert to degrees and rotate so 0 = North, 90 = East
    local deg = 90 - math_deg(yaw_rad)
    deg = deg % 360
    if deg < 0 then deg = deg + 360 end

    -- Map to cardinal direction (8 sectors of 45)
    local index = math_floor((deg + 22.5) / 45) % 8 + 1
    local dir = directions[index] or "?"

    -- Clear old HUD message and print new direction (prevents spam)
    for _ = 1, 10 do hud_message(" ") end
    hud_message(dir)
end

function OnCommand(command)
    if command:lower() == custom_command then
        enabled = not enabled
        console_out("Compass " .. (enabled and "enabled" or "disabled") .. ".")
        return false
    end
end