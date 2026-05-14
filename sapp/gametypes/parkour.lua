--[[
=====================================================================================
SCRIPT NAME:      parkour.lua
DESCRIPTION:      Halo SAPP/Lua parkour plugin.
                  - Allows players to run custom parkour courses on maps.
                  - Tracks checkpoints, start/finish lines, and player progression.
                  - Supports in-order or free checkpoint completion.
                  - Records player statistics (best times, averages, completions) globally and per map.
                  - Provides commands for teleporting to checkpoints, resetting runs, and viewing leaderboards.
                  - Handles respawning at checkpoints, death limits, and course restarts.
                  - Includes optional visual aids (flags and oddball markers) for starts, finishes, and checkpoints.
                  - Fully configurable per map via the CONFIG table.

CONFIGURATION:    spawn_flags: Set to true to spawn flag poles at start/finish lines
                  spawn_checkpoint_markers: Set to true to spawn visual markers at checkpoints
                  restart_after: Number of deaths after which player is reset to start
                  respawn_time: Set the respawn timer (seconds), set nil to disable
                  running_speed: Player speed while running the course
                  start: Coordinates for start line and spawn point (x, y, z, yaw)
                  finish: Coordinates for finish line (x, y, z)
                  in_order: If true, checkpoints must be crossed in order
                  checkpoints: List of checkpoint positions and yaw (x, y, z, yaw)

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

LAST UPDATED:     2/10/2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start -----------------------------------------------------------
local CONFIG = {
    DATABASE_FILE = './parkour_results.json',
    CLAIM_RADIUS = 1.0,        -- Radius to claim a checkpoint
    SPAWN_PROTECTION_TIME = 3, -- Seconds of invulnerability after spawning
    ANTI_CAMP = true,          -- Enable checkpoint anti camping
    ANTI_CAMP_SECONDS = 6,     -- Seconds allowed to camp at a checkpoint
    ANTI_CAMP_RADIUS = 1.5,    -- Radius to consider "camping" at a checkpoint
    MSG_PREFIX = "**SAPP**",   -- Some functions temporarily change the message msg_prefix; this restores it.

    COMMANDS = {
        get_position = { { "getpos" }, 4 },
        goto_checkpoint = { { "goto" }, 4 }, -- 4 = required level
        hard_reset = { { "hardreset" }, -1 },
        soft_reset = { { "softreset" }, -1 },
        stats = { { "stats" }, -1 },
    },

    MAPS = {
        ['EV_jump'] = {
            spawn_flags = true,
            spawn_checkpoint_markers = true,
            restart_after = 10,
            respawn_time = 1,
            running_speed = 1.4,
            start = { -0.80, -9.93, .30, 0.30, -9.93, 0.30 },
            finish = { 50.19, 259.27, -18.62, 52.79, 259.27, -18.62 },
            in_order = true,
            checkpoints = {
                { 0.11,   11.76,  0.00,  2.4748 },
                { -10.31, 45.01,  0.00,  1.5598 },
                { -7.40,  63.75,  1.00,  1.5754 },
                { 10.31,  104.63, -6.62, 0.3510 },
                { 29.79,  125.52, -6.62, -0.0156 },
                { 27.85,  129.02, 0.28,  4.7079 },
                { 40.87,  129.02, 2.78,  3.1339 },
                { 27.70,  134.74, 5.23,  -0.0000 },
                { 39.51,  137.21, 2.78,  1.5210 },
                { 51.53,  198.75, 5.36,  2.1197 }
            }
        },

        ['training_jump'] = {
            spawn_flags = true,
            spawn_checkpoint_markers = true,
            restart_after = 10,
            respawn_time = 1,
            running_speed = 1.57,
            start = { -0.89, -37.80, 0.00, 0.87, -37.80, 0.00 },
            finish = { -0.71, 41.11, 0.00, 0.69, 41.08, 0.00 },
            in_order = true,
            checkpoints = {
                { -0.01, -20.90, 0.50, 1.5682 },
                { -0.01, 3.10,   0.20, 1.5682 },
                { -0.01, 25.42,  2.00, 1.5717 }
            }
        },
    }
}
-- CONFIG end --------------------------------------------------------------

api_version = '1.12.0.0'

local ANTI_CAMP_RADIUS = CONFIG.ANTI_CAMP_RADIUS * CONFIG.ANTI_CAMP_RADIUS
local CLAIM_RADIUS = CONFIG.CLAIM_RADIUS * CONFIG.CLAIM_RADIUS

local json = loadfile('json.lua')()
local math_floor, math_huge, math_abs = math.floor, math.huge, math.abs
local table_insert, table_sort = table.insert, table.sort
local string_format = string.format

local elapsed_game_time
local os_clock = os.clock
local os_start_time = os_clock()

local read_bit, read_string = read_bit, read_string
local read_dword, write_dword = read_dword, write_dword
local read_byte, read_float, read_vector3d, write_float, write_vector3d =
    read_byte, read_float, read_vector3d, write_float, write_vector3d
local get_object_memory, spawn_object = get_object_memory, spawn_object
local get_var, player_present, register_callback, say_all, rprint =
    get_var, player_present, register_callback, say_all, rprint
local get_dynamic_player, get_player, player_alive =
    get_dynamic_player, get_player, player_alive

local BASE_TAG_TABLE = 0x40440000
local TAG_ENTRY_SIZE, TAG_DATA_OFFSET, BIT_CHECK_OFFSET, BIT_INDEX = 0x20, 0x14, 0x308, 3

local map_cfg, game_over, stats_file
local stats, players, oddballs, alias_to_command = {}, {}, {}, {}

local sapp_events = {
    [cb.EVENT_TICK] = 'OnTick',
    [cb.EVENT_DIE] = 'OnDeath',
    [cb.EVENT_JOIN] = 'OnJoin',
    [cb.EVENT_LEAVE] = 'OnQuit',
    [cb.EVENT_SPAWN] = 'OnSpawn',
    [cb.EVENT_GAME_END] = 'OnEnd',
    [cb.EVENT_COMMAND] = 'OnCommand',
    [cb.EVENT_PRESPAWN] = 'OnPreSpawn',
    [cb.EVENT_DAMAGE_APPLICATION] = 'SpawnProtection'
}

local function getTime()
    return os_clock() - os_start_time
end

local function registerCallbacks(enable)
    for event, callback in pairs(sapp_events) do
        if enable then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function formatMessage(message, ...)
    return select('#', ...) > 0 and message:format(...) or message
end

local function sendPublicExclude(id, message)
    for i = 1, 16 do
        if player_present(i) and i ~= id then
            rprint(i, message)
        end
    end
end

local function sendPublic(message)
    execute_command('msg_prefix ""')
    say_all(message)
    execute_command('msg_prefix "' .. CONFIG.MSG_PREFIX .. '"')
end

local function parseArgs(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function formatTime(seconds)
    if seconds == 0 or seconds == math_huge then return "00:00.000" end
    local total_milliseconds = math_floor(seconds * 1000 + 0.5)
    local minutes = math_floor(total_milliseconds / 60000)
    local remaining_ms = total_milliseconds % 60000
    local secs = math_floor(remaining_ms / 1000)
    local ms = remaining_ms % 1000
    return string_format("%02d:%02d.%03d", minutes, secs, ms)
end

local function readJSON(file_path, default)
    local file = io.open(file_path, "r")
    if not file then return default end
    local content = file:read("*a")
    file:close()
    if content == "" then return default end
    local success, data = pcall(json.decode, json, content)
    return success and data or default
end

local function writeJSON(file_path, data)
    local file = io.open(file_path, "w")
    if not file then return false end
    file:write(json:encode(data))
    file:close()
    return true
end

local function distanceSq(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    return dx * dx + dy * dy + dz * dz
end

local function getConfigPath()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
end

local function getPlayerStats(name)
    local mapStats = stats[map_cfg.map]
    local playerStats = mapStats and mapStats.players[name]
    return playerStats
end

local function getFlagAndOddballData()
    local tag_array = read_dword(BASE_TAG_TABLE)
    local tag_count = read_dword(BASE_TAG_TABLE + 0xC)
    local flag_id, flag_name, oddball_id, oddball_name

    for i = 0, tag_count - 1 do
        local tag = tag_array + TAG_ENTRY_SIZE * i
        local tag_class = read_dword(tag)
        if tag_class == 0x77656170 then
            local tag_data = read_dword(tag + TAG_DATA_OFFSET)
            if read_bit(tag_data + BIT_CHECK_OFFSET, BIT_INDEX) == 1 then
                local item_type = read_byte(tag_data + 2)
                local meta_id = read_dword(tag + 0xC)
                local tag_name = read_string(read_dword(tag + 0x10))
                if item_type == 0 and not flag_id then
                    flag_id, flag_name = meta_id, tag_name
                elseif item_type == 4 and not oddball_id then
                    oddball_id, oddball_name = meta_id, tag_name
                end
            end
        end
    end

    return flag_id, flag_name, oddball_id, oddball_name
end

local function getPos(dyn_player)
    local crouch = read_float(dyn_player + 0x50C)
    local vehicle_id = read_dword(dyn_player + 0x11C)
    local vehicle_obj = get_object_memory(vehicle_id)

    local x, y, z
    if vehicle_id == 0xFFFFFFFF then
        x, y, z = read_vector3d(dyn_player + 0x5C)
    elseif vehicle_obj ~= 0 then
        x, y, z = read_vector3d(vehicle_obj + 0x5C)
    end

    return x, y, z + 0.65 - (0.3 * crouch)
end

local function atan2(y, x)
    return math.atan(y / x) + ((x < 0) and math.pi or 0)
end

local function setRespawnTime(player)
    local static_player = get_player(player.id)
    if static_player ~= 0 then
        write_dword(static_player + 0x2C, map_cfg.respawn_time * 33)
    end
end

local function setSpeed(id)
    execute_command("s " .. id .. " " .. map_cfg.running_speed)
end

local function spawnObject(x, y, z, meta_id)
    return spawn_object('', '', x, y, z, 0, meta_id)
end

local function validatePlayer(id)
    local dyn_player = get_dynamic_player(id)
    if player_present(id) and player_alive(id) and dyn_player ~= 0 then
        return dyn_player
    end
    return nil
end

local function hasCommandPermission(id, command_data)
    local level_required = command_data.level
    local player_level = tonumber(get_var(id, "$lvl"))
    if player_level >= level_required then return true end
    rprint(id, "You do not have permission to use this command")
    return false
end

local function getPosition(id)
    local dyn = get_dynamic_player(id)
    if not player_alive(id) or dyn == 0 then
        rprint(id, "You must be alive to use this command.")
        return
    end

    local x, y, z = read_vector3d(dyn + 0x5C)
    local cam_x = read_float(dyn + 0x230)
    local cam_y = read_float(dyn + 0x234)
    local yaw = atan2(cam_y, cam_x)

    local out = string.format("Position: %.2f, %.2f, %.2f, %.4f", x, y, z, yaw)
    rprint(id, out); cprint(out)
end

local function resetAntiCamp(player)
    player.camp_start = nil
    player.camp_warned = nil
    player.camp_checkpoint = nil
end

local function hardReset(player, finished)
    player.started = false
    player.finished = false
    player.start_time = 0
    player.completion_time = 0
    player.checkpoint_index = 0
    player.current_checkpoint = nil
    player.deaths = 0
    player.prev_pos = nil
    resetAntiCamp(player)
    if not finished then
        execute_command('kill ' .. player.id)
        rprint(player.id, "Your course progress has been reset to the start line.")
    end
end

local function teleportPlayer(id, x, y, z, r)
    local dyn_player = get_dynamic_player(id)
    if dyn_player == 0 then return end

    write_vector3d(dyn_player + 0x5C, x, y, z)
    write_vector3d(dyn_player + 0x74, math.cos(r), math.sin(r), 0)
end

local function precomputeLineData()
    map_cfg.start_line = {
        A = { map_cfg.start[1], map_cfg.start[2], map_cfg.start[3] },
        B = { map_cfg.start[4], map_cfg.start[5], map_cfg.start[6] },
        dx = map_cfg.start[4] - map_cfg.start[1],
        dy = map_cfg.start[5] - map_cfg.start[2],
        dz = map_cfg.start[6] - map_cfg.start[3],
        length_sq = (map_cfg.start[4] - map_cfg.start[1]) ^ 2 +
            (map_cfg.start[5] - map_cfg.start[2]) ^ 2 +
            (map_cfg.start[6] - map_cfg.start[3]) ^ 2
    }

    map_cfg.finish_line = {
        A = { map_cfg.finish[1], map_cfg.finish[2], map_cfg.finish[3] },
        B = { map_cfg.finish[4], map_cfg.finish[5], map_cfg.finish[6] },
        dx = map_cfg.finish[4] - map_cfg.finish[1],
        dy = map_cfg.finish[5] - map_cfg.finish[2],
        dz = map_cfg.finish[6] - map_cfg.finish[3],
        length_sq = (map_cfg.finish[4] - map_cfg.finish[1]) ^ 2 +
            (map_cfg.finish[5] - map_cfg.finish[2]) ^ 2 +
            (map_cfg.finish[6] - map_cfg.finish[3]) ^ 2
    }
end

local function precomputeCheckpointData()
    map_cfg.checkpoint_precomputed = {}
    for i, checkpoint in ipairs(map_cfg.checkpoints) do
        map_cfg.checkpoint_precomputed[i] = {
            x = checkpoint[1],
            y = checkpoint[2],
            z = checkpoint[3],
            yaw = checkpoint[4]
        }
    end
end

-- Check if player crossed the line segment from lineA to lineB between previous and current positions
local function isCrossingLine(px, py, pz, line_type, prevPos)
    if not prevPos then return false end

    local line = (line_type == "start") and map_cfg.start_line or map_cfg.finish_line
    local Ax, Ay, Az = unpack(line.A)

    -- Use precomputed values
    local Lx, Ly, Lz = line.dx, line.dy, line.dz

    -- Calculate vector from line point A to current and previous positions (XY only)
    local Vx, Vy = px - Ax, py - Ay
    local Px, Py = prevPos[1] - Ax, prevPos[2] - Ay

    -- Calculate Z component of cross products
    local crossCurrentZ = Lx * Vy - Ly * Vx
    local crossPreviousZ = Lx * Py - Ly * Px

    -- Check if the signs of the Z components are different
    if crossCurrentZ * crossPreviousZ < 0 then
        -- Additional check to ensure the crossing is within the line segment
        -- Use precomputed length_sq
        local t = ((px - Ax) * Lx + (py - Ay) * Ly + (pz - Az) * Lz) / line.length_sq
        return t >= 0 and t <= 1
    end

    return false
end

local function updateStats(player, completionTime)
    local map = map_cfg.map
    local name = player.name

    -- Initialize map entry if needed
    if not stats[map] then
        stats[map] = {
            best_time = { time = math_huge, player = "" },
            players = {}
        }
    end

    -- Initialize player entry if needed
    if not stats[map].players[name] then
        stats[map].players[name] = {
            best_time_seconds = math_huge,
            completions = 0,
            avg_time_seconds = 0
        }
    end

    local player_stats = stats[map].players[name]
    local map_stats = stats[map]

    -- Update personal best
    if completionTime < player_stats.best_time_seconds then
        player_stats.best_time_seconds = completionTime
        sendPublic(formatMessage("New personal best for %s: %s", name, formatTime(completionTime)))
    end

    -- Update map record
    if completionTime < map_stats.best_time.time then
        map_stats.best_time = { time = completionTime, player = name }
        sendPublic(formatMessage("New map record by %s: %s!", name, formatTime(completionTime)))
    end

    -- Update averages
    local total_time = player_stats.avg_time_seconds * player_stats.completions + completionTime
    player_stats.completions = player_stats.completions + 1
    player_stats.avg_time_seconds = total_time / player_stats.completions

    -- Update player's session stats
    player.best_time = player_stats.best_time_seconds
    player.completions = player_stats.completions
end

local function saveStats()
    writeJSON(stats_file, stats)
end

local function loadStats()
    stats = readJSON(stats_file, {})
end

local function showStats(player)
    local map = map_cfg.map
    local send = player and function(msg) rprint(player.id, msg) end or sendPublic

    if not stats[map] then
        send("No records for this map yet.")
        return false
    end

    -- Build ranking table
    local ranking = {}
    for name, data in pairs(stats[map].players) do
        table_insert(ranking, { name = name, best_time = data.best_time_seconds, completions = data.completions })
    end

    -- Sort by best time (ascending)
    table_sort(ranking, function(a, b) return a.best_time < b.best_time end)

    -- Header
    send("Top 5 players for " .. map)

    if #ranking == 0 then
        send("No completions recorded yet.")
        return
    end

    local top5 = {}
    for i = 1, math.min(5, #ranking) do
        local p = ranking[i]
        table_insert(top5, p)
        send(string_format("%d. %s - %s (%d completions)", i, p.name, formatTime(p.best_time), p.completions))
    end

    -- Show personal best if player is not in top 5
    if player and player.best_time and player.best_time ~= math_huge then
        local inTop5 = false
        for _, p in ipairs(top5) do
            if p.name == player.name then
                inTop5 = true
                break
            end
        end

        if not inTop5 then
            send("Your Fastest Time: " .. formatTime(player.best_time))
        end
    end
end

function OnScriptLoad()
    for command_name, data in pairs(CONFIG.COMMANDS) do
        for _, alias in ipairs(data[1]) do
            alias_to_command[alias] = { command = command_name, level = data[2] }
        end
    end

    register_callback(cb.EVENT_GAME_START, 'OnStart')

    local config_path = getConfigPath()
    stats_file = config_path .. "\\sapp\\" .. CONFIG.DATABASE_FILE

    loadStats()
    OnStart() -- in case the script is loaded mid-game
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    local map = get_var(0, '$map')
    local cfg = CONFIG.MAPS[map]
    if not cfg then
        registerCallbacks(false)
        return
    end

    local flag_id, flag_name, oddball_id, oddball_name = getFlagAndOddballData()
    if cfg.spawn_flags and flag_id then
        execute_command("disable_object '" .. flag_name .. "'")
        spawnObject(cfg.start[1], cfg.start[2], cfg.start[3], flag_id)
        spawnObject(cfg.start[4], cfg.start[5], cfg.start[6], flag_id)
        spawnObject(cfg.finish[1], cfg.finish[2], cfg.finish[3], flag_id)
        spawnObject(cfg.finish[4], cfg.finish[5], cfg.finish[6], flag_id)
    end

    if cfg.spawn_checkpoint_markers and oddball_id then
        for _, checkpoint in ipairs(cfg.checkpoints) do
            local x, y, z = checkpoint[1], checkpoint[2], checkpoint[3]
            local oddball = spawnObject(x, y, z, oddball_id)
            oddballs[oddball] = { x = x, y = y, z = z }
        end
        execute_command("disable_object '" .. oddball_name .. "'")
    end

    os_start_time = os_clock() -- just in case (keep timing consistent)
    map_cfg = cfg
    map_cfg.map = map
    game_over = false

    precomputeLineData()
    precomputeCheckpointData()

    -- Initialize map stats if needed
    if not stats[map] then
        stats[map] = {
            best_time = { time = math_huge, player = "" },
            players = {}
        }
    end

    players = {}
    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end

    registerCallbacks(true)
    execute_command('msg_prefix ""')

    timer(1000, "AnchorCheckpoints")
end

function OnEnd()
    game_over = true
    saveStats()
    showStats()
end

function OnJoin(id)
    local name = get_var(id, '$name')
    local playerStats = getPlayerStats(name)

    players[id] = {
        id = id,
        name = name,
        started = false,
        finished = false,
        start_time = 0,
        completion_time = 0,
        deaths = 0,
        checkpoint_index = 0,
        best_time = playerStats and playerStats.best_time_seconds or math_huge,
        completions = playerStats and playerStats.completions or 0
    }
end

function OnQuit(id)
    players[id] = nil
end

function OnPreSpawn(id)
    if game_over then return end

    local player = players[id]
    local cp = player and player.current_checkpoint
    if cp then
        teleportPlayer(id, cp[1], cp[2], cp[3], cp[4])
    end
end

function OnSpawn(id)
    local player = players[id]
    if not player then return end

    players[id].protected = player.started and elapsed_game_time + CONFIG.SPAWN_PROTECTION_TIME or nil
    setSpeed(id)
end

function OnDeath(id)
    if game_over then return end

    local player = players[id]
    if not player or not player.started then return end

    player.deaths = player.deaths + 1

    -- Restart course if too many deaths
    if player.deaths >= map_cfg.restart_after then
        hardReset(player)
    else
        rprint(id, "You have " .. (map_cfg.restart_after - player.deaths) .. " more deaths before restarting.")
    end

    setRespawnTime(player)
end

function AnchorCheckpoints()
    if not map_cfg.spawn_checkpoint_markers or game_over then return false end

    for object_id, pos in pairs(oddballs) do
        local object = get_object_memory(object_id)
        if object == 0 then goto continue end

        -- Only update if the object has moved significantly
        local x = read_float(object + 0x5C)
        local y = read_float(object + 0x60)
        local z = read_float(object + 0x64)

        -- Check if position has changed beyond a small threshold
        if math_abs(x - pos.x) > 0.01 or
            math_abs(y - pos.y) > 0.01 or
            math_abs(z - pos.z) > 0.01 then
            write_vector3d(object + 0x5C, pos.x, pos.y, pos.z)
            write_float(object + 0x68, 0) -- x velocity
            write_float(object + 0x6C, 0) -- y velocity
            write_float(object + 0x70, 0) -- z velocity
            write_float(object + 0x90, 0) -- yaw
            write_float(object + 0x8C, 0) -- pitch
            write_float(object + 0x94, 0) -- roll
        end

        ::continue::
    end
    return true
end

function OnTick()
    if game_over then return end

    elapsed_game_time = getTime()

    for id, player in pairs(players) do
        local dyn_player = validatePlayer(id)
        if not dyn_player then goto continue end

        local x, y, z = getPos(dyn_player)
        if not x then goto continue end

        if player.started and player.protected ~= nil and elapsed_game_time >= player.protected then
            player.protected = nil
        end

        -- Store previous position for line crossing detection
        local prev_pos = player.prev_pos
        player.prev_pos = { x, y, z }

        -- Skip if we don't have a previous position
        if not prev_pos then goto continue end

        local cur_index = player.checkpoint_index
        local max = #map_cfg.checkpoints

        -- Check if player is crossing the start line
        if not player.started and not player.finished and isCrossingLine(x, y, z, "start", prev_pos) then
            player.started = true
            player.finished = false
            player.start_time = elapsed_game_time
            player.checkpoint_index = 0
            player.deaths = 0
            rprint(id, "Course started! Good luck!")

            goto continue
        end

        -- Check if player is crossing the finish line
        if player.started and not player.finished and isCrossingLine(x, y, z, "finish", prev_pos) then
            -- Make sure all checkpoints were passed
            if cur_index >= max then
                player.finished = true
                player.completion_time = elapsed_game_time - player.start_time

                -- Update stats
                updateStats(player, player.completion_time)

                rprint(id, "Course completed in " .. formatTime(player.completion_time) .. "!")
                hardReset(player, true)
            else
                rprint(id, "You missed some checkpoints! (" .. cur_index .. "/" .. max .. ")")
            end

            goto continue
        end

        -- Check if player is near a checkpoint and handle camping + claims
        if player.started and not player.finished then
            if CONFIG.ANTI_CAMP then
                -- First: anti-camping check across ALL checkpoints
                local near_index = nil
                for i, checkpoint in ipairs(map_cfg.checkpoint_precomputed) do
                    if distanceSq(x, y, z, checkpoint.x, checkpoint.y, checkpoint.z) <= ANTI_CAMP_RADIUS then
                        near_index = i
                        break
                    end
                end

                if near_index then
                    -- standing on some checkpoint (any checkpoint)
                    if player.camp_checkpoint == near_index and player.camp_start then
                        local elapsed = elapsed_game_time - player.camp_start
                        if elapsed >= CONFIG.ANTI_CAMP_SECONDS then
                            hardReset(player)
                            goto continue
                        elseif elapsed >= CONFIG.ANTI_CAMP_SECONDS / 2 and not player.camp_warned then
                            rprint(id, "Move away soon or you'll be reset!")
                            player.camp_warned = true
                        end
                    else
                        -- start fresh timer for this checkpoint
                        player.camp_checkpoint = near_index
                        player.camp_start = elapsed_game_time
                        player.camp_warned = nil -- reset warning for new camp
                    end
                else
                    -- not near any checkpoint, clear camp info
                    resetAntiCamp(player)
                end
            end

            -- Second: try to claim only eligible checkpoints
            for i, checkpoint in ipairs(map_cfg.checkpoint_precomputed) do
                local can_claim = false
                if map_cfg.in_order then
                    can_claim = (i == cur_index + 1)
                else
                    can_claim = (i > cur_index)
                end

                if can_claim and distanceSq(x, y, z, checkpoint.x, checkpoint.y, checkpoint.z) <= CLAIM_RADIUS then
                    player.checkpoint_index = i
                    local elapsed = elapsed_game_time - player.start_time
                    rprint(id, string_format("Checkpoint %d/%d reached! Total time: %s", i, max, formatTime(elapsed)))

                    -- Update respawn position for pre-spawn teleport
                    player.current_checkpoint = { checkpoint.x, checkpoint.y, checkpoint.z, checkpoint.yaw }
                    setSpeed(id)

                    -- reset any camp tracking when legitimately claiming a checkpoint
                    resetAntiCamp(player)

                    break
                end
            end
        end

        ::continue::
    end
end

function OnCommand(id, command)
    if id == 0 then return true end

    local args = parseArgs(command)
    if #args == 0 then return false end

    local command_data = alias_to_command[args[1]]
    if not command_data then return true end -- allow all other commands
    if not hasCommandPermission(id, command_data) then return false end

    local cmd = command_data.command
    local player = players[id]
    if not player then return true end

    if cmd == "get_position" then
        getPosition(id)
    elseif cmd == "goto_checkpoint" then
        if not args[2] then
            rprint(id, "Usage: /goto <checkpoint_index>")
            return false
        end

        local index = tonumber(args[2])
        if not index or index < 1 or index > #map_cfg.checkpoint_precomputed then
            rprint(id, "Invalid checkpoint index. Must be between 1 and " .. #map_cfg.checkpoint_precomputed)
            return false
        end

        local checkpoint = map_cfg.checkpoint_precomputed[index]
        teleportPlayer(id, checkpoint.x, checkpoint.y, checkpoint.z, checkpoint.yaw)

        player.checkpoint_index = index
        player.current_checkpoint = { checkpoint.x, checkpoint.y, checkpoint.z, checkpoint.yaw }
        resetAntiCamp(player)
        setSpeed(id)

        rprint(id, string.format("Teleported to checkpoint %d/%d.", index, #map_cfg.checkpoint_precomputed))
    elseif cmd == "hard_reset" then -- start over
        hardReset(player)
        sendPublicExclude(id, player.name .. " performed a hard-reset")
    elseif cmd == "soft_reset" then -- reset to checkpoint
        if not player_alive(id) then
            rprint(id, "You must be alive to use this command.")
            return false
        end
        local cp = player.current_checkpoint
        if cp then
            teleportPlayer(id, cp[1], cp[2], cp[3], cp[4])
            setSpeed(id)
            rprint(id, "You have been reset to your last checkpoint.")
            sendPublicExclude(id, player.name .. " performed a soft-reset")
        else
            rprint(id, "No checkpoint reached yet. Use hardreset to start over.")
        end
    elseif cmd == "stats" then -- shows top 5 players for this map only
        showStats(player)
    end

    return false
end

function SpawnProtection(victimId, causerId)
    local player = players[tonumber(victimId)]
    if player and player.protected ~= nil and player.started and player_alive(causerId) then
        return false
    end
end

function OnScriptUnload()
    saveStats()
end
