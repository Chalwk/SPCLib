--[[
=====================================================================================
SCRIPT NAME:      race_assistant.lua
DESCRIPTION:      Enforces vehicle usage in race gametypes with configurable
                  penalties for violations.

LAST UPDATED:     17/10/25

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ------------------------------------------------------------
local GRACE_PERIOD = 30       -- Seconds to enter vehicle
local FORGIVENESS_PERIOD = 30 -- Seconds of continuous racing before violations reset

local ESCALATING_PENALTIES = {
    { violations = 1, action = "kill", message = "Killed for not racing - 1st offense" },
    { violations = 2, action = "kill", message = "Killed for not racing - 2nd offense" },
    { violations = 3, action = "kick", message = "Removed for racing violations" }
}

local ALLOW_EXEMPTIONS = true
local EXEMPT_ADMIN_LEVELS = {
    [1] = false,
    [2] = false,
    [3] = true,
    [4] = true
}
-- CONFIG END --------------------------------------------------------------

api_version = '1.12.0.0'

local players = {}
local game_in_progress = false

local os_time = os.time
local tonumber = tonumber
local math_ceil = math.ceil

local rprint = rprint
local get_var = get_var
local read_dword = read_dword
local player_alive = player_alive
local player_present = player_present
local get_dynamic_player = get_dynamic_player

local function getPenalty(violation_count)
    for i = #ESCALATING_PENALTIES, 1, -1 do
        if violation_count >= ESCALATING_PENALTIES[i].violations then
            return ESCALATING_PENALTIES[i]
        end
    end
    return ESCALATING_PENALTIES[1]
end

local function inVehicle(id)
    local dyn = get_dynamic_player(id)
    return dyn ~= 0 and read_dword(dyn + 0x11C) ~= 0xFFFFFFFF
end

local function resetPlayer(id)
    if not players[id] then players[id] = {} end

    players[id].timer = os_time() + GRACE_PERIOD
    players[id].warned = false
    players[id].in_vehicle_since = nil
    players[id].violations = players[id].violations or 0
end

local function isExempt(id)
    if not ALLOW_EXEMPTIONS then return false end
    local level = tonumber(get_var(id, '$lvl'))
    return EXEMPT_ADMIN_LEVELS[level] or false
end

local function penalize(player, id, current_time)
    player.violations = player.violations + 1
    local penalty = getPenalty(player.violations)

    rprint(id, penalty.message)

    if penalty.action == "kill" then
        execute_command('kill ' .. id)
    elseif penalty.action == "kick" then
        execute_command('k ' .. id .. ' "Repeated racing violations"')
    end

    player.timer = current_time + GRACE_PERIOD
    player.warned = false
end

local function proceed(id)
    if player_present(id) and player_alive(id) and not isExempt(id) then
        return players[id] or nil
    end
    return nil
end

function OnScriptLoad()
    timer(1000, "CheckPlayers")
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_VEHICLE_ENTER'], 'OnEnter')
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    players = {}
    game_in_progress = true

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnEnd()
    game_in_progress = false
    players = {}
end

function OnJoin(id)
    resetPlayer(id)
end

function OnQuit(id)
    players[id] = nil
end

function OnSpawn(id)
    if not game_in_progress then return end
    resetPlayer(id)
end

function OnEnter(id)
    local player = players[id]
    if player then
        player.timer = 0
        player.warned = false
        player.in_vehicle_since = os_time()
    end
end

function CheckPlayers()
    if not game_in_progress then return true end

    local current_time = os_time()

    for i = 1, 16 do
        local player = proceed(i)
        if not player then goto continue end

        if inVehicle(i) then
            if player.in_vehicle_since and (current_time - player.in_vehicle_since >= FORGIVENESS_PERIOD) then
                if player.violations > 0 then
                    player.violations = 0
                    rprint(i, "Race violations reset.")
                end
                player.in_vehicle_since = os_time()
            end
            goto continue
        end

        if player.timer > 0 then
            local time_left = player.timer - current_time
            local half_time = GRACE_PERIOD / 2

            if not player.warned and time_left <= half_time then
                rprint(i, "WARNING: Enter vehicle in " .. math_ceil(time_left) .. "s and race, or die!")
                rprint(i, 'Use "/vlist" to show vehicle spawn commands.')
                player.warned = true
            elseif time_left <= 0 then
                penalize(player, i, current_time)
            end
        else
            player.timer = current_time + GRACE_PERIOD
            player.warned = false
        end

        ::continue::
    end
    return true
end

function OnScriptUnload() end
