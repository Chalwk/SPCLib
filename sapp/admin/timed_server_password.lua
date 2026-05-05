--[[
=====================================================================================
SCRIPT NAME:      Timed Server Password
DESCRIPTION:      Automatically removes server password after configurable duration.

FEATURES:
                  - Set password expiration time (seconds)
                  - Automatic password clearing
                  - Server-wide notifications
                  - Admin command integration
                  - Event-based optimization
                  - Permission system

CONFIGURATION:
                  local CONFIG = {
                    DURATION = 300,   - Password duration in seconds (5 minutes)
                    ADMIN_LEVEL = 4   - Required admin level for password commands
                  }

DEVELOPED FOR:    BK Clan (@Rev)

Copyright (c) 2022-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

-- Configuration ---------------------------------------------------------------
local CONFIG = {
    DURATION = 300,  -- Password duration in seconds (5 minutes)
    ADMIN_LEVEL = 4, -- Required admin level for password commands
    NOTIFICATION = "Server password has been automatically removed"
}
-- End Configuration -----------------------------------------------------------

-- Localized API functions for performance
local get_var = get_var
local execute_command = execute_command
local say_all = say_all
local cprint = cprint
local rprint = rprint
local os_time = os.time
local tonumber = tonumber

-- Script state
local password_removal_time = nil

-- Starts the password removal timer
local function start_timer()
    password_removal_time = os_time() + CONFIG.DURATION
end

local function has_permission(player_id)
    return player_id == 0 or tonumber(get_var(player_id, "$lvl")) >= CONFIG.ADMIN_LEVEL
end

local function send(player_id, message)
    if player_id == 0 then return cprint(message, 10) end
    rprint(player_id, message)
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    start_timer()
end

function OnTick()
    if password_removal_time and os_time() >= password_removal_time then
        password_removal_time = nil
        execute_command("sv_password \"\"")
        say_all(CONFIG.NOTIFICATION)
    end
end

function OnCommand(player_id, command)
    local cmd = command:lower()
    if cmd:sub(1, 11) == "sv_password" and #cmd > 12 and has_permission(player_id) then
        start_timer()
        send(player_id, "Server password will auto-remove in " .. CONFIG.DURATION .. " seconds")
        return false
    end
    return true
end

function OnScriptLoad()
    register_callback(cb['EVENT_TICK'], "OnTick")
    register_callback(cb['EVENT_COMMAND'], "OnCommand")
    register_callback(cb['EVENT_GAME_START'], "OnStart")
    OnStart()
end

function OnScriptUnload() end
