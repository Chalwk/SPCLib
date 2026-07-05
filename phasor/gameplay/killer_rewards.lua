--[[
=====================================================================================
SCRIPT NAME:      killer_rewards.lua
DESCRIPTION:      Rewards players with random equipment when they reach a killstreak.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ------------------------------------------------
local EQUIPMENT = {
    "powerups\\active camouflage", "powerups\\health pack", "powerups\\over shield",
    "powerups\\assault rifle ammo\\assault rifle ammo", "powerups\\needler ammo\\needler ammo",
    "powerups\\pistol ammo\\pistol ammo", "powerups\\rocket launcher ammo\\rocket launcher ammo",
    "powerups\\shotgun ammo\\shotgun ammo", "powerups\\sniper rifle ammo\\sniper rifle ammo",
    "powerups\\flamethrower ammo\\flamethrower ammo", "powerups\\double speed", "powerups\\full-spectrum vision"
}

-- Player killstreaks that trigger a reward
local REWARD_KILLS = {
    [10] = true,
    [20] = true,
    [30] = true,
    [40] = true,
    [50] = true,
    [60] = true,
    [70] = true,
    [80] = true,
    [90] = true
}

local MIN_REWARD = 100 -- 100+ also triggers

-- CONFIG END --------------------------------------------------

local tags = {}

function GetRequiredVersion()
    return 200
end

function OnScriptLoad() end

function OnScriptUnload() end

local function get_multi_kills(killer)
    local player = getplayer(killer)
    if not player then return nil end
    return readword(player + 0x98)
end

local function get_pos(id)
    local obj = getplayerobjectid(id)
    if not obj then return end
    return getobjectcoords(obj)
end

local function drop_powerup(x, y, z)
    local tag = EQUIPMENT[getrandomnumber(1, #EQUIPMENT)]
    createobject(tag, 0, 10, false, x, y, z + 0.5)
end

local function reward_killer(id)
    local x, y, z = get_pos(id)
    if not x then return end

    drop_powerup(x, y, z)
end

function OnPlayerKill(killer, _, mode)
    if #tags == 0 or mode ~= 4 then return end

    local kills = get_multi_kills(killer)
    if not kills then return end

    if REWARD_KILLS[kills] or kills >= MIN_REWARD then
        reward_killer(killer)
    end
end

function OnNewGame()
    tags = {}
    for i = 1, #EQUIPMENT do
        local tag = gettagid("eqip", EQUIPMENT[i])
        if tag then tags[i] = tag end
    end
end
