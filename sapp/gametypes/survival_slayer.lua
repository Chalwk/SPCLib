--[[
=====================================================================================
SCRIPT NAME:      survival_slayer.lua
DESCRIPTION:      Time-based survival mode featuring:
                  - Countdown life timer for all players
                  - Time bonus awarded for kills (+10 seconds)
                  - Victory condition: First to reach kill limit (15)
                  - Automatic player elimination when timer expires

GAMEPLAY MECHANICS:
                  - Players start with 45 second life timer
                  - Timer counts down while alive
                  - Kills extend your remaining time
                  - Last player standing wins if kill limit isn't reached

CONFIGURATION:
                  - Adjustable base lifespan (default: 45s)
                  - Customizable time bonus per kill (default: +10s)
                  - Configurable win condition (default: 15 kills)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Configuration table for the Survival Slayer game mode
local SurvivalSlayer = {
    -- The initial life time (in seconds) for each player
    life_time = 45,

    -- The bonus life time (in seconds) awarded for each kill
    death_bonus = 10,

    -- The number of kills required to win the game
    kills_to_win = 15
}

-- config ends

local players = {}
local start_time = 0
local game_started = false

local floor = math.floor
local format = string.format

api_version = '1.12.0.0'

local function say(id, message)
    for _ = 1, 25 do
        rprint(id, " ")
    end
    rprint(id, message)
end

function SurvivalSlayer:newPlayer(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    players = {}
    game_started = true
    start_time = os.clock()
    execute_command('scorelimit ' .. SurvivalSlayer.kills_to_win)
    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnEnd()
    game_started = false
end

function OnJoin(id)
    players[id] = SurvivalSlayer:newPlayer({
        name = get_var(id, '$name'),
        life = SurvivalSlayer.life_time
    })
end

function OnQuit(id)
    players[id] = nil
end

function OnSpawn(id)
    local p = players[id]
    if p then
        p.life = SurvivalSlayer.life_time
    end
end

function OnTick()
    if not game_started then return end

    local elapsed_time = os.clock() - start_time
    for i, v in pairs(players) do
        if player_alive(i) and v.life then
            v.life = v.life - elapsed_time
            if v.life <= 0 then
                v.life = nil
                execute_command('kill ' .. i)
            else
                say(i, format('%s: %s', v.name, floor(v.life)))
            end
        end
    end
    start_time = os.clock()
end

function OnDeath(victim, killer)
    killer = tonumber(killer)
    victim = tonumber(victim)

    local k = players[killer]
    local v = players[victim]

    if killer > 0 and killer ~= victim and k and v then
        k.life = k.life + SurvivalSlayer.death_bonus
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, 'OnDeath')
    register_callback(cb.EVENT_TICK, 'OnTick')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnQuit')
    register_callback(cb.EVENT_SPAWN, 'OnSpawn')
    register_callback(cb.EVENT_GAME_END, 'OnEnd')
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnScriptUnload() end
