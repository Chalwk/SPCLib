--[[
===========================================================================
SCRIPT NAME:      drive_as_gunner.lua
DESCRIPTION:      Allows players to drive as gunners in specified vehicles.

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===========================================================================
]]

-- CONFIG START -------------------------------
api_version = "1.12.0.0"

local VEHICLES = {
    ["vehicles\\rwarthog\\rwarthog"] = true,
    ["vehicles\\warthog\\mp_warthog"] = true
}
-- CONFIG END -------------------------------

function OnScriptLoad()
    register_callback(cb.EVENT_GAME_START, 'OnStart')
    register_callback(cb.EVENT_VEHICLE_ENTER, 'OnVehicleEnter')

    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end
    for path in pairs(VEHICLES) do
        local tag = lookup_tag('vehi', path)
        if tag ~= 0 then VEHICLES[read_dword(tag + 0xC)] = true end
    end
end

function OnVehicleEnter(player, seat)
    if seat ~= '2' then return end

    local dyn = get_dynamic_player(player)
    if dyn == 0 then return end

    local vehicle_id = read_dword(dyn + 0x11C)
    local vehicle = get_object_memory(vehicle_id)

    if vehicle == 0 then return end
    if not VEHICLES[read_dword(vehicle)] then return end

    if read_dword(vehicle + 0x324) == 0xFFFFFFFF then
        enter_vehicle(vehicle_id, player, 0)
        enter_vehicle(vehicle_id, player, 2)
    end
end

function OnScriptUnload() end
