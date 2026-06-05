--[[
===========================================================================
SCRIPT NAME:      race_hud.lua
DESCRIPTION:      Displays speed (km), map name, checkpoint progress,
                  lap timer, and best time.

                  Commands:
                    /hud            - Toggle HUD on/off
                    /hudsize <size> - Set text size: small, medium, large

                  Persistent stats saved to race_hud_stats.txt.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===========================================================================
]]

-- CONFIG START --
clua_version = 2.056

local FACTOR = 30 * 3.6
local LEFT = 5
local RIGHT = 635
local LINE_HEIGHT = 20
local Y_OFFSET = 150
local STATS_FILE = "race_hud_stats.txt"

-- HUD settings
local HUD_ENABLED = true      -- default HUD state
local HUD_FONT_SIZE = "small" -- default font size: "small", "medium", "large"

-- Message definitions: {msg, x1, y1, x2, y2, font size, align, alpha, r, g, b}
local MESSAGES = {
    { "%s", LEFT, Y_OFFSET + 5, RIGHT, Y_OFFSET + LINE_HEIGHT + 5, HUD_FONT_SIZE, "left", 1.0, 0.45, 0.72, 1.0 },
    {
        "%s | %.0fkm/h",
        LEFT,
        Y_OFFSET + LINE_HEIGHT + 5,
        RIGHT,
        Y_OFFSET + LINE_HEIGHT * 2 + 5,
        HUD_FONT_SIZE,
        "left",
        1.0,
        0.45,
        0.72,
        1.0
    },
    {
        "CP: %s-%s",
        LEFT,
        Y_OFFSET + LINE_HEIGHT * 2 + 5,
        RIGHT,
        Y_OFFSET + LINE_HEIGHT * 3 + 5,
        HUD_FONT_SIZE,
        "left",
        1.0,
        0.45,
        0.72,
        1.0
    },
    {
        "PB: %s",
        LEFT,
        Y_OFFSET + LINE_HEIGHT * 3 + 5,
        RIGHT,
        Y_OFFSET + LINE_HEIGHT * 4 + 5,
        HUD_FONT_SIZE,
        "left",
        1.0,
        0.45,
        0.72,
        1.0
    },
    {
        "%s",
        LEFT,
        Y_OFFSET + LINE_HEIGHT * 4 + 5,
        RIGHT,
        Y_OFFSET + LINE_HEIGHT * 5 + 5,
        HUD_FONT_SIZE,
        "left",
        1.0,
        0.45,
        0.72,
        1.0
    }
}

-- CONFIG END --

local msg_params = {
    { "" },     -- map name
    { "", 0 },  -- vehicle name + km/h
    { "", "" }, -- current checkpoint index + total checkpoints
    { "" },     -- best time
    { "" }      -- current lap time
}

local vehicle_name_cache = {}
local map_best_table = {}

local last_vehicle_obj = nil
local last_vehicle_name = ""

local race_globals = 0x64C1C0 -- CE
local gametype_base = 0x68CC48 -- CE
local checkpoint_addr
local last_mask, last_idx = 0, 0
local total_checkpoints = nil

local lap_started = false
local lap_finished = false
local start_time_seconds = 0
local current_time_seconds = 0
local best_time_seconds = nil
local best_time_str = "---:--.--"

local io_open = io.open
local os_clock = os.clock
local math_sqrt = math.sqrt
local math_floor = math.floor
local gsub = string.gsub
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local table_unpack = table.unpack
local read_float = read_float
local read_dword = read_dword
local get_object = get_object
local get_dynamic_player = get_dynamic_player
local get_tag = get_tag
local read_string = read_string
local draw_text = draw_text
local read_byte = read_byte

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

local popcnt8 = {}
for i = 0, 255 do
    local c, n = 0, i
    while n > 0 do
        c = c + (n % 2)
        n = math_floor(n / 2)
    end
    popcnt8[i] = c
end

local two = {}
for i = 0, 99 do
    two[i] = string_format("%02d", i)
end

local function format_time(s)
    if not s or s < 0 then return "00:00.00" end
    local total = math_floor(s * 100 + 0.5)
    local mins  = math_floor(total / 6000)
    local rem   = total - mins * 6000
    local secs  = math_floor(rem / 100)
    local cent  = rem - secs * 100
    return mins .. ":" .. two[secs] .. "." .. two[cent]
end

local function load_best_for_current_map()
    local best = map_best_table[map]
    if best then
        best_time_seconds = best
        best_time_str = format_time(best_time_seconds)
    else
        best_time_seconds = nil
        best_time_str = "---:--.--"
    end
end

