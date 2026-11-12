--[[
=====================================================================================
SCRIPT NAME:    rank_system.lua
DESCRIPTION:    Progression system. Players earn credits (cR) from kills and
                objectives, lose them for suicides, betrayals and falling, and
                move through ranks and grades as their credit total changes.
                Stats are saved by player name.

CREDITS (defaults, see KILL_CREDITS, MILESTONES, SCORING_CREDITS and KOTH):
                - First blood                +20
                - Kill while dead (sticky)   +12
                - Roadkill                   +15
                - Standard PvP kill          +15
                - CTF flag capture           +40
                - Race lap                   +8
                - Streak bonus               +10 at 3 kills, +15 at 5, +20 at 10,
                                             scaling up to +50 at 50
                - Suicide                    -8
                - Betrayal                   -10 (deducted from the betrayer)
                - Falling or distance        -6

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
                - /rank                                 - Show your rank and progress
                - /ranks                                - List all ranks and thresholds
                - /top                                  - Show the leaderboard
                - /setrank <player_id> <rank_id> <grade> - Admin only, sets a player's rank

LAST UPDATED:   11 November 2026

Copyright (c) 2017-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START ------------------------------------------------------------------------------------------------

local SAVE_FILE = "ranks.txt" -- Written to <instance>\sapp\
local SAVE_ON_LEAVE = false   -- Also save every time a player leaves
local SHOW_TOP_END = true     -- Broadcast the leaderboard when a game ends
local SETRANK_ADMIN_LEVEL = 4 -- Minimum admin level for /setrank (the console is always allowed)
local TOP_PLAYERS_COUNT = 10  -- Entries shown by /top

-- Each grade threshold is the credit total needed to reach that grade.
-- Keep ranks in ascending order.
local RANKS = {
    { name = "Recruit", grades = { 0 } }, { name = "Apprentice", grades = { 3000, 6000 } },
    { name = "Private", grades = { 9000, 12000 } }, { name = "Corporal", grades = { 13000, 14000 } },
    { name = "Sergeant", grades = { 15000, 16000, 17000, 18000 } },
    { name = "Gunnery Sergeant", grades = { 19000, 20000, 21000, 22000 } },
    { name = "Lieutenant", grades = { 23000, 24000, 25000, 26000 } },
    { name = "Captain", grades = { 27000, 28000, 29000, 30000 } },
    { name = "Major", grades = { 31000, 32000, 33000, 34000 } },
    { name = "Commander", grades = { 35000, 36000, 37000, 38000 } },
    { name = "Colonel", grades = { 39000, 40000, 41000, 42000 } },
    { name = "Brigadier", grades = { 43000, 44000, 45000, 46000 } },
    { name = "General", grades = { 47000, 48000, 49000, 50000 } }
}

-- [kill streak] = bonus credits, awarded on top of the kill credits
local MILESTONES = { [3] = 10, [5] = 15, [10] = 20, [15] = 25, [20] = 30, [25] = 35, [30] = 40, [40] = 45, [50] = 50 }

-- Positive values are awarded to the killer. Negative values are deducted from the player at fault
-- (the victim for suicide and falling, the killer for betrayal). Zero disables the type.
local KILL_CREDITS = {
    first_blood = 20,
    grave = 12,   -- killer was already dead (e.g. a sticky going off)
    roadkill = 15,
    pvp = 15,
    suicide = -8,
    betrayal = -10,
    squashed = 0, -- killed by an unoccupied vehicle
    falling = -6, -- falling or distance damage
    server = 0,
    unknown = 0
}

-- Credits per scoring event, 0 disables. CTF pays the capturing player only.
local SCORING_CREDITS = {
    ctf = 40, -- flag capture
    race = 8  -- lap complete
}

-- King of the Hill pays `credits` for every `interval` seconds spent on the hill. 0 disables.
local KOTH = { credits = 0, interval = 30 }

-- Private lines sent to a player on join. Leave empty to disable.
local WELCOME_MESSAGES = {}

local MESSAGES = {
    RANK_UP_HEADER = "=== RANK UP ===",
    RANK_UP = "%s: %s G%d",
    RANK_DOWN_HEADER = "=== RANK DOWN ===",
    RANK_DOWN = "%s: %s G%d",

    CREDIT_KILL = "%+d cR (kill)",
    CREDIT_STREAK = "%+d cR (streak)",
    CREDIT_SCORE = "%+d cR (score)",
    CREDIT_HILL = "%+d cR (hill)",
    CREDIT_LOSS = "%+d cR",

    RANK_HEADER = "=== Rank ===",
    RANK_CURRENT = "%s: G%d",
    RANK_CREDITS = "Credits: %d cR",
    RANK_STATS = "Kills: %d  Deaths: %d  K/D: %.2f",
    RANK_NEXT = "Next: %s: G%d in %d cR",
    RANK_MAX = "Maximum rank reached!",

    RANKS_HEADER = "=== Available Ranks ===",
    RANKS_LINE = "%d. %s: %s",

    TOP_HEADER = "=== Top %d ===",
    TOP_LINE = "%d. %s - %s - %s%d",

    NO_PERMISSION = "You do not have permission to use this command.",
    NO_PLAYER_DATA = "Player data not available.",
    SET_RANK_USAGE = "Usage: /setrank <player_id> <rank_id> <grade>",
    NOT_A_NUMBER = "%s must be a whole number.",
    PLAYER_NOT_FOUND = "Player not found or not online.",
    INVALID_RANK_ID = "Valid rank IDs are 1-%d.",
    INVALID_GRADE = "Valid grades for %s are 1-%d.",
    SET_RANK_HEADER = "Rank updated for %s",
    SET_RANK_INFO = "New Rank: %s, G%d"
}

-- Players using these names get fresh stats every session and are never saved or ranked.
-- These are Halo's default and placeholder profile names.
local FILTERED_NAMES = {
    "Butcher", "Caboose", "Crazy", "Cupid", "Darling", "Dasher", "Disco", "Donut", "Dopey", "Ghost", "Goat", "Grumpy",
    "Hambone", "Hollywood", "Howard", "Jack", "Killer", "King", "New001", "Noodle", "Nuevo", "Penguin", "Pirate",
    "Prancer", "Saucy", "Shadow", "Sleepy", "Snake", "Sneak", "Stompy", "Stumpy", "The Bear", "The Big L", "Tooth",
    "Walla Walla", "Weasel", "Wheezy", "Whicker", "Whisp", "Wilshire"
}

-- CONFIG END --------------------------------------------------------------------------------------------------

local io_open = io.open
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_format = string.format
local table_concat = table.concat
local table_sort = table.sort

-- Kill types that increase the killer's kill count. Betrayals are deliberately left out.
local COUNTS_AS_KILL = { first_blood = true, grave = true, roadkill = true, pvp = true }

---@class PlayerStats
---@field kills   number
---@field deaths  number
---@field credits number
---@field rank    string
---@field grade   number

---@class PlayerData
---@field id              number        Player index (1-16)
---@field name            string
---@field stats           PlayerStats   Shared with `stats_db` unless the name is filtered
---@field team            string
---@field switched        boolean | nil True from a team switch until the next spawn
---@field last_damage     number | nil  Tag ID of the last damage received
---@field last_hill_award number        Hill time (seconds) already paid out this game

---@class ThresholdEntry
---@field credits    number
---@field rank_name  string
---@field rank_index number
---@field grade      number

---@type table<number, PlayerData>
local players = {}
---@type table<string, PlayerStats>
local stats_db = {}
---@type table<string, number>
local rank_lookup = {}
---@type ThresholdEntry[]
local threshold_entries = {}
---@type table<string, string>
local rank_abbreviations = {}
---@type table<string, boolean>
local filtered_names = {}

for _, name in ipairs(FILTERED_NAMES) do
    filtered_names[name] = true
end

local save_path
local stats_globals
local gametype
local is_ffa = false
local first_blood_pending = true
local falling_tag_id, distance_tag_id

-- Bumped on every game start and end. A timer started in an earlier session stops itself.
local game_session = 0

---@param str       string
---@param delimiter string
---@return string[] tokens
local function tokenize(str, delimiter)
    local tokens = {}
    for token in str:gmatch("([^" .. delimiter .. "]+)") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

---@param value string | nil
---@return number | nil integer
local function parseInteger(value)
    local number = tonumber(value)
    return number and number == math_floor(number) and number or nil
end

---@param signature string Byte pattern to scan for
---@param offset    number Offset from the match to the pointer
---@return number | nil pointer Resolved pointer, or nil if the scan failed or the value looks wrong
local function safeScan(signature, offset)
    local hit = sig_scan(signature)
    if hit == 0 then return nil end

    ---@diagnostic disable-next-line: param-type-mismatch
    local pointer = read_dword(hit + offset)
    if not pointer or pointer < 0x400000 or pointer > 0x800000 then return nil end
    return pointer
end

---@return string path The instance directory passed to the server with -path
local function getProfilePath()
    local address = safeScan("68??????008D54245468", 0x1) or (halo_type == "PC" and 0x635610 or 0x5B9630)
    ---@diagnostic disable-next-line: param-type-mismatch
    return read_string(address)
end

---@param tag_class string
---@param tag_name  string
---@return number | nil tag_id
local function getTagId(tag_class, tag_name)
    local tag = lookup_tag(tag_class, tag_name)
    if tag == 0 then return nil end

    local meta_id = read_dword(tag + 0xC)
    return meta_id ~= 0 and meta_id or nil
end

---@param player_id number 0 targets the server console
---@param message   string
local function respond(player_id, message)
    if player_id == 0 then
        cprint(message)
    else
        rprint(player_id, message)
    end
end

---@param message string
local function rprintAll(message)
    for player_id = 1, 16 do
        if player_present(player_id) then
            rprint(player_id, message)
        end
    end
end

---@param player_id number
---@return boolean
local function isAdmin(player_id)
    if player_id == 0 then return true end
    ---@diagnostic disable-next-line: param-type-mismatch
    return (tonumber(get_var(player_id, "$lvl")) or -1) >= SETRANK_ADMIN_LEVEL
end

---@return PlayerStats
local function defaultStats()
    return { kills = 0, deaths = 0, credits = 0, rank = RANKS[1].name, grade = 1 }
end

---@param stats PlayerStats
---@return boolean
local function hasProgress(stats)
    return stats.kills > 0 or stats.deaths > 0 or stats.credits > 0
end

-- 1500 becomes "1.5k", 2000 becomes "2k"
---@param credits number
---@return string
local function formatCredits(credits)
    if credits < 1000 then return tostring(credits) end

    local whole = math_floor(credits / 1000)
    local tenths = math_floor((credits % 1000) / 100)
    return tenths == 0 and whole .. "k" or whole .. "." .. tenths .. "k"
end

-- Multi-word names use initials (Gunnery Sergeant becomes GS), single words use the first three
-- letters (Private becomes Pri).
---@param rank_name string
---@return string
local function abbreviateRank(rank_name)
    local words = tokenize(rank_name, "%s")
    if #words <= 1 then return rank_name:sub(1, 3) end

    local initials = {}
    for i = 1, math_min(3, #words) do
        if not words[i] then break end
        initials[i] = words[i]:sub(1, 1)
    end
    return table_concat(initials)
end

---@param rank_name string
---@return string
local function getRankAbbreviation(rank_name)
    local abbreviation = rank_abbreviations[rank_name]
    if not abbreviation then
        abbreviation = abbreviateRank(rank_name)
        rank_abbreviations[rank_name] = abbreviation
    end
    return abbreviation
end

-- Flattens every grade of every rank into one list sorted by credits, for binary search.
local function buildRankTables()
    for rank_index, rank in ipairs(RANKS) do
        rank_lookup[rank.name] = rank_index
        for grade, credits in ipairs(rank.grades) do
            threshold_entries[#threshold_entries + 1] = {
                credits = credits,
                rank_name = rank.name,
                rank_index = rank_index,
                grade = grade
            }
        end
    end
    table_sort(threshold_entries, function (a, b) return a.credits < b.credits end)
end

-- Index of the highest threshold at or below `credits`, or 0 if there is none.
---@param credits number
---@return number index
local function findThresholdIndex(credits)
    local low, high, found = 1, #threshold_entries, 0
    while low <= high do
        local mid = math_floor((low + high) / 2)
        if threshold_entries[mid].credits <= credits then
            found = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return found
end

local function saveStats()
    local file = io_open(save_path, "w")
    if not file then
        cprint("rank_system: could not write " .. save_path, 12)
        return
    end

    for name, stats in pairs(stats_db) do
        if hasProgress(stats) then
            local fields = { name, stats.kills, stats.deaths, stats.credits, stats.rank, stats.grade }
            file:write(table_concat(fields, ";"), "\n")
        end
    end
    file:close()
end

local function loadStats()
    local file = io_open(save_path, "r")
    if not file then return end

    for line in file:lines() do
        -- Name is matched greedily so a ";" inside a name does not shift the other fields.
        local name, kills, deaths, credits, rank, grade = line:match("^(.+);(%d+);(%d+);(%d+);([^;]+);(%d+)%s*$")

        if name and not filtered_names[name] then
            stats_db[name] = {
                kills = tonumber(kills),
                deaths = tonumber(deaths),
                credits = tonumber(credits),
                rank = rank,
                grade = tonumber(grade)
            }
        end
    end
    file:close()
end

-- Recomputes rank and grade from credits and announces the change unless `silent`.
---@param player PlayerData
---@param silent boolean | nil
local function refreshRank(player, silent)
    local stats = player.stats
    local old_rank, old_grade = stats.rank, stats.grade

    local entry = threshold_entries[findThresholdIndex(stats.credits)] or threshold_entries[1]
    stats.rank, stats.grade = entry.rank_name, entry.grade

    if silent or (old_rank == stats.rank and old_grade == stats.grade) then return end

    local old_rank_index = rank_lookup[old_rank] or 0
    local promoted = entry.rank_index > old_rank_index
        or (entry.rank_index == old_rank_index and entry.grade > old_grade)

    rprintAll(promoted and MESSAGES.RANK_UP_HEADER or MESSAGES.RANK_DOWN_HEADER)
    rprintAll(string_format(promoted and MESSAGES.RANK_UP or MESSAGES.RANK_DOWN, player.name, stats.rank, stats.grade))
end

-- Credits never drop below zero.
---@param player PlayerData
---@param amount number     Positive to award, negative to deduct
local function addCredits(player, amount)
    player.stats.credits = math_max(0, player.stats.credits + amount)
    refreshRank(player, false)
end

---@param player_id number
---@return number streak Kills since the player's last respawn
local function getKillStreak(player_id)
    local static_player = get_player(player_id)
    return static_player ~= 0 and read_word(static_player + 0x98) or 0
end

---@param player_id number
---@return number seconds Cumulative hill time this game
local function getHillTime(player_id)
    return read_word(stats_globals + to_real_index(player_id) * 0x30 + 0x1E)
end

---@param player_id number
---@return boolean
local function isInVehicle(player_id)
    local dyn_player = get_dynamic_player(player_id)
    return dyn_player ~= 0 and read_dword(dyn_player + 0x11C) ~= 0xFFFFFFFF
end

local function resetGameState()
    is_ffa = get_var(0, "$ffa") == "1"
    falling_tag_id = getTagId("jpt!", "globals\\falling")
    distance_tag_id = getTagId("jpt!", "globals\\distance")
    first_blood_pending = true
end

-- Claims first blood when it applies, so call it once per death.
---@param victim_id number
---@param victim    PlayerData
---@param killer_id number | nil - 1 server, 0 non-player source, 1+ player index
---@param killer    PlayerData | nil
---@return string kill_type A key of KILL_CREDITS
local function getKillType(victim_id, victim, killer_id, killer)
    if not killer_id then return "unknown" end

    if killer_id == -1 then
        if victim.switched then return "unknown" end

        local last = victim.last_damage
        local is_fall = last and (last == falling_tag_id or last == distance_tag_id)
        return is_fall and "falling" or "server"
    end

    if killer_id == 0 then return "squashed" end
    if killer_id == victim_id then return "suicide" end
    if not is_ffa and killer and killer.team == victim.team then return "betrayal" end

    if first_blood_pending then
        first_blood_pending = false
        return "first_blood"
    end

    if not player_alive(killer_id) then return "grave" end
    ---@diagnostic disable-next-line: param-type-mismatch
    if isInVehicle(killer_id) then return "roadkill" end
    return "pvp"
end

---@param killer    PlayerData | nil
---@param victim    PlayerData
---@param kill_type string           A key of KILL_CREDITS
local function applyKillCredits(killer, victim, kill_type)
    local change = KILL_CREDITS[kill_type]
    if not change or change == 0 then return end

    if change < 0 then
        local offender = kill_type == "betrayal" and killer or victim
        if not offender then return end

        respond(offender.id, string_format(MESSAGES.CREDIT_LOSS, change))
        addCredits(offender, change)
        return
    end

    if not killer then return end

    respond(killer.id, string_format(MESSAGES.CREDIT_KILL, change))

    local bonus = MILESTONES[getKillStreak(killer.id)]
    if bonus then
        respond(killer.id, string_format(MESSAGES.CREDIT_STREAK, bonus))
    end

    addCredits(killer, change + (bonus or 0))
end

---@return string[] lines
local function getLeaderboardLines()
    local entries = {}
    for name, stats in pairs(stats_db) do
        if hasProgress(stats) then
            entries[#entries + 1] = { name = name, stats = stats }
        end
    end

    table_sort(entries, function (a, b)
        if a.stats.credits ~= b.stats.credits then return a.stats.credits > b.stats.credits end
        return a.name < b.name
    end)

    local count = math_min(TOP_PLAYERS_COUNT, #entries)
    local lines = { string_format(MESSAGES.TOP_HEADER, count) }
    for i = 1, count do
        local entry = entries[i]
        if not entry then break end -- todo: double-check this

        lines[#lines + 1] = string_format(
            MESSAGES.TOP_LINE, 
            i, 
            entry.name, 
            formatCredits(entry.stats.credits), 
            getRankAbbreviation(entry.stats.rank),
            entry.stats.grade
        )
    end
    return lines
end

---@param player_id number | nil Omit to broadcast to everyone
local function showTopStats(player_id)
    for _, line in ipairs(getLeaderboardLines()) do
        if player_id then
            respond(player_id, line)
        else
            rprintAll(line)
        end
    end
end

---@param player_id number
---@param player    PlayerData | nil
local function showRank(player_id, player)
    if not player then
        respond(player_id, MESSAGES.NO_PLAYER_DATA)
        return
    end

    local stats = player.stats
    local next_entry = threshold_entries[findThresholdIndex(stats.credits) + 1]
    local kd_ratio = stats.deaths > 0 and stats.kills / stats.deaths or stats.kills

    respond(player_id, MESSAGES.RANK_HEADER)
    respond(player_id, string_format(MESSAGES.RANK_CURRENT, stats.rank, stats.grade))
    respond(player_id, string_format(MESSAGES.RANK_CREDITS, stats.credits))
    respond(player_id, string_format(MESSAGES.RANK_STATS, stats.kills, stats.deaths, kd_ratio))

    if next_entry then
        respond(
            player_id,
            string_format(
                MESSAGES.RANK_NEXT, 
                next_entry.rank_name, 
                next_entry.grade, 
                next_entry.credits - stats.credits
            )
        )
    else
        respond(player_id, MESSAGES.RANK_MAX)
    end
end

---@param player_id number
local function registerPlayer(player_id)
    local name = get_var(player_id, "$name")
    local is_filtered = filtered_names[name]

    local stats = not is_filtered and stats_db[name] or nil
    if not stats then
        stats = defaultStats()
        if not is_filtered then stats_db[name] = stats end
    end

    local player = {
        id = player_id,
        name = name,
        stats = stats,
        team = get_var(player_id, "$team"),
        last_hill_award = 0
    }

    players[player_id] = player
    refreshRank(player, true)
end

---@param player_id number
---@param args      string[]
local function handleSetRank(player_id, args)
    if not isAdmin(player_id) then
        respond(player_id, MESSAGES.NO_PERMISSION)
        return
    end

    if #args < 4 then
        respond(player_id, MESSAGES.SET_RANK_USAGE)
        return
    end

    local target_id = parseInteger(args[2])
    if not target_id then
        respond(player_id, string_format(MESSAGES.NOT_A_NUMBER, "Player ID"))
        return
    end

    local target = players[target_id]
    if not target then
        respond(player_id, MESSAGES.PLAYER_NOT_FOUND)
        return
    end

    local rank_id = parseInteger(args[3])
    if not rank_id then
        respond(player_id, string_format(MESSAGES.NOT_A_NUMBER, "Rank ID"))
        return
    end

    ---@diagnostic disable-next-line: undefined-field
    local rank = RANKS[rank_id]
    if not rank then
        respond(player_id, string_format(MESSAGES.INVALID_RANK_ID, #RANKS))
        return
    end

    local grade = parseInteger(args[4])
    if not grade then
        respond(player_id, string_format(MESSAGES.NOT_A_NUMBER, "Grade"))
        return
    end

    local credits = rank.grades[grade]
    if not credits then
        respond(player_id, string_format(MESSAGES.INVALID_GRADE, rank.name, #rank.grades))
        return
    end

    target.stats.credits = credits
    refreshRank(target, false)
    saveStats()

    respond(player_id, string_format(MESSAGES.SET_RANK_HEADER, target.name))
    respond(player_id, string_format(MESSAGES.SET_RANK_INFO, rank.name, grade))
end

---@param player_id number
local function handleRank(player_id)
    showRank(player_id, players[player_id])
end

---@param player_id number
local function handleRanks(player_id)
    respond(player_id, MESSAGES.RANKS_HEADER)
    for rank_index, rank in ipairs(RANKS) do
        respond(player_id, string_format(MESSAGES.RANKS_LINE, rank_index, rank.name, table_concat(rank.grades, ", ")))
    end
end

---@type table<string, fun(player_id: number, args: string[])>
local COMMANDS = { rank = handleRank, ranks = handleRanks, top = showTopStats, setrank = handleSetRank }

function OnScriptLoad()
    save_path = getProfilePath() .. "\\sapp\\" .. SAVE_FILE
    stats_globals = safeScan("33C0BF??????00F3AB881D", 0x3) or (halo_type == "PC" and 0x639878 or 0x5BD898)

    buildRankTables()
    loadStats()

    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_DIE, "OnDie")
    register_callback(cb.EVENT_SCORE, "OnScore")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_TEAM_SWITCH, "OnTeamSwitch")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")

    OnStart() -- in case the script was loaded mid-game
end

function OnScriptUnload() saveStats() end

function OnStart()
    gametype = get_var(0, "$gt")
    if gametype == "n/a" then return end

    game_session = game_session + 1
    resetGameState()

    players = {}
    for player_id = 1, 16 do
        if player_present(player_id) then
            registerPlayer(player_id)
        end
    end

    ---@diagnostic disable-next-line: unnecessary-if
    if gametype == "king" and KOTH.credits > 0 and KOTH.interval > 0 then
        timer(1000, "KothTimer", game_session)
    end
end

function OnEnd()
    game_session = game_session + 1
    saveStats()
    ---@diagnostic disable-next-line: unnecessary-if
    if SHOW_TOP_END then showTopStats() end
end

---@param session number The game_session the timer was started in
---@return boolean repeat_timer
function KothTimer(session)
    if session ~= game_session then return false end

    for player_id, player in pairs(players) do
        local elapsed = getHillTime(player_id) - player.last_hill_award
        local intervals = math_floor(elapsed / KOTH.interval)

        if intervals > 0 then
            local award = intervals * KOTH.credits
            player.last_hill_award = player.last_hill_award + intervals * KOTH.interval

            respond(player_id, string_format(MESSAGES.CREDIT_HILL, award))
            addCredits(player, award)
        end
    end
    return true
end

---@param player_id number
function OnJoin(player_id)
    registerPlayer(player_id)
    for _, line in ipairs(WELCOME_MESSAGES) do
        rprint(player_id, line)
    end
end

---@param player_id number
function OnLeave(player_id)
    ---@diagnostic disable-next-line: unnecessary-if
    if SAVE_ON_LEAVE then saveStats() end
    players[player_id] = nil
end

---@param player_id number
function OnSpawn(player_id)
    local player = players[player_id]
    if not player then return end

    player.last_damage = nil
    player.switched = nil
end

---@param player_id number
function OnTeamSwitch(player_id)
    local player = players[player_id]
    if not player then return end

    player.team = get_var(player_id, "$team")
    player.switched = true
end

-- Remembers the last damage tag so a server kill can be told apart as falling or distance damage.
---@param victim_id     number
---@param causer_id     number
---@param damage_tag_id number
function OnDamageApplication(victim_id, causer_id, damage_tag_id)
    local victim = players[victim_id]
    ---@diagnostic disable-next-line: unnecessary-if
    if victim then victim.last_damage = damage_tag_id end
end

---@param victim_id     number
---@param killer_source string "-1" server, "0" non-player source, "1+" player index
function OnDie(victim_id, killer_source)
    local victim = players[victim_id]
    if not victim then return end

    local killer_id = tonumber(killer_source)
    local killer = killer_id and players[killer_id]
    local kill_type = getKillType(victim_id, victim, killer_id, killer)

    victim.stats.deaths = victim.stats.deaths + 1
    if killer and COUNTS_AS_KILL[kill_type] then
        killer.stats.kills = killer.stats.kills + 1
    end

    applyKillCredits(killer, victim, kill_type)
end

-- CTF captures and race laps.
---@param player_id number
function OnScore(player_id)
    local player = players[player_id]
    local credits = SCORING_CREDITS[gametype]
    if not player or not credits or credits == 0 then return end

    respond(player_id, string_format(MESSAGES.CREDIT_SCORE, credits))
    addCredits(player, credits)
end

---@param player_id number
---@param command   string
---@return boolean | nil allow Returns false for commands handled here
function OnCommand(player_id, command)
    local args = tokenize(command, " ")
    local handler = COMMANDS[(args[1] or ""):lower()]
    if not handler then return end

    handler(player_id, args)
    return false
end
