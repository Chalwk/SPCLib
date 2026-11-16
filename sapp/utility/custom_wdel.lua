--[[
===============================================================================
SCRIPT NAME:    custom_wdel.lua
DESCRIPTION:    Removes a player's non-objective weapons while protecting flags
                and oddballs. Supports self, all players, and player IDs.

Copyright (c) 2021-2026 Jericho Crosby (Chalwk)
LICENSE:        MIT License
                https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- CONFIG START

-- Syntax: /wdel [me|all|*|1-16]
local COMMAND = "wdel"

-- Minimum admin level required. The server console is always allowed.
local REQUIRED_PERMISSION = 1

-- CONFIG END

api_version = "1.12.0.0"

local function tell(player_id, message)
    if player_id == 0 then
        cprint(message)
    else
        rprint(player_id, message)
    end
end

local function hasPermission(player_id)
    if player_id == 0 then return true end
    return tonumber(get_var(player_id, "$lvl")) >= REQUIRED_PERMISSION
end

local function parseCommand(command)
    local args = {}
    for arg in command:gmatch("%S+") do
        args[#args + 1] = arg
    end
    return args
end

local function getTargets(executor_id, target_arg)
    local targets = {}
    local target = target_arg and target_arg:lower() or "me"

    if target == "me" then
        if executor_id == 0 then
            return nil, "You must specify a player ID or 'all'."
        end
        targets[1] = executor_id
    elseif target == "all" or target == "*" then
        for player_id = 1, 16 do
            if player_present(player_id) then
                targets[#targets + 1] = player_id
            end
        end
    else
        local player_id = tonumber(target)
        if not player_id or player_id % 1 ~= 0 or player_id < 1 or player_id > 16 then
            return nil, "Invalid target. Usage: /" .. COMMAND .. " [me|all|*|1-16]"
        end
        if not player_present(player_id) then
            return nil, "Player #" .. player_id .. " is not online."
        end
        targets[1] = player_id
    end

    return targets
end

local function getNonObjectiveWeapons(dynamic_player)
    local weapons = {}
    local tag_array = read_dword(0x40440000)
    if not tag_array or tag_array == 0 then return weapons end

    for slot = 0, 3 do
        local weapon_id = read_dword(dynamic_player + 0x2F8 + (slot * 4))
        if weapon_id ~= 0xFFFFFFFF then
            local weapon_object = get_object_memory(weapon_id)
            if weapon_object ~= 0 then
                local tag_index = read_word(weapon_object)
                local tag_entry = tag_array + (tag_index * 0x20)
                local tag_data = read_dword(tag_entry + 0x14)

                -- Weapon tags with the objective bit set are flags or oddballs.
                if tag_data ~= 0 and read_bit(tag_data + 0x308, 3) ~= 1 then
                    weapons[#weapons + 1] = weapon_id
                end
            end
        end
    end

    return weapons
end

local function deleteWeapons(executor_id, target_arg)
    if not hasPermission(executor_id) then
        tell(executor_id, "You do not have permission to use this command.")
        return
    end

    local targets, err = getTargets(executor_id, target_arg)
    if not targets then
        tell(executor_id, err)
        return
    end

    for _, player_id in ipairs(targets) do
        local name = get_var(player_id, "$name")
        local dynamic_player = get_dynamic_player(player_id)

        if not player_alive(player_id) or dynamic_player == 0 then
            tell(executor_id, name .. " is not alive.")
            goto next_player
        end

        local weapons = getNonObjectiveWeapons(dynamic_player)
        for _, weapon_id in ipairs(weapons) do
            destroy_object(weapon_id)
        end

        if #weapons > 0 then
            tell(executor_id, name .. "'s weapons have been removed.")
        else
            tell(executor_id, name .. " has no removable weapons.")
        end

        ::next_player::
    end
end

function OnCommand(executor_id, command)
    local args = parseCommand(command)
    if #args == 0 or args[1]:lower() ~= COMMAND:lower() then return true end

    if #args > 2 then
        tell(executor_id, "Usage: /" .. COMMAND .. " [me|all|*|1-16]")
    else
        deleteWeapons(executor_id, args[2])
    end

    return false
end

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "OnCommand")
end

function OnScriptUnload() end
