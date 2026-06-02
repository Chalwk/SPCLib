--[[
============================================================================================
SCRIPT NAME:    rank_system.lua
DESCRIPTION:    This is a progression system that tracks kills, deaths,
                awards credits, and you advance through ranks & grades.

EARN CREDITS FROM:
                - First Blood (+20 cR)
                - Kill while dead (e.g., sticky) (+12 cR)
                - Roadkill (+15 cR)
                - Standard PvP kill (+15 cR)
                - Scoring events (CTF flag cap  +40 cR, race lap +8 cR)
                * Additional streak bonuses:
                  - 3 kills (+10 cR)
                  - 5 kills (+15 cR)
                  - 10 kills (+20 cR)
                  and higher streaks scale further.
                * Lose credits on suicide/betrayal/falling

RANKS: [ rank | grade threshold(s) ]
                - Recruit           |  0
                - Apprentice        |  3000, 6000
                - Private           |  9000, 12000
                - Corporal          |  13000, 14000
                - Sergeant          |  15000, 16000, 17000, 18000
                - Gunnery Sergeant  |  19000, 20000, 21000, 22000
                - Lieutenant        |  23000, 24000, 25000, 26000
                - Captain           |  27000, 28000, 29000, 30000
                - Major             |  31000, 32000, 33000, 34000
                - Commander         |  35000, 36000, 37000, 38000
                - Colonel           |  39000, 40000, 41000, 42000
                - Brigadier         |  43000, 44000, 45000, 46000
                - General           |  47000, 48000, 49000, 50000

COMMANDS:
                - /rank                            - Show your current rank and progress
                - /ranks                           - List all ranks and credit thresholds
                - /top                             - Show top 10 players
                - /setrank <id> <rank_id> <grade>  - admin only, self-explanatory

LAST UPDATED:   2 June 2026

Copyright (c) 2017-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
============================================================================================
]]

-- CONFIG START ------------------------------------------------------------------------------------------------

api_version = "1.12.0.0"

-- ========================= GENERAL SETTINGS =========================
local SAVE_FILE = "ranks.txt" -- DB file name
local SAVE_ON_LEAVE = false   -- Save stats when player leaves (true/false)
local SHOW_TOP_END = true     -- Show top players when game ends (true/false)
local SETRANK_ADMIN_LEVEL = 4 -- Permission level for /setrank
local TOP_PLAYERS_COUNT = 10  -- Number of top players to display in /top command

-- ========================= RANK CONFIG =========================
-- Format: { "Rank", { grade thresholds } }
local RANKS = {
    { "Recruit", { 0 } }, { "Apprentice", { 3000, 6000 } }, { "Private", { 9000, 12000 } },
    { "Corporal", { 13000, 14000 } }, { "Sergeant", { 15000, 16000, 17000, 18000 } },
    { "Gunnery Sergeant", { 19000, 20000, 21000, 22000 } }, { "Lieutenant", { 23000, 24000, 25000, 26000 } },
    { "Captain", { 27000, 28000, 29000, 30000 } }, { "Major", { 31000, 32000, 33000, 34000 } },
    { "Commander", { 35000, 36000, 37000, 38000 } }, { "Colonel", { 39000, 40000, 41000, 42000 } },
    { "Brigadier", { 43000, 44000, 45000, 46000 } }, { "General", { 47000, 48000, 49000, 50000 } }
}

-- ========================= KILL STREAK CONFIG  =========================
-- Milestones and corresponding bonus credits
-- Format: [streak] = bonus
local MILESTONES = { [3] = 10, [5] = 15, [10] = 20, [15] = 25, [20] = 30, [25] = 35, [30] = 40, [40] = 45, [50] = 50 }

