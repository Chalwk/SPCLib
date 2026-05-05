--[[
===============================================================================
SCRIPT NAME:      list_players.lua
DESCRIPTION:      Enhanced player listing with:
                  - Detailed player information
                  - Clean column formatting
                  - Team/IP visibility

FEATURES:
                  - Multiple command triggers
                  - Configurable output format
                  - Permission controls
                  - Real-time updates

CONFIGURATION:    Adjust these settings:
                  - command/alt_command: Trigger words
                  - max_name_length: Name column width
                  - permission_level: Access requirement
                  - ffa_team_name: Label for FFA players

Copyright (c) 2019-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG STARTS -------------------------------------------------------------
local CFG = {
    command = 'pls',               -- Primary command trigger
    alt_command = 'players',       -- Alternate command trigger
    permission_level = 1,          -- Minimum admin level required
    max_name_length = 24,          -- Maximum characters for player names
    max_team_length = 12,          -- Maximum characters for team names
    show_player_count = true,      -- Display player count in header
    ffa_team_name = 'FFA',         -- Display name for FFA players
    header_spacing = 2            -- Extra spaces between columns
}
-- CONFIG ENDS ---------------------------------------------------------------

api_version = '1.12.0.0'

local players, player_format, header_format
local get_var = get_var
local player_present = player_present
local register_callback = register_callback
local cprint = cprint
local rprint = rprint
local format = string.format
local sub = string.sub
local insert = table.insert
local concat = table.concat

local function update_player(id)
    local name = get_var(id, '$name')
    local ip = get_var(id, '$ip')
    local team = (CFG.ffa and CFG.ffa_team_name) or get_var(id, '$team'):upper()

    players[id] = {
        name = sub(name, 1, CFG.max_name_length),
        ip = ip,
        team = team
    }
end

local function init_formats()
    local name_width = CFG.max_name_length + CFG.header_spacing
    local team_width = CFG.max_team_length + CFG.header_spacing

    player_format = format('%%-%ds%%-%ds%%s', name_width, team_width)
    header_format = format(player_format, 'PLAYER NAME', 'TEAM', 'IP ADDRESS')
end

function OnJoin(id)
    update_player(id)
end

function OnQuit(id)
    players[id] = nil
end

function OnTeamSwitch(id)
    if player_present(id) then
        update_player(id)
    end
end

function OnStart()
    players = {}
    CFG.ffa = (get_var(0, '$ffa') == '1')

    for i = 1, 16 do
        if player_present(i) then
            update_player(i)
        end
    end
end

local function respond(id, msg)
    if id == 0 then
        cprint(msg)
    else
        rprint(id, msg)
    end
end

local function has_permission(id)
    if id == 0 then return true end
    local lvl = tonumber(get_var(id, '$lvl'))
    return lvl >= CFG.permission_level or false
end

local function generate_player_list()
    local list = {}
    for _, player in pairs(players) do
        insert(list, format(player_format, player.name, player.team, player.ip))
    end
    return concat(list, '\n')
end

function OnCommand(id, cmd)
    cmd = cmd:lower()
    local trigger = cmd:match('^(%S+)')

    if trigger == CFG.command or trigger == CFG.alt_command then
        if not has_permission(id) then
            respond(id, 'Insufficient permissions')
            return false
        end

        local count = 0
        for _ in pairs(players) do count = count + 1 end

        if count == 0 then
            respond(id, 'No players online')
            return false
        end

        local header = header_format
        if CFG.show_player_count then
            header = header .. format('\nPlayers online: %d', count)
        end

        respond(id, header .. '\n' .. generate_player_list())
        return false
    end
end

function OnScriptLoad()
    init_formats()

    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_TEAM_SWITCH'], 'OnTeamSwitch')

    if get_var(0, '$gt') ~= 'n/a' then
        OnStart()
    end
end

function OnScriptUnload() end