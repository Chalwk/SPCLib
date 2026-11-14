-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Hash, IP and password admins: add, delete, list, and level changes.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')
local ListCommand = import('commands.list')
local util = import('util')

--- Adds an admin from an online player (by id) or from explicit flags.
-- Fields: store, label, article, spec, and keyFor()/validateKey() overrides.
local AdminAdd = Command:extend('AdminAdd')

---@param parsed table
---@param target Player | nil
---@return string | nil key Database key for the new admin.
function AdminAdd:keyFor(parsed, target)
    error(self.class_name .. ' must implement keyFor()')
end

---@param key    string
---@param parsed table
---@return string | nil problem Message to show when the key is unacceptable.
function AdminAdd:validateKey(key, parsed)
    return nil
end

function AdminAdd:run(player, args)
    local parsed, err = util.parseFlags(args, self.spec)
    if not parsed then
        player:send(err)
        return self:usage(player)
    end

    local target
    if parsed.id then
        target = self:findPlayer(player, parsed.id)
        if not target then return end
        parsed.username = target.name
    end

    local username, level = parsed.username, parsed.level
    local key = self:keyFor(parsed, target)
    if not username or not key or not level or (self.needs_password and not parsed.password) then
        return self:usage(player)
    end

    if #username > 11 then
        player:send('Username must be 11 characters or less.')
        return
    end
    local problem = self:validateKey(key, parsed)
    if problem then
        player:send(problem)
        return
    end
    if not self:validateLevel(player, level) then return end

    local database = self.manager.database
    local existing = database.admins[self.store][key]
    if existing then
        player:send(('%s is already %s (level %d)'):format(username, self.article, existing.level))
        return
    end

    database:addAdmin(self.store, key, {
        name = username,
        level = level,
        password = parsed.password and util.simpleHash(parsed.password) or nil,
        added_on = ('Added on %s by %s (%s)'):format(util.formatDate(), player.name, player.ip)
    })

    if target then
        if self.needs_password then self.manager:startSession(target) end
        target:refreshLevel()
    end

    player:send(('Added %s to the %s list. Level (%d).'):format(username, self.label, level))
    self:log(('%s (%s) added (%s) to the %s list. Level (%d)')
            :format(player.name, player.ip, username, self.label, level))
end

--- Deletes an admin by the id shown in the matching list command.
-- Fields: store, label.
local AdminDelete = Command:extend('AdminDelete', { help = 'Syntax: /$cmd <admin id>' })

function AdminDelete:run(player, args)
    local id = tonumber(args[1])
    if not id then return self:usage(player) end

    local manager = self.manager
    local database = manager.database
    local key, record = database:keyById(database.admins[self.store], id)
    if not key then
        player:send('Admin ID not found.')
        return
    end

    if not player:isConsole() and manager.config.protect_higher_levels and (record.level or 1) >= player.level then
        player:send('You cannot remove an admin whose level is equal to or higher than yours.')
        return
    end

    database:removeAdmin(self.store, key)
    manager:refreshLevels()

    local name = record.name or '?'
    player:send(('Removed (%s) (%s) from the %s list.'):format(key, name, self.label))
    self:log(('%s (%s) removed (%s) (%s) from the %s list.'):format(player.name, player.ip, key, name, self.label))
end

local AdminList = ListCommand:extend('AdminList', {
    collection = 'admins',
    output = '[$id] $name | Level: [$level]'
})

function AdminList:fields(key, record)
    return { id = record.id, name = record.name or 'N/A', level = record.level }
end

local HashAdminAdd = AdminAdd:extend('HashAdminAdd', {
    name = 'hash_admin_add',
    description = 'Add a new hash-admin.',
    help = 'Syntax: /$cmd <ID / -u "username"> <-l level> <-h hash>',
    store = 'hash_admins',
    label = 'hash-admin',
    article = 'a hash-admin',
    spec = { flags = { ['-u'] = 'username', ['-l'] = 'level', ['-h'] = 'hash' }, numeric = { level = true } }
})

function HashAdminAdd:keyFor(parsed, target)
    local hash = target and target.hash or parsed.hash
    return hash and hash:lower()
end

function HashAdminAdd:validateKey(hash)
    if #hash ~= 32 then return 'Hash must be 32 characters long.' end
    if not util.isMD5(hash) then return 'Hash must be a valid MD5 hash.' end
end

local HashAdminDelete = AdminDelete:extend('HashAdminDelete', {
    name = 'hash_admin_delete',
    description = 'Delete a hash-admin. Use /hash_admins to get the admin ID.',
    store = 'hash_admins',
    label = 'hash-admin'
})

local HashAdmins = AdminList:extend('HashAdmins', {
    name = 'hash_admins',
    description = 'List all hash-admins.',
    store = 'hash_admins',
    header = '[Hash-Admins] (Page: $page/$pages)',
    empty = 'There are no hash-admins.',
    subject = 'hash-admin list'
})