local function load_stats()
    map_best_table = {}
    local f = io_open(STATS_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local map_name, best = line:match("^([^;]+);([%d%.]+)$")
        if map_name and best then
            local best_num = tonumber(best)
            if best_num then
                map_best_table[map_name] = best_num
            end
        end
    end
    f:close()
    load_best_for_current_map()
end

local function save_stats()
    local f = io_open(STATS_FILE, "w")
    if not f then return end
    for map_name, best_sec in pairs(map_best_table) do
        f:write(string_format("%s;%.2f\n", map_name, best_sec))
    end
    f:close()
end

local function update_best_time(final_time)
    local current_best = map_best_table[map]
    if not current_best or final_time < current_best then
        map_best_table[map] = final_time
        save_stats()
        best_time_seconds = final_time
        best_time_str = format_time(best_time_seconds)
    else
        best_time_seconds = current_best
        best_time_str = format_time(best_time_seconds)
    end
end

local function bit_band(a, b) -- Chimera doesn't have bit library
    local result, bitval = 0, 1
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

local function get_checkpoint_idx(bitmask) -- get current checkpoint index (0-indexed)
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

local function update_checkpoint_addr()
    if checkpoint_addr then return end
    if local_player_index == nil then return end
    checkpoint_addr = race_globals + (local_player_index * 4) + 0x44
end

local function get_total_checkpoints()
    if total_checkpoints then return end
    local total_mask = read_dword(race_globals)
    if total_mask and total_mask ~= 0 then
        total_checkpoints = get_checkpoint_count(total_mask)
    end
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

local function get_player_vehicle(dynamic_player)
    local vehicle = read_dword(dynamic_player + 0x11C)
    if vehicle == 0xFFFFFFFF then return nil end
    return get_object(vehicle)
end

local function show_hud()
    local player = get_dynamic_player()
    local game_type = read_byte(gametype_base + 0x30)
    return (server_type == "dedicated" and game_type == 5 and player ~= nil and HUD_ENABLED) and player or nil
end

function OnTick()
    local player = show_hud()
    if not player then return end

    update_checkpoint_addr()
    if not checkpoint_addr then return end
    get_total_checkpoints()
    if not total_checkpoints then return end

    local vehicle_name, kmh = "", 0
    local current_idx = 0

    local checkpoint_mask = read_dword(checkpoint_addr) -- (0-indexed)
    if checkpoint_mask ~= last_mask then
        last_mask = checkpoint_mask
        last_idx = get_checkpoint_idx(checkpoint_mask)
    end
    current_idx = last_idx

    local vehicle_obj = get_player_vehicle(player)
    if vehicle_obj then
        if vehicle_obj ~= last_vehicle_obj then
            last_vehicle_obj = vehicle_obj
            last_vehicle_name = get_vehicle_name_cached(vehicle_obj)
        end
        vehicle_name = last_vehicle_name

        local vx = read_float(vehicle_obj + 0x68)
        local vy = read_float(vehicle_obj + 0x6C)
        local vz = read_float(vehicle_obj + 0x70)
        kmh = math_sqrt(vx * vx + vy * vy + vz * vz) * FACTOR
    end

    if not lap_finished and total_checkpoints > 0 then
        if not lap_started and current_idx > 0 then
            lap_started = true
            start_time_seconds = os_clock()
            current_time_seconds = 0
        elseif lap_started and not lap_finished then
            current_time_seconds = os_clock() - start_time_seconds
            if current_idx >= total_checkpoints then
                lap_finished = true
                update_best_time(current_time_seconds)
            end
        end
    end

    if lap_started and not lap_finished and current_idx == 0 then
        lap_started, current_time_seconds = false, 0
    end

    msg_params[1][1] = map
    local speed_params = msg_params[2]
    speed_params[1] = vehicle_name
    speed_params[2] = kmh
    msg_params[3][1] = tostring(current_idx)
    msg_params[3][2] = tostring(total_checkpoints)
    msg_params[4][1] = best_time_str

    if lap_started and not lap_finished then
        msg_params[5][1] = format_time(current_time_seconds)
    elseif lap_finished then
        msg_params[5][1] = format_time(current_time_seconds)
    else
        msg_params[5][1] = "00:00.00"
    end
end

function OnPreFrame()
    if not show_hud() then return end

    for i = 1, #MESSAGES do
        local msg = MESSAGES[i]
        local formatted = string_format(msg[1], table_unpack(msg_params[i]))
        draw_text(formatted, msg[2], msg[3], msg[4], msg[5], HUD_FONT_SIZE, msg[7], msg[8], msg[9], msg[10], msg[11])
    end
end

function OnMapLoad()
    checkpoint_addr, total_checkpoints = nil, nil
    last_mask, last_idx = 0, 0
    lap_started, lap_finished = false, false
    start_time_seconds, current_time_seconds = 0, 0

    load_stats()
end

local function parse_cmd(cmd)
    local args = {}
    for w in cmd:gmatch("%S+") do
        args[#args + 1] = w
    end
    return args
end

function OnCommand(cmd)
    local args = parse_cmd(cmd)
    local command = args[1]:lower()

    if command == "hud" then
        HUD_ENABLED = not HUD_ENABLED
        console_out("Race HUD " .. (HUD_ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    elseif command == "hudsize" and #args >= 2 then
        local size = args[2]:lower()
        if size == "small" or size == "medium" or size == "large" then
            HUD_FONT_SIZE = size
            for i = 1, #MESSAGES do
                MESSAGES[i][6] = HUD_FONT_SIZE
            end
            console_out("HUD font size set to: " .. size .. ".")
        else
            console_out("Invalid size. Use: small, medium, or large.")
        end
        return false
    end
end

OnMapLoad()

set_callback("map load", "OnMapLoad")
set_callback("tick", "OnTick")
set_callback("preframe", "OnPreFrame")
set_callback("command", "OnCommand")