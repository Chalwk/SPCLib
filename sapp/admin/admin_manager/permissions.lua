-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Command permission table (commands.txt): which level may run which command,
-- and whether it is enabled. Covers stock SAPP commands and this script's own.
---@type fun(name: string): any
local import = ...
local Class = import('class')
local Serializer = import('serializer')
local util = import('util')

---@class Permissions
---@field levels table<number, table<string, boolean>> level -> { command = enabled }
---@field index  table<string, number?>                command -> level
local Permissions = Class:extend('Permissions')

---@param storage  Storage
---@param filename string
---@param defaults { stock: table, managed: table } Seed lists: level -> command names.
function Permissions:init(storage, filename, defaults)
    self.storage = storage
    self.filename = filename
    self.defaults = defaults
    self.levels = { [1] = {} } -- level -> { command = enabled }
    self.index = {}            -- command -> level
end

function Permissions:load()
    local levels = Serializer.decodeCommands(self.storage:read(self.filename))
    local changed = false

    if next(levels) == nil then
        for level, names in pairs(self.defaults.stock) do
            levels[level] = {}
            for _, name in ipairs(names) do
                levels[level][name] = true
            end
        end
        changed = true
    end

    if not levels[1] then
        levels[1] = {}
    end -- level 1 must always exist
    self.levels = levels
    self:reindex()

    if self:ensureManaged() then changed = true end
    if changed then self:save() end
end

function Permissions:save()
    self.storage:write(self.filename, Serializer.encodeCommands(self.levels))
end

function Permissions:reindex()
    self.index = {}
    for level, names in pairs(self.levels) do
        for name in pairs(names) do
            self.index[name] = level
        end
    end
end

--- Makes sure every command this script provides has an entry, so older
--- commands.txt files pick up newly added commands at their default level.
---@return boolean added
function Permissions:ensureManaged()
    local added = false
    for level, names in pairs(self.defaults.managed) do
        for _, name in ipairs(names) do
            if not self.index[name] then
                local target = self.levels[level] and level or self:highest()
                self.levels[target][name] = true
                self.index[name] = target
                added = true
            end
        end
    end
    return added
end

---@param name string
---@return number | nil level
---@return boolean | nil enabled
function Permissions:find(name)
    local level = self.index[name]
    if level == nil then return nil end
    return level, self.levels[level][name]
end

---@param level number
---@return boolean
function Permissions:exists(level)
    return self.levels[level] ~= nil
end

---@return number[] levels Sorted ascending.
function Permissions:levelList()
    return util.sortedKeys(self.levels)
end

---@return number level
function Permissions:highest()
    local levels = self:levelList()
    return levels[#levels]
end

---@param level number
function Permissions:addLevel(level)
    self.levels[level] = {}
    self:save()
end

--- Deletes a level and its command entries. Commands provided by this script are
--- immediately re-seeded so they can never be orphaned.
---@param level number
function Permissions:deleteLevel(level)
    for name in pairs(self.levels[level] or {}) do
        self.index[name] = nil
    end
    self.levels[level] = nil
    self:ensureManaged()
    self:save()
end

--- Moves (or adds) a command to a level.
---@param name    string
---@param level   number
---@param enabled boolean
function Permissions:assign(name, level, enabled)
    local previous = self.index[name]
    if previous then self.levels[previous][name] = nil end
    self.levels[level][name] = enabled
    self.index[name] = level
    self:save()
end

---@param name    string
---@param enabled boolean
function Permissions:setEnabled(name, enabled)
    local level = self.index[name]
    if not level then return end
    self.levels[level][name] = enabled
    self:save()
end

return Permissions
