--[[
=====================================================================================
SCRIPT NAME:      sendconsoletext_extended.lua
DESCRIPTION:      Extended replacement for Phasor's native sendconsoletext().
                  Lets you create persistent console messages with support for:
                  ordered message queues, centered/right-aligned text, dynamic
                  message updates, pausing, shifting, timed expiration, and
                  conditional callbacks.

                  Inspired by Nuggets sendconsoletext override script.
                  Rewritten from scratch and optimized for lower overhead
                  than the original implementation.

                  Example Usage:

                      local console = require("sendconsoletext_extended")
                      local sendconsoletext = console.sendconsoletext
                      local get_message = console.get_message

                      local order = { welcome = 0, kills = 1 }

                      function OnPlayerJoin(player)
                          sendconsoletext(
                              player,
                              "Welcome to the server!",
                              10,
                              order.welcome,
                              "center"
                          )
                      end

                      function OnPlayerKill(killer)
                          local msg = get_message(killer, order.kills)

                          if msg then
                              msg:append("You're popping off!", true)
                          else
                              sendconsoletext(
                                  killer,
                                  "First kill!",
                                  5,
                                  order.kills
                              )
                          end
                      end

Copyright (c) 2026 Jericho Crosby (Chalwk)
LICENSE:          MIT License
                  https://github.com/Chalwk/SPCLib/blob/master/LICENSE
=====================================================================================
]]

local type = type
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local next = next
local sort = table.sort
local floor = math.floor
local str_len = string.len
local str_sub = string.sub
local str_rep = string.rep

local INF = 1 / 0
local TICK_SECONDS = 0.1
local CONSOLE_WIDTH = 78
local CLEAR_BUFFER = str_rep(" \n", 31)
local original_sendconsoletext = sendconsoletext

local console = {}
console.__index = console

local console_state = { players = {} }

local function clamp_text(text)
    text = tostring(text or "")
    if str_len(text) > CONSOLE_WIDTH then
        return str_sub(text, 1, CONSOLE_WIDTH)
    end
    return text
end

local function pad_left(text, width)
    local len = str_len(text)
    if len >= width then
        return str_sub(text, 1, width)
    end
    return str_rep(" ", width - len) .. text
end

local function pad_center(text, width)
    local len = str_len(text)
    if len >= width then
        return str_sub(text, 1, width)
    end

    local total = width - len
    local left = floor(total / 2)
    local right = total - left
    return str_rep(" ", left) .. text .. str_rep(" ", right)
end

local function normalize_align(align)
    align = tostring(align or "left"):lower()
    if align ~= "center" and align ~= "right" then align = "left" end
    return align
end

local function resolve_callback(func)
    if type(func) == "function" then
        return func
    end
    return nil
end

local function get_state(player, create_if_missing)
    local state = console_state.players[player]
    if not state and create_if_missing then
        state = { messages = {}, order_buckets = {}, order_counts = {}, ordered = nil, dirty = true, next_id = 1 }
        console_state.players[player] = state
    end
    return state
end

local function mark_dirty(state)
    state.dirty = true
    state.ordered = nil
end

local function allocate_order(state)
    local order = 0
    while state.order_counts[order] do
        order = order + 1
    end
    return order
end

local function add_to_bucket(state, msg)
    local order = msg.order
    local bucket = state.order_buckets[order]
    if not bucket then
        bucket = {}
        state.order_buckets[order] = bucket
    end

    bucket[msg.id] = msg
    state.order_counts[order] = (state.order_counts[order] or 0) + 1
    state.messages[msg.id] = msg
    mark_dirty(state)
end

local function remove_from_bucket(state, msg)
    local order = msg.order
    local bucket = state.order_buckets[order]
    if bucket and bucket[msg.id] then
        bucket[msg.id] = nil
        local count = (state.order_counts[order] or 1) - 1
        if count <= 0 then
            state.order_counts[order] = nil
            state.order_buckets[order] = nil
        else
            state.order_counts[order] = count
        end
    end

    state.messages[msg.id] = nil
    mark_dirty(state)
end

