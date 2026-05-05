--[[
=====================================================================================
SCRIPT NAME:      random_grenades.lua
DESCRIPTION:      Randomized grenade spawn system with map-specific customization

FEATURES:
                  - Automatic grenade assignment on player spawn
                  - Two operational modes:
                    * Random quantity within defined ranges
                    * Manual map-specific presets
                  - Independent control for frag/plasma grenades
                  - Supports all standard Halo maps

CONFIGURATION:
                  Mode Selection:
                  random_grenades.FRAGS = true/false
                  random_grenades.PLASMAS = true/false

USAGE:
                  Simply load the script - no commands required

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration --

local random_grenades = {
    FRAGS = true, -- If false, uses manual configuration
    PLASMAS = true   -- If false, uses manual configuration
}

-- Manual Configuration --
local manual_grenades = {
    ['beavercreek'] = { frags = 3, plasmas = 1 },
    ['bloodgulch'] = { frags = 4, plasmas = 2 },
    ['boardingaction'] = { frags = 1, plasmas = 3 },
    ['carousel'] = { frags = 3, plasmas = 3 },
    ['dangercanyon'] = { frags = 4, plasmas = 4 },
    ['deathisland'] = { frags = 1, plasmas = 1 },
    ['gephyrophobia'] = { frags = 3, plasmas = 3 },
    ['icefields'] = { frags = 1, plasmas = 1 },
    ['infinity'] = { frags = 2, plasmas = 4 },
    ['sidewinder'] = { frags = 3, plasmas = 2 },
    ['timberland'] = { frags = 2, plasmas = 4 },
    ['hangemhigh'] = { frags = 3, plasmas = 3 },
    ['ratrace'] = { frags = 3, plasmas = 2 },
    ['damnation'] = { frags = 1, plasmas = 3 },
    ['putput'] = { frags = 4, plasmas = 1 },
    ['prisoner'] = { frags = 2, plasmas = 1 },
    ['wizard'] = { frags = 1, plasmas = 2 }
}

-- Configuration End --

local map

function OnScriptLoad()
    register_callback(cb['EVENT_SPAWN'], "OnPlayerSpawn")
    register_callback(cb['EVENT_GAME_START'], "OnStart")
end

function OnStart()
    if get_var(0, "$gt") ~= "n/a" then
        map = get_var(0, "$map")
    end
end

local function getGrenades(type)
    if random_grenades[type] then
        return math.random(_G["MIN_" .. type], _G["MAX_" .. type])
    end
    return manual_grenades[type:lower()][map] or 0
end

function OnPlayerSpawn(PlayerIndex)
    local dyn = get_dynamic_player(PlayerIndex)
    if dyn == 0 then
        return
    end

    local frags, plasmas = getGrenades("FRAGS"), getGrenades("PLASMAS")

    write_word(dyn + 0x31E, frags)
    write_word(dyn + 0x31F, plasmas)
end

function OnScriptUnload()

end
