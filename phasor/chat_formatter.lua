--[[
=====================================================================================
SCRIPT NAME:      chat_formatter.lua
DESCRIPTION:      Chat formatter with placeholders, command filtering,
                  and team-sensitive delivery. Supports global, team, and vehicle
                  chat types.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/HALO-SCRIPT-PROJECTS/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG start ---------------------------------------------------------------
-- Chat format templates (types 0 = global, 1 = team, 2 = vehicle)
-- Use $name, $id, $msg as dynamic placeholders
local chat_format = {
    [0] = "$name [$id]: $msg",
    [1] = "[$name] [$id]: $msg",
    [2] = "[$name] [$id]: $msg"
}

-- Messages whose first word (case-insensitive) matches a key here are ignored.
-- Perfect for commands like rtv / skip that shouldn't be reformatted.
local ignore_list = { rtv = true, skip = true, }
-- CONFIG END -----------------------------------------------------------------

local gametype_base

local function format(template, args)
    if not args then return template end
    return (template:gsub("%$([%w_]+)", function(key)
        local value = args[key] or args[key:lower()] or args[key:upper()]
        return value ~= nil and tostring(value) or "$" .. key
    end))
end

local function split_message(msg)
    local words = {}
    for w in msg:gmatch("[^%s]+") do
        words[#words + 1] = w:lower()
    end
    return words
end

local function is_command(w)
    return w and (w:sub(1, 1) == "/" or w:sub(1, 1) == "\\")
end

local function send_formatted(player, chat_type, msg)
    local name = getname(player)
    local id = resolveplayer(player)

    local template = chat_format[chat_type]
    if not template then return end

    local formatted = format(template, { name = name, id = tostring(id), msg = msg })

    if chat_type == 1 or chat_type == 2 then
        for i = 0, 15 do
            local p = getplayer(i)
            if p and getteam(i) == getteam(player) then
                privatesay(i, formatted)
            end
        end
    else
        say(formatted)
    end
end

function OnScriptLoad(_, game)
    gametype_base = (game == "PC") and 0x671340 or 0x5F5498
end

function OnServerChat(player, chat_type, message)
    if chat_type == 3 or chat_type == 4 then return end

    local words = split_message(message)
    if is_command(words[1]) or ignore_list[words[1]] then return end
    send_formatted(player, chat_type, message)

    return false
end

function OnScriptUnload() end

function GetRequiredVersion() return 200 end
