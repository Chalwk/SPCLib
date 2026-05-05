--[[
===============================================================================
SCRIPT NAME:      kill_zones.lua
DESCRIPTION:      Configurable danger zone system that:
                  - Kills players who stay too long in restricted areas
                  - Provides warnings before killing
                  - Supports team-specific zones

FEATURES:
                  - Map-specific zone configurations
                  - Adjustable warning timers
                  - Custom death messages
                  - Team/FFA mode support

CONFIGURATION:    Edit the CONFIG table to:
                  - Add zones per map (coordinates + radius)
                  - Set warning/kill timers
                  - Customize messages
                  - Define team-specific zones

Copyright (c) 2024 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config Starts ----------------------------------------
local CONFIG = {
    -- MESSAGES:
    WARNING_MESSAGE = "Warning: Forbidden zone [%]!",
    KILL_MESSAGE = "%s was killed (in forbidden zone: %s)",
    PREFIX = "**SAPP**",

    -- KILL ZONE SETTINGS:
    -- team                 = Player Team: 'red', 'blue', 'FFA'
    -- x, y, z, radius      = Zone coordinates.
    -- seconds until death  = A player has this many seconds to leave a kill zone or they are killed.
    ['bloodgulch'] = {
        { 'FFA', 82.68, -114.61, 0.67, 5, 15, "Base Camp" },
        -- Add more zones for bloodgulch or other maps.
    },
    -- Add more maps and zones as needed.
}
-- Config Ends ----------------------------------------

api_version = '1.12.0.0'

local ffa
local zones = {}
local players = {}

-- Localized for performance
local ipairs = ipairs
local string_format = string.format
local os_time = os.time
local math_abs, math_floor = math.abs, math.floor

local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local get_dynamic_player = get_dynamic_player
local get_object_memory = get_object_memory
local read_float = read_float
local read_dword = read_dword
local read_vector3d = read_vector3d
local execute_command = execute_command

local function loadZones()
    local map = get_var(0, '$map')
    zones = CONFIG[map]
    return zones and #zones > 0 or nil
end

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], "OnStart")
end

function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        players = {}
        ffa = (get_var(0, '$ffa') == '1')

        if loadZones() then
            register_callback(cb['EVENT_TICK'], "OnTick")
            register_callback(cb['EVENT_JOIN'], "OnJoin")
            register_callback(cb['EVENT_LEAVE'], "OnQuit")
            register_callback(cb['EVENT_TEAM_SWITCH'], "OnTeamSwitch")
        else
            unregister_callback(cb['EVENT_TICK'])
            unregister_callback(cb['EVENT_JOIN'])
            unregister_callback(cb['EVENT_LEAVE'])
            unregister_callback(cb['EVENT_TEAM_SWITCH'])
        end
    end
end

function OnJoin(id)
    players[id] = {
        id = id,
        name = get_var(id, '$name'),
        team = ffa and 'FFA' or get_var(id, '$team')
    }
end

function OnQuit(id)
    players[id] = nil
end

function OnTeamSwitch(id)
    local player = players[id]
    player.team = get_var(id, '$team')
end

local function killPlayer(player, zoneName)
    execute_command("kill " .. player.id)
    local message = string_format(CONFIG.KILL_MESSAGE, player.name, zoneName)
    execute_command('msg_prefix ""')
    say_all(message)
    execute_command('msg_prefix "' .. CONFIG.PREFIX .. '"')
end

local function warn(player, remaining)
    local message = string_format(CONFIG.WARNING_MESSAGE, remaining)

    for _ = 1, 25 do rprint(player.id, " ") end

    rprint(player.id, message)
end

local function startTimer(player, killDelay, now)
    if not player.timer then
        player.timer = {
            start = now,
            remaining = killDelay,
        }
    end
end

local function updateTimer(player, zoneName, now)
    if player.timer then
        local elapsed = now - player.timer.start
        if elapsed < player.timer.remaining then
            warn(player, math_floor(player.timer.remaining - elapsed))
        else
            player.timer = nil
            killPlayer(player, zoneName)
        end
    end
end

local function getPlayerPosition(dyn_player)
    local crouch = read_float(dyn_player + 0x50C)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn_player + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    else
        return nil, nil, nil
    end

    local z_off = (crouch == 0) and 0.65 or 0.35 * crouch

    return {
        x = x,
        y = y,
        z = z + z_off,
    }
end

local function isPlayerOutsideZone(pos, zone)
    local max_distance = zone.radius
    local dx = math_abs(pos.x - zone.x)
    local dy = math_abs(pos.y - zone.y)
    local dz = math_abs(pos.z - zone.z)
    return dx > max_distance or dy > max_distance or dz > max_distance
end

local function checkPlayerZoneAndTimer(player, now)
    local dyn = get_dynamic_player(player.id)
    if dyn == 0 then return end

    local player_position = getPlayerPosition(dyn)
    if not player_position then return end

    for _, zone in ipairs(zones) do
        local zone_position = { x = zone[2], y = zone[3], z = zone[4], radius = zone[5] }
        if not isPlayerOutsideZone(player_position, zone_position) then
            startTimer(player, zone[6], now)
            break
        elseif player.timer then
            player.timer = nil
            break
        end
    end
end

function OnTick()
    local now = os_time()
    for i = 1, 16 do
        local player = players[i]
        if player and player_present(i) and player_alive(i) then
            checkPlayerZoneAndTimer(player, now)
            updateTimer(player, zones[1][7], now)
        end
    end
end

function OnScriptUnload() end
