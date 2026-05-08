--[[
===============================================================================
SCRIPT NAME:      live_on_3.lua
DESCRIPTION:      Competitive match restart system with:
                  - 3-2-1 countdown sequence
                  - Automatic map reset
                  - Admin permission controls

FEATURES:
                  - Custom command trigger
                  - Visual countdown feedback
                  - Temporary death message suppression
                  - Permission-based access

CONFIGURATION:    Adjust these settings:
                  - command: Trigger word
                  - permission: Required admin level

Copyright (c) 2022 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

-- Configuration section
local command = 'lo3'            -- Custom command to trigger Live on Three
local permission = 1              -- Minimum permission level required to execute the command

-- SAPP Lua API Version
api_version = '1.12.0.0'

-- Variables for death message handling
local count = 3
local DeathMessageAddress
local OriginalMessageAddress

-- Called when the script is loaded
function OnScriptLoad()
    -- Register event callbacks
    register_callback(cb['EVENT_COMMAND'], 'OnCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnStart')

    -- Find the death message address
    DeathMessageAddress = sig_scan('8B42348A8C28D500000084C9') + 3
    OriginalMessageAddress = read_dword(DeathMessageAddress)

    OnStart()
end

-- Reset count when a new game starts
function OnStart()
    if get_var(0, '$gt') ~= 'n/a' then
        count = 3
    end
end

-- Function to enable or disable stock death messages
local function patchDeathMessages(address, value)
    safe_write(true)
    write_dword(address, value)
    safe_write(false)
end

-- Function to reset the map
-- @return (recursively calls itself if count > 0)
function resetMap()
    count = count - 1
    execute_command('resetMap')
    say_all('Live on ' .. (count + 1))

    -- Enable default death messages if count has reached 0
    if count <= 0 then
        patchDeathMessages(DeathMessageAddress, OriginalMessageAddress)
    end

    return count > 0
end

-- Check if the player has permission to execute the command
-- @param playerId (Player memory address index) [number]
local function hasPermission(playerId)
    return playerId == 0 or tonumber(get_var(playerId, '$lvl')) >= permission
end

-- Command Handler
-- @param playerId (Player memory address index) [number]
-- @param cmd (command string) [string]
function OnCommand(playerId, cmd)
    if cmd:sub(1, #command):lower() == command then
        if not hasPermission(playerId) then
            rprint(playerId, 'Insufficient Permission.')
            return false
        end

        -- Disable default death messages
        patchDeathMessages(DeathMessageAddress, 0x03EB01B1)

        count = 3
        timer(1000, 'resetMap')
        return false
    end
end

function OnScriptUnload()
    -- No actions needed on script unload
end
