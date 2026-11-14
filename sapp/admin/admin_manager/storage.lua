-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Thin wrapper around io for the database folder.
---@type fun(name: string): any
local import = ...
local Class = import('class')

local open = io.open
local cprint = cprint

---@class Storage
local Storage = Class:extend('Storage')

---@param directory string Folder path including the trailing separator.
function Storage:init(directory)
    self.directory = directory
end

---@param name string
---@return string contents Empty string when the file does not exist.
function Storage:read(name)
    local file = open(self.directory .. name, 'r')
    if not file then return '' end
    local contents = file:read('*a')
    file:close()
    return contents or ''
end

local function writeWith(self, mode, name, contents)
    local file, err = open(self.directory .. name, mode)
    if not file then
        cprint('[AdminManager] Could not open ' .. name .. ': ' .. tostring(err), 12)
        return false
    end
    file:write(contents or '')
    file:close()
    return true
end

---@param name     string
---@param contents string
---@return boolean ok
function Storage:write(name, contents)
    return writeWith(self, 'w', name, contents)
end

---@param name string
---@param text string
---@return boolean ok
function Storage:append(name, text)
    return writeWith(self, 'a', name, text)
end

return Storage
