--[[
=====================================================================================
SCRIPT NAME:      items_from_heaven.lua
DESCRIPTION:      Random item/vehicle spawn system
                  - Spawns weapons and vehicles at random map locations
                  - Configurable spawn frequency (10-60 seconds by default)
                  - Automatic cleanup of unused items (30 second despawn timer)
                  - Map-specific spawn coordinates (pre-configured for Blood Gulch)
                  - Supports all standard weapons and vehicles

                  Features:
                  - Dynamic spawn intervals (randomized between min/max)
                  - Items spawn at specified heights above ground
                  - Vehicles despawn when unused
                  - Weapons persist while held by players

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts --
-- How often should we spawn an object (in seconds)?
local min = 10
local max = 60

-- While an object is not being interacted with, how long until it de-spawns?
local half_life = 30

-- This is an array of items that will spawn spawned:
--
local items = {

    -- vehicle objects --
    { "vehi", "vehicles\\ghost\\ghost_mp" },
    { "vehi", "vehicles\\rwarthog\\rwarthog" },
    { "vehi", "vehicles\\banshee\\banshee_mp" },
    { "vehi", "vehicles\\c gun turret\\c gun turret_mp" },
    { "vehi", "vehicles\\warthog\\mp_warthog", "Warthog" },
    { "vehi", "vehicles\\scorpion\\scorpion_mp" },

    -- weapon objects --
    { "weap", "weapons\\gravity rifle\\gravity rifle" },
    { "weap", "weapons\\flag\\flag" },
    { "weap", "weapons\\ball\\ball" },
    { "weap", "weapons\\pistol\\pistol" },
    { "weap", "weapons\\shotgun\\shotgun" },
    { "weap", "weapons\\needler\\mp_needler" },
    { "weap", "weapons\\plasma rifle\\plasma rifle" },
    { "weap", "weapons\\flamethrower\\flamethrower" },
    { "weap", "weapons\\plasma_cannon\\plasma_cannon" },
    { "weap", "weapons\\plasma pistol\\plasma pistol" },
    { "weap", "weapons\\assault rifle\\assault rifle" },
    { "weap", "weapons\\sniper rifle\\sniper rifle" },
    { "weap", "weapons\\rocket launcher\\rocket launcher" },
}

local coordinates = {
    ["bloodgulch"] = {

        -- {x,y,z,height above the surface)

        { 34.964138031006, -83.497467041016, 0.038491830229759, 35 },
        { 44.647392272949, -86.807655334473, 0.0082822889089584, 35 },
        { 46.195606231689, -93.426376342773, 1.0764836072922, 35 },
        { 62.467247009277, -107.68267822266, 3.0117502212524, 35 },
        { 77.337089538574, -115.42254638672, 1.4317927360535, 35 },
        { 80.265563964844, -125.56439208984, 0.32580471038818, 35 },
        { 73.183158874512, -141.03010559082, 2.8756811618805, 35 },
        { 68.247161865234, -148.23875427246, 4.2010931968689, 35 },
        { 72.263076782227, -158.02416992188, 0.59069782495499, 35 },
        { 81.473442077637, -164.65151977539, 0.80858880281448, 35 },
        { 86.213737487793, -168.29141235352, 0.56051832437515, 35 },
        { 100.29655456543, -166.33018493652, 0.90130609273911, 35 },
        { 107.63474273682, -150.76184082031, 0.65446490049362, 35 },
        { 103.05908203125, -135.2099609375, 1.9275138378143, 35 },
        { 92.875076293945, -124.18204498291, 2.3354911804199, 35 },
        { 76.690071105957, -119.71539306641, 0.86159378290176, 35 },
        { 57.201026916504, -123.2013092041, 0.63535797595978, 35 },
        { 50.516471862793, -124.39450836182, 0.008850485086441, 35 },
        { 43.485145568848, -121.78145599365, 1.3898348808289, 35 },
        { 38.032375335693, -113.43714904785, 2.3637220859528, 35 },
        { 33.453273773193, -107.18868255615, 3.025857925415, 35 },
        { 27.854064941406, -97.263809204102, 2.3833355903625, 35 },
        { 28.759851455688, -73.526336669922, 1.0468406677246, 35 },
    },
    ["beavercreek"] = {

    },
    ["boardingaction"] = {

    },
    ["carousel"] = {

    },
    ["chillout"] = {

    },
    ["dangercanyon"] = {

    },
    ["deathisland"] = {

    },
    ["gephyrophobia"] = {

    },
    ["icefields"] = {

    },
    ["infinity"] = {

    },
    ["sidewinder"] = {

    },
    ["timberland"] = {

    },
    ["hangemhigh"] = {

    },
    ["ratrace"] = {

    },
    ["damnation"] = {

    },
    ["putput"] = {

    },
    ["prisoner"] = {

    },
    ["wizard"] = {

    },
    ["longest"] = {

    }
}
-- config ends --

local coords
local game_started

local interval = 0
local spawn_timer = 0

local objects = { }
local time_scale = 1 / 30
local gmatch, lower = string.gmatch, string.lower

api_version = "1.12.0.0"

function OnScriptLoad()
    register_callback(cb.EVENT_TICK, "OnTick")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_COMMAND, "OnServerCommand")
    OnGameStart()
end

local function NewInterval()
    spawn_timer = 0
    math.randomseed(os.clock())
    interval = math.random(min, max)
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then

        OnScriptUnload(true)

        game_started = true
        coords = nil

        local map = get_var(0, "$map")
        coords = coordinates[map] ~= nil and coordinates[map]
    end
end

local function Delete(Object)
    destroy_object(Object)
    objects[Object] = nil
end

function OnTick()
    if (game_started and coords) then

        spawn_timer = spawn_timer + time_scale

        if (spawn_timer >= interval) then
            NewInterval()
            math.randomseed(os.clock())
            local pos = coords[math.random(1, #coords)]
            local item = items[math.random(1, #items)]
            local object = spawn_object(item[1], item[2], pos[1], pos[2], pos[3] + pos[4])
            local object_memory = get_object_memory(object)
            table.insert(objects, { tag_type = item, object_memory = object_memory, object = object, timer = 0 })
        end

        for k, v in pairs(objects) do
            if (k) then
                if (v.tag_type[1] == "vehi") then
                    if (v.object_memory ~= 0xFFFFFFFFF) then
                        v.timer = v.timer + time_scale
                        if (v.timer >= half_life) then
                            Delete(k)
                        end
                    else
                        v.timer = 0
                    end
                elseif (v.tag_type[1] == "weap") then
                    local held
                    for i = 1, 16 do
                        if player_alive(i) and player_present(i) then
                            local DyN = get_dynamic_player(i)
                            for j = 0, 3 do
                                local WeaponID = read_dword(DyN + 0x2F8 + (j * 4))
                                local WeaponObject = get_object_memory(WeaponID)
                                if (WeaponID ~= 0xFFFFFFFF and WeaponObject == v.object_memory) then
                                    held = true
                                end
                            end
                        end
                    end
                    if (not held) then
                        v.timer = v.timer + time_scale
                        if (v.timer >= half_life) then
                            Delete(k)
                        end
                    else
                        v.timer = 0
                    end
                end
            else
                Delete(k)
            end
        end
    end
end

local function CMDSplit(CMD)
    local Args = { }
    for Params in gmatch(CMD, "([^%s]+)") do
        Args[#Args + 1] = lower(Params)
    end
    return Args
end

function OnServerCommand(Ply, Command)
    local Args = CMDSplit(Command)
    local access = (tonumber(get_var(Ply, "$lvl")) == 4)
    if (access) and (Args and Args[1] == "sv_map_reset") then
        OnScriptUnload(true)
    end
end

function OnScriptUnload(NewTime)

    if (NewTime) then
        NewInterval()
    end

    for k, _ in pairs(objects) do
        Delete(k)
    end
end