local IpAdminAdd = AdminAdd:extend('IpAdminAdd', {
    name = 'ip_admin_add',
    description = 'Add a new IP-admin.',
    help = 'Syntax: /$cmd <ID / -u "username"> <-l level> <-ip IP>',
    store = 'ip_admins',
    label = 'IP-admin',
    article = 'an IP-admin',
    spec = { flags = { ['-u'] = 'username', ['-l'] = 'level', ['-ip'] = 'ip' }, numeric = { level = true } }
})

function IpAdminAdd:keyFor(parsed, target)
    return target and target.ip or parsed.ip
end

function IpAdminAdd:validateKey(ip)
    if not util.isIPv4(ip) then return 'IP address not valid.' end
end

local IpAdminDelete = AdminDelete:extend('IpAdminDelete', {
    name = 'ip_admin_delete',
    description = 'Delete an IP-admin. Use /ip_admins to get the admin ID.',
    store = 'ip_admins',
    label = 'IP-admin'
})

local IpAdmins = AdminList:extend('IpAdmins', {
    name = 'ip_admins',
    description = 'List all IP-admins.',
    store = 'ip_admins',
    header = '[IP-Admins] (Page: $page/$pages)',
    empty = 'There are no ip-admins.',
    subject = 'ip-admin list'
})

local PasswordAdminAdd = AdminAdd:extend('PasswordAdminAdd', {
    name = 'pw_admin_add',
    description = 'Add a new username & password admin.',
    help = 'Syntax: /$cmd <ID / -u "username"> <-l level> <-p "password">',
    store = 'password_admins',
    label = 'password-admin',
    article = 'a password-admin',
    needs_password = true,
    spec = { flags = { ['-u'] = 'username', ['-l'] = 'level', ['-p'] = 'password' }, numeric = { level = true } }
})

function PasswordAdminAdd:keyFor(parsed)
    return parsed.username
end

function PasswordAdminAdd:validateKey(_, parsed)
    local min, max = self.manager.config.password_length_limit[1], self.manager.config.password_length_limit[2]
    if #parsed.password < min or #parsed.password > max then
        return ('Password must be %d to %d characters'):format(min, max)
    end
end

local PasswordAdminDelete = AdminDelete:extend('PasswordAdminDelete', {
    name = 'pw_admin_delete',
    description = 'Delete a password-admin. Use /pw_admins to get the admin ID.',
    store = 'password_admins',
    label = 'password-admin'
})

local PasswordAdmins = AdminList:extend('PasswordAdmins', {
    name = 'pw_admins',
    description = 'List all username & password admins.',
    store = 'password_admins',
    header = '[Password-Admins] (Page: $page/$pages)',
    empty = 'There are no password-admins.',
    subject = 'password-admin list'
})

local ChangeLevel = Command:extend('ChangeLevel', {
    name = 'change_level',
    description = 'Changes a player\'s admin level.',
    help = 'Syntax: /$cmd <player> <level> <type (hash/ip/password)>'
})

local LEVEL_TYPES = {
    hash = { store = 'hash_admins', label = 'a hash-admin', key = function (target) return target.hash end },
    ip = { store = 'ip_admins', label = 'an ip-admin', key = function (target) return target.ip end },
    password = {
        store = 'password_admins',
        label = 'a logged in password-admin',
        needs_session = true,
        key = function (target) return target.name end
    }
}

function ChangeLevel:run(player, args)
    local id, level, kind = tonumber(args[1]), tonumber(args[2]), args[3]
    if not id or not level then return self:usage(player) end

    if not self:validateLevel(player, level) then return end
    if level == 1 then
        player:send('You cannot change a player\'s admin level to 1.')
        return
    end
    if id == player.id then
        player:send('You cannot change your own admin level.')
        return
    end

    local target = self:findPlayer(player, id)
    if not target or not self:checkTarget(player, target) then return end

    if target.level == 1 then
        player:send(target.name .. ' is either not an admin or isn\'t logged in.')
        return
    end

    local spec = LEVEL_TYPES[kind]
    if not spec then
        player:send('Invalid type argument. Valid types: hash, ip, password')
        return
    end

    local database = self.manager.database
    local record = database.admins[spec.store][spec.key(target)]
    if not record or (spec.needs_session and not target.password_admin) then
        player:send(('%s is not %s.'):format(target.name, spec.label))
        return
    end

    record.level = level
    record.changed_on = ('Changed on %s by %s (%s)'):format(util.formatDate(), player.name, player.ip)
    database:saveAdmins()
    target:refreshLevel()

    player:send(('Changed %s\'s admin level to %d (%s)'):format(target.name, level, kind))
    self:log(('%s (%s) changed %s\'s admin level to %d (%s)')
            :format(player.name, player.ip, target.name, level, kind))
end

return {
    HashAdminAdd, HashAdminDelete, HashAdmins, IpAdminAdd, IpAdminDelete, IpAdmins, PasswordAdminAdd,
    PasswordAdminDelete, PasswordAdmins, ChangeLevel
}
