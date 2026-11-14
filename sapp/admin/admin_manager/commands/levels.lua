-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Level and command-permission management, confirmations and database reload.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')

local floor = math.floor

local LevelAdd = Command:extend('LevelAdd', {
    name = 'level_add',
    description = 'Add a new admin level.',
    help = 'Syntax: /$cmd <level>'
})

function LevelAdd:run(player, args)
    local level = tonumber(args[1])
    if not level or level < 1 or level ~= floor(level) then return self:usage(player) end

    local permissions = self.manager.permissions
    if permissions:exists(level) then
        player:send('Level ' .. level .. ' already exists.')
        return
    end

    permissions:addLevel(level)
    player:send('Level ' .. level .. ' added.')
    self:log(('%s (%s) added level %d to (%s)')
            :format(player.name, player.ip, level, self.manager.config.files.commands))
end

local LevelDelete = Command:extend('LevelDelete', {
    name = 'level_delete',
    description = 'Delete an admin level (requires confirmation).',
    help = 'Syntax: /$cmd <level>'
})

function LevelDelete:run(player, args)
    local level = tonumber(args[1])
    if not level then return self:usage(player) end

    local manager = self.manager
    if level == 1 then
        player:send('You cannot delete level 1.')
        return
    end
    if not manager.permissions:exists(level) then
        player:send('Level ' .. level .. ' does not exist.')
        return
    end

    player:requestConfirmation('Are you sure you want to delete level ' .. level .. '?', function ()
        if not manager.permissions:exists(level) then return end
        manager.permissions:deleteLevel(level)
        player:send('Level (' .. level .. ') has been deleted.')
        self:log(('%s (%s) deleted level %d from (%s)')
                :format(player.name, player.ip, level, manager.config.files.commands))
    end)
end

local Confirm = Command:extend('Confirm', {
    name = 'confirm',
    description = 'Confirm a pending action.'
})

function Confirm:run(player)
    local pending = player.pending
    if not pending then
        player:send('You have nothing to confirm.')
        return
    end

    player.pending = nil
    if os.time() > pending.expires then
        player:send('Action timed out.')
        return
    end
    pending.action()
end

--- Fields: enable (boolean), past ('enabled' | 'disabled').
local CommandSwitch = Command:extend('CommandSwitch', { help = 'Syntax: /$cmd <command>' })

function CommandSwitch:run(player, args)
    local name = args[1] and args[1]:lower()
    if not name then return self:usage(player) end

    local permissions = self.manager.permissions
    local level, enabled = permissions:find(name)
    if not level then
        player:send('Command (' .. name .. ') does not exist.')
    elseif enabled == self.enable then
        player:send('Command (' .. name .. ') is already ' .. self.past .. '.')
    else
        permissions:setEnabled(name, self.enable)
        player:send('Command (' .. name .. ') has been ' .. self.past .. '.')
        self:log(('%s (%s) %s command (%s)'):format(player.name, player.ip, self.past, name))
    end
end

local DisableCommand = CommandSwitch:extend('DisableCommand', {
    name = 'disable_command',
    description = 'Disable a command.',
    enable = false,
    past = 'disabled'
})
local EnableCommand = CommandSwitch:extend('EnableCommand', {
    name = 'enable_command',
    description = 'Enable a command.',
    enable = true,
    past = 'enabled'
})

local SetCommand = Command:extend('SetCommand', {
    name = 'set_command',
    description = 'Add or set a new/existing command to a new level.',
    help = 'Syntax: /$cmd <command> <level> [true/false] (optional: enable or disable it; defaults to its current state, or enabled for a new command)'
})

function SetCommand:run(player, args)
    local name, level = args[1] and args[1]:lower(), tonumber(args[2])
    if not name or not level then return self:usage(player) end

    local permissions = self.manager.permissions
    if not permissions:exists(level) then
        player:send('Admin level (' .. level .. ') does not exist.')
        return
    end

    local _, current = permissions:find(name)
    local enabled = current ~= false -- new or currently enabled -> enabled
    if args[3] then enabled = args[3]:lower() == 'true' end

    permissions:assign(name, level, enabled)
    player:send(('Command (%s) has been set to level (%d). Enabled: %s'):format(name, level, tostring(enabled)))
    self:log(('%s (%s) set command (%s) to level (%d). Enabled: %s')
            :format(player.name, player.ip, name, level, tostring(enabled)))
end

local Reload = Command:extend('Reload', {
    name = 'reload',
    description = 'Reload all admin databases.'
})

function Reload:run(player)
    self.manager:reload()
    player:send('Databases reloaded.')
    self:log(('%s (%s) reloaded the databases.'):format(player.name, player.ip))
end

return { LevelAdd, LevelDelete, Confirm, DisableCommand, EnableCommand, SetCommand, Reload }
