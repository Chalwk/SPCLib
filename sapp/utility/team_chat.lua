--[[
=====================================================================================
SCRIPT NAME:      team_chat.lua
DESCRIPTION:      Advanced team-based private chat system with invite functionality,
                  multiple channels, and flexible communication modes.

FEATURES:
                  - Create/manage private team chat channels
                  - Invite system with player notifications
                  - Multiple chat modes (team-only or global)
                  - Team ownership and moderation controls
                  - Cooldown system to prevent spam
                  - Comprehensive help system

COMMANDS:
                  /team create <name>      - Create new team
                  /team invite <player>    - Invite player to your team
                  /team join <name>        - Join a team
                  /team leave              - Leave current team
                  /team kick <player>      - Kick player from team (owner)
                  /team members            - List team members
                  /team list               - List all available teams
                  /team disband            - Disband team (owner)
                  /team mode [team|global] - Set chat mode
                  /team help               - Show command help
                  /t <message>             - Send team message (alias)

CONFIGURATION:
                  commands = {'team', 't'}  - Primary command and aliases
                  permission = -1           - Required access level (-1 = all players)
                  cooldown = 1.5            - Message cooldown in seconds

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local TeamChat = {
    -- Primary command and aliases
    commands = { 'team', 't' },

    -- Minimum permission level required (-1 = all players)
    permission = -1,

    -- System messages
    messages = {
        created = 'Team "$name" created!',
        exists = 'Team "$name" already exists',
        not_found = 'Team "$name" not found',
        joined = 'Joined team "$name"',
        left = 'Left team "$name"',
        not_member = 'You are not in team "$name"',
        not_owner = 'Only team owner can do that',
        kicked = 'Kicked $player from team',
        been_kicked = 'You were kicked from team "$name"',
        invite_sent = 'Invited $player to team "$name"',
        invited = 'You were invited to team "$name" by $sender',
        player_not_found = '$player not found',
        no_invite = 'No invite for team "$name"',
        already_in_team = 'You are already in team "$name"',
        already_member = '$player is already in team "$name"',
        not_in_team = 'You are not in a team',
        members = 'Team "$name" members: $list',
        list = 'Available teams: $list',
        none = 'No teams available',
        disbanded = 'Team "$name" disbanded',
        help = [[
Team Chat Commands:
  /team create <name> - Create new team
  /team invite <player> - Invite to your team
  /team join <name> - Join a team
  /team leave - Leave current team
  /team kick <player> - Kick from team (owner)
  /team members - List team members
  /team list - List all teams
  /team disband - Disband team (owner)
  /t <message> - Send to team
  /team mode [team|global] - Set chat mode
        ]]
    },

    -- Message formatting
    formats = {
        team_message = '[Team:$team] $name: $msg',
        system = '[TeamChat] $msg'
    },

    -- Message cooldown (seconds)
    cooldown = 1.5
}

local teams = {}               -- [team_name] = { owner = pid, members = { [pid] = true } }
local invites = {}             -- [pid] = { [team_name] = true }
local cooldowns = {}           -- [pid] = last_message_time
local active_players = {}      -- [pid] = Player object
local command_map = {}         -- [command] = true

api_version = '1.12.0.0'

local Player = {}

function Player:new(id)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.id = id
    o.name = get_var(id, '$name')
    o.team = nil
    o.chat_mode = 'global'
    o.lvl = function()
        return tonumber(get_var(id, '$lvl'))
    end

    return o
end

function Player:has_permission()
    return self.lvl() >= TeamChat.permission
end

function Player:send_message(msg)
    rprint(self.id, msg)
end

function Player:set_chat_mode(mode)
    if mode == 'team' or mode == 'global' then
        self.chat_mode = mode
        self:send_message(TeamChat.formats.system:gsub('$msg', 'Chat mode set to: ' .. mode))
    else
        self:send_message(TeamChat.formats.system:gsub('$msg', 'Invalid mode. Use "team" or "global"'))
    end
end

-- Team management functions
local function create_team(player, team_name)
    if teams[team_name] then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.exists:gsub('$name', team_name)))
        return
    end

    teams[team_name] = {
        owner = player.id,
        members = { [player.id] = true }
    }

    player.team = team_name
    player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.created:gsub('$name', team_name)))
