--[[
=====================================================================================
SCRIPT NAME:      one_in_the_chamber.lua
DESCRIPTION:      Pistol duel mode where every shot counts:
                  - Players start with one bullet
                  - Earn bullets by eliminating opponents
                  - Switch to melee when out of ammo
                  - High-risk, high-reward gameplay

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start ---------------------------------------
local WEAPON = 'weapons\\pistol\\pistol'
local STARTING_PRIMARY_AMMO = 1
local STARTING_SECONDARY_AMMO = 0
local AMMO_PER_KILL = 1
local STARTING_FRAGS = 0
local STARTING_PLASMAS = 0
-- CONFIG end -----------------------------------------

local pistol_bullet_tag, weapon_tag

local function set_pistol_ammo(player_id, clip, reserve)
    local player_object = getplayer(player_id)
    if not player_object then return end

    local weapon_id = readdword(player_object + 0x118)
    local weapon_mem = getobject(weapon_id)
    if weapon_mem == 0 then return end

    writeword(weapon_mem + 0x2B8, clip)
    writeword(weapon_mem + 0x2B6, reserve)
    updateammo(weapon_id)
end

local function clear_weapons(player_object)
    for i = 0, 3 do
        local weapon_id = readdword(player_object + 0x2F8 + i * 4)
        local weapon_object = getobject(weapon_id)
        if weapon_object then destroyobject(weapon_id) end
    end
end

local function set_grenades(player_object, frags, plasmas)
    writebyte(player_object + 0x31E, frags)
    writebyte(player_object + 0x31F, plasmas)
end

local function is_alive(player_id)
    return getplayerobjectid(player_id) ~= nil
end

function SetupInventory(_, _, player_id)
    if not weapon_tag then return end

    local obj_id = getplayerobjectid(player_id)
    if not obj_id then return end

    local player_object = getobject(obj_id)
    if not player_object then return end

    clear_weapons(player_object)
    set_grenades(player_object, STARTING_FRAGS, STARTING_PLASMAS)

    local pistol = createobject(weapon_tag, 0, 0, false, 0, 0, 0)
    if pistol == 0 then return end

    local weapon_mem = getobject(pistol)
    if weapon_mem == 0 then return end

    assignweapon(player_id, pistol)

    writeword(weapon_mem + 0x2B8, STARTING_PRIMARY_AMMO)
    writeword(weapon_mem + 0x2B6, STARTING_SECONDARY_AMMO)
    updateammo(pistol)
    return false
end

function OnScriptLoad() end

function OnNewGame()
    weapon_tag = gettagid("weap", WEAPON)
    pistol_bullet_tag = gettagid("jpt!", "weapons\\pistol\\bullet")
end

function OnPlayerSpawn(player_id)
    registertimer(50, "SetupInventory", player_id)
end

function OnPlayerKill(killer, victim, mode)
    if not weapon_tag or mode ~= 4 then return end
    if killer == nil or killer == victim or killer < 0 then return end
    if not is_alive(killer) then return end
    set_pistol_ammo(killer, AMMO_PER_KILL, STARTING_SECONDARY_AMMO)
end

function OnDamageLookup(_, _, mapId, _)
    if mapId == pistol_bullet_tag then odl_flags(2, 1) end
end

function OnScriptUnload() end

function GetRequiredVersion() return 200 end
