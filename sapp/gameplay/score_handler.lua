--[[
=====================================================================================
SCRIPT NAME:      score_handler.lua
DESCRIPTION:      Advanced scoring system with configurable points and custom messages.

                  Awards points for kills, flag captures, flag carrier kills, assists, first blood,
                  headshots, assassinations, killing sprees, multikills, and more. Handles special
                  cases like suicide, betrayal, team change penalty, fall damage, vehicle squash,
                  and “killed from the grave”. Includes optional zombie mode (infection points) and
                  damage-source mapping for weapons, grenades, melee, and vehicles.

Copyright (c) 2021-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local config = {
    custom_messages = true, -- Show custom scoring messages

    -- Base points and messages
    score = { 1, "Flag Capture" },
    red_flag_kill = { 5, "Red Flag Carrier Kill" },
    blue_flag_kill = { 5, "Blue Flag Carrier Kill" },
    assist = { 1, "Assist" },
    server = { 0, "Killed by Server" },
    killed_from_the_grave = { 1, "Killed from the grave" },
    first_blood = { 1, "First Blood" },
    head_shot = { 3, "Headshot" },
    assassination = { 1, "Assassination" },
    guardians = { -1, "Guardians" },
    suicide = { -1, "Suicide (rip)" },
    betrayal = { -1, "Betrayal" },
    team_change = { -1, "Team Change Penalty" },
    squashed = { -1, "Squashed" },

    -- Zombie mode (disabled by default)
    zombies = {
        points = { 1, "Zombie Infect" },
        enabled = false,
        human_team = "red",
        zombie_team = "blue"
    },

    -- Killing spree bonuses
    spree = {
        { 5, 1, "Spree" },
        { 10, 1, "Spree" },
        { 15, 1, "Spree" },
        { 20, 1, "Spree" },
        { 25, 1, "Spree" },
        { 30, 1, "Spree" },
        { 35, 1, "Spree" },
        { 40, 1, "Spree" },
        { 45, 1, "Spree" },
        { 50, 2, 5, "Spree" } -- 2 points every 5 kills after 50
    },

    -- Multi‑kill bonuses
    multi_kill = {
        { 2, 1, "Combo Kill" },
        { 3, 1, "Combo Kill" },
        { 4, 1, "Combo Kill" },
        { 5, 1, "Combo Kill" },
        { 6, 1, "Combo Kill" },
        { 7, 1, "Combo Kill" },
        { 8, 1, "Combo Kill" },
        { 9, 1, "Combo Kill" },
        { 10, 2, 2, "Combo Kill" } -- 2 points every 2 kills after 10
    },

    -- Damage source mapping (tag path -> points, message)
    tags = {
        -- Fall damage
        { "jpt!", "globals\\falling", -1, "Hit the ground too hard" },
        { "jpt!", "globals\\distance", -1, "Fall Damage" },
        -- Vehicle projectiles
        { "jpt!", "vehicles\\ghost\\ghost bolt", 1, "Ghost Bolt" },
        { "jpt!", "vehicles\\scorpion\\bullet", 1, "Tank Bullet" },
        { "jpt!", "vehicles\\warthog\\bullet", 1, "Hog Bullet" },
        { "jpt!", "vehicles\\c gun turret\\mp bolt", 1, "Turret Bolt" },
        { "jpt!", "vehicles\\banshee\\banshee bolt", 1, "Banshee Bolt" },
        { "jpt!", "vehicles\\scorpion\\shell explosion", 1, "Tank Shell" },
        { "jpt!", "vehicles\\banshee\\mp_fuel rod explosion", 1, "Banshee Fuel Rod" },
        -- Weapon projectiles
        { "jpt!", "weapons\\pistol\\bullet", 1, "Pistol Bullet" },
        { "jpt!", "weapons\\shotgun\\pellet", 1, "Shotgun Bullet" },
        { "jpt!", "weapons\\plasma rifle\\bolt", 1, "Plasma Rifle Bolt" },
        { "jpt!", "weapons\\needler\\explosion", 1, "Needler Explosion" },
        { "jpt!", "weapons\\plasma pistol\\bolt", 1, "Plasma Pistol Bolt" },
        { "jpt!", "weapons\\assault rifle\\bullet", 1, "Assault Rifle Bullet" },
        { "jpt!", "weapons\\needler\\impact damage", 1, "Needler Explosion" },
        { "jpt!", "weapons\\flamethrower\\explosion", 1, "Flames" },
        { "jpt!", "weapons\\flamethrower\\burning", 1, "Flames" },
        { "jpt!", "weapons\\flamethrower\\impact damage", 1, "Flames" },
        { "jpt!", "weapons\\rocket launcher\\explosion", 1, "Rocket Explosion" },
        { "jpt!", "weapons\\needler\\detonation damage", 1, "Needler Explosion" },
        { "jpt!", "weapons\\plasma rifle\\charged bolt", 1, "Plasma Rifle Bolt (charged)" },
        { "jpt!", "weapons\\sniper rifle\\sniper bullet", 1, "Sniper Bullet" },
        { "jpt!", "weapons\\plasma_cannon\\effects\\plasma_cannon_explosion", 1, "Fuel Rod Explosion" },
        -- Grenades
        { "jpt!", "weapons\\frag grenade\\explosion", 1, "Frag Explosion" },
        { "jpt!", "weapons\\plasma grenade\\attached", 2, "Sticky" },
        { "jpt!", "weapons\\plasma grenade\\explosion", 1, "Plasma Explosion" },
        -- Melee
        { "jpt!", "weapons\\flag\\melee", 2, "Flag Melee" },
        { "jpt!", "weapons\\ball\\melee", 2, "Skull Melee" },
        { "jpt!", "weapons\\pistol\\melee", 2, "Pistol Melee" },
        { "jpt!", "weapons\\needler\\melee", 2, "Needler Melee" },
        { "jpt!", "weapons\\shotgun\\melee", 2, "Shotgun Melee" },
        { "jpt!", "weapons\\flamethrower\\melee", 2, "Flamethrower Melee" },
        { "jpt!", "weapons\\sniper rifle\\melee", 2, "Sniper Melee" },
        { "jpt!", "weapons\\plasma rifle\\melee", 2, "Plasma Rifle Melee" },
        { "jpt!", "weapons\\plasma pistol\\melee", 2, "Plasma Pistol Melee" },
        { "jpt!", "weapons\\assault rifle\\melee", 2, "Assault Rifle Melee" },
        { "jpt!", "weapons\\rocket launcher\\melee", 2, "Rocket Launcher Melee" },
        { "jpt!", "weapons\\plasma_cannon\\effects\\plasma_cannon_melee", 2, "Plasma Cannon Melee" },

        -- Vehicle collision (special handling)
        collision = { "jpt!", "globals\\vehicle_collision" },
        vehicles = {
            { "vehi", "vehicles\\ghost\\ghost_mp", 1, "Ghost Squash" },
            { "vehi", "vehicles\\rwarthog\\rwarthog", 1, "Rocket Hog Squash" },
            { "vehi", "vehicles\\warthog\\mp_warthog", 1, "Hog Squash" },
            { "vehi", "vehicles\\banshee\\banshee_mp", 1, "Banshee Squash" },
            { "vehi", "vehicles\\scorpion\\scorpion_mp", 1, "Tank Squash" },
            { "vehi", "vehicles\\c gun turret\\c gun turret_mp", 0, "Turret Squash (how?)" }
        }
    }
}

local tonumber = tonumber
local ipairs = ipairs
local type = type
local string_format = string.format

local get_var = get_var
local execute_command = execute_command
local rprint = rprint
local player_present = player_present
local player_alive = player_alive
local get_player = get_player
local get_dynamic_player = get_dynamic_player
local read_dword = read_dword
local read_word = read_word
local read_string = read_string
local lookup_tag = lookup_tag
local register_callback = register_callback
local sig_scan = sig_scan
local get_object_memory = get_object_memory

local players = {}
local game_over = false
local init_first_blood = true
local team_play = false
local fall_damage_tag = nil
local distance_damage_tag = nil
local vehicle_collision_tag = nil
local red_flag_ptr = nil
local blue_flag_ptr = nil
local globals_ptr = nil

local function get_tag_id(type_str, path)
    local tag = lookup_tag(type_str, path)
    if tag == 0 then return nil end
    return read_dword(tag + 0xC)
end

local function add_points(ply, amount, msg)
    if amount == 0 then return end
    local cur = tonumber(get_var(ply, "$score")) or 0
    local new = cur + amount
    execute_command(string_format("score %d %d", ply, new))
    if config.custom_messages and msg and msg ~= "" then
        local sign = (amount > 0 and "+") or ""
        rprint(ply, string_format("(%s%d) %s", sign, amount, msg))
    end
end

local function get_points_for_meta(meta_id)
    for _, t in ipairs(config.tags) do
        if type(t) == "table" and t[1] and t[2] then
            local id = get_tag_id(t[1], t[2])
            if id and id == meta_id then
                return t[3], t[4]
            end
        end
    end
    return 0, ""
end

local function is_fall_damage(meta_id)
    if fall_damage_tag and meta_id == fall_damage_tag then
        return config.tags[1][3], config.tags[1][4]
    elseif distance_damage_tag and meta_id == distance_damage_tag then
        return config.tags[2][3], config.tags[2][4]
    end
    return nil, nil
end

local function apply_multi_kill(ply)
    local player_ptr = get_player(ply)
    if player_ptr == 0 then return end
    local kills = read_word(player_ptr + 0x98) -- consecutive kills
    local tiers = config.multi_kill
    local last = tiers[#tiers]
    for _, v in ipairs(tiers) do
        if kills == v[1] then
            add_points(ply, v[2], v[3])
            break
        elseif kills >= last[1] and kills % last[3] == 0 then
            add_points(ply, last[2], last[4])
            break
        end
    end
end

local function apply_spree(ply)
    local player_ptr = get_player(ply)
    if player_ptr == 0 then return end
    local kills = read_word(player_ptr + 0x96) -- total kills (not consecutive)
    local tiers = config.spree
    local last = tiers[#tiers]
    for _, v in ipairs(tiers) do
        if kills == v[1] then
            add_points(ply, v[2], v[3])
            break
        elseif kills >= last[1] and kills % last[3] == 0 then
            add_points(ply, last[2], last[4])
            break
        end
    end
end

local function maybe_first_blood(ply)
    if not init_first_blood then return end
    local kills = tonumber(get_var(ply, "$kills")) or 0
    if kills == 1 then
        init_first_blood = false
        add_points(ply, config.first_blood[1], config.first_blood[2])
    end
end

local function get_tag_name(object_ptr)
    if not object_ptr or object_ptr == 0 then return nil end
    local tag_datum = read_word(object_ptr) -- tag datum index
    local tag_addr = tag_datum * 32 + 0x40440038
    local name_ptr = read_dword(tag_addr)
    if name_ptr == 0 then return nil end
    return read_string(name_ptr)
end

local function has_flag(ply)
    local dyn = get_dynamic_player(ply)
    if dyn == 0 then return false, nil end
    -- check weapon objects
    local weapon = read_dword(dyn + 0x118)
    if weapon ~= 0 then
        if weapon == red_flag_ptr then return true, config.red_flag_kill end
        if weapon == blue_flag_ptr then return true, config.blue_flag_kill end
    end
    -- also check equipment slots (0x2F8 + 4*j)
    for j = 0, 3 do
        local obj = read_dword(dyn + 0x2F8 + 4 * j)
        if obj == red_flag_ptr then return true, config.red_flag_kill end
        if obj == blue_flag_ptr then return true, config.blue_flag_kill end
    end
    return false, nil
end

local function handle_vehicle_squash(killer)
    local dyn = get_dynamic_player(killer)
    if dyn == 0 then return end
    local vehicle_id = read_dword(dyn + 0x11C)
    if vehicle_id == 0 then return end
    local obj = get_object_memory(vehicle_id)
    if obj == 0 then return end
    local tag_name = get_tag_name(obj)
    if not tag_name then return end
    for _, v in ipairs(config.tags.vehicles) do
        if tag_name == v[2] then
            add_points(killer, v[3], v[4])
            break
        end
    end
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    players = {}
    game_over = false
    init_first_blood = true
    team_play = (get_var(0, "$ffa") == "0")

    fall_damage_tag = get_tag_id(config.tags[1][1], config.tags[1][2])
    distance_damage_tag = get_tag_id(config.tags[2][1], config.tags[2][2])
    local coll = config.tags.collision
    vehicle_collision_tag = get_tag_id(coll[1], coll[2])

    if globals_ptr then
        red_flag_ptr = read_dword(globals_ptr + 0x8)
        blue_flag_ptr = read_dword(globals_ptr + 0xC)
    end

    for i = 1, 16 do
        if player_present(i) then
            players[i] = {
                assists = 0,
                meta_id = 0,
                head_shot = false,
                assassination = false,
                team_change = false,
                team = get_var(i, "$team")
            }
        end
    end
end

function OnEnd()
    game_over = true
end

function OnJoin(ply)
    players[ply] = {
        assists = 0,
        meta_id = 0,
        head_shot = false,
        assassination = false,
        team_change = false,
        team = get_var(ply, "$team")
    }
end

function OnQuit(ply)
    players[ply] = nil
end

function OnSpawn(ply)
    if players[ply] then
        players[ply].meta_id = 0
    end
end

function OnSwitch(ply)
    if players[ply] then
        players[ply].team_change = true
        players[ply].team = get_var(ply, "$team")
    end
end

function OnScore(ply)
    add_points(ply, config.score[1], config.score[2])
end

function OnDamage(victim, killer, meta_id, _, hit_string, back_tap)
    if not player_present(victim) then return end
    -- Store info for the killer (will be used on death)
    if killer > 0 and players[killer] then
        players[killer].meta_id = meta_id
        players[killer].head_shot = (hit_string == "head")
        players[killer].assassination = (back_tap ~= 0)
    end
    -- Store meta_id for victim (used to determine death type)
    if players[victim] then
        players[victim].meta_id = meta_id
    end
end

function OnDeath(victim, killer, _)
    if game_over then return end

    local vdata = players[victim]
    if not vdata then return end

    local kdata = (killer > 0) and players[killer]
    local is_server = (killer == -1)
    local is_guardians = (killer == nil) -- killed by guardians
    local is_suicide = (killer == victim)
    local is_squashed = (killer == 0) -- squashed by vehicle
    local is_betrayal = (team_play and not is_suicide and kdata and kdata.team == vdata.team)

    -- Determine if it was a team‑change death (server kill shortly after team switch)
    local is_team_change_penalty = (is_server and vdata.team_change)

    -- Fall damage detection
    local fall_points, fall_msg = is_fall_damage(vdata.meta_id)

    -- Reset team_change flag
    vdata.team_change = false

    -- PvP kill (non‑betrayal)
    if killer > 0 and not is_betrayal and killer ~= victim then
        maybe_first_blood(killer)
        apply_multi_kill(killer)
        apply_spree(killer)

        -- Flag carrier kill
        local has_flag_flag, flag_points = has_flag(victim)
        if has_flag_flag then
            add_points(killer, flag_points[1], flag_points[2])
        end

        -- Killed from the grave
        if not player_alive(killer) then
            add_points(killer, config.killed_from_the_grave[1], config.killed_from_the_grave[2])
        end

        -- Assist points (check if assists increased)
        if kdata then
            local new_assists = tonumber(get_var(killer, "$assists")) or 0
            if new_assists > (kdata.assists or 0) then
                kdata.assists = new_assists
                add_points(killer, config.assist[1], config.assist[2])
            end
        end

        -- Zombie infect (if enabled)
        local z = config.zombies
        if z.enabled and kdata and vdata and kdata.team == z.zombie_team and vdata.team == z.human_team then
            add_points(killer, z.points[1], z.points[2])
            return -- no further points for this kill
        end

        -- Headshot
        if kdata and kdata.assassination then
            add_points(killer, config.assassination[1], config.assassination[2])
        elseif kdata and kdata.head_shot then
            add_points(killer, config.head_shot[1], config.head_shot[2])
        end

        -- Vehicle squash (special damage source)
        if kdata and kdata.meta_id == vehicle_collision_tag then
            handle_vehicle_squash(killer)
            return
        end

        -- Default weapon/vehicle projectile points
        local pts, msg = get_points_for_meta(vdata.meta_id)
        add_points(killer, pts, msg)

        -- Team change penalty
    elseif is_team_change_penalty then
        add_points(victim, config.team_change[1], config.team_change[2])

        -- Server kill
    elseif is_server and not fall_points then
        add_points(victim, config.server[1], config.server[2])

        -- Guardians
    elseif is_guardians then
        add_points(victim, config.guardians[1], config.guardians[2])
        if killer and killer > 0 then
            add_points(killer, config.guardians[1], config.guardians[2])
        end

        -- Suicide
    elseif is_suicide then
        add_points(victim, config.suicide[1], config.suicide[2])

        -- Betrayal (team kill)
    elseif is_betrayal and kdata then
        add_points(killer, config.betrayal[1], config.betrayal[2])

        -- Squashed by vehicle (killer == 0)
    elseif is_squashed then
        add_points(victim, config.squashed[1], config.squashed[2])

        -- Fall damage
    elseif fall_points then
        add_points(victim, fall_points, fall_msg)

        -- Any other death (e.g. unknown damage)
    else
        local pts, msg = get_points_for_meta(vdata.meta_id)
        if pts ~= 0 then
            add_points(victim, pts, msg)
        end
    end

    -- Reset temporary flags for killer (if any)
    if kdata then
        kdata.head_shot = false
        kdata.assassination = false
        kdata.meta_id = 0
    end
end

function OnScriptLoad()
    local gp = sig_scan("8B3C85????????3BF9741FE8????????8B8E2C0200008B4610") + 3
    if gp ~= 3 then globals_ptr = read_dword(gp) end

    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")
    register_callback(cb.EVENT_DIE, "OnDeath")
    register_callback(cb.EVENT_GAME_END, "OnEnd")
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_SCORE, "OnScore")
    register_callback(cb.EVENT_SPAWN, "OnSpawn")
    register_callback(cb.EVENT_TEAM_SWITCH, "OnSwitch")
end

function OnScriptUnload() end
