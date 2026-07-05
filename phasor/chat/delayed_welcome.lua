--[[
=====================================================================================
SCRIPT NAME:      delayed_welcome.lua
DESCRIPTION:      Displays a welcome message to joining players after a short delay.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config start ---------------------------------
local WELCOME_MESSAGE = "Welcome Message Here"
local JOIN_DELAY = 10
-- Config end -----------------------------------

function Welcome(id)
    if getplayer(id) then privatesay(id, WELCOME_MESSAGE) end
    return false
end

function GetRequiredVersion()
    return 200
end

function OnScriptLoad() end

function OnScriptUnload() end

function OnPlayerJoin(player)
    registertimer(1000 * JOIN_DELAY, "Welcome", player)
end
