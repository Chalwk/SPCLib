--[[
=====================================================================================
SCRIPT NAME:      rank_system.lua
DESCRIPTION:      Rank progression system. Tracks kills, deaths, awards credits,
                  and advances through ranks/grades.

                  Commands
                    /rank      - Show your current rank and progress
                    /ranks     - List all ranks and credit thresholds
                    /top       - Show your own stats (client-only)
                    /setrank <rank_id> <grade>

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
================================================================================================
]]


-- ======================== CONFIG START ======================== --
clua_version = 2.056

local CONFIG = {
    SAVE_FILE = "rank_system.dat", -- (appears in Halo install root directory)
    SYMBOL = "cR",
    CREDITS_PER_KILL = 10,
    MESSAGES = {
        RANK_UP = "Rank Up! %s Grade %d",
        RANK_DOWN = "Rank Down: %s Grade %d",
        KILL = "+%d %s (Kill)",
        STREAK_SUFFIX = " + Streak",
        RANK_HEADER = "=== Your Rank ===",
        RANK_CURRENT = "%s Grade %d",
        RANK_CREDITS = "Credits: %d %s",
        RANK_STATS = "Kills: %d  Deaths: %d  K/D: %.2f",
        RANK_NEXT = "Next: %s Grade %d in %d %s",
        RANK_MAX = "Maximum rank reached!",
        RANKS_HEADER = "=== Available Ranks ===",
        RANKS_LINE = "%d. %s: [%s]",
        TOP_HEADER = "=== Your Stats (client-only) ===",
        TOP_RANK = "Rank: %s Grade %d",
        TOP_CREDITS = "Credits: %d %s",
        TOP_STATS = "Kills: %d  Deaths: %d  K/D: %.2f",
        SETRANK_USAGE = "Usage: /setrank <rank_id> <grade>",
        SETRANK_INVALID_RID = "Invalid rank ID.",
        SETRANK_INVALID_GRADE = "Invalid grade (1-%d)",
        SETRANK_SET = "Set rank to %s Grade %d (%d credits)",
        LOAD_OK = "Rank System loaded. Use /rank, /ranks, /top",
        SAVE_ERROR = "Error saving stats: %s",
        MALFORMED_FILE = "Warning: stats file malformed, using defaults."
    },
    RANKS = {
        { "Recruit", { 0 } },
        { "Apprentice", { 3000, 6000 } },
        { "Private", { 9000, 12000 } },
        { "Corporal", { 13000, 14000 } },
        { "Sergeant", { 15000, 16000, 17000, 18000 } },
        { "Gunnery Sergeant", { 19000, 20000, 21000, 22000 } },
        { "Lieutenant", { 23000, 24000, 25000, 26000 } },
        { "Captain", { 27000, 28000, 29000, 30000 } },
        { "Major", { 31000, 32000, 33000, 34000 } },
        { "Commander", { 35000, 36000, 37000, 38000 } },
        { "Colonel", { 39000, 40000, 41000, 42000 } },
        { "Brigadier", { 43000, 44000, 45000, 46000 } },
        { "General", { 47000, 48000, 49000, 50000 } }
    }
}
-- ======================== CONFIG END ======================== --

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local io_open, os_time, floor = io.open, os.time, math.floor
local fmt, concat = string.format, table.concat

local SAVE_FILE = CONFIG.SAVE_FILE
local SYMBOL = CONFIG.SYMBOL
local CREDITS_PER_KILL = CONFIG.CREDITS_PER_KILL
local RANKS = CONFIG.RANKS
local M = CONFIG.MESSAGES

local in_game = false

local function default_stats()
    return { kills = 0, deaths = 0, credits = RANKS[1][2][1] or 0, rank = RANKS[1][1], grade = 1 }
end

local function ensure_data_file()
    local f = io_open(SAVE_FILE, "r")
    if not f then
        local d = default_stats()
        local out = io_open(SAVE_FILE, "w")
        if out then
            out:write(fmt("0;0;%d;%s;1", d.credits, d.rank))
            out:close()
        end
    else
        f:close()
    end
