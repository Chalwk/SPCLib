--[[
=====================================================================================
SCRIPT NAME:      replace_weapon_projectile.lua
DESCRIPTION:      Replaces weapon projectiles with custom projectiles while maintaining
                  original visual effects. Includes damage multiplier configuration.

FEATURES:
                - Seamless projectile replacement without visual glitches
                - Customizable damage multipliers for each projectile
                - Supports all standard Halo weapons and vehicles
                - Easy configuration via the projectiles table

CONFIGURATION:
                - Edit the projectiles table to define replacements
                - Set damage multipliers (1 = normal, max 10)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"
local projectiles = {}

-- Configuration [starts] ------------------------------------------------------
projectiles = {
    --      ORIGINAL TAG                                    REPLACEMENT TAG                             DAMAGE MULTIPLIER (normal is 1, max 10)
    [1] = { "vehicles\\banshee\\banshee bolt", "vehicles\\banshee\\banshee bolt", 1 },
    [2] = { "vehicles\\banshee\\mp_banshee fuel rod", "vehicles\\banshee\\mp_banshee fuel rod", 1 },
    [3] = { "vehicles\\c gun turret\\mp gun turret", "vehicles\\c gun turret\\mp gun turret", 1 },
    [4] = { "vehicles\\ghost\\ghost bolt", "vehicles\\ghost\\ghost bolt", 1 },
    [5] = { "vehicles\\scorpion\\bullet", "vehicles\\scorpion\\bullet", 1 },
    [6] = { "vehicles\\scorpion\\tank shell", "vehicles\\scorpion\\tank shell", 1 },
    [7] = { "vehicles\\warthog\\bullet", "vehicles\\warthog\\bullet", 1 },

    [8] = { "weapons\\assault rifle\\bullet", "weapons\\assault rifle\\bullet", 1 },
    [9] = { "weapons\\flamethrower\\flame", "weapons\\flamethrower\\flame", 1 },
    [10] = { "weapons\\needler\\mp_needle", "weapons\\needler\\mp_needle", 1 },
    [11] = { "weapons\\pistol\\bullet", "weapons\\pistol\\bullet", 1 },
    [12] = { "weapons\\plasma pistol\\bolt", "weapons\\plasma pistol\\bolt", 1 },
    [13] = { "weapons\\plasma rifle\\bolt", "weapons\\plasma rifle\\bolt", 1 },
    [14] = { "weapons\\plasma rifle\\charged bolt", "weapons\\plasma rifle\\charged bolt", 1 },
    [15] = { "weapons\\rocket launcher\\rocket", "weapons\\rocket launcher\\rocket", 1 },
    [16] = { "weapons\\shotgun\\pellet", "weapons\\shotgun\\pellet", 1 },
    [17] = { "weapons\\sniper rifle\\sniper bullet", "weapons\\sniper rifle\\sniper bullet", 1 },
    [18] = { "weapons\\plasma_cannon\\plasma_cannon", "weapons\\plasma_cannon\\plasma_cannon", 1 },

    -- grenades --
    [19] = { "weapons\\frag grenade\\frag grenade", "weapons\\frag grenade\\frag grenade", 1 },
    [20] = { "weapons\\plasma grenade\\plasma grenade", "weapons\\plasma grenade\\plasma grenade", 1 },
    [21] = { "weapons\\frag grenade\\explosion", "weapons\\frag grenade\\explosion", 1 },
    [22] = { "weapons\\plasma grenade\\attached", "weapons\\plasma grenade\\attached", 1 },
    [23] = { "weapons\\plasma grenade\\explosion", "weapons\\plasma grenade\\explosion", 1 }

    -- See example below to lean how to swap the "sniper bullet" for "tank shell":

    ------- Change the following -------
    -- from:  [17] = { "weapons\\sniper rifle\\sniper bullet",        "weapons\\sniper rifle\\sniper bullet"},
    -- to:    [17] = { "weapons\\sniper rifle\\sniper bullet",        "vehicles\\scorpion\\tank shell"},
}
-- Configuration [ends] --------------------------------------------------------

function OnScriptLoad()
    register_callback(cb.EVENT_OBJECT_SPAWN, "OnObjectSpawn")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")
end

local function getTag(a, b)
    local tag = lookup_tag(a, b)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

function OnObjectSpawn(PlayerIndex, MapID)
    if (PlayerIndex) then
        for i = 1, #projectiles do
            local original = projectiles[i][1]
            local replacement = projectiles[i][2]

            if (MapID == getTag("proj", original)) then
                return true, getTag("proj", replacement)
            end
        end
    end
end

function OnDamageApplication(_, CauserIndex, MetaID, Damage)
    if tonumber(CauserIndex) > 0 then
        for i = 1, #projectiles do
            local repl, mul = projectiles[i][2], projectiles[i][3]
            if (MetaID == getTag("jpt!", repl)) then
                return true, Damage * mul
            end
        end
    end
end
