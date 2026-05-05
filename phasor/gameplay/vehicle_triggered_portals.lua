--[[
=====================================================================================
SCRIPT NAME:      vehicle_triggered_portals.lua
DESCRIPTION:      When a player sitting in the correct seat of a valid vehicle enters
                  a portal sphere, the entire vehicle is teleported to the
                  destination coordinates.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ----------------------------------------------------------------
local MAPS = {
    -- Coordinate mapping: { origin_x, origin_y, origin_z, radius, dest_x, dest_y, dest_z }
    bloodgulch = {
        { 84.106, -71.677, 16.636, 3.0, 55.223, -132.877, 1.142 },
    }
}

-- Vehicle mapping: {vehicle tag, trigger seat index}
local VALID_VEHICLES = {
    { "vehicles\\rwarthog\\rwarthog", 2 },
    { "vehicles\\ghost\\ghost",       1 },
    { "vehicles\\scorpion\\scorpion", 3 },
}
-- CONFIG END ------------------------------------------------------------------

local is_valid_map = false
local current_portals = nil

local valid_vehicle_tags = {}
local vehicle_tag_to_seat = {}

local function build_cache()
    valid_vehicle_tags = {}
    vehicle_tag_to_seat = {}
    for _, entry in ipairs(VALID_VEHICLES) do
        local tag_path, seat = entry[1], entry[2]
        local tag = gettagid("vehi", tag_path)
        if tag then
            valid_vehicle_tags[tag] = true
            vehicle_tag_to_seat[tag] = seat
        end
    end
end

local function in_sphere(px, py, pz, ox, oy, oz, radius)
    local dx, dy, dz = ox - px, oy - py, oz - pz
    return (dx * dx + dy * dy + dz * dz) <= radius * radius
end

local function get_player_coords(ply_mem)
    local px = readfloat(ply_mem + 0xF8)
    local py = readfloat(ply_mem + 0xFC)
    local pz = readfloat(ply_mem + 0x100)
    return px, py, pz
end

local function get_player_vehicle(player)
    local obj_id = getplayerobjectid(player)
    if not obj_id then return nil end

    local vehicle_id = readdword(getobject(obj_id) + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end
    return vehicle_id
end

function OnNewGame(map)
    is_valid_map = MAPS[map] ~= nil
    current_portals = MAPS[map]
    build_cache()
end

function OnClientUpdate(player)
    if not is_valid_map or not current_portals then return end

    local vehicle_id = get_player_vehicle(player)
    if not vehicle_id then return end

    local veh_obj = getobject(vehicle_id)
    if veh_obj == 0 then return end

    local veh_tag = readdword(veh_obj + 0x31C)
    if not valid_vehicle_tags[veh_tag] then return end

    local required_seat = vehicle_tag_to_seat[veh_tag]
    if not required_seat then return end

    local cur_seat = readword(veh_obj + 0x2F0)
    if cur_seat ~= required_seat then return end

    local ply_mem = getplayer(player)
    if not ply_mem then return end
    local px, py, pz = get_player_coords(ply_mem)

    for _, portal in ipairs(current_portals) do
        local ox, oy, oz, radius, dx, dy, dz =
            portal[1], portal[2], portal[3], portal[4], portal[5], portal[6], portal[7]

        if in_sphere(px, py, pz, ox, oy, oz, radius) then
            movobjectcoords(vehicle_id, dx, dy, dz)
            privatesay(player, "Whoosh!")
            break
        end
    end
end

function GetRequiredVersion() return 200 end

function OnScriptLoad() build_cache() end