-- ========================= KILL TYPE CREDITS CONFIG =========================
-- Each kill type maps to a single number:
-- positive -> awarded to the killer
-- negative -> deducted from the victim
-- zero     -> no effect
local KILL_CREDITS = {
    [1] = 20,  -- first blood
    [2] = 12,  -- kill someone while dead (i.e., w/sticky)
    [3] = 15,  -- run someone over
    [4] = 15,  -- pvp
    [5] = -8,  -- suicide
    [6] = -10, -- betrayal
    [7] = 0,   -- squashed
    [8] = -6,  -- falling/distance
    [9] = 0,   -- killed by server
    [10] = 0   -- generic/unknown death
}

-- ========================= SCORING CREDITS CONFIG =========================
-- Set credits to 0 to disable scoring
local SCORING_CREDITS = {
    ctf = 40,        -- flag capture (scoring player only - not whole team)
    race = 8,        -- lap complete
    king = { 0, 30 } -- KING format: credits, interval (award credits every interval)
}

local MESSAGES = {
    RANK_UP_HEADER = "=== RANK UP ===",
    RANK_UP = "%s: %s G%d",
    ---
    RANK_DOWN_HEADER = "=== RANK DOWN ===",
    RANK_DOWN = "%s: %s G%d",
    --
    KILL = "+%d cR",
    STREAK_SUFFIX = " + Streak",
    --
    RANK_HEADER = "=== Rank ===",
    RANK_CURRENT = "%s: G%d",
    RANK_CREDITS = "Credits: %d cR",
    RANK_STATS = "Kills: %d  Deaths: %d  K/D: %.2f",
    RANK_NEXT = "Next: %s: G%d in %d cR",
    --
    RANKS_HEADER = "=== Available Ranks ===",
    RANKS_LINE = "%d. %s: %s",
    RANK_MAX = "Maximum rank reached!",
    --
    NO_PERMISSION = "You do not have permission to use this command.",
    --
    TOP_HEADER = "=== Top %d ===",
    TOP_LINE = "%d. %s - %s - %s%d",
    --
    SET_RANK_HEADER = "Rank updated for %s",
    SET_RANK_INFO = "New Rank: %s, G%d",
    --
    CREDIT_CHANGE = "%+d cR",
    CREDIT_LOSS = "-%d cR",
    --
    WELCOME_MESSAGE_HEADER = "",
    WELCOME_MESSAGE = ""
}

-- ========================= NAME FILTERING =========================
-- Players with these names will NOT have their stats saved.
-- Set name to false (or remove it) to allow saving
local NAME_FILTER = {
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
    ["New001"] = true,
    ["Noodle"] = true,
    ["Nuevo"] = true,
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
    ["Wheezy"] = true,
    ["Whicker"] = true,
    ["Whisp"] = true,
    ["Wilshire"] = true
}
-- CONFIG END ------------------------------------------------------------------------------------------------

-- localized these for performance
local get_player = get_player
local read_word = read_word
local read_dword = read_dword
local lookup_tag = lookup_tag
local get_dynamic_player = get_dynamic_player
local get_var = get_var
local player_present = player_present
local player_alive = player_alive
local rprint = rprint
local cprint = cprint
local read_string = read_string

local io_open = io.open
local math_abs = math.abs
local math_min = math.min
local math_floor = math.floor
local string_format = string.format
local string_gmatch = string.gmatch
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local table_concat = table.concat

-- cached so I don't have to recompute abbreviations a million times -_-
local rank_abbrev_cache = {}
local players = {}           -- active players indexed by id

local stats_db = {}          -- persistent stats keyed by player name
local rank_lookup = {}       -- rank name -> index
local threshold_entries = {} -- all rank thresholds sorted

local game_over = nil
local first_blood_flag = true
local falling_tag_id = nil
local distance_tag_id = nil
local ffa_flag = false
local gametype = nil
local koth_globals, stats_globals

local KOTH_CREDITS = SCORING_CREDITS.king[1]
local KOTH_INTERVAL = SCORING_CREDITS.king[2]

local function is_filtered_name(name)
    return NAME_FILTER[name] == true
end

