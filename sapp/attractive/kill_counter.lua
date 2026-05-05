--[[
=====================================================================================
SCRIPT NAME:      kill_counter.lua
DESCRIPTION:      Displays kill count to players after each kill
                  - Shows current kill count in a private message
                  - Customizable message format
                  - Only triggers on valid player kills (no suicides or team kills)
                  - Lightweight with no configuration required

                  Default message format: "Kill Counter: X"
                  Customize by editing the 'output' variable

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local output = "Kill Counter: $kills"

function OnScriptLoad()
    register_callback(cb['EVENT_DIE'], 'OnDeath')
end

function OnDeath(Victim, Killer)

    local killer = tonumber(Killer)
    local victim = tonumber(Victim)

    if (killer > 0 and killer ~= victim) then
        local kills = tonumber(get_var(killer, '$kills'))
        local str = output:gsub('$kills', kills)
        rprint(killer,str)
    end
end

function OnScriptUnload()
    -- N/A
end