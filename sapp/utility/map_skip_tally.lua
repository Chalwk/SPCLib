--[[
=====================================================================================
SCRIPT NAME:      map_skip_tally.lua
DESCRIPTION:      Tracks and persists map skip votes across game sessions.

COMMANDS:
                  skip       - Register a skip vote
                  tally     - View current map's skip count
                  tallydetails - View your personal skip contributions

REQUIREMENTS:     Install to the same directory as sapp.dll
                  - Lua JSON Parser:  http://regex.info/blog/lua/json

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

local file_name = 'skip_tally.json'
local query_cmd = 'tally'
local detailed_cmd = 'tallydetails'
local permission_level = 1
local deduct_on_quit = true

local dir, map, mode
local skipped, records, player_skips = {}, {}, {}
local json = (loadfile "json.lua")()  -- Load JSON library
local open = io.open

-- Script Initialization
function OnScriptLoad()
    dir = read_string(read_dword(sig_scan('68??????008D54245468') + 0x1)) .. '\\sapp\\' .. file_name
    register_callback(cb['EVENT_CHAT'], 'OnChat')
    register_callback(cb['EVENT_JOIN'], 'OnJoin')
    register_callback(cb['EVENT_LEAVE'], 'OnQuit')
    register_callback(cb['EVENT_GAME_END'], 'OnEnd')
    register_callback(cb['EVENT_COMMAND'], 'HandleCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')
    OnStart()
end

-- Write content to JSON file with error handling
local function Write(content)
    local file, err = open(dir, "w")
    if not file then
        cprint("Error opening file for writing: " .. err)
        return
    end
    file:write(json:encode_pretty(content))
    file:close()
end

-- Initialize records on game start
function OnStart()
    if get_var(0, "$gt") ~= "n/a" then
        records = {}
        player_skips = {}  -- Initialize player skips
        map = get_var(0, "$map")
        mode = get_var(0, "$mode")

        local file, err = open(dir, "r")
        local content = file and file:read("*all") or ""
        if file then
            file:close()
        else
            cprint("Error opening file for reading: " .. err)
        end

        local data, decode_err = json:decode(content) or {}
        if decode_err then
            cprint("Error decoding JSON data: " .. decode_err)
            return
        end

        data[map] = data[map] or {}
        data[map][mode] = data[map][mode] or 0
        Write(data)  -- Write initial data to file
        records = data
    end
end

-- Handle player joining
function OnJoin(playerId)
    skipped[playerId] = false
    player_skips[playerId] = 0  -- Initialize player's skip count
end

-- Handle player quitting
function OnQuit(playerId)
    if deduct_on_quit and skipped[playerId] then
        records[map][mode] = records[map][mode] - 1
        player_skips[playerId] = player_skips[playerId] - 1  -- Deduct from player skips
    end
    skipped[playerId] = nil
end

-- Handle game end
function OnEnd()
    for _, skip in pairs(skipped) do
        if skip then
            Write(records)  -- Write updated records
            break
        end
    end
end

-- Handle chat messages
function OnChat(playerId, message)
    if message:lower():match("skip") and not skipped[playerId] then
        skipped[playerId] = true
        records[map][mode] = records[map][mode] + 1
        player_skips[playerId] = player_skips[playerId] + 1  -- Increment player's skip count
        Respond(playerId, "You have registered a skip!")  -- Confirm skip registration
    end
end

-- Respond to players
local function Respond(playerId, message)
    if playerId == 0 then
        cprint(message)  -- Console output
    else
        rprint(playerId, message)  -- Player output
    end
end

-- Check player permissions
local function HasPermission(playerId)
    return playerId == 0 or tonumber(get_var(playerId, '$lvl')) >= permission_level or (Respond(playerId, 'Insufficient Permission') and false)
end

-- Handle tally command
function HandleCommand(playerId, command)
    if command:sub(1, #query_cmd):lower() == query_cmd and HasPermission(playerId) then
        Respond(playerId, string.format("%s/%s: %d", map, mode, records[map][mode]))
        return false
    elseif command:sub(1, #detailed_cmd):lower() == detailed_cmd and HasPermission(playerId) then
        local skipCount = player_skips[playerId] or 0
        Respond(playerId, string.format("Your total skips: %d", skipCount))
        return false
    end
end

-- Cleanup on script unload
function OnScriptUnload()
    -- No specific actions needed on unload
end