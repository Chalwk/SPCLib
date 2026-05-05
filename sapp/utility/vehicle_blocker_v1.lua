--[[
=====================================================================================
SCRIPT NAME:      vehicle_blocker_v1.lua
DESCRIPTION:      Map-based vehicle entry restriction system with configurable settings.

FEATURES:
                  - Per-map vehicle blocking configuration
                  - Customizable restrictions by vehicle type
                  - Seat-specific controls (driver/passenger/gunner)
                  - Automatic vehicle exit enforcement
                  - Custom denial messages
                  - Simple in-script configuration

CONFIGURATION:
                  Modify VehicleSettings() function to customize:
                  - Vehicle class restrictions
                  - Map-specific exceptions
                  - Seat permissions (driver/passenger/gunner)
                  - Exit delay timing (in milliseconds)

SUPPORTED VEHICLES:
                  - Ghost, Scorpion, Warthog, Banshee
                  - Rocket Hog, Turret, and more

Copyright (c) 2016-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"
MapSettings = {}
function OnScriptLoad()
    register_callback(cb['EVENT_VEHICLE_ENTER'], "OnVehicleEntry")
    register_callback(cb['EVENT_GAME_START'], "OnNewGame")
    mapname = get_var(0, "$map")
    VehicleSettings()
end

function OnNewGame(map)
    mapname = get_var(0, "$map")
    VehicleSettings()
end

function OnVehicleEntry(PlayerIndex)
    local player_object = get_dynamic_player(PlayerIndex)
    if (player_object ~= 0) then
        local VehicleObject = get_object_memory(read_dword(player_object + 0x11c))
        local seat = read_word(player_object + 0x2F0)
        for j = 1, #MapSettings[mapname] do
            if MapSettings[mapname] ~= { } and MapSettings[mapname][j] ~= nil then
                if VehicleTagID(VehicleObject) == MapSettings[mapname][j][1] then
                    if seat == 0 then
                        if MapSettings[mapname][j][3] == false then
                            say(PlayerIndex, "Drivers Seat disabled for " .. tostring(MapSettings[mapname][j][2]))
                            timer(tonumber(MapSettings[mapname][j][6]), "exitvehicle", PlayerIndex)
                        end
                    elseif seat == 1 then
                        if MapSettings[mapname][j][4] == false then
                            say(PlayerIndex, "Passengers Seat disabled for " .. tostring(MapSettings[mapname][j][2]))
                            timer(tonumber(MapSettings[mapname][j][6]), "exitvehicle", PlayerIndex)
                        end
                    elseif seat >= 2 then
                        if MapSettings[mapname][j][5] == false then
                            say(PlayerIndex, "Gunners Seat disabled for " .. tostring(MapSettings[mapname][j][2]))
                            timer(tonumber(MapSettings[mapname][j][6]), "exitvehicle", PlayerIndex)
                        end
                    end
                end
            end
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

function exitvehicle(PlayerIndex)
    if player_alive(PlayerIndex) then
        exit_vehicle(PlayerIndex)
    end
end

--[[

DRIVER:     Can they Drive this Vehicle?                Options: true|false
PASSENGER:  Can they be a passenger in this Vehicle?    Options: true|false
GUNNER:     Can they be a gunner in this Vehicle?       Options: true|false
DELAY:      Exit the vehicle after this many seconds.   1000*1.00 = 1 second.

]]

function VehicleSettings()
    MapSettings["bloodgulch"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
    MapSettings["prisoner"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, false, 1000 * 1.30 },
    }
    MapSettings["hangemhigh"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, false, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, false, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["putput"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, false, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["longest"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, false, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["ratrace"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, false, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, false, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["timberland"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, false, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["infinity"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
    MapSettings["wizard"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, false, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["sidewinder"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, false, true, 1000 * 1.30 },
    }
    MapSettings["deathisland"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, false, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
    MapSettings["dangercanyon"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, false, true, 1000 * 1.30 },
    }
    MapSettings["icefields"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", true, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["beavercreek"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["boardingaction"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", true, true, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, true, false, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, false, true, 1000 * 1.30 },
    }
    MapSettings["carousel"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, false, true, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", false, false, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", true, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, false, 1000 * 1.30 },
    }
    MapSettings["gephyrophobia"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER          PASSENGER      GUNNER         DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", false, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", true, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", false, false, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, true, true, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, false, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", false, true, true, 1000 * 1.30 },
    }
    MapSettings["damnation"] = {
        --   VEHICLE ID                                     VEHICLE NAME        DRIVER         PASSENGER      GUNNER          DELAY
        { "vehicles\\ghost\\ghost_mp", "Ghost", true, true, false, 1000 * 1.15 },
        { "vehicles\\scorpion\\scorpion_mp", "Tank", false, false, true, 1000 * 2.20 },
        { "vehicles\\warthog\\mp_warthog", "Warthog", true, true, true, 1000 * 1.65 },
        { "vehicles\\banshee\\banshee_mp", "Banshee", true, false, false, 1000 * 1.00 },
        { "vehicles\\rwarthog\\rwarthog", "Rocket-Hog", false, true, true, 1000 * 1.65 },
        { "vehicles\\c gun turret\\c gun turret_mp", "Turret", true, true, true, 1000 * 1.30 },
    }
end