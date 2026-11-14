-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Append-only activity log (logs.txt). Entries are appended, never rewritten.
---@type fun(name: string): any
local import = ...
local Class = import('class')
local util = import('util')
local Serializer = import('serializer')

---@class Logger
local Logger = Class:extend('Logger')

---@param storage  Storage
---@param filename string
---@param channels table<string, boolean> e.g. { management = true, default = true }
function Logger:init(storage, filename, channels)
    self.storage = storage
    self.filename = filename
    self.channels = channels
end

---@param entry   string
---@param channel string | nil Channel name; the entry is dropped if that channel is disabled.
function Logger:write(entry, channel)
    if channel and self.channels[channel] == false then return end
    self.storage:append(self.filename, Serializer.encodeLogLine(util.formatDate(true), entry))
end

return Logger
