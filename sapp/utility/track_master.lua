--[[
===============================================================================
SCRIPT NAME:    track_master.lua
DESCRIPTION:    Advanced racing tracker and leaderboard system with:

                - Lap timing with checkpoint validation (sequential/non-sequential modes)
                - Personal bests, map records, per-map stats (laps, best, average)
                - Announcements: personal bests, map records, checkpoint times
                  performance up to 50, top finishes threshold 0.95, participation penalty for <3 maps)

COMMANDS:       - /stats [name|id|all]   - personal stats on current map
                - /top [page]            - top laps on current map
                - /reset                 - reset checkpoint progress
                                           OR: Press melee key.

REQUIRED:       * Lua JSON Parser: http://regex.info/blog/lua/json
                  Place json.lua in the same directory as sapp.dll

SCORING:        Map Record: +200 per map held
                Top Finishes: laps within 95% of record (tiebreaker)
                Participation: <3 maps > 50% penalty
                Tiebreakers: map records > top finishes

LAST UPDATED:     4 July 2026

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Config start ---------------------------------------------
local STATS_FILE = "race_stats.json"
local STATS_COMMAND = "stats"
local MAP_TOP_COMMAND = "top"
local RESET_CHECKPOINT_COMMAND = "reset"
local TOP_PAGE_SIZE = 10
local DRIVER_REQUIRED = true -- (when true, you must be the driver for your stats to count)
local SHOW_TOP_AT_END_GAME = true
local SHOW_CHECKPOINT_HUD = true

local ALLOW_MELEE_RESET = true
local MELEE_RESET_COOLDOWN = 3.0

-- Add modes that are non-sequential (any order) here:
local NON_SEQUENTIAL_MODES = { ["EXAMPLE_ORDER_GAMEMODE"] = true, ["ANOTHER"] = true }

local MESSAGES = {
    NEW_MAP_RECORD = "NEW MAP RECORD: [%s - %s]",
    NEW_PERSONAL_BEST = "NEW PERSONAL BEST: [%s - %s]",
    LAP_COMPLETED_FILTERED = "Lap completed: %s (Stats N/A - Filtered Name)",
    LAP_COMPLETED_WITH_BEST = "Lap completed: %s (Best: %s | %s)",
    NO_RECORDS = "No records for this map yet",
    TOP_HEADER = "Top players for %s",
    TOP_ENTRY = "%d. %s - %s",
    TOP_NEXT_PAGE_HINT = "[Page %d/%d] - Use '/top %d' for next page",
    STATS_PLAYER_LINE = "%s: Best [%s], Avg [%s]",
    STATS_NO_LAPS = "%s: No laps recorded",
    STATS_NO_RECORDS_FOR_PLAYER = "No records found for %s on %s",
    LAP_STARTED = "LAP STARTED - CHECKPOINT %d-%d",
    CHECKPOINT_TIME = "CHECKPOINT %d-%d - [%s]",
    RESET_SEQUENTIAL = "Lap progress reset. Start a new lap from the first checkpoint",
    RESET_NONSEQUENTIAL = "Lap progress reset. Start a new lap from any checkpoint"
}

-- Name filtering
-- Players with these names will NOT have their stats saved.
local NO_SAVING = {
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
-- Config ends ---------------------------------------------

api_version = '1.12.0.0'

-- localized these for performance
local io_open = io.open
local os_clock = os.clock
local bit_band = bit.band
local bit_rshift = bit.rshift
local math_abs, math_ceil, math_floor, math_huge, math_min = math.abs, math.ceil, math.floor, math.huge, math.min
local table_insert, table_sort = table.insert, table.sort
local tonumber, pcall, pairs, select = tonumber, pcall, pairs, select
local string_format, gmatch = string.format, string.gmatch
local write_dword = write_dword
local read_dword = read_dword
local read_word = read_word
local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local rprint = rprint
local get_object_memory = get_object_memory
local get_dynamic_player = get_dynamic_player
local to_real_index = to_real_index
local read_string = read_string

local race_globals, race_mode, game_over
local race_checkpoint_count
local map_record_cache = {}
local players, stats = {}, {}
local current_map = ""
local json

local function fmt(str, ...)
    return select('#', ...) > 0 and string_format(str, ...) or str
end

local function rprint_all(msg)
    for i = 1, 16 do
        if player_present(i) then
            rprint(i, msg)
        end
    end
end

local function round_to_hundredths(num)
    return math_floor(num * 100 + 0.5) / 100
end

-- get SAPP directory path (root path where mapcycle.txt is)
local function get_config_path()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
end

local function get_checkpoint_count(mask)
    local count = 0
    while mask ~= 0 do
        mask = bit_band(mask, mask - 1)
        count = count + 1
    end
    return count + 1
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

-- pretty print minutes (for long lap times)
local function fmt_minutes(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    local minutes = math_floor(total_ms / 60000)
    local remaining = total_ms % 60000
    local secs = math_floor(remaining / 1000)
    local ms = remaining % 1000
    return fmt("%s%d:%02d.%03d", sign or "", minutes, secs, ms)
end

-- seconds or minutes if > 60
local function fmt_seconds(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    local seconds = math_floor(total_ms / 1000)
    local ms = total_ms % 1000
    if seconds >= 60 then
        return fmt_minutes(total_ms / 1000, sign)
    end
    return fmt("%s%d.%03ds", sign or "", seconds, ms)
end

-- sub-second times (e.g., 0.123s)
local function fmt_sub_seconds(abs_time, sign)
    local total_ms = math_floor(abs_time * 1000 + 0.5)
    if total_ms >= 1000 then
        return fmt_seconds(total_ms / 1000, sign)
    end
    return fmt("%s0.%03ds", sign or "", total_ms)
end

-- main time formatter, handles differences as well
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

-- pagination math for /top command
local function get_pagination_indices(page, total_entries, page_size)
    local total_pages = math_ceil(total_entries / page_size)
    page = page or 1
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end
    local start_index = (page - 1) * page_size + 1
    ---@diagnostic disable-next-line: assign-type-mismatch
    local end_index = math_min(start_index + page_size - 1, total_entries)
    return start_index, end_index, total_pages, page
end

-- load stats JSON, return default if fails
local function load_stats(default)
    local file = io_open(STATS_FILE, "r")
    if not file then return default end
    local content = file:read("*a")
    file:close()
    if content == "" then return default end

    ---@diagnostic disable-next-line: param-type-mismatch, need-check-nil
    local success, data = pcall(json.decode, json, content)
    return success and data or default
end

local function save_stats()
    local file = io_open(STATS_FILE, "w")
    if not file then return false end

    ---@diagnostic disable-next-line: call-non-callable, need-check-nil
    file:write(json:encode(stats))
    file:close()
    return true
end

-- Compute map records from player data and update cache
local function compute_map_records(map_name)
    local map_data = stats[map_name]
    if not map_data or type(map_data) ~= "table" then
        map_record_cache[map_name] = { time = math_huge, player = "" }
        return
    end
    local best_time = math_huge
    local best_player = ""
    for name, pstats in pairs(map_data) do
        if pstats.best and pstats.best < best_time then
            best_time = pstats.best
            best_player = name
        end
    end
    map_record_cache[map_name] = { time = best_time, player = best_player }
end

local function is_filtered_name(name)
    return NO_SAVING[name] == true
end

-- check if player is actually driving (not passenger), if DRIVER_REQUIRED is off then everyone qualifies
local function is_driver(id)
    ---@diagnostic disable-next-line: unnecessary-if
    if not DRIVER_REQUIRED then return true end
    local dyn_player = get_dynamic_player(id)
    if not player_alive(id) or dyn_player == 0 then return false end
    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return false end
    local vehicle_object = get_object_memory(vehicle_id)
    if vehicle_object == 0 then return false end
    return read_word(dyn_player + 0x2F0) == 0 -- driver seat index
end

local function melee_button_pressed(dyn_player)
    local in_v = read_dword(dyn_player + 0x11C)
    if in_v == 0xFFFFFFFF then return end
    return read_word(dyn_player + 0x208) == 128
end

local function setPlayerState(player, racing, time, checkpoint)
    player.racing = racing
    player.start_time = time
    player.last_checkpoint = checkpoint
end

local function reset_checkpoint_progress(player, id)
    if not player then return end
    write_dword(player.checkpoint_addr, 0)
    setPlayerState(player, nil, nil, 0)
    player.last_mask = 0
    player.last_idx = 0
    player.just_completed_lap = false
    rprint(id, race_mode == 1 and MESSAGES.RESET_SEQUENTIAL or MESSAGES.RESET_NONSEQUENTIAL)
end

-- record a completed lap, update personal best, map record, averages
local function update_stats(player, lap_time)
    local id = player.id
    local name = player.name
    if is_filtered_name(name) then
        rprint(id, fmt(MESSAGES.LAP_COMPLETED_FILTERED, fmt_time(lap_time)))
        return
    end

    -- Ensure map entry exists
    if not stats[current_map] then
        stats[current_map] = {}
    end
    local map_stats = stats[current_map]

    -- Get or create player stats
    local player_stats = map_stats[name]
    local old_laps = player_stats and player_stats.laps or 0
    local new_laps = old_laps + 1
    local old_best = player_stats and player_stats.best or math_huge

    -- Determine all-time personal best
    local is_personal_best = lap_time < old_best

    -- Map record check
    local current_record = map_record_cache[current_map]
    if not current_record or current_record.time == math_huge then
        compute_map_records(current_map)
        current_record = map_record_cache[current_map]
    end
    local is_map_record = lap_time < current_record.time
    if is_map_record then
        current_record.time = lap_time
        current_record.player = name
    end

    -- Update stats (best, laps, average)
    local new_best = math_min(old_best, lap_time)
    local new_average

    ---@diagnostic disable-next-line: unnecessary-if
    if new_laps == 1 then
        new_average = lap_time
    else
        local old_average = player_stats and player_stats.average or 0
        new_average = (old_average * old_laps + lap_time) / new_laps
    end

    map_stats[name] = { best = new_best, laps = new_laps, average = new_average }

    if is_personal_best then
        player.best_lap = lap_time
    end

    -- Announcements
    local lap_time_formatted = fmt_time(lap_time)
    if is_map_record then
        rprint_all(fmt(MESSAGES.NEW_MAP_RECORD, name, lap_time_formatted))
    elseif is_personal_best then
        rprint_all(fmt(MESSAGES.NEW_PERSONAL_BEST, name, lap_time_formatted))
    else
        local previous_best_formatted = fmt_time(old_best)
        local diff = fmt_time(lap_time - old_best, true)
        rprint(id, fmt(MESSAGES.LAP_COMPLETED_WITH_BEST, lap_time_formatted, previous_best_formatted, diff))
    end
end

local function split(input)
    local result = {}
    local n = 0
    for substring in gmatch(input, "%S+") do
        n = n + 1
        result[n] = substring
    end
    return result
end

-- show top times for current map (paginated)
local function show_top(id, page)
    local send = id
        and function (msg)
            rprint(id, msg)
        end or rprint_all
    local map_data = stats[current_map]
    if not map_data then
        send(MESSAGES.NO_RECORDS)
        return
    end

    local map_best_laps = {}
    for name, player_stats in pairs(map_data) do
        if not is_filtered_name(name) and player_stats.best then
            table_insert(map_best_laps, { name = name, best_lap = player_stats.best })
        end
    end

    if #map_best_laps == 0 then
        send(MESSAGES.NO_RECORDS)
        return
    end

    table_sort(map_best_laps, function (a, b) return a.best_lap < b.best_lap end)
    local start_idx, end_idx, total_pages, cur_page = get_pagination_indices(page, #map_best_laps, TOP_PAGE_SIZE)
    send(fmt(MESSAGES.TOP_HEADER, current_map))
    for i = start_idx, end_idx do
        local entry = map_best_laps[i]

        ---@diagnostic disable-next-line: need-check-nil
        send(fmt(MESSAGES.TOP_ENTRY, i, entry.name, fmt_time(entry.best_lap)))
    end
    if total_pages > 1 then
        send(fmt(MESSAGES.TOP_NEXT_PAGE_HINT, cur_page, total_pages, cur_page + 1))
    end
end

local function show_stats(id, target)
    local map_data = stats[current_map]
    if not map_data then
        rprint(id, MESSAGES.NO_RECORDS)
        return
    end

    if target == "all" then
        for pid, pdata in pairs(players) do
            if player_present(pid) then
                local pname = pdata.name
                local ps = map_data[pname]
                if ps then
                    rprint(id, fmt(MESSAGES.STATS_PLAYER_LINE, pname, fmt_time(ps.best), fmt_time(ps.average)))
                else
                    rprint(id, fmt(MESSAGES.STATS_NO_LAPS, pname))
                end
            end
        end
    else
        local target_id = tonumber(target)
        local name
        if target_id and player_present(target_id) then
            name = get_var(target_id, "$name")
        else
            name = target
        end
        local ps = map_data[name]
        if ps then
            rprint(id, fmt(MESSAGES.STATS_PLAYER_LINE, name, fmt_time(ps.best), fmt_time(ps.average)))
        else
            rprint(id, fmt(MESSAGES.STATS_NO_RECORDS_FOR_PLAYER, name, current_map))
        end
    end
end

-- get race mode: 1 = sequential, 2 = non-sequential (any order)
local function get_race_mode()
    return NON_SEQUENTIAL_MODES[get_var(0, '$mode')] and 2 or 1
end

function OnScore(id)
    if not is_driver(id) then return end
    local player = players[id]
    if not player or not player.racing or not player.start_time then return end

    local lap_time = round_to_hundredths(os_clock() - player.start_time)
    update_stats(player, lap_time)

    setPlayerState(player, nil, nil, 0)
    player.just_completed_lap = true
end

-- monitor checkpoints, start/stop laps, show checkpoint times, and handle melee reset
function OnTick()
    ---@diagnostic disable-next-line: unnecessary-if
    if game_over then return end

    local now = os_clock()

    for id, player in pairs(players) do
        if player_present(id) and player_alive(id) then
            local checkpoint_mask = read_dword(player.checkpoint_addr)

            -- update cached mask and count if changed
            if checkpoint_mask ~= player.last_mask then
                player.last_mask = checkpoint_mask
                player.last_idx = get_checkpoint_idx(checkpoint_mask)
            end
            local current_idx = player.last_idx

            if race_mode == 1 then -- sequential mode (classic)
                if current_idx == 1 and not player.racing then
                    setPlayerState(player, true, now, 0)
                    if not player.just_completed_lap then
                        rprint(id, string_format(MESSAGES.LAP_STARTED, current_idx, race_checkpoint_count))
                    end
                    player.just_completed_lap = false
                elseif current_idx == 0 and player.racing then
                    setPlayerState(player, nil, nil, 0)
                    player.just_completed_lap = false
                end
            else -- mode == 2 (non-sequential: any checkpoint starts lap)
                if current_idx >= 1 and not player.racing then
                    setPlayerState(player, true, now, 0)
                    if not player.just_completed_lap then
                        rprint(id, string_format(MESSAGES.LAP_STARTED, current_idx, race_checkpoint_count))
                    end
                    player.just_completed_lap = false
                elseif current_idx == 0 and player.racing then
                    setPlayerState(player, nil, nil, 0)
                    player.just_completed_lap = false
                end
            end

            -- show checkpoint times if HUD enabled
            if SHOW_CHECKPOINT_HUD and player.racing and player.start_time then
                local elapsed = now - player.start_time
                if elapsed > 600 then -- 10 minute safety, something's broken
                    setPlayerState(player, nil, nil, 0)
                elseif current_idx > 1 and current_idx ~= player.last_checkpoint then
                    rprint(id, fmt(MESSAGES.CHECKPOINT_TIME, current_idx, race_checkpoint_count, fmt_time(elapsed)))
                    player.last_checkpoint = current_idx
                end
            end

            ---@diagnostic disable-next-line: unnecessary-if
            if ALLOW_MELEE_RESET then
                local dyn = get_dynamic_player(id)
                if dyn and dyn ~= 0 then
                    if melee_button_pressed(dyn) then
                        local cooldown = player.melee_reset_cooldown or 0
                        if now >= cooldown then
                            reset_checkpoint_progress(player, id)
                            player.melee_reset_cooldown = now + MELEE_RESET_COOLDOWN
                        else
                            local remaining = cooldown - now
                            rprint(id, fmt("Wait %.1f seconds to reset", remaining))
                        end
                    end
                end
            end
        end
    end
end

function OnStart()
    if get_var(0, '$gt') ~= 'race' then return end
    players = {}

    local checkpoint_mask = read_dword(race_globals)
    race_checkpoint_count = get_checkpoint_count(checkpoint_mask)

    race_mode = get_race_mode()
    current_map = get_var(0, "$map")
    game_over = false

    if not map_record_cache[current_map] then
        compute_map_records(current_map)
    end

    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnEnd()
    save_stats()

    ---@diagnostic disable-next-line: unnecessary-if
    if SHOW_TOP_AT_END_GAME then show_top() end

    game_over = true
end

function OnJoin(id)
    local name = get_var(id, "$name")
    local best_lap = math_huge
    local map_data = stats[current_map]

    ---@diagnostic disable-next-line: unnecessary-if
    if map_data and map_data[name] then
        best_lap = map_data[name].best
    end

    players[id] = {
        id = id,
        name = name,
        previous_time = 0,
        last_checkpoint = 0,
        best_lap = best_lap,
        just_completed_lap = false,

        ---@diagnostic disable-next-line: need-check-nil
        checkpoint_addr = race_globals + to_real_index(id) * 4 + 0x44,

        last_mask = 0,
        last_idx = 0,
        melee_reset_cooldown = 0
    }
end

function OnQuit(id)
    players[id] = nil
end

function OnCommand(id, command)
    if id == 0 then return end
    local args = split(command)
    if #args == 0 then return false end
    local cmd = args[1]
    if cmd == MAP_TOP_COMMAND then
        show_top(id, tonumber(args[2]) or 1)
        return false
    elseif cmd == STATS_COMMAND then
        show_stats(id, args[2] or tostring(id))
        return false
    elseif cmd == RESET_CHECKPOINT_COMMAND then
        reset_checkpoint_progress(players[id], id)
        return false
    end
end

function OnScriptLoad()
    race_globals = read_dword(sig_scan("BF??????00F3ABB952000000") + 0x1)

    local config_path = get_config_path()
    STATS_FILE = config_path .. "\\sapp\\" .. STATS_FILE

    local ok, json_module = pcall(dofile, "json.lua")
    if ok and type(json_module) == "table" then
        json = json_module
    else
        print("ERROR: Failed to load json.lua. Stats will not be saved/loaded.")
        json = nil
    end

    -- Load stats
    if json then
        stats = load_stats({})
    else
        stats = {}
    end

    for map_name, _ in pairs(stats) do
        compute_map_records(map_name)
    end

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
