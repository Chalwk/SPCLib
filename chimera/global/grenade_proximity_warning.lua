--[[
=====================================================================================
SCRIPT NAME:      grenade_proximity_warning.lua
DESCRIPTION:      Shows a warning when a live grenade is nearby and indicates its
                  direction relative to the player using clock-face notation
                  (e.g., 12 = ahead, 3 = right, 6 = behind, etc.).

                  Command: /grenwarn - Toggle proximity warning on/off

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
clua_version = 2.056

local ENABLED = true
local COMMAND = "grenwarn"
local RADIUS = 3.5 -- warning radius in world units
-- END CONFIG --

local pi = math.pi

-- POLYFILL: math.atan2 (not available in Lua 5.1)
if not math.atan2 then
    math.atan2 = function (y, x)
        if x > 0 then
            return math.atan(y / x)
        elseif x < 0 then
            return (y >= 0 and math.atan(y / x) + pi or math.atan(y / x) - pi)
        else
            if y > 0 then
                return pi / 2
            elseif y < 0 then
                return -pi / 2
            else
                return 0
            end
        end
    end
end

-- For the sake of performance
local get_dynamic_player = get_dynamic_player
local read_float = read_float
local read_dword = read_dword
local read_word = read_word
local read_string = read_string
local get_tag = get_tag
local hud_message = hud_message

local atan2 = math.atan2
local deg = function (rad) return rad * 180 / pi end

-- Clock-face positions for the eight 45-degree sectors, starting from straight ahead (12 o'clock)
local directions = { "12", "1:30", "3", "4:30", "6", "7:30", "9", "10:30" }

local function get_pos(base) -- player/object
    return read_float(base + 0x5C), read_float(base + 0x60), read_float(base + 0x64)
end

local function get_player_forward(player)
    return read_float(player + 0x230), read_float(player + 0x234)
end

local function is_grenade(obj)
    local tag_id = read_dword(obj)
    if tag_id == 0 then return false end
    local tag = get_tag(tag_id)
    if not tag then return false end
    local path = read_string(read_dword(tag + 0x10))
    return path and (path:find("frag grenade") or path:find("plasma grenade"))
end

local function compute_direction(px, py, gx, gy, fx, fy)
    local dx = gx - px
    local dy = gy - py
    local angle = deg(atan2(fy, fx)) - deg(atan2(dy, dx))
    angle = (angle + 360) % 360
    local idx = math.floor((angle + 22.5) / 45) % 8 + 1
    return directions[idx]
end

function OnTick()
    if not ENABLED then return end

    local player = get_dynamic_player()
    if not player then return end

    local m_player = get_player()
    local player_obj_id = m_player and read_dword(m_player + 0x34) or nil
    if not player_obj_id then return end

    local px, py, pz = get_pos(player)
    local fx, fy = get_player_forward(player)

    -- Global object table to enumerate all game objects
    local object_table = read_dword(read_dword(0x401192 + 2))
    if object_table == 0 then return end -- safety check

    -- Get the total number of objects and the pointer to the first object entry
    local object_count = read_word(object_table + 0x2E)
    local first_object = read_dword(object_table + 0x34)
    if first_object == 0 then return end -- no objects to scan

    local closest_dist = RADIUS + 1 -- start just above the warning threshold
    local closest_dir = nil

    -- Loop through every object in the world
    for i = 0, object_count - 1 do
        local obj = read_dword(first_object + i * 0xC + 0x8)
        if obj ~= 0 and read_word(obj + 0xB4) == 5 then -- object type: projectile
            if is_grenade(obj) then
                local owner_id = read_dword(obj + 0xC4)
                if owner_id ~= player_obj_id then
                    local gx, gy, gz = get_pos(obj)
                    local dx = gx - px
                    local dy = gy - py
                    local dz = gz - pz
                    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if dist < closest_dist then
                        closest_dist = dist
                        closest_dir = compute_direction(px, py, gx, gy, fx, fy)
                    end
                end
            end
        end
    end

    ---@diagnostic disable-next-line: unnecessary-if
    if closest_dist < RADIUS and closest_dir then
        for _ = 1, 10 do
            hud_message(" ")
        end
        hud_message("Grenade! @ " .. closest_dir)
    end
end

function OnCommand(command)
    if command:lower() == COMMAND then
        ENABLED = not ENABLED
        console_out("Grenade proximity warning " .. (ENABLED and "enabled" or "disabled") .. ".")
        return false
    end
end

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")
