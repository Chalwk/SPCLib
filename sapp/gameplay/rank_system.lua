--[[
================================================================================================
SCRIPT NAME:      rank_system.lua
DESCRIPTION:      Advanced player ranking and progression system that tracks
                  player statistics, awards credits for in-game actions, and
                  implements a multi-tier ranking system with grade progression.
                  Player stats save when game ends OR script unloaded.

COMMANDS:        - rank [player_id]    - Check your or another player's rank and statistics
                 - ranks               - List all available ranks and their credit thresholds
                 - top [limit]         - Display leaderboard with top players by composite score
                 - setrank <id> <rank> <grade> - Admin command to set player rank

REQUIREMENTS:    * Lua JSON Parser: http://regex.info/blog/lua/json
                   Place json.lua in the same directory as sapp.dll

Copyright (c) 2019-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
================================================================================================
]]

--
-- CONFIG START.
--

api_version = '1.12.0.0'

local CONFIG = {
    -- Symbol displayed in credit messages
    SYMBOL = 'cR',
    -- Command cooldown in seconds (prevents command spam)
    COOLDOWN = 3,
    -- Whether to display top players on game end
    SHOW_STATS_ON_END = true,
    -- Number of top players to display
    STATS_LIMIT = 5,
    -- Commands and required permission levels (-1 = all players, 1-4 = admin levels)
    COMMANDS = {
        { 'rank', -1 },
        { 'ranks', -1 },
        { 'top', -1 },
        { 'setrank', 4 }
    },
    -- Rank definitions: { "Rank Name", { grade1_threshold, grade2_threshold, ... } }
    RANKS = {
        { "Recruit", { [1] = 0 } },
        { "Apprentice", { [1] = 3000, [2] = 6000 } },
        { "Private", { [1] = 9000, [2] = 12000 } },
        { "Corporal", { [1] = 13000, [2] = 14000 } },
        { "Sergeant", { [1] = 15000, [2] = 16000, [3] = 17000, [4] = 18000 } },
        { "Gunnery Sergeant", { [1] = 19000, [2] = 20000, [3] = 21000, [4] = 22000 } },
        { "Lieutenant", { [1] = 23000, [2] = 24000, [3] = 25000, [4] = 26000 } },
        { "Captain", { [1] = 27000, [2] = 28000, [3] = 29000, [4] = 30000 } },
        { "Major", { [1] = 31000, [2] = 32000, [3] = 33000, [4] = 34000 } },
        { "Commander", { [1] = 35000, [2] = 36000, [3] = 37000, [4] = 38000 } },
        { "Colonel", { [1] = 39000, [2] = 40000, [3] = 41000, [4] = 42000 } },
        { "Brigadier", { [1] = 43000, [2] = 44000, [3] = 45000, [4] = 46000 } },
        { "General", { [1] = 47000, [2] = 48000, [3] = 49000, [4] = 50000 } }
    },
    -- NOTES:     1. Set to 0 to disable a credit event.
    --            2. %s will be replaced with currency symbol.
    CREDITS = {
        head_shot = { 8, '+8 %s (Headshot)' },
        revenge = { 12, '+12 %s (Revenge)' },
        avenge = { 10, '+10 %s (Avenge)' },
        reload_this = { 5, '+5 %s (Reload This!)' },
        close_call = { 12, '+12 %s (Close Call)' },
        server = { 0, '+0 %s (Server)' },
        guardians = { -8, '-8 %s (Guardians)' },
        suicide = { -12, '-12 %s (Suicide)' },
        betrayal = { -20, '-20 %s (Betrayal)' },
        killed_from_the_grave = { 20, '+20 %s (Killed From Grave)' },
        first_blood = { 35, '+35 %s (First Blood)' },
        spree = {
            [5] = { 15, '+15 %s (Spree)' },
            [10] = { 25, '+25 %s (Spree)' },
            [15] = { 35, '+35 %s (Spree)' },
            [20] = { 50, '+50 %s (Spree)' },
            [25] = { 65, '+65 %s (Spree)' },
            [30] = { 80, '+80 %s (Spree)' },
            [35] = { 95, '+95 %s (Spree)' },
            [40] = { 110, '+110 %s (Spree)' },
            [45] = { 125, '+125 %s (Spree)' },
            [50] = { 150, '+150 %s (Spree)' }
        },
        multi_kill = {
            [2] = { 8, '+8 %s (Double Kill)' },
            [3] = { 15, '+15 %s (Triple Kill)' },
            [4] = { 25, '+25 %s (Multi-Kill)' },
            [5] = { 35, '+35 %s (Multi-Kill)' },
            [6] = { 45, '+45 %s (Multi-Kill)' },
            [7] = { 55, '+55 %s (Multi-Kill)' },
            [8] = { 65, '+65 %s (Multi-Kill)' },
            [9] = { 75, '+75 %s (Multi-Kill)' },
            [10] = { 100, '+100 %s (Ultra Kill)' }
        },
        game_score = {
            [1] = { 150, '+150 %s (Flag Capture)' },
            [2] = { 125, '+125 %s (Lap)' },
            [3] = { 100, '+100 %s (Lap)' }
        },
        damage_tags = {
            falling = { -5, '-5 %s (Fall)' },
            distance = { -5, '-5 %s (Distance)' },
            collision = 'globals\\vehicle_collision',
            vehicles = {
                ['vehicles\\ghost\\ghost_mp'] = { 15, '+15 %s (Ghost)' },
                ['vehicles\\rwarthog\\rwarthog'] = { 20, '+20 %s (R-Hog)' },
                ['vehicles\\warthog\\mp_warthog'] = { 25, '+25 %s (Warthog)' },
                ['vehicles\\banshee\\banshee_mp'] = { 30, '+30 %s (Banshee)' },
                ['vehicles\\scorpion\\scorpion_mp'] = { 35, '+35 %s (Tank)' },
                ['vehicles\\c gun turret\\c gun turret_mp'] = { 40, '+40 %s (Turret)' }
            },
            { 'vehicles\\ghost\\ghost bolt', 12, '+12 %s (Ghost)' },
            { 'vehicles\\scorpion\\bullet', 10, '+10 %s (Tank)' },
            { 'vehicles\\warthog\\bullet', 10, '+10 %s (Warthog)' },
            { 'vehicles\\c gun turret\\mp bolt', 12, '+12 %s (Turret)' },
            { 'vehicles\\banshee\\banshee bolt', 12, '+12 %s (Banshee)' },
            { 'vehicles\\scorpion\\shell explosion', 20, '+20 %s (Tank Shell)' },
            { 'vehicles\\banshee\\mp_fuel rod explosion', 20, '+20 %s (Fuel Rod)' },
            { 'vehicles\\doozy\\bullet', 8, '+8 %s (Doozy)' },
            { 'weapons\\pistol\\bullet', 8, '+8 %s (Pistol)' },
            { 'weapons\\shotgun\\pellet', 12, '+12 %s (Shotgun)' },
            { 'weapons\\plasma rifle\\bolt', 6, '+6 %s (Plasma Rifle)' },
            { 'weapons\\needler\\explosion', 15, '+15 %s (Needler)' },
            { 'weapons\\plasma pistol\\bolt', 6, '+6 %s (Plasma Pistol)' },
            { 'weapons\\assault rifle\\bullet', 8, '+8 %s (Assault Rifle)' },
            { 'weapons\\needler\\impact damage', 6, '+6 %s (Needler)' },
            { 'weapons\\flamethrower\\explosion', 12, '+12 %s (Flamethrower)' },
            { 'weapons\\flamethrower\\burning', 12, '+12 %s (Flamethrower)' },
            { 'weapons\\flamethrower\\impact damage', 12, '+12 %s (Flamethrower)' },
            { 'weapons\\rocket launcher\\explosion', 18, '+18 %s (Rocket Launcher)' },
            { 'weapons\\needler\\detonation damage', 6, '+6 %s (Needler)' },
            { 'weapons\\plasma rifle\\charged bolt', 8, '+8 %s (Plasma Rifle)' },
            { 'weapons\\sniper rifle\\sniper bullet', 15, '+15 %s (Sniper Rifle)' },
            { 'weapons\\plasma_cannon\\effects\\plasma_cannon_explosion', 18, '+18 %s (Plasma Cannon)' },
            { 'weapons\\frag grenade\\explosion', 15, '+15 %s (Frag)' },
            { 'weapons\\plasma grenade\\attached', 15, '+15 %s (Plasma Grenade)' },
            { 'weapons\\plasma grenade\\explosion', 10, '+10 %s (Plasma Grenade)' },
            { 'weapons\\flag\\melee', 8, '+8 %s (Flag)' },
            { 'weapons\\ball\\melee', 8, '+8 %s (Ball)' },
            { 'weapons\\pistol\\melee', 6, '+6 %s (Pistol)' },
            { 'weapons\\needler\\melee', 6, '+6 %s (Needler)' },
            { 'weapons\\shotgun\\melee', 8, '+8 %s (Shotgun)' },
            { 'weapons\\flamethrower\\melee', 8, '+8 %s (Flamethrower)' },
            { 'weapons\\sniper rifle\\melee', 8, '+8 %s (Sniper Rifle)' },
            { 'weapons\\plasma rifle\\melee', 6, '+6 %s (Plasma Rifle)' },
            { 'weapons\\plasma pistol\\melee', 6, '+6 %s (Plasma Pistol)' },
            { 'weapons\\assault rifle\\melee', 6, '+6 %s (Assault Rifle)' },
            { 'weapons\\rocket launcher\\melee', 15, '+15 %s (Rocket Launcher)' },
            { 'weapons\\plasma_cannon\\effects\\plasma_cannon_melee', 15, '+15 %s (Plasma Cannon)' }
        }
    }
}

