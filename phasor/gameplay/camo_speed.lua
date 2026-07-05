--[[
=====================================================================================
SCRIPT NAME:      camo_speed.lua
DESCRIPTION:      Grants a temporary speed boost when a player picks up
                  Active Camouflage (or other configured equipment).

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START -------------------------------------------------------
local CAMO_TAG = "powerups\\active camouflage"
local SPEED_MULTIPLIER = 2                     -- Speed scale while boosted
local SPEED_DURATION = 10                      -- Duration of the boost (seconds)
local NORMAL_SPEED = 1.0                       -- Speed to reset to after boost ends
-- CONFIG END ---------------------------------------------------------

local camo_tag_id

local function apply_speed(player_id)
    local player = getplayer(player_id)
    if not player then return end

    setspeed(player, SPEED_MULTIPLIER)
    registertimer(SPEED_DURATION * 1000, "ResetSpeed", player_id)
end

function ResetSpeed(_, _, player_id)
    local player = getplayer(player_id)
    if player then setspeed(player, NORMAL_SPEED) end
    return false
end

function OnObjectInteraction(player_id, objId, MapID)
    if camo_tag_id[MapID] then apply_speed(player_id) end
end

function OnNewGame()
    local tag = gettagid("eqip", CAMO_TAG)
    if tag then camo_tag_id[tag] = true end
end

function OnScriptLoad() end

function OnScriptUnload() end

function GetRequiredVersion()
    return 200
end
