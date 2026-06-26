--[[
===========================================================================
SCRIPT NAME:      vehicle_speedometer.lua
DESCRIPTION:      HUD that displays map name, vehicle name,
                  and speed (km/h) at the top-left.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===========================================================================
]]

-- CONFIG START --
clua_version = 2.056

local LEFT_MARGIN = 5
local TOP_Y = 5
local LINE_HEIGHT = 15
local TEXT_RIGHT = 320
local COMMAND = "hud"
local HUD_ENABLED = true

-- Format: {text, x1, y1, x2, y2, font, align, alpha, r, g, b}
local MESSAGES = {
    { "%s",     LEFT_MARGIN, TOP_Y,                  TEXT_RIGHT, TOP_Y + LINE_HEIGHT,         "smaller", "left", 1.0, 0.45, 0.72, 1.0 }, -- map
    { "%s",     LEFT_MARGIN, TOP_Y + LINE_HEIGHT,    TEXT_RIGHT, TOP_Y + 2 * LINE_HEIGHT,     "smaller", "left", 1.0, 0.45, 0.72, 1.0 }, -- vehicle
    { "%.1f km/h", LEFT_MARGIN, TOP_Y + 2 * LINE_HEIGHT, TEXT_RIGHT, TOP_Y + 3 * LINE_HEIGHT, "large", "left", 1.0, 0.45, 0.72, 1.0 }    -- speed
}
-- CONFIG END --

local msg_params = { { "" }, { "" }, { 0 } }

local vehicle_name_cache = {}
local last_vehicle_obj = nil
local last_vehicle_name = ""
local render_hud = false
local gametype_base = nil

local math_sqrt = math.sqrt
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

local function format_vehicle_name(raw_name)
    if vehicle_names[raw_name] then return vehicle_names[raw_name] end
    local lower = raw_name:lower()
    if vehicle_names[lower] then return vehicle_names[lower] end

    local name = gsub(raw_name, "_", " ")
    name = gsub(name, "(%a)([%a]*)", function(first, rest)
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

local function get_gametype_base()
    local addresses = { 0x6F1C88, 0x68CC48 } -- PC, CE
    for _, addr in ipairs(addresses) do
        local success, game_type = pcall(function()
            return read_byte(addr + 0x30)
        end)
        if success and game_type == 5 then
            return addr
        end
    end
    return nil
end

local function ensure_gametype_detected()
    if gametype_base ~= nil then return end
    gametype_base = get_gametype_base()
end

local function is_race()
    if not gametype_base then return false end
    return read_byte(gametype_base + 0x30) == 5
end

local function show_hud()
    ensure_gametype_detected()
    local player = get_dynamic_player()
    return (server_type == "dedicated" and is_race() and player ~= nil and HUD_ENABLED) and player or nil
end

local function get_map_name()
    return _G.map_name or _G.map or "Unknown Map"
end

function OnTick()
    local player = show_hud()
    if not player then return end

    local vehicle_name = ""
    local kmh = 0

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
        local speed_units_per_sec = math_sqrt(vx * vx + vy * vy + vz * vz) * 30
        kmh = speed_units_per_sec * 3.6
    else
        vehicle_name = "Walking"
        kmh = 0
        render_hud = false
        return
    end

    render_hud = true

    msg_params[1][1] = get_map_name()
    msg_params[2][1] = vehicle_name
    msg_params[3][1] = kmh
end

function OnPreFrame()
    if not show_hud() or not render_hud then return end
    for i = 1, #MESSAGES do
        local msg = MESSAGES[i]
        local formatted = string_format(msg[1], table_unpack(msg_params[i]))
        draw_text(formatted, msg[2], msg[3], msg[4], msg[5], msg[6], msg[7], msg[8], msg[9], msg[10], msg[11])
    end
end

function OnMapLoad()
    gametype_base = nil
    last_vehicle_obj = nil
    render_hud = false
    last_vehicle_name = ""
    vehicle_name_cache = {}
end

function OnCommand(command)
    if command:lower() == COMMAND then
        HUD_ENABLED = not HUD_ENABLED
        console_out("Race HUD " .. (HUD_ENABLED and "ENABLED" or "disabled") .. ".")
        return false
    end
end

OnMapLoad()

set_callback("map load", "OnMapLoad")
set_callback("tick", "OnTick")
set_callback("preframe", "OnPreFrame")
set_callback("command", "OnCommand")