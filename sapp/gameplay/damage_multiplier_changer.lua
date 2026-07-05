--[[
===============================================================================
SCRIPT NAME:      damage_multiplier_changer.lua
DESCRIPTION:      Customizes weapon and damage effects with:
                  - Configurable damage multipliers
                  - Support for all weapon types
                  - Vehicle damage adjustments

FEATURES:
                  - Fine-tuned damage control
                  - Melee, projectile and explosion modifiers
                  - Vehicle weapon customization

CONFIGURATION:    Edit the multipliers table to:
                  - Adjust damage values (0-9999)
                  - Add new weapon tags
                  - Modify existing entries
                  - 1 = normal damage, <1 = reduced, >1 = increased

Copyright (c) 2019 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

local multipliers = {

    -- Format:
    -- [TAG NAME] = DAMAGE MULTIPLIER (0-9999) (1 = normal damage)

    -- WEAPONS:
    ["weapons\\assault rifle\\melee"] = 4,
    ["weapons\\ball\\melee"] = 4,
    ["weapons\\flag\\melee"] = 4,
    ["weapons\\flamethrower\\melee"] = 4,
    ["weapons\\needler\\melee"] = 4,
    ["weapons\\pistol\\melee"] = 1,
    ["weapons\\plasma pistol\\melee"] = 4,
    ["weapons\\plasma rifle\\melee"] = 3,
    ["weapons\\rocket launcher\\melee"] = 1,
    ["weapons\\shotgun\\melee"] = 2,
    ["weapons\\sniper rifle\\melee"] = 2,
    ["weapons\\plasma_cannon\\effects\\plasma_cannon_melee"] = 2,

    -- GRENADES:
    ["weapons\\frag grenade\\explosion"] = 2,
    ["weapons\\plasma grenade\\explosion"] = 2,
    ["weapons\\plasma grenade\\attached"] = 10,

    -- VEHICLES:
    ["vehicles\\ghost\\ghost bolt"] = 1.015,
    ["vehicles\\scorpion\\bullet"] = 1.020,
    ["vehicles\\warthog\\bullet"] = 1.025,
    ["vehicles\\c gun turret\\mp bolt"] = 1.030,
    ["vehicles\\banshee\\banshee bolt"] = 1.035,
    ["vehicles\\scorpion\\shell explosion"] = 1.040,
    ["vehicles\\banshee\\mp_fuel rod explosion"] = 1.045,

    -- BULLET PROJECTILES:
    ["weapons\\pistol\\bullet"] = 1.00,
    ["weapons\\plasma rifle\\bolt"] = 1.50,
    ["weapons\\shotgun\\pellet"] = 1.20,
    ["weapons\\plasma pistol\\bolt"] = 1.50,
    ["weapons\\needler\\explosion"] = 2.00,
    ["weapons\\assault rifle\\bullet"] = 2.00,
    ["weapons\\needler\\impact damage"] = 1.10,
    ["weapons\\flamethrower\\explosion"] = 2.00,
    ["weapons\\sniper rifle\\sniper bullet"] = 4.00,
    ["weapons\\rocket launcher\\explosion"] = 5.00,
    ["weapons\\needler\\detonation damage"] = 2.00,
    ["weapons\\plasma rifle\\charged bolt"] = 3.00,
    ["weapons\\plasma_cannon\\effects\\plasma_cannon_explosion"] = 2.50,

    -- VEHICLE COLLISION & FALL DAMAGE:
    ["globals\\vehicle_collision"] = 1,
    ["globals\\falling"] = 1,
    ["globals\\distance"] = 1,

    -- repeat the structure to add custom tags:
    ['tag name here'] = 0
}

local meta_ids = {}

function OnScriptLoad()
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamage")
    register_callback(cb.EVENT_GAME_START, "OnStart")

    OnStart()
end

local function getTag(type, name)
    local tag = lookup_tag(type, name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

-- Function to initialize the meta_ids table with multipliers
function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        meta_ids = {}

        for tagName, multiplier in pairs(multipliers) do
            -- Get the tag ID
            local metaId = getTag('jpt!', tagName)

            -- Add the tag ID and its associated multiplier to the meta_ids table
            meta_ids[metaId or ''] = metaId and multiplier
        end
    end
end

function OnDamage(Victim, Killer, MetaID, Damage)
    local victim = tonumber(Victim)
    local killer = tonumber(Killer)

    if (killer > 0 and victim ~= killer) then
        local mult = meta_ids[MetaID]
        return true, (mult and Damage ^ mult) -- Apply the damage multiplier exponentially
    end
end