end
ensure_data_file()

local rank_lookup = {}
local threshold_entries = {}

local stats = default_stats()

local last_kills = 0
local last_deaths = 0
local kill_streak = 0
local last_kill_time = 0

local function get_player_kd(player)
    local kills = read_word(player + 0x9C)
    local deaths = read_word(player + 0xAE)
    return kills, deaths
end

local function build_rank_tables()
    rank_lookup = {}
    threshold_entries = {}

    for idx, rank in ipairs(RANKS) do
        local name = rank[1]
        rank_lookup[name] = idx

        for grade, cred in ipairs(rank[2]) do
            threshold_entries[#threshold_entries + 1] = {
                credits = cred,
                rank_index = idx,
                grade = grade,
                rank_name = name
            }
        end
    end

    table.sort(threshold_entries, function (a, b)
        return a.credits < b.credits
    end)
end

local function find_rank(credits)
    local lo, hi, best = 1, #threshold_entries, threshold_entries[1]
    while lo <= hi do
        local mid = floor((lo + hi) / 2)
        local ent = threshold_entries[mid]
        if not ent then return end

        if credits >= ent.credits then
            best = ent
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return best
end

local function find_next_threshold(credits)
    for _, ent in ipairs(threshold_entries) do
        if ent.credits > credits then
            return ent
        end
    end
end

local function refresh_rank(silent)
    if not stats then return end

    local old_rank = stats.rank
    local old_grade = stats.grade

    local best = find_rank(stats.credits)
    if not best then return end

    stats.rank = best.rank_name
    stats.grade = best.grade

    if silent then return end

    local promoted = (best.rank_index > (rank_lookup[old_rank] or 0))
        or (stats.rank == old_rank and stats.grade > old_grade)

    if promoted then
        console_out(fmt(M.RANK_UP, stats.rank, stats.grade))
    elseif stats.rank ~= old_rank or stats.grade ~= old_grade then
        console_out(fmt(M.RANK_DOWN, stats.rank, stats.grade))
    end
end

local function award_credits(amount, message)
    if amount == 0 then return end
    stats.credits = stats.credits + amount
    refresh_rank(false)
    console_out(message)
end

local function save_stats()
    local f, err = io_open(SAVE_FILE, "w")
    if not f then
        console_out(fmt(M.SAVE_ERROR, tostring(err)))
        return
    end

    local line = fmt("%d;%d;%d;%s;%d", stats.kills, stats.deaths, stats.credits, stats.rank, stats.grade)
    f:write(line)
    f:close()
    console_out(M.SAVE_OK)
end

