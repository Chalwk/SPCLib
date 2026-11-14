--[[
=====================================================================================
SCRIPT NAME:      admin_chat.lua
DESCRIPTION:      Admin-only chat system for "secure" communication.

Copyright (c) 2016-2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

api_version = "1.12.0.0"

-- CONFIG START ----------------------------------------------------------------------

local COMMAND = "achat"
local REQUIRED_PERMISSION = 1
local ENABLED_ON_JOIN = false
local OUTPUT_FORMAT = "[AdminChat] $name: $msg"
local COOLDOWN_TIME = 1.5
local MESSAGES = {
    toggled = "Admin Chat: $state",
    permission = "Insufficient permissions",
    cooldown = "Message cooldown active",
    help = "Use /achat to toggle admin-only chat"
}

-- CONFIG END ------------------------------------------------------------------------

local get_var = get_var
local tonumber = tonumber
local os_clock = os.clock
local string_sub = string.sub
local string_gsub = string.gsub

local player_state = {}

local function isChatCommand(message)
    local first = string_sub(message, 1, 1)
    return first == "/" or first == "\\"
end

local function formatTemplate(template, values)
    return (string_gsub(template, "%$(%w+)", function (key)
        local value = values[key]
        return value ~= nil and tostring(value) or "$" .. key
    end))
end

local function hasPermission(player_id)
    return tonumber(get_var(player_id, "$lvl")) >= REQUIRED_PERMISSION
end

local function broadcastAdminMessage(sender_name, message)
    local formatted = formatTemplate(OUTPUT_FORMAT, { name = sender_name, msg = message })

    for player_id, entry in pairs(player_state) do
        if entry.state and player_present(player_id) then
            rprint(player_id, formatted)
        end
    end
end

local function initPlayer(player_id)
    local permission = hasPermission(player_id)

    player_state[player_id] = {
        name = get_var(player_id, "$name"),
        state = permission and ENABLED_ON_JOIN,
        last_message = 0
    }

    if not permission then return end
    rprint(player_id, MESSAGES.help)
end

function OnChat(player_id, message)
    if isChatCommand(message) then return true end

    local entry = player_state[player_id]
    if not entry or not entry.state then return true end

    if not hasPermission(player_id) then -- recheck just in case
        entry.state = false
        rprint(player_id, MESSAGES.permission)
        return true
    end

    local now = os_clock()
    if now - entry.last_message < COOLDOWN_TIME then
        rprint(player_id, MESSAGES.cooldown)
        return false
    end

    entry.last_message = now
    broadcastAdminMessage(entry.name, message)
    return false
end

function OnCommand(executor_id, command)
    if executor_id == 0 or command ~= COMMAND:lower() then return true end
    if not player_state[executor_id] then return true end

    if not hasPermission(executor_id) then
        rprint(executor_id, MESSAGES.permission)
        return false
    end

    local entry = player_state[executor_id]
    if not entry then return false end

    entry.state = not entry.state
    local state_word = entry.state and "ON" or "OFF"
    rprint(executor_id, formatTemplate(MESSAGES.toggled, { state = state_word }))
    return false
end

function OnJoin(player_id)
    initPlayer(player_id)
end

function OnLeave(player_id)
    player_state[player_id] = nil
end

function OnStart()
    if get_var(0, "$gt") == "n/a" then return end

    for id in pairs(player_state) do
        if not player_present(id) then
            player_state[id] = nil
        end
    end

    for i = 1, 16 do
        if player_present(i) and not player_state[i] then
            initPlayer(i)
        end
    end
end

function OnScriptLoad()
    register_callback(cb.EVENT_CHAT, "OnChat")
    register_callback(cb.EVENT_COMMAND, "OnCommand")
    register_callback(cb.EVENT_JOIN, "OnJoin")
    register_callback(cb.EVENT_LEAVE, "OnLeave")
    register_callback(cb.EVENT_GAME_START, "OnStart")

    OnStart() -- in case the script was loaded mid-game
end

function OnScriptUnload() end
