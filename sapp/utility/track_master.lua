--[[
===============================================================================
SCRIPT NAME:    track_master.lua
DESCRIPTION:    Advanced racing tracker and leaderboard system for Halo SAPP.

REQUIRED:       * Lua JSON Parser: http://regex.info/blog/lua/json
                  Place json.lua in the same directory as sapp.dll

FEATURES:       - Lap timing with checkpoint validation (sequential/non-sequential modes)
                - Personal bests, map records, per-map stats (laps, best, average)
                - Announcements: personal bests, map records, checkpoint times
                  performance up to 50, top finishes threshold 0.95, participation penalty for <3 maps)

COMMANDS:       - /stats [player_name|id|all]   - personal stats on current map
                - /top [page]                   - top laps on current map
                - /reset                        - reset checkpoint progress

SCORING:        Map Record: +200 per map held
                Performance: up to +50 (ratio × weight)
                Top Finishes: laps within 95% of record (tiebreaker)
                Participation: <3 maps > 50% penalty
                Tiebreakers: map records > top finishes

LAST UPDATED:     1 June 2026

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config start ---------------------------------------------
local CONFIG = {
    -- File names (in the SAPP config directory):
    STATS_FILE = "race_stats.json",
    --
    -- Commands:
    STATS_COMMAND = "stats",            -- Command to show player's personal best lap (current map)
    MAP_TOP_COMMAND = "top",            -- Command to show top 5 global best laps (current map)
    RESET_CHECKPOINT_COMMAND = "reset", -- Command to reset checkpoint for yourself
    --
    -- Settings:
    TOP_PAGE_SIZE = 10,                 -- Default results per page for /top command
    MIN_LAP_TIME = 10.0,                -- Minimum valid lap time in seconds
    DRIVER_REQUIRED = true,             -- Only count laps if the player is the driver of the vehicle
    SHOW_FINAL_TOP = true,              -- Show top results on game end
    SHOW_CHECKPOINT_HUD = true,         -- Show checkpoint HUD while racing
    MSG_PREFIX = "",                    -- Removed during msg relay; It will be restored to this.
    --
    -- Add game modes that are non-sequential (any order) here:
    NON_SEQUENTIAL_MODES = {
        ["ANY_ORDER"] = true
    },
    --
    -- Name filtering
    -- When false, players with these names will NOT have their stats saved
    NO_SAVING = {
        ["Butcher"] = true,
        ["Caboose"] = true,
        ["Crazy"] = true,
        ["Cupid"] = true,
        ["Darling"] = true,
        ["Dasher"] = true,
        ["Disco"] = true,
        ["Donut"] = true,
        ["Dopey"] = true,
        ["Ghost"] = true,
        ["Goat"] = true,
        ["Grumpy"] = true,
        ["Hambone"] = true,
        ["Hollywood"] = true,
        ["Howard"] = true,
        ["Jack"] = true,
        ["Killer"] = true,
        ["King"] = true,
        ["Noodle"] = true,
        ["Penguin"] = true,
        ["Pirate"] = true,
        ["Prancer"] = true,
        ["Saucy"] = true,
        ["Shadow"] = true,
        ["Sleepy"] = true,
        ["Snake"] = true,
        ["Sneak"] = true,
        ["Stompy"] = true,
        ["Stumpy"] = true,
        ["The Bear"] = true,
        ["The Big L"] = true,
        ["Tooth"] = true,
        ["Walla Walla"] = true,
        ["Weasel"] = true,
        ["Whicker"] = true,
        ["Wheezy"] = true,
        ["Whisp"] = true,
        ["Wilshire"] = true
    }
}
-- Config ends ---------------------------------------------

api_version = '1.12.0.0'

local io_open = io.open
local os_clock = os.clock
local band = bit.band
local math_abs, math_ceil, math_floor, math_huge, math_min = math.abs, math.ceil, math.floor, math.huge, math.min
local table_insert, table_sort = table.insert, table.sort
local tonumber, pcall, pairs, select = tonumber, pcall, pairs, select

local get_object_memory, get_dynamic_player = get_object_memory, get_dynamic_player
local player_alive, read_dword, read_word = player_alive, read_dword, read_word
local get_var, player_present, rprint, say_all = get_var, player_present, rprint, say_all

local race_globals, race_mode, game_over
local players, stats = {}, {}
local stats_file

local current_map = ""
local json = loadfile('json.lua')()

local function fmt(str, ...)
    return select('#', ...) > 0 and str:format(...) or str
end

local function send_all(str)
    execute_command('msg_prefix ""')
    say_all(str)
    execute_command('msg_prefix "' .. CONFIG.MSG_PREFIX .. '"')
end

local function round_to_hundredths(num)
    return math_floor(num * 100 + 0.5) / 100
end

local function get_config_path()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
end

local function fmt_minutes(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    local minutes = math_floor(total_ms / 60000)
    local remaining = total_ms % 60000
    local secs = math_floor(remaining / 1000)
    local ms = remaining % 1000
    return fmt("%s%d:%02d.%03d", sign or "", minutes, secs, ms)
end

local function fmt_seconds(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    local seconds = math_floor(total_ms / 1000)
    local ms = total_ms % 1000
    if seconds >= 60 then
        return fmt_minutes(total_ms / 1000, sign)
    end
    return fmt("%s%d.%03ds", sign or "", seconds, ms)
end

local function fmt_sub_seconds(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    if total_ms >= 1000 then
        return fmt_seconds(total_ms / 1000, sign)
    end
    return fmt("%s0.%03ds", sign or "", total_ms)
end

local function fmt_time(time, is_difference)
    if time == 0 or time == math_huge then
        return is_difference and "+00:00.000" or "00:00.000"
    end

    local abs_time = math_abs(time)
    local sign = is_difference and "+" or ""

    if abs_time < 1 then
        return fmt_sub_seconds(abs_time, sign)
    elseif abs_time < 60 then
        return fmt_seconds(abs_time, sign)
    else
        return fmt_minutes(abs_time, sign)
    end
end

local function get_pagination_indices(page, total_entries, page_size)
    local total_pages = math_ceil(total_entries / page_size)
    page = page or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end
    local start_index = (page - 1) * page_size + 1
    local end_index = math_min(start_index + page_size - 1, total_entries)
    return start_index, end_index, total_pages, page
end

local function load_stats(default)
    local file = io_open(stats_file, "r")
    if not file then return default end
    local content = file:read("*a")
    file:close()
    if content == "" then return default end
    local success, data = pcall(json.decode, json, content)

    return success and data or default
end

local function save_stats()
    local file = io_open(stats_file, "w")
    if not file then return false end
    file:write(json:encode(stats))
    file:close()
    return true
end

local function is_filtered_name(name)
    return CONFIG.NO_SAVING[name] == true
end

local function is_driver(id)
    if not CONFIG.DRIVER_REQUIRED then return true end

    local dyn_player = get_dynamic_player(id)
    if not player_alive(id) or dyn_player == 0 then return false end

    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return false end

    local vehicle_object = get_object_memory(vehicle_id)
    if vehicle_object == 0 then return false end

    return read_word(dyn_player + 0x2F0) == 0 -- driver seat
end

local function update_stats(player, lap_time)
    local name = player.name

    if is_filtered_name(name) then
        rprint(player.id, fmt("Lap completed: %s (Stats N/A - Filtered Name)", fmt_time(lap_time)))
        return
    end

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
    local lap_time_formatted = fmt_time(lap_time)

    if is_map_record then
        send_all(fmt("NEW MAP RECORD: [%s - %s]", name, lap_time_formatted))
    elseif is_personal_best then
        send_all(fmt("NEW PERSONAL BEST: [%s - %s]", name, lap_time_formatted))
    else
        rprint(
            player.id,
            fmt(
                "Lap completed: %s (Best: %s | %s)", lap_time_formatted, fmt_time(previous_best),
                fmt_time(lap_time - previous_best, true)
            )
        )
    end
end

local function split(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function show_top(id, page)
    local send = id
        and function (msg)
            rprint(id, msg)
        end or send_all
    local map_data = stats[current_map]
    local map_best_laps = {}

    if not map_data then
        send("No records for this map yet")
        return
    end

    -- Collect all player best laps (excluding generic names if not saving)
    for player_name, player_stats in pairs(map_data.players) do
        if not is_filtered_name(player_name) then
            table_insert(map_best_laps, {
                name = player_name,
                best_lap = player_stats.best
            })
        end
    end

    if #map_best_laps == 0 then
        send("No records for this map yet")
        return
    end

    -- Sort by best lap time
    table_sort(map_best_laps, function (a, b) return a.best_lap < b.best_lap end)

    -- Pagination using shared helper
    local start_index, end_index, total_pages, current_page = get_pagination_indices(
        page, #map_best_laps, CONFIG.TOP_PAGE_SIZE
    )

    -- Display results
    send(fmt("Top players for %s [Page %d/%d]:", current_map, current_page, total_pages))

    for i = start_index, end_index do
        local entry = map_best_laps[i]
        send(fmt("%d. %s - %s", i, entry.name, fmt_time(entry.best_lap)))
    end

    if total_pages > 1 then
        send(fmt("Use '/top %d' for next page", current_page + 1))
    end
end

local function show_stats(id, target)
    local send = function (msg)
        rprint(id, msg)
    end

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
                    send(
                        fmt(
                            "%s: Best [%s], Avg [%s]", player_name, fmt_time(player_stats.best),
                            fmt_time(player_stats.average)
                        )
                    )
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
            send(
                fmt("%s: Best [%s], Avg [%s]", player_name, fmt_time(player_stats.best), fmt_time(player_stats.average))
            )
        else
            send(fmt("No records found for %s on %s", player_name, current_map))
        end
    end
end

local function get_race_mode()
    local mode = get_var(0, '$mode')
    return CONFIG.NON_SEQUENTIAL_MODES[mode] and 2 or 1
end

local function get_checkpoint_idx(bitmask)
    if bitmask == 0 then return 0 end
    local n = 0
    while bitmask ~= 0 do
        bitmask = band(bitmask, bitmask - 1)
        n = n + 1
    end
    return n
end

local function set_state(player, racing, time, checkpoint)
    player.racing = racing
    player.start_time = time
    player.last_checkpoint = checkpoint
end

local function reset_checkpoint(id)
    local player = players[id]
    if not player then return end

    write_dword(race_globals + to_real_index(id) * 4 + 0x44, 0)
    set_state(player, nil, nil, 0)
    player.just_completed_lap = false

    if race_mode == 1 then
        rprint(id, "Lap progress reset. Start a new lap from the first checkpoint")
    else
        rprint(id, "Lap progress reset. Start a new lap from any checkpoint")
    end
end

local function handle_race_mode(player, current_checkpoint, now)
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
        set_state(player, true, now, 0)
        if not player.just_completed_lap then
            rprint(player.id, "LAP STARTED!")
        end
        player.just_completed_lap = false
    elseif reset_condition then
        set_state(player, nil, nil, 0)
        player.just_completed_lap = false
    end
end

function OnScore(id)
    if not is_driver(id) then goto continue end

    local player = players[id]
    if not player or not player.racing or not player.start_time then goto continue end

    local timer = os_clock() - player.start_time
    local lap_time = round_to_hundredths(timer)

    if lap_time >= CONFIG.MIN_LAP_TIME then
        update_stats(player, lap_time)
        set_state(player, nil, nil, 0)
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

            local current_checkpoint = get_checkpoint_idx(checkpoint)
            local prev_checkpoint = player.last_checkpoint

            handle_race_mode(player, current_checkpoint, now)

            -- Show checkpoint times
            if player.racing and player.start_time then
                local elapsed = now - player.start_time

                -- Timeout safeguard (10 minutes)
                if elapsed > 600 then
                    set_state(player, nil, nil, 0)
                elseif CONFIG.SHOW_CHECKPOINT_HUD and current_checkpoint > 1 and current_checkpoint ~= prev_checkpoint then
                    rprint(id, fmt("Checkpoint %d - [%s]", current_checkpoint, fmt_time(elapsed)))
                    player.last_checkpoint = current_checkpoint
                end
            end
        end
    end
end

function OnStart()
    if get_var(0, '$gt') ~= 'race' then return end

    players = {}
    race_mode = get_race_mode()
    current_map = get_var(0, "$map")
    game_over = false

    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnEnd()
    save_stats()
    if CONFIG.SHOW_FINAL_TOP then show_top() end
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
    if id == 0 then return end
    local args = split(command)
    if #args == 0 then return false end
    if args[1] == CONFIG.MAP_TOP_COMMAND then
        local page = tonumber(args[2]) or 1
        show_top(id, page)
        return false
    elseif args[1] == CONFIG.STATS_COMMAND then
        local target = args[2] or tostring(id)
        show_stats(id, target)
        return false
    elseif args[1] == CONFIG.RESET_CHECKPOINT_COMMAND then
        reset_checkpoint(id)
        return false
    end
end

function OnScriptLoad()
    race_globals = read_dword(sig_scan("BF??????00F3ABB952000000") + 0x1)

    local config_path = get_config_path()
    stats_file = config_path .. "\\sapp\\" .. CONFIG.STATS_FILE

    stats = load_stats(stats)

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
    save_stats()
end
