-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Base class for every command this script provides.
--
-- Concrete commands only declare fields (name, description, help, ...) and
-- implement `run(player, args)`. `execute` is a template method: it performs the
-- permission check, handles `/cmd help` and the console restriction, then calls `run`.
-- `args` excludes the command name itself, so args[1] is the first parameter.
---@type fun(name: string): any
local import = ...
local Class = import('class')

local concat = table.concat
local player_present = player_present

---@class (partial) Command: Class
---@field name        string
---@field description string
---@field help        string
---@field player_only boolean
---@field relay       fun(self: Command, player: Player, text: string) Emits to command spies / admin chat.
local Command = Class:extend('Command')

Command.description = ''
Command.help = 'Syntax: /$cmd'
Command.player_only = false

---@param manager Manager
function Command:init(manager)
    self.manager = manager
    self.help = (self.help:gsub('%$cmd', self.name))
    self.description = (self.description:gsub('%$cmd', self.name))
end

---@param text string
function Command:log(text)
    self.manager:log(text, 'management')
end

---@param player Player
---@param args   string[]
function Command:execute(player, args)
    local required = self.manager.permissions:find(self.name)
    if required and not player:requireLevel(required, self.name) then return end

    if args[1] == 'help' then
        player:send(self.description)
        return
    end
    if self.player_only and player:isConsole() then
        player:send('You cannot execute this command from console.')
        return
    end
    self:run(player, args)
end

---@param _player Player
---@param _args   string[]
function Command:run(_player, _args)
    error(self.class_name .. ' must implement run()')
end

---@param player Player
function Command:usage(player)
    player:send(self.help)
end

--- Looks up an online player by id, telling `actor` when they are not there.
---@param actor Player
---@param id    number
---@return Player | nil
function Command:findPlayer(actor, id)
    local players = self.manager.players
    local target = players and players[id]
    if not target or not player_present(id) then
        actor:send('Player #' .. id .. ' is not online.')
        return nil
    end
    return target
end

--- Enforces `protect_higher_levels`: you cannot act on someone of equal or higher level.
---@param actor  Player
---@param target Player
---@return boolean allowed
function Command:checkTarget(actor, target)
    if actor:isConsole() or not self.manager.config.protect_higher_levels then return true end
    if target.level < actor.level then return true end

    actor:send(target.name .. '\'s level is equal to or higher than yours.')
    self:log(('%s (%s) tried to use (%s) on %s (level %d)')
            :format(actor.name, actor.ip, self.name, target.name, target.level))
    return false
end

--- Checks that `level` exists and that `actor` may hand it out.
---@param actor Player
---@param level number | nil
---@return boolean valid
function Command:validateLevel(actor, level)
    local manager = self.manager
    if not level or not manager.permissions:exists(level) then
        actor:send('Invalid level. Valid levels: ' .. concat(manager.permissions:levelList(), ', '))
        return false
    end
    if not actor:isConsole() and not manager.config.allow_level_escalation and level > actor.level then
        actor:send('You cannot assign a level higher than your own (' .. actor.level .. ').')
        return false
    end
    return true
end

return Command
