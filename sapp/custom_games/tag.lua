--[[
=====================================================================================
SCRIPT NAME:      tag.lua
DESCRIPTION:      Dynamic tag minigame featuring:
                  - Rotating "Tagger" role with speed advantage
                  - Score-based progression system
                  - Automatic role rotation mechanics

GAMEPLAY RULES:
                  - One player is Tagger (faster movement)
                  - Tagger scores points by tagging others
                  - Runners earn points over time
                  - Tag transfers on successful touch
                  - Role auto-rotates after timeout

CONFIGURATION:
                  - Adjustable score limits
                  - Customizable speed modifiers
                  - Toggle automatic role rotation
                  - Set point values and intervals

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG --
local CFG = {

    SCORE_LIMIT          = 10000,                   -- Total score required to end the game.
    TAG_POINTS           = 500,                     -- Points awarded to the tagger for tagging a runner.
    RUNNER_POINTS        = 5,                       -- Points awarded to each runner every interval.
    POINTS_INTERVAL      = 10,                      -- Seconds between runner point awards.
    TURN_TIME            = 60,                      -- Max seconds a player can stay tagger before auto-rotation.
    MIN_PLAYERS          = 2,                       -- Minimum players required to start a game.
    TAGGER_SPEED         = 1.5,                     -- Movement speed multiplier for the tagger.
    RUNNER_SPEED         = 1.0,                     -- Movement speed multiplier for runners.
    INITIAL_TAGGER_DELAY = 5,                       -- Delay (seconds) before selecting random tagger.
    NEW_TAGGER_ON_QUIT   = true,                    -- Select new tagger if current tagger leaves.
    NEW_TAGGER_ON_DEATH  = false,                   -- Select new tagger if current tagger dies.
    SERVER_PREFIX        = '**TAG**',               -- Prefix for server broadcast messages.
    RANDOM_TAGGER        = '%s is now the tagger!', -- Message when a random player becomes tagger.
    ON_TAG               = {                        -- Messages displayed when a player is tagged:
        "Tag, you're it! (%s got you)",
        '%s was tagged by %s'
    }
}
-- END OF CONFIG

api_version = '1.12.0.0'

-- Localize frequently used global functions
local execute_command = execute_command
local player_present = player_present
local get_var = get_var
local say = say
local say_all = say_all
local player_alive = player_alive
local rand = rand
local spawn_object = spawn_object
local assign_weapon = assign_weapon
local destroy_object = destroy_object
local lookup_tag = lookup_tag
local read_dword = read_dword
local tonumber = tonumber
local timer = timer
local pairs = pairs
local os_time = os.time

-- Game State
local game = {
    players = {},
    player_count = 0,
    tagger = nil,
    game_over = true,
    next_point_time = 0,
    tagger_weapon = nil,
    runner_weapon = nil,
    waiting_for_players = false,
}

-- Predefined object bans
local BANNED_OBJECTS = {
    'weapons\\frag grenade\\frag grenade',
    'weapons\\plasma grenade\\plasma grenade',
    'vehicles\\ghost\\ghost_mp',
    'vehicles\\rwarthog\\rwarthog',
    'vehicles\\banshee\\banshee_mp',
    'vehicles\\warthog\\mp_warthog',
    'vehicles\\scorpion\\scorpion_mp',
    'vehicles\\c gun turret\\c gun turret_mp',
    'weapons\\ball\\ball',
    'weapons\\flag\\flag',
    'weapons\\pistol\\pistol',
    'weapons\\shotgun\\shotgun',
    'weapons\\needler\\mp_needler',
    'weapons\\flamethrower\\flamethrower',
    'weapons\\plasma rifle\\plasma rifle',
    'weapons\\sniper rifle\\sniper rifle',
    'weapons\\plasma pistol\\plasma pistol',
    'weapons\\plasma_cannon\\plasma_cannon',
    'weapons\\assault rifle\\assault rifle',
    'weapons\\rocket launcher\\rocket launcher'
}

-- Player Management
local Player = {}
Player.__index = Player

function Player.new(id)
    return setmetatable({
        id = id,
        name = get_var(id, '$name'),
        is_tagger = false,
        drone = nil,
        next_point = 0,
        turn_end = 0,
    }, Player)
end

function Player:set_tagger(state)
    self.is_tagger = state
    execute_command('s ' .. self.id .. ' ' .. (state and CFG.TAGGER_SPEED or CFG.RUNNER_SPEED))

    if state then
        self.turn_end = os_time() + CFG.TURN_TIME
        self:assign_weapon(game.tagger_weapon)
    else
        self:assign_weapon(game.runner_weapon)
    end
end

function Player:assign_weapon(weapon)
    self:remove_weapons()
    self.drone = spawn_object('', '', 0, 0, -9999, 0, weapon)
    assign_weapon(self.drone, self.id)
end

function Player:remove_weapons()
    if self.drone then
        destroy_object(self.drone)
        self.drone = nil
    end
    execute_command('wdel ' .. self.id)
end

function Player:update_score(points)
    local new_score = tonumber(get_var(self.id, '$score')) + points
    execute_command('score ' .. self.id .. ' ' .. new_score)
end

function Player:reset()
    self:remove_weapons()
    execute_command('s ' .. self.id .. ' 1.0')
end

-- Game Logic
local function broadcast(msg, pid)
    execute_command('msg_prefix ""')
    if pid then say(pid, msg) else say_all(msg) end
    execute_command('msg_prefix "' .. CFG.SERVER_PREFIX .. '"')
end

local function disable_objects(disable)
    local cmd = disable and 'disable_object' or 'enable_object'
    for _, object in ipairs(BANNED_OBJECTS) do
        execute_command(cmd .. ' "' .. object .. '" 0')
    end
end

local function get_tag_id(class, name)
    local tag = lookup_tag(class, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

local function select_new_tagger(exclude)
    local candidate_count = 0
    local selected = nil
    for id, _ in pairs(game.players) do
        if player_present(id) and id ~= exclude then
            candidate_count = candidate_count + 1
            if rand(1, candidate_count + 1) == 1 then -- +1 because of SAPP bug
                selected = id
            end
        end
    end
    return selected
end

function SetInitialTagger()
    if game.player_count < CFG.MIN_PLAYERS then
        game.waiting_for_players = true
        disable_objects(false)
        timer(2000, "SetInitialTagger")
        return false
    end

    local new_tagger = select_new_tagger(nil)
    if new_tagger then
        disable_objects(true)
        execute_command('sv_map_reset')
        game.next_point_time = os_time() + CFG.POINTS_INTERVAL
        game.players[new_tagger]:set_tagger(true)
        game.tagger = new_tagger
        broadcast(CFG.RANDOM_TAGGER:format(game.players[new_tagger].name))
        game.game_over = false
        game.waiting_for_players = false
        return false
    else
        game.waiting_for_players = true
        timer(2000, "SetInitialTagger")
        return false
    end
end

local function handle_tagger_transfer(new_tagger_id, old_tagger_name)
    local new_player = game.players[new_tagger_id]

    -- Set new tagger
    if game.tagger then
        game.players[game.tagger]:set_tagger(false)
    end
    new_player:set_tagger(true)
    game.tagger = new_tagger_id

    -- Broadcast messages
    broadcast(CFG.ON_TAG[1]:format(old_tagger_name), new_tagger_id)
    for id, _ in pairs(game.players) do
        if id ~= new_tagger_id then
            broadcast(CFG.ON_TAG[2]:format(new_player.name, old_tagger_name), id)
        end
    end

    new_player:update_score(CFG.TAG_POINTS)
end

local function process_point_distribution(current_time)
    if current_time < game.next_point_time then return end
    game.next_point_time = current_time + CFG.POINTS_INTERVAL

    for _, player in pairs(game.players) do
        if not player.is_tagger then
            player:update_score(CFG.RUNNER_POINTS)
        end
    end
end

local function check_tagger_timeout(current_time)
    if not game.tagger then return end

    local tagger = game.players[game.tagger]
    if current_time >= tagger.turn_end then
        local new_tagger = select_new_tagger(game.tagger)
        if new_tagger then
            handle_tagger_transfer(new_tagger, tagger.name)
        end
    end
end

-- Event Handlers
function OnScriptLoad()
    register_callback(cb['EVENT_DIE'], 'OnDeath')
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_WEAPON_DROP'], 'OnWeaponDrop')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDamage')

    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    game.tagger_weapon = get_tag_id('weap', 'weapons\\ball\\ball')
    game.runner_weapon = get_tag_id('weap', 'weapons\\plasma rifle\\plasma rifle')
    execute_command('scorelimit ' .. CFG.SCORE_LIMIT)

    game.player_count = 0
    for i = 1, 16 do
        if player_present(i) then
            game.players[i] = Player.new(i)
            game.player_count = game.player_count + 1
        end
    end

    if game.player_count >= CFG.MIN_PLAYERS then
        broadcast("Starting a new game in " .. CFG.INITIAL_TAGGER_DELAY .. " seconds...")
        timer(CFG.INITIAL_TAGGER_DELAY * 1000, "SetInitialTagger")
        game.waiting_for_players = false
    else
        game.waiting_for_players = true
        disable_objects(false)
    end
end

function OnEnd()
    game.game_over = true
    for _, player in pairs(game.players) do
        player:reset()
    end
end

function OnTick()
    if game.game_over or game.waiting_for_players then return end

    local current_time = os_time()
    process_point_distribution(current_time)
    check_tagger_timeout(current_time)
end

function OnJoin(id)
    game.players[id] = Player.new(id)
    game.player_count = game.player_count + 1

    if game.waiting_for_players and game.player_count >= CFG.MIN_PLAYERS then
        game.waiting_for_players = false
        broadcast("Enough players joined! Starting a new game in " .. CFG.INITIAL_TAGGER_DELAY .. " seconds...")
        timer(CFG.INITIAL_TAGGER_DELAY * 1000, "SetInitialTagger")
    end
end

function OnSpawn(id)
    local player = game.players[id]
    player:reset()
    player:set_tagger(id == game.tagger)
end

function OnQuit(id)
    if not game.players[id] then return end

    if id == game.tagger and CFG.NEW_TAGGER_ON_QUIT then
        local new_tagger = select_new_tagger(id)
        if new_tagger then
            handle_tagger_transfer(new_tagger, game.players[id].name)
        else
            game.tagger = nil
        end
    end

    game.players[id]:reset()
    game.players[id] = nil
    game.player_count = game.player_count - 1

    if game.player_count < CFG.MIN_PLAYERS then
        game.waiting_for_players = true
        disable_objects(false)
        broadcast("Not enough players to continue the game. Waiting for more players...")
        if game.tagger and game.players[game.tagger] then
            game.players[game.tagger]:set_tagger(false)
        end
        game.tagger = nil
    end
end

function OnWeaponDrop(id)
    local player = game.players[id]
    if player and player_alive(id) then
        if player.is_tagger then
            player:assign_weapon(game.tagger_weapon)
        else
            player:assign_weapon(game.runner_weapon)
        end
    end
end

function OnDamage(victim, killer)
    victim = tonumber(victim)
    killer = tonumber(killer)

    if game.game_over or killer == 0 then return end
    if not game.players[victim] or not game.players[killer] then return end

    local victim_player = game.players[victim]
    local killer_player = game.players[killer]

    if killer_player.is_tagger and not victim_player.is_tagger then
        handle_tagger_transfer(victim, killer_player.name)
    end
end

function OnDeath(victim)
    victim = tonumber(victim)
    if not game.players[victim] then return end

    if victim == game.tagger and CFG.NEW_TAGGER_ON_DEATH then
        local new_tagger = select_new_tagger(victim)
        if new_tagger then
            handle_tagger_transfer(new_tagger, game.players[victim].name)
        end
    end
end

function OnScriptUnload() end