-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

-- Plain text record codecs for every database file.
--
-- One record per line, fields separated by ';'. Literal ';', '\', LF and CR inside a
-- field are backslash-escaped (\; \\ \n \r). Commas are only used as list separators
-- in commands.txt and are not escaped (command names never contain them).
---@type fun(name: string): any
local import = ...
local util = import('util')

local Serializer = {}

local concat, sort = table.concat, table.sort
local find, gmatch, gsub, sub, byte = string.find, string.gmatch, string.gsub, string.sub, string.byte

local ESCAPE = { ['\\'] = '\\\\', [';'] = '\\;', ['\n'] = '\\n', ['\r'] = '\\r' }
local UNESCAPE = { n = '\n', r = '\r' }
local BACKSLASH = 92

---@type table<string, boolean>
local NUMERIC = { id = true, level = true }

local function escape(value)
    if value == nil then return '' end
    return (gsub(tostring(value), '[\\;\n\r]', ESCAPE))
end

local function unescape(text)
    if not find(text, '\\', 1, true) then return text end
    return (gsub(text, '\\(.)', function (char) return UNESCAPE[char] or char end))
end

--- Splits a line on unescaped semicolons and unescapes every field.
---@param line string
---@return (string | nil)[] fields
local function splitFields(line)
    local fields, count = {}, 0
    local start, position = 1, 1
    while true do
        local i = find(line, '[;\\]', position)
        if not i then break end
        if byte(line, i) == BACKSLASH then
            position = i + 2 -- skip the escaped character
        else
            count = count + 1
            fields[count] = unescape(sub(line, start, i - 1))
            start, position = i + 1, i + 1
        end
    end
    fields[count + 1] = unescape(sub(line, start))
    return fields
end

local function lines(text)
    return gmatch(text or '', '[^\r\n]+')
end

local function toText(rows)
    if #rows == 0 then return '' end
    return concat(rows, '\n') .. '\n'
end

