-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Alias lookups: every name an IP or CD-key hash has joined with.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')
local util = import('util')

--- Fields: store, field ('ip' | 'hash'), invalid, header, label, isValid(), normalise().
local AliasCommand = Command:extend('AliasCommand', {
    output = '$name  |  Level: [$level]',
    per_page = 10
})

function AliasCommand:normalise(target)
    return target
end
function AliasCommand:notice(target, player) end

function AliasCommand:run(player, args)
    local target = args[1]
    if not target then return self:usage(player) end

    local id = tonumber(target)
    if id then
        local online = self:findPlayer(player, id)
        if not online then return end
        target = online[self.field]
    else
        target = self:normalise(target)
        if not self:isValid(target) then
            player:send(self.invalid)
            return
        end
    end

    local page = tonumber(args[2]) or 1
    if page < 1 then
        player:send('Invalid page number. Must be 1 or higher.')
        return
    end

    local names = self.manager.database.aliases[self.store][target]
    local aliases = {}
    for name, record in pairs(names or {}) do
        aliases[#aliases + 1] = { name = name, record = record }
    end
    table.sort(aliases, function (a, b) return a.name < b.name end)

    local results, pages = util.paginate(aliases, page, self.per_page)
    if not results then
        player:send(('No aliases found for [%s] on page %d.'):format(target, page))
        return
    end

    player:send(('Aliases for [%s]: Page %d/%d'):format(target, page, pages))
    for _, alias in ipairs(results) do
        player:send(util.fill(self.output, {
                name = alias.name,
                level = alias.record.level or '?',
                date_joined = alias.record.joined or '?',
                last_activity = alias.record.last_activity or '?'
            }))
    end

    self:notice(target, player)
    self:log(('%s viewed the %s alias list for [%s]'):format(player.name, self.label, target))
end

local AliasIp = AliasCommand:extend('AliasIp', {
    name = 'alias_ip',
    description = 'View a player\'s aliases by IP.',
    help = 'Syntax: /$cmd <player/ip> <page>',
    store = 'IP_ALIASES',
    field = 'ip',
    label = 'IP',
    invalid = 'Invalid IP address or player ID.'
})

function AliasIp:isValid(target)
    return util.isIPv4(target)
end

local AliasHash = AliasCommand:extend('AliasHash', {
    name = 'alias_hash',
    description = 'View a player\'s aliases by hash.',
    help = 'Syntax: /$cmd <player/hash> <page>',
    store = 'HASH_ALIASES',
    field = 'hash',
    label = 'hash',
    invalid = 'Invalid hash or player ID.'
})

function AliasHash:normalise(target)
    return target:lower()
end
function AliasHash:isValid(target)
    return util.isMD5(target)
end

function AliasHash:notice(target, player)
    if self.manager.pirated_hashes[target] then
        player:send('This CD-KEY hash is pirated.')
    end
end

return { AliasIp, AliasHash }
