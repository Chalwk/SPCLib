--[[
=====================================================================================
SCRIPT NAME:      admin_chat.lua
DESCRIPTION:      Admin-only chat system for secure communication.
                  - Commands: /achat, /ac
                  - Configurable permission level required to use
                  - Toggle admin chat visibility per player
                  - Built-in cooldown to prevent spam
                  - Customizable message formatting and notification messages

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START -------------------------------------------------------------------
local AdminChat = {
    -- Primary command and aliases
    commands = { 'achat', 'ac' },

    -- Minimum permission level required
    permission = 1,

    -- Default state for admins
    enabled_by_default = false,

    -- Message formatting
    output = '[AdminChat] $name: $msg',

    -- Message cooldown (seconds)
    cooldown = 1.5,

    -- System messages
    messages = {
        toggled = 'Admin Chat: $state',
        permission = 'Insufficient permissions',
        cooldown = 'Message cooldown active',
        help = 'Use /$cmd to toggle admin-only chat'
    }
}
-- CONFIG ENDS -------------------------------------------------------------------

local cooldowns = {}
local command_map = {}
local active_players = {}

local get_var = get_var

local ipairs = ipairs
local os_clock = os.clock

api_version = '1.12.0.0'

local Player = {}

function Player:new(id)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.id = id
    o.name = get_var(id, '$name')
    o.lvl = function()
        return tonumber(get_var(id, '$lvl'))
    end
    o.state = (o.lvl() >= AdminChat.permission and AdminChat.enabled_by_default)

    return o
end

function Player:has_permission()
    return self.lvl() >= AdminChat.permission
end

function Player:toggle_state()
    if not self:has_permission() then
        return false, AdminChat.messages.permission
    end

    self.state = not self.state
    local state = self.state and 'ON' or 'OFF'
    local msg = AdminChat.messages.toggled:gsub('$state', state)
    return true, msg
end

function Player:send_message(msg)
    rprint(self.id, msg)
end

local function format_message(sender, message)
    return AdminChat.output
        :gsub('$name', sender.name)
        :gsub('$msg', message)
end

local function broadcast_admin_message(sender, message)
    local formatted = format_message(sender, message)

    for _, player in pairs(active_players) do
        if player.state then
            player:send_message(formatted)
        end
    end
end

local function handle_admin_chat(player, message)
    if not player.state then return true end

    local now = os_clock()
    if cooldowns[player.id] and now - cooldowns[player.id] < AdminChat.cooldown then
        player:send_message(AdminChat.messages.cooldown)
        return false
    end

    cooldowns[player.id] = now
    broadcast_admin_message(player, message)
    return false
end

local function process_command(player, command)
    if command_map[command] then
        local _, response = player:toggle_state()
        player:send_message(response)
        return true
    end
    return false
end

local function show_help(player)
    if player:has_permission() then
        local cmd = AdminChat.commands[1]
        player:send_message(AdminChat.messages.help:gsub('$cmd', cmd))
    end
end

function OnScriptLoad()
    for _, cmd in ipairs(AdminChat.commands) do
        command_map[cmd:lower()] = true
    end

    register_callback(cb.EVENT_CHAT, 'OnChat')
    register_callback(cb.EVENT_JOIN, 'OnJoin')
    register_callback(cb.EVENT_LEAVE, 'OnLeave')
    register_callback(cb.EVENT_COMMAND, 'OnCommand')
    register_callback(cb.EVENT_GAME_START, 'OnStart')

    OnStart()
end

function OnStart()
    if get_var(0, '$gt') == 'n/a' then return end

    active_players = {}

    for i = 1, 16 do
        if player_present(i) then
            OnJoin(i)
        end
    end
end

function OnJoin(playerId)
    local player = Player:new(playerId)
    active_players[playerId] = player
    show_help(player)
end

function OnLeave(playerId)
    active_players[playerId] = nil
    cooldowns[playerId] = nil
end

local function isCommand(msg)
    return msg:sub(1, 1) == '/' or msg:sub(1, 1) == '\\'
end

function OnChat(playerId, message)
    local player = active_players[playerId]
    if not player then return true end

    if isCommand(message) then return true end

    return handle_admin_chat(player, message)
end

function OnCommand(playerId, command)
    local player = active_players[playerId]
    if not player then return true end

    command = command:lower()
    return not process_command(player, command)
end

function OnScriptUnload() end
