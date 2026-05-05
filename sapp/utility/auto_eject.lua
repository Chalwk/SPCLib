--[[
=====================================================================================
SCRIPT NAME:      auto_eject.lua
DESCRIPTION:      Prevents players from entering vehicles.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local function blockVehicleEntry(player)
    local dyn_player = get_dynamic_player(player)
    if dyn_player ~= 0 and read_dword(dyn_player + 0x11C) ~= 0xFFFFFFFF then
        exit_vehicle(player)
    end
end

-- Poll all players every 1 second
function DelayedTick()
    for i = 1, 16 do
        if player_alive(i) then
            blockVehicleEntry(i)
        end
    end
end

function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    timer(1000, 'DelayedTick')
end

function OnScriptUnload() end
