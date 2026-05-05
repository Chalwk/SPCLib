--[[
=====================================================================================
SCRIPT NAME:      mode_destroy_gun.lua
DESCRIPTION:      Enables destructive weapon mode that can delete in-game objects
                  - Toggle with: /destroygun [on/off] (requires permission level 1)
                  - Destroys any object in weapon crosshairs when fired
                  - Shows object type and name in confirmation message
                  - Works with all weapon types
                  - Configurable permission requirements

                  WARNING:
                  This powerful tool can significantly impact gameplay and map integrity.
                  Use with caution on live servers.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local destroy_command = "destroygun"
local destroy_permission_level = 1

local weapon_status = {}
local destroy_mode = {}

local function initialize_player(PlayerIndex)
    weapon_status[PlayerIndex] = 0
    destroy_mode[PlayerIndex] = false
end

local function get_player_coordinates(player_object)
    local px, py, pz = read_vector3d(player_object + 0x5c)
    local couching = read_float(player_object + 0x50C)
    pz = pz + (couching == 0 and 0.65 or 0.35 * couching)
    return px, py, pz
end

local function handle_destroy_mode(PlayerIndex)
    local player_object = get_dynamic_player(PlayerIndex)
    local playerX, playerY, playerZ = read_float(player_object + 0x230), read_float(player_object + 0x234), read_float(player_object + 0x238)
    local px, py, pz = get_player_coordinates(player_object)
    local ignore_player = read_dword(get_player(PlayerIndex) + 0x34)
    local success, _, _, _, target = intersect(px, py, pz, playerX * 1000, playerY * 1000, playerZ * 1000, ignore_player)

    if success and target then
        local shot_fired = read_float(player_object + 0x490)
        if shot_fired ~= weapon_status[PlayerIndex] and shot_fired == 1 then
            local target_object = get_object_memory(target)
            if target_object ~= 0 then
                local ObjectType = read_byte(target_object + 0xB4)
                local ObjectName = read_string(read_dword(read_word(target_object) * 32 + 0x40440038))
                local type = ({ [0] = "bipd", [1] = "vehi", [2] = "weap", [3] = "eqip" })[ObjectType] or "unknown"
                for _ = 1, 30 do
                    rprint(PlayerIndex, " ")
                end
                rprint(PlayerIndex, "Destroyed: " .. type .. ", " .. ObjectName)
                destroy_object(target)
            end
        end
        weapon_status[PlayerIndex] = shot_fired
    end
end

local function CMDSplit(CMD)
    local t = {}
    for str in CMD:gmatch("([^%s]+)") do
        table.insert(t, str)
    end
    return t
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) and destroy_mode[i] then
            handle_destroy_mode(i)
        end
    end
end

function OnPlayerSpawn(PlayerIndex)
    initialize_player(PlayerIndex)
end

function OnServerCommand(PlayerIndex, Command)
    local t = CMDSplit(Command)
    if t[1] and t[1]:lower() == destroy_command then
        if tonumber(get_var(PlayerIndex, "$lvl")) >= destroy_permission_level then
            if t[2] then
                if t[2] == "on" or t[2] == "1" or t[2] == "true" then
                    destroy_mode[PlayerIndex] = true
                    rprint(PlayerIndex, "Destroy Mode enabled.")
                elseif t[2] == "off" or t[2] == "0" or t[2] == "false" then
                    destroy_mode[PlayerIndex] = false
                    rprint(PlayerIndex, "Destroy Mode disabled.")
                else
                    rprint(PlayerIndex, "Invalid Syntax")
                end
            else
                rprint(PlayerIndex, "Invalid Syntax")
            end
        else
            rprint(PlayerIndex, "You do not have permission to execute that command!")
        end
        return false
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], "OnTick")
    register_callback(cb['EVENT_SPAWN'], "OnPlayerSpawn")
    register_callback(cb['EVENT_COMMAND'], "OnServerCommand")
end

function OnScriptUnload()
    -- N/A
end