local function rebuild_ordered_cache(state)
    if not state.dirty then return state.ordered end

    local ordered = {}
    for _, msg in pairs(state.messages) do
        ordered[#ordered + 1] = msg
    end

    sort(ordered, function (a, b)
        if a.order == b.order then
            if a._seq == b._seq then return a.id < b.id end
            return a._seq < b._seq
        end
        return a.order < b.order
    end)

    state.ordered = ordered
    state.dirty = false
    return ordered
end

local function first_message_in_bucket(bucket)
    local best

    for _, msg in pairs(bucket) do
        if not best then
            best = msg
        elseif msg._seq < best._seq or (msg._seq == best._seq and msg.id < best.id) then
            best = msg
        end
    end

    return best
end

local function get_message_text(msg)
    return msg and msg.message or nil
end

local function render_message(msg)
    local text = clamp_text(msg.message)

    if msg.align == "center" then
        return pad_center(text, CONSOLE_WIDTH)
    elseif msg.align == "right" then
        return pad_left(text, CONSOLE_WIDTH)
    end

    return text
end

local function player_is_connected(player)
    return getplayer(player) ~= nil
end

local function cleanup_player(player)
    local state = console_state.players[player]
    if state and not next(state.messages) then
        console_state.players[player] = nil
    end
end

local function destroy_message(msg)
    local state = get_state(msg.player, false)
    if not state then return end

    if state.messages[msg.id] ~= nil then
        remove_from_bucket(state, msg)
        cleanup_player(msg.player)
    end
end

local function move_message(msg, new_order)
    local state = get_state(msg.player, false)
    if not state or state.messages[msg.id] ~= msg then return false end

    new_order = tonumber(new_order)
    if new_order == nil then return false end

    if msg.order == new_order then return true end

    remove_from_bucket(state, msg)
    msg.order = new_order
    add_to_bucket(state, msg)
    return true
end

local function next_id(player, order)
    local state = get_state(player, false)
    if not state then
        if order == nil then return 1 end
        order = tonumber(order)
        return order or 0
    end

    if order == nil then return state.next_id end

    order = tonumber(order)
    if order == nil then return state.next_id end

    local count = state.order_counts[order] or 0
    return order + (count * 0.001)
end

local function sendconsoletext(player, message, time, order, align, func)
    if player == nil then return nil end
    local state = get_state(player, true)
    local msg = {
        player = player,
        id = state.next_id,
        order = tonumber(order) or allocate_order(state),
        message = tostring(message or ""),
        time = tonumber(time) or 5,
        remain = tonumber(time) or 5,
        align = normalize_align(align),
        func = resolve_callback(func),
        paused = false,
        pause_remaining = nil,
        _seq = state.next_id
    }

    state.next_id = state.next_id + 1
    add_to_bucket(state, msg)

    return setmetatable(msg, console)
end

local function get_message(player, order)
    local state = get_state(player, false)
    order = tonumber(order)
    if not state or order == nil then return nil end

    local bucket = state.order_buckets[order]
    if not bucket then return nil end

    return first_message_in_bucket(bucket)
end

local function get_messages(player)
    local state = get_state(player, false)
    if not state then return nil end
    return state.messages
end

local function get_message_block(player, order)
    local state = get_state(player, false)
    order = tonumber(order)
    if not state or order == nil then return nil end

    local bucket = state.order_buckets[order]
    if not bucket then return {} end

    local messages = {}
    for _, msg in pairs(bucket) do
        messages[#messages + 1] = msg
    end

    sort(messages, function (a, b)
        if a._seq == b._seq then return a.id < b.id end
        return a._seq < b._seq
    end)

    return messages
end

function console:get_message()
    return get_message_text(self)
end

function console:append(new_message, reset)
    local state = get_state(self.player, false)
    if not state or state.messages[self.id] ~= self then return false end

    if not player_is_connected(self.player) then return false end

    self.message = tostring(new_message or "")

    if reset ~= nil and reset ~= false then
        if reset == true then
            self.remain = self.time
        else
            local seconds = tonumber(reset)
            if seconds then
                self.time = seconds
                self.remain = seconds
            end
        end
    end

    return true
end

function console:shift(order)
    return move_message(self, order)
end

function console:pause(time)
    local state = get_state(self.player, false)
    if not state or state.messages[self.id] ~= self then return false end

    self.paused = true
    self.pause_remaining = tonumber(time) or 5
    return true
end

function console:delete()
    destroy_message(self)
end

local function refresh_message(msg, dt)
    if msg.paused then
        if msg.pause_remaining == INF then return true end

        msg.pause_remaining = msg.pause_remaining - dt
        if msg.pause_remaining <= 0 then
            msg.paused = false
            msg.pause_remaining = nil
        end

        return true
    end

    if msg.func then
        local ok, keep = pcall(msg.func, msg.player)
        if (not ok) or (not keep) then return false end
    end

    msg.remain = msg.remain - dt
    if msg.remain <= 0 then return false end

    return true
end

local function render_player(player, state)
    local ordered = rebuild_ordered_cache(state)
    if not ordered or #ordered == 0 then return end

    local visible = false
    for i = 1, #ordered do
        if not ordered[i].paused then
            visible = true
            break
        end
    end

    if not visible then return end

    original_sendconsoletext(player, CLEAR_BUFFER)

    for i = 1, #ordered do
        local msg = ordered[i]
        if not msg.paused then
            original_sendconsoletext(player, render_message(msg))
        end
    end
end

local function ConsoleTimer(id, count)
    for player, state in pairs(console_state.players) do
        if not player_is_connected(player) then
            console_state.players[player] = nil
        else
            local ordered = rebuild_ordered_cache(state)
            if ordered and #ordered > 0 then
                for i = 1, #ordered do
                    local msg = ordered[i]
                    if state.messages[msg.id] == msg then
                        if not refresh_message(msg, TICK_SECONDS) then
                            destroy_message(msg)
                        end
                    end
                end

                cleanup_player(player)
                if console_state.players[player] then
                    render_player(player, state)
                end
            end
        end
    end
    return true
end

local function console_center(text)
    text = clamp_text(text or "")
    return pad_center(text, CONSOLE_WIDTH)
end

local function opairs(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end

    sort(keys, function (a, b)
        local ta, tb = type(a), type(b)
        if ta == "number" and tb == "number" then return a < b end

        local an = tostring(a):lower()
        local bn = tostring(b):lower()
        if an ~= bn then return an < bn end
        return tostring(a) < tostring(b)
    end)

    local i = 0
    return function ()
        i = i + 1
        local key = keys[i]
        if key ~= nil then return key, t[key] end
    end
end

registertimer(100, ConsoleTimer)

return {
    sendconsoletext = sendconsoletext,
    get_message = get_message,
    get_messages = get_messages,
    get_message_block = get_message_block,
    next_id = next_id,
    console_center = console_center,
    opairs = opairs
}