--- Appends the escaped value of each column to `parts`.
local function appendColumns(parts, record, columns)
    for i = 1, #columns do
        parts[#parts + 1] = escape(record[columns[i]])
    end
end

--- Reads `columns` from `fields` starting at index `first`. Empty text becomes nil.
local function readColumns(fields, first, columns)
    local record = {}
    for i = 1, #columns do
        local column, value = columns[i], fields[first + i - 1]
        if NUMERIC[column] then
            record[column] = tonumber(value)
        elseif value and value ~= '' then
            record[column] = value
        end
    end
    return record
end

---@alias AdminsStore table<string, table<string, table>>
---@alias BansStore table<string, table<string, table>>
---@alias AliasesStore table<string, table<string, table<string, table>>>

---@return AdminsStore
function Serializer.emptyAdmins()
    return { hash_admins = {}, ip_admins = {}, password_admins = {} }
end

---@return BansStore
function Serializer.emptyBans()
    return { ip = {}, hash = {}, name = {}, mute_ip = {}, mute_hash = {} }
end

---@return AliasesStore
function Serializer.emptyAliases()
    return { IP_ALIASES = {}, HASH_ALIASES = {} }
end

-- admins.txt   TYPE;KEY;NAME;LEVEL;PASSWORD;ID;ADDED_ON;CHANGED_ON

local ADMIN_KINDS = { 'hash_admins', 'ip_admins', 'password_admins' }
local ADMIN_COLUMNS = { 'name', 'level', 'password', 'id', 'added_on', 'changed_on' }

function Serializer.encodeAdmins(admins)
    local rows = {}
    for _, kind in ipairs(ADMIN_KINDS) do
        for _, entry in ipairs(util.sortedEntries(admins[kind] or {})) do
            local parts = { kind, escape(entry.key) }
            appendColumns(parts, entry.record, ADMIN_COLUMNS)
            rows[#rows + 1] = concat(parts, ';')
        end
    end
    return toText(rows)
end

function Serializer.decodeAdmins(text)
    ---@type table<string, table<string, table>?>
    local admins = Serializer.emptyAdmins()
    for line in lines(text) do
        local fields = splitFields(line)
        local kind = fields[1] or ''
        local key = fields[2] or ''
        if kind ~= '' and key ~= '' then
            local store = admins[kind]
            if store then store[key] = readColumns(fields, 3, ADMIN_COLUMNS) end
        end
    end
    return admins
end

-- commands.txt   LEVEL;enabled_cmd1,enabled_cmd2;disabled_cmd1,disabled_cmd2

function Serializer.encodeCommands(levels)
    local rows = {}
    for _, level in ipairs(util.sortedKeys(levels)) do
        local enabled, disabled = {}, {}
        for name, on in pairs(levels[level]) do
            local bucket = on and enabled or disabled
            bucket[#bucket + 1] = name
        end
        sort(enabled)
        sort(disabled)
        rows[#rows + 1] = concat({ escape(level), escape(concat(enabled, ',')), escape(concat(disabled, ',')) }, ';')
    end
    return toText(rows)
end

function Serializer.decodeCommands(text)
    local levels = {}
    for line in lines(text) do
        local fields = splitFields(line)
        local level = tonumber(fields[1])
        if level then
            local names = levels[level] or {}
            levels[level] = names
            for name in gmatch(fields[2] or '', '[^,]+') do
                names[name] = true
            end
            for name in gmatch(fields[3] or '', '[^,]+') do
                names[name] = false
            end
        end
    end
    return levels
end

-- bans.txt
--   ip;IP;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;OFFENDER_HASH;Y;MO;D;H;M;S
--   hash;HASH;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;OFFENDER_IP;Y;MO;D;H;M;S
--   name;NAME;ID;ADDED_BY;ADDED_ON;ADMIN_IP;ADMIN_HASH
--   mute_ip;IP;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;Y;MO;D;H;M;S
--   mute_hash;HASH;ID;OFFENDER;ADDED_BY;ADDED_ON;REASON;Y;MO;D;H;M;S

local TIME_FIELDS = { 'year', 'month', 'day', 'hour', 'min', 'sec' }
local BAN_KINDS = { 'ip', 'hash', 'name', 'mute_ip', 'mute_hash' }

---@class BanLayout
---@field columns string[]
---@field timed   boolean | nil
---@type table<string, BanLayout>
local BAN_LAYOUTS = {
    ip        = { columns = { 'id', 'offender', 'added_by', 'added_on', 'reason', 'hash' }, timed = true },
    hash      = { columns = { 'id', 'offender', 'added_by', 'added_on', 'reason', 'ip' }, timed = true },
    name      = { columns = { 'id', 'added_by', 'added_on', 'ip', 'hash' } },
    mute_ip   = { columns = { 'id', 'offender', 'added_by', 'added_on', 'reason' }, timed = true },
    mute_hash = { columns = { 'id', 'offender', 'added_by', 'added_on', 'reason' }, timed = true }
}

function Serializer.encodeBans(bans)
    local rows = {}
    for _, kind in ipairs(BAN_KINDS) do
        local layout = BAN_LAYOUTS[kind]
        for _, entry in ipairs(util.sortedEntries(bans[kind] or {})) do
            local record = entry.record
            -- Name bans are keyed by lowercase name in memory; the file keeps the display case.
            local parts = { kind, escape(kind == 'name' and record.name or entry.key) }
            appendColumns(parts, record, layout.columns)
            if layout.timed then
                appendColumns(parts, record.time or {}, TIME_FIELDS)
            end
            rows[#rows + 1] = concat(parts, ';')
        end
    end
    return toText(rows)
end

function Serializer.decodeBans(text)
    ---@type table<string, table<string, table>?>
    local bans = Serializer.emptyBans()

    ---@type table<string, BanLayout?>
    local layouts = BAN_LAYOUTS

    for line in lines(text) do
        local fields = splitFields(line)
        local kind = fields[1] or ''
        local key = fields[2] or ''
        local layout = layouts[kind]

        if layout and key ~= '' then
            local record = readColumns(fields, 3, layout.columns)

            if layout.timed then
                local first = #layout.columns + 3
                local time = {}
                for i = 1, #TIME_FIELDS do
                    time[TIME_FIELDS[i]] = tonumber(fields[first + i - 1] or '') or 0
                end
                record.time = time
                record.expires = util.toEpoch(time)
            end

            if kind == 'name' then
                record.name = key
                key = key:lower() -- name bans are case-insensitive
            end

            local store = bans[kind]
            if store then store[key] = record end
        end
    end
    return bans
end

-- aliases.txt   PARENT;KEY;NAME;JOINED;LEVEL;LAST_ACTIVITY

local ALIAS_PARENTS = { 'IP_ALIASES', 'HASH_ALIASES' }
local ALIAS_COLUMNS = { 'joined', 'level', 'last_activity' }

function Serializer.encodeAliases(aliases)
    local rows = {}
    for _, parent in ipairs(ALIAS_PARENTS) do
        for key, names in pairs(aliases[parent] or {}) do
            for name, record in pairs(names) do
                local parts = { parent, escape(key), escape(name) }
                appendColumns(parts, record, ALIAS_COLUMNS)
                rows[#rows + 1] = concat(parts, ';')
            end
        end
    end
    return toText(rows)
end

function Serializer.decodeAliases(text)
    ---@type table<string, table<string, table?>?>
    local aliases = Serializer.emptyAliases()
    for line in lines(text) do
        local fields = splitFields(line)
        local parent = fields[1] or ''
        local key = fields[2] or ''
        local name = fields[3] or ''
        if parent ~= '' and key ~= '' and name ~= '' then
            local group = aliases[parent]
            if group then
                local names = group[key] or {}
                group[key] = names
                names[name] = readColumns(fields, 4, ALIAS_COLUMNS)
            end
        end
    end
    return aliases
end

-- logs.txt   DATE;ENTRY   (append-only)

---@return string line Complete line including the trailing newline.
function Serializer.encodeLogLine(date, entry)
    return escape(date) .. ';' .. escape(entry) .. '\n'
end

return Serializer
