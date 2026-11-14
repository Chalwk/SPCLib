--[[
=====================================================================================
SCRIPT NAME:      april_fools_chat.lua
DESCRIPTION:      Randomly modifies player chat messages to appear as if they were
                  sent by other players.

Copyright (c) 2020-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START ----------------------------------------------------------------------

-- Percent chance (0-100) that any given chat message is impersonated.
-- 20 = roughly 1 in 5 messages on average. Set to 0 to disable.
local IMPERSONATE_CHANCE = 20

-- The script temporarily removes the "msg_prefix" and restores
-- it to this when its broadcast relay is done:
local SERVER_PREFIX = "**SAPP**"

-- CONFIG END ------------------------------------------------------------------------

local math_random = math.random
local string_sub = string.sub

local function isChatCommand(message)
    local first = string_sub(message, 1, 1)
    return first == "/" or first == "\\"
end

local function getRandomOtherPlayer(excluded_player_id)
    local available = {}
    for i = 1, 16 do
        if player_present(i) and i ~= excluded_player_id then
            available[#available + 1] = i
        end
    end

    if #available == 0 then return nil end
    return available[math_random(#available)]
end

local function formatImpersonation(chat_type, player_name, message)
    if chat_type == 0 then
        return player_name .. ": " .. message
    elseif chat_type == 1 or chat_type == 2 then
        return "[" .. player_name .. "]: " .. message
    end
    return nil
end

local function broadcast(chat_type, message, team)
    if chat_type == 0 then
        say_all(message)
        return
    end
    for i = 1, 16 do
        if player_present(i) and get_var(i, "$team") == team then
            say(i, message)
        end
    end
end

function OnChat(player_id, message, chat_type)
    if isChatCommand(message) then return true end

    ---@diagnostic disable-next-line: unnecessary-if
    if IMPERSONATE_CHANCE < 1 then return true end
    if math_random(100) > IMPERSONATE_CHANCE then return true end

    local impostor_id = getRandomOtherPlayer(player_id)
    if not impostor_id then return true end

    local formatted = formatImpersonation(chat_type, get_var(impostor_id, "$name"), message)
    if not formatted then return true end

    execute_command('msg_prefix ""')
    broadcast(chat_type, formatted, get_var(player_id, "$team"))
    execute_command('msg_prefix "' .. SERVER_PREFIX .. '"')

    return false
end

function OnScriptLoad()
    math.randomseed(os.time())
    register_callback(cb.EVENT_CHAT, "OnChat")
end

function OnScriptUnload() end
