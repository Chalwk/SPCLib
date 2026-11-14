-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Central coordinator: owns the database, permissions, commands and players, and
-- implements every event handler the entry script forwards to.
---@type fun(name: string): any
local import = ...
local Class = import('class')
local util = import('util')
local Storage = import('storage')
local Logger = import('logger')
local Database = import('database')
local Permissions = import('permissions')
local Player = import('player')
local Console = import('console')

local time = os.time
local pairs, ipairs = pairs, ipairs
local get_var, player_present, execute_command, cprint = get_var, player_present, execute_command, cprint

local IP_PATTERN = '%d+%.%d+%.%d+%.%d+'

-- Modules that return a list of concrete command classes.
local COMMAND_MODULES = {
    'commands.auth', 'commands.chat', 'commands.punishments', 'commands.admins', 'commands.aliases', 'commands.levels'
}

-- Run from chat as well, so the player's password never appears in the chat feed.
---@type table<string, boolean>
local CHAT_OVERRIDES = { login = true, change_password = true }

---@class Manager
---@field players  table<number, Player> | nil id -> Player; nil until the first game starts
---@field commands table<string, Command>
local Manager = Class:extend('Manager')

---@param loader         function The module importer.
---@param config         table
---@param data_directory string   Folder holding the database files (with trailing separator).
function Manager:init(loader, config, data_directory)
    self.config = config
    self.storage = Storage:new(data_directory)
    self.logger = Logger:new(self.storage, config.files.logs, config.logging)
    self.database = Database:new(self.storage, config.files)
    self.permissions = Permissions:new(self.storage, config.files.commands, {
        stock = loader('stock_commands'),
        managed = config.management_commands
    })
    self.pirated_hashes = loader('pirated_hashes')

    self.commands = {}
    for _, module_name in ipairs(COMMAND_MODULES) do
        for _, class in ipairs(loader(module_name)) do
            local command = class:new(self)
            self.commands[command.name] = command
        end
    end

    self.players = nil
    self.sessions = {} -- socket -> login expiry (epoch)
    self.last_tick = 0
end

function Manager:load()
    self.database:load()
    self.permissions:load()
    execute_command('var_add ' .. self.config.custom_level_var .. ' 4 0')
    self:onStart() -- covers the script being loaded mid-game
end

---@param text    string
---@param channel string | nil 'management' | 'default'
function Manager:log(text, channel)
    self.logger:write(text, channel)
end

--- Re-reads every database file and re-applies levels to connected players.
function Manager:reload()
    self.database:saveAliases() -- keep aliases that only exist in memory
    self.database:load()
    self.permissions:load()
    self:refreshLevels()
end

function Manager:refreshLevels()
    for id, player in pairs(self.players or {}) do
        if id ~= 0 then player:refreshLevel() end
    end
end

---@param player Player
function Manager:startSession(player)
    self.sessions[player.socket] = time() + self.config.login_timeout * 3600
end

---@param socket string
function Manager:endSession(socket)
    self.sessions[socket] = nil
end

---@param socket string
---@return boolean
function Manager:hasSession(socket)
    local expires = self.sessions[socket]
    return expires ~= nil and time() <= expires
end

local function createPlayer(manager, id)
    local raw_ip = get_var(id, '$ip') or ''
    local socket = raw_ip
    if manager.config.cache_session_index == 2 then
        socket = raw_ip:match(IP_PATTERN) or raw_ip
    end
    return Player:new(manager, {
        id = id,
        name = get_var(id, '$name'),
        hash = get_var(id, '$hash'),
        ip = raw_ip:match(IP_PATTERN) or 'N/A',
        socket = socket
    })
end

---@param player Player
function Manager:announceJoin(player)
    local players = self.players
    if not players then return end

    local messages = self.config.admin_join_messages
    local entry = messages[player.level]
    if not messages.enabled or not entry or not entry[2] then return end

    local text = entry[1]:format(player.name)
    for id, other in pairs(players) do
        if id ~= 0 then other:send(text) end
    end
end

---@param id    number
---@param quiet boolean | nil Skip the join announcement (used when rebuilding on game start).
function Manager:onJoin(id, quiet)
    if not self.players then return end

    local player = createPlayer(self, id)
    self.players[id] = player

    local violation = player:findBan()
    if violation then
        self:log(('%s tried to join, but is %s-banned.'):format(player.name, violation), 'management')
        player:kick()
        return
    end
    if player:isMuted() then
        self:log(('%s joined and is muted.'):format(player.name), 'management')
    end

    player:refreshLevel()
    player:grantEngineAccess()

    local database = self.database
    database:recordAlias('IP_ALIASES', player.ip, player.name, player.level)
    database:recordAlias('HASH_ALIASES', player.hash, player.name, player.level)

    if not quiet then self:announceJoin(player) end
end

---@param id number
function Manager:onLeave(id)
    if self.players then self.players[id] = nil end
