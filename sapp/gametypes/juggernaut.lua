--[[
=====================================================================================
SCRIPT NAME:      juggernaut.lua
DESCRIPTION:      Juggernaut mode where one player becomes the juggernaut with
                  special attributes for a limited time before passing to another.

KEY FEATURES:
                 - Single juggernaut with enhanced abilities
                 - Timed juggernaut role rotation
                 - Configurable juggernaut attributes and duration
                 - Works on MOST custom maps

CONFIGURATION:
    - REQUIRED_PLAYER:            Minimum players needed to start (default: 2)
    - COUNTDOWN_DELAY:            Countdown duration in seconds (default: 5)
    - JUGGERNAUT_DURATION:        Time in seconds as juggernaut (default: 60)
    - SERVER_PREFIX:              Server message prefix (default: "**JUGGERNAUT**")
    - END_ON_NO_PLAYERS:          End the game when no players are present (default: true)
    - ATTRIBUTES_COMMAND_ENABLED: Enable "/attributes" command (default: true)
    - ATTRIBUTES_COMMAND:         Command to show player attributes (default: "attributes")

    - Juggernaut Attributes:
        - SPEED:                  Movement multiplier
        - HEALTH:                 Health multiplier
        - DAMAGE_MULTIPLIER:      Damage amplification
        - CAMO:                   Active camouflage
        - GRENADES:               Number of frag/plasma grenades
        - HEALTH_REGEN:           Health regeneration rate
        - OVER_SHIELD:            Overshield multiplier

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
=====================================================================================
]]

-- Configuration -----------------------------------------------------------------------
local CONFIG = {
    SCORELIMIT = 50,
    REQUIRED_PLAYERS = 2,
    COUNTDOWN_DELAY = 5,
    JUGGERNAUT_DURATION = 60,
    SERVER_PREFIX = "**JUGGERNAUT**",
    END_ON_NO_PLAYERS = true,
    ATTRIBUTES_COMMAND_ENABLED = true,
    ATTRIBUTES_COMMAND = "attributes",
    ATTRIBUTES = {
        SPEED = 1.3,
        HEALTH = 2.0,
        DAMAGE_MULTIPLIER = 2,
        CAMO = true,
        GRENADES = { frags = 3, plasmas = 3 },
        HEALTH_REGEN = 0.01,
        HEALTH_REGEN_INTERVAL = 1,
        OVER_SHIELD = 1.5
    }
}

api_version = '1.12.0.0'

local pairs, table_insert = pairs, table.insert
local math_random, os_time, tonumber = math.random, os.time, tonumber
local string_format = string.format
local get_var, say_all = get_var, say_all
local execute_command, player_present = execute_command, player_present

-- Game state and constants
local game = {
    players = {},
    player_count = 0,
    started = false,
    countdown_start = 0,
    waiting_for_players = true,
    juggernaut_id = nil,
    juggernaut_id_spawning = nil,
    juggernaut_assignment_time = 0,
    next_juggernaut_check = 0,
    next_regen_check = 0
}

local sapp_events = {
    [cb['EVENT_TICK']] = 'OnTick',
    [cb['EVENT_DIE']] = 'OnDeath',
    [cb['EVENT_JOIN']] = 'OnJoin',
    [cb['EVENT_LEAVE']] = 'OnQuit',
    [cb['EVENT_SPAWN']] = 'OnSpawn',
    [cb['EVENT_GAME_END']] = 'OnEnd',
    [cb['EVENT_COMMAND']] = 'OnCommand',
    [cb['EVENT_DAMAGE_APPLICATION']] = 'OnDamage'
}

local function registerCallbacks(juggernaut_game)
    for event, callback in pairs(sapp_events) do
        if juggernaut_game then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function createPlayer(id)
    return {
        id = id,
        name = get_var(id, '$name'),
        is_juggernaut = false
    }
end

