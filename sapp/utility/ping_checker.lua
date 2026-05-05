--[[
=====================================================================================
SCRIPT NAME:      ping_checker.lua
DESCRIPTION:      Player latency monitoring system with configurable command interface

FEATURES:
                  - Real-time ping checking for any player
                  - Customizable command and output format
                  - Permission level restrictions
                  - Supports both console and in-game execution

CONFIGURATION:
                  pingCommand:       Command trigger (default: 'ping')
                  permissionLevel:   Minimum admin level required (default: -1 for public)
                  outputTemplate:    Customizable response format with $name and $ping variables

USAGE:
                  Basic:             "ping <playerID>"
                  Example:           "ping 2" checks ping for player ID 2
                  Self-check:       "ping" (checks your own ping)

Copyright (c) 2020-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- config starts:

-- Custom ping command:
--
local pingCommand = 'ping'

-- Minimum permission level to execute the custom command:
--
local permissionLevel = -1

-- Message template for ping output:
-- The $name & $ping placeholders will be replaced by the corsending values.
--
local outputTemplate = '$name: $ping'

-- config ends

-- SAPP Lua API Version:
api_version = '1.12.0.0'

-- Responsible for handling the loading of the script:
--
function OnScriptLoad()
    -- register needed event callback for the Command Handler:
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
end

-- Checks if a player has permission to execute the custom command:
-- @param p (Player memory address index) [number]
--
local function hasAccess(id)
    local lvl = tonumber(get_var(id, '$lvl'))
    return (id == 0 or lvl >= permissionLevel)
end

-- Splits a string by whitespace into an array:
-- @param s (String to split) [string]
--
local function stringSplit(s)
    local args = {}
    for arg in s:gmatch('([^%s]+)') do
        args[#args + 1] = arg:lower()
    end
    return args
end

-- Sends a response to the player:
-- @param id (Player memory address index) [number]
-- @param str (Message to send) [string]
--
local function send(id, message)
    return (id == 0 and cprint(message) or rprint(id, message))
end

-- Gets a player's ping:
-- @param id (Player memory address index) [number]
-- @return player's ping [number]
--
local function getPing(id)
    return get_var(id, '$ping')
end

-- Gets a player's name:
-- @param id (Player memory address index) [number]
-- @return player's name [string]
--
local function getName(id)
    return get_var(id, '$name')
end

-- Replaces placeholders in a string with provided values:
-- @param str (String with placeholders) [string]
-- @param name (Player's name) [string]
-- @param ping (Player's ping) [number]
-- @return modified string [string]
--
local function replacePlaceholders(str, name, ping)
    return str:gsub('$ping', ping):gsub('$name', name)
end

-- Checks if a player ID is valid:
-- @param id (Player memory address index) [number]
-- @return true if player is present, false otherwise [boolean]
--
local function validatePlayer(id)
    return (id and player_present(id))
end

-- Handles the custom command execution:
-- @param id (Player memory address index) [number]
-- @param cmd (Command string) [string]
--
function OnCommand(id, CMD, _, _)
    local args = stringSplit(CMD)

    if (args and args[1] == pingCommand and hasAccess(id)) then
        local player = tonumber(args[2])
        local name, ping

        if validatePlayer(player) then

            -- Get player name and ping:
            ping = getPing(player)
            name = getName(player)

            -- Replace placeholders in output template:
            local output = replacePlaceholders(outputTemplate, name, ping)

            -- Send output message to the player:
            send(id, output)
        else
            -- Notify the player that the target player is invalid or not online:
            send(id, 'Invalid Player ID or Player not online!')
        end

        -- Return false to indicate that the command has been handled:
        return false
    end
end

-- Placeholder function for unloading the script:
--
function OnScriptUnload()
    -- N/A
end