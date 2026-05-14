--[[
=====================================================================================
SCRIPT NAME:      zombies_advanced.lua
DESCRIPTION:      Zombie survival mode where humans fight against zombies.
                  Zombies convert humans by killing them.

KEY FEATURES:
                 - Team conversion mechanics (humans to zombies)
                 - Zombies use melee weapons only
                 - Configurable attributes for both teams
                 - Victory condition: when all humans are eliminated
                 - Player count-based game activation
                 - Countdown timer before the match starts
                 - Enhanced team shuffling with anti-duplicate protection
                 - Death message suppression during team changes
                 - Alpha Zombie and Standard Zombie types
                 - Last Man Standing bonus for the final human
                 - Dynamic alpha zombie count based on player population
                 - Works on MOST custom maps, including ones with obfuscated/protected tags.

CONFIGURATION:
    - REQUIRED_PLAYER:            Minimum players needed to start (default: 2)
    - COUNTDOWN_DELAY:            Countdown duration in seconds (default: 5)
    - CURE_THRESHOLD:             Kills needed for zombies to become human again (default: 6)
    - CONSECUTIVE:                Players need 'CURE_THRESHOLD' kills per life, otherwise 'CURE_THRESHOLD' kills total
    - SERVER_PREFIX:              Server message prefix (default: "**ZOMBIES**")
    - ZOMBIFY_ON_SUICIDE:         Convert humans to zombies on suicide (default: true)
    - ZOMBIFY_ON_FALL_DAMAGE:     Convert humans to zombies on fall damage (default: true)
    - LAST_MAN_NAV:               Enable navigation waypoints for Last Man Standing (default: true)
    - END_ON_NO_PLAYERS:          End the game when no players are present (default: true)
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
        - CAMO:                   Active camouflage
        - GRENADES:               Number of frag/plasma grenades
        - HEALTH_REGEN:           Health regeneration rate (Last Man Standing only)

LAST UPDATED: 6/10/2025

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration starts ---------------------------------------------------------------
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
        { 1,  4,  1 },
        { 5,  8,  2 },
        { 9,  12, 3 },
        { 13, 16, 4 }
    },
    ATTRIBUTES = {
        ['alpha_zombies'] = {
            SPEED = 1.25,
            HEALTH = 1.75,
            RESPAWN_TIME = 2.0,
            DAMAGE_MULTIPLIER = 3,
            CAMO = true
        },
        ['standard_zombies'] = {
            SPEED = 1.15,
            HEALTH = 1.25,
            RESPAWN_TIME = 1.5,
            DAMAGE_MULTIPLIER = 2,
            CAMO = false
        },
        ['humans'] = {
            SPEED = 1.0,
            HEALTH = 1.0,
            RESPAWN_TIME = 5,
            DAMAGE_MULTIPLIER = 1,
            CAMO = false,
            GRENADES = { frags = 2, plasmas = 2 }
        },
        ['last_man_standing'] = {
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

local pairs, ipairs, table_insert = pairs, ipairs, table.insert
local math_random, os_time, tonumber = math.random, os.time, tonumber
local string_format = string.format
local get_var, say_all = get_var, say_all
local execute_command, player_present = execute_command, player_present

local game = {
    players = {},
    player_count = 0,
    started = false,
    countdown_start = 0,
    last_man_id = nil,
    waiting_for_players = true,
    red_count = 0,
    blue_count = 0,
    oddball = nil
}

local falling, distance
local death_message_address = nil
local original_death_message_bytes = nil
local death_message_hook_enabled = false

local base_tag_table = 0x40440000

local TEAM_RED = 'red'
local TEAM_BLUE = 'blue'
local death_message_signature = "8B42348A8C28D500000084C9"

local sapp_events = {
    [cb.EVENT_TICK] = 'OnTick',
    [cb.EVENT_DIE] = 'OnDeath',
    [cb.EVENT_JOIN] = 'OnJoin',
    [cb.EVENT_LEAVE] = 'OnQuit',
    [cb.EVENT_SPAWN] = 'OnSpawn',
    [cb.EVENT_GAME_END] = 'OnEnd',
    [cb.EVENT_COMMAND] = 'OnCommand',
    [cb.EVENT_TEAM_SWITCH] = 'OnTeamSwitch',
    [cb.EVENT_WEAPON_DROP] = 'OnWeaponDrop',
    [cb.EVENT_DAMAGE_APPLICATION] = 'OnDamage'
}

local function registerCallbacks(team_game)
    for event, callback in pairs(sapp_events) do
        if team_game then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function scanMapObjects()
    local tag_array = read_dword(base_tag_table)
    local tag_count = read_dword(base_tag_table + 0xC)
    local objects = { vehicles = {}, weapons = {}, equipment = {} }

    for i = 0, tag_count - 1 do
        local tag = tag_array + 0x20 * i
        local class = read_dword(tag)
        local name = read_string(read_dword(tag + 0x10))

        if class == 0x76656869 then
            table_insert(objects.vehicles, { tag = name, team = 0 })
        elseif class == 0x77656170 then
            table_insert(objects.weapons, { tag = name, team = 2 })
        elseif class == 1701931376 then
            table_insert(objects.equipment, { tag = name, team = 2 })
        end
    end

    return objects
end

local function manageMapObjects(state)
    local command = state and "enable_object" or "disable_object"
    local objects = scanMapObjects()
    for _, category in pairs(objects) do
        for _, obj in ipairs(category) do
            execute_command(string_format('%s "%s" %d', command, obj.tag, obj.team))
        end
    end
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function SetupDeathMessageHook()
    local address = sig_scan(death_message_signature)
    if address == 0 then
        cprint("Zombies: Death message signature not found!", 4)
        return false
    end

    death_message_address = address + 3
    original_death_message_bytes = read_dword(death_message_address)

    if not original_death_message_bytes or original_death_message_bytes == 0 then
        cprint("Zombies: Failed to read original death message bytes!", 4)
        death_message_address = nil
        return false
    end

    return true
end

local function disableDeathMessages()
    if death_message_hook_enabled and death_message_address then
        safe_write(true)
        write_dword(death_message_address, 0x03EB01B1)
        safe_write(false)
    end
end

local function restoreDeathMessages()
    if death_message_hook_enabled and death_message_address and original_death_message_bytes then
        safe_write(true)
        write_dword(death_message_address, original_death_message_bytes)
        safe_write(false)
    end
end

local function findOddballTagID()
    local tag_array = read_dword(base_tag_table)
    local tag_count = read_dword(base_tag_table + 0xC)
    for i = 0, tag_count - 1 do
        local tag = tag_array + 0x20 * i
        if read_dword(tag) == 0x77656170 then
            local tag_data = read_dword(tag + 0x14)
            if read_bit(tag_data + 0x308, 3) == 1 and read_byte(tag_data + 2) == 4 then
                return read_dword(tag + 0xC)
            end
        end
    end
    return nil
end

local function getAlphaZombieCount()
    local player_count = game.player_count
    for _, range in ipairs(CONFIG.ZOMBIE_COUNT) do
        if player_count >= range[1] and player_count <= range[2] then
            return range[3]
        end
    end
    return 1
end

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
        switched = nil
    }
end

local function applyPlayerAttributes(player, player_type)
    local attributes = CONFIG.ATTRIBUTES[player_type]
    local dyn_player = get_dynamic_player(player.id)

    if player_alive(player.id) and dyn_player ~= 0 then
        write_float(dyn_player + 0xE0, attributes.HEALTH)
        if attributes.GRENADES then
            execute_command('nades ' .. player.id .. ' ' .. attributes.GRENADES.frags .. ' 1')
            execute_command('nades ' .. player.id .. ' ' .. attributes.GRENADES.plasmas .. ' 2')
        end
        execute_command("s " .. player.id .. " " .. attributes.SPEED)
    end

    player.is_last_man_standing = (player_type == 'last_man_standing')
end

local function destroyweapon(player)
    if player.weapon then
        destroy_object(player.weapon)
        player.weapon = nil
    end
end

local function send(id, msg)
    if not id then
        execute_command('msg_prefix ""')
        say_all(msg)
        execute_command('msg_prefix "' .. CONFIG.SERVER_PREFIX .. '"')
        return
    end
    rprint(id, msg)
end

local function resetKills(player)
    if CONFIG.CONSECUTIVE then player.kills = 0 end
end

local function switchPlayerTeam(player, new_team, zombie_type)
    player.switched = true
    execute_command('st ' .. player.id .. ' ' .. new_team)
    player.team = new_team

    if new_team == TEAM_BLUE then
        player.zombie_type = zombie_type or 'standard_zombies'
        applyPlayerAttributes(player, player.zombie_type)
        player.kills = 0
        if CONFIG.SHOW_ZOMBIE_TYPE_MESSAGES then
            if player.zombie_type == 'alpha_zombies' then
                send(player.id, "You are an Alpha Zombie! (Stronger/faster than normal zombies)")
            elseif player.zombie_type == 'standard_zombies' then
                send(player.id, "You are a Standard Zombie!")
            end
        end
    else
        player.zombie_type = nil
        if game.red_count == 1 and game.started then
            applyPlayerAttributes(player, 'last_man_standing')
        else
            applyPlayerAttributes(player, 'humans')
        end
        destroyweapon(player)
        execute_command('wdel ' .. player.id)
    end
end

local function updateTeamCounts()
    game.red_count, game.blue_count = 0, 0
    for _, player in pairs(game.players) do
        if player.team == TEAM_RED then
            game.red_count = game.red_count + 1
        elseif player.team == TEAM_BLUE then
            game.blue_count = game.blue_count + 1
        end
    end
end

local function checkLastManStanding()
    if game.red_count == 1 and game.started then
        for _, player in pairs(game.players) do
            if player.team == TEAM_RED then
                game.last_man_id = player.id
                applyPlayerAttributes(player, 'last_man_standing')
                send(nil, player.name .. " is the Last Man Standing!")
                timer(30, 'RegenHealth')
                break
            end
        end
    end
end

local function checkZombieCure(killer)
    if CONFIG.CURE_THRESHOLD <= 0 then return false end

    killer.kills = killer.kills + 1

    if killer.kills >= CONFIG.CURE_THRESHOLD then
        switchPlayerTeam(killer, TEAM_RED)
        killer.kills = 0 -- reset once cured
        updateTeamCounts()

        if game.red_count > 1 and game.last_man_id then
            local last_man = game.players[game.last_man_id]
            if last_man then
                applyPlayerAttributes(last_man, 'humans')
                last_man.is_last_man_standing = false
                send(nil, last_man.name .. " is no longer the Last Man Standing!")
                game.last_man_id = nil
            end
        end

        send(nil, killer.name .. " has been cured and is now human!")
        return true
    end

    return false
end

local function shuffleTeams()
    local players = {}
    for id, _ in pairs(game.players) do
        table_insert(players, id)
    end

    if #players < 2 then return end

    -- Shuffle players
    for i = #players, 2, -1 do
        local j = math_random(i)
        players[i], players[j] = players[j], players[i]
    end

    -- Determine number of alpha zombies
    local alpha_zombie_count = getAlphaZombieCount()

    -- Assign teams
    for i, id in ipairs(players) do
        if i <= alpha_zombie_count then
            switchPlayerTeam(game.players[id], TEAM_BLUE, "alpha_zombies")
        else
            switchPlayerTeam(game.players[id], TEAM_RED)
        end
    end

    updateTeamCounts()
end

local function checkVictory()
    if game.red_count == 0 then
        send(nil, "Zombies have overrun the humans!")
        execute_command('sv_map_next')
    elseif CONFIG.END_ON_NO_PLAYERS and game.blue_count == 0 then
        send(nil, "Zombies have retreated. Humans win!")
        execute_command('sv_map_next')
    end
end

local function checkEmptyTeams()
    if CONFIG.END_ON_NO_PLAYERS and game.started then
        if game.red_count == 0 then
            send(nil, "Zombies have overrun the humans!")
            execute_command('sv_map_next')
            return true
        elseif game.blue_count == 0 then
            send(nil, "Humans have eliminated all zombies!")
            execute_command('sv_map_next')
            return true
        end
    end
    return false
end

local function startGame()
    if game.player_count < CONFIG.REQUIRED_PLAYERS then
        game.waiting_for_players = true
        return
    end

    game.waiting_for_players = false
    game.countdown_start = os_time()
    send(nil, "Game starting in " .. CONFIG.COUNTDOWN_DELAY .. " seconds...")
    timer(CONFIG.COUNTDOWN_DELAY, 'OnCountdown')
end

local function getRespawnTime(player_type)
    if player_type == 'last_man_standing' then return 0 end
    return CONFIG.ATTRIBUTES[player_type].RESPAWN_TIME * 33
end

local function setRespawnTime(player)
    local player_type = player.zombie_type or (player.team == TEAM_RED and 'humans') or 'standard_zombies'
    local respawn_time = getRespawnTime(player_type)
    local static_player = get_player(player.id)

    if static_player ~= 0 then
        write_dword(static_player + 0x2C, respawn_time)
    end
end

local function isFallDamage(metaId)
    return (metaId == falling or metaId == distance) and CONFIG.ZOMBIFY_ON_FALL_DAMAGE
end

local function isSuicide(killerId, victimId)
    return (killerId == victimId) and CONFIG.ZOMBIFY_ON_SUICIDE
end

local function isFriendlyFire(killer, victim)
    return killer.id ~= victim.id and killer.team == victim.team
end

local function checkTeams(victim, killer)
    if killer and killer.id ~= victim.id then
        if victim.team == TEAM_RED and killer.team == TEAM_BLUE then
            return 1 -- zombie vs human (infection)
        elseif victim.team == TEAM_BLUE and killer.team == TEAM_RED then
            return 0 -- human vs zombie (kill)
        end
    end
    return nil
end

local function getValidWeapon(player_weapon)
    if not player_weapon then
        return spawn_object('', '', 0, 0, -9999, 0, game.oddball)
    end
    local object = get_object_memory(player_weapon)
    if object == 0 then
        return spawn_object('', '', 0, 0, -9999, 0, game.oddball)
    else
        return player_weapon
    end
end

local function getPlayerType(player)
    return player.zombie_type or
        (player.team == TEAM_RED and (player.is_last_man_standing and 'last_man_standing' or 'humans')) or
        'standard_zombies'
end

local function showAttributes(id)
    local player = game.players[id]
    if not player then return end

    local player_type = getPlayerType(player)
    local attributes = CONFIG.ATTRIBUTES[player_type]
    local current_health = "N/A"
    local dyn_player = get_dynamic_player(id)

    if dyn_player ~= 0 and player_alive(id) then
        current_health = string_format("%.0f%%", read_float(dyn_player + 0xE0) * 100)
    end

    send(id, "** Your Attributes **")
    send(id, "Type: " .. player_type:gsub("_", " "):gsub("(%l)(%w*)", function(a, b) return a:upper() .. b end))
    send(id, "Health: " .. current_health .. " (Base: " .. (attributes.HEALTH * 100) .. "%)")
    send(id, "Speed: " .. (attributes.SPEED * 100) .. "%")
    send(id, "Damage: " .. attributes.DAMAGE_MULTIPLIER .. "x")
    send(id, "Grenades - Frags: " .. attributes.GRENADES.frags .. ", Plasmas: " .. attributes.GRENADES.plasmas)
    send(id, "Camouflage: " .. (attributes.CAMO and "Yes" or "No"))

    if player_type == 'last_man_standing' then
        send(id, "Health Regen: " .. (attributes.HEALTH_REGEN * 100) .. "% per tick")
    end

    if player.team == TEAM_BLUE and CONFIG.CURE_THRESHOLD > 0 then
        send(id, "Cure Progress: " .. player.kills .. "/" .. CONFIG.CURE_THRESHOLD .. " kills")
    end
end

local function setNav(id)
    if not CONFIG.LAST_MAN_NAV then return end

    local player = get_player(id)
    if player == 0 then return end

    local last_man_id = game.last_man_id
    if id ~= last_man_id and last_man_id ~= nil and player_alive(last_man_id) then
        write_word(player + 0x88, to_real_index(last_man_id))
    else
        write_word(player + 0x88, to_real_index(id))
    end
end

-- SAPP Events
function OnScriptLoad()
    death_message_hook_enabled = SetupDeathMessageHook()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    execute_command('sv_tk_ban 0')
    execute_command('sv_friendly_fire 1')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    if get_var(0, '$ffa') == '1' then
        registerCallbacks(false)
        cprint('====================================================', 12)
        cprint('Zombies: Only runs on team-based games', 12)
        cprint('====================================================', 12)
        return
    end

    game.players = {}
    game.player_count = 0
    game.last_man_id = nil
    game.started = false
    game.oddball = findOddballTagID()

    execute_command('scorelimit 9999')
    falling = getTag('jpt!', 'globals\\falling')
    distance = getTag('jpt!', 'globals\\distance')

    for i = 1, 16 do
        if player_present(i) then
            game.players[i] = createPlayer(i)
            game.player_count = game.player_count + 1
        end
    end

    updateTeamCounts()
    startGame()
    registerCallbacks(true)
    manageMapObjects(false)
end

function OnEnd()
    game.started = false
    game.waiting_for_players = true
    restoreDeathMessages()
end

function OnJoin(id)
    game.players[id] = createPlayer(id)
    game.player_count = game.player_count + 1
    updateTeamCounts()

    if game.started then
        switchPlayerTeam(game.players[id], TEAM_BLUE, "standard_zombies")
        updateTeamCounts()
    elseif game.waiting_for_players and game.player_count >= CONFIG.REQUIRED_PLAYERS then
        startGame()
    end
end

function OnQuit(id)
    local player = game.players[id]
    if player then
        destroyweapon(player)
        game.players[id] = nil
        game.player_count = game.player_count - 1
        updateTeamCounts()
        checkLastManStanding()

        if checkEmptyTeams() then return end

        if game.player_count < CONFIG.REQUIRED_PLAYERS and not game.started then
            game.started = false
            game.waiting_for_players = true
            send(nil, "Not enough players. Game paused.")
        end
    end
end

function OnTeamSwitch(id)
    if not game.started then return true end

    local player = game.players[id]
    if player then
        player.team = get_var(id, '$team')
        player.switched = true
        updateTeamCounts()
        checkLastManStanding()

        if checkEmptyTeams() then return end

        checkVictory()
    end
end

function OnDeath(victimId, killerId)
    if not game.started then return end
    victimId = tonumber(victimId)
    killerId = tonumber(killerId)

    local killer = game.players[killerId]
    local victim = game.players[victimId]
    local pvp = checkTeams(victim, killer)

    local fall_damage = isFallDamage(victim.meta_id)
    local suicide = isSuicide(killerId, victimId)

    if victim.team == TEAM_BLUE then resetKills(victim) end

    if killerId == 0 or (killerId == -1 and not victim.switched) or killerId == nil then
        send(nil, victim.name .. " died!")
    elseif pvp == 1 then
        switchPlayerTeam(victim, TEAM_BLUE, 'standard_zombies')
        updateTeamCounts()
        if checkEmptyTeams() then return end
        send(nil, victim.name .. " was infected by " .. killer.name .. "!")
        if checkZombieCure(killer) then checkVictory() end
    elseif pvp == 0 then
        send(nil, victim.name .. " was killed by " .. killer.name .. "!")
    elseif (suicide or fall_damage) then
        if victim.team == TEAM_RED then -- only switch if human
            switchPlayerTeam(victim, TEAM_BLUE, 'standard_zombies')
            updateTeamCounts()
            if checkEmptyTeams() then return end
        end
        send(nil, victim.name .. " died!")
    end

    destroyweapon(victim)
    setRespawnTime(victim)
    victim.switched = nil
end

function OnTick()
    if not game.started then return end

    for i, player in pairs(game.players) do
        if player and player_alive(i) then
            local dyn_player = get_dynamic_player(i)
            if dyn_player == 0 then goto continue end

            local player_type = getPlayerType(player)
            local attributes = CONFIG.ATTRIBUTES[player_type]

            if attributes.CAMO and read_float(dyn_player + 0x50C) == 1 then
                execute_command('camo ' .. i .. ' 1')
            end

            setNav(i)

            ::continue::
        end
    end
end

function OnDamage(victimId, killerId, metaId, damage)
    if not game.started then return true, damage end
    local killer = tonumber(killerId)
    local victim = tonumber(victimId)

    local victim_data = game.players[victim]
    game.players[victim].meta_id = metaId

    local killer_data = game.players[killer]
    if not killer_data then return true end

    if isFriendlyFire(killer_data, victim_data) then return false end

    local killer_type = getPlayerType(killer_data)
    local damage_multiplier = CONFIG.ATTRIBUTES[killer_type].DAMAGE_MULTIPLIER

    return true, damage * damage_multiplier
end

function OnSpawn(id)
    if not game.started then return end

    local player = game.players[id]
    if not player then return end
    player.meta_id = nil

    local player_type = getPlayerType(player)
    applyPlayerAttributes(player, player_type)

    if player.team == TEAM_BLUE then
        player.weapon = getValidWeapon(player.weapon)

        execute_command('wdel ' .. id)
        assign_weapon(player.weapon, id)
    end
end

function OnWeaponDrop(id)
    if not game.started then return end

    local player = game.players[id]
    if not player then return end

    if player.team == TEAM_BLUE then
        player.weapon = getValidWeapon(player.weapon)
        assign_weapon(player.weapon, id)
    end
end

function OnCommand(id, command)
    if not game.started then return true end

    if CONFIG.ATTRIBUTES_COMMAND_ENABLED and command == CONFIG.ATTRIBUTES_COMMAND then
        showAttributes(id)
        return false
    end

    return true
end

function OnCountdown()
    if game.waiting_for_players or game.started then return false end

    local elapsed = os_time() - game.countdown_start
    local remaining = CONFIG.COUNTDOWN_DELAY - elapsed

    if remaining <= 0 then
        send(nil, "Zombies are coming! Survive or become one of them!")
        disableDeathMessages()
        execute_command('sv_map_reset')
        shuffleTeams()
        game.started = true
    end

    return true
end

function RegenHealth()
    if not game.started then return false end

    local last_man = game.players[game.last_man_id]
    if not last_man then return false end
    local id = last_man.id

    local dyn_player = get_dynamic_player(id)
    if dyn_player ~= 0 and player_alive(id) then
        local health = read_float(dyn_player + 0xE0)
        if health < 1 then
            local new_health = math.min(health + CONFIG.ATTRIBUTES['last_man_standing'].HEALTH_REGEN, 1)
            write_float(dyn_player + 0xE0, new_health)
        end
    end
    return true
end

function OnScriptUnload()
    if death_message_hook_enabled then restoreDeathMessages() end
    manageMapObjects(true)
end
