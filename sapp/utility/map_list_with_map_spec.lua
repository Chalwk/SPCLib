--[[
===============================================================================
SCRIPT NAME:      map_list_with_map_spec.lua
DESCRIPTION:      Enhanced map rotation tracker with:
                  - Current/next map display
                  - Position-based map queries
                  - Map specification index tracking
                  - Cycle completion detection

FEATURES:
                  - Reads from mapcycle.txt
                  - Two command interfaces:
                    * /maplist - Shows current and next map
                    * /whatis [num] - Shows details for specific position
                  - Tracks played maps in current cycle

CONFIGURATION:    Adjust these settings:
                  - map_list_command: Main command trigger
                  - what_is_next_command: Position query command
                  - output: Customize message formats

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- config starts --

-- Command to show current/next map & mode:
-- Syntax: /command
--
local map_list_command = "maplist"

-- Command to show map & mode at specific map cycle position:
-- Syntax: /command [pos]
--
local what_is_next_command = "whatis"

-- Customizable message output:
--
local output = {

    -- Placeholders:
    -- $map   = map name
    -- $mode  = game mode
    -- $pos   = map cycle position
    -- $total = total number of maps in mapcycle.txt

    -- Message output when you type /map_list_command:
    --
    "Current Map: $map ($mode) | Map Spec Index: ($pos/$total)",
    "Next Map: $map ($mode) | Map Spec Index: ($pos/$total)",

    -- Message output when you type /what_is_next_command:
    --
    "$map ($mode) | Map Spec Index: $pos/$total"
}

-- config ends --

local map, mode
local maps = {}
local map_spec_index

api_version = '1.12.0.0'

local function parseArgs(msg, delim)
    local args = {}
    for word in msg:gsub('"', ""):gmatch("([^" .. delim .. "]+)") do
        args[#args + 1] = word:lower()
    end

    return args
end

local function getMapcycleDir()
    local path = read_string(read_dword(sig_scan("68??????008D54245468") + 0x1))
    return path .. "\\sapp\\mapcycle.txt"
end

local function send(id, msg)
    if id == 0 then
        cprint(msg)
        return
    end

    rprint(id, msg)
end

local function formatString(str, pos, _map, _mode, total)
    local replacements = {
        ["$pos"] = tostring(pos),
        ["$map"] = tostring(_map),
        ["$mode"] = tostring(_mode),
        ["$total"] = tostring(total)
    }

    return (str:gsub("%$%w+", replacements))
end

local function getNextMap(i)
    i = (i + 1)
    local next = maps[i]
    return { next and next or maps[1], next and i or 1 }
end

local function showCurrentMap(id)
    local next_map = {}
    local txt = output[1]

    for i, t in pairs(maps) do
        if map == t.map and mode == t.mode and not t.done then
            next_map = getNextMap(i)
            send(id, formatString(txt, i, t.map, t.mode, #maps))
            break
        end
    end

    if #next_map == 0 then
        send(id, "Unable to display map info.")
        send(id, "Current map and/or mode is not configured in mapcycle.txt.")
        return
    end

    return next_map
end

local function showNextMap(id, next_map)
    local txt = output[2]
    local t, i = next_map[1], next_map[2]
    send(id, formatString(txt, i, t.map, t.mode, #maps))
end

function OnCommand(id, command)
    local args = parseArgs(command, "%s")
    if #args == 0 then return true end

    local index = args[2]

    -- map list command --
    if args[1] == map_list_command then
        local next_map = showCurrentMap(id)
        if next_map and #next_map > 0 then showNextMap(id, next_map) end
        return false
    end

    if args[1] == "map_spec" and index:match("%d+") then -- override SAPP's map_spec command
        index = tonumber(index)
        if index >= 0 and index <= #maps then
            map_spec_index = index
            return true
        else
            send(id, "Please enter a number between 0/" .. #maps)
        end
    end

    -- what is next command --
    if args[1] == what_is_next_command then
        if index ~= nil and index:match("%d+") then
            local i = tonumber(index)
            local t = maps[i]

            if not t then goto continue end

            local txt = output[3]
            send(id, formatString(txt, i, t.map, t.mode, #maps))
        end

        :: continue ::
        send(id, "Please enter a number between 0/" .. #maps)
        return false
    end
end

function OnScriptLoad()
    local path = getMapcycleDir()
    local file = io.open(path)
    if file then
        local i = 0
        for entry in file:lines() do
            local args = parseArgs(entry, ":")
            maps[i] = { map = args[1], mode = args[2], done = false }
            i = i + 1
        end
        file:close()

        register_callback(cb.EVENT_GAME_END, "OnEnd")
        register_callback(cb.EVENT_COMMAND, "OnCommand")
        register_callback(cb.EVENT_GAME_START, "OnStart")

        OnStart()
    end
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    map = get_var(0, "$map"):lower()
    mode = get_var(0, "$mode"):lower()

    for i, t in pairs(maps) do
        if map == t.map and mode == t.mode and not t.done then
            map_spec_index = i
            break
        end
    end
end

function OnEnd()
    if not maps[map_spec_index + 1] then
        for _, v in pairs(maps) do
            v.done = false
        end
        return
    end

    for _, t in pairs(maps) do
        if map == t.map and mode == t.mode and not t.done then
            t.done = true
        end
    end
end

function OnScriptUnload() end
