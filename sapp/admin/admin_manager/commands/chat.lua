-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Admin chat and command spy. Both are on/off toggles that relay text to other admins.
---@type fun(name: string): any
local import = ...
local Command = import('commands.command')
local util = import('util')

---@class ToggleCommand: Command
---@field flag       'a_chat' | 'spy'
---@field permit_key 'admin_chat' | 'command_spy'
---@field label      string
---@field output     string
local ToggleCommand = Command:extend('ToggleCommand', {
    help = 'Syntax: /$cmd <1/0 (on/off)>',
    player_only = true
})

---@param player Player
---@return boolean
function ToggleCommand:isEnabled(player)
    if self.flag == 'a_chat' then return player.a_chat end
    return player.spy
end

---@param player  Player
---@param enabled boolean
function ToggleCommand:setEnabled(player, enabled)
    if self.flag == 'a_chat' then
        player.a_chat = enabled
    else
        player.spy = enabled
    end
end

function ToggleCommand:run(player, args)
    local toggle = tonumber(args[1])
    if toggle ~= 0 and toggle ~= 1 then return self:usage(player) end

    local permitted = self.manager.config[self.permit_key]
    if not permitted[player.level] then
        local levels = {}
        for _, level in ipairs(util.sortedKeys(permitted)) do
            if permitted[level] then levels[#levels + 1] = level end
        end
        player:send('Insufficient Permission.')
        player:send('Required levels: ' .. table.concat(levels, ', ') .. '.')
        return
    end

    local enabled = toggle == 1
    self:setEnabled(player, enabled)
    player:send(self.label .. ': ' .. (enabled and 'Enabled' or 'Disabled'))
end

--- Sends `text` from `sender` to every opted-in admin of equal or higher level.
---@param sender Player
---@param text   string
function ToggleCommand:relay(sender, text)
    local permitted = self.manager.config[self.permit_key]
    local message = util.fill(self.output, { name = sender.name, message = text })

    for id, recipient in pairs(self.manager.players or {}) do
        if id ~= 0 and self:isEnabled(recipient) and recipient.level >= sender.level and permitted[recipient.level] then
            recipient:send(message)
        end
    end
end

local AdminChat = ToggleCommand:extend('AdminChat', {
    name = 'admin_chat',
    description = 'Chat privately with other admins.',
    flag = 'a_chat',
    permit_key = 'admin_chat',
    label = 'Admin Chat',
    output = '[A-CHAT] $name: $message'
})

local CommandSpy = ToggleCommand:extend('CommandSpy', {
    name = 'command_spy',
    description = 'Toggle command spy on or off (spy on player commands).',
    flag = 'spy',
    permit_key = 'command_spy',
    label = 'Command Spy',
    output = '[SPY] $name: $message'
})

return { AdminChat, CommandSpy }
