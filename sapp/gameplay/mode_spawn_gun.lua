--[[
=====================================================================================
SCRIPT NAME:      mode_spawn_gun.lua
DESCRIPTION:      Advanced object spawning system using weapon targeting
                  - Spawn objects by aiming and shooting
                  - Over 40 spawnable items (vehicles, weapons, equipment, projectiles)
                  - Automatic cleanup system
                  - Precise object placement and physics

                  Key Features:
                  - Command: /spawngun [object] (e.g. "/spawngun banshee")
                  - Command: /clean (removes all spawned objects)
                  - Objects auto-delete on player death
                  - Realistic physics on spawned objects
                  - Complete list of spawnable objects in config

                  Object Categories:
                  - Characters (cyborg)
                  - Equipment (camo, overshield)
                  - Weapons (all standard weapons)
                  - Vehicles (all standard vehicles)
                  - Projectiles (all weapon projectiles)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'
spawngun_command = "spawngun"
clean_command = "clean"

objects = { }
active_mode = { }

obj_type = { }
for b = 1, 16 do
    obj_type[b] = {}
end
obj_name = { }
for c = 1, 16 do
    obj_name[c] = {}
end

-- object deletion --
clean_up_dones = { }
drones = {}

for i = 1, 16 do
    drones[i] = {}
end
initial_spawn = {}
for d = 1, 16 do
    initial_spawn[d] = {}
end
obj_in_memory = {}

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
    register_callback(cb.EVENT_OBJECT_SPAWN, "OnObjectSpawn")
    register_callback(cb.EVENT_PRESPAWN, "OnPlayerPrespawn")
    register_callback(cb.EVENT_DIE, "OnPlayerDeath")
    register_callback(cb.EVENT_JOIN, "OnPlayerJoin")
end

function OnScriptUnload()

end

function OnPlayerJoin(PlayerIndex)
    initial_spawn[get_var(PlayerIndex, "$n")] = true
    obj_in_memory[get_var(PlayerIndex, "$n")] = nil
end

function OnPlayerPrespawn(PlayerIndex)
    if (initial_spawn[get_var(PlayerIndex, "$n")] == false) then
        active_mode[get_var(PlayerIndex, "$n")] = false
    end
end

function OnPlayerDeath(PlayerIndex)
    initial_spawn[get_var(PlayerIndex, "$n")] = false
    active_mode[get_var(PlayerIndex, "$n")] = false
    CleanUpDrones(PlayerIndex)
end

function CleanUpDrones(PlayerIndex)
    if (clean_up_dones[PlayerIndex] == true) then
        if drones[PlayerIndex] ~= nil then
            for k, v in pairs(drones[PlayerIndex]) do
                if drones[PlayerIndex][k] > 0 then
                    if v then
                        if obj_in_memory[get_var(PlayerIndex, "$n")] then
                            destroy_object(v)
                        end
                        drones[PlayerIndex][k] = nil
                    end
                end
            end
        end
    end
end

function OnServerCommand(PlayerIndex, Command)
    local UnknownCMD
    local t = tokenizestring(Command)
    if (t[1] == spawngun_command) then
        if t[2] ~= nil then
            ObjectExists = false
            for i = 1, #objects do
                if string.find(t[2], objects[i][1]) then
                    active_mode[get_var(PlayerIndex, "$n")] = true
                    initial_spawn[get_var(PlayerIndex, "$n")] = false
                    obj_type[PlayerIndex] = objects[i][2]
                    obj_name[PlayerIndex] = objects[i][3]
                    rprint(PlayerIndex, "Now spawning: " .. objects[i][1])
                    UnknownCMD = false
                    ObjectExists = true
                    break
                end
            end
            if ObjectExists == false then
                rprint(PlayerIndex, "Object does not exist")
            end
            UnknownCMD = false
            if (active_mode[get_var(PlayerIndex, "$n")] == true) then
                if t[2] == 'off' or t[2] == '0' or t[2] == 'false' then
                    active_mode[get_var(PlayerIndex, "$n")] = false
                    rprint(PlayerIndex, "Spawngun mode deactivated")
                    UnknownCMD = false
                end
            end
        else
            rprint(PlayerIndex, "Invalid Syntax!")
            UnknownCMD = false
        end
    elseif (t[1] == clean_command) then
        if drones[PlayerIndex][1] ~= nil then
            for _, v in pairs(drones[PlayerIndex]) do
                rprint(PlayerIndex, "Cleaning up " .. tonumber(#drones[PlayerIndex]) .. " vehicles")
                CleanUpDrones(PlayerIndex)
                UnknownCMD = false
                break
            end
        else
            rprint(PlayerIndex, "Nothing to clean up!")
            UnknownCMD = false
        end
    end
    return UnknownCMD
end

function OnObjectSpawn(PlayerIndex, MapID, ParentID, ObjectID)
    if (PlayerIndex and initial_spawn[get_var(PlayerIndex, "$n")] ~= true) then
        if active_mode[get_var(PlayerIndex, "$n")] == true then
            return false, SpawnGun(PlayerIndex, ParentID)
        end
    end
end

function SpawnGun(PlayerIndex, ParentID)
    if get_dynamic_player(PlayerIndex) ~= nil then
        local object_id = get_object_memory(ParentID)
        if object_id ~= nil then
            local x_aim = read_float(object_id + 0x230)
            local y_aim = read_float(object_id + 0x234)
            local z_aim = read_float(object_id + 0x238)
            local x = read_float(object_id + 0x5C)
            local y = read_float(object_id + 0x60)
            local z = read_float(object_id + 0x64)
            local obj_x = x + 0.5 * math.sin(x_aim)
            local obj_y = y + 0.5 * math.sin(y_aim)
            local obj_z = z + 0.5 * math.sin(z_aim) + 0.5
            local object_spawned = spawn_object(obj_type[PlayerIndex], obj_name[PlayerIndex], obj_x, obj_y, obj_z)
            local object = get_object_memory(object_spawned)
            drones[PlayerIndex] = drones[PlayerIndex] or {}
            table.insert(drones[PlayerIndex], object_spawned)
            clean_up_dones[PlayerIndex] = true
            obj_in_memory[get_var(PlayerIndex, "$n")] = object
            if object then
                write_float(object + 0x68, 0.6 * math.sin(x_aim))
                write_float(object + 0x6C, 0.6 * math.sin(y_aim))
                write_float(object + 0x70, 0.6 * math.sin(z_aim))
            end
        end
    end
end

function tokenizestring(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = { };
    i = 1
    for str in string.gmatch(inputstr, '([^' .. sep .. ']+)') do
        t[i] = str
        i = i + 1
    end
    return t
end

objects[1] = { "cyborg", "bipd", "characters\\cyborg_mp\\cyborg_mp" }
objects[2] = { "camo", "eqip", "powerups\\active camouflage" }
objects[3] = { "health", "eqip", "powerups\\health pack" }
objects[4] = { "overshield", "eqip", "powerups\\over shield" }
objects[5] = { "frag", "eqip", "weapons\\frag grenade\\frag grenade" }
objects[6] = { "plasma", "eqip", "weapons\\plasma grenade\\plasma grenade" }
objects[7] = { "banshee", "vehi", "vehicles\\banshee\\banshee_mp" }
objects[8] = { "turret", "vehi", "vehicles\\c gun turret\\c gun turret_mp" }
objects[9] = { "ghost", "vehi", "vehicles\\ghost\\ghost_mp" }
objects[10] = { "tank", "vehi", "vehicles\\scorpion\\scorpion_mp" }
objects[11] = { "rhog", "vehi", "vehicles\\rwarthog\\rwarthog" }
objects[12] = { "hog", "vehi", "vehicles\\warthog\\mp_warthog" }
objects[13] = { "rifle", "weap", "weapons\\assault rifle\\assault rifle" }
objects[14] = { "ball", "weap", "weapons\\ball\\ball" }
objects[15] = { "flag", "weap", "weapons\\flag\\flag" }
objects[16] = { "flamethrower", "weap", "weapons\\flamethrower\\flamethrower" }
objects[17] = { "needler", "weap", "weapons\\needler\\mp_needler" }
objects[18] = { "pistol", "weap", "weapons\\pistol\\pistol" }
objects[19] = { "ppistol", "weap", "weapons\\plasma pistol\\plasma pistol" }
objects[20] = { "prifle", "weap", "weapons\\plasma rifle\\plasma rifle" }
objects[21] = { "frg", "weap", "weapons\\plasma_cannon\\plasma_cannon" }
objects[22] = { "rocket", "weap", "weapons\\rocket launcher\\rocket launcher" }
objects[23] = { "shotgun", "weap", "weapons\\shotgun\\shotgun" }
objects[24] = { "sniper", "weap", "weapons\\sniper rifle\\sniper rifle" }
objects[25] = { "sheebolt", "proj", "vehicles\\banshee\\banshee bolt" }
objects[26] = { "sheerod", "proj", "vehicles\\banshee\\mp_banshee fuel rod" }
objects[27] = { "turretbolt", "proj", "vehicles\\c gun turret\\mp gun turret" }
objects[28] = { "ghostbolt", "proj", "vehicles\\ghost\\ghost bolt" }
objects[29] = { "tankbullet", "proj", "vehicles\\scorpion\\bullet" }
objects[30] = { "tankshell", "proj", "vehicles\\scorpion\\tank shell" }
objects[31] = { "hogbullet", "proj", "vehicles\\warthog\\bullet" }
objects[32] = { "riflebullet", "proj", "weapons\\assault rifle\\bullet" }
objects[33] = { "flame", "proj", "weapons\\flamethrower\\flame" }
objects[34] = { "needle", "proj", "weapons\\needler\\mp_needle" }
objects[35] = { "pistolbullet", "proj", "weapons\\pistol\\bullet" }
objects[36] = { "ppistolbolt", "proj", "weapons\\plasma pistol\\bolt" }
objects[37] = { "priflebolt", "proj", "weapons\\plasma rifle\\bolt" }
objects[38] = { "priflecbolt", "proj", "weapons\\plasma rifle\\charged bolt" }
objects[39] = { "rocketproj", "proj", "weapons\\rocket launcher\\rocket" }
objects[40] = { "shottyshot", "proj", "weapons\\shotgun\\pellet" }
objects[41] = { "snipershot", "proj", "weapons\\sniper rifle\\sniper bullet" }
objects[42] = { "fuelrodshot", "proj", "weapons\\plasma_cannon\\plasma_cannon" }
