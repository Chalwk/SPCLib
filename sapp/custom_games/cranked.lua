--[[
=====================================================================================
SCRIPT NAME:      cranked.lua
DESCRIPTION:      Implements Call of Duty-style Cranked mode with time-limited kill chains
                  and explosive consequences for failing to maintain momentum.

KEY FEATURES:
                 - Kill-triggered "cranked" state with timer
                 - Speed and damage boosts while cranked
                 - Explosive penalty for failing to chain kills
                 - Visual countdown timer display
                 - Map-specific configuration options
                 - Multiplayer-compatible mechanics

CONFIGURATION OPTIONS:
                 - Adjustable cranked duration per map
                 - Customizable speed/damage multipliers
                 - Explosion effect customization
                 - Cross-map settings consistency

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

----------------------------------------
-- Configuration starts
----------------------------------------
local Game = {
    ["bloodgulch"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["deathisland"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["icefields"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["infinity"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["sidewinder"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["timberland"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["dangercanyon"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["beavercreek"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["boardingaction"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["carousel"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["chillout"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["damnation"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["gephyrophobia"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["hangemhigh"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["longest"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["prisoner"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["putput"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["ratrace"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    },
    ["wizard"] = {
        explosion_effect = { 'proj', 'vehicles\\scorpion\\tank shell' },
        crank_duration = 30,
        damage_multiplier = 1.2,
        speed_boost = 1.3
    }
}
----------------------------------------
-- Configuration ends
----------------------------------------

Game.__index = Game
local map

api_version = '1.12.0.0'

local Timer = {}
Timer.__index = Timer

function Timer:new(duration)
    local self = setmetatable({}, Timer)
    self.start_time = nil
    self.duration = duration or 30 -- default to 30 seconds
    return self
end

function Timer:start()
    self.start_time = os.clock()
end

function Timer:stop()
    self.start_time = nil
end

function Timer:isExpired()
    if self.start_time then
        return (os.clock() - self.start_time) >= self.duration
    end
    return false
end

function Timer:getRemainingTime()
    if self.start_time then
        return math.max(0, self.duration - (os.clock() - self.start_time))
    end
    return 0
end

local Player = {}
Player.__index = Player

function Player:new(playerId)
    local self = setmetatable({}, Player)
    self.id = playerId
    self.team = get_var(playerId, '$team')
    self.cranked_timer = nil -- Timer for "cranked" state
    return self
end

function Player:startCranked(duration)
    self.cranked_timer = Timer:new(duration)
    self.cranked_timer:start()
    local speed_boost = Game[map].speed_boost
    execute_command('s ' .. self.id .. ' ' .. speed_boost)
end

function Player:stopCranked()
    self.cranked_timer = nil
end

function Player:isCranked()
    return self.cranked_timer ~= nil
end

function Player:getCrankedTimeLeft()
    return self.cranked_timer and self.cranked_timer:getRemainingTime() or 0
end

function Game:new()
    local self = setmetatable({}, Game)
    self.players = {}
    return self
end

function Game:addPlayer(playerId)
    self.players[playerId] = Player:new(playerId)
end

function Game:removePlayer(playerId)
    self.players[playerId] = nil
end

local function getTag(class, name)
    local tag = lookup_tag(class, name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

local function clearScreen(playerId)
    for _ = 1, 25 do
        rprint(playerId, ' ')
    end
end

local function getXYZ(dyn)
    local x, y, z
    local crouch = read_float(dyn + 0x50C)
    local vehicle = read_dword(dyn + 0x11C)
    local object = get_object_memory(vehicle)
    if (vehicle == 0xFFFFFFFF) then
        x, y, z = read_vector3d(dyn + 0x5c)
    elseif (object ~= 0) then
        x, y, z = read_vector3d(object + 0x5c)
    end
    return x, y, (crouch == 0 and z + 0.65) or (z + 0.35 * crouch)
end

local function validatePlayer(playerId, dynamic_player)
    return player_present(playerId) and player_alive(playerId) and dynamic_player ~= 0
end

function Game:registerCallbacks(register)
    for event, method in pairs({
        EVENT_DIE = 'onDeath',
        EVENT_DAMAGE_APPLICATION = 'onDeath',
        EVENT_TICK = 'onTick',
        EVENT_JOIN = 'addPlayer',
        EVENT_LEAVE = 'removePlayer',
        EVENT_GAME_END = 'onEnd'
    }) do
        if register then
            _G[method] = function(...)
                return self[method](self, ...)
            end
            register_callback(cb[event], method)
        else
            unregister_callback(cb[event])
        end
    end
end

function Game:validateMap()

    -- Check if the map is supported
    if not self[map] then
        cprint("Unsupported map: " .. map, 12)
        return false
    end

    -- Check if the required tag (tank_shell) is available
    local class, name = self[map].explosion_effect[1], self[map].explosion_effect[2]

    self.tank_shell = getTag(class, name)
    if not self.tank_shell then
        cprint("Missing required tag: " .. "'" .. class .. "', '" .. name .. "'", 12)
        return false
    end

    -- If both checks pass, return true
    return true
end

function Game:start()
    if get_var(0, '$gt') ~= 'n/a' then

        map = get_var(0, '$map')
        if not self:validateMap() then
            self:registerCallbacks()
            return
        end

        self:registerCallbacks(true)
        self.players = {}
        for playerId = 1, 16 do
            if player_present(playerId) then
                self:addPlayer(playerId)
            end
        end
    end
end

function Game:onEnd()
    for _, player in pairs(self.players) do
        if player:isCranked() then
            player:stopCranked()
        end
    end
    self.players = {}
end

function Game:onDeath(victim, killer, meta_id, damage)
    victim = tonumber(victim)
    killer = tonumber(killer)

    -- server
    if killer == 0 then
        return
    end

    -- EVENT_DAMAGE_APPLICATION
    if meta_id then
        return true, damage * self[map].damage_multiplier
    end

    -- pvp
    if killer ~= victim then
        local killerPlayer = self.players[killer]
        if killerPlayer then
            killerPlayer:startCranked(self[map].crank_duration) -- start timer for the killer
        end
    end

    local victimPlayer = self.players[victim]
    if victimPlayer then
        victimPlayer:stopCranked() -- Stop timer for the victim
    end
end

function Game:Explode(x, y, z)
    for _ = 1, 10 do
        local payload = spawn_projectile(self.tank_shell, 0, x, y, z)
        local projectile = get_object_memory(payload)
        if (payload and projectile ~= 0) then
            write_float(projectile + 0x68, 0)
            write_float(projectile + 0x6C, 0)
            write_float(projectile + 0x70, -9999)
        end
    end
end

function Game:onTick()
    for playerId, player in pairs(self.players) do
        local dynamic_player = get_dynamic_player(playerId)
        if validatePlayer(playerId, dynamic_player) then
            if player:isCranked() then
                if player.cranked_timer:isExpired() then
                    -- Player's timer expired, trigger explosion
                    local x, y, z = getXYZ(dynamic_player)
                    self:Explode(x, y, z)
                    rprint(playerId, "You exploded! Get a kill faster next time!")
                    player:stopCranked()
                else
                    -- Display remaining time to the player
                    local timeLeft = math.ceil(player:getCrankedTimeLeft())
                    clearScreen(playerId)
                    rprint(playerId, "CRANKED TIME LEFT: " .. timeLeft .. "s")
                end
            end
        end
    end
end

--- Global Game Instance and Callbacks ---
local game

function OnScriptLoad()
    game = Game:new()

    _G['start'] = function()
        game:start()
    end
    register_callback(cb['EVENT_GAME_START'], 'start')

    game:start()
end

function OnScriptUnload()
    -- N/A
end