local function load_stats()
    local f = io_open(SAVE_FILE, "r")
    if not f then
        stats = default_stats()
        return
    end

    local content = f:read("*l")
    f:close()

    if not content or content == "" then
        stats = default_stats()
        return
    end

    local parts = {}
    for token in string.gmatch(content, "[^;]+") do
        parts[#parts + 1] = token
    end

    if #parts < 5 then
        console_out(M.MALFORMED_FILE)
        stats = default_stats()
        return
    end

    stats = {
        kills = tonumber(parts[1]) or 0,
        deaths = tonumber(parts[2]) or 0,
        credits = tonumber(parts[3]) or (RANKS[1][2][1] or 0),
        rank = parts[4] or RANKS[1][1],
        grade = tonumber(parts[5]) or 1
    }

    local best = find_rank(stats.credits)
    if best then
        stats.rank = best.rank_name
        stats.grade = best.grade
    end
end

local function on_kill()
    stats.kills = stats.kills + 1

    local now = os_time()
    local streak_bonus = 0

    if now - last_kill_time <= 5 then
        kill_streak = kill_streak + 1
        if kill_streak == 2 then
            streak_bonus = 5
        elseif kill_streak == 3 then
            streak_bonus = 10
        elseif kill_streak >= 4 then
            streak_bonus = 15
        end
    else
        kill_streak = 1
    end

    last_kill_time = now

    local total_credits = CREDITS_PER_KILL + streak_bonus
    local msg = fmt(M.KILL, total_credits, SYMBOL)

    if streak_bonus > 0 then
        msg = msg .. M.STREAK_SUFFIX
    end

    award_credits(total_credits, msg)
end

local function on_death()
    stats.deaths = stats.deaths + 1
    kill_streak = 0
end

local function cmd_rank()
    local next_entry = find_next_threshold(stats.credits)

    console_out(M.RANK_HEADER)
    console_out(fmt(M.RANK_CURRENT, stats.rank, stats.grade))
    console_out(fmt(M.RANK_CREDITS, stats.credits, SYMBOL))
    console_out(
        fmt(M.RANK_STATS, stats.kills, stats.deaths, stats.deaths > 0 and stats.kills / stats.deaths or stats.kills)
    )

    if next_entry then
        console_out(
            fmt(M.RANK_NEXT, next_entry.rank_name, next_entry.grade, next_entry.credits - stats.credits, SYMBOL)
        )
    else
        console_out(M.RANK_MAX)
    end
end

local function cmd_ranks()
    console_out(M.RANKS_HEADER)
    for i, rank in ipairs(RANKS) do
        console_out(fmt(M.RANKS_LINE, i, rank[1], concat(rank[2], ", ")))
    end
end

local function cmd_top()
    console_out(M.TOP_HEADER)
    console_out(fmt(M.TOP_RANK, stats.rank, stats.grade))
    console_out(fmt(M.TOP_CREDITS, stats.credits, SYMBOL))
    console_out(
        fmt(M.TOP_STATS, stats.kills, stats.deaths, stats.deaths > 0 and stats.kills / stats.deaths or stats.kills)
    )
end

local function cmd_set_rank(args)
    if #args < 3 then
        console_out(M.SETRANK_USAGE)
        return
    end

    local rid = tonumber(args[2])
    local grade = tonumber(args[3])

    if not rid or rid < 1 or rid > #RANKS then
        console_out(M.SETRANK_INVALID_RID)
        return
    end

    local rank_data = RANKS[rid]
    if not grade or grade < 1 or grade > #rank_data[2] then
        console_out(fmt(M.SETRANK_INVALID_GRADE, #rank_data[2]))
        return
    end

    stats.credits = rank_data[2][grade]
    stats.rank = rank_data[1]
    stats.grade = grade

    refresh_rank(false)
    save_stats()

    console_out(fmt(M.SETRANK_SET, rank_data[1], grade, stats.credits))
end

local function parse_cmd(s)
    local args = {}
    for w in s:gmatch("%S+") do
        args[#args + 1] = w
    end
    return args
end

function OnCommand(cmd)
    local args = parse_cmd(cmd)
    if #args == 0 then return end

    local command = args[1]:lower()
    if command == "rank" then
        cmd_rank()
        return false
    elseif command == "ranks" then
        cmd_ranks()
        return false
    elseif command == "top" then
        cmd_top()
        return false
    elseif command == "setrank" then
        cmd_set_rank(args)
        return false
    end
end

function OnTick()
    if server_type ~= "dedicated" then
        if in_game then
            save_stats()
            in_game = false
        end
        return
    end

    if not in_game then
        in_game = true
        kill_streak = 0
        last_kill_time = 0
    end

    local player = get_player()
    if not player then return end

    local kills, deaths = get_player_kd(player)

    if kills > last_kills then
        on_kill()
    end

    if deaths > last_deaths then
        on_death()
    end

    last_kills = kills
    last_deaths = deaths
end

function OnMapLoad()
    refresh_rank(true)
    console_out(M.LOAD_OK)
end

function OnScriptUnload()
    save_stats()
end

build_rank_tables()
load_stats()
refresh_rank(true)

in_game = (server_type == "dedicated")

set_callback("tick", "OnTick")
set_callback("command", "OnCommand")
set_callback("map load", "OnMapLoad")