local function tokenize(str, delimiter)
    local args, n = {}, 0
    for token in string_gmatch(str, "([^" .. delimiter .. "]+)") do
        n = n + 1
        args[n] = token
    end
    return args
end

local function get_config_path()
    return read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
end

local function respond(id, msg)
    if id == 0 then
        cprint(msg) -- sapp terminal
    else
        rprint(id, msg)
    end
end

local function rprint_all(msg)
    for i = 1, 16 do
        if player_present(i) then
            rprint(i, msg)
        end
    end
end

local function is_admin(id)
    if id == 0 then return true end
    return tonumber(get_var(id, '$lvl')) >= SETRANK_ADMIN_LEVEL
end

-- default stats
local function default_stats()
    return { kills = 0, deaths = 0, credits = 0, rank = "Recruit", grade = 1 }
end

-- turns 1500 into "1.5k", 2300 into "2.3k", etc. looks cleaner on leaderboards (I think?)
local function format_credits(cr)
    if cr < 1000 then return tostring(cr) end
    local whole = math_floor(cr / 1000)
    local decimal = math_floor((cr % 1000) / 100)
    if decimal == 0 then return whole .. "k" end
    return whole .. "." .. decimal .. "k"
end

-- takes "Gunnery Sergeant" -> "GSe" or "Private" -> "Pri"
local function abbreviate_rank(rank_name)
    local words = tokenize(rank_name, "%s")
    if #words > 1 then
        local abbr = ""
        local limit = math_min(3, #words)
        for i = 1, limit do
            abbr = abbr .. words[i]:sub(1, 1)
        end
        return abbr
    else
        return rank_name:sub(1, 3)
    end
end

-- build sorted list of all grade thresholds for binary search later
local function build_rank_tables()
    local entry_count = 0
    for i, rank in ipairs(RANKS) do
        rank_lookup[rank[1]] = i
        local thresholds = rank[2]
        for grade = 1, #thresholds do
            entry_count = entry_count + 1
            threshold_entries[entry_count] = {
                credits = thresholds[grade],
                rank_name = rank[1],
                rank_index = i,
                grade = grade
            }
        end
    end
    table_sort(threshold_entries, function (a, b) return a.credits < b.credits end)
end

-- find highest rank threshold <= current credits (binary search)
local function find_threshold_index(credits)
    local entries = threshold_entries
    local lo, hi = 1, #entries
    local idx = 0
    while lo <= hi do
        local mid = math_floor((lo + hi) / 2)
        if entries[mid].credits <= credits then
            idx = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return idx
end

local function save_stats()
    local f = io_open(SAVE_FILE, "w")
    if not f then return end
    local write = f.write
    for name, s in pairs(stats_db) do
        if not is_filtered_name(name) and (s.kills > 0 or s.deaths > 0) then
            write(f, table_concat({ name, s.kills, s.deaths, s.credits, s.rank, s.grade }, ";") .. "\n")
        end
    end
    f:close()
end

local function load_stats()
    local f = io_open(SAVE_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local p = tokenize(line, ";")
        if #p >= 6 then
            stats_db[p[1]] = {
                kills = tonumber(p[2]) or 0,
                deaths = tonumber(p[3]) or 0,
                credits = tonumber(p[4]) or 0,
                rank = p[5],
                grade = tonumber(p[6]) or 1
            }
        end
    end
    f:close()
end

-- recalc player's rank based on credits, announce if changed
local function refresh_rank(pl, silent)
    local s = pl.stats
    local old_rank, old_grade = s.rank, s.grade

    local idx = find_threshold_index(s.credits)
    local best = threshold_entries[idx] or threshold_entries[1]
    if not best then return nil end

    s.rank = best.rank_name
    s.grade = best.grade

    if silent or (old_rank == s.rank and old_grade == s.grade) then return end

    local old_rank_index = rank_lookup[old_rank] or 0
    local promoted = (best.rank_index > old_rank_index) or (old_rank == s.rank and s.grade > old_grade)

    local is_promoted = promoted
    local header_line = is_promoted and MESSAGES.RANK_UP_HEADER or MESSAGES.RANK_DOWN_HEADER
    local rank_line = string_format(is_promoted and MESSAGES.RANK_UP or MESSAGES.RANK_DOWN, pl.name, s.rank, s.grade)

    for i = 1, 16 do
        if player_present(i) then
            rprint(i, header_line)
            rprint(i, rank_line)
        end
    end
end

local function get_current_streak(id)
    local player_ptr = get_player(id)
    if player_ptr == 0 then return 0 end
    return read_word(player_ptr + 0x98)
end

local function get_player_koth_hill_time(id)
    local stats_base = stats_globals + to_real_index(id) * 0x30
    return read_word(stats_base + 0x1E) -- whole seconds (cumulative, resets on quit, value is 0 on join)
end

local function get_tag_id(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function in_vehicle(id)
    local dyn = get_dynamic_player(id)
    return dyn ~= 0 and read_dword(dyn + 0x11C) ~= 0xFFFFFFFF
end

-- apply credit change for a kill, handle streak bonuses, update rank
local function apply_kill_credits(killer, victim, kill_type)
    local change = KILL_CREDITS[kill_type]
    if not change or change == 0 then return end

    local is_reward = change > 0
    local target = is_reward and killer or victim
    if not target then return end

    local amount = math_abs(change)
    if is_reward and killer then
        local streak = get_current_streak(killer.id)
        local streak_bonus = MILESTONES[streak]

        if streak_bonus then
            amount = amount + streak_bonus
            respond(killer.id, string_format(MESSAGES.KILL, streak_bonus) .. MESSAGES.STREAK_SUFFIX)
        end
    end

    local new_credits = target.stats.credits + (is_reward and amount or -amount)
    if not is_reward and new_credits < 0 then new_credits = 0 end
    target.stats.credits = new_credits

    if is_reward then
        respond(target.id, string_format(MESSAGES.CREDIT_CHANGE .. " (kill)", amount))
    else
        respond(target.id, string_format(MESSAGES.CREDIT_LOSS, amount))
    end

    refresh_rank(target, false)
end

local function reset_game_state()
    ffa_flag = get_var(0, "$ffa") == "1"
    falling_tag_id = get_tag_id('jpt!', 'globals\\falling')
    distance_tag_id = get_tag_id('jpt!', 'globals\\distance')
    first_blood_flag = true
    game_over = false
end

-- build leaderboard lines (top N players by credits)
local function get_top_leaderboard()
    local leaderboard = {}
    local count = 0
    for name, stats in pairs(stats_db) do
        count = count + 1
        leaderboard[count] = { name = name, stats = stats }
    end

    if count == 0 then
        return { string_format(MESSAGES.TOP_HEADER, 0) }
    end

    table_sort(leaderboard, function (a, b) return a.stats.credits > b.stats.credits end)

    local display_count = math_min(TOP_PLAYERS_COUNT, count)
    local lines = { string_format(MESSAGES.TOP_HEADER, display_count) }
    for i = 1, display_count do
        local entry = leaderboard[i]
        local s = entry.stats
        local credits_fmt = format_credits(s.credits)
        local rank_abbr = rank_abbrev_cache[s.rank] or abbreviate_rank(s.rank)
        lines[#lines + 1] = string_format(MESSAGES.TOP_LINE, i, entry.name, credits_fmt, rank_abbr, s.grade)
    end
    return lines
end

-- show top stats to a specific player or broadcast to all (end of game)
local function show_top_stats(id)
    local lines = get_top_leaderboard()
    if id then
        for i = 1, #lines do
            rprint(id, lines[i])
        end
    else
        for i = 1, #lines do
            rprint_all(lines[i])
        end
    end
end

-- show rank info for a player (target is active player table entry)
local function show_rank(id, target)
    if not target then
        respond(id, "Player data not available.")
        return
    end

    local s = target.stats
    local idx = find_threshold_index(s.credits)
    local next_rank = threshold_entries[idx + 1] -- nil if at max
    if not next_rank then return end

    respond(id, MESSAGES.RANK_HEADER)
    respond(id, string_format(MESSAGES.RANK_CURRENT, s.rank, s.grade))
    respond(id, string_format(MESSAGES.RANK_CREDITS, s.credits))

    local kd = s.deaths > 0 and s.kills / s.deaths or s.kills
    respond(id, string_format(MESSAGES.RANK_STATS, s.kills, s.deaths, kd))

    if next_rank then
        local msg = MESSAGES.RANK_NEXT
        respond(id, string_format(msg, next_rank.rank_name, next_rank.grade, next_rank.credits - s.credits))
    else
        respond(id, MESSAGES.RANK_MAX)
    end
end

function OnJoin(id)
    local name = get_var(id, "$name")
    local stats = stats_db[name]
    if not stats then
        stats = default_stats()
        stats_db[name] = stats
    end

    local new_player = {
        id = id,
        name = name,
        stats = stats,
        team = get_var(id, '$team'),
        switched = nil,
        last_damage = nil,
        last_hill_award_time = 0
    }

    players[id] = new_player
    refresh_rank(new_player, true)

    if MESSAGES.WELCOME_MESSAGE_HEADER ~= "" and MESSAGES.WELCOME_MESSAGE ~= "" then
        rprint(id, MESSAGES.WELCOME_MESSAGE_HEADER)
        rprint(id, MESSAGES.WELCOME_MESSAGE)
    end
end

function OnLeave(id)
    if SAVE_ON_LEAVE then save_stats() end
    players[id] = nil
end

-- track last damage source for falling/distance
function OnDamage(victim, _, meta_id)
    victim = players[victim]
    if not victim then return end
    victim.last_damage = meta_id
end

function OnDeath(victim, killer)
    killer = tonumber(killer) -- killer id comes as string

    local victim_data = players[victim]
    if not victim_data then return end

    local killer_data = killer and players[killer] or nil
    local kill_type = 10

    -- figure out what kind of death this is
    if killer == -1 and not victim_data.switched then -- server kill (falling, distance, etc)
        local last = victim_data.last_damage
        kill_type = (last == falling_tag_id or last == distance_tag_id) and 8 or 9
    elseif killer == 0 then
        kill_type = 7 -- squashed by unoccupied vehicle
    elseif killer and killer > 0 then
        if killer == victim then
            kill_type = 5 -- suicide
        elseif not ffa_flag and killer_data and victim_data.team == killer_data.team then
            kill_type = 6 -- betrayal
        elseif first_blood_flag then
            first_blood_flag, kill_type = false, 1
        elseif not player_alive(killer) then
            kill_type = 2 -- killed from grave (post-death sticky etc)
        elseif in_vehicle(victim) then
            kill_type = 3 -- roadkill
        else
            kill_type = 4 -- pvp
        end
    end

    victim_data.stats.deaths = victim_data.stats.deaths + 1
    if killer_data and killer > 0 and killer ~= victim then
        killer_data.stats.kills = killer_data.stats.kills + 1
    end

    apply_kill_credits(killer_data, victim_data, kill_type)
    refresh_rank(victim_data, false)
end

function OnCommand(id, cmd)
    local args = tokenize(cmd, " ")
    if not args then return false end

    local c = (args[1] or ""):lower()

    if c == "rank" then
        show_rank(id, players[id])
        return false
    elseif c == "ranks" then
        respond(id, MESSAGES.RANKS_HEADER)
        for i, rank in ipairs(RANKS) do
            respond(id, string_format(MESSAGES.RANKS_LINE, i, rank[1], table_concat(rank[2], ", ")))
        end
        return false
    elseif c == "top" then
        show_top_stats(id)
        return false
    elseif c == "setrank" then
        if not is_admin(id) then
            respond(id, MESSAGES.NO_PERMISSION)
            return false
        end

        if not args[2] or not args[3] or not args[4] then
            respond(id, "Usage: /setrank <id> <rank> <grade>")
            return false
        end

        local target_id = tonumber(args[2])
        if not target_id then
            respond(id, "Player ID must be a number!")
            return false
        end

        local target = players[target_id]
        if not target then
            respond(id, "Player not found or not online.")
            return false
        end

        local rid = tonumber(args[3])
        if not rid then
            respond(id, "Rank ID must be a number!")
            return false
        end
        if rid < 1 or rid > #RANKS then
            respond(id, "Valid Rank IDs are 1-" .. #RANKS)
            return false
        end

        local grade = tonumber(args[4])
        if not grade then
            respond(id, "Grade must be a number.")
            return false
        end
        if grade < 1 or grade > #RANKS[rid][2] then
            respond(id, "Valid grades: 1-" .. #RANKS[rid][2])
            return false
        end

        target.stats.credits = RANKS[rid][2][grade]
        refresh_rank(target, false)
        save_stats()

        respond(id, string_format(MESSAGES.SET_RANK_HEADER, target.name))
        respond(id, string_format(MESSAGES.SET_RANK_INFO, RANKS[rid][1], grade))
        return false
    end
end

function OnGameEnd()
    game_over = true
    save_stats()
    if SHOW_TOP_END then show_top_stats() end
end

function OnSwitch(id)
    local player = players[id]
    if not player then return end
    player.team = get_var(id, '$team')
    player.switched = true
end

function OnSpawn(id)
    local player = players[id]
    if not player then return end
    player.last_damage = nil
    player.switched = nil
end

function OnScore(id) -- supports ctf/race
    local player = players[id]
    if not player then return end

    local reward = SCORING_CREDITS[gametype]
    if not reward or reward == 0 then return end

    player.stats.credits = player.stats.credits + reward
    refresh_rank(player, false)
    respond(id, string_format(MESSAGES.CREDIT_CHANGE .. " (score)", reward))
end

function KothTimer()
    if game_over then return false end

    for i = 1, 16 do
        local pl = players[i]
        if pl and player_present(i) and player_alive(i) then
            local hill_time = get_player_koth_hill_time(i)
            if hill_time == 0 then goto next end
            local last = pl.last_hill_award_time or 0

            local intervals = math_floor((hill_time - last) / KOTH_INTERVAL)
            if intervals > 0 then
                local award = intervals * KOTH_CREDITS
                pl.stats.credits = pl.stats.credits + award
                pl.last_hill_award_time = last + (intervals * KOTH_INTERVAL)
                refresh_rank(pl, false)
                respond(pl.id, string_format(MESSAGES.CREDIT_CHANGE, award) .. " (hill)")
            end
        end
        ::next::
    end
    return true
end

function OnStart()
    gametype = get_var(0, "$gt")
    if gametype == "n/a" then return end

    reset_game_state()
    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end

    if KOTH_CREDITS > 0 and gametype == "king" then
        timer(1000, "KothTimer")
    end
end

-- resolve SAPP directory (root path where mapcycle.txt is), init caches, load stats
function OnScriptLoad()
    local config_path = get_config_path()
    SAVE_FILE = config_path .. "\\sapp\\" .. SAVE_FILE

    for _, rank_entry in ipairs(RANKS) do
        local rank_name = rank_entry[1]
        rank_abbrev_cache[rank_name] = abbreviate_rank(rank_name)
    end

    build_rank_tables()
    load_stats()

    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_DIE, "OnDeath")
    register_callback(cb.EVENT_SCORE, "OnScore")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_TEAM_SWITCH, 'OnSwitch')
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")

    koth_globals = read_dword(sig_scan("BF??????00F3ABB96B000000") + 0x1)
    stats_globals = read_dword(sig_scan("33C0BF??????00F3AB881D") + 0x3)

    OnStart() -- in case script is loaded mid-game
end

function OnScriptUnload()
    save_stats()
end
