--[[
===============================================================================
SCRIPT NAME:      infinite_ammo.lua
DESCRIPTION:      Continuously grants all players unlimited ammunition.

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

function OnScriptLoad()
    timer(500, "InfiniteAmmo")
end

function InfiniteAmmo()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            local dyn_player = get_dynamic_player(i)
            if dyn_player == 0 then goto continue end

            for slot = 0, 3 do
                local weapon = read_dword(dyn_player + 0x2F8 + slot * 4)
                local object_id = get_object_memory(weapon)
                if object_id == 0 then goto continue end
                write_short(object_id + 0x2B6, 0x7CFF)
                write_short(object_id + 0x2B8, 0x7CFF)
                sync_ammo(weapon)
            end

            ::continue::
        end
    end
    return true
end

function OnScriptUnload() end
