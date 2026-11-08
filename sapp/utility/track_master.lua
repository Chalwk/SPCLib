--[[
===============================================================================
SCRIPT NAME:    track_master.lua
DESCRIPTION:    Advanced racing tracker and leaderboard system with:

                - Lap timing with checkpoint validation (sequential/non-sequential)
                - Personal bests, map records, per-map stats (laps, best, average)
                - Session bests and lap counters
                - Announcements: personal bests, map records, checkpoint times

COMMANDS:       - /stats [name|id|all]   - personal stats on current map
                - /top [page]            - top laps on current map
                - /reset                 - reset checkpoint progress
                                           OR: Press melee key while in a vehicle.
                - /raceinfo              - show current race mode and checkpoints

REQUIRED:       * Lua JSON Parser: http://regex.info/blog/lua/json
                  Place json.lua in the same directory as sapp.dll

LAST UPDATED:     2026-11-08

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
local RACE_INFO_COMMAND = "raceinfo"
local TOP_PAGE_SIZE = 10
local DRIVER_REQUIRED = true
local SHOW_TOP_AT_END_GAME = true
local SHOW_CHECKPOINT_HUD = true
local SHOW_RACE_MODE_AT_START = true
local SAVE_AFTER_EACH_LAP = true
local ALLOW_MELEE_RESET = true
local MELEE_RESET_COOLDOWN = 3.0
local MAX_LAP_SECONDS = 600
local NON_SEQUENTIAL_MODES = { ["EXAMPLE_ORDER_GAMEMODE"] = true, ["ANOTHER"] = true }

local MESSAGES = {
    NEW_MAP_RECORD              = "NEW MAP RECORD: [%s - %s]",
    NEW_PERSONAL_BEST           = "NEW PERSONAL BEST: [%s - %s]",
    LAP_COMPLETED_FILTERED      = "Lap completed: %s (Stats N/A - Filtered Name)",
    LAP_COMPLETED_WITH_BEST     = "Lap completed: %s (Best: %s | %s)",
    NO_RECORDS                  = "No records for this map yet",
    TOP_HEADER                  = "Top players for %s",
    TOP_ENTRY                   = "%d. %s - %s",
    TOP_NEXT_PAGE_HINT          = "[Page %d/%d] - Use '/top %d' for next page",
    STATS_PLAYER_LINE           = "%s: Best [%s], Avg [%s]",
    STATS_NO_LAPS               = "%s: No laps recorded",
    STATS_NO_RECORDS_FOR_PLAYER = "No records found for %s on %s",
    LAP_STARTED                 = "LAP STARTED - CHECKPOINT %d-%d",
    CHECKPOINT_TIME             = "CHECKPOINT %d-%d - [%s]",
    RESET_SEQUENTIAL            = "Lap progress reset. Start a new lap from the first checkpoint",
    RESET_NONSEQUENTIAL         = "Lap progress reset. Start a new lap from any checkpoint",
    RACE_INFO                   = "Race mode: %s, %d checkpoints",
    STATS_SAVED_WARN            = "WARNING: could not save stats. Check sapp/race_stats.json",
    JSON_MISSING                = "ERROR: json.lua not found. Stats will not persist."
}

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
local read_byte = read_byte
local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local rprint = rprint
local get_object_memory = get_object_memory
local get_dynamic_player = get_dynamic_player
local to_real_index = to_real_index
local read_string = read_string
local sig_scan = sig_scan

local race_globals, gametype_base
local race_mode, game_over
local race_checkpoint_count
local race_type_name
local map_record_cache = {}
local players, stats = {}, {}
local current_map = ""
local json
local stats_file_path = STATS_FILE

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

local function safeScan(sig, offset)
    local hit = sig_scan(sig)
    if hit == 0 then return nil end
    local ptr = read_dword(hit + offset)
    if not ptr or ptr < 0x400000 or ptr > 0x800000 then return nil end
    return ptr
end

local function getConfigPath()
    local path = safeScan('68??????008D54245468', 0x1)
    if not path then return nil end
    return read_string(path)
end

local function getCheckpointCount(mask)
    local count = 0
    while mask ~= 0 do
        mask = bit_band(mask, mask - 1)
        count = count + 1
    end
    return count
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
    if time == 0 or time == math_huge or time == nil then
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
    local file = io_open(stats_file_path, "r")
    if not file then return default end
    local content = file:read("*a")
    file:close()
    if content == "" then return default end
    local success, data = pcall(json.decode, json, content)
    return success and data or default
end

local function save_stats()
    if not json then return false end
    local file = io_open(stats_file_path, "w")
    if not file then return false end
    local ok = pcall(function () file:write(json:encode(stats)) end)
    file:close()
    return ok
end

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

local function is_driver(id)
    if not DRIVER_REQUIRED then return true end
    if not player_alive(id) then return false end
    local dyn = get_dynamic_player(id)
    if dyn == 0 then return false end
    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return false end
    local vehicle_obj = get_object_memory(vehicle_id)
    if vehicle_obj == 0 then return false end
    -- Seat 0 is the driver for all Halo vehicles.
    return read_word(dyn + 0x2F0) == 0
end

local function melee_button_pressed(dyn)
    if read_dword(dyn + 0x11C) == 0xFFFFFFFF then return false end
    return bit_band(read_word(dyn + 0x208), 128) ~= 0
end

local function read_checkpoint_mask(player)
    if not player.checkpoint_addr then return 0 end
    return read_dword(player.checkpoint_addr) or 0
end

local function write_checkpoint_mask(player, value)
    if not player.checkpoint_addr then return end
    write_dword(player.checkpoint_addr, value)
end

local function set_player_state(player, racing, start_time, last_checkpoint)
    player.racing = racing
    player.start_time = start_time
    player.last_checkpoint = last_checkpoint
end

local function reset_checkpoint_progress(player, id)
    if not player then return end
    write_checkpoint_mask(player, 0)
    set_player_state(player, nil, nil, 0)
    player.last_mask = 0
    player.last_idx = 0
    player.just_completed_lap = false
    rprint(id, race_mode == 1 and MESSAGES.RESET_SEQUENTIAL or MESSAGES.RESET_NONSEQUENTIAL)
end

local function get_race_mode()
    if gametype_base and gametype_base ~= 0 then
        local race_type = read_byte(gametype_base + 0x7C)
        if race_type == 1 then
            race_type_name = "Any Order"
            return 2
        elseif race_type == 2 then
            race_type_name = "Rally"
            return 1
        elseif race_type == 0 then
            race_type_name = "Normal"
            return 1
        end
    end
    if NON_SEQUENTIAL_MODES[get_var(0, '$mode')] then
        race_type_name = get_var(0, '$mode')
        return 2
    end
    race_type_name = race_type_name or "Normal"
    return 1
end

-- Record a completed lap, update personal best, map record, averages, announce.
local function update_stats(player, lap_time)
    local id = player.id
    local name = player.name
    if is_filtered_name(name) then
        rprint(id, fmt(MESSAGES.LAP_COMPLETED_FILTERED, fmt_time(lap_time)))
        return
    end

    if not stats[current_map] then
        stats[current_map] = {}
    end
    local map_stats = stats[current_map]
    if not map_stats then return end

    local player_stats = map_stats[name]
    local old_laps = player_stats and player_stats.laps or 0
    local new_laps = old_laps + 1
    local old_best = player_stats and player_stats.best or math_huge

    local is_personal_best = lap_time < old_best
    local is_session_best = lap_time < (player.session_best or math_huge)

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

    -- Update best/laps/average
    local new_best = math_min(old_best, lap_time)
    local new_average
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
    if is_session_best then
        player.session_best = lap_time
    end
    player.session_laps = (player.session_laps or 0) + 1

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

    if SAVE_AFTER_EACH_LAP then
        if not save_stats() then
            rprint(id, MESSAGES.STATS_SAVED_WARN)
        end
    end
end

local function split(input)
    local result = {}
    for substring in gmatch(input, "%S+") do
        result[#result + 1] = substring
    end
    return result
end

local function show_top(id, page)
    local send
    if id and id ~= 0 then
        send = function (msg) rprint(id, msg) end
    else
        send = rprint_all
    end

    local map_data = stats[current_map]
    if not map_data then
        send(MESSAGES.NO_RECORDS)
        return
    end

    local entries = {}
    for name, ps in pairs(map_data) do
        if not is_filtered_name(name) and ps.best then
            table_insert(entries, { name = name, best_lap = ps.best })
        end
    end
    if #entries == 0 then
        send(MESSAGES.NO_RECORDS)
        return
    end

    table_sort(entries, function (a, b) return a.best_lap < b.best_lap end)
    local start_idx, end_idx, total_pages, cur_page = get_pagination_indices(page, #entries, TOP_PAGE_SIZE)
    send(fmt(MESSAGES.TOP_HEADER, current_map))
    for i = start_idx, end_idx do
        local entry = entries[i]
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
                local ps = map_data[pdata.name]
                if ps then
                    rprint(id, fmt(MESSAGES.STATS_PLAYER_LINE, pdata.name, fmt_time(ps.best), fmt_time(ps.average)))
                else
                    rprint(id, fmt(MESSAGES.STATS_NO_LAPS, pdata.name))
                end
            end
        end
        return
    end

    local name
    local target_id = tonumber(target)
    if target_id and player_present(target_id) then
        name = get_var(target_id, "$name")
    else
        name = target
    end
    if not name or name == "" then
        rprint(id, "Usage: /stats [name|id|all]")
        return
    end

    local ps = map_data[name]
    if ps then
        rprint(id, fmt(MESSAGES.STATS_PLAYER_LINE, name, fmt_time(ps.best), fmt_time(ps.average)))
    else
        rprint(id, fmt(MESSAGES.STATS_NO_RECORDS_FOR_PLAYER, name, current_map))
    end
end

function OnScore(id)
    if not is_driver(id) then return end
    local player = players[id]
    if not player or not player.racing or not player.start_time then return end

    local lap_time = round_to_hundredths(os_clock() - player.start_time)
    update_stats(player, lap_time)

    set_player_state(player, nil, nil, 0)
    player.just_completed_lap = true
end

function OnTick()
    if game_over then return end
    if not race_globals or race_globals == 0 then return end

    local now = os_clock()

    for id, player in pairs(players) do
        if player.checkpoint_addr and player_present(id) and player_alive(id) then
            local checkpoint_mask = read_checkpoint_mask(player)

            if checkpoint_mask ~= player.last_mask then
                player.last_mask = checkpoint_mask
                player.last_idx = get_checkpoint_idx(checkpoint_mask)
            end
            local current_idx = player.last_idx

            local lap_started = false
            if race_mode == 1 then
                lap_started = (current_idx == 1)
            else
                lap_started = (current_idx >= 1)
            end

            if lap_started and not player.racing then
                set_player_state(player, true, now, 0)
                if not player.just_completed_lap then
                    rprint(id, string_format(MESSAGES.LAP_STARTED, current_idx, race_checkpoint_count))
                end
                player.just_completed_lap = false
            elseif current_idx == 0 and player.racing then
                set_player_state(player, nil, nil, 0)
                player.just_completed_lap = false
            end

            if SHOW_CHECKPOINT_HUD and player.racing and player.start_time then
                local elapsed = now - player.start_time
                if elapsed > MAX_LAP_SECONDS then
                    set_player_state(player, nil, nil, 0)
                elseif current_idx > 1 and current_idx ~= player.last_checkpoint then
                    rprint(id, fmt(MESSAGES.CHECKPOINT_TIME, current_idx, race_checkpoint_count, fmt_time(elapsed)))
                    player.last_checkpoint = current_idx
                end
            end

            -- Melee reset
            if ALLOW_MELEE_RESET then
                local dyn = get_dynamic_player(id)
                if dyn and dyn ~= 0 and melee_button_pressed(dyn) then
                    local cooldown = player.melee_reset_cooldown or 0
                    if now >= cooldown then
                        reset_checkpoint_progress(player, id)
                        player.melee_reset_cooldown = now + MELEE_RESET_COOLDOWN
                    else
                        rprint(id, fmt("Wait %.1f seconds to reset", cooldown - now))
                    end
                end
            end
        end
    end
end

function OnStart()
    if get_var(0, '$gt') ~= 'race' then return end
    if not race_globals or race_globals == 0 then return end

    players = {}
    game_over = false

    local checkpoint_mask = read_dword(race_globals)
    race_checkpoint_count = getCheckpointCount(checkpoint_mask)

    race_mode = get_race_mode()
    current_map = get_var(0, "$map")

    if not map_record_cache[current_map] then
        compute_map_records(current_map)
    end

    if SHOW_RACE_MODE_AT_START then
        rprint_all(fmt(MESSAGES.RACE_INFO, race_type_name or "Normal", race_checkpoint_count))
    end

    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnEnd()
    save_stats()
    if SHOW_TOP_AT_END_GAME then show_top(0, 1) end
    game_over = true
end

function OnJoin(id)
    local name = get_var(id, "$name")
    local best_lap = math_huge
    local map_data = stats[current_map]
    if map_data and map_data[name] then
        best_lap = map_data[name].best
    end

    local checkpoint_addr = nil
    if race_globals and race_globals ~= 0 then
        checkpoint_addr = race_globals + to_real_index(id) * 4 + 0x44
    end

    players[id] = {
        id                   = id,
        name                 = name,
        previous_time        = 0,
        last_checkpoint      = 0,
        best_lap             = best_lap,
        just_completed_lap   = false,
        checkpoint_addr      = checkpoint_addr,
        last_mask            = 0,
        last_idx             = 0,
        melee_reset_cooldown = 0,
        session_best         = math_huge,
        session_laps         = 0
    }

    if checkpoint_addr then
        write_dword(checkpoint_addr, 0)
    end
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
    elseif cmd == RACE_INFO_COMMAND then
        rprint(id, fmt(MESSAGES.RACE_INFO, race_type_name or "Normal", race_checkpoint_count or 0))
        return false
    end
end

function OnScriptLoad()
    race_globals = safeScan("BF??????00F3ABB952000000", 0x1) or (halo_type == 'PC' and 0x639F80 or 0x5BDFA0)
    gametype_base = safeScan("B9360000008BF3BF????????", 0x8) or (halo_type == 'PC' and 0x671320 or 0x5F5478)

    local config_path = getConfigPath()
    if config_path and config_path ~= "" then
        stats_file_path = config_path .. "\\" .. STATS_FILE
    end

    local ok, json_module = pcall(dofile, "json.lua")
    if ok and type(json_module) == "table" then
        json = json_module
        stats = load_stats({})
        for map_name in pairs(stats) do
            compute_map_records(map_name)
        end
    else
        print(MESSAGES.JSON_MISSING)
        json = nil
        stats = {}
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
