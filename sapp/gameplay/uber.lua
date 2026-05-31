--[[
=====================================================================================
SCRIPT NAME:      uber.lua
DESCRIPTION:      Team-based vehicle transport system that allows players to join
                  teammates' vehicles via chat command or crouch action.

EXTERNAL DEPENDENCY:
                 - This script requires the 'uber_vehicles.lua' library file to be
                   placed in your server root directory (same location as sapp.dll
                   and strings.dll).
                 - Download from:
                   https://github.com/Chalwk/SPCLib/blob/master/sapp/modules/uber_vehicles.lua
                 - Without this file, the script will use default (stock/vanilla) vehicles,
                   and may not work on custom maps.

KEY FEATURES:
                 - Configurable vehicle whitelist with seat priority
                 - Smart seat assignment based on insertion order
                 - Cooldown system and call limits
                 - Objective carrier restrictions
                 - Automatic ejection from invalid vehicles
                 - Driver presence verification
                 - Team-based functionality
                 - Accept/reject system for driver approval
                 - Configurable call radius for proximity-based requests

CONFIGURATION OPTIONS:
                 - Customizable chat triggers
                 - Adjustable cooldown timers
                 - Per-game call limits
                 - Vehicle-specific settings
                 - Seat role definitions
                 - Accept/reject command customization
                 - Call radius configuration

LAST UPDATED:     31 May 2026

Copyright (c) 2020-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

---------------------------------------------------------------------------
-- CONFIG START -----------------------------------------------------------
---------------------------------------------------------------------------

-- General settings
local CALL_RADIUS = 0                      -- Radius for calling an Uber (0 to disable)
local CALLS_PER_GAME = 20                  -- Max Uber calls allowed per player per game (0 = unlimited)
local COOLDOWN_PERIOD = 10                 -- Cooldown time (seconds) between Uber calls per player
local CROUCH_TO_CALL = false               -- Enable Uber call when player crouches
local BLOCK_OBJECTIVE = true               -- Prevent Uber calls if player is carrying an objective (e.g. flag)
local DRIVER_ONLY_IMMUNE = true            -- Vehicles with only a driver are immune to damage
local EJECT_FROM_DISABLED_VEHICLE = true   -- Eject players from vehicles that aren't enabled for Uber
local EJECT_FROM_DISABLED_VEHICLE_TIME = 3 -- Delay before ejecting from disabled vehicle (seconds)
local EJECT_WITHOUT_DRIVER = true          -- Eject passengers if vehicle has no driver
local EJECT_WITHOUT_DRIVER_TIME = 5        -- Delay before ejecting without driver (seconds)

-- Chat keywords players can use to call an Uber
local PHRASES = { ['uber'] = true, ['taxi'] = true, ['axi'] = true, ['cab'] = true, ['taxo'] = true }

-- Accept/Reject settings
local ACCEPT_REJECT = false      -- Allow drivers to accept or decline incoming Uber requests
local ACCEPT_REJECT_TIMEOUT = 10 -- Timeout (seconds) for responding

local ACCEPT_COMMAND = 'accept' -- Command to accept an Uber request
local REJECT_COMMAND = 'reject' -- Command to reject an Uber request

-- Player-facing messages
local MESSAGES = {
    must_be_alive = "You must be alive to call an uber",
    already_in_vehicle = "You cannot call an uber while in a vehicle",
    carrying_objective = "You cannot call uber while carrying an objective",
    no_calls_left = "You have no more uber calls left",
    cooldown_wait = "Please wait %d seconds",
    entering_vehicle = "Entering %s as %s",
    remaining_calls = "Remaining calls: %d",
    no_vehicles_available = "No available vehicles or seats",
    driver_left = "Driver left the vehicle",
    ejecting_in = "Ejecting in %d seconds...",
    ejected = "Ejected from vehicle",
    vehicle_not_enabled = "This vehicle is not enabled for uber",
    vehicle_no_driver = "Vehicle has no driver",
    ejection_cancelled = "Driver entered, ejection cancelled"
}
-------------------------------------------------
-- DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING
-------------------------------------------------
local DEFAULT_VEHICLE_SETTINGS = {
    {
        'vehicles\\warthog\\mp_warthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Chain Gun Hog',
        { 0, 2, 1 }
    },
    {
        'vehicles\\rwarthog\\rwarthog',
        {
            [0] = 'driver',
            [1] = 'passenger',
            [2] = 'gunner'
        },
        true,
        'Rocket Hog',
        { 0, 2, 1 }
    }
}
-- CONFIG END -------------------------------------------------------------

local VEHICLES = {}

api_version = '1.12.0.0'

local players = {}
local vehicle_meta_cache = {}

local base_tag_table = 0x40440000
local tag_entry_size = 0x20
local tag_data_offset = 0x14
local bit_check_offset = 0x308
local bit_index = 3

local map_name
local game_over
local gametype_is_ctf_or_oddball = nil

local pairs, ipairs, tonumber, select = pairs, ipairs, tonumber, select
local math_floor = math.floor
local os_time = os.time
local sort = table.sort
local game_time

local rprint, get_var = rprint, get_var
local player_alive, player_present = player_alive, player_present
local enter_vehicle, exit_vehicle = enter_vehicle, exit_vehicle

local lookup_tag = lookup_tag
local get_object_memory, get_dynamic_player = get_object_memory, get_dynamic_player
local read_dword, read_word, read_byte, read_bit = read_dword, read_word, read_byte, read_bit

local sapp_events = {
    [cb['EVENT_TICK']] = 'OnTick',
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_CHAT']] = 'OnChat',
    [cb['EVENT_GAME_END']] = 'OnEnd',
    [cb['EVENT_COMMAND']] = 'OnCommand',
    [cb['EVENT_DIE']] = 'HandleEjection',
    [cb['EVENT_TEAM_SWITCH']] = 'OnTeamSwitch',
    [cb['EVENT_VEHICLE_ENTER']] = 'OnVehicleEnter',
    [cb['EVENT_VEHICLE_EXIT']] = 'HandleEjection',
    [cb['EVENT_DAMAGE_APPLICATION']] = 'OnDamageApplication'
}

local function loadVehicleConfig()
    local ok, chunk = pcall(function ()
        return assert(loadfile("uber_vehicles.lua"))
    end)
    if not ok then
        print("[UBER] Failed to load uber_vehicles.lua: " .. tostring(chunk))
        print("[UBER] Download the file from:")
        print("https://github.com/Chalwk/SPCLib/blob/master/sapp/modules/uber_vehicles.lua")
        print("[UBER] Using default vehicle settings")
        return DEFAULT_VEHICLE_SETTINGS
    end

    local ok2, vehicles = pcall(chunk)
    if not ok2 then
        print("[UBER] Error executing uber_vehicles.lua: " .. tostring(vehicles))
        return DEFAULT_VEHICLE_SETTINGS
    end

    return vehicles
end

local function fmt(message, ...)
    if select('#', ...) > 0 then return message:format(...) end
    return message
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function inRange(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2
    local dy = y1 - y2
    local dz = z1 - z2
    return (dx * dx + dy * dy + dz * dz) <= CALL_RADIUS
end

local function getPos(dyn)
    local crouch = read_float(dyn + 0x50C)
    local vehicle_id = read_dword(dyn + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    end

    local z_offset = 0.65 - (0.3 * crouch)
    return x, y, z + z_offset
end

local function validateVehicle(object_memory)
    return vehicle_meta_cache[map_name][read_dword(object_memory)]
end

local function newEject(object, delay)
    return { object = object, finish = game_time + delay }
end

local function send(player, message)
    rprint(player.id, message)
end

local function scheduleEjection(player, object, delay, reason)
    if reason then send(player, reason) end
    send(player, fmt(MESSAGES.ejecting_in, delay))
    player.auto_eject = newEject(object, delay)
end

local function scheduleEjectionIfDisabled(player, vehicle_obj, config_entry)
    if EJECT_FROM_DISABLED_VEHICLE and not config_entry.enabled then
        scheduleEjection(player, vehicle_obj, EJECT_FROM_DISABLED_VEHICLE_TIME, fmt(MESSAGES.vehicle_not_enabled))
    end
end

local function hasObjective(dyn)
    local weapon_id = read_dword(dyn + 0x118)
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

local function getVehicleIfDriver(dyn)
    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    local vehicle_obj = get_object_memory(vehicle_id)
    if vehicle_obj == 0 then return nil end

    local config_entry = validateVehicle(vehicle_obj)
    if not config_entry then return nil end

    local seat = read_word(dyn + 0x2F0)
    if seat ~= 0 then return nil end

    return vehicle_obj, vehicle_id, config_entry
end

local function commandChecks(player)
    local dyn = get_dynamic_player(player.id)
    if not player_alive(player.id) or dyn == 0 then
        send(player, "You must alive to do this!")
        return nil
    end

    local vehicle_obj, _, config_entry = getVehicleIfDriver(dyn)
    if not vehicle_obj then
        send(player, "You must be a driver to do this!")
        return nil
    end
    return config_entry
end

local function countOccupants(vehicle_obj)
    local count = 0
    for i = 1, 16 do
        local player = players[i]
        if player and player.current_vehi_obj == vehicle_obj and player_alive(i) then
            count = count + 1
        end
    end
    return count
end

local function doChecks(player, dyn)
    if player.call_cooldown then
        send(player, fmt(MESSAGES.cooldown_wait, math_floor(player.call_cooldown - game_time)))
        return false
    end

    if not player_alive(player.id) then
        send(player, fmt(MESSAGES.must_be_alive))
        return false
    end

    if read_dword(dyn + 0x11C) ~= 0xFFFFFFFF then -- in vehicle
        send(player, fmt(MESSAGES.already_in_vehicle))
        return false
    end

    if BLOCK_OBJECTIVE and gametype_is_ctf_or_oddball and hasObjective(dyn) then
        send(player, fmt(MESSAGES.carrying_objective))
        return false
    end

    if CALLS_PER_GAME > 0 and player.calls <= 0 then
        send(player, fmt(MESSAGES.no_calls_left))
        return false
    end

    return true
end

local function isValidPlayer(player, id)
    return player_present(id) and player_alive(id) and id ~= player.id and get_var(id, '$team') == player.team
end

local function getAvailableVehicles(player, caller_x, caller_y, caller_z)
    local available = {}
    local count = 0

    for i = 1, 16 do
        if not isValidPlayer(player, i) then goto continue end
        local dyn = get_dynamic_player(i)
        if not dyn then goto continue end

        local vehicle_obj, vehicle_id, config_entry = getVehicleIfDriver(dyn)
        if vehicle_obj then
            local veh_x, veh_y, veh_z = read_vector3d(vehicle_obj + 0x5C)

            if CALL_RADIUS <= 0 or inRange(caller_x, caller_y, caller_z, veh_x, veh_y, veh_z) then
                count = count + 1
                available[count] = {
                    object = vehicle_obj,
                    id = vehicle_id,
                    meta = config_entry,
                    driver = i,
                    occupants = countOccupants(vehicle_obj)
                }
            end
        end
        ::continue::
    end

    sort(available, function (a, b)
        return a.occupants < b.occupants
    end)

    return available
end

local function findSeat(player, vehicle)
    local vehicle_insertion_order = vehicle.meta.insertion_order

    for _, seat_id in ipairs(vehicle_insertion_order) do
        if not vehicle.meta.seats[seat_id] then goto continue end

        local seat_free = true

        for i = 1, 16 do
            if i ~= player.id then
                local other = players[i]
                if other and other.current_vehi_obj == vehicle.object and player_alive(i) and other.seat == seat_id then
                    seat_free = false
                    break
                end
            end
        end

        if seat_free then return seat_id end

        ::continue::
    end
end

local function processPendingRequest(passenger_id, vehicle, seat_id, accepted)
    local passenger = players[passenger_id]
    if not passenger or not passenger.pending_request then return end

    local driver = players[passenger.pending_request.driver_id]
    if driver then
        if accepted then
            enter_vehicle(vehicle.id, passenger_id, seat_id)
            send(passenger, fmt(MESSAGES.entering_vehicle, vehicle.meta.display_name, vehicle.meta.seats[seat_id]))

            if CALLS_PER_GAME > 0 then
                passenger.calls = passenger.calls - 1
                send(passenger, fmt(MESSAGES.remaining_calls, passenger.calls))
            end
        else
            send(passenger, "Your Uber request was declined by the driver.")
        end
    else
        send(passenger, "Driver is no longer available.")
    end

    passenger.pending_request = nil
end

local function callUber(player, dyn)
    dyn = dyn or get_dynamic_player(player.id)

    if not doChecks(player, dyn) then return end

    player.call_cooldown = game_time + COOLDOWN_PERIOD

    local x, y, z = getPos(dyn)
    if not x then
        send(player, "Unable to determine your position")
        return
    end

    local vehicles = getAvailableVehicles(player, x, y, z)

    for _, vehicle in ipairs(vehicles) do
        local seat_id = findSeat(player, vehicle)
        if seat_id then
            if ACCEPT_REJECT then
                local driver = players[vehicle.driver]
                if driver then
                    send(
                        driver,
                        player.name .. " is requesting to join your vehicle. Type '"
                            .. ACCEPT_COMMAND .. "' or '"
                            .. REJECT_COMMAND .. "' to respond."
                    )

                    player.pending_request = {
                        driver_id = vehicle.driver,
                        vehicle_id = vehicle.id,
                        seat_id = seat_id,
                        time_sent = game_time,
                        timeout = game_time + ACCEPT_REJECT_TIMEOUT
                    }

                    send(player, "Request sent to driver. Waiting for response...")
                    return
                end
            else
                if CALLS_PER_GAME > 0 then player.calls = player.calls - 1 end
                enter_vehicle(vehicle.id, player.id, seat_id)
                send(player, fmt(MESSAGES.entering_vehicle, vehicle.meta.display_name, vehicle.meta.seats[seat_id]))

                if CALLS_PER_GAME > 0 then
                    send(player, fmt(MESSAGES.remaining_calls, player.calls))
                end
                return
            end
        end
    end

    if CALL_RADIUS > 0 then
        send(player, fmt("No available vehicles within %d units", CALL_RADIUS))
    else
        send(player, fmt(MESSAGES.no_vehicles_available))
    end
end

local function ejectionCheck(player)
    player.auto_eject = nil
    if player.seat ~= 0 then return end

    local dyn = get_dynamic_player(player.id)
    if dyn == 0 then return end

    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return end

    local vehicle_obj = get_object_memory(vehicle_id)
    for id, other_player in pairs(players) do
        if id ~= player.id and other_player.current_vehi_obj == vehicle_obj then
            scheduleEjection(other_player, vehicle_obj, EJECT_WITHOUT_DRIVER_TIME, fmt(MESSAGES.driver_left))
        end
    end
end

local function checkCrouch(player, dyn)
    if not CROUCH_TO_CALL then return end

    local crouching = read_bit(dyn + 0x208, 0)
    if crouching == 1 and player.crouching ~= crouching then callUber(player, dyn) end
    player.crouching = crouching
end

local function processAutoEject(player)
    if not player.auto_eject or game_time < player.auto_eject.finish then return end

    exit_vehicle(player.id)
    send(player, fmt(MESSAGES.ejected))
    player.auto_eject = nil
end

local function processCooldown(player)
    if player.call_cooldown and game_time >= player.call_cooldown then
        player.call_cooldown = nil
    end
end

local function updateVehicleState(player, dyn)
    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then -- not in vehicle
        player.seat = nil
        player.current_vehi_obj = nil
        return
    end

    local vehicle_obj = get_object_memory(vehicle_id)
    if vehicle_obj ~= 0 then
        player.seat = read_word(dyn + 0x2F0)
        player.current_vehi_obj = vehicle_obj
    end
end

local function processPendingRequests()
    for _, player in pairs(players) do
        if player and player.pending_request then
            if game_time > player.pending_request.timeout then
                send(player, "Your Uber request timed out.")
                player.pending_request = nil
            end
        end
    end
end

local function initialize()
    map_name = get_var(0, '$map')
    if not vehicle_meta_cache[map_name] then -- not cached yet
        vehicle_meta_cache[map_name] = {}
        for _, v in ipairs(VEHICLES) do
            local tag, seats, enabled, label, insertion_order = v[1], v[2], v[3], v[4], v[5]
            local meta_id = getTag('vehi', tag)
            if meta_id then
                vehicle_meta_cache[map_name][meta_id] = {
                    seats = seats,
                    enabled = enabled,
                    display_name = label,
                    insertion_order = insertion_order
                }
            end
        end
    end

    local game_type = get_var(0, '$gt')
    gametype_is_ctf_or_oddball = game_type == 'ctf' or game_type == 'oddball'
end

local function registerCallbacks(team_game)
    for event, callback in pairs(sapp_events) do
        if team_game then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

function OnScriptLoad()
    VEHICLES = loadVehicleConfig()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    if get_var(0, '$ffa') == '1' then
        registerCallbacks(false)
        cprint('====================================', 12)
        cprint('[Uber] Only runs on team-based games', 12)
        cprint('====================================', 12)
        return
    end

    initialize()

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end

    game_over = false
    registerCallbacks(true)
end

function OnEnd()
    game_over = true
end

function OnJoin(id)
    players[id] = {
        id = id,
        team = get_var(id, '$team'),
        name = get_var(id, '$name'),
        calls = CALLS_PER_GAME,
        crouching = 0,
        auto_eject = nil,
        call_cooldown = nil,
        seat = nil,
        current_vehi_obj = nil,
        pending_request = nil
    }
end

function OnQuit(id)
    local player = players[id]
    if not player then return end

    if player.seat == 0 and player.current_vehi_obj then
        for other_id, other_player in pairs(players) do
            if other_id ~= id and other_player.current_vehi_obj == player.current_vehi_obj then
                scheduleEjection(
                    other_player, player.current_vehi_obj, EJECT_WITHOUT_DRIVER_TIME, fmt(MESSAGES.driver_left)
                )
            end
        end
    end

    players[id] = nil
end

function OnTick()
    if game_over then return end

    game_time = os_time()

    for i = 1, 16 do
        local player = players[i]
        if not player or not player_present(i) then goto continue end

        processCooldown(player)

        local dyn = get_dynamic_player(i)
        if dyn == 0 or not player_alive(i) then goto continue end

        updateVehicleState(player, dyn)
        processAutoEject(player)
        checkCrouch(player, dyn)

        ::continue::
    end

    processPendingRequests() -- Process pending requests
end

function OnChat(id, msg)
    msg = msg:lower()
    local player = players[id]
    if player and PHRASES[msg] then
        callUber(player)
        return false
    end
end

function OnVehicleEnter(id, seat)
    seat = tonumber(seat)

    local player = players[id]
    local dyn = get_dynamic_player(id)
    if dyn == 0 then return end

    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return end

    local vehicle_obj = get_object_memory(vehicle_id)
    if vehicle_obj == 0 then return end

    -- Get vehicle config | If it isn't configured allow the player to enter
    local config_entry = validateVehicle(vehicle_obj)
    if not config_entry then goto continue end

    scheduleEjectionIfDisabled(player, vehicle_obj, config_entry) -- prevent using disabled vehicles

    ::continue::

    if seat ~= 0 and EJECT_WITHOUT_DRIVER then
        local driver = read_dword(vehicle_obj + 0x324) -- check if the vehicle has a driver
        if driver == 0xFFFFFFFF then
            scheduleEjection(player, vehicle_obj, EJECT_WITHOUT_DRIVER_TIME, fmt(MESSAGES.vehicle_no_driver))
        end
    end

    if seat == 0 then
        for _, p in pairs(players) do
            if p.auto_eject and p.auto_eject.object == vehicle_obj then
                p.auto_eject = nil
                send(p, fmt(MESSAGES.ejection_cancelled))
            end
        end
    end
end

function HandleEjection(id) -- event_vehicle_exit/event_die
    ejectionCheck(players[id])
end

function OnTeamSwitch(id)
    players[id].team = get_var(id, '$team')
end

function OnDamageApplication(id, killer, _, damage)
    if killer ~= 0 then
        if not DRIVER_ONLY_IMMUNE then return true, damage end

        local victim_dyn = get_dynamic_player(id)
        if victim_dyn == 0 then return true, damage end

        local vehicle_id = read_dword(victim_dyn + 0x11C)
        local vehicle_obj = (vehicle_id ~= 0xFFFFFFFF) and get_object_memory(vehicle_id) or 0
        if vehicle_obj == 0 or not validateVehicle(vehicle_obj) then
            return true, damage
        end

        if read_word(victim_dyn + 0x2F0) == 0 and countOccupants(vehicle_obj) == 1 then
            return false -- prevent driver from taking damage if they are the only occupant
        end
        return true, damage
    end
end

function OnCommand(id, command)
    local cmd = command:lower()
    local player = players[id]

    if not player then return true end
    if (cmd == ACCEPT_COMMAND or cmd == REJECT_COMMAND) and not ACCEPT_REJECT then
        send(player, "Accept/reject system is disabled.")
        return false
    end

    if cmd ~= ACCEPT_COMMAND or cmd ~= REJECT_COMMAND then return true end

    local config_entry = commandChecks(player)
    if config_entry then return false end

    local found_request = false
    if cmd == ACCEPT_COMMAND then
        for passenger_id, p in pairs(players) do
            if p and p.pending_request and p.pending_request.driver_id == id then
                found_request = true
                local vehicle = { id = p.pending_request.vehicle_id, meta = config_entry }
                processPendingRequest(passenger_id, vehicle, p.pending_request.seat_id, true)
                send(player, "Accepted " .. p.name .. "'s Uber request.")
                break
            end
        end
    elseif cmd == REJECT_COMMAND then
        for passenger_id, p in pairs(players) do
            if p and p.pending_request and p.pending_request.driver_id == id then
                found_request = true
                processPendingRequest(passenger_id, nil, nil, false)
                send(player, "Rejected " .. p.name .. "'s Uber request.")
                break
            end
        end
    end

    if not found_request then
        send(player, "No pending Uber requests.")
    end

    return false
end

function OnScriptUnload() end
