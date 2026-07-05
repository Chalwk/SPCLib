--[[
===============================================================================
SCRIPT NAME:      get_object_identity.lua
DESCRIPTION:      Advanced object inspection tool with:
                  - Real-time object targeting
                  - Detailed object information display
                  - Admin-only access control

FEATURES:
                  - Crosshair-based object targeting
                  - Displays type, name, ID and coordinates
                  - Console and RCON output
                  - Toggleable inspection mode

CONFIGURATION:    Adjust these settings:
                  - COMMAND: Toggle command name
                  - PERMISSION_LEVEL: Required admin level

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = '1.12.0.0'

-----------------------------------------
-- Config starts here, edit as needed --
-----------------------------------------

-- Command to toggle get-object mode:
local COMMAND = 'get_objects'
-- Minimum permission level required to use the command:
local PERMISSION_LEVEL = 4

-----------------------------------------
-- Config ends here, do not edit below --
-----------------------------------------

-- Table to store active admin sessions:
local active_admins = {}

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    OnGameStart()
end

function OnGameStart()
    if get_var(0, '$gt') ~= 'n/a' then
        active_admins = {}
    end
end

--- Helper function to get player camera and position vectors ---
local function GetCameraAndPosition(dyn_player)
    local cam_x = read_float(dyn_player + 0x230)
    local cam_y = read_float(dyn_player + 0x234)
    local cam_z = read_float(dyn_player + 0x238)
    local couching = read_float(dyn_player + 0x50C)
    local pos_x, pos_y, pos_z = read_vector3d(dyn_player + 0x5C)

    -- Adjust Z-coordinate for crouching:
    pos_z = pos_z + (couching == 0 and 0.65 or 0.35 * couching)
    return pos_x, pos_y, pos_z, cam_x * 1000, cam_y * 1000, cam_z * 1000
end

--- Helper function to display object information ---
local function DisplayObjectInfo(player, object_type, object_name, meta_id, x, y, z)
    -- Clear player RCON:
    for _ = 1, 25 do
        rprint(player, " ")
    end

    -- Send details to player's RCON:
    rprint(player, 'Type: ' .. object_type)
    rprint(player, 'Name: ' .. object_name)
    rprint(player, 'Meta: ' .. meta_id)
    rprint(player, 'X, Y, Z: ' .. x .. ', ' .. y .. ', ' .. z)

    -- Log details to server console:
    cprint('Type: ' .. object_type)
    cprint('Name: ' .. object_name)
    cprint('Meta: ' .. meta_id)
    cprint('X, Y, Z: ' .. x .. ', ' .. y .. ', ' .. z)
end

function OnTick()
    for player, data in pairs(active_admins) do
        local dyn_player = get_dynamic_player(player)
        if dyn_player ~= 0 and player_alive(player) then
            local px, py, pz, cx, cy, cz = GetCameraAndPosition(dyn_player)
            local ignore_player = read_dword(get_player(player) + 0x34)

            local success, _, _, _, target = intersect(px, py, pz, cx, cy, cz, ignore_player)
            if success and target then
                local is_shooting = read_float(dyn_player + 0x490)
                if is_shooting ~= data.last_shoot and is_shooting == 1 then
                    local object = get_object_memory(target)
                    if object ~= 0 then
                        local obj_type = read_byte(object + 0xB4)
                        local obj_name = read_string(read_dword(read_word(object) * 32 + 0x40440038))
                        local meta_id = read_dword(object)
                        local ox, oy, oz = read_vector3d(object + 0x5C)

                        local type_string = ({ [0] = 'bipd', [1] = 'vehi', [2] = 'eqip', [3] = 'weap' })[obj_type]
                            or 'unknown'
                        DisplayObjectInfo(player, type_string, obj_name, meta_id, ox, oy, oz)
                    end
                end
                data.last_shoot = is_shooting
            end
        end
    end
end

local function hasPermission(playerId)
    local level = tonumber(get_var(playerId, '$lvl'))
    if level >= PERMISSION_LEVEL then
        return true
    end

    rprint(playerId, 'You do not have permission to execute that command.')
    return false
end

function OnCommand(player, cmd)
    if cmd:lower():sub(1, #COMMAND) == COMMAND then
        if not hasPermission(player) then
            return false
        end

        if active_admins[player] then
            active_admins[player] = nil
            rprint(player, 'Get Object mode disabled.')
        else
            active_admins[player] = { last_shoot = 0 }
            rprint(player, 'Get Object mode enabled.')
        end

        return false
    end
end

function OnScriptUnload()
    -- Cleanup not required
end
