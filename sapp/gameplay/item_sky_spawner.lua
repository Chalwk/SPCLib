--[[
===============================================================================
SCRIPT NAME:      item_sky_spawner.lua
DESCRIPTION:      Random item spawner that drops weapons/vehicles from the sky:
                  - Configurable spawn locations per map
                  - Random item selection
                  - Automatic cleanup system

FEATURES:
                  - Randomized spawn timing
                  - Item persistence controls
                  - Height-adjustable spawns
                  - Support for all weapon/vehicle types

CONFIGURATION:    Adjust these settings:
                  - min/max: Spawn time range (seconds)
                  - height_from_ground: Drop height
                  - items: List of spawnable objects
                  - coordinates: Map-specific drop points

Copyright (c) 2021 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- config starts --
-- How often should we spawn an object (in seconds)?
local min = 5
local max = 60

-- While an object is not being interacted with, how long until it de-spawns?
local half_life = 30

-- Height from ground that objects will spawn (in world units)
local height_from_ground = 30

local items = {
    { "vehi", "vehicles\\ghost\\ghost_mp" },
    { "vehi", "vehicles\\rwarthog\\rwarthog" },
    { "vehi", "vehicles\\banshee\\banshee_mp" },
    { "vehi", "vehicles\\c gun turret\\c gun turret_mp" },
    { "vehi", "vehicles\\warthog\\mp_warthog", "Warthog" },
    { "vehi", "vehicles\\scorpion\\scorpion_mp" },

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
        { 41.101623535156, -90.281707763672, 0.12476693093777 },
        { 46.077514648438, -90.439193725586, 0.77358269691467 },
        { 56.91703414917, -101.42024993896, 0.076191321015358 },
        { 65.814765930176, -104.81482696533, 1.938010931015 },
        { 73.550834655762, -111.81549835205, 2.6525256633759 },
        { 77.765007019043, -125.80402374268, 0.71494293212891 },
        { 74.582389831543, -139.28483581543, 1.9513947963715 },
        { 85.483337402344, -163.49174499512, 0.11511813104153 },
        { 103.53232574463, -173.73710632324, 0.74547308683395 },
        { 109.66470336914, -163.90553283691, 0.10314647853374 },
        { 105.28534698486, -155.08737182617, 0.67522388696671 },
        { 93.378700256348, -145.28199768066, 0.31651598215103 },
        { 88.151893615723, -142.88500976563, 1.4771356582642 },
        { 78.458541870117, -138.9543762207, 3.5617597103119 },
        { 73.147125244141, -136.68130493164, 3.500504732132 },
        { 56.038143157959, -131.96516418457, 2.0096452236176 },
        { 47.858089447021, -125.94813537598, 1.7084130048752 },
        { 37.010986328125, -106.34159088135, 1.9382441043854 },
        { 23.565832138062, -77.041366577148, 0.90631490945816 },
        { 26.064079284668, -59.849906921387, 3.1582815647125 },
        { 36.09298324585, -56.705558776855, 3.3356153964996 },
        { 49.803821563721, -61.756992340088, 2.4028491973877 },
        { 62.824329376221, -78.13745880127, 1.5507658720016 },
    }
}

-- config starts --

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
            local object = spawn_object(item[1], item[2], pos[1], pos[2], pos[3] + height_from_ground)
            local object_memory = get_object_memory(object)
            table.insert(objects, { tag_type = item, object_memory = object_memory, object = object, timer = 0 })
        end

        for k, v in pairs(objects) do
            if (k and v.object_memory ~= 0) then
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
                                if (WeaponID ~= 0xFFFFFFFF) then
                                    local WeaponObject = get_object_memory(WeaponID)
                                    if (WeaponObject == v.object_memory) then
                                        held = true
                                    end
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