local function applyJuggernautAttributes(player, apply)
    local attributes = CONFIG.ATTRIBUTES
    local dyn_player = get_dynamic_player(player.id)

    if player_alive(player.id) and dyn_player ~= 0 then
        if apply then
            -- Apply juggernaut attributes
            write_float(dyn_player + 0xE0, attributes.HEALTH)
            write_float(dyn_player + 0xE4, attributes.OVER_SHIELD)
            execute_command('nades ' .. player.id .. ' ' .. attributes.GRENADES.frags .. ' 1')
            execute_command('nades ' .. player.id .. ' ' .. attributes.GRENADES.plasmas .. ' 2')
            execute_command("s " .. player.id .. " " .. attributes.SPEED)

            if attributes.CAMO then
                execute_command('camo ' .. player.id .. ' -1') -- infinite camouflage
            end

            player.is_juggernaut = true
        else
            -- Remove juggernaut attributes
            write_float(dyn_player + 0xE0, 1.0)              -- Reset health to 100%
            write_float(dyn_player + 0xE4, 1.0)              -- Reset shield to 100%
            execute_command('nades ' .. player.id .. ' 0 1') -- Remove frag grenades
            execute_command('nades ' .. player.id .. ' 0 2') -- Remove plasma grenades
            execute_command("s " .. player.id .. " 1.0")     -- Reset speed

            if attributes.CAMO then
                execute_command('camo ' .. player.id .. ' 1') -- 1 second camouflage to remove
            end

            player.is_juggernaut = false
        end
    end
end

local function regenerateHealth(dyn_player)
    local health = read_float(dyn_player + 0xE0)
    local max_health = CONFIG.ATTRIBUTES.HEALTH
    if health < max_health then
        local new_health = math.min(health + CONFIG.ATTRIBUTES.HEALTH_REGEN, max_health)
        write_float(dyn_player + 0xE0, new_health)
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

local function setJuggernaut(id)
    game.juggernaut_id = id
    game.juggernaut_assignment_time = os_time()
    game.next_juggernaut_check = os_time() + CONFIG.JUGGERNAUT_DURATION
    game.juggernaut_id_spawning = nil
end

