--[[
=====================================================================================
SCRIPT NAME:      rules_command.lua
DESCRIPTION:      Displays server rules to players via chat command with timed
                  announcements and formatted console output.

FEATURES:
                  - Customizable rules display via chat command
                  - Automatic periodic announcements
                  - Console-formatted text output
                  - Configurable timing and messages
                  - Server prefix preservation

CONFIGURATION:
                  command:          Rules command (default: "rules")
                  announcement:     Automatic reminder message
                  interval:         Announcement frequency in seconds (default: 180)
                  show_time:        Duration to display rules in seconds (default: 10)
                  Rules:            Table containing your server rules (editable)
                  server_prefix:    Custom server message prefix

USAGE:
                  Players type: /rules
                  Automatic announcements every 3 minutes
                  Rules display for 10 seconds in console format

DEPENDENCIES:
                  Requires rcon_text.lua for formatted text display

Copyright (c) 2021-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

--------------------------
-- Configuration Starts --
--------------------------

local command = "rules"  -- Custom command to view the rules
local announcement = "Type /" .. command .. " to view the game rules."  -- Announcement message
local interval = 180  -- Interval (in seconds) between each announcement
local show_time = 10  -- Duration (in seconds) to display messages

-- Rules Table
local Rules = {
    "1. Do not betray your teammates.",
    "2. Do not be toxic; be a good sport!",
    "3. Do not camp in any forbidden places.",
    "4. Do not block any entrances or teleports.",
    "5. If you're a zombie, press the melee key to infect them.",
}

local server_prefix = "**BK**"  -- Server prefix for messages

------------------------
-- Configuration Ends --
------------------------

api_version = "1.12.0.0"

local ConsoleText = (loadfile "rcon_text.lua")()
local game_started = false  -- Flag to track if the game has started

-- Load script and register callbacks
function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, "HandleCommand")
    register_callback(cb.EVENT_GAME_END, "OnGameEnd")
    register_callback(cb.EVENT_GAME_START, "OnGameStart")
    register_callback(cb.EVENT_TICK, "OnTick")

    OnGameStart()  -- Initialize game state
end

-- Handle custom command for displaying rules
function HandleCommand(playerId, commandInput, _, _)
    if commandInput:sub(1, command:len()):lower() == command then
        ConsoleText:NewMessage(playerId, Rules, show_time, nil, true)
        return false
    end
end

-- Show announcement to all players
function ShowAnnouncement()
    execute_command('msg_prefix ""')  -- Temporarily remove server prefix
    say_all(announcement)  -- Broadcast the announcement
    execute_command('msg_prefix "' .. server_prefix .. '"')  -- Temporarily remove server prefix
    return game_started
end

-- Initialize game state when the game starts
function OnGameStart()
    game_started = true
    if get_var(0, "$gt") ~= "n/a" then
        timer(1000 * interval, "ShowAnnouncement")  -- Schedule announcements
    end
end

-- Reset game state when the game ends
function OnGameEnd()
    game_started = false
end

-- Handle game tick events
function OnTick()
    ConsoleText:GameTick()  -- Update console text on tick
end