--[[
=====================================================================================
SCRIPT NAME:      health_regeneration.lua
DESCRIPTION:      Automatic health regeneration system
                  - Gradually restores player health over time
                  - Dynamic regeneration rate (faster when more injured)
                  - Caps at full health (1.0)
                  - Only activates when health is below 100%
                  - Simple configuration (adjust HEALTH_INCREMENT)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local HEALTH_INCREMENT = 0.2

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb.EVENT_JOIN, 'OnJoin')
end

function OnJoin(id)
    timer(1000, 'RegenHealth', id)
end

function RegenHealth(id)
    local dyn = get_dynamic_player(id)
    if (dyn ~= 0 and player_alive(id)) then
        local health = read_float(dyn + 0xE0)
        if (health < 1) then
            -- Dynamic regeneration rate
            local increment = HEALTH_INCREMENT * (1 - health)
            local new_health = math.min(health + increment, 1)

            write_float(dyn + 0xE0, new_health)
        end
    end
    return true
end

function OnScriptUnload()
    -- N/A
end
