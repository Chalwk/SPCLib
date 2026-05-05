--[[
=====================================================================================
SCRIPT NAME:      set_running_speed.lua
DESCRIPTION:      Sets a custom movement speed for all players on spawn.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config:
-- Default movement speed is 1.0
local RUN_SPEED = 1.08
--

function GetRequiredVersion() return 200 end

function OnScriptLoad() end

function OnScriptUnload() end

function OnPlayerSpawnEnd(player_id, _)
    local player = getplayer(player_id)
    if player then
        setspeed(player, RUN_SPEED)
    end
end