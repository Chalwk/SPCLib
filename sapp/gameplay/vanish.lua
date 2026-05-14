--[[
=====================================================================================
SCRIPT NAME:      vanish.lua
DESCRIPTION:      Allows players to become invisible/invulnerable and unvanish on command.

FEATURES:
                  - Toggle vanish mode with /vanish command
                  - Player position manipulation for invisibility
                  - Objective item detection (flag/oddball)
                  - Configurable weapon/vehicle restrictions
                  - Automatic player state management
                  - Memory-safe position calculations

COMMANDS:
                  /vanish - Toggles vanish state for current player

CONFIGURATION:
                  no_objective_pickup = true   -- Force drop objective (oddball/flag)
                  no_weapon_pickup    = true   -- Force weapon drop when vanishing
                  no_vehicle_entry    = true   -- Force vehicle exit when vanishing
                  vanish_x_offset     = -1000  -- X-axis vanish offset
                  vanish_y_offset     = -1000  -- Y-axis vanish offset
                  vanish_z_offset     = -1000  -- Z-axis vanish offset

LAST UPADTED:     20/8/2025

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]] --

api_version = '1.12.0.0'

---------------------------------
-- CONFIGURATION (Edit these) --
---------------------------------
local config = {
    no_objective_pickup = true, -- Force drop objective (oddball/flag)
    no_weapon_pickup = true,    -- Force weapon drop when vanishing
    no_vehicle_entry = true,    -- Force vehicle exit when vanishing
    vanish_x_offset = -1000,    -- X-axis vanish offset
    vanish_y_offset = -1000,    -- Y-axis vanish offset
    vanish_z_offset = -1000,    -- Z-axis vanish offset
    uncollidable = true,        -- Make player uncollidable
    undamageable = true,        -- Make player undamageable
    camo_god_mode = true,       -- Apply camo and god mode
}
---------------------------------
-- END CONFIGURATION --
---------------------------------

-- Localize frequently used API functions
local read_dword, read_word, read_byte, read_float, read_vector3d, read_bit =
    read_dword, read_word, read_byte, read_float, read_vector3d, read_bit
local write_float, write_bit, execute_command, destroy_object =
    write_float, write_bit, execute_command, destroy_object
local get_object_memory, get_player, get_dynamic_player, player_present, player_alive =
    get_object_memory, get_player, get_dynamic_player, player_present, player_alive

local base_tag_table = 0x40440000
local tag_entry_size = 0x20
local tag_data_offset = 0x14
local bit_check_offset = 0x308
local bit_index = 3

local players = {}

local function send(id, message)
    rprint(id, message)
end

local function has_objective(dyn_player)
    local weapon_id = read_dword(dyn_player + 0x118)
    if weapon_id == 0xFFFFFFFF then return false end

    local weapon_obj = get_object_memory(weapon_id)
    if weapon_obj == 0 then return false end

    local tag_address = read_word(weapon_obj)
    local tag_data_base = read_dword(base_tag_table)
    local tag_data = read_dword(tag_data_base + tag_address * tag_entry_size + tag_data_offset)

    if read_bit(tag_data + bit_check_offset, bit_index) ~= 1 then return false end

    local obj_byte = read_byte(tag_data + 2)
    return obj_byte == 4 or obj_byte == 0 -- Oddball (4) or Flag (0)
end

local function get_player_position(dyn_player)
    local crouch = read_float(dyn_player + 0x50C)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    local z_offset = (crouch == 0) and 0.65 or 0.35 * crouch

    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn_player + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    end

    return x, y, z + z_offset
end

-- Main vanish functionality
local function vanish(player)
    local id = player.id
    local static_player = get_player(id)
    if not static_player then return end

    local dyn_player = get_dynamic_player(id)
    if dyn_player == 0 then return end

    local x, y, z = get_player_position(dyn_player)
    if not x then return end

    -- Relocate player off-map
    write_float(static_player + 0xF8, x + config.vanish_x_offset)
    write_float(static_player + 0xFC, y + config.vanish_y_offset)
    write_float(static_player + 0x100, z + config.vanish_z_offset)

    if config.no_weapon_pickup or (config.no_objective_pickup and has_objective(dyn_player)) then
        execute_command('wdrop ' .. id)
    end

    if config.no_vehicle_entry then
        execute_command('vexit ' .. id)
    end

    -- Apply one-time effects
    if player.set_once then
        player.set_once = false

        if config.camo_god_mode then
            execute_command_sequence('camo ' .. id .. ';god ' .. id)
        end

        if config.uncollidable then
            write_bit(dyn_player + 0x10, 0, 1)
        end

        if config.undamageable then
            write_bit(dyn_player + 0x106, 11, 1)
        end
    end
end

function OnJoin(id)
    players[id] = { id = id, vanished = false, set_once = false }
end

function OnQuit(id)
    players[id] = nil
end

function OnDeath(victim)
    if players[victim] then
        players[victim].vanished = false
    end
end

function OnCommand(id, cmd)
    if not players[id] then return true end
    cmd = cmd:lower()

    if cmd == 'vanish' then
        if not player_alive(id) then
            send(id, 'You must be alive to vanish!')
        elseif not players[id].vanished then
            players[id].vanished = true
            players[id].set_once = true
            send(id, 'You are now vanished!')
        else
            local player_object = read_dword(get_player(id) + 0x34)
            if player_object ~= 0 then
                destroy_object(player_object)
            end
            players[id].vanished = false
            send(id, 'You are now visible!')
        end
        return false
    end
    return true
end

local function validate_player(id)
    return player_present(id) and player_alive(id) and players[id]
end

function OnTick()
    for i = 1, 16 do
        if validate_player(i) and players[i].vanished then
            vanish(players[i])
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end
