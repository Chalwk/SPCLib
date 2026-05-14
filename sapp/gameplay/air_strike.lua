--[[
=====================================================================================
SCRIPT NAME:      air_strike.lua
DESCRIPTION:      Simulates random airstrikes in Halo PC/CE with configurable:
                  - Rocket count per strike
                  - Strike frequency
                  - Spawn heights
                  - Projectile trajectories
                  - Map-specific target locations

                  Players receive warning when a strike is incoming.

LAST UPADTED:     August, 2025

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration
local config = {
    min_projectiles = 1,  -- Minimum rockets per strike
    max_projectiles = 5,  -- Maximum rockets per strike
    min_interval = 30,    -- Minimum seconds between strikes
    max_interval = 60,    -- Maximum seconds between strikes
    min_height = 15,      -- Minimum spawn height
    max_height = 30,      -- Maximum spawn height
    velocity = {
        horizontal = 1.5, -- Max horizontal velocity
        vertical = -25    -- Downward velocity (negative = down)
    },
    strike_locations = {
        bloodgulch = {
            { 64,    -112.09, 2.21 },
            { 52.96, -93.79,  0.47 },
            { 38.64, -91.71,  0.37 },
            { 81.41, -145.96, 0.6 },
            { 36.64, -105.38, 1.8 },
            { 92.14, -141.23, 1.18 },
            { 79.61, -135.17, 0.99 },
            { 80.48, -121.13, 0.63 },
            { 61.68, -129.85, 1.37 },
            { 46.78, -131.33, 1.28 },
            { 47.78, -116.02, 0.74 },
            { 80.01, -107.42, 2.31 },
            { 81.66, -116.47, 0.78 },
            { 94.88, -127.31, 1.77 },
            { 101.5, -143.25, 1.07 },
            { 82.27, -156.12, 0.19 },
            { 52.43, -111.84, 0.64 },
            { 28.06, -19.75,  -18.65 }
        }
    }
}

-- Global variables
local rocket_tag
local next_strike_time
local active_map_locations

local clock = os.clock
local sqrt, pi, sin, cos = math.sqrt, math.pi, math.sin, math.cos

-- Utility functions
local function get_random(min, max)
    return min + (max - min) * math.random()
end

local function broadcast(message)
    for i = 1, 16 do
        if player_present(i) then
            rprint(i, message)
        end
    end
end

-- Initialize strike schedule
local function schedule_next_strike()
    next_strike_time = clock() + get_random(config.min_interval, config.max_interval)
end

-- Physics calculations
local function calculate_velocity(target_x, target_y, spawn_x, spawn_y, height)
    local dx = target_x - spawn_x
    local dy = target_y - spawn_y
    local distance = sqrt(dx * dx + dy * dy)

    -- Normalize direction and apply random offset
    if distance > 0.1 then
        dx = dx / distance
        dy = dy / distance
    else
        dx, dy = 0, 1 -- Default direction if too close
    end

    -- Add randomness to impact point
    local spread = get_random(-config.velocity.horizontal, config.velocity.horizontal)
    return {
        x = dx * config.velocity.horizontal + spread * -dy,
        y = dy * config.velocity.horizontal + spread * dx,
        z = config.velocity.vertical
    }
end

-- Main strike function
local function execute_airstrike()
    if not active_map_locations or #active_map_locations == 0 then return end

    -- Select random target location
    local target = active_map_locations[rand(1, #active_map_locations + 1)]
    local tx, ty, tz = target[1], target[2], target[3]

    broadcast("INCOMING AIRSTRIKE! Seek cover!")

    -- Spawn rockets
    local count = rand(config.min_projectiles, config.max_projectiles + 1)
    for _ = 1, count do
        -- Random spawn position above target
        local height = get_random(config.min_height, config.max_height)
        local angle = get_random(0, 2 * pi)
        local distance = get_random(5, 15)
        local sx = tx + cos(angle) * distance
        local sy = ty + sin(angle) * distance

        -- Spawn rocket
        local rocket = spawn_object("", "", sx, sy, tz + height, 0, rocket_tag)
        if rocket ~= 0 then
            local obj = get_object_memory(rocket)
            if obj ~= 0 then
                -- Calculate realistic trajectory
                local vel = calculate_velocity(tx, ty, sx, sy, height)
                write_float(obj + 0x68, vel.x) -- Velocity X
                write_float(obj + 0x6C, vel.y) -- Velocity Y
                write_float(obj + 0x70, vel.z) -- Velocity Z
            end
        end
    end

    schedule_next_strike()
end

-- Callbacks
function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_TICK, "OnTick")
end

function OnGameStart()
    if get_var(0, "$gt") == "n/a" then return end

    -- Load rocket tag
    rocket_tag = lookup_tag("proj", "weapons\\rocket launcher\\rocket")
    if rocket_tag == 0 then return end

    -- Get map-specific locations
    local map = get_var(0, "$map")
    active_map_locations = config.strike_locations[map]

    if active_map_locations then
        schedule_next_strike()
    end
end

function OnTick()
    if next_strike_time and clock() >= next_strike_time then
        execute_airstrike()
    end
end

function OnScriptUnload() end
