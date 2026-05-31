--[[
=====================================================================================
SCRIPT NAME:      rank_system.lua
DESCRIPTION:      Rank progression system. Tracks kills, deaths, awards credits,
                  and advances through ranks/grades.

                  Stats are saved when the game ends, and optionally when a
                  player leaves.

                  Commands:
                    /rank      - Show your current rank and progress
                    /ranks     - List all ranks and credit thresholds
                    /top       - Show top players by credits
                    /setrank <id> <rank_id> <grade> - admin only

Copyright (c) 2017-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START -------------------------------------------------------------------

api_version = "1.12.0.0"

-- ========================= GENERAL SETTINGS =========================
local SAVE_FILE = "ranks.txt" -- DB file name
local SAVE_ON_LEAVE = false   -- Save stats when player leaves (true/false)
local SHOW_TOP_END = true     -- Show top players when game ends (true/false)
local COMMAND_PERM_LEVEL = 4  -- Permission level for /setrank
local TOP_PLAYERS_COUNT = 10  -- Number of top players to display in /top command
local MSG_PREFIX = ""         -- Prefix removed temporarily; restored to this after msg relay.

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
    [7] = -8,  -- squashed
    [8] = -6,  -- falling/distance
    [9] = 0,   -- killed by server
    [10] = -5  -- generic/unknown death
}

-- ========================= MESSAGES =========================
local MESSAGES = {
    RANK_UP = "RANK UP - %s: %s G%d",
    RANK_DOWN = "RANK DOWN - %s: %s G%d",
    KILL = "+%d cR (Kill)",
    STREAK_SUFFIX = " + Streak",
    RANK_HEADER = "=== Rank ===",
    RANK_CURRENT = "%s: G%d",
    RANK_CREDITS = "Credits: %d cR",
    RANK_STATS = "Kills: %d  Deaths: %d  K/D: %.2f",
    RANK_NEXT = "Next: %s: G%d in %d cR",
    RANKS_HEADER = "=== Available Ranks ===",
    RANKS_LINE = "%d. %s: [%s]",
    RANK_MAX = "Maximum rank reached!",
    NO_PERMISSION = "You do not have permission to use this command.",
    TOP_HEADER = "=== Top %d Players ===",
    TOP_LINE = "%d. %s | K/D: %.2f | cR: %d | %s G%d",
    SET_RANK_HEADER = "Rank updated for %s",
    SET_RANK_INFO = "New Rank: %s, G%d",
    CREDIT_CHANGE = "%+d cR (%s)",
    CREDIT_LOSS = "-%d cR lost (%s)",
    WELCOME_MESSAGE_HEADER = "",
    WELCOME_MESSAGE = ""
}
-- CONFIG END -------------------------------------------------------------------

local players = {}
local stats_db = {}
local rank_lookup = {}
local threshold_entries = {}

local first_blood_flag = true
local falling_tag_id = nil
local distance_tag_id = nil
local ffa_flag = false

local io_open = io.open
local math_min = math.min
local string_format = string.format
local string_gmatch = string.gmatch
local tonumber = tonumber
local pairs, ipairs = pairs, ipairs
local table_sort = table.sort
local table_concat = table.concat

local function default_stats()
    return { kills = 0, deaths = 0, credits = 0, rank = "Recruit", grade = 1 }
end

local function tokenize(str, delimiter)
    local args, n = {}, 0
    for token in string_gmatch(str, "([^" .. delimiter .. "]+)") do
        n = n + 1
        args[n] = token
    end
    return args
end

local function respond(id, msg)
    if id == 0 then return cprint(msg) end
    rprint(id, msg)
end

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

local function find_rank(credits)
    local entries = threshold_entries
    local best = entries[1]
    for i = 1, #entries do
        local entry = entries[i]
        if credits >= entry.credits then
            best = entry
        else
            break
        end
    end
    return best
end

local function find_next_threshold(credits)
    local entries = threshold_entries
    for i = 1, #entries do
        local entry = entries[i]
        if entry.credits > credits then
            return entry
        end
    end
end

local function save_stats()
    local f = io_open(SAVE_FILE, "w")
    if not f then return end

    local write = f.write
    for name, s in pairs(stats_db) do
        write(f, table_concat({ name, s.kills, s.deaths, s.credits, s.rank, s.grade }, ";") .. "\n")
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

local function refresh_rank(pl, silent)
    local s = pl.stats
    local old_rank, old_grade = s.rank, s.grade

    local best = find_rank(s.credits)
    s.rank = best.rank_name
    s.grade = best.grade

    if silent or (old_rank == s.rank and old_grade == s.grade) then return end

    local old_rank_index = rank_lookup[old_rank] or 0
    local promoted = (best.rank_index > old_rank_index) or (old_rank == s.rank and s.grade > old_grade)

    local msg = string_format(promoted and MESSAGES.RANK_UP or MESSAGES.RANK_DOWN, pl.name, s.rank, s.grade)
    execute_command('msg_prefix ""')
    say_all(msg)
    execute_command('msg_prefix "' .. MSG_PREFIX .. '"')
end

local function get_current_streak(id)
    local player_ptr = get_player(id)
    if player_ptr == 0 then return 0 end
    return read_word(player_ptr + 0x98)
end

local function get_tag_id(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function in_vehicle(id)
    local dyn = get_dynamic_player(id)
    return dyn ~= 0 and read_dword(dyn + 0x11C) ~= 0xFFFFFFFF
end

local function apply_kill_credits(killer, victim, kill_type)
    local change = KILL_CREDITS[kill_type]
    if not change or change == 0 then return end

    -- Determine who gets the change
    local is_reward = change > 0
    local target = is_reward and killer or victim
    if not target then return end

    -- Apply streak bonus only if the killer is receiving a positive reward
    local amount = math.abs(change)
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
        respond(target.id, string_format(MESSAGES.CREDIT_CHANGE, amount, "Kill"))
    else
        respond(target.id, string_format(MESSAGES.CREDIT_LOSS, amount, "Death"))
    end

    refresh_rank(target, false)
end

local function reset_game_state()
    ffa_flag = get_var(0, "$ffa") == "1"
    falling_tag_id = get_tag_id('jpt!', 'globals\\falling')
    distance_tag_id = get_tag_id('jpt!', 'globals\\distance')
    first_blood_flag = true
end

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

    table_sort(leaderboard, function (a, b)
        return a.stats.credits > b.stats.credits
    end)

    local display_count = math_min(TOP_PLAYERS_COUNT, count)
    local lines = { string_format(MESSAGES.TOP_HEADER, display_count) }

    for i = 1, display_count do
        local entry = leaderboard[i]
        local s = entry.stats
        local kd = s.deaths > 0 and s.kills / s.deaths or s.kills
        lines[#lines + 1] = string_format(MESSAGES.TOP_LINE, i, entry.name, kd, s.credits, s.rank, s.grade)
    end

    return lines
end

local function show_top_stats(id)
    execute_command('msg_prefix ""')
    local lines = get_top_leaderboard()
    for _, line in ipairs(lines) do
        if not id then
            say_all(line)
        else
            respond(id, line)
        end
    end
    execute_command('msg_prefix "' .. MSG_PREFIX .. '"')
end

function OnJoin(id)
    local name = get_var(id, "$name")
    local stats = stats_db[name]
    if not stats then
        stats = default_stats()
        stats_db[name] = stats
    end

    local player = {
        id = id,
        name = name,
        stats = stats,
        team = get_var(id, '$team'),
        switched = nil,
        last_damage = nil
    }

    players[id] = player
    refresh_rank(player, true)

    if MESSAGES.WELCOME_MESSAGE_HEADER == "" or MESSAGES.WELCOME_MESSAGE == "" then return end
    rprint(id, MESSAGES.WELCOME_MESSAGE_HEADER)
    rprint(id, MESSAGES.WELCOME_MESSAGE)
end

function OnLeave(id)
    if SAVE_ON_LEAVE then save_stats() end
    players[id] = nil
end

function OnDamage(victim_id, _, meta_id)
    local victim = players[tonumber(victim_id)]
    if victim then
        victim.last_damage = meta_id
    end
end

function OnDeath(victim_id, killer_id)
    local victim = tonumber(victim_id)
    local killer = tonumber(killer_id)

    local victim_data = players[victim]
    if not victim_data then return end

    local killer_data = killer and players[killer] or nil
    local kill_type = 10

    if killer == -1 and not victim_data.switched then -- server or falling/distance
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
            kill_type = 2 -- killed from grave
        elseif in_vehicle(victim) then
            kill_type = 3 -- run someone over
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

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    reset_game_state()
    for i = 1, 16 do -- in case script is loaded mid-game
        if player_present(i) then
            OnJoin(i)
        end
    end
end

local function show_rank(id, target)
    if not target then
        respond(id, "Player data not available.")
        return
    end

    local s = target.stats
    local next_rank = find_next_threshold(s.credits)

    respond(id, MESSAGES.RANK_HEADER)
    respond(id, string_format(MESSAGES.RANK_CURRENT, s.rank, s.grade))
    respond(id, string_format(MESSAGES.RANK_CREDITS, s.credits))

    local kd = s.deaths > 0 and s.kills / s.deaths or s.kills
    respond(id, string_format(MESSAGES.RANK_STATS, s.kills, s.deaths, kd))

    if next_rank then
        respond(
            id, string_format(MESSAGES.RANK_NEXT, next_rank.rank_name, next_rank.grade, next_rank.credits - s.credits)
        )
    else
        respond(id, MESSAGES.RANK_MAX)
    end
end

local function is_admin(id)
    if id == 0 then return true end
    return tonumber(get_var(id, '$lvl')) >= COMMAND_PERM_LEVEL
end

local function setrank_usage(id, msg)
    if msg then respond(id, msg) end
    respond(id, "Usage: /setrank <id> <rank> <grade>")
    return false
end

function OnCommand(id, cmd)
    local args = tokenize(cmd, " ")
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

        local target = players[tonumber(args[2])]
        if not target then
            return setrank_usage(id, "Invalid player ID.")
        end

        local rid = tonumber(args[3])
        if not rid or rid < 1 or rid > #RANKS then
            return setrank_usage(id, "Invalid rank ID.")
        end

        local grade = tonumber(args[4])
        if not grade or grade < 1 or grade > #RANKS[rid][2] then
            return setrank_usage(id, "Invalid grade ID.")
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
    save_stats()
    if SHOW_TOP_END then
        show_top_stats()
    end
end

function OnSwitch(id)
    local player = players[id]
    if player then
        player.team, player.switched = get_var(id, '$team'), true
    end
end

function OnSpawn(id)
    local player = players[id]
    if player then
        player.last_damage, player.switched = nil, nil
    end
end

function OnScriptLoad()
    local sapp_dir = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    SAVE_FILE = sapp_dir .. "\\sapp\\" .. SAVE_FILE

    build_rank_tables()
    load_stats()

    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_DIE, "OnDeath")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_TEAM_SWITCH, 'OnSwitch')
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")

    OnStart()
end

function OnScriptUnload()
    save_stats()
end
