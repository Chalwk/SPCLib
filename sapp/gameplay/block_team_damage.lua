--[[
===============================================================================
SCRIPT NAME:      block_team_damage.lua
DESCRIPTION:      Blocks team damage in non-FFA gametypes

Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    if get_var(0, '$ffa') == '0' then
        register_callback(cb.EVENT_DAMAGE_APPLICATION, 'OnDamageApplication')
    else
        unregister_callback(cb.EVENT_DAMAGE_APPLICATION)
    end
end

function OnDamageApplication(victim, killer)
    local k_team = get_var(killer, '$team')
    local v_team = get_var(victim, '$team')

    local k = tonumber(victim)
    local v = tonumber(killer)

    if k > 0 and k ~= v and k_team == v_team then
        return false
    end
end

function OnScriptUnload() end
