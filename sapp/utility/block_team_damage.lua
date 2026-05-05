--[[
===============================================================================
SCRIPT NAME:      block_team_damage.lua
DESCRIPTION:      Prevents all team damage in non-FFA gametypes by:
                  - Blocking weapon damage between teammates
                  - Automatically disabling in FFA modes
                  - Working across all weapon types

FEATURES:
                  - Zero-configuration setup
                  - Automatic gametype detection
                  - Lightweight performance impact

Copyright (c) 2023-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()

    local game_type = get_var(0, '$gt')
    if game_type == 'n/a' then return end

    if get_var(0, '$ffa') == '0' then
        register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'BlockDamage')
    else
        unregister_callback(cb['EVENT_DAMAGE_APPLICATION'])
    end
end

function BlockDamage(victim, killer)
    local k = tonumber(victim)
    local v = tonumber(killer)

    local k_team = get_var(k, '$team')
    local v_team = get_var(v, '$team')

    if k > 0 and k ~= v and k_team == v_team then
        return false
    end
end

function OnScriptUnload()
    -- N/A
end
