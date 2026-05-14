--[[
=====================================================================================
SCRIPT NAME:      random_name.lua
DESCRIPTION:      Replaces player names with random names from predefined categories.
                  Configure name pools in the script's CONFIG section.

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]
-- CONFIG STARTS ------------------------------
local names = {
    ["ADuck"] = {
        { "Halo" }, { "Cortana" }, { "MasterChief" }, { "Covenant" }, { "Flood" },
        { "Grunt" }, { "Elite" }, { "Brute" }, { "Jackal" }, { "Hunter" },
        { "Prophet" }, { "Monitor" }, { "Sentinel" }, { "Spartan" }, { "ODST" },
        { "Marine" }, { "Pilot" }, { "Engineer" }
    },
    ["AGuy"] = {
        { "NewName1" }, { "NewName2" }
    }
}
-- CONFIG ENDS ------------------------------

api_version = "1.12.0.0"

local players = {}
local network_struct, ce
local byte = string.byte

function OnScriptLoad()
    network_struct = read_dword(sig_scan("F3ABA1????????BA????????C740??????????E8????????668B0D") + 3)
    ce = (halo_type == 'PC' and 0x0 or 0x40)
    math.randomseed(os.clock())
    register_callback(cb.EVENT_GAME_START, "OnStart")
    register_callback(cb.EVENT_LEAVE, "OnQuit")
    register_callback(cb.EVENT_PREJOIN, "OnPreJoin")
    OnStart()
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    for _, category in pairs(names) do
        for i = 1, #category do
            category[i].taken = false
        end
    end
end

local function get_random_name(id)
    local player_name = get_var(id, "$name")
    local category = names[player_name]
    if not category then return false end

    local available = {}
    for i, entry in ipairs(category) do
        if not entry.taken then
            available[#available + 1] = {name = entry[1], index = i}
        end
    end

    if #available > 0 then
        local selected = available[math.random(1, #available)]
        category[selected.index].taken = true
        players[id] = {player_name, selected.index}
        return selected.name
    end
    return false
end

function OnPreJoin(id)
    local new_name = get_random_name(id)
    if new_name then
        local address = network_struct + 0x1AA + ce + to_real_index(id) * 0x20
        for i = 0, 12 - 1 do
            write_byte(address + i * 2, 0)
        end
        for i = 1, #new_name do
            write_byte(address + (i - 1) * 2, byte(new_name, i))
        end
    end
end

function OnQuit(id)
    if players[id] then
        local original_name, name_index = players[id][1], players[id][2]
        names[original_name][name_index].taken = false
        players[id] = nil
    end
end