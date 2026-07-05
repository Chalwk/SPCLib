--[[
=====================================================================================
SCRIPT NAME:      flashlight_vehicle_entry.lua
DESCRIPTION:      Allows players to enter unoccupied vehicles by:
                  1. Aiming at the vehicle
                  2. Pressing flashlight key (default: L key)

                  Supported vehicles:
                  - Ghost
                  - Rocket Warthog
                  - Banshee
                  - Warthog
                  - Scorpion
                  - Gun Turret

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration
local vehicles = {
    ['vehicles\\ghost\\ghost_mp'] = true,
    ['vehicles\\rwarthog\\rwarthog'] = true,
    ['vehicles\\banshee\\banshee_mp'] = true,
    ['vehicles\\warthog\\mp_warthog'] = true,
    ['vehicles\\scorpion\\scorpion_mp'] = true,
    ['vehicles\\c gun turret\\c gun turret_mp'] = true
}

api_version = '1.12.0.0'

-- Player Data
local players = {}

-- Utility Functions
local function GetTag(type, name)
    local tag = lookup_tag(type, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

local function GetCameraPosition(dyn)
    return read_float(dyn + 0x230) * 1000, read_float(dyn + 0x234) * 1000, read_float(dyn + 0x238) * 1000
end

local function GetPlayerPosition(dyn)
    local crouch = read_float(dyn + 0x50C)
    local x, y, z = read_vector3d(dyn + 0x5C)
    return x, y, (crouch == 0 and z + 0.65 or z + 0.35)
end

local function IsVehicleOccupied(obj)
    for i = 1, 16 do
        local dyn = get_dynamic_player(i)
        if player_present(i) and player_alive(i) and dyn ~= 0 then
            local vehicle = read_dword(dyn + 0x11C)
            local object = get_object_memory(vehicle)
            if object ~= 0 and vehicle ~= 0xFFFFFFFF and object == obj then
                return true
            end
        end
    end
    return false
end

local function IsValidVehicle(object)
    return (vehicles[read_dword(object)] and not IsVehicleOccupied(object))
end

local function GetIntersectingVehicle(px, py, pz, cx, cy, cz, ply)
    local ignore = read_dword(get_player(ply) + 0x34)
    local success, _, _, _, map_object = intersect(px, py, pz, cx, cy, cz, ignore)
    local object = get_object_memory(map_object)
    return (object ~= 0 and IsValidVehicle(object) and (success and map_object) or nil)
end

local function LoadVehicleTags()
    local tagMap = {}
    for k, v in pairs(vehicles) do
        local tag = GetTag('vehi', k)
        if tag then
            tagMap[tag] = v
        end
    end
    return tagMap
end

-- Event Handlers
function OnJoin(playerId)
    players[playerId] = { flashlight = 0 }
end

function OnQuit(playerId)
    players[playerId] = nil
end

function OnTick()
    for playerId, data in pairs(players) do
        local dyn = get_dynamic_player(playerId)
        if dyn ~= 0 and player_alive(playerId) then
            local px, py, pz = GetPlayerPosition(dyn)
            local cx, cy, cz = GetCameraPosition(dyn)
            local flashlight = read_bit(dyn + 0x208, 4)
            local vehicle = GetIntersectingVehicle(px, py, pz, cx, cy, cz, playerId)

            if vehicle and flashlight ~= data.flashlight and flashlight == 1 then
                enter_vehicle(vehicle, playerId, 0)
            end

            data.flashlight = flashlight
        end
    end
end

function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        players = {}
        vehicles = LoadVehicleTags()
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnScriptUnload()
    -- No actions required on unload
end