--
-- CONFIG END.
--

local ipairs, pairs, pcall, tonumber, tostring, type = ipairs, pairs, pcall, tonumber, tostring, type
local io_open, os_time, math_floor, math_min, math_max = io.open, os.time, math.floor, math.min, math.max
local string_format, table_concat, table_insert, table_sort = string.format, table.concat, table.insert, table.sort
local cprint, rprint = cprint, rprint
local get_dynamic_player, get_object_memory, get_player = get_dynamic_player, get_object_memory, get_player
local get_var, lookup_tag, player_alive, player_present = get_var, lookup_tag, player_alive, player_present
local read_byte, read_dword, read_float, read_word = read_byte, read_dword, read_float, read_word

local collision_meta_id, falling_meta_id, distance_meta_id
local json, db_directory
local rank_lookup, threshold_entries = {}, {}
local command_registry = {}
local stats_db = {}
local command_cooldowns = {}
local damage_rewards, vehicle_rewards = {}, {}
local ffa, first_blood, game_type = false, true, nil
local players = setmetatable({}, { __index = function () return nil end })

local RANKS = CONFIG.RANKS
local CREDITS = CONFIG.CREDITS
local DAMAGE_TAGS = CREDITS.damage_tags
local SYMBOL = CONFIG.SYMBOL

