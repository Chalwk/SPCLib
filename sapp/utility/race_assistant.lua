--[[
=====================================================================================
SCRIPT NAME:      race_assistant.lua
DESCRIPTION:      Enforces vehicle usage in race gametypes with configurable
                  penalties for violations.

LAST UPDATED:     2026-11-14

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ------------------------------------------------------------
local GRACE_PERIOD = 30       -- Seconds to enter a racing vehicle (driver seat)
local FORGIVENESS_PERIOD = 30 -- Seconds of continuous racing before violations reset
local REQUIRE_DRIVER = true   -- true = only driver seat counts as racing; false = any seat

-- Gametypes that trigger enforcement. Add others if desired (e.g. ["ctf"] = true).
local ENABLED_GAMETYPES = { ["race"] = true }

local ESCALATING_PENALTIES = {
    { violations = 1, action = "kill", message = "Killed for not racing - 1st offense" },
    { violations = 2, action = "kill", message = "Killed for not racing - 2nd offense" },
    { violations = 3, action = "kick", message = "Removed for racing violations" }
}

local ALLOW_EXEMPTIONS = true
local EXEMPT_ADMIN_LEVELS = { [1] = false, [2] = false, [3] = true, [4] = true }
local NOTIFY_EXEMPT = false
local LOG_TO_CONSOLE = false
-- CONFIG END --------------------------------------------------------------

api_version = '1.12.0.0'

local TICKS_PER_SECOND = 30 -- Do not change unless gamespeed is altered
local GRACE_TICKS = GRACE_PERIOD * TICKS_PER_SECOND
local FORGIVENESS_TICKS = FORGIVENESS_PERIOD * TICKS_PER_SECOND
local HALF_GRACE_TICKS = GRACE_TICKS / 2

local players = {}
local game_in_progress = false

local tick_counter_address
local getCurrentTick

local os_time = os.time
local tonumber = tonumber
local math_ceil = math.ceil

local rprint = rprint
local cprint = cprint
local get_var = get_var
local read_word = read_word
local read_dword = read_dword
local sig_scan = sig_scan
local player_alive = player_alive
local player_present = player_present
local get_dynamic_player = get_dynamic_player
local execute_command = execute_command
local register_callback = register_callback

local function log(message, color)
    ---@diagnostic disable-next-line: unnecessary-if
    if LOG_TO_CONSOLE then
        cprint("[race_assistant] " .. message, color or 8)
    end
end

local function resolveTickCounter()
    local hit = sig_scan("8B2D????????807D0000C644240600")
    if hit == 0 then return nil end

    local ptr1 = read_dword(hit + 2)
    if not ptr1 or ptr1 < 0x400000 or ptr1 > 0x800000 then return nil end

    local struct_ptr = read_dword(ptr1)
    if not struct_ptr or struct_ptr < 0x10000 then return nil end

    return struct_ptr + 0xC
end

local function getPenalty(violation_count)
    for i = #ESCALATING_PENALTIES, 1, -1 do
        if violation_count >= ESCALATING_PENALTIES[i].violations then
            return ESCALATING_PENALTIES[i]
        end
    end
    return ESCALATING_PENALTIES[1]
end

local function resetPlayer(id)
    if not players[id] then
        players[id] = {}
    end

    ---@diagnostic disable-next-line: need-check-nil
    players[id].timer = getCurrentTick() + GRACE_TICKS
    players[id].warned = false
    players[id].in_vehicle_since = nil
    players[id].was_driving = false
    players[id].violations = players[id].violations or 0
end

local function isExempt(id)
    ---@diagnostic disable-next-line: unnecessary-if
    if not ALLOW_EXEMPTIONS then return false end
    local level = tonumber(get_var(id, '$lvl'))
    return EXEMPT_ADMIN_LEVELS[level] or false
end

local function penalize(player, id, current_tick)
    player.violations = player.violations + 1
    local penalty = getPenalty(player.violations)

    rprint(id, penalty.message)
    log(
        string.format(
            "Player %d (%s) - violation %d -> %s", 
            id, 
            get_var(id, '$name'), 
            player.violations, 
            penalty.action
        ), 12
    )

    if penalty.action == "kill" then
        execute_command('kill ' .. id)
        ---@diagnostic disable-next-line: unnecessary-if
    elseif penalty.action == "kick" then
        execute_command('k ' .. id .. ' "Repeated racing violations"')
    end

    player.timer = current_tick + GRACE_TICKS
    player.warned = false
end

local function proceed(id)
    if player_present(id) and player_alive(id) and not isExempt(id) then
        return players[id]
    end
    return nil
end

function OnScriptLoad()
    tick_counter_address = resolveTickCounter()

    if tick_counter_address then
        getCurrentTick = function () return read_dword(tick_counter_address) end
        log("Tick counter resolved - precise timing enabled", 10)
    else
        log("WARNING: tick counter unresolved; falling back to os.time()", 14)
        getCurrentTick = function () return os_time() * TICKS_PER_SECOND end
    end

    timer(1000, "CheckPlayers")
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnLeave')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_VEHICLE_ENTER, 'OnVehicleEnter')
    register_callback(cb.EVENT_VEHICLE_EXIT, 'OnVehicleExit')

    OnStart()
end

function OnStart()
    local gt = get_var(0, "$gt")
    if gt == "n/a" or not ENABLED_GAMETYPES[gt] then
        game_in_progress = false
        return
    end

    players = {}
    game_in_progress = true
    log(
        string.format(
            "Race enforcement active (grace %ds, forgiveness %ds, %s)", 
            GRACE_PERIOD, 
            FORGIVENESS_PERIOD,
            REQUIRE_DRIVER and "driver-only" or "any-seat"
        ), 10
    )

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnEnd()
    game_in_progress = false
    players = {}
    log("Race enforcement paused (game ended)", 14)
end

function OnJoin(id)
    resetPlayer(id)
    ---@diagnostic disable-next-line: unnecessary-if
    if NOTIFY_EXEMPT and isExempt(id) then
        rprint(id, "Admin exemption active - racing penalties disabled.")
    end
end

function OnLeave(id)
    players[id] = nil
end

function OnSpawn(id)
    if not game_in_progress then return end
    resetPlayer(id)
end

function OnVehicleEnter(id, seat_index)
    local player = players[id]
    if not player then return end

    local seat = tonumber(seat_index) or 0
    if REQUIRE_DRIVER and seat ~= 0 then return end

    player.timer = 0
    player.warned = false
    ---@diagnostic disable-next-line: need-check-nil
    player.in_vehicle_since = getCurrentTick()
end

function OnVehicleExit(id)
    local player = players[id]
    if not player then return end
    player.in_vehicle_since = nil
end

function OnError(message)
    log("Lua error: " .. tostring(message), 12)
end

function CheckPlayers()
    if not game_in_progress then return true end

    ---@diagnostic disable-next-line: need-check-nil
    local current_tick = getCurrentTick()

    for i = 1, 16 do
        local player = proceed(i)
        if not player then goto continue end

        local dyn = get_dynamic_player(i)
        if dyn == 0 then goto continue end

        local vehicle_id = read_dword(dyn--[[@cast -?]] + 0x11C)
        local in_vehicle = vehicle_id ~= 0xFFFFFFFF
        local is_driving = in_vehicle and (not REQUIRE_DRIVER or read_word(dyn--[[@cast -?]] + 0x2F0) == 0)

        if is_driving then
            if not player.in_vehicle_since then
                player.in_vehicle_since = current_tick
            end
            if (current_tick - player.in_vehicle_since) >= FORGIVENESS_TICKS then
                if player.violations > 0 then
                    player.violations = 0
                    rprint(i, "Race violations reset.")
                    log(string.format("Player %d violations reset (clean racing)", i), 10)
                end
                player.in_vehicle_since = current_tick
            end
            player.timer = 0
            player.warned = false
            player.was_driving = true
            goto continue
        end

        player.in_vehicle_since = nil

        if player.was_driving then
            player.timer = current_tick + GRACE_TICKS
            player.warned = false
            player.was_driving = false
        end

        if player.timer > 0 then
            local time_left_ticks = player.timer - current_tick

            if time_left_ticks <= 0 then
                penalize(player, i, current_tick)
            elseif not player.warned and time_left_ticks <= HALF_GRACE_TICKS then
                local s = math_ceil(time_left_ticks / TICKS_PER_SECOND)
                if in_vehicle then
                    rprint(i, "WARNING: Switch to the DRIVER seat in " .. s .. "s, or die!")
                else
                    rprint(i, "WARNING: Enter a vehicle in " .. s .. "s and race, or die!")
                end
                player.warned = true
            end
        else
            player.timer = current_tick + GRACE_TICKS
            player.warned = false
        end

        ::continue::
    end
    return true
end

function OnScriptUnload()
    game_in_progress = false
    players = {}
end
