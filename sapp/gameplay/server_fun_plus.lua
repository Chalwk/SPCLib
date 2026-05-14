--[[
=====================================================================================
SCRIPT NAME:      server_fun_plus.lua
DESCRIPTION:      Comprehensive admin fun/mod toolkit with 12+ gameplay-altering commands
                  for creating chaotic and entertaining server experiences.

FEATURES:
                - Rocket: Launch players in vehicles with custom trajectories
                - Force Chat: Make players say anything you want
                - Fake Join/Quit: Simulate player connections/disconnections
                - Random Teleport: Move players to random map locations
                - Slap: Physically knock players around
                - Spam: Flood players with annoying messages
                - Zap: Deal customizable damage to players
                - God Mode: Broadcast messages as "God"
                - Nuke: Obliterate players with massive explosions
                - Color Changer: Modify player colors
                - Weapon Removal: Strip players of their weapons
                - Client Crash: Disconnect players (admin use only)

CONFIGURATION:
                - Customize permission levels for each command
                - Adjust spam duration and intensity
                - Configure projectile types for nuke command
                - Set custom messages and prefixes

                WARNING: Some features (like client crash) should be used responsibly and only on
                         consenting players/administrators. May cause gameplay disruption.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- ROCKET --
-- /rocket
-- /rocket me
-- /rocket x,y,z
-- /rocket me x,y,z
-- /rocket me x,y,z,yaw,pitch,roll
-- /rocket x,y,z,yaw,pitch,roll
-- /rocket index
-- /rocket index x,y,z
-- /rocket index x,y,z,yaw,pitch,roll
rocket_command = "rocket"
rocket_permission_level = 1
values_specified = {}
x = {}
y = {}
z = {}
yaw = {}
pitch = {}
roll = {}
ypr = {}

-- FORCE CHAT --
-- /fchat [index id] (message)
force_chat_command = "fchat"
fc_permission_level = 1

-- SLAP --
-- /slap [index id]
slap_command = "slap"
slap_permission_level = 1

-- FAKE JOIN | FAKE QUIT --
-- /fakejoin [name]
-- /fakequit [name]
fake_join_command = "fakejoin"
fake_quit_command = "fakequit"
fake_permission_level = 1

-- BROADCAST AS GOD --
god_command = "bgod"
god_prefix = "[god]"
god_permission_level = 1

-- EXPLODE --
nuke_command = "nuke"
nuke_permission_level = 1

-- SPAM --
spam_command = "spam"
spam_permission_level = 1
spam_duration = 10
spam_victim = {}
spam = {}

-- TAKE WEAPONS --
take_command = "take"
take_permission_level = 1

-- CRASH --
crash_command = "crash"
crash_permission_level = 1

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnPlayerChat")
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_JOIN, "OnPlayerJoin")
    register_callback(cb.EVENT_LEAVE, "OnPlayerLeave")
end

function OnScriptUnload()
end

function OnPlayerJoin(PlayerIndex)
    spam_victim[get_var(PlayerIndex, "$n")] = { }
    spam_victim[get_var(PlayerIndex, "$n")].spam_timer = 0
    spam[PlayerIndex] = false
end

function OnPlayerLeave(PlayerIndex)
    spam_victim[get_var(PlayerIndex, "$n")].spam_timer = 0
    spam[PlayerIndex] = false
end

function OnTick()
    for i = 1, 16 do
        if player_present(i) then
            if (spam[i] == true) then
                for s = 1, 1 do
                    rprint(i, " ")
                end
                spam_victim[get_var(i, "$n")].spam_timer = spam_victim[get_var(i, "$n")].spam_timer + 0.030
                Spam(i, spam_broadcast)
                if spam_victim[get_var(i, "$n")].spam_timer >= math.floor(spam_duration) then
                    spam_victim[get_var(i, "$n")].spam_timer = 0
                    spam[i] = false
                    for t = 1, 30 do
                        rprint(i, " ")
                    end
                    rprint(i, "|c" .. "Y O U   W E R E   S P A M M E D!")
                    for u = 1, 10 do
                        rprint(i, "|c" .. " ")
                    end
                end
            end
        end
    end
end

function OnPlayerChat(PlayerIndex, Message)
    local t = tokenizestring(Message)
    local executor = get_var(PlayerIndex, "$n")
    if t[1] ~= nil then
        if t[1] == ("/" .. string.lower(force_chat_command)) or t[1] == ("\\" .. string.lower(force_chat_command)) then
            if tonumber(get_var(executor, "$lvl")) >= fc_permission_level then
                if t[2] ~= nil then
                    local index = tonumber(t[2])
                    if string.match(t[2], "%d+") then
                        if t[3] ~= nil then
                            if index ~= tonumber(executor) then
                                if player_present(index) then
                                    local broadcast = string.gsub(Message, string.sub(t[1], 1, 1) .. force_chat_command .. " %d+", "")
                                    execute_command("msg_prefix \"\"")
                                    say_all(get_var(index, "$name") .. " [" .. get_var(index, "$n") .. "]: " .. broadcast)
                                    execute_command("msg_prefix \" *  * SERVER *  * \"")
                                    return false
                                else
                                    rprint(executor, "Invalid Player Index")
                                    return false
                                end
                            else
                                rprint(executor, "You cannot broadcast as yourself!")
                                return false
                            end
                        else
                            rprint(executor, "You didn't type a message!")
                            return false
                        end
                    else
                        rprint(executor, "Invalid Syntax!")
                        return false
                    end
                else
                    rprint(executor, "Invalid Syntax. Type /" .. force_chat_command .. " [index id]")
                    return false
                end
            else
                rprint(executor, "You do not have permission to execute that command!")
                return false
            end
        elseif t[1] == ("/" .. string.lower(god_command)) or t[1] == ("\\" .. string.lower(god_command)) then
            if tonumber(get_var(executor, "$lvl")) >= god_permission_level then
                if t[2] ~= nil then
                    execute_command("msg_prefix \"\"")
                    local broadcast = string.gsub(Message, string.sub(t[1], 1, 1) .. god_command, "")
                    say_all("God:" .. broadcast)
                    execute_command("msg_prefix \" *  * SERVER *  * \"")
                    return false
                else
                    rprint(executor, "Invalid Syntax. Type /" .. god_command .. " (message)")
                    return false
                end
            else
                rprint(executor, "You do not have permission to execute that command!")
                return false
            end
        elseif t[1] == ("/" .. string.lower(spam_command)) or t[1] == ("\\" .. string.lower(spam_command)) then
            if tonumber(get_var(executor, "$lvl")) >= spam_permission_level then
                if t[2] ~= nil then
                    local index = tonumber(t[2])
                    if string.match(t[2], "%d+") then
                        if spam[index] == false then
                            if t[3] ~= nil then
                                if index ~= tonumber(executor) then
                                    if index ~= nil and index > 0 and index < 17 then
                                        if player_present(index) then
                                            execute_command("msg_prefix \"\"")
                                            spam_broadcast = string.gsub(Message, "/" .. spam_command .. " %d+", "")
                                            spam[index] = true
                                            say(PlayerIndex, get_var(index, "$name") .. " is being spammed!")
                                            execute_command("msg_prefix \" *  * SERVER *  * \"")
                                            return false
                                        else
                                            rprint(executor, "Invalid Player Index")
                                            return false
                                        end
                                    end
                                else
                                    rprint(executor, "You cannot spam yourself!")
                                    return false
                                end
                            else
                                rprint(executor, "You didn't type a message!")
                                return false
                            end
                        else
                            rprint(executor, get_var(index, "$name") .. " is already being spammed!")
                            return false
                        end
                    else
                        rprint(executor, "Invalid Syntax!")
                        return false
                    end
                else
                    rprint(executor, "Invalid Syntax. Type /" .. spam_command .. " [index id] (message)")
                    return false
                end
            else
                rprint(executor, "You do not have permission to execute that command!")
                return false
            end
        end
    end
    return true
end

function OnServerCommand(PlayerIndex, Command)
    local UnknownCMD
    local t = tokenizestring(Command)
    local executor = get_var(PlayerIndex, "$n")
    if t[1] ~= nil then
        if t[1] == string.lower(rocket_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= rocket_permission_level then
                local index = tonumber(t[2])
                -- /rocket
                if t[2] == nil then
                    Rocket(PlayerIndex, executor)
                    values_specified[PlayerIndex] = false
                    ypr[PlayerIndex] = false

                    -- /rocket me
                elseif t[2] == "me" and t[3] == nil then
                    Rocket(PlayerIndex, executor)
                    values_specified[PlayerIndex] = false
                    ypr[PlayerIndex] = false

                    -- /rocket x,y,z
                elseif t[2] ~= "me" and t[5] == nil then
                    Rocket(PlayerIndex, executor, t[2], t[3], t[4])
                    values_specified[PlayerIndex] = true
                    ypr[PlayerIndex] = false

                    -- /rocket me x,y,z
                elseif t[2] == "me" and t[6] == nil then
                    Rocket(PlayerIndex, executor, t[3], t[4], t[5])
                    values_specified[PlayerIndex] = true
                    ypr[PlayerIndex] = false

                    -- /rocket me x,y,z,yaw,pitch,roll
                elseif t[2] == "me" and t[9] == nil then
                    Rocket(PlayerIndex, executor, t[3], t[4], t[5], t[6], t[7], t[8])
                    values_specified[PlayerIndex] = true
                    ypr[PlayerIndex] = true

                    -- /rocket x,y,z,yaw,pitch,roll
                elseif t[2] ~= "me" and t[8] == nil then
                    Rocket(PlayerIndex, executor, t[2], t[3], t[4], t[5], t[6], t[7])
                    values_specified[PlayerIndex] = true
                    ypr[PlayerIndex] = true

                    -- /rocket index
                elseif t[2] ~= "me" and t[3] == nil then
                    if string.match(t[2], "%d+") then
                        if player_present(index) then
                            if index > 0 and index < 17 then
                                Rocket(index, executor)
                                values_specified[index] = false
                                ypr[index] = false
                            end
                        else
                            rprint(executor, "Invalid Player ID")
                        end
                    else
                        rprint(executor, "Invalid Syntax!")
                    end
                    -- /rocket index x,y,z
                elseif t[2] ~= nil and t[2] ~= "me" and t[3] ~= nil and t[4] ~= nil and t[5] ~= nil and t[6] == nil then
                    if string.match(t[2], "%d+") then
                        if player_present(index) then
                            if index > 0 and index < 17 then
                                Rocket(index, executor, t[3], t[4], t[5])
                                values_specified[index] = true
                                ypr[index] = false
                            end
                        else
                            rprint(executor, "Invalid Player ID")
                        end
                    else
                        rprint(executor, "Invalid Syntax!")
                    end
                    -- /rocket index x,y,z,yaw,pitch,roll
                elseif t[2] ~= nil and t[2] ~= "me" and t[3] ~= nil and t[4] ~= nil and t[5] ~= nil and t[6] ~= nil and t[7] ~= nil and t[8] ~= nil and t[9] == nil then
                    if string.match(t[2], "%d+") then
                        if player_present(index) then
                            if index > 0 and index < 17 then
                                Rocket(index, executor, t[3], t[4], t[5], t[6], t[7], t[8])
                                values_specified[index] = true
                                ypr[index] = true
                            end
                        else
                            rprint(executor, "Invalid Player ID")
                        end
                    else
                        rprint(executor, "Invalid Syntax!")
                    end
                end
            else
                rprint(executor, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        end
    end
    if t[1] ~= nil then
        if t[1] == string.lower(slap_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= slap_permission_level then
                if t[2] ~= nil then
                    local index = tonumber(t[2])
                    if index ~= tonumber(executor) then
                        if string.match(t[2], "%d+") then
                            if index ~= nil and index > 0 and index < 17 then
                                if player_present(index) then
                                    if player_alive(index) then
                                        if not PlayerInVehicle(index) then
                                            local pX, pY, pX = read_vector3d(get_dynamic_player(index) + 0x5C)
                                            write_vector3d(get_dynamic_player(index) + 0x5C, pX + 0.50, pY + 0.50, pX + 4)
                                            rprint(executor, "You slapped " .. get_var(index, "$name"))
                                            rprint(index, "You were slapped by " .. get_var(executor, "$name"))
                                        else
                                            rprint(executor, get_var(index, "$name") .. " is in a vehicle!")
                                        end
                                    else
                                        rprint(executor, "Unable to execute. Player is dead! Wait until they respawn.")
                                    end
                                else
                                    rprint(executor, "Invalid Player ID!")
                                end
                            end
                        else
                            rprint(executor, "Invalid Syntax!")
                        end
                    else
                        rprint(executor, "You cannot slap yourself!")
                    end
                else
                    rprint(executor, "Invalid Syntax. Type /" .. slap_command .. " [index id]")
                end
            else
                rprint(executor, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        end
    end
    if t[1] ~= nil then
        if t[1] == string.lower(fake_join_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= fake_permission_level then
                if t[2] ~= nil then
                    if t[3] == nil then
                        local fake_name = tostring(t[2])
                        local char_len = string.len(fake_name)
                        if char_len > 11 then
                            rprint(PlayerIndex, "Name can only be 11 characters! You typed " .. char_len .. " characters!")
                        else
                            execute_command("msg_prefix \"\"")
                            say_all("Welcome " .. fake_name)
                            execute_command("msg_prefix \" *  * SERVER *  * \"")
                        end
                    else
                        rprint(PlayerIndex, "The name can only be one word!")
                    end
                else
                    rprint(PlayerIndex, "Invalid Syntax. Type /" .. fake_join_command .. " [name]")
                end
            else
                rprint(PlayerIndex, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        elseif t[1] == string.lower(fake_quit_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= fake_permission_level then
                if t[2] ~= nil then
                    if t[3] == nil then
                        local fake_name = tostring(t[2])
                        local char_len = string.len(fake_name)
                        if char_len > 11 then
                            rprint(PlayerIndex, "Name can only be 11 characters! You typed " .. char_len .. " characters!")
                        else
                            execute_command("msg_prefix \"\"")
                            say_all(fake_name .. " quit")
                            execute_command("msg_prefix \" *  * SERVER *  * \"")
                        end
                    else
                        rprint(PlayerIndex, "The name can only be one word!")
                    end
                else
                    rprint(PlayerIndex, "Invalid Syntax. Type /" .. fake_quit_command .. " [name]")
                end
            else
                rprint(PlayerIndex, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        elseif t[1] == string.lower(nuke_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= nuke_permission_level then
                if t[2] ~= nil then
                    local index = tonumber(t[2])
                    if index ~= tonumber(executor) then
                        if string.match(t[2], "%d+") then
                            if index ~= nil and index > 0 and index < 17 then
                                if player_present(index) then
                                    if (player_alive(index)) then

                                        local function TagInfo(obj_type, obj_name)
                                            local tag = lookup_tag(obj_type, obj_name)
                                            return tag ~= 0 and read_dword(tag + 0xC) or nil
                                        end

                                        local x1, y1, z1 = read_vector3d(get_dynamic_player(index) + 0x5C)
                                        local frag_grenade = get_tag_info("proj", "weapons\\frag grenade\\frag grenade")

                                        for i = 1, math.random(1, 15) do
                                            -- frag grenade
                                            spawn_projectile(frag_grenade, index, x1 + math.random(0.1, 5.5), y1 + math.random(0.1, 5.5), z1 + math.random(0.1, 1))

                                            if TagInfo("proj", "weapons\\rocket launcher\\rocket") then
                                                -- rocket launcher projectile
                                                local rocket = spawn_object("proj", "weapons\\rocket launcher\\rocket", x1, y1, z1 + math.random(1, 20))
                                                local rocket_projectile = get_object_memory(rocket)
                                                write_float(rocket_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "weapons\\plasma_cannon\\plasma_cannon") then
                                                -- plasma cannon projectile
                                                local plasma_cannon = spawn_object("proj", "weapons\\plasma_cannon\\plasma_cannon", x1, y1, z1 + math.random(1, 20))
                                                local plasma_cannon_projectile = get_object_memory(plasma_cannon)
                                                write_float(plasma_cannon_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "weapons\\needler\\mp_needle") then
                                                -- needle projectile
                                                local needle = spawn_object("proj", "weapons\\needler\\mp_needle", x1, y1, z1 + math.random(1, 5))
                                                local needle_projectile = get_object_memory(needle)
                                                write_float(needle_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "vehicles\\banshee\\banshee bolt") then
                                                -- banshee plasma bolt
                                                local banshee_bolt = spawn_object("proj", "vehicles\\banshee\\banshee bolt", x1, y1, z1 + math.random(1, 20))
                                                local banshee_bolt_projectile = get_object_memory(banshee_bolt)
                                                write_float(banshee_bolt_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "vehicles\\banshee\\mp_banshee fuel rod") then
                                                -- banshee fuel rod
                                                local banshee_fuel_rod = spawn_object("proj", "vehicles\\banshee\\mp_banshee fuel rod", x1, y1, z1 + math.random(1, 20))
                                                local banshee_fuel_rod_projectile = get_object_memory(banshee_fuel_rod)
                                                write_float(banshee_fuel_rod_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "vehicles\\scorpion\\tank shell") then
                                                -- tank shell
                                                local tank_shell = spawn_object("proj", "vehicles\\scorpion\\tank shell", x1, y1, z1 + math.random(1, 20))
                                                local tank_shell_projectile = get_object_memory(tank_shell)
                                                write_float(tank_shell_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "weapons\\flamethrower\\flame") then
                                                -- flames
                                                local flames = spawn_object("proj", "weapons\\flamethrower\\flame", x1, y1, z1 + 0.2)
                                                local flame_projectile = get_object_memory(flames)
                                                write_float(flame_projectile + 0x70, -math.random(0.2, 0.5))
                                            end

                                            if TagInfo("proj", "weapons\\sniper rifle\\sniper bullet") then
                                                -- sniper bullet projectile
                                                local sniper = spawn_object("proj", "weapons\\sniper rifle\\sniper bullet", x1, y1, z1 + math.random(1, 20))
                                                local sniper_projectile = get_object_memory(sniper)
                                                write_float(sniper_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "weapons\\plasma rifle\\charged bolt") then
                                                -- plasma rile charged bolt projectile
                                                local plasma_rile_bolt = spawn_object("proj", "weapons\\plasma rifle\\charged bolt", x1, y1, z1 + math.random(1, 20))
                                                local plasma_rile_bolt_projectile = get_object_memory(plasma_rile_bolt)
                                                write_float(plasma_rile_bolt_projectile + 0x70, -math.random(1, 3))
                                            end

                                            if TagInfo("proj", "vehicles\\ghost\\ghost bolt") then
                                                -- ghost bolt projectile
                                                local ghost_bolt = spawn_object("proj", "vehicles\\ghost\\ghost bolt", x1, y1, z1 + math.random(1, 20))
                                                local ghost_bolt_projectile = get_object_memory(ghost_bolt)
                                                write_float(ghost_bolt_projectile + 0x70, -math.random(1, 3))
                                            end
                                        end
                                    else
                                        rprint(executor, get_var(index, "$name") .. " is dead!")
                                    end
                                else
                                    rprint(executor, "Invalid Player ID!")
                                end
                            end
                        else
                            rprint(executor, "Invalid Syntax.")
                        end
                    else
                        rprint(executor, "You cannot nuke yourself!")
                    end
                else
                    rprint(executor, "Invalid Syntax. Type /" .. nuke_command .. " [index id]")
                end
            else
                rprint(executor, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        elseif t[1] == string.lower(take_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= take_permission_level then
                if t[2] ~= nil then
                    if string.match(t[2], "%d+") then
                        local target = tonumber(t[2])
                        if player_present(target) then
                            if (tonumber(target) ~= tonumber(executor)) then
                                local player_object = get_dynamic_player(target)
                                if player_object ~= 0 then
                                    local weapon_id = read_dword(player_object + 0x118)
                                    if weapon_id ~= 0 then
                                        for j = 0, 3 do
                                            local weapons = read_dword(player_object + 0x2F8 + j * 4)
                                            destroy_object(weapons)
                                        end
                                        rprint(executor, "You have removed " .. get_var(target, "$name") .. "'s weapons!")
                                    end
                                end
                            else
                                rprint(executor, "You cannot take your own weapons!")
                            end
                        else
                            rprint(executor, "Player not present!")
                        end
                    else
                        rprint(executor, "Invalid Player Index")
                    end
                else
                    rprint(PlayerIndex, "Invalid Syntax. Type /" .. take_command .. " [index id]")
                end
            else
                rprint(PlayerIndex, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        elseif t[1] == string.lower(crash_command) then
            if tonumber(get_var(PlayerIndex, "$lvl")) >= take_permission_level then
                if t[2] ~= nil then
                    if string.match(t[2], "%d+") then
                        local target = tonumber(t[2])
                        if player_present(target) then
                            if (tonumber(target) ~= tonumber(executor)) then
                                local function TagInfo(obj_type, obj_name)
                                    local tag = lookup_tag(obj_type, obj_name)
                                    return tag ~= 0 and read_dword(tag + 0xC) or nil
                                end
                                if TagInfo("vehi", "vehicles\\rwarthog\\rwarthog") then
                                    local player_object = get_dynamic_player(target)
                                    if player_object ~= 0 then
                                        timer(0, "CrashPlayer", target)
                                        rprint(executor, "You have crashed " .. get_var(target, "$name") .. "'s game client")
                                    end
                                else
                                    rprint(PlayerIndex, "Error. Crash does not work on this map!")
                                end
                            else
                                rprint(executor, "You cannot crash your own game client!")
                            end
                        else
                            rprint(executor, "Player not present!")
                        end
                    else
                        rprint(executor, "Invalid Player Index")
                    end
                else
                    rprint(PlayerIndex, "Invalid Syntax. Type /" .. crash_command .. " [index id]")
                end
            else
                rprint(PlayerIndex, "You do not have permission to execute that command!")
            end
            UnknownCMD = false
        end
    end
    return UnknownCMD
end

function Rocket(player, executor, X, Y, Z, Yaw, Pitch, Roll)
    local player_object = get_dynamic_player(player)
    if player_object then
        if PlayerInVehicle(player) then
            local VehicleObj = get_object_memory(read_dword(player_object + 0x11c))
            if VehicleObj ~= nil then
                write_bit(VehicleObj + 0x10, 2, 0)
                if values_specified[player] then
                    x[player] = X
                    y[player] = Y
                    z[player] = Z
                    yaw[player] = Yaw
                    pitch[player] = Pitch
                    roll[player] = Roll
                else
                    x[player] = 0
                    y[player] = 0
                    z[player] = 0.75
                    yaw[player] = 1
                    pitch[player] = 1
                    roll[player] = 15
                    ypr[player] = true
                end
                write_float(VehicleObj + 0x68, x[player])
                write_float(VehicleObj + 0x6C, y[player])
                write_float(VehicleObj + 0x70, z[player])
                if ypr[player] then
                    write_float(VehicleObj + 0x90, yaw[player])
                    write_float(VehicleObj + 0x8C, pitch[player])
                    write_float(VehicleObj + 0x94, roll[player])
                end
            end
        else
            if get_var(player, "$n") == get_var(executor, "$n") then
                rprint(executor, "You're not in a vehicle!")
            else
                rprint(executor, get_var(player, "$name") .. " is not in a vehicle!")
            end
        end
        if get_var(player, "$n") == get_var(executor, "$n") and PlayerInVehicle(player) then
            rprint(executor, "You have been rocketed!")
        elseif get_var(player, "$n") ~= get_var(executor, "$n") and PlayerInVehicle(player) then
            rprint(executor, "You launched " .. get_var(player, "$name"))
        end
    end
end

function Spam(player, broadcast)
    for i = 1, math.random(1, 10) do
        if i == 1 then
            rprint(player, "|l" .. " " .. broadcast)
            rprint(player, "|r" .. " " .. broadcast)
            rprint(player, "|c" .. " " .. broadcast)
            rprint(player, "|t" .. " " .. broadcast)
        elseif i == 2 then
            rprint(player, "|t" .. " " .. broadcast)
            rprint(player, "|l" .. " " .. broadcast)
            rprint(player, "|c" .. " " .. broadcast)
            rprint(player, "|r" .. " " .. broadcast)
        elseif i == 3 then
            rprint(player, "|l" .. " " .. broadcast)
            rprint(player, "|c" .. " " .. broadcast)
            rprint(player, "|r" .. " " .. broadcast)
            rprint(player, "|t" .. " " .. broadcast)
        elseif i == 4 then
            rprint(player, "|t" .. " " .. broadcast)
            rprint(player, "|r" .. " " .. broadcast)
            rprint(player, "|c" .. " " .. broadcast)
            rprint(player, "|l" .. " " .. broadcast)
        elseif i == 5 then
            rprint(player, "|c" .. " " .. broadcast)
            rprint(player, "|r" .. " " .. broadcast)
            rprint(player, "|l" .. " " .. broadcast)
            rprint(player, "|t" .. " " .. broadcast)
        elseif i == 6 then
            rprint(player, "|t" .. " " .. broadcast)
            rprint(player, "|c" .. " " .. broadcast)
            rprint(player, "|l" .. " " .. broadcast)
            rprint(player, "|r" .. " " .. broadcast)
        elseif i == 7 then
            rprint(player, "|t" .. "@r^ (]= ()n d*# =(e dzd #v/ fiv *$= c-( g** ges -/& 'w] qh/" .. broadcast)
            rprint(player, "|c" .. "='g *!- ymr a#$ &=t atu @*i =(d .^. -'/ )[' (*k @$# a)! -iv" .. broadcast)
            rprint(player, "|l" .. "$w z.m qch j*= sp) )f* =&y m#v $-- axl" .. broadcast)
            rprint(player, "|c" .. "^h= %&b d-m sp/ gmu ;lk d%; @/, #j* ,yx tkz i$# ^j# co) x.*" .. broadcast)
            rprint(player, "|r" .. "p*v ace -po -zx by] zu[ .$; -to &vh i-$ jdz [*- k-] ]yj in^" .. broadcast)
        elseif i == 8 then
            rprint(player, "|r" .. "zh@ )-i f[f kp% ]et j-= !yr %** !kdo k%y ;$. #-@ (n- ^jh dc" .. broadcast)
            rprint(player, "|r" .. "n$y =bd f@h jzi xgm b') !sh /ec @yj $^e k*r @-/ qs/ t*; /ql" .. broadcast)
            rprint(player, "|r" .. "!ma f-- cax 'm/ k@- lih oq, nsv .cq t.@" .. broadcast)
            rprint(player, "|r" .. "<> <> <> <> <> <> <> <> <> <> <> <> <> <> <> <>" .. broadcast)
            rprint(player, "|r" .. "=*t /)^ -gu d;] w]= j-k oi. rgv [r& ,/o 'gn z*$ wra )t; /o(" .. broadcast)
        elseif i == 9 then
            rprint(player, "|t" .. "mt& dgm v$a n/= b!n *$q ,j@ k/d z&k qi$ b&' /.b *zu [/t /=%" .. broadcast)
            rprint(player, "|t" .. "r]/ -#! cp* -ek xsf nan %=@ sy= qrf b=j t,a -[- -v@ z[q -^w" .. broadcast)
            rprint(player, "|t" .. "/q! uv] ,[- d*u ;(/ -i% km- rfb $p@ r#o" .. broadcast)
            rprint(player, "|t" .. "kkm ^mi -^/ j^e t$x '** '** [/^ /r/ 's- .if xe^ bpg k$& -s[" .. broadcast)
            rprint(player, "|t" .. "^!y m&y #h! ,-- azi ht% nrk ]'$ a#b 'vo 'du *)* %/x w// dr*" .. broadcast)
        elseif i == 10 then
            rprint(player, "|l" .. "v,b b'w r*[ ox* ..$ z-/ %)( (w[ d[. wl] v-( k*o qts [gi pyb" .. broadcast)
            rprint(player, "|l" .. "cm[ &(& /h) )!* f[f t#! u]] h^n m!/ '-. /tt $[h /er ]e^ eze" .. broadcast)
            rprint(player, "|l" .. "$q) z*w xr[ oz$ p.d *ux -&% *&; #g/ /yu ,!i ;za ezx .*p *l," .. broadcast)
            rprint(player, "|l" .. "d$) /.r ^;e [^# tzn e.- l!- ww- v-e s,/ %og %!- *yt nx- ]j^" .. broadcast)
            rprint(player, "|l" .. "$c* oeq /oy *cy y)m *g/ nse &h^ *va u&@ x-- *(& ;mx &n; m*j" .. broadcast)
        end
    end
end

function CrashPlayer(target)
    local player_object = get_dynamic_player(target)
    if (player_object ~= 0) then
        local x, y, z = read_vector3d(player_object + 0x5C)
        local vehicle_id = spawn_object("vehi", "vehicles\\rwarthog\\rwarthog", x, y, z)
        local veh_obj = get_object_memory(vehicle_id)
        if (veh_obj ~= 0) then
            for j = 0, 20 do
                enter_vehicle(vehicle_id, target, j)
                exit_vehicle(target)
            end
            destroy_object(vehicle_id)
        end
    end
    return false
end

function PlayerInVehicle(PlayerIndex)
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

-- credits to 002 for this function.
function get_tag_info(tagclass, tagname)
    local tagarray = read_dword(0x40440000)
    for i = 0, read_word(0x4044000C) - 1 do
        local tag = tagarray + i * 0x20
        local class = string.reverse(string.sub(read_string(tag), 1, 4))
        if (class == tagclass) then
            if (read_string(read_dword(tag + 0x10)) == tagname) then
                return read_dword(tag + 0xC)
            end
        end
    end
    return nil
end
