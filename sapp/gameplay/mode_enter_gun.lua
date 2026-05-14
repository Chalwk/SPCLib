--[[
=====================================================================================
SCRIPT NAME:      mode_enter_gun.lua
DESCRIPTION:      Vehicle entry system using weapon targeting
                  - Toggle with: /entergun [on/off] (requires permission level 1)
                  - Enter vehicles by aiming and shooting at them
                  - Supports all standard Halo vehicles
                  - Shows vehicle name confirmation message
                  - Lightweight implementation

                  Supported Vehicles:
                  - Warthog (standard and rocket)
                  - Ghost
                  - Banshee
                  - Scorpion Tank
                  - Gun Turret

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

command = "entergun"
permission_level = 1

vehicles = {}
vehicles[1] = { "vehi", "vehicles\\warthog\\mp_warthog", "Warthog" }
vehicles[2] = { "vehi", "vehicles\\ghost\\ghost_mp", "Ghost" }
vehicles[3] = { "vehi", "vehicles\\rwarthog\\rwarthog", "RocketHog" }
vehicles[4] = { "vehi", "vehicles\\banshee\\banshee_mp", "Banshee" }
vehicles[5] = { "vehi", "vehicles\\scorpion\\scorpion_mp", "Tank" }
vehicles[6] = { "vehi", "vehicles\\c gun turret\\c gun turret_mp", "Turret" }

enter_mode = {}
weapon_status = {}
function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_SPAWN, "OnPlayerSpawn")
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
end

function OnScriptUnload()

end

function OnPlayerSpawn(PlayerIndex)
    enter_mode[PlayerIndex] = false
    weapon_status[PlayerIndex] = 0
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) and player_alive(i) then
            if (enter_mode[i] == true) then
                local player_object = get_dynamic_player(i)
                local playerX, playerY, playerZ = read_float(player_object + 0x230), read_float(player_object + 0x234), read_float(player_object + 0x238)
                local shot_fired
                local couching = read_float(player_object + 0x50C)
                local px, py, pz = read_vector3d(player_object + 0x5c)
                if (couching == 0) then
                    pz = pz + 0.65
                else
                    pz = pz + (0.35 * couching)
                end
                local ignore_player = read_dword(get_player(i) + 0x34)
                local success, a, b, c, target = intersect(px, py, pz, playerX * 1000, playerY * 1000, playerZ * 1000, ignore_player)
                if (success == true and target ~= nil) then
                    local object_id = read_dword(get_object_memory(target))
                    for k, v in pairs(vehicles) do
                        if object_id == TagInfo(tostring(v[1]), tostring(v[2])) then
                            shot_fired = read_float(player_object + 0x490)
                            if (shot_fired ~= weapon_status[i] and shot_fired == 1) then
                                enter_vehicle(target, i, 0)
                                rprint(i, "Entering " .. v[3])
                                break
                            end
                            weapon_status[i] = shot_fired
                        end
                    end
                end
            end
        end
    end
end

function OnServerCommand(PlayerIndex, Command)
    local UnknownCMD = nil
    local t = tokenizestring(Command)
    if t[1] ~= nil then
        if t[1] == string.lower(command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= permission_level then
                if t[2] ~= nil then
                    if t[2] == "on" or t[2] == "1" or t[2] == "true" then
                        enter_mode[PlayerIndex] = true
                        rprint(PlayerIndex, "Enter Gun Mode enabled.")
                        UnknownCMD = false
                    elseif t[2] == "off" or t[2] == "0" or t[2] == "false" then
                        enter_mode[PlayerIndex] = false
                        rprint(PlayerIndex, "Enter Gun Mode disabled.")
                        UnknownCMD = false
                    end
                else
                    rprint(PlayerIndex, "Invalid Syntax")
                    UnknownCMD = false
                end
            else
                rprint(PlayerIndex, "You do not have permission to execute that command!")
                UnknownCMD = false
            end
        end
        return UnknownCMD
    end
end

function TagInfo(obj_type, obj_name)
    local tag_id = lookup_tag(obj_type, obj_name)
    return tag_id ~= 0 and read_dword(tag_id + 0xC) or nil
end

function tokenizestring(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = { };
    i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end
