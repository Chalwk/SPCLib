-- ============================================================================
-- Copyright (c) 2023-2026 Jericho Crosby (Chalwk)
-- LICENSE:          MIT License
--                   https://github.com/Chalwk/SPCLib/blob/master/LICENSE
-- ============================================================================

local util = {}

local byte, find, format, sub = string.byte, string.find, string.format, string.sub
local concat, sort = table.concat, table.sort
local floor, ceil, min = math.floor, math.ceil, math.min
local os_date, os_time = os.date, os.time

--- djb2-style hashing. NOT cryptographically secure; it only keeps plain
--- text passwords out of admins.txt.
---@param str string
---@return string hash Eight hex characters.
function util.simpleHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33 + byte(str, i)) % 4294967296
    end
    return format('%08x', hash)
end

--- Splits on whitespace; "double quoted" sections stay together as one token.
--- An unterminated quote swallows the rest of the line.
---@param str string
---@return string[] tokens
function util.tokenize(str)
    local tokens, position, length = {}, 1, #str
    while true do
        local start = find(str, '%S', position)
        if not start then return tokens end

        if sub(str, start, start) == '"' then
            local close = find(str, '"', start + 1, true)
            tokens[#tokens + 1] = sub(str, start + 1, (close or length + 1) - 1)
            if not close then return tokens end
            position = close + 1
        else
            local stop = find(str, '%s', start) or length + 1
            tokens[#tokens + 1] = sub(str, start, stop - 1)
            position = stop
        end
    end
end

--- Replaces $placeholders from `vars`. Unknown placeholders are left untouched.
--- A function replacement is used so '%' inside values (names, reasons) is safe.
---@param template string
---@param vars     table<string, any>
---@return string
function util.fill(template, vars)
    return (template:gsub('%$([%a_]+)', function (key)
        local value = vars[key]
        if value == nil then return nil end
        return tostring(value)
    end))
end

---@param str string | nil
---@return boolean
function util.isChatCommand(str)
    local first = str and sub(str, 1, 1)
    return first == '/' or first == '\\'
end

---@param str string
---@return boolean
function util.isIPv4(str)
    local a, b, c, d = str:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')
    if not a then return false end
    return tonumber(a) <= 255 and tonumber(b) <= 255 and tonumber(c) <= 255 and tonumber(d) <= 255
end

---@param str string
---@return boolean
function util.isMD5(str)
    return #str == 32 and find(str, '^%x+$') ~= nil
end

--- Parses `-flag value` style arguments.
--- A leading numeric token is stored as `parsed.id`. Unknown tokens are skipped.
---
--- spec.flags    map of flag -> field name
--- spec.numeric  set of field names that must be non-negative integers
--- spec.greedy   set of field names that consume tokens up to the next flag
---@param args string[]
---@param spec table
---@return table | nil parsed
---@return string | nil error_message
function util.parseFlags(args, spec)
    ---@type table<string, any>
    local parsed, i = {}, 1
    local numeric, greedy = spec.numeric or {}, spec.greedy or {}

    if args[1] and tonumber(args[1]) then
        parsed.id = tonumber(args[1])
        i = 2
    end

    while i <= #args do
        local flag = args[i]
        local key = spec.flags[flag]

        if not key then
            i = i + 1
        elseif args[i + 1] == nil then
            return nil, 'Missing value for flag: ' .. flag
        elseif greedy[key] then
            local parts, j = { args[i + 1] }, i + 2
            while j <= #args and not spec.flags[args[j]] do
                parts[#parts + 1] = args[j]
                j = j + 1
            end
            parsed[key] = concat(parts, ' ')
            i = j
        elseif numeric[key] then
            local number = tonumber(args[i + 1])
            if not number or number < 0 or number ~= floor(number) then
                return nil, 'Invalid numeric value for flag ' .. flag .. ': ' .. args[i + 1]
            end
            parsed[key] = number
            i = i + 2
        else
            parsed[key] = args[i + 1]
            i = i + 2
        end
    end
    return parsed
end

---@param set table
---@return any[] keys Sorted keys.
function util.sortedKeys(set)
    local keys = {}
    for key in pairs(set) do
        keys[#keys + 1] = key
    end
    sort(keys)
    return keys
end

--- Turns { key = record } into a list of { key, record } ordered by record.id.
--- Stable ordering keeps pages consistent between calls.
---@param map table<any, table>
---@return { key: any, record: table } []
function util.sortedEntries(map)
    local entries = {}
    for key, record in pairs(map) do
        entries[#entries + 1] = { key = key, record = record }
    end
    sort(entries, function (a, b)
        local id_a, id_b = a.record.id or 0, b.record.id or 0
        if id_a ~= id_b then return id_a < id_b end
        return tostring(a.key) < tostring(b.key)
    end)
    return entries
end

--- Returns (results, total_pages, page). `results` is nil when the page is out of range.
---@param list     any[]
---@param page     number | string | nil
---@param per_page number | nil
function util.paginate(list, page, per_page)
    per_page = per_page or 5
    page = floor(tonumber(page) or 1)
    if page < 1 then page = 1 end

    local total = #list
    local pages = ceil(total / per_page)
    local first = (page - 1) * per_page + 1
    if first > total then return nil, pages, page end

    local results = {}
    for i = first, min(first + per_page - 1, total) do
        results[#results + 1] = list[i]
    end
    return results, pages, page
end

---@param for_log boolean | nil Compact sortable format for the log file.
---@return string
function util.formatDate(for_log)
    return os_date(for_log and '%Y/%m/%d %H:%M:%S' or '%Y/%m/%d at %I:%M %p (%z)')
end

---@param epoch number
---@return table time { year, month, day, hour, min, sec }
local function timeTable(epoch)
    local t = os_date('*t', epoch)
    return { year = t.year, month = t.month, day = t.day, hour = t.hour, min = t.min, sec = t.sec }
end

--- Converts a stored expiry table to epoch seconds. Zeroed or missing tables mean "never".
---@param t table | nil
---@return number | nil epoch
function util.toEpoch(t)
    if not t or (t.year or 0) <= 0 then return nil end
    return os_time({
        year = t.year,
        month = t.month,
        day = t.day,
        hour = t.hour or 0,
        min = t.min or 0,
        sec = t.sec or 0
    })
end

---@param t table | nil
---@return string
function util.describeExpiry(t)
    if not t or (t.year or 0) <= 0 then return 'permanent' end
    return format('%04d/%02d/%02d %02d:%02d:%02d', t.year, t.month, t.day, t.hour, t.min, t.sec)
end

local function isZero(...)
    for i = 1, select('#', ...) do
        if select(i, ...) ~= 0 then return false end
    end
    return true
end

--- Builds an expiry from parsed duration flags, falling back to `default` when no
--- duration was supplied. Returns nothing for a permanent entry, and `false` when
--- the resulting date cannot be represented.
---@param duration table { years, months, days, hours, minutes, seconds }
---@param default  table { y, mo, d, h, m, s }
---@return table | nil | boolean time
---@return number | nil epoch
function util.expiration(duration, default)
    local y, mo, d = duration.years or 0, duration.months or 0, duration.days or 0
    local h, m, s = duration.hours or 0, duration.minutes or 0, duration.seconds or 0

    if isZero(y, mo, d, h, m, s) then
        y, mo, d = default.y or 0, default.mo or 0, default.d or 0
        h, m, s = default.h or 0, default.m or 0, default.s or 0
    end
    if isZero(y, mo, d, h, m, s) then return nil end

    local now = os_date('*t')
    -- os.time normalises overflowing fields (month 14, day 45, ...) for us.
    local epoch = os_time({
        year = now.year + y,
        month = now.month + mo,
        day = now.day + d,
        hour = now.hour + h,
        min = now.min + m,
        sec = now.sec + s
    })
    if not epoch or epoch < 0 then return false end

    local time = timeTable(epoch)
    if time.year > 9999 then return false end -- absurd durations; use no flags for a permanent ban
    return time, epoch
end

return util
