--[[
=====================================================================================
SCRIPT NAME:      ping_spike_watch.lua
DESCRIPTION:      Tracks ping, rolling average, and sudden spikes.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "pingwatch"

local HIGH_PING = 210
local SPIKE_THRESHOLD = 35
local ALERT_COOLDOWN_TICKS = 45

local HID_PING_OK = "Ping: %d ms | Avg: %d ms | Delta: %+d"
local HUD_PING_HIGH_TAG = "  [HIGH]"
local HUD_MISSING_PING = "Ping: -- ms"
local CONSOLE_ALERT = "Latency warning: ping is %d ms (avg %d ms)."
local TOGGLE_ENABLED = "Ping Spike Watch enabled."
local TOGGLE_DISABLED = "Ping Spike Watch disabled."
-- CONFIG END --

set_callback("tick", "OnTick")
set_callback("map load", "OnMapLoad")
set_callback("command", "OnCommand")

local tick_count = 0
local last_message = ""
local ema_ping = nil
local last_alert_tick = -9999

local format = string.format
local math_floor = math.floor

local function get_ping()
    local id = get_player()
    if not id then return nil end
    return read_dword(id + 0xDC)
end

local function proceed(id)
    return ENABLED and id and server_type == "dedicated"
end

function OnMapLoad()
    tick_count = 0
    last_message = ""
    ema_ping = nil
    last_alert_tick = -9999
end

function OnTick()
    local id = get_player()
    if not proceed(id) then return end

    local ping = get_ping()
    if not ping then
        local msg = HUD_MISSING_PING
        if msg ~= last_message then
            execute_script("cls")
            hud_message(msg)
            last_message = msg
        end
        return
    end

    ema_ping = ema_ping and (ema_ping * 0.85 + ping * 0.15) or ping

    local avg = math_floor(ema_ping + 0.5)
    local delta = math_floor(ping - ema_ping + 0.5)

    local msg = format(HID_PING_OK, ping, avg, delta)
    if ping >= HIGH_PING then
        msg = msg .. HUD_PING_HIGH_TAG
    end

    if msg ~= last_message then
        execute_script("cls")
        hud_message(msg)
        last_message = msg
    end

    local now = ticks()
    if (ping >= HIGH_PING or delta >= SPIKE_THRESHOLD) and (now - last_alert_tick) >= ALERT_COOLDOWN_TICKS then
        console_out(format(CONSOLE_ALERT, ping, avg))
        last_alert_tick = now
    end
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out(ENABLED and TOGGLE_ENABLED or TOGGLE_DISABLED)
        return false
    end
end
