--[[
=====================================================================================
SCRIPT NAME:      vehicle_blocker_v2.lua
DESCRIPTION:      Enhanced vehicle restriction system with advanced features.

KEY IMPROVEMENTS FROM V1:
                  - More granular vehicle control
                  - Player teleportation system
                  - Improved configuration structure
                  - Better error handling
                  - Enhanced player tracking

FEATURES:
                  - Map-specific vehicle restrictions
                  - Seat-based permission system
                  - Vehicle respawn system
                  - Player position restoration
                  - Customizable denial messages

CONFIGURATION:
                  Modify VehicleSettings() function to customize:
                  - Vehicle class restrictions
                  - Map-specific exceptions
                  - Seat permissions (driver/passenger/gunner)
                  - Teleport behavior settings

SUPPORTED VEHICLES:
                  - All standard Halo vehicles
                  - Custom vehicle support

TODO: rewrite this garbage

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"
players = { }

coordiantes = { }
for i = 1, 16 do
    coordiantes[i] = { }
end

map_settings = {}

function OnScriptLoad()
    register_callback(cb['EVENT_VEHICLE_ENTER'], "OnVehicleEntry")
    register_callback(cb['EVENT_JOIN'], "OnPlayerJoin")
    register_callback(cb['EVENT_LEAVE'], "OnPlayerLeave")
    register_callback(cb['EVENT_GAME_START'], "OnGameStart")
    register_callback(cb['EVENT_GAME_END'], "OnGameEnd")
    register_callback(cb['EVENT_PRESPAWN'], "OnPlayerPrespawn")
    mapname = get_var(0, "$map")
    VehicleSettings()
end

function OnScriptUnload()

end

function OnGameStart(map)
    mapname = get_var(0, "$map")
    VehicleSettings()
end

function OnGameEnd()
    for i = 1, 16 do
        if player_present(i) then
            players[get_var(i, "$name")].teleport_trigger = false
        end
    end
end

function OnPlayerJoin(PlayerIndex)
    players[get_var(PlayerIndex, "$name")] = { }
    players[get_var(PlayerIndex, "$name")].teleport_trigger = false
end

function OnPlayerLeave(PlayerIndex)
    players[get_var(PlayerIndex, "$name")].teleport_trigger = false
end

function OnVehicleEntry(PlayerIndex)
    local player_object = get_dynamic_player(PlayerIndex)
    if (player_object ~= 0) then
        local VehicleObject = get_object_memory(read_dword(player_object + 0x11c))
        local seat = read_word(player_object + 0x2F0)
        for i = 1, #map_settings[mapname] do
            if map_settings[mapname] ~= { } and map_settings[mapname][i] ~= nil then
                if VehicleTagID(VehicleObject) == map_settings[mapname][i][1] then
                    if seat == 0 then
                        if map_settings[mapname][i][3] == false then
                            rprint(PlayerIndex, "Drivers Seat disabled for " .. tostring(map_settings[mapname][i][2]))
                            handlePlayerVehicle(PlayerIndex)
                        end
                    elseif seat == 1 then
                        if map_settings[mapname][i][4] == false then
                            rprint(PlayerIndex, "Passengers Seat disabled for " .. tostring(map_settings[mapname][i][2]))
                            handlePlayerVehicle(PlayerIndex)
                        end
                    elseif seat >= 2 then
                        if map_settings[mapname][i][5] == false then
                            rprint(PlayerIndex, "Gunners Seat disabled for " .. tostring(map_settings[mapname][i][2]))
                            handlePlayerVehicle(PlayerIndex)
                        end
                    end
                end
            end
        end
    end
end

function handlePlayerVehicle(PlayerIndex)
    local player_object = get_dynamic_player(PlayerIndex)
    if (player_object ~= 0) then
        local current_vehicle_id = read_dword(player_object + 0x11C)
        local vehicle_object = get_object_memory(read_dword(player_object + 0x11C))
        if (vehicle_object ~= 0 and vehicle_object ~= nil) then
            local vX, vY, vZ = read_vector3d(vehicle_object + 0x5C)
            coordiantes[PlayerIndex][1] = vX
            coordiantes[PlayerIndex][2] = vY + 2
            coordiantes[PlayerIndex][3] = vZ + 0.5
            local object_name = read_string(read_dword(read_word(vehicle_object) * 32 + 0x40440038))
            destroy_object(read_dword(get_player(PlayerIndex) + 0x34))
            destroy_object(current_vehicle_id)
            spawn_object("vehi", tostring(object_name), vX, vY, vZ + 0.5)
            players[get_var(PlayerIndex, "$name")].teleport_trigger = true
        end
    end
end

function VehicleTagID(VehicleObject)
    if VehicleObject ~= nil and VehicleObject ~= 0 then
        return read_string(read_dword(read_word(VehicleObject) * 32 + 0x40440038))
    else
        return ""
    end
end

function OnPlayerPrespawn(VictimIndex)
    local victim = tonumber(VictimIndex)
    if (players[get_var(VictimIndex, "$name")].teleport_trigger == true) then
        players[get_var(VictimIndex, "$name")].teleport_trigger = false
        if VictimIndex then
            if coordiantes[victim][1] ~= nil then
                write_vector3d(get_dynamic_player(victim) + 0x5C, coordiantes[victim][1], coordiantes[victim][2], coordiantes[victim][3])
            end
        end
    end
    for i = 1, 3 do
        coordiantes[victim][i] = nil
    end
end

--[[

DRIVER:     Can they Drive this Vehicle?                Options: true|false
PASSENGER:  Can they be a passenger in this Vehicle?    Options: true|false
GUNNER:     Can they be a gunner in this Vehicle?       Options: true|false
DELAY:      Exit the vehicle after this many seconds.   1000*1.00 = 1 second.

]]

function VehicleSettings()
    map_settings["bloodgulch"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
    map_settings["prisoner"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, false, 1000 * 1.30 },
    }
    map_settings["hangemhigh"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, false, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, false, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["putput"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, false, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["longest"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, false, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["ratrace"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, false, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, false, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["timberland"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, false, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["infinity"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
    map_settings["wizard"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, false, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["sidewinder"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, false, true, 1000 * 1.30 },
    }
    map_settings["deathisland"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, false, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
    map_settings["dangercanyon"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, false, true, 1000 * 1.30 },
    }
    map_settings["icefields"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", true, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["beavercreek"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["boardingaction"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", true, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, false, true, 1000 * 1.30 },
    }
    map_settings["carousel"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, false, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, false, 1000 * 1.30 },
    }
    map_settings["gephyrophobia"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    map_settings["damnation"] = {
        --   VEHICLE ID | VEHICLE NAME | DRIVER | PASSENGER | GUNNER | DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", true, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, false, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
end
