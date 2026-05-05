--[[
=====================================================================================
SCRIPT NAME:      rank_system.lua
DESCRIPTION:      Advanced player ranking and progression system that tracks
                  player statistics, awards credits for in-game actions, and
                  implements a multi-tier ranking system with grade progression.

FEATURES:
                 - Comprehensive rank progression system with multiple grades per rank
                 - Real-time credit rewards/penalties for various combat actions and events
                 - Persistent player statistics storage using JSON database
                 - Admin commands for rank management and player tracking
                 - Leaderboard system with KDR-based scoring
                 - Optimized performance with precomputed data structures
                 - Command cooldown system to prevent spam

RANK SYSTEM DETAILS:
                 - Players progress through ranks by earning credits from kills and special events
                 - Each rank contains multiple grades that must be achieved before advancing
                 - Credit rewards are awarded for: headshots, revenge kills, multi-kills, sprees,
                   vehicle kills, weapon-specific kills, and various combat scenarios
                 - Penalties are applied for: suicides, betrayals, environmental deaths

CREDIT EVENTS:
                 - Combat Actions: Headshots, revenge, avenge, reload kills, close calls
                 - Kill Streaks: Spree bonuses at 5,10,15... kills and multi-kill chains
                 - Special Events: First blood, killed from the grave, vehicle squashes
                 - Weapon Specific: Different credit values per weapon type and damage source
                 - Penalties: Suicide, betrayal, falling, distance deaths

COMMANDS:
                 - rank [player_id]    - Check your or another player's rank and statistics
                 - ranks               - List all available ranks and their credit thresholds
                 - top [limit]         - Display leaderboard with top players by composite score
                 - setrank <id> <rank> <grade> - Admin command to set player rank (level 4 only)

DATA PERSISTENCE:
                 - Player stats automatically saved to 'sapp/ranks.json'
                 - Configurable save triggers: game end, player quit, script unload
                 - Survives server restarts and maintains player progression

CONFIGURATION:
                All aspects customizable via CONFIG table:
                 - Rank names and grade thresholds
                 - Credit values for all damage types and events
                 - Command permissions and currency symbol
                 - Database save timing and event triggers
                 - Command cooldown duration

REQUIREMENTS:   Install to the same directory as sapp.dll
                 - Lua JSON Parser: http://regex.info/blog/lua/json
                 - This scirpt ONLY works on maps with stock tag addresses

LAST UPDATED:     2/10/2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--CONFIG start ------------------------------------------------------

local CONFIG = {

    -- Symbol displayed in credit messages
    SYMBOL = 'cR',

    -- Command cooldown in seconds (prevents command spam)
    COOLDOWN = 3,

    -- Whether to display top players on game end
    SHOW_STATS_ON_END = true,
    STATS_LIMIT = 5,

    -- Commands and required permission levels (-1 = all players, 1-4 = admin levels)
    COMMANDS = {
        { 'rank',    -1 }, -- Check your or another player's rank
        { 'ranks',   -1 }, -- List all available ranks
        { 'top',     -1 }, -- Show leaderboard
        { 'setrank', 4 }   -- Admin command to set player rank (level 4 only)
    },

    -- Rank definitions: { "Rank Name", { grade1_threshold, grade2_threshold, ... } }
    -- Players progress through grades within each rank before advancing to next rank
    RANKS = {
        { "Recruit",          { [1] = 0 } },
        { "Apprentice",       { [1] = 3000, [2] = 6000 } },
        { "Private",          { [1] = 9000, [2] = 12000 } },
        { "Corporal",         { [1] = 13000, [2] = 14000 } },
        { "Sergeant",         { [1] = 15000, [2] = 16000, [3] = 17000, [4] = 18000 } },
        { "Gunnery Sergeant", { [1] = 19000, [2] = 20000, [3] = 21000, [4] = 22000 } },
        { "Lieutenant",       { [1] = 23000, [2] = 24000, [3] = 25000, [4] = 26000 } },
        { "Captain",          { [1] = 27000, [2] = 28000, [3] = 29000, [4] = 30000 } },
        { "Major",            { [1] = 31000, [2] = 32000, [3] = 33000, [4] = 34000 } },
        { "Commander",        { [1] = 35000, [2] = 36000, [3] = 37000, [4] = 38000 } },
        { "Colonel",          { [1] = 39000, [2] = 40000, [3] = 41000, [4] = 42000 } },
        { "Brigadier",        { [1] = 43000, [2] = 44000, [3] = 45000, [4] = 46000 } },
        { "General",          { [1] = 47000, [2] = 48000, [3] = 49000, [4] = 50000 } }
    },

    ----------------------------------------------
    -- Credit rewards/penalties for in-game events
    ----------------------------------------------

    -- NOTES:     1. Set to 0 to disable a credit event.
    --            2. %s will be replaced with currency symbol.

    CREDITS = {
        -- Bonus Events: { credit_amount, "display_message" }
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

        -- Consecutive spree kills
        spree = {
            [5]  = { 15, '+15 %s (Spree)' },
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

        -- Multi-kill: rapid consecutive kills
        multi_kill = {
            [2]  = { 8, '+8 %s (Double Kill)' },
            [3]  = { 15, '+15 %s (Triple Kill)' },
            [4]  = { 25, '+25 %s (Multi-Kill)' },
            [5]  = { 35, '+35 %s (Multi-Kill)' },
            [6]  = { 45, '+45 %s (Multi-Kill)' },
            [7]  = { 55, '+55 %s (Multi-Kill)' },
            [8]  = { 65, '+65 %s (Multi-Kill)' },
            [9]  = { 75, '+75 %s (Multi-Kill)' },
            [10] = { 100, '+100 %s (Ultra Kill)' }
        },

        -- Game scoring events
        game_score = {
            [1] = { 150, '+150 %s (Flag Capture)' },
            [2] = { 125, '+125 %s (Lap)' }, -- Team Race
            [3] = { 100, '+100 %s (Lap)' }  -- FFA Race
        },

        -- Damage Events
        damage_tags = {
            falling = { -5, '-5 %s (Fall)' },
            distance = { -5, '-5 %s (Distance)' },
            collision = 'globals\\vehicle_collision',

            -- Vehicle squash rewards
            vehicles = {
                ['vehicles\\ghost\\ghost_mp'] = { 15, '+15 %s (Ghost)' },
                ['vehicles\\rwarthog\\rwarthog'] = { 20, '+20 %s (R-Hog)' },
                ['vehicles\\warthog\\mp_warthog'] = { 25, '+25 %s (Warthog)' },
                ['vehicles\\banshee\\banshee_mp'] = { 30, '+30 %s (Banshee)' },
                ['vehicles\\scorpion\\scorpion_mp'] = { 35, '+35 %s (Tank)' },
                ['vehicles\\c gun turret\\c gun turret_mp'] = { 40, '+40 %s (Turret)' }
            },

            --------
            -- Weapon damage rewards
            --------
            -- Vehicles Damage
            { 'vehicles\\ghost\\ghost bolt',                              12, '+12 %s (Ghost)' },
            { 'vehicles\\scorpion\\bullet',                               10, '+10 %s (Tank)' },
            { 'vehicles\\warthog\\bullet',                                10, '+10 %s (Warthog)' },
            { 'vehicles\\c gun turret\\mp bolt',                          12, '+12 %s (Turret)' },
            { 'vehicles\\banshee\\banshee bolt',                          12, '+12 %s (Banshee)' },
            { 'vehicles\\scorpion\\shell explosion',                      20, '+20 %s (Tank Shell)' },
            { 'vehicles\\banshee\\mp_fuel rod explosion',                 20, '+20 %s (Fuel Rod)' },
            { 'vehicles\\doozy\\bullet',                                  8,  '+8 %s (Doozy)' },
            -- Weapons Damage
            { 'weapons\\pistol\\bullet',                                  8,  '+8 %s (Pistol)' },
            { 'weapons\\shotgun\\pellet',                                 12, '+12 %s (Shotgun)' },
            { 'weapons\\plasma rifle\\bolt',                              6,  '+6 %s (Plasma Rifle)' },
            { 'weapons\\needler\\explosion',                              15, '+15 %s (Needler)' },
            { 'weapons\\plasma pistol\\bolt',                             6,  '+6 %s (Plasma Pistol)' },
            { 'weapons\\assault rifle\\bullet',                           8,  '+8 %s (Assault Rifle)' },
            { 'weapons\\needler\\impact damage',                          6,  '+6 %s (Needler)' },
            { 'weapons\\flamethrower\\explosion',                         12, '+12 %s (Flamethrower)' },
            { 'weapons\\flamethrower\\burning',                           12, '+12 %s (Flamethrower)' },
            { 'weapons\\flamethrower\\impact damage',                     12, '+12 %s (Flamethrower)' },
            { 'weapons\\rocket launcher\\explosion',                      18, '+18 %s (Rocket Launcher)' },
            { 'weapons\\needler\\detonation damage',                      6,  '+6 %s (Needler)' },
            { 'weapons\\plasma rifle\\charged bolt',                      8,  '+8 %s (Plasma Rifle)' },
            { 'weapons\\sniper rifle\\sniper bullet',                     15, '+15 %s (Sniper Rifle)' },
            { 'weapons\\plasma_cannon\\effects\\plasma_cannon_explosion', 18, '+18 %s (Plasma Cannon)' },
            { 'weapons\\frag grenade\\explosion',                         15, '+15 %s (Frag)' },
            { 'weapons\\plasma grenade\\attached',                        15, '+15 %s (Plasma Grenade)' },
            { 'weapons\\plasma grenade\\explosion',                       10, '+10 %s (Plasma Grenade)' },
            -- Melee
            { 'weapons\\flag\\melee',                                     8,  '+8 %s (Flag)' },
            { 'weapons\\ball\\melee',                                     8,  '+8 %s (Ball)' },
            { 'weapons\\pistol\\melee',                                   6,  '+6 %s (Pistol)' },
            { 'weapons\\needler\\melee',                                  6,  '+6 %s (Needler)' },
            { 'weapons\\shotgun\\melee',                                  8,  '+8 %s (Shotgun)' },
            { 'weapons\\flamethrower\\melee',                             8,  '+8 %s (Flamethrower)' },
            { 'weapons\\sniper rifle\\melee',                             8,  '+8 %s (Sniper Rifle)' },
            { 'weapons\\plasma rifle\\melee',                             6,  '+6 %s (Plasma Rifle)' },
            { 'weapons\\plasma pistol\\melee',                            6,  '+6 %s (Plasma Pistol)' },
            { 'weapons\\assault rifle\\melee',                            6,  '+6 %s (Assault Rifle)' },
            { 'weapons\\rocket launcher\\melee',                          15, '+15 %s (Rocket Launcher)' },
            { 'weapons\\plasma_cannon\\effects\\plasma_cannon_melee',     15, '+15 %s (Plasma Cannon)' }
        }
    }
}

-------------------------------------------------------------------
--CONFIG end ------------------------------------------------------
-------------------------------------------------------------------

api_version = '1.12.0.0'

-- Precomputed data structures for optimization
local RANK_LOOKUP = {}
local GRADE_THRESHOLDS = {}
local SORTED_THRESHOLDS = {}
local COMMAND_LOOKUP = {}

local stats_db = {} -- Persistent stats database
local db_directory, json

local players = {}
local damage_meta_ids = {}
local collision_meta_id = nil
local vehicle_meta_ids = {}
local ffa, falling, distance, first_blood, game_type

-- Command cooldown tracking
local command_cooldowns = {}

local io_open = io.open
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local type = type
local table_sort = table.sort
local tonumber, tostring, string_format = tonumber, tostring, string.format
local math_floor, math_min = math.floor, math.min
local os_time = os.time

local get_var = get_var
local read_dword = read_dword
local read_byte = read_byte
local read_float = read_float
local read_word = read_word
local get_dynamic_player = get_dynamic_player
local get_object_memory = get_object_memory
local get_player = get_player
local player_alive = player_alive
local player_present = player_present
local lookup_tag = lookup_tag
local cprint, rprint = cprint, rprint

local function loadStatsDB()
    local f = io_open(db_directory, 'r')
    if not f then
        stats_db = {}
        return true
    end

    local content = f:read('*a')
    f:close()

    if content and content ~= '' then
        local success, result = pcall(function()
            return json:decode(content)
        end)
        if success and result then
            stats_db = result
            return true
        else
            print("Error parsing stats database: " .. tostring(result))
            stats_db = {}
            return false
        end
    else
        stats_db = {}
        return true
    end
end

local function saveStatsDB()
    local f, err = io.open(db_directory, 'w')
    if not f then
        print("Error opening stats database for writing: " .. err)
        return false
    end

    local success, json_str = pcall(function()
        return json:encode(stats_db)
    end)

    if not success then
        print("Error encoding stats database: " .. tostring(json_str))
        f:close()
        return false
    end

    f:write(json_str)
    f:close()
    return true
end

local function hasPermission(id, required_level)
    if id == 0 then return true end
    return tonumber(get_var(id, '$lvl')) >= required_level
end

local function send(id, msg, exclude, all_players)
    if id == 0 then return cprint(msg) end
    if exclude then
        for i, _ in pairs(players) do
            if i ~= id then
                rprint(i, msg)
            end
        end
        return
    elseif all_players then
        for i, _ in pairs(players) do
            rprint(i, msg)
        end
        return
    end
    rprint(id, msg)
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function getVehicleObjectID(killer_id)
    local dyn_player = get_dynamic_player(killer_id)
    if dyn_player == 0 then return nil end

    local vehicle_id = read_dword(dyn_player + 0x11C)
    if vehicle_id == 0xFFFFFFFF then return nil end

    local vehicle_object = get_object_memory(vehicle_id)
    if vehicle_object == 0 then return nil end

    return read_dword(vehicle_object)
end

local function parseArgs(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function calculateKDR(kills, deaths)
    if deaths == 0 then return kills > 0 and kills or 0 end
    return kills / deaths
end

local function getPlayerScore(stats)
    local rank_index = RANK_LOOKUP[stats.rank] or 0
    local rank_score = rank_index * 100000
    local grade_score = stats.grade or 1
    local credit_score = stats.credits or 0
    local kdr_score = calculateKDR(stats.kills or 0, stats.deaths or 0) * 1000

    return rank_score + grade_score * 10000 + credit_score + kdr_score
end

local function initializePlayer(id)
    local name = get_var(id, '$name')

    if not stats_db[name] then
        local default_rank = CONFIG.RANKS[1]
        stats_db[name] = {
            rank = default_rank[1],
            grade = 1,
            credits = default_rank[2][1],
            kills = 0,
            deaths = 0
        }
    end

    return {
        name = name,
        team = get_var(id, '$team'),
        id = id,
        last_damage = nil,
        headshot = nil,
        last_killer = nil,
        switched = false,
        stats = stats_db[name]
    }
end

local function updatePlayerRank(player)
    local old_rank = player.stats.rank
    local old_grade = player.stats.grade
    local credits = player.stats.credits
    local id = player.id

    -- Binary search for the appropriate threshold
    local low, high = 1, #SORTED_THRESHOLDS
    local best_match = nil

    while low <= high do
        local mid = math_floor((low + high) / 2)
        local threshold = SORTED_THRESHOLDS[mid]

        if credits >= threshold then
            best_match = GRADE_THRESHOLDS[threshold]
            low = mid + 1 -- Look for higher threshold
        else
            high = mid - 1
        end
    end

    local new_rank, new_grade
    if best_match then
        new_rank = best_match[3]
        new_grade = best_match[2]
    else
        -- Default to first rank
        new_rank = CONFIG.RANKS[1][1]
        new_grade = 1
    end

    -- Only update if changed
    if old_rank ~= new_rank or old_grade ~= new_grade then
        player.stats.rank = new_rank
        player.stats.grade = new_grade

        local old_index = RANK_LOOKUP[old_rank] or 0
        local new_index = RANK_LOOKUP[new_rank]

        if new_index > old_index or (new_index == old_index and new_grade > old_grade) then
            send(id, string_format("Rank Up: %s Grade %d", new_rank, new_grade))
            send(id, string_format("%s has ranked up to %s Grade %d!", player.name, new_rank, new_grade), true)
        else
            send(id, string_format("Rank Down: %s Grade %d", new_rank, new_grade))
            send(id, string_format("%s has been demoted to %s Grade %d!", player.name, new_rank, new_grade), true)
        end
    end
end

local function awardCredits(player, amount, label)
    if not player or amount == 0 then return end

    player.stats.credits = player.stats.credits + amount
    updatePlayerRank(player)

    local formatted_label = string_format(label, CONFIG.SYMBOL)
    send(player.id, formatted_label)
end

local function initializeDamageSystem()
    damage_meta_ids, vehicle_meta_ids, collision_meta_id = {}, {}, nil

    for _, tag_data in ipairs(CONFIG.CREDITS.damage_tags) do
        if type(tag_data) == 'table' and #tag_data >= 2 then
            local meta_id = getTag('jpt!', tag_data[1])
            if meta_id then
                damage_meta_ids[meta_id] = {
                    credits = tag_data[2],
                    label = tag_data[3]
                }
            end
        end
    end

    collision_meta_id = getTag('jpt!', CONFIG.CREDITS.damage_tags.collision)

    local vehicles = CONFIG.CREDITS.damage_tags.vehicles
    if vehicles then
        for vehicle_tag, vehicle_data in pairs(vehicles) do
            local vehicle_meta_id = getTag('vehi', vehicle_tag)
            if vehicle_meta_id then
                vehicle_meta_ids[vehicle_meta_id] = {
                    credits = vehicle_data[1],
                    label = vehicle_data[2]
                }
            end
        end
    end
end

local function processVehicleSquash(killer_id)
    local killer_data = players[killer_id]

    local vehicle_object_id = getVehicleObjectID(killer_id)
    if not vehicle_object_id then return false end

    local vehicle_data = vehicle_meta_ids[vehicle_object_id]

    if vehicle_data then
        awardCredits(killer_data, vehicle_data.credits, vehicle_data.label)
        return true
    end

    return false
end

local function processWeaponKill(killer_id, damage_meta_id)
    local killer_data = players[killer_id]

    local damage_data = damage_meta_ids[damage_meta_id]
    if damage_data then
        awardCredits(killer_data, damage_data.credits, damage_data.label)
        return true
    end

    return false
end

local function reloadThis(victim_id, killer_data)
    local dyn_player = get_dynamic_player(victim_id)
    if dyn_player == 0 then return nil end

    local reloading = read_byte(dyn_player + 0x2A4)
    if reloading == 5 then
        awardCredits(killer_data, CONFIG.CREDITS.reload_this[1], CONFIG.CREDITS.reload_this[2])
    end
end

local function closeCall(killer_id, killer_data)
    local dyn_player = get_dynamic_player(killer_id)
    if dyn_player == 0 then return end

    local health = read_float(dyn_player + 0xE0)
    local shields = read_float(dyn_player + 0xE4)
    if shields and shields <= 0 and health and health < 0.3 then
        awardCredits(killer_data, CONFIG.CREDITS.close_call[1], CONFIG.CREDITS.close_call[2])
    end
end

local function awardAvengeBonus(killer_id, victim_id, killer_data)
    for id, player in pairs(players) do
        if id ~= killer_id and player.team == killer_data.team and player.last_killer == victim_id then
            awardCredits(killer_data, CONFIG.CREDITS.avenge[1], CONFIG.CREDITS.avenge[2])
            break
        end
    end
end

local function spree(killer_id)
    local static_player = get_player(killer_id)
    if static_player == 0 then return end

    local spree_count = read_word(static_player + 0x96) -- current spree

    -- Check if the spree count matches any configured threshold
    local award_data = CONFIG.CREDITS.spree[spree_count]
    if award_data then
        local killer_data = players[killer_id]
        if killer_data then
            awardCredits(killer_data, award_data[1], award_data[2])
        end
    end
end

local function multiKiller(killer_id)
    local static_player = get_player(killer_id)
    if static_player == 0 then return end

    local combo = read_word(static_player + 0x98) -- kill-combo

    -- Check if the combo matches any configured threshold
    local award_data = CONFIG.CREDITS.multi_kill[combo]
    if award_data then
        local killer_data = players[killer_id]
        if killer_data then
            awardCredits(killer_data, award_data[1], award_data[2])
        end
    end
end

local function processPlayerDeath(victim_id, killer_id)
    victim_id = tonumber(victim_id)
    killer_id = tonumber(killer_id)

    local victim_data = players[victim_id]
    if not victim_data then return end

    local killer_data = players[killer_id]
    local last_damage = victim_data.last_damage

    -- Reset victim's last damage/headshot
    victim_data.last_damage = nil; victim_data.headshot = nil

    -- Track last killer for revenge/avenge
    victim_data.last_killer = killer_id

    -- Update kill/death stats
    if killer_id > 0 and killer_id ~= victim_id and killer_data then
        killer_data.stats.kills = (killer_data.stats.kills or 0) + 1
    end

    victim_data.stats.deaths = (victim_data.stats.deaths or 0) + 1

    -- Server kill (falling, distance, etc.)
    if killer_id == -1 and not victim_data.switched then
        if falling and last_damage == falling then
            awardCredits(victim_data, CONFIG.CREDITS.damage_tags.falling[1], CONFIG.CREDITS.damage_tags.falling[2])
        elseif distance and last_damage == distance then
            awardCredits(victim_data, CONFIG.CREDITS.damage_tags.distance[1], CONFIG.CREDITS.damage_tags.distance[2])
        else
            awardCredits(victim_data, CONFIG.CREDITS.server[1], CONFIG.CREDITS.server[2])
        end
        -- Guardians kill
    elseif killer_id == nil then
        awardCredits(victim_data, CONFIG.CREDITS.guardians[1], CONFIG.CREDITS.guardians[2])
        -- PvP kills
    elseif killer_id > 0 then
        -- Suicide
        if killer_id == victim_id then
            awardCredits(killer_data, CONFIG.CREDITS.suicide[1], CONFIG.CREDITS.suicide[2])
            -- Betrayal (team kill in non-FFA)
        elseif not ffa and killer_data and victim_data.team == killer_data.team then
            awardCredits(killer_data, CONFIG.CREDITS.betrayal[1], CONFIG.CREDITS.betrayal[2])
        else
            -- First Blood (only award once per game)
            if first_blood then
                first_blood = false
                awardCredits(killer_data, CONFIG.CREDITS.first_blood[1], CONFIG.CREDITS.first_blood[2])
            end

            -- Killed from the grave
            if not player_alive(killer_id) then
                awardCredits(killer_data, CONFIG.CREDITS.killed_from_the_grave[1],
                    CONFIG.CREDITS.killed_from_the_grave[2])
            end

            -- Headshot bonus
            if victim_data.headshot then
                awardCredits(killer_data, CONFIG.CREDITS.head_shot[1], CONFIG.CREDITS.head_shot[2])
            end

            -- Revenge bonus (killed someone who recently killed you)
            if killer_data.last_killer == victim_id then
                awardCredits(killer_data, CONFIG.CREDITS.revenge[1], CONFIG.CREDITS.revenge[2])
            end

            -- Avenge bonus (killed someone who recently killed a teammate)
            if not ffa then
                awardAvengeBonus(killer_id, victim_id, killer_data)
            end

            -- Reloading this bonus
            reloadThis(victim_id, killer_data)

            -- Close call bonus
            closeCall(killer_id, killer_data)

            -- Process spree bonus
            spree(killer_id)

            -- Process multi-kill bonus
            multiKiller(killer_id)

            -- Process vehicle squash
            if collision_meta_id and last_damage == collision_meta_id then
                if processVehicleSquash(killer_id) then
                    return
                end
            end

            -- Process weapon damage
            if last_damage then
                processWeaponKill(killer_id, last_damage)
            end
        end
    end
end

local function getRankProgressionInfo(player_stats)
    local current_credits = player_stats.credits
    local current_rank = player_stats.rank
    local current_grade = player_stats.grade

    -- Find current rank index
    local current_rank_index = RANK_LOOKUP[current_rank] or 1

    -- Check if player can progress within current rank
    local current_rank_data = CONFIG.RANKS[current_rank_index]
    local next_grade = current_grade + 1

    if current_rank_data[2][next_grade] then
        -- Next grade in current rank
        local credits_needed = current_rank_data[2][next_grade] - current_credits
        return {
            type = "grade",
            rank = current_rank,
            grade = next_grade,
            credits_needed = credits_needed,
            total_credits = current_rank_data[2][next_grade]
        }
    else
        -- Next rank
        local next_rank_index = current_rank_index + 1
        if CONFIG.RANKS[next_rank_index] then
            local next_rank_data = CONFIG.RANKS[next_rank_index]
            local credits_needed = next_rank_data[2][1] - current_credits
            return {
                type = "rank",
                rank = next_rank_data[1],
                grade = 1,
                credits_needed = credits_needed,
                total_credits = next_rank_data[2][1]
            }
        else
            -- Max rank achieved
            return {
                type = "max",
                rank = current_rank,
                grade = current_grade
            }
        end
    end
end

local function formatRankInfo(player_name, player_stats, show_progression)
    local rank = player_stats.rank
    local grade = player_stats.grade
    local credits = player_stats.credits
    local kills = player_stats.kills or 0
    local deaths = player_stats.deaths or 0
    local kdr = calculateKDR(kills, deaths)

    local lines = {
        string_format("%s: %s (Grade %d) - %d %s", player_name, rank, grade, credits, CONFIG.SYMBOL),
        string_format("KDR: %.2f (%d/%d)", kdr, kills, deaths)
    }

    if show_progression then
        local progression = getRankProgressionInfo(player_stats)

        if progression.type == "grade" then
            table.insert(lines, string_format(
                "Next: %s Grade %d (need %d more %s)",
                progression.rank,
                progression.grade,
                progression.credits_needed,
                CONFIG.SYMBOL
            ))
        elseif progression.type == "rank" then
            table.insert(lines, string_format(
                "Next: %s Grade %d (need %d more %s)",
                progression.rank,
                progression.grade,
                progression.credits_needed,
                CONFIG.SYMBOL
            ))
        else
            table.insert(lines, "You have reached the highest rank!")
        end
    end

    return lines
end

local function getTopPlayers()
    local all_players = {}

    -- Pre-allocated table for performance reasons
    for name, stats in pairs(stats_db) do
        if (stats.kills or 0) > 0 or (stats.deaths or 0) > 0 then
            all_players[#all_players + 1] = {
                name = name,
                stats = stats,
                score = getPlayerScore(stats)
            }
        end
    end

    -- Sort with pre-calculated scores
    table.sort(all_players, function(a, b)
        return a.score > b.score
    end)

    return all_players
end

local function displayTopPlayers(limit, recipient_id, is_broadcast)
    local top_players = getTopPlayers()

    if #top_players == 0 then
        if not is_broadcast then
            send(recipient_id, "No players found.")
        end
        return
    end

    local display_limit = math_min(limit, #top_players)
    local header = string_format("=== TOP %d PLAYERS ===", display_limit)

    if is_broadcast then
        send(nil, header, nil, true)
    else
        send(recipient_id, header)
    end

    for i = 1, display_limit do
        local player = top_players[i]
        local kdr = calculateKDR(player.stats.kills, player.stats.deaths)
        local msg = string_format(
            "%d. %s: %s G%d | %d credits | KDR: %.2f (%d/%d)",
            i,
            player.name,
            player.stats.rank,
            player.stats.grade,
            player.stats.credits,
            kdr,
            player.stats.kills,
            player.stats.deaths
        )

        if is_broadcast then
            send(nil, msg, nil, true)
        else
            send(recipient_id, msg)
        end
    end
end

local function isOnCooldown(id, command)
    local key = id .. "_" .. command
    local current_time = os_time()

    if command_cooldowns[key] then
        local time_since_last_use = current_time - command_cooldowns[key]
        if time_since_last_use < CONFIG.COOLDOWN then
            return true, CONFIG.COOLDOWN - time_since_last_use
        end
    end

    command_cooldowns[key] = current_time
    return false, 0
end

function OnScriptLoad()
    local success, result = pcall(function()
        return loadfile('json.lua')()
    end)

    if not success or not result then
        error("Failed to load json.lua. Make sure the file exists and is valid.")
        return
    end
    json = result

    local directory = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1))
    db_directory = directory .. '\\sapp\\ranks.json'

    if not loadStatsDB() then
        print("Warning: Could not load stats database, starting with empty database")
    end

    -- Initialize optimized data structures
    for rank_index, rank_data in ipairs(CONFIG.RANKS) do
        local rank_name = rank_data[1]
        RANK_LOOKUP[rank_name] = rank_index

        for grade, threshold in ipairs(rank_data[2]) do
            GRADE_THRESHOLDS[threshold] = { rank_index, grade, rank_name }
            table.insert(SORTED_THRESHOLDS, threshold)
        end
    end

    table_sort(SORTED_THRESHOLDS)

    for _, cmd_data in ipairs(CONFIG.COMMANDS) do
        COMMAND_LOOKUP[cmd_data[1]:lower()] = cmd_data[2]
    end

    register_callback(cb['EVENT_DIE'], 'OnDeath')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_SCORE'], 'OnScore')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_TEAM_SWITCH'], 'OnSwitch')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDamage')

    OnStart() -- in case the script is loaded mid-game
end

function OnStart()
    game_type = get_var(0, '$gt')
    if game_type == 'n/a' then return end

    initializeDamageSystem()
    first_blood = true
    ffa = get_var(0, '$ffa') == '1'
    falling = getTag('jpt!', 'globals\\falling')
    distance = getTag('jpt!', 'globals\\distance')

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnEnd()
    saveStatsDB()
    if CONFIG.SHOW_STATS_ON_END then
        displayTopPlayers(CONFIG.STATS_LIMIT, nil, true)
    end
end

function OnJoin(id)
    players[id] = initializePlayer(id)
    local player = players[id]
    if player and player.stats then
        local lines = formatRankInfo(player.name, player.stats, true)
        for _, line in ipairs(lines) do
            rprint(id, line)
        end
    end
end

function OnQuit(id)
    players[id] = nil
end

function OnDamage(victim_id, _, meta_id, _, hitstring)
    victim_id = tonumber(victim_id)
    if players[victim_id] then
        players[victim_id].last_damage = tonumber(meta_id)
        players[victim_id].headshot = hitstring == 'head' or nil
    end
end

function OnDeath(victim_id, killer_id)
    processPlayerDeath(victim_id, killer_id)
end

function OnSpawn(id)
    if players[id] then
        players[id].switched = nil
        players[id].headshot = nil
        players[id].last_damage = nil
    end
end

function OnSwitch(id)
    if players[id] then
        players[id].switched = true
        players[id].team = get_var(id, '$team')
    end
end

function OnScore(id)
    if players[id] then
        -- Map game types to game_score index
        local score_index = ({
            ctf = 1,
            race = not ffa and 2 or 3
        })[game_type]

        if not score_index then return end

        local score_data = CONFIG.CREDITS.game_score[score_index]
        if not score_data then return end

        awardCredits(players[id], score_data[1], score_data[2])
    end
end

function OnCommand(id, command)
    local args = parseArgs(command)

    if #args == 0 then return true end

    local cmd = args[1]:lower()

    -- Command lookup
    local required_level = COMMAND_LOOKUP[cmd]
    if not required_level then return true end

    -- Check permission level
    if not hasPermission(id, required_level) then
        send(id, "Insufficient permission level for this command.")
        return false
    end

    -- Check command cooldown
    local on_cooldown, time_left = isOnCooldown(id, cmd)
    if on_cooldown then
        send(id, string_format("Command on cooldown. Please wait %d seconds.", time_left))
        return false
    end

    if cmd == 'rank' then
        local target_id = id
        local player = players[target_id]

        if #args >= 2 then
            local input_id = tonumber(args[2])
            if input_id and player_present(input_id) then
                target_id = input_id
                player = players[target_id]
            else
                send(id, "Player not found with ID: " .. args[2])
                return false
            end
        end

        if not player then
            send(id, "Player data not available")
            return false
        end

        local lines = formatRankInfo(player.name, player.stats, true)
        for _, line in ipairs(lines) do
            send(id, line)
        end

        return false
    elseif cmd == 'setrank' then
        if #args < 4 then
            send(id, "Usage: setrank <player_id> <rank_id> <grade>")
            return false
        end

        local target_id = tonumber(args[2])
        if not target_id or not player_present(target_id) then
            send(id, "Player not found with ID: " .. args[2])
            return false
        end

        local rank_id = tonumber(args[3])
        local grade = tonumber(args[4])
        if not rank_id or rank_id < 1 or rank_id > #CONFIG.RANKS then
            send(id, "Invalid rank ID: " .. tostring(args[3]))
            return false
        end

        local selected_rank = CONFIG.RANKS[rank_id]
        if not grade or grade < 1 or grade > #selected_rank[2] then
            send(id, "Invalid grade index for rank " .. selected_rank[1] ..
                ". Must be between 1 and " .. #selected_rank[2])
            return false
        end

        local player = players[target_id]

        -- Set player credits to exact value for that rank/grade
        player.stats.credits = selected_rank[2][grade]
        player.stats.rank = selected_rank[1]
        player.stats.grade = grade

        local new_rank = player.stats.rank
        send(id, "Set " .. player.name .. " to rank " .. new_rank ..
            " (Grade " .. grade .. ", " .. player.stats.credits .. " credits)")

        if target_id ~= id then
            rprint(target_id, "An admin has set your rank!")
            rprint(target_id,
                "New rank: " .. new_rank .. " (Grade " .. grade .. ", " .. player.stats.credits .. " credits)")
        end

        return false
    elseif cmd == 'ranks' then
        send(id, "=== Available Ranks ===")
        for i, rank_data in ipairs(CONFIG.RANKS) do
            local grades = table.concat(rank_data[2], ", ")
            send(id, i .. ". " .. rank_data[1] .. ": [" .. grades .. "]")
        end
        return false
    elseif cmd == 'top' then
        local limit = tonumber(args[2]) or 5
        if limit > 15 then limit = 15 end
        displayTopPlayers(limit, id)
        return false
    end

    return true
end

function OnScriptUnload()
    saveStatsDB()
end
