--[[
=====================================================================================
SCRIPT NAME:      april_fools_chat.lua
DESCRIPTION:      Randomly modifies player chat messages to appear as if they were
                  sent by other players.

FEATURES:
                  - Random chance per chat message to alter
                  - Preserves chat commands

Copyright (c) 2020-2025 Jericho Crosby
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- Config [starts]--------------------------------
local SERVER_PREFIX = "**SAPP** "
local RANDOM_CHANCE = 0.2  -- 20% chance to alter chat
-- Config [ends]----------------------------------

local function isChatCommand(message)
    local first_char = message:sub(1, 1)
    return first_char == "/" or first_char == "\\"
end

local function getRandomPlayer(excludedPlayerId)
    local available = {}
    for i = 1, 16 do
        if player_present(i) and i ~= excludedPlayerId then
            available[#available + 1] = i
        end
    end
    return (#available > 0) and available[rand(1, #available + 1)] or nil
end

local function alterChatMessage(originalPlayerId, message)
    local random_player = getRandomPlayer(originalPlayerId)
    if random_player then
        local name = get_var(random_player, "$name")
        execute_command('msg_prefix ""')
        say_all(name .. ": " .. message)
        execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')
        return false
    end
    return true
end

function OnChat(playerId, message)
    if isChatCommand(message) then return true end

    local chance = rand(1, 101 + 1) / 100 -- gives 0.01-1.00
    if chance <= RANDOM_CHANCE then
        return alterChatMessage(playerId, message)
    end

    return true
end

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnChat")
end

function OnScriptUnload() end
