--[[
===============================================================================
SCRIPT NAME:      game_countdown.lua
DESCRIPTION:      Displays remaining game time.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG START --
api_version = "1.12.0.0"

local DISPLAY_INTERVAL = 1
local OUTPUT = "%s"
local TIME_FORMAT = "%02d:%02d:%02d"
local TOGGLE_COMMAND = "countdown"
-- END CONFIG --

local floor, format = math.floor, string.format
local get_var, timer = get_var, timer
local player_present, rprint = player_present, rprint

local timelimit_address, tick_counter_address, sv_map_reset_tick_address
local game_started
local disabled = {}

local function SecondsToTime(seconds)
    seconds = floor(seconds)
    local hr = floor(seconds / 3600)
    local min = floor((seconds % 3600) / 60)
    local sec = floor(seconds % 60)
    return format(TIME_FORMAT, hr, min, sec)
end

local function getTimeRemaining()
    local timelimit = read_dword(timelimit_address)
    local tick_counter = read_dword(tick_counter_address)
    local sv_map_reset_tick = read_dword(sv_map_reset_tick_address)
    return SecondsToTime((timelimit - (tick_counter - sv_map_reset_tick)) / 30)
end

function OnScriptLoad()

    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")

    local tick_counter_sig = sig_scan("8B2D????????807D0000C644240600")
    if tick_counter_sig == 0 then return end

    local sv_map_reset_tick_sig = sig_scan("8B510C6A018915????????E8????????83C404")
    if sv_map_reset_tick_sig == 0 then return end

    local timelimit_location_sig = sig_scan("8B0D????????83C8FF85C97E17")
    if timelimit_location_sig == 0 then return end

    timelimit_address = read_dword(timelimit_location_sig + 2)
    sv_map_reset_tick_address = read_dword(sv_map_reset_tick_sig + 7)
    tick_counter_address = read_dword(read_dword(tick_counter_sig + 2)) + 0xC

    OnStart() -- in case script is loaded mid-game
end

function OnStart()
    if get_var(0, '$gt') == "n/a" then return end
    game_started = true
    disabled = {}
    timer(1000 * DISPLAY_INTERVAL, "GameCountdown")
end

function OnEnd()
    game_started = false
    disabled = {}
end

function OnCommand(id, command)
    if command:lower() ~= TOGGLE_COMMAND then return true end

    disabled[id] = not disabled[id]
    rprint(id, "Game countdown " .. (disabled[id] and "disabled" or "enabled") .. ".")
    return false
end

local function clear_hud(id)
    for _ = 1,25 do rprint(id, " ") end
end

function GameCountdown()
    if not game_started then return end

    local time_remaining = getTimeRemaining()

    for i = 1, 16 do
        if player_present(i) and not disabled[i] then
            clear_hud(i)
            rprint(i, format(OUTPUT, time_remaining))
        end
    end

    return true
end
