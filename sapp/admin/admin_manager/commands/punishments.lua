-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Bans, mutes and name bans: create, list and remove.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')
local ListCommand = import('commands.list')
local util = import('util')

--- Bans or mutes the target player by one of their identifiers.
-- Fields: store, key_field, extra_field, kick, refuse_pirated, output.
local PunishCommand = Command:extend('PunishCommand', {
    description = 'Flags: -y -mo -d -h -m -s -r "example reason"',
    help = 'Syntax: /$cmd <player> <flags> | Type ($cmd help) for more information.',
    spec = {
        flags = {
            ['-y'] = 'years',
            ['-mo'] = 'months',
            ['-d'] = 'days',
            ['-h'] = 'hours',
            ['-m'] = 'minutes',
            ['-s'] = 'seconds',
            ['-r'] = 'reason'
        },
        numeric = { years = true, months = true, days = true, hours = true, minutes = true, seconds = true },
        greedy = { reason = true }
    }
})

function PunishCommand:run(player, args)
    local id = tonumber(args[1])
    if not id then return self:usage(player) end

    local target = self:findPlayer(player, id)
    if not target or not self:checkTarget(player, target) then return end

    local parsed, err = util.parseFlags(args, self.spec)
    if not parsed then
        player:send(err)
        return self:usage(player)
    end

    local manager = self.manager
    if self.refuse_pirated and manager.pirated_hashes[target.hash] then
        player:send('[WARNING] ' .. target.name .. ' is using a pirated copy of Halo.')
        player:send('Pirated hashes cannot be banned, as doing so would affect all players sharing that hash.')
        return
    end

    local time, expires = util.expiration(parsed, manager.config.default_ban_duration)
    if time == false then
        player:send('That duration is out of range.')
        return
    end

    local reason = parsed.reason or 'No reason given.'
    local record = {
        offender = target.name,
        added_by = player.name,
        added_on = util.formatDate(),
        reason = reason,
        time = time,
        expires = expires
    }
    if self.extra_field then record[self.extra_field] = target[self.extra_field] end
    manager.database:addBan(self.store, target[self.key_field], record)

    if self.kick then target:kick() end

    local text = util.fill(self.output, {
        admin = player.name,
        offender = target.name,
        reason = reason,
        expires = util.describeExpiry(time)
    })
    player:send(text)
    self:log(text)
end

--- Removes a ban/mute by the id shown in the matching list command.
-- Fields: store, output.
local UnbanCommand = Command:extend('UnbanCommand', {
    help = 'Syntax: /$cmd <ban id>'
})

function UnbanCommand:run(player, args)
    local id = tonumber(args[1])
    if not id then return self:usage(player) end

    local database = self.manager.database
    local key, record = database:keyById(database.bans[self.store], id)
    if not key then
        player:send('Ban ID not found.')
        return
    end

    database:removeBan(self.store, key)
    local text = util.fill(self.output, {
        offender = record.offender or record.name or '?',
        key = key,
        name = record.name or key
    })
    player:send(text)
    self:log(('%s (%s): %s'):format(player.name, player.ip, text))
end

--- Paged list of bans/mutes.
local BanList = ListCommand:extend('BanList', {
    collection = 'bans',
    output = '[$id] $offender [$expires] [Pirated: $pirated]'
})

function BanList:fields(key, record)
    return {
        id = record.id,
        offender = record.offender or '?',
        expires = util.describeExpiry(record.time),
        pirated = self.manager.pirated_hashes[record.hash or key] and 'Yes' or 'No'
    }
end

local IpBan = PunishCommand:extend('IpBan', {
    name = 'ip_ban',
    store = 'ip',
    key_field = 'ip',
    extra_field = 'hash',
    kick = true,
    output = '$admin ip-banned $offender until [$expires] for reason: $reason'
})
local HashBan = PunishCommand:extend('HashBan', {
    name = 'hash_ban',
    store = 'hash',
    key_field = 'hash',
    extra_field = 'ip',
    kick = true,
    refuse_pirated = true,
    output = '$admin hash-banned $offender until [$expires] for reason: $reason'
})
local IpMute = PunishCommand:extend('IpMute', {
    name = 'ip_mute',
    store = 'mute_ip',
    key_field = 'ip',
    output = '$admin IP-muted $offender until [$expires] for reason: $reason'
})
local HashMute = PunishCommand:extend('HashMute', {
    name = 'hash_mute',
    store = 'mute_hash',
    key_field = 'hash',
    output = '$admin hash-muted $offender until [$expires] for reason: $reason'
})

