--[[
=====================================================================================
SCRIPT NAME:      super_jump.lua
DESCRIPTION:      Grants players enhanced jumping abilities with configurable height
                  and cooldown settings. Toggleable via chat command.

FEATURES:
                  - Configurable jump height (default: 3 world units)
                  - Toggleable super jump with /superjump command
                  - Cooldown system between jumps
                  - Vehicle detection (disabled in vehicles)
                  - Permission level requirement
                  - Player feedback messages

CONFIGURATION:
                  - jump_height:          Vertical boost amount (world units)
                  - min_privilege_level:  Required admin level (-1 = all players)
                  - cooldown_duration:    Seconds between jumps
                  - base_command:         Chat command name
                  - Customize all feedback messages

USAGE:
                  1. Type "/superjump on" to activate
                  2. Press jump key for super jump
                  3. Type "/superjump off" to deactivate

TECHNICAL NOTES:
                  - 1 world unit ≈ 10 feet (3.048 meters)
                  - Cooldown timer resets on spawn
                  - Works in all game modes
                  - No effect while in vehicles

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Configuration [starts]
jump_height = 3

min_privilege_level = -1
cooldown_duration = 5

base_command = "superjump"

superjump_activated = "Super Jump Activated!"
superjump_deactivated = "Super Jump Deactivated!"

superjump_already_on = "Super Jump already on!"
superjump_already_off = "Super Jump already off!"

insufficient_permission = "Insufficient Permission!"
environment_error = "This command can only be executed by a player!"

cooldown_message = "Please wait %seconds% seconds before jumping again"
-- Configuration [ends] -------------------------------------

jump_status = {}
jumping_state = {}
cooldown_bool = { }
players = { }
function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")

    register_callback(cb.EVENT_SPAWN, "OnPlayerSpawn")
    register_callback(cb.EVENT_JOIN, "OnPlayerConnect")
    register_callback(cb.EVENT_LEAVE, "OnPlayerDisconnect")

    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_GAME_START, "OnNewGame")

    for i = 1, 16 do
        if player_present(i) then
            jump_status[i] = false
            cooldown_bool[i] = false
            players[get_var(i, "$n")].cooldown = 0
        end
    end
end

function OnScriptUnload()
    jump_status = { }
    jumping_state = { }
    cooldown_bool = { }
end

function OnNewGame()
    for i = 1, 16 do
        if player_present(i) then
            jump_status[i] = false
            cooldown_bool[i] = false
            players[get_var(i, "$n")].cooldown = 0
        end
    end
end

function OnGameEnd()
    for i = 1, 16 do
        if player_present(i) then
            jump_status[i] = false
            cooldown_bool[i] = false
            players[get_var(i, "$n")].cooldown = 0
        end
    end
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) then
            local player_object = get_dynamic_player(i)
            if (player_object ~= 0) then
                if (jump_status[i] == true) then
                    if not vehicleCheck(i) then

                        local jumping = read_bit(player_object + 0x208, 1)
                        if (jumping ~= jumping_state[i] and jumping == 1 and cooldown_bool[i] == false) then
                            cooldown_bool[i] = true
                            superJump(player_object)
                        end
                        jumping_state[i] = jumping

                        if (cooldown_bool[i] == true) then
                            players[get_var(i, "$n")].cooldown = players[get_var(i, "$n")].cooldown + 0.030
                            local minutes, seconds = secondsToTime(players[get_var(i, "$n")].cooldown, 2)
                            if (jumping == 1) then
                                if (players[get_var(i, "$n")].cooldown < math.floor(cooldown_duration)) then
                                    cls(i)
                                    local time_remaining = cooldown_duration - math.floor(seconds)
                                    local message_format = string.gsub(cooldown_message, "%%seconds%%", time_remaining)
                                    rprint(i, message_format)
                                end
                            end
                        end

                        if players[get_var(i, "$n")].cooldown >= math.floor(cooldown_duration) then
                            cooldown_bool[i] = false
                            players[get_var(i, "$n")].cooldown = 0
                        end
                    end
                end
            end
        end
    end
end

function secondsToTime(seconds, places)
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    if places == 2 then
        return minutes, seconds
    end
end

function OnPlayerConnect(PlayerIndex)
    jump_status[PlayerIndex] = false
    cooldown_bool[PlayerIndex] = false

    players[get_var(PlayerIndex, "$n")] = { }
    players[get_var(PlayerIndex, "$n")].cooldown = 0
end

function OnPlayerDisconnect(PlayerIndex)
    jump_status[PlayerIndex] = false
    cooldown_bool[PlayerIndex] = false

    players[get_var(PlayerIndex, "$n")].cooldown = 0
end

function OnPlayerSpawn(PlayerIndex)
    jumping_state[PlayerIndex] = 0
    cooldown_bool[PlayerIndex] = false

    players[get_var(PlayerIndex, "$n")].cooldown = 0
end

function OnServerCommand(PlayerIndex, Command, Environment, Password)
    local t = tokenizeString(Command)
    if (Environment ~= 0) then
        if (t[1] == base_command) then
            if hasPermission(PlayerIndex) then
                if t[2] ~= nil then
                    if t[2] == "on" then
                        if jump_status[PlayerIndex] == false then
                            rprint(PlayerIndex, superjump_activated)
                            jump_status[PlayerIndex] = true
                        else
                            rprint(PlayerIndex, superjump_already_on)
                        end
                    elseif t[2] == "off" then
                        if jump_status[PlayerIndex] == true then
                            rprint(PlayerIndex, superjump_deactivated)
                            jump_status[PlayerIndex] = false
                        else
                            rprint(PlayerIndex, superjump_already_off)
                        end
                    else
                        rprint(PlayerIndex, "Invalid Syntax. Usage: /" .. base_command .. " on|off")
                    end
                else
                    rprint(PlayerIndex, "Invalid Syntax. Usage: /" .. base_command .. " on|off")
                end
            else
                rprint(PlayerIndex, insufficient_permission)
            end
            return false
        end
    else
        cprint(environment_error, 10)
    end
end

function superJump(player_object)
    local x, y, z = read_vector3d(player_object + 0x5C)
    write_vector3d(player_object + 0x5C, x, y, z + jump_height)
end

function hasPermission(PlayerIndex)
    if (tonumber(get_var(PlayerIndex, "$lvl"))) >= min_privilege_level then
        return true
    else
        return false
    end
end

function vehicleCheck(PlayerIndex)
    local player_object = get_dynamic_player(PlayerIndex)
    if (player_object ~= 0) then
        local VehicleID = read_dword(player_object + 0x11C)
        if VehicleID == 0xFFFFFFFF then
            return false
        else
            return true
        end
    else
        return false
    end
end

function tokenizeString(inputString, Separator)
    if Separator == nil then
        Separator = "%s"
    end
    local t = { };
    i = 1
    for str in string.gmatch(inputString, '([^' .. Separator .. ']+)') do
        t[i] = str
        i = i + 1
    end
    return t
end

function cls(PlayerIndex)
    for i = 1, 25 do
        rprint(PlayerIndex, " ")
    end
end
