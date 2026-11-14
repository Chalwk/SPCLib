--[[
=====================================================================================
SCRIPT NAME:      zombies_advanced.lua
DESCRIPTION:      Zombie survival mode where humans fight against zombies.
                  Zombies convert humans by killing them.

KEY FEATURES:
                 - Team conversion mechanics (humans to zombies)
                 - Zombies use melee weapons only (and carry no grenades)
                 - Configurable attributes for both teams
                 - Victory condition: when all humans are eliminated
                 - Player count-based game activation
                 - Cancellable countdown timer before the match starts
                 - Team shuffling with at least one human guaranteed
                 - Death message suppression during rounds
                 - Alpha Zombie and Standard Zombie types
                 - Last Man Standing bonus for the final human
                 - Dynamic alpha zombie count based on player population
                 - Team-swap protection during a round
                 - Works on MOST custom maps, including ones with obfuscated/protected tags.

CONFIGURATION:
    - REQUIRED_PLAYERS:           Minimum players needed to start (default: 2)
    - COUNTDOWN_DELAY:            Countdown duration in seconds (default: 5)
    - CURE_THRESHOLD:             Infections needed for a zombie to become human again
                                  (default: 6, 0 disables curing)
    - CONSECUTIVE:                true = the infections must happen in a single life
                                  false = infections accumulate across lives
    - SERVER_PREFIX:              Server message prefix (default: "**ZOMBIES**")
    - ZOMBIFY_ON_SUICIDE:         Convert humans to zombies on suicide (default: true)
    - ZOMBIFY_ON_FALL_DAMAGE:     Convert humans to zombies on fall damage (default: true)
    - LAST_MAN_NAV:               Enable navigation waypoints for Last Man Standing (default: true)
    - END_ON_NO_PLAYERS:          End the round when no zombies remain (default: true)
    - SHOW_ZOMBIE_TYPE_MESSAGES:  Show messages when a player converts to a zombie (default: false)
    - ATTRIBUTES_COMMAND_ENABLED: Enable "/attributes" command (default: true)
    - ATTRIBUTES_COMMAND:         Command to show player attributes (default: "attributes")
    - ZOMBIE_COUNT:               Dynamic alpha zombie count based on player population
                                  Format: {min players, max players, zombie count}
                                  Example: {1, 4, 1} = 1 alpha zombie for 1-4 players

    - Team Attributes:
        * alpha_zombies:          Enhanced zombies with better stats
        * standard_zombies:       Regular zombies
        * humans:                 Default human players
        * last_man_standing:      Enhanced human attributes for last remaining player

      Each team type has configurable:
        - SPEED:                  Movement multiplier
        - HEALTH:                 Health multiplier
        - RESPAWN_TIME:           Respawn delay (seconds)
        - DAMAGE_MULTIPLIER:      Damage amplification
        - CAMO:                   Active camouflage (while crouched)
        - GRENADES:               Number of frag/plasma grenades (0-7)
        - HEALTH_REGEN:           Health regeneration per tick (Last Man Standing only)

LAST UPDATED: 14 Nov 2026

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

---@class TeamAttributes
---@field SPEED             number
---@field HEALTH            number
---@field RESPAWN_TIME?     number
---@field DAMAGE_MULTIPLIER number
---@field CAMO              boolean
---@field GRENADES?         { frags: number, plasmas: number }
---@field HEALTH_REGEN?     number

---@alias ZombieCountRange { [1]: number, [2]: number, [3]: number }
---@alias PlayerType 'alpha_zombies' | 'standard_zombies' | 'humans' | 'last_man_standing'

---@class ZombieConfig
---@field REQUIRED_PLAYERS           number
---@field COUNTDOWN_DELAY            number
---@field CURE_THRESHOLD             number
---@field CONSECUTIVE                boolean
---@field SERVER_PREFIX              string
---@field ZOMBIFY_ON_SUICIDE         boolean
---@field ZOMBIFY_ON_FALL_DAMAGE     boolean
---@field LAST_MAN_NAV               boolean
---@field END_ON_NO_PLAYERS          boolean
---@field SHOW_ZOMBIE_TYPE_MESSAGES  boolean
---@field ATTRIBUTES_COMMAND_ENABLED boolean
---@field ATTRIBUTES_COMMAND         string
---@field ZOMBIE_COUNT               ZombieCountRange[]
---@field ATTRIBUTES                 table<PlayerType, TeamAttributes>

-- Configuration starts ---------------------------------------------------------------

---@type ZombieConfig
local CONFIG = {
    REQUIRED_PLAYERS = 2,
    COUNTDOWN_DELAY = 5,
    CURE_THRESHOLD = 6,
    CONSECUTIVE = false,
    SERVER_PREFIX = "**ZOMBIES**",
    ZOMBIFY_ON_SUICIDE = true,
    ZOMBIFY_ON_FALL_DAMAGE = true,
    LAST_MAN_NAV = true,
    END_ON_NO_PLAYERS = true,
    SHOW_ZOMBIE_TYPE_MESSAGES = false,
    ATTRIBUTES_COMMAND_ENABLED = true,
    ATTRIBUTES_COMMAND = "attributes",
    ZOMBIE_COUNT = {
        { 1, 4, 1 },
        { 5, 8, 2 },
        { 9, 12, 3 },
        { 13, 16, 4 }
    },
    ATTRIBUTES = {
        alpha_zombies = {
            SPEED = 1.25,
            HEALTH = 1.75,
            RESPAWN_TIME = 2.0,
            DAMAGE_MULTIPLIER = 3,
            CAMO = true,
            GRENADES = { frags = 0, plasmas = 0 }
        },
        standard_zombies = {
            SPEED = 1.15,
            HEALTH = 1.25,
            RESPAWN_TIME = 1.5,
            DAMAGE_MULTIPLIER = 2,
            CAMO = false,
            GRENADES = { frags = 0, plasmas = 0 }
        },
        humans = {
            SPEED = 1.0,
            HEALTH = 1.0,
            RESPAWN_TIME = 5,
            DAMAGE_MULTIPLIER = 1,
            CAMO = false,
            GRENADES = { frags = 2, plasmas = 2 }
        },
        last_man_standing = {
            SPEED = 1.15,
            HEALTH = 1.25,
            DAMAGE_MULTIPLIER = 1.5,
            CAMO = false,
            GRENADES = { frags = 3, plasmas = 3 },
            HEALTH_REGEN = 0.001
        }
    }
}
-- Configuration ends ---------------------------------------------------------------

api_version = '1.12.0.0'

local pairs, ipairs, tonumber, tostring, select = pairs, ipairs, tonumber, tostring, select
local table_insert = table.insert
local math_random, math_min, math_floor = math.random, math.min, math.floor
local string_format = string.format

---@type fun(player_id: number): number
local get_dynamic_player = get_dynamic_player

local TEAM_RED, TEAM_BLUE = 'red', 'blue'

---@alias GameStateCode integer

---@type table<string, GameStateCode>
local STATE = { IDLE = 0, WAITING = 1, COUNTDOWN = 2, RUNNING = 3, OVER = 4 }

---@type { ALPHA: PlayerType, ZOMBIE: PlayerType, HUMAN: PlayerType, LAST_MAN: PlayerType }
local TYPE = { ALPHA = 'alpha_zombies', ZOMBIE = 'standard_zombies', HUMAN = 'humans', LAST_MAN = 'last_man_standing' }

local TYPE_LABEL = {
    [TYPE.ALPHA] = 'Alpha Zombie',
    [TYPE.ZOMBIE] = 'Standard Zombie',
    [TYPE.HUMAN] = 'Human',
    [TYPE.LAST_MAN] = 'Last Man Standing'
}

local TAG_TABLE = 0x40440000 -- same for PC and CE
local TICKS_PER_SECOND = 30

local DYN_HEALTH = 0xE0
local DYN_FRAGS = 0x31E
local DYN_PLASMAS = 0x31F
local DYN_CROUCH = 0x50C -- 0.0 standing, 1.0 fully crouched

local STATIC_RESPAWN_TIMER = 0x2C -- ticks
local STATIC_SPEED = 0x6C
local STATIC_NAV_TARGET = 0x88 -- waypoint target (real player index)

local CAMO_TICKS = 1
local DEATH_IGNORE_TICKS = 15 -- window in which a script-driven `st` death is ignored
local REVERT_TEAM_DELAY_MS = 100

local DEATH_MESSAGE_SIG = "8B42348A8C28D500000084C9"
local DEATH_MESSAGE_PATCH = 0x03EB01B1

local FALLING_TAG, DISTANCE_TAG = 'globals\\falling', 'globals\\distance'

-- Tag class dwords -> team passed to disable_object (0 = red only, 2 = everyone)
---@type table<number, number | nil>
local OBJECT_CLASS_TEAM = {
    [0x76656869] = 0, -- vehi
    [0x77656170] = 2, -- weap
    [0x65716970] = 2  -- eqip
}

---@class ZombiePlayer
---@field id                   number           SAPP player index
---@field name                 string
---@field team                 string           'red' or 'blue'. The team the SCRIPT expects the player to be on.
---@field zombie_type          PlayerType | nil TYPE.ALPHA or TYPE.ZOMBIE while blue
---@field weapon               number | nil     Object ID of the zombie's melee weapon
---@field is_last_man_standing boolean
---@field kills                number           Infections counted toward the cure
---@field meta_id              number | nil     Tag ID of the last damage this player took
---@field ignore_death_until   number           game.tick before which a -1 death is script-driven

---@class ZombieGameState
---@field state               GameStateCode
---@field players             table<number, ZombiePlayer?>
---@field player_count        number
---@field red_count           number
---@field blue_count          number
---@field last_man_id         number | nil
---@field last_man_enabled    boolean
---@field oddball             number | nil
---@field falling             number | nil
---@field distance            number | nil
---@field tick                number
---@field countdown_gen       number
---@field countdown_remaining number
---@field shuffling           boolean
---@field disabled_objects    { tag: string, team: number } [] | nil

---@type ZombieGameState
local game = {
    state = STATE.IDLE,
    players = {},
    player_count = 0,
    red_count = 0,
    blue_count = 0,
    last_man_id = nil,
    last_man_enabled = false,
    oddball = nil,
    falling = nil,
    distance = nil,
    tick = 0,
    countdown_gen = 0,
    countdown_remaining = 0,
    shuffling = false,
    disabled_objects = nil
}

---@class DeathHook
---@field address  number | nil
---@field original number | nil
---@field patched  boolean

---@type DeathHook
local death_hook = { address = nil, original = nil, patched = false }

---@param id      number Player index.
---@param message string Format string (printf-style) or literal message.
---@param ...     any    Values substituted into `message` when present.
local function tell(id, message, ...)
    if select('#', ...) > 0 then
        message = string_format(message, ...)
    end
    rprint(id, message)
end

---@param message string
local function broadcast(message)
    execute_command('msg_prefix ""')
    say_all(message)
    execute_command('msg_prefix "' .. CONFIG.SERVER_PREFIX .. '"')
end

---@return { tag: string, team: number } [] objects List of { tag = string, team = number }.
local function scanMapObjects()
    local objects = {}
    local tag_array = read_dword(TAG_TABLE)
    local tag_count = read_dword(TAG_TABLE + 0xC)

    for i = 0, tag_count - 1 do
        local tag = tag_array + 0x20 * i
        local team = OBJECT_CLASS_TEAM[read_dword(tag)]
        if team then
            local name_ptr = read_dword(tag + 0x10)
            if name_ptr ~= 0 then
                local name = read_string(name_ptr)
                if name and name ~= "" then
                    table_insert(objects, { tag = name, team = team })
                end
            end
        end
    end

    return objects
end

---@param enabled boolean true re-enables the objects this script disabled.
local function setMapObjectsEnabled(enabled)
    local objects = enabled and game.disabled_objects or scanMapObjects()
    if not objects then return end

    local command = enabled and 'enable_object' or 'disable_object'
    for _, object in ipairs(objects) do
        execute_command(string_format('%s "%s" %d', command, object.tag, object.team))
    end

    game.disabled_objects = (not enabled) and objects or nil
end

---@param class string Four-letter tag class.
---@param name  string Tag path.
---@return number | nil tag_id
local function getTagId(class, name)
    local tag = lookup_tag(class, name)
    if tag == 0 then return nil end

    local meta_id = read_dword(tag + 0xC)
    return meta_id ~= 0 and meta_id or nil
end

--- Finds the oddball weapon tag. Zombies are handed one so they can only melee.
---@return number | nil meta_id
local function findOddballTagId()
    local tag_array = read_dword(TAG_TABLE)
    local tag_count = read_dword(TAG_TABLE + 0xC)

    for i = 0, tag_count - 1 do
        local tag = tag_array + 0x20 * i
        if read_dword(tag) == 0x77656170 then -- weap
            local tag_data = read_dword(tag + 0x14)
            if tag_data ~= 0 and read_bit(tag_data + 0x308, 3) == 1 and read_byte(tag_data + 2) == 4 then
                return read_dword(tag + 0xC)
            end
        end
    end

    return nil
end

---@return boolean ok
local function setupDeathMessageHook()
    local match = sig_scan(DEATH_MESSAGE_SIG)
    if match == 0 then
        cprint("Zombies: Death message signature not found (already patched?)", 12)
        return false
    end

    local address = match + 3
    local original = read_dword(address)
    if not original or original == 0 then
        cprint("Zombies: Failed to read original death message bytes!", 12)
        return false
    end

    death_hook.address, death_hook.original = address, original
    return true
end

local function disableDeathMessages()
    if death_hook.address and not death_hook.patched then
        safe_write(true)
        write_dword(death_hook.address, DEATH_MESSAGE_PATCH)
        safe_write(false)
        death_hook.patched = true
    end
end

local function restoreDeathMessages()
    if death_hook.address and death_hook.original and death_hook.patched then
        safe_write(true)
        write_dword(death_hook.address, death_hook.original)
        safe_write(false)
        death_hook.patched = false
    end
end

---@param id number
---@return ZombiePlayer
local function createPlayer(id)
    return {
        id = id,
        name = get_var(id, '$name'),
        team = get_var(id, '$team'),
        zombie_type = nil,
        weapon = nil,
        is_last_man_standing = false,
        kills = 0,
        meta_id = nil,
        ignore_death_until = 0
    }
end

---@param player ZombiePlayer
---@return PlayerType player_type One of the TYPE values.
local function getPlayerType(player)
    if player.team == TEAM_BLUE then
        return player.zombie_type or TYPE.ZOMBIE
    end
    return player.is_last_man_standing and TYPE.LAST_MAN or TYPE.HUMAN
end

local function updateTeamCounts()
    local red, blue, total = 0, 0, 0
    for _, player in pairs(game.players) do
        total = total + 1
        if player.team == TEAM_RED then
            red = red + 1
        elseif player.team == TEAM_BLUE then
            blue = blue + 1
        end
    end
    game.red_count, game.blue_count, game.player_count = red, blue, total
end

---@return number count Alpha zombies for the current player population.
local function getAlphaZombieCount()
    for _, range in ipairs(CONFIG.ZOMBIE_COUNT) do
        if game.player_count >= range[1] and game.player_count <= range[2] then
            return range[3]
        end
    end
    return 1
end

---@param player ZombiePlayer
local function setRespawnTime(player)
    if not player_present(player.id) then return end

    local player_type = getPlayerType(player)
    local seconds = CONFIG.ATTRIBUTES[player_type].RESPAWN_TIME or 0
    local static_player = get_player(player.id)

    if static_player and static_player ~= 0 then
        write_dword(static_player + STATIC_RESPAWN_TIMER, math_floor(seconds * TICKS_PER_SECOND + 0.5))
    end
end

---@param player      ZombiePlayer
---@param player_type PlayerType   One of the TYPE values.
local function applyAttributes(player, player_type)
    local attributes = CONFIG.ATTRIBUTES[player_type]
    player.is_last_man_standing = (player_type == TYPE.LAST_MAN)

    if not player_present(player.id) then return end

    local static_player = get_player(player.id)
    if static_player and static_player ~= 0 then
        write_float(static_player + STATIC_SPEED, attributes.SPEED)
    end

    local dyn_player = get_dynamic_player(player.id)
    if dyn_player == 0 then return end -- dead: OnSpawn re-applies

    write_float(dyn_player + DYN_HEALTH, attributes.HEALTH)

    if attributes.GRENADES then
        write_byte(dyn_player + DYN_FRAGS, math_min(attributes.GRENADES.frags, 7))
        write_byte(dyn_player + DYN_PLASMAS, math_min(attributes.GRENADES.plasmas, 7))
    end
end

---@param player ZombiePlayer
local function destroyWeapon(player)
    local weapon = player.weapon
    player.weapon = nil
    if weapon and get_object_memory(weapon) ~= 0 then
        destroy_object(weapon)
    end
end

--- Returns the player's existing melee weapon, or spawns a new one far below the map.
---@param player ZombiePlayer
---@return number | nil object_id
local function getZombieWeapon(player)
    if player.weapon and get_object_memory(player.weapon) ~= 0 then
        return player.weapon
    end

    if not game.oddball then return nil end

    local weapon = spawn_object('', '', 0, 0, -9999, 0, game.oddball)
    player.weapon = weapon ~= 0 and weapon or nil
    return player.weapon
end

---@param player ZombiePlayer
local function giveZombieWeapon(player)
    execute_command('wdel ' .. player.id .. ' 5')
    local weapon = getZombieWeapon(player)
    if weapon then assign_weapon(weapon, player.id) end
end

--- Moves a player to a team and applies the matching attributes.
---@param player      ZombiePlayer
---@param new_team    string
---@param zombie_type PlayerType | nil Defaults to standard zombie when joining blue.
local function switchTeam(player, new_team, zombie_type)
    player.team = new_team
    player.ignore_death_until = game.tick + DEATH_IGNORE_TICKS
    execute_command(string_format('st %d %s', player.id, new_team))

    if new_team == TEAM_BLUE then
        player.zombie_type = zombie_type or TYPE.ZOMBIE
        player.kills = 0
        applyAttributes(player, player.zombie_type)

        -- `st` normally kills the player. If they survived the swap, equip them now.
        if player_alive(player.id) then giveZombieWeapon(player) end

        if CONFIG.SHOW_ZOMBIE_TYPE_MESSAGES then
            if player.zombie_type == TYPE.ALPHA then
                tell(player.id, "You are an Alpha Zombie! (Stronger/faster than normal zombies)")
            else
                tell(player.id, "You are a Standard Zombie!")
            end
        end
    else
        player.zombie_type = nil
        applyAttributes(player, TYPE.HUMAN)
        destroyWeapon(player)
        execute_command('wdel ' .. player.id .. ' 5')
    end

    setRespawnTime(player)
end

---@param message string
local function endRound(message)
    if game.state ~= STATE.RUNNING then return end
    game.state = STATE.OVER
    broadcast(message)
    execute_command('sv_map_next')
end

---@return boolean over True if the round just ended.
local function checkGameOver()
    if game.state ~= STATE.RUNNING then return false end

    if game.red_count == 0 then
        endRound("Zombies have overrun the humans!")
        return true
    elseif CONFIG.END_ON_NO_PLAYERS and game.blue_count == 0 then
        endRound("Humans have eliminated all zombies!")
        return true
    end

    return false
end

--- Promotes or demotes the Last Man Standing.
local function updateLastMan()
    if game.state ~= STATE.RUNNING then return end

    -- A round only grants Last Man Standing after there have been 2+ humans.
    if game.red_count > 1 then game.last_man_enabled = true end

    local current_id = game.last_man_id
    if current_id then
        local current = game.players[current_id]
        if not (current and current.team == TEAM_RED and game.red_count == 1) then
            game.last_man_id = nil
            if current then
                current.is_last_man_standing = false
                if current.team == TEAM_RED then -- someone was cured, no longer alone
                    applyAttributes(current, TYPE.HUMAN)
                    broadcast(current.name .. " is no longer the Last Man Standing!")
                end
            end
        end
    end

    if game.last_man_enabled and game.red_count == 1 and not game.last_man_id then
        for _, player in pairs(game.players) do
            if player.team == TEAM_RED then
                game.last_man_id = player.id
                applyAttributes(player, TYPE.LAST_MAN)
                broadcast(player.name .. " is the Last Man Standing!")
                break
            end
        end
    end
end

--- Call after ANY team composition change (infection, cure, quit, join).
---@return boolean over True if the round ended.
local function onTeamsChanged()
    updateTeamCounts()
    if checkGameOver() then return true end
    updateLastMan()
    return false
end

---@param killer ZombiePlayer Zombie that just infected someone.
local function awardInfection(killer)
    if CONFIG.CURE_THRESHOLD <= 0 then return end

    killer.kills = killer.kills + 1
    if killer.kills >= CONFIG.CURE_THRESHOLD then
        switchTeam(killer, TEAM_RED)
        killer.kills = 0
        broadcast(killer.name .. " has been cured and is now human!")
    end
end

local function shuffleTeams()
    local ids = {}
    for id in pairs(game.players) do
        table_insert(ids, id)
    end
    if #ids < 2 then return end

    for i = #ids, 2, -1 do
        local j = math_random(i)
        ids[i], ids[j] = ids[j], ids[i]
    end

    -- Always leave at least one human.
    local alphas = math_min(getAlphaZombieCount(), #ids - 1)

    for i, id in ipairs(ids) do
        local player = game.players[id]
        if player then
            if i <= alphas then
                switchTeam(player, TEAM_BLUE, TYPE.ALPHA)
            else
                switchTeam(player, TEAM_RED)
            end
        end
    end
end

local function beginRound()
    broadcast("Zombies are coming! Survive or become one of them!")
    disableDeathMessages()
    execute_command('sv_map_reset')

    game.shuffling = true
    shuffleTeams()
    game.shuffling = false

    updateTeamCounts()
    game.last_man_id = nil
    game.last_man_enabled = game.red_count > 1
    game.state = STATE.RUNNING
end

local function cancelCountdown()
    game.countdown_gen = game.countdown_gen + 1 -- invalidates any pending timer
    if game.state == STATE.COUNTDOWN then game.state = STATE.WAITING end
end

local function startCountdown()
    if game.state ~= STATE.WAITING then return end
    if game.player_count < CONFIG.REQUIRED_PLAYERS then return end

    game.state = STATE.COUNTDOWN
    game.countdown_gen = game.countdown_gen + 1
    game.countdown_remaining = CONFIG.COUNTDOWN_DELAY

    broadcast("Game starting in " .. CONFIG.COUNTDOWN_DELAY .. " seconds...")
    timer(1000, 'OnCountdown', game.countdown_gen)
end

---@param id number
local function showAttributes(id)
    local player = game.players[id]
    if not player then return end

    if game.state ~= STATE.RUNNING then
        tell(id, "Attributes are only available during a round.")
        return
    end

    local player_type = getPlayerType(player)
    local attributes = CONFIG.ATTRIBUTES[player_type]

    local health = "N/A"
    local dyn_player = get_dynamic_player(id)
    if dyn_player ~= 0 then
        health = string_format("%.0f%%", read_float(dyn_player + DYN_HEALTH) * 100)
    end

    tell(id, "** Your Attributes **")
    tell(id, "Type: " .. TYPE_LABEL[player_type])
    tell(id, "Health: %s (Base: %.0f%%)", health, attributes.HEALTH * 100)
    tell(id, "Speed: %.0f%%", attributes.SPEED * 100)
    tell(id, "Damage: " .. attributes.DAMAGE_MULTIPLIER .. "x")

    if attributes.GRENADES then
        tell(id, "Grenades - Frags: %d, Plasmas: %d", attributes.GRENADES.frags, attributes.GRENADES.plasmas)
    end

    tell(id, "Camouflage: " .. (attributes.CAMO and "Yes (crouch)" or "No"))

    if attributes.HEALTH_REGEN then
        tell(id, "Health Regen: %.2f%% per tick", attributes.HEALTH_REGEN * 100)
    end

    if player.team == TEAM_BLUE and CONFIG.CURE_THRESHOLD > 0 then
        tell(id, "Cure Progress: " .. player.kills .. "/" .. CONFIG.CURE_THRESHOLD .. " infections")
    end
end

--- Points every player's waypoint at the Last Man Standing (or at themselves to clear it).
---@param id number
local function updateNav(id)
    local static_player = get_player(id)
    if not static_player or static_player == 0 then return end

    local target = id
    local last_man_id = game.last_man_id
    if last_man_id and id ~= last_man_id and player_alive(last_man_id) then
        target = last_man_id
    end

    local real_index = to_real_index(target)
    if read_word(static_player + STATIC_NAV_TARGET) ~= real_index then
        write_word(static_player + STATIC_NAV_TARGET, real_index)
    end
end

---@param enable boolean
local function registerCallbacks(enable)
    if enable then
        register_callback(cb.EVENT_TICK, 'OnTick')
        register_callback(cb.EVENT_DIE, 'OnDie')
        register_callback(cb.EVENT_JOIN, 'OnJoin')
        register_callback(cb.EVENT_LEAVE, 'OnLeave')
        register_callback(cb.EVENT_SPAWN, 'OnSpawn')
        register_callback(cb.EVENT_GAME_END, 'OnEnd')
        register_callback(cb.EVENT_COMMAND, 'OnCommand')
        register_callback(cb.EVENT_TEAM_SWITCH, 'OnTeamSwitch')
        register_callback(cb.EVENT_WEAPON_DROP, 'OnWeaponDrop')
        register_callback(cb.EVENT_DAMAGE_APPLICATION, 'OnDamageApplication')
        return
    end

    unregister_callback(cb.EVENT_TICK)
    unregister_callback(cb.EVENT_DIE)
    unregister_callback(cb.EVENT_JOIN)
    unregister_callback(cb.EVENT_LEAVE)
    unregister_callback(cb.EVENT_SPAWN)
    unregister_callback(cb.EVENT_GAME_END)
    unregister_callback(cb.EVENT_COMMAND)
    unregister_callback(cb.EVENT_TEAM_SWITCH)
    unregister_callback(cb.EVENT_WEAPON_DROP)
    unregister_callback(cb.EVENT_DAMAGE_APPLICATION)
end

---@return boolean valid
local function validateConfig()
    for _, player_type in pairs(TYPE) do
        local attributes = CONFIG.ATTRIBUTES[player_type]
        if type(attributes) ~= 'table' or not attributes.SPEED
            or not attributes.HEALTH or not attributes.DAMAGE_MULTIPLIER then
            cprint("Zombies: ATTRIBUTES['" .. player_type .. "'] needs SPEED, HEALTH and DAMAGE_MULTIPLIER", 12)
            return false
        end
    end
    CONFIG.REQUIRED_PLAYERS = math.max(CONFIG.REQUIRED_PLAYERS, 2)
    CONFIG.COUNTDOWN_DELAY = math.max(CONFIG.COUNTDOWN_DELAY, 1)
    return true
end

function OnScriptLoad()
    if not validateConfig() then return end

    math.randomseed(os.time())
    death_hook.address = nil
    setupDeathMessageHook()

    register_callback(cb.EVENT_GAME_START, 'OnStart')
    execute_command('sv_tk_ban 0')
    execute_command('sv_friendly_fire 1') -- off: friendly damage is also blocked in OnDamageApplication
    execute_command('msg_prefix "' .. CONFIG.SERVER_PREFIX .. '"')

    OnStart() -- in case the script was loaded mid-game
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    cancelCountdown()
    game.state = STATE.IDLE

    if get_var(0, '$ffa') == '1' then
        registerCallbacks(false)
        cprint('====================================================', 12)
        cprint('Zombies: Only runs on team-based games', 12)
        cprint('====================================================', 12)
        return
    end

    game.players = {}
    game.last_man_id = nil
    game.last_man_enabled = false
    game.shuffling = false
    game.oddball = findOddballTagId()
    game.falling = getTagId('jpt!', FALLING_TAG)
    game.distance = getTagId('jpt!', DISTANCE_TAG)

    if not game.oddball then
        cprint("Zombies: No oddball weapon tag on this map. Zombies will keep their weapons!", 12)
    end

    execute_command('scorelimit 9999')

    for i = 1, 16 do
        if player_present(i) then game.players[i] = createPlayer(i) end
    end

    updateTeamCounts()
    registerCallbacks(true)
    setMapObjectsEnabled(false)

    game.state = STATE.WAITING
    startCountdown()
end

function OnEnd()
    if game.state == STATE.RUNNING and game.red_count > 0 then
        broadcast("Time is up! " .. game.red_count .. " human(s) survived.")
    end

    cancelCountdown()
    game.state = STATE.IDLE
    restoreDeathMessages()
end

---@param id number
function OnJoin(id)
    local player = createPlayer(id)
    game.players[id] = player

    if game.state == STATE.RUNNING then
        switchTeam(player, TEAM_BLUE, TYPE.ZOMBIE)
        onTeamsChanged()
    else
        updateTeamCounts()
        startCountdown() -- no-op unless waiting with enough players
    end
end

---@param id number
function OnLeave(id)
    local player = game.players[id]
    if not player then return end

    destroyWeapon(player)
    game.players[id] = nil
    updateTeamCounts()

    if game.state == STATE.RUNNING then
        onTeamsChanged()
    elseif game.state == STATE.COUNTDOWN and game.player_count < CONFIG.REQUIRED_PLAYERS then
        cancelCountdown()
        broadcast("Not enough players. Game paused.")
    end
end

--- Reverts team swaps the script did not make (RevertTeam checks the real team).
---@param id number
function OnTeamSwitch(id)
    if game.state ~= STATE.RUNNING or game.shuffling then return end

    local player = game.players[id]
    if player and get_var(id, '$team') ~= player.team then
        timer(REVERT_TEAM_DELAY_MS, 'RevertTeam', id)
    end
end

---@param id number
---@return boolean repeat_timer Always false.
function RevertTeam(id)
    ---@diagnostic disable-next-line: assign-type-mismatch
    id = tonumber(id)
    local player = game.players[id]
    ---@diagnostic disable-next-line: param-type-mismatch
    if game.state == STATE.RUNNING and player and player_present(id) and get_var(id, '$team') ~= player.team then
        player.ignore_death_until = game.tick + DEATH_IGNORE_TICKS
        execute_command(string_format('st %d %s', id, player.team))
        ---@diagnostic disable-next-line: param-type-mismatch
        tell(id, "You cannot change teams during a round.")
    end
    return false
end

---@param victim_id number
---@param killer_id string `-1` = environment, `0` = non-player, `1+` = player
function OnDie(victim_id, killer_id)
    if game.state ~= STATE.RUNNING then return end

    ---@diagnostic disable-next-line: assign-type-mismatch
    killer_id = tonumber(killer_id)
    if not killer_id then return end

    local victim = game.players[victim_id]
    if not victim then return end

    if killer_id == -1 and game.tick <= victim.ignore_death_until then return end

    if victim.team == TEAM_BLUE and CONFIG.CONSECUTIVE then victim.kills = 0 end

    local suicide = (killer_id == victim_id)
    local fall = killer_id == -1 and victim.meta_id ~= nil
        and (victim.meta_id == game.falling or victim.meta_id == game.distance)
    local killer = (killer_id > 0 and not suicide) and game.players[killer_id] or nil

    if killer and killer.team ~= victim.team then
        if victim.team == TEAM_RED then
            switchTeam(victim, TEAM_BLUE, TYPE.ZOMBIE)
            broadcast(victim.name .. " was infected by " .. killer.name .. "!")
            awardInfection(killer)
        else
            broadcast(victim.name .. " was killed by " .. killer.name .. "!")
        end
    elseif victim.team == TEAM_RED
        and ((suicide and CONFIG.ZOMBIFY_ON_SUICIDE) or (fall and CONFIG.ZOMBIFY_ON_FALL_DAMAGE)) then
        switchTeam(victim, TEAM_BLUE, TYPE.ZOMBIE)
        broadcast(victim.name .. " died and rose again as a zombie!")
    else
        broadcast(victim.name .. " died!")
    end

    destroyWeapon(victim)
    setRespawnTime(victim)
    victim.meta_id = nil

    onTeamsChanged()
end

function OnTick()
    game.tick = game.tick + 1
    if game.state ~= STATE.RUNNING then return end

    for id, player in pairs(game.players) do
        local dyn_player = get_dynamic_player(id)
        if dyn_player ~= 0 then -- alive
            local player_type = getPlayerType(player)
            local attributes = CONFIG.ATTRIBUTES[player_type]

            if attributes.CAMO and read_float(dyn_player + DYN_CROUCH) == 1 then
                camo(id, CAMO_TICKS)
            end

            if attributes.HEALTH_REGEN then
                local health = read_float(dyn_player + DYN_HEALTH)
                if health < attributes.HEALTH then
                    write_float(dyn_player + DYN_HEALTH, math_min(health + attributes.HEALTH_REGEN, attributes.HEALTH))
                end
            end

            if CONFIG.LAST_MAN_NAV then updateNav(id) end
        end
    end
end

---@param victim_id     number
---@param killer_id     number
---@param damage_tag_id number
---@param damage        number
---@return boolean | nil allow
---@return number | nil new_damage
function OnDamageApplication(victim_id, killer_id, damage_tag_id, damage)
    if game.state ~= STATE.RUNNING then return true end

    local victim = game.players[victim_id]
    local killer = game.players[killer_id]

    if victim then victim.meta_id = damage_tag_id end
    if not victim or not killer then return true end
    if killer.id == victim.id then return true end -- self damage is untouched
    if killer.team == victim.team then return false end -- no friendly fire

    return true, damage * CONFIG.ATTRIBUTES[getPlayerType(killer)].DAMAGE_MULTIPLIER
end

---@param id number
function OnSpawn(id)
    if game.state ~= STATE.RUNNING then return end

    local player = game.players[id]
    if not player then return end

    player.meta_id = nil
    applyAttributes(player, getPlayerType(player))

    if player.team == TEAM_BLUE then giveZombieWeapon(player) end
end

---@param id number
function OnWeaponDrop(id)
    if game.state ~= STATE.RUNNING then return end

    local player = game.players[id]
    if player and player.team == TEAM_BLUE then
        local weapon = getZombieWeapon(player)
        if weapon then assign_weapon(weapon, player.id) end
    end
end

---@param id      number
---@param command string
---@return boolean allow
function OnCommand(id, command)
    if not CONFIG.ATTRIBUTES_COMMAND_ENABLED then return true end

    local name = command and command:match("^%s*(%S+)")
    if name and name:lower() == CONFIG.ATTRIBUTES_COMMAND:lower() and game.players[id] then
        showAttributes(id)
        return false
    end

    return true
end

---@param generation number Countdown generation; stale timers are dropped.
---@return boolean repeat_timer
function OnCountdown(generation)
    ---@diagnostic disable-next-line: assign-type-mismatch
    generation = tonumber(generation)
    if generation ~= game.countdown_gen or game.state ~= STATE.COUNTDOWN then return false end

    game.countdown_remaining = game.countdown_remaining - 1
    if game.countdown_remaining > 0 then
        if game.countdown_remaining <= 3 then broadcast(tostring(game.countdown_remaining) .. "...") end
        return true
    end

    if game.player_count < CONFIG.REQUIRED_PLAYERS then
        cancelCountdown()
        return false
    end

    beginRound()
    return false
end

function OnScriptUnload()
    restoreDeathMessages()
    setMapObjectsEnabled(true)

    for id, player in pairs(game.players) do
        destroyWeapon(player)
        if player_present(id) then
            local static_player = get_player(id)
            if static_player and static_player ~= 0 then
                write_float(static_player + STATIC_SPEED, 1.0)
                write_word(static_player + STATIC_NAV_TARGET, to_real_index(id))
            end
        end
    end

    execute_command('sv_friendly_fire 0')
    execute_command('sv_tk_ban 4')
    execute_command('msg_prefix "**SAPP**"')
end
