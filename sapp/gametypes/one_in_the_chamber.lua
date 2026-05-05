--[[
=====================================================================================
SCRIPT NAME:      one_in_the_chamber.lua
DESCRIPTION:      Intense pistol duel mode where every shot counts:
                  - Players start with one bullet (guaranteed one-shot kill)
                  - Earn bullets by eliminating opponents
                  - Switch to melee when out of ammo
                  - High-risk, high-reward gameplay

Copyright (c) 2023-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- START Config ---------------------------------------
local STARTING_PRIMARY_AMMO = 1
local STARTING_SECONDARY_AMMO = 0
local AMMO_PER_KILL = 1
local STARTING_FRAGS = 0
local STARTING_PLASMAS = 0
local WEAPON = 'weapons\\pistol\\pistol'
-- END Config -----------------------------------------

api_version = '1.12.0.0'

local weapon_id
local base_tag_table = 0x40440000

local function getTag(Type, Name)
    local tag = lookup_tag(Type, Name)
    return tag ~= 0 and read_dword(tag + 0xC) or nil
end

local function disableMapObjects()
    local tag_array = read_dword(base_tag_table)
    local tag_count = read_dword(base_tag_table + 0xC)
    for i = 0, tag_count - 1 do
        local tag = tag_array + 0x20 * i
        local class = read_dword(tag)
        if class == 0x76656869 or class == 0x77656170 or class == 1701931376 then
            local name_ptr = read_dword(tag + 0x10)
            local tag_name = (name_ptr ~= 0) and read_string(name_ptr) or "<no-name>"
            local tag_data = read_dword(tag + 0x14)
            if tag_data ~= 0 then
                execute_command("disable_object '" .. tag_name .. "'")
            end
        end
    end
end

local function setAmmo(player, ammoType, amount)
    local command = (ammoType == 'unloaded') and 'ammo' or 'mag'
    for i = 1, 4 do
        execute_command(command .. ' ' .. player .. ' ' .. amount .. ' ' .. i)
    end
end

-- Event Handlers
function OnScriptLoad()
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    weapon_id = getTag('weap', WEAPON)

    if not weapon_id then
        unregister_callback(cb['EVENT_DIE'])
        unregister_callback(cb["EVENT_SPAWN"])
        unregister_callback(cb['EVENT_DAMAGE_APPLICATION'])
        return
    end

    execute_command("disable_all_vehicles 0 1")
    disableMapObjects()

    register_callback(cb['EVENT_DIE'], "OnKill")
    register_callback(cb["EVENT_SPAWN"], "OnSpawn")
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], "OnDamage")
end

function OnKill(victimId, killerId)
    killerId, victimId = tonumber(killerId), tonumber(victimId)
    if killerId > 0 and killerId ~= victimId then
        setAmmo(killerId, 'loaded', AMMO_PER_KILL)
    end
end

function OnSpawn(id)
    execute_command('wdel ' .. id)
    execute_command('nades ' .. id .. ' ' .. STARTING_FRAGS .. ' 1')
    execute_command('nades ' .. id .. ' ' .. STARTING_PLASMAS .. ' 2')

    assign_weapon(spawn_object('', '', 0, 0, 0, 0, weapon_id), id)

    setAmmo(id, 'loaded', STARTING_PRIMARY_AMMO)
    setAmmo(id, 'unloaded', STARTING_SECONDARY_AMMO)
end

function OnDamage(victim, causer, _, damage)
    if causer > 0 and victim ~= causer then return true, damage * 10 end
end

function OnScriptUnload() end
