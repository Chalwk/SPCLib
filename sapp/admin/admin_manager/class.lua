-- ============================================================================
-- Lookup chain: instance -> class -> parent class -> ... -> Class.
-- `new` calls `init` (if any) with the constructor arguments.
--
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

local setmetatable = setmetatable
local pairs = pairs

---@class Class
---@field init? fun(self: Class, ...: any) Called by `new`; subclasses override this.
local Class = {}
Class.__index = Class
Class.class_name = 'Class'

---@param class_name string      Name used for debugging.
---@param fields     table | nil Static fields copied onto the new class.
---@return table subclass
function Class:extend(class_name, fields)
    local subclass = { class_name = class_name, super = self }
    subclass.__index = subclass
    if fields then
        for key, value in pairs(fields) do
            subclass[key] = value
        end
    end
    return setmetatable(subclass, { __index = self })
end

---@return Class instance
function Class:new(...)
    local instance = setmetatable({}, self)
    ---@cast instance Class
    local init = instance.init
    if init then init(instance, ...) end
    return instance
end

return Class
