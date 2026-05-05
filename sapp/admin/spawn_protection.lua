--[[
=====================================================================================
SCRIPT NAME:      spawn_protection.lua
DESCRIPTION:      Provides temporary invulnerability to newly spawned players.
                  Prevents protected players from taking damage (configurable).

FEATURES:
                  - Configurable protection duration (default: 5 seconds)
                  - Toggle whether protected players can deal damage
                  - Visual feedback when protection is active
                  - Automatic protection on spawn

CONFIGURATION:
                  grace_period = 5       -- Protection duration in seconds
                  inflict_damage = true  -- Whether protected players can deal damage

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local SpawnProtection = {

    -- Time (in seconds) that players cannot be harmed:
    -- Default: 5
    --
    grace_period = 5,

    -- Should the player be able to inflict damage on others while under protection?
    -- Default: true
    --
    inflict_damage = true
}

local players = { }
local time = os.time

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], 'OnTick')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDamage')
    OnStart()
end

function OnStart()
    if (get_var(0, '$gt') ~= 'n/a') then
        players = { }
        for i = 1, 16 do
            if player_present(i) then
                OnJoin(i)
            end
        end
    end
end

function SpawnProtection:NewPlayer(o)

    setmetatable(o, { __index = self })
    self.__index = self

    return o
end

function SpawnProtection:Protect()

    self.protected = true
    self.start = time
    self.finish = time() + self.grace_period

    rprint(self.id, 'You are invulnerable to damage for ' .. self.grace_period .. ' seconds')
end

function OnTick()
    for _,v in pairs(players) do
        if (v.protected and v.start() >= v.finish) then
            v.protected = false
        end
    end
end

function OnJoin(Ply)
    players[Ply] = SpawnProtection:NewPlayer({ id = Ply })
end

function OnQuit(Ply)
    players[Ply] = nil
end

function OnSpawn(Ply)
    players[Ply]:Protect()
end

function OnDamage(V, K)

    local victim = tonumber(V)
    local killer = tonumber(K)

    local v = players[victim]
    local k = players[killer]

    local pvp = (killer > 0 and killer ~= victim)

    if (pvp and v and v.protected) then
        return false
    elseif (pvp and k and k.protected) then
        return k.inflict_damage
    end

    return true
end

function OnScriptUnload()
    -- N/A
end