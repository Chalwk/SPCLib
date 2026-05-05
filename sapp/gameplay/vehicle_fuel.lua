--[[
=====================================================================================
SCRIPT NAME:      vehicle_fuel.lua
DESCRIPTION:      Adds a fuel system to vehicles with configurable consumption,
                  refueling stations, and an on-screen fuel gauge for drivers.

FEATURES:
                  - Configurable max fuel and consumption rates per vehicle type
                  - Fuel consumption scales with vehicle speed
                  - Designated refueling stations per map
                  - Adjustable refuel rate and station radius
                  - Fuel gauge display with status indicators
                  - Vehicles enter "snail mode" when out of fuel (instead of stopping)

USAGE:
                  1. Define fuel stations for each map in `fuel_stations`.
                  2. Configure per-vehicle fuel settings in `fuel_settings`.
                  3. Adjust constants (FUEL_STATION_RADIUS, REFUEL_RATE,
                     MINIMUM_FUEL_SPEED) as desired.

NOTES:
                  - Fuel state is tracked per vehicle object, not per type.
                  - Only drivers see the fuel gauge.
                  - Script disables itself if no stations are configured for a map.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config -----------------------------------------
local FUEL_STATION_RADIUS = 3.5
local REFUEL_RATE = 0.5 -- Fuel units per tick when refueling
local MINIMUM_FUEL_SPEED = 0.1 -- Minimum speed when out of fuel (snail mode)

local fuel_stations = {
    ["bloodgulch"] = {
        { 65.749, -120.409, 0.118 }
    },
}

local fuel_settings = { -- {max fuel, consumption rate}
    ['vehicles\\ghost\\ghost_mp'] = { 100, 0.1 },
    ['vehicles\\rwarthog\\rwarthog'] = { 120, 0.15 },
    ['vehicles\\banshee\\banshee_mp'] = { 80, 0.2 },
    ['vehicles\\warthog\\mp_warthog'] = { 150, 0.10 },
    ['vehicles\\scorpion\\scorpion_mp'] = { 200, 0.25 },
    ['vehicles\\c gun turret\\c gun turret_mp'] = { 50, 0.05 },
}

-- Config End -------------------------------------

api_version = '1.12.0.0'

local map
local vehicles = {}
local vehicle_state = {}

local unpack = unpack
local lookup_tag = lookup_tag
local read_vector3d, write_float = read_vector3d, write_float
local get_object_memory, get_dynamic_player = get_object_memory, get_dynamic_player
local read_dword, read_word, read_float = read_dword, read_word, read_float
local math_sqrt, math_min, math_max, math_floor = math.sqrt, math.min, math.max, math.floor
local player_present, player_alive, get_var, rprint = player_present, player_alive, get_var, rprint

local function get_tag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function in_range(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return (dx * dx + dy * dy + dz * dz) <= (FUEL_STATION_RADIUS * FUEL_STATION_RADIUS)
end

local function get_vehicle_speed(vehicle_obj)
    local vx = read_float(vehicle_obj + 0x68)  -- X velocity
    local vy = read_float(vehicle_obj + 0x6C)  -- Y velocity
    local vz = read_float(vehicle_obj + 0x70)  -- Z velocity
    return math_sqrt(vx*vx + vy*vy + vz*vz)    -- Actual speed magnitude
end

local function get_vehicle(dyn)
    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    local vehicle_obj = get_object_memory(vehicle_id)
    if vehicle_obj == 0 then return nil end

    local seat = read_word(dyn + 0x2F0)
    if seat ~= 0 then return nil end -- check if they are the driver

    local meta_id = read_dword(vehicle_obj)
    local vehicle_cfg = vehicles[meta_id]
    if not vehicle_cfg then return nil end

    local crouch = read_float(dyn + 0x50C)
    local x, y, z = read_vector3d(vehicle_obj + 0x5C)
    local z_offset = (crouch == 0) and 0.65 or 0.35 * crouch

    return {
        vehicle_id,
        vehicle_obj,
        vehicle_cfg,
        x,
        y,
        z + z_offset,
    }
end

local function is_at_fuel_station(x, y, z)
    for _, station in ipairs(fuel_stations[map]) do
        if in_range(x, y, z, station[1], station[2], station[3]) then
            return true
        end
    end
    return false
end

local function clear_console(id)
    for _ = 1, 25 do rprint(id, " ") end
end

local function update_fuel_gauge(player, _, current_fuel, max_fuel, at_station)
    local percentage = math_floor((current_fuel / max_fuel) * 100)
    local gauge = "|"
    local filled = math_floor(percentage / 10)

    for i = 1, 10 do
        if i <= filled then
            gauge = gauge .. "#"
        else
            gauge = gauge .. "-"
        end
    end

    local status_text = "Fuel: " .. gauge .. "| " .. percentage .. "%"
    if at_station and percentage < 100 then
        status_text = status_text .. " [REFUELING]"
    elseif current_fuel <= 0 then
        status_text = status_text .. " [OUT OF FUEL]"
    end

    clear_console(player)
    rprint(player, status_text)
end

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnObjectSpawn(_, meta_id)
    if vehicles[meta_id] then
        vehicle_state[meta_id] = {
            fuel = vehicles[meta_id].max_fuel,
            max_fuel = vehicles[meta_id].max_fuel
        }
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    map = get_var(0, '$map')
    vehicles = {}
    vehicle_state = {}

    if not fuel_stations[map] or #fuel_stations[map] == 0 then
        unregister_callback(cb['EVENT_TICK'])
        unregister_callback(cb['EVENT_OBJECT_SPAWN'])
        return
    end

    for tag_name, v in pairs(fuel_settings) do
        local max_fuel, consumption_rate = v[1], v[2]
        local meta_id = get_tag('vehi', tag_name)
        if meta_id then
            vehicles[meta_id] = {
                max_fuel = max_fuel,
                consumption_rate = consumption_rate
            }
        end
    end

    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_OBJECT_SPAWN'], 'OnObjectSpawn')
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if dyn == 0 then goto next end

            local vehicle_data = get_vehicle(dyn)
            if not vehicle_data then goto next end

            local vehicle_id, vehicle_obj, vehicle_cfg, x, y, z = unpack(vehicle_data)

            -- Initialize vehicle state if not exists
            if not vehicle_state[vehicle_id] then
                vehicle_state[vehicle_id] = {
                    fuel = vehicle_cfg.max_fuel,
                    max_fuel = vehicle_cfg.max_fuel
                }
            end

            local state = vehicle_state[vehicle_id]
            local at_station = is_at_fuel_station(x, y, z)
            local speed = get_vehicle_speed(vehicle_obj)  -- Get actual speed

            -- Refuel if at station
            if at_station then
                if state.fuel < state.max_fuel then
                    state.fuel = math_min(state.max_fuel, state.fuel + REFUEL_RATE)
                end
            else
                -- Consume fuel when vehicle is moving
                if speed > 0.1 then
                    state.fuel = math_max(0, state.fuel - (vehicle_cfg.consumption_rate * speed))
                end
            end

            -- Handle out of fuel (snail mode)
            if state.fuel <= 0 then
                -- Get current thrust
                local current_thrust = read_float(vehicle_obj + 0x4F0)

                -- Only limit speed if they're trying to go faster than snail mode
                if speed > MINIMUM_FUEL_SPEED then
                    -- Scale down velocity vector to achieve snail mode
                    local scale = MINIMUM_FUEL_SPEED / speed
                    write_float(vehicle_obj + 0x68, read_float(vehicle_obj + 0x68) * scale)
                    write_float(vehicle_obj + 0x6C, read_float(vehicle_obj + 0x6C) * scale)
                    write_float(vehicle_obj + 0x70, read_float(vehicle_obj + 0x70) * scale)
                end

                -- Reduce thrust to prevent acceleration
                if current_thrust > 0.1 then
                    write_float(vehicle_obj + 0x4F0, current_thrust * 0.3)
                end
            end

            -- Show fuel gauge to driver
            update_fuel_gauge(i, vehicle_id, state.fuel, state.max_fuel, at_station)
        end

        ::next::
    end
end

function OnScriptUnload() end