local IpBans = BanList:extend('IpBans', {
    name = 'ip_bans',
    description = 'List all IP-bans.',
    store = 'ip',
    header = '[IP-Bans] (Page: $page/$pages)',
    empty = 'There are no ip-bans.',
    subject = 'ip-ban list'
})
local HashBans = BanList:extend('HashBans', {
    name = 'hash_bans',
    description = 'List all hash-bans.',
    store = 'hash',
    header = '[Hash-Bans] (Page: $page/$pages)',
    empty = 'There are no hash-bans.',
    subject = 'hash-ban list'
})
local IpMutes = BanList:extend('IpMutes', {
    name = 'ip_mutes',
    description = 'List all text-ban mutes by IP.',
    store = 'mute_ip',
    header = '[Text-Bans (IP)] (Page: $page/$pages)',
    empty = 'There are no text-bans by IP.',
    subject = 'text-ban list by IP'
})
local HashMutes = BanList:extend('HashMutes', {
    name = 'hash_mutes',
    description = 'List all text-ban mutes by hash.',
    store = 'mute_hash',
    header = '[Text-Bans (hash)] (Page: $page/$pages)',
    empty = 'There are no text-bans by hash.',
    subject = 'text-ban list by hash'
})

local IpUnban = UnbanCommand:extend('IpUnban', {
    name = 'ip_unban',
    store = 'ip',
    output = '($offender) ($key) unbanned.',
    description = 'Unban a player\'s IP. Use /ip_bans to get the ban ID.'
})
local HashUnban = UnbanCommand:extend('HashUnban', {
    name = 'hash_unban',
    store = 'hash',
    output = '($offender) ($key) unbanned.',
    description = 'Unban a player\'s hash. Use /hash_bans to get the ban ID.'
})
local IpUnmute = UnbanCommand:extend('IpUnmute', {
    name = 'ip_unmute',
    store = 'mute_ip',
    output = '($offender) ($key) unmuted.',
    description = 'Unmute a player by IP. Use /ip_mutes to get the mute ID.'
})
local HashUnmute = UnbanCommand:extend('HashUnmute', {
    name = 'hash_unmute',
    store = 'mute_hash',
    output = '($offender) ($key) unmuted.',
    description = 'Unmute a player by hash. Use /hash_mutes to get the mute ID.'
})

local NameBan = Command:extend('NameBan', {
    name = 'name_ban',
    description = 'Block an unwanted name.',
    help = 'Syntax: /$cmd <id> or /$cmd <name> | Type /$cmd help for more information.'
})

function NameBan:run(player, args)
    local argument = args[1]
    if not argument then return self:usage(player) end

    local manager = self.manager
    local name
    local id = tonumber(argument)

    if id then
        local target = self:findPlayer(player, id)
        if not target or not self:checkTarget(player, target) then return end
        name = target.name
    elseif #argument > 11 then
        player:send('Name too long. Max 11 characters.')
        return
    else
        name = argument
    end

    local key = name:lower()
    if manager.database.bans.name[key] then
        player:send(('Name (%s) is already banned.'):format(name))
        return
    end

    manager.database:addBan('name', key, {
        name = name,
        added_by = player.name,
        added_on = util.formatDate(),
        ip = player.ip,
        hash = player.hash
    })

    -- Remove anyone currently using the banned name.
    for other_id, other in pairs(manager.players) do
        if other_id ~= 0 and other.name:lower() == key then other:kick() end
    end

    player:send(('Added (%s) to the name-ban list.'):format(name))
    self:log(('%s name-banned (%s)'):format(player.name, name))
end

local NameBans = ListCommand:extend('NameBans', {
    name = 'name_bans',
    description = 'List all name-bans.',
    collection = 'bans',
    store = 'name',
    header = '[Name-Bans] (Page: $page/$pages)',
    output = '[$id] $name',
    empty = 'There are no name-bans.',
    subject = 'name-ban list'
})

function NameBans:fields(key, record)
    return { id = record.id, name = record.name or key }
end

local NameUnban = UnbanCommand:extend('NameUnban', {
    name = 'name_unban',
    store = 'name',
    output = 'Name ($name) has been unbanned.',
    description = 'Unban a name. Use /name_bans to view all name-bans.'
})

return {
    IpBan, HashBan, IpMute, HashMute, IpBans, HashBans, IpMutes, HashMutes, IpUnban, HashUnban, IpUnmute, HashUnmute,
    NameBan, NameBans, NameUnban
}
