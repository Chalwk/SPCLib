--[[
=====================================================================================
SCRIPT NAME:      capture_the_flag.lua
DESCRIPTION:      Adds full CTF gameplay to any Slayer (FFA/Team) game mode by
                  spawning a single neutral flag that players must capture and
                  return to designated team bases.

FEATURES:
                  - Works with both FFA and Team Slayer modes
                  - Single neutral flag gameplay (not team-specific flags)
                  - Configurable flag spawn and capture points per map
                  - Customizable scoring system with point bonuses
                  - Automatic flag respawning with warnings
                  - Team-specific messaging and announcements
                  - Efficient object memory management
                  - Weapon tag verification for flag detection

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start -----------------------------------------------------------

local CONFIG = {
    MSG_PREFIX = "**CTF** ",
    RESPAWN_DELAY = 15,   -- Time (in seconds) until the flag respawns after being dropped or moved.
    RESPAWN_WARNING = "The flag was dropped and will respawn in %s second%s",
    CAPTURE_RADIUS = 0.5, -- Radius (in meters) for the trigger area.
    CAPTURE_POINTS = 5,   -- Points received for capturing a flag.
    CAPTURE_MESAGE = "%s captured a flag!",
    PICKUP_MESSAGES = {
        "[%s team] %s has the flag!",               -- Team message
        "%s picked up the flag!",                   -- Global message
        "Return the flag to ANY base for %s points" -- Message to the flag carrier
    },

    -- ========== map settings ========== --
    -- format:
    -- [map_name] = {spawn_point = {x, y, z}, blue_capture = {x, y, z}, red_capture = {x, y, z}}}

    ["bloodgulch"] = {
        spawn_point  = { 65.749, -120.409, 0.118 },
        blue_capture = { 95.687, -159.449, -0.100 },
        red_capture  = { 40.240, -79.123, -0.100 }
    },
    ["deathisland"] = {
        spawn_point  = { -30.282, 31.312, 16.601 },
        blue_capture = { -26.576, -6.976, 9.663 },
        red_capture  = { 29.843, 15.971, 8.295 }
    },
    ["icefields"] = {
        spawn_point  = { -26.032, 32.365, 9.007 },
        blue_capture = { 24.850, -22.110, 2.111 },
        red_capture  = { -77.860, 86.550, 2.111 }
    },
    ["infinity"] = {
        spawn_point  = { 9.631, -64.030, 7.776 },
        blue_capture = { 0.680, -164.567, 15.039 },
        red_capture  = { -1.858, 47.780, 11.791 }
    },
    ["sidewinder"] = {
        spawn_point  = { 2.051, 55.220, -2.801 },
        blue_capture = { -32.038, -42.067, -3.700 },
        red_capture  = { 30.351, -46.108, -3.700 }
    },
    ["timberland"] = {
        spawn_point  = { 1.250, -1.487, -21.264 },
        blue_capture = { 17.322, -52.365, -17.751 },
        red_capture  = { -16.330, 52.360, -17.741 }
    },
    ["dangercanyon"] = {
        spawn_point  = { -0.477, 55.331, 0.239 },
        blue_capture = { -12.105, -3.435, -2.242 },
        red_capture  = { 12.007, -3.451, -2.242 }
    },
    ["beavercreek"] = {
        spawn_point  = { 14.015, 14.238, -0.911 },
        blue_capture = { 29.056, 13.732, -0.100 },
        red_capture  = { -0.860, 13.765, -0.010 }
    },
    ["boardingaction"] = {
        spawn_point  = { 4.374, -12.832, 7.220 },
        blue_capture = { 1.723, 0.478, 0.600 },
        red_capture  = { 18.204, -0.537, 0.600 }
    },
    ["carousel"] = {
        spawn_point  = { 0.033, 0.003, -0.856 },
        blue_capture = { 5.606, -13.548, -3.200 },
        red_capture  = { -5.750, 13.887, -3.200 }
    },
    ["chillout"] = {
        spawn_point  = { 1.392, 4.700, 3.108 },
        blue_capture = { 7.488, -4.491, 2.500 },
        red_capture  = { -7.509, 9.750, 0.100 }
    },
    ["damnation"] = {
        spawn_point  = { -2.002, -4.301, 3.399 },
        blue_capture = { 9.693, -13.340, 6.800 },
        red_capture  = { -12.179, 14.983, -0.200 }
    },
    ["gephyrophobia"] = {
        spawn_point  = { 63.513, -74.088, -1.062 },
        blue_capture = { 26.884, -144.716, -16.049 },
        red_capture  = { 26.728, 0.166, -16.048 }
    },
    ["hangemhigh"] = {
        spawn_point  = { 21.020, -4.632, -4.229 },
        blue_capture = { 13.048, 9.033, -3.362 },
        red_capture  = { 32.656, -16.497, -1.700 }
    },
    ["longest"] = {
        spawn_point  = { -0.840, -14.540, 2.410 },
        blue_capture = { -12.792, -21.642, -0.400 },
        red_capture  = { 11.035, -7.588, -0.400 }
    },
    ["prisoner"] = {
        spawn_point  = { 0.902, 0.088, 1.392 },
        blue_capture = { -9.368, -4.948, 5.700 },
        red_capture  = { 9.368, 5.119, 5.700 }
    },
    ["putput"] = {
        spawn_point  = { -2.350, -21.121, 0.902 },
        blue_capture = { -18.890, -20.186, 1.100 },
        red_capture  = { 34.865, -28.195, 0.100 }
    },
    ["ratrace"] = {
        spawn_point  = { 8.662, -11.159, 0.221 },
        blue_capture = { -4.228, -0.856, -0.400 },
        red_capture  = { 18.613, -22.653, -3.400 }
    },
    ["wizard"] = {
        spawn_point  = { -5.035, -5.064, -2.750 },
        blue_capture = { -9.246, 9.334, -2.600 },
        red_capture  = { 9.183, -9.181, -2.600 }
    }
}

-- Config End -------------------------------------------------------------

api_version = '1.12.0.0'

local sapp_events = {
    [cb['EVENT_DIE']] = 'OnDie',
    [cb['EVENT_TICK']] = 'OnTick',
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_TEAM_SWITCH']] = 'OnTeamSwitch',
}

local flag, players = {}, {}
local map_config, team_play

-- Tag table addresses for weapon checking
local base_tag_table = 0x40440000
local tag_entry_size = 0x20
local tag_data_offset = 0x14
local bit_check_offset = 0x308
local bit_index = 3

local get_var = get_var
local say_all, rprint = say_all, rprint
local execute_command = execute_command
local os_time, tonumber = os.time, tonumber
local destroy_object, spawn_object = destroy_object, spawn_object
local player_present, player_alive = player_alive, player_present
local get_dynamic_player, get_object_memory = get_dynamic_player, get_object_memory

local read_bit = read_bit
local read_word = read_word
local read_float = read_float
local read_dword = read_dword
local read_vector3d = read_vector3d

-- Respawn timer helper
local function newRespawnTimer(now)
    return { start = now, finish = now + CONFIG.RESPAWN_DELAY, warned = false }
end

-- Spawn flag
local function spawnFlag()
    local spawn_point = map_config.spawn_point
    local x, y, z = spawn_point[1], spawn_point[2], spawn_point[3] + 0.1

    if flag.object then destroy_object(flag.object) end

    local object = spawn_object('', '', x, y, z, 0, flag.tag_id)
    local object_memory = get_object_memory(object)

    if object_memory == 0 then
        error("Failed to spawn flag")
        return false
    end

    flag.object = object
    flag.object_memory = object_memory
    flag.state = "at_spawn_point"
    flag.carrier = nil
end

-- Distance check
local function inRange(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return (dx * dx + dy * dy + dz * dz) <= (CONFIG.CAPTURE_RADIUS ^ 2)
end

-- Get player position
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
    return x, y, z + z_off
end

-- Check if player has the flag
local function hasObjective(dyn_player)
    for i = 0, 3 do
        local weapon_id = read_dword(dyn_player + 0x2F8 + 0x4 * i)
        local weapon_obj = get_object_memory(weapon_id)
        if weapon_obj ~= 0 and weapon_obj ~= 0xFFFFFFFF then
            local tag_address = read_word(weapon_obj)
            local tag_data_base = read_dword(base_tag_table)
            local tag_data = read_dword(tag_data_base + tag_address * tag_entry_size + tag_data_offset)
            if read_bit(tag_data + bit_check_offset, bit_index) == 1 then return true end
        end
    end
    return false
end

-- Find flag tag
local function findFlagTagAddress()
    local tag_address = read_dword(0x40440000)
    local tag_count = read_dword(0x4044000C)
    for i = 0, tag_count - 1 do
        local tag = tag_address + 0x20 * i
        if read_dword(tag) == 0x6D617467 then
            local globals_tag = read_dword(tag + 0x14)
            return read_dword(read_dword(globals_tag + 0x164 + 4) + 0xC)
        end
    end
    return nil
end

-- Get team name
local function getTeamName(player)
    return not team_play and "" or (player.team == "red" and "Red" or "Blue")
end

-- Update score
local function updateScore(player)
    if team_play then
        local team_score_var = player.team == "red" and "$redscore" or "$bluescore"
        local current_score = tonumber(get_var(0, team_score_var))
        local new_score = current_score + CONFIG.CAPTURE_POINTS
        execute_command("team_score " .. (player.team == "red" and 0 or 1) .. " " .. new_score)
    else
        local current_score = tonumber(get_var(player.id, "$score"))
        local new_score = current_score + CONFIG.CAPTURE_POINTS
        execute_command("score " .. player.id .. " " .. new_score)
    end
end

-- Register/unregister event callbacks
local function registerCallbacks(enable)
    for event, callback in pairs(sapp_events) do
        if enable then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

-- Get map config
local function getConfig(game_type)
    if game_type ~= "slayer" then
        cprint("[Capture The Flag]: Only FFA is supported", 10)
        return nil
    end
    local current_map = get_var(0, "$map")
    if not CONFIG[current_map] then
        cprint("[Capture The Flag]: " .. current_map .. " not configured", 10)
        return nil
    end
    return CONFIG[current_map]
end

-- Check if flag needs reset
local function checkForFlagReset(playerId)
    if flag.carrier == playerId then
        flag.state = "dropped"
        flag.carrier = nil
        flag.respawn_timer = newRespawnTimer(os_time())
    end
end

-- Validate player
local function validatePlayer(playerId)
    return player_present(playerId) and player_alive(playerId) and players[playerId]
end

-- Formats a string with optional arguments:
local function formatMessage(message, ...)
    if select('#', ...) > 0 then
        return message:format(...)
    end
    return message
end

-- Send global message or private message
local function sendMessage(target, message, ...)
    local text = formatMessage(message, ...)

    if target == 0 then
        execute_command('msg_prefix ""')
        say_all(text)
        execute_command('msg_prefix "' .. CONFIG.MSG_PREFIX .. '"')
    else
        rprint(target, text)
    end
end

-- SAPP EVENTS ----------------------------
function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    local game_type = get_var(0, "$gt")
    if game_type == "n/a" then return end

    map_config = getConfig(game_type)
    registerCallbacks(false)

    if not map_config then return end

    team_play = get_var(0, "$ffa") == "0"

    for i = 1, 16 do if player_present(i) then OnJoin(i) end end

    flag.tag_id = findFlagTagAddress()
    spawnFlag()
    registerCallbacks(true)
end

function OnJoin(playerId)
    players[playerId] = {
        id = playerId,
        name = get_var(playerId, "$name"),
        team = get_var(playerId, "$team"),
    }
end

function OnQuit(playerId)
    checkForFlagReset(playerId)
    players[playerId] = nil
end

function OnDie(playerId)
    checkForFlagReset(playerId)
end

function OnTeamSwitch(playerId)
    players[playerId].team = get_var(playerId, "$team")
end

function OnTick()
    local now = os_time()

    -- Handle flag respawn timer
    if flag.state == "dropped" then
        local remaining = flag.respawn_timer.finish - now
        local halfway = CONFIG.RESPAWN_DELAY / 2

        if not flag.respawn_timer.warned and remaining <= halfway then
            flag.respawn_timer.warned = true
            local sec = math.floor(remaining + 0.5)
            sendMessage(0, CONFIG.RESPAWN_WARNING, sec, (sec == 1 and "" or "s"))
        end

        if now >= flag.respawn_timer.finish then
            spawnFlag()
            sendMessage(0, "The flag has respawned!")
        end
    end

    for i = 1, 16 do
        local player = validatePlayer(i)
        if not player then goto continue end
        local dyn_player = get_dynamic_player(i)
        if dyn_player == 0 then goto continue end

        -- Check flag pickup
        if hasObjective(dyn_player) then
            if flag.state ~= "carried" then
                flag.state = "carried"
                flag.carrier = i

                if team_play then
                    sendMessage(0, CONFIG.PICKUP_MESSAGES[1], getTeamName(player), player.name)
                else
                    sendMessage(0, CONFIG.PICKUP_MESSAGES[2], player.name)
                end
                sendMessage(player.id, CONFIG.PICKUP_MESSAGES[3], CONFIG.CAPTURE_POINTS)
            end
        elseif flag.carrier == i then
            checkForFlagReset(i)
        end

        -- Check capture points
        if flag.carrier == i then
            local px, py, pz = getPlayerPosition(dyn_player)
            if not px then goto continue end

            local blue_cap = map_config.blue_capture
            local red_cap = map_config.red_capture

            if inRange(px, py, pz, blue_cap[1], blue_cap[2], blue_cap[3]) or
                inRange(px, py, pz, red_cap[1], red_cap[2], red_cap[3]) then
                sendMessage(0, CONFIG.CAPTURE_MESAGE, player.name)
                updateScore(player)
                spawnFlag()
            end
        end

        ::continue::
    end
end

function OnScriptUnload() end
