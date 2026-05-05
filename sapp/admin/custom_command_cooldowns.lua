--[[
===============================================================================
SCRIPT NAME:      custom_command_cooldowns.lua
DESCRIPTION:      Prevents command spamming by enforcing custom cooldown timers
                  per command, and player-specific usage tracking

Copyright (c) 2025-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
===============================================================================
]]

api_version = "1.12.0.0"

-- Config Start ---------------------------------------------------------
local COMMANDS = {
    -- Example commands:
    teleport = 10, -- 10 seconds cooldown for teleport command
    team = 5,      -- 5 seconds cooldown for team command
    heal = 30,     -- 30 seconds cooldown for heal command

    -- Add more commands here...
}

local WAIT_MESSAGE = "You must wait %.1f seconds before using this command again."
-- Config End -----------------------------------------------------------

local os_time = os.time
local fmt = string.format
local cooldowns = {}

local function get_remaining_cooldown(player_id, command, now, cooldown_time)
    local player_cooldowns = cooldowns[player_id]
    if not player_cooldowns then return 0 end

    local last_used = player_cooldowns[command]
    if not last_used then return 0 end

    local elapsed = now - last_used
    if elapsed >= cooldown_time then return 0 end

    return cooldown_time - elapsed
end

function OnCommand(playerId, command)
    if playerId == 0 then return true end -- console

    local cooldown_time = COMMANDS[command]
    if not cooldown_time then return true end

    local now = os_time()
    local remaining = get_remaining_cooldown(playerId, command, now, cooldown_time)

    if remaining > 0 then
        rprint(playerId, fmt(WAIT_MESSAGE, remaining))
        return false
    end

    local player_cooldowns = cooldowns[playerId]
    if not player_cooldowns then
        player_cooldowns = {}
        cooldowns[playerId] = player_cooldowns
    end

    player_cooldowns[command] = now
    return true
end

function OnScriptLoad()
    register_callback(cb["EVENT_COMMAND"], "OnCommand")
    register_callback(cb["EVENT_GAME_START"], "OnStart")
    OnStart() -- in case script is loaded mid-game
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end
    cooldowns = {}
end

function OnScriptUnload() end