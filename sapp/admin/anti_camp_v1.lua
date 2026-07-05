--[[
=====================================================================================
SCRIPT NAME:      anti_camp_v1.lua
DESCRIPTION:      Camping prevention system with:
                  - Configurable per-map zones
                  - Dynamic radius & duration tracking
                  - Progressive warnings & punishment
                  - Cooldown-protected enforcement
                  - Automatic reset on spawn/disconnect

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start --------------------------------------------
api_version = "1.12.0.0"

local COOLDOWN = 10 -- Cooldown period in seconds

local WARNING_MESSAGE = "[Anti-Camp]: Move or be killed in %ds!"
local PUNISH_MESSAGE = "[Anti-Camp]: Killed for camping!"

-- Camping zones {x, y, z, radius, max_time}
local MAPS = {
    ["bloodgulch"] = {
        { 98.80, -156.30, 1.70, 5.0, 120 }, -- RED base
        { 36.87, -82.33, 1.70, 5.0, 120 }   -- BLUE base
    }
    -- Repeat the structure for other maps
}
-- Config End ----------------------------------------------

local map
local players = {}
local CAMP_ZONES = {}

local player_present = player_present
local player_alive = player_alive
local get_dynamic_player = get_dynamic_player
local read_vector3d = read_vector3d
local read_dword = read_dword
local os_time = os.time
local get_var = get_var

local ipairs = ipairs

local function get_pos(dyn)
    return read_vector3d(dyn + 0x5C)
end

local function in_vehicle(dyn)
    return read_dword(dyn + 0x11C) == 0xFFFFFFF
end

local function punish(player)
    execute_command('kill ' .. player)
    rprint(player, PUNISH_MESSAGE)
    return os_time()
end

local function precompute_zones()
    for map_name, zones in pairs(MAPS) do
        local processed = {}
        for i, zone in ipairs(zones) do
            processed[i] = {
                x = zone[1],
                y = zone[2],
                z = zone[3],
                radius = zone[4],
                radius_sq = zone[4] * zone[4],
                max_time = zone[5]
            }
        end
        CAMP_ZONES[map_name] = processed
    end
end

function OnScriptLoad()
    precompute_zones()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnSpawn(id)
    players[id] = nil
end

function OnStart()
    map = get_var(0, '$gt') ~= "n/a" and get_var(0, '$map') or nil
end

function OnTick()
    local zones = CAMP_ZONES[map]
    if not zones then return end
    local current_time = os_time()

    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if not in_vehicle(dyn) then
                local x, y, z = get_pos(dyn)
                local data = players[i] or {}

                if data.last_punishment and (current_time - data.last_punishment) < COOLDOWN then
                    goto continue
                end

                local in_zone = false
                for index, zone in ipairs(zones) do
                    local dx, dy, dz = x - zone.x, y - zone.y, z - zone.z
                    if (dx * dx + dy * dy + dz * dz) <= zone.radius_sq then
                        in_zone = true

                        if data.zone ~= index then
                            data.zone = index
                            data.entry_time = current_time
                            data.warned = false
                        end

                        local elapsed = current_time - data.entry_time
                        local max_time = zone.max_time

                        if not data.warned and elapsed >= max_time / 2 then
                            local time_left = max_time - elapsed
                            rprint(i, WARNING_MESSAGE:format(time_left))
                            data.warned = true
                        end

                        if elapsed >= max_time then
                            data.last_punishment = punish(i)
                            data.zone = nil
                            break
                        end
                    end
                end

                if not in_zone and data.zone then
                    data.zone = nil
                    data.entry_time = nil
                end

                players[i] = data
            end
        end
        ::continue::
    end
end

function OnQuit(id)
    players[id] = nil
end

function OnScriptUnload() end
