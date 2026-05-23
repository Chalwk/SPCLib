--[[
================================================================================================
SCRIPT NAME:      vehicle_rider_names.lua
DESCRIPTION:      Shows driver, gunner, and passenger names when you are in a vehicle.
                  Can hide your own name or mark it with "(you)".

                  Command: /riders - Toggle rider name display on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
================================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "riders"
local UPDATE_INTERVAL = 15 -- ticks between HUD updates
local HIDE_SELF = false    -- set to true to not show your own name
-- END CONFIG --

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")

local ticker = 0

local function get_player_name(index)
    local obj = get_player(index)
    if not obj then return "Unknown" end
    local addr = obj + 0x4
    local chars = {}
    for j = 1, 12 do
        local b = read_byte(addr + (j - 1) * 2)
        if b == 0 then break end
        chars[#chars + 1] = string.char(b)
    end
    return table.concat(chars)
end

local function clear_hud()
    for _ = 1, 10 do
        hud_message(" ")
    end
end

local function add_rider(parts, label, idx)
    if not idx then return end
    local name = get_player_name(idx)
    if idx == local_player_index then
        name = name .. " (you)"
    end
    parts[#parts + 1] = label .. ": " .. name
end

function OnTick()
    if not ENABLED then return end

    ticker = ticker + 1
    if ticker < UPDATE_INTERVAL then return end
    ticker = 0

    local local_dyn = get_dynamic_player()
    if not local_dyn then return end

    local local_vehicle_id = read_dword(local_dyn + 0x11C)
    if local_vehicle_id == 0xFFFFFFFF then return end

    local driver_idx, gunner_idx, passenger_idx = nil, nil, nil

    for i = 0, 15 do
        if i ~= local_player_index or not HIDE_SELF then
            local dyn = get_dynamic_player(i)
            if dyn and dyn ~= 0 then
                local veh_id = read_dword(dyn + 0x11C)
                if veh_id == local_vehicle_id then
                    local seat = read_byte(dyn + 0x2F0)
                    if seat == 0 then
                        driver_idx = i
                    elseif seat == 1 then
                        passenger_idx = i
                    elseif seat == 2 then
                        gunner_idx = i
                    else
                        passenger_idx = i
                    end
                end
            end
        end
    end

    local parts = {}

    add_rider(parts, "Driver", driver_idx)
    add_rider(parts, "Gunner", gunner_idx)
    add_rider(parts, "Passenger", passenger_idx)

    if #parts == 0 then return end
    local msg = table.concat(parts, " | ")

    clear_hud()
    hud_message(msg)
end

function OnCommand(cmd)
    if cmd:lower() == COMMAND then
        ENABLED = not ENABLED
        if not ENABLED then clear_hud() end
        console_out("Rider name display " .. (ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end
