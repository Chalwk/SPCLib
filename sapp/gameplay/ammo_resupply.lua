--[[
=====================================================================================
SCRIPT NAME:      ammo_resupply.lua
DESCRIPTION:      Adds a configurable '/res' command that allows players to:
                  - Replenish ammo, grenades, and battery
                  - Customizable resupply amounts
                  - Permission level restriction
                  - Cooldown timer between uses

                  Server operators can configure all aspects of the resupply.

Copyright (c) 2019-2025 Jericho Crosby
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]
-- Configuration table for the resupply script
local CONFIG = {

    -- Command to trigger the resupply
    COMMAND = 'res',

    -- Permission level required to use the command (-1 means no restriction)
    -- Default: -1
    PERMISSION_LEVEL = -1,

    -- Amount of ammo to resupply
    -- Default: 200
    AMMO = 200,

    -- Amount of magazine to resupply
    -- Default: 500
    MAG = 500,

    -- Number of frag grenades to resupply
    -- Default: 4
    FRAGS = 4,

    -- Number of plasma grenades to resupply
    -- Default: 4
    PLASMAS = 4,

    -- Battery percentage to resupply
    -- Default: 100%
    BATTERY = 100,

    -- Output message to display after resupply
    OUTPUT = '[RESUPPLY] +200 ammo, +500 mag, +4 frags, +4 plasmas, +100% battery',

    -- Cooldown period in seconds before the command can be used again
    -- Default: 30 seconds
    COOLDOWN = 30
}

api_version = '1.12.0.0'

-- State variables
local last_resupply = {}

-- Function to check if a player has the required permission level
local function hasPermission(playerId)
    local level = tonumber(get_var(playerId, '$lvl'))
    return level >= CONFIG.PERMISSION_LEVEL
end

-- Function to handle the resupply command
local function handleResupplyCommand(playerId)
    local now = os.time()

    if CONFIG.COOLDOWN > 0 and last_resupply[playerId] and now < last_resupply[playerId] + CONFIG.COOLDOWN then
        local wait_time = math.floor(last_resupply[playerId] + CONFIG.COOLDOWN - now)
        rprint(playerId, 'You must wait ' .. wait_time .. ' more seconds before resupplying.')
        return
    end

    last_resupply[playerId] = now

    -- Update ammo
    execute_command('ammo ' .. playerId .. ' ' .. CONFIG.AMMO .. ' 5')
    execute_command('mag ' .. playerId .. ' ' .. CONFIG.MAG .. ' 5')
    execute_command('battery ' .. playerId .. ' ' .. CONFIG.BATTERY .. ' 5')

    -- Update grenades
    execute_command('nades ' .. playerId .. ' ' .. CONFIG.FRAGS .. ' 1')
    execute_command('nades ' .. playerId .. ' ' .. CONFIG.PLASMAS .. ' 2')

    rprint(playerId, CONFIG.OUTPUT)
end

-- Event handler for command execution
function OnCommand(player_id, command)
    if command:sub(1, #CONFIG.COMMAND):lower() == CONFIG.COMMAND then
        if hasPermission(player_id) then
            handleResupplyCommand(player_id)
        else
            rprint(player_id, 'Insufficient Permission')
        end
        return false
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
end

function OnScriptUnload() end
