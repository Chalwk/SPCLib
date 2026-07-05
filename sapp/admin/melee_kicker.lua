--[[
=====================================================================================
SCRIPT NAME:      melee_kicker.lua
DESCRIPTION:      Forces instant kick for players killed by melee attacks
                  - Applies to all melee weapon types (including flag/ball melee)
                  - Optional admin-only restriction
                  - Lightweight implementation with minimal configuration

                  WARNING:
                  This is a novelty script designed for fun servers and custom gametypes.
                  Not recommended for competitive play.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- Config [STARTS] -----------------------

-- If true, then only admins can melee-kick other players (FALSE BY DEFAULT)
local admins_only = false

-- Config [ENDS] -------------------------

api_version = "1.12.0.0"

local content = {}

function OnScriptLoad()
    register_callback(cb.EVENT_DIE, "OnPlayerDeath")
    register_callback(cb.EVENT_SPAWN, "OnPlayerSpawn")
    register_callback(cb.EVENT_JOIN, "OnPlayerConnect")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_LEAVE, "OnPlayerDisconnect")
    register_callback(cb.EVENT_DAMAGE_APPLICATION, "OnDamageApplication")
    if (get_var(0, "$gt") ~= "n/a") then
        MeleeTagAddresses()
        for i = 1, 16 do
            if player_present(i) then
                InitPlayer(i, false)
            end
        end
    end
end

function OnGameStart()
    if (get_var(0, "$gt") ~= "n/a") then
        MeleeTagAddresses()
    end
end

function OnPlayerConnect(PlayerIndex)
    InitPlayer(PlayerIndex, false)
end

function OnPlayerSpawn(PlayerIndex)
    content.last_damage[PlayerIndex] = 0
end

function OnPlayerDisconnect(PlayerIndex)
    InitPlayer(PlayerIndex, true)
end

function OnPlayerDeath(VictimIndex, KillerIndex)
    local killer, victim = tonumber(KillerIndex), tonumber(VictimIndex)
    if (killer > 0) and (killer ~= victim) then
        for i = 1, #content.melee_tags do
            if (content.last_damage[victim] == content.melee_tags[i]) then
                execute_command("k " .. victim)
            end
        end
    end
end

function OnDamageApplication(VictimIndex, CauserIndex, MetaID, _, _, _)
    if (tonumber(CauserIndex) <= 0) then return end
    if Validate(CauserIndex) then
        content.last_damage[VictimIndex] = MetaID
    end
end

function MeleeTagAddresses()
    content = {
        melee_tags = {

            GetTag("jpt!", "weapons\\flag\\melee"),
            GetTag("jpt!", "weapons\\ball\\melee"),
            GetTag("jpt!", "weapons\\pistol\\melee"),
            GetTag("jpt!", "weapons\\needler\\melee"),
            GetTag("jpt!", "weapons\\shotgun\\melee"),
            GetTag("jpt!", "weapons\\flamethrower\\melee"),
            GetTag("jpt!", "weapons\\sniper rifle\\melee"),
            GetTag("jpt!", "weapons\\plasma rifle\\melee"),
            GetTag("jpt!", "weapons\\plasma pistol\\melee"),
            GetTag("jpt!", "weapons\\assault rifle\\melee"),
            GetTag("jpt!", "weapons\\rocket launcher\\melee"),
            GetTag("jpt!", "weapons\\plasma_cannon\\effects\\plasma_cannon_melee")
        },
        last_damage = {}
    }
end

function GetTag(Type, Name)
    local tag = lookup_tag(Type, Name)
    return (tag ~= 0 and read_dword(tag + 0xC)) or nil
end

function InitPlayer(PlayerIndex, Reset)
    if (Reset) then
        content.last_damage[PlayerIndex] = nil
    else
        content.last_damage[PlayerIndex] = 0
    end
end

function Validate(Killer)
    local lvl = tonumber(get_var(Killer, "$lvl"))
    if (lvl >= 1 or admins_only == false) then
        return true
    end
    return false
end

function OnScriptUnload()
end