end

local function invite_to_team(player, target_name, team_name)
    local team = teams[team_name]
    if not team then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_found:gsub('$name', team_name)))
        return
    end

    if team.owner ~= player.id then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_owner))
        return
    end

    for _, target in pairs(active_players) do
        if target.name:lower() == target_name:lower() then
            if team.members[target.id] then
                player:send_message(TeamChat.formats.system:gsub('$msg',
                    TeamChat.messages.already_member:gsub('$player', target.name)
                    :gsub('$name', team_name)))
                return
            end

            -- Create invite
            invites[target.id] = invites[target.id] or {}
            invites[target.id][team_name] = true

            -- Notify players
            player:send_message(TeamChat.formats.system:gsub('$msg',
                TeamChat.messages.invite_sent:gsub('$player', target.name)
                :gsub('$name', team_name)))

            target:send_message(TeamChat.formats.system:gsub('$msg',
                TeamChat.messages.invited:gsub('$name', team_name)
                :gsub('$sender', player.name)))
            return
        end
    end

    player:send_message(TeamChat.formats.system:gsub('$msg',
        TeamChat.messages.player_not_found:gsub('$player', target_name)))
end

local function join_team(player, team_name)
    if player.team then
        player:send_message(TeamChat.formats.system:gsub('$msg',
            TeamChat.messages.already_in_team:gsub('$name', player.team)))
        return
    end

    if not teams[team_name] then
        player:send_message(TeamChat.formats.system:gsub('$msg',
            TeamChat.messages.not_found:gsub('$name', team_name)))
        return
    end

    -- Check invite
    if not invites[player.id] or not invites[player.id][team_name] then
        player:send_message(TeamChat.formats.system:gsub('$msg',
            TeamChat.messages.no_invite:gsub('$name', team_name)))
        return
    end

    -- Join team
    teams[team_name].members[player.id] = true
    player.team = team_name
    invites[player.id][team_name] = nil

    player:send_message(TeamChat.formats.system:gsub('$msg',
        TeamChat.messages.joined:gsub('$name', team_name)))
end

local function leave_team(player)
    if not player.team then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_in_team))
        return
    end

    local team_name = player.team
    local team = teams[team_name]

    -- Remove from team
    team.members[player.id] = nil
    player.team = nil

    -- Handle empty team
    if next(team.members) == nil then
        teams[team_name] = nil
    -- Transfer ownership if owner left
    elseif team.owner == player.id then
        for id in pairs(team.members) do
            team.owner = id
            break
        end
    end

    player:send_message(TeamChat.formats.system:gsub('$msg',
        TeamChat.messages.left:gsub('$name', team_name)))
end

local function kick_from_team(player, target_name)
    if not player.team then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_in_team))
        return
    end

    local team_name = player.team
    local team = teams[team_name]

    if team.owner ~= player.id then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_owner))
        return
    end

    for _, target in pairs(active_players) do
        if target.name:lower() == target_name:lower() then
            if not team.members[target.id] then
                player:send_message(TeamChat.formats.system:gsub('$msg',
                    TeamChat.messages.not_member:gsub('$player', target.name)
                    :gsub('$name', team_name)))
                return
            end

            -- Kick player
            team.members[target.id] = nil
            target.team = nil

            player:send_message(TeamChat.formats.system:gsub('$msg',
                TeamChat.messages.kicked:gsub('$player', target.name)))

            target:send_message(TeamChat.formats.system:gsub('$msg',
                TeamChat.messages.been_kicked:gsub('$name', team_name)))
            return
        end
    end

    player:send_message(TeamChat.formats.system:gsub('$msg',
        TeamChat.messages.player_not_found:gsub('$player', target_name)))
end

local function list_members(player)
    if not player.team then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_in_team))
        return
    end

    local team = teams[player.team]
    local members = {}
    for id in pairs(team.members) do
        table.insert(members, get_var(id, '$name'))
    end

    player:send_message(TeamChat.formats.system:gsub('$msg',
        TeamChat.messages.members:gsub('$name', player.team)
        :gsub('$list', table.concat(members, ', '))))
end

