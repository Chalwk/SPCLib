--[[
=====================================================================================
SCRIPT NAME:      april_fools_word_shuffler.lua
DESCRIPTION:      Randomly scrambles player chat messages as an April Fools prank,
                  making text appear jumbled while preserving original sender info.

Copyright (c) 2022-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START ----------------------------------------------------------------------

-- 1-in-N chance per chat message. 1 = every message is scrambled,
-- 10 = roughly 1 in 10. Set to 0 to disable the script.
local SHUFFLE_CHANCE = 3

-- The script temporarily removes the "msg_prefix" and restores
-- it to this when its broadcast relay is done:
local SERVER_PREFIX = "**SAPP**"

-- CONFIG END ------------------------------------------------------------------------

local math_random = math.random
local table_concat = table.concat

local function splitUtf8(str)
    local chars = {}
    for char in str:gmatch(".[\128-\191]*") do
        chars[#chars + 1] = char
    end
    return chars
end

local function shuffleArray(array)
    for i = #array, 2, -1 do
        local j = math_random(i)
        array[i], array[j] = array[j], array[i]
    end
end

local function shuffleString(str)
    local chars = splitUtf8(str)
    shuffleArray(chars)
    return table_concat(chars)
end

local function formatScrambled(chat_type, player_name, message)
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
    ---@diagnostic disable-next-line: unnecessary-if
    if SHUFFLE_CHANCE < 1 then return true end
    if math_random(SHUFFLE_CHANCE) ~= 1 then return true end

    local formatted = formatScrambled(chat_type, get_var(player_id, "$name"), shuffleString(message))
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
