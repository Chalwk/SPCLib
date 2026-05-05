--[[
=====================================================================================
SCRIPT NAME:      nitrous_boost.lua
DESCRIPTION:      Vehicle nitrous boost system with:
                  - Flashlight key toggle for activation/deactivation
                  - Boost multiplier applied to vehicle velocity
                  - Finite nitrous resource with configurable drain & regen rates
                  - Automatic cooldown state when depleted
                  - HUD display showing nitrous bar, percentage, and status
                  - State persistence across vehicle entry/exit

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIGURATION
local nitrous_max = 100
local boost_multiplier = 1.007
local drain_rate = 0.5
local regen_rate = 0.1
local min_threshold = 10
-- END CONFIG

api_version = '1.12.0.0'

-- Cache global functions
local get_dynamic_player, write_float, read_bit = get_dynamic_player, write_float, read_bit
local player_present, player_alive, rprint = player_present, player_alive, rprint
local string_rep, string_format = string.rep, string.format
local math_floor, math_min = math.floor, math.min

-- Nitrous states
local NITROUS_STATE = {
    DISABLED = 0,
    ACTIVE = 1,
    COOLDOWN = 2
}

-- Player state tracking
local players = {}

local function playerValid(id)
    local dyn_player = get_dynamic_player(id)
    return player_present(id) and player_alive(id) and dyn_player ~= 0 and dyn_player
end

local function getVehicle(dyn)
    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    local seat = read_word(dyn + 0x2F0)
    if seat ~= 0 then return nil end

    local vehicle_object = get_object_memory(vehicle_id)
    return vehicle_object ~= 0 and vehicle_object or nil
end

local function getVelocity(vehicle)
    local vel_x = read_float(vehicle + 0x68)
    local vel_y = read_float(vehicle + 0x6C)
    local vel_z = read_float(vehicle + 0x70)
    return vel_x, vel_y, vel_z
end

local function setVelocity(vehicle, vel_x, vel_y, vel_z)
    write_float(vehicle + 0x68, vel_x)
    write_float(vehicle + 0x6C, vel_y)
    write_float(vehicle + 0x70, vel_z)
end

local function clear_hud(id)
    for _ = 1, 25 do rprint(id, " ") end
end

local function update_nitrous_hud(player_id, nitrous, state)
    clear_hud(player_id)

    local status_text = ""
    if state == NITROUS_STATE.ACTIVE then
        status_text = "| BOOSTING |"
    elseif state == NITROUS_STATE.COOLDOWN then
        status_text = "| COOLDOWN |"
    else
        status_text = "| READY |"
    end

    local segments = 20
    local filled = math_floor((nitrous / nitrous_max) * segments)
    local bar = string_rep("|", filled) .. string_rep(" ", segments - filled)

    rprint(player_id, string_format("NITROUS: %s %d%% %s", bar, math_floor(nitrous), status_text))
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnLeave')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    players = {}
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnJoin(id)
    players[id] = {
        nitrous = nitrous_max,
        boost_state = NITROUS_STATE.DISABLED,
        last_flashlight = 0,
        was_in_vehicle = false,
        last_boost_state = NITROUS_STATE.DISABLED,
        last_nitrous = nitrous_max
    }
end

function OnLeave(id)
    players[id] = nil
end

function OnTick()
    for i = 1, 16 do
        local player = players[i]
        local dyn_player = playerValid(i)

        if not dyn_player or not player then goto continue end

        local vehicle_object = getVehicle(dyn_player)
        local flashlight_state = read_bit(dyn_player + 0x208, 4)
        local is_in_vehicle = vehicle_object ~= nil

        -- Show initial message when entering a vehicle
        if is_in_vehicle and not player.was_in_vehicle then
            update_nitrous_hud(i, player.nitrous, player.boost_state)
        elseif not is_in_vehicle and player.was_in_vehicle then
            clear_hud(i) -- Clear HUD when exiting vehicle
        end

        -- Only process nitrous if player is in a vehicle
        if is_in_vehicle then
            -- Detect flashlight toggle
            if flashlight_state ~= player.last_flashlight then
                player.last_flashlight = flashlight_state

                if flashlight_state == 1 then
                    if player.boost_state == NITROUS_STATE.DISABLED and player.nitrous > min_threshold then
                        player.boost_state = NITROUS_STATE.ACTIVE
                        update_nitrous_hud(i, player.nitrous, player.boost_state) -- Show HUD on activation
                    elseif player.boost_state == NITROUS_STATE.ACTIVE then
                        player.boost_state = NITROUS_STATE.DISABLED
                        update_nitrous_hud(i, player.nitrous, player.boost_state) -- Show HUD on deactivation
                    end
                end
            end

            -- State machine
            if player.boost_state == NITROUS_STATE.ACTIVE then
                -- Apply boost to vehicle velocity
                local vel_x, vel_y, vel_z = getVelocity(vehicle_object)
                setVelocity(vehicle_object, vel_x * boost_multiplier, vel_y * boost_multiplier, vel_z * boost_multiplier)

                -- Drain nitrous
                player.nitrous = player.nitrous - drain_rate

                -- Update HUD at 5% intervals during active boost
                if math_floor(player.nitrous) % 5 == 0 and math_floor(player.nitrous) ~= math_floor(player.last_nitrous) then
                    update_nitrous_hud(i, player.nitrous, player.boost_state)
                end

                if player.nitrous <= 0 then
                    player.nitrous = 0
                    player.boost_state = NITROUS_STATE.COOLDOWN
                    update_nitrous_hud(i, player.nitrous, player.boost_state) -- Show HUD on depletion
                end
            elseif player.boost_state == NITROUS_STATE.COOLDOWN then
                -- Regenerate nitrous
                player.nitrous = player.nitrous + regen_rate

                if player.nitrous >= nitrous_max then
                    player.nitrous = nitrous_max
                    player.boost_state = NITROUS_STATE.DISABLED
                    update_nitrous_hud(i, player.nitrous, player.boost_state) -- Show HUD on full regeneration
                elseif math_floor(player.nitrous) % 25 == 0 and math_floor(player.nitrous) ~= math_floor(player.last_nitrous) then
                    -- Show HUD at 25% increments during regeneration
                    update_nitrous_hud(i, player.nitrous, player.boost_state)
                end
            else
                -- Regenerate nitrous when not active
                player.nitrous = math_min(nitrous_max, player.nitrous + regen_rate)
            end

            -- Show HUD when state changes
            if player.boost_state ~= player.last_boost_state then
                update_nitrous_hud(i, player.nitrous, player.boost_state)
            end
        else
            -- Reset state when not in vehicle
            if player.boost_state ~= NITROUS_STATE.DISABLED then
                player.boost_state = NITROUS_STATE.DISABLED
            end
            -- Regenerate nitrous when not in vehicle
            player.nitrous = math_min(nitrous_max, player.nitrous + regen_rate)
        end

        -- Update tracking variables for next tick
        player.was_in_vehicle = is_in_vehicle
        player.last_boost_state = player.boost_state
        player.last_nitrous = player.nitrous

        ::continue::
    end
end

function OnScriptUnload() end
