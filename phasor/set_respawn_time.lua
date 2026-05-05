--[[
=====================================================================================
SCRIPT NAME:      set_respawn_time.lua
DESCRIPTION:      Overrides the default respawn time for every player death.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config:
-- Desired respawn delay in seconds
local RESPAWN_TIME = 1.5

-- 33 = internal tick multiplier (30 ticks = 1 second; 33 is the game's exact factor)
local TICK_SCALE = 33
--

function GetRequiredVersion() return 200 end

function OnScriptLoad() end
function OnScriptUnload() end

function OnPlayerKill(_, victim)
    if not victim then return end

    local player_mem = getplayer(victim)
    if player_mem and player_mem ~= 0 then
        writedword(player_mem + 0x2C, RESPAWN_TIME * TICK_SCALE)
    end
end