local function list_teams(player)
    local team_list = {}
    for name in pairs(teams) do
        table.insert(team_list, name)
    end

    if #team_list == 0 then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.none))
    else
        player:send_message(TeamChat.formats.system:gsub('$msg',
            TeamChat.messages.list:gsub('$list', table.concat(team_list, ', '))))
    end
end

local function disband_team(player)
    if not player.team then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_in_team))
        return
    end

    local team_name = player.team
    local team = teams[team_name]

    if team.owner ~= player.id then
        player:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_owner))
        return
    end

    -- Notify and remove all members
    for id in pairs(team.members) do
        local p = active_players[id]
        if p then
            p.team = nil
            p:send_message(TeamChat.formats.system:gsub('$msg',
                TeamChat.messages.disbanded:gsub('$name', team_name)))
        end
    end

    teams[team_name] = nil
end

local function send_team_message(sender, message)

    if not sender.team then
        sender:send_message(TeamChat.formats.system:gsub('$msg', TeamChat.messages.not_in_team))
        return false
    end

    local team = teams[sender.team]
    if not team then
        sender.team = nil
        return false
    end

    local formatted = TeamChat.formats.team_message
        :gsub('$team', sender.team)
        :gsub('$name', sender.name)
        :gsub('$msg', message)

    for id in pairs(team.members) do
        rprint(id, formatted)
    end

    return false
end

local function handle_team_command(player, args)

    local sub_cmd = args[1] and args[1]:lower() or ""

    if sub_cmd == 'create' and args[2] then
        create_team(player, args[2])
    elseif sub_cmd == 'invite' and args[2] and player.team then
        invite_to_team(player, args[2], player.team)
    elseif sub_cmd == 'join' and args[2] then
        join_team(player, args[2])
    elseif sub_cmd == 'leave' then
        leave_team(player)
    elseif sub_cmd == 'kick' and args[2] and player.team then
        kick_from_team(player, args[2])
    elseif sub_cmd == 'members' then
        list_members(player)
    elseif sub_cmd == 'list' then
        list_teams(player)
    elseif sub_cmd == 'disband' then
        disband_team(player)
    elseif sub_cmd == 'mode' and args[2] then
        player:set_chat_mode(args[2]:lower())
    elseif sub_cmd == 'help' then
        player:send_message(TeamChat.messages.help)
    else
        player:send_message(TeamChat.formats.system:gsub('$msg', 'Invalid command. Use /team help'))
    end
end

function OnScriptLoad()

    for _, cmd in ipairs(TeamChat.commands) do
        command_map[cmd:lower()] = true
    end

    -- Register callbacks
    register_callback(cb['EVENT_CHAT'], 'OnChat')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnLeave')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')

    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    teams = {}
    invites = {}
    cooldowns = {}
    active_players = {}

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnJoin(playerId)
    active_players[playerId] = Player:new(playerId)
    active_players[playerId]:send_message(TeamChat.formats.system:gsub('$msg',
        'Type /team help for team chat commands'))
end

function OnLeave(playerId)
    local player = active_players[playerId]
    if player and player.team then
        leave_team(player)
    end

    active_players[playerId] = nil
    cooldowns[playerId] = nil
    invites[playerId] = nil
end

function OnChat(playerId, message)
    local player = active_players[playerId]
    if not player then return true end

    -- Handle team chat mode
    if player.chat_mode == 'team' then
        local now = os.clock()
        if cooldowns[playerId] and now - cooldowns[playerId] < TeamChat.cooldown then
            return false
        end
        cooldowns[playerId] = now
        return send_team_message(player, message)
    end

    return true
end

local function string_split(message)
    local args = {}
    for arg in message:gmatch('%S+') do
        table.insert(args, arg)
    end
    return args
end

function OnCommand(playerId, command)
    local player = active_players[playerId]
    if not player then return true end

    command = command:lower()
    local args = string_split(command)

    local cmd = table.remove(args, 1)
    if not cmd then return true end

    if command_map[cmd] then
        handle_team_command(player, args)
        return false
    elseif cmd == 'tc' or cmd == 't' then
        local msg = table.concat(args, ' ')
        if #msg > 0 then
            send_team_message(player, msg)
        end
        return false
    end

    return true
end

function OnScriptUnload()
    -- N/A
end