--[[
=====================================================================================
SCRIPT NAME:      weapon_durability_jam_system.lua
DESCRIPTION:      Realistic weapon degradation and jamming system that adds
                  durability mechanics to Halo's weapons.

KEY FEATURES:
                 - Weapon-specific durability profiles
                 - Dynamic jamming probability based on condition
                 - Melee-action unjamming mechanic
                 - Ammo state preservation during jams
                 - Energy weapon support
                 - Vehicle usage detection
                 - Comprehensive debug mode

CONFIGURATION OPTIONS:
                 - Global durability thresholds
                 - Per-weapon decay rates
                 - Jam chance multipliers
                 - Energy weapon classification
                 - Unjam durability cost

LAST UPADTED:     August, 2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- FIXME 1: When a player picks up ammo with a jammed weapon, it auto-reloads and they can fire.
-- FIXME 2: Doesn't immediately detect when a player fires their weapon.

-- CONFIG STARTS ---------------------------------------------------------------

local MAX_DURABILITY = 100.0        -- Starting durability value                (default: 100.0)
local NO_JAM_THRESHOLD = 90.0       -- No jamming occurs above this durability  (default: 90.0)
local UNJAM_DURABILITY_COST = 1.0   -- Durability cost to unjam weapon          (default: 1.0)
local JAM_CHANCE_MULTIPLIER = 0.095 -- Base chance multiplier for jams          (default: 0.015)
local BASE_DECAY = 1.0              -- Base decay rate                          (default: 1.0)

-- Weapon-specific decay rates
local DECAY_RATES = {
    ['weapons\\plasma pistol\\plasma pistol'] = 1.0,     -- default: 1.0
    ['weapons\\plasma rifle\\plasma rifle'] = 1.2,       -- default: 1.2
    ['weapons\\assault rifle\\assault rifle'] = 1.4,     -- default: 1.4
    ['weapons\\pistol\\pistol'] = 4.10,                  -- default: 4.10
    ['weapons\\needler\\mp_needler'] = 4.20,             -- default: 4.20
    ['weapons\\flamethrower\\flamethrower'] = 7.05,      -- default: 7.05
    ['weapons\\shotgun\\shotgun'] = 8.0,                 -- default: 8.0
    ['weapons\\sniper rifle\\sniper rifle'] = 23.0,      -- default: 23.0
    ['weapons\\plasma_cannon\\plasma_cannon'] = 25.0,    -- default: 25.0
    ['weapons\\rocket launcher\\rocket launcher'] = 40.0 -- default: 40.0
}

local ENERGY_WEAPONS = {
    ['weapons\\plasma pistol\\plasma pistol'] = true,
    ['weapons\\plasma rifle\\plasma rifle'] = true,
    ['weapons\\plasma_cannon\\plasma_cannon'] = true
}

-- CONFIG ENDS ---------------------------------------------------------------

api_version = '1.12.0.0'

-- Debug toggle
local DEBUG = true -- Set false to disable debug output

-- System State
local weapon_state = {}       -- weapon_id -> {durability, jammed, jam_applied, ammo_snapshot}
local decay_rates_by_tag = {} -- tag_id -> decay_rate
local is_energy_by_tag = {}
local game_active = false

-- Memory Address Constants
local PLAYER_OBJECT_OFFSET = 0x118
local PLAYER_VEHICLE_OFFSET = 0x11C
local PLAYER_INPUT_OFFSET = 0x208
local PLAYER_FIRING_OFFSET = 0x490
local WEAPON_OVERHEAT_OFFSET = 0x22C
local WEAPON_PRIMARY_AMMO_OFFSET = 0x2B8
local WEAPON_RESERVE_AMMO_OFFSET = 0x2B6
local WEAPON_BATTERY_OFFSET = 0x240

local clock, format = os.clock, string.format

local function debug_print(...)
    if DEBUG then
        cprint("[DEBUG] " .. format(...))
    end
end

local function melee_button_pressed(dyn_player)
    return read_word(dyn_player + PLAYER_INPUT_OFFSET) == 128
end

local function is_firing(dyn_player)
    return read_float(dyn_player + PLAYER_FIRING_OFFSET) == 1
end

local function is_overheating(weapon_obj)
    return read_bit(weapon_obj + WEAPON_OVERHEAT_OFFSET, 0) == 1
end

local function in_vehicle(dyn_player)
    local vehicle_id = read_dword(dyn_player + PLAYER_VEHICLE_OFFSET)
    return vehicle_id ~= 0xFFFFFFFF and get_object_memory(vehicle_id) ~= 0
end

-- Weapon state
local function initialize_weapon_state(weapon_id, weapon_tag)
    local current_state = weapon_state[weapon_id]

    -- Reset state if weapon ID is reused for a different weapon type
    if current_state and current_state.tag_id ~= weapon_tag then
        debug_print("[DEBUG] Weapon ID %d reused (old tag: %d, new tag: %d). Resetting state.",
            weapon_id, current_state.tag_id, weapon_tag)
        weapon_state[weapon_id] = nil
        current_state = nil
    end

    -- Initialize new state if needed
    if not current_state then
        weapon_state[weapon_id] = {
            tag_id = weapon_tag,
            durability = MAX_DURABILITY,
            jammed = false,
            jam_applied = nil,
            ammo_snapshot = nil
        }
    end

    return weapon_state[weapon_id]
end

-- Save ammo state for given weapon
local function getAmmunition(weapon_obj, is_energy)
    if is_energy then
        local battery = read_float(weapon_obj + WEAPON_BATTERY_OFFSET)
        local shots_fired = 100 - math.floor(battery * 100)
        return { battery = shots_fired }
    else
        return {
            primary = read_word(weapon_obj + WEAPON_PRIMARY_AMMO_OFFSET),
            reserve = read_word(weapon_obj + WEAPON_RESERVE_AMMO_OFFSET)
        }
    end
end

-- Apply jam by saving current ammo state and setting ammo to zero
local function apply_jam(weapon_obj, weapon_id, state, is_energy, player_id)
    state.ammo_snapshot = getAmmunition(weapon_obj, is_energy)
    if is_energy then
        execute_command('battery ' .. player_id .. ' 0')
    else
        execute_command('ammo ' .. player_id .. ' 0')
        execute_command('mag ' .. player_id .. ' 0')
    end
    sync_ammo(weapon_id)
end

-- Clear jam by restoring saved ammo state
local function clear_jam(weapon_obj, weapon_id, state, is_energy, player_id)
    if is_energy then
        execute_command('battery ' .. player_id .. ' ' .. state.ammo_snapshot.battery .. ' 0')
    else
        write_word(weapon_obj + WEAPON_PRIMARY_AMMO_OFFSET, state.ammo_snapshot.primary)
        write_word(weapon_obj + WEAPON_RESERVE_AMMO_OFFSET, state.ammo_snapshot.reserve)
    end
    sync_ammo(weapon_id)
    state.ammo_snapshot = nil
    return false -- Clear jam state
end

-- Core Degradation Logic
local function process_weapon_decay(dyn_player, state, decay_rate)
    local decay = 0
    if is_firing(dyn_player) then
        decay = BASE_DECAY * decay_rate
        state.durability = state.durability - decay
    end
    return decay > 0
end

-- Jam state logic with jam_applied fix + debug
local function process_jam_state(player_id, dyn_player, weapon_id, weapon_obj, state, is_energy)
    if state.jammed then
        if not state.jam_applied then
            apply_jam(weapon_obj, weapon_id, state, is_energy, player_id)
            state.jam_applied = true
            rprint(player_id, "Your weapon is jammed! Press melee to unjam.")
        end

        if melee_button_pressed(dyn_player) then
            state.jammed = clear_jam(weapon_obj, weapon_id, state, is_energy, player_id)
            state.jam_applied = nil
            state.durability = state.durability - UNJAM_DURABILITY_COST
            rprint(player_id, "Weapon unjammed!")
            debug_print("[DEBUG] Player %d weapon UNJAMMED at durability %.2f", player_id, state.durability)
            return "unjammed"
        end
        return "jammed"
    end

    if state.durability < NO_JAM_THRESHOLD and is_firing(dyn_player) then
        local jam_chance = ((NO_JAM_THRESHOLD - state.durability) / NO_JAM_THRESHOLD) * JAM_CHANCE_MULTIPLIER
        debug_print("[DEBUG] Player %d | Durability: %.2f | Jam chance: %.4f",
            player_id, state.durability, jam_chance)

        if math.random() < jam_chance then
            state.jammed = true
            state.jam_applied = false
            debug_print("[DEBUG] Player %d weapon JAMMED at durability %.2f", player_id, state.durability)

            return "jammed"
        end
    end

    return "functional"
end

-- Main Processing Function
local function process_player_weapon(player_id)
    local dyn_player = get_dynamic_player(player_id)
    if dyn_player == 0 then return end
    if in_vehicle(dyn_player) or not game_active then return end

    local weapon_id = read_dword(dyn_player + PLAYER_OBJECT_OFFSET)
    if weapon_id == 0xFFFFFFFF then return end

    local weapon_obj = get_object_memory(weapon_id)
    if weapon_obj == 0 then return end

    local weapon_tag = read_dword(weapon_obj)
    local decay_rate = decay_rates_by_tag[weapon_tag]
    if not decay_rate then return end

    -- Check if weapon is energy-based
    local is_energy = is_energy_by_tag[weapon_tag] or false

    local state = initialize_weapon_state(weapon_id, weapon_tag)

    -- Skip overheat check only if not jammed
    if is_overheating(weapon_obj) and not state.jammed then return end

    local jam_result = process_jam_state(player_id, dyn_player, weapon_id, weapon_obj, state, is_energy)

    if jam_result == "functional" then
        process_weapon_decay(dyn_player, state, decay_rate)
        if state.durability <= 0 then
            debug_print("[DEBUG] Player %d weapon destroyed at durability %.2f", player_id, state.durability)

            destroy_object(weapon_id)
            weapon_state[weapon_id] = nil
            rprint(player_id, "Your weapon has been destroyed!")
        end
    end
end

-- SAPP Event Handlers
function OnTick()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            process_player_weapon(i)
        end
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    for tag_path, rate in pairs(DECAY_RATES) do
        local tag_id = lookup_tag('weap', tag_path)
        if tag_id ~= 0 then
            local tag_id_value = read_dword(tag_id + 0xC)
            decay_rates_by_tag[tag_id_value] = rate
            is_energy_by_tag[tag_id_value] = ENERGY_WEAPONS[tag_path] or false
        end
    end

    game_active = true
    weapon_state = {}
end

function OnEnd()
    game_active = false
end

function OnSpawn(id)
    local dyn_player = get_dynamic_player(id)
    if dyn_player == 0 then return end
    local weapon_id = read_dword(dyn_player + PLAYER_OBJECT_OFFSET)
    if weapon_id ~= 0xFFFFFFFF then
        weapon_state[weapon_id] = nil
    end
end

function OnScriptLoad()
    math.randomseed(clock())
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
end