local DEFAULT_STATS = { rank = RANKS[1][1], grade = 1, credits = RANKS[1][2][1] or 0, kills = 0, deaths = 0 }
local stats_mt = { __index = DEFAULT_STATS }

local function copy_default_stats()
    return {
        rank = DEFAULT_STATS.rank,
        grade = DEFAULT_STATS.grade,
        credits = DEFAULT_STATS.credits,
        kills = 0,
        deaths = 0
    }
end

local function normalize_stats(stats)
    if type(stats) ~= 'table' then stats = copy_default_stats() end

    stats.rank = tostring(stats.rank or DEFAULT_STATS.rank)
    stats.grade = tonumber(stats.grade) or DEFAULT_STATS.grade
    stats.credits = tonumber(stats.credits) or DEFAULT_STATS.credits
    stats.kills = tonumber(stats.kills) or 0
    stats.deaths = tonumber(stats.deaths) or 0

    return setmetatable(stats, stats_mt)
end

local function load_stats()
    local f = io_open(db_directory, 'r')
    if not f then
        stats_db = {}
        return true
    end

    local content = f:read('*a')
    f:close()

    if not content or content == '' then
        stats_db = {}
        return true
    end

    local success, result = pcall(function () return json:decode(content) end)
    if not success or type(result) ~= 'table' then
        print('Error parsing stats: ' .. tostring(result))
        stats_db = {}
        return false
    end

    for name, stats in pairs(result) do
        stats_db[name] = normalize_stats(stats)
    end

    return true
end

local function save_stats()
    local f, err = io_open(db_directory, 'w')
    if not f then
        print('Error opening stats db: ' .. tostring(err))
        return false
    end

    local success, json_str = pcall(function () return json:encode(stats_db) end)
    if not success then
        print('Error encoding stats: ' .. tostring(json_str))
        f:close()
        return false
    end

    f:write(json_str)
    f:close()

    return true
end

local function is_admin(id, lvl)
    return id == 0 or tonumber(get_var(id, '$lvl')) >= lvl
end

local function send_msg(recipient, msg, broadcast, exclude)
    if broadcast then
        for i = 1, 16 do
            if player_present(i) then
                rprint(i, msg)
            end
        end
    elseif exclude then
        for i = 1, 16 do
            if i ~= exclude and player_present(i) then
                rprint(i, msg)
            end
        end
    elseif not recipient or recipient == 0 then
        cprint(msg)
    else
        rprint(recipient, msg)
    end
end

local function find_rank(credits)
    local lo, hi, best = 1, #threshold_entries, threshold_entries[1]
    while lo <= hi do
        local mid = math_floor((lo + hi) * 0.5)
        local ent = threshold_entries[mid]
        if credits >= ent.credits then
            best = ent
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return best
end

local function refresh_player_rank(pl, silent)
    if not pl or not pl.stats then return false end

    local stats = pl.stats
    local old_rank = stats.rank
    local old_grade = stats.grade

    local best = find_rank(stats.credits or 0)
    if not best then return false end

    stats.rank, stats.grade = best.rank_name, best.grade
    pl.rank_index = best.rank_index

    if silent or (old_rank == stats.rank and old_grade == stats.grade) then return false end

    local promoted = (best.rank_index > (rank_lookup[old_rank] or 0))
        or (stats.rank == old_rank and stats.grade > old_grade)

    send_msg(pl.id, string_format('%s %s Grade %d', promoted and 'Rank Up:' or 'Rank Down:', stats.rank, stats.grade))
    send_msg(
        nil,
        string_format(
            '%s has %s to %s Grade %d!', pl.name, promoted and 'ranked up' or 'been demoted', stats.rank, stats.grade
        ), false, pl.id
    )
    return true
end

local function award_credits(pl, amount, label)
    if not pl or amount == 0 then return end

    pl.stats.credits = (pl.stats.credits or 0) + amount
    refresh_player_rank(pl, false)

    send_msg(pl.id, string_format(label, SYMBOL))
end

local function award_credit_entry(pl, entry)
    if pl and entry then
        award_credits(pl, entry[1], entry[2])
    end
end

