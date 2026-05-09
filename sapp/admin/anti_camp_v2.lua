--[[
=====================================================================================
SCRIPT NAME:      anti_camp_v2.lua
DESCRIPTION:      Universal camping prevention system with:
                  - Continuous global monitoring
                  - Radius-based movement detection
                  - Dynamic warning at 50% of max time
                  - Automatic punishment on threshold exceed
                  - Cooldown-protected enforcement
                  - Automatic reset on spawn/disconnect

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start ---------------------------------------------------
api_version = "1.12.0.0"

local COOLDOWN = 10       -- Cooldown period in seconds
local MAX_CAMP_TIME = 120 -- Maximum allowed camping time (in seconds)
local CAMP_RADIUS = 1.0   -- Radius (world units) within which movement is considered camping

-- Customizable messages:
local WARNING_MESSAGE = "WARNING: Move or be killed in %ds!"
local PUNISH_MESSAGE = "No camping allowed!"

-- Config End -------------------------------------------------

local CAMP_RADIUS_SQ = CAMP_RADIUS * CAMP_RADIUS
local players = {}

local player_present = player_present
local player_alive = player_alive
local get_dynamic_player = get_dynamic_player
local read_vector3d = read_vector3d
local read_dword = read_dword
local os_time = os.time

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

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
end

function OnJoin(id)
    players[id] = {
        last_punishment = nil,
        start_time = nil,
        last_x = nil,
        last_y = nil,
        last_z = nil,
        warned = false
    }
end

function OnSpawn(id)
    local data = players[id]
    if data then
        data.start_time = nil
        data.last_x = nil
        data.last_y = nil
        data.last_z = nil
        data.warned = false
    end
end

function OnTick()
    local current_time = os_time()

    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if dyn ~= 0 and not in_vehicle(dyn) then
                local x, y, z = get_pos(dyn)
                local data = players[i]

                local in_cooldown = data.last_punishment and (current_time - data.last_punishment) < COOLDOWN

                if not data.start_time then
                    data.start_time = current_time
                    data.last_x, data.last_y, data.last_z = x, y, z
                    data.warned = false
                else
                    local dx, dy, dz = x - data.last_x, y - data.last_y, z - data.last_z
                    if (dx * dx + dy * dy + dz * dz) <= CAMP_RADIUS_SQ and not in_cooldown then
                        local elapsed = current_time - data.start_time

                        if not data.warned and elapsed >= MAX_CAMP_TIME / 2 then
                            local time_left = MAX_CAMP_TIME - elapsed
                            rprint(i, WARNING_MESSAGE:format(time_left))
                            data.warned = true
                        end

                        if elapsed >= MAX_CAMP_TIME then
                            data.last_punishment = punish(i)
                            data.start_time = nil
                        end
                    else
                        data.start_time = current_time
                        data.last_x     = x
                        data.last_y     = y
                        data.last_z     = z
                        data.warned     = false
                    end
                end
            end
        end
    end
end

function OnQuit(id) players[id] = nil end

function OnScriptUnload() end