end

function Manager:onStart()
    if get_var(0, '$gt') == 'n/a' then return end

    local previous = self.players
    self.players = { [0] = Console:new(self) }

    for id = 1, 16 do
        if player_present(id) then
            local existing = previous and previous[id]
            -- Keep toggles (admin chat, spy) across maps when it is clearly the same player.
            if existing and existing.hash == get_var(id, '$hash') and existing.name == get_var(id, '$name') then
                self.players[id] = existing
                existing:refreshLevel()
            else
                self:onJoin(id, true)
            end
        end
    end
end

--- Writes alias activity for everyone currently connected.
function Manager:flushAliases()
    local database = self.database
    for id, player in pairs(self.players or {}) do
        if id ~= 0 then
            database:recordAlias('IP_ALIASES', player.ip, player.name, player.level)
            database:recordAlias('HASH_ALIASES', player.hash, player.name, player.level)
        end
    end
    database:saveAliases()
end

function Manager:onEnd()
    self:flushAliases()
end

function Manager:onUnload()
    self:flushAliases()
    execute_command('var_del ' .. self.config.custom_level_var)
end

function Manager:onTick()
    if not self.players then return end

    local now = time()
    if now == self.last_tick then return end
    self.last_tick = now

    for _, message in ipairs(self.database:purgeExpired(now)) do
        cprint(message, 12)
    end

    for _, player in pairs(self.players) do
        local pending = player.pending
        if pending and now > pending.expires then
            player.pending = nil
            player:send('Action timed out.')
        end
    end

    for socket, expires in pairs(self.sessions) do
        if now > expires then
            self.sessions[socket] = nil
            for id, player in pairs(self.players) do
                if id ~= 0 and player.socket == socket and player.password_admin then
                    player.password_admin = false
                    player:setLevel(1)
                    player:send('Your login session has expired.')
                end
            end
        end
    end
end

--- Runs a command, converting a Lua error into a log entry instead of letting it
--- escape (an escaped error would let SAPP run the raw command as well).
function Manager:run(command, player, args)
    local ok, err = pcall(command.execute, command, player, args)
    if ok then return end

    cprint(('[AdminManager] Error in %s: %s'):format(command.name, tostring(err)), 12)
    self:log(('Error in command (%s) run by %s: %s'):format(command.name, player.name, tostring(err)), 'management')
    player:send('An internal error occurred while running that command.')
end

---@param id      number
---@param message string
---@return boolean allow
function Manager:onChat(id, message)
    local player = self.players and self.players[id]
    if not player then return true end

    if util.isChatCommand(message) then
        local line = message:sub(2)
        local args = util.tokenize(line)
        local name = table.remove(args, 1)
        name = name and name:lower()

        if name and CHAT_OVERRIDES[name] then
            -- SAPP will raise EVENT_COMMAND for this same line; remember it so
            -- onCommand does not run it a second time.
            player.chat_line, player.chat_time = line, time()
            self:run(self.commands[name], player, args)
            return false
        end
        return true
    end

    if player:isMuted() then return false end

    if player.a_chat then
        self.commands.admin_chat:relay(player, message)
        return false
    end
    return true
end

local function deny(manager, player, name, reason)
    player:send(('Command (%s) %s.'):format(name, reason))
    manager:log(('%s is attempting to execute (%s) but it %s.'):format(player.name, name, reason), 'default')
    return false
end

---@param id      number
---@param command string
---@return boolean | nil allow Return false to block the command.
function Manager:onCommand(id, command)
    local player = self.players and self.players[id]
    if not player then return end

    -- Already handled through onChat (see above).
    if player.chat_line == command and player.chat_time and time() - player.chat_time <= 1 then
        player.chat_line = nil
        return false
    end

    local args = util.tokenize(command)
    local name = table.remove(args, 1)
    if not name then return end
    name = name:lower()

    ---@type Command?
    local managed = self.commands[name]

    if player:isConsole() then
        if managed then
            self:run(managed, player, args)
            return false
        end
        return true -- the console may run any stock command
    end

    local level, enabled = self.permissions:find(name)
    if level == nil then
        return deny(self, player, name, 'does not exist')
    elseif not enabled then
        return deny(self, player, name, 'is disabled')
    end

    local spy = self.commands.command_spy

    if managed then
        spy:relay(player, name)
        self:run(managed, player, args) -- checks the level itself
        return false
    end

    if player.level < level then
        player:send('Insufficient Permission.')
        player:send('You must be level (' .. level .. ') or higher.')
        self:log(
            ('%s is attempting to execute (%s) but is not a high enough level (current level: %d) (Required level: %d)')
                :format(player.name, name, player.level, level), 'default'
        )
        return false
    end

    self:log(('Command: (%s) was executed by: %s (%d) (%s)'):format(name, player.name, id, player.ip), 'default')
    spy:relay(player, name)
    return true
end

return Manager
