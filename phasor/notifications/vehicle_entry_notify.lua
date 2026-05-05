--[[
=====================================================================================
SCRIPT NAME:      vehicle_entry_notify.lua
DESCRIPTION:      Notifies server console when a player enters a vehicle.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local OUTPUT = "$name entered the $seat_name of a $vehicle_name"

-- CONFIG start ---------------------------------------------------------------
local VEHICLES = {
    { "vehicles\\rwarthog\\rwarthog",            "Rocket Warthog",  { [0] = "Driver", [1] = "Passenger", [2] = "Gunner" } },
    { "vehicles\\ghost\\ghost_mp",               "Ghost",           { [0] = "Driver" } },
    { "vehicles\\warthog\\mp_warthog",           "Warthog",         { [0] = "Driver", [1] = "Passenger", [2] = "Gunner" } },
    { "vehicles\\scorpion\\scorpion_mp",         "Scorpion Tank",   { [0] = "Commander", [1] = "Passenger", [2] = "Passenger", [3] = "Passenger", [4] = "Passenger" } },
    { "vehicles\\banshee\\banshee_mp",           "Banshee",         { [0] = "Pilot" } },
    { "vehicles\\c gun turret\\c gun turret_mp", "Covenant Turret", { [0] = "Controller" } },
}
-- CONFIG end -----------------------------------------------------------------

local vehicle_data = {}

local function format(template, args)
    if not args then return template end
    return (template:gsub("%$([%w_]+)", function(key)
        local value = args[key] or args[key:lower()] or args[key:upper()]
        return value ~= nil and tostring(value) or "$" .. key
    end))
end

function OnScriptLoad() end

function OnNewGame()
    vehicle_data = {}
    for _, v in ipairs(VEHICLES) do
        local tag_path, vehicle_name, seats = v[1], v[2], v[3]
        local tag_id = gettagid("vehi", tag_path)
        if tag_id then
            vehicle_data[tag_id] = { name = vehicle_name, seats = seats }
        end
    end
end

function OnVehicleEntry(player, _, seat, mapId)
    local info = vehicle_data[mapId]
    if not info then return end

    local name = getname(player)
    local seat_name = info.seats[seat] or "Seat " .. seat
    local vehicle_name = info.name

    respond("Vehicle Entry: " .. format(OUTPUT, {
        name = name,
        seat_name = seat_name,
        vehicle_name = vehicle_name
    }))
end

function OnScriptUnload() end

function GetRequiredVersion() return 200 end
