--[[
=====================================================================================
SCRIPT NAME:      headshot_blocker.lua
DESCRIPTION:      Completely prevents headshot damage in multiplayer

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "BlockHeadshots")
end

function BlockHeadshots(victim, killer, _, _, hit_string, _)
    killer, victim = tonumber(killer), tonumber(victim)
    if killer > 0 and killer ~= victim and hit_string == "head" then
        return false
    end
end

function OnScriptUnload() end
