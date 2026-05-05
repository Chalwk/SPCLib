--[[
=====================================================================================
SCRIPT NAME:      gravity_gun.lua
DESCRIPTION:      Half-Life style gravity gun for Halo
                  - Command: !ggun [on/off] (permission level -1)
                  - Pick up objects by aiming and shooting
                  - Launch objects with secondary fire
                  - Physics-based velocity (heavier objects move slower)
                  - Works with vehicles, weapons, equipment, and devices

                  Configurable settings:
                  - Pickup range, rotation speed, launch power
                  - Cooldown timers, mass limits
                  - Allowed object types

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG STARTS -------------------------------------------------------------
local GravityGun = {
    command = "ggun",
    permission = -1,
    distance = 4.5,
    launch_velocity = 1.2,
    rotation_speed = 0.1,
    max_weight = 1.0,           -- Maximum mass-to-velocity ratio (0.1-1.0)
    cooldown = 15,              -- Ticks between shots (15 = 0.5 seconds)
    pickup_cooldown = 5,        -- Ticks before allowing launch after pickup
    allowed_types = {           -- Object types that can be manipulated
        [1] = true, -- Vehicle
        [4] = true, -- Equipment
        [5] = true, -- Weapon
        [6] = true  -- Device
    }
}

-- CONFIG ENDS ---------------------------------------------------------------

api_version = "1.12.0.0"

local players = {}

-- Precomputed offsets
local PLAYER = {
    XYZ = 0x5C,
    VEHICLE = 0x11C,
    CROUCHING = 0x50C,
    CAMERA = 0x230,
    SHOOTING = 0x490,
    BIPED = 0x34
}

local OBJECT = {
    XYZ = 0x5C,
    VELOCITY = 0x68,
    ROTATION = 0x8C,
    FLAGS = 0x10,
    TYPE = 0xB4,
    MASS = 0x98,
    SCALE = 0xB0
}

local function get_player_xyz(dyn)
    local vehicle = read_dword(dyn + PLAYER.VEHICLE)
    if vehicle == 0xFFFFFFFF then
        local x, y, z = read_vector3d(dyn + PLAYER.XYZ)
        local crouching = read_float(dyn + PLAYER.CROUCHING)
        return x, y, crouching == 0 and z + 0.65 or z + 0.35
    end

    local object = get_object_memory(vehicle)
    if object ~= 0 then
        return read_vector3d(object + OBJECT.XYZ)
    end

    -- Fallback to player position
    local x, y, z = read_vector3d(dyn + PLAYER.XYZ)
    return x, y, z + 0.5
end

local function get_camera_vector(dyn)
    return read_vector3d(dyn + PLAYER.CAMERA)
end

local function is_shooting(dyn)
    return read_float(dyn + PLAYER.SHOOTING) == 1
end

local function object_intersect(px, py, pz, cx, cy, cz, ignore)
    local success, _, _, _, object_id = intersect(px, py, pz, cx * 1000, cy * 1000, cz * 1000, ignore)
    if not success then return nil end

    local object = get_object_memory(object_id)
    if not object or object == 0 then return nil end

    local obj_type = read_byte(object + OBJECT.TYPE)
    return GravityGun.allowed_types[obj_type] and object
end

local function calculate_velocity(mass)
    local ratio = math.min(mass / 1000, GravityGun.max_weight)
    return GravityGun.launch_velocity * (1 - ratio)
end

local function new_player(id)
    return {
        id = id,
        enabled = false,
        object = nil,
        cooldown = 0,
        pickup_timer = 0  -- Prevent immediate launch after pickup
    }
end

local function reset_player(player)
    player.object = nil
    player.cooldown = 0
    player.pickup_timer = 0
end

local function handle_command(id, cmd)
    local player = players[id]
    if not player then return false end

    local args = {}
    for arg in cmd:gmatch("%S+") do
        args[#args + 1] = arg:lower()
    end

    if #args == 0 or args[1] ~= GravityGun.command then return false end

    local state = args[2]
    local current = player.enabled
    local new_state

    if state == "on" or state == "1" or state == "true" then
        new_state = true
    elseif state == "off" or state == "0" or state == "false" then
        new_state = false
    end

    if new_state == nil then
        rprint(id, "Gravity Gun: " .. (current and "ENABLED" or "DISABLED"))
        return false
    end

    if current == new_state then
        rprint(id, "Gravity Gun already " .. (new_state and "enabled" or "disabled"))
        return false
    end

    player.enabled = new_state
    if not new_state then
        reset_player(player)
    end

    rprint(id, "Gravity Gun " .. (new_state and "ENABLED" or "DISABLED"))
    return false
end

function OnTick()
    for id, player in pairs(players) do
        if player.enabled then
            local dyn = get_dynamic_player(id)
            if not player_alive(id) or not dyn or dyn == 0 then
                reset_player(player)
            else
                -- Handle cooldowns
                if player.cooldown > 0 then player.cooldown = player.cooldown - 1 end
                if player.pickup_timer > 0 then player.pickup_timer = player.pickup_timer - 1 end

                -- Get positions
                local px, py, pz = get_player_xyz(dyn)
                local cx, cy, cz = get_camera_vector(dyn)

                -- Pick up logic (only when not holding object)
                if not player.object and is_shooting(dyn) and player.cooldown == 0 then
                    local biped = read_dword(get_player(id) + PLAYER.BIPED)
                    local object = object_intersect(px, py, pz, cx, cy, cz, biped)

                    if object then
                        -- Check mass restrictions
                        local mass = read_float(object + OBJECT.MASS)
                        if mass > 0 and mass < 5000 then
                            player.object = object
                            player.pickup_timer = GravityGun.pickup_cooldown
                        end
                    end
                end

                -- Object manipulation
                if player.object then
                    -- Calculate target position
                    local distance = GravityGun.distance
                    local x = px + distance * cx
                    local y = py + distance * cy
                    local z = pz + distance * cz

                    -- Update object position
                    write_vector3d(player.object + OBJECT.XYZ, x, y, z)

                    -- Apply anti-gravity effect
                    write_float(player.object + OBJECT.VELOCITY, 0)
                    write_float(player.object + OBJECT.VELOCITY + 4, 0)
                    write_float(player.object + OBJECT.VELOCITY + 8, 0.01285)

                    -- Rotate object
                    write_float(player.object + OBJECT.ROTATION, GravityGun.rotation_speed)
                    write_float(player.object + OBJECT.ROTATION + 4, GravityGun.rotation_speed)
                    write_float(player.object + OBJECT.ROTATION + 8, GravityGun.rotation_speed)

                    -- Clear physics flags
                    write_bit(player.object + OBJECT.FLAGS, 0, 0)  -- Sleep flag
                    write_bit(player.object + OBJECT.FLAGS, 5, 0)  -- At rest flag

                    -- Launch logic (only after pickup cooldown)
                    if is_shooting(dyn) and player.cooldown == 0 and player.pickup_timer == 0 then
                        local mass = read_float(player.object + OBJECT.MASS)
                        local velocity = calculate_velocity(mass)

                        write_vector3d(player.object + OBJECT.VELOCITY,
                            cx * velocity,
                            cy * velocity,
                            cz * velocity
                        )

                        reset_player(player)
                        player.cooldown = GravityGun.cooldown
                    end
                end
            end
        end
    end
end

function OnScriptLoad()
    register_callback(cb["EVENT_TICK"], "OnTick")
    register_callback(cb["EVENT_JOIN"], "OnJoin")
    register_callback(cb["EVENT_LEAVE"], "OnQuit")
    register_callback(cb["EVENT_SPAWN"], "OnSpawn")
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    register_callback(cb["EVENT_GAME_START"], "OnStart")
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    players = {}
    for i = 1, 16 do
        if player_present(i) then
            players[i] = new_player(i)
        end
    end
end

function OnJoin(id)
    players[id] = new_player(id)
end

function OnSpawn(id)
    if players[id] then
        reset_player(players[id])
    end
end

function OnQuit(id)
    players[id] = nil
end

function OnCommand(id, cmd)
    return handle_command(id, cmd)
end

function OnScriptUnload() end