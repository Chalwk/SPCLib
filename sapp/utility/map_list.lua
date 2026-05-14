--[[
===============================================================================
SCRIPT NAME:      map_list.lua
DESCRIPTION:      Map rotation information system with:
                  - Current/next map display
                  - Position lookup functionality
                  - Clean output formatting

FEATURES:
                  - Reads from mapcycle.txt
                  - Two command interfaces:
                    * /maplist - Shows current and next map
                    * /whatis [num] - Shows specific rotation position
                  - Automatic mode detection

USAGE:
                  /maplist       - Shows current and upcoming maps
                  /whatis [num]  - Shows details for specific rotation slot

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

local map_list_command = "maplist"
local what_is_next_command = "whatis"
local output = {
    "Current Map: $map ($mode) | Pos: ($pos/$total)",
    "Next Map: $map ($mode) | Pos: ($pos/$total)",
    "$map ($mode) | Pos: $pos/$total"
}

local map, mode, maps = {}, {}

local function STRSplit(CMD, Delim)
    local Args = {}
    for word in CMD:gsub('"', ""):gmatch("([^" .. Delim .. "]+)") do
        Args[#Args + 1] = word:lower()
    end
    return Args
end

function OnScriptLoad()
    local cg_dir = read_string(read_dword(sig_scan("68??????008D54245468") + 0x1))
    local file = io.open(cg_dir .. "\\sapp\\mapcycle.txt")
    if file then
        for entry in file:lines() do
            local args = STRSplit(entry, ":")
            maps[#maps + 1] = { map = args[1], mode = args[2] }
        end
        file:close()
        --register_callback(cb.EVENT_COMMAND, "OnCommand")
        --register_callback(cb.EVENT_GAME_START, "OnStart")
        --OnStart()
    end
end

local function Say(Ply, Msg)
    return (Ply == 0 and cprint(Msg, 10) or rprint(Ply, Msg))
end

local function FormatTxt(Str, Pos, Map, Mode, Total)
    return Str:gsub("$pos", Pos):gsub("$map", Map):gsub("$mode", Mode):gsub("$total", Total)
end

local function GetNextMap(i)
    i = i + 1
    return { maps[i] or maps[1], maps[i] and i or 1 }
end

local function ShowCurrentMap(Ply)
    for i, t in pairs(maps) do
        if map == t.map and mode == t.mode then
            local next_map = GetNextMap(i)
            Say(Ply, FormatTxt(output[1], i, t.map, t.mode, #maps))
            return next_map
        end
    end
    Say(Ply, "Unable to display map info.\nCurrent map and/or mode is not configured in mapcycle.txt.")
end

local function ShowNextMap(Ply, next_map)
    local t, i = next_map[1], next_map[2]
    Say(Ply, FormatTxt(output[2], i, t.map, t.mode, #maps))
end

function OnCommand(Ply, CMD)
    local Args = STRSplit(CMD, "%s")
    if Args[1] == map_list_command then
        local next_map = ShowCurrentMap(Ply)
        if next_map then ShowNextMap(Ply, next_map) end
        return false
    elseif Args[1] == what_is_next_command and Args[2] and Args[2]:match("%d+") then
        local i = tonumber(Args[2])
        local t = maps[i]
        if t then
            Say(Ply, FormatTxt(output[3], i, t.map, t.mode, #maps))
        else
            Say(Ply, "Please enter a number between 1/" .. #maps)
        end
        return false
    end
end

function OnStart()
    if get_var(0, "$gt") ~= "n/a" then
        map = get_var(0, "$map"):lower()
        mode = get_var(0, "$mode"):lower()
    end
end

function OnScriptUnload()
    -- N/A
end