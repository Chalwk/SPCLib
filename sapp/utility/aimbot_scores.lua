--[[
=====================================================================================
SCRIPT NAME:      aimbot_scores.lua
DESCRIPTION:      Displays player accuracy statistics with optional filters.
                  - Command: /botscore [target] [mode]
                    * target: 1-16 | me | all | *
                    * mode: 0 (basic) | 1 (detailed)
                  - Supports individual or global player queries
                  - Provides real-time bot/accuracy scores
                  - Requires minimum permission level 1

Credits:          Original concept by mouseboyx (OpenCarnage)

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config Start -----------------------

local COMMAND = 'botscore'
local COMMAND_PERMISSION_LEVEL = 1

-- Config Ends -----------------------

api_version = '1.12.0.0'

local players = {}

local function clearConsole(playerId)
    for _ = 1, 25 do rprint(playerId, ' ') end
end

function OnTick()
    for playerId, data in pairs(players) do
        if #data.suspects > 0 then
            clearConsole(playerId)
            for _, suspect in ipairs(data.suspects) do
                rprint(playerId, string.format("%s: %s", suspect.name, suspect:score()))
            end
        end
    end
end

local function parseArgs(input)
    local result = {}
    for substring in input:gmatch("([^%s]+)") do
        result[#result + 1] = substring
    end
    return result
end

local function hasPermission(id)
    return tonumber(get_var(id, '$lvl')) >= COMMAND_PERMISSION_LEVEL
end

local function getPlayers(playerId, args)
    local targets = {}
    local suspect = args[2]

    if suspect == 'me' and playerId ~= 0 then
        table.insert(targets, playerId)
    elseif tonumber(suspect) and player_present(tonumber(suspect)) then
        table.insert(targets, tonumber(suspect))
    elseif suspect == 'all' or suspect == '*' then
        for i = 1, 16 do
            if player_present(i) then
                table.insert(targets, i)
            end
        end
    else
        rprint(playerId, string.format("Invalid Player ID. Usage: /%s [1-16/me/all/*] [0/1]", COMMAND))
    end
    return targets
end

-- Determine whether to show scores
local function getShowScores(showScoresArg)
    return showScoresArg == '1' or showScoresArg == nil
end

-- Add a suspect to the player's list
local function addSuspect(playerId, suspect)
    table.insert(players[playerId].suspects, {
        name = get_var(suspect, '$name'),
        score = function()
            local botScore = get_var(suspect, '$botscore')
            return botScore .. (player_alive(suspect) and '' or ' [respawning]')
        end
    })
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    players = {}
    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnJoin(playerId)
    players[playerId] = { suspects = {} }
end

function OnQuit(playerId)
    players[playerId] = nil
end

function OnCommand(playerId, command)
    local args = parseArgs(command)
    if #args == 0 then return true end

    if args[1] == COMMAND then
        if playerId == 0 then
            cprint("Cannot execute this command from the console")
            return false
        elseif hasPermission(playerId) then
            local showScores = getShowScores(args[3])

            if not showScores then
                rprint(playerId, 'Hiding bot scores')
                players[playerId].suspects = {}
                return false
            end

            local suspects = getPlayers(playerId, args)

            for _, pl in ipairs(suspects) do
                addSuspect(playerId, pl)
            end
        else
            rprint(playerId, 'Insufficient Permission')
        end
    end
end

function OnScriptUnload() end
