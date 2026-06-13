--[[
=====================================================================================
SCRIPT NAME:      object_spawner.lua
DESCRIPTION:      Persistent object spawning with automatic respawn.

                  Spawns configured objects (weapons, vehicles, equipment, etc.) at
                  defined coordinates. The object automatically respawns after being
                  picked up, destroyed, or moved beyond a set radius from its origin.
                  Vehicles only respawn when unoccupied and moved.

                  When a weapon is picked up by a player, the script will NOT destroy
                  the held weapon on respawn, it safely ignores destruction of the
                  old object if a player is carrying it.

                  Config format:
                   { tag_class, "tag_path", x, y, z, rotation, respawn_time, radius },

                  Examples:
                   -- Sniper rifle (weapon) at center of Blood Gulch, respawns 30s after pickup/move
                   { "weap", "weapons\\sniper rifle\\sniper rifle", 0, 0, 0.5, 0, 30, 1.5 },
                   -- Rocket launcher (weapon)
                   { "weap", "weapons\\rocket launcher\\rocket launcher", 10, 10, 0.5, 90, 45, 2.0 },
                   -- Warthog (vehicle) - respawns 60s after moving if empty
                   { "vehi", "vehicles\\warthog\\mp_warthog", 20, 20, 0, 180, 60, 3.0 },
                   -- Active camouflage (equipment)
                   { "eqip", "powerups\\active camouflage", -15, 5, 0.2, 0, 45, 1.0 },

                  tag_class options: "weap", "vehi", "eqip", "bipd" (biped), etc.

Copyright (c) 2021-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start ---------------------------------------------------------------------------------
api_version = "1.12.0.0"

local maps = {
    bloodgulch = {
        { "weap", "weapons\\sniper rifle\\sniper rifle", 90.899, -159.633, 1.704, 1.587, 30, 1.5 },
        -- Add more entries below:
    },
    -- Add more maps here:
}
-- CONFIG end -----------------------------------------------------------------------------------

local os_time = os.time
local table_insert = table.insert
local get_var, lookup_tag, read_dword = get_var, lookup_tag, read_dword
local spawn_object, destroy_object = spawn_object, destroy_object
local get_object_memory, get_dynamic_player = get_object_memory, get_dynamic_player
local read_vector3d = read_vector3d
local player_present, player_alive = player_present, player_alive

local MOVE_CHECK_INTERVAL = 0.5 -- to reduce get_object_memory calls

local Objects = {}
Objects.__index = Objects

function Objects:new(data)
    setmetatable(data, self)
    data.object = nil
    data.respawn_timer = nil
    return data
end

local function is_weapon_in_inventory(object_id)
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn = get_dynamic_player(i)
            if dyn ~= 0 then
                for slot = 0, 3 do
                    local weapon_id = read_dword(dyn + 0x2F8 + (slot * 4))
                    if weapon_id ~= 0xFFFFFFFF and weapon_id == object_id then return true end
                end
            end
        end
    end
    return false
end

function Objects:spawn()
    if self.object then
        if not self.is_vehicle and is_weapon_in_inventory(self.object) then
            -- The weapon is in a player's hands; leave it alone.
            -- Forget reference so a new ground weapon can be spawned.
        else
            destroy_object(self.object)
        end
        self.object = nil
    end
    self.object = spawn_object('', '', self.x, self.y, self.z, self.rot, self.meta_id)
    self.respawn_timer = nil
end

local function get_tag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function get_vehicle_object(id)
    local dyn = get_dynamic_player(id)
    if dyn == 0 then return nil end
    local veh_id = read_dword(dyn + 0x11C)
    if veh_id == 0xFFFFFFFF then return nil end
    return get_object_memory(veh_id)
end

local function is_occupied(object)
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local vehAddr = get_vehicle_object(i)
            if vehAddr and vehAddr == object then return true end
        end
    end
    return false
end

local function has_moved(v, object)
    local cx, cy, cz = read_vector3d(object + 0x5C)
    local dx, dy, dz = v.x - cx, v.y - cy, v.z - cz
    local distSq = dx * dx + dy * dy + dz * dz
    return distSq > (v.respawn_radius * v.respawn_radius)
end

local active = {}
local last_move_check = 0

function OnTick()
    if #active == 0 then return end

    local now = os_time()
    local check_movement = (now - last_move_check >= MOVE_CHECK_INTERVAL)
    if check_movement then last_move_check = now end

    for i = 1, #active do
        local v = active[i]

        if v.respawn_timer then
            if now >= v.respawn_timer then
                v:spawn()
            elseif check_movement and v.object then
                if get_object_memory(v.object) == 0 then v.object = nil end
            end
        elseif check_movement then
            local object = get_object_memory(v.object)
            if object == 0 then
                v.object = nil
                v.respawn_timer = now + v.respawn_time
            elseif v.is_vehicle then
                if not is_occupied(object) and has_moved(v, object) then
                    v.respawn_timer = now + v.respawn_time
                end
            else
                if has_moved(v, object) then
                    v.respawn_timer = now + v.respawn_time
                end
            end
        end
    end
end

local function check_object(type, path)
    local meta = get_tag(type, path)
    if not meta then
        print("[object_spawner] Invalid object type or path: " .. type .. " \"" .. path .. "\"")
    end
    return meta
end

local function init_objects()
    active = {}
    local map = get_var(0, "$map")
    local cfg = maps[map]
    if not cfg then return end

    for _, entry in ipairs(cfg) do
        local type_str, path, x, y, z, rot, respawn_time, radius = unpack(entry)
        local meta_id = check_object(type_str, path)
        if meta_id then
            local obj = Objects:new({
                meta_id = meta_id,
                x = x,
                y = y,
                z = z,
                rot = rot,
                respawn_time = respawn_time,
                respawn_radius = radius,
                is_vehicle = (type_str == "vehi")
            })
            obj:spawn()
            table_insert(active, obj)
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") ~= "n/a" then init_objects() end
end

function OnEnd() active = {} end

function OnScriptUnload() end
