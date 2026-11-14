-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- In-memory admins, bans and aliases backed by plain text files.
---@type fun(name: string): any
local import = ...
local Class = import('class')
local util = import('util')
local Serializer = import('serializer')

local min, huge = math.min, math.huge

---@class Database
---@field admins      AdminsStore
---@field bans        BansStore
---@field aliases     AliasesStore
---@field next_expiry number | nil Earliest ban expiry (epoch); nil = unknown, rescan
local Database = Class:extend('Database')

---@param storage Storage
---@param files   table<string, string> Filenames keyed by purpose.
function Database:init(storage, files)
    self.storage = storage
    self.files = files
    self.admins = Serializer.emptyAdmins()
    self.bans = Serializer.emptyBans()
    self.aliases = Serializer.emptyAliases()
    self.next_expiry = nil
end

function Database:load()
    local admins_text = self.storage:read(self.files.admins)
    self.admins = Serializer.decodeAdmins(admins_text)
    if admins_text == '' then self:saveAdmins() end -- create the file on first run

    self.bans = Serializer.decodeBans(self.storage:read(self.files.bans))
    self.aliases = Serializer.decodeAliases(self.storage:read(self.files.aliases))
    self.next_expiry = nil
end

function Database:saveAdmins()
    self.storage:write(self.files.admins, Serializer.encodeAdmins(self.admins))
end

function Database:saveBans()
    self.storage:write(self.files.bans, Serializer.encodeBans(self.bans))
end

function Database:saveAliases()
    self.storage:write(self.files.aliases, Serializer.encodeAliases(self.aliases))
end

---@param store table<any, table>
---@return number id
function Database:nextId(store)
    local highest = 0
    for _, record in pairs(store) do
        if record.id and record.id > highest then highest = record.id end
    end
    return highest + 1
end

---@param store table<any, table>
---@param id    number
---@return any | nil key
---@return table | nil record
function Database:keyById(store, id)
    for key, record in pairs(store) do
        if record.id == id then return key, record end
    end
end

---@param kind   string 'hash_admins' | 'ip_admins' | 'password_admins'
---@param key    string
---@param record table
function Database:addAdmin(kind, key, record)
    record.id = self:nextId(self.admins[kind])
    self.admins[kind][key] = record
    self:saveAdmins()
end

function Database:removeAdmin(kind, key)
    self.admins[kind][key] = nil
    self:saveAdmins()
end

---@param kind   string 'ip' | 'hash' | 'name' | 'mute_ip' | 'mute_hash'
---@param key    string
---@param record table
function Database:addBan(kind, key, record)
    record.id = self:nextId(self.bans[kind])
    self.bans[kind][key] = record
    if record.expires and self.next_expiry then
        self.next_expiry = min(self.next_expiry, record.expires)
    end
    self:saveBans()
end

function Database:removeBan(kind, key)
    self.bans[kind][key] = nil
    self:saveBans()
end

local EXPIRING_KINDS = { 'ip', 'hash', 'mute_ip', 'mute_hash' }

--- Removes expired timed bans/mutes. Cheap when nothing is due: the earliest expiry
--- is cached, so the tables are only scanned when something can actually expire.
---@param now number Epoch seconds.
---@return string[] messages One line per removed entry.
function Database:purgeExpired(now)
    local messages = {}
    if self.next_expiry and now < self.next_expiry then return messages end

    local earliest = huge
    for _, kind in ipairs(EXPIRING_KINDS) do
        local store = self.bans[kind]
        for key, record in pairs(store) do
            local expires = record.expires
            if expires then
                if now >= expires then
                    store[key] = nil -- clearing during traversal is allowed
                    messages[#messages + 1] = ('Ban expired: %s (%s) %s'):format(key, record.offender or '?', kind)
                elseif expires < earliest then
                    earliest = expires
                end
            end
        end
    end

    self.next_expiry = earliest
    if #messages > 0 then self:saveBans() end
    return messages
end

---@param parent string 'IP_ALIASES' | 'HASH_ALIASES'
---@param key    string The ip or hash.
---@param name   string
---@param level  number
function Database:recordAlias(parent, key, name, level)
    local group = self.aliases[parent]
    local names = group[key]
    if not names then
        names = {}
        group[key] = names
    end

    local date = util.formatDate(true)
    local alias = names[name]
    if not alias then
        alias = { joined = date }
        names[name] = alias
    end
    alias.level = level
    alias.last_activity = date
end

return Database