local function get_tag_id(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function get_vehicle_obj_id(killer_id)
    local dyn = get_dynamic_player(killer_id)
    if dyn == 0 then return nil end

    local vid = read_dword(dyn + 0x11C)
    if vid == 0xFFFFFFFF then return nil end
    local obj = get_object_memory(vid)

    return obj ~= 0 and read_dword(obj) or nil
end

local function parse_args(input)
    local args = {}
    for s in tostring(input):gmatch('([^%s]+)') do
        args[#args + 1] = s
    end
    return args
end

local function compute_kdr(k, d)
    d = tonumber(d) or 0
    return d == 0 and (k > 0 and k or 0) or (tonumber(k) or 0) / d
end

local function get_player_score(stats, rank_index)
    return (rank_index or 0) * 100000 + (stats.grade or 1) * 10000
        + (stats.credits or 0) + compute_kdr(stats.kills, stats.deaths) * 1000
end

local function build_rank_tables()
    rank_lookup, threshold_entries = {}, {}

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

    table_sort(threshold_entries, function (a, b)
        return a.credits < b.credits
    end)
end

local function build_command_registry()
    command_registry = {}
    for _, cmd in ipairs(CONFIG.COMMANDS) do
        local name = tostring(cmd[1]):lower()
        command_registry[name] = { level = cmd[2] }
    end
end

local function new_player_state(id)
    local name = get_var(id, '$name')
    local stats = stats_db[name]

    if not stats then
        stats = copy_default_stats()
        stats_db[name] = setmetatable(stats, stats_mt)
    else
        stats = normalize_stats(stats)
        stats_db[name] = stats
    end

    local best = find_rank(stats.credits or 0)
    return {
        id = id,
        name = name,
        team = get_var(id, '$team'),
        last_damage = nil,
        headshot = nil,
        last_killer = nil,
        switched = false,
        stats = stats,
        rank_index = best and best.rank_index or 1
    }
end

local function cache_damage_tags()
    damage_rewards, vehicle_rewards = {}, {}

    for _, spec in ipairs(DAMAGE_TAGS) do
        if type(spec) == 'table' and #spec >= 3 then
            local mid = get_tag_id('jpt!', spec[1])
            if mid then
                damage_rewards[mid] = { credits = spec[2], label = spec[3] }
            end
        end
    end

    collision_meta_id = get_tag_id('jpt!', DAMAGE_TAGS.collision)
    falling_meta_id = get_tag_id('jpt!', 'globals\\falling')
    distance_meta_id = get_tag_id('jpt!', 'globals\\distance')

    for vehi, data in pairs(DAMAGE_TAGS.vehicles) do
        local mid = get_tag_id('vehi', vehi)
        if mid then
            vehicle_rewards[mid] = { credits = data[1], label = data[2] }
        end
    end
end

local function process_vehicle_squash(killer_id)
    local killer = players[killer_id]
    if not killer then return false end

    local vid = get_vehicle_obj_id(killer_id)
    if not vid then return false end

    local reward = vehicle_rewards[vid]
    if reward then
        award_credits(killer, reward.credits, reward.label)
        return true
    end
    return false
end

local function process_weapon_kill(killer_id, meta_id)
    local killer = players[killer_id]
    if not killer then return false end

    local reward = damage_rewards[meta_id]
    if reward then
        award_credits(killer, reward.credits, reward.label)
        return true
    end
    return false
end

local function reload_this(victim_id, killer)
    local dyn = get_dynamic_player(victim_id)
    if dyn ~= 0 and read_byte(dyn + 0x2A4) == 5 then
        award_credit_entry(killer, CREDITS.reload_this)
    end
end

local function close_call(killer_id, killer)
    local dyn = get_dynamic_player(killer_id)
    if dyn == 0 then return end

    local shields, health = read_float(dyn + 0xE4), read_float(dyn + 0xE0)
    if shields and shields <= 0 and health and health < 0.3 then
        award_credit_entry(killer, CREDITS.close_call)
    end
end

local function avenge(killer_id, victim_id, killer)
    for id = 1, 16 do
        local p = players[id]
        if p and id ~= killer_id and p.team == killer.team and p.last_killer == victim_id then
            award_credit_entry(killer, CREDITS.avenge)
            return
        end
    end
end

local function award_spree(killer_id)
    local static = get_player(killer_id)
    if static == 0 then return end

    local spree = read_word(static + 0x96)
    local reward = CREDITS.spree[spree]
    if reward then
        award_credits(players[killer_id], reward[1], reward[2])
    end
end

local function award_multi(killer_id)
    local static = get_player(killer_id)
    if static == 0 then return end

    local combo = read_word(static + 0x98)
    local reward = CREDITS.multi_kill[combo]
    if reward then
        award_credits(players[killer_id], reward[1], reward[2])
    end
end

local function get_progression(stats)
    local idx = rank_lookup[stats.rank] or 1
    local rank_data = RANKS[idx]
    local next_grade = (stats.grade or 1) + 1
    local threshold = rank_data[2][next_grade]

    if threshold then
        return {
            type = 'grade',
            rank = rank_data[1],
            grade = next_grade,
            needed = math_max(0, threshold - (stats.credits or 0)),
            total = threshold
        }
    end

    local next_rank = RANKS[idx + 1]
    if next_rank then
        local total = next_rank[2][1]
        return {
            type = 'rank',
            rank = next_rank[1],
            grade = 1,
            needed = math_max(0, total - (stats.credits or 0)),
            total = total
        }
    end
    return { type = 'max', rank = stats.rank, grade = stats.grade }
end

local function format_rank_info(name, stats, show_next)
    local lines = {
        string_format('%s: %s (Grade %d) %d %s', name, stats.rank, stats.grade, stats.credits or 0, SYMBOL),
        string_format('KDR: %.2f (%d/%d)', compute_kdr(stats.kills, stats.deaths), stats.kills or 0, stats.deaths or 0)
    }

    if show_next then
        local prog = get_progression(stats)
        if prog.type == 'grade' or prog.type == 'rank' then
            lines[#lines + 1] = string_format(
                'Next: %s Grade %d (need %d more %s)', prog.rank, prog.grade, prog.needed, SYMBOL
            )
        else
            lines[#lines + 1] = 'You have reached the highest rank!'
        end
    end
    return lines
end

local function insert_top(list, entry, limit)
    for i = 1, #list do
        if entry.score > list[i].score then
            table_insert(list, i, entry)
            if #list > limit then
                list[#list] = nil
            end
            return
        end
    end

    list[#list + 1] = entry
    if #list > limit then list[#list] = nil end
end

local function collect_top(limit)
    local top = {}
    for name, stats in pairs(stats_db) do
        if (stats.kills or 0) > 0 or (stats.deaths or 0) > 0 then
            local idx = rank_lookup[stats.rank] or 1
            insert_top(top, { name = name, stats = stats, score = get_player_score(stats, idx) }, limit)
        end
    end
    return top
end

local function show_top(limit, recipient, broadcast)
    limit = math_max(1, math_min(tonumber(limit) or CONFIG.STATS_LIMIT, 15))

    local top = collect_top(limit)
    if #top == 0 then
        if not broadcast then
            send_msg(recipient, 'No players found.')
        end
        return
    end

    local header = string_format('=== TOP %d PLAYERS ===', math_min(limit, #top))
    send_msg(recipient, header, broadcast, false)

    for i = 1, math_min(limit, #top) do
        local p = top[i]
        local kdr = compute_kdr(p.stats.kills, p.stats.deaths)
        send_msg(
            recipient,
            string_format(
                '%d. %s: %s G%d | %d credits | KDR: %.2f (%d/%d)', i, p.name, p.stats.rank, p.stats.grade,
                p.stats.credits, kdr, p.stats.kills, p.stats.deaths
            ), broadcast, false
        )
    end
end

local function on_cooldown(id, cmd)
    local key = id .. '_' .. cmd
    local now = os_time()
    local last = command_cooldowns[key]

    if last and now - last < CONFIG.COOLDOWN then
        return true, CONFIG.COOLDOWN - (now - last)
    end
    command_cooldowns[key] = now

    return false, 0
end

local function cmd_rank(id, args)
    local target_id = id

    if args[2] then
        local tid = tonumber(args[2])
        if tid and player_present(tid) then
            target_id = tid
        else
            send_msg(id, 'Player not found: ' .. tostring(args[2]))
            return false
        end
    end

    local pl = players[target_id]
    if not pl then
        send_msg(id, 'Player data unavailable')
        return false
    end

    for _, line in ipairs(format_rank_info(pl.name, pl.stats, true)) do
        send_msg(id, line)
    end
    return false
end

local function cmd_ranks(id)
    send_msg(id, '=== Available Ranks ===')
    for i, rank in ipairs(RANKS) do
        send_msg(id, string_format('%d. %s: [%s]', i, rank[1], table_concat(rank[2], ', ')))
    end
    return false
end

local function cmd_top(id, args)
    local lim = tonumber(args[2]) or 5
    lim = math_min(math_max(lim, 1), 15)
    show_top(lim, id, false)
    return false
end

local function cmd_setrank(id, args)
    if #args < 4 then
        send_msg(id, 'Usage: setrank <player_id> <rank_id> <grade>')
        return false
    end

    local tid = tonumber(args[2])
    if not tid or not player_present(tid) then
        send_msg(id, 'Player not found: ' .. tostring(args[2]))
        return false
    end

    local rid = tonumber(args[3])
    local grade = tonumber(args[4])
    if not rid or rid < 1 or rid > #RANKS then
        send_msg(id, 'Invalid rank ID')
        return false
    end

    local rank_data = RANKS[rid]
    if not grade or grade < 1 or grade > #rank_data[2] then
        send_msg(id, 'Invalid grade (1-' .. #rank_data[2] .. ') for rank ' .. rank_data[1])
        return false
    end

    local pl = players[tid]
    if not pl then
        send_msg(id, 'Player data unavailable')
        return false
    end

    pl.stats.credits = rank_data[2][grade]
    pl.stats.rank, pl.stats.grade = rank_data[1], grade
    local best = find_rank(pl.stats.credits)
    pl.rank_index = best and best.rank_index or rid

    send_msg(id, string_format('Set %s to %s Grade %d (%d credits)', pl.name, rank_data[1], grade, pl.stats.credits))

    if tid ~= id then
        send_msg(tid, 'An admin changed your rank!')
        send_msg(tid, string_format('New rank: %s Grade %d (%d credits)', rank_data[1], grade, pl.stats.credits))
    end

    return false
end

local function init_commands()
    command_registry.rank.handler = cmd_rank
    command_registry.ranks.handler = cmd_ranks
    command_registry.top.handler = cmd_top
    command_registry.setrank.handler = cmd_setrank
end

function OnScriptLoad()
    local loader, err = loadfile("json.lua")
    if not loader then error("json.lua missing: " .. tostring(err)) end

    local ok, lib = pcall(loader)
    if not ok or type(lib) ~= "table" then error("json.lua invalid") end
    json = lib

    local sig = sig_scan("68??????008D54245468")
    if sig == 0 then error("SAPP base scan failed") end

    local dir = read_string(read_dword(sig + 0x1))
    db_directory = dir .. "\\sapp\\ranks.json"

    if not load_stats() then print("Warning: stats load failed, starting fresh") end

    build_rank_tables()
    build_command_registry()
    init_commands()

    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")
    register_callback(cb.EVENT_DIE, "OnDeath")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_SCORE, "OnScore")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_TEAM_SWITCH, "OnSwitch")
    OnStart()
end

function OnStart()
    game_type = get_var(0, "$gt")
    if game_type == "n/a" then return end

    cache_damage_tags()
    first_blood = true
    ffa = get_var(0, "$ffa") == "1"

    for i = 1, 16 do
        if player_present(i) then OnJoin(i) end
    end
end

function OnEnd()
    save_stats()
    if CONFIG.SHOW_STATS_ON_END then
        show_top(CONFIG.STATS_LIMIT, nil, true)
    end
end

function OnJoin(id)
    local pl = new_player_state(id)
    players[id] = pl
    for _, line in ipairs(format_rank_info(pl.name, pl.stats, true)) do
        rprint(id, line)
    end
end

function OnQuit(id)
    players[id] = nil
end

function OnDamage(victim_id, _, meta_id, _, hit_string)
    local pl = players[victim_id]
    if pl then
        pl.last_damage = tonumber(meta_id)
        pl.headshot = (hit_string == 'head')
    end
end

function OnSpawn(id)
    local pl = players[id]
    if pl then
        pl.switched = nil
        pl.headshot = nil
        pl.last_damage = nil
    end
end

function OnSwitch(id)
    local pl = players[id]
    if pl then
        pl.switched = true
        pl.team = get_var(id, '$team')
    end
end

function OnScore(id)
    local pl = players[id]
    if not pl then return end

    local idx = ({ ctf = 1, race = not ffa and 2 or 3 })[game_type]
    if not idx then return end

    local data = CREDITS.game_score[idx]
    if data then
        award_credit_entry(pl, data)
    end
end

function OnDeath(victim_id, killer_id)
    victim_id, killer_id = tonumber(victim_id), tonumber(killer_id)
    local victim, killer = players[victim_id], players[killer_id]
    if not victim then return end

    local last_damage = victim.last_damage
    victim.last_damage, victim.headshot, victim.last_killer = nil, nil, killer_id

    if killer_id > 0 and killer_id ~= victim_id and killer then
        killer.stats.kills = (killer.stats.kills or 0) + 1
    end
    victim.stats.deaths = (victim.stats.deaths or 0) + 1

    if killer_id == -1 and not victim.switched then
        if last_damage == falling_meta_id then
            award_credit_entry(victim, DAMAGE_TAGS.falling)
        elseif last_damage == distance_meta_id then
            award_credit_entry(victim, DAMAGE_TAGS.distance)
        else
            award_credit_entry(victim, CREDITS.server)
        end
        return
    end

    if killer_id == nil then
        award_credit_entry(victim, CREDITS.guardians)
        return
    end

    if killer_id <= 0 or not killer then return end
    if killer_id == victim_id then
        award_credit_entry(killer, CREDITS.suicide)
        return
    end

    if not ffa and victim.team == killer.team then
        award_credit_entry(killer, CREDITS.betrayal)
        return
    end

    if first_blood then
        first_blood = false
        award_credit_entry(killer, CREDITS.first_blood)
    end

    if not player_alive(killer_id) then
        award_credit_entry(killer, CREDITS.killed_from_the_grave)
    end

    if victim.headshot then award_credit_entry(killer, CREDITS.head_shot) end
    if killer.last_killer == victim_id then
        award_credit_entry(killer, CREDITS.revenge)
    end

    if not ffa then
        avenge(killer_id, victim_id, killer)
    end

    reload_this(victim_id, killer)
    close_call(killer_id, killer)
    award_spree(killer_id)
    award_multi(killer_id)

    if collision_meta_id and last_damage == collision_meta_id then
        if process_vehicle_squash(killer_id) then
            return
        end
    end

    if last_damage then
        process_weapon_kill(killer_id, last_damage)
    end
end

function OnCommand(id, command)
    local args = parse_args(command)
    if #args == 0 then return end

    local cmd = args[1]:lower()
    local spec = command_registry[cmd]
    if not spec or not spec.handler then return true end

    if not is_admin(id, spec.level) then
        send_msg(id, 'Insufficient permission.')
        return false
    end

    local cooldown, left = on_cooldown(id, cmd)
    if cooldown then
        send_msg(id, string_format('Command cooldown: %d seconds.', left))
        return false
    end

    return spec.handler(id, args)
end

function OnScriptUnload()
    save_stats()
end
