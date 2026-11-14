--[[
===============================================================================
SCRIPT NAME:      get_object_identity.lua
DESCRIPTION:      Inspect the object targeted by an admin's crosshair.
                  Toggle with the configured command while aiming and firing.

CONFIGURATION:    COMMAND, PERMISSION_LEVEL

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

local COMMAND = "get_objects"
local PERMISSION_LEVEL = 4

local TAG_TABLE_BASE = 0x40440000
local TAG_ENTRY_SIZE = 0x20
local MAX_RAY_DISTANCE = 1000
local INVALID_OBJECT_ID = 0xFFFFFFFF

local active_admins = {}
local tag_array, tag_count = nil, 0

local function refreshTagTable()
    tag_array, tag_count = nil, 0

    if get_var(0, "$gt") == "n/a" then return end

    local array = read_dword(TAG_TABLE_BASE)
    local count = read_dword(TAG_TABLE_BASE + 0xC)
    if array and array ~= 0 and count and count > 0 then
        ---@diagnostic disable-next-line: assign-type-mismatch
        tag_array, tag_count = array, count
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    OnStart()
end

function OnScriptUnload()
    active_admins = {}
end

function OnStart()
    active_admins = {}
    refreshTagTable()
end

function OnLeave(player_id)
    active_admins[player_id] = nil
end

local function displayObjectInfo(player_id, object_id, object_type, object_name, meta_id, x, y, z)
    for _ = 1, 25 do
        rprint(player_id, " ")
    end

    local lines = {
        string.format("Type: %s", object_type), string.format("Name: %s", object_name),
        string.format("Object ID: %u", object_id), string.format("Meta ID: %u", meta_id),
        string.format("X, Y, Z: %.2f, %.2f, %.2f", x, y, z)
    }

    for _, line in ipairs(lines) do
        rprint(player_id, line)
        cprint(line)
    end
end

local function getObjectIdentity(object)
    if not tag_array or tag_count == 0 then return nil end

    local tag_index = read_word(object)
    if tag_index >= tag_count then return nil end

    local tag_entry = tag_array + tag_index * TAG_ENTRY_SIZE
    local tag_name_address = read_dword(tag_entry + 0x10)
    local tag_name = tag_name_address ~= 0 and read_string(tag_name_address) or nil
    local class = read_dword(tag_entry)
    local tag_class = string.char(
        math.floor(class / 0x1000000) % 0x100,
        math.floor(class / 0x10000) % 0x100,
        math.floor(class / 0x100) % 0x100,
        ---@diagnostic disable-next-line: param-type-mismatch
        class % 0x100
    )

    return tag_class, tag_name and tag_name ~= "" and tag_name or "<unnamed>", read_dword(tag_entry + 0xC)
end

local function inspectTarget(player_id, dyn_player)
    local camera_x, camera_y, camera_z = read_vector3d(dyn_player + 0x230)
    local x, y, z = read_vector3d(dyn_player + 0x5C)
    local crouch = read_float(dyn_player + 0x50C)
    z = z + 0.65 - (0.3 * crouch)

    local static_player = get_player(player_id)
    if not static_player or static_player == 0 then return end
    local ignored_object = read_dword(static_player + 0x34)

    local hit, _, _, _, object_id = intersect(
        x, y, z, camera_x * MAX_RAY_DISTANCE, camera_y * MAX_RAY_DISTANCE, camera_z * MAX_RAY_DISTANCE, ignored_object
    )
    if not hit or object_id == INVALID_OBJECT_ID then return end

    local object = get_object_memory(object_id)
    if not object or object == 0 then return end

    local object_type, object_name, meta_id = getObjectIdentity(object)
    if not object_type then return end

    local object_x, object_y, object_z = read_vector3d(object + 0x5C)
    displayObjectInfo(player_id, object_id, object_type, object_name, meta_id, object_x, object_y, object_z)
end

function OnTick()
    for player_id, data in pairs(active_admins) do
        if not player_present(player_id) then
            active_admins[player_id] = nil
        elseif not player_alive(player_id) then
            data.last_shoot = 0
        else
            local dyn_player = get_dynamic_player(player_id)
            if dyn_player == 0 then
                data.last_shoot = 0
            else
                local shooting = read_float(dyn_player--[[@cast -?]] + 0x490)
                local just_shot = shooting == 1 and data.last_shoot ~= 1
                data.last_shoot = shooting

                if just_shot then
                    inspectTarget(player_id, dyn_player)
                end
            end
        end
    end
end

local function hasPermission(player_id)
    local level = tonumber(get_var(player_id, "$lvl"))
    if level >= PERMISSION_LEVEL then return true end

    rprint(player_id, "You do not have permission to execute that command.")
    return false
end

function OnCommand(player_id, command)
    local command_name = type(command) == "string" and command:match("^%s*(%S+)")
    if not command_name or command_name:lower() ~= COMMAND then return end

    if not hasPermission(player_id) then return false end

    if active_admins[player_id] then
        active_admins[player_id] = nil
        rprint(player_id, "Get Object mode disabled.")
    else
        active_admins[player_id] = { last_shoot = 0 }
        rprint(player_id, "Get Object mode enabled.")
    end

    return false
end
