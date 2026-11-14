-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Login, logout, level info and password management.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')
local util = import('util')

local concat = table.concat

local function validatePassword(player, config, password)
    local min, max = config.password_length_limit[1], config.password_length_limit[2]
    if #password < min or #password > max then
        player:send(('Password must be %d to %d characters'):format(min, max))
        return false
    end
    return true
end

local function changeStamp(player)
    return ('Changed on %s by %s (%s)'):format(util.formatDate(), player.name, player.ip)
end

local Login = Command:extend('Login', {
    name = 'login',
    description = 'Login as a password-admin.',
    help = 'Syntax: /$cmd <password>',
    player_only = true
})

function Login:run(player, args)
    local password = concat(args, ' ')
    if password == '' then return self:usage(player) end

    if player.level > 1 then
        player:send(('You are already logged in as %s (level %d)'):format(player.name, player.level))
        return
    end

    local manager = self.manager
    local record = manager.database.admins.password_admins[player.name]
    if not record or record.password ~= util.simpleHash(password) then
        player:send('Incorrect username or password.')
        self:log(('%s (%s) failed to log in.'):format(player.name, player.ip))
        return
    end

    manager:startSession(player)
    player.password_admin = true
    player:setLevel(record.level)
    player:send(('Successfully logged in as %s (level %d)'):format(player.name, player.level))
    self:log(('%s (%s) logged in as %s Level (%d)'):format(player.name, player.ip, player.name, player.level))
end

local Logout = Command:extend('Logout', {
    name = 'logout',
    description = 'Logout as a password-admin.',
    player_only = true
})

function Logout:run(player)
    if player.level == 1 then
        player:send('You are not logged in.')
        return
    end
    if player.password_admin then
        self.manager:endSession(player.socket)
        player.password_admin = false
    end
    player:setLevel(1)
    player:send('Successfully logged out.')
    self:log(('%s (%s) logged out.'):format(player.name, player.ip))
end

local MyLevel = Command:extend('MyLevel', {
    name = 'my_level',
    description = 'Show your current admin level.'
})

function MyLevel:run(player)
    player:send('Your admin level is (' .. player.level .. ').')
end

local AdminsOnline = Command:extend('AdminsOnline', {
    name = 'admins_online',
    description = 'List all online admins.'
})

function AdminsOnline:run(player)
    local found = {}
    for id, other in pairs(self.manager.players) do
        if id ~= 0 and other.level > 1 then
            found[#found + 1] = ('[%d] %s (Level %d)'):format(id, other.name, other.level)
        end
    end

    if #found == 0 then
        player:send('No admins are currently online.')
        return
    end
    table.sort(found)
    player:send('Online admins:')
    for _, line in ipairs(found) do
        player:send(line)
    end
end

local ChangePassword = Command:extend('ChangePassword', {
    name = 'change_password',
    description = 'Change your own password.',
    help = 'Syntax: /$cmd <"old password"> <"new password">',
    player_only = true
})

function ChangePassword:run(player, args)
    local old_password, new_password = args[1], args[2]
    if not old_password then return self:usage(player) end
    if not new_password or new_password == '' then
        player:send('You must specify the new password')
        return
    end

    local manager = self.manager
    if not validatePassword(player, manager.config, new_password) then return end

    local database = manager.database
    local record = database.admins.password_admins[player.name]
    if not record then
        player:send(('Username (%s) is not a registered admin name.'):format(player.name))
        return
    end

    if record.password ~= util.simpleHash(old_password) then
        player:send('The old password is incorrect.')
        return
    end

    local new_hash = util.simpleHash(new_password)
    if new_hash == record.password then
        player:send('New password cannot be the same as the old password.')
        return
    end

    record.password, record.changed_on = new_hash, changeStamp(player)
    database:saveAdmins()
    player:send('Password changed successfully.')
    self:log(('%s (%s) changed %s\'s password.'):format(player.name, player.ip, player.name))
end

local ChangeAdminPassword = Command:extend('ChangeAdminPassword', {
    name = 'change_admin_password',
    description = 'Change another player\'s password.',
    help = 'Syntax: /$cmd <id> <"new password">'
})

function ChangeAdminPassword:run(player, args)
    local id, new_password = tonumber(args[1]), args[2]
    if not id then return self:usage(player) end

    local target = self:findPlayer(player, id)
    if not target or not self:checkTarget(player, target) then return end

    if not new_password or new_password == '' then
        player:send('You must specify a password.')
        return
    end

    local manager = self.manager
    if not validatePassword(player, manager.config, new_password) then return end

    local database = manager.database
    local record = database.admins.password_admins[target.name]
    if not record then
        player:send(('Username (%s) is not a registered admin name.'):format(target.name))
        return
    end

    local new_hash = util.simpleHash(new_password)
    if new_hash == record.password then
        player:send('New password cannot be the same as the old password.')
        return
    end

    record.password, record.changed_on = new_hash, changeStamp(player)
    database:saveAdmins()
    player:send(('Changed %s\'s password.'):format(target.name))
    self:log(('%s (%s) changed %s\'s password.'):format(player.name, player.ip, target.name))
end

return { Login, Logout, MyLevel, AdminsOnline, ChangePassword, ChangeAdminPassword }
