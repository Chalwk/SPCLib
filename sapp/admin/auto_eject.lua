--[[
=====================================================================================
SCRIPT NAME:      auto_eject.lua
DESCRIPTION:      Prevents players from entering vehicles.

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

function CheckVehicles()
    for i = 1, 16 do
        if player_alive(i) then
            local dyn = get_dynamic_player(i)
            if dyn ~= 0 and read_dword(dyn + 0x11C) ~= 0xFFFFFFFF then
                exit_vehicle(i)
            end
        end
    end
    return true
end

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    OnStart() -- in case script is loaded mid-game
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    timer(1000, "CheckVehicles")
end

function OnScriptUnload() end