local function assignNewJuggernaut()
    if game.player_count < CONFIG.REQUIRED_PLAYERS then return end

    -- Remove current juggernaut if exists
    if game.juggernaut_id then
        local current_juggernaut = game.players[game.juggernaut_id]
        if current_juggernaut then
            applyJuggernautAttributes(current_juggernaut, false)
            send(nil, current_juggernaut.name .. " is no longer the Juggernaut!")
        end
    end

    -- Select random player
    local players = {}
    for id, _ in pairs(game.players) do
        if id ~= game.juggernaut_id then -- Exclude current juggernaut
            table_insert(players, id)
        end
    end

    if #players == 0 then return end

    local new_juggernaut_id = players[math_random(1, #players)]
    local new_juggernaut = game.players[new_juggernaut_id]

    -- Assign new juggernaut
    if player_alive(new_juggernaut_id) then
        applyJuggernautAttributes(new_juggernaut, true)
        setJuggernaut(new_juggernaut_id)
        send(nil, new_juggernaut.name .. " is now the JUGGERNAUT!")
        send(nil, "Juggernaut time: " .. CONFIG.JUGGERNAUT_DURATION .. " seconds")
    else
        send(nil, new_juggernaut.name .. " will be the JUGGERNAUT when they spawn!")
        game.juggernaut_id_spawning = new_juggernaut_id
    end
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

local function showAttributes(id)
    local player = game.players[id]
    if not player then return end

    if player.is_juggernaut then
        local attributes = CONFIG.ATTRIBUTES
        local current_health = "N/A"
        local dyn_player = get_dynamic_player(id)

        if dyn_player ~= 0 and player_alive(id) then
            current_health = string_format("%.0f%%", read_float(dyn_player + 0xE0) * 100)
        end

        send(id, "** JUGGERNAUT Attributes **")
        send(id, "Health: " .. current_health .. " (Base: " .. (attributes.HEALTH * 100) .. "%)")
        send(id, "Speed: " .. (attributes.SPEED * 100) .. "%")
        send(id, "Damage: " .. attributes.DAMAGE_MULTIPLIER .. "x")
        send(id, "Grenades - Frags: " .. attributes.GRENADES.frags .. ", Plasmas: " .. attributes.GRENADES.plasmas)
        send(id, "Camouflage: " .. (attributes.CAMO and "Yes" or "No"))
        send(id, "Health Regen: " .. (attributes.HEALTH_REGEN * 100) .. "% per tick")
        send(id, "Overshield: " .. (attributes.OVER_SHIELD * 100) .. "%")

        local time_left = CONFIG.JUGGERNAUT_DURATION - (os_time() - game.juggernaut_assignment_time)
        if time_left < 0 then time_left = 0 end
        send(id, "Time as Juggernaut: " .. time_left .. " seconds remaining")
    else
        send(id, "You are a normal player with standard attributes.")
    end
end

-- SAPP Events
function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    game.players = {}
    game.player_count = 0
    game.juggernaut_id = nil
    game.started = false
    game.next_juggernaut_check = 0
    game.next_regen_check = os_time() + 1

    execute_command('scorelimit ' .. CONFIG.SCORELIMIT)

    for i = 1, 16 do
        if player_present(i) then
            game.players[i] = createPlayer(i)
            game.player_count = game.player_count + 1
        end
    end

    startGame()
    registerCallbacks(true)
end

function OnEnd()
    game.started = false
    game.waiting_for_players = true
    game.juggernaut_id = nil
    game.juggernaut_id_spawning = nil
end

function OnJoin(id)
    game.players[id] = createPlayer(id)
    game.player_count = game.player_count + 1

    if game.started then return end

    if game.waiting_for_players and game.player_count >= CONFIG.REQUIRED_PLAYERS then
        startGame()
    end
end

function OnQuit(id)
    if game.players[id] then
        -- If juggernaut leaves, assign a new one
        if game.juggernaut_id == id or game.juggernaut_id_spawning == id then
            game.juggernaut_id = nil
            game.juggernaut_id_spawning = nil
            if game.started then
                assignNewJuggernaut()
            end
        end

        game.players[id] = nil
        game.player_count = game.player_count - 1

        if CONFIG.END_ON_NO_PLAYERS and game.player_count == 0 then
            execute_command('sv_map_next')
        end
    end
end

function OnSpawn(id)
    local player = game.players[id]
    if player and game.temp_juggernaut_id == id then
        applyJuggernautAttributes(player, true)
        setJuggernaut(id)
        send(nil, player.name .. " spawned and is now the JUGGERNAUT!")
        send(nil, "Juggernaut time: " .. CONFIG.JUGGERNAUT_DURATION .. " seconds")
    end
end

function OnDeath(victimId)
    if not game.started then return end
    victimId = tonumber(victimId)

    local victim = game.players[victimId]

    -- If juggernaut dies, assign a new one immediately
    if victim and victim.is_juggernaut then
        game.juggernaut_id = nil
        assignNewJuggernaut()
    end
end

function OnDamage(_, killerId, _, damage)
    if not game.started then return true, damage end
    local killer = tonumber(killerId)

    local killer_data = game.players[killer]
    if not killer_data then return true end

    -- Apply damage multiplier if the killer is the juggernaut
    if killer_data.is_juggernaut then
        local damage_multiplier = CONFIG.ATTRIBUTES.DAMAGE_MULTIPLIER
        return true, damage * damage_multiplier
    end

    return true, damage
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
        send(nil, "Juggernaut mode started!")

        -- Assign initial juggernaut
        assignNewJuggernaut()
        game.started = true
    end

    return true
end

function OnTick()
    if not game.started or not game.juggernaut_id then return end

    local now = os_time()
    if now >= game.next_juggernaut_check then
        assignNewJuggernaut()
    elseif now >= game.next_regen_check then
        local dyn_player = get_dynamic_player(game.juggernaut_id)
        if dyn_player ~= 0 and player_alive(game.juggernaut_id) then
            regenerateHealth(dyn_player)
        end
        game.next_regen_check = now + CONFIG.HEALTH_REGEN_INTERVAL
    end

    return true
end

function OnScriptUnload() end
