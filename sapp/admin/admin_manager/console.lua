-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- The server console, modelled as player 0 so commands treat it like any other caller.
---@type fun(name: string): any
local import = ...
local Player = import('player')

local cprint = cprint

---@class Console: Player
local Console = Player:extend('Console')

---@param manager Manager
function Console:init(manager)
    Player.init(self, manager, { id = 0, name = '_CONSOLE_', ip = 'localhost', hash = 'N/A', socket = 'console' })
    self.level = manager.config.console_default_level
end

function Console:isConsole()
    return true
end

function Console:send(message)
    if message and message ~= '' then cprint(message) end
end

function Console:kick() end
function Console:grantEngineAccess() end
function Console:setLevel() end
function Console:requireLevel()
    return true
end
function Console:resolveLevel()
    return self.level, false
end
function Console:refreshLevel() end

return Console
