--[[
=====================================================================================
SCRIPT NAME:      vehicle_blocker.lua
DESCRIPTION:      Blocks players from entering vehicles based on team configuration.

                  Permissions are specified per vehicle as boolean maps:
                  [0] = Red team,  [1] = Blue team,  true = allowed, false = blocked.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START -----------------------------------------
local block_message = "You're not allowed to use this vehicle"

-- Format: vehicle tag name => { [0] = Red allowed?, [1] = Blue allowed? }
local vehicle_tags = {
    ["vehicles\\ghost\\ghost_mp"] = { [0] = true, [1] = true },
    ["vehicles\\warthog\\mp_warthog"] = { [0] = true, [1] = true },
    ["vehicles\\scorpion\\scorpion_mp"] = { [0] = true, [1] = true },
    ["vehicles\\banshee\\banshee_mp"] = { [0] = true, [1] = true },
    ["vehicles\\c gun turret\\c gun turret_mp"] = { [0] = true, [1] = true },
    ["vehicles\\rwarthog\\rwarthog"] = { [0] = true, [1] = true },
}
-- CONFIG END -------------------------------------------

local allowed_vehicles = {}

local function cache_vehicle_tags()
    allowed_vehicles = {}
    for tag_str, perms in pairs(vehicle_tags) do
        local tag_id = gettagid("vehi", tag_str)
        if tag_id then
            allowed_vehicles[tag_id] = {
                [0] = perms[0] == true,
                [1] = perms[1] == true
            }
        end
    end
end

function OnScriptLoad() cache_vehicle_tags() end

function OnNewGame() cache_vehicle_tags() end

function OnVehicleEntry(player, _, _, map_id)
    local perms = allowed_vehicles[map_id]
    if not perms then return true end

    if not perms[getteam(player)] then
        privatesay(player, block_message)
        return false
    end
    return true
end

function OnScriptUnload() end

function GetRequiredVersion() return 200 end
