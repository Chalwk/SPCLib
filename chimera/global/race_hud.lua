--[[
======================================================================
SCRIPT NAME:      race_hud.lua
DESCRIPTION:      Displays speed, map name & checkpoint progress (current/total).

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
======================================================================
]]

-- CONFIG START --
clua_version = 2.056

local FACTOR = 30 * 3.6
local LEFT = 0
local RIGHT = 635
local LINE_HEIGHT = 20
-- CONFIG END --

-- Message definitions: {format, x1, y1, x2, y2, font, align, alpha, r, g, b}
local MESSAGES = {
    { "Map: %s", LEFT, 5, RIGHT, LINE_HEIGHT + 5, "small", "left", 1.0, 0.45, 0.72, 1.0 },
    { "%s | %.0f km/h", LEFT, LINE_HEIGHT + 5, RIGHT, LINE_HEIGHT * 2 + 5, "small", "left", 1.0, 0.45, 0.72, 1.0 },
    { "CP [%s-%s]", LEFT, LINE_HEIGHT * 2 + 5, RIGHT, LINE_HEIGHT * 3 + 5, "small", "left", 1.0, 0.45, 0.72, 1.0 }
}

local msg_params = {
    { "" },    -- map: map name
    { "", 0 }, -- speed: vehicle name + km/h
    { "", "" } -- current checkpoint index + total checkpoints
}

local vehicle_name_cache = {}

local should_draw = false
local last_vehicle_id = nil
local last_vehicle_obj = nil
local last_vehicle_name = ""

local race_globals = 0x64C1C0 -- CE
local checkpoint_addr
local last_mask, last_idx = 0, 0
local total_checkpoints = 0

local math_sqrt = math.sqrt
local math_floor = math.floor
local gsub = string.gsub
local string_format = string.format
local table_unpack = table.unpack
local read_float = read_float
local read_dword = read_dword
local get_object = get_object
local get_dynamic_player = get_dynamic_player
local get_tag = get_tag
local read_string = read_string
local draw_text = draw_text

local vehicle_names = {
    ghost_mp = "Ghost",
    ghost = "Ghost",
    rwarthog = "R-Hog",
    banshee_mp = "Banshee",
    banshee = "Banshee",
    mp_warthog = "Warthog",
    warthog = "Warthog",
    scorpion_mp = "Tank",
    scorpion = "Tank",
    warthog_laag = "LAAG Warthog",
    warthog_l = "Gauss Warthog",
    warthog_rocket = "Rocket Warthog",
    spectre = "Spectre",
    spectre_gun = "Spectre (Gunner)",
    wraith = "Wraith",
    shade = "Shade Turret",
    mongoose = "Mongoose"
}

local function update_checkpoint_addr()
    if checkpoint_addr then return end
    if local_player_index == nil then return end
    checkpoint_addr = race_globals + (local_player_index * 4) + 0x44
end

local function bit_band(a, b) -- Chimera doesn't have bit library
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then
            result = result + bitval
        end
        a = math_floor(a / 2)
        b = math_floor(b / 2)
        bitval = bitval * 2
    end
    return result
end

local function bit_rshift(x, n)
    return math_floor(x / (2 ^ n))
end

local popcnt8 = {}
for i = 0, 255 do
    local c, n = 0, i
    while n > 0 do
        c = c + (n % 2)
        n = math_floor(n / 2)
    end
    popcnt8[i] = c
end

local function get_checkpoint_idx(bitmask)
    if bitmask == 0 then return 0 end
    return popcnt8[bit_band(bitmask, 0xFF)] + popcnt8[bit_band(bit_rshift(bitmask, 8), 0xFF)]
        + popcnt8[bit_band(bit_rshift(bitmask, 16), 0xFF)] + popcnt8[bit_band(bit_rshift(bitmask, 24), 0xFF)]
end

local function get_checkpoint_count(mask) -- get total checkpoints
    local count = 0
    while mask ~= 0 do
        mask = bit_band(mask, mask - 1)
        count = count + 1
    end
    return count + 1
end

local function format_vehicle_name(raw_name)
    if vehicle_names[raw_name] then return vehicle_names[raw_name] end
    local lower = raw_name:lower()
    if vehicle_names[lower] then return vehicle_names[lower] end

    local name = gsub(raw_name, "_", " ")
    name = gsub(name, "(%a)([%a]*)", function (first, rest)
        return first:upper() .. rest:lower()
    end)
    return name
end

local function get_vehicle_name_cached(vehicle_obj)
    if not vehicle_obj then return "Unknown" end
    local tag_id = read_dword(vehicle_obj)
    if not tag_id or tag_id == 0 then return "Unknown" end

    local cached = vehicle_name_cache[tag_id]
    if cached then return cached end

    local tag = get_tag(tag_id)
    if not tag then return "Unknown" end
    local path = read_string(read_dword(tag + 0x10))
    if not path then return "Unknown" end

    local filename = gsub((path:match(".*\\([^\\]+)$") or path), "%.[^%.]+$", "")
    local name = format_vehicle_name(filename)
    vehicle_name_cache[tag_id] = name
    return name
end

function OnTick()
    if gametype and gametype ~= "race" then return end

    update_checkpoint_addr()
    if not checkpoint_addr then return end

    local total_mask = read_dword(race_globals)
    if total_mask and total_mask ~= 0 then
        total_checkpoints = get_checkpoint_count(total_mask)
    end

    local player = get_dynamic_player()
    local vehicle_id, vehicle_obj = nil, nil
    local vehicle_name, kmh = "", 0
    local current_idx = 0

    if player then
        vehicle_id = read_dword(player + 0x11C)
        if vehicle_id and vehicle_id ~= 0xFFFFFFFF then
            vehicle_obj = get_object(vehicle_id)
        end

        local checkpoint_mask = read_dword(checkpoint_addr)
        if checkpoint_mask ~= last_mask then
            last_mask = checkpoint_mask
            last_idx = get_checkpoint_idx(checkpoint_mask)
        end
        current_idx = last_idx
    end

    should_draw = (player ~= nil) and (vehicle_obj ~= nil)

    if vehicle_obj ~= last_vehicle_obj or vehicle_id ~= last_vehicle_id then
        last_vehicle_id = vehicle_id
        last_vehicle_obj = vehicle_obj
        last_vehicle_name = get_vehicle_name_cached(vehicle_obj)
    end
    vehicle_name = last_vehicle_name

    if vehicle_obj then
        local vx = read_float(vehicle_obj + 0x68)
        local vy = read_float(vehicle_obj + 0x6C)
        local vz = read_float(vehicle_obj + 0x70)
        local raw_speed = math_sqrt(vx * vx + vy * vy + vz * vz)
        kmh = raw_speed * FACTOR
    end

    msg_params[1][1] = map
    local speed_params = msg_params[2]
    speed_params[1] = vehicle_name
    speed_params[2] = kmh

    msg_params[3][1] = tostring(current_idx)
    msg_params[3][2] = tostring(total_checkpoints)
end

function OnPreFrame()
    if not should_draw then return end
    for i = 1, #MESSAGES do
        local msg = MESSAGES[i]
        local formatted = string_format(msg[1], table_unpack(msg_params[i]))
        draw_text(formatted, msg[2], msg[3], msg[4], msg[5], msg[6], msg[7], msg[8], msg[9], msg[10], msg[11])
    end
end

function OnMapLoad()
    if map == "ui" then return end -- menu
    checkpoint_addr = nil
    total_checkpoints, last_mask, last_idx = 0, 0, 0
end

set_callback("map load", "OnMapLoad")
set_callback("tick", "OnTick")
set_callback("preframe", "OnPreFrame")
