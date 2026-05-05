--[[
=====================================================================================
SCRIPT NAME:      vote_kick.lua
DESCRIPTION:      Player-driven moderation system for removing disruptive players.

FEATURES:
                  - Democratic player moderation system
                  - Configurable vote thresholds (minimum players, percentage)
                  - Vote tracking and validation
                  - Cooldown protection against abuse
                  - Vote expiration system
                  - Admin immunity option
                  - Anonymous voting option

COMMANDS:
                  /votekick <player_id>    - Initiate kick vote against player
                  /votelist                - View active vote kick sessions
                  /cancelvote              - Cancel your active vote

CONFIGURATION:
                  vote_percentage = 60     - Required vote percentage to kick
                  minimum_players = 2      - Minimum players needed to vote
                  vote_grace_period = 30   - Vote duration in seconds
                  kicked_grace_period = 60 - Cooldown for kicked players
                  admin_immunity = true    - Protect admins from votes

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local CFG = {
    vote_command = 'votekick',
    vote_list_command = 'votelist',
    cancel_vote_command = 'cancelvote',
    minimum_players = 2,
    vote_percentage = 60,
    vote_grace_period = 30,
    kicked_grace_period = 60,
    anonymous_votes = false,
    announce_on_initiate = true,
    announce_usage = true,
    announce_interval = 120,
    admin_immunity = true,
    prefix = '**SAPP**',
}

local clock = os.clock
local ceil = math.ceil
local format = string.format

local active_votes = {}
local kicked_players = {}

local player_present = player_present
local get_var = get_var
local execute_command = execute_command
local rprint = rprint
local say_all = say_all
local timer = timer

api_version = '1.12.0.0'

-- Utility Functions
local function split_command(input)
    local args = {}
    for arg in input:gmatch('([^%s]+)') do
        table.insert(args, arg)
    end
    return args
end

local function send(player_id, ...)
    if not player_id then
        execute_command('msg_prefix ""')
        say_all(format(...))
        execute_command('msg_prefix "' .. CFG.prefix .. '"')
        return
    end
    rprint(player_id, format(...))
end

local function is_admin(player_id)
    return CFG.admin_immunity and tonumber(get_var(player_id, '$lvl')) > 0
end

-- Vote Management
local function announce_vote_start(target_id)
    if not CFG.announce_on_initiate then return end

    local target_name = active_votes[target_id].name
    send(nil, 'Vote Kick initiated against %s.', target_name)
    send(nil, 'Use /%s to see active votes.', CFG.vote_list_command)
    send(nil, 'Use /%s <id> to vote.', CFG.vote_command)
    send(nil, 'Use /%s <id> to cancel a vote.', CFG.cancel_vote_command)
end

local function start_vote_session(target_id, initiator_id)
    active_votes[target_id] = {
        name = get_var(target_id, '$name'),
        start_time = clock(),
        voters = { [initiator_id] = true },
        count = 1
    }
    announce_vote_start(target_id)
end

local function add_vote(target_id, voter_id)
    local session = active_votes[target_id]
    if session.voters[voter_id] then
        send(voter_id, 'You have already voted.')
        return false
    end

    session.voters[voter_id] = true
    session.count = session.count + 1
    return true
end

local function cancel_vote_session(target_id)
    local player = active_votes[target_id]
    if player then
        send(nil, 'Vote against %s has been canceled.', player.name)
        active_votes[target_id] = nil
    end
end

local function expire_votes(now)
    for target_id, session in pairs(active_votes) do
        if now - session.start_time > CFG.vote_grace_period then
            send(nil, 'Vote against %s has expired.', session.name)
            active_votes[target_id] = nil
        end
    end
end

local function kick_player(target_id, session)
    kicked_players[target_id] = clock()
    execute_command(format('k %d "[Vote Kick - %d votes]"', target_id, session.vote_count))
    send(nil, '%s has been vote kicked.', session.name)
end

local function process_vote(voter_id, target_id)
    if not player_present(target_id) then
        send(voter_id, 'Invalid player ID.')
        return
    end

    if is_admin(target_id) then
        send(voter_id, 'Admins cannot be vote kicked.')
        return
    end

    local total_players = tonumber(get_var(0, '$pn'))
    if total_players < CFG.minimum_players then
        send(voter_id, format('Minimum %d players required.', CFG.minimum_players))
        return
    end

    local session = active_votes[target_id]
    if session then
        if not add_vote(target_id, voter_id) then return end
    else
        start_vote_session(target_id, voter_id)
        session = active_votes[target_id]
    end

    local votes_needed = math.ceil((CFG.vote_percentage / 100) * total_players)
    if session.count >= votes_needed then
        kick_player(target_id, session)
        active_votes[target_id] = nil
    elseif not CFG.anonymous_votes then
        local voter_name = get_var(voter_id, '$name')
        send(nil, '%s voted to kick %s (%d/%d votes)',
            voter_name, session.name, session.count, votes_needed)
    end
end

local function list_votable_players(player_id)
    send(player_id, 'Players eligible for vote kick:')
    for i = 1, 16 do
        if player_present(i) and not is_admin(i) then
            send(player_id, format('%d - %s', i, get_var(i, '$name')))
        end
    end
end

local function clean_kicked_players(now)
    for id, kick_time in pairs(kicked_players) do
        if now - kick_time > CFG.kicked_grace_period then
            kicked_players[id] = nil
        end
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnLeave')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnScriptUnload() end

function OnStart()
    active_votes = {}
    if get_var(0, '$gt') == 'n/a' then return end

    if CFG.announce_usage then
        timer(CFG.announce_interval * 1000, 'AnnounceUsage')
    end

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnJoin(player_id)
    if kicked_players[player_id] then
        local elapsed = clock() - kicked_players[player_id]
        if elapsed < CFG.kicked_grace_period then
            local wait_time = ceil(CFG.kicked_grace_period - elapsed)
            send(player_id, 'You were recently kicked. Wait %d seconds.', wait_time)
            execute_command(format('k %d "Kick cooldown: %d seconds"', player_id, wait_time))
        else
            kicked_players[player_id] = nil
        end
    end
end

function OnLeave(player_id)
    -- Cancel any vote against this player
    cancel_vote_session(player_id)

    for i = 1,#active_votes do
        local session = active_votes[i]
        if session.voters[player_id] then
            session.voters[player_id] = nil
            session.count = session.count - 1
        end
    end
end

function OnTick()
    local now = clock()
    expire_votes(now)
    clean_kicked_players(now)
end

function OnCommand(player_id, command)
    if player_id == 0 then return true end

    local args = split_command(command)
    local cmd = args[1]:lower()

    if cmd == CFG.vote_command and args[2] then
        local target_id = tonumber(args[2])
        if target_id then
            process_vote(player_id, target_id)
        else
            send(player_id, 'Invalid player ID format.')
        end
        return true
    elseif cmd == CFG.vote_list_command then
        list_votable_players(player_id)
        return true
    elseif cmd == CFG.cancel_vote_command and args[2] then
        local target_id = tonumber(args[2])
        if target_id then
            cancel_vote_session(target_id)
        else
            send(player_id, 'Invalid player ID format.')
        end
        return true
    end

    return true
end

function AnnounceUsage()
    send(nil, 'Use /%s <player_id> to initiate a vote kick.', CFG.vote_command)
    return true -- loop
end
