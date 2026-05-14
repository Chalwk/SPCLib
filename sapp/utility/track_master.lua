--[[
===============================================================================
SCRIPT NAME:      track_master.lua
DESCRIPTION:      Advanced racing tracker and leaderboard system for Halo SAPP.

FEATURES:         - Tracks player lap times with checkpoint validation
                  - Supports both sequential and non-sequential race modes
                  - Records personal bests per player and all-time map records
                  - Maintains detailed per-map player statistics:
                      * laps completed
                      * best lap time
                      * average lap time
                  - Real-time checkpoint tracking with optional time display
                  - Calculates global rankings across all maps using weighted scoring:
                      * MAP_RECORD_WEIGHT: points for holding map records
                      * GLOBAL_RECORD_WEIGHT: bonus for overall best lap
                      * PERFORMANCE_WEIGHT: points based on lap time vs record
                      * TOP_FINISH_THRESHOLD: counts near-record laps
                      * Participation adjustment for players with few maps
                  - In-game announcements:
                      * New personal bests
                      * New map records
                      * Checkpoint completion times
                  - Player commands:
                      * /stats [player|all] - Personal/player stats for current map
                      * /top [page] - Paginated top laps for current map
                      * /global [page] - Paginated top overall players (all maps)
                      * /reset - Reset personal checkpoint progress
                  - Automatic data persistence with JSON export
                  - Optional text file export of lap records
                  - Configurable race validation (driver seat requirement)
                  - End-of-game leaderboard display (map or global)

COMMAND SYNTAX:
    /stats                    - Show your personal stats on current map
    /stats [player_name]      - Show stats for specific player on current map
    /stats [player_id]        - Show stats for player by ID on current map
    /stats all                - Show stats for all online players on current map
    /top                      - Show first page of top laps for current map
    /top [page_number]        - Show specific page of top laps for current map
    /global                   - Show first page of top overall players
    /global [page_number]     - Show specific page of top overall players
    /reset                    - Reset your current checkpoint progress

SCORING SYSTEM:
    Global rankings are calculated using a weighted system:
    - Map Record: +200 points per map record held
    - Global Record: +300 bonus points for overall best lap
    - Performance: Up to +50 points based on lap time relative to map record
    - Top Finishes: Laps within 95% of record time count as top finishes (tiebreaker)
    - Participation: Players with fewer than 3 maps played get 50% point penalty
    - Tiebreakers: map records > global record > top finishes

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

LAST UPDATED:     12/10/2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config start ---------------------------------------------
local CONFIG = {
    -- File names (in the SAPP config directory):
    STATS_FILE = "race_stats.json",
    TEXT_EXPORT_FILE = "lap_records.txt",

    -- Commands:
    STATS_COMMAND = "stats",            -- Command to show player's personal best lap (current map)
    MAP_TOP_COMMAND = "top",            -- Command to show top 5 global best laps (current map)
    GLOBAL_TOP_COMMAND = "global",      -- Command to show top 5 overall players (all maps)
    RESET_CHECKPOINT_COMMAND = "reset", -- Command to reset checkpoint for yourself

    -- Settings:
    LIST_SIZE = 5,              -- Number of top laps to display (applies to top command and game end)
    MIN_LAP_TIME = 10.0,        -- Minimum valid lap time in seconds
    EXPORT_LAP_RECORDS = true,  -- Export lap records to a text file
    DRIVER_REQUIRED = true,     -- Only count laps if the player is the driver of the vehicle
    SHOW_FINAL_TOP = true,      -- Show top results on game end
    TOP_FINAL_GLOBAL = false,   -- true = GLOBAL map results | false = CURRENT map results | This setting requires SHOW_FINAL_TOP = true
    SHOW_CHECKPOINT_HUD = true, -- Show checkpoint HUD while racing
    MSG_PREFIX = "**SAPP**",    -- Some functions temporarily change the message msg_prefix; this restores it.

    -- Pagination settings
    TOP_PAGE_SIZE = 10,    -- Default results per page for /top command
    GLOBAL_PAGE_SIZE = 10, -- Default results per page for /global command

    -- Scoring weights
    MAP_RECORD_WEIGHT = 200,     -- Points for holding a map record
    GLOBAL_RECORD_WEIGHT = 300,  -- Bonus points for holding the global best lap
    PERFORMANCE_WEIGHT = 50,     -- Max points for performance relative to record
    TOP_FINISH_THRESHOLD = 0.95, -- Ratio threshold for counting top finishes

    -- Add game modes that are non-sequential (any order) here:
    NON_SEQUENTIAL_MODES = {
        ["ANY_ORDER"] = true
    }
}
-- Config ends ---------------------------------------------

api_version = '1.12.0.0'

local io_open = io.open
local os_clock = os.clock

local band = bit.band

local math_abs, math_ceil, math_floor, math_huge, math_min =
    math.abs, math.ceil, math.floor, math.huge, math.min

local table_concat, table_insert, table_sort = table.concat, table.insert, table.sort
local tonumber, pcall, pairs, ipairs, select = tonumber, pcall, pairs, ipairs, select

local get_object_memory, get_dynamic_player = get_object_memory, get_dynamic_player
local player_alive, read_dword, read_word = player_alive, read_dword, read_word
local get_var, player_present, rprint, say_all = get_var, player_present, rprint, say_all

local race_globals, race_mode, game_over

local players, stats = {}, {}
local stats_file, txt_export_file

local current_map = ""
local json = loadfile('json.lua')()

local global_best_lap = {
    time = math_huge,
    player = "",
    map = ""
}

local function fmt(str, ...)
    return select('#', ...) > 0 and str:format(...) or str
end

local function sendPublic(str)
    execute_command('msg_prefix ""')
    say_all(str)
    execute_command('msg_prefix "' .. CONFIG.MSG_PREFIX .. '"')
end

local function roundToHundredths(num)
    return math_floor(num * 100 + 0.5) / 100
end

local function getConfigPath()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
end

local function formatMinutes(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    local minutes = math_floor(total_ms / 60000)
    local remaining = total_ms % 60000
    local secs = math_floor(remaining / 1000)
    local ms = remaining % 1000
    return fmt("%s%d:%02d.%03d", sign or "", minutes, secs, ms)
end

local function formatSeconds(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    local seconds = math_floor(total_ms / 1000)
    local ms = total_ms % 1000
    if seconds >= 60 then
        return formatMinutes(total_ms / 1000, sign)
    end
    return fmt("%s%d.%03ds", sign or "", seconds, ms)
end

local function formatSubSecond(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    if total_ms >= 1000 then
        return formatSeconds(total_ms / 1000, sign)
    end
    return fmt("%s0.%03ds", sign or "", total_ms)
end

local function fmtTime(time, is_difference)
    if time == 0 or time == math_huge then
        return is_difference and "+00:00.000" or "00:00.000"
    end

    local abs_time = math_abs(time)
    local sign = is_difference and "+" or ""

    if abs_time < 1 then
        return formatSubSecond(abs_time, sign)
    elseif abs_time < 60 then
        return formatSeconds(abs_time, sign)
    else
        return formatMinutes(abs_time, sign)
    end
end

local function readJSON(default)
    local file = io_open(stats_file, "r")
    if not file then return default end
    local content = file:read("*a")
    file:close()
    if content == "" then return default end
    local success, data = pcall(json.decode, json, content)

    -- Load global best lap if available
    if success and data.global_best then
        global_best_lap = data.global_best
    end

    return success and data or default
end

local function writeJSON()
    -- Include global best lap in saved data
    stats.global_best = global_best_lap

    local file = io_open(stats_file, "w")
    if not file then return false end
    file:write(json:encode(stats))
    file:close()
    return true
end

local function exportLapRecords()
    local lines, maps = {}, {}

    for map in pairs(stats) do
        if map ~= "global_best" then -- Skip the global best entry
            table_insert(maps, map)
        end
    end
    table_sort(maps, function(a, b) return a:lower() < b:lower() end)

    for _, map in ipairs(maps) do
        local data = stats[map]
        if data.current_best and data.current_best.time < math_huge then
            local line = fmt("%s, %s, %s", map, data.current_best.time, data.current_best.player)
            table_insert(lines, line)
        end
    end

    -- Add global best lap to export
    if global_best_lap.time < math_huge then
        local line = fmt("GLOBAL_BEST, %s, %s (%s)", global_best_lap.time,
            global_best_lap.player, global_best_lap.map)
        table_insert(lines, line)
    end

    local file = io_open(txt_export_file, "w")
    if file then
        file:write(table_concat(lines, "\n"))
        file:close()
    end
end

local function saveStats()
    writeJSON()
    if CONFIG.EXPORT_LAP_RECORDS then
        exportLapRecords()
    end
end

local function considerOccupant(id)
    if not CONFIG.DRIVER_REQUIRED then return true end

    local dyn_player = get_dynamic_player(id)
    if not player_alive(id) or dyn_player == 0 then return false end

    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return false end

    local vehicle_object = get_object_memory(vehicle_id)
    if vehicle_object == 0 then return false end

    return read_word(dyn_player + 0x2F0) == 0 -- driver seat
end

local function updatePlayerStats(player, lap_time)
    local name = player.name
    local map_stats = stats[current_map] or { current_best = { time = math_huge, player = "" }, players = {} }

    local lap_count = tonumber(get_var(player.id, '$score'))
    local previous_best = player.best_lap or math_huge
    local is_personal_best = false
    local is_map_record = false

    -- Personal best
    if lap_time < previous_best then
        player.best_lap = lap_time
        is_personal_best = true
    end

    -- Map best
    if lap_time < map_stats.current_best.time then
        map_stats.current_best = { time = lap_time, player = name }
        is_map_record = true

        -- Check for global best
        if lap_time < global_best_lap.time then
            global_best_lap = { time = lap_time, player = name, map = current_map }
        end
    end

    local player_stats = map_stats.players[name]
    if not player_stats then
        player_stats = { best = lap_time, laps = lap_count, average = lap_time }
        map_stats.players[name] = player_stats
    else
        player_stats.laps = lap_count
        player_stats.best = math_min(player_stats.best, lap_time)
        player_stats.average = ((player_stats.average * (lap_count - 1)) + lap_time) / lap_count
    end

    stats[current_map] = map_stats

    local lap_time_formatted = fmtTime(lap_time)

    if is_map_record then
        sendPublic(fmt("NEW MAP RECORD: [%s - %s]", name, lap_time_formatted))
    elseif is_personal_best then
        sendPublic(fmt("NEW PERSONAL BEST: [%s - %s]", name, lap_time_formatted))
    else
        rprint(player.id,
            fmt("Lap completed: %s (Best: %s | %s)",
                lap_time_formatted,
                fmtTime(previous_best),
                fmtTime(lap_time - previous_best, true)))
    end
end

local function parseArgs(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function showTopPlayers(id, page)
    local send = id and function(msg) rprint(id, msg) end or sendPublic
    local map_data = stats[current_map]
    local map_best_laps = {}

    if not map_data then
        send("No records for this map yet")
        return
    end

    -- Collect all player best laps
    for player_name, player_stats in pairs(map_data.players) do
        table_insert(map_best_laps, {
            name = player_name,
            best_lap = player_stats.best
        })
    end

    if #map_best_laps == 0 then
        send("No records for this map yet")
        return
    end

    -- Sort by best lap time
    table_sort(map_best_laps, function(a, b) return a.best_lap < b.best_lap end)

    -- Pagination logic
    local page_size = CONFIG.TOP_PAGE_SIZE
    local total_entries = #map_best_laps
    local total_pages = math_ceil(total_entries / page_size)

    page = page or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_index = (page - 1) * page_size + 1
    local end_index = math_min(start_index + page_size - 1, total_entries)

    -- Display results
    send(fmt("Top players for %s [Page %d/%d]:", current_map, page, total_pages))

    for i = start_index, end_index do
        local entry = map_best_laps[i]
        send(fmt("%d. %s - %s", i, entry.name, fmtTime(entry.best_lap)))
    end

    if total_pages > 1 then
        send(fmt("Use '/top %d' for next page", page + 1))
    end
end

local function getTopOverallPlayers(n)
    local player_totals = {}

    -- Calculate scores for each player across all maps
    for map_name, map_data in pairs(stats) do
        if map_name ~= "global_best" and map_data.players then -- Skip global best entry
            for player_name, player_stats in pairs(map_data.players) do
                if not player_totals[player_name] then
                    player_totals[player_name] = {
                        points = 0,
                        map_records = 0,
                        top_finishes = 0,
                        maps_played = 0
                    }
                end

                local player = player_totals[player_name]
                player.maps_played = player.maps_played + 1

                -- Award points for map record (if held)
                if map_data.current_best and map_data.current_best.player == player_name then
                    player.points = player.points + CONFIG.MAP_RECORD_WEIGHT
                    player.map_records = player.map_records + 1
                end

                -- Award bonus for global record
                if global_best_lap.player == player_name then
                    player.points = player.points + CONFIG.GLOBAL_RECORD_WEIGHT
                end

                -- Award points based on performance relative to map record
                if map_data.current_best then
                    local ratio = map_data.current_best.time / player_stats.best
                    local performance_points = math_floor(ratio * CONFIG.PERFORMANCE_WEIGHT)
                    player.points = player.points + performance_points

                    -- Count top finishes (within threshold of record)
                    if ratio >= CONFIG.TOP_FINISH_THRESHOLD then
                        player.top_finishes = player.top_finishes + 1
                    end
                end
            end
        end
    end

    -- Convert to sortable array, excluding players with no map records
    local players_array = {}
    for name, data in pairs(player_totals) do
        -- Only include players who have at least one map record
        if data.map_records > 0 then
            -- Apply penalty for players with few maps played
            local participation_penalty = data.maps_played < 3 and 0.5 or 1
            data.adjusted_points = data.points * participation_penalty

            table_insert(players_array, {
                name = name,
                points = data.adjusted_points,
                map_records = data.map_records,
                top_finishes = data.top_finishes,
                maps_played = data.maps_played
            })
        end
    end

    -- Sort by points (descending)
    table_sort(players_array, function(a, b)
        if a.points == b.points then
            -- Tiebreaker: more map records
            if a.map_records == b.map_records then
                -- Second tiebreaker: more top finishes
                return a.top_finishes > b.top_finishes
            end
            return a.map_records > b.map_records
        end
        return a.points > b.points
    end)

    -- Return top n players
    local result = {}
    for i = 1, math_min(n, #players_array) do
        table_insert(result, players_array[i])
    end

    return result
end

local function showGlobalStats(id, page, page_size)
    local send = id and function(msg) rprint(id, msg) end or sendPublic

    -- Get all players (not limited by page size yet)
    local all_players = getTopOverallPlayers(10000) -- Large number to get all players

    if #all_players == 0 then
        send("No records yet")
        return
    end

    -- Pagination logic
    page_size = page_size or CONFIG.GLOBAL_PAGE_SIZE
    local total_entries = #all_players
    local total_pages = math_ceil(total_entries / page_size)

    page = page or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end

    local start_index = (page - 1) * page_size + 1
    local end_index = math_min(start_index + page_size - 1, total_entries)

    -- Display results
    send(fmt("Top players [Page %d/%d]:", page, total_pages))

    for i = start_index, end_index do
        local player = all_players[i]
        send(fmt("%d. %s [%d pts]", i, player.name, player.points))
    end

    if total_pages > 1 then
        send(fmt("Use '/global %d' for next page", page + 1))
    end
end

local function showPlayerStats(id, target)
    local send = function(msg) rprint(id, msg) end
    local map_data = stats[current_map]

    if not map_data or not map_data.players then
        send("No records for this map yet")
        return
    end

    if target == "all" then
        -- Show stats for all online players
        for pid, player_data in pairs(players) do
            if player_present(pid) then
                local player_name = player_data.name
                local player_stats = map_data.players[player_name]
                if player_stats then
                    send(fmt("%s: Best [%s], Avg [%s]",
                        player_name,
                        fmtTime(player_stats.best),
                        fmtTime(player_stats.average)))
                else
                    send(fmt("%s: No laps recorded", player_name))
                end
            end
        end
    else
        -- Show stats for specific player
        local target_id = tonumber(target)
        local player_name

        if target_id and player_present(target_id) then
            player_name = get_var(target_id, "$name")
        else
            -- Assume it's a player name
            player_name = target
        end

        local player_stats = map_data.players[player_name]
        if player_stats then
            send(fmt("%s: Best [%s], Avg [%s]",
                player_name,
                fmtTime(player_stats.best),
                fmtTime(player_stats.average)))
        else
            send(fmt("No records found for %s on %s", player_name, current_map))
        end
    end
end

local function getRaceMode()
    local mode = get_var(0, '$mode')
    return CONFIG.NON_SEQUENTIAL_MODES[mode] and 2 or 1
end

local function getCheckpointNumber(bitmask)
    if bitmask == 0 then return 0 end
    local n = 0
    while bitmask ~= 0 do
        bitmask = band(bitmask, bitmask - 1)
        n = n + 1
    end
    return n
end

local function setPlayerState(player, racing, time, checkpoint)
    player.racing = racing; player.start_time = time
    player.last_checkpoint = checkpoint
end

local function resetCheckpoint(id)
    local player = players[id]
    if not player then return end

    write_dword(race_globals + to_real_index(id) * 4 + 0x44, 0)
    setPlayerState(player, nil, nil, 0)
    player.just_completed_lap = false

    if race_mode == 1 then
        rprint(id, "Lap progress reset. Start a new lap from the first checkpoint")
    else
        rprint(id, "Lap progress reset. Start a new lap from any checkpoint")
    end
end

local function handleRaceMode(player, current_checkpoint, now)
    local start_condition
    local reset_condition = (current_checkpoint == 0 and player.racing)

    if race_mode == 1 then
        -- Sequential mode: Start only at the first checkpoint
        start_condition = (current_checkpoint == 1 and not player.racing)
    elseif race_mode == 2 then
        -- Non-sequential mode: Start when any checkpoint is reached
        start_condition = (current_checkpoint >= 1 and not player.racing)
    end

    if start_condition then
        setPlayerState(player, true, now, 0)
        if not player.just_completed_lap then
            rprint(player.id, "LAP STARTED!")
        end
        player.just_completed_lap = false
    elseif reset_condition then
        setPlayerState(player, nil, nil, 0)
        player.just_completed_lap = false
    end
end

function OnScore(id)
    if not considerOccupant(id) then goto continue end

    local player = players[id]
    if not player or not player.racing or not player.start_time then goto continue end

    local timer = os_clock() - player.start_time
    local lap_time = roundToHundredths(timer)

    if lap_time >= CONFIG.MIN_LAP_TIME then
        updatePlayerStats(player, lap_time)
        setPlayerState(player, nil, nil, 0)
        player.just_completed_lap = true
    end

    ::continue::
end

function OnTick()
    if game_over then return end

    for id, player in pairs(players) do
        if player_present(id) and player_alive(id) then
            local now = os_clock()
            local checkpoint_address = race_globals + to_real_index(id) * 4 + 0x44
            local checkpoint = read_dword(checkpoint_address)

            local current_checkpoint = getCheckpointNumber(checkpoint)
            local prev_checkpoint = player.last_checkpoint

            handleRaceMode(player, current_checkpoint, now)

            -- Show checkpoint times
            if player.racing and player.start_time then
                local elapsed = now - player.start_time

                -- Timeout safeguard (10 minutes)
                if elapsed > 600 then
                    setPlayerState(player, nil, nil, 0)
                elseif CONFIG.SHOW_CHECKPOINT_HUD and current_checkpoint > 1 and current_checkpoint ~= prev_checkpoint then
                    rprint(id, fmt("Checkpoint %d - [%s]", current_checkpoint, fmtTime(elapsed)))
                    player.last_checkpoint = current_checkpoint
                end
            end
        end
    end
end

function OnStart()
    if get_var(0, '$gt') ~= 'race' then return end

    players = {}
    race_mode = getRaceMode()
    current_map = get_var(0, "$map")
    game_over = false

    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnEnd()
    saveStats()
    if not CONFIG.SHOW_FINAL_TOP then return end
    if not CONFIG.TOP_FINAL_GLOBAL then
        showTopPlayers() -- show top for current map only
        return
    end
    showGlobalStats(nil, 1, CONFIG.LIST_SIZE) -- show top overall players (all maps)
    game_over = true
end

function OnJoin(id)
    local player_name = get_var(id, "$name")
    local best_lap = math_huge
    if stats[current_map] and stats[current_map].players and stats[current_map].players[player_name] then
        best_lap = stats[current_map].players[player_name].best
    end
    players[id] = {
        id = id,
        name = player_name,
        previous_time = 0,
        last_checkpoint = 0,
        best_lap = best_lap,
        just_completed_lap = false
    }
end

function OnQuit(id)
    players[id] = nil
end

function OnCommand(id, command)
    if id == 0 then return true end

    local args = parseArgs(command)
    if #args == 0 then return false end

    if args[1] == CONFIG.MAP_TOP_COMMAND then
        local page = tonumber(args[2]) or 1
        showTopPlayers(id, page)
        return false
    elseif args[1] == CONFIG.STATS_COMMAND then
        local target = args[2] or tostring(id)
        showPlayerStats(id, target)
        return false
    elseif args[1] == CONFIG.GLOBAL_TOP_COMMAND then
        local page = tonumber(args[2]) or 1
        showGlobalStats(id, page)
        return false
    elseif args[1] == CONFIG.RESET_CHECKPOINT_COMMAND then
        resetCheckpoint(id)
        return false
    end
end

function OnScriptLoad()
    race_globals = read_dword(sig_scan("BF??????00F3ABB952000000") + 0x1)

    local config_path = getConfigPath()
    stats_file = config_path .. "\\sapp\\" .. CONFIG.STATS_FILE
    txt_export_file = config_path .. "\\sapp\\" .. CONFIG.TEXT_EXPORT_FILE

    stats = readJSON(stats)

    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_SCORE, 'OnScore')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_GAME_START, 'OnStart')

    OnStart()
end

function OnScriptUnload()
    saveStats()
end
