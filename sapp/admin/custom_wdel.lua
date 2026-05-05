--[[
===============================================================================
SCRIPT NAME:      custom_wdel.lua
DESCRIPTION:      Enhanced weapon deletion command that:
                  - Prevents accidental deletion of objective items (flags/oddballs)
                  - Maintains standard weapon removal functionality
                  - Provides admin permission controls

FEATURES:
                  - Safe weapon-only deletion
                  - Multiple target selection (player ID, "me", "all")
                  - Configurable admin requirements

CONFIGURATION:    Adjust these settings:
                  - command: Custom command name
                  - permission_required: Minimum admin level

Copyright (c) 2021-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- config starts --

-- Custom command used to remove weapons:
-- Syntax: /command "me", "all", "*" or [#1-16]
-- Example: /wdel 1, or /wdel me, or /wdel *
local command = 'wdel'

-- Permission level required to execute the custom command
local permission_required = 1
-- config ends --

api_version = '1.12.0.0'

function OnScriptLoad()
    register_callback(cb['EVENT_COMMAND'], 'DeleteWeapons')
end

local function Respond(Ply, Msg)
    return (Ply == 0 and cprint(Msg) or rprint(Ply, Msg))
end

local function GetPlayers(Ply, Args)

    local t = { }
    local player = Args[2]

    if (player == nil or player == 'me') then
        t[#t + 1] = Ply
    elseif (player == 'all' or player == '*') then
        for i = 1, 16 do
            if player_present(i) then
                t[#t + 1] = i
            end
        end
    elseif (player:match('%d+') and tonumber(player:match('%d+')) > 0) then
        if player_present(player) then
            t[#t + 1] = player
        else
            Respond(Ply, 'Player #' .. player .. ' is not online!')
        end
    else
        Respond(Ply, 'Invalid Player ID')
        Respond(Ply, 'Usage: "me", "all", "*" or [#1-16]')
    end

    return t
end

local function GetWeapons(dyn)
    local weapons = { }
    for i = 0, 3 do
        local weapon = read_dword(dyn + 0x2F8 + 0x4 * i)
        local object = get_object_memory(weapon)
        if (weapon ~= 0xFFFFFFFF and object ~= 0) then
            local tag_address = read_word(object)
            local tag_data = read_dword(read_dword(0x40440000) + tag_address * 0x20 + 0x14)
            if (read_bit(tag_data + 0x308, 3) ~= 1) then
                weapons[#weapons + 1] = weapon
            end
        end
    end
    return weapons
end

local function HasPerm(Ply)
    local lvl = tonumber(get_var(Ply, '$lvl'))
    return (Ply == 0 or lvl >= permission_required)
end

local function CMDSplit(s)
    local t = { }
    for arg in s:gmatch('([^%s]+)') do
        t[#t + 1] = arg:lower()
    end
    return t
end

function DeleteWeapons(Ply, CMD)

    local args = CMDSplit(CMD)
    if (#args > 0 and args[1] == command) then

        if (HasPerm(Ply)) then
            local players = GetPlayers(Ply, args)
            if (players) then

                for _,player in pairs(players) do

                    local name = get_var(player, '$name')

                    local dyn = get_dynamic_player(player)
                    if (player_alive(player) and dyn ~= 0) then

                        local weapons = GetWeapons(dyn)
                        if (#weapons > 0) then
                            for j = 1, #weapons do
                                destroy_object(weapons[j])
                            end
                            Respond(Ply, name .. "'s weapons have been removed.")
                        end
                    else
                        Respond(Ply, name .. ' is not alive.')
                    end
                end
            end
        else
            Respond(Ply, 'You do not have permission to execute this command.')
        end
        return false
    end
end

function OnScriptUnload()
    -- N/A
end