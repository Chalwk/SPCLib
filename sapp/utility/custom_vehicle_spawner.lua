--[[
===============================================================================
SCRIPT NAME:      custom_vehicle_spawner.lua
DESCRIPTION:      Manages persistent vehicle spawns with:
                  - Automatic respawning of moved vehicles
                  - Map-specific vehicle configurations
                  - Occupancy detection
                  - Configurable respawn timers
                  - Movement threshold detection
                  - Multi-map support
                  - Gametype-specific setups

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = '1.12.0.0'

local VEHICLES = {
    bloodgulch = {
        ['YOUR_GAME_MODE_HERE'] = {
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 23.598, -102.343, 2.163, -0.000, 30, 1.5 },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 38.119, -64.898, 0.617, -2.260, 30, 1.5 },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 51.349, -61.517, 1.759, -1.611, 30, 1.5 },
            { "vehi", "vehicles\\warthog\\mp_warthog", 28.854, -90.193, 0.434, -0.848, 30, 1.5 },
            { "vehi", "vehicles\\warthog\\mp_warthog", 43.559, -64.809, 1.113, 5.524, 30, 1.5 },
            { "vehi", "vehicles\\rwarthog\\rwarthog", 50.655, -87.787, 0.079, -1.936, 30, 1.5 },
            { "vehi", "vehicles\\rwarthog\\rwarthog", 62.745, -72.406, 1.031, 3.657, 30, 1.5 },
            { "vehi", "vehicles\\banshee\\banshee_mp", 70.078, -62.626, 3.758, 4.011, 30, 1.5 },
            { "vehi", "vehicles\\c gun turret\\c gun turret_mp", 29.537, -53.667, 2.945, 5.110, 30, 1.5 },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 104.017, -129.761, 1.665, -3.595, 30, 1.5 },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 81.150, -169.359, 0.158, 1.571, 30, 1.5 },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 97.117, -173.132, 0.744, 1.532, 30, 1.5 },
            { "vehi", "vehicles\\warthog\\mp_warthog", 102.312, -144.626, 0.580, 1.895, 30, 1.5 },
            { "vehi", "vehicles\\warthog\\mp_warthog", 67.961, -171.002, 1.428, 0.524, 30, 1.5 },
            { "vehi", "vehicles\\rwarthog\\rwarthog", 106.885, -169.245, 0.091, 2.494, 30, 1.5 },
            { "vehi", "vehicles\\banshee\\banshee_mp", 64.178, -176.802, 3.960, 0.785, 30, 1.5 },
            { "vehi", "vehicles\\c gun turret\\c gun turret_mp", 118.084, -185.346, 6.563, 2.411, 30, 1.5 },
            { "vehi", "vehicles\\ghost\\ghost_mp", 59.765, -116.449, 1.801, 0.524, 30, 1.5 },
            { "vehi", "vehicles\\c gun turret\\c gun turret_mp", 51.315, -154.075, 21.561, 1.346, 30, 1.5 },
            { "vehi", "vehicles\\rwarthog\\rwarthog", 78.124, -131.192, -0.027, 2.112, 30, 1.5 }
            -- Add more vehicles here...
        }
    }
    -- Add more maps here...
}

local os_time = os.time
local table_insert = table.insert
local vehicles = {}               -- Active vehicle instances
local Vehicle = {}                -- Vehicle metatable

local get_object_memory, destroy_object, spawn_object, lookup_tag, read_dword = get_object_memory,
    destroy_object, spawn_object,
    lookup_tag, read_dword

local player_present, player_alive, get_dynamic_player, read_vector3d = player_present,
    player_alive, get_dynamic_player,
    read_vector3d

function Vehicle:new(data)
    setmetatable(data, self)
    self.__index = self
    return data
end

function Vehicle:spawn()
    if self.object then
        destroy_object(self.object)
    end
    self.object = spawn_object('', '', self.x, self.y, self.z, self.yaw, self.meta_id)
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function getVehicleObj(playerId)
    local dyn = get_dynamic_player(playerId)
    if dyn == 0 then return end

    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return end

    return get_object_memory(vehicle_id)
end

local function isInVehicle(playerId, vehicleObj)
    return player_present(playerId) and player_alive(playerId) and getVehicleObj(playerId) == vehicleObj
end

local function isOccupied(vehicleObj)
    for i = 1, 16 do
        if isInVehicle(i, vehicleObj) then
            return true
        end
    end
    return false
end

local function hasMoved(v, obj)
    local cx, cy, cz = read_vector3d(obj + 0x5C)
    local dx, dy, dz = v.x - cx, v.y - cy, v.z - cz
    local dist2 = dx * dx + dy * dy + dz * dz
    return dist2 > (v.respawn_radius * v.respawn_radius)
end

function CheckVehicles()
    local now = os_time()
    for _, v in pairs(vehicles) do
        local obj = get_object_memory(v.object)
        if obj == 0 then
            v:spawn()
            goto continue
        end
        if isOccupied(obj) then
            v.delay = nil
            goto continue
        end

        if hasMoved(v, obj) then
            v.delay = v.delay or (now + v.respawn_time)
            if now >= v.delay then
                v:spawn()
                v.delay = nil
            end
        else
            v.delay = nil
        end

        ::continue::
    end
end

local function initVehicles()
    vehicles = {}

    local map = get_var(0, '$map')
    local mode = get_var(0, '$mode')
    local cfg = VEHICLES[map] and VEHICLES[map][mode]

    if not cfg then return end

    for _, entry in ipairs(cfg) do
        local class, tag, x, y, z, yaw, respawn_time, radius = unpack(entry)
        local meta_id = getTag(class, tag)
        if meta_id then
            local v = Vehicle:new({
                x = x,
                y = y,
                z = z,
                yaw = yaw,
                meta_id = meta_id,
                respawn_time = respawn_time,
                respawn_radius = radius
            })
            v:spawn()
            table_insert(vehicles, v)
        end
    end

    register_callback(cb.EVENT_TICK, 'CheckVehicles')
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnGameStart')
    register_callback(cb.EVENT_GAME_END, 'OnGameEnd')
    OnGameStart()
end

function OnGameStart()
    if get_var(0, '$gt') ~= 'n/a' then
        initVehicles()
    end
end

function OnGameEnd()
    unregister_callback(cb.EVENT_TICK)
end

function OnScriptUnload() end
