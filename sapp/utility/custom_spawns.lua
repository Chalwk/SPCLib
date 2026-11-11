--[[
=====================================================================================
SCRIPT NAME:    custom_spawns.lua
DESCRIPTION:    Custom spawn point handling for players based on map and team.

                FEATURES:
                - Supports team-based and free-for-all game modes.
                - Caches map-specific spawn points to optimize performance.
                - Prevents players from spawning on occupied points.
                - Places players during the pre-spawn callback.
                - Retries placement when all configured points are occupied.

LAST UPDATED:     12 Nov 2026

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start ----------------------------------------------------------
local MAPS = {

    -- Format: map_name = { team_name = { {x, y, z, rotation}, ... }, ... }

    ['training_jump'] = {
        red = {
            { -0.77, -39.56, 0.00, 1.3374 },
            { -0.77, -39.26, 0.00, 1.4720 },
            { -0.77, -38.95, 0.00, 1.4681 },
            { -0.77, -38.53, 0.00, 1.4739 },
            { -0.77, -38.09, 0.00, -0.4819 },
            { -0.26, -38.00, 0.00, -0.1153 },
            { 0.26, -38.06, 0.00, 4.4947 },
            { 0.68, -37.97, 0.00, 4.0404 },
            { 0.75, -38.52, 0.00, 3.9410 },
            { 0.80, -39.03, 0.00, 3.0752 },
            { 0.48, -39.28, 0.00, 3.0362 },
            { -0.04, -39.30, 0.00, 1.6244 },
            { -0.50, -38.94, 0.00, 1.4333 },
            { 0.11, -38.59, 0.00, 1.4859 },
            { -0.58, -38.30, 0.00, 1.5600 },
            { 0.52, -38.76, 0.00, 2.2445 },
            { -0.01, -39.27, 0.00, 1.5269 }
        },
        blue = {}
    }
    -- Add more maps here following the same format
}
-- CONFIG end ------------------------------------------------------------

api_version = '1.12.0.0'

local RETRY_INTERVAL_MS = 250
local RETRY_RESPAWN_SECONDS = 0.1
local RELEASE_DISTANCE_SQUARED = 1.0
local RESPAWN_TICKS_PER_SECOND = 33

local table_insert = table.insert
local math_random, math_floor = math.random, math.floor
local math_cos, math_sin = math.cos, math.sin
local pairs, ipairs, type = pairs, ipairs, type
local get_var, get_player = get_var, get_player
local player_alive, player_present = player_alive, player_present
local read_dword, read_float = read_dword, read_float
local read_vector3d, write_vector3d = read_vector3d, write_vector3d
local write_dword = write_dword
local get_dynamic_player, get_object_memory = get_dynamic_player, get_object_memory
local register_callback, timer = register_callback, timer
local cprint, string_format = cprint, string.format

local map_spawns = {}
local active_spawns = {}
local waiting_to_spawn = {}
local current_map
local is_ffa = false
local spawn_count = 0
local game_active = false
local timer_generation = 0

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function isValidSpawn(spawn)
    if type(spawn) ~= 'table' then return false end

    local x, y, z = spawn[1], spawn[2], spawn[3]
    local rotation = spawn[4]
    return isFiniteNumber(x) and isFiniteNumber(y)
        and isFiniteNumber(z) and isFiniteNumber(rotation)
end

local function teleportPlayer(dyn_player, spawn)
    local x, y, z = spawn[1], spawn[2], spawn[3]
    local rotation = spawn[4]

    write_vector3d(dyn_player + 0x5C, x, y, z)
    write_vector3d(dyn_player + 0x74, math_cos(rotation), math_sin(rotation), 0)
end

local function getPosition(dyn_player)
    local crouch = read_float(dyn_player + 0x50C)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    local object = vehicle_id == 0xFFFFFFFF and dyn_player or get_object_memory(vehicle_id)
    if object == 0 then return nil end

    local x, y, z = read_vector3d(object + 0x5C)
    if x == nil or y == nil or z == nil then return nil end
    return x, y, z + 0.65 - (0.3 * crouch)
end

local function setRespawnTime(id, seconds)
    local player = get_player(id)
    if player == nil then return end

    write_dword(player + 0x2C, math_floor(seconds * RESPAWN_TICKS_PER_SECOND + 0.5))
end

local function clearPlayerState(id)
    active_spawns[id] = nil
    waiting_to_spawn[id] = nil
end

local function cacheSpawns()
    current_map = get_var(0, '$map')
    is_ffa = get_var(0, '$ffa') == '1'
    map_spawns = {}
    spawn_count = 0

    local map_data = MAPS[current_map]
    if type(map_data) ~= 'table' then return end

    for team, team_spawns in pairs(map_data) do
        if type(team_spawns) == 'table' then
            local valid_spawns = {}
            for index, spawn in ipairs(team_spawns) do
                if isValidSpawn(spawn) then
                    table_insert(valid_spawns, spawn)
                else
                    cprint(
                        string_format(
                            '[custom_spawns] Ignoring invalid spawn point %s/%s[%d].', tostring(current_map),
                            tostring(team), index
                        )
                    )
                end
            end

            if is_ffa then
                for _, spawn in ipairs(valid_spawns) do
                    table_insert(map_spawns, spawn)
                    spawn_count = spawn_count + 1
                end
            else
                map_spawns[team] = valid_spawns
                spawn_count = spawn_count + #valid_spawns
            end
        else
            cprint(
                string_format(
                    '[custom_spawns] Ignoring invalid spawn list for %s/%s.', tostring(current_map), tostring(team)
                )
            )
        end
    end
end

local function getSpawnPool(team)
    if is_ffa then return map_spawns end
    return map_spawns[team]
end

local function isSpawnOccupied(spawn)
    for _, active_spawn in pairs(active_spawns) do
        local x, y, z = spawn[1], spawn[2], spawn[3]
        if active_spawn[1] == x and active_spawn[2] == y and active_spawn[3] == z then
            return true
        end
    end
    return false
end

local function getAvailableSpawn(spawn_pool)
    local selected_spawn
    local available_count = 0

    for _, spawn in ipairs(spawn_pool) do
        if not isSpawnOccupied(spawn) then
            available_count = available_count + 1
            if math_random(1, available_count) == 1 then
                selected_spawn = spawn
            end
        end
    end

    return selected_spawn
end

local function trySpawn(id)
    if not game_active or not player_present(id) then
        clearPlayerState(id)
        return false
    end

    local spawn_pool = getSpawnPool(get_var(id, '$team'))
    if not spawn_pool or #spawn_pool == 0 then
        waiting_to_spawn[id] = nil
        return false
    end

    local dyn_player = get_dynamic_player(id)
    if dyn_player == 0 then
        waiting_to_spawn[id] = true
        setRespawnTime(id, RETRY_RESPAWN_SECONDS)
        return false
    end

    local spawn = getAvailableSpawn(spawn_pool)
    if not spawn then
        waiting_to_spawn[id] = true
        if not player_alive(id) then
            setRespawnTime(id, RETRY_RESPAWN_SECONDS)
        end
        return false
    end

    teleportPlayer(dyn_player, spawn)
    active_spawns[id] = spawn
    waiting_to_spawn[id] = nil
    setRespawnTime(id, 0)
    return true
end

function OnPreSpawn(id)
    if not game_active then return end
    active_spawns[id] = nil
    trySpawn(id)
end

function OnDeath(id)
    active_spawns[id] = nil
    waiting_to_spawn[id] = nil

    local spawn_pool = getSpawnPool(get_var(id, '$team'))
    if game_active and player_present(id) and spawn_pool and #spawn_pool > 0 then
        waiting_to_spawn[id] = true
        setRespawnTime(id, RETRY_RESPAWN_SECONDS)
    end
end

function OnLeave(id)
    clearPlayerState(id)
end

function UpdateSpawnPoints(generation)
    if generation ~= timer_generation or not game_active then return false end

    for id, spawn in pairs(active_spawns) do
        if not player_present(id) or not player_alive(id) then
            active_spawns[id] = nil
        else
            local dyn_player = get_dynamic_player(id)
            if dyn_player ~= 0 then
                local spawn_x, spawn_y, spawn_z = spawn[1], spawn[2], spawn[3]
                local x, y, z = getPosition(dyn_player)
                if x ~= nil and y ~= nil and z ~= nil then
                    local dx = spawn_x - x
                    local dy = spawn_y - y
                    local dz = spawn_z - z

                    if dx * dx + dy * dy + dz * dz > RELEASE_DISTANCE_SQUARED then
                        active_spawns[id] = nil
                    end
                end
            end
        end
    end

    for id in pairs(waiting_to_spawn) do
        if not player_present(id) then
            clearPlayerState(id)
        elseif player_alive(id) then
            trySpawn(id)
        end
    end

    return true
end

function OnStart()
    timer_generation = timer_generation + 1
    active_spawns = {}
    waiting_to_spawn = {}
    game_active = false

    if get_var(0, '$gt') == 'n/a' then return end

    cacheSpawns()
    game_active = true
    if spawn_count > 0 then
        timer(RETRY_INTERVAL_MS, 'UpdateSpawnPoints', timer_generation)
    end
end

function OnEnd()
    game_active = false
    timer_generation = timer_generation + 1
    active_spawns = {}
    waiting_to_spawn = {}
end

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_LEAVE, 'OnLeave')
    register_callback(cb.EVENT_PRESPAWN, 'OnPreSpawn')
    OnStart()
end

function OnScriptUnload() end
