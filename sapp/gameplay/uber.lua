--[[
=====================================================================================
SCRIPT NAME:      uber.lua
DESCRIPTION:      Team-based vehicle transport system that lets players join a
                  teammate's vehicle via chat command or crouch action.

KEY FEATURES:
                 - Automatic seat and role detection for any vehicle on any map
                 - Smart seat assignment (gunner first, then passengers)
                 - Prefers emptier vehicles, then the closest one
                 - Cooldown system and per-game call limits
                 - Objective carrier restrictions
                 - Automatic ejection from disabled vehicles
                 - Driver presence verification
                 - Accept/reject system for driver approval
                 - Configurable call radius for proximity-based requests
                 - Optional per-vehicle overrides (names, seats, boarding order)
                 - Compatible with stock and custom maps.

LAST UPDATED:     12 November 2026

Copyright (c) 2020-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

---@class UberConfig
---@field CALL_RADIUS                      number  Max distance in world units to a vehicle (0 = no limit).
---@field CALLS_PER_GAME                   number  Max Uber calls per player per game (0 = unlimited).
---@field COOLDOWN_PERIOD                  number  Seconds between Uber calls per player.
---@field CROUCH_TO_CALL                   boolean Call an Uber when the player crouches.
---@field BLOCK_OBJECTIVE                  boolean Block calls while carrying an objective (flag, oddball).
---@field DRIVER_ONLY_IMMUNE               boolean A lone driver takes no damage from other players.
---@field EJECT_FROM_DISABLED_VEHICLE      boolean Eject players from vehicles disabled in VEHICLE_OVERRIDES.
---@field EJECT_FROM_DISABLED_VEHICLE_TIME number  Seconds before ejecting from a disabled vehicle.
---@field EJECT_WITHOUT_DRIVER             boolean Eject passengers when a vehicle has no driver.
---@field EJECT_WITHOUT_DRIVER_TIME        number  Seconds before ejecting passengers without a driver.
---@field DEBUG_VEHICLES                   boolean Print a vehicle's detected seats the first time it is seen.
---@field ACCEPT_REJECT                    boolean Drivers must approve incoming Uber requests.
---@field ACCEPT_REJECT_TIMEOUT            number  Seconds a request waits for a response.
---@field ACCEPT_COMMAND                   string  Command a driver uses to accept (lowercase).
---@field REJECT_COMMAND                   string  Command a driver uses to reject (lowercase).

---------------------------------------------------------------------------
-- CONFIG START -----------------------------------------------------------
---------------------------------------------------------------------------

---@type UberConfig
local CONFIG = {
    -- General settings
    CALL_RADIUS = 0,                      -- Max distance in world units to a vehicle (0 = no limit)
    CALLS_PER_GAME = 20,                  -- Max Uber calls per player per game (0 = unlimited)
    COOLDOWN_PERIOD = 10,                 -- Seconds between Uber calls per player
    CROUCH_TO_CALL = false,               -- Call an Uber when the player crouches
    BLOCK_OBJECTIVE = true,               -- Block calls while carrying an objective (flag, oddball)
    DRIVER_ONLY_IMMUNE = true,            -- A lone driver takes no damage from other players
    EJECT_FROM_DISABLED_VEHICLE = true,   -- Eject players from vehicles disabled in VEHICLE_OVERRIDES
    EJECT_FROM_DISABLED_VEHICLE_TIME = 3, -- Seconds before ejecting from a disabled vehicle
    EJECT_WITHOUT_DRIVER = true,          -- Eject passengers when a vehicle has no driver
    EJECT_WITHOUT_DRIVER_TIME = 5,        -- Seconds before ejecting passengers without a driver

    -- Print each vehicle's detected seats to the server console the first time it is seen.
    -- Turn this on when testing a new custom map.
    DEBUG_VEHICLES = false,

    -- Accept/Reject settings
    ACCEPT_REJECT = false,                -- Drivers must approve incoming Uber requests
    ACCEPT_REJECT_TIMEOUT = 10,           -- Seconds a request waits for a response
    ACCEPT_COMMAND = 'accept',            -- Command a driver uses to accept (lowercase)
    REJECT_COMMAND = 'reject'             -- Command a driver uses to reject (lowercase)
}

-- Chat keywords players can use to call an Uber (lowercase)
---@type table<string, boolean>
local PHRASES = { ['uber'] = true, ['taxi'] = true, ['axi'] = true, ['cab'] = true, ['taxo'] = true }

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
    no_vehicles_in_range = "No available vehicles within %d units",
    driver_left = "Driver left the vehicle",
    ejecting_in = "Ejecting in %d seconds...",
    ejected = "Ejected from vehicle",
    vehicle_not_enabled = "This vehicle is not enabled for uber",
    vehicle_no_driver = "Vehicle has no driver",
    ejection_cancelled = "Driver entered, ejection cancelled",
    request_pending = "You already have a request waiting for a driver",
    request_sent = "Request sent to driver. Waiting for response...",
    request_received = "%s is requesting to join your vehicle. Type '%s' or '%s' to respond.",
    request_declined = "Your Uber request was declined by the driver",
    request_timed_out = "Your Uber request timed out",
    request_accepted_driver = "Accepted %s's Uber request",
    request_rejected_driver = "Rejected %s's Uber request",
    driver_unavailable = "Driver is no longer available",
    passenger_unavailable = "That player can no longer join your vehicle",
    not_a_driver = "You must be driving a vehicle to do this",
    no_pending_requests = "No pending Uber requests"
}

--[[
VEHICLE OVERRIDES (optional)

Seats, roles and boarding order are detected automatically. Only add an entry here to
change something. Keys are vehicle tag paths (not case sensitive). Every field is optional:

    display_name    (string)   Name shown to players. Default: built from the tag path.
    enabled         (boolean)  false disables Uber for this vehicle and, if
                               CONFIG.EJECT_FROM_DISABLED_VEHICLE is on, ejects players from it.
    insertion_order (table)    Seats to try, in order. Seats not listed are never filled.
                               Example: { 2, 1 } tries the gunner seat, then the passenger seat.
    seats           (table)    Manual seat roles, used instead of the tag data. Only needed if
                               a map's tags cannot be read. Example:
                               { [0] = 'driver', [1] = 'passenger', [2] = 'gunner' }
]]
local VEHICLE_OVERRIDES = {
    ['vehicles\\warthog\\mp_warthog'] = { display_name = 'Chain Gun Hog' },
    ['vehicles\\rwarthog\\rwarthog'] = { display_name = 'Rocket Hog' }

    -- ['vehicles\\ghost\\ghost_mp'] = { enabled = false },
    -- ['vehicles\\scorpion\\scorpion_mp'] = { insertion_order = { 1 } }
}

---------------------------------------------------------------------------
-- CONFIG END -------------------------------------------------------------
---------------------------------------------------------------------------

local TICKS_PER_SECOND = 30
local MAX_PLAYERS = 16
local NO_OBJECT = 0xFFFFFFFF

-- Tag table
local BASE_TAG_TABLE = 0x40440000
local TAG_ENTRY_SIZE = 0x20
local TAG_NAME_OFFSET = 0x10
local TAG_DATA_OFFSET = 0x14
local TAG_CLASS_VEHICLE = 0x76656869 -- 'vehi'
local MIN_VALID_ADDRESS = 0x400000
local MAX_VALID_ADDRESS = 0x7FFF0000

-- Vehicle tag data: the seats reflexive is the last field of the unit struct.
local UNIT_SEATS_COUNT = 0x2E4
local UNIT_SEATS_ADDRESS = 0x2E8
local SEAT_STRUCT_SIZE = 0x11C
local MAX_SEATS = 16

-- Seat flag bits (first dword of each seat struct)
local SEAT_FLAG_LOCKED = 1
local SEAT_FLAG_DRIVER = 2
local SEAT_FLAG_GUNNER = 3

-- Weapon tag data: objective weapons (flag, oddball)
local WEAPON_FLAGS_OFFSET = 0x308
local WEAPON_FLAG_OBJECTIVE = 3
local WEAPON_OBJECTIVE_TYPE = 2
local OBJECTIVE_FLAG, OBJECTIVE_ODDBALL = 0, 4

-- Object memory
local OBJECT_POSITION = 0x5C
local DYN_WEAPON_ID = 0x118
local DYN_VEHICLE_ID = 0x11C
local DYN_INPUT_FLAGS = 0x208
local DYN_SEAT = 0x2F0
local VEHICLE_DRIVER_ID = 0x324
local INPUT_FLAG_CROUCH = 0

-- Lower numbers fill first. Roles not listed fill last. Driver seats are never auto-filled.
local ROLE_PRIORITY = { gunner = 1, passenger = 2 }
local OTHER_ROLE_PRIORITY = 3

local pairs, ipairs, tonumber = pairs, ipairs, tonumber
local math_ceil = math.ceil
local string_format = string.format
local table_sort, table_concat = table.sort, table.concat

local rprint, cprint, get_var = rprint, cprint, get_var
local player_alive, player_present = player_alive, player_present
local enter_vehicle, exit_vehicle = enter_vehicle, exit_vehicle
local register_callback, unregister_callback = register_callback, unregister_callback
local get_object_memory = get_object_memory
---@type fun(player_id: number): number
local get_dynamic_player = get_dynamic_player
local read_dword, read_word, read_bit = read_dword, read_word, read_bit
local read_byte, read_string, read_vector3d = read_byte, read_string, read_vector3d

local call_radius_squared = CONFIG.CALL_RADIUS * CONFIG.CALL_RADIUS
local cooldown_ticks = CONFIG.COOLDOWN_PERIOD * TICKS_PER_SECOND
local request_timeout_ticks = CONFIG.ACCEPT_REJECT_TIMEOUT * TICKS_PER_SECOND

local sapp_events = {
    [cb['EVENT_TICK']] = 'OnTick',
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_CHAT']] = 'OnChat',
    [cb['EVENT_GAME_END']] = 'OnEnd',
    [cb['EVENT_COMMAND']] = 'OnCommand',
    [cb['EVENT_DIE']] = 'HandleEjection',
    [cb['EVENT_VEHICLE_ENTER']] = 'OnVehicleEnter',
    [cb['EVENT_VEHICLE_EXIT']] = 'HandleEjection',
    [cb['EVENT_DAMAGE_APPLICATION']] = 'OnDamageApplication'
}

---@class VehicleInfo
---@field display_name string                Name shown to players.
---@field enabled      boolean               False if disabled through VEHICLE_OVERRIDES.
---@field seats        table<number, string> Usable seat index to role name.
---@field driver_seat  number                Seat index of the driver.
---@field order        number[]              Seat indices a joining player is placed in, first choice first.
---@field capacity     number                Number of seats in `order`. Zero means nobody can be picked up.

---@class AutoEject
---@field kind        string 'disabled' or 'no_driver'.
---@field vehicle_id  number Object id of the vehicle to eject from.
---@field finish_tick number Tick at which the player is ejected.

---@class PendingRequest
---@field driver_id    number Player index of the driver asked.
---@field vehicle_id   number Object id of the vehicle.
---@field sent_tick    number Tick the request was sent.
---@field expires_tick number Tick the request times out.

---@class UberPlayer
---@field id              number               Player index
---@field name            string               Player name.
---@field calls           number               Uber calls left this game.
---@field call_ready_tick number               First tick a new call is allowed.
---@field crouching       number               Crouch bit from the last tick (0 or 1).
---@field vehicle_id      number | nil         Object id of the current vehicle.
---@field vehicle         VehicleInfo | nil    Detected info for the current vehicle.
---@field seat            number | nil         Seat index in the current vehicle.
---@field is_driver       boolean              True when sitting in the driver seat.
---@field auto_eject      AutoEject | nil      Scheduled ejection.
---@field pending_request PendingRequest | nil Request waiting for a driver response.

---@type table<number, UberPlayer>
local players = {}

---@type table<number, VehicleInfo | false> Keyed by tag id. `false` marks an unreadable vehicle.
local vehicle_cache = {}

---@type table<string, table> VEHICLE_OVERRIDES with lowercase keys.
local overrides = {}

local ticks = 0
local game_over = true
local objective_gametype = false
local callbacks_active = false

---@param message string Format string.
---@param ...     any    Format arguments.
---@return string formatted Formatted message, or the original if no arguments are supplied.
local function formatMessage(message, ...)
    return select('#', ...) > 0 and message:format(...) or message
end

---@param player  UberPlayer
---@param message string
local function send(player, message)
    rprint(player.id, message)
end

---@param tag_path string Full tag path.
---@return string display_name Last path component with spaces and capitals.
local function prettifyName(tag_path)
    local short_name = tag_path:match('([^\\]+)$')
    if not short_name or short_name == '' then return 'Vehicle' end

    short_name = short_name:gsub('_', ' ')
    return (short_name:gsub('(%a)(%w*)', function (first, rest)
        return first:upper() .. rest
    end))
end

---@param seats table<number, string> Seat index to role name.
---@return number[] indices Seat indices in ascending order.
local function getSeatIndices(seats)
    local indices = {}
    for index in pairs(seats) do
        indices[#indices + 1] = index
    end
    table_sort(indices)
    return indices
end

---@param seats table<number, string> Seat index to role name.
---@return number driver_seat Lowest seat with the driver role, or 0 if none.
local function findDriverSeat(seats)
    for _, index in ipairs(getSeatIndices(seats)) do
        if seats[index] == 'driver' then return index end
    end
    return 0
end

-- Reads the seat list from a vehicle's tag data.
---@param tag_data number Address of the vehicle tag data.
---@return table<number, string> | nil seats Seat index to role name, or nil if the data looks invalid.
local function readSeats(tag_data)
    if tag_data < MIN_VALID_ADDRESS or tag_data > MAX_VALID_ADDRESS then return nil end

    local count = read_dword(tag_data + UNIT_SEATS_COUNT)
    local address = read_dword(tag_data + UNIT_SEATS_ADDRESS)
    if count < 1 or count > MAX_SEATS then return nil end
    if address < MIN_VALID_ADDRESS or address > MAX_VALID_ADDRESS then return nil end

    local seats = {}
    for index = 0, count - 1 do
        local seat = address + index * SEAT_STRUCT_SIZE

        if read_bit(seat, SEAT_FLAG_LOCKED) == 0 then
            local role = 'passenger'
            if read_bit(seat, SEAT_FLAG_DRIVER) == 1 then
                role = 'driver'
            elseif read_bit(seat, SEAT_FLAG_GUNNER) == 1 then
                role = 'gunner'
            end
            seats[index] = role
        end
    end

    return seats
end

-- Builds the order seats are filled in.
---@param seats        table<number, string | nil> Seat index to role name; locked or missing seats are absent.
---@param custom_order number[] | nil              Order from VEHICLE_OVERRIDES.
---@return number[] order Seat indices, first choice first.
local function orderSeats(seats, custom_order)
    local order = {}

    if custom_order then
        for _, index in ipairs(custom_order) do
            if seats[index] then order[#order + 1] = index end
        end
        return order
    end

    for index, role in pairs(seats) do
        if role ~= 'driver' then order[#order + 1] = index end
    end

    table_sort(order, function (a, b)
        local priority_a = ROLE_PRIORITY[seats[a]] or OTHER_ROLE_PRIORITY
        local priority_b = ROLE_PRIORITY[seats[b]] or OTHER_ROLE_PRIORITY
        if priority_a ~= priority_b then return priority_a < priority_b end
        return a < b
    end)

    return order
end

---@param tag_path string      Vehicle tag path.
---@param vehicle  VehicleInfo Detected vehicle info.
local function printVehicle(tag_path, vehicle)
    local roles = {}
    for _, index in ipairs(getSeatIndices(vehicle.seats)) do
        roles[#roles + 1] = index .. '=' .. vehicle.seats[index]
    end

    cprint(
        string_format(
            '[Uber] %s (%s): seats [%s], boarding order [%s]%s', vehicle.display_name, tag_path,
            table_concat(roles, ', '), table_concat(vehicle.order, ', '), vehicle.enabled and '' or ', DISABLED'
        ), 11
    )
end

---@param vehicle_obj number Vehicle object memory address.
---@return VehicleInfo | nil vehicle Vehicle info, or nil if the tag cannot be read.
local function buildVehicleInfo(vehicle_obj)
    local tag_entry = read_dword(BASE_TAG_TABLE) + read_word(vehicle_obj) * TAG_ENTRY_SIZE
    if read_dword(tag_entry) ~= TAG_CLASS_VEHICLE then return nil end

    local name_address = read_dword(tag_entry + TAG_NAME_OFFSET)
    local tag_path = name_address ~= 0 and read_string(name_address) or ''
    local override = overrides[tag_path:lower()] or {}

    local seats = override.seats or readSeats(read_dword(tag_entry + TAG_DATA_OFFSET))
    if not seats then
        cprint('[Uber] Could not read seats for "' .. tag_path .. '". Add a seats override for it.', 12)
        return nil
    end

    local order = orderSeats(seats, override.insertion_order)
    local vehicle = {
        display_name = override.display_name or prettifyName(tag_path),
        enabled = override.enabled ~= false,
        seats = seats,
        driver_seat = findDriverSeat(seats),
        order = order,
        capacity = #order
    }

    if CONFIG.DEBUG_VEHICLES then printVehicle(tag_path, vehicle) end
    return vehicle
end

-- Returns cached info for a vehicle, reading its tag on first sight.
---@param vehicle_obj number Vehicle object memory address.
---@return VehicleInfo | nil vehicle Vehicle info, or nil if the object is not a readable vehicle.
local function getVehicleInfo(vehicle_obj)
    local tag_id = read_dword(vehicle_obj)
    local cached = vehicle_cache[tag_id]
    if cached == false then return nil end
    if cached ~= nil then return cached end

    local vehicle = buildVehicleInfo(vehicle_obj)
    vehicle_cache[tag_id] = vehicle or false
    return vehicle
end

---@param dyn number Dynamic player address.
---@return boolean holding True if the player is holding a flag or oddball.
local function hasObjective(dyn)
    local weapon_id = read_dword(dyn + DYN_WEAPON_ID)
    if weapon_id == NO_OBJECT then return false end

    local weapon_obj = get_object_memory(weapon_id)
    if weapon_obj == 0 then return false end

    local tag_entry = read_dword(BASE_TAG_TABLE) + read_word(weapon_obj) * TAG_ENTRY_SIZE
    local tag_data = read_dword(tag_entry + TAG_DATA_OFFSET)

    if read_bit(tag_data + WEAPON_FLAGS_OFFSET, WEAPON_FLAG_OBJECTIVE) ~= 1 then return false end

    local objective_type = read_byte(tag_data + WEAPON_OBJECTIVE_TYPE)
    return objective_type == OBJECTIVE_FLAG or objective_type == OBJECTIVE_ODDBALL
end

---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number distance_squared Squared distance in world units.
local function getDistanceSquared(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return dx * dx + dy * dy + dz * dz
end

---@param player UberPlayer
local function clearVehicleState(player)
    player.vehicle_id = nil
    player.vehicle = nil
    player.seat = nil
    player.is_driver = false
end

---@param player     UberPlayer
---@param vehicle_id number            Vehicle object id.
---@param seat       number            Seat index.
---@param vehicle    VehicleInfo | nil Detected vehicle info.
local function setVehicleState(player, vehicle_id, seat, vehicle)
    player.vehicle_id = vehicle_id
    player.vehicle = vehicle
    player.seat = seat
    player.is_driver = seat == (vehicle and vehicle.driver_seat or 0)
end

-- Syncs the stored vehicle state with the game. Only reads the tag when the vehicle or seat changes.
---@param player UberPlayer
---@param dyn    number     Dynamic player address.
local function trackVehicle(player, dyn)
    local vehicle_id = read_dword(dyn + DYN_VEHICLE_ID)
    if vehicle_id == NO_OBJECT then
        clearVehicleState(player)
        return
    end

    local seat = read_word(dyn + DYN_SEAT)
    if vehicle_id == player.vehicle_id and seat == player.seat then return end

    local vehicle_obj = get_object_memory(vehicle_id)
    local vehicle = vehicle_obj ~= 0 and getVehicleInfo(vehicle_obj) or nil
    setVehicleState(player, vehicle_id, seat, vehicle)
end

---@param vehicle_id       number Vehicle object id.
---@param seat_id          number Seat index.
---@param ignore_player_id number Player index to skip.
---@return boolean taken True if a living player holds the seat.
local function isSeatTaken(vehicle_id, seat_id, ignore_player_id)
    for i = 1, MAX_PLAYERS do
        local other = players[i]
        if other and i ~= ignore_player_id
            and other.vehicle_id == vehicle_id and other.seat == seat_id
            and player_alive(i) then
            return true
        end
    end
    return false
end

---@param vehicle_id number Vehicle object id.
---@return number count Number of living players inside.
local function countOccupants(vehicle_id)
    local count = 0
    for i = 1, MAX_PLAYERS do
        local player = players[i]
        if player and player.vehicle_id == vehicle_id and player_alive(i) then
            count = count + 1
        end
    end
    return count
end

---@param player_id  number      Player index looking for a seat.
---@param vehicle_id number      Vehicle object id.
---@param vehicle    VehicleInfo
---@return number | nil seat_id First free seat in boarding order, or nil if the vehicle is full.
local function findSeat(player_id, vehicle_id, vehicle)
    for _, seat_id in ipairs(vehicle.order) do
        if not isSeatTaken(vehicle_id, seat_id, player_id) then return seat_id end
    end
end

---@param driver_id number           Player index of the candidate driver.
---@param driver    UberPlayer | nil
---@param caller_id number           Player index of the caller.
---@param team      string           Caller's team.
---@return boolean eligible True if the driver can take passengers from this caller.
local function isEligibleDriver(driver_id, driver, caller_id, team)
    if not driver or driver_id == caller_id then return false end
    if not driver.is_driver or not driver.vehicle then return false end
    if not driver.vehicle.enabled or driver.vehicle.capacity == 0 then return false end
    return player_present(driver_id) and player_alive(driver_id) and get_var(driver_id, '$team') == team
end

-- Lists nearby team vehicles, emptiest first and then closest first.
---@param caller UberPlayer
---@param team   string     Caller's team.
---@param x      number     Caller X.
---@param y      number     Caller Y.
---@param z      number     Caller Z.
---@return table[] candidates Entries with vehicle_id, vehicle, driver_id, occupants, distance_squared.
local function getCandidates(caller, team, x, y, z)
    local candidates = {}

    for i = 1, MAX_PLAYERS do
        local driver = players[i]
        local vehicle_id = driver and driver.vehicle_id
        local vehicle = driver and driver.vehicle
        if driver and vehicle_id and vehicle and isEligibleDriver(i, driver, caller.id, team) then
            local vehicle_obj = get_object_memory(vehicle_id)
            if vehicle_obj ~= 0 then
                local vx, vy, vz = read_vector3d(vehicle_obj + OBJECT_POSITION)
                local distance_squared = getDistanceSquared(x, y, z, vx, vy, vz)

                if CONFIG.CALL_RADIUS <= 0 or distance_squared <= call_radius_squared then
                    candidates[#candidates + 1] = {
                        vehicle_id = vehicle_id,
                        vehicle = vehicle,
                        driver_id = i,
                        occupants = countOccupants(vehicle_id),
                        distance_squared = distance_squared
                    }
                end
            end
        end
    end

    table_sort(candidates, function (a, b)
        if a.occupants ~= b.occupants then return a.occupants < b.occupants end
        return a.distance_squared < b.distance_squared
    end)

    return candidates
end

---@param player     UberPlayer
---@param vehicle_id number      Vehicle object id.
---@param vehicle    VehicleInfo
---@param seat_id    number      Seat index to place the player in.
local function boardVehicle(player, vehicle_id, vehicle, seat_id)
    enter_vehicle(vehicle_id, player.id, tostring(seat_id))

    -- Reserve the seat now so a second call in the same tick picks a different one.
    -- trackVehicle corrects this on the next tick if the game refused the entry.
    setVehicleState(player, vehicle_id, seat_id, vehicle)

    send(player, formatMessage(MESSAGES.entering_vehicle, vehicle.display_name, vehicle.seats[seat_id]))

    if CONFIG.CALLS_PER_GAME > 0 then
        player.calls = player.calls - 1
        send(player, formatMessage(MESSAGES.remaining_calls, player.calls))
    end
end

---@param player    UberPlayer
---@param candidate table      Entry from getCandidates.
local function requestSeat(player, candidate)
    local driver = players[candidate.driver_id]

    send(driver, formatMessage(MESSAGES.request_received, player.name, CONFIG.ACCEPT_COMMAND, CONFIG.REJECT_COMMAND))
    send(player, MESSAGES.request_sent)

    player.pending_request = {
        driver_id = candidate.driver_id,
        vehicle_id = candidate.vehicle_id,
        sent_tick = ticks,
        expires_tick = ticks + request_timeout_ticks
    }
end

---@param player UberPlayer
---@param dyn    number     Dynamic player address (0 if dead).
---@return boolean allowed True if the player may call an Uber right now.
local function checkCaller(player, dyn)
    if dyn == 0 or not player_alive(player.id) then
        send(player, MESSAGES.must_be_alive)
        return false
    end

    if ticks < player.call_ready_tick then
        local seconds = math_ceil((player.call_ready_tick - ticks) / TICKS_PER_SECOND)
        send(player, formatMessage(MESSAGES.cooldown_wait, seconds))
        return false
    end

    if player.pending_request then
        send(player, MESSAGES.request_pending)
        return false
    end

    if read_dword(dyn + DYN_VEHICLE_ID) ~= NO_OBJECT then
        send(player, MESSAGES.already_in_vehicle)
        return false
    end

    if CONFIG.BLOCK_OBJECTIVE and objective_gametype and hasObjective(dyn) then
        send(player, MESSAGES.carrying_objective)
        return false
    end

    if CONFIG.CALLS_PER_GAME > 0 and player.calls <= 0 then
        send(player, MESSAGES.no_calls_left)
        return false
    end

    return true
end

---@param player UberPlayer
---@param dyn    number | nil Dynamic player address. Looked up if omitted.
local function callUber(player, dyn)
    local dynamic_player = dyn or get_dynamic_player(player.id)
    if not checkCaller(player, dynamic_player) then return end

    player.call_ready_tick = ticks + cooldown_ticks

    local x, y, z = read_vector3d(dynamic_player + OBJECT_POSITION)
    local team = get_var(player.id, '$team')

    for _, candidate in ipairs(getCandidates(player, team, x, y, z)) do
        local seat_id = findSeat(player.id, candidate.vehicle_id, candidate.vehicle)
        if seat_id then
            if CONFIG.ACCEPT_REJECT then
                requestSeat(player, candidate)
            else
                boardVehicle(player, candidate.vehicle_id, candidate.vehicle, seat_id)
            end
            return
        end
    end

    if CONFIG.CALL_RADIUS > 0 then
        send(player, formatMessage(MESSAGES.no_vehicles_in_range, CONFIG.CALL_RADIUS))
    else
        send(player, MESSAGES.no_vehicles_available)
    end
end

-- Returns the player with the oldest request waiting on this driver.
---@param driver_id number Driver's player index.
---@return UberPlayer | nil passenger
local function findOldestRequest(driver_id)
    local oldest
    for i = 1, MAX_PLAYERS do
        local player = players[i]
        local request = player and player.pending_request
        if request and request.driver_id == driver_id then
            if not oldest or request.sent_tick < oldest.pending_request.sent_tick then
                oldest = player
            end
        end
    end
    return oldest
end

---@param driver   UberPlayer
---@param accepted boolean    True to accept the oldest request, false to reject it.
local function respondToRequest(driver, accepted)
    if not driver.is_driver or not driver.vehicle or not driver.vehicle_id then
        send(driver, MESSAGES.not_a_driver)
        return
    end

    local vehicle_id = driver.vehicle_id
    local vehicle = driver.vehicle
    local passenger = findOldestRequest(driver.id)
    if not passenger then
        send(driver, MESSAGES.no_pending_requests)
        return
    end

    local request = passenger.pending_request
    if not request then
        send(driver, MESSAGES.no_pending_requests)
        return
    end
    passenger.pending_request = nil

    if not accepted then
        send(passenger, MESSAGES.request_declined)
        send(driver, formatMessage(MESSAGES.request_rejected_driver, passenger.name))
        return
    end

    if request.vehicle_id ~= vehicle_id then
        send(passenger, MESSAGES.driver_unavailable)
        send(driver, MESSAGES.passenger_unavailable)
        return
    end

    -- The passenger may have died or boarded something else while waiting.
    local dyn = get_dynamic_player(passenger.id)
    if not dyn or dyn == 0 or read_dword(dyn + DYN_VEHICLE_ID) ~= NO_OBJECT then
        send(driver, MESSAGES.passenger_unavailable)
        return
    end

    local seat_id = findSeat(passenger.id, vehicle_id, vehicle)
    if not seat_id then
        send(passenger, MESSAGES.no_vehicles_available)
        send(driver, MESSAGES.passenger_unavailable)
        return
    end

    boardVehicle(passenger, vehicle_id, vehicle, seat_id)
    send(driver, formatMessage(MESSAGES.request_accepted_driver, passenger.name))
end

---@param player     UberPlayer
---@param kind       string     'disabled' or 'no_driver'.
---@param vehicle_id number     Vehicle object id.
---@param delay      number     Seconds until the ejection.
---@param reason     string     Message explaining why.
local function scheduleEjection(player, kind, vehicle_id, delay, reason)
    if player.auto_eject then return end

    send(player, reason)
    send(player, formatMessage(MESSAGES.ejecting_in, delay))

    player.auto_eject = { kind = kind, vehicle_id = vehicle_id, finish_tick = ticks + delay * TICKS_PER_SECOND }
end

-- Schedules ejection for everyone still riding in a vehicle that just lost its driver.
---@param vehicle_id number Vehicle object id.
---@param driver_id  number Player index of the driver who left.
local function scheduleDriverLeftEjections(vehicle_id, driver_id)
    if not CONFIG.EJECT_WITHOUT_DRIVER then return end

    for i = 1, MAX_PLAYERS do
        local other = players[i]
        if other and i ~= driver_id and other.vehicle_id == vehicle_id then
            scheduleEjection(other, 'no_driver', vehicle_id, CONFIG.EJECT_WITHOUT_DRIVER_TIME, MESSAGES.driver_left)
        end
    end
end

---@param player UberPlayer
local function processAutoEject(player)
    local eject = player.auto_eject
    if not eject or ticks < eject.finish_tick then return end

    player.auto_eject = nil
    if player.vehicle_id ~= eject.vehicle_id then return end -- already left or switched vehicles

    exit_vehicle(player.id)
    send(player, MESSAGES.ejected)
end

---@param player UberPlayer
---@param dyn    number     Dynamic player address.
local function checkCrouch(player, dyn)
    if not CONFIG.CROUCH_TO_CALL then return end

    local crouching = read_bit(dyn + DYN_INPUT_FLAGS, INPUT_FLAG_CROUCH)
    local pressed = crouching == 1 and player.crouching == 0
    player.crouching = crouching

    if pressed and not player.vehicle_id then callUber(player, dyn) end
end

local function processPendingRequests()
    for i = 1, MAX_PLAYERS do
        local player = players[i]
        local request = player and player.pending_request

        if request then
            local driver = players[request.driver_id]

            if ticks >= request.expires_tick then
                player.pending_request = nil
                send(player, MESSAGES.request_timed_out)
            elseif not driver or not driver.is_driver or driver.vehicle_id ~= request.vehicle_id then
                player.pending_request = nil
                send(player, MESSAGES.driver_unavailable)
            end
        end
    end
end

local function loadOverrides()
    overrides = {}
    for tag_path, override in pairs(VEHICLE_OVERRIDES) do
        overrides[tag_path:lower()] = override
    end
end

local function initialize()
    players = {}
    vehicle_cache = {}
    ticks = 0

    local game_type = get_var(0, '$gt')
    objective_gametype = game_type == 'ctf' or game_type == 'oddball'
end

---@param enabled boolean True to register the team game callbacks, false to remove them.
local function setCallbacks(enabled)
    if enabled == callbacks_active then return end
    callbacks_active = enabled

    for event, callback in pairs(sapp_events) do
        if enabled then
            ---@diagnostic disable-next-line: param-type-mismatch
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

function OnScriptLoad()
    loadOverrides()
    register_callback(cb['EVENT_GAME_START'], "OnGameStart")
    OnGameStart() -- in case the script was loaded mid-game
end

function OnGameStart()
    if get_var(0, '$gt') == 'n/a' then return end

    if get_var(0, '$ffa') == '1' then
        setCallbacks(false)
        cprint('====================================', 12)
        cprint('[Uber] Only runs on team-based games', 12)
        cprint('====================================', 12)
        return
    end

    initialize()
    setCallbacks(true)

    for i = 1, MAX_PLAYERS do
        if player_present(i) then OnJoin(i) end
    end

    game_over = false
end

function OnEnd()
    game_over = true
end

---@param player_id number Player index
function OnJoin(player_id)
    players[player_id] = {
        id = player_id,
        name = get_var(player_id, '$name'),
        calls = CONFIG.CALLS_PER_GAME,
        call_ready_tick = 0,
        crouching = 0,
        is_driver = false
    }
end

---@param player_id number Player index
function OnQuit(player_id)
    local player = players[player_id]
    if not player then return end

    if player.is_driver and player.vehicle_id then
        scheduleDriverLeftEjections(player.vehicle_id, player_id)
    end

    players[player_id] = nil
end

function OnTick()
    if game_over then return end

    ticks = ticks + 1

    for i = 1, MAX_PLAYERS do
        local player = players[i]
        if player and player_present(i) then
            local dyn = get_dynamic_player(i)

            if dyn ~= 0 then
                trackVehicle(player, dyn)
                processAutoEject(player)
                checkCrouch(player, dyn)
            else
                clearVehicleState(player)
                player.auto_eject = nil
            end
        end
    end

    processPendingRequests()
end

---@param player_id number Player index
---@param message   string Chat message.
---@return boolean | nil allow Returns false to hide the message when it was an Uber call.
function OnChat(player_id, message)
    local player = players[player_id]
    if not player then return end

    local phrase = message:lower():match('^%s*(.-)%s*$')
    if PHRASES[phrase] then
        callUber(player)
        return false
    end
end

---@param player_id  number Player index
---@param seat_index string Seat index as a string.
function OnVehicleEnter(player_id, seat_index)
    local player = players[player_id]
    local seat = tonumber(seat_index)
    if not player or not seat then return end

    local dyn = get_dynamic_player(player_id)
    if dyn == 0 then return end

    local vehicle_id = read_dword(dyn + DYN_VEHICLE_ID)
    if vehicle_id == NO_OBJECT then return end

    local vehicle_obj = get_object_memory(vehicle_id)
    if vehicle_obj == 0 then return end

    local vehicle = getVehicleInfo(vehicle_obj)
    setVehicleState(player, vehicle_id, seat, vehicle)

    if vehicle and not vehicle.enabled and CONFIG.EJECT_FROM_DISABLED_VEHICLE then
        scheduleEjection(
            player, 'disabled', vehicle_id, CONFIG.EJECT_FROM_DISABLED_VEHICLE_TIME, MESSAGES.vehicle_not_enabled
        )
    end

    if player.is_driver then
        -- A driver arrived, so cancel the "no driver" ejections for this vehicle.
        for i = 1, MAX_PLAYERS do
            local other = players[i]
            local eject = other and other.auto_eject
            if eject and eject.kind == 'no_driver' and eject.vehicle_id == vehicle_id then
                other.auto_eject = nil
                send(other, MESSAGES.ejection_cancelled)
            end
        end
    elseif CONFIG.EJECT_WITHOUT_DRIVER and read_dword(vehicle_obj + VEHICLE_DRIVER_ID) == NO_OBJECT then
        scheduleEjection(player, 'no_driver', vehicle_id, CONFIG.EJECT_WITHOUT_DRIVER_TIME, MESSAGES.vehicle_no_driver)
    end
end

-- Runs on both EVENT_VEHICLE_EXIT and EVENT_DIE.
---@param player_id number Player index
function HandleEjection(player_id)
    local player = players[player_id]
    if not player then return end

    player.auto_eject = nil

    if player.is_driver and player.vehicle_id then
        scheduleDriverLeftEjections(player.vehicle_id, player_id)
    end

    clearVehicleState(player)
end

---@param victim_id number Player index taking damage.
---@param causer_id number Player index dealing damage, or 0 for the world.
---@param damage    number Damage amount.
---@return boolean allow, number | nil new_damage Returns false to block the damage.
function OnDamageApplication(victim_id, causer_id, _, damage)
    if CONFIG.DRIVER_ONLY_IMMUNE and causer_id ~= 0 then
        local victim = players[victim_id]
        local vehicle_id = victim and victim.vehicle_id

        if victim and vehicle_id and victim.is_driver and victim.vehicle and victim.vehicle.capacity > 0
            and countOccupants(vehicle_id) == 1 then
            return false -- lone driver in a vehicle that can carry passengers
        end
    end

    return true, damage
end

---@param player_id number Player index (0 for the console).
---@param command   string The command as typed.
---@return boolean allow Returns false when the command was handled here.
function OnCommand(player_id, command)
    if not CONFIG.ACCEPT_REJECT then return true end

    local player = players[player_id]
    if not player then return true end

    local name = command:lower():match('^(%S+)')
    if name == CONFIG.ACCEPT_COMMAND then
        respondToRequest(player, true)
        return false
    elseif name == CONFIG.REJECT_COMMAND then
        respondToRequest(player, false)
        return false
    end

    return true
end

function OnScriptUnload() end
