--[[
=====================================================================================
SCRIPT NAME:      suicide_punisher.lua
DESCRIPTION:      Automatically punishes players who commit excessive suicides
                  with configurable kick/ban actions and grace periods.

FEATURES:
                  - Configurable suicide threshold before punishment
                  - Adjustable grace period timer
                  - Choice of kick or ban actions
                  - Customizable ban duration
                  - Clear console notifications

CONFIGURATION:
                  threshold = 5    -- Max allowed suicides before punishment
                  grace = 30       -- Grace period in seconds
                  action = 'kick'  -- 'kick' or 'ban'
                  ban_time = 10    -- Ban duration in minutes (0 = permanent)
                  reason = 'Excessive Suicide'

USAGE:
                  Simply load the script - automatically monitors suicides
                  Punishments are applied when threshold is exceeded

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration
local config = {
    threshold = 5, -- Number of suicides within the grace period to trigger the action
    grace = 30, -- Grace period in seconds
    action = 'kick', -- Valid actions are 'kick' and 'ban'
    ban_time = 10, -- Ban time in minutes. Set to zero for permanent ban.
    reason = 'Excessive Suicide'
}

api_version = "1.12.0.0"

-- Player class
local Player = {}
Player.__index = Player

function Player:new(id, name)
    local self = setmetatable({}, Player)
    self.id = id
    self.name = name
    self.suicides = 0
    self.start = nil
    self.finish = nil
    return self
end

function Player:takeAction()
    if config.action == 'kick' then
        execute_command('k ' .. self.id .. ' "' .. config.reason .. '"')
        cprint(self.name .. ' was kicked for ' .. config.reason, 12)
    elseif config.action == 'ban' then
        execute_command('b ' .. self.id .. ' ' .. config.ban_time .. ' "' .. config.reason .. '"')
        cprint(self.name .. ' was banned for ' .. config.reason, 12)
    end
end

-- Global variables
local players = {}

-- Event handlers
function OnScriptLoad()
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    players = {}
    if get_var(0, "$gt") ~= "n/a" then
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function OnJoin(playerIndex)
    players[playerIndex] = Player:new(playerIndex, get_var(playerIndex, "$name"))
end

function OnQuit(playerIndex)
    players[playerIndex] = nil
end

function OnDeath(victimIndex, killerIndex)
    local killer = tonumber(killerIndex)
    local victim = tonumber(victimIndex)
    local victimPlayer = players[victim]

    if victimPlayer and killer == victim then
        victimPlayer.suicides = victimPlayer.suicides + 1

        if victimPlayer.suicides >= config.threshold then
            victimPlayer:takeAction()
        else
            victimPlayer.start = os.time()
            victimPlayer.finish = os.time() + config.grace
        end
    end
end

function OnTick()
    for victimIndex, playerData in pairs(players) do
        if player_present(victimIndex) and playerData.start and os.time() >= playerData.finish then
            playerData.start, playerData.finish, playerData.suicides = nil, nil, 0
        end
    end
end

function OnScriptUnload()
    -- N/A
end