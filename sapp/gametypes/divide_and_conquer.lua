--[[
=====================================================================================
SCRIPT NAME:      divide_and_conquer.lua
DESCRIPTION:      Team conversion warfare where kills convert enemies to allies,
                  creating dynamic team shifts and strategic gameplay.

KEY FEATURES:
                 - Team conversion mechanics
                 - Real-time team composition changes
                 - Automatic team balancing on game start
                 - Victory condition when one team is eliminated
                 - Player count-based game activation
                 - Countdown timer before match start
                 - Enhanced team shuffling with anti-duplicate protection
                 - Death message suppression during team changes

LAST UPDATED:    21/8/2025

Copyright (c) 2023-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration -----------------------------------------------------------------------
local REQUIRED_PLAYERS = 2                   -- Minimum players required to start
local COUNTDOWN_DELAY = 5                    -- Seconds before game starts
local SERVER_PREFIX = "**Divide & Conquer**" -- Server message prefix
local SCORE_LIMIT = 99999                    -- Score limit (effectively disabled)
-- End of Configuration -----------------------------------------------------------------

api_version = '1.12.0.0'

local pairs, ipairs, table_insert = pairs, ipairs, table.insert
local math_random, os_time, tonumber = math.random, os.time, tonumber

local get_var, say_all = get_var, say_all
local execute_command, player_present = execute_command, player_present

local death_message_hook_enabled = false
local death_message_address = nil
local original_death_message_bytes = nil
local DEATH_MESSAGE_SIGNATURE = "8B42348A8C28D500000084C9"

local sapp_events = {
    [cb.EVENT_DIE] = 'OnDeath',
    [cb.EVENT_JOIN] = 'OnJoin',
    [cb.EVENT_LEAVE] = 'OnQuit',
    [cb.EVENT_GAME_END] = 'OnEnd',
    [cb.EVENT_TEAM_SWITCH] = 'OnTeamSwitch'
}

local function register_callbacks(team_game)
    for event, callback in pairs(sapp_events) do
        if team_game then
            register_callback(event, callback)
        else
            unregister_callback(event)
        end
    end
end

local function SetupDeathMessageHook()
    local address = sig_scan(DEATH_MESSAGE_SIGNATURE)
    if address == 0 then
        cprint("Divide & Conquer: Death message signature not found!", 4)
        return false
    end

    death_message_address = address + 3
    original_death_message_bytes = read_dword(death_message_address)

    if not original_death_message_bytes or original_death_message_bytes == 0 then
        cprint("Divide & Conquer: Failed to read original death message bytes!", 4)
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

-- Game State
local game = {
    players = {},
    player_count = 0,
    started = false,
    countdown_start = 0,
    waiting_for_players = true,
    red_count = 0,
    blue_count = 0
}

local function create_player(id)
    return { id = id, name = get_var(id, '$name'), team = get_var(id, '$team') }
end

local function switch_player_team(player, new_team)
    execute_command('st ' .. player.id .. ' ' .. new_team)
    player.team = new_team
end

local function broadcast(msg)
    execute_command('msg_prefix ""')
    say_all(msg)
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')
end

local function update_team_counts()
    game.red_count, game.blue_count = 0, 0
    for _, player in pairs(game.players) do
        if player.team == 'red' then
            game.red_count = game.red_count + 1
        elseif player.team == 'blue' then
            game.blue_count = game.blue_count + 1
        end
    end
end

local function shuffle_teams()
    local players = {}
    local original_teams = {} -- Store original team for each player

    for id, player in pairs(game.players) do
        original_teams[id] = player.team
        table_insert(players, id)
    end

    if #players < 2 then return end

    -- Fisher-Yates shuffle
    for i = #players, 2, -1 do
        local j = math_random(i)
        players[i], players[j] = players[j], players[i]
    end

    -- Check if new assignment is identical to original
    local identical = true
    for i, id in ipairs(players) do
        local new_team = (i <= #players / 2) and "red" or "blue"
        if new_team ~= original_teams[id] then
            identical = false
            break
        end
    end

    -- Force change by swapping first/last players if identical
    if identical then
        players[1], players[#players] = players[#players], players[1]
    end
    for i, id in ipairs(players) do
        local desired_team = (i <= #players / 2) and "red" or "blue"
        execute_command("st " .. id .. " " .. desired_team)
        game.players[id].team = desired_team
    end

    update_team_counts()
end

local function check_victory()
    if game.red_count == 0 then
        broadcast("Blue team wins!")
        execute_command('sv_map_next')
    elseif game.blue_count == 0 then
        broadcast("Red team wins!")
        execute_command('sv_map_next')
    end
end

local function start_game()
    if game.player_count < REQUIRED_PLAYERS then
        game.waiting_for_players = true
        return
    end

    game.waiting_for_players = false
    game.countdown_start = os_time()
    broadcast("Game starting in " .. COUNTDOWN_DELAY .. " seconds...")
    timer(COUNTDOWN_DELAY, 'OnCountdown')
end

-- SAPP Events
function OnScriptLoad()
    death_message_hook_enabled = SetupDeathMessageHook()
    register_callback(cb.EVENT_GAME_START, 'OnStart')

    execute_command('sv_tk_ban 0')
    execute_command('sv_friendly_fire 0')
    execute_command('scorelimit ' .. SCORE_LIMIT)

    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    if get_var(0, '$ffa') == '1' then
        register_callbacks(false)
        cprint('====================================================', 12)
        cprint('Divide & Conquer: Only runs on team-based games', 12)
        cprint('====================================================', 12)
        return
    end

    game.players = {}
    game.player_count = 0
    game.started = false

    for i = 1, 16 do
        if player_present(i) then
            game.players[i] = create_player(i)
            game.player_count = game.player_count + 1
        end
    end

    update_team_counts()
    start_game()
    register_callbacks(true)
end

function OnEnd()
    game.started = false
    game.waiting_for_players = true
end

function OnJoin(id)
    game.players[id] = create_player(id)
    game.player_count = game.player_count + 1
    update_team_counts()

    if game.waiting_for_players and game.player_count >= REQUIRED_PLAYERS then
        start_game()
    end
end

function OnQuit(id)
    if game.players[id] then
        game.players[id] = nil
        game.player_count = game.player_count - 1
        update_team_counts()

        if game.player_count < REQUIRED_PLAYERS and not game.started then
            game.started = false
            game.waiting_for_players = true
            broadcast("Not enough players. Game paused.")
        end
    end
end

function OnTeamSwitch(id)
    if game.players[id] then
        game.players[id].team = get_var(id, '$team')
        update_team_counts()

        if game.started then check_victory() end
    end
end

function OnDeath(victim_id, killer_id)
    if not game.started then return end
    victim_id = tonumber(victim_id)
    killer_id = tonumber(killer_id)

    local victim = game.players[victim_id]
    local killer = game.players[killer_id]

    local server_environmental = killer_id == 0 or killer_id == -1
    if server_environmental or not victim or not killer then return end

    if victim.team ~= killer.team then
        switch_player_team(victim, killer.team)
        update_team_counts()
        broadcast(victim.name .. " was converted to the " .. killer.team .. " team!")

        check_victory()
    end
end

function OnCountdown()
    if game.waiting_for_players or game.started then return false end

    local elapsed = os_time() - game.countdown_start
    local remaining = COUNTDOWN_DELAY - elapsed

    if remaining <= 0 then
        broadcast("Game started! Convert enemies to your team by eliminating them!")

        disableDeathMessages()
        execute_command('sv_map_reset')
        shuffle_teams()
        restoreDeathMessages()

        game.started = true
    end

    return true
end

function OnScriptUnload()
    if death_message_hook_enabled then
        restoreDeathMessages()
    end
end
