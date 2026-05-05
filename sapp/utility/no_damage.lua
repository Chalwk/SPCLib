--[[
=====================================================================================
SCRIPT NAME:      no_damage.lua
DESCRIPTION:      Player invulnerability system with toggleable damage prevention.

FEATURES:
                  - Toggleable player invulnerability via command
                  - Prevents all external damage sources
                  - Preserves original damage state for restoration
                  - Individual player control (not global)
                  - Memory-safe implementation

COMMAND USAGE:
                  - /damage - Toggles damage protection on/off
                  - Players receive confirmation messages

TECHNICAL DETAILS:
                  - Modifies in-memory damage flags
                  - Tracks original states for proper restoration
                  - Handles player disconnects gracefully

Copyright (c) 2023-2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = '1.12.0.0'

local command = 'damage'
local protectedPlayers = {}

-- This function is called when the script is loaded.
function OnScriptLoad()
    register_callback(cb['EVENT_LEAVE'], 'OnPlayerLeave')
    register_callback(cb['EVENT_SPAWN'], 'OnSpawn')
    register_callback(cb['EVENT_COMMAND'], 'OnPlayerCommand')
    register_callback(cb['EVENT_GAME_START'], 'OnGameStart')
    register_callback(cb['EVENT_DAMAGE_APPLICATION'], 'OnDamageApplication')
    OnGameStart() -- Initialize player states at game start
end

-- Retrieves original bit values for a player
-- @param playerId (number) | The player's index.
-- @return (table | nil) | A table containing original bit values or nil if not found.
local function getOriginalBits(playerId)
    local playerDynamic = get_dynamic_player(playerId)
    if playerDynamic ~= 0 then
        return {
            [playerDynamic + 0x10] = { 0, read_bit(playerDynamic + 0x10, 0) },
            [playerDynamic + 0x106] = { 11, read_bit(playerDynamic + 0x106, 11) },
        }
    end
    return nil
end

-- Restores the original bit values for a player
-- @param playerId (number) | The player's index.
local function restoreOriginalBits(playerId)
    for address, values in pairs(protectedPlayers[playerId]) do
        write_bit(address, values[1], values[2])
    end
    protectedPlayers[playerId] = nil -- Remove player from the protection table
end

-- Modifies damage-related bits to prevent damage
-- @param playerId (number) | The player's index.
local function modifyDamageBits(playerId)
    local playerDynamic = get_dynamic_player(playerId)
    if playerDynamic ~= 0 and protectedPlayers[playerId] then
        write_bit(playerDynamic + 0x10, 0, 1)  -- Set the "no damage" bit
        write_bit(playerDynamic + 0x106, 11, 1) -- Set the "no damage" bit for the second value
    end
end

-- Initializes player states when the game starts
function OnGameStart()
    if get_var(0, '$gt') ~= 'n/a' then
        for playerId = 1, 16 do
            if player_present(playerId) then
                restoreOriginalBits(playerId) -- Restore original bits for all players
            end
        end
    end
end

-- Handles player commands
-- @param playerId (number) | The player's index.
-- @param commandInput (string) | The command entered by the player.
-- @return (boolean) | Indicates whether to prevent further command processing.
function OnPlayerCommand(playerId, commandInput)
    if commandInput:sub(1, #command):lower() == command then
        if protectedPlayers[playerId] then
            restoreOriginalBits(playerId) -- Restore original damage behavior
            rprint(playerId, "You will now take damage from other players.")
        else
            protectedPlayers[playerId] = getOriginalBits(playerId) -- Store original bits
            modifyDamageBits(playerId) -- Apply no damage effects
            rprint(playerId, "You will no longer take damage from other players.")
        end
        return false -- Prevent further processing of the command
    end
end

-- Handles damage application events
-- @param victimId (number) | The player's index of the victim.
-- @param killerId (number) | The player's index of the killer.
-- @return (boolean) | Indicates whether to prevent the damage event.
function OnDamageApplication(victimId, killerId)
    if tonumber(victimId) ~= tonumber(killerId) and protectedPlayers[tonumber(victimId)] then
        return false -- Prevent damage if the victim is in the protected list
    end
end

-- Handles player leaving events
-- @param playerId (number) | The player's index who is leaving.
function OnPlayerLeave(playerId)
    protectedPlayers[playerId] = nil -- Remove player from the protection list
end

-- This function is called when the script is unloaded. Currently not in use.
function OnScriptUnload()
    -- N/A
end