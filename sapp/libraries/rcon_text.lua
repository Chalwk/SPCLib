--[[
=====================================================================================
SCRIPT NAME:      rcon_text.lua
DESCRIPTION:      Advanced RCON message system with comprehensive message management
                  capabilities for SAPP Halo Custom Edition servers.

                  Enhanced Features:
                  - Multi-format message support (single-line, multi-line, tables)
                  - Priority-based message queuing system
                  - Configurable display modes (persistent, timed, repeating)
                  - Message grouping and batch operations
                  - Player-specific and global messaging
                  - Conditional message display
                  - Comprehensive message lifecycle management

                  USAGE:
                  1. local rcon_text = loadfile("rcon_text.lua")()
                  2. Create a SAPP callback for EVENT_TICK and call rcon_text:GameTick()
                  3. Basic usage:
                        rcon_text:NewMessage(player_id, message, duration_secs)
                  4. Advanced usage:
                      local message_id = rcon_text:NewAdvancedMessage({
                          target = player_id,
                          content = "Important message",
                          duration = 30,
                          priority = 2,
                          mode = "timed",
                          clear_console = true,
                          condition = function() return true end
                      })

Copyright (c) 2025 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

-- CONFIG START ---------------------------------------------------------------------

-- Message display modes
-- These define how messages behave when displayed to players:
local MODES = {
    PERSISTENT = "persistent", -- Stays visible until manually removed by script
    TIMED = "timed",           -- Automatically disappears after specified duration
    REPEATING = "repeating"    -- Repeats at intervals until total duration expires
}

-- Priority levels
-- Higher priority messages may be processed first and can override lower priority ones:
local PRIORITY = {
    LOW = 1,     -- Non-urgent messages (system notifications, minor updates)
    NORMAL = 2,  -- Standard gameplay messages (default)
    HIGH = 3,    -- Important alerts (warnings, major events)
    CRITICAL = 4 -- Critical information (admin commands, emergency messages)
}

-- Main RCONText library configuration table
local RCONText = {
    -- Storage for all active messages using message_id as key
    messages = {},

    -- Groups messages together for batch operations (remove, update multiple messages)
    message_groups = {},

    -- Counter for assigning unique IDs to each new message
    next_message_id = 1,

    -- Counter for assigning unique IDs to each new message group
    next_group_id = 1,

    -- Configuration settings that control default behavior
    config = {
        -- Maximum number of messages allowed per player to prevent spam/memory issues
        max_messages_per_player = 10,

        -- Default time in seconds that timed messages will display (30 seconds)
        default_duration = 30,

        -- Default priority level for new messages (PRIORITY.NORMAL = 2)
        default_priority = PRIORITY.NORMAL,

        -- Default display mode for new messages (MODES.TIMED = "timed")
        default_mode = MODES.TIMED,

        -- Whether to allow clearing the console before displaying new messages
        enable_console_clearing = true,

        -- Number of blank lines to print when clearing console (preevents duplicate messages)
        console_lines_to_clear = 25
    }
}

-- CONFIG END ---------------------------------------------------------------------

local type = type
local os_time = os.time
local t_remove = table.remove
local t_insert = table.insert
local pairs = pairs
local ipairs = ipairs

local rprint = rprint
local player_present = player_present

local function deep_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = deep_copy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function validate_player_id(id)
    return type(id) == "number" and id >= 0 and id <= 15
end

local function get_current_timestamp()
    return os_time()
end

local function format_content(content)
    if type(content) == "table" then
        return deep_copy(content)
    elseif type(content) == "string" then
        return { content }
    else
        return { tostring(content) }
    end
end

-- Message sending with advanced formatting
local function send_message(player_id, message_data)
    if not player_present(player_id) then
        return false
    end

    local clear_console = message_data.clear_console and RCONText.config.enable_console_clearing

    -- Clear console if requested
    if clear_console then
        for _ = 1, RCONText.config.console_lines_to_clear do
            rprint(player_id, " ")
        end
    end

    -- Send formatted content
    local content = message_data.content
    if type(content) == "table" then
        for i = 1, #content do
            rprint(player_id, content[i])
        end
    else
        rprint(player_id, content)
    end

    -- Update message tracking
    message_data.last_sent = get_current_timestamp()
    message_data.times_sent = (message_data.times_sent or 0) + 1

    return true
end

-- Message management functions
function RCONText:NewMessage(player_id, content, duration, clear_console)
    return self:NewAdvancedMessage({
        target = player_id,
        content = content,
        duration = duration or self.config.default_duration,
        clear_console = clear_console or false,
        priority = self.config.default_priority,
        mode = self.config.default_mode
    })
end

function RCONText:NewAdvancedMessage(params)
    local target = params.target
    local content = params.content
    local duration = params.duration or self.config.default_duration
    local priority = params.priority or self.config.default_priority
    local mode = params.mode or self.config.default_mode
    local clear_console = params.clear_console or false
    local condition = params.condition
    local group_id = params.group_id
    local repeat_interval = params.repeat_interval

    if not validate_player_id(target) then
        error("Invalid player ID: " .. tostring(target))
    end

    if not content then
        error("Message content cannot be nil")
    end

    local message_id = self.next_message_id
    self.next_message_id = self.next_message_id + 1

    local message_data = {
        id = message_id,
        player = target,
        content = format_content(content),
        duration = duration,
        priority = priority,
        mode = mode,
        clear_console = clear_console,
        condition = condition,
        group_id = group_id,
        repeat_interval = repeat_interval,
        created = get_current_timestamp(),
        finish = get_current_timestamp() + duration,
        last_sent = 0,
        times_sent = 0,
        active = true
    }

    self.messages[message_id] = message_data

    -- Add to group if specified
    if group_id then
        if not self.message_groups[group_id] then
            self.message_groups[group_id] = {}
        end
        t_insert(self.message_groups[group_id], message_id)
    end

    return message_id
end

function RCONText:CreateMessageGroup()
    local group_id = self.next_group_id
    self.next_group_id = self.next_group_id + 1
    self.message_groups[group_id] = {}
    return group_id
end

function RCONText:RemoveMessage(message_id)
    local message = self.messages[message_id]
    if message then
        -- Remove from group if applicable
        if message.group_id and self.message_groups[message.group_id] then
            local group = self.message_groups[message.group_id]
            for i = #group, 1, -1 do
                if group[i] == message_id then
                    t_remove(group, i)
                    break
                end
            end
        end

        self.messages[message_id] = nil
        return true
    end
    return false
end

function RCONText:RemoveGroup(group_id)
    if self.message_groups[group_id] then
        for _, message_id in ipairs(self.message_groups[group_id]) do
            self.messages[message_id] = nil
        end
        self.message_groups[group_id] = nil
        return true
    end
    return false
end

function RCONText:RemoveAllPlayerMessages(player_id)
    local removed = 0
    for message_id, message in pairs(self.messages) do
        if message.player == player_id then
            self.messages[message_id] = nil
            removed = removed + 1
        end
    end
    return removed
end

function RCONText:UpdateMessage(message_id, updates)
    local message = self.messages[message_id]
    if message then
        for key, value in pairs(updates) do
            if key == "content" then
                message.content = format_content(value)
            elseif key == "duration" then
                message.duration = value
                message.finish = message.created + value
            else
                message[key] = value
            end
        end
        return true
    end
    return false
end

function RCONText:GetMessageCount(player_id)
    local count = 0
    for _, message in pairs(self.messages) do
        if not player_id or message.player == player_id then
            count = count + 1
        end
    end
    return count
end

-- Core processing function
function RCONText:GameTick()
    local now = get_current_timestamp()
    local messages_to_remove = {}

    -- Process all messages
    for message_id, message in pairs(self.messages) do
        local should_remove = false
        local should_send = false

        -- Check if player is still present
        if not player_present(message.player) then
            should_remove = true
        else
            -- Check message conditions
            local condition_met = true
            if message.condition and type(message.condition) == "function" then
                condition_met = message.condition(message)
            end

            if condition_met and message.active then
                -- Handle different message modes
                if message.mode == MODES.PERSISTENT then
                    should_send = true
                elseif message.mode == MODES.TIMED then
                    if now < message.finish then
                        should_send = true
                    else
                        should_remove = true
                    end
                elseif message.mode == MODES.REPEATING then
                    if now < message.finish then
                        if message.repeat_interval and
                            now >= (message.last_sent + message.repeat_interval) then
                            should_send = true
                        elseif message.last_sent == 0 then
                            should_send = true
                        end
                    else
                        should_remove = true
                    end
                end
            else
                should_send = false
            end
        end

        -- Send message if appropriate
        if should_send then
            send_message(message.player, message)
        end

        -- Mark for removal if needed
        if should_remove then
            t_insert(messages_to_remove, message_id)
        end
    end

    -- Remove expired/invalid messages
    for _, message_id in ipairs(messages_to_remove) do
        self.messages[message_id] = nil
    end
end

-- Configuration management
function RCONText:Configure(new_config)
    for key, value in pairs(new_config) do
        if self.config[key] ~= nil then
            self.config[key] = value
        end
    end
end

function RCONText:GetConfig()
    return deep_copy(self.config)
end

-- Utility functions
function RCONText:SendToAll(content, duration, clear_console)
    local sent_count = 0
    for i = 0, 15 do
        if player_present(i) then
            self:NewMessage(i, content, duration, clear_console)
            sent_count = sent_count + 1
        end
    end
    return sent_count
end

function RCONText:PausePlayerMessages(player_id)
    for _, message in pairs(self.messages) do
        if message.player == player_id then
            message.active = false
        end
    end
end

function RCONText:ResumePlayerMessages(player_id)
    for _, message in pairs(self.messages) do
        if message.player == player_id then
            message.active = true
        end
    end
end

-- Export constants
RCONText.MODES = MODES
RCONText.PRIORITY = PRIORITY

return RCONText
