-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Base class for paged list commands (ban lists, admin lists).
-- Subclasses set `collection` ('bans' | 'admins'), `store`, `header`, `output`,
-- `empty`, `subject` and implement `fields(key, record)`.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')
local util = import('util')

---@class ListCommand: Command
---@field collection 'bans' | 'admins'
---@field store      string
---@field empty      string
---@field header     string
---@field output     string
---@field subject    string
---@field per_page   number
local ListCommand = Command:extend('ListCommand', {
    help = 'Syntax: /$cmd <page>',
    per_page = 5
})

---@param _key    any
---@param _record table
---@return table vars Placeholder values for `output`.
function ListCommand:fields(_key, _record)
    error(self.class_name .. ' must implement fields()')
end

function ListCommand:run(player, args)
    local database = self.manager.database
    ---@cast database table<string, table<string, table>>
    local source = database[self.collection][self.store]
    local entries = util.sortedEntries(source)

    if #entries == 0 then
        player:send(self.empty)
    else
        local results, pages, page = util.paginate(entries, args[1], self.per_page)
        if not results then
            player:send(('Page %d does not exist (1-%d).'):format(page, pages))
        else
            player:send(util.fill(self.header, { page = page, pages = pages }))
            for _, entry in ipairs(results) do
                player:send(util.fill(self.output, self:fields(entry.key, entry.record)))
            end
        end
    end
    self:log(('%s viewed the %s.'):format(player.name, self.subject))
end

return ListCommand
