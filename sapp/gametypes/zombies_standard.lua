--[[
=====================================================================================
SCRIPT NAME:      zombies_standard.lua
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
                 - Dynamic zombie count based on player population
                 - Works on MOST custom maps, including ones with obfuscated/protected tags.

CONFIGURATION:
    - REQUIRED_PLAYERS:                 Minimum players needed to start (default: 2)
    - COUNTDOWN_DELAY:                  Countdown duration in seconds (default: 5)
    - SERVER_PREFIX:                    Server message prefix (default: "**ZOMBIES**")
    - ZOMBIFY_ON_SUICIDE:               Convert humans to zombies on suicide (default: true)
    - ZOMBIFY_ON_FALL_DAMAGE:           Convert humans to zombies on fall damage (default: true)
    - END_ON_NO_PLAYERS:                End the game when no players are present (default: true)
    - ZOMBIE_COUNT:                     Dynamic zombie count based on player population
                                        Format: {min players, max players, zombie count}
                                        Example: {1, 4, 1} = 1 zombie for 1-4 players

    - Team Attributes:
        * humans:                       Default human players
        * zombies:                      Zombie players

      Each team type has configurable:
        - SPEED:                        Movement multiplier
        - RESPAWN_TIME:                 Respawn delay (seconds)
        - DAMAGE_MULTIPLIER:            Damage amplification
        - CAMO:                         Active camouflage

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration starts ---------------------------------------------------------------
local CONFIG = {
    REQUIRED_PLAYERS = 2,
    COUNTDOWN_DELAY = 5,
    SERVER_PREFIX = "**ZOMBIES**",
    ZOMBIFY_ON_SUICIDE = true,
    ZOMBIFY_ON_FALL_DAMAGE = true,
    END_ON_NO_PLAYERS = true,
    ZOMBIE_COUNT = {
        { 1,  4,  1 },
        { 5,  8,  2 },
        { 9,  12, 3 },
        { 13, 16, 4 },
    },
    ATTRIBUTES = {
        ['humans'] = {
            SPEED = 1.0,
            RESPAWN_TIME = 5,
            DAMAGE_MULTIPLIER = 1,
            CAMO = false,
        },
        ['zombies'] = {
            SPEED = 1.15,
            RESPAWN_TIME = 1.5,
            DAMAGE_MULTIPLIER = 2,
            CAMO = true
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
    [cb['EVENT_TICK']] = 'OnTick',
    [cb['EVENT_DIE']] = 'OnDeath',
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_SPAWN']] = 'OnSpawn',
    [cb['EVENT_GAME_END']] = 'OnEnd',
    [cb['EVENT_TEAM_SWITCH']] = 'OnTeamSwitch',
    [cb['EVENT_WEAPON_DROP']] = 'OnWeaponDrop',
    [cb['EVENT_DAMAGE_APPLICATION']] = 'OnDamage'
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

local function getZombieCount()
    local player_count = game.player_count
    for _, range in ipairs(CONFIG.ZOMBIE_COUNT) do
        if player_count >= range[1] and player_count <= range[2] then
            return range[3]
        end
    end
    return 1 -- Default to 1 if no range matches
end

-- Player management
local function createPlayer(id)
    return {
        id = id,
        name = get_var(id, '$name'),
        team = get_var(id, '$team'),
        weapon = nil,
        meta_id = nil,
        switched = nil
    }
end

local function destroyweapon(player)
    if player.weapon then
        destroy_object(player.weapon)
        player.weapon = nil
    end
end

local function switchPlayerTeam(player, new_team)
    player.switched = true
    execute_command('st ' .. player.id .. ' ' .. new_team)
    player.team = new_team

    local attributes = CONFIG.ATTRIBUTES[new_team == TEAM_RED and 'humans' or 'zombies']
    execute_command("s " .. player.id .. " " .. attributes.SPEED)

    if new_team == TEAM_RED then
        destroyweapon(player)
        execute_command('wdel ' .. player.id)
    end
end

local function send(msg)
    execute_command('msg_prefix ""')
    say_all(msg)
    execute_command('msg_prefix "' .. CONFIG.SERVER_PREFIX .. '"')
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

    -- Determine number of zombies
    local zombie_count = getZombieCount()

    -- Assign teams
    for i, id in ipairs(players) do
        local desired_team = (i <= zombie_count) and TEAM_BLUE or TEAM_RED
        execute_command("st " .. id .. " " .. desired_team)
        game.players[id].team = desired_team

        local attributes = CONFIG.ATTRIBUTES[desired_team == TEAM_RED and 'humans' or 'zombies']
        execute_command("s " .. id .. " " .. attributes.SPEED)
    end

    updateTeamCounts()
end

local function checkVictory()
    if game.red_count == 0 then
        send("Zombies have overrun the humans!")
        execute_command('sv_map_next')
    elseif CONFIG.END_ON_NO_PLAYERS and game.blue_count == 0 then
        send("Zombies have retreated. Humans win!")
        execute_command('sv_map_next')
    end
end

local function checkEmptyTeams()
    if CONFIG.END_ON_NO_PLAYERS and game.started then
        if game.red_count == 0 then
            send("Zombies have overrun the humans!")
            execute_command('sv_map_next')
            return true
        elseif game.blue_count == 0 then
            send("Humans have eliminated all zombies!")
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
    send("Game starting in " .. CONFIG.COUNTDOWN_DELAY .. " seconds...")
    timer(CONFIG.COUNTDOWN_DELAY, 'OnCountdown')
end

local function getRespawnTime(team)
    local attributes = CONFIG.ATTRIBUTES[team == TEAM_RED and 'humans' or 'zombies']
    return attributes.RESPAWN_TIME * 33
end

local function setRespawnTime(id, team)
    local respawn_time = getRespawnTime(team)
    local player = get_player(id)
    if player ~= 0 then
        write_dword(player + 0x2C, respawn_time)
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

local function getDamageMultiplier(player)
    local team = player.team == TEAM_BLUE and 'zombies' or 'humans'
    return CONFIG.ATTRIBUTES[team].DAMAGE_MULTIPLIER
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

function OnScriptLoad()
    death_message_hook_enabled = SetupDeathMessageHook()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
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
        switchPlayerTeam(game.players[id], TEAM_BLUE)
        updateTeamCounts()
    elseif game.waiting_for_players and game.player_count >= CONFIG.REQUIRED_PLAYERS then
        startGame()
    end
end

function OnQuit(id)
    if game.players[id] then
        destroyweapon(game.players[id])
        game.players[id] = nil
        game.player_count = game.player_count - 1
        updateTeamCounts()

        if checkEmptyTeams() then return end

        if game.player_count < CONFIG.REQUIRED_PLAYERS and not game.started then
            game.started = false
            game.waiting_for_players = true
            send("Not enough players. Game paused.")
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

    if killerId == 0 or (killerId == -1 and not victim.switched) or killerId == nil then
        send(victim.name .. " died!")
    elseif pvp == 1 then
        switchPlayerTeam(victim, TEAM_BLUE)
        updateTeamCounts()

        if checkEmptyTeams() then return end

        send(victim.name .. " was infected by " .. killer.name .. "!")
    elseif pvp == 0 then
        send(victim.name .. " was killed by " .. killer.name .. "!")
    elseif (suicide or fall_damage) then
        if victim.team == TEAM_RED then
            switchPlayerTeam(victim, TEAM_BLUE)
            updateTeamCounts()

            if checkEmptyTeams() then return end
        end
        send(victim.name .. " died!")
    end

    destroyweapon(victim)
    setRespawnTime(victim.id, victim.team)
    victim.switched = nil
end

function OnTick()
    if not game.started then return end

    for i, player in pairs(game.players) do
        if player and player_alive(i) then
            local attributes = CONFIG.ATTRIBUTES[player.team == TEAM_RED and 'humans' or 'zombies']
            local dyn_player = get_dynamic_player(i)

            if dyn_player == 0 then goto continue end

            if attributes.CAMO and read_float(dyn_player + 0x50C) == 1 then
                execute_command('camo ' .. i .. ' 1')
            end

            ::continue::
        end
    end
end

function OnSpawn(id)
    if not game.started then return end

    local player = game.players[id]
    if not player then return end
    player.meta_id = nil

    local attributes = CONFIG.ATTRIBUTES[player.team == TEAM_RED and 'humans' or 'zombies']
    execute_command("s " .. id .. " " .. attributes.SPEED)

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

function OnDamage(victimId, killerId, metaId, damage)
    if not game.started then return true, damage end
    local killer = tonumber(killerId)
    local victim = tonumber(victimId)

    local victim_data = game.players[victim]
    game.players[victim].meta_id = metaId

    local killer_data = game.players[killer]
    if not killer_data then return true end

    if isFriendlyFire(killer_data, victim_data) then return false end

    return true, damage * getDamageMultiplier(killer_data)
end

function OnCountdown()
    if game.waiting_for_players or game.started then return false end

    local elapsed = os_time() - game.countdown_start
    local remaining = CONFIG.COUNTDOWN_DELAY - elapsed

    if remaining <= 0 then
        send("Zombies are coming! Survive or become one of them!")
        disableDeathMessages()
        execute_command('sv_map_reset')
        shuffleTeams()
        game.started = true
    end

    return true
end

function OnScriptUnload()
    if death_message_hook_enabled then restoreDeathMessages() end
    manageMapObjects(true)
end
