-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- A connected player. Console extends this (see console.lua).
---@type fun(name: string): any
local import = ...
local Class = import('class')

local max, time = math.max, os.time
local rprint, execute_command = rprint, execute_command

---@class PendingAction
---@field expires number Epoch seconds when the pending action times out.
---@field action  fun()  Runs when the player types /confirm.

---@class Player
---@field level          number
---@field password_admin boolean
---@field a_chat         boolean
---@field spy            boolean
---@field socket         string
---@field pending        PendingAction | nil
---@field chat_line      string | nil        Set by Manager:onChat; cleared by Manager:onCommand.
---@field chat_time      number | nil
local Player = Class:extend('Player')

---@param manager Manager
---@param info    { id: number, name: string, ip: string, hash: string, socket: string }
function Player:init(manager, info)
    self.manager = manager
    self.id = info.id
    self.name = info.name
    self.ip = info.ip
    self.hash = info.hash
    self.socket = info.socket
    self.level = 1
    self.password_admin = false
    self.a_chat = false
    self.spy = false
    self.pending = nil
end

---@return boolean
function Player:isConsole()
    return false
end

---@param message string | nil
function Player:send(message)
    if message and message ~= '' then rprint(self.id, message) end
end

---@param reason string | nil
function Player:kick(reason)
    if reason then self:send(reason) end
    execute_command('sv_kick ' .. self.id)
end

--- SAPP-level access is what lets this script see the player's commands at all;
--- this script then enforces its own permission table on top.
function Player:grantEngineAccess()
    execute_command('adminadd ' .. self.id .. ' 4')
end

---@param level number
function Player:setLevel(level)
    self.level = level
    execute_command(('var_set %s %d %d'):format(self.manager.config.custom_level_var, level, self.id))
end

--- Works out the level this player is entitled to from the admin databases.
---@return number level
---@return boolean via_password
function Player:resolveLevel()
    local admins = self.manager.database.admins
    local by_hash, by_ip = admins.hash_admins[self.hash], admins.ip_admins[self.ip]

    if by_hash or by_ip then
        return max(by_hash and by_hash.level or 1, by_ip and by_ip.level or 1), false
    end

    local record = admins.password_admins[self.name]
    if record and self.manager:hasSession(self.socket) then
        return record.level or 1, true
    end
    return 1, false
end

--- Re-reads the databases and applies the resulting level.
function Player:refreshLevel()
    local level, via_password = self:resolveLevel()
    self.password_admin = via_password
    self:setLevel(level)
end

---@param required number
---@param command  string | nil Used in the log line only.
---@return boolean allowed
function Player:requireLevel(required, command)
    if self.level >= required then return true end

    self:send('Insufficient Permission.')
    self:send('You must be level (' .. required .. ') or higher.')
    self.manager:log(
        ('%s is attempting to execute (%s) but is not a high enough level (current level: %d) (Required level: %d)')
            :format(self.name, tostring(command), self.level, required), 'management'
    )
    return false
end

---@return table | nil mute The matching mute record, if any.
function Player:isMuted()
    local bans = self.manager.database.bans
    return bans.mute_ip[self.ip] or bans.mute_hash[self.hash]
end

---@return string | nil kind 'hash' | 'ip' | 'name' when the player is banned.
function Player:findBan()
    local bans = self.manager.database.bans
    if bans.hash[self.hash] then return 'hash' end
    if bans.ip[self.ip] then return 'ip' end
    if bans.name[self.name:lower()] then return 'name' end
end

--- Asks the player to type /confirm; `action` runs if they do before the timeout.
---@param prompt string
---@param action fun()
function Player:requestConfirmation(prompt, action)
    self.pending = { expires = time() + self.manager.config.confirmation_timeout, action = action }
    self:send(prompt)
    self:send('Type /confirm to confirm.')
end

return Player
