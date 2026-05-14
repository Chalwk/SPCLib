--[[
=====================================================================================
SCRIPT NAME:      rage_quit.lua
DESCRIPTION:      Detects and announces rage quits with different message types.
                  - Detects kill-related rage quits
                  - Detects general quick disconnects
                  - Customizable detection time thresholds
                  - Custom announcement messages

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration starts --------------------------------------------------
local GRACE_PERIOD_AFTER_KILL = 10 -- in seconds
local GENERAL_RAGE_QUIT_PERIOD = 15 -- in seconds
-- Messages ---------------------------------------------------
local KILL_RAGE_QUIT_MESSAGE = '%s rage quit because of %s'
local GENERAL_RAGE_QUIT_MESSAGE = '%s rage quit!'
local SERVER_PREFIX = '**SAPP**'
-- Configuration ends ----------------------------------------------------

api_version = '1.12.0.0'

local players = {}

local function send(message, ...)
    execute_command('msg_prefix ""')
    cprint(string.format(message, ...))
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')
end

function onJoin(id)
    players[id] = {
        name = get_var(id, '$name'),
        joined = os.time(),
    }
end

function onQuit(id)
    local player = players[id]
    if player then
        local currentTime = os.time()
        if player.killer and player.finish - player.joined > 0 then
            send(KILL_RAGE_QUIT_MESSAGE, player.name, player.killer.name)
        elseif player.joined + GENERAL_RAGE_QUIT_PERIOD > currentTime then
            send(GENERAL_RAGE_QUIT_MESSAGE, player.name)
        end
        players[id] = nil
    end
end

function onDeath(victimId, killerId)
    local victim = tonumber(victimId)
    local killer = tonumber(killerId)

    if killer > 0 and killer ~= victim then
        local victimData = players[victim]
        local killerData = players[killer]

        if victimData and killerData then
            victimData.killer = killerData
            victimData.joined = os.time()
            victimData.finish = os.time() + GRACE_PERIOD_AFTER_KILL
        end
    end
end

function onStart()
    if get_var(0, '$gt') ~= 'n/a' then
        players = {}
        for i = 1, 16 do
            if player_present(i) then
                onJoin(i)
            end
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, 'onJoin')
    register_callback(cb.EVENT_LEAVE, 'onQuit')
    register_callback(cb.EVENT_DIE, 'onDeath')
    register_callback(cb.EVENT_GAME_START, 'onStart')
    onStart()
end

function OnScriptUnload()
    -